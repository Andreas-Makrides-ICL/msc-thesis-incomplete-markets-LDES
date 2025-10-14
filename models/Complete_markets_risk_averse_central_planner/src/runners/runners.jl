# main_iteration.jl
# Functions for managing ADMM iterations in the risk-averse capacity expansion model.
# These functions handle updates to previous values, convergence checks, penalty computations, 
# and objective optimization during the iterative process.

"""
    initialize_previous_values(m)

Initializes storage arrays for previous iteration values of generator, storage, and demand variables. 
This is used to track changes between iterations for convergence calculations in the ADMM algorithm.

# Arguments
- `m`: The JuMP model containing the variables (`q`, `q_dch`, `q_ch`, `d_fix`, `d_flex`).

# Returns
- `Dict`: A dictionary containing previous values for:
  - `:q`: Generator outputs.
  - `:ch_dis`: Net storage charge/discharge (discharge minus charge).
  - `:d`: Total demand (negative sum of fixed and flexible demand).
"""
function initialize_previous_values(m)
    previous_values = Dict(
        :q => value.(m[:q]),                  # Store previous generator outputs
        :ch_dis => value.(m[:q_dch]) .- value.(m[:q_ch]),  # Net storage charge/discharge
        :d => -(value.(m[:d_fix]) .+ value.(m[:d_flex]))  # Total demand (negative sum)
    )
    return previous_values
end

"""
    compute_dual_convergence(m, d, iteration, residual, penalty, previous_values)

Computes the dual residual norm using stored dual residual variables. This is a key metric for 
assessing convergence in the ADMM algorithm, measuring the change in decision variables between 
iterations.

# Arguments
- `m`: The JuMP model containing the variables (`q`, `q_dch`, `q_ch`, `d_fix`, `d_flex`).
- `d`: The `ModelData` instance containing sets (`S`, `G`, `T`, `O`) and parameters.
- `iteration::Int`: The current iteration number.
- `residual`: The primal residual values.
- `penalty::Float64`: The penalty factor for ADMM updates.
- `previous_values::Dict`: Dictionary of previous iteration values (from `initialize_previous_values`).

# Returns
- `Float64`: The total dual residual norm, summing contributions from generators, storage, and demand.
"""
function compute_dual_convergence(m, d, iteration, residual, penalty, previous_values)
    if iteration == 1
        return 0.0  # No dual residual for the first iteration
    else
        # Calculate the length of resources (generators + storage + demand)
        len_r = length(d.S) + length(d.G) + 1

        # Compute dual residual for generators
        residual_array = reshape(repeat(Array(residual), 1, 1, length(d.G)), length(d.G), length(d.T), length(d.O))
        if iteration > 1 
            previous_residual_array = reshape(repeat(Array(previous_values[:residual]), 1, 1, length(d.G)), length(d.G), length(d.T), length(d.O))
        else
            previous_residual_array = zeros(length(d.G), length(d.T), length(d.O))
        end
        dual_residual_g = norm(penalty * (value.(m[:q]) .- previous_values[:q] .- residual_array / len_r .+ previous_residual_array / len_r), 2)

        # Compute dual residual for storage (net charge/discharge)
        residual_array = reshape(repeat(Array(residual), 1, 1, length(d.S)), length(d.S), length(d.T), length(d.O))
        if iteration > 1 
            previous_residual_array = reshape(repeat(Array(previous_values[:residual]), 1, 1, length(d.S)), length(d.S), length(d.T), length(d.O))
        else
            previous_residual_array = zeros(length(d.S), length(d.T), length(d.O))
        end
        dual_residual_s = norm(penalty * ((value.(m[:q_dch]) .- value.(m[:q_ch])) .- previous_values[:ch_dis] .- residual_array / len_r .+ previous_residual_array / len_r), 2)

        # Compute dual residual for demand
        dual_residual_c = norm(penalty * ((-value.(m[:d_fix]) .- value.(m[:d_flex])) .- previous_values[:d] .- residual / len_r .+ (iteration > 1 ? previous_values[:residual] / len_r : 0)), 2)

        # Sum the dual residuals
        return dual_residual_g + dual_residual_s + dual_residual_c
    end
end


function compute_dual_convergence_new(model, iteration)

    m = model.model
    d = model.data
    settings = model.setup
    G = d["sets"]["G"]
    S = d["sets"]["S"]
    T = d["sets"]["T"]
    O = d["sets"]["O"]

    previous_residual = m.results[i-1][:residual]
    previous_values_g = m.results[i-1][:q]
    previous_values_s = m.results[i-1][:ch_dis]
    previous_values_d = m.results[i-1][:d]

    len_r = length(S) + length(G) + 1
    dual_residual_g = Containers.DenseAxisArray{Float64}(undef, G, T, O);
    dual_residual_s = Containers.DenseAxisArray{Float64}(undef, S, T, O);
    dual_residual_c = Containers.DenseAxisArray{Float64}(undef, T, O);

    for g in d["sets"]["G"]
        residual_g = norm(penalty * ( m.results[i][:q][g,:,:] .- m.results[i-1][:q][g,:,:] .- m.results[i][:residual] / len_r + m.results[i-1][:residual] / len_r), 2)
    end
    for s in d["sets"]["S"]
        residual_s = norm(penalty * ( m.results[i][:ch_dis][s,:,:] .- m.results[i-1][:ch_dis][s,:,:] .- m.results[i][:residual] / len_r + m.results[i-1][:residual] / len_r), 2)
    end
    
    residual_c = norm(penalty * ( m.results[i][:d] .- m.results[i-1][:d] .- m.results[i][:residual] / len_r + m.results[i-1][:residual] / len_r), 2)
    
    residual_total = dual_residual_g + dual_residual_s + dual_residual_c
    
    return residual_total

end

"""
    update_lambda_values(d, residual, penalty)

Updates the Lagrange multipliers (λ values) based on residuals, as part of the ADMM algorithm. 
This adjusts the prices to balance supply and demand iteratively.

# Arguments
- `d`: The `ModelData` instance containing the current λ values and parameters.
- `residual`: The primal residual values.
- `penalty::Float64`: The penalty factor for ADMM updates.
"""
function update_lambda_values(d, residual, penalty)
    # Update λ values using the residual and penalty factor
    prices = d.λ .- (penalty / 2 .* residual)
    override_param!(d, :λ, prices)  # Store the updated prices in ModelData
end

"""
    update_previous_values!(m, previous_values)

Updates the previous iteration values before the next iteration starts. This ensures that the 
values of generator outputs, storage charge/discharge, and demand are stored for convergence 
checks in the ADMM algorithm.

# Arguments
- `m`: The JuMP model containing the variables (`q`, `q_dch`, `q_ch`, `d_fix`, `d_flex`, `residual`).
- `previous_values::Dict`: Dictionary to store the updated previous values.
"""
function update_previous_values!(m, previous_values)
    previous_values[:q] = value.(m[:q])                  # Update generator outputs
    previous_values[:ch_dis] = value.(m[:q_dch]) .- value.(m[:q_ch])  # Update net storage charge/discharge
    previous_values[:d] = -(value.(m[:d_fix]) .+ value.(m[:d_flex]))  # Update total demand
    previous_values[:residual] = value.(m[:residual])    # Update residual values
end

"""
    update_model_expressions!(opt_model)

Updates expressions in the model using new λ values. This adjusts the model’s profit, risk 
measures, and other expressions for the current iteration of the ADMM algorithm.

# Arguments
- `opt_model::OptimizationModel`: The optimization model to update expressions for.
"""
function update_model_expressions!(opt_model)
    # Update expressions with settings to use λ values and calculate profits and risk measures
    define_expressions!(opt_model, settings_temp=Dict(:use_lambda => true, :calculate_profits => true, :calculate_risk_measures => true, :calculate_residual => false))
end

"""
    check_convergence(primal_convergence, dual_convergence; tolerance=1e-4)

Checks if the convergence criteria are met for the ADMM algorithm by comparing primal and dual 
residual norms against a tolerance threshold.

# Arguments
- `primal_convergence::Float64`: The primal residual norm.
- `dual_convergence::Float64`: The dual residual norm.
- `tolerance::Float64`: The convergence tolerance threshold (default: 1e-4).

# Returns
- `Bool`: True if both primal and dual convergence criteria are met, False otherwise.
"""
function check_convergence(primal_convergence, dual_convergence; tolerance=1e-4)
    return primal_convergence < tolerance && dual_convergence < tolerance
end

"""
    define_and_compute_penalty!(m, d, residual, previous_values, penalty, iteration, results_history)

Defines and computes penalty terms and penalty expressions for the ADMM algorithm in a single 
function. These penalties are added to the objective function to enforce convergence.

# Arguments
- `m`: The JuMP model to define penalty expressions in.
- `d`: The `ModelData` instance containing sets (`G`, `S`, `T`, `O`), weights (`W`, `P`), and parameters (`δ`).
- `residual`: The primal residual values.
- `previous_values::Dict`: Dictionary of previous iteration values.
- `penalty::Float64`: The penalty factor for ADMM updates.
- `iteration::Int`: The current iteration number.
- `results_history`: A history of results (not used in this function but passed for potential future use).
"""
function define_and_compute_penalty!(m, d, residual, previous_values, penalty, iteration, results_history)
    # Calculate the length of resources (generators + storage + demand)
    len_r = length(d.S) + length(d.G) + 1

    # Remove previous penalty expressions if they exist
    if haskey(m, :penalty_term_g)
        unregister(m, :penalty_term_g)
    end
    if haskey(m, :penalty_term_s)
        unregister(m, :penalty_term_s)
    end
    if haskey(m, :penalty_term_c)
        unregister(m, :penalty_term_c)
    end

    # Define penalty term for generators
    @expression(m, penalty_term_g[g in d.G], 
        sum(d.W[(t,o)] * (d.P[o] * d.δ + dual(m[:cvar_tail_g][g, o])) * penalty / 2 *
        (m[:q][g, t, o] - previous_values[:q][g, t, o] + residual[t, o] / len_r)^2 
        for t in d.T, o in d.O)
    )

    # Define penalty term for storage (net charge/discharge)
    @expression(m, penalty_term_s[s in d.S], 
        sum(d.W[(t,o)] * (d.P[o] * d.δ + dual(m[:cvar_tail_s][s, o])) * penalty / 2 *
        (m[:q_dch][s, t, o] - m[:q_ch][s, t, o] - previous_values[:ch_dis][s, t, o] + residual[t, o] / len_r)^2 
        for t in d.T, o in d.O)
    )

    # Define penalty term for demand
    @expression(m, penalty_term_c, 
        sum(d.W[(t,o)] * d.P[o] * penalty / 2 * 
        (-m[:d_fix][t, o] - m[:d_flex][t, o] - previous_values[:d][t, o] + residual[t, o] / len_r)^2 
        for t in d.T, o in d.O)
    )
end

"""
    define_and_optimize_objective!(m, d)

Defines and optimizes the updated objective function for the current ADMM iteration. The objective 
includes profit terms, demand value, energy costs, and penalty terms to enforce convergence.

# Arguments
- `m`: The JuMP model to define and optimize the objective for.
- `d`: The `ModelData` instance containing sets and parameters.
"""
function define_and_optimize_objective!(m, d)
    # Define the objective as maximizing profits minus costs and penalties
    @objective(m, Max, sum(m[:ρ_g][g] for g in d.G) +  
                    sum(m[:ρ_s][s] for s in d.S) +  
                    m[:demand_value] -  
                    m[:energy_cost] - 
                    sum(m[:penalty_term_g][g] for g in d.G) -
                    sum(m[:penalty_term_s][s] for s in d.S) -
                    m[:penalty_term_c])

    # Optimize the model with the updated objective
    optimize!(m)
end
# results.jl
# Functions and structs for extracting and storing results from the optimization model in the 
# risk-averse capacity expansion framework. This includes solution values, dual prices, and 
# iteration history for analysis.

using JuMP

"""
    extract_solution!(opt_model::OptimizationModel)

Extracts decision variable values from a solved optimization model, focusing on investment 
decisions for generators and storage units. The extracted values are stored in dictionaries 
for power and energy capacities.

# Arguments
- `opt_model::OptimizationModel`: The optimization model containing the solved variables.

# Returns
- `Tuple{Dict, Dict}`: A tuple of two dictionaries:
  - `cap_P`: Power capacities for generators (`x_g`) and storage units (`x_P`).
  - `cap_E`: Energy capacities for storage units (`x_E`).
"""
function extract_capacities!(model)
    m = model.model
    data = model.data

    # Extract power capacity investment decisions
    capacities = Dict{Symbol, Any}()
    capacities[:x_g] = value.(m[:x_g])
    capacities[:x_P] = value.(m[:x_P]) 
    capacities[:x_E] = value.(m[:x_E]) 

    return capacities
end

"""
    extract_dual_values!(opt_model::OptimizationModel; weight_prices=true)

Extracts dual variables (shadow prices) from the solved optimization model, specifically from 
the demand balance constraint. These prices represent the marginal cost of meeting demand and 
are optionally adjusted by weights and probabilities.

# Arguments
- `opt_model::OptimizationModel`: The optimization model containing the solved constraints.
- `weight_prices::Bool`: If `true`, adjusts prices by dividing by time weights and scenario 
  probabilities (default: `true`).

# Returns
- `Dict`: A dictionary of rounded dual prices (shadow prices) for each time period and scenario.

# Notes
- The function checks if the `demand_balance` constraint exists in the model.
- If all extracted prices are non-positive, they are negated to ensure positive values.
- The results are stored in `opt_model.results[:price]` and rounded to 3 decimal places.
"""
function extract_price!(model; verbose = false)
    m = model.model
    data = model.data

    δ = data["data"]["additional_params"]["δ"]

    O = data["sets"]["O"]
    T = data["sets"]["T"]

    # Check if the demand_balance constraint exists in the model
    if haskey(m, :demand_balance)
        # Extract shadow prices (dual values) from the demand balance constraint
        price = dual.(m[:demand_balance])
        

        # Adjust prices by weights and probabilities if specified
        for t in T, o in O
            price[t, o] /= data["data"]["time_weights"][t,o] * data["data"]["additional_params"]["P"][o] #This step is needed because your model likely multiplies constraints and objectives by weights during optimization.
        end

        # Ensure prices are positive by negating if the average is negative
        avg_price = mean(values(price))
        if avg_price < 0
            price = -price
        end
        
    else
        if verbose
            @warn "The demand_balance constraint does not exist in the model. Dual prices cannot be extracted."
        end
        price = Dict{Any, Any}()
        print("The demand_balance constraint does not exist in the model. Dual prices cannot be extracted.")
        
    end
    return price
end
"""
    extract_op!(model)

Extracts operational parameters from the solved optimization model:
- Generator outputs (`q`)
- Net storage charge/discharge (`ch_dis`)
- Total demand (negative sum of fixed and flexible demand) (`d`)

Returns a dictionary with these arrays and their summed values.
"""
function extract_op!(model)
    m = model.model
    settings = model.setup
    op = Dict{Symbol, Any}()

    data = model.data
    D = data["data"]["demand"]        # Demand profiles (DenseAxisArray)
    peak_demand = data["data"]["additional_params"]["peak_demand"]  # Peak demand

    # Generator outputs
    op[:q] = value.(m[:q])

    # Net storage charge/discharge (q_dch - q_ch)
    op[:q_dch] = value.(m[:q_dch])
    op[:q_ch] = value.(m[:q_ch])
    op[:ch_dis] = op[:q_dch] .- op[:q_ch]

    # Total demand (negative sum of d_fix and d_flex)
    if settings["demand_type"] == "QP"
        op[:d_fix] = value.(m[:d_fix])
        op[:d_flex] = value.(m[:d_flex])
        op[:d] = -(op[:d_fix] .+ op[:d_flex])
    else
        op[:l] = value.(m[:l])
        op[:d] = - D[t, o] * peak_demand
    end

    return op
end

function extract_base_results(model)
    base_results = Dict{Any, Any}()

    base_results["capacities"] = extract_capacities!(model)   # Extract primal solution values
    base_results["price"] = extract_price!(model) # Extract dual prices if needed

    return base_results
end


function extract_iteration_results!(model, name)

    # Extracts results for a specific iteration of the optimization model.
    # This includes primal and dual variables, as well as other relevant data.
    op = extract_op!(model)  # Extract operational parameters (e.g., generation, storage)
    
    # Store results in a dictionary
    iteration_results = Dict{Symbol, Any}()
    iteration_results[:price] = extract_price!(model)  # Extract dual prices (shadow prices)
    iteration_results[:capacities] = extract_capacities!(model)  # Extract investment decisions
    iteration_results[:residual] = value.(model.model[:residual])  # Extract primal residual values
    for (key, value) in op
        iteration_results[key] = value  # Store operational parameters in the results dictionary
    end

    iteration_results[:of] = objective_value(model.model)  # Extract objective function value

    m = model.model
    G = model.data["sets"]["G"]
    S = model.data["sets"]["S"]
    O = model.data["sets"]["O"]
    iteration_results[:μ_g] = Dict((g, o) => dual(m[:cvar_tail_g][g, o]) for g in G, o in O)
    iteration_results[:μ_s] = Dict((s, o) => dual(m[:cvar_tail_s][s, o]) for s in S, o in O)
    #iteration_results[:μ_d] = Dict(o => dual(m[:cvar_tail_d][o]) for o in O)

    model.results[name] = iteration_results  # Store the results in the model's results dictionary
    
end

"""
    extract_risk_adjusted_weights(model)

Extracts the duals of the CVaR tail constraints (`cvar_tail_total[o]`) in a central planner model.

Returns a dictionary of:
- raw dual values for each scenario
- normalized "risk-adjusted probabilities" (duals / sum)

Also prints:
- Active tail scenarios (with non-zero duals)
- Risk-adjusted probability distribution

# Arguments
- `model`: the OptimizationModel (after solve)

# Returns
- Tuple: (Dict{Int, Float64}, Dict{Int, Float64})
"""
function extract_risk_adjusted_weights(model)
    m = model.model
    O = model.data["sets"]["O"]

    # Get raw dual values of CVaR tail constraints
    dual_vals = Dict(o => dual(m[:cvar_tail_total][o]) for o in O)

    # Total dual weight for normalization
    total_dual = sum(dual_vals[o] for o in O)

    # Compute normalized risk weights
    risk_weights = total_dual > 0 ? Dict(o => dual_vals[o] / total_dual for o in O) : Dict(o => 0.0 for o in O)

    # Print summary
    println("\n===== CVaR Tail Dual Analysis =====")
    println("Raw dual values (all shown):")
    for o in O
        d = dual_vals[o]
        @printf("  Scenario %d → dual = %.12e\n", o, d)
    end

    println("\nNormalized risk-adjusted probabilities:")
    for (o, p) in risk_weights
        if p > 1e-4
            println("  Scenario $o → risk_weight = $(round(p, digits=4))")
        end
    end
    println("====================================\n")

    return dual_vals, risk_weights
end

function extract_unserved_demand(model)
    m = model.model
    T = model.data["sets"]["T"]
    O = model.data["sets"]["O"]
    W = model.data["data"]["time_weights"]
    
    unserved_demand_fix = Dict(o => sum(W[t,o] *  value(m[:unserved_fixed][t,o]) for t in T) for o in O)
    unserved_demand_flex = Dict(o => sum(W[t,o] *  value(m[:unserved_flex][t,o]) for t in T) for o in O)

    total_unserved_demand_fix = sum(P[o] * unserved_demand_fix[o] for o in O)
    total_unserved_demand_flex = sum(P[o] * unserved_demand_flex[o] for o in O) 
    total = total_unserved_demand_fix + total_unserved_demand_flex
    
    # Print summary
    println("\n===== Unserved demand per scenario =====")
    for o in O
        d1 = unserved_demand_fix[o]
        d2 = unserved_demand_flex[o]
        d3 = d1 + d2
        println("  Scenario $o → Unserved Demand Fix = $d1, Unserved Demand Flex = $d2, Total Unserved Demand = $d3")
    end

    println("\nTotal Unserved Demand across all scenarios:")
    println(" Total Unserved Demand Fix = $total_unserved_demand_fix, Total Unserved Demand Flex = $total_unserved_demand_flex, Total Unserved Demand = $total")
    println("====================================\n")

    co2 = value(m[:co2])
    println("\nTotal MWh of gas = $co2")
    println("====================================\n")
end
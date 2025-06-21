# generators.jl
# Functions for defining generator-related constraints and expressions in the optimization model. 
# These include generation limits, profit calculations, cost expressions, risk measures, and 
# Conditional Value-at-Risk (CVaR) constraints for the risk-averse capacity expansion framework.

using JuMP

"""
    define_generator!(m::JuMP.Model, data::Dict, settings::Dict; remove_first::Bool=false, update_prices::Bool=false)

Defines generator-related expressions (profits, costs, risk measures, residuals) and constraints 
(generation limits, CVaR tail constraints) for the optimization model. These model generator 
behavior, including operational limits and risk-averse investment decisions.

# Arguments
- `m::JuMP.Model`: The JuMP model to which expressions and constraints are added.
- `data::Dict`: The data dictionary returned by `load_data`, containing sets and data arrays.
- `settings::Dict`: The settings dictionary (e.g., `default_setup`) containing model configurations.
- `remove_first::Bool`: If `true`, removes existing CVaR constraints and exits (default: `false`).
- `update_prices::Bool`: If `true`, updates price coefficients (λ) in existing CVaR constraints (default: `false`).

# Expressions Defined
- `gen_variable_costs`: Variable costs for generators per scenario, based on output and variable cost rates.
- `gen_investment_costs`: Investment costs for generators, based on installed capacity.
- `gen_total_costs`: Total costs for generators per scenario, combining variable and investment costs.
- `π_g`: Generation revenue per scenario, based on output and prices (λ if available, otherwise 0).
- `ρ_g`: Generator risk-adjusted profit, combining expected revenue minus costs and risk measures (CVaR).

# Constraints Defined
- `gen_limits`: Limits generator output based on capacity and availability.
- `cvar_tail_g`: CVaR tail constraint for generators, ensuring the tail profit meets the risk threshold.

# Notes
- If λ is provided in `data["data"]["additional_params"]`, revenues use λ values; otherwise, revenues are set to 0.
- If `update_prices` is `true`, the function removes and redefines the CVaR constraints with updated price coefficients.
- If `remove_first` is `true`, the function removes the CVaR constraints and exits without redefining them.
"""
function define_generator!(model; remove_first::Bool=false, update_prices::Bool=false)

    m = model.model  # Extract the JuMP model from the mod object
    settings = model.setup  # Extract settings from the mod object
    data = model.data  # Extract data from the mod object
    
    # Extract sets from data dictionary
    G = data["sets"]["G"]
    T = data["sets"]["T"]
    O = data["sets"]["O"]

    # Extract data arrays and additional parameters
    A = data["data"]["availability"]  # Availability factors (DenseAxisArray)
    W = data["data"]["time_weights"]  # Time weights (DenseAxisArray)
    P = data["data"]["additional_params"]["P"]  # Scenario probabilities (Dict)
    δ = data["data"]["additional_params"]["δ"]  # Risk aversion coefficient
    Ψ = data["data"]["additional_params"]["Ψ"]  # CVaR parameter
    gen_data = data["data"]["generation_data"]  # Generation data (DenseAxisArray)
    λ = haskey(data["data"], "additional_params") && haskey(data["data"]["additional_params"], "λ") ? 
        data["data"]["additional_params"]["λ"] : nothing  # Lagrange multipliers (Dict or nothing)

    G_VRE = [g for g in G if gen_data[g, "VRE"] >= 1]  # Variable Renewable Energy generators
    # Set price_available flag based on whether λ is provided
    price_available = !isnothing(λ)

    # Throw error if update_prices is true but prices are not available
    if update_prices && !price_available
        error("Cannot update prices: Price coefficients (λ) are not provided in data['data']['additional_params']")
    end

    # Remove existing expressions at the beginning
    for sym in [:π_g, :ρ_g]
        maybe_remove_expression(m, sym)
    end

    if !update_prices
        # Define Generator Costs Expressions
        # Variable costs: Based on output and variable cost rates, per scenario
        @expression(m, gen_variable_costs[g in G, o in O], 
            sum(W[t, o] * gen_data[g, "C_v"] * m[:q][g, t, o] for t in T)
        )
        # Investment costs: Based on installed capacity (not scenario-specific)
        @expression(m, gen_investment_costs[g in G], 
            gen_data[g, "C_inv"] * gen_data[g, "CRF"] * m[:x_g][g]
        )
        # Total costs: Combine variable and investment costs, per scenario
        @expression(m, gen_total_costs[g in G, o in O], 
            m[:gen_variable_costs][g, o] + m[:gen_investment_costs][g]
        )
    end

    # Define Revenue Expression (excluding costs)
    # Generation revenue per scenario: Use λ if available, otherwise set to 0
    @expression(m, π_g[g in G, o in O], 
        sum(W[t, o] * m[:q][g, t, o] * (price_available ? λ[t, o] : 0) for t in T)
    )


    if δ==1.0
        # Generator risk-adjusted profit: Weighted sum of expected profit (revenue - costs) and CVaR
        @expression(m, ρ_g[g in G], sum(P[o] * (m[:π_g][g, o] - m[:gen_total_costs][g, o]) for o in O)
        ) 
    elseif δ==0.0
        # Generator risk-adjusted profit: Weighted sum of expected profit (revenue - costs) and CVaR
        @expression(m, ρ_g[g in G], (m[:ζ_g][g] - (1 / Ψ) * sum(P[o] * m[:u_g][g, o] for o in O))
        )
    else
        # Define Risk-Adjusted Profit Expression
        # Generator risk-adjusted profit: Weighted sum of expected profit (revenue - costs) and CVaR
        @expression(m, ρ_g[g in G], 
            δ * sum(P[o] * (m[:π_g][g, o] - m[:gen_total_costs][g, o]) for o in O) + 
            (1 - δ) * (m[:ζ_g][g] - (1 / Ψ) * sum(P[o] * m[:u_g][g, o] for o in O))
        )   
    end


    if !update_prices
        # Generation Limits: Ensures generator output does not exceed capacity times availability
        @constraint(m, gen_limits[g in G, t in T, o in O], 
            (g in A.axes[3] || g in G_VRE ? m[:x_g][g] * A[t, o, g] : m[:x_g][g]) >= m[:q][g, t, o]
        )
    end

    # Check if CVaR constraint already exists
    has_cvar_tail_g = haskey(m, :cvar_tail_g)

    # Remove existing CVaR constraint if it exists and either remove_first is true or update_prices is true
    if has_cvar_tail_g && (remove_first || !update_prices || update_prices)
        maybe_remove_constraint(m, :cvar_tail_g)
        has_cvar_tail_g = false
    end

    # If remove_first is true, exit after removal
    if remove_first
        return
    end

    # Define new CVaR tail constraint for generators
    if !has_cvar_tail_g
        if price_available
            @constraint(m, cvar_tail_g[g in G, o in O], 
                m[:u_g][g, o] - m[:ζ_g][g] + 
                sum(W[t, o] * m[:q][g, t, o] * λ[t, o] for t in T) - 
                m[:gen_total_costs][g, o] >= 0
            )
        else
            @constraint(m, cvar_tail_g[g in G, o in O], 
                m[:u_g][g, o] - m[:ζ_g][g] - m[:gen_total_costs][g, o] >= 0
            )
        end
    end

    if update_prices
        return  # Exit after updating constraints without redefining other expressions or constraints
    end

    # --- Nuclear Ramp Rate Constraints ---
    # Define ramp rate as a fraction of installed capacity (e.g., 10% per hour)
    ramp_rate = 1  # 100% of capacity per hour

    for g in G
        if g == "Nuclear"
            @constraint(m, [t in T[2:end], o in O], 
                m[:q][g, t, o] - m[:q][g, t-1, o] <= ramp_rate * m[:x_g][g]
            )
            @constraint(m, [t in T[2:end], o in O], 
                m[:q][g, t-1, o] - m[:q][g, t, o] <= ramp_rate * m[:x_g][g]
            )
        end
    end

        # --- Nuclear Minimum Stable Output Constraint ---
    min_output_frac = 0.5  # Minimum output is 50% of installed capacity
    nuclear_fraction = 0.04

    for g in G
        if g == "Nuclear"
            @constraint(m, [t in T, o in O],
                m[:q][g, t, o] ≥ min_output_frac * m[:x_g][g]
            )
            @constraint(m, m[:x_g][g] ≤ nuclear_fraction * setup["peak_demand"])
        end
    end

end

export define_generator!
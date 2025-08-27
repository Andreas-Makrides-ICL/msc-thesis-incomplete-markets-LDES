# consumer.jl
# Functions for defining consumer-related expressions and constraints in the optimization model. 
# These include welfare value of demand, energy costs, risk measures, and demand limits for the 
# risk-averse capacity expansion framework.

using JuMP

"""
    define_consumer!(m::JuMP.Model, data::Dict, settings::Dict; remove_first::Bool=false, update_prices::Bool=false)

Defines consumer-related expressions and constraints for the optimization model, including the 
welfare value of demand, energy costs, risk measures, and limits on fixed and flexible demand components.

# Arguments
- `micael::JuMP.Model`: The JuMP model to which expressions and constraints are added.
- `data::Dict`: The data dictionary returned by `load_data`, containing sets and data arrays.
- `settings::Dict`: The settings dictionary (e.g., `default_setup`) containing model configurations.
- `remove_first::Bool`: If `true`, removes existing constraints and exits (default: `false`).
- `update_prices::Bool`: If `true`, updates price coefficients (λ) in existing CVaR constraints (default: `false`).

# Expressions Defined
- `demand_value`: Welfare value of demand per scenario, calculated as:
  - For LP (`demand_type == "linear"`): `sum(W[t, o] * B * (D[t, o] * peak_demand - m[:l][t, o]) for t in T)`.
  - For QP (`demand_type == "QP"`): `sum(W[t, o] * B * (d_fix[t, o] + d_flex[t, o] - d_flex[t, o]^2 / (2 * flexible_demand)) for t in T)`.
- `energy_cost`: Total energy cost per scenario, calculated as:
  - For LP (`demand_type == "linear"`): `sum(W[t, o] * λ[t, o] * (D[t, o] * peak_demand - m[:l][t, o]) for t in T)`.
  - For QP (`demand_type == "QP"`): `sum(W[t, o] * λ[t, o] * (d_fix[t, o] + d_flex[t, o]) for t in T)`.
- `u_d`: Loss relative to Value-at-Risk (VaR) for consumers, per scenario.
- `ζ_d`: VaR variable for consumers.
- `ρ_d`: Consumer risk-adjusted welfare, combining expected welfare minus costs and risk measures (CVaR).

# Constraints Defined
- `d_fix_limit`: Limits fixed demand to `D[t, o] * peak_demand`, for QP demand.
- `d_flex_limit`: Limits flexible demand to `flexible_demand`, for QP demand.
- `cvar_tail_d`: CVaR tail constraint for consumers, ensuring the tail welfare meets the risk threshold.

# Notes
- If λ is provided in `data["data"]["additional_params"]`, energy costs are calculated using λ; otherwise, the `energy_cost` expression is not defined.
- Demand limits (`d_fix_limit`, `d_flex_limit`) and risk measures (`u_d`, `ζ_d`, `ρ_d`, `cvar_tail_d`) are only defined for QP demand (`demand_type == "QP"`).
- If `update_prices` is `true`, the function removes and redefines the CVaR constraints with updated price coefficients.
- If `remove_first` is `true`, the function removes existing constraints and exits without redefining them.
"""
function define_consumer!(model; remove_first::Bool=false, update_prices::Bool=false)

    m = model.model  # Extract the JuMP model from the mod object
    settings = model.setup  # Extract settings from the mod object
    data = model.data  # Extract data from the mod object

    # Extract sets from data dictionary
    T = data["sets"]["T"]
    O = data["sets"]["O"]

    # Extract data arrays and additional parameters
    D = data["data"]["demand"]        # Demand profiles (DenseAxisArray)
    W = data["data"]["time_weights"]  # Time weights (DenseAxisArray)
    P = data["data"]["additional_params"]["P"]  # Scenario probabilities (Dict)
    δ = data["data"]["additional_params"]["δ"]  # Risk aversion coefficient
    Ψ = data["data"]["additional_params"]["Ψ"]  # CVaR parameter
    B = data["data"]["additional_params"]["B"]  # Penalty for unserved energy
    peak_demand = data["data"]["additional_params"]["peak_demand"]  # Peak demand
    λ = haskey(data["data"], "additional_params") && haskey(data["data"]["additional_params"], "λ") ? 
        data["data"]["additional_params"]["λ"] : nothing  # Lagrange multipliers (Dict or nothing)

    # Extract settings
    demand_type = settings["demand_type"]  # QP or linear demand
    flexible_demand = settings["flexible_demand"]  # Fraction of demand that can be flexible
    # Set price_available flag based on whether λ is provided
    price_available = !isnothing(λ)

    # Throw error if update_prices is true but prices are not available
    if update_prices && !price_available
        error("Cannot update prices: Price coefficients (λ) are not provided in data['data']['additional_params']")
    end

    # Remove existing expressions at the beginning
    for sym in [:demand_value, :energy_cost, :ρ_d, :unserved_demand_cost]
        maybe_remove_expression(m, sym)
    end

    # Check if CVaR constraint already exists
    has_cvar_tail_d = haskey(m, :cvar_tail_d)

    # Remove existing CVaR constraint if update_prices is true or if not updating prices
    if has_cvar_tail_d && (!update_prices || update_prices)
        maybe_remove_constraint(m, :cvar_tail_d)
        has_cvar_tail_d = false
    end
    
    minWTP = 0
    # Define Welfare Value of Demand (per scenario)
    if demand_type == "QP"
        @expression(m, demand_value[o in O], 
            sum(W[t, o] * (B) * 
                (m[:d_fix][t, o] + m[:d_flex][t, o] - m[:d_flex][t, o]^2 / (2 * ((flexible_demand-1) * D[t, o] * peak_demand))) 
                for t in T)
        )
        @expression(m, unserved_demand_cost[o in O], 
            0
        )
        @expression(m, unserved_fixed[t in T, o in O], 
            D[t,o]* peak_demand - ((flexible_demand-1) * D[t, o] * peak_demand) - m[:d_fix][t, o]
        )
        @expression(m, unserved_fixed_cost[o in O], 
            sum(W[t,o] * (B) * unserved_fixed[t,o] for t in T)
        )
        @expression(m, unserved_flex[t in T, o in O], 
            ((flexible_demand-1) * D[t, o] * peak_demand) - m[:d_flex][t, o]
        )
         
        @expression(m, unserved_flex_cost[o in O], 
            sum(W[t,o] * 0.5 * unserved_flex[t,o] * ((price_available ? price[t, o] : 50) - minWTP) for t in T) 
        )
        @expression(m, unserved_demand[t in T, o in O], 
            D[t,o] - m[:d_fix][t, o] - m[:d_flex][t, o]
        )
        @expression(m, unserved_demand_cost_fix_and_flex[o in O], 
            unserved_fixed_cost[o] + unserved_flex_cost[o]
        )

    elseif demand_type == "linear"
        @expression(m, demand_value[o in O], 
            sum(W[t, o] * B * (D[t, o] * peak_demand) for t in T)
        )
        @expression(m, unserved_demand_cost[o in O], 
            sum(W[t, o] * B * m[:l][t, o] for t in T)
        )
    end

    # Define Energy Cost Expression (per scenario, only if λ is available)
    if price_available
        if demand_type == "QP"
            @expression(m, energy_cost[o in O], 
                sum(W[t, o] * λ[t, o] * (m[:d_fix][t, o] + m[:d_flex][t, o]) for t in T)
            )
        elseif demand_type == "linear"
            @expression(m, energy_cost[o in O], 
                sum(W[t, o] * λ[t, o] * (D[t, o] * peak_demand - m[:l][t, o]) for t in T)
            )
        end
    end


    # Define Demand Limits and Risk Measures (only for QP demand)
    if demand_type == "QP"
        if !update_prices
            @constraint(m, d_fix_limit[t in T, o in O], 
                m[:d_fix][t, o] + m[:d_flex][t, o] <= D[t, o] * peak_demand
            )
            @constraint(m, d_flex_limit[t in T, o in O], 
                m[:d_flex][t, o] <= (flexible_demand-1) * D[t, o] * peak_demand
            )
            @constraint(m, d_fix_limit_extra[t in T, o in O], 
                m[:d_fix][t, o] <= D[t, o] * peak_demand - (flexible_demand-1) * D[t, o] * peak_demand
            )
            #dfixmax=D-Dflex
        end
    end

    @expression(m, ρ_d, sum(P[o] * (m[:demand_value][o] - (price_available ? m[:energy_cost][o] : 0)) for o in O))
"""
    # Consumer risk-adjusted welfare: Weighted sum of expected welfare minus costs and CVaR
    if δ == 1.0
        @expression(m, ρ_d, sum(P[o] * (m[:demand_value][o] - (price_available ? m[:energy_cost][o] : 0)) for o in O))
    elseif δ == 0.0
        @expression(m, ρ_d, (m[:ζ_d] - (1 / Ψ) * sum(P[o] * m[:u_d][o] for o in O)))
    else
        @expression(m, ρ_d, 
            δ * sum(P[o] * (m[:demand_value][o] - (price_available ? m[:energy_cost][o] : 0)) for o in O) + 
            (1 - δ) * (m[:ζ_d] - (1 / Ψ) * sum(P[o] * m[:u_d][o] for o in O))
        )
    end

    # Define CVaR Tail Constraint for Consumers
    if !has_cvar_tail_d
        if demand_type == "QP" && price_available
            @constraint(m, cvar_tail_d[o in O], 
                m[:ζ_d] - (m[:demand_value][o] - sum(W[t, o] * λ[t, o] * (m[:d_fix][t, o] + m[:d_flex][t, o]) for t in T)) <= m[:u_d][o]
            )
        else
            @constraint(m, cvar_tail_d[o in O], 
                m[:ζ_d] - (m[:demand_value][o] - (price_available ? m[:energy_cost][o] : 0)) <= m[:u_d][o]
            )
        end
    end
"""
    if update_prices
        return  # Exit after updating constraints without redefining other expressions or constraints
    end

end

export define_consumer!
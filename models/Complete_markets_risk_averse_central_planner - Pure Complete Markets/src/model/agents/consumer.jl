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
    for sym in [:demand_value, :unserved_demand_cost]
        maybe_remove_expression(m, sym)
    end

    
    minWTP = 0
    # Define Welfare Value of Demand (per scenario)
    if demand_type == "QP"
        #@expression(m, demand_value[o in O], 
        #    sum(W[t, o] * (B) * 
        #        (m[:d_fix][t, o] + m[:d_flex][t, o] - m[:d_flex][t, o]^2 / (2 * ((flexible_demand-1) * D[t, o] * peak_demand))) 
        #        for t in T)
        #)
        @expression(m, demand_value[o in O], 
            sum(W[t, o] * (B) * 
                (m[:d_fix][t, o] + m[:d_flex][t, o] - m[:d_flex][t, o]^2 / (2 * (0.05 * peak_demand))) 
                for t in T)
        )
        
        @expression(m, unserved_fixed[t in T, o in O], 
            D[t,o]* peak_demand - (0.05 * peak_demand) - m[:d_fix][t, o]
        )
        @expression(m, unserved_fixed_cost[o in O], 
            sum(W[t,o] * (B) * unserved_fixed[t,o] for t in T)
        )
        @expression(m, unserved_flex[t in T, o in O], 
            (0.05 * peak_demand) - m[:d_flex][t, o]
        )
         
        @expression(m, unserved_flex_cost[o in O], 
            sum(W[t,o] * 0.5 * unserved_flex[t,o] * ((price_available ? price[t, o] : 50) - minWTP) for t in T) 
        )

    end

    # Define Demand Limits and Risk Measures (only for QP demand)
    if demand_type == "QP"
        if !update_prices
            @constraint(m, d_fix_limit[t in T, o in O], 
                m[:d_fix][t, o] + m[:d_flex][t, o] <= D[t, o] * peak_demand
            )
            #@constraint(m, d_flex_limit[t in T, o in O], 
            #    m[:d_flex][t, o] <= (flexible_demand-1) * D[t, o] * peak_demand
            #)
            @constraint(m, d_flex_limit[t in T, o in O], 
                m[:d_flex][t, o] <= 0.05 * peak_demand
            )
            #@constraint(m, d_fix_limit_extra[t in T, o in O], 
            #    m[:d_fix][t, o] <= D[t, o] * peak_demand - (flexible_demand-1) * D[t, o] * peak_demand
            #)
            @constraint(m, d_fix_limit_extra[t in T, o in O], 
                m[:d_fix][t, o] <= D[t, o] * peak_demand - 0.05 * peak_demand
            )
            #dfixmax=D-Dflex
        end
    end

end

export define_consumer!
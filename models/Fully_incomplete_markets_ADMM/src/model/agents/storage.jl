# storage.jl
# Functions for defining storage-related expressions and constraints in the optimization model. 
# These handle risk-averse investor behavior for storage units, including profit calculations, 
# risk measures, operational constraints, and Conditional Value-at-Risk (CVaR) constraints for the 
# risk-averse capacity expansion framework.

using JuMP

"""
    define_storage!(m::JuMP.Model, data::Dict, settings::Dict; remove_first::Bool=false, update_prices::Bool=false)

Defines key storage-related expressions (profits, costs, risk measures, residuals) and constraints 
(operational and CVaR tail constraints) for the optimization model. These model risk-averse behavior 
for storage units.

# Arguments
- `m::JuMP.Model`: The JuMP model to which expressions and constraints are added.
- `data::Dict`: The data dictionary returned by `load_data`, containing sets and data arrays.
- `settings::Dict`: The settings dictionary (e.g., `default_setup`) containing model configurations.
- `remove_first::Bool`: If `true`, removes existing CVaR constraints and exits (default: `false`).
- `update_prices::Bool`: If `true`, updates price coefficients (λ) in existing CVaR constraints (default: `false`).

# Expressions Defined
- `stor_variable_costs`: Variable costs for storage units per scenario (currently 0, as storage has no variable costs in this model).
- `stor_investment_costs`: Investment costs for storage units, based on installed power and energy capacity.
- `stor_total_costs`: Total costs for storage units per scenario, combining variable and investment costs.
- `initial_SOC_expr`: Initial state of charge for storage units, per scenario.
- `π_s`: Storage revenue per scenario, based on net discharge and prices (λ if available, otherwise 0).
- `ρ_s`: Storage risk-adjusted profit, combining expected revenue minus costs and risk measures (CVaR).
- `energy_cost`: Total energy cost, calculated using λ values (if λ is provided).
- `residual`: Market residual, representing the imbalance between supply and demand.

# Constraints Defined
- `SOC_limit`: Tracks energy levels in storage over time, introduced only if `update_prices` is `false`.
- `storage_energy_limits`: Ensures storage energy does not exceed capacity, introduced only if `update_prices` is `false`.
- `charging_limits`: Limits the charging rate of storage units, introduced only if `update_prices` is `false`.
- `discharging_limits`: Limits the discharging rate of storage units, introduced only if `update_prices` is `false`.
- `final_SOC`: Ensures storage units meet a minimum energy level at the end, introduced only if `update_prices` is `false`.
- `cvar_tail_s`: CVaR tail constraint for storage units, combining power and energy profits.

# Notes
- If λ is provided in `data["data"]["additional_params"]`, revenues and energy costs are calculated using λ; otherwise, revenues are set to 0.
- If `update_prices` is `true`, the function removes and redefines the CVaR constraints with updated price coefficients.
- If `remove_first` is `true`, the function removes the CVaR constraints and exits without redefining them.
"""
function define_storage!(model; remove_first::Bool=false, update_prices::Bool=false)

    m = model.model  # Extract the JuMP model from the mod object
    settings = model.setup  # Extract settings from the mod object
    data = model.data  # Extract data from the mod object

    # Extract sets from data dictionary
    S = data["sets"]["S"]
    T = data["sets"]["T"]
    O = data["sets"]["O"]

    # Extract data arrays and additional parameters
    W = data["data"]["time_weights"]  # Time weights (DenseAxisArray)
    P = data["data"]["additional_params"]["P"]  # Scenario probabilities (Dict)
    δ = data["data"]["additional_params"]["δ"]  # Risk aversion coefficient
    Ψ = data["data"]["additional_params"]["Ψ"]  # CVaR parameter
    stor_data = data["data"]["storage_data"]    # Storage data (DenseAxisArray)
    λ = haskey(data["data"], "additional_params") && haskey(data["data"]["additional_params"], "λ") ? 
        data["data"]["additional_params"]["λ"] : nothing  # Lagrange multipliers (Dict or nothing)

    # Extract settings flag
    chronological_clustering = settings["use_hierarchical_clustering"]  # Clustering setting

    # Set price_available flag based on whether λ is provided
    price_available = !isnothing(λ)

    # Throw error if update_prices is true but prices are not available
    if update_prices && !price_available
        error("Cannot update prices: Price coefficients (λ) are not provided in data['data']['additional_params']")
    end

    # Remove existing expressions at the beginning
    for sym in [:π_s, :ρ_s, :energy_cost]
        maybe_remove_expression(m, sym)
    end

    if !update_prices
        # Define Storage Costs Expressions
        # Variable costs: Currently 0, as storage has no variable costs in this model, per scenario
        @expression(m, stor_variable_costs[s in S, o in O], 0)
        # Investment costs: Based on installed power and energy capacity (not scenario-specific)
        @expression(m, stor_investment_costs[s in S], 
            (stor_data[s, "C_inv_P"] * stor_data[s, "CRF"] + stor_data[s, "FOMs"])* m[:x_P][s] + 
            stor_data[s, "C_inv_E"] * stor_data[s, "CRF"] * m[:x_E][s]
        )
        # Total costs: Combine variable and investment costs, per scenario
        @expression(m, stor_total_costs[s in S, o in O], 
            m[:stor_variable_costs][s, o] + m[:stor_investment_costs][s]
        )
    end

    # Define Revenue Expression (excluding costs)
    # Storage revenue per scenario: Use λ if available, otherwise set to 0
    @expression(m, π_s[s in S, o in O], 
        sum(W[t, o] * (m[:q_dch][s, t, o] - m[:q_ch][s, t, o]) * (price_available ? λ[t, o] : 0) for t in T)
    )

    if δ==1.0
        # Define Risk-Adjusted Profit Expression
        # Storage risk-adjusted profit: Weighted sum of expected profit (revenue - costs) and CVaR
        @expression(m, ρ_s[s in S], sum(P[o] * (m[:π_s][s, o] - m[:stor_total_costs][s, o]) for o in O)
        )
    elseif δ==0.0
        # Define Risk-Adjusted Profit Expression
        # Storage risk-adjusted profit: Weighted sum of expected profit (revenue - costs) and CVaR
        @expression(m, ρ_s[s in S], (m[:ζ_s][s] - (1 / Ψ) * sum(P[o] * m[:u_s][s, o] for o in O))
        )
    else
        # Define Risk-Adjusted Profit Expression
        # Storage risk-adjusted profit: Weighted sum of expected profit (revenue - costs) and CVaR
        @expression(m, ρ_s[s in S], 
            δ * sum(P[o] * (m[:π_s][s, o] - m[:stor_total_costs][s, o]) for o in O) + 
            (1 - δ) * (m[:ζ_s][s] - (1 / Ψ) * sum(P[o] * m[:u_s][s, o] for o in O))
        )
    end

    # Energy Cost Expression (using λ values if available)
    if price_available
        @expression(m, energy_cost, 
            sum(W[t, o] * P[o] * λ[t, o] * (m[:d_fix][t, o] + m[:d_flex][t, o]) for t in T, o in O)
        )
    end


    # Check if CVaR constraint already exists
    has_cvar_tail_s = haskey(m, :cvar_tail_s)

    # Remove existing CVaR constraint if it exists and either remove_first is true or update_prices is true
    if has_cvar_tail_s && (remove_first || !update_prices || update_prices)
        maybe_remove_constraint(m, :cvar_tail_s)
        has_cvar_tail_s = false
    end

    # Remove existing operational constraints if they exist and either remove_first is true or update_prices is false
    if remove_first || !update_prices
        for sym in [:SOC_limit, :storage_energy_limits, :charging_limits, :discharging_limits, :final_SOC]
            maybe_remove_constraint(m, sym)
        end
    end

    # If remove_first is true, exit after removal
    if remove_first
        return
    end

    if !update_prices
        # Identify storage units with initial state of charge requirements
        s_soc_init = [s for s in S if stor_data[s, "init_soc"] > 0]

        # Initial State of Charge (SOC) as Expression: Sets initial energy level for storage
        @expression(m, initial_SOC_expr[s in S, o in O], 
            (s in s_soc_init ? stor_data[s, "init_soc"] * m[:x_E][s] : 0)
        )
        
        # State of Charge (SOC) Limit: Tracks energy levels in storage over time
        @constraint(m, SOC_limit[s in S, t in T, o in O], 
            m[:e][s, t, o] == (t == T[1] ? m[:initial_SOC_expr][s, o] : m[:e][s, t-1, o]) - 
                            (1 / stor_data[s, "dis_eff"]) * (chronological_clustering ? W[t, o] * m[:q_dch][s, t, o] : m[:q_dch][s, t, o]) + 
                            stor_data[s, "ch_eff"] * (chronological_clustering ? W[t, o] * m[:q_ch][s, t, o] : m[:q_ch][s, t, o])
        )

        # Storage Energy Limits: Ensures storage energy does not exceed capacity
        @constraint(m, storage_energy_limits[s in S, t in T, o in O],
            m[:e][s, t, o] <= m[:x_E][s]
        )

        # Storage Charging Limits: Limits the charging rate of storage units
        @constraint(m, charging_limits[s in S, t in T, o in O],
            m[:q_ch][s, t, o] <= m[:x_P][s]
        )

        # Storage Discharging Limits: Limits the discharging rate of storage units
        @constraint(m, discharging_limits[s in S, t in T, o in O],
            m[:q_dch][s, t, o] <= m[:x_P][s]
        )

        # Final State of Charge (SOC): Ensures storage units meet a minimum energy level at the end
        @constraint(m, final_SOC[s in S, o in O; s in s_soc_init], 
            m[:e][s, T[end], o] >= stor_data[s, "init_soc"] * m[:x_E][s]
        )

        # === Fixed Duration Constraints for BESS Variants ===
        @constraint(m, storage_duration1, m[:x_E]["BESS"] <= 4 * m[:x_P]["BESS"])
        @constraint(m, storage_duration2, m[:x_E]["BESS"] >= 1 * m[:x_P]["BESS"])
        #@constraint(m, storage_duration_8h, m[:x_E]["BESS_8h"] == 8 * m[:x_P]["BESS_8h"])
        @constraint(m, H2_morethan10h, m[:x_E]["H2"] >= 8 * m[:x_P]["H2"])
        #@constraint(m, H2_lessthan15h, m[:x_E]["H2"] <= (20 - δ*6)* m[:x_P]["H2"])
    end 

    # Define new CVaR tail constraint for storage units
    if !has_cvar_tail_s
        if price_available
            @constraint(m, cvar_tail_s[s in S, o in O], 
                m[:u_s][s, o] - m[:ζ_s][s] + 
                sum(W[t, o] * (m[:q_dch][s, t, o] - m[:q_ch][s, t, o]) * λ[t, o] for t in T) - 
                m[:stor_total_costs][s, o] >= 0
            )
        else
            @constraint(m, cvar_tail_s[s in S, o in O], 
                m[:u_s][s, o] - m[:ζ_s][s] - m[:stor_total_costs][s, o] >= 0
            )
        end
    end

    if update_prices
        return  # Exit after updating constraints without redefining other expressions or constraints
    end
end

export define_storage!
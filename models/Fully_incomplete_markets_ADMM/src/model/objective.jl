# objective.jl
# Functions for defining the objective function and related expressions in the optimization model. 
# The objective function can be either central (maximizing total welfare minus costs) or individual 
# (sum of risk-adjusted profits) based on settings in the risk-averse capacity expansion framework.

using JuMP

"""
    define_objective!(model; expected_value::Bool=false)

Defines the objective function and related expressions for the optimization model based on the 
objective type specified in settings ("central" or "individual").

# Arguments
- `model::OptimizationModel`: The optimization model containing the JuMP model, data, and settings.
- `expected_value::Bool`: If `true` and objective is "central", defines the objective as the expected value without risk aversion (default: `false`).

# Variables Defined (only for `objective == "central"` and `expected_value == false`)
- `u_total`: Loss relative to Value-at-Risk (VaR) for the total system, per scenario (if not already defined).
- `ζ_total`: VaR variable for the total system (if not already defined).

# Expressions Defined
- If `objective == "central"`:
  - `total_costs`: Total costs per scenario, summing consumer, generator, and storage costs.
  - `objective_expr`: Objective function expression, defined as:
    - If `expected_value == true`: Expected value of demand value minus total costs.
    - If `expected_value == false`: Demand value minus total costs, adjusted for risk aversion.
- If `objective == "individual"`:
  - `objective_expr`: Objective function expression, defined as the sum of individual risk measures (`ρ_g`, `ρ_s`, `ρ_d`).

# Constraints Defined (only for `objective == "central"` and `expected_value == false`)
- `cvar_tail_total`: CVaR tail constraint for the total system, ensuring the tail welfare meets the risk threshold.

# Notes
- For the "central" objective with `expected_value == false`, `u_total` and `ζ_total` are introduced as decision variables to model system-wide risk aversion, but only if they are not already defined in the model.
- If `energy_cost` is not defined (e.g., λ is not available), it is treated as 0 in the `total_costs` expression.
"""
function define_objective!(model; expected_value::Bool=false)
    m = model.model  # Extract the JuMP model from the mod object
    settings = model.setup  # Extract settings from the mod object
    data = model.data  # Extract data from the mod object

    # Extract sets from data dictionary
    G = data["sets"]["G"]
    S = data["sets"]["S"]
    O = data["sets"]["O"]

    # Extract data arrays and additional parameters
    P = data["data"]["additional_params"]["P"]  # Scenario probabilities (Dict)
    δ = data["data"]["additional_params"]["δ"]  # Risk aversion coefficient
    Ψ = data["data"]["additional_params"]["Ψ"]  # CVaR parameter

    # Extract objective type from settings
    objective_type = settings["objective"]  # "central" or "individual"

    # Remove existing expressions
    for sym in [:total_costs, :objective_expr]
        maybe_remove_expression(m, sym)
    end

    # Remove existing variables and constraints (only if they exist)
    for sym in [:u_total, :ζ_total]
        if haskey(m, sym)
            delete(m, m[sym])
            unregister(m, sym)
        end
    end
    maybe_remove_constraint(m, :cvar_tail_total)

    if objective_type == "central"
        # Define Total Costs Expression (per scenario)
        @expression(m, total_costs[o in O], 
             m[:unserved_demand_cost][o]  +
            sum(m[:gen_total_costs][g, o] for g in G) +
            sum(m[:stor_total_costs][s, o] for s in S)
        )

        if !expected_value
            # Define Risk-Averse Variables (only if they don't already exist)
            if !haskey(m, :u_total)
                @variable(m, u_total[o in O] >= 0)  # Loss relative to Value-at-Risk (VaR) for the total system
            end
            if !haskey(m, :ζ_total)
                @variable(m, ζ_total)  # VaR variable for the total system
            end

            # Define CVaR Tail Constraint for the Total System
            @constraint(m, cvar_tail_total[o in O], 
                 ζ_total - (m[:demand_value][o] - total_costs[o]) <= u_total[o]
            )
            if δ==1.0
                # Define Objective Function Expression: Demand value minus total costs, adjusted for risk aversion
                @expression(m, objective_expr, sum(P[o] * (m[:demand_value][o] - total_costs[o]) for o in O)
                ) 
            elseif δ==0.0
                # Define Objective Function Expression: Demand value minus total costs, adjusted for risk aversion
                @expression(m, objective_expr, (ζ_total - (1 / Ψ) * sum(P[o] * u_total[o] for o in O))
                ) 
            else
                # Define Objective Function Expression: Demand value minus total costs, adjusted for risk aversion
                @expression(m, objective_expr, 
                    δ * sum(P[o] * (m[:demand_value][o] - total_costs[o]) for o in O) + 
                    (1 - δ) * (ζ_total - (1 / Ψ) * sum(P[o] * u_total[o] for o in O))
                )  
            end          

            #@variable(m,obj_value)  # Register the objective expression
            #@constraint(m, obj_value == objective_expr)  # Register the objective expression as a constraint
        else
            # Define Objective Function Expression: Expected value without risk aversion
            @expression(m, objective_expr, 
                sum(P[o] * (m[:demand_value][o] - total_costs[o]) for o in O)
            )
        end
    elseif objective_type == "individual"
        # Define Objective Function Expression: Sum of individual risk measures
        @expression(m, objective_expr, 
            sum(m[:ρ_g][g] for g in G) +
            sum(m[:ρ_s][s] for s in S) +
            m[:ρ_d]
        )
    end
end

export define_objective!
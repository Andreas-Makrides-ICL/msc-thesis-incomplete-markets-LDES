# balances.jl
# Functions for defining balance constraints in the optimization model. These constraints ensure 
# market balance (supply equals demand) in the risk-averse capacity expansion framework.

using JuMP

"""
    define_balances!(model; remove_first::Bool=false)

Defines the demand balance constraints for the optimization model, dynamically adjusting for 
quadratic programming (QP) or linear demand balance based on settings.

# Arguments
- `model::OptimizationModel`: The optimization model containing the JuMP model, data, and settings.
- `remove_first::Bool`: If `true`, removes existing constraints and exits (default: `false`).

# Constraints Defined
- `demand_balance`: Ensures supply (from generators and storage) matches demand, calculated as:
  - For QP (`demand_type == :QP`): Supply equals fixed plus flexible demand.
  - For LP (`demand_type == :linear`): Supply plus load shedding equals demand.

# Notes
- If `remove_first` is `true`, the function removes existing constraints and exits without redefining them.
"""
function define_balances!(model; remove::Bool=false)
    m = model.model  # Extract the JuMP model from the mod object
    settings = model.setup  # Extract settings from the mod object
    data = model.data  # Extract data from the mod object

    # Extract sets from data dictionary
    G = data["sets"]["G"]
    S = data["sets"]["S"]
    T = data["sets"]["T"]
    O = data["sets"]["O"]

    # Extract data arrays and additional parameters
    D = data["data"]["demand"]        # Demand profiles (DenseAxisArray)
    peak_demand = data["data"]["additional_params"]["peak_demand"]  # Peak demand

    # Extract settings
    demand_type = settings["demand_type"]  # QP or linear demand

    # Remove existing constraints if specified
    if remove
        maybe_remove_constraint(m, :demand_balance)
        return
    end

    # Demand Balance Constraint: Ensures supply equals demand
    if demand_type == "QP"
        # Quadratic programming demand balance: Supply = Fixed + Flexible demand
        @constraint(m, demand_balance[t in T, o in O],
            0 == sum(m[:q][g, t, o] for g in G) +
                sum(m[:q_dch][s, t, o] - m[:q_ch][s, t, o] for s in S) - 
                m[:d_fix][t, o] - m[:d_flex][t, o]
        )
    end
end

export define_balances!
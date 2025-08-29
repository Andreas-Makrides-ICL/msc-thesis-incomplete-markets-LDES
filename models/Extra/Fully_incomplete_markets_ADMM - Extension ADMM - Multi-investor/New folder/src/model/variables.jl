# variables.jl
# Functions for defining decision variables and setting capacity upper limits in the optimization 
# model for the risk-averse capacity expansion framework. These variables include generation, 
# storage, demand, and risk-related variables.

using JuMP

"""
    define_variables!(m::JuMP.Model, data::Dict, settings::Dict)

Defines all decision variables for the optimization model based on settings. These variables 
include generation outputs, storage operations, demand, investment decisions, and risk-related 
variables for modeling risk-averse behavior.

# Arguments
- `m::JuMP.Model`: The JuMP model to which variables are added.
- `data::Dict`: The data dictionary returned by `load_data`, containing sets and data arrays.
- `settings::Dict`: The settings dictionary (e.g., `default_setup`) containing model configurations.

# Variables Defined
- **ISO Variables**:
  - `q[g,t,o]`: Generation output for each generator, time, and scenario.
  - `q_ch[s,t,o]`: Storage charging for each storage unit, time, and scenario.
  - `q_dch[s,t,o]`: Storage discharging for each storage unit, time, and scenario.
  - `e[s,t,o]`: Storage energy level for each storage unit, time, and scenario.
- **Demand Variables** (based on demand type):
  - For QP demand: `d_fix[t,o]`, `d_flex[t,o]` (fixed and flexible demand components).
  - For linear demand: `l[t,o]` (unserved demand).
- **Investment Variables**:
  - `x_g[g]`: Generator capacity investment.
  - `x_P[s]`: Storage power capacity investment.
  - `x_E[s]`: Storage energy capacity investment.
- **Risk Variables**:
  - `u_g[g,o]`, `u_s[s,o]`: Loss relative to Value-at-Risk (VaR) for generators and storage.
  - `ζ_g[g]`, `ζ_s[s]`: VaR variables for generators and storage.

# Throws
- `Error`: If an unsupported demand type is specified in the settings.
"""
function define_variables!(model)


    m = model.model  # Extract the JuMP model from the mod object
    settings = model.setup  # Extract settings from the mod object
    data = model.data  # Extract data from the mod object
    # Extract sets from data dictionary

    participants = model.setup["participants"]
    tech_map = model.setup["investor_tech_map"]
    stor_map = model.setup["investor_storage_map"]

    G = data["sets"]["G"]
    S = data["sets"]["S"]
    T = data["sets"]["T"]
    O = data["sets"]["O"]

    # Extract additional parameters
    peak_demand = data["data"]["additional_params"]["peak_demand"]

    # Extract settings for variable inclusion and demand type
    demand_type = settings["demand_type"]

    # Helper function to get upper bounds from data, defaulting to Inf
    function get_bound(data, key, g)
        haskey(data["data"], key) && haskey(data["data"][key], g) ? data["data"][key][g] : Inf
    end

    # Set capacity upper limits if specified in settings
    if haskey(settings, "default_capacity_limits") && settings["default_capacity_limits"]
        set_capacity_upper_limits!(data)
    end

    # ISO Decision Variables
    @variable(m, 0 <= q[g in G, t in T, o in O])  # Generation output
    @variable(m, 0 <= q_ch[s in S, t in T, o in O])  # Storage charging
    @variable(m, 0 <= q_dch[s in S, t in T, o in O])  # Storage discharging
    @variable(m, 0 <= e[s in S, t in T, o in O])  # Storage energy level

    # Define Demand Variables Based on Demand Type
    if demand_type == "QP"
        # Quadratic programming demand: Fixed and flexible components
        @variable(m, 0 <= d_fix[t in T, o in O])
        @variable(m, 0 <= d_flex[t in T, o in O])
    elseif demand_type == "linear"
        # Linear demand: Unserved demand (load shedding)
        @variable(m, 0 <= l[t in T, o in O])
    else
        error("Unsupported demand type: $demand_type")
    end

    # Investment Variables (always included as per the simplified model)
    @variable(m, 0 <= x_g[i in participants, g in G; g in get(tech_map, i, [])] <= get_bound(data, "x_g_up_bounds", g))

    @variable(m, 0 <= x_P[i in participants, s in S; s in get(stor_map, i, [])] <= get_bound(data, "x_P_up_bounds", s))
    @variable(m, 0 <= x_E[i in participants, s in S; s in get(stor_map, i, [])] <= get_bound(data, "x_E_up_bounds", s))

    # Risk Variables (always included as per the risk-averse model)
    #@variable(m, u_g[g in G, o in O] >= 0)  # Loss relative to Value-at-Risk (VaR) for generators
    #@variable(m, ζ_g[g in G])  # VaR variable for generators
    #@variable(m, u_s[s in S, o in O] >= 0)  # Loss relative to VaR for storage units
    #@variable(m, ζ_s[s in S])  # VaR variable for storage units
    #@variable(m, ζ_d)  # VaR variable for consumers
    #@variable(m, u_d[o in O] >= 0)  # Loss relative to VaR for consumers
    @variable(m, u_s[i in participants, s in S, o in O; s in get(setup["investor_storage_map"], i, [])] >= 0)
    @variable(m, ζ_s[i in participants, s in S; s in get(setup["investor_storage_map"], i, [])])
    @variable(m, u_g[i in participants, g in G, o in O; g in get(setup["investor_tech_map"], i, [])] >= 0)
    @variable(m, ζ_g[i in participants, g in G; g in get(setup["investor_tech_map"], i, [])])
    @variable(m, ζ_multi)
    @variable(m, u_multi[o in O] >= 0)
end
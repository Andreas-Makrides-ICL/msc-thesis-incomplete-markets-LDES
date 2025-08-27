# solver_utils.jl
# Utility functions for configuring the Gurobi optimizer in the risk-averse capacity expansion framework.

using Gurobi

"""
    rename_keys(dict::Dict{String, Any}, replacements::Dict{String, String})

Renames keys in a dictionary based on a mapping of old keys to new keys.

# Arguments
- `dict::Dict{String, Any}`: The input dictionary whose keys need to be renamed.
- `replacements::Dict{String, String}`: A dictionary mapping old keys to new keys.

# Returns
- `Dict{String, Any}`: A new dictionary with renamed keys.
"""
function rename_keys(dict::Dict{String, Any}, replacements::Dict{String, String})
    return Dict((haskey(replacements, k) ? replacements[k] : k) => v for (k, v) in dict)
end

"""
    configure_gurobi(optimizer::Any; solver_options::Union{Dict{String, Any}, Nothing}=nothing)

Configures the Gurobi optimizer with default settings and optional user-provided overrides.

# Arguments
- `optimizer::Any`: The Gurobi optimizer (e.g., `Gurobi.Optimizer`).
- `solver_options::Union{Dict{String, Any}, Nothing}`: Optional dictionary of solver parameters to override defaults (default: `nothing`).

# Returns
- The configured optimizer instance with applied attributes.

# Notes
- Prints configuration status and the applied attributes for transparency.
"""
function configure_gurobi(optimizer::Any = Gurobi.Optimizer; solver_options::Union{Dict{String, Any}, Nothing}=nothing)
    println("   Configuring Gurobi optimizer...")

    # Define default Gurobi settings
    default_settings = Dict{String, Any}(
        "Presolve" => 0,        # Automatic presolve
        "AggFill" => -1,         # Automatic aggressive fill
        "PreDual" => -1,         # Automatic dualization
        "TimeLimit" => Inf,      # No time limit by default
        "MIPGap" => 1e-3,       # MIP gap tolerance
        "BarConvTol" => 1e-10,   # Barrier convergence tolerance
        "OutputFlag" => 1,       # Enable solver output
        "LPWarmStart" => 0,      # Disable warm start by default
        "BarHomogeneous" => -1   # Automatic homogeneous barrier
    )

    # Merge default settings with solver_options if provided
    attributes = solver_options === nothing ? default_settings : merge(default_settings, solver_options)

    # Return optimizer with merged attributes
    optimizer_instance = optimizer_with_attributes(optimizer, attributes...)
    println("   Gurobi/CPLEX optimizer configured with attributes: ", keys(attributes))
    return optimizer_instance
end


"""
    add_residual(model::OptimizationModel; remove=false, verbose=false)

Adds or removes the residual expression in the JuMP model within `model`.
If `remove=true`, deletes the residual expression if it exists and returns.
If `verbose=true`, prints status messages.

# Arguments
- `model::OptimizationModel`: The optimization model (expects fields `model` and `data`).
- `remove=false`: If true, removes the residual expression if it exists.
- `verbose=false`: If true, prints status messages.
"""
function add_residual!(model; remove=false, verbose=false)
    m = model.model
    data = model.data
    settings = model.setup

    T = data["sets"]["T"]
    O = data["sets"]["O"]
    S = data["sets"]["S"]
    G = data["sets"]["G"]

    if haskey(m, :residual)
        if verbose
            println("Residual expression already exists. Removing it.")
        end
        unregister(m, :residual)
        #maybe_remove_expression(m, :residual)
        if remove
            if verbose
                println("Residual expression removed. Exiting as requested.")
            end
            return
        end
    end

    if verbose
        println("Defining residual expression.")
    end

    demand_type = get(settings, "demand_type", "QP")
    if demand_type == "QP"
        @expression(m, residual[t in T, o in O],
            sum(m[:q][g, t, o] for g in G) +
            sum(m[:q_dch][s, t, o] - m[:q_ch][s, t, o] for s in S) -
            m[:d_fix][t, o] - m[:d_flex][t, o]
        )
    elseif demand_type == "linear"
        @expression(m, residual[t in T, o in O],
            sum(m[:q][g, t, o] for g in G) +
            sum(m[:q_dch][s, t, o] - m[:q_ch][s, t, o] for s in S) +
            m[:l][t, o] - data["data"]["demand"][t, o] * data["data"]["additional_params"]["peak_demand"]
        )
    else
        error("Unknown demand type: $demand_type")
    end

    if verbose
        println("Residual expression defined.")
    end
end

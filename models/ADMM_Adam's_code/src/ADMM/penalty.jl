"""
    define_and_compute_penalty!(m, d, residual, previous_values, penalty, iteration, results_history)

Defines and computes penalty terms and penalty expressions for the ADMM algorithm in a single 
function. These penalties are added to the objective function to enforce convergence.

# Arguments
- `m`: The JuMP model to define penalty expressions in.
- `d`: The `ModelData` instance containing sets (`G`, `S`, `T`, `O`), weights (`W`, `P`), and parameters (`δ`).
- `residual`: The primal residual values.
- `previous_values::Dict`: Dictionary of previous iteration values.
- `penalty::Float64`: The penalty factor for ADMM updates.
- `iteration::Int`: The current iteration number.
- `results_history`: A history of results (not used in this function but passed for potential future use).
"""
function define_and_compute_penalty!(model, iteration)

    m = model.model
    d = model.data
    settings = model.setup

    penalty = settings["penalty"]

    G = d["sets"]["G"]
    S = d["sets"]["S"]
    T = d["sets"]["T"]
    O = d["sets"]["O"]
    # Calculate the length of resources (generators + storage + demand)
    len_r = length(S) + length(G) + 1

    W = d["data"]["time_weights"]  # Time weights (DenseAxisArray)

    P = d["data"]["additional_params"]["P"]  # Scenario probabilities (Dict)

    δ = d["data"]["additional_params"]["δ"]  # Risk aversion coefficient
    
    residual = model.results[iteration][:residual]

    # Remove previous penalty expressions if they exist
    for sym in [:penalty_term_g, :penalty_term_s, :penalty_term_c, :total_penalty_term]
        maybe_remove_expression(m, sym)
    end

    # Define penalty term for generators
    @expression(m, penalty_term_g[g in G], 
        sum(W[t, o] * (P[o] * δ +  dual(m[:cvar_tail_g][g, o])) * penalty / 2 *
        (m[:q][g, t, o] - model.results[iteration][:q][g, t, o] + residual[t, o] / len_r)^2 
        for t in T, o in O)
    )

    # Define penalty term for storage (net charge/discharge)
    @expression(m, penalty_term_s[s in S], 
        sum(W[t, o] * (P[o] * δ +  dual(m[:cvar_tail_s][s, o])) * penalty / 2 *
        (m[:q_dch][s, t, o] - m[:q_ch][s, t, o] - model.results[iteration][:ch_dis][s, t, o] + residual[t, o] / len_r)^2 
        for t in T, o in O)
    )

    # Define penalty term for demand
    @expression(m, penalty_term_c, 
        sum(W[t, o] * P[o] * penalty / 2 * 
        (-m[:d_fix][t, o] - m[:d_flex][t, o] - model.results[iteration][:d][t, o] + residual[t, o] / len_r)^2 
        for t in T, o in O)
    )

    @expression(m, total_penalty_term, 
        sum(penalty_term_g[g] for g in G) + sum(penalty_term_s[s] for s in S) + penalty_term_c
    )
end
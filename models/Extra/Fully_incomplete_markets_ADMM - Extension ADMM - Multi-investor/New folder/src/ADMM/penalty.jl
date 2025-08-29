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

    participants = settings["participants"]
    tech_map = settings["investor_tech_map"]
    stor_map = settings["investor_storage_map"]

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

    q_prev      = model.results[iteration][:q]
    q_dch_prev  = model.results[iteration][:q_dch]
    q_ch_prev   = model.results[iteration][:q_ch]
    d_fix_prev  = model.results[iteration][:d_fix]
    d_flex_prev = model.results[iteration][:d_flex]

    # Extract duals from previous iteration
    μ_g = model.results[iteration][:μ_g]
    μ_s = model.results[iteration][:μ_s]
    #μ_d = model.results[iteration][:μ_d]

    # Remove previous penalty expressions if they exist
    for sym in [:penalty_term_g, :penalty_term_s, :penalty_term_c, :total_penalty_term]
        maybe_remove_expression(m, sym)
    end

    println("\nChecking penalty coefficients and duals for generators...")
    for g in G, o in O
        coeffg = P[o] * δ + μ_g[(g, o)]
        if coeffg < 0
            println("     Negative penalty coefficient for generator: g = $g, o = $o")
            println("     P[o] * δ = ", P[o] * δ)
            println("     μ_g[$g, $o] = ", μ_g[(g, o)])
            println("     Total coefficient = ", coeffg)
        end
    end


    println("\nChecking penalty coefficients and duals for storage...")
    for s in S, o in O
        coeffs = P[o] * δ + μ_s[(s, o)]
        if coeffs < 0
            println("     Negative penalty coefficient for storage: s = $s, o = $o")
            println("     P[o] * δ = ", P[o] * δ)
            println("     μ_s[$s, $o] = ", μ_s[(s, o)])
            println("     Total coefficient = ", coeffs)
        end
    end

    #println("\nChecking penalty coefficients and duals for consumer...")
    #for s in S, o in O
    #    coeffs = P[o] * δ + μ_d[o]
    #    if coeffs < 0
    #        println("     Negative penalty coefficient for consumer:  o = $o")
    #        println("     P[o] * δ = ", P[o] * δ)
    #        println("     μ_d[ $o] = ", μ_d[o])
    #        println("     Total coefficient = ", coeffs)
    #    end
    #end
   
    if δ==1.0
        # Define penalty term for generators
        @expression(m, penalty_term_g[g in G], 
            sum(W[t, o] * (max(0.0, P[o] + μ_g[(g, o)])) * penalty / 2 *
            (m[:q][g, t, o] - q_prev[g, t, o] + residual[t, o] / len_r)^2
            for t in T, o in O)
        )
        # Define penalty term for storage (net charge/discharge)
        @expression(m, penalty_term_s[s in S], 
            sum(W[t, o] * (max(0.0, P[o] + μ_s[(s, o)])) * penalty / 2 *
            (m[:q_dch][s, t, o]- m[:q_ch][s, t, o] - q_dch_prev[s, t, o] + q_ch_prev[s, t, o] + residual[t, o] / len_r)^2
            for t in T, o in O)
        ) 
                # Define penalty term for demand
        #@expression(m, penalty_term_c, 
        #    sum(W[t, o] * (max(0.0, P[o] + μ_d[o])) * penalty / 2 * 
        #    (-m[:d_fix][t, o] - m[:d_flex][t, o] + d_fix_prev[t, o] + d_flex_prev[t, o] + residual[t, o] / len_r)^2 
        #    for t in T, o in O)
        #)
    elseif δ==0.0
        # Define penalty term for generators
        @expression(m, penalty_term_g[g in G], 
            sum(W[t, o] * (max(0.0, μ_g[(g, o)])) * penalty / 2 *
            (m[:q][g, t, o] - q_prev[g, t, o] + residual[t, o] / len_r)^2
            for t in T, o in O)
        )
        # Define penalty term for storage (net charge/discharge)
        @expression(m, penalty_term_s[s in S], 
            sum(W[t, o] * (max(0.0, μ_s[(s, o)])) * penalty / 2 *
            (m[:q_dch][s, t, o]- m[:q_ch][s, t, o] - q_dch_prev[s, t, o] + q_ch_prev[s, t, o] + residual[t, o] / len_r)^2
            for t in T, o in O)
        )
                # Define penalty term for demand
        #@expression(m, penalty_term_c, 
        #    sum(W[t, o] * (max(0.0, μ_d[o])) * penalty / 2 * 
        #    (-m[:d_fix][t, o] - m[:d_flex][t, o] + d_fix_prev[t, o] + d_flex_prev[t, o] + residual[t, o] / len_r)^2 
        #    for t in T, o in O)
        #)
    else
        # Define penalty term for generators
        @expression(m, penalty_term_g[g in G], 
            sum(W[t, o] * (max(0.0, P[o] * δ + μ_g[(g, o)])) * penalty / 2 *
            (m[:q][g, t, o] - q_prev[g, t, o] + residual[t, o] / len_r)^2
            for t in T, o in O)
        )
        # Define penalty term for storage (net charge/discharge)
        @expression(m, penalty_term_s[s in S], 
            sum(W[t, o] * (max(0.0, P[o] * δ + μ_s[(s, o)])) * penalty / 2 *
            (m[:q_dch][s, t, o]- m[:q_ch][s, t, o] - q_dch_prev[s, t, o] + q_ch_prev[s, t, o] + residual[t, o] / len_r)^2
            for t in T, o in O)
        )
        # Define penalty term for demand
        #@expression(m, penalty_term_c, 
        #    sum(W[t, o] * (max(0.0, P[o] * δ + μ_d[o])) * penalty / 2 * 
        #    (-m[:d_fix][t, o] - m[:d_flex][t, o] + d_fix_prev[t, o] + d_flex_prev[t, o] + residual[t, o] / len_r)^2 
        #    for t in T, o in O)
        #)
    end
    # Define penalty term for demand
    @expression(m, penalty_term_c, 
        sum(W[t, o] * P[o] * penalty / 2 * 
        (-m[:d_fix][t, o] - m[:d_flex][t, o] + d_fix_prev[t, o] + d_flex_prev[t, o] + residual[t, o] / len_r)^2 
        for t in T, o in O)
    )    

    @expression(m, total_penalty_term, 
        sum(penalty_term_g[g] for g in G) + sum(penalty_term_s[s] for s in S) + penalty_term_c
    )

    
end
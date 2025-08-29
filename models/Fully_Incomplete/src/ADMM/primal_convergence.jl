function calculate_primal_convergence(m, iteration)

    d = m.data
    G = d["sets"]["G"]
    S = d["sets"]["S"]
    T = d["sets"]["T"]
    O = d["sets"]["O"]
    W = d["data"]["time_weights"]  # Time weights (DenseAxisArray)
    P = d["data"]["additional_params"]["P"]  # Scenario probabilities (Dict

    residual = m.results[iteration][:residual]
    
    s = 0.0
    for t in T, o in O
        r = residual[t, o]
        s += W[t, o] * P[o] * r^2
    end

    primal_convergence = sqrt(s)  # Q_primal

    # Store primal convergence in the results
    m.results[iteration][:primal_convergence] = primal_convergence
    return primal_convergence
end
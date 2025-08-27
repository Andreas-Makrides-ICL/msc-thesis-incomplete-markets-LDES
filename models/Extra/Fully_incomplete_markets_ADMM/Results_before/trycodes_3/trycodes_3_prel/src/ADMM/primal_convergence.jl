function calculate_primal_convergence(m, iteration)

    residual = m.results[iteration][:residual]
    primal_convergence = norm(residual, 2)

    # Store primal convergence in the results
    m.results[iteration][:primal_convergence] = primal_convergence
    return primal_convergence
end
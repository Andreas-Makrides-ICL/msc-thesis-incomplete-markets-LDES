"""
    check_convergence(primal_convergence, dual_convergence; tolerance=1e-4)

Checks if the convergence criteria are met for the ADMM algorithm by comparing primal and dual 
residual norms against a tolerance threshold.

# Arguments
- `primal_convergence::Float64`: The primal residual norm.
- `dual_convergence::Float64`: The dual residual norm.
- `tolerance::Float64`: The convergence tolerance threshold (default: 1e-4).

# Returns
- `Bool`: True if both primal and dual convergence criteria are met, False otherwise.
"""
function check_convergence(m, iter, tolerance)

    results = m.results[iter]
    primal_convergence = results[:primal_convergence]
    dual_convergence = results[:dual_convergence]

    converged = (primal_convergence < tolerance) && (dual_convergence < tolerance)
    return converged
end

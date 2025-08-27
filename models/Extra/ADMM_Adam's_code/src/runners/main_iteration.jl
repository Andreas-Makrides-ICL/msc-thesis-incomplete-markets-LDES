"""
    run_benchmark_risk_neutral(results, settings, overrides)

Run a benchmark optimization model with risk-neutral settings.

# Arguments
- `results::Dict`: A dictionary to store the benchmark results.
- `settings::Dict`: A dictionary containing the settings for the benchmark.
- `overrides::Dict`: A dictionary containing override parameters for the model.

# Description
This function initializes a `ModelData` object with the given overrides, builds an optimization model with a risk-neutral objective, and solves it. The results, including prices and capacity values, are extracted and stored in the `results` dictionary.

# Example
"""
function run_benchmark_risk_neutral(results, settings, overrides)
    d = ModelData(overrides=overrides)
    m = OptimizationModel(d; model_type=:risk_neutral)
    build_model!(m)
    @objective(m.model, Min, m.model[:expected_costs_expr] - m.model[:demand_value])
    optimize!(m.model)
    prices = extract_dual_values!(m)
    results.benchmark_results[:prices] = prices
    results.benchmark_results[:cap_P], results.benchmark_results[:cap_E] = extract_solution!(m)
end

"""
    run_zero_iteration(results, settings, overrides)

Run the zero iteration of the optimization model with the given results, settings, and overrides.

# Arguments
- `results::Dict`: A dictionary containing the benchmark results, including prices.
- `settings::Dict`: A dictionary containing the settings for the iteration.
- `overrides::Dict`: A dictionary containing the override parameters for the model.

# Returns
- `m::OptimizationModel`: The optimized model after running the zero iteration.

# Description
"""
function run_zero_iteration(results, settings, overrides)
    d = ModelData(overrides=overrides)
    prices = results.benchmark_results[:prices]
    override_param!(d, :λ, prices)
    m = OptimizationModel(d; model_type=:risk_averse)
    build_model!(m)
    @objective(m.model, Max, sum(m.model[:ρ_g][g] for g in d.G) + sum(m.model[:ρ_s][s] for s in d.S) + m.model[:demand_value] - m.model[:energy_cost])
    optimize!(m.model)
    return m
end


"""
    iterative_optimization!(opt_model::OptimizationModel; max_iterations=10000, penalty=1.1, results)

Performs an **iterative optimization loop**, updating penalties and tracking convergence.

# Arguments:
- `opt_model::OptimizationModel`: The optimization model instance.
- `max_iterations::Int`: Maximum number of iterations (default: 10,000).
- `penalty::Float64`: Penalty factor for convergence adjustments (default: 1.1).
- `results::ResultsHistory`: Struct to store iteration results.

# Returns:
- `ResultsHistory`: Struct storing **primal residuals, dual residuals, λ values, and objective values**.
"""
function iterative_optimization!(opt_model::OptimizationModel; max_iterations=10000, penalty=1.1, convergence_tolerance = 0.1, results)
    m, d = opt_model.model, opt_model.data

    # Initialize previous iteration values
    previous_values = initialize_previous_values(m)

    # Print table header
    gen_headers = [string(g) for g in d.G]  # Generate generator headers from d.G
    stor_headers = [string(s) for s in d.S]  # Generate storage headers from d.S
    print_table_header(6, CONV_WIDTH, COL_WIDTH, TIME_COL_WIDTH, gen_headers, stor_headers)

    total_start_time = time()
    for i in 1:max_iterations
        iter_start_time = time()
        # Print header every 50th iteration
        if i % 50 == 0
            print_table_header(6, CONV_WIDTH, COL_WIDTH, TIME_COL_WIDTH, gen_headers, stor_headers)
        end
        # Compute residuals and convergence metrics
        residual = value.(m[:residual])
        len_r = length(d.S) + length(d.G) + 1
        dual_convergence = compute_dual_convergence(m, d, i, residual, penalty, previous_values)
        
        # calculate primal convergence 
        primal_convergence = norm(residual, 2)

        # Store history
        push!(results.primal_convergence, primal_convergence)
        push!(results.dual_convergence, dual_convergence)
        push!(results.residual, residual)

        # Extract and store investment decisions
        cap_P, cap_E = extract_solution!(opt_model)
        push!(results.investments_P, cap_P)
        push!(results.investments_E, cap_E)

        # Update λ values dynamically
        update_lambda_values(d, residual, penalty);
        push!(results.lambda_values, deepcopy(d.λ))

        # Store previous iteration values
        update_previous_values!(m, previous_values)

        # Compute penalty term and define penalty expression
        define_and_compute_penalty!(m, d, residual, previous_values, penalty, i, results)

        # Update model expressions
        update_model_expressions!(opt_model)

        # Define and optimize the objective function
        define_and_optimize_objective!(m, d)

        # Store objective value
        push!(results.objective_values, objective_value(m))

        # Calculate iteration time and total time
        iter_time = time() - iter_start_time
        total_time = time() - total_start_time

        # Print iteration results
        gen_values = [cap_P[g] for g in d.G]  # Use actual generator values
        stor_values = [(cap_P[s], cap_E[s]) for s in d.S]  # Use actual storage values
        print_iteration(i, primal_convergence, dual_convergence, gen_values, stor_values, 6, CONV_WIDTH, COL_WIDTH, TIME_COL_WIDTH, iter_time, total_time)

        # Early stopping criterion
        if check_convergence(primal_convergence, dual_convergence, tolerance=convergence_tolerance)
            println("Convergence reached at iteration: ", i)
            break
        end
    end
    #return results
end

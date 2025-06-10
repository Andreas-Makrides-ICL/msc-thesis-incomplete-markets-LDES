using DataFrames, CSV, Statistics, JuMP, Gurobi, LinearAlgebra, Random, Dates, Printf, Plots, MathOptInterface, CPLEX

include("src/_init_.jl");

"""
    run_ADMM(data, setup)

Runs the ADMM optimization workflow on the provided data and setup.
"""
function run_ADMM(data, setup)
    # ============================
    # Create Base Optimization Model
    # ============================
    # Initialize the optimization model
    m = OptimizationModel(data, setup = setup)
    # Set solver attribute to suppress output
    set_attribute(m.model, "CPX_PARAM_SCRIND", false) #here controls the print of the output of the solver, true prints solver progress

    #set_optimizer_attribute(m.model, "OutputFlag", 1)
    #set_optimizer_attribute(m.model, "LogFile", "gurobi_log1.txt")
    # Define variables and create the base model
    define_variables!(m)
    create_base_model!(m)

    # ============================
    # Solve Base Optimization Model
    # ============================
    # Define the objective (expected value) and add constraints
    define_objective!(m, expected_value = false)
    define_balances!(m)
    add_residual!(m)

    # Solve the base model
    @objective(m.model, Max, m.model[:objective_expr])
    solution_pars = solve_and_check_optimality!(m.model)
    # Extract and store results
    base_results = extract_base_results(m)
    op_results = extract_op!(m)
    m.results["base"] = Dict(
        "base_results" => base_results,
        "op_results" => op_results
    )
    # ============================
    # Initialize prices
    # ============================
    data["data"]["additional_params"]["λ"] = base_results["price"]

    # Recreate model with updated prices and remove balances
    create_base_model!(m, update_prices = true)

    # ============================
    # Prepare model for ADMM and run iteration 0
    # ============================
    
    # Switch to individual objective and resolve
    define_balances!(m, remove = true)
    m.setup["objective"] = "individual"
    define_objective!(m)
    @objective(m.model, Max, m.model[:objective_expr])
    solution_pars = solve_and_check_optimality!(m.model)

    # ============================
    #  Initialize ADMM iteration and run
    # ============================
    # Set up ADMM iteration parameters
    total_start_time = time()
    tolerance = sqrt((length(m.data["sets"]["S"]) + length(m.data["sets"]["G"]) + 1) *
                     length(m.data["sets"]["T"]) * length(m.data["sets"]["O"])) * m.setup["tolerance"]

    # Main ADMM loop
    for iter in 1:m.setup["max_iterations"]
        # Print table header every 10 iterations or at the first iteration
        if iter % 10 == 0 || iter == 1
            print_table_header(m)
        end
        # Extract results and compute convergence metrics
        # Save the results of the current iteration for analysis
        extract_iteration_results!(m, iter)
        
        # Calculate the primal convergence metrics for the current iteration
        calculate_primal_convergence(m, iter)
        
        # If not the first iteration, calculate the dual convergence metrics
        if iter > 1
            calculate_dual_convergence(m, iter)
        end

        # Compute the penalty term based on the current iteration results
        define_and_compute_penalty!(m, iter)
        
        # Update the price values based on the penalty and iteration results
        update_price_values!(m, iter)

        # Rebuild the optimization model with updated prices and objective
        create_base_model!(m, update_prices = true)
        
        # Define the new objective function for the updated model
        define_objective!(m)
        
        # Add the penalty term to the objective expression
        add_to_expression!(m.model[:objective_expr], -m.model[:total_penalty_term])
        
        # Set the updated objective function in the model
        @objective(m.model, Max, m.model[:objective_expr])
        
        # Solve the updated model and check for optimality
        solution_pars = solve_and_check_optimality!(m.model)
        
        # Store the solution status for the current iteration
        m.results[iter][:solution_status] = solution_pars

        # Print a summary of the current iteration, including timing information
        total_time = time() - total_start_time
        print_iteration(m, iter, total_time)

        # Check convergence
        if iter > 1
            converged = check_convergence(m, iter, tolerance)
            if converged
                println("Convergence criteria met at iteration $iter")
                m.results["final"] = m.results[iter]
                break
            end
        end
    end

    return m
end

# Example usage: load data and run ADMM
setup = copy(default_setup)

# ADMM parameter 
setup["max_iterations"] = 10000
setup["penalty"] = 1.1
setup["tolerance"] = 0.01

setup["δ"] = 0.8   # Risk aversion coefficient - > 1 means risk neutral for validation of ADMM
setup["Ψ"] = 0.5

data = load_data(setup, user_sets = Dict("O" => [1,2,3], "T" => 1:150));
m = run_ADMM(data, setup);


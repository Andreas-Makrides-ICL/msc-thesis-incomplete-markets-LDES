using DataFrames, CSV, Statistics, JuMP, Gurobi, LinearAlgebra, Random, Dates, Printf, Plots, MathOptInterface, CPLEX, RiskMeasures

include("src/_init_.jl");

"""
    run_ADMM(data, setup, solver)

Runs the ADMM optimization workflow on the provided data and setup.
"""
function run_ADMM(data, setup, solver, delta)
    # ============================
    # Create Base Optimization Model
    # ============================
    # Initialize the optimization model
    m = OptimizationModel(data, setup = setup, solver=solver)
    # Set solver attribute to suppress output
    if solver == "CPLEX"
        set_attribute(m.model, "CPX_PARAM_SCRIND", 1)  # CPLEX: print progress
        set_optimizer_attribute(m, "CPX_PARAM_THREADS", 10)
        #set_optimizer_attribute(m.model, "CPX_PARAM_SCAIND", 1)  # Enable scaling: 0 for equilibrium scaling (default), 1 for aggressive scaling
    elseif solver == "Gurobi"
        set_optimizer_attribute(m.model, "OutputFlag", 1)      # print Gurobi output
        set_optimizer_attribute(m.model, "QCPDual", 1)         # allow duals for QCPs
        #set_optimizer_attribute(m.model, "NonConvex", 2)       # allow nonconvex QPs/QCPs
        #set_optimizer_attribute(m.model, "LogFile", "gurobi_log1.txt")
    else
        error("Unsupported solver. Choose 'CPLEX' or 'Gurobi'.")
    end
    define_variables!(m)
    create_base_model!(m)

    # ============================
    # Solve Base Optimization Model
    # ============================
    # Define the objective (expected value) and add constraints
    define_objective!(m, expected_value = true) #false for risk aversion on central planner
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
        println("\n1st print for iteration = ", iter)
        #print CVaR and ζ_d,ζ_g,ζ_s to ensure correct operation
        println("CVaR variable ζ_g exists? ", haskey(m.model, :ζ_g))
        println("CVaR variable ζ_s exists? ", haskey(m.model, :ζ_s))
        println("CVaR variable ζ_d exists? ", haskey(m.model, :ζ_d))
        println("CVaR constraint for generator exists? ", haskey(m.model, :cvar_tail_g))
        println("CVaR constraint for storage exists? ", haskey(m.model, :cvar_tail_s))
        println("CVaR constraint for consumer exists? ", haskey(m.model, :cvar_tail_d))

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
        #add_to_expression!(m.model[:objective_expr], -m.model[:total_penalty_term])
        
        # Set the updated objective function in the model
        @objective(m.model, Max, m.model[:objective_expr]-m.model[:total_penalty_term])
        
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

        # Final iteration reached without convergence
        if iter == m.setup["max_iterations"] && !converged
            println("Convergence criteria not met at iteration $iter")
            m.results["final"] = m.results[iter]
        end

        println("\n2nd print for iteration = ", iter)

    end

    if termination_status(m.model) == MOI.OPTIMAL
        # Then call the function with output redirected
        filename = "nogasprice05_25_agent_objective_breakdown_delta_$(round(delta, digits=2)).txt"
        str = "nogasprice05_25"
        open(filename, "w") do io
            redirect_stdout(io) do
                print_agents_objective_breakdown(m, str)
            end
        end
    else
        println("Model did not solve to optimality — skipping breakdown.")
    end

    return m
end



# Extract capacity safely
function safeget(cap_dict, sym, key)
    sym ∈ keys(cap_dict) && key ∈ axes(cap_dict[sym], 1) ? cap_dict[sym][key] : 0.0
end

function safe_div(num, denom)
    return denom ≈ 0.0 ? 0.0 : num / denom
end

# Example usage: load data and run central planner
setup = copy(default_setup)
solver = "CPLEX"
# Central planner parameter 
setup["max_iterations"] = 10000
setup["penalty"] = 1.1
setup["tolerance"] = 0.0001
setup["use_hierarchical_clustering"] = true

"""
setup["δ"] = 0.8   # Risk aversion coefficient - > 1 means risk neutral for validation of ADMM
setup["Ψ"] = 0.5

data = load_data(setup, user_sets = Dict("O" => 1:3, "T" => 1:150));
m = run_ADMM(data, setup);
"""


results = []
for delta in [0.50,0.25]#[1, 0.8, 0.6, 0.4, 0.2, 0.0] #[0.5] #[1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1, 0.0]
    for psi in [0.5] #[0.5, 0.2, 0.1]
        
    
        local_setup = copy(default_setup)
        local_setup["max_iterations"] = 10000
        local_setup["penalty"] = 1.1
        local_setup["tolerance"] = 0.008
        local_setup["use_hierarchical_clustering"] = true
        local_setup["factor_gas_price"] = 0
        local_setup["δ"] = delta
        local_setup["Ψ"] = psi
        solver = "Gurobi"
        #setup["δ"] = delta
        #setup["Ψ"] = psi

        data = load_data(local_setup, user_sets = Dict("O" => 1:30, "T" => 1:672));
        #data = load_data(setup, user_sets = Dict("O" => [6, 21, 33, 40, 15, 14, 31, 1, 5, 4, 13, 3, 18], "T" => 1:3600));
        m = run_ADMM(data, local_setup, solver, delta);

        price = m.data["data"]["additional_params"]["λ"]

        res = m.results["final"]
        cap = res[:capacities]
        obj = res[:of]

        push!(results, (
            delta = delta,
            psi = psi,
            objective = obj,
            Price_max = maximum(price),
            Price_min = minimum(price),
            Price_avg = mean(price),
            PV = safeget(cap, :x_g, "PV"),
            Wind_Onshore = safeget(cap, :x_g, "Wind_Onshore"),
            Wind_Offshore = safeget(cap, :x_g, "Wind_Offshore"),
            Gas = safeget(cap, :x_g, "Gas"),
            Nuclear = safeget(cap, :x_g, "Nuclear"),
            BESS_P = safeget(cap, :x_P, "BESS"),
            BESS_E = safeget(cap, :x_E, "BESS"),
            Duration = safe_div(safeget(cap, :x_E, "BESS"), safeget(cap, :x_P, "BESS")),
            LDES_PHS_P = safeget(cap, :x_P, "LDES_PHS"),
            LDES_PHS_E = safeget(cap, :x_E, "LDES_PHS"),
            Duration_PHS = safe_div(safeget(cap, :x_E, "LDES_PHS"), safeget(cap, :x_P, "LDES_PHS"))
        ))

    end
end

df = DataFrame(results)
display(df)
#change the name of the file accordingly
CSV.write("nogasprice05_25_ADMM_risk_aversion_results_O30_T672_new_final_unserved_fix_flex_gaspricescaled_cinvEldescheap_conwind.csv", df)
#Print the model for inspection
#print_model_structure_symbolic(m.model)

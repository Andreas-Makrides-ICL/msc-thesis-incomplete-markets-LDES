using DataFrames, CSV, Statistics, JuMP, Gurobi, LinearAlgebra, Random, Dates, Printf, Plots, MathOptInterface, Distributions, RiskMeasures, CPLEX

include("src/_init_.jl");


function run_ADMM(data, setup, solver, delta)
    # ============================
    # Create Base Optimization Model
    # ============================
    # Initialize the optimization model
    m = OptimizationModel(data, setup = setup, solver=solver)
    # Set solver attribute to suppress output
    if solver == "CPLEX"
        set_attribute(m.model, "CPX_PARAM_SCRIND", 1)  # CPLEX: print progress
        set_optimizer_attribute(m.model, "CPX_PARAM_THREADS", 6)
        set_optimizer_attribute(m.model, "CPX_PARAM_SCAIND", 1)  # Enable scaling: 0 for equilibrium scaling (default), 1 for aggressive scaling
        set_optimizer_attribute(m.model, "CPXPARAM_Barrier_QCPConvergeTol",1e-10 )
    elseif solver == "Gurobi"
        set_optimizer_attribute(m.model, "OutputFlag", 1)      # print Gurobi output
        set_optimizer_attribute(m.model, "QCPDual", 1)         # allow duals for QCPs
        #set_optimizer_attribute(m.model, "NonConvex", 2)       # allow nonconvex QPs/QCPs
        #set_optimizer_attribute(m.model, "LogFile", "gurobi_log1.txt")
        set_optimizer_attribute(m.model, "Threads", 6)
    else
        error("Unsupported solver. Choose 'CPLEX' or 'Gurobi'.")
    end
    m.setup["objective"] = "individual"

    # Load CSV with prices
    price_df = CSV.read("C:\\Users\\user\\Desktop\\msc-thesis-incomplete-markets-LDES\\models\\my_hpc_project_riskaverseCON_CPLEX\\fix_prices.csv", DataFrame)
    # Create Dict{(T, O) => price}
    prices = Dict((row.T, row.O) => row.price_2 for row in eachrow(price_df))
    # Inject into model data
    data["data"]["additional_params"]["λ"] = prices

    define_variables!(m)
    create_base_model!(m)
    define_balances!(m, remove = true)
    # ============================
    # Solve Base Optimization Model
    # ============================
    # Define the objective (expected value) and add constraints
    define_objective!(m) #false for risk aversion on central planner

   
    # Solve the base model
    @objective(m.model, Max, m.model[:objective_expr])

    solution_pars = solve_and_check_optimality!(m.model)

    op_results = extract_op!(m)
    m.results["base"] = Dict(
        "op_results" => op_results
    )


    if termination_status(m.model) == MOI.OPTIMAL
        print_agents_objective_breakdown(m)
    else
        println("Model did not solve to optimality — skipping breakdown.")

    end

    return m
end

setup = copy(default_setup)
solver = "CPLEX"
# Central planner parameter 
setup["max_iterations"] = 10000
setup["penalty"] = 1.1
setup["tolerance"] = 0.0001
setup["use_hierarchical_clustering"] = true

for delta in [1,0.50]#[1, 0.8, 0.6, 0.4, 0.2, 0.0] #[0.5] #[1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1, 0.0]
    for psi in [0.5] #[0.5, 0.2, 0.1]
        
    
        local_setup = copy(default_setup)
        local_setup["use_hierarchical_clustering"] = false
        local_setup["δ"] = delta
        local_setup["Ψ"] = psi
        solver = "CPLEX"
        #setup["δ"] = delta
        #setup["Ψ"] = psi

        data = load_data(local_setup, user_sets = Dict("O" => 1:3, "T" => 1:100));
        #data = load_data(setup, user_sets = Dict("O" => [6, 21, 33, 40, 15, 14, 31, 1, 5, 4, 13, 3, 18], "T" => 1:3600));
        m = run_ADMM(data, local_setup, solver, delta);
        
    end
end


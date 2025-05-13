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

    start_time = time()

    # Solve the base model
    @objective(m.model, Max, m.model[:objective_expr])

    println("CVaR variable ζ_total exists? ", haskey(m.model, :ζ_total))
    println("CVaR constraint exists? ", haskey(m.model, :cvar_tail_total))


    solution_pars = solve_and_check_optimality!(m.model)
    
    println("ζ_total = ", value(m.model[:ζ_total]))
    println("u_total = ", [round(value(m.model[:u_total][o]), digits=4) for o in m.data["sets"]["O"]])


    solve_time = time() - start_time

    # Extract and store results
    base_results = extract_base_results(m)
    op_results = extract_op!(m)
    m.results["base"] = Dict(
        "base_results" => base_results,
        "op_results" => op_results
    )

    # Print summary
    print_central_summary(m, solve_time)
    print_objective_breakdown(m)
    return m
end

# Example usage: load data and run ADMM
setup = copy(default_setup)

# ADMM parameter 
setup["max_iterations"] = 1
setup["penalty"] = 1.1
setup["tolerance"] = 0.01

setup["objective"] = "central"

results = []
for delta in [1.0, 0.8, 0.5, 0.2, 0.0]
    for psi in [0.5, 0.2, 0.1]
        setup["δ"] = delta
        setup["Ψ"] = psi

        data = load_data(setup, user_sets = Dict("O" => [1,2,3], "T" => 1:150));
        m = run_ADMM(data, setup);

        res = m.results["base"]["base_results"]
        cap = res["capacities"]
        obj = objective_value(m.model)
        ζ = value(m.model[:ζ_total])
        u = [value(m.model[:u_total][o]) for o in m.data["sets"]["O"]]

        # Extract capacity safely
        function safeget(cap_dict, sym, key)
            sym ∈ keys(cap_dict) && key ∈ axes(cap_dict[sym], 1) ? cap_dict[sym][key] : 0.0
        end

        push!(results, (
            δ = delta,
            Ψ = psi,
            objective = obj,
            ζ_total = ζ,
            max_u = maximum(u),
            PV = safeget(cap, :x_g, "PV"),
            Wind = safeget(cap, :x_g, "Wind"),
            Gas = safeget(cap, :x_g, "Gas"),
            Battery_P = safeget(cap, :x_P, "Battery"),
            Battery_E = safeget(cap, :x_E, "Battery"),
        ))

    end
end

using DataFrames
df = DataFrame(results)
display(df)
CSV.write("risk_aversion_results.csv", df)

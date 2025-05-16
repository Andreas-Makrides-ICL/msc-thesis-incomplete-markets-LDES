using DataFrames, CSV, Statistics, JuMP, Gurobi, LinearAlgebra, Random, Dates, Printf, Plots, MathOptInterface, CPLEX

include("src/_init_.jl");

"""
    run_central_planner(data, setup)

Runs the central planner optimization workflow on the provided data and setup.
"""
function run_central_planner(data, setup)
    # ============================
    # Create Base Optimization Model
    # ============================
    # Initialize the optimization model
    m = OptimizationModel(data, setup = setup)
    # Set solver attribute to suppress output
    set_attribute(m.model, "CPX_PARAM_SCRIND", true) #here controls the print of the output of the solver, true prints solver progress
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

    #Start time of the model\
    start_time = time()

    # Solve the base model
    @objective(m.model, Max, m.model[:objective_expr])

    #print CVaR and ζ_total to ensure correct operation
    println("CVaR variable ζ_total exists? ", haskey(m.model, :ζ_total))
    println("CVaR constraint exists? ", haskey(m.model, :cvar_tail_total))

    solution_pars = solve_and_check_optimality!(m.model)

    #Prints the the values of ζ_total and u_total
    println("ζ_total = ", value(m.model[:ζ_total]))
    println("u_total = ", [round(value(m.model[:u_total][o]), digits=4) for o in m.data["sets"]["O"]])

    #Captures the run duration of the model
    solve_time = time() - start_time

    # Extract and store results
    base_results = extract_base_results(m)
    op_results = extract_op!(m)
    m.results["base"] = Dict(
        "base_results" => base_results,
        "op_results" => op_results
    )

    # ============================
    # Print summary of the central planner code
    print_central_summary(m, solve_time)

    print_objective_breakdown(m)
    print_individual_risks(m)

    return m
end

# Extract capacity safely
function safeget(cap_dict, sym, key)
    sym ∈ keys(cap_dict) && key ∈ axes(cap_dict[sym], 1) ? cap_dict[sym][key] : 0.0
end

# Example usage: load data and run central planner
setup = copy(default_setup)

# Central planner parameter 
setup["max_iterations"] = 10000
setup["penalty"] = 1.1
setup["tolerance"] = 0.01
setup["objective"] = "central"

"""
setup["δ"] = 1   # Risk aversion coefficient - > 1 means risk neutral for validation of ADMM
setup["Ψ"] = 0.5

data = load_data(setup, user_sets = Dict("O" => 1:3, "T" => 1:150));
m = run_central_planner(data, setup);

"""

results = []
for delta in [1.0, 0.8, 0.5, 0.2, 0.0]
    for psi in [0.5] #[0.5, 0.2, 0.1]
        setup["δ"] = delta
        setup["Ψ"] = psi

        data = load_data(setup, user_sets = Dict("O" => 1:10, "T" => 1:720));
        m = run_central_planner(data, setup);

        res = m.results["base"]["base_results"]
        cap = res["capacities"]
        obj = objective_value(m.model)
        ζ = value(m.model[:ζ_total])
        u = [value(m.model[:u_total][o]) for o in m.data["sets"]["O"]]
        
        # Extract CVaR tail duals and risk weights
        duals, risk_weights = extract_risk_adjusted_weights(m)

        # Sort tail scenarios by descending weight
        sorted_tail = sort(collect(duals), by = x -> -x[2])
        # Format as (scenario, raw dual) for display
        tail_scenarios = [(o, round(d, digits=8)) for (o, d) in sorted_tail if d > 1e-8]

        push!(results, (
            δ = delta,
            Ψ = psi,
            objective = obj,
            ζ_total = ζ,
            max_u = maximum(u),
            max_dual = !isempty(duals) ? maximum(values(duals)) : 0.0,
            tail_scenarios = tail_scenarios,
            PV = safeget(cap, :x_g, "PV"),
            Wind = safeget(cap, :x_g, "Wind"),
            Gas = safeget(cap, :x_g, "Gas"),
            Battery_P = safeget(cap, :x_P, "Battery"),
            Battery_E = safeget(cap, :x_E, "Battery"),
            LDES_P = safeget(cap, :x_P, "LDES"),
            LDES_E = safeget(cap, :x_E, "LDES")
        ))

    end
end

df = DataFrame(results)
display(df)
#change the name of the file accordingly
#CSV.write("risk_aversion_results_O4T720_synthetic_data.csv", df)

#Print the model for inspection
#print_model_structure_symbolic(m.model)



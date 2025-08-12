using DataFrames, CSV, Statistics, JuMP, Gurobi, LinearAlgebra, Random, Dates, Printf, Plots, MathOptInterface, CPLEX, Distributions, RiskMeasures

include("src/_init_.jl");

"""
    run_central_planner(data, setup, solver)

Runs the central planner optimization workflow on the provided data and setup.
"""
function run_central_planner(data, setup, solver)
    # ============================
    # Create Base Optimization Model
    # ============================
    # Initialize the optimization model
    m = OptimizationModel(data, setup = setup, solver=solver)
    
    # Set solver attribute to suppress output
    if solver == "CPLEX"
        set_attribute(m.model, "CPX_PARAM_SCRIND", 0)  # CPLEX: print progress
    elseif solver == "Gurobi"
        set_optimizer_attribute(m.model, "OutputFlag", 1)      # print Gurobi output
        set_optimizer_attribute(m.model, "QCPDual", 1)         # allow duals for QCPs
        #set_optimizer_attribute(m.model, "NonConvex", 2)       # allow nonconvex QPs/QCPs
        #set_optimizer_attribute(m.model, "LogFile", "gurobi_log1.txt")
    else
        error("Unsupported solver. Choose 'CPLEX' or 'Gurobi'.")
    end
    # Define variables and create the base model
    define_variables!(m)
    create_base_model!(m)

    # ============================
    # Solve Optimization Model
    # ============================
    # Define the objective (expected value) and add constraints
    define_objective!(m, expected_value = false)
    println("CVaR constraint present? ", haskey(m.model, :cvar_tail_total))
    println("ζ_total present? ", haskey(m.model, :ζ_total))
    println("u_total present? ", haskey(m.model, :u_total))

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

   
    delta = data["data"]["additional_params"]["δ"]
    psi = data["data"]["additional_params"]["Ψ"]
    if termination_status(m.model) == MOI.OPTIMAL
        # Then call the function with output redirected
        filename = "centralplanner_delta_$(round(delta, digits=2))_$(round(psi, digits=2)).txt"
        open(filename, "w") do io
            redirect_stdout(io) do
                print_central_summary(m, solve_time)
                print_objective_breakdown(m)
                recalculate_and_print_individual_risks(m)
                extract_unserved_demand(m)
                extract_risk_adjusted_weights(m)
                #rhs and lhs on cvar tail constraint
                inspect_cvar_constraint_tightness(m)
                residual_print(m)
                print_model_structure_symbolic(m.model)
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
setup["tolerance"] = 0.01
setup["objective"] = "central"
setup["use_hierarchical_clustering"] = true

"""
setup["δ"] = 1   # Risk aversion coefficient - > 1 means risk neutral for validation of ADMM
setup["Ψ"] = 0.5

data = load_data(setup, user_sets = Dict("O" => 1:3, "T" => 1:150));
m = run_central_planner(data, setup, solver);

"""

results = []
for delta in [1.00,0.75,0.50,0.25] #[1, 0.8,0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.0] #[0.5] #[1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1, 0.0]
    for psi in [0.5] #[0.5, 0.2, 0.1]
        setup["δ"] = delta
        setup["Ψ"] = psi
        set1_lowest = [21, 6, 10, 9, 14, 17, 15, 3, 18, 28, 2, 25, 20, 5, 19]
        set2_middle = [19, 12, 7, 11, 23, 8, 30, 24, 1, 26, 29, 13, 4, 22, 27]
        set3_manual = [6, 10, 14, 17, 18, 20, 12, 11, 7, 23, 8, 24, 30, 1, 26, 29, 13, 4]
        set4_stable_core = [ 24, 25, 26, 27, 28, 29, 30]

        data = load_data(setup, user_sets = Dict("O" => set2_middle, "T" => 1:672));
        #data = load_data(setup, user_sets = Dict("O" => [6, 21, 33, 40, 15, 14, 31, 1, 5, 4, 13, 3, 18], "T" => 1:3600));
        m = run_central_planner(data, setup, solver);

        res = m.results["base"]["base_results"]
        price = m.results["base"]["base_results"]["price"]
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
            delta = delta,
            psi = psi,
            objective = obj,
            z_total = ζ,
            max_u = maximum(u),
            max_dual = !isempty(duals) ? maximum(values(duals)) : 0.0,
            tail_scenarios = tail_scenarios,
            Price_max = maximum(price),
            Price_min = minimum(price),
            PV = safeget(cap, :x_g, "PV"),
            Wind_Onshore = safeget(cap, :x_g, "Wind_Onshore"),
            Wind_Offshore = safeget(cap, :x_g, "Wind_Offshore"),
            Gas = safeget(cap, :x_g, "Gas"),
            Nuclear = safeget(cap, :x_g, "Nuclear"),
            BESS_P = safeget(cap, :x_P, "BESS"),
            BESS_E = safeget(cap, :x_E, "BESS"),
            Duration = safe_div(safeget(cap, :x_E, "BESS"), safeget(cap, :x_P, "BESS")),
            H2_P = safeget(cap, :x_P, "H2"),
            H2_E = safeget(cap, :x_E, "H2"),
            Duration_H2 = safe_div(safeget(cap, :x_E, "H2"), safeget(cap, :x_P, "H2"))
        ))
    end
end

df = DataFrame(results)
display(df)
#change the name of the file accordingly
CSV.write("risk_aversion_results_O30_T672_new_final_unserved_fix_flex_gaspricescaled_cinvEldescheap_conwind.csv", df)
#Print the model for inspection
#print_model_structure_symbolic(m.model)


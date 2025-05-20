# Define column width for uniform spacing
global const COL_WIDTH = 12  # Reduced column width
global const CONV_WIDTH = 14  # Wider column width for convergence
global const TIME_COL_WIDTH = 10  # Smaller width for time

# Function to format value
function format_value(value::Float64)
    return @sprintf("%8.2f", value)
end

# Function to format time properly (ensuring "s" sticks right after)
function format_time(value::Float64)
    return @sprintf("%.2fs", value)  # Ensures "s" is attached
end

# Function to print an iteration row
function print_iteration(model, iter, total_time)

    iter_width = 6
    conv_width = CONV_WIDTH
    data_width = COL_WIDTH
    time_width = TIME_COL_WIDTH

    m = model.model
    d = model.data
    results = model.results[iter]

    print(rpad(iter, iter_width))  # Left-align iteration number
    print(rpad(@sprintf("%.2f", results[:primal_convergence]), conv_width))  # Right-align primal convergence
    if iter > 1
        dual_conv = results[:dual_convergence]
    else
        dual_conv = 0.0  # Initialize dual convergence for the first iteration
    end
    print(rpad(@sprintf("%.2f", dual_conv), conv_width))  # Right-align dual convergence

    # Print generator values with correct width
    G = d["sets"]["G"]
    
    for g in G
        print(rpad(@sprintf("%.2f", results[:capacities][:x_g][g]), data_width))
    end

    # Print storage values (Power & Energy) properly aligned
    S = d["sets"]["S"]
    for s in S
        print(rpad(@sprintf("%.2f", results[:capacities][:x_P][s]), data_width))
        print(rpad(@sprintf("%.2f", results[:capacities][:x_E][s]), data_width))
    end

    # Print time columns
    print(rpad(@sprintf("%.2fs", results[:solution_status][:solve_time]), time_width))
    print(rpad(@sprintf("%.2fs", total_time), time_width))

    println()  # Move to next line
end

function print_table_header(model)
    iter_width = 6
    conv_width = CONV_WIDTH
    data_width = COL_WIDTH
    time_width = TIME_COL_WIDTH

    m = model.model
    d = model.data
    gen_headers = [string(g) for g in d["sets"]["G"]]  # Generate generator headers from d.G
    stor_headers = [string(s) for s in d["sets"]["S"]]  # Generate storage headers from d.S
    # Prepare the total table width
    total_width = iter_width + 2 * conv_width + (length(gen_headers) * data_width) + (length(stor_headers) * 2 * data_width) + (2 * time_width)

    # Print top separator
    println(repeat("-", total_width))

    # Print column headers dynamically
    print(rpad("Iter", iter_width))  # Iteration column
    print(rpad("Primal Conv.", conv_width))  # Primal Convergence column
    print(rpad("Dual Conv.", conv_width))  # Dual Convergence column

    for g in gen_headers
        print(rpad(g, data_width))  # Print generator headers
    end
    for s in stor_headers
        print(rpad(s * " Pwr.", data_width) * rpad(s * " En.", data_width))  # Print storage power & energy headers
    end
    print(rpad("Time", time_width))
    print(rpad("Total Time", time_width))

    println()  # Move to the next line

    # Print bottom separator
    println(repeat("-", total_width))
end

function print_central_summary(model, solve_time)
    # Column widths
    iter_width = 6
    conv_width = CONV_WIDTH
    data_width = COL_WIDTH
    time_width = TIME_COL_WIDTH

    m = model.model
    d = model.data
    base = model.results["base"]["base_results"]

    capacities = base["capacities"]
    obj = objective_value(m)

    println()
    println("------------------------------------------------------------------------------------------------------------------")
    println(rpad("Iter", iter_width),
        rpad("Primal Conv.", conv_width),
        rpad("Dual Conv.", conv_width),
        rpad("PV", data_width),
        rpad("Wind", data_width),
        rpad("Gas", data_width),
        rpad("Battery Pwr.", data_width),
        rpad("Battery En.", data_width),
        rpad("Time", time_width),
        rpad("Total Time", time_width))
    println("------------------------------------------------------------------------------------------------------------------")


    print(rpad("CENT", iter_width))
    print(rpad(" - ", conv_width))
    print(rpad(" - ", conv_width))

    # Generator capacities
    for g in d["sets"]["G"]
        val = g ∈ axes(capacities[:x_g], 1) ? capacities[:x_g][g] : 0.0
        print(rpad(@sprintf("%.2f", val), data_width))
    end

    # Storage power and energy
    for s in d["sets"]["S"]
        val_P = s ∈ axes(capacities[:x_P], 1) ? capacities[:x_P][s] : 0.0
        val_E = s ∈ axes(capacities[:x_E], 1) ? capacities[:x_E][s] : 0.0
        print(rpad(@sprintf("%.2f", val_P), data_width))
        print(rpad(@sprintf("%.2f", val_E), data_width))
    end

    print(rpad(@sprintf("%.2fs", solve_time), time_width))
    print(rpad(@sprintf("%.2fs", solve_time), time_width))  # repeated to mimic Total Time
    println()

    total_cap = sum(values(capacities[:x_g])) + sum(values(capacities[:x_P])) + sum(values(capacities[:x_E]))
    println("\nTotal Installed Capacity: ", round(total_cap, digits=2), " MW")

end

function print_objective_breakdown(m::OptimizationModel)
    # Extract sets and parameters
    O = m.data["sets"]["O"]
    P = m.data["data"]["additional_params"]["P"]
    δ = m.data["data"]["additional_params"]["δ"]
    Ψ = m.data["data"]["additional_params"]["Ψ"]
    jm = m.model

    # Compute expected welfare minus cost
    expected_term = sum(P[o] * (value(jm[:demand_value][o]) - value(jm[:total_costs][o])) for o in O)

    # Compute CVaR term: ζ - (1 / Ψ) * ∑ P[o] * u[o]
    ζ = value(jm[:ζ_total])
    u = [value(jm[:u_total][o]) for o in O]
    cvar_term = ζ - (1 / Ψ) * sum(P[o] * u[o] for o in O)

    # Final blended objective
    objective = δ * expected_term + (1 - δ) * cvar_term

    # Print nicely
    println("\n===== Risk-Averse Objective Breakdown =====")
    println("Expected Term (δ * E[W - C]):     ", round(δ * expected_term, digits=2))
    println("CVaR Term ((1 - δ) * CVaR):       ", round((1 - δ) * cvar_term, digits=2))
    println("  ↳ ζ_total:                       ", round(ζ, digits=2))
    println("  ↳ u_total[o]:                    ", [round(u[o], digits=4) for o in eachindex(O)])
    println("Full Objective Value:             ", round(objective, digits=2))
    println("===========================================")
end

using JuMP

# print the structure of the model (objective + constraints) in central planner risk averse case
function print_model_structure_symbolic(m::JuMP.Model)
    println("========== MODEL STRUCTURE ==========")

    # --- Objective ---
    println("\n--- Objective Function ---")
    println("Sense: ", JuMP.objective_sense(m))
    println("Expression Type: ", typeof(JuMP.objective_function(m)))
    println("Symbolic Expression:")
    println(JuMP.objective_function(m))

    # --- Constraints ---
    println("\n--- Constraints ---")

    for (func_type, set_type) in JuMP.list_of_constraint_types(m)
        cons = JuMP.all_constraints(m, func_type, set_type)
        if !isempty(cons)
            name = JuMP.name(cons[1])
            println("\n• Constraint Type: ", set_type)
            println("  Symbolic Name: ", isempty(name) ? "(unnamed)" : split(name, "::")[1])
            println("  Sample Expression:")
            println("    ", JuMP.constraint_object(cons[1]).func, " ∈ ", JuMP.constraint_object(cons[1]).set)
        end
    end

    println("\n=====================================")
end

#extract and print the individual agent risk measures (generator, storage, consumer)
function print_individual_risks(model::OptimizationModel)
    m = model.model
    G = model.data["sets"]["G"]
    S = model.data["sets"]["S"]

    # Extract individual risk-adjusted profit/welfare values
    risk_g = Dict(g => value(m[:ρ_g][g]) for g in G if haskey(m, :ρ_g))
    risk_s = Dict(s => value(m[:ρ_s][s]) for s in S if haskey(m, :ρ_s))
    risk_d = haskey(m, :ρ_d) ? value(m[:ρ_d]) : missing

    println("\n===== Individual Risk Measures (ρ) =====")
    println("Generators:")
    for (g, ρ) in sort(collect(risk_g), by = x -> x[1])
        println("  $g → $(round(ρ, digits=2))")
    end
    println("Storage:")
    for (s, ρ) in sort(collect(risk_s), by = x -> x[1])
        println("  $s → $(round(ρ, digits=2))")
    end
    println("Consumer:")
    println("  ρ_d → $(risk_d isa Missing ? "n/a" : round(risk_d, digits=2))")
    println("========================================\n")

    return Dict(
        "generators" => risk_g,
        "storage" => risk_s,
        "consumer" => risk_d
    )
end

function inspect_cvar_constraint_tightness(model)
    m = model.model
    data = model.data
    O = data["sets"]["O"]

    println("===== CVaR Constraint Tightness per Scenario =====")
    for o in O
        welfare = value(m[:demand_value][o]) - value(m[:total_costs][o])
        lhs = value(m[:ζ_total]) - (value(m[:demand_value][o]) - value(m[:total_costs][o]))
        rhs = value(m[:u_total][o])
        gap = lhs - rhs
        println("Scenario $o: welfare = $(round(welfare, digits=4)), LHS = $(round(lhs, digits=4)), RHS = $(round(rhs, digits=4)), Gap = $(round(gap, digits=4))")
    end
    println("==================================================\n")
end





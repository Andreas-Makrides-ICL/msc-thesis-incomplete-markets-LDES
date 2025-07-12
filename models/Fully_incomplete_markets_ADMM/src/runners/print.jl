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

    print_table_header(model)

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

    total_cap = sum(values(results[:capacities][:x_g])) + sum(values(results[:capacities][:x_P]))
    total_energy = sum(values(results[:capacities][:x_E]))
    println("\nTotal Installed Capacity: ", round(total_cap, digits=2), " MW")
    println("\nTotal Installed Energy: ", round(total_energy, digits=2), " MWh")
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
        rpad("Wind Onshore", data_width),
        rpad("Wind Offshore", data_width),
        rpad("Gas", data_width),
        rpad("Nuclear", data_width),
        rpad("BESS Pwr.", data_width),
        rpad("BESS En.", data_width),
        rpad("Duration", data_width),
        rpad("LDES_PHS Pwr.", data_width),
        rpad("LDES_PHS En.", data_width),
        rpad("Dur_PHS", data_width),
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
        Dur = val_E/val_P
        print(rpad(@sprintf("%.2f", val_P), data_width))
        print(rpad(@sprintf("%.2f", val_E), data_width))
        print(rpad(@sprintf("%.2f", Dur), data_width))
    end

    print(rpad(@sprintf("%.2fs", solve_time), time_width))
    print(rpad(@sprintf("%.2fs", solve_time), time_width))  # repeated to mimic Total Time
    println()

    total_cap = sum(values(capacities[:x_g])) + sum(values(capacities[:x_P]))
    total_energy = sum(values(capacities[:x_E]))
    println("\nTotal Installed Capacity: ", round(total_cap, digits=2), " MW")
    println("\nTotal Installed Energy: ", round(total_energy, digits=2), " MWh")

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
    #cvar_term = ζ - (1 / Ψ) * sum(P[o] * u[o] for o in O)
    cvar_term = ζ - (1 / Ψ) * sum(P[o] * u[i] for (i, o) in enumerate(O))


    # Final blended objective
    objective = δ * expected_term + (1 - δ) * cvar_term

    # Print nicely
    println("\n===== Risk-Averse Objective Breakdown =====")
    println("Expected Term (δ * E[W - C]):     ", round(δ * expected_term, digits=2))
    println("CVaR Term ((1 - δ) * CVaR):       ", round((1 - δ) * cvar_term, digits=2))
    println("  ↳ ζ_total:                       ", round(ζ, digits=2))
    println("  ↳ u_total[o]:                    ", Dict(o => round(u[i], digits=4) for (i, o) in enumerate(O)))
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
function recalculate_and_print_individual_risks(model::OptimizationModel)
    m = model.model
    data = model.data

    G = data["sets"]["G"]
    S = data["sets"]["S"]
    T = data["sets"]["T"]
    O = data["sets"]["O"]

    W = data["data"]["time_weights"]
    P = data["data"]["additional_params"]["P"]
    δ = data["data"]["additional_params"]["δ"]
    Ψ = data["data"]["additional_params"]["Ψ"]
    B = data["data"]["additional_params"]["B"]
    flexible_demand = data["data"]["additional_params"]["flexible_demand"]

    # === Extract solved λ from dual of balance constraint
    λ = Dict((t, o) => dual(m[:demand_balance][t, o])/(P[o] * W[t,o]) for t in T, o in O)

    # === Generators
    risk_g = Dict{String, Float64}()
    for g in G
        π = Dict(o => sum(W[t, o] * value(m[:q][g, t, o]) * abs(λ[(t, o)]) for t in T) for o in O)
        expected = sum(P[o] * (π[o] - value(m[:gen_total_costs][g, o])) for o in O)
        cvar = value(m[:ζ_g][g]) - (1 / Ψ) * sum(P[o] * value(m[:u_g][g, o]) for o in O)
        risk_g[g] = δ * expected + (1 - δ) * cvar
    end

    # === Storage
    risk_s = Dict{String, Float64}()
    for s in S
        π = Dict(o =>
            sum(W[t, o] * (value(m[:q_dch][s, t, o]) - value(m[:q_ch][s, t, o])) * abs(λ[(t, o)]) for t in T)
            for o in O)
        expected = sum(P[o] * (π[o] - value(m[:stor_total_costs][s, o])) for o in O)
        cvar = value(m[:ζ_s][s]) - (1 / Ψ) * sum(P[o] * value(m[:u_s][s, o]) for o in O)
        risk_s[s] = δ * expected + (1 - δ) * cvar
    end

    # === Consumer
    π = Dict{Int, Float64}()
    val = Dict{Int, Float64}()
    for o in O
        π[o] = sum(W[t, o] * abs(λ[(t, o)]) * (value(m[:d_fix][t, o]) + value(m[:d_flex][t, o])) for t in T)
        val[o] = sum(W[t, o] * B * (
            value(m[:d_fix][t, o]) + value(m[:d_flex][t, o]) -
            value(m[:d_flex][t, o])^2 / (2 * flexible_demand)) for t in T)
    end
    expected = sum(P[o] * (val[o] - π[o]) for o in O)
    cvar = value(m[:ζ_d]) - (1 / Ψ) * sum(P[o] * value(m[:u_d][o]) for o in O)
    risk_d = δ * expected + (1 - δ) * cvar

    # === Print
    println("\n===== Recalculated Individual Risk Measures with Dual Prices =====")
    println("Generators:")
    for (g, ρ) in sort(collect(risk_g), by = x -> x[1])
        println("  $g → ", round(ρ, digits=2))
    end
    println("Storage:")
    for (s, ρ) in sort(collect(risk_s), by = x -> x[1])
        println("  $s → ", round(ρ, digits=2))
    end
    println("Consumer:")
    println("  ρ_d → ", round(risk_d, digits=2))
    println("==============================================================\n")

    return Dict("generators" => risk_g, "storage" => risk_s, "consumer" => risk_d)
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




function compute_expected_consumer_welfare(m)
    O = m.data["sets"]["O"]
    P = m.data["data"]["additional_params"]["P"]
    
    price_available = haskey(m.model, :energy_cost)
    ec_expr = m.model[:energy_cost]

    expected = sum(P[o] * (
        value(m.model[:demand_value][o]) -
        (price_available ?
            (isa(ec_expr, JuMP.Containers.DenseAxisArray) ? value(ec_expr[o]) : value(ec_expr))
            : 0)
    ) for o in O)

    return expected
end



function print_agents_objective_breakdown(m)
    @assert has_values(m.model) "Attempted to print results from a model with no solution."

    println("Checking solver status before result extraction...")
    println("Status: ", termination_status(m.model))
    println("Primal status: ", primal_status(m.model))

    println("\n=== Agent Objective Breakdown ===")

    G, S, O, T = m.data["sets"]["G"], m.data["sets"]["S"], m.data["sets"]["O"], m.data["sets"]["T"]
    W = m.data["data"]["time_weights"]
    P = m.data["data"]["additional_params"]["P"]
    δ = m.data["data"]["additional_params"]["δ"]
    Ψ = m.data["data"]["additional_params"]["Ψ"]
    λ = m.data["data"]["additional_params"]["λ"]

    for o in O
        avg_price = sum(W[t, o] * λ[t, o] for t in T) / sum(W[t, o] for t in T)
        println("Average price in scenario $o = $(round(avg_price, digits=4)) [£/MWh]")
    end
    
    println("Risk aversion (δ): $δ, CVaR confidence (Ψ): $Ψ")

    # Generators
    println("\n--- Generators ---")
    for g in G
        ζ = value(m.model[:ζ_g][g])
        u_vals = [value(m.model[:u_g][g, o]) for o in O]
        u_avg = sum(P[o] * u_vals[o] for o in O)
        ρ = value(m.model[:ρ_g][g])
        
        gen_data = m.data["data"]["generation_data"]
        gic = gen_data[g, "C_inv"] * gen_data[g, "CRF"] * value(m.model[:x_g][g])

        expected = 0.0
        for o in O
            πg = sum(W[t, o] * λ[t, o] * value(m.model[:q][g, t, o]) for t in T)
            gvc = sum(W[t, o] * gen_data[g, "C_v"] * value(m.model[:q][g, t, o]) for t in T)
            gtc = gic + gvc

            expected += P[o] * (πg - gtc)

            #check with expressions
            genrev = value(m.model[:π_g][g, o])
            generators_total_costs = value(m.model[:gen_total_costs][g, o])

            println("(Manual Calculation) For scenario $o: π_g = $(round(πg, digits=4)), TCG = $(round(gtc, digits=4))")
            println("(From model expression) For scenario $o: π_g = $(round(genrev, digits=4)), TCG = $(round(generators_total_costs, digits=4))")
        end


        cvar = ζ - (1 / Ψ) * u_avg
        expected_term = δ * expected
        cvar_term = (1 - δ) * cvar
        println("Gen $g: ζ = $(round(ζ, digits=4)), ū = $(round(u_avg, digits=4)), ρ = $(round(ρ, digits=4)), Expected = $(round(expected, digits=4)), CVaR = $(round(cvar, digits=4)), Expected Term (δ * E[W - C]) = $(round(expected_term, digits=4)), CVaR Term ((1 - δ) * CVaR) = $(round(cvar_term, digits=4))")
        
        println("  Scenario breakdown for Gen $g:")
        for o in O
            u = value(m.model[:u_g][g, o])
            d = dual(m.model[:cvar_tail_g][g, o])
            tail_flag = u > 1e-6 ? "TAIL" : ""
            println("    Scenario $o: u = $u, dual = $d $tail_flag")
        end
        
    end

    # Storage
    println("\n--- Storage ---")
    for s in S
        ζ = value(m.model[:ζ_s][s])
        u_vals = [value(m.model[:u_s][s, o]) for o in O]
        u_avg = sum(P[o] * u_vals[o] for o in O)
        ρ = value(m.model[:ρ_s][s])
    
        
        stor_data = m.data["data"]["storage_data"]
        svc = 0
        sic = stor_data[s, "C_inv_P"] * stor_data[s, "CRF"] * value(m.model[:x_P][s]) + stor_data[s, "C_inv_E"] * stor_data[s, "CRF"] * value(m.model[:x_E][s])

        expected = 0.0
        for o in O
            πs = sum(W[t, o] * λ[t, o] * (value(m.model[:q_dch][s, t, o]) - value(m.model[:q_ch][s, t, o])) for t in T)
            stc = sic + svc

            expected += P[o] * (πs - stc)
            
            #check with expressions
            storrev = value(m.model[:π_s][s, o])
            storage_total_costs = value(m.model[:stor_total_costs][s, o])
            println("(Manual Calculation) For scenario $o: π_s = $(round(πs, digits=4)), TCS = $(round(stc, digits=4))")
            println("(From model expression) For scenario $o: π_s = $(round(storrev, digits=4)), TCS = $(round(storage_total_costs, digits=4))")
        end
        
        cvar = ζ - (1 / Ψ) * u_avg
        expected_term = δ * expected
        cvar_term = (1 - δ) * cvar
        println("Storage $s: ζ = $(round(ζ, digits=4)), ū = $(round(u_avg, digits=4)), ρ = $(round(ρ, digits=4)), Expected = $(round(expected, digits=4)), CVaR = $(round(cvar, digits=4)), Expected Term (δ * E[W - C]) = $(round(expected_term, digits=4)), CVaR Term ((1 - δ) * CVaR) = $(round(cvar_term, digits=4))")
        
        println("  Scenario breakdown for Storage $s:")
        for o in O
            u = value(m.model[:u_s][s, o])
            d = dual(m.model[:cvar_tail_s][s, o])
            tail_flag = u > 1e-6 ? "TAIL" : ""
            println("    Scenario $o: u = $u, dual = $d $tail_flag")
        end

    end

    # Consumer (only one set of variables)
    println("\n--- Consumer ---")
    #ζ = value(m.model[:ζ_d])
    #u_vals = [value(m.model[:u_d][o]) for o in O]
    #u_avg = sum(P[o] * u_vals[o] for o in O)
    ρ = value(m.model[:ρ_d])
    #expected = compute_expected_consumer_welfare(m)

    demand = m.data["data"]["demand"]                  # D[t,o]
    B = m.data["data"]["additional_params"]["B"]
    peak = m.data["data"]["additional_params"]["peak_demand"]
    flex = m.setup["flexible_demand"]

    expected = 0.0
    for o in O
        
        dm = sum(W[t, o] * B * (value(m.model[:d_fix][t, o]) + value(m.model[:d_flex][t, o]) - value(m.model[:d_flex][t, o])^2 / (2 * ((flex-1) * demand[t, o] * peak))) for t in T)
        ec = sum(W[t, o] * λ[t, o] * (value(m.model[:d_fix][t, o]) + value(m.model[:d_flex][t, o])) for t in T)
            
        expected += P[o] * (dm - ec)
        println("For scenario $o: Demand value = $(round(dm, digits=4)), Energy costs = $(round(ec, digits=4))")
    end

    #cvar = ζ - (1 / Ψ) * u_avg
    #expected_term = δ * expected
    #cvar_term = (1 - δ) * cvar
    #println("Consumer: ζ = $(round(ζ, digits=4)), ū = $(round(u_avg, digits=4)), ρ = $(round(ρ, digits=4)), Expected = $(round(expected, digits=4)), CVaR = $(round(cvar, digits=4)), Expected Term (δ * E[W - C]) = $(round(expected_term, digits=4)), CVaR Term ((1 - δ) * CVaR) = $(round(cvar_term, digits=4))")
    println("Consumer: ρ = $(round(ρ, digits=4)),  Expected = $(round(expected, digits=4))")

    #println("  Scenario breakdown for Consumer:")
    #for o in O
    #    u = value(m.model[:u_d][o])
    #    #d = dual(m.model[:cvar_tail_d][o])
    #    tail_flag = u > 1e-6 ? "TAIL" : ""
    #    #println("    Scenario $o: u = $u, dual = $d $tail_flag")
    #    println("    Scenario $o: u = $u $tail_flag")
    #end

    println("=================================\n")

    println("\n--- Residual Summary (per Scenario) ---")
    residual = value.(m.model[:residual])

    manual_residual = Dict{Tuple{Any,Any}, Float64}()

    for t in T, o in O
        supply = sum(value(m.model[:q][g, t, o]) for g in G) +
                sum(value(m.model[:q_dch][s, t, o]) - value(m.model[:q_ch][s, t, o]) for s in S)

        demand = value(m.model[:d_fix][t, o]) + value(m.model[:d_flex][t, o])

        manual_residual[(t, o)] = supply - demand
    end

    println("\n--- Residual Comparison (Model vs. Manual) ---")
    for t in T, o in O
        r_model = residual[t, o]
        r_manual = manual_residual[(t, o)]
        diff = abs(r_model - r_manual)
        println("t=$t, o=$o → Model: $(round(r_model, digits=4)), Manual: $(round(r_manual, digits=4)), Diff: $(round(diff, digits=6))")
    end


    for o in O
        scenario_residuals = [residual[t, o] for t in T]
        l2_norm = norm(scenario_residuals, 2)
        max_residual = maximum(abs.(scenario_residuals))
        avg_residual = mean(abs.(scenario_residuals))
        println("Scenario $o: L2 Norm = $(round(l2_norm, digits=4)), Max = $(round(max_residual, digits=4)), Avg = $(round(avg_residual, digits=4))")
    end
    
    filename = "residuals_detailed_delta_$(round(δ, digits=2))_psi_$(round(Ψ, digits=2)).csv"
    rows = [(t, o, residual[t, o]) for t in T for o in O]
    df = DataFrame(rows, [:Time, :Scenario, :Residual])
    CSV.write(filename, df)
    println("Full residuals saved to '$filename'")

    

    println("\n--- Demand Value and Total Costs (per Scenario) ---")

    demand_value = value.(m.model[:demand_value])
    gen_total_costs = value.(m.model[:gen_total_costs])
    stor_total_costs = value.(m.model[:stor_total_costs])
    unserved_demand = value.(m.model[:unserved_demand_cost])

    for o in O
        dv = demand_value[o]
        tc = sum(gen_total_costs[g, o] for g in G) + sum(stor_total_costs[s, o] for s in S) + unserved_demand[o]
        net = dv - tc
        println("Scenario $o: Demand Value = $(round(dv, digits=4)) [£], Total Cost = $tc [£], Net Welfare = $(round(net, digits=4)) [£]")
    end
    # Compute net welfare per scenario
    net_values = [value(m.model[:demand_value][o]) -
                sum(value(m.model[:gen_total_costs][g, o]) for g in G) -
                sum(value(m.model[:stor_total_costs][s, o]) for s in S) - unserved_demand[o]
                for o in O]

    # Extract scenario probabilities
    p = [P[o] for o in O]

    # Compute CVaR at level Ψ
    cvar_val = CVaR(net_values, p, Ψ)
    cvar_value=cvar_val.value
    println("\n=== CVaR using RiskMeasures.jl ===")
    println("CVaR at Ψ = $Ψ: $cvar_val")

    exp_term = sum(P[o] * (demand_value[o] - sum(gen_total_costs[g, o] for g in G) - sum(stor_total_costs[s, o] for s in S) - unserved_demand[o]) for o in O)

    social_welfare_incomplete = δ * exp_term  + (1 - δ) * cvar_value  

    println("\n===== Social Welfare Fully Incomplete Markets =====")
    println("Expected Term:     ", exp_term)
    println("CVaR Term:       ", cvar_value)
    println("Social Welfare Value (ADMM):             ", social_welfare_incomplete)
    println("===========================================")

end

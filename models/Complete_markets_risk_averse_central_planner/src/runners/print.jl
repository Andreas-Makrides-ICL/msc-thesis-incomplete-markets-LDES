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

    println("Checking solver status before result extraction...")
    println("Status: ", termination_status(m))
    println("Primal status: ", primal_status(m))

    G, S, O, T = model.data["sets"]["G"], model.data["sets"]["S"], model.data["sets"]["O"], model.data["sets"]["T"]
    W = model.data["data"]["time_weights"]
    P = model.data["data"]["additional_params"]["P"]
    δ = model.data["data"]["additional_params"]["δ"]
    Ψ = model.data["data"]["additional_params"]["Ψ"]

    price = model.results["base"]["base_results"]["price"]

    filename = "prices_delta_$(round(δ, digits=2)).csv"
    rows = [(t, o, price[t, o]) for t in T for o in O]
    df = DataFrame(rows, [:Time, :Scenario, :price_model])
    CSV.write(filename, df)


    println("Risk aversion (δ): $δ, CVaR confidence (Ψ): $Ψ")

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
        rpad("H2 Pwr.", data_width),
        rpad("H2 En.", data_width),
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

    for o in O
        avg_price = sum(W[t, o] * price[t, o] for t in T) / sum(W[t, o] for t in T)
        println("Average price in scenario $o = $(round(avg_price, digits=4)) [£/MWh]") 
    end
    
    # Step 1: Compute average price per scenario
    avg_price_per_scenario = Dict{Int, Float64}()

    for o in O
        num = sum(W[t, o] * price[t, o] for t in T)
        den = sum(W[t, o] for t in T)
        avg_price_per_scenario[o] = num / den
    end

    # Step 2: Compute total average price
    total_avg_price_caseB = sum(P[o] * avg_price_per_scenario[o] for o in O)
    println("Total Average price Case B = $(round(total_avg_price_caseB, digits=4)) [£/MWh]")


    # Assume T and O are the sets of time steps and scenarios
    numerator = sum(P[o] * W[t, o] * price[t, o] for o in O, t in T)
    denominator = sum(P[o] * W[t, o] for o in O, t in T)
    total_avg_price_caseA = numerator / denominator
    println("Total Average price Case A = $(round(total_avg_price_caseA, digits=4)) [£/MWh]")

end

function print_objective_breakdown(m::OptimizationModel)
    # Extract sets and parameters
    O = m.data["sets"]["O"]
    G = m.data["sets"]["G"]
    S = m.data["sets"]["S"]
    T = m.data["sets"]["T"]
    W = m.data["data"]["time_weights"]
    P = m.data["data"]["additional_params"]["P"]
    δ = m.data["data"]["additional_params"]["δ"]
    Ψ = m.data["data"]["additional_params"]["Ψ"]
    gas_price = m.data["data"]["additional_params"]["gas_price"]
    factor_gas_price = m.data["data"]["additional_params"]["factor_gas_price"]
    jm = m.model

    # Compute expected welfare minus cost
    expected_term = sum(P[o] * (value(jm[:demand_value][o]) - value(jm[:total_costs][o])) for o in O)

    # Compute CVaR term: ζ - (1 / Ψ) * ∑ P[o] * u[o]
    ζ = value(jm[:ζ_total])
    u = [value(jm[:u_total][o]) for o in O]
    #cvar_term = ζ - (1 / Ψ) * sum(P[o] * u[o] for o in O)
    cvar_term = ζ - (1 / Ψ) * sum(P[o] * u[i] for (i, o) in enumerate(O))

    co2term = gas_price * 0.3294 * value(jm[:co2]) * factor_gas_price

    objective = value(jm[:objective_expr])

    # Print nicely
    println("\n===== Risk-Averse Objective Breakdown from model =====")
    println("Expected Term (E[W - C]):     ", expected_term)
    println("CVaR Term :       ", cvar_term)
    println("CO2 price :       ", co2term)
    println("Expected Term (δ * E[W - C]):     ", round(δ * expected_term, digits=4))
    println("CVaR Term ((1 - δ) * CVaR) :       ", round((1 - δ) * cvar_term, digits=4))
    println("  ↳ ζ_total:                       ", round(ζ, digits=2))
    println("  ↳ u_total[o]:                    ", Dict(o => round(u[i], digits=4) for (i, o) in enumerate(O)))
    println("Full Objective Value:             ", objective)
    println("===========================================")

    demand = m.data["data"]["demand"]                  # D[t,o]
    B = m.data["data"]["additional_params"]["B"]
    peak = m.data["data"]["additional_params"]["peak_demand"]
    flex = m.setup["flexible_demand"]

    gen_data = m.data["data"]["generation_data"]
    gic = sum((gen_data[g, "C_inv"] * gen_data[g, "CRF"] + gen_data[g, "FOMg"] )* value(m.model[:x_g][g]) for g in G)

    stor_data = m.data["data"]["storage_data"]
    svc = 0
    sic = sum((stor_data[s, "C_inv_P"] * stor_data[s, "CRF"] + stor_data[s, "FOMs"] )* value(m.model[:x_P][s]) + stor_data[s, "C_inv_E"] * stor_data[s, "CRF"] * value(m.model[:x_E][s]) for s in S)

    expected = 0.0
    for o in O
        
        dm = sum(W[t, o] * B * (value(m.model[:d_fix][t, o]) + value(m.model[:d_flex][t, o]) - value(m.model[:d_flex][t, o])^2 / (2 * ((flex-1) * demand[t, o] * peak))) for t in T)
        gvc = sum(sum(W[t, o] * gen_data[g, "C_v"] * value(m.model[:q][g, t, o]) for t in T) for g in G)
        tc = gic + gvc + svc + sic
            
        expected += P[o] * (dm - tc)
        println("For scenario $o: Demand value = $(round(dm, digits=4)), Total costs = $(round(tc, digits=4))")
    end

    k = sum(P[o] * W[t,o] * value(m.model[:q]["Gas", t, o]) for t in T, o in O)
    co2 = gas_price * 0.3294 * factor_gas_price * k

    # Final blended objective
    obj = δ * expected + (1 - δ) * cvar_term

    # Print nicely
    println("\n===== Risk-Averse Objective Breakdown Manual Calculation =====")
    println("Expected Term (E[W - C]):     ", expected)
    println("CVaR Term :       ", cvar_term)
    println("CO2 Price :       ", co2)
    println("Expected Term (δ * E[W - C]):     ", round(δ * expected, digits=4))
    println("CVaR Term ((1 - δ) * CVaR) :       ", round((1 - δ) * cvar_term, digits=4))
    println("  ↳ ζ_total:                       ", round(ζ, digits=2))
    println("  ↳ u_total[o]:                    ", Dict(o => round(u[i], digits=4) for (i, o) in enumerate(O)))
    println("Full Objective Value:             ", obj)
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
    D = data["data"]["demand"] 
    peak_demand = data["data"]["additional_params"]["peak_demand"]
    # === Extract solved λ from dual of balance constraint
    dual_vals = Dict(o => dual(m[:cvar_tail_total][o]) for o in O)

    λ = model.results["base"]["base_results"]["price"]
    #λ = Dict((t, o) => dual(m[:demand_balance][t, o])/(W[t,o]*(P[o]*δ + dual_vals[o])) for t in T, o in O)

    gen_data = data["data"]["generation_data"]
    

    # === Generators
    ex_g = Dict{String, Float64}()
    cvar_g = Dict{String, Float64}()
    risk_g = Dict{String, Float64}()
    for g in G
        π = Dict(o => sum(W[t, o] * value(m[:q][g, t, o]) * λ[t, o] for t in T) for o in O)
        gic = (gen_data[g, "C_inv"] * gen_data[g, "CRF"] + gen_data[g, "FOMg"])* value(m[:x_g][g])
        gvc = Dict(o => sum(W[t, o] * gen_data[g, "C_v"] * value(m[:q][g, t, o]) for t in T) for o in O)
        expected = sum(P[o] * (π[o] - gic - gvc[o]) for o in O)
        netrevg=sum(P[o] * (π[o] - gvc[o]) for o in O)
        cvar = value(m[:ζ_g][g]) - (1 / Ψ) * sum(P[o] * value(m[:u_g][g, o]) for o in O)
        ex_g[g] = expected
        cvar_g[g] = cvar
        risk_g[g] = δ * expected + (1 - δ) * cvar
        println("Generator $(g) : expected = $(expected), cvar = $(cvar), ρ=$(δ * expected + (1 - δ) * cvar), net_revenues=$(netrevg)")
    end

    stor_data = data["data"]["storage_data"]
    svc = 0
    
    # === Storage
    ex_s = Dict{String, Float64}()
    cvar_s = Dict{String, Float64}()
    risk_s = Dict{String, Float64}()
    for s in S
        π = Dict(o =>
            sum(W[t, o] * (value(m[:q_dch][s, t, o]) - value(m[:q_ch][s, t, o])) * λ[t, o] for t in T)
            for o in O)
        sic = (stor_data[s, "C_inv_P"] * stor_data[s, "CRF"] + stor_data[s, "FOMs"])* value(m[:x_P][s]) + stor_data[s, "C_inv_E"] * stor_data[s, "CRF"] * value(m[:x_E][s])
        netrevs = sum(P[o] * (π[o]) for o in O)
        expected = sum(P[o] * (π[o] - svc - sic) for o in O)
        cvar = value(m[:ζ_s][s]) - (1 / Ψ) * sum(P[o] * value(m[:u_s][s, o]) for o in O)
        ex_s[s] = expected
        cvar_s[s] = cvar
        risk_s[s] = δ * expected + (1 - δ) * cvar
        println("Storage $(s) : expected = $(expected), cvar = $(cvar), ρ=$(δ * expected + (1 - δ) * cvar), net_revenues=$(netrevs)")
    end

    # === Consumer
    π = Dict{Int, Float64}()
    val = Dict{Int, Float64}()
    for o in O
        π[o] = sum(W[t, o] * λ[t, o] * (value(m[:d_fix][t, o]) + value(m[:d_flex][t, o])) for t in T)
        val[o] = sum(W[t, o] * B * (
            value(m[:d_fix][t, o]) + value(m[:d_flex][t, o]) -
            value(m[:d_flex][t, o])^2 / (2 * ((flexible_demand-1) * D[t, o] * peak_demand))) for t in T)
    end
    expected = sum(P[o] * (val[o] - π[o]) for o in O)
    cvar = value(m[:ζ_d]) - (1 / Ψ) * sum(P[o] * value(m[:u_d][o]) for o in O)
    risk_d = δ * expected + (1 - δ) * cvar
    println("Consumer: expected = $(expected), cvar = $(cvar), ρ=$(δ * expected + (1 - δ) * cvar)")

    return Dict("generators" => risk_g, "storage" => risk_s, "consumer" => risk_d)
end

function residual_print(m)
    G, S, O, T = m.data["sets"]["G"], m.data["sets"]["S"], m.data["sets"]["O"], m.data["sets"]["T"]
    W = m.data["data"]["time_weights"]
    P = m.data["data"]["additional_params"]["P"]
    δ = m.data["data"]["additional_params"]["δ"]
    Ψ = m.data["data"]["additional_params"]["Ψ"]


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

    

    filename = "gas_dispatch_delta_$(round(δ, digits=2)).csv"
    # Extract dispatch for all generators, time steps, and scenarios
    rows = [(t, o, g, value(m.model[:q][g, t, o])) for g in G for t in T for o in O]
    # Create a DataFrame
    df = DataFrame(rows, [:Time, :Scenario, :Generator, :Dispatch])
    # Save to CSV
    CSV.write(filename, df)
    println("Gas dispatch saved to '$filename'")




    peak_demand = m.data["data"]["additional_params"]["peak_demand"]
    D = m.data["data"]["demand"]

    filename = "served_demand_delta_$(round(δ, digits=2)).csv"
    # Extract dispatch for all generators, time steps, and scenarios
    rows = [(t, o, peak_demand*D[t,o], value(m.model[:d_fix][t, o]), value(m.model[:d_flex][t, o])) for t in T for o in O]
    # Create a DataFrame
    df = DataFrame(rows, [:Time, :Scenario, :Dto, :dfix_to, :dflex_to])
    # Save to CSV
    CSV.write(filename, df)
    println("Gas dispatch saved to '$filename'")


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





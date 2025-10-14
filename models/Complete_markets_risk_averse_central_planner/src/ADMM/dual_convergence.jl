
function calculate_dual_convergence(model, iteration)

    m = model.model
    d = model.data
    settings = model.setup
    i = iteration

    penalty = settings["penalty"]
    G = d["sets"]["G"]
    S = d["sets"]["S"]
    T = d["sets"]["T"]
    O = d["sets"]["O"]

    len_r = length(S) + length(G) + 1 # Total number of agent types (generators + storage + consumers)
    dual_residual_g = Containers.DenseAxisArray{Float64}(undef, G, T, O);
    dual_residual_s = Containers.DenseAxisArray{Float64}(undef, S, T, O);
    dual_residual_c = Containers.DenseAxisArray{Float64}(undef, T, O);

    for g in d["sets"]["G"]
        #This measures how much the generator’s output has changed, adjusted for its share of the global residual
        dual_residual_g[g,:,:] = penalty * ( model.results[i][:q][g,:,:] .- model.results[i-1][:q][g,:,:] .- model.results[i][:residual] / len_r .+ model.results[i-1][:residual] / len_r)
    end
    for s in d["sets"]["S"]
        dual_residual_s[s,:,:] = penalty * ( model.results[i][:ch_dis][s,:,:] .- model.results[i-1][:ch_dis][s,:,:] .- model.results[i][:residual] / len_r .+ model.results[i-1][:residual] / len_r)
    end
    
    #Tracks change in total demand decisions.
    dual_residual_c = penalty * ( model.results[i][:d] .- model.results[i-1][:d] .- model.results[i][:residual] / len_r .+ model.results[i-1][:residual] / len_r)
    
    residual_total = norm(dual_residual_g, 2) + norm(dual_residual_s, 2) + norm(dual_residual_c, 2)

    # Store dual convergence in the results
    model.results[i][:dual_convergence] = residual_total
    
    return residual_total

end
"""
    struct IterationResults

Stores **iteration-wise optimization results** separately from the `OptimizationModel`.

# Fields:
- `iterations::Int`: **Number of completed iterations**
- `residual_history::Vector{Dict{Tuple{String, String}, Float64}}`: **History of residual values**
- `primal_convergence::Vector{Float64}`: **Primal convergence per iteration**
- `dual_convergence::Vector{Float64}`: **Dual convergence per iteration**
- `λ_history::Vector{Dict{Tuple{String, String}, Float64}}`: **Lambda (price) updates per iteration**
- `generator_capacities::Vector{Dict{String, Float64}}`: **Generator capacities per iteration**
- `storage_power_capacities::Vector{Dict{String, Float64}}`: **Storage power capacities per iteration**
- `storage_energy_capacities::Vector{Dict{String, Float64}}`: **Storage energy capacities per iteration**
- `objective_values::Vector{Float64}`: **Objective function values over iterations**
- `optimization_times::Vector{Float64}`: **Time taken per iteration**
"""
mutable struct IterationResults
    iterations::Int
    residual_history::Vector{Dict{Tuple{String, String}, Float64}}
    primal_convergence::Vector{Float64}
    dual_convergence::Vector{Float64}
    λ_history::Vector{Dict{Tuple{String, String}, Float64}}
    generator_capacities::Vector{Dict{String, Float64}}
    storage_power_capacities::Vector{Dict{String, Float64}}
    storage_energy_capacities::Vector{Dict{String, Float64}}
    objective_values::Vector{Float64}
    optimization_times::Vector{Float64}

    """
        IterationResults()

    Initializes an empty `IterationResults` struct to store iterative optimization results.
    """
    function IterationResults()
        return new(
            0,                          # iterations
            [],                         # residual_history
            [],                         # primal_convergence
            [],                         # dual_convergence
            [],                         # λ_history
            [],                         # generator_capacities
            [],                         # storage_power_capacities
            [],                         # storage_energy_capacities
            [],                         # objective_values
            []                          # optimization_times
        )
    end
end

"""
    update_iteration_results!(iteration_results::IterationResults; 
                              λ_init=nothing, 
                              primal_convergence=nothing, 
                              dual_convergence=nothing, 
                              q_previous=nothing, 
                              ch_dis_previous=nothing, 
                              d_previous=nothing, 
                              residual=nothing)

Updates `IterationResults` structure **after each iteration**.

# Arguments:
- `iteration_results::IterationResults`: The results container to be updated.
- `λ_init=nothing`: Updated price multipliers.
- `primal_convergence=nothing`: Primal convergence metric.
- `dual_convergence=nothing`: Dual convergence metric.
- `q_previous=nothing`: Previous generation dispatch.
- `ch_dis_previous=nothing`: Previous charge-discharge values.
- `d_previous=nothing`: Previous demand values.
- `residual=nothing`: Residual values.

# Behavior:
- **Only updates fields that are passed** as arguments.
- **If a field is not provided**, it remains `missing`.
"""
function update_iteration_results!(iteration_results::IterationResults; 
                                   λ_init=nothing, 
                                   primal_convergence=nothing, 
                                   dual_convergence=nothing, 
                                   q_previous=nothing, 
                                   ch_dis_previous=nothing, 
                                   d_previous=nothing, 
                                   residual=nothing)

    # **Update only defined values, set missing otherwise**
    iteration_results.λ_init = isnothing(λ_init) ? missing : λ_init
    iteration_results.primal_convergence = isnothing(primal_convergence) ? missing : primal_convergence
    iteration_results.dual_convergence = isnothing(dual_convergence) ? missing : dual_convergence
    iteration_results.q_previous = isnothing(q_previous) ? missing : q_previous
    iteration_results.ch_dis_previous = isnothing(ch_dis_previous) ? missing : ch_dis_previous
    iteration_results.d_previous = isnothing(d_previous) ? missing : d_previous
    iteration_results.residual = isnothing(residual) ? missing : residual
end

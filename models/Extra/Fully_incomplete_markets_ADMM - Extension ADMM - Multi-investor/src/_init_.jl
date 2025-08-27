
include("default_setup.jl"); #changed
include("data/data.jl"); #changed
include("configure_solver.jl"); #changed
include("utils.jl"); #changed
include("model/variables.jl"); #changed
include("model/agents/consumer.jl"); #changed
include("model/agents/generator.jl"); #changed
include("model/agents/storage.jl"); #changed
include("model/model.jl"); #changed
include("model/extract_results.jl"); #changed
include("model/objective.jl"); #changed
include("model/balances.jl"); #changed
include("ADMM/residual.jl"); #changed
include("ADMM/dual_convergence.jl"); #changed
include("ADMM/primal_convergence.jl"); #changed
include("ADMM/penalty.jl"); #changed
include("ADMM/price_update.jl"); #changed
include("ADMM/check_convergence.jl"); #changed
include("runners/print.jl");

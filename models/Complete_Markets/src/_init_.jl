
include("default_setup.jl"); #check
include("data/data.jl"); #check
include("configure_solver.jl"); #check
include("utils.jl"); #check
include("model/variables.jl"); #check
include("model/agents/consumer.jl");  #check
include("model/agents/generator.jl"); #check
include("model/agents/storage.jl"); #check
include("model/model.jl"); #check
include("model/extract_results.jl");  #check
include("model/objective.jl");#check
include("model/balances.jl"); #check
include("ADMM/residual.jl"); #check
include("ADMM/dual_convergence.jl"); #check
include("ADMM/primal_convergence.jl"); #check
include("ADMM/penalty.jl"); #check
include("ADMM/price_update.jl");  #check
include("ADMM/check_convergence.jl");  #check
include("runners/print.jl"); #check

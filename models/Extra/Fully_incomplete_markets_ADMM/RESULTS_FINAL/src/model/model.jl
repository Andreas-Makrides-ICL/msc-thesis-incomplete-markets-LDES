# model.jl
# Core functionality for the optimization model in the ADMM-based risk-averse capacity expansion 
# framework. This file defines the OptimizationModel struct and methods to build and solve the 
# model using JuMP and Gurobi.

using JuMP
import Gurobi

"""
    mutable struct OptimizationModel

Encapsulates a JuMP model for solving capacity expansion problems in a risk-averse framework.

# Fields
- `model::Model`: The underlying JuMP model.
- `data::Dict`: The data dictionary returned by `load_data`, containing sets and data arrays.
- `setup::Dict`: The settings dictionary (e.g., `default_setup`) containing model configurations.
- `results::Dict{Symbol, Any}`: Stores the results after solving the model.
- `solver_settings::Dict{String, Any}`: Solver-specific settings (e.g., for Gurobi).
"""
mutable struct OptimizationModel
    model::Model                       # JuMP model
    data::Dict                         # Data dictionary
    setup::Dict                        # Model configurations
    results::Dict{Any, Any}         # Results
    solver_settings::Any # Solver settings

    """
        OptimizationModel(data::Dict; setup::Dict=Dict())

    Initializes a JuMP model with default solver settings and model configuration.

    # Arguments
    - `data::Dict`: The data dictionary returned by `load_data`, containing sets and data arrays.
    - `setup::Dict`: User-defined settings to override defaults (default: empty `Dict`).

    # Returns
    - `OptimizationModel`: A new instance of the `OptimizationModel` struct.
    """
    function OptimizationModel(data::Dict; setup::Dict=Dict(), solver::String)
        # Initialize a JuMP model with Gurobi solver
        # Configure solver settings using Gurobi-specific function
        optimizer = configure_gurobi()
        
        #if solver == "CPLEX"
        #    m = Model(CPLEX.Optimizer)  # CPLEX
        #else
        if solver == "Gurobi"
            m = Model(Gurobi.Optimizer)      # Gurobi 
        else
            error("Unsupported solver. Choose 'CPLEX' or 'Gurobi'.")
        end
        # Return a new OptimizationModel instance
        return new(m, data, setup, Dict(), optimizer)
    end
end

"""
    create_base_model(m)

Includes and defines all base agents (consumer, generator, storage) for the model `m`.
This function loads the agent definitions from their respective files and applies them to the model.

# Arguments
- `m`: The model object to which agent definitions will be added.
"""
function create_base_model!(m; verbose=false, update_prices = false)
    if verbose
        println("   Defining consumer agent...")
    end
    # Define consumer agent
    define_consumer!(m, update_prices=update_prices)

    if verbose
        println("   Defining generator agent...")
    end
    # Define generator agent
    define_generator!(m, update_prices=update_prices)

    if verbose
        println("   Defining storage agent...")
    end
    # Define storage agent
    define_storage!(m, update_prices=update_prices)

    if verbose
        println("Base model creation complete.")
    end
end

"""
    model_settings(model_type::Symbol)

Returns predefined structured settings based on the selected `model_type`. These settings configure 
the model’s behavior for different scenarios (e.g., risk-neutral vs. risk-averse formulations).

# Arguments
- `model_type::Symbol`: Type of model (`:risk_neutral`, `:risk_averse`, `:bilevel`).

# Returns
- `Dict`: A dictionary of settings for general configuration, variables, constraints, expressions, 
  and objective function.

# Available Model Types
- `:risk_neutral`: Configures a risk-neutral model (no CVaR, simple profit maximization).
- `:risk_averse`: Configures a risk-averse model (includes CVaR for risk modeling).
- `:bilevel`: Not implemented in this code but reserved for future extensions.

# Throws
- `Error`: If an unknown `model_type` is provided.
"""
function model_settings(model_type::Symbol)
    settings = Dict(
        :risk_neutral => Dict(
            :general => Dict(:demand_type => :QP, :default_capacity_limits => true, :chronological_clustering => true),  # Default demand type is linear
            :variables => Dict(:include_dual => false, :include_investor_primal => true, :include_investor_dual => false, :include_investor_risk => false),
            :constraints => Dict(:iso_primal => true, :investor_primal => false, :investor_dual => false, :demand_balance => true),
            :expressions => Dict(:use_lambda => false, :calculate_residual => true, :calculate_profits => false, :calculate_risk_measures => false),  # New Expressions Settings
            :objective_function => Dict(:type => :maximize_profit, :use_risk_aversion => false)
        ),
        :risk_averse  => Dict(
            :general => Dict(:demand_type => :QP, :default_capacity_limits => true, :chronological_clustering => true),  # Default demand type is QP
            :variables => Dict(:include_dual => false, :include_investor_primal => true, :include_investor_dual => false, :include_investor_risk => true),
            :constraints => Dict(:iso_primal => true, :investor_primal => true, :investor_dual => false, :demand_balance => false),
            :expressions => Dict(:use_lambda => true, :calculate_residual => true, :calculate_profits => true, :calculate_risk_measures => true),  # New Expressions Settings
            :objective_function => Dict(:type => :risk_averse_profit, :use_risk_aversion => true)
        ),
    )

    if haskey(settings, model_type)
        return settings[model_type]
    else
        error("Unknown model type: $model_type")
    end
end

"""
    add_variables!(opt_model::OptimizationModel)

Automatically defines all decision variables based on `opt_model.settings[:variables]`. This 
function sets up variables such as energy output, installed capacity, and risk-related variables.

# Arguments
- `opt_model::OptimizationModel`: The optimization model to add variables to.
"""
function add_variables!(opt_model::OptimizationModel)
    define_variables!(opt_model::OptimizationModel)
end

"""
    add_constraints!(opt_model::OptimizationModel)

Automatically applies all relevant constraints based on `opt_model.settings[:constraints]`. This 
includes constraints like demand balance, ramping limits, and investor-specific constraints.

# Arguments
- `opt_model::OptimizationModel`: The optimization model to add constraints to.
"""
function add_constraints!(opt_model::OptimizationModel)
    constraint_settings = opt_model.settings[:constraints]

    # Add ISO (market operator) primal constraints if enabled
    if constraint_settings[:iso_primal]
        define_iso_primal_constraints!(opt_model)
    end
    # Add investor primal constraints if enabled (e.g., for generators)
    if constraint_settings[:investor_primal]
        define_investor_primal_constraints!(opt_model)
    end
    # Add investor dual constraints if enabled
    if constraint_settings[:investor_dual]
        define_investor_dual_constraints!(opt_model)
    end
end

"""
    add_expressions!(opt_model::OptimizationModel)

Automatically defines key model expressions based on `opt_model.settings[:expressions]`. This 
includes expressions for profits, risk measures (e.g., CVaR for risk-averse models), total costs, 
and residuals for the ADMM algorithm.

# Arguments
- `opt_model::OptimizationModel`: The optimization model to add expressions to.

# Expressions Added
- Profit expressions for agents.
- Risk measures (e.g., CVaR for risk-averse models).
- Total cost expressions.
- Residual calculations (if enabled, for ADMM iterations).
"""
function add_expressions!(opt_model::OptimizationModel)
    define_expressions!(opt_model)
end

"""
    define_objective!(opt_model::OptimizationModel)

Automatically sets up the objective function based on `opt_model.settings[:objective_function]`. 
This implements the objective for risk-averse models (balancing profit and risk) or a simple 
profit maximization for risk-neutral models.

# Arguments
- `opt_model::OptimizationModel`: The optimization model to define the objective for.
"""
#function define_objective!(opt_model::OptimizationModel)
#    define_objective_expressions!(opt_model)
#end

"""
    build_model!(opt_model::OptimizationModel)

Builds the entire optimization model by adding variables, constraints, expressions, and the 
objective. This function orchestrates the model setup.

# Arguments
- `opt_model::OptimizationModel`: The optimization model to build.

# Steps
1. Defines decision variables (e.g., energy output, installed capacity).
2. Adds expressions (e.g., profits, residuals).
3. Adds constraints (e.g., demand balance, ramping limits).
4. Defines the objective function (e.g., risk-averse profit maximization).
"""
function build_model!(opt_model::OptimizationModel)
    add_variables!(opt_model)
    add_expressions!(opt_model)  # Add expressions before defining the objective
    add_constraints!(opt_model)
    #define_objective!(opt_model)
end

"""
    extract_results(opt_model::OptimizationModel)

Extracts relevant results after solving the optimization model. This includes primal solutions 
(e.g., installed capacities, energy outputs) and dual values (e.g., prices).

# Arguments
- `opt_model::OptimizationModel`: The optimization model to extract results from.
"""
function extract_results(opt_model::OptimizationModel)
    extract_solution!(opt_model)   # Extract primal solution values
    extract_dual_values!(opt_model) # Extract dual prices if needed
end
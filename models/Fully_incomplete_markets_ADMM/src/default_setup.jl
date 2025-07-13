# default_setup.jl
#
# This script defines the `default_setup` dictionary, which contains model parameters and configurations 
# for the risk-averse capacity expansion model. The dictionary is organized into groups based on the 
# type and purpose of each option, with comments explaining each group's role. Below is a detailed 
# description of each option.
#
# Model Configuration Options
# - `"use_hierarchical_clustering"`: Boolean flag to enable hierarchical clustering for time weights, 
#   affecting how time periods are weighted in the model (default: `false`).
### the model groups similar time steps and then assigns weights to each representative period based on how many original time steps it represents. When false, all time steps might be equally weighted.
#
# Data Path Options
# - `"input_path"`: String path to the input data folder (e.g., `"data/"`).
# - `"availability"`: String filename for availability factors data (e.g., `"CF.csv"`).
# - `"demand"`: String filename for demand profiles data (e.g., `"load_profile.csv"`).
# - `"storage_data"`: String filename for storage data (e.g., `"storagedata.csv"`).
# - `"generation_data"`: String filename for generation data (e.g., `"gendata.csv"`).
# - `"time_weight"`: String filename for time weights (e.g., `"time_weight.csv"`).
#
# Demand and Load Shedding Options
# - `"peak_demand"`: Float precomputed peak demand value (e.g., `100`).
# - `"B"`: Float penalty for unserved energy, used as the cost of energy not served (e.g., `1000`). pound per kwh
#
# Risk Aversion Options
# - `"δ"`: Float risk aversion coefficient for balancing expected profit and risk (e.g., `0.5`).
# - `"Ψ"`: Float Conditional Value-at-Risk (CVaR) parameter for risk modeling (e.g., `0.5`).

# Setup dictionary with model parameters and configurations
const default_setup = Dict(
    # Model Configuration Options
    "use_hierarchical_clustering" => false,
    "objective" => "central",  # Options: "central" or "individual"

    # Data Path Options
    "input_path" => "data_final/f672",
    #"input_path" => "synthetic_data/",
    "availability" => "concatenated_capacity_factors_672_30yr_new_final_lf.csv", #"CF.csv",
    "demand" => "concatenated_load_profiles_672_30yr_new_final.csv", #"load_profile.csv",
    "storage_data" => "storagedata.csv",
    "generation_data" => "gendata.csv",
    "time_weight" => "concatenated_weights_672_30yr_new_final.csv", #"time_weight.csv",

    # Demand and Load Shedding Options
    "peak_demand" => 100,
    "flexible_demand" => 1.1,  # Fraction of demand that can be flexible, 10% demand flexibility, This value means that the demand at each time step can vary up to ±10% around its nominal (reference) value.
    "B" => 8000,
    "demand_type" => "QP",  # Options: :QP or :linear, QP= Quadratic Programming — demand deviation penalized quadratically (e.g., (Δdemand)²)

    # Risk Aversion Options
    "δ" => 1,
    "Ψ" => 0.5,
    "gas_price" => 128, #128
    "factor_gas_price" => 10,

    # ADMM Options
    "penalty" => 2,  # Penalty parameter for ADMM
    "max_iterations" => 10000,  # Maximum number of iterations for ADMM
    "tolerance" => 0.1,  # Tolerance for convergence criteria (calculated as sqrt((|S|+|G|+1)*|T|*|O|)*0.1)
)
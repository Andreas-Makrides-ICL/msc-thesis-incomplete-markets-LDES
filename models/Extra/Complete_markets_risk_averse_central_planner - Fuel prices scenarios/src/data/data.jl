# data.jl
# Functions for loading and processing input data for the risk-averse capacity expansion model.
# This file loads data from CSV files, filters it based on user-defined sets, and converts it into 
# DenseAxisArray format for use in the optimization model.

using CSV
using DataFrames
using Dates: now
using JuMP
using JuMP.Containers: DenseAxisArray

"""
    load_data(setup::Dict; user_sets::Dict=Dict(), verbose::Bool=true)

Loads various data inputs from multiple CSV files in the specified path directory and stores 
the variables in a dictionary object for use in the optimization model. The data is converted 
into DenseAxisArray format for efficient indexing and access.

# Arguments
- `setup::Dict`: Dictionary containing configuration settings, including:
  - `input_path`: Path to the directory containing input CSV files.
  - `availability`: Filename for availability factors data.
  - `demand`: Filename for demand profiles data.
  - `storage_data`: Filename for storage data.
  - `generation_data`: Filename for generation data.
  - `time_weight`: Filename for time weights data.
  - `use_hierarchical_clustering`: Boolean to enable hierarchical clustering (default: false).
  - `peak_demand`: Precomputed peak demand value (default: 100).
  - `B`: Penalty for unserved energy (default: 1000).
  - `δ`: Risk aversion coefficient (default: 0.5).
  - `Ψ`: CVaR parameter (default: 0.5).
- `user_sets::Dict`: Optional dictionary containing user-defined sets (e.g., "G" => [...], "S" => [...]; default: empty `Dict`).
- `verbose::Bool`: Boolean to indicate whether detailed output should be printed (default: `true`).

# Returns
- `Dict`: A dictionary containing:
  - `"data"`: Sub-dictionary with DenseAxisArray objects for each data type (e.g., `generation_data`, `storage_data`).
  - `"sets"`: Sub-dictionary with sets (e.g., `T`, `O`, `G`, `S`, `R`).
  - `"maps"`: Sub-dictionary with mapping sets (currently empty).

# Example
```julia
setup = Dict(
    "input_path" => "data/",
    "availability" => "CF.csv",
    "demand" => "load_profile.csv",
    "storage_data" => "storagedata.csv",
    "generation_data" => "gendata.csv",
    "time_weight" => "time_weight.csv",
    "use_hierarchical_clustering" => false,
    "peak_demand" => 100,
    "B" => 1000,
    "δ" => 0.5,
    "Ψ" => 0.5
)
data = load_data(setup, verbose=true)
```
"""
function load_data(setup::Dict; user_sets::Dict=Dict(), verbose::Bool=true)
    start_time = now()
    if verbose
        println("-------------------------------")
        println("Loading data from CSV files...")
    end

    # Extract path and file names from setup
    path = setup["input_path"]

    # Load all DataFrames
    dataframes = Dict(
        "availability" => CSV.read(joinpath(path, setup["availability"]), DataFrame),
        "demand" => CSV.read(joinpath(path, setup["demand"]), DataFrame),
        "storage_data" => CSV.read(joinpath(path, setup["storage_data"]), DataFrame),
        "generation_data" => CSV.read(joinpath(path, setup["generation_data"]), DataFrame),
        "time_weights" => CSV.read(joinpath(path, setup["time_weight"]), DataFrame)
    )

    if verbose
        for (key, _) in dataframes
            println("   $key data loaded successfully")
        end
    end

    # Compute CRF for generation_data and storage_data DataFrames ### CRF = CAPITAL RECOVERY FACTOR, The Capital Recovery Factor (CRF) turns a lump-sum investment (like £/MW or £/MWh) into an annualized cost over the asset’s lifetime. Then, you can multiply CRF,This gives a multiplier that you apply to capital cost to get annualized cost per MW or MWh per year.
    for key in ["generation_data", "storage_data"]
        df = dataframes[key]
        if "WACC" in names(df) && "Lifetime" in names(df)
            df[!, "CRF"] = @. df.WACC * (1 + df.WACC)^df.Lifetime / ((1 + df.WACC)^df.Lifetime - 1)
            if verbose
                println("   Computed CRF column for $key")
            end
        else
            if verbose
                println("   Warning: Missing 'WACC' or 'Lifetime' column in $key; CRF not computed")
            end
        end
    end

    # Filter generation_data and storage_data based on Include column (1 = include, 0 = exclude)
    for key in ["generation_data", "storage_data"]
        if "Include" in names(dataframes[key])
            filter!(row -> row.Include != 0, dataframes[key])
            if verbose
                println("   Filtered $key based on Include column")
            end
        else
            if verbose
                println("   Warning: No 'Include' column found in $key; no filtering applied")
            end
        end
    end

    # Define sets from raw (filtered) data
    sets = Dict(
        "T" => unique(dataframes["demand"].T),
        "O" => unique(dataframes["demand"].O),
        "G" => unique(dataframes["generation_data"].G),
        "S" => unique(dataframes["storage_data"].S),
        "R" => union(unique(dataframes["generation_data"].G), unique(dataframes["storage_data"].S))
    )

    # Ensure all generator/storage names are String (not String31, Symbol, etc.)
    sets["G"] = String.(sets["G"])
    sets["S"] = String.(sets["S"])
    sets["R"] = String.(sets["R"])

    # Apply user-defined set filters from user_sets if provided
    user_sets_defined = !isempty(user_sets)
    if user_sets_defined
        for set_name in ["T", "O", "G", "S", "R"]
            if haskey(user_sets, set_name) && !isempty(user_sets[set_name])
                sets[set_name] = intersect(sets[set_name], user_sets[set_name])
                isempty(sets[set_name]) && error("No elements in $set_name after filtering with user-defined set.")
                if verbose
                    println("   Filtered set $set_name with user-defined values")
                end
            end
        end
    end

    # Filter DataFrames based on filtered sets only if user_sets were defined
    filter!(row -> row.T in sets["T"] && row.O in sets["O"] && row.G in sets["G"], dataframes["availability"])
    filter!(row -> row.T in sets["T"] && row.O in sets["O"], dataframes["demand"])
    filter!(row -> row.G in sets["G"], dataframes["generation_data"])
    filter!(row -> row.S in sets["S"], dataframes["storage_data"])
    filter!(row -> row.T in sets["T"] && row.O in sets["O"], dataframes["time_weights"])
    if verbose
        println("   DataFrames filtered based on user-defined sets")
    end


    # Define index columns for DenseAxisArray creation
    index_config = Dict(
        "availability" => (["T", "O", "G"], String[]),
        "demand" => (["T", "O"], String[]),
        "storage_data" => (["S"], String[]),
        "generation_data" => (["G"], String[]),
        "time_weights" => (["T", "O"], String[])
    )


    # Convert filtered DataFrames to DenseAxisArrays
    data_arrays = Dict{String, Any}()


    for (key, df) in dataframes
        if verbose
            println("   Converting $key data to DenseAxisArray...")
        end
        data_arrays[key] = create_dense_array(df, index_config[key][1], index_config[key][2])
    end
    if verbose
        println("   DataFrames converted to DenseAxisArrays successfully")
    end


     # ---------------------------------------------------------
    # Step 1: Expand O to include gas price scenarios (30 × 3)
    # ---------------------------------------------------------

    original_O = sort(sets["O"])  # These are your original 30 scenarios (weather/demand)
    gas_price_levels = [7.0, 20.0, 40.0]

    new_O = 1:(length(original_O) * length(gas_price_levels))  # 1:90
    sets["O"] = new_O  # Overwrite the scenario set with the full 1:90 list

    # Map new scenario index to (original weather scenario, gas price)
    scenario_map = Dict{Int, Tuple{Int, Float64}}()
    gas_price_scenarios = Dict{Int, Float64}()

    counter = 1
    for o_weather in original_O
        for gp in gas_price_levels
            scenario_map[counter] = (o_weather, gp)
            gas_price_scenarios[counter] = gp
            counter += 1
        end
    end


    T = sets["T"]
    G = sets["G"]

    new_demand = DenseAxisArray(zeros(Float64, length(T), length(new_O)), T, new_O)
    new_avail = DenseAxisArray(zeros(Float64, length(T), length(new_O), length(G)), T, new_O, G)
    new_weights = DenseAxisArray(zeros(Float64, length(T), length(new_O)), T, new_O)


    original_demand = data_arrays["demand"]
    original_avail = data_arrays["availability"]
    original_weights = data_arrays["time_weights"]

    for o_new in new_O
        (o_weather, _) = scenario_map[o_new]

        for t in T
            new_demand[t, o_new] = original_demand[t, o_weather]
            new_weights[t, o_new] = original_weights[t, o_weather]
            for g in G
                if g in axes(original_avail, 3)
                    new_avail[t, o_new, g] = original_avail[t, o_weather, g]
                else
                    new_avail[t, o_new, g] = 1.0  # or 0.0 depending on your modeling logic
                end
            end
        end
    end

    # Replace with expanded versions
    data_arrays["demand"] = new_demand
    data_arrays["availability"] = new_avail
    data_arrays["time_weights"] = new_weights
    # Save to data dictionary
    data_arrays["scenario_map"] = scenario_map
    data_arrays["gas_price_scenarios"] = gas_price_scenarios










    # Check for missing elements
    missing_elements = [key for (key, value) in data_arrays if isempty(value)]
    if !isempty(missing_elements)
        println("   Missing data elements: ", join(missing_elements, ", "))
    elseif verbose
        println("   All required data elements are present.")
    end

    # Adjust time weights based on hierarchical clustering setting
    if !haskey(setup, "use_hierarchical_clustering") || !setup["use_hierarchical_clustering"]
        # Uniform weights for non-clustered case
        for t in sets["T"], o in sets["O"]
            data_arrays["time_weights"][t, o] = 8760 / length(sets["T"])
        end
    else
        # Validate that weights sum to 8760 (hours in a year) for each scenario
        for o in sets["O"]
            total_weight = sum(data_arrays["time_weights"][t, o] for t in sets["T"])
            if total_weight != 8760
                error("Sum of weights for scenario $o is not equal to 8760 (got $total_weight)")
            end
        end
    end

    # Compute number of CVaR scenarios (N_cvar)
    P = Dict(o => 1 / length(sets["O"]) for o in sets["O"])  # Equal probability by default
    N_cvar = max(1, setup["Ψ"] / P[sets["O"][1]])  # Number of CVaR scenarios, Calculates the number of worst-case scenarios to include in CVaR, Example#10 scenarios → P[o] = 0.1##Ψ = 0.5#→ N_cvar = 0.5 / 0.1 = 5#So CVaR is computed as the average cost of the 5 worst scenarios

    # Add additional parameters to data_arrays
    data_arrays["additional_params"] = Dict(
        "peak_demand" => get(setup, "peak_demand", 100),  # Default peak demand
        "B" => get(setup, "B", 1000),  # Penalty for unserved energy
        "δ" => get(setup, "δ", 0.5),   # Risk aversion coefficient
        "Ψ" => get(setup, "Ψ", 0.5),   # CVaR parameter
        "gas_price" => get(setup, "gas_price", 173),   # CVaR parameter
        "factor_gas_price" => get(setup, "factor_gas_price", 1),   # CVaR parameter
        "N_cvar" => N_cvar,            # Number of CVaR scenarios
        "P" => P,                       # Scenario probabilities
        "flexible_demand" => get(setup, "flexible_demand", 1.1),
    )

    if verbose
        println("   Added additional parameters: peak_demand, B, δ, Ψ, N_cvar, P")
    end

    end_time = now()
    if verbose
        println("   Data loading completed in $(end_time - start_time)")
    else
        println("Data loaded successfully.")
    end

    # Return dictionary with arrays and sets
    inputs = Dict{String, Any}()
    
    inputs["data"] = data_arrays
    inputs["sets"] = sets
    inputs["maps"] = Dict()  # No mapping sets required for this model

    return inputs
end


"""
    create_dense_array(df::DataFrame, index_cols::Vector{String}, exclude_cols::Vector{String}=String[]; data_type::Type=Float64)

Creates a `DenseAxisArray` from a DataFrame, using specified columns as indices and the remaining 
columns (after excluding any specified columns) as values, casting the data to the specified type.

This helper function extracts indices and values from a DataFrame and constructs a `DenseAxisArray`. 
If there is only one value column (after exclusions), the array is flattened to exclude the value 
dimension. The data is converted to the specified `data_type` before creating the array.

# Arguments
- `df::DataFrame`: The input DataFrame containing the data to convert.
- `index_cols::Vector{String}`: Column names in `df` to use as indices for the `DenseAxisArray`.
- `exclude_cols::Vector{String}`: Optional vector of column names to exclude from the DataFrame (defaults to an empty vector, meaning no additional exclusions beyond `index_cols`).
- `data_type::Type`: The data type to which values are cast (defaults to `Float64`).

# Returns
- `DenseAxisArray`: A `DenseAxisArray` with dimensions equal to the number of index columns plus remaining value columns after exclusions. If only one value column exists, the value dimension is omitted.

# Throws
- `Error`: If `index_cols` or `exclude_cols` includes columns not found in the DataFrame.
- `Error`: If the number of index columns plus excluded columns exceeds or equals the total number of columns (no value columns remain).
- `Error`: If the number of index columns exceeds 3 when there is only one value column (due to implementation limitations).

# Examples
```julia
df = DataFrame(B=1:3, T=1:3, value=[10.0, 20.0, 30.0])
array = create_dense_array(df, ["B", "T"], String[], data_type=Float64)
```
"""
function create_dense_array(df::DataFrame, index_cols::Vector{String}, exclude_cols::Vector{String}=String[]; data_type::Type=Float64)
    # Validate inputs
    all_cols = names(df)
    n_cols = length(all_cols)
    n_indices = length(index_cols)
    n_excludes = length(exclude_cols)
    
    # Check if total columns to use/index/exclude exceeds DataFrame columns
    if n_indices + n_excludes > n_cols
        error("Number of index columns ($n_indices) and excluded columns ($n_excludes) exceeds total columns ($n_cols)")
    elseif n_indices + n_excludes == n_cols
        error("All columns specified as indices or excluded; no value columns remain")
    end

    # Check that index_cols and exclude_cols exist in df
    for col in vcat(index_cols, exclude_cols)
        col in all_cols || error("Column '$col' not found in DataFrame")
    end

    # Value columns are those not in index_cols or exclude_cols
    value_cols = [col for col in all_cols if col ∉ vcat(index_cols, exclude_cols)]
    n_values = length(value_cols)

    # Define index sets
    index_sets = [sort(unique(df[!, col])) for col in index_cols]

    # If only one value column, flatten the output dimensionality
    if n_values == 1
        value_col = value_cols[1]
        dims = Tuple(length(s) for s in index_sets)
        
        # Pre-allocate array with specified data type and appropriate dimensions
        if n_indices == 1
            arr = zeros(data_type, dims[1])
        elseif n_indices == 2
            arr = zeros(data_type, dims[1], dims[2])
        elseif n_indices == 3
            arr = zeros(data_type, dims[1], dims[2], dims[3])
        else
            error("Unsupported number of indices ($n_indices) with one value column")
        end

        # Fill array assuming indices are 1-based consecutive integers
        for row in eachrow(df)
            idx = Tuple(findfirst(isequal(row[col]), index_sets[i]) for (i, col) in enumerate(index_cols))
            arr[idx...] = convert(data_type, row[value_col])
        end

        # Create DenseAxisArray
        return DenseAxisArray(arr, index_sets...)
    else
        # Multiple value columns; include them as an additional dimension
        dims = Tuple(length(s) for s in index_sets)
        arr = zeros(data_type, dims..., n_values)
        
        # Fill array
        for row in eachrow(df)
            idx = Tuple(findfirst(isequal(row[col]), index_sets[i]) for (i, col) in enumerate(index_cols))
            for (v_idx, v_col) in enumerate(value_cols)
                arr[idx..., v_idx] = convert(data_type, row[v_col])
            end
        end

        # Create DenseAxisArray with value_cols as the last dimension
        return DenseAxisArray(arr, index_sets..., value_cols)
    end
end

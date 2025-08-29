# utils.jl
# Utility functions for the ADMM-based risk-averse capacity expansion model.
# These functions support data manipulation, dictionary operations, and price updates
# for the optimization framework.

"""
    df_to_dict(df::DataFrame, n::Int)

Convert a DataFrame to a dictionary with tuple keys. This is useful for transforming tabular 
data (e.g., market data) into a dictionary format for easier lookup in the model.

# Arguments
- `df::DataFrame`: Input DataFrame containing the data.
- `n::Int`: Number of columns to use as the key tuple.

# Returns
- `Dict`: A dictionary with tuple keys and corresponding values from the DataFrame.

# Throws
- `ArgumentError`: If `n` is greater than or equal to the number of columns in the DataFrame.
"""
function df_to_dict(df::DataFrame, n::Int)
    # Validate input
    if n >= ncol(df)
        throw(ArgumentError("n cannot be greater than or equal to the number of columns in the DataFrame"))
    end

    dict = Dict()
    for row in eachrow(df)
        # Create a tuple key from the first n columns, converting each element to a string
        key = n == 1 ? tuple(string(row[1])) : tuple([string(i) for i in row[1:n]]...)
        
        # If n is the second-to-last column, map the last column directly to the key
        if n == ncol(df) - 1
            dict[key...] = row[ncol(df)]
        else
            # Otherwise, create a key for each remaining column and map its value
            for col in names(df)[n+1:end]
                dict[(key..., string(col))] = row[col]
            end
        end
    end
    return dict
end

"""
    fill_missing_values!(dict::Dict, indices::Vector{Any}, default_value=0)

Fill missing values in a dictionary with a default value and remove invalid keys. This ensures 
that the dictionary has entries for all combinations of indices, which is useful for maintaining 
consistency in data across scenarios and time steps.

# Arguments
- `dict::Dict`: The dictionary to modify.
- `indices::Vector{Any}`: A vector of index sets (e.g., scenarios, time steps).
- `default_value`: The value to use for missing entries (default is 0).

# Returns
- `Dict`: The modified dictionary with filled missing values and invalid keys removed.
"""
function fill_missing_values!(dict::Dict, indices::Vector{Any}, default_value=0)
    # Step 1: Fill missing values with the default value
    for index_combination in Iterators.product(indices...)
        if !haskey(dict, index_combination)
            dict[index_combination] = default_value
        end
    end

    # Step 2: Identify keys that contain indices not in the provided sets
    keys_to_remove = []
    for key in keys(dict)
        if any(k ∉ indices[i] for (i, k) in enumerate(key))
            push!(keys_to_remove, key)
        end
    end

    # Step 3: Remove invalid keys
    for key in keys_to_remove
        delete!(dict, key)
    end

    return dict
end

"""
    generate_set(n::Int)

Generate a set of strings from 1 to n. This is useful for creating index sets (e.g., for agents 
or time steps).

# Arguments
- `n::Int`: The upper bound for the set.

# Returns
- `Vector{String}`: A vector of strings ["1", "2", ..., "n"].
"""
function generate_set(n::Int)
    return ["$i" for i in 1:n]
end

"""
    previous_element(vec::Vector, elem)

Get the previous element in a vector. Useful for time-dependent operations, such as handling 
sequential constraints like ramping limits.

# Arguments
- `vec::Vector`: The vector to search in.
- `elem`: The element to find.

# Returns
- The previous element if it exists, otherwise `nothing`.

# Throws
- `ArgumentError`: If the element is not found in the vector.
"""
function previous_element(vec::Vector, elem)
    idx = findfirst(x -> x == elem, vec)
    if idx == nothing
        throw(ArgumentError("Element not found in the vector"))
    elseif idx == 1
        return nothing
    else
        return vec[idx - 1]
    end
end

"""
    next_element(vec::Vector, elem)

Get the next element in a vector. Useful for time-dependent operations, such as handling 
sequential constraints like ramping limits.

# Arguments
- `vec::Vector`: The vector to search in.
- `elem`: The element to find.

# Returns
- The next element if it exists, otherwise `nothing`.

# Throws
- `ArgumentError`: If the element is not found in the vector.
"""
function next_element(vec::Vector, elem)
    idx = findfirst(x -> x == elem, vec)
    if idx == nothing
        throw(ArgumentError("Element not found in the vector"))
    elseif idx == length(vec)
        return nothing
    else
        return vec[idx + 1]
    end
end


"""
    count_unique_elements(dict::Dict, n::Int; return_elements::Bool=false)

Count unique elements in the n-th position of tuple keys in a dictionary. Optionally return 
the unique elements themselves. This is useful for analyzing sets (e.g., counting unique 
scenarios or time steps).

# Arguments
- `dict::Dict`: The dictionary with tuple keys.
- `n::Int`: The position in the tuple to consider for uniqueness.
- `return_elements::Bool`: If true, return the unique elements; if false, return the count (default: false).

# Returns
- If `return_elements` is false: `Int`, the number of unique elements.
- If `return_elements` is true: `Vector`, the unique elements.

# Example
```julia
dict = Dict(("a", "x") => 1.0, ("b", "y") => 2.0, ("c", "x") => 3.0)
count = count_unique_elements(dict, 2)  # returns 2
elements = count_unique_elements(dict, 2, return_elements=true)  # returns ["x", "y"]
```
"""
function count_unique_elements(dict::Dict, n::Int; return_elements::Bool=false)
    second_elements = [key[n] for key in keys(dict)]
    unique_elements = unique(second_elements)
    return return_elements ? unique_elements : length(unique_elements)
end

"""
    df_get_d(df::DataFrame, elem, col::Symbol)

Get a value from a DataFrame based on a matching element in the first column. Useful for 
retrieving specific parameters (e.g., costs or demands) from a DataFrame.

# Arguments
- `df::DataFrame`: The DataFrame to search in.
- `elem`: The element to match in the first column.
- `col::Symbol`: The column to retrieve the value from.

# Returns
- The value in the specified column for the matching row.

# Throws
- `ArgumentError`: If the element is not found in the first column.
"""
function df_get_d(df::DataFrame, elem, col::Symbol)
    row = findfirst(r -> r[1] == elem, eachrow(df))
    if row === nothing
        throw(ArgumentError("Element not found in the first column"))
    end
    return df[row, col]
end

"""
    maybe_remove_constraint(m, name)

Remove a constraint from a JuMP model if it exists. This is useful for dynamically updating 
the model during ADMM iterations.

# Arguments
- `m`: The JuMP model.
- `name`: The name of the constraint to remove.
"""
function maybe_remove_constraint(m, name)
    if haskey(m, name)
        delete.(m, m[name])
        unregister.(m, name)
    end
end

"""
    maybe_remove_expression(m, name)

Remove an expression from a JuMP model if it exists. This is useful for dynamically updating 
expressions during ADMM iterations.

# Arguments
- `m`: The JuMP model.
- `name`: The name of the expression to remove.
"""
function maybe_remove_expression(m, name)
    if haskey(m, name)
        unregister(m, name)
    end
end

function safe_objective_value(model::Model)
    if termination_status(model) == MOI.OPTIMAL
        return objective_value(model)
    else
        error("Tried to access objective value but model was not solved to optimality.")
    end
end


"""
    solve_and_check_optimality!(m)

Solve a JuMP model and check if it is solved to optimality. If not, throw an error.

# Arguments
- `m`: The JuMP model to solve and check.

# Throws
- `ErrorException`: If the model is not solved to optimality.
"""
function solve_and_check_optimality!(m, verbose::Bool = true)
    # this is for gurobi
    # Ensure solver output is not suppressed 
    #MOI.set(m, MOI.RawParameter("OutputFlag"), 1)

    # Solve
    @time optimize!(m)
    term_status = termination_status(m)
    if termination_status(m) != MOI.OPTIMAL
        throw(ErrorException("Model not solved to optimality: $term_status"))
    end
    # Extract results
    primal_stat = primal_status(m)
    dual_stat = dual_status(m)
    obj_val = safe_objective_value(m)
    time_taken = solve_time(m)

    if verbose
        println("=== Solver Summary ===")
        println("Termination Status : ", term_status)
        println("Primal Status      : ", primal_stat)
        println("Dual Status        : ", dual_stat)
        println("Objective Value    : ", obj_val)
        println("Solve Time (s)     : ", time_taken)
        println("=======================")
    end

    

    return Dict(
        :termination_status => term_status,
        :primal_status => primal_stat,
        :dual_status => dual_stat,
        :objective_value => obj_val,
        :solve_time => time_taken
    )
end


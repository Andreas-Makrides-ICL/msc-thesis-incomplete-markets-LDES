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
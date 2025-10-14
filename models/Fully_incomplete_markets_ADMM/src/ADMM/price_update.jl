
"""
    update_price_values(d, residual, penalty)

Updates the Lagrange multipliers (λ values) based on residuals, as part of the ADMM algorithm. 
This adjusts the prices to balance supply and demand iteratively.

# Arguments
- `d`: The `ModelData` instance containing the current λ values and parameters.
- `residual`: The primal residual values.
- `penalty::Float64`: The penalty factor for ADMM updates.
"""
function update_price_values!(model, iteration)
    data = model.data
    m = model.model
    settings = model.setup

    penalty = settings["penalty"]
    residual = model.results[iteration][:residual]

    # Update λ values using the residual and penalty factor
    prices = data["data"]["additional_params"]["λ"] .- (penalty / 2 .* residual) # if residual>0, supply> demand and price goes down, if residual<0, supply<demand and price goes up

    data["data"]["additional_params"]["λ"] = prices

    # Store the updated prices in the model for future reference
    model.results[iteration][:price_update] = prices
end

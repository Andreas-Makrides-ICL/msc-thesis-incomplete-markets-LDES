# -*- coding: utf-8 -*-
"""
Created on Tue Aug  5 16:41:30 2025

@author: Andreas Makrides
"""

import pandas as pd

# Load files
# Update with correct paths
duals_df = pd.read_csv(r"...\scarcity_rent_delta_0.25.csv")
weights_df = pd.read_csv(r"...\concatenated_weights_672_30yr_new.csv")  
cvar_dual_df = pd.read_csv(r"...\dual_cvar_delta_0.25.csv")
prices_df = pd.read_csv(r"...\prices_delta_0.25_H2_15000_025.csv")
storage_dispacth_df = pd.read_csv(r"...\energy_charge_discharge_delta_0.25.csv")

# Just to make sure you have the correct number of scearios
scenarios = [19, 12, 7, 11, 23, 8, 30, 24, 1, 26, 29, 13, 4, 22, 27]
duals_df = duals_df[duals_df["Scenario"].isin(scenarios)]
weights_df = weights_df[weights_df["O"].isin(scenarios)]
cvar_dual_df = cvar_dual_df[cvar_dual_df["Scenario"].isin(scenarios)]
prices_df = prices_df[prices_df["Scenario"].isin(scenarios)]
storage_dispacth_df = storage_dispacth_df[storage_dispacth_df["Scenario"].isin(scenarios)]

# Define the probability per scenario
p_o = 1 / len(scenarios)

# Merge the duals dataframe with the time weights dataframe
merged = duals_df.merge(weights_df, left_on=["Scenario", "Time"], right_on=["O", "T"], how="left")

# Merge in CVaR duals (λ_ω) per scenario
merged = merged.merge(cvar_dual_df, on=["Scenario", "Storage"], how="left")

# Merge prices (on Scenario and Time)
merged = merged.merge(prices_df, on=["Scenario", "Time"], how="left")

# Optionally merge storage dispatch data (for validation)
merged = merged.merge(storage_dispacth_df, on=["Scenario", "Time", "Storage"], how="left")

# Compute scarcity rents
delta = 0.25
results = {}

        
for storage in merged["Storage"].unique():
    df = merged[merged["Storage"] == storage].copy()
    
    # Compute risk-adjusted probabilities
    df["risk_weight"] = df["value"] * (delta * p_o + df["dualcvarstorage"])
    
    raw_dual_discharge = -df["Dual_discharge"]
    raw_dual_charge = -df["Dual_charge"]
    raw_dual_energy = -df["Dual_energy"]
    
    processed_dual_discharge = raw_dual_discharge / df["risk_weight"]
    processed_dual_charge = raw_dual_charge / df["risk_weight"]
    processed_dual_energy = raw_dual_energy / df["risk_weight"]
    
    
    scarcity_rent_discharge = (p_o * df["value"] *processed_dual_discharge).sum()
    scarcity_rent_charge =  (p_o * df["value"] *processed_dual_charge).sum()
    scarcity_rent_energy = (p_o * df["value"] *processed_dual_energy).sum()
    scarcity_rent_power = scarcity_rent_discharge + scarcity_rent_charge


    # per scenario scarcity rents and revenues
    # Define installed capacities
    if storage.lower() == "hydrogen" or storage.lower() == "h2":
        power_capacity = 1.49441035012585  # MW
        energy_capacity = 162.143502361599  # MWh
    elif storage.lower() == "bess":
        power_capacity = 19.9266573819775 # MW
        energy_capacity = 195.748400373726  # MWh
    else:
        raise ValueError(f"Unknown storage type: {storage}")
        
    rev_from_scarcity_per_scenario =  df["value"]*(processed_dual_discharge + processed_dual_charge)*power_capacity +  df["value"]*processed_dual_energy*energy_capacity

    
    rev_from_prices = df["price_model"] * df["value"] * (df["Discharge"] - df["Charge"])
   
    per_scenario_df = pd.DataFrame({
        "Scenario": df["Scenario"],
        "Storage": storage,
        "Rev_Scarcity": rev_from_scarcity_per_scenario,
        "Rev_Price": rev_from_prices
    })
    
    # Group by scenario and sum across time
    per_scenario_summary = per_scenario_df.groupby(["Scenario", "Storage"])[["Rev_Scarcity", "Rev_Price"]].sum().reset_index()
    
    # Print per-scenario values
    print(f"\n=== Per-Scenario Revenues for {storage} ===")
    print(per_scenario_summary)
    
    # Also print averages
    avg_scarcity = per_scenario_summary["Rev_Scarcity"].mean()
    avg_price = per_scenario_summary["Rev_Price"].mean()
    
    print(f"\nAverage Revenue from Scarcity Rents: {avg_scarcity} ")
    print(f"Average Revenue from Market Prices: {avg_price} ")



    
    results[storage] = {
        "Scarcity_Rent_discharge": scarcity_rent_discharge,
        "Scarcity_Rent_charge": scarcity_rent_charge,
        "Scarcity_Rent_power": scarcity_rent_power,
        "Scarcity_Rent_energy": scarcity_rent_energy
    }

# Show the results
for storage, rents in results.items():
    print(f"\nStorage: {storage}")
    for rent_type, value in rents.items():
        print(f"{rent_type}: {value}")


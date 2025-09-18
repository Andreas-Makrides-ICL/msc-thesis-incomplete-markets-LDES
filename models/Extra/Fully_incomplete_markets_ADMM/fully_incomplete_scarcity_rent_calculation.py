# -*- coding: utf-8 -*-
"""
Created on Tue Aug  5 16:41:30 2025

@author: Andreas Makrides
"""

import pandas as pd

# Load the duals and time weights CSV files
duals_df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Fully_incomplete_markets_ADMM\RESULTS_FINAL\scarcity_rent_delta_0.75.csv")  # e.g. duals.csv

#checking about bess
#duals_df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Fully_Incomplete\Results\scarcity_rent_binding_hours.csv")

weights_df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Fully_incomplete_markets_ADMM\RESULTS_FINAL\data_final\f672\fff672\concatenated_weights_40yr.csv")  # e.g. weights.csv
cvar_dual_df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Fully_incomplete_markets_ADMM\RESULTS_FINAL\dual_cvar_delta_0.75.csv")
prices_df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Fully_incomplete_markets_ADMM\RESULTS_FINAL\prices_delta_0.75_H2_15000_075.csv")
storage_dispacth_df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Fully_incomplete_markets_ADMM\RESULTS_FINAL\energy_charge_discharge_delta_0.75.csv")

# Filter the scenarios
scenarios = [1,2,6,7,9,13,15,16,19,22,24,26,28,29,30]
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

# 4. Merge prices (on Scenario and Time)
merged = merged.merge(prices_df, on=["Scenario", "Time"], how="left")

# 5. Optionally merge storage dispatch data (for validation)
merged = merged.merge(storage_dispacth_df, on=["Scenario", "Time", "Storage"], how="left")

# Compute scarcity rents
delta = 0.75
results = {}

        
for storage in merged["Storage"].unique():
    df = merged[merged["Storage"] == storage].copy()
    
    # Compute risk-adjusted probabilities: π_ω = δ·P_ω + λ_ω
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
    if (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.25):
        power_capacity = 9.097425245  # MW
        energy_capacity = 1540.578555  # MWh
    elif (storage.lower() == "bess") and (delta == 0.25):
        power_capacity = 9.742623265# MW
        energy_capacity = 148.2573105  # MWh
    elif (delta == 0.25):
        raise ValueError(f"Unknown storage type D025: {storage}")
    
    if (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.5):
        power_capacity = 8.898791315  # MW
        energy_capacity = 1480.119127  # MWh
    elif (storage.lower() == "bess") and (delta == 0.5):
        power_capacity = 9.841243549# MW
        energy_capacity = 149.758054  # MWh
    elif (delta == 0.5):
        raise ValueError(f"Unknown storage type D050: {storage}")
    
    if (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.75):
        power_capacity = 9.04498805  # MW
        energy_capacity = 1445.464076  # MWh
    elif (storage.lower() == "bess") and (delta == 0.75):
        power_capacity = 9.833486796# MW
        energy_capacity = 149.6400165  # MWh
    elif (delta == 0.75):
        raise ValueError(f"Unknown storage type D075: {storage}")
        
    rev_from_scarcity_per_scenario =  df["value"]*(processed_dual_discharge + processed_dual_charge)*power_capacity +  df["value"]*processed_dual_energy*energy_capacity
    rev_from_scarcity_per_scenarioP =  df["value"]*(processed_dual_discharge + processed_dual_charge)*power_capacity
    rev_from_scarcity_per_scenarioE =  df["value"]*processed_dual_energy*energy_capacity
    #average_rev_from_scarcity = rev_from_scarcity_per_scenario.sum()/15
    #print(average_rev_from_scarcity)
    #print(scarcity_rent_power*power_capacity + scarcity_rent_energy*energy_capacity)
    
    rev_from_prices = df["price_model"] * df["value"] * (df["Discharge"] - df["Charge"])
    #average_rev_from_prices = rev_from_prices.sum()/15
    #print(average_rev_from_prices)
    # Add per-scenario revenue DataFrame
    per_scenario_df = pd.DataFrame({
        "Scenario": df["Scenario"],
        "Storage": storage,
        "Rev_Scarcity": rev_from_scarcity_per_scenario,
        "Rev_Scarcity_Power": rev_from_scarcity_per_scenarioP,
        "Rev_Scarcity_Energy": rev_from_scarcity_per_scenarioE,
        "Rev_Price": rev_from_prices
    })
    
    # Group by scenario and sum across time
   # per_scenario_summary = per_scenario_df.groupby(["Scenario", "Storage"])[["Rev_Scarcity", "Rev_Price", "Rev_Scarcity_Power", "Rev_Scarcity_Energy"]].sum().reset_index()
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


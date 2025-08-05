# -*- coding: utf-8 -*-
"""
Created on Tue Aug  5 16:41:30 2025

@author: Andreas Makrides
"""

import pandas as pd

# Load the duals and time weights CSV files
duals_df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Fully_incomplete_markets_ADMM\trycodes_3_FINAL\scarcity_rent_delta_0.5.csv")  # e.g. duals.csv
weights_df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Fully_incomplete_markets_ADMM\trycodes_3_FINAL\data_final\f672\concatenated_weights_672_30yr_new.csv")  # e.g. weights.csv

# Filter the scenarios
scenarios = [19, 12, 7, 11, 23, 8, 30, 24, 1, 26, 29, 13, 4, 22, 27]
duals_df = duals_df[duals_df["Scenario"].isin(scenarios)]
weights_df = weights_df[weights_df["O"].isin(scenarios)]

# Define the probability per scenario
p_o = 1 / len(scenarios)

# Merge the duals dataframe with the time weights dataframe
merged = duals_df.merge(weights_df, left_on=["Scenario", "Time"], right_on=["O", "T"])

# Compute Scarcity Rent components for each storage asset
results = {}

for storage in merged["Storage"].unique():
    df = merged[merged["Storage"] == storage]
    
    scarcity_rent_discharge = sum(-df["Dual_discharge"] * p_o * df["value"])
    scarcity_rent_charge = sum(-df["Dual_charge"] * p_o * df["value"])
    scarcity_rent_energy = sum(-df["Dual_energy"]* p_o * df["value"])
    
    results[storage] = {
        "Scarcity_Rent_discharge": scarcity_rent_discharge,
        "Scarcity_Rent_charge": scarcity_rent_charge,
        "Scarcity_Rent_energy": scarcity_rent_energy
    }

# Show the results
for storage, rents in results.items():
    print(f"\nStorage: {storage}")
    for rent_type, value in rents.items():
        print(f"{rent_type}: {value:}")

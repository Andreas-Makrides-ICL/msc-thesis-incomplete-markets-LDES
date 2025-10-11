# -*- coding: utf-8 -*-
"""
Created on Tue Aug  5 16:41:30 2025

@author: Andreas Makrides
"""

import pandas as pd

# Load the duals and time weights CSV files
duals_df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Fully_incomplete_markets_ADMM\PSCC\PSCC_higher_resolution\trycodes_3_final_higher_resolution\scarcity_rent_delta_0.1.csv")  # e.g. duals.csv

#checking about bess
#duals_df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Fully_Incomplete\Results\scarcity_rent_binding_hours.csv")

weights_df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Fully_incomplete_markets_ADMM\PSCC\PSCC_higher_resolution\trycodes_3_final_higher_resolution\data_final\f672\ffff672\concatenated_weights_40yr.csv")  # e.g. weights.csv
cvar_dual_df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Fully_incomplete_markets_ADMM\PSCC\PSCC_higher_resolution\trycodes_3_final_higher_resolution\dual_cvar_delta_0.1.csv")
prices_df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Fully_incomplete_markets_ADMM\PSCC\PSCC_higher_resolution\trycodes_3_final_higher_resolution\prices_delta_0.1_H2_15000_01.csv")
storage_dispacth_df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Fully_incomplete_markets_ADMM\PSCC\PSCC_higher_resolution\trycodes_3_final_higher_resolution\energy_charge_discharge_delta_0.1.csv")

# Filter the scenarios
scenarios = [27, 6, 29, 14, 10, 8, 7, 12, 17, 18, 22, 24, 23, 21, 2]
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
delta = 0.1
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
    if (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.90):
        power_capacity = 19.23405232  # MW
        energy_capacity = 4004.083593  # MWh
    elif (storage.lower() == "bess") and (delta == 0.90):
        power_capacity = 10.36543374  # MW
        energy_capacity = 162.1153836  # MWh
    elif (delta == 0.90):
        raise ValueError(f"Unknown storage type D090: {storage}")
    
    elif (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.80):
        power_capacity = 19.0124724  # MW
        energy_capacity = 3935.169165  # MWh
    elif (storage.lower() == "bess") and (delta == 0.80):
        power_capacity = 10.66525881  # MW
        energy_capacity = 166.0591623  # MWh
    elif (delta == 0.80):
        raise ValueError(f"Unknown storage type D080: {storage}")
    
    elif (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.70):
        power_capacity = 18.80761818  # MW
        energy_capacity = 3889.966734  # MWh
    elif (storage.lower() == "bess") and (delta == 0.70):
        power_capacity = 11.01086689  # MW
        energy_capacity = 169.5506346  # MWh
    elif (delta == 0.70):
        raise ValueError(f"Unknown storage type D070: {storage}")
    
    elif (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.60):
        power_capacity = 18.83061061  # MW
        energy_capacity = 3912.836907  # MWh
    elif (storage.lower() == "bess") and (delta == 0.60):
        power_capacity = 11.31571523  # MW
        energy_capacity = 172.1956665  # MWh
    elif (delta == 0.60):
        raise ValueError(f"Unknown storage type D060: {storage}")
    
    elif (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.50):
        power_capacity = 18.96428556  # MW
        energy_capacity = 3974.581419  # MWh
    elif (storage.lower() == "bess") and (delta == 0.50):
        power_capacity = 11.61677519  # MW
        energy_capacity = 176.7770141  # MWh
    elif (delta == 0.50):
        raise ValueError(f"Unknown storage type D050: {storage}")
    
    elif (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.40):
        power_capacity = 19.37674211  # MW
        energy_capacity = 3984.054698  # MWh
    elif (storage.lower() == "bess") and (delta == 0.40):
        power_capacity = 11.69619231  # MW
        energy_capacity = 177.9855352  # MWh
    elif (delta == 0.40):
        raise ValueError(f"Unknown storage type D040: {storage}")
    
    elif (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.30):
        power_capacity = 19.46736703  # MW
        energy_capacity = 3928.744703  # MWh
    elif (storage.lower() == "bess") and (delta == 0.30):
        power_capacity = 12.51498067  # MW
        energy_capacity = 190.4453581  # MWh
    elif (delta == 0.30):
        raise ValueError(f"Unknown storage type D030: {storage}")
    
    elif (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.20):
        power_capacity = 19.7268926  # MW
        energy_capacity = 3884.467205  # MWh
    elif (storage.lower() == "bess") and (delta == 0.20):
        power_capacity = 12.93346408  # MW
        energy_capacity = 196.8135839  # MWh
    elif (delta == 0.20):
        raise ValueError(f"Unknown storage type D020: {storage}")
    
    elif (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.10):
        power_capacity = 20.32294451  # MW
        energy_capacity = 3437.604266  # MWh
    elif (storage.lower() == "bess") and (delta == 0.10):
        power_capacity = 13.04058771  # MW
        energy_capacity = 212.6182778  # MWh
    elif (delta == 0.10):
        raise ValueError(f"Unknown storage type D010: {storage}")
    
    
        
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
































































# -*- coding: utf-8 -*-
"""
Created on Tue Aug  5 16:41:30 2025

@author: Andreas Makrides
"""

import pandas as pd
import numpy as np

# Load the duals and time weights CSV files
duals_df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Fully_incomplete_markets_ADMM\PSCC\PSCC_higher_resolution\trycodes_3_final_higher_resolution\scarcity_rent_delta_0.9.csv")  # e.g. duals.csv

#checking about bess
#duals_df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Fully_Incomplete\Results\scarcity_rent_binding_hours.csv")

weights_df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Fully_incomplete_markets_ADMM\PSCC\PSCC_higher_resolution\trycodes_3_final_higher_resolution\data_final\f672\ffff672\concatenated_weights_40yr.csv")  # e.g. weights.csv
cvar_dual_df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Fully_incomplete_markets_ADMM\PSCC\PSCC_higher_resolution\trycodes_3_final_higher_resolution\dual_cvar_delta_0.9.csv")
prices_df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Fully_incomplete_markets_ADMM\PSCC\PSCC_higher_resolution\trycodes_3_final_higher_resolution\prices_delta_0.9_H2_15000_09.csv")
storage_dispacth_df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Fully_incomplete_markets_ADMM\PSCC\PSCC_higher_resolution\trycodes_3_final_higher_resolution\energy_charge_discharge_delta_0.9.csv")

# Filter the scenarios
scenarios = [27, 6, 29, 14, 10, 8, 7, 12, 17, 18, 22, 24, 23, 21, 2]
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
delta = 0.9
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
    if (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.90):
        power_capacity = 19.23405232  # MW
        energy_capacity = 4004.083593  # MWh
    elif (storage.lower() == "bess") and (delta == 0.90):
        power_capacity = 10.36543374  # MW
        energy_capacity = 162.1153836  # MWh
    elif (delta == 0.90):
        raise ValueError(f"Unknown storage type D090: {storage}")
    
    elif (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.80):
        power_capacity = 19.0124724  # MW
        energy_capacity = 3935.169165  # MWh
    elif (storage.lower() == "bess") and (delta == 0.80):
        power_capacity = 10.66525881  # MW
        energy_capacity = 166.0591623  # MWh
    elif (delta == 0.80):
        raise ValueError(f"Unknown storage type D080: {storage}")
    
    elif (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.70):
        power_capacity = 18.80761818  # MW
        energy_capacity = 3889.966734  # MWh
    elif (storage.lower() == "bess") and (delta == 0.70):
        power_capacity = 11.01086689  # MW
        energy_capacity = 169.5506346  # MWh
    elif (delta == 0.70):
        raise ValueError(f"Unknown storage type D070: {storage}")
    
    elif (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.60):
        power_capacity = 18.83061061  # MW
        energy_capacity = 3912.836907  # MWh
    elif (storage.lower() == "bess") and (delta == 0.60):
        power_capacity = 11.31571523  # MW
        energy_capacity = 172.1956665  # MWh
    elif (delta == 0.60):
        raise ValueError(f"Unknown storage type D060: {storage}")
    
    elif (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.50):
        power_capacity = 18.96428556  # MW
        energy_capacity = 3974.581419  # MWh
    elif (storage.lower() == "bess") and (delta == 0.50):
        power_capacity = 11.61677519  # MW
        energy_capacity = 176.7770141  # MWh
    elif (delta == 0.50):
        raise ValueError(f"Unknown storage type D050: {storage}")
    
    elif (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.40):
        power_capacity = 19.37674211  # MW
        energy_capacity = 3984.054698  # MWh
    elif (storage.lower() == "bess") and (delta == 0.40):
        power_capacity = 11.69619231  # MW
        energy_capacity = 177.9855352  # MWh
    elif (delta == 0.40):
        raise ValueError(f"Unknown storage type D040: {storage}")
    
    elif (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.30):
        power_capacity = 19.46736703  # MW
        energy_capacity = 3928.744703  # MWh
    elif (storage.lower() == "bess") and (delta == 0.30):
        power_capacity = 12.51498067  # MW
        energy_capacity = 190.4453581  # MWh
    elif (delta == 0.30):
        raise ValueError(f"Unknown storage type D030: {storage}")
    
    elif (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.20):
        power_capacity = 19.7268926  # MW
        energy_capacity = 3884.467205  # MWh
    elif (storage.lower() == "bess") and (delta == 0.20):
        power_capacity = 12.93346408  # MW
        energy_capacity = 196.8135839  # MWh
    elif (delta == 0.20):
        raise ValueError(f"Unknown storage type D020: {storage}")
    
    elif (storage.lower() == "hydrogen" or storage.lower() == "h2") and (delta == 0.10):
        power_capacity = 20.32294451  # MW
        energy_capacity = 3437.604266  # MWh
    elif (storage.lower() == "bess") and (delta == 0.10):
        power_capacity = 13.04058771  # MW
        energy_capacity = 212.6182778  # MWh
    elif (delta == 0.10):
        raise ValueError(f"Unknown storage type D010: {storage}")
    
    
        
    # === Per-timestep scarcity revenue components ===
    revP = df["value"] * (processed_dual_discharge + processed_dual_charge) * power_capacity
    revE = df["value"] * processed_dual_energy * energy_capacity

    # === Binding classification ===
    # Use a small epsilon to treat near-zero duals as non-binding.
    eps = 1e-6
    bind_power  = (processed_dual_discharge > eps) | (processed_dual_charge > eps)
    bind_energy = (processed_dual_energy    > eps)

    only_power  =  bind_power & (~bind_energy)
    only_energy = (~bind_power) &  bind_energy
    both_bind   =  bind_power &  bind_energy

    # === Split scarcity revenues by category ===
    rev_scarcity_power_only  = (revP[only_power]).sum()
    rev_scarcity_energy_only = (revE[only_energy]).sum()
    rev_scarcity_both        = (revP[both_bind]).sum() + (revE[both_bind]).sum()

    # Sanity check: split should equal the total scarcity revenue constructed from your original formula
    rev_from_scarcity_total = (revP + revE).sum()
    assert np.isfinite(rev_from_scarcity_total), "Non-finite scarcity revenue encountered."
    # Optionally ensure near-equality (tolerate tiny FP noise)
    if not np.isclose(rev_from_scarcity_total,
                      rev_scarcity_power_only + rev_scarcity_energy_only + rev_scarcity_both,
                      rtol=1e-8, atol=1e-6):
        print("Warning: split totals do not add up exactly to overall scarcity revenue (floating-point tolerance).")

    # === Keep your per-scenario price-revenue calculation (unchanged) ===
    rev_from_prices = df["price_model"] * df["value"] * (df["Discharge"] - df["Charge"])

    # === Build per-scenario dataframe with the new split ===
    per_scenario_df = pd.DataFrame({
        "Scenario": df["Scenario"],
        "Storage": storage,
        # Total scarcity (P + E)
        "Rev_Scarcity_Total": revP + revE,
        # Split by category
        "Rev_Scarcity_PowerOnly":  np.where(only_power,  revP, 0.0),
        "Rev_Scarcity_EnergyOnly": np.where(only_energy, revE, 0.0),
        "Rev_Scarcity_Both_power_part":       np.where(both_bind,   revP + 0*revE, 0.0),
        "Rev_Scarcity_Both_energy_part":       np.where(both_bind,   0*revP + revE, 0.0),
        # If you also want to see the component-level contributions (optional):
        # "Rev_Scarcity_P": revP,
        # "Rev_Scarcity_E": revE,
        # Market-price revenue
        "Rev_Price": rev_from_prices
    })

    # === Per-scenario sums (across time) ===
    per_scenario_summary = (
        per_scenario_df
        .groupby(["Scenario", "Storage"], as_index=False)[
            ["Rev_Scarcity_Total",
             "Rev_Scarcity_PowerOnly",
             "Rev_Scarcity_EnergyOnly",
             "Rev_Scarcity_Both_power_part",
             "Rev_Scarcity_Both_energy_part",
             "Rev_Price"]
        ]
        .sum()
    )

    # === Print per-scenario values ===
    print(f"\n=== Per-Scenario Revenues for {storage} ===")
    print(per_scenario_summary)

    # === Also print averages across scenarios ===
    avg_total_scarcity   = per_scenario_summary["Rev_Scarcity_Total"].mean()
    avg_power_only       = per_scenario_summary["Rev_Scarcity_PowerOnly"].mean()
    avg_energy_only      = per_scenario_summary["Rev_Scarcity_EnergyOnly"].mean()
    avg_both_power_part             = per_scenario_summary["Rev_Scarcity_Both_power_part"].mean()
    avg_both_energy_part             = per_scenario_summary["Rev_Scarcity_Both_energy_part"].mean()
    avg_price            = per_scenario_summary["Rev_Price"].mean()

    print(f"\nAverage Scarcity Revenue (Total): {avg_total_scarcity}")
    print(f"  • Power-only binding:           {avg_power_only}")
    print(f"  • Energy-only binding:          {avg_energy_only}")
    print(f"  • Both binding power part:                 {avg_both_power_part}")
    print(f"  • Both binding energy part:                 {avg_both_energy_part}")
    print(f"Average Revenue from Market Prices: {avg_price}")

    # === Keep your aggregate dual-based rents dictionary (optional) ===
    results[storage] = {
        "Scarcity_Rent_discharge": scarcity_rent_discharge,
        "Scarcity_Rent_charge":    scarcity_rent_charge,
        "Scarcity_Rent_power":     scarcity_rent_power,
        "Scarcity_Rent_energy":    scarcity_rent_energy,
        "Scarcity_Rent_power only" :avg_power_only/power_capacity,
        "Scarcity_Rent_power both binding" :avg_both_power_part/power_capacity,
        "Scarcity_Rent_energy only" :avg_energy_only/energy_capacity,
        "Scarcity_Rent_energy both binding" :avg_both_energy_part/energy_capacity,
        # New split totals (useful to export)
        #"Split_PowerOnly":         rev_scarcity_power_only,
        #"Split_EnergyOnly":        rev_scarcity_energy_only,
        #"Split_Both":              rev_scarcity_both,
        #"Split_Total_Check":       rev_from_scarcity_total
    }

# Show the results
for storage, rents in results.items():
    print(f"\nStorage: {storage}")
    for rent_type, value in rents.items():
        print(f"{rent_type}: {value}")


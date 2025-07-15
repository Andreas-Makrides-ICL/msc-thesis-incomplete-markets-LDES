# -*- coding: utf-8 -*-
"""
Created on Thu Jun  5 10:31:29 2025

@author: Andreas Makrides
"""
# import pandas as pd

# # === Load data ===
# cf_df = pd.read_csv("concatenated_capacity_factors_40yr_lf.csv")
# load_df = pd.read_csv("concatenated_load_profiles_40yr.csv")

# # === Step 1: Summarize load ===
# load_summary = load_df.groupby("O")["value"].agg(["mean", "max", "std"]).rename(columns={
#     "mean": "load_mean", "max": "load_max", "std": "load_std"
# })
# load_summary["load_cv"] = load_summary["load_std"] / load_summary["load_mean"]

# # === Step 2: Summarize capacity factors by generator (PV, Wind) ===
# cf_stats = cf_df.pivot_table(index=["T", "O"], columns="G", values="value").reset_index()
# cf_summary = cf_stats.groupby("O").agg({
#     "PV": ["mean", "std"],
#     "Wind": ["mean", "std"]
# })
# cf_summary.columns = ["PV_mean", "PV_std", "Wind_mean", "Wind_std"]

# # === Step 3: Combine all metrics ===
# summary = load_summary.join(cf_summary)

# # === Step 4: Normalize for scoring
# for col in summary.columns:
#     summary[f"z_{col}"] = (summary[col] - summary[col].mean()) / summary[col].std()

# # === Step 5: Select diverse years (extremes + typicals)

# # Get extremes (high/low for load, PV, Wind, variability)
# extremes = pd.concat([
#     summary.nsmallest(2, "z_load_mean"),
#     summary.nlargest(2, "z_load_mean"),
#     summary.nsmallest(2, "z_PV_mean"),
#     summary.nlargest(2, "z_PV_mean"),
#     summary.nsmallest(2, "z_Wind_mean"),
#     summary.nlargest(2, "z_Wind_mean"),
#     summary.nsmallest(2, "z_load_cv"),
#     summary.nlargest(2, "z_load_cv")
# ])

# # Find "typical" years (z-scores near 0)
# typicals = summary[(summary.filter(like="z_").abs() < 0.6).all(axis=1)]
# typicals = typicals.sample(n=min(3, len(typicals)), random_state=1)

# # Combine and deduplicate
# selected_years = pd.Index(extremes.index.tolist() + typicals.index.tolist()).unique()

# # Output selected years
# print("Selected scenario years (O):", sorted(selected_years.tolist()))

# # Optionally: save the summary table for reference
# summary.loc[selected_years].to_csv("selected_scenario_summary.csv")



import pandas as pd

# === Load full datasets ===
cf_df = pd.read_csv("concatenated_capacity_factors_40yr_lf.csv")
load_df = pd.read_csv("concatenated_load_profiles_40yr.csv")
weights_df = pd.read_csv("concatenated_weights_40yr.csv")

# === List of selected scenario IDs (O values) ===
selected_years = [1, 3, 4, 5, 6, 13, 14, 15, 18, 21, 31, 33, 40]  # ← Update if your selected list changes

# === Filter each dataset ===
cf_selected = cf_df[cf_df["O"].isin(selected_years)].copy()
load_selected = load_df[load_df["O"].isin(selected_years)].copy()
weights_selected = weights_df[weights_df["O"].isin(selected_years)].copy()

# === Save filtered versions ===
cf_selected.to_csv("selected_capacity_factors.csv", index=False)
load_selected.to_csv("selected_load_profiles.csv", index=False)
weights_selected.to_csv("selected_weights.csv", index=False)
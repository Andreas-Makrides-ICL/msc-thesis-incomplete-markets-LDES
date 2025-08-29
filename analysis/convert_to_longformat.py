# -*- coding: utf-8 -*-
"""
Created on Thu Jun  5 10:20:19 2025

@author: Andreas Makrides
"""

import pandas as pd

# Load your data
# Update accordingly
df = pd.read_csv("...\concatenated_capacity_factors.csv")  # Replace with your actual filename

# Convert from wide to long format
long_df = df.melt(id_vars=["Y", "T"], var_name="G", value_name="value")

# Rename columns
long_df = long_df.rename(columns={"Y": "O"})

# Save to new CSV
# Update accordingly
long_df.to_csv("...\concatenated_capacity_factors_lf.csv", index=False)

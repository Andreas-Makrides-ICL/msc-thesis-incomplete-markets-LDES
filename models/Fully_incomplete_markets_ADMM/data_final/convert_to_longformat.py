# -*- coding: utf-8 -*-
"""
Created on Thu Jun  5 10:20:19 2025

@author: Andreas Makrides
"""

import pandas as pd

# Load your data
df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Fully_incomplete_markets_ADMM\data_final\concatenated_capacity_factors_672_30yr_new.csv") # Replace with your actual filename

# Convert from wide to long format
long_df = df.melt(id_vars=["Y", "T"], var_name="G", value_name="value")

# Rename columns
long_df = long_df.rename(columns={"Y": "O"})

# Save to new CSV
long_df.to_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Fully_incomplete_markets_ADMM\data_final\concatenated_capacity_factors_672_30yr_new_lf.csv", index=False)

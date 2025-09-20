import pandas as pd
import numpy as np

def equalize_annual_energy_with_peak_one(
    df,
    year_col="Y",
    time_col="T",
    value_col="value",
    target_annual_sum=None,   # If None, use mean of current annual sums
    make_new_column=False,     # If True, writes to 'value_adjusted'; else overwrites 'value'
    tol=1e-9
):
    """
    For each year (scenario), apply an affine transform q = a*p + b that:
      - preserves the peak at 1,
      - makes the annual sum equal to a common target S*.

    If `target_annual_sum` is None, S* is the mean of annual sums across all years.

    Returns: (df_out, info)
      df_out: copy of df with adjusted values in 'value_adjusted' (or overwriting 'value')
      info:   dict with diagnostics per year and global summary
    """
    # Basic checks
    if not {year_col, time_col, value_col}.issubset(df.columns):
        missing = {year_col, time_col, value_col} - set(df.columns)
        raise ValueError(f"Missing required columns: {missing}")

    df = df.copy()

    # ---- FIXED: use named aggregations; always returns a DataFrame ----
    per_year = df.groupby(year_col, sort=False).agg(
        annual_sum=(value_col, "sum"),
        n_hours=(time_col, "count"),
        peak=(value_col, "max"),
    ).copy()

    # Choose target S*
    if target_annual_sum is None:
        S_star = per_year["annual_sum"].mean()
        target_source = "mean of existing annual sums"
    else:
        S_star = float(target_annual_sum)
        target_source = "user-specified"

    # Prepare outputs / diagnostics
    per_year["a"] = np.nan
    per_year["b"] = np.nan
    per_year["feasible"] = True
    per_year["reason"] = ""

    # Compute a and b per year
    for y, row in per_year.iterrows():
        S = row["annual_sum"]
        n = int(row["n_hours"])
        peak = row["peak"]

        # Sanity: peak should be 1 for a normalized profile
        if not (abs(peak - 1.0) <= 1e-6):
            # We proceed anyway, but note it
            per_year.at[y, "reason"] += f"Peak not exactly 1 (={peak:.6f}); "

        denom = (S - n)
        if abs(denom) < tol:
            # Flat-at-1 case (or numerically indistinguishable)
            if abs(S_star - n) < 1e-6:
                # Only possible solution is identity: a=1, b=0
                a = 1.0
                b = 0.0
            else:
                per_year.at[y, "feasible"] = False
                per_year.at[y, "reason"] += (
                    f"Profile sum equals n={n} (flat at 1). Cannot match S*={S_star:.6f} while keeping peak=1. "
                    "Leaving this year unchanged."
                )
                a = 1.0
                b = 0.0
        else:
            a = (S_star - n) / denom
            b = 1.0 - a

        per_year.at[y, "a"] = a
        per_year.at[y, "b"] = b

    # Apply transform
    out_col = "value_adjusted" if make_new_column else value_col
    df[out_col] = df[value_col]  # initialize

    def _apply_group(g):
        y = g[year_col].iloc[0]
        a = per_year.at[y, "a"]
        b = per_year.at[y, "b"]
        q = a * g[value_col].to_numpy() + b

        # Check for negatives (very rare for realistic normalized demand)
        if (q < -1e-12).any():
            per_year.at[y, "feasible"] = False
            per_year.at[y, "reason"] += "Affine transform produced negatives; values clipped to 0 (sum may deviate slightly). "
            q = np.maximum(q, 0.0)

        # Peak should be exactly 1 by construction; enforce tiny numerical robustness:
        # (do NOT clip generally, as that would change the sum; just small rounding at 1+eps)
        q = np.where(q > 1 + 1e-12, 1.0, q)

        g[out_col] = q
        return g

    df = df.groupby(year_col, group_keys=False).apply(_apply_group)

    # Verify results
    verify = df.groupby(year_col)[out_col].agg(annual_sum="sum", peak="max").round(10)
    verify["n_hours"] = df.groupby(year_col)[time_col].count()
    verify["target_S*"] = round(S_star, 10)

    # Global summary
    info = {
        "target_annual_sum": S_star,
        "target_source": target_source,
        "per_year_parameters": per_year.round(6).to_dict(orient="index"),
        "verification": verify.to_dict(orient="index"),
    }

    return df, info


# -----------------------------
# Example usage:
df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Complete_markets_risk_averse_central_planner\data_final\data_preparation_new\data_preparation_same_maximum_welfare\clustering_new\sampled_normalized_data_40.csv")  # expects columns: Y, T, value
df_adj, diag = equalize_annual_energy_with_peak_one(df, target_annual_sum=None, make_new_column=True)
print("Target annual sum (S*):", diag["target_annual_sum"], f"({diag['target_source']})")
print(pd.DataFrame.from_dict(diag["verification"], orient="index"))
#The adjusted profile is in df_adj['value_adjusted']

# 1) Save the adjusted time series (all years stacked)
df_adj.to_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Complete_markets_risk_averse_central_planner\data_final\data_preparation_new\data_preparation_same_maximum_welfare\clustering_new\sampled_normalized_data_40_adjusted.csv", index=False)

# 2) (Optional) Save a compact verification table per year
verify_df = (
    pd.DataFrame.from_dict(diag["verification"], orient="index")
    .reset_index()
    .rename(columns={"index": "Y"})
)
verify_df.to_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Complete_markets_risk_averse_central_planner\data_final\data_preparation_new\data_preparation_same_maximum_welfare\clustering_new\sampled_normalized_data_40_adjusted_verification.csv", index=False)

# 3) (Optional) Save the affine parameters (a, b) used per year
params_df = (
    pd.DataFrame.from_dict(diag["per_year_parameters"], orient="index")
    .reset_index()
    .rename(columns={"index": "Y"})
)
params_df.to_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Extra\Complete_markets_risk_averse_central_planner\data_final\data_preparation_new\data_preparation_same_maximum_welfare\clustering_new\sampled_normalized_data_40_adjusted_parameters.csv", index=False)

print("Saved:")
print(" - your_file_adjusted.csv")
print(" - your_file_adjusted_verification.csv")
print(" - your_file_adjusted_parameters.csv")

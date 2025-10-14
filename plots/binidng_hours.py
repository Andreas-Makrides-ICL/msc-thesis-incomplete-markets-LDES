import pandas as pd
import numpy as np


COL_SCEN, COL_TIME, COL_TECH = "Scenario", "Time", "Storage"
DUAL_CHARGE, DUAL_DISCH, DUAL_SOCU = "Dual_charge", "Dual_discharge", "Dual_energy"
TOL = 1e-6

# === load & flag ===
df = pd.read_csv(r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Fully_Incomplete\Results\scarcity_rent_delta_0.5.csv")


bind = lambda s: (s.abs() > TOL).astype(int)
for c in [DUAL_CHARGE, DUAL_DISCH, DUAL_SOCU]:
    df[c+"_b"] = bind(df[c])

# === pairwise “both binding” counts (per scenario & tech) ===
by = [COL_SCEN, COL_TECH]
out = (
    df.assign(
        both_charge_soc = df[f"{DUAL_CHARGE}_b"] & df[f"{DUAL_SOCU}_b"],
    )
    .groupby(by, as_index=False)
    .agg(
        hours_both_charge_soc = ("both_charge_soc", "sum"),
    )
)

print(out.to_string(index=False))





import pandas as pd
import numpy as np

# --- config (your headers) ---
COL_SCEN, COL_TIME, COL_TECH = "Scenario", "Time", "Storage"
DUAL_CHARGE, DUAL_DISCH, DUAL_SOCU = "Dual_charge", "Dual_discharge", "Dual_energy"
TOL = 1e-6
PATH = r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Fully_Incomplete\Results\scarcity_rent_delta_0.5.csv"

df = pd.read_csv(PATH)

# 1) flag each dual as binding
for c in (DUAL_CHARGE, DUAL_DISCH, DUAL_SOCU):
    df[c+"_b"] = (df[c].abs() > TOL).astype(int)

# 2) “both binding” indicator (choose one)
both = (df[f"{DUAL_CHARGE}_b"] & df[f"{DUAL_SOCU}_b"]).astype(int)     # specific pair: charge & SOC
# both = (df[[f"{DUAL_CHARGE}_b", f"{DUAL_DISCH}_b", f"{DUAL_SOCU}_b"]].sum(axis=1) >= 2).astype(int)  # any two+

df["both_binding"] = both

# 3) zero out desired columns when NOT both-binding
cols_to_zero = [DUAL_CHARGE, DUAL_DISCH, DUAL_SOCU]  # add rent cols here if needed, e.g. "Scarcity_rent"
df[cols_to_zero] = df[cols_to_zero].where(df["both_binding"].eq(1), 0.0)

# (optional) keep only BESS rows
# df = df[df[COL_TECH] == "BESS"]

print(df.head())

OUT_PATH = r"C:\Users\user\Desktop\msc-thesis-incomplete-markets-LDES\models\Fully_Incomplete\Results\scarcity_rent_binding_hours.csv"
df.to_csv(OUT_PATH, index=False)


import numpy as np
from scipy.optimize import fsolve

def implied_wacc(Cinv_net, Cinv_riskfree, N, WACC):
    """
    Solve for implied WACC Rm given:
    - Cinv_net: net revenue
    - Cinv_riskfree: annualized investment cost at risk-free rate
    - N: lifetime in years
    Returns:
    - Rm (implied WACC) as a percentage
    """
    def present_value_diff(Rm):
        lhs = np.sum([Cinv_net / ((1 + Rm) ** n) for n in range(1, N + 1)])
        rhs = np.sum([Cinv_riskfree / ((1 + WACC) ** n) for n in range(1, N + 1)])  # Rf = 4%
        return lhs - rhs

    Rm_guess = 0.05  # initial guess of 5%
    Rm_solution = fsolve(present_value_diff, Rm_guess)[0]
    return Rm_solution

delta=0.9

if (delta == 0.90):
    h2p = 19.23405232  # MW
    h2e = 4004.083593  # MWh
    bessp = 10.36543374  # MW
    besse = 162.1153836  # MWh

elif (delta == 0.80):
    h2p = 19.0124724  # MW
    h2e = 3935.169165  # MWh
    bessp = 10.66525881  # MW
    besse = 166.0591623  # MWh

elif (delta == 0.70):
    h2p = 18.80761818  # MW
    h2e = 3889.966734  # MWh
    bessp = 11.01086689  # MW
    besse = 169.5506346  # MWh

elif (delta == 0.60):
    h2p = 18.83061061  # MW
    h2e = 3912.836907  # MWh
    bessp = 11.31571523  # MW
    besse = 172.1956665  # MWh

elif (delta == 0.50):
    h2p = 18.96428556  # MW
    h2e = 3974.581419  # MWh
    bessp = 11.61677519  # MW
    besse = 176.7770141  # MWh

elif (delta == 0.40):
    h2p = 19.37674211  # MW
    h2e = 3984.054698  # MWh
    bessp = 11.69619231  # MW
    besse = 177.9855352  # MWh

elif (delta == 0.30):
    h2p = 19.46736703  # MW
    h2e = 3928.744703  # MWh
    bessp = 12.51498067  # MW
    besse = 190.4453581  # MWh

elif (delta == 0.20):
    h2p = 19.7268926  # MW
    h2e = 3884.467205  # MWh
    bessp = 12.93346408  # MW
    besse = 196.8135839  # MWh

elif (delta == 0.10):
    h2p = 20.32294451  # MW
    h2e = 3437.604266  # MWh
    bessp = 13.04058771  # MW
    besse = 212.6182778  # MWh


example_Rm_for_BESS_P = implied_wacc(Cinv_net=, Cinv_riskfree=, N=20, WACC=0.06)
example_Rm_for_BESS_E = implied_wacc(Cinv_net=, Cinv_riskfree=, N=20, WACC=0.06)
example_Rm_for_LDES_P = implied_wacc(Cinv_net=, Cinv_riskfree=, N=18, WACC=0.07)
example_Rm_for_LDES_E = implied_wacc(Cinv_net=, Cinv_riskfree=, N=18, WACC=0.07)


print("Implied WACC for BESS Power", example_Rm_for_BESS_P)
print("Implied WACC for BESS Energy", example_Rm_for_BESS_E)
print("Implied WACC for LDES Power", example_Rm_for_LDES_P)
print("Implied WACC for LDES Energy", example_Rm_for_LDES_E)




import pandas as pd

# Data
data = {
    "delta": [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1],
    "bess": [250014.6433, 256351.8912, 261429.6652, 266542.4118, 273873.2651,
             281845.2059, 288769.3315, 303422.149, 381586.5501],
    "bess_risk_free": [248418.5041, 247543.8835, 245396.4542, 243130.5168, 243130.5171,
                       243130.5168, 243130.5168, 243130.5168, 256731.3075],
    "h2": [482483.4893, 503764.9792, 527302.2218, 553790.1429, 581890.3868,
           611152.9728, 650243.5569, 687660.7917, 771816.6157],
    "h2_risk_free": [452444.4057, 451920.1591, 451854.9908, 452275.7755, 453059.2555,
                     451321.7068, 449660.2606, 447517.1234, 435373.0083]
}

df = pd.DataFrame(data)
bess_list = []
ldes_list = []

# Loop through each row and call your lines
for i, row in df.iterrows():
    example_Rm_for_BESS = implied_wacc(Cinv_net=row["bess"], Cinv_riskfree=row["bess_risk_free"], N=20, WACC=0.06)
    example_Rm_for_LDES = implied_wacc(Cinv_net=row["h2"], Cinv_riskfree=row["h2_risk_free"], N=18, WACC=0.07)
    
    bess_list.append(100*example_Rm_for_BESS)
    ldes_list.append(100*example_Rm_for_LDES)
    
    print(f"Δ = {row['delta']:.1f}")
    print("  Implied WACC for BESS:", example_Rm_for_BESS)
    print("  Implied WACC for LDES:", example_Rm_for_LDES)
    print()
print("BESS=",bess_list)
print("H2=",ldes_list)











# Example usage

#example_Rm_for_Windon = implied_wacc(Cinv_net=248244.7875, Cinv_riskfree=127857.772, N=30, WACC=0.061)
example_Rm_for_Windoff = implied_wacc(Cinv_net=1000, Cinv_riskfree=1000, N=30, WACC=0.065)
#example_Rm_for_Nuclear = implied_wacc(Cinv_net=5.980748415914494e6, Cinv_riskfree=607878.207, N=60, WACC=0.07)
#example_Rm_for_Gas = implied_wacc(Cinv_net=2.34E+05, Cinv_riskfree=131972.621, N=25, WACC=0.07)
example_Rm_for_Gas_CCS = implied_wacc(Cinv_net=1367638.3643, Cinv_riskfree=342431.552, N=25, WACC=0.07)
example_Rm_for_PV = implied_wacc(Cinv_net=146006.8569, Cinv_riskfree=84023.611, N=20, WACC=0.062)


print("Implied WACC for PV", example_Rm_for_PV)
#print("Implied WACC for Wind Onshore", example_Rm_for_Windon)
print("Implied WACC for Wind Offshore", example_Rm_for_Windoff)
#print("Implied WACC for Nuclear", example_Rm_for_Nuclear)
#print("Implied WACC for Gas", example_Rm_for_Gas)
print("Implied WACC for Gas_CCS", example_Rm_for_Gas_CCS)



example_Rm_for_BESS_P = implied_wacc(Cinv_net=45104.202746532865, Cinv_riskfree=52719.44431, N=20, WACC=0.06)
example_Rm_for_BESS_E = implied_wacc(Cinv_net=13456.440246560333, Cinv_riskfree=13600.79089, N=20, WACC=0.06)
example_Rm_for_LDES_P = implied_wacc(Cinv_net=374262.8773705063, Cinv_riskfree=361384.6546, N=18, WACC=0.07)
example_Rm_for_LDES_E = implied_wacc(Cinv_net=4000, Cinv_riskfree=795.3008133, N=18, WACC=0.07)


print("Implied WACC for BESS Power", example_Rm_for_BESS_P)
print("Implied WACC for BESS Energy", example_Rm_for_BESS_E)
print("Implied WACC for LDES Power", example_Rm_for_LDES_P)
print("Implied WACC for LDES Energy", example_Rm_for_LDES_E)



example_Rm_for_BESS = implied_wacc(Cinv_net=381586.5501, Cinv_riskfree=251566.769, N=20, WACC=0.06)
example_Rm_for_LDES = implied_wacc(Cinv_net=771816.6157, Cinv_riskfree=453144.5068, N=18, WACC=0.07)
print("Implied WACC for BESS", example_Rm_for_BESS)
print("Implied WACC for LDES", example_Rm_for_LDES)



# this is for risk neutral
example_Rm_for_LDES_P = implied_wacc(Cinv_net=391384.22369767685, Cinv_riskfree=391384.6546, N=18, WACC=0.07)
example_Rm_for_LDES_E = implied_wacc(Cinv_net=1529.0166608637733, Cinv_riskfree=1491.189025, N=18, WACC=0.07)
example_Rm_for_BESS_P = implied_wacc(Cinv_net=52719.38628526274, Cinv_riskfree=52719.44431, N=20, WACC=0.06)
example_Rm_for_BESS_E = implied_wacc(Cinv_net=17531.841672185743, Cinv_riskfree=17524.09595, N=20, WACC=0.06)



print("Implied WACC for PV", example_Rm_for_PV)
print("Implied WACC for Wind Onshore", example_Rm_for_Windon)
print("Implied WACC for Wind Offshore", example_Rm_for_Windoff)
print("Implied WACC for Nuclear", example_Rm_for_Nuclear)
print("Implied WACC for Gas", example_Rm_for_Gas)
print("Implied WACC for LDES Power", example_Rm_for_LDES_P)
print("Implied WACC for LDES Energy", example_Rm_for_LDES_E)
print("Implied WACC for BESS Power", example_Rm_for_BESS_P)
print("Implied WACC for BESS Energy", example_Rm_for_BESS_E)

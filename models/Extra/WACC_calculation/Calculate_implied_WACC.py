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

# Example usage

#example_Rm_for_Windon = implied_wacc(Cinv_net=248244.7875, Cinv_riskfree=127857.772, N=30, WACC=0.061)
example_Rm_for_Windoff = implied_wacc(Cinv_net=552381.5182, Cinv_riskfree=272985.861, N=30, WACC=0.065)
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
example_Rm_for_LDES_E = implied_wacc(Cinv_net=833.3859854615777, Cinv_riskfree=795.3008133, N=18, WACC=0.07)


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

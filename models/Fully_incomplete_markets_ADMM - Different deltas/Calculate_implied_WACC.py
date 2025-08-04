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
example_Rm_for_PV = implied_wacc(Cinv_net=101790.3971, Cinv_riskfree=103561.363, N=25, WACC=0.062)
example_Rm_for_Windon = implied_wacc(Cinv_net=225164.9301, Cinv_riskfree=125438.907, N=30, WACC=0.061)
example_Rm_for_Windoff = implied_wacc(Cinv_net=288294.8142, Cinv_riskfree=339025.541, N=30, WACC=0.065)
example_Rm_for_Nuclear = implied_wacc(Cinv_net=1275129.9188, Cinv_riskfree=607878.207, N=60, WACC=0.07)
example_Rm_for_Gas = implied_wacc(Cinv_net=87236.01694, Cinv_riskfree=426127.988, N=25, WACC=0.07)

example_Rm_for_LDES_P = implied_wacc(Cinv_net=386388.4023, Cinv_riskfree=391384.6546, N=18, WACC=0.07)
example_Rm_for_LDES_E = implied_wacc(Cinv_net=1238.145663, Cinv_riskfree=1491.189025, N=18, WACC=0.07)
example_Rm_for_BESS_P = implied_wacc(Cinv_net=225.4615873, Cinv_riskfree=52719.44431, N=20, WACC=0.06)
example_Rm_for_BESS_E = implied_wacc(Cinv_net=21233.24583, Cinv_riskfree=17524.09595, N=20, WACC=0.06)

print("Implied WACC for PV", example_Rm_for_PV)
print("Implied WACC for Wind Onshore", example_Rm_for_Windon)
print("Implied WACC for Wind Offshore", example_Rm_for_Windoff)
print("Implied WACC for Nuclear", example_Rm_for_Nuclear)
print("Implied WACC for Gas", example_Rm_for_Gas)
print("Implied WACC for LDES Power", example_Rm_for_LDES_P)
print("Implied WACC for LDES Energy", example_Rm_for_LDES_E)
print("Implied WACC for BESS Power", example_Rm_for_BESS_P)
print("Implied WACC for BESS Energy", example_Rm_for_BESS_E)

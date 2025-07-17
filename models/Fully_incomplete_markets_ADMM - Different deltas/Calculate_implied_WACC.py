import numpy as np
from scipy.optimize import fsolve

def implied_wacc(Cinv_net, Cinv_riskfree, N, WACC):
    """
    Solve for implied WACC Rm given:
    - Cinv_net: net revenue per year from the risk-averse model ($/MW-year)
    - Cinv_riskfree: annualized investment cost at risk-free rate ($/MW-year)
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
    return Rm_solution * 100  # convert to percentage

# Example usage

example_Rm_for_PV = implied_wacc(Cinv_net=, Cinv_riskfree=5871231.104, N=30, WACC=0.03)
example_Rm_for_Windon = implied_wacc(Cinv_net=, Cinv_riskfree= 5599436.756, N=25, WACC=0.035)
example_Rm_for_Windoff = implied_wacc(Cinv_net=, Cinv_riskfree=13203248.55, N=30, WACC=0.04)
example_Rm_for_Nuclear = implied_wacc(Cinv_net=, Cinv_riskfree=2484411.684, N=60, WACC=0.047)
example_Rm_for_Gas = implied_wacc(Cinv_net=, Cinv_riskfree=6204974.02, N=25, WACC=0.07)
example_Rm_for_LDES = implied_wacc(Cinv_net=, Cinv_riskfree=5129341.161, N=40, WACC=0.035)
example_Rm_for_BESS = implied_wacc(Cinv_net=, Cinv_riskfree=16961.38387, N=15, WACC=0.06)

print("Implied WACC for PV", example_Rm_for_PV)
print("Implied WACC for Wind Onshore", example_Rm_for_Windon)
print("Implied WACC for Wind Offshore", example_Rm_for_Windoff)
print("Implied WACC for Nuclear", example_Rm_for_Nuclear)
print("Implied WACC for Gas", example_Rm_for_Gas)
print("Implied WACC for LDES", example_Rm_for_LDES)
print("Implied WACC for BESS", example_Rm_for_BESS)
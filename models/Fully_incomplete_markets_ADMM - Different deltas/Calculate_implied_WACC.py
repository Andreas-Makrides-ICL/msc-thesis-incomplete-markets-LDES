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
    return Rm_solution

# Example usage
#0.75
example_Rm_for_PV = implied_wacc(Cinv_net=14654878.9478394, Cinv_riskfree=13931806.898, N=25, WACC=0.062)
example_Rm_for_Windon = implied_wacc(Cinv_net=12013415.7775119, Cinv_riskfree= 6509745.581, N=30, WACC=0.061)
example_Rm_for_Windoff = implied_wacc(Cinv_net=27424957.4295909, Cinv_riskfree=31669167.794, N=30, WACC=0.065)
example_Rm_for_Nuclear = implied_wacc(Cinv_net=5653658.77235569, Cinv_riskfree=2431509.189, N=60, WACC=0.07)
example_Rm_for_Gas = implied_wacc(Cinv_net=10752739.5415318, Cinv_riskfree=20743922.010, N=25, WACC=0.07)
example_Rm_for_LDES = implied_wacc(Cinv_net=2395544.34772416, Cinv_riskfree=2575367.058, N=18, WACC=0.07)
example_Rm_for_BESS = implied_wacc(Cinv_net=3362979.19633211, Cinv_riskfree=3009084.101, N=20, WACC=0.06)

print("Implied WACC for PV", example_Rm_for_PV)
print("Implied WACC for Wind Onshore", example_Rm_for_Windon)
print("Implied WACC for Wind Offshore", example_Rm_for_Windoff)
print("Implied WACC for Nuclear", example_Rm_for_Nuclear)
print("Implied WACC for Gas", example_Rm_for_Gas)
print("Implied WACC for LDES", example_Rm_for_LDES)
print("Implied WACC for BESS", example_Rm_for_BESS)

#0.50
example_Rm_for_PV = implied_wacc(Cinv_net=13799965.2170157, Cinv_riskfree=13931806.898, N=25, WACC=0.062)
example_Rm_for_Windon = implied_wacc(Cinv_net=11522861.6142249, Cinv_riskfree= 6509745.581, N=30, WACC=0.061)
example_Rm_for_Windoff = implied_wacc(Cinv_net=26513570.4676637, Cinv_riskfree=31669167.794, N=30, WACC=0.065)
example_Rm_for_Nuclear = implied_wacc(Cinv_net=5135386.92689675, Cinv_riskfree=2431509.189, N=60, WACC=0.07)
example_Rm_for_Gas = implied_wacc(Cinv_net=4967323.95898848, Cinv_riskfree=20743922.010, N=25, WACC=0.07)
example_Rm_for_LDES = implied_wacc(Cinv_net=2697660.6642398, Cinv_riskfree=2575367.058, N=18, WACC=0.07)
example_Rm_for_BESS = implied_wacc(Cinv_net=2813182.90661901, Cinv_riskfree=3009084.101, N=20, WACC=0.06)

print("Implied WACC for PV", example_Rm_for_PV)
print("Implied WACC for Wind Onshore", example_Rm_for_Windon)
print("Implied WACC for Wind Offshore", example_Rm_for_Windoff)
print("Implied WACC for Nuclear", example_Rm_for_Nuclear)
print("Implied WACC for Gas", example_Rm_for_Gas)
print("Implied WACC for LDES", example_Rm_for_LDES)
print("Implied WACC for BESS", example_Rm_for_BESS)

#0.25
example_Rm_for_PV = implied_wacc(Cinv_net=13810448.8160794, Cinv_riskfree=13931806.898, N=25, WACC=0.062)
example_Rm_for_Windon = implied_wacc(Cinv_net=11531175.7957445, Cinv_riskfree= 6509745.581, N=30, WACC=0.061)
example_Rm_for_Windoff = implied_wacc(Cinv_net=26575618.5137309, Cinv_riskfree=31669167.794, N=30, WACC=0.065)
example_Rm_for_Nuclear = implied_wacc(Cinv_net=5100723.63860877, Cinv_riskfree=2431509.189, N=60, WACC=0.07)
example_Rm_for_Gas = implied_wacc(Cinv_net=4317043.78688742, Cinv_riskfree=20743922.010, N=25, WACC=0.07)
example_Rm_for_LDES = implied_wacc(Cinv_net=2759541.16775282, Cinv_riskfree=2575367.058, N=18, WACC=0.07)
example_Rm_for_BESS = implied_wacc(Cinv_net=2761606.10009699, Cinv_riskfree=3009084.101, N=20, WACC=0.06)

print("Implied WACC for PV", example_Rm_for_PV)
print("Implied WACC for Wind Onshore", example_Rm_for_Windon)
print("Implied WACC for Wind Offshore", example_Rm_for_Windoff)
print("Implied WACC for Nuclear", example_Rm_for_Nuclear)
print("Implied WACC for Gas", example_Rm_for_Gas)
print("Implied WACC for LDES", example_Rm_for_LDES)
print("Implied WACC for BESS", example_Rm_for_BESS)
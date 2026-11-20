# *************************************************************************
#  Model SBM (aggregate)
#  A two-money world: PC (state money) + BMW (bank money), closed economy
#  Sources: Godley & Lavoie, Monetary Economics, chapters 4 and 7
#  Author: Marco Veronese Passarella
#  Last change: 20/11/2026
# *************************************************************************

# Clear environment
rm(list = ls(all = TRUE))

# Set model parameters ####
nPeriods    <- 200         # Periods
nScenarios  <- 2           # 1 baseline, 2 higher government spending
shockStart  <- 101         # Period at which the shock hits
alpha10     <- 0.68        # Propensity to consume out of disposable income: autonomous component
alpha11     <- 4           # Propensity to consume out of disposable income: sensitivity to the interest rate
alpha2      <- 0.1         # Propensity to consume out of wealth
lambda10    <- 0.25        # Portfolio: autonomous share of bills
lambda11    <- 1           # Portfolio: sensitivity of bills to interest rate
lambdac     <- 0.2         # Cash to (lagged) consumption ratio
theta       <- 0.2         # Average tax rate on income
delta       <- 0.1         # Depreciation rate
gamma       <- 0.1         # Speed of adjustment of capital to its target
kappa       <- 1.5         # Target capital-output ratio
pr          <- 1           # Labour productivity
Gbase       <- 20          # Government spending (baseline)
Gshock      <- 25          # Government spending (scenario 2)
psi         <- 1           # Fiscal rule: share of the extra interest bill offset by lower spending
rbar        <- 0.02        # Fiscal rule: reference interest rate

# Create the variables as matrices [scenario, period], all starting at zero ####

# A) Households
YD    <- matrix(0, nScenarios, nPeriods)  # Disposable income
C     <- matrix(0, nScenarios, nPeriods)  # Consumption
alpha1<- matrix(0, nScenarios, nPeriods)  # Propensity to consume out of disposable income
V     <- matrix(0, nScenarios, nPeriods)  # Net wealth
H_h   <- matrix(0, nScenarios, nPeriods)  # Cash held by households
B_h   <- matrix(0, nScenarios, nPeriods)  # Bills held by households
M_h   <- matrix(0, nScenarios, nPeriods)  # Bank deposits held by households

# B) Firms
Y     <- matrix(0, nScenarios, nPeriods)  # Output / income (GDP)
WB    <- matrix(0, nScenarios, nPeriods)  # Wage bill
N     <- matrix(0, nScenarios, nPeriods)  # Employment
w     <- matrix(0, nScenarios, nPeriods)  # Wage rate
I     <- matrix(0, nScenarios, nPeriods)  # Gross investment
K     <- matrix(0, nScenarios, nPeriods)  # Capital stock
KT    <- matrix(0, nScenarios, nPeriods)  # Target capital stock
DA    <- matrix(0, nScenarios, nPeriods)  # Depreciation allowances
AF    <- matrix(0, nScenarios, nPeriods)  # Amortisation funds
L_d   <- matrix(0, nScenarios, nPeriods)  # Demand for bank loans

# C) Banks
L_s   <- matrix(0, nScenarios, nPeriods)  # Supply of bank loans
M_s   <- matrix(0, nScenarios, nPeriods)  # Supply of bank deposits
B_b   <- matrix(0, nScenarios, nPeriods)  # Bills held by banks (if < 0, CB advances)
FB    <- matrix(0, nScenarios, nPeriods)  # Bank profits (distributed to households)

# D) Government and central bank
TAX   <- matrix(0, nScenarios, nPeriods)  # Taxes
PSBR  <- matrix(0, nScenarios, nPeriods)  # Public sector borrowing requirement
B_s   <- matrix(0, nScenarios, nPeriods)  # Bills supplied by government
B_cb  <- matrix(0, nScenarios, nPeriods)  # Bills held by central bank
F_cb  <- matrix(0, nScenarios, nPeriods)  # Central bank profits
H_s   <- matrix(0, nScenarios, nPeriods)  # Cash supplied by central bank

# Exogenous variables as matrices (so they can take scenario-specific shocks) ####
G0  <- matrix(Gbase, nScenarios, nPeriods)  # Government spending, exogenous component
G   <- matrix(Gbase, nScenarios, nPeriods)  # Government spending
rb  <- matrix(0.02,  nScenarios, nPeriods)  # Interest rate on bills (policy rate)
rm  <- matrix(0.02,  nScenarios, nPeriods)  # Interest rate on deposits
rl  <- matrix(0.02,  nScenarios, nPeriods)  # Interest rate on loans

# Loop over scenarios ####
for (j in 1:nScenarios) {

  # Time loop
  for (i in 2:nPeriods) {

    # Shocks ####
    if (i >= shockStart && j == 2) G0[j, i] <- Gshock        # higher government spending

    # Solve the SIMULTANEOUS equations by iteration
    for (iter in 1:100) {

      # A) HOUSEHOLDS ####
      YD[j, i]   = WB[j, i] - TAX[j, i] +
        rb[j, i - 1] * B_h[j, i - 1] + rm[j, i - 1] * M_h[j, i - 1] + FB[j, i]  # Disposable income (1)
      TAX[j, i]  = theta * (WB[j, i] + FB[j, i] + rb[j, i - 1] * B_h[j, i - 1] +
        rm[j, i - 1] * M_h[j, i - 1])                                        # Taxes on household income (2)
      V[j, i]    = V[j, i - 1] + (YD[j, i] - C[j, i])                       # Wealth accumulation (3)
      alpha1[j, i] = alpha10 - alpha11 * rb[j, i - 1]               # Propensity to consume and interest rate (4)
      C[j, i]    = alpha1[j, i] * YD[j, i] + alpha2 * V[j, i - 1]           # Consumption (5)
      H_h[j, i]  = lambdac * C[j, i - 1]                                    # Cash for transactions (6)
      B_h[j, i]  = V[j, i] * (lambda10 + lambda11 * rb[j, i])               # Demand for bills (7)
      M_h[j, i]  = V[j, i] - H_h[j, i] - B_h[j, i]                          # Deposits as buffer stock (8)

      # B) FIRMS ####
      Y[j, i]    = C[j, i] + I[j, i] + G[j, i]                              # GDP (9)
      WB[j, i]   = Y[j, i] - rl[j, i - 1] * L_d[j, i - 1] - AF[j, i]        # Wage bill = residual, no retained profits (10)
      N[j, i]    = Y[j, i] / pr                                             # Employment (11)
      w[j, i]    = WB[j, i] / N[j, i]                                       # Wage rate (12)
      KT[j, i]   = kappa * Y[j, i - 1]                                      # Target capital (13)
      DA[j, i]   = delta * K[j, i - 1]                                      # Depreciation allowances (14)
      AF[j, i]   = DA[j, i]                                                 # Amortisation funds (15)
      I[j, i]    = gamma * (KT[j, i] - K[j, i - 1]) + DA[j, i]              # Gross investment (16)
      K[j, i]    = K[j, i - 1] + I[j, i] - DA[j, i]                         # Capital accumulation (17)
      L_d[j, i]  = L_d[j, i - 1] + I[j, i] - AF[j, i]                       # Loans fund net investment   (18)

      # C) BANKS ####
      L_s[j, i]  = L_s[j, i - 1] + (L_d[j, i] - L_d[j, i - 1])              # Loans supplied on demand (19)
      M_s[j, i]  = M_s[j, i - 1] + (L_s[j, i] - L_s[j, i - 1])              # Loans create deposits (20)
      B_b[j, i]  = M_h[j, i] - M_s[j, i]                                    # Bills held by banks (21)
      FB[j, i]   = rl[j, i - 1] * L_s[j, i - 1] + rb[j, i - 1] * B_b[j, i - 1] -
        rm[j, i - 1] * M_h[j, i - 1]                                         # Bank profits (22)

      # D) GOVERNMENT AND CENTRAL BANK ####
      F_cb[j, i] = rb[j, i - 1] * B_cb[j, i - 1]                            # Central bank profits (23)
      G[j, i]    = G0[j, i] - psi * (rb[j, i - 1] - rbar) * B_s[j, i - 1]   # Fiscal rule (24)
      PSBR[j, i] = G[j, i] + rb[j, i - 1] * B_s[j, i - 1] - TAX[j, i] - F_cb[j, i] # Borrowing requirement (25)
      B_s[j, i]  = B_s[j, i - 1] + PSBR[j, i]                               # Supply of bills (26)
      B_cb[j, i] = B_s[j, i] - B_h[j, i] - B_b[j, i]                        # Central bank residual (27)
      H_s[j, i]  = H_s[j, i - 1] + (B_cb[j, i] - B_cb[j, i - 1])            # Supply of cash (28)
    }
  }
}

# Display the results ####
sfcGap <- max(abs(H_h[, 2:nPeriods] - H_s[, 2:nPeriods]))     # Hidden equation: H_h = H_s
cat(" ******************************")
cat("\n Max |H_h - H_s| =", sfcGap)
cat("\n ******************************")
cat("\n Baseline values at period", shockStart - 1, ": \n Y =", round(Y[1, shockStart - 1], 2),
    "\n V =", round(V[1, shockStart - 1], 2),
    "\n PSBR =", round(PSBR[1, shockStart - 1], 2),
    "\n B_s =", round(B_s[1, shockStart - 1], 2))
cat("\n ******************************")

# Plot the results ####
op = par(mfrow = c(3, 2), mar = c(4, 4, 3, 1))

# a) Consistency check (both scenarios): H_h - H_s should hug zero
plot(H_h[1, 2:nPeriods] - H_s[1, 2:nPeriods], type = "l", col = "seagreen", lwd = 2,
     font.main = 1, main = "a) Consistency check: H_h - H_s", xlab = "period", ylab = "",
     ylim = range(-1, 1))
lines(H_h[2, 2:nPeriods] - H_s[2, 2:nPeriods], col = "orange", lwd = 2, lty = 2)
abline(h = 0, lty = 3)
legend("topright", c("Baseline", "Higher G"), col = c("seagreen", "orange"),
       lwd = 2, lty = c(1, 2), bty = "n")

# b) Demand components building up (baseline)
yr = range(0, Y[1, 2:60])
plot(Y[1, 2:60], type = "l", col = "black", lwd = 2, font.main = 1,
     main = "b) GDP and its components (baseline)", xlab = "period", ylab = "", ylim = yr)
lines(C[1, 2:60], col = "aquamarine4", lwd = 2, lty = 2)
lines(I[1, 2:60], col = "orchid", lwd = 2, lty = 3)
lines(G[1, 2:60], col = "purple", lwd = 2, lty = 4)
legend("right", c("GDP", "Consumption", "Investment", "Government spending"),
       col = c("black", "aquamarine4", "orchid", "purple"),
       lwd = 2, lty = 1:4, bty = "n", cex = 0.8)

# c) GDP after the fiscal expansion
yr = range(Y[1, 90:nPeriods], Y[2, 90:nPeriods])
plot(Y[2, 90:nPeriods], type = "l", col = "coral3", lwd = 2, font.main = 1,
     main = "c) GDP after higher government spending", xlab = "period (from 90)", ylab = "",
     ylim = yr)
lines(Y[1, 90:nPeriods], col = "black", lwd = 1, lty = 2)
legend("right", c("Higher G", "Baseline"), col = c("coral3", "black"),
       lwd = c(2, 1), lty = c(1, 2), bty = "n")

# d) Sectoral balances after the fiscal expansion
NLh <- YD - C                                       # Household net lending (= saving)
NLf <- -(I - DA)                                    # Firm net lending (= - net investment)
yr = range(-PSBR[2, 90:nPeriods], NLh[2, 90:nPeriods], NLf[2, 90:nPeriods], 0)
plot(-PSBR[2, 90:nPeriods], type = "l", col = "purple", lwd = 2, font.main = 1,
     main = "d) Sectoral balances (higher G)", xlab = "period (from 90)", ylab = "",
     ylim = yr)
lines(NLh[2, 90:nPeriods], col = "aquamarine4", lwd = 2, lty = 2)
lines(NLf[2, 90:nPeriods], col = "orchid", lwd = 2, lty = 3)
abline(h = 0, lty = 3)
legend("bottomright", c("Government", "Households", "Firms"),
       col = c("purple", "aquamarine4", "orchid"), lwd = 2, lty = c(1, 2, 3), bty = "n")

# e) Public debt and its holders after the fiscal expansion
yr = c(min(0, B_s[2, 90:nPeriods], B_h[2, 90:nPeriods], B_cb[2, 90:nPeriods], B_b[2, 90:nPeriods]),
       1.35 * max(B_s[2, 90:nPeriods]))
plot(B_s[2, 90:nPeriods], type = "l", col = "black", lwd = 2, font.main = 1,
     main = "e) Public debt and its holders (higher G)", xlab = "period (from 90)", ylab = "",
     ylim = yr)
lines(B_h[2, 90:nPeriods], col = "firebrick", lwd = 2, lty = 2)
lines(B_cb[2, 90:nPeriods], col = "seagreen", lwd = 2, lty = 3)
lines(B_b[2, 90:nPeriods], col = "steelblue", lwd = 2, lty = 4)
legend("topright", c("Bills supplied", "Households", "Central bank", "Banks"),
       col = c("black", "firebrick", "seagreen", "steelblue"), lwd = 2, lty = 1:4,
       bty = "n", cex = 0.8, ncol = 2)

# f) Household portfolio (baseline)
yr = range(0, 1.3 * V[1, 2:nPeriods])
plot(V[1, 2:nPeriods], type = "l", col = "black", lwd = 2, font.main = 1,
     main = "f) Household wealth and portfolio (baseline)", xlab = "period", ylab = "", ylim = yr)
lines(M_h[1, 2:nPeriods], col = "steelblue", lwd = 2, lty = 2)
lines(B_h[1, 2:nPeriods], col = "firebrick", lwd = 2, lty = 3)
lines(H_h[1, 2:nPeriods], col = "seagreen", lwd = 2, lty = 4)
legend("topright", c("Wealth", "Deposits", "Bills", "Cash"), ncol = 2,
       col = c("black", "steelblue", "firebrick", "seagreen"),
       lwd = 2, lty = 1:4, bty = "n", cex = 0.8)

par(op)

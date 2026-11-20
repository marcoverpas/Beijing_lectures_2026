# *************************************************************************
#  Model OPENSBM-FIX (aggregate)
#  Model SBM with a super-stylised foreign sector and fixed exchange rate
#  Sources: Godley & Lavoie, Monetary Economics, chapters 4, 7 and 12;
#           foreign-sector set-up as in the OPENSIMPLEST model
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
lambda10    <- 0.15        # Portfolio: autonomous share of domestic bills
lambda11    <- 1           # Portfolio: sensitivity of domestic bills to domestic rate
lambda12    <- 1           # Portfolio: sensitivity of domestic bills to foreign rate
lambda20    <- 0.1         # Portfolio: autonomous share of foreign bills
lambda21    <- 1           # Portfolio: sensitivity of foreign bills to domestic rate (= lambda12)
lambda22    <- 1           # Portfolio: sensitivity of foreign bills to foreign rate
lambdac     <- 0.2         # Cash to (lagged) consumption ratio
theta       <- 0.2         # Average tax rate on income
delta       <- 0.1         # Depreciation rate
gamma       <- 0.1         # Speed of adjustment of capital to its target
kappa       <- 1.5         # Target capital-output ratio
pr          <- 1           # Labour productivity
eps0        <- log(0.1)    # Export equation: constant
eps1        <- 0.8         # Export equation: elasticity to exchange rate
eps2        <- 1           # Export equation: elasticity to foreign income
mu0         <- log(0.2)    # Import equation: constant (m = 0.2*y when xr = 1)
mu1         <- 0.8         # Import equation: elasticity to exchange rate
mu2         <- 1           # Import equation: elasticity to domestic income
Gbase       <- 20          # Government spending (baseline)
Gshock      <- 25          # Government spending (scenario 2)
psi         <- 1           # Fiscal rule: share of the extra interest bill offset by lower spending
rbar        <- 0.02        # Fiscal rule: reference interest rate
xrbar       <- 1.0598692   # Fixed exchange rate, calibrated so that CA = 0 in the baseline stationary state

# Create the variables as matrices [scenario, period], all starting at zero ####

# A) Households
YD    <- matrix(0, nScenarios, nPeriods)  # Disposable income (regular)
CG    <- matrix(0, nScenarios, nPeriods)  # Capital gains on foreign bills
C     <- matrix(0, nScenarios, nPeriods)  # Consumption
alpha1<- matrix(0, nScenarios, nPeriods)  # Propensity to consume out of disposable income
V     <- matrix(0, nScenarios, nPeriods)  # Net wealth
H_h   <- matrix(0, nScenarios, nPeriods)  # Cash held by households
B_h   <- matrix(0, nScenarios, nPeriods)  # Domestic bills held by households
BF_h  <- matrix(0, nScenarios, nPeriods)  # Foreign bills held by households (foreign currency)
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
B_s   <- matrix(0, nScenarios, nPeriods)  # Domestic bills supplied by government
B_cb  <- matrix(0, nScenarios, nPeriods)  # Domestic bills held by central bank
F_cb  <- matrix(0, nScenarios, nPeriods)  # Central bank profits
H_s   <- matrix(0, nScenarios, nPeriods)  # Cash supplied by central bank

# E) Rest of the World
X     <- matrix(0, nScenarios, nPeriods)  # Exports
IM    <- matrix(0, nScenarios, nPeriods)  # Imports
TB    <- matrix(0, nScenarios, nPeriods)  # Trade balance
CA    <- matrix(0, nScenarios, nPeriods)  # Current account
NETFA <- matrix(0, nScenarios, nPeriods)  # Net foreign assets of domestic economy
B_w   <- matrix(0, nScenarios, nPeriods)  # Domestic bills held by RoW

# Exogenous variables as matrices (so they can take scenario-specific shocks) ####
G0  <- matrix(Gbase, nScenarios, nPeriods)  # Government spending, exogenous component
G   <- matrix(Gbase, nScenarios, nPeriods)  # Government spending
rb  <- matrix(0.02,  nScenarios, nPeriods)  # Interest rate on domestic bills (policy rate)
rm  <- matrix(0.02,  nScenarios, nPeriods)  # Interest rate on deposits
rl  <- matrix(0.02,  nScenarios, nPeriods)  # Interest rate on loans
rw  <- matrix(0.02,  nScenarios, nPeriods)  # Interest rate on foreign bills
yw  <- matrix(200,   nScenarios, nPeriods)  # Foreign income
xr  <- matrix(xrbar, nScenarios, nPeriods)  # Nominal exchange rate (domestic price of foreign currency), fixed

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
        rb[j, i - 1] * B_h[j, i - 1] + rm[j, i - 1] * M_h[j, i - 1] +
        rw[j, i - 1] * BF_h[j, i - 1] * xr[j, i] + FB[j, i]                  # Disposable income (1)
      CG[j, i]   = (xr[j, i] - xr[j, i - 1]) * BF_h[j, i - 1]               # Capital gains (2)
      TAX[j, i]  = theta * (WB[j, i] + FB[j, i] + rb[j, i - 1] * B_h[j, i - 1] + rm[j, i - 1] * M_h[j, i - 1] +
        rw[j, i - 1] * BF_h[j, i - 1] * xr[j, i])                            # Taxes on household income (3)
      V[j, i]    = V[j, i - 1] + (YD[j, i] - C[j, i]) + CG[j, i]                # Wealth accumulation (4)
      alpha1[j, i] = alpha10 - alpha11 * rb[j, i - 1]               # Propensity to consume and interest rate (5)
      C[j, i]    = alpha1[j, i] * YD[j, i] + alpha2 * V[j, i - 1]           # Consumption (6)
      H_h[j, i]  = lambdac * C[j, i - 1]                                    # Cash for transactions (7)
      B_h[j, i]  = V[j, i] * (lambda10 + lambda11 * rb[j, i] - lambda12 * rw[j, i])          # Domestic bills (8)
      BF_h[j, i] = (V[j, i] / xr[j, i]) * (lambda20 - lambda21 * rb[j, i] + lambda22 * rw[j, i]) # Foreign bills (9)
      M_h[j, i]  = V[j, i] - H_h[j, i] - B_h[j, i] - BF_h[j, i] * xr[j, i]  # Deposits as buffer stock (10)

      # B) FIRMS ####
      Y[j, i]    = C[j, i] + I[j, i] + G[j, i] + X[j, i] - IM[j, i]         # GDP (11)
      WB[j, i]   = Y[j, i] - rl[j, i - 1] * L_d[j, i - 1] - AF[j, i]        # Wage bill = residual, no retained profits (12)
      N[j, i]    = Y[j, i] / pr                                             # Employment (13)
      w[j, i]    = WB[j, i] / N[j, i]                                       # Wage rate (14)
      KT[j, i]   = kappa * Y[j, i - 1]                                      # Target capital (15)
      DA[j, i]   = delta * K[j, i - 1]                                      # Depreciation allowances (16)
      AF[j, i]   = DA[j, i]                                                 # Amortisation funds (17)
      I[j, i]    = gamma * (KT[j, i] - K[j, i - 1]) + DA[j, i]              # Gross investment (18)
      K[j, i]    = K[j, i - 1] + I[j, i] - DA[j, i]                         # Capital accumulation (19)
      L_d[j, i]  = L_d[j, i - 1] + I[j, i] - AF[j, i]                       # Loans fund net investment   (20)

      # C) BANKS ####
      L_s[j, i]  = L_s[j, i - 1] + (L_d[j, i] - L_d[j, i - 1])              # Loans supplied on demand (21)
      M_s[j, i]  = M_s[j, i - 1] + (L_s[j, i] - L_s[j, i - 1])              # Loans create deposits (22)
      B_b[j, i]  = M_h[j, i] - M_s[j, i]                                    # Bills held by banks (23)
      FB[j, i]   = rl[j, i - 1] * L_s[j, i - 1] + rb[j, i - 1] * B_b[j, i - 1] -
        rm[j, i - 1] * M_h[j, i - 1]                                         # Bank profits (24)

      # D) GOVERNMENT AND CENTRAL BANK ####
      F_cb[j, i] = rb[j, i - 1] * B_cb[j, i - 1]                            # Central bank profits (25)
      G[j, i]    = G0[j, i] - psi * (rb[j, i - 1] - rbar) * B_s[j, i - 1]   # Fiscal rule (26)
      PSBR[j, i] = G[j, i] + rb[j, i - 1] * B_s[j, i - 1] - TAX[j, i] - F_cb[j, i] # Borrowing requirement (27)
      B_s[j, i]  = B_s[j, i - 1] + PSBR[j, i]                               # Supply of domestic bills (28)
      B_cb[j, i] = B_s[j, i] - B_h[j, i] - B_b[j, i] - B_w[j, i]            # Central bank residual (29)
      H_s[j, i]  = H_s[j, i - 1] + (B_cb[j, i] - B_cb[j, i - 1])            # Supply of cash (30)

      # E) REST OF THE WORLD ####
      X[j, i]    = exp(eps0 + eps1 * log(xr[j, i - 1]) + eps2 * log(yw[j, i]))  # Exports (31)
      IM[j, i]   = exp(mu0 - mu1 * log(xr[j, i - 1]) + mu2 * log(Y[j, i]))      # Imports (32)
      TB[j, i]   = X[j, i] - IM[j, i]                                       # Trade balance (33)
      CA[j, i]   = TB[j, i] + rw[j, i - 1] * BF_h[j, i - 1] * xr[j, i] -
        rb[j, i - 1] * B_w[j, i - 1]                                         # Current account (34)
      NETFA[j, i]= NETFA[j, i - 1] + CA[j, i] + CG[j, i]                    # Net foreign assets (35)
      B_w[j, i]  = BF_h[j, i] * xr[j, i] - NETFA[j, i]                      # Domestic bills held by RoW (36)
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
    "\n CA =", round(CA[1, shockStart - 1], 2),
    "\n PSBR =", round(PSBR[1, shockStart - 1], 2),
    "\n NETFA =", round(NETFA[1, shockStart - 1], 2))
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
lines(IM[1, 2:60], col = "firebrick", lwd = 2, lty = 4)
lines(X[1, 2:60], col = "dodgerblue", lwd = 2, lty = 5)
legend("right", c("GDP", "Consumption", "Investment", "Imports", "Exports"),
       col = c("black", "aquamarine4", "orchid", "firebrick", "dodgerblue"),
       lwd = 2, lty = 1:5, bty = "n", cex = 0.8)

# c) GDP after the fiscal expansion
yr = range(Y[1, 90:nPeriods], Y[2, 90:nPeriods])
plot(Y[2, 90:nPeriods], type = "l", col = "coral3", lwd = 2, font.main = 1,
     main = "c) GDP after higher government spending", xlab = "period (from 90)", ylab = "",
     ylim = yr)
lines(Y[1, 90:nPeriods], col = "black", lwd = 1, lty = 2)
legend("right", c("Higher G", "Baseline"), col = c("coral3", "black"),
       lwd = c(2, 1), lty = c(1, 2), bty = "n")

# d) Twin deficits after the fiscal expansion
yr = range(-PSBR[2, 90:nPeriods], CA[2, 90:nPeriods], 0)
plot(-PSBR[2, 90:nPeriods], type = "l", col = "purple", lwd = 2, font.main = 1,
     main = "d) Government balance and current account", xlab = "period (from 90)", ylab = "",
     ylim = yr)
lines(CA[2, 90:nPeriods], col = "dodgerblue", lwd = 2, lty = 2)
lines(TB[2, 90:nPeriods], col = "gray50", lwd = 2, lty = 3)
abline(h = 0, lty = 3)
legend("bottomright", c("Government balance", "Current account", "Trade balance"),
       col = c("purple", "dodgerblue", "gray50"), lwd = 2, lty = c(1, 2, 3), bty = "n")

# e) External position after the fiscal expansion
yr = range(NETFA[, 90:nPeriods], B_w[, 90:nPeriods])
plot(NETFA[2, 90:nPeriods], type = "l", col = "dodgerblue", lwd = 2, font.main = 1,
     main = "e) Net foreign assets and foreign-held bills", xlab = "period (from 90)", ylab = "",
     ylim = yr)
lines(B_w[2, 90:nPeriods], col = "firebrick", lwd = 2, lty = 2)
lines(NETFA[1, 90:nPeriods], col = "dodgerblue", lwd = 1, lty = 3)
lines(B_w[1, 90:nPeriods], col = "firebrick", lwd = 1, lty = 3)
legend("topleft", c("NETFA", "Bills held by RoW", "Baseline"),
       col = c("dodgerblue", "firebrick", "black"), lwd = c(2, 2, 1), lty = c(1, 2, 3), bty = "n")

# f) Household portfolio (baseline)
yr = range(0, V[1, 2:nPeriods])
plot(V[1, 2:nPeriods], type = "l", col = "black", lwd = 2, font.main = 1,
     main = "f) Household wealth and portfolio (baseline)", xlab = "period", ylab = "", ylim = yr)
lines(M_h[1, 2:nPeriods], col = "steelblue", lwd = 2, lty = 2)
lines(B_h[1, 2:nPeriods], col = "firebrick", lwd = 2, lty = 3)
lines(BF_h[1, 2:nPeriods] * xr[1, 2:nPeriods], col = "darkorange", lwd = 2, lty = 4)
lines(H_h[1, 2:nPeriods], col = "seagreen", lwd = 2, lty = 5)
legend("right", c("Wealth", "Deposits", "Domestic bills", "Foreign bills", "Cash"),
       col = c("black", "steelblue", "firebrick", "darkorange", "seagreen"),
       lwd = 2, lty = 1:5, bty = "n", cex = 0.8)

par(op)

# *************************************************************************
#  Model IO-SBM, Sraffa-like prices (3 industries)
#  Model IO-SBM (closed economy) with cost-plus (Sraffa-like) prices
#  Sources: Godley & Lavoie, Monetary Economics, chapters 4 and 7;
#           IO core as in the Leeds lectures (IO-PC, IO-BMW);
#           price equations as in Canelli et al. (2026) (without imported inputs)
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
kappaj      <- c(0.8, 1.3, 0.3)       # Target capital-gross output ratios by industry (agriculture, manufacturing, services)

# Input-output parameters ####
nIndustries <- 3           # Industries (agriculture, manufacturing, services)
pr          <- c(3.5, 5, 2.2)         # Labour productivity by industry
betaC       <- c(0.15, 0.35, 0.50)    # Consumption shares by industry
betaI       <- c(0.20, 0.50, 0.30)    # Investment shares by industry
betaG       <- c(0.10, 0.30, 0.60)    # Government spending shares by industry
A  <- matrix(c(0.11, 0.12, 0.10,      # Technical coefficients
               0.21, 0.22, 0.20,      # (row: supplying industry; column: using industry)
               0.15, 0.18, 0.10), nrow = nIndustries, byrow = TRUE)
Leontief <- solve(diag(nIndustries) - A)   # (I - A)^-1, computed once (A is constant)
wbar        <- 1           # Nominal wage rate (uniform across industries)
mup0        <- c(0.3, 0.4, 0.3)       # Normal mark-ups on intermediate costs by industry
mup1        <- 0.2         # Sensitivity of mark-ups to the gap between actual and normal output
phiN        <- 0.1         # Speed of adjustment of normal output to actual output
lab         <- 1 / pr                 # Labour coefficients by industry
MkN         <- diag((1 + kappaj * delta) * (1 + mup0))  # Normal mark-up factors (incl. capital-cost component)
Gbase       <- 20          # Real government spending (baseline)
Gshock      <- 25          # Real government spending (scenario 2)
psi         <- 1           # Fiscal rule: share of the extra interest bill offset by lower spending
rbar        <- 0.02        # Fiscal rule: reference interest rate

# Create the variables as matrices [scenario, period], all starting at zero ####

# A) Households
YD    <- matrix(0, nScenarios, nPeriods)  # Disposable income
C     <- matrix(0, nScenarios, nPeriods)  # Consumption (nominal)
alpha1<- matrix(0, nScenarios, nPeriods)  # Propensity to consume out of disposable income
Cr    <- matrix(0, nScenarios, nPeriods)  # Consumption (real)
V     <- matrix(0, nScenarios, nPeriods)  # Net wealth
H_h   <- matrix(0, nScenarios, nPeriods)  # Cash held by households
B_h   <- matrix(0, nScenarios, nPeriods)  # Bills held by households
M_h   <- matrix(0, nScenarios, nPeriods)  # Bank deposits held by households

# B) Firms
Y     <- matrix(0, nScenarios, nPeriods)  # GDP (nominal)
Yr    <- matrix(0, nScenarios, nPeriods)  # GDP (real)
WB    <- matrix(0, nScenarios, nPeriods)  # Wage bill
FD    <- matrix(0, nScenarios, nPeriods)  # Distributed profits of firms
N     <- matrix(0, nScenarios, nPeriods)  # Employment
I     <- matrix(0, nScenarios, nPeriods)  # Gross investment (nominal)
Ir    <- matrix(0, nScenarios, nPeriods)  # Gross investment (real)
K     <- matrix(0, nScenarios, nPeriods)  # Capital stock (real)
KT    <- matrix(0, nScenarios, nPeriods)  # Target capital stock (real)
DA    <- matrix(0, nScenarios, nPeriods)  # Depreciation (real)
AF    <- matrix(0, nScenarios, nPeriods)  # Amortisation funds (nominal)
L_d   <- matrix(0, nScenarios, nPeriods)  # Demand for bank loans

# Industry-level variables as arrays [scenario, period, industry] ####
d     <- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Final demand by industry
x     <- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Gross output
Nz    <- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Employment by industry
p     <- array(1, dim = c(nScenarios, nPeriods, nIndustries))  # Current unit prices
pS    <- array(1, dim = c(nScenarios, nPeriods, nIndustries))  # Reproduction (Sraffa) prices
mup   <- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Current mark-ups
xN    <- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Normal (potential) output

# Price indices ####
p_c   <- matrix(1, nScenarios, nPeriods)  # Consumer price index
p_i   <- matrix(1, nScenarios, nPeriods)  # Price of investment goods
p_g   <- matrix(1, nScenarios, nPeriods)  # Price of government purchases
p_y   <- matrix(1, nScenarios, nPeriods)  # GDP deflator

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
Gr0 <- matrix(Gbase, nScenarios, nPeriods)  # Real government spending, exogenous component
Gr  <- matrix(Gbase, nScenarios, nPeriods)  # Real government spending
G   <- matrix(0,     nScenarios, nPeriods)  # Nominal government spending
rb  <- matrix(0.02,  nScenarios, nPeriods)  # Interest rate on bills (policy rate)
rm  <- matrix(0.02,  nScenarios, nPeriods)  # Interest rate on deposits
rl  <- matrix(0.02,  nScenarios, nPeriods)  # Interest rate on loans

# Loop over scenarios ####
for (j in 1:nScenarios) {

  # Time loop
  for (i in 2:nPeriods) {

    # Shocks ####
    if (i >= shockStart && j == 2) Gr0[j, i] <- Gshock        # higher government spending

    # Solve the SIMULTANEOUS equations by iteration
    for (iter in 1:100) {

      # A) HOUSEHOLDS ####
      YD[j, i]   = WB[j, i] + FD[j, i] - TAX[j, i] +
        rb[j, i - 1] * B_h[j, i - 1] + rm[j, i - 1] * M_h[j, i - 1] + FB[j, i]  # Disposable income (1)
      TAX[j, i]  = theta * (WB[j, i] + FD[j, i] + FB[j, i] + rb[j, i - 1] * B_h[j, i - 1] +
        rm[j, i - 1] * M_h[j, i - 1])                                        # Taxes on household income (2)
      V[j, i]    = V[j, i - 1] + (YD[j, i] - C[j, i])                       # Wealth accumulation (3)
      alpha1[j, i] = alpha10 - alpha11 * rb[j, i - 1]               # Propensity to consume and interest rate (4)
      Cr[j, i]   = alpha1[j, i] * YD[j, i] / p_c[j, i] +
        alpha2 * V[j, i - 1] / p_c[j, i]                                   # Consumption, real (5)
      C[j, i]    = p_c[j, i] * Cr[j, i]                                     # Consumption, nominal (6)
      H_h[j, i]  = lambdac * C[j, i - 1]                                    # Cash for transactions (7)
      B_h[j, i]  = V[j, i] * (lambda10 + lambda11 * rb[j, i])               # Demand for bills (8)
      M_h[j, i]  = V[j, i] - H_h[j, i] - B_h[j, i]                          # Deposits as buffer stock (9)

      # B) FIRMS ####
      G[j, i]    = p_g[j, i] * Gr[j, i]                                     # Government spending, nominal (10)
      Y[j, i]    = C[j, i] + I[j, i] + G[j, i]                              # GDP, nominal (11)
      Yr[j, i]   = Cr[j, i] + Ir[j, i] + Gr[j, i]                           # GDP, real (12)
      p_y[j, i]  = ifelse(Yr[j, i] > 0, Y[j, i] / Yr[j, i], 1)              # GDP deflator (13)
      N[j, i]    = sum(Nz[j, i, ])                                          # Employment (14)
      WB[j, i]   = wbar * N[j, i]                                           # Wage bill (15)
      FD[j, i]   = Y[j, i] - WB[j, i] - AF[j, i] - rl[j, i - 1] * L_d[j, i - 1]  # Profits = residual, all distributed (16)
      KT[j, i]   = sum(kappaj * x[j, i - 1, ])                         # Target capital (17)
      DA[j, i]   = delta * K[j, i - 1]                                      # Depreciation, real (18)
      AF[j, i]   = p_i[j, i] * DA[j, i]                                     # Amortisation funds at replacement cost (19)
      Ir[j, i]   = gamma * (KT[j, i] - K[j, i - 1]) + DA[j, i]              # Gross investment, real (20)
      I[j, i]    = p_i[j, i] * Ir[j, i]                                     # Gross investment, nominal (21)
      K[j, i]    = K[j, i - 1] + Ir[j, i] - DA[j, i]                        # Capital accumulation (22)
      L_d[j, i]  = L_d[j, i - 1] + I[j, i] - AF[j, i]                       # Loans fund net investment   (23)

      # INDUSTRIAL STRUCTURE (real terms) ####
      d[j, i, ]  = betaC * Cr[j, i] + betaI * Ir[j, i] + betaG * Gr[j, i]   # Final demand by industry (24)
      x[j, i, ]  = Leontief %*% d[j, i, ]                                   # Gross output (25)
      Nz[j, i, ] = x[j, i, ] * lab                                          # Employment by industry (26)
      
      # PRICES ####
      xN[j, i, ] = if (i < 3) x[j, i, ] else xN[j, i - 1, ] + phiN * (x[j, i - 1, ] - xN[j, i - 1, ])  # Normal output (27)
      mup[j, i, ] = if (i < 3) mup0 else mup0 + mup1 * (x[j, i - 1, ] / xN[j, i - 1, ] - 1)  # Current mark-ups (28)
      pS[j, i, ] = as.vector(wbar * lab %*% solve(diag(nIndustries) - A %*% MkN))  # Reproduction prices (29)
      p[j, i, ]  = as.vector(wbar * lab %*% solve(diag(nIndustries) -
                               A %*% diag((1 + kappaj * delta) * (1 + mup[j, i, ]))))  # Current prices (30)
      p_c[j, i]  = sum(p[j, i, ] * betaC)                                   # Consumer price index (31)
      p_i[j, i]  = sum(p[j, i, ] * betaI)                                   # Price of investment goods (32)
      p_g[j, i]  = sum(p[j, i, ] * betaG)                                   # Price of government purchases (33)
      
      # C) BANKS ####
      L_s[j, i]  = L_s[j, i - 1] + (L_d[j, i] - L_d[j, i - 1])              # Loans supplied on demand (34)
      M_s[j, i]  = M_s[j, i - 1] + (L_s[j, i] - L_s[j, i - 1])              # Loans create deposits (35)
      B_b[j, i]  = M_h[j, i] - M_s[j, i]                                    # Bills held by banks (36)
      FB[j, i]   = rl[j, i - 1] * L_s[j, i - 1] + rb[j, i - 1] * B_b[j, i - 1] -
        rm[j, i - 1] * M_h[j, i - 1]                                         # Bank profits (37)

      # D) GOVERNMENT AND CENTRAL BANK ####
      F_cb[j, i] = rb[j, i - 1] * B_cb[j, i - 1]                            # Central bank profits (38)
      Gr[j, i]   = Gr0[j, i] - psi * (rb[j, i - 1] - rbar) * B_s[j, i - 1] / p_g[j, i]  # Fiscal rule (real spending) (39)
      PSBR[j, i] = G[j, i] + rb[j, i - 1] * B_s[j, i - 1] - TAX[j, i] - F_cb[j, i] # Borrowing requirement (40)
      B_s[j, i]  = B_s[j, i - 1] + PSBR[j, i]                               # Supply of bills (41)
      B_cb[j, i] = B_s[j, i] - B_h[j, i] - B_b[j, i]                        # Central bank residual (42)
      H_s[j, i]  = H_s[j, i - 1] + (B_cb[j, i] - B_cb[j, i - 1])            # Supply of cash (43)
    }
  }
}

# Display the results ####
sfcGap <- max(abs(H_h[, 2:nPeriods] - H_s[, 2:nPeriods]))     # Hidden equation: H_h = H_s
ioGap  <- max(abs(apply(x[, 2:nPeriods, ], c(1, 2), sum) -
                  apply(x[, 2:nPeriods, ], c(1, 2), function(v) sum(A %*% v)) -
                  apply(d[, 2:nPeriods, ], c(1, 2), sum)))  # IO check: x = A x + d
cat(" ******************************")
cat("\n Industries =", nIndustries)
cat("\n Max |H_h - H_s| =", sfcGap)
cat("\n Max IO gap =", ioGap)
cat("\n ******************************")
cat("\n Values at period", nPeriods, "(baseline | higher G): \n Y =",
    round(Y[1, nPeriods], 2), "|", round(Y[2, nPeriods], 2),
    "\n x =", round(x[1, nPeriods, ], 2), "|", round(x[2, nPeriods, ], 2),
    "\n N =", round(N[1, nPeriods], 2), "|", round(N[2, nPeriods], 2),
    "\n Y (real) =", round(Yr[1, nPeriods], 2), "|", round(Yr[2, nPeriods], 2),
    "\n p =", round(p[1, nPeriods, ], 3),
    "\n p_c =", round(p_c[1, nPeriods], 3), " p_y =", round(p_y[1, nPeriods], 3),
    "\n Wage share =", round(WB[1, nPeriods] / Y[1, nPeriods], 3), "|", round(WB[2, nPeriods] / Y[2, nPeriods], 3))
cat("\n ******************************")

# Plot the results ####
indCol <- c("springgreen4", "orangered", "dodgerblue3")   # Industry colours
indLab <- c("Agriculture", "Manufacturing", "Services")   # Industry names
per    <- 2:nPeriods                                       # Periods shown

op = par(mfrow = c(3, 2), mar = c(4, 4, 3, 1))

# a) Consistency check (both scenarios): H_h - H_s should hug zero
plot(H_h[1, per] - H_s[1, per], type = "l", col = "seagreen", lwd = 2,
     font.main = 1, main = "a) Consistency check: H_h - H_s", xlab = "period", ylab = "",
     ylim = range(-1, 1))
lines(H_h[2, per] - H_s[2, per], col = "orange", lwd = 2, lty = 2)
abline(h = 0, lty = 3)
legend("topright", c("Baseline", "Higher G"), col = c("seagreen", "orange"),
       lwd = 2, lty = c(1, 2), bty = "n")

# b) Nominal and real GDP: baseline vs higher government spending
plot(Y[2, per], type = "l", col = "coral3", lwd = 2, font.main = 1,
     main = "b) Nominal and real GDP", xlab = "period", ylab = "", ylim = range(Y[, per], Yr[, per]))
lines(Y[1, per], col = "black", lwd = 2, lty = 2)
lines(Yr[2, per], col = "coral3", lwd = 1, lty = 3)
lines(Yr[1, per], col = "black", lwd = 1, lty = 3)
legend("bottomright", c("Higher G (nominal)", "Baseline (nominal)", "Real (dotted)"),
       col = c("coral3", "black", "gray40"), lwd = c(2, 2, 1), lty = c(1, 2, 3), bty = "n")

# c) Current (solid) and reproduction (dashed) prices by industry (higher G)
matplot(p[2, per, ], type = "l", lty = 1, lwd = 2, col = indCol, font.main = 1,
        main = "c) Current vs reproduction prices (higher G)", xlab = "period", ylab = "",
        ylim = range(p[2, per, ], pS[2, per, ]))
matlines(pS[2, per, ], lty = 2, lwd = 1, col = indCol)
legend("right", indLab, col = indCol, lwd = 2, bty = "n")

# d) Gross output by industry (higher G)
matplot(x[2, per, ], type = "l", lty = 1, lwd = 2, col = indCol, font.main = 1,
        main = "d) Gross output by industry (higher G)", xlab = "period", ylab = "")
legend("right", indLab, col = indCol, lwd = 2, bty = "n")

# e) Employment by industry (higher G)
matplot(Nz[2, per, ], type = "l", lty = 1, lwd = 2, col = indCol, font.main = 1,
        main = "e) Employment by industry (higher G)", xlab = "period", ylab = "")
legend("right", indLab, col = indCol, lwd = 2, bty = "n")

# f) Change in gross output by industry (higher G vs baseline, last period)
barplot(100 * (x[2, nPeriods, ] / x[1, nPeriods, ] - 1), names.arg = indLab, col = indCol,
        font.main = 1, main = "f) Gross output: higher G vs baseline (%)", ylab = "%")
abline(h = 0)

par(op)

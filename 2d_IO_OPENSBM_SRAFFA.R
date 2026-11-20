# *************************************************************************
#  Model IO-OPENSBM, Sraffa-like prices (3 industries)
#  Model IO-OPENSBM with cost-plus (Sraffa-like) prices, imported inputs priced at the exchange rate
#  Sources: Godley & Lavoie, Monetary Economics, chapters 4, 7 and 12;
#           foreign-sector set-up as in the OPENSIMPLEST model;
#           IO treatment of trade and price equations as in Canelli et al. (2026)
#  Author: Marco Veronese Passarella
#  Last change: 20/11/2026
# *************************************************************************

# Clear environment
rm(list = ls(all = TRUE))

# Set model parameters ####
nPeriods    <- 400         # Periods (longer: the price-exchange-rate loop converges slowly)
nScenarios  <- 2           # 1 baseline, 2 higher government spending
shockStart  <- 201         # Period at which the shock hits
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
kappaj      <- c(0.8, 1.3, 0.3)       # Target capital-gross output ratios by industry (agriculture, manufacturing, services)

# Input-output parameters ####
nIndustries <- 3           # Industries (agriculture, manufacturing, services)
pr          <- c(3.5, 5, 2.2)         # Labour productivity by industry
betaC       <- c(0.15, 0.35, 0.50)    # Consumption shares by industry
betaI       <- c(0.20, 0.50, 0.30)    # Investment shares by industry
betaG       <- c(0.10, 0.30, 0.60)    # Government spending shares by industry
chi         <- c(0.20, 0.60, 0.20)    # Export shares by industry
psiC        <- c(0.20, 0.40, 0.05)    # Import content of consumption by industry
psiI        <- c(0.10, 0.40, 0.05)    # Import content of investment by industry
psiG        <- c(0.05, 0.10, 0.02)    # Import content of government spending by industry
A  <- matrix(c(0.11, 0.12, 0.10,      # Domestic technical coefficients
               0.21, 0.22, 0.20,      # (row: supplying industry; column: using industry)
               0.15, 0.18, 0.10), nrow = nIndustries, byrow = TRUE)
Am <- matrix(c(0.01, 0.005, 0.005,    # Imported input coefficients
               0.02, 0.03,  0.01,
               0.005, 0.005, 0.01), nrow = nIndustries, byrow = TRUE)
Leontief <- solve(diag(nIndustries) - A)   # (I - A)^-1, computed once (A is constant)
wbar        <- 1           # Nominal wage rate (uniform across industries)
mup0        <- c(0.3, 0.4, 0.3)       # Normal mark-ups on intermediate costs by industry
mup1        <- 0.2         # Sensitivity of mark-ups to the gap between actual and normal output
phiN        <- 0.1         # Speed of adjustment of normal output to actual output
pf          <- c(1, 1, 1)             # Foreign prices of imported goods (foreign currency)
lab         <- 1 / pr                 # Labour coefficients by industry
MkN         <- diag((1 + kappaj * delta) * (1 + mup0))  # Normal mark-up factors (incl. capital-cost component)
p0 <- as.vector((t(pf) %*% Am %*% MkN + wbar * lab) %*% solve(diag(nIndustries) - A %*% MkN))  # Base-period prices, used to normalise
eps0        <- log(0.1)    # Export equation: constant
eps1        <- 0.8         # Export equation: elasticity to relative prices
eps2        <- 1           # Export equation: elasticity to foreign income
mu0         <- log(0.2)    # Import equation: constant (m = 0.2*y when xr = 1)
mu1         <- 0.8         # Import equation: elasticity to relative prices
mu2         <- 1           # Import equation: elasticity to domestic income
Gbase       <- 20          # Real government spending (baseline)
Gshock      <- 25          # Real government spending (scenario 2)
psi         <- 1           # Fiscal rule: share of the extra interest bill offset by lower spending
rbar        <- 0.02        # Fiscal rule: reference interest rate
phixr       <- 3           # Speed of exchange-rate adjustment to the current account
maxIter     <- 1000        # Maximum number of iterations per period
tol         <- 1e-12       # Convergence tolerance

# Create the variables as matrices [scenario, period], all starting at zero ####

# A) Households
YD    <- matrix(0, nScenarios, nPeriods)  # Disposable income (regular)
CG    <- matrix(0, nScenarios, nPeriods)  # Capital gains on foreign bills
C     <- matrix(0, nScenarios, nPeriods)  # Consumption (nominal)
alpha1<- matrix(0, nScenarios, nPeriods)  # Propensity to consume out of disposable income
Cr    <- matrix(0, nScenarios, nPeriods)  # Consumption (real)
V     <- matrix(0, nScenarios, nPeriods)  # Net wealth
H_h   <- matrix(0, nScenarios, nPeriods)  # Cash held by households
B_h   <- matrix(0, nScenarios, nPeriods)  # Domestic bills held by households
BF_h  <- matrix(0, nScenarios, nPeriods)  # Foreign bills held by households (foreign currency)
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
d     <- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Final demand (domestic + imported)
d_pat <- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Import content of final demand (pattern)
d_im  <- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Final demand met by imports
d_dom <- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Final demand met by domestic production
x     <- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Gross output
im_int<- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Intermediate imports
Nz    <- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Employment by industry
p     <- array(1, dim = c(nScenarios, nPeriods, nIndustries))  # Current unit prices (normalised)
pS    <- array(1, dim = c(nScenarios, nPeriods, nIndustries))  # Reproduction (Sraffa) prices (normalised)
mup   <- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Current mark-ups
xN    <- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Normal (potential) output

# Price indices ####
p_c   <- matrix(1, nScenarios, nPeriods)  # Consumer price index
p_i   <- matrix(1, nScenarios, nPeriods)  # Price of investment goods
p_g   <- matrix(1, nScenarios, nPeriods)  # Price of government purchases
p_x   <- matrix(1, nScenarios, nPeriods)  # Export price
p_m   <- matrix(1, nScenarios, nPeriods)  # Import price (domestic currency)
p_y   <- matrix(1, nScenarios, nPeriods)  # GDP deflator

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
X     <- matrix(0, nScenarios, nPeriods)  # Exports (nominal)
Xr    <- matrix(0, nScenarios, nPeriods)  # Exports (real)
IM    <- matrix(0, nScenarios, nPeriods)  # Imports (nominal)
IMr   <- matrix(0, nScenarios, nPeriods)  # Imports (real)
TB    <- matrix(0, nScenarios, nPeriods)  # Trade balance
CA    <- matrix(0, nScenarios, nPeriods)  # Current account
NETFA <- matrix(0, nScenarios, nPeriods)  # Net foreign assets of domestic economy
B_w   <- matrix(0, nScenarios, nPeriods)  # Domestic bills held by RoW

# Exogenous variables as matrices (so they can take scenario-specific shocks) ####
Gr0 <- matrix(Gbase, nScenarios, nPeriods)  # Real government spending, exogenous component
Gr  <- matrix(Gbase, nScenarios, nPeriods)  # Real government spending
G   <- matrix(0,     nScenarios, nPeriods)  # Nominal government spending
rb  <- matrix(0.02,  nScenarios, nPeriods)  # Interest rate on domestic bills (policy rate)
rm  <- matrix(0.02,  nScenarios, nPeriods)  # Interest rate on deposits
rl  <- matrix(0.02,  nScenarios, nPeriods)  # Interest rate on loans
rw  <- matrix(0.02,  nScenarios, nPeriods)  # Interest rate on foreign bills
yw  <- matrix(200,   nScenarios, nPeriods)  # Foreign income
xr  <- matrix(1,     nScenarios, nPeriods)  # Nominal exchange rate (domestic price of foreign currency), flexible

# Loop over scenarios ####
for (j in 1:nScenarios) {

  # Time loop
  for (i in 2:nPeriods) {

    # Shocks ####
    if (i >= shockStart && j == 2) Gr0[j, i] <- Gshock        # higher government spending

    # Solve the SIMULTANEOUS equations by iteration
    for (iter in 1:maxIter) {
      check0 <- c(Y[j, i], V[j, i], p_c[j, i], xr[j, i])    # Values at the previous iteration

      # A) HOUSEHOLDS ####
      YD[j, i]   = WB[j, i] + FD[j, i] - TAX[j, i] +
        rb[j, i - 1] * B_h[j, i - 1] + rm[j, i - 1] * M_h[j, i - 1] +
        rw[j, i - 1] * BF_h[j, i - 1] * xr[j, i] + FB[j, i]                  # Disposable income (1)
      CG[j, i]   = (xr[j, i] - xr[j, i - 1]) * BF_h[j, i - 1]               # Capital gains (2)
      TAX[j, i]  = theta * (WB[j, i] + FD[j, i] + FB[j, i] + rb[j, i - 1] * B_h[j, i - 1] + rm[j, i - 1] * M_h[j, i - 1] +
        rw[j, i - 1] * BF_h[j, i - 1] * xr[j, i])                            # Taxes on household income (3)
      V[j, i]    = V[j, i - 1] + (YD[j, i] - C[j, i]) + CG[j, i]                # Wealth accumulation (4)
      alpha1[j, i] = alpha10 - alpha11 * rb[j, i - 1]               # Propensity to consume and interest rate (5)
      Cr[j, i]   = alpha1[j, i] * YD[j, i] / p_c[j, i] +
        alpha2 * V[j, i - 1] / p_c[j, i]                                   # Consumption, real (6)
      C[j, i]    = p_c[j, i] * Cr[j, i]                                     # Consumption, nominal (7)
      H_h[j, i]  = lambdac * C[j, i - 1]                                    # Cash for transactions (8)
      B_h[j, i]  = V[j, i] * (lambda10 + lambda11 * rb[j, i] - lambda12 * rw[j, i])          # Domestic bills (9)
      BF_h[j, i] = (V[j, i] / xr[j, i]) * (lambda20 - lambda21 * rb[j, i] + lambda22 * rw[j, i]) # Foreign bills (10)
      M_h[j, i]  = V[j, i] - H_h[j, i] - B_h[j, i] - BF_h[j, i] * xr[j, i]  # Deposits as buffer stock (11)

      # B) FIRMS ####
      G[j, i]    = p_g[j, i] * Gr[j, i]                                     # Government spending, nominal (12)
      Y[j, i]    = C[j, i] + I[j, i] + G[j, i] + X[j, i] - IM[j, i]         # GDP, nominal (13)
      Yr[j, i]   = Cr[j, i] + Ir[j, i] + Gr[j, i] + Xr[j, i] - IMr[j, i]    # GDP, real (14)
      p_y[j, i]  = ifelse(Yr[j, i] > 0, Y[j, i] / Yr[j, i], 1)              # GDP deflator (15)
      N[j, i]    = sum(Nz[j, i, ])                                          # Employment (16)
      WB[j, i]   = wbar * N[j, i]                                           # Wage bill (17)
      FD[j, i]   = Y[j, i] - WB[j, i] - AF[j, i] - rl[j, i - 1] * L_d[j, i - 1]  # Profits = residual, all distributed (18)
      KT[j, i]   = sum(kappaj * x[j, i - 1, ])                         # Target capital (19)
      DA[j, i]   = delta * K[j, i - 1]                                      # Depreciation, real (20)
      AF[j, i]   = p_i[j, i] * DA[j, i]                                     # Amortisation funds at replacement cost (21)
      Ir[j, i]   = gamma * (KT[j, i] - K[j, i - 1]) + DA[j, i]              # Gross investment, real (22)
      I[j, i]    = p_i[j, i] * Ir[j, i]                                     # Gross investment, nominal (23)
      K[j, i]    = K[j, i - 1] + Ir[j, i] - DA[j, i]                        # Capital accumulation (24)
      L_d[j, i]  = L_d[j, i - 1] + I[j, i] - AF[j, i]                       # Loans fund net investment   (25)

      # INDUSTRIAL STRUCTURE (real terms) ####
      d[j, i, ]     = betaC * Cr[j, i] + betaI * Ir[j, i] + betaG * Gr[j, i] + chi * Xr[j, i]  # Final demand by industry (26)
      d_pat[j, i, ] = psiC * betaC * Cr[j, i] + psiI * betaI * Ir[j, i] + psiG * betaG * Gr[j, i]  # Import content of final demand (27)
      d_dom[j, i, ] = d[j, i, ] - d_im[j, i, ]                              # Domestic final demand (28)
      x[j, i, ]     = Leontief %*% d_dom[j, i, ]                            # Gross output (29)
      im_int[j, i, ] = Am %*% x[j, i, ]                                     # Intermediate imports (30)
      d_im[j, i, ]  = d_pat[j, i, ] * (IMr[j, i] - sum(im_int[j, i, ])) / sum(d_pat[j, i, ])  # Final imports = residual (31)
      Nz[j, i, ]    = x[j, i, ] * lab                                       # Employment by industry (32)
      
      # PRICES ####
      xN[j, i, ] = if (i < 3) x[j, i, ] else xN[j, i - 1, ] + phiN * (x[j, i - 1, ] - xN[j, i - 1, ])  # Normal output (33)
      mup[j, i, ] = if (i < 3) mup0 else mup0 + mup1 * (x[j, i - 1, ] / xN[j, i - 1, ] - 1)  # Current mark-ups (34)
      pS[j, i, ] = as.vector((xr[j, i] * t(pf) %*% Am %*% MkN + wbar * lab) %*%
                               solve(diag(nIndustries) - A %*% MkN)) / p0    # Reproduction prices, normalised (35)
      p[j, i, ]  = as.vector((xr[j, i] * t(pf) %*% Am %*% diag((1 + kappaj * delta) * (1 + mup[j, i, ])) + wbar * lab) %*%
                               solve(diag(nIndustries) - A %*% diag((1 + kappaj * delta) * (1 + mup[j, i, ])))) / p0  # Current prices, normalised (36)
      p_c[j, i]  = sum(p[j, i, ] * betaC)                                   # Consumer price index (37)
      p_i[j, i]  = sum(p[j, i, ] * betaI)                                   # Price of investment goods (38)
      p_g[j, i]  = sum(p[j, i, ] * betaG)                                   # Price of government purchases (39)
      p_x[j, i]  = sum(p[j, i, ] * chi)                                     # Export price (40)
      p_m[j, i]  = xr[j, i] * ifelse(IMr[j, i] > 0, sum(pf * (im_int[j, i, ] + d_im[j, i, ])) / IMr[j, i], 1)  # Import price (41)
      
      # C) BANKS ####
      L_s[j, i]  = L_s[j, i - 1] + (L_d[j, i] - L_d[j, i - 1])              # Loans supplied on demand (42)
      M_s[j, i]  = M_s[j, i - 1] + (L_s[j, i] - L_s[j, i - 1])              # Loans create deposits (43)
      B_b[j, i]  = M_h[j, i] - M_s[j, i]                                    # Bills held by banks (44)
      FB[j, i]   = rl[j, i - 1] * L_s[j, i - 1] + rb[j, i - 1] * B_b[j, i - 1] -
        rm[j, i - 1] * M_h[j, i - 1]                                         # Bank profits (45)

      # D) GOVERNMENT AND CENTRAL BANK ####
      F_cb[j, i] = rb[j, i - 1] * B_cb[j, i - 1]                            # Central bank profits (46)
      Gr[j, i]   = Gr0[j, i] - psi * (rb[j, i - 1] - rbar) * B_s[j, i - 1] / p_g[j, i]  # Fiscal rule (real spending) (47)
      PSBR[j, i] = G[j, i] + rb[j, i - 1] * B_s[j, i - 1] - TAX[j, i] - F_cb[j, i] # Borrowing requirement (48)
      B_s[j, i]  = B_s[j, i - 1] + PSBR[j, i]                               # Supply of domestic bills (49)
      B_cb[j, i] = B_s[j, i] - B_h[j, i] - B_b[j, i] - B_w[j, i]            # Central bank residual (50)
      H_s[j, i]  = H_s[j, i - 1] + (B_cb[j, i] - B_cb[j, i - 1])            # Supply of cash (51)

      # E) REST OF THE WORLD ####
      Xr[j, i]   = exp(eps0 + eps1 * log(p_m[j, i - 1] / p_x[j, i - 1]) + eps2 * log(yw[j, i]))  # Exports, real (52)
      IMr[j, i]  = exp(mu0 - mu1 * log(p_m[j, i - 1] / p_y[j, i - 1]) + mu2 * log(Yr[j, i]))  # Imports, real (53)
      X[j, i]    = p_x[j, i] * Xr[j, i]                                     # Exports, nominal (54)
      IM[j, i]   = p_m[j, i] * IMr[j, i]                                    # Imports, nominal (55)
      TB[j, i]   = X[j, i] - IM[j, i]                                       # Trade balance (56)
      CA[j, i]   = TB[j, i] + rw[j, i - 1] * BF_h[j, i - 1] * xr[j, i] -
        rb[j, i - 1] * B_w[j, i - 1]                                         # Current account (57)
      NETFA[j, i]= NETFA[j, i - 1] + CA[j, i] + CG[j, i]                    # Net foreign assets (58)
      B_w[j, i]  = BF_h[j, i] * xr[j, i] - NETFA[j, i]                      # Domestic bills held by RoW (59)
      xr[j, i]   = xr[j, i - 1] * exp(-phixr * CA[j, i] / max(Y[j, i], 1))  # Flexible exchange rate (60)

      # Stop when the solution no longer changes (convergence) ####
      if (max(abs(c(Y[j, i], V[j, i], p_c[j, i], xr[j, i]) - check0)) < tol) break
    }
  }
}

# Display the results ####
sfcGap <- max(abs(H_h[, 2:nPeriods] - H_s[, 2:nPeriods]))     # Hidden equation: H_h = H_s
cat(" ******************************")
cat("\n Industries =", nIndustries)
cat("\n Max |H_h - H_s| =", sfcGap)
cat("\n Min final imports by industry =", round(min(d_im[, 3:nPeriods, ]), 3))
cat("\n ******************************")
cat("\n Values at period", nPeriods, "(baseline | higher G): \n Y (nominal) =",
    round(Y[1, nPeriods], 2), "|", round(Y[2, nPeriods], 2),
    "\n Y (real) =", round(Yr[1, nPeriods], 2), "|", round(Yr[2, nPeriods], 2),
    "\n p =", round(p[1, nPeriods, ], 3), "|", round(p[2, nPeriods, ], 3),
    "\n p_c =", round(p_c[1, nPeriods], 3), "|", round(p_c[2, nPeriods], 3),
    "\n xr =", round(xr[1, nPeriods], 3), "|", round(xr[2, nPeriods], 3),
    "\n FD / Y =", round(FD[1, nPeriods] / Y[1, nPeriods], 3), "|", round(FD[2, nPeriods] / Y[2, nPeriods], 3))
cat("\n ******************************")

# Plot the results ####
indCol <- c("springgreen4", "orangered", "dodgerblue3")   # Industry colours
indLab <- c("Agriculture", "Manufacturing", "Services")   # Industry names
per    <- 3:nPeriods                                       # Periods shown

op = par(mfrow = c(3, 2), mar = c(4, 4, 3, 1))

# a) Consistency check (both scenarios): H_h - H_s should hug zero
plot(H_h[1, per] - H_s[1, per], type = "l", col = "seagreen", lwd = 2,
     font.main = 1, main = "a) Consistency check: H_h - H_s", xlab = "period", ylab = "",
     ylim = range(-1, 1))
lines(H_h[2, per] - H_s[2, per], col = "orange", lwd = 2, lty = 2)
abline(h = 0, lty = 3)
legend("topright", c("Baseline", "Higher G"), col = c("seagreen", "orange"),
       lwd = 2, lty = c(1, 2), bty = "n")

# b) Real GDP: baseline vs higher government spending
plot(Yr[2, per], type = "l", col = "coral3", lwd = 2, font.main = 1,
     main = "b) Real GDP", xlab = "period", ylab = "", ylim = range(Yr[, per]))
lines(Yr[1, per], col = "black", lwd = 2, lty = 2)
legend("bottomright", c("Higher G", "Baseline"), col = c("coral3", "black"),
       lwd = 2, lty = c(1, 2), bty = "n")

# c) Gross output by industry (higher G)
matplot(x[2, per, ], type = "l", lty = 1, lwd = 2, col = indCol, font.main = 1,
        main = "c) Gross output by industry (higher G)", xlab = "period", ylab = "")
legend("right", indLab, col = indCol, lwd = 2, bty = "n")

# d) Current (solid) and reproduction (dashed) prices by industry (higher G)
matplot(p[2, per, ], type = "l", lty = 1, lwd = 2, col = indCol, font.main = 1,
        main = "d) Current vs reproduction prices (higher G)", xlab = "period", ylab = "",
        ylim = range(p[2, per, ], pS[2, per, ]))
matlines(pS[2, per, ], lty = 2, lwd = 1, col = indCol)
legend("right", indLab, col = indCol, lwd = 2, bty = "n")

# e) Exchange rate and consumer prices (higher G)
plot(xr[2, per], type = "l", col = "black", lwd = 2, font.main = 1,
     main = "e) Exchange rate and price indices (higher G)", xlab = "period", ylab = "",
     ylim = range(xr[2, per], p_c[2, per], p_x[2, per]))
lines(p_c[2, per], col = "brown", lwd = 2, lty = 2)
lines(p_x[2, per], col = "dodgerblue", lwd = 2, lty = 3)
legend("bottomright", c("Exchange rate", "Consumer prices", "Export prices"),
       col = c("black", "brown", "dodgerblue"), lwd = 2, lty = 1:3, bty = "n")

# f) Real wage
plot(wbar / p_c[2, per], type = "l", col = "coral3", lwd = 2, font.main = 1,
     main = "f) Real wage rate", xlab = "period", ylab = "",
     ylim = range(wbar / p_c[, per]))
lines(wbar / p_c[1, per], col = "black", lwd = 2, lty = 2)
legend("topright", c("Higher G", "Baseline"), col = c("coral3", "black"),
       lwd = 2, lty = c(1, 2), bty = "n")

par(op)

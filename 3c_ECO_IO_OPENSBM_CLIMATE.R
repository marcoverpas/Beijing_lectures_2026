# *************************************************************************
#  Model ECO-IO-OPENSBM, climate block (3 industries, fixed prices)
#  Model IO-OPENSBM plus energy, CO2 emissions and temperature by industry, with climate feedback on investment
#  Sources: Godley & Lavoie, Monetary Economics, chapters 4, 7 and 12;
#           foreign-sector set-up as in the OPENSIMPLEST model;
#           IO treatment of trade as in Canelli et al. (2026);
#           ecological block as in the ECO-3IO-PC model (Florence keynote)
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
kappaj      <- c(0.8, 1.3, 0.3)       # Target capital-gross output ratios by industry, pre-warming values (agriculture, manufacturing, services)
omega1      <- 0.2         # Sensitivity of target capital to warming

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

# Ecosystem parameters ####
eps_en      <- c(4, 3, 1.5)           # Energy intensity by industry (EJ per unit of output)
eta_en      <- c(0.12, 0.15, 0.18)    # Share of renewable energy by industry
beta_e0     <- 0.07        # Initial CO2 intensity of non-renewable energy (Gt per EJ)
g_beta_e    <- 0.01        # Rate of decline of CO2 intensity of non-renewable energy
tcre        <- 1.65 / 1000 # Transient climate response to cumulative carbon emissions (C per GtC)
fnc         <- 0.34        # Non-CO2 fraction of total anthropogenic forcing
car         <- 3.67        # Coefficient converting Gt of carbon into Gt of CO2
tau         <- tcre / ((1 - fnc) * car)  # Warming per Gt of cumulative CO2 emissions
temp0       <- 1.2         # Temperature anomaly at the start of the simulation (C)
Gbase       <- 20          # Government spending (baseline)
Gshock      <- 25          # Government spending (scenario 2)
psi         <- 1           # Fiscal rule: share of the extra interest bill offset by lower spending
rbar        <- 0.02        # Fiscal rule: reference interest rate
eps0        <- log(0.1)    # Export equation: constant
eps1        <- 0.8         # Export equation: elasticity to exchange rate
eps2        <- 1           # Export equation: elasticity to foreign income
mu0         <- log(0.2)    # Import equation: constant (m = 0.2*y when xr = 1)
mu1         <- 0.8         # Import equation: elasticity to exchange rate
mu2         <- 1           # Import equation: elasticity to domestic income
phixr       <- 3           # Speed of exchange-rate adjustment to the current account

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
omega <- matrix(1, nScenarios, nPeriods) # Climate factor on target capital (1 = no warming)
KT    <- matrix(0, nScenarios, nPeriods)  # Target capital stock
DA    <- matrix(0, nScenarios, nPeriods)  # Depreciation allowances
AF    <- matrix(0, nScenarios, nPeriods)  # Amortisation funds
L_d   <- matrix(0, nScenarios, nPeriods)  # Demand for bank loans

# Industry-level variables as arrays [scenario, period, industry] ####
d     <- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Final demand (domestic + imported)
d_pat <- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Import content of final demand (pattern)
d_im  <- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Final demand met by imports
d_dom <- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Final demand met by domestic production
x     <- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Gross output
im_int<- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Intermediate imports
Nz    <- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # Employment by industry

# F) Ecosystem
EN    <- matrix(0, nScenarios, nPeriods)  # Total energy required for production
REN   <- matrix(0, nScenarios, nPeriods)  # Renewable energy
NEN   <- matrix(0, nScenarios, nPeriods)  # Non-renewable energy
beta_e<- matrix(beta_e0, nScenarios, nPeriods) # CO2 intensity of non-renewable energy
EMIS  <- matrix(0, nScenarios, nPeriods)  # CO2 emissions
EMISz <- array(0, dim = c(nScenarios, nPeriods, nIndustries))  # CO2 emissions by industry
CO2c  <- matrix(0, nScenarios, nPeriods)  # Cumulative CO2 emissions (since period 1)
TEMP  <- matrix(temp0, nScenarios, nPeriods)  # Atmospheric temperature anomaly

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
xr  <- matrix(1,     nScenarios, nPeriods)  # Nominal exchange rate (domestic price of foreign currency), flexible

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
      N[j, i]    = sum(Nz[j, i, ])                                          # Employment (total) (13)
      w[j, i]    = WB[j, i] / N[j, i]                                       # Wage rate (14)
      KT[j, i]   = omega[j, i] * sum(kappaj * x[j, i - 1, ])                       # Target capital (15)
      DA[j, i]   = delta * K[j, i - 1]                                      # Depreciation allowances (16)
      AF[j, i]   = DA[j, i]                                                 # Amortisation funds (17)
      I[j, i]    = gamma * (KT[j, i] - K[j, i - 1]) + DA[j, i]              # Gross investment (18)
      K[j, i]    = K[j, i - 1] + I[j, i] - DA[j, i]                         # Capital accumulation (19)
      L_d[j, i]  = L_d[j, i - 1] + I[j, i] - AF[j, i]                       # Loans fund net investment   (20)

      # INDUSTRIAL STRUCTURE ####
      d[j, i, ]     = betaC * C[j, i] + betaI * I[j, i] + betaG * G[j, i] + chi * X[j, i]  # Final demand by industry (21)
      d_pat[j, i, ] = psiC * betaC * C[j, i] + psiI * betaI * I[j, i] + psiG * betaG * G[j, i]  # Import content of final demand (22)
      d_dom[j, i, ] = d[j, i, ] - d_im[j, i, ]                              # Domestic final demand (23)
      x[j, i, ]     = Leontief %*% d_dom[j, i, ]                            # Gross output (24)
      im_int[j, i, ] = Am %*% x[j, i, ]                                     # Intermediate imports (25)
      d_im[j, i, ]  = d_pat[j, i, ] * (IM[j, i] - sum(im_int[j, i, ])) / sum(d_pat[j, i, ])  # Final imports = residual (26)
      Nz[j, i, ]    = x[j, i, ] / pr                                        # Employment by industry (27)
      
      # F) ECOSYSTEM ####
      EN[j, i]   = sum(eps_en * x[j, i, ])                                  # Energy required for production (28)
      REN[j, i]  = sum(eps_en * eta_en * x[j, i, ])                         # Renewable energy (29)
      NEN[j, i]  = EN[j, i] - REN[j, i]                                     # Non-renewable energy (30)
      beta_e[j, i] = beta_e[j, i - 1] * (1 - g_beta_e)                      # Declining CO2 intensity (31)
      EMIS[j, i] = beta_e[j, i] * NEN[j, i]                                 # CO2 emissions (32)
      EMISz[j, i, ] = beta_e[j, i] * eps_en * (1 - eta_en) * x[j, i, ]      # CO2 emissions by industry (33)
      CO2c[j, i] = CO2c[j, i - 1] + EMIS[j, i]                              # Cumulative emissions (34)
      TEMP[j, i] = temp0 + tau * CO2c[j, i]                                   # Temperature anomaly (35)
      omega[j, i] = 1 - omega1 * (TEMP[j, i - 1] - temp0)               # Warming and target capital (36)
      
      # C) BANKS ####
      L_s[j, i]  = L_s[j, i - 1] + (L_d[j, i] - L_d[j, i - 1])              # Loans supplied on demand (37)
      M_s[j, i]  = M_s[j, i - 1] + (L_s[j, i] - L_s[j, i - 1])              # Loans create deposits (38)
      B_b[j, i]  = M_h[j, i] - M_s[j, i]                                    # Bills held by banks (39)
      FB[j, i]   = rl[j, i - 1] * L_s[j, i - 1] + rb[j, i - 1] * B_b[j, i - 1] -
        rm[j, i - 1] * M_h[j, i - 1]                                         # Bank profits (40)

      # D) GOVERNMENT AND CENTRAL BANK ####
      F_cb[j, i] = rb[j, i - 1] * B_cb[j, i - 1]                            # Central bank profits (41)
      G[j, i]    = G0[j, i] - psi * (rb[j, i - 1] - rbar) * B_s[j, i - 1]   # Fiscal rule (42)
      PSBR[j, i] = G[j, i] + rb[j, i - 1] * B_s[j, i - 1] - TAX[j, i] - F_cb[j, i] # Borrowing requirement (43)
      B_s[j, i]  = B_s[j, i - 1] + PSBR[j, i]                               # Supply of domestic bills (44)
      B_cb[j, i] = B_s[j, i] - B_h[j, i] - B_b[j, i] - B_w[j, i]            # Central bank residual (45)
      H_s[j, i]  = H_s[j, i - 1] + (B_cb[j, i] - B_cb[j, i - 1])            # Supply of cash (46)

      # E) REST OF THE WORLD ####
      X[j, i]    = exp(eps0 + eps1 * log(xr[j, i - 1]) + eps2 * log(yw[j, i]))  # Exports (47)
      IM[j, i]   = exp(mu0 - mu1 * log(xr[j, i - 1]) + mu2 * log(Y[j, i]))      # Imports (48)
      TB[j, i]   = X[j, i] - IM[j, i]                                       # Trade balance (49)
      CA[j, i]   = TB[j, i] + rw[j, i - 1] * BF_h[j, i - 1] * xr[j, i] -
        rb[j, i - 1] * B_w[j, i - 1]                                         # Current account (50)
      NETFA[j, i]= NETFA[j, i - 1] + CA[j, i] + CG[j, i]                    # Net foreign assets (51)
      B_w[j, i]  = BF_h[j, i] * xr[j, i] - NETFA[j, i]                      # Domestic bills held by RoW (52)
      xr[j, i]   = xr[j, i - 1] * exp(-phixr * CA[j, i] / max(Y[j, i], 1))  # Flexible exchange rate (53)
    }
  }
}

# Display the results ####
sfcGap <- max(abs(H_h[, 2:nPeriods] - H_s[, 2:nPeriods]))     # Hidden equation: H_h = H_s
ioGap  <- max(abs(apply(x[, 2:nPeriods, ], c(1, 2), sum) - 
                  apply(x[, 2:nPeriods, ], c(1, 2), function(v) sum(A %*% v)) -
                  apply(d_dom[, 2:nPeriods, ], c(1, 2), sum)))  # IO check: x = A x + d_dom
cat(" ******************************")
cat("\n Industries =", nIndustries)
cat("\n Max |H_h - H_s| =", sfcGap)
cat("\n Max IO gap =", ioGap)
cat("\n Min final imports by industry =", round(min(d_im[, 2:nPeriods, ]), 3))
cat("\n Max import share of final demand =", round(max((d_im / d)[, 3:nPeriods, ]), 3))
cat("\n ******************************")
cat("\n Values at period", nPeriods, "(baseline | higher G): \n Y =",
    round(Y[1, nPeriods], 2), "|", round(Y[2, nPeriods], 2),
    "\n x =", round(x[1, nPeriods, ], 2), "|", round(x[2, nPeriods, ], 2),
    "\n N =", round(N[1, nPeriods], 2), "|", round(N[2, nPeriods], 2),
    "\n EMIS =", round(EMIS[1, nPeriods], 2), "|", round(EMIS[2, nPeriods], 2),
    "\n TEMP =", round(TEMP[1, nPeriods], 2), "|", round(TEMP[2, nPeriods], 2),
    "\n climate factor (omega) =", round(omega[1, nPeriods], 4), "|", round(omega[2, nPeriods], 4),
    "\n xr =", round(xr[1, nPeriods], 3), "|", round(xr[2, nPeriods], 3))
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

# b) GDP: baseline vs higher government spending
plot(Y[2, per], type = "l", col = "coral3", lwd = 2, font.main = 1,
     main = "b) GDP", xlab = "period", ylab = "", ylim = range(Y[, per]))
lines(Y[1, per], col = "black", lwd = 2, lty = 2)
legend("bottomright", c("Higher G", "Baseline"), col = c("coral3", "black"),
       lwd = 2, lty = c(1, 2), bty = "n")

# c) Gross output by industry (higher G)
matplot(x[2, per, ], type = "l", lty = 1, lwd = 2, col = indCol, font.main = 1,
        main = "c) Gross output by industry (higher G)", xlab = "period", ylab = "")
legend("right", indLab, col = indCol, lwd = 2, bty = "n")

# d) CO2 emissions by industry (higher G)
matplot(EMISz[2, per, ], type = "l", lty = 1, lwd = 2, col = indCol, font.main = 1,
        main = "d) CO2 emissions by industry (higher G)", xlab = "period", ylab = "Gt")
legend("topright", indLab, col = indCol, lwd = 2, bty = "n")

# e) Temperature anomaly
plot(TEMP[2, per], type = "l", col = "coral3", lwd = 2, font.main = 1,
     main = "e) Atmospheric temperature anomaly", xlab = "period", ylab = "C",
     ylim = range(TEMP[, per]))
lines(TEMP[1, per], col = "black", lwd = 2, lty = 2)
legend("bottomright", c("Higher G", "Baseline"), col = c("coral3", "black"),
       lwd = 2, lty = c(1, 2), bty = "n")

# f) Warming and the climate factor on target capital
plot(omega[2, per], type = "l", col = "coral3", lwd = 2, font.main = 1,
     main = "f) Climate factor on target capital", xlab = "period", ylab = "",
     ylim = range(omega[, per]))
lines(omega[1, per], col = "black", lwd = 2, lty = 2)
legend("topright", c("Higher G", "Baseline"), col = c("coral3", "black"),
       lwd = 2, lty = c(1, 2), bty = "n")

par(op)

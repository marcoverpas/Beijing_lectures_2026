# *************************************************************************
#  Model ABM-OPENSBM (agent-based households, open economy, flexible exchange rate)
#  Model OPENSBM-FLEX with heterogeneous households and a job lottery
#  Sources: Godley & Lavoie, Monetary Economics, chapters 4, 7 and 12;
#           foreign-sector set-up as in the OPENSIMPLEST model;
#           agent-based set-up as in the Leeds lectures (ABM-PC, ABM-BMW)
#  Author: Marco Veronese Passarella
#  Last change: 16/11/2026
# *************************************************************************
#  Conventions: upper-case = MACRO total; lower-case = MICRO (one household)
# *************************************************************************
#  Story:
#    - each household decides how much it wants to spend (its OWN alpha1,
#      which falls when the interest rate rises);
#    - firms plan investment (aggregate accelerator, as in SBM);
#    - the economy needs 1/pr workers for each unit of planned demand;
#    - a random job lottery fills those jobs (some stay unfilled = friction);
#    - part of planned demand is met by imports (aggregate import function);
#    - goods are served first to foreign buyers (exports), then to the
#      government, then to firms (investment), then to households,
#      first-come-first-served;
#    - the wage bill left after interest and depreciation is split equally
#      among the employed; bank profits are split equally among households;
#    - households pay taxes and allocate wealth between cash (for
#      transactions), domestic bills, foreign bills and deposits (buffer);
#    - the exchange rate adjusts to the current account; the rest of the
#      world holds domestic bills as a residual.
#  One single random shuffle of households per period decides BOTH who gets a
#  job AND who reaches the shop first.
# *************************************************************************

# Clear environment
rm(list = ls(all = TRUE))

# Set model parameters ####
nPeriods    <- 200         # Periods
nHouseholds <- 180         # Number of households (workforce)
MC          <- 50          # Monte Carlo repetitions
s           <- 0.1         # Size of the hiring randomness (0 = no friction)
shockStart  <- 101         # Period at which government spending rises
alpha10m    <- 0.68        # Mean autonomous component of the propensity to consume out of income
alpha11     <- 4           # Sensitivity of the propensity to consume to the interest rate
alpha1d     <- 0.1         # Spread of alpha10 across households (0 = homogeneous)
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
rb          <- 0.02        # Interest rate on bills
rm          <- 0.02        # Interest rate on deposits
rl          <- 0.02        # Interest rate on loans
rw          <- 0.02        # Interest rate on foreign bills
yw          <- 200         # Foreign income
eps0        <- log(0.1)    # Export equation: constant
eps1        <- 0.8         # Export equation: elasticity to exchange rate
eps2        <- 1           # Export equation: elasticity to foreign income
mu0         <- log(0.2)    # Import equation: constant (m = 0.2*y when xr = 1)
mu1         <- 0.8         # Import equation: elasticity to exchange rate
phixr       <- 3           # Speed of exchange-rate adjustment to the current account
G           <- rep(20, nPeriods)   # Government spending (planned)
G[shockStart:nPeriods] <- 25       # Higher government spending
psi         <- 1                   # Fiscal rule: share of the extra interest bill offset by lower spending
rbar        <- 0.02                # Fiscal rule: reference interest rate

# Heterogeneous, time-invariant propensity to consume out of income ####
set.seed(123)
alpha10 <- runif(nHouseholds, alpha10m - alpha1d, alpha10m + alpha1d)

# Define macro variables (results) to be stored ####
store = list(Y    = matrix(0, nPeriods, MC),   # Output / income (GDP)
             C    = matrix(0, nPeriods, MC),   # Consumption
             I    = matrix(0, nPeriods, MC),   # Investment
             V    = matrix(0, nPeriods, MC),   # Household wealth
             H_h  = matrix(0, nPeriods, MC),   # Cash held by households
             B_h  = matrix(0, nPeriods, MC),   # Bills held by households
             M_h  = matrix(0, nPeriods, MC),   # Deposits held by households
             PSBR = matrix(0, nPeriods, MC),   # Public sector borrowing requirement
             X    = matrix(0, nPeriods, MC),   # Exports
             IM   = matrix(0, nPeriods, MC),   # Imports
             CA   = matrix(0, nPeriods, MC),   # Current account
             XR   = matrix(0, nPeriods, MC),   # Exchange rate
             BF_h = matrix(0, nPeriods, MC),   # Foreign bills held by households (domestic currency)
             UR   = matrix(0, nPeriods, MC),   # Unemployment rate
             GINI = matrix(0, nPeriods, MC))   # Gini index of household wealth

# Store micro values (for MC = 1)
vHist = matrix(0, nPeriods, nHouseholds)   # Wealth of each household

# Gini index (auxiliary function)
gini <- function(z) { z <- sort(pmax(z, 0)); n <- length(z)
  if (sum(z) == 0) return(0); sum((2 * (1:n) - n - 1) * z) / (n * sum(z)) }

# Record the worst gap between H_h and H_s
sfcGap = 0

# Start the MC loop ####
for (mc in 1:MC) {

  # Set randomness seed
  set.seed(mc)

  # Define and initialise the stocks (MICRO)
  v  = rep(0, nHouseholds)   # Micro: household wealth
  h  = rep(0, nHouseholds)   # Micro: cash
  b  = rep(0, nHouseholds)   # Micro: domestic bills
  bf = rep(0, nHouseholds)   # Micro: foreign bills (foreign currency)
  m  = rep(0, nHouseholds)   # Micro: deposits
  yd = rep(0, nHouseholds)   # Micro: disposable income (LAST period)
  c  = rep(0, nHouseholds)   # Micro: consumption (LAST period)

  # Define and initialise the stocks (MACRO)
  K = 0; L = 0; M_s = 0; B_b = 0; Ylag = 0     # Firms and banks
  B_s = 0; B_cb = 0; H_s = 0                   # Government and central bank
  xr = 1; NETFA = 0; B_w = 0                   # Rest of the World

  # Start time loop
  for (i in 1:nPeriods) {

    ## TICK 1: firms plan investment, households plan consumption ####
    DA  = delta * K                                     # Macro: depreciation
    Ipl = max(0, gamma * (kappa * Ylag - K) + DA)       # Macro: planned investment
    alpha1 = alpha10 - alpha11 * rb                     # Micro: propensity to consume (falls with the interest rate)
    cd  = pmax(0, pmin(alpha1 * yd + alpha2 * v, v + yd))  # Micro: planned consumption (never negative)
    X   = exp(eps0 + eps1 * log(xr) + eps2 * log(yw))  # Macro: exports (lagged exchange rate)
    Gpl = G[i] - psi * (rb - rbar) * B_s                # Macro: fiscal rule (B_s is still last period's stock here)
    AD  = X + Gpl + Ipl + sum(cd)                       # Macro: planned demand
    mm  = exp(mu0 - mu1 * log(xr))                      # Macro: import propensity (lagged exchange rate)
    IM  = AD * mm / (1 + mm)                            # Macro: imports (= mm * domestic output when no friction)
    N_d = (AD - IM) / pr                                # Macro: labour needed

    ## TICK 2: job lottery ####
    N = min(floor(N_d * runif(1, 1 - s, 1 + s)), floor(N_d), nHouseholds)
    Ypot = N * pr + IM                                  # Macro: goods available (domestic + imported)

    ## TICK 3: households are re-shuffled ####
    order = sample(nHouseholds)                         # Queue for both jobs and goods

    ## TICK 4: goods are served: exports, government, firms, then households ####
    Xs  = min(X, Ypot)                                  # Macro: exports served
    Gs  = min(Gpl, Ypot - Xs)                           # Macro: government purchases served
    Is  = min(Ipl, Ypot - Xs - Gs)                      # Macro: investment served
    YC  = Ypot - Xs - Gs - Is                           # Macro: goods left for households
    cdq = cd[order]                                     # Micro: planned demand in queue order
    cda = cumsum(cdq) - cdq                             # Micro: goods claimed by those ahead
    cds = pmin(cdq, pmax(0, YC - cda))                  # Micro: actually served
    c   = rep(0, nHouseholds); c[order] = cds           # Micro: actual consumption
    Y   = Xs + Gs + Is + sum(c) - IM                    # Macro: output (GDP) = domestic goods actually sold

    ## TICK 5: firms and banks ####
    Llag = L; M_slag = M_s; B_blag = B_b
    WB  = Y - rl * Llag - DA                            # Macro: wage bill = residual
    K   = K + Is - DA                                   # Macro: capital accumulation
    L   = L + Is - DA                                   # Macro: loans finance net investment
    M_s = M_s + (L - Llag)                              # Macro: loans create deposits
    FB  = rl * Llag + rb * B_blag - rm * sum(m)         # Macro: bank profits (m still lagged here)

    ## TICK 6: incomes, taxes, wealth ####
    wage = rep(0, nHouseholds)
    if (N >= 1) wage[order[1:N]] = WB / N               # Micro: wage of the employed
    xrlag  = xr
    intinc = rb * b + rm * m + rw * bf * xr             # Micro: interest on last period's assets (xr not yet updated)
    income = wage + FB / nHouseholds + intinc           # Micro: total income
    tax    = theta * income                             # Micro: taxes
    yd     = income - tax                               # Micro: disposable income (also used NEXT period)
    v      = v + yd - c                                 # Micro: wealth accumulation (before capital gains)

    ## TICK 7: rest of the world: current account, exchange rate, capital gains ####
    CA  = Xs - IM + rw * sum(bf) * xrlag - rb * B_w     # Macro: current account (B_w still lagged)
    xr  = xrlag * exp(-phixr * CA / max(Y, 1))          # Macro: flexible exchange rate
    cg  = (xr - xrlag) * bf                             # Micro: capital gains on foreign bills
    v   = v + cg                                        # Micro: wealth incl. capital gains
    
    ## TICK 8: portfolio choice ####
    h  = pmax(0, pmin(lambdac * c, v))                  # Micro: cash for transactions
    b  = pmax(0, pmin(v * (lambda10 + lambda11 * rb - lambda12 * rw), v - h))  # Micro: domestic bills
    bf = pmax(0, pmin(v * (lambda20 - lambda21 * rb + lambda22 * rw), v - h - b)) / xr  # Micro: foreign bills
    m  = v - h - b - bf * xr                            # Micro: deposits = buffer stock (< 0 = overdraft)

    ## TICK 9: banks, government, central bank and rest of the world ####
    NETFA = NETFA + CA + sum(cg)                        # Macro: net foreign assets
    B_w   = sum(bf) * xr - NETFA                        # Macro: domestic bills held by RoW
    B_cblag = B_cb
    B_b  = sum(m) - M_s                                 # Macro: bills held by banks
    F_cb = rb * B_cb                                    # Macro: central bank profits (on last period's bills)
    PSBR = Gs + rb * B_s - sum(tax) - F_cb              # Macro: public sector borrowing requirement
    B_s  = B_s + PSBR                                   # Macro: supply of bills
    B_cb = B_s - sum(b) - B_b - B_w                     # Macro: central bank residual
    H_s  = H_s + (B_cb - B_cblag)                       # Macro: supply of cash
    sfcGap = max(sfcGap, abs(sum(h) - H_s))             # Hidden equation: H_h = H_s
    Ylag = Y

    # Store micro values (for MC = 1)
    if (mc == 1) vHist[i, ] = v

    # Store macro values
    store$Y[i, mc] = Y;          store$C[i, mc] = sum(c);   store$I[i, mc] = Is
    store$V[i, mc] = sum(v);     store$H_h[i, mc] = sum(h); store$B_h[i, mc] = sum(b)
    store$M_h[i, mc] = sum(m);   store$PSBR[i, mc] = PSBR
    store$X[i, mc] = Xs;         store$IM[i, mc] = IM;      store$CA[i, mc] = CA
    store$XR[i, mc] = xr;        store$BF_h[i, mc] = sum(bf) * xr
    store$UR[i, mc] = (nHouseholds - N) / nHouseholds
    store$GINI[i, mc] = gini(v)
  }
}

# Display the results ####
meanY <- rowMeans(store$Y); late1 <- 81:100; late2 <- 181:200
cat(" ******************************")
cat("\n Households =", nHouseholds, "| MC runs =", MC, "| s =", s)
cat("\n Max |H_h - H_s| =", sfcGap)
cat("\n ******************************")
cat("\n Mean values, periods 81-100 | 181-200: \n Y =", round(mean(meanY[late1]), 2), "|",
    round(mean(meanY[late2]), 2),
    "\n UR =", round(mean(rowMeans(store$UR)[late1]), 3), "|", round(mean(rowMeans(store$UR)[late2]), 3),
    "\n V =", round(mean(rowMeans(store$V)[late1]), 2), "|", round(mean(rowMeans(store$V)[late2]), 2),
    "\n Gini (wealth) =", round(mean(rowMeans(store$GINI)[late1]), 3), "|",
    round(mean(rowMeans(store$GINI)[late2]), 3),
    "\n xr =", round(mean(rowMeans(store$XR)[late1]), 3), "|", round(mean(rowMeans(store$XR)[late2]), 3),
    "\n (aggregate OPENSBM-FLEX: Y = 131.86 | 165.12; xr = 1.189 | 1.369)")
cat("\n ******************************")

# Plot the results (grey = runs, bold = MC mean) ####
op = par(mfrow = c(3, 2), mar = c(4, 4, 3, 1))

# a) Output
matplot(store$Y, type = "l", lty = 1, col = "grey85", font.main = 1,
        main = "a) Output (GDP)", xlab = "period", ylab = "")
lines(rowMeans(store$Y), lwd = 2, col = "dodgerblue")
segments(1, 131.86, shockStart - 1, 131.86, lty = 2); segments(shockStart, 165.12, nPeriods, 165.12, lty = 2)
legend("bottomright", c("MC mean", "Aggregate OPENSBM-FLEX"), col = c("dodgerblue", "black"),
       lwd = c(2, 1), lty = c(1, 2), bty = "n")

# b) Consumption and investment
matplot(store$C, type = "l", lty = 1, col = "grey85", font.main = 1,
        main = "b) Consumption and investment", xlab = "period", ylab = "",
        ylim = range(0, store$C))
matlines(store$I, lty = 1, col = "grey85")
lines(rowMeans(store$C), lwd = 2, col = "aquamarine4")
lines(rowMeans(store$I), lwd = 2, col = "orchid")
legend("right", c("Consumption", "Investment"), col = c("aquamarine4", "orchid"), lwd = 2, bty = "n")

# c) Unemployment rate (emergent)
matplot(store$UR, type = "l", lty = 1, col = "grey88", font.main = 1,
        main = "c) Unemployment rate (emergent)", xlab = "period", ylab = "")
lines(rowMeans(store$UR), lwd = 2, col = "salmon")

# d) Household portfolio (MC mean)
plot(rowMeans(store$V), type = "l", lwd = 2, col = "black", font.main = 1,
     main = "d) Household wealth and portfolio (MC mean)", xlab = "period", ylab = "",
     ylim = range(0, 1.45 * rowMeans(store$V)))
lines(rowMeans(store$M_h), lwd = 2, col = "steelblue", lty = 2)
lines(rowMeans(store$B_h), lwd = 2, col = "firebrick", lty = 3)
lines(rowMeans(store$BF_h), lwd = 2, col = "darkorange", lty = 4)
lines(rowMeans(store$H_h), lwd = 2, col = "seagreen", lty = 5)
legend("topright", c("Wealth", "Deposits", "Domestic bills", "Foreign bills", "Cash"),
       col = c("black", "steelblue", "firebrick", "darkorange", "seagreen"), lwd = 2, lty = 1:5,
       bty = "n", cex = 0.8, ncol = 2)

# e) Exchange rate
matplot(store$XR[3:nPeriods, ], type = "l", lty = 1, col = "grey88", font.main = 1,
        main = "e) Exchange rate (from period 3)", xlab = "period", ylab = "")
lines(rowMeans(store$XR[3:nPeriods, ]), lwd = 2, col = "black")

# f) Gini index of household wealth
matplot(store$GINI, type = "l", lty = 1, col = "grey88", font.main = 1,
        main = "f) Gini index of household wealth", xlab = "period", ylab = "")
lines(rowMeans(store$GINI), lwd = 2, col = "darkorange")

par(op)

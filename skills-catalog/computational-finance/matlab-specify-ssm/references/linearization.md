# Linearizing Stochastic Volatility

Stochastic volatility (Harvey, Ruiz & Shephard 1994):

$$y_t = \exp(h_t/2)\,\zeta_t,\quad \zeta_t \sim N(0,1); \qquad h_{t+1} = \nu + \phi\, h_t + \eta_t,\quad \eta_t \sim N(0, \sigma_\eta^2)$$

1. Square both sides and take logs: $\log(y_t^2) = h_t + \log(\zeta_t^2)$.
2. Since $\zeta_t \sim N(0,1)$, $\zeta_t^2 \sim \chi^2(1)$, so $\log(\zeta_t^2)$ has mean $-1.2704$ and variance $\pi^2/2$.
3. Define $y^*_t = \log(y_t^2)$. The linearized observation equation is $y^*_t = h_t - 1.2704 + \varepsilon^*_t$, where $\varepsilon^*_t = \log(\zeta_t^2) + 1.2704$ has mean 0 and variance $\pi^2/2$ but is not Gaussian (it is a centered log-$\chi^2(1)$ variable). `ssm` approximates it by $N(0, \pi^2/2)$, so `estimate` gives quasi-ML estimates.
4. The offset $-1.2704$ is a known intercept on the constant-1 state, which also carries $\nu$ as a NaN in A. States $[h_t;\, 1]$:
   - A = [NaN NaN; 0 1], B = [NaN; 0], C = [1 -1.2704]
   - D = `sqrt(pi^2/2)` (about 2.22), known, not NaN
   - StateType [0; 1]
   - NaN-form

Build the model on the transformed data `ystar = log(y.^2)`.

----
Copyright 2026 The MathWorks, Inc.
----

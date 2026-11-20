# Standard Models

State vectors and system matrices of standard models. Unknown entries are NaN in NaN-form, or `params(i)` in a parameter-mapping function.

| Model | States (m) | A | B | C | D | StateType | Form |
|-------|-----------|---|---|---|---|---|---|
| Local level | $\mu_t$ (1) | 1 | $\sigma_\xi$ | 1 | $\sigma_\varepsilon$ | 2 | NaN-form |
| Local linear trend | $[\mu_t;\ \nu_t]$ (2) | [1 1; 0 1] | diag($\sigma_\xi, \sigma_\zeta$) | [1 0] | $\sigma_\varepsilon$ | [2; 2] | NaN-form |
| Basic structural, quarterly dummy seasonal | $[\mu_t;\ \nu_t;\ \gamma_t;\ \gamma_{t-1};\ \gamma_{t-2}]$ (5) | blkdiag([1 1; 0 1], [-1 -1 -1; 1 0 0; 0 1 0]) | [diag($\sigma_\xi, \sigma_\zeta, \sigma_\omega$); zeros(2, 3)] | [1 0 1 0 0] | $\sigma_\varepsilon$ | all 2 | NaN-form |
| ARMA(2,1) | $[y_t;\ \phi_2 y_{t-1} + \theta_1 \zeta_t]$ (2) | [$\phi_1$ 1; $\phi_2$ 0] | [$\sigma$; $\theta_1\sigma$] | [1 0] | `[]` | [0; 0] | ParamMap ($\sigma$ in two rows of B) |
| ARMA(p,q) | r = max(p, q+1) | first column $[\phi_1; \ldots; \phi_r]$, `eye(r-1)` in the upper right, last row otherwise 0 ($\phi_i = 0$ for i > p) | $\sigma\,[1;\ \theta_1;\ \ldots;\ \theta_{r-1}]$ ($\theta_j = 0$ for j > q) | [1, zeros(1, r-1)] | `[]` | all 0 | ParamMap ($\sigma$ in several rows of B) |
| Factor model | factors $f_t$ (r) | $\Phi$ | `chol(Sigma_u, 'lower')` | $\Lambda$ | `chol(Sigma_e, 'lower')` | all 0 | NaN-form if each entry is one parameter |

----
Copyright 2026 The MathWorks, Inc.
----

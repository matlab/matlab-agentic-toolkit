# Problem Classification

The class you assign decides three things: which solver to use, what guarantee you can promise (global vs local), and how you'll verify. Getting this right is the highest-value step in the workflow.

## Check for domain-specific tools first

Before formulating with `optimproblem`, check if a purpose-built tool exists for the user's domain. These tools encode domain structure (constraints, typical objectives, standard forms) that the generic path discards:

- **Finance:** `Portfolio`, `PortfolioCVaR`, `PortfolioMAD` (Financial Toolbox)
- **Control:** `lqr`, `lqg`, `mpc` (Control System Toolbox / MPC Toolbox)
- **Simulink parameter tuning:** `sdo.optimize`, Response Optimizer (Simulink Design Optimization)

**Method:** search the doc for your domain keyword + "MATLAB" + "optimize" or "toolbox." If a tool exists, confirm it's licensed (`ver` / `license('test', ...)`) before committing to it.

## Problem class → solver → guarantee

| Class | Typical MATLAB solver | Guarantee at success |
|---|---|---|
| Linear program (LP) | `linprog` | **Global** optimum (convex) |
| Quadratic program (QP), convex | `quadprog` | **Global** optimum |
| Quadratic program, nonconvex (indefinite `H`) | `fmincon` (NOT `quadprog`) | Local only |
| Second-order cone program (SOCP) | `coneprog` | **Global** optimum (convex) |
| Mixed-integer linear (MILP) | `intlinprog` | **Global** to a gap; NP-hard |
| Mixed-integer quadratic/nonlinear (MIQP/MINLP) | `ga` or `surrogateopt` with integer constraints | Heuristic (no proof) |
| Linear least squares | `lsqlin`, `\` (mldivide) | **Global** optimum (convex) |
| Nonlinear least squares | `lsqnonlin`, `lsqcurvefit` | Local optimum |
| Smooth nonlinear (NLP) | `fmincon`, `fminunc` | Local optimum (global only if convex) |
| Nonsmooth / derivative-free | `patternsearch`, `surrogateopt` | Local; no gradients needed |
| Global (heuristic) | `GlobalSearch`, `MultiStart`, `ga`, `particleswarm` | *Attempts* global; **no proof** |
| Multi-objective | `paretosearch`, `gamultiobj` | Pareto set (no single optimum) |
| Equation solving | `fsolve` | A solution (not a minimum) |

**Integer + nonlinear:** `intlinprog` is linear-only. For integer variables with a nonlinear/quadratic objective or constraint, confirm `ga`/`surrogateopt` (Global Optimization Toolbox) are available, or reformulate to MILP.

## Nonconvex QP — check `eig(H)` yourself

`quadprog`'s convex algorithm cannot solve a nonconvex (indefinite-`H`) QP, but how it fails is not uniform: without bounds it refuses outright (negative exit flag); **with finite bounds it may stall and return a positive flag at a non-optimal point** (e.g., the saddle at the origin when the true boxed optimum is at a corner). A positive flag is NOT proof the QP was solved.

**Robust move:** test convexity up front with `eig(H)` — any negative eigenvalue means nonconvex. Route to `fmincon` (local) or reformulate.

## Convexity — global vs local

If the problem is **convex**, any local optimum is the global optimum. If **nonconvex**, a solver returns *a* local optimum — don't claim more.

Quick "it's convex" checks:
- Objective is linear, or sum-of-squares of linear residuals, or positive-semidefinite quadratic
- AND all constraints are linear or convex inequalities

When unsure, treat as nonconvex (safe assumption for what you promise).

## Watch for a hidden easier class

Before accepting a general-NLP framing, check:
- Is the objective a **sum of squares**? → `lsqnonlin`/`lsqcurvefit` (better convergence)
- Is everything actually **linear / quadratic**? → `linprog`/`quadprog` (global + fast)
- Is the only nonsmoothness an `abs`/`max`? → may be reformulable to LP/QP

Recognizing the true class is often the single biggest improvement you can make.

---
Copyright 2026 The MathWorks, Inc.

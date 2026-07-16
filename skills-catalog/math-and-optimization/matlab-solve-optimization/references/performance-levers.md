# Performance Levers

**Correctness first, always.** Apply nothing here until the answer is right and verified. After any change, re-run validation — the answer must not change. A faster path to a *different* answer is a bug, not a speedup.

## When to reach for this file (triggers)

- The solve is slow or `funcCount` is very large
- The same problem is solved **repeatedly** (a sweep, an online loop)
- The problem is **large** (many variables/constraints, sparse structure)
- It must be **deployed** — embedded, real-time, or run where MATLAB isn't installed

## Lever 1 — Analytic gradients / Jacobian

Gradient-based solvers estimate derivatives by finite differences by default, costing many extra objective evaluations and adding noise. Supplying analytic gradients is usually the biggest single win.

```matlab
options = optimoptions('fmincon', ...
    SpecifyObjectiveGradient=true, ...
    SpecifyConstraintGradient=true);
```

For least-squares, return the Jacobian from the residual function.

**Always verify** with `checkGradients` — a wrong gradient causes silent stalls, which is worse than slow. Trade-off: more code to write and maintain.

## Lever 2 — Sparsity

For large problems with known structure, store matrices as `sparse` and supply sparsity patterns so the solver skips known-zero entries:

```matlab
options = optimoptions('fmincon', ...
    HessPattern=hess_pattern, ...          % for Hessian structure
    HessianMultiplyFcn=@hessmult);         % for Hessian vector product
```

```matlab
options = optimoptions('lsqnonlin', ...
    JacobPattern=jacob_pattern, ...        % for Jacobian
    JacobianMultiplyFcn=@jacobmult);       % for Jacobian vector product
```

Big speed/memory win when the structure is genuinely sparse; no benefit (slight overhead) when dense.

## Lever 3 — Warm starting / problem reuse

In an online loop or a sweep of similar problems, seed `x0` from the previous solution:

```matlab
x0 = x_prev_solution;  % converges faster from a nearby start
[x, fval] = fmincon(fun, x0, ...);
x_prev_solution = x;   % save for next iteration
```

Some LP/QP workflows support explicit warm starts. Helpful only when consecutive problems are genuinely similar.

## Lever 4 — Code generation (deployment / real-time)

Use **MATLAB Coder** to generate C/C++ for embedded or MATLAB-free deployment. Key caveats:

- **Problem-based `solve` does not support codegen.** Convert to solver-based first with `prob2struct`.
- **The default algorithm usually does NOT support codegen.** You must set a codegen-capable algorithm explicitly. Don't hardcode which one — it's release-specific. Consult "Code Generation in Optimization Toolbox" in the docs and confirm in the session.
- Codegen needs **fixed-size inputs** and has other restrictions.
- **Always validate** generated code against MATLAB: `max(abs(x_codegen - x_matlab))` should be ≈1e-10; a gap of ~1e-5+ means a real discrepancy.
- **Bounded effort:** if codegen restrictions eat hours, confirm it's genuinely needed for embedded deployment. Fall back to the MATLAB solver for exploratory work.

Trade-off: real engineering effort — worth it for deployment, overkill for one-off analysis.

## Lever 5 — Integer programs (MILP) that are too slow

Integer solve time is dominated by the **formulation**, not solver options. Tighten it:

- **Smaller big-M constants** — oversized M values weaken LP relaxations and explode the tree
- **Tighter variable bounds** — every tighter bound prunes branches
- **Valid inequalities** — extra constraints that don't cut feasible integer points but tighten the relaxation
- **Warm-start** from a known feasible solution where supported

Set a **relative-gap or time limit** and accept the best incumbent when a proven optimum isn't worth the wait — report the gap honestly.

---

**Note:** Parallel evaluation (`UseParallel`) is already covered in `solver-tuning.md`. Expensive black-box handling (`surrogateopt`, `bayesopt`) and global-search methods (`MultiStart`, `GlobalSearch`) are also covered there. This file addresses levers that are NOT already in the solver tuning reference.

---
Copyright 2026 The MathWorks, Inc.

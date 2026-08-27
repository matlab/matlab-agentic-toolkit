# Symmatrix Workflow

Use `symmatrix` to create symbolic matrix variables that behave as atomic objects — like textbook linear algebra where A, B, x are whole matrices, not arrays of scalar elements.

## When to Use `symmatrix` vs `sym`

| Need | Use |
|------|-----|
| Textbook-style formulas: `A^(-1)*b`, `det(A)`, `trace(A*B)` | `symmatrix` |
| Element-wise access: `A(1,2)`, substituting specific values | `sym('A', [n n])` |
| Matrix calculus: derivatives of matrix expressions | `symmatrix` |
| Numerical evaluation with specific entries | Convert with `symmatrix2sym` first |

## Key Functions

| Function | Purpose | Since |
|----------|---------|-------|
| `symmatrix('A', [m n])` | Create m-by-n atomic symbolic matrix | R2021a |
| `symmatrix('A', n)` | Create n-by-n square atomic symbolic matrix | R2021a |
| `symmatrix2sym(X)` | Expand to element-wise sym matrix | R2021a |
| `symfunmatrix(expr, vars)` | Create symbolic matrix function | R2022a |
| `symfunmatrix2symfun(X)` | Expand to element-wise symfun matrix | R2022a |

## Supported Operations on `symmatrix`

These produce compact, formula-level results:

- Arithmetic: `A + B`, `A * B`, `A - B`, `scalar * A`
- Inverse: `inv(A)` or `A^(-1)`
- Transpose: `transpose(A)` or `A.'`
- Determinant: `det(A)`
- Trace: `trace(A)`
- Powers: `A^n`
- Concatenation: `[A B; C D]`

## Operations Requiring Conversion to `sym`

These do NOT work directly on `symmatrix` — convert first with `symmatrix2sym`:

- `eig(A)` — eigenvalues/eigenvectors
- `svd(A)` — singular value decomposition
- `rank(A)` — matrix rank
- `null(A)` — null space
- Element access: `A(i,j)`

## Pattern: Textbook Linear Algebra

```matlab
% Create atomic matrices
A = symmatrix('A', [3 3]);
b = symmatrix('b', [3 1]);

% Matrix-level operations (results stay compact)
x = inv(A) * b;           % Displays as: A^-1*b
detA = det(A);             % Displays as: det(A)
trAB = trace(A * A.');     % Displays as: trace(A*A.')

% Convert to element-wise when needed
x_elements = symmatrix2sym(x);  % Expands using Cramer's rule
```

## Pattern: Matrix Calculus (Vector Derivative)

```matlab
x = symmatrix('x', [3 1]);
f = transpose(x) * x;  % Scalar: x'*x

% Differentiate scalar with respect to vector
dfdx = diff(f, x);  % Returns 2*x.'
```

## Pattern: Convert to Numeric

```matlab
A = symmatrix('A', [2 2]);
b = symmatrix('b', [2 1]);
x = inv(A) * b;

% Expand to symbolic elements
x_sym = symmatrix2sym(x);

% Substitute numeric values
A_sym = symmatrix2sym(A);
b_sym = symmatrix2sym(b);
A_num = [1 2; 3 4];
b_num = [5; 6];
oldVars = [A_sym(:).', b_sym(:).'];
newVals = [A_num(:).', b_num(:).'];
x_num = double(subs(x_sym, oldVars, newVals));
```

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| `sym('A', [3 3])` for textbook-style algebra | Creates 9 scalar variables (A1_1, A1_2, ...), not an atomic matrix | `symmatrix('A', [3 3])` |
| Calling `eig(A)` on a symmatrix | Not supported — throws error | `eig(symmatrix2sym(A))` |

----

Copyright 2026 The MathWorks, Inc.

----

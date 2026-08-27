# Simplification, Polynomials, and Variable-Precision Arithmetic

Reference patterns for simplifying symbolic expressions, extracting polynomial coefficients, and using variable-precision arithmetic (VPA).

## Extracting Polynomial Coefficients

Two key functions with different behaviors:

```matlab
syms s K

% sym2poly: Returns NUMERIC double vector, descending powers
%           Only works with single-variable NUMERIC coefficients
p = 3*s^3 + 2*s + 7;
c = sym2poly(p);             % [3 0 2 7] — includes zero coefficients

% coeffs: Returns SYMBOLIC coefficients, ascending powers by default
%         Works with symbolic (parametric) coefficients
p2 = K*s^2 + 3*s + 1;
[c, terms] = coeffs(p2, s);  % c = [K, 3, 1], terms = [s^2, s, 1]

% For descending order with zeros included (like sym2poly):
c_all = coeffs(p2, s, 'All');  % Descending order, includes zeros
```

## Simplification Strategies

Different simplification functions serve different purposes:

```matlab
syms x

% General simplification (tries multiple strategies)
simplify(sin(x)^2 + cos(x)^2)          % 1

% More aggressive simplification (more steps = slower but better)
simplify(expr, 'Steps', 50)

% Specific simplifiers (faster, more predictable):
expand((x+1)^3)                         % x^3 + 3*x^2 + 3*x + 1
factor(x^3 - 1)                         % [x - 1, x^2 + x + 1]
simplifyFraction((x^2-1)/(x-1))         % x + 1
partfrac(1/(x^2-1), x)                  % 1/(2*(x - 1)) - 1/(2*(x + 1))

% Combine logarithms (requires real assumption or IgnoreAnalyticConstraints)
syms x real
simplify(log(x^2) + log(x))             % log(x^3)
```

## Variable-Precision Arithmetic (VPA)

When you need more than double precision:

```matlab
% Default: 32 significant digits
vpa(pi)                          % 3.1415926535897932384626433832795

% Change precision
vpa(pi, 50)                          % 50-digit pi

% IMPORTANT: Convert to symbolic FIRST, then use vpa
% WRONG: vpa(0.12345678901234567890123456789012) gives vpa of the already-rounded double
% RIGHT: vpa("0.12345678901234567890123456789012") gives the exact value to the desired digits
% This same principle applies to any number requiring more digits than double
% WRONG: sym(0.12345678901234567890123456789012) the double value is rounded before converting to sym
% RIGHT: sym("0.12345678901234567890123456789012") once the number is a sym or vpa, you are safe

% Reset precision
digits(32);                      % Back to default
```

## Checklist

- [ ] Using `sym2poly` only with purely numeric symbolic polynomials
- [ ] Using `coeffs` for polynomials with symbolic parameters

## Troubleshooting

**Issue**: `simplify` doesn't simplify enough
- **Try**: `simplify(expr, 'Steps', 100)` for more aggressive simplification.
- **Try**: Specific functions: `expand`, `factor`, `collect`, `simplifyFraction`, `rewrite`.
- **Try**: Setting assumptions on variables (e.g., `assume(x, 'real')`).

**Issue**: `sym2poly` errors with "coefficients must be numeric"
- **Cause**: Expression contains symbolic parameters (not just the polynomial variable).
- **Fix**: Use `coeffs(expr, s, 'All')` instead, or substitute numeric values first with `subs`.

----

Copyright 2026 The MathWorks, Inc.

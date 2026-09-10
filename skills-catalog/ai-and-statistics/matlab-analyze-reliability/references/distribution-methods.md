# Distribution Object Methods

Common methods available on probability distribution objects created by `makedist` or `fitdist`.

| Method | Purpose |
|--------|---------|
| `pdf` | Compute the probability density function (PDF) or probability mass function (PMF) |
| `cdf` | Compute the cumulative distribution function (CDF). Also computes the survivor function via the `"upper"` argument |
| `icdf` | Compute the inverse CDF/quantiles |
| `iqr` | Compute the interquartile range |
| `mean` | Compute the mean |
| `median` | Compute the median |
| `var` | Compute the variance |
| `std` | Compute the standard deviation |
| `negloglik` | Compute the negative log-likelihood (fitdist only) |
| `proflik` | Compute the profile likelihood of a fitted parameter (fitdist only) |
| `paramci` | Compute confidence intervals for fitted parameters. Supports Wald-style and likelihood-ratio intervals via the Type argument (fitdist only) |
| `random` | Generate random samples |
| `plot` | Plot the PDF (includes histogram of raw data for fitted distributions). Can also plot the CDF with empirical CDF |
| `truncate` | Truncate the distribution to a fixed range. Returns a new truncated distribution object |
| `capability` | Compute capability indices like Cpk (fitdist only) |
| `capaplot` | Plot the PDF with shaded area for specification bounds |
| `probplot` | Plot a probability plot to assess fit quality (fitdist only) |

----

Copyright 2026 The MathWorks, Inc.

----

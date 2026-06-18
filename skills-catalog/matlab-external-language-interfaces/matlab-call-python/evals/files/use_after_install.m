% use_after_install.m — Requires scipy (not installed in eval venv)
% Tests mid-session install recovery with terminate(pyenv)

x = linspace(-3, 3, 100);

% Use scipy for normal distribution PDF
pdfValues = double(py.scipy.stats.norm.pdf(py.numpy.array(x)));
fprintf("PDF at x=0: %.4f\n", pdfValues(50));

% Copyright 2026 The MathWorks, Inc.

function Tf = hasReportGenerator()
%hasReportGenerator True when MATLAB Report Generator is installed and licensed.
%
%   Tf = hasReportGenerator() gates the optional PDF report: the markdown report
%   is always emitted, but generateFeatureReportPdf needs the Report Generator's
%   programmatic API. This checks both that the class is present and that a
%   license can be checked out, so a run degrades to markdown-only rather than
%   erroring when the product is absent.

% Copyright 2026 The MathWorks, Inc.

    Tf = exist('mlreportgen.report.Report', 'class') == 8 && ...
        license('test', 'MATLAB_Report_Gen');
end

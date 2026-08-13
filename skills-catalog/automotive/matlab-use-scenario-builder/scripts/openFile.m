function openFile(filePath)
%openFile Open a file with the OS default handler (Windows / macOS / Linux)
%
%   openFile(filePath) launches the host OS's default application for the
%   given file. Use in place of winopen() so the same script works on
%   Windows, macOS, and Linux.

arguments
    filePath (1,1) string
end

if ~isfile(filePath) && ~isfolder(filePath)
    error("openFile:notFound", "File or folder not found: %s", filePath);
end

if ispc
    winopen(filePath);
elseif ismac
    system("open """ + filePath + """");
else
    % Linux / other Unix — xdg-open is the freedesktop.org standard.
    system("xdg-open """ + filePath + """ &");
end

end

%% ----
% Copyright 2026 The MathWorks, Inc.
% ----

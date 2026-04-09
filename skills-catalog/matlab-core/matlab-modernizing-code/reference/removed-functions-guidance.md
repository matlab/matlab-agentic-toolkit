
# Removed Functions

## Quick Reference: Removed Functions

| Removed Function | Replacement | Removed In | Category |
|------------------|-------------|------------|----------|
| guide | appdesigner | R2025a | UI Development |
| optimtool | Optimize Live Editor Task | R2021a | Optimization |
| hgexport('readstyle') | exportgraphics | R2025a | Graphics Export |
| fints | timetable | R2020a | Financial |
| wavread/wavwrite | audioread/audiowrite | R2015b | Audio I/O |
| aviread/avifile | VideoReader/VideoWriter | R2015b | Video I/O |
| mmreader | VideoReader | R2014b | Video I/O |

---

## UI Development

### guide → appdesigner

**Status:** Removed in R2025a (deprecated since R2021a)

GUIDE (Graphical User Interface Development Environment) was MATLAB's original drag-and-drop app builder. It has been fully removed and replaced by App Designer.

**Old Pattern (Will Error):**
```matlab
% REMOVED: These will cause errors in R2025a+
guide                    % Error: Undefined function 'guide'
guide('myapp.fig')       % Error: Undefined function 'guide'
```

**Modern Pattern (Use This):**
```matlab
% Create new apps with App Designer
appdesigner              % Opens App Designer

% Open existing App Designer app
appdesigner('myapp.mlapp')

% Run an app programmatically
app = myapp;
```

**Migration Strategies:**

1. **For Active Development (Recommended):**
   - Use the "GUIDE to App Designer Migration Tool" from File Exchange
   - In App Designer: **Designer tab** → **Open** menu → Migration tool

2. **For Minimal Changes:**
   - Export GUIDE app to single `.m` file
   - Manage layout and code using standard MATLAB functions

**Key Differences:**
| GUIDE | App Designer |
|-------|--------------|
| `.fig` + `.m` files | Single `.mlapp` file |
| Callbacks in separate file | Callbacks in same file as layout |
| `handles` structure | App properties (`app.PropertyName`) |
| `guidata` for data sharing | App properties for data sharing |
| Figure-based | UIFigure-based |

**Example Migration - Callback Pattern:**
```matlab
% OLD GUIDE pattern (will not work)
function pushbutton1_Callback(hObject, eventdata, handles)
    handles.data = handles.data + 1;
    guidata(hObject, handles);
    set(handles.text1, 'String', num2str(handles.data));
end

% NEW App Designer pattern
function Button1Pushed(app, event)
    app.Data = app.Data + 1;
    app.Label1.Text = num2str(app.Data);
end
```

**Running Existing GUIDE Apps:**
- Existing GUIDE apps (`.fig` + `.m`) can still RUN in R2025a+
- You cannot EDIT them with the GUIDE environment
- Consider migrating to App Designer for maintainability

---

## Optimization

### optimtool → Optimize Live Editor Task

**Status:** Removed in R2021a (deprecated since R2015b)

The Optimization app (`optimtool`) was a Java-based GUI for setting up optimization problems. It was removed due to Java compatibility issues and replaced with the Optimize Live Editor Task.

**Old Pattern (Will Error):**
```matlab
% REMOVED: These will cause errors in R2021a+
optimtool                    % Error: Undefined function 'optimtool'
optimtool('fmincon')         % Error
optimtool(@objfun, x0)       % Error
```

**Modern Pattern (Use This):**

**Option 1: Optimize Live Editor Task**
```matlab
% In a Live Script (.mlx), insert the Optimize task:
% Live Editor tab → Task → Optimize

% The task generates equivalent code like:
options = optimoptions('fmincon', 'Algorithm', 'sqp', 'Display', 'iter');
[solution, objectiveValue] = fmincon(@objfun, x0, A, b, Aeq, beq, lb, ub, @nonlcon, options);
```

**Option 2: Programmatic (Recommended for Production)**
```matlab
% Set up optimization programmatically
options = optimoptions('fmincon', ...
    'Algorithm', 'sqp', ...
    'Display', 'iter', ...
    'OptimalityTolerance', 1e-6);

[x, fval, exitflag, output] = fmincon(@objfun, x0, A, b, Aeq, beq, lb, ub, @nonlcon, options);
```

**Option 3: Problem-Based Approach**
```matlab
% Modern problem-based optimization
x = optimvar('x', 2, 'LowerBound', 0);
prob = optimproblem('Objective', sum(x.^2));
prob.Constraints.c1 = x(1) + x(2) >= 1;
[sol, fval] = solve(prob);
```

---

## Graphics Export

### hgexport('readstyle') → exportgraphics

**Status:** Removed in R2025a

The `hgexport('readstyle', ...)` function for reading export style files has been removed.

**Old Pattern (Will Error):**
```matlab
% REMOVED: This will cause errors in R2025a+
style = hgexport('readstyle', 'mystyle.txt');
hgexport(gcf, 'output.eps', style);
```

**Modern Pattern (Use This):**
```matlab
% Use exportgraphics for high-quality figure export
exportgraphics(gcf, 'output.pdf', 'ContentType', 'vector');
exportgraphics(gcf, 'output.png', 'Resolution', 300);
exportgraphics(gca, 'output.eps', 'ContentType', 'vector');

% For more control, set figure properties directly
fig = gcf;
fig.Color = 'white';
ax = gca;
ax.FontSize = 12;
ax.LineWidth = 1.5;
exportgraphics(fig, 'output.pdf');
```

**Key Differences:**
- `exportgraphics` is simpler and more consistent
- No need for external style files
- Better PDF and vector output quality
- Works with axes, figures, or chart containers

---

## Financial Toolbox

### fints → timetable

**Status:** Removed in R2020a (deprecated since R2016b)

Financial time series objects (`fints`) have been replaced with MATLAB's built-in `timetable` data type.

**Old Pattern (Will Error):**
```matlab
% REMOVED: fints no longer exists
tsobj = fints(dates, data);           % Error
price = tsobj.Close;                   % Error
```

**Modern Pattern (Use This):**
```matlab
% Use timetable for financial time series
dates = datetime(2024, 1, 1:10);
prices = rand(10, 1) * 100;

% Create timetable
tt = timetable(dates', prices, 'VariableNames', {'Close'});

% Access data
price = tt.Close;

% Time-based operations
dailyReturns = diff(log(tt.Close));
tt2024 = tt(tt.Time >= datetime(2024,1,1), :);

% Resample
monthlyData = retime(tt, 'monthly', 'mean');
```

**Why timetable is Better:**
- Native MATLAB data type (no toolbox required for basic operations)
- Better integration with other MATLAB functions
- Supports more time-based operations
- Consistent with modern MATLAB data workflows

---

## Audio/Video I/O

| Removed | Replacement | Removed In |
|---------|-------------|------------|
| wavread | audioread | R2015b |
| wavwrite | audiowrite | R2015b |
| wavfinfo | audioinfo | R2015b |
| wavplay | audioplayer | R2015b |
| wavrecord | audiorecorder | R2015b |
| aviread | VideoReader | R2015b |
| aviinfo | VideoReader | R2015b |
| avifile | VideoWriter | R2015b |
| mmreader | VideoReader | R2014b |
| mmfileinfo | VideoReader | R2014b |

---

## Other Notable Removals

### nargin/nargout in Scripts

**Status:** Removed support in R2022a

```matlab
% OLD (Error in R2022a+ when used in a script)
if nargin > 0
    % ...
end

% This only works in FUNCTIONS, not scripts
% Convert your script to a function if you need input arguments
```

### java.* Classes in MATLAB Online

Many Java-based functions are not available in MATLAB Online. Use MATLAB-native alternatives.

---

## Checking for Removed Functions

Use the Code Compatibility Analyzer to find removed functions in your code:

```matlab
% Analyze a folder for compatibility issues
codeCompatibilityReport('myFolder')

% Or use the app
codeCompatibilityAnalyzer
```

---

## Version Timeline

| Version | Major Removals |
|---------|---------------|
| R2025a | GUIDE, hgexport('readstyle') |
| R2022a | nargin/nargout in scripts |
| R2021a | optimtool |
| R2020a | fints (Financial) |
| R2015b | wavread/wavwrite, aviread/avifile |
| R2014b | mmreader, mmfileinfo |

---

## Summary: Functions That Will Error

**These functions DO NOT EXIST in recent MATLAB versions:**

| Function | Last Working Version | Use Instead |
|----------|---------------------|-------------|
| `guide` | R2024b | `appdesigner` |
| `optimtool` | R2020b | Optimize Live Editor Task |
| `hgexport('readstyle',...)` | R2024b | `exportgraphics` |
| `fints` | R2019b | `timetable` |
| `wavread` | R2015a | `audioread` |
| `wavwrite` | R2015a | `audiowrite` |
| `aviread` | R2015a | `VideoReader` |
| `avifile` | R2015a | `VideoWriter` |


# Data Types

**Contents:** datetime (+ component extraction, dateshift), duration, calendarDuration, string arrays (search, edit, extract), categorical (ordinal, mergecats/renamecats/removecats/reordercats)

MATLAB also provides `dictionary`, `enumeration`, and other container types not covered in detail here. This skill focuses on the types most commonly encountered in tabular data analysis.

## Quick Reference: Modern vs Legacy Types

| Instead of | Use | Why |
|---|---|---|
| `datenum`, `datestr` | `datetime` | Proper arithmetic, timezone support |
| `char`, `cellstr`, `strcmp` | `string`, `==`/`matches` | `==` for scalar, `matches` for vector comparison |
| Numeric codes or strings with few unique values | `categorical` | Self-documenting, works with grouping functions, memory-efficient |

## Use `datetime` not serial date numbers
```matlab
dt = datetime("2024-01-15");
dt2 = datetime("now");
dateString = string(dt,"yyyy-MM-dd");  % string() only needed for export or UI display
elapsed = dt2 - dt;  % Returns duration type

% Timezone-aware
dt = datetime("now",TimeZone="America/New_York");

% Avoid: Serial date numbers
dn = datenum("2024-01-15");
dn2 = now;
dateString = datestr(dn,"yyyy-mm-dd");
elapsed = dn2 - dn;  % The unit of this is not clear!
```

### Effective use of the `datetime` constructor

**Set `InputFormat`, `TimeZone`, and `Format` as name-value arguments on the single
`datetime(...)` call — never as follow-up `dt.TimeZone = ...` / `dt.Format = ...` assignments.**
The property names match the argument names, so build the value fully in one statement:

```matlab
offsets = ["2024-03-15T09:30:00-05:00" "2024-03-15T14:00:00+00:00"];

% One call — parse, set the zone, and set the display format together
dt = datetime(offsets, ...
    InputFormat="yyyy-MM-dd'T'HH:mm:ssZZZZZ", ...
    TimeZone="America/Los_Angeles", ...
    Format="yyyy-MM-dd HH:mm:ss zzz");

% Avoid: parse, then mutate in separate statements
dt = datetime(offsets,InputFormat="yyyy-MM-dd'T'HH:mm:ssZZZZZ");
dt.TimeZone = "America/Los_Angeles";
dt.Format = "yyyy-MM-dd HH:mm:ss zzz";
```

Use a follow-up `.TimeZone` / `.Format` assignment only to restamp a datetime you did not just
construct.

**Convert text timestamps with `InputFormat`, not manual/regex parsing.** For any text-to-datetime
conversion, write an `InputFormat` that matches the pattern in the data. Any literal characters
(marker letters, custom separators) can be escaped inside single quotes:

```matlab
% Custom "2024_day100" day-of-year format — the literal word "day" contains letters that
% collide with format tokens, so quote it; DDD then parses the day-of-year number
labels = ["2024_day100" "2024_day200" "2024_day365"];
dt = datetime(labels,InputFormat="uuuu_'day'DDD",Format="uuuu-MM-dd");

% Doubled slashes as literal separators
dates = ["15//03//2024" "16//03//2024"];
dt = datetime(dates,InputFormat="dd//MM//yyyy");
```

Look up the correct format tokens with `doc datetime.Format` — common ones: `yyyy`/`uuuu` (year),
`MM` (month number) vs `MMM`/`MMMM` (month name), `dd` (day), `DDD` (day of year), `HH` (24-hour)
vs `hh` (12-hour), `mm` (minute), `ss` (second), `QQQ` (quarter), `ZZZZZ` (offset like `-05:00`),
`zzz` (zone abbreviation).

Manual text/regex parsing is only justified when (a) the data uses a token `datetime` does not
support, or (b) an `InputFormat` call errors or returns `NaT` on the real values.

### Extract datetime components

Pull out parts of a datetime for computed variables, filtering, or display. In these examples, `T` is a table with a `Date` variable of type `datetime`:
```matlab
T.Year = year(T.Date);
T.Month = month(T.Date);                   % numeric (1-12)
T.MonthName = month(T.Date,"name");        % "January", "February", ...
T.Day = day(T.Date);
T.Weekday = weekday(T.Date);               % numeric (1=Sunday)
T.Quarter = quarter(T.Date);
T.Hour = hour(T.Date);

% Split into multiple components at once
[y,m,d] = ymd(T.Date);
[h,m,s] = hms(T.Date);
```

Use `dateshift` to snap dates to calendar boundaries or find specific weekdays:
```matlab
T.MonthStart = dateshift(T.Date,"start","month");
T.QuarterEnd = dateshift(T.Date,"end","quarter");
T.NextFriday = dateshift(T.Date,"dayofweek","Friday");
```

**Note:** For grouping by time unit (e.g., hourly means, monthly totals), prefer the binning rules in `groupsummary`, `pivot`, etc. rather than creating a separate component column. See [grouping-and-aggregation.md](grouping-and-aggregation.md) for examples.

### Use `duration` and `calendarDuration` for time differences

Arithmetic on datetime values produces `duration` (fixed-length) or `calendarDuration` (calendar-aware) results:
```matlab
% duration — fixed units (years, days, hours, minutes, seconds, milliseconds)
elapsed = hours(3) + minutes(45);
T.ResponseTime = T.EndTime - T.StartTime;       % duration result

% calendarDuration — calendar-aware (months, years vary in length)
offset = calmonths(3) + caldays(15);
T.DueDate = T.StartDate + offset;
```

Use `duration` for fixed time periods (elapsed time, sensor intervals). Use `calendarDuration` when calendar boundaries matter (months and years have variable lengths due to leap years and DST).

**Dual-purpose creation/extraction functions:** `years`, `days`, `hours`, `minutes`, `seconds`, `milliseconds` both create durations from numbers and extract numbers from durations:
```matlab
d = hours(2.5);              % create: 2.5 hr duration
n = hours(d);                % extract: 2.5 (numeric)
T.ElapsedHours = hours(T.ResponseTime);  % convert duration variable to numeric
```

**Display format:** The `Format` property controls display without changing the underlying value:
```matlab
d = hours(1) + minutes(30);
d.Format = "hh:mm:ss";      % displays as "01:30:00"
d.Format = "m";             % displays as "90 min"
```

## Use `string` arrays not character/cell arrays
```matlab
names = ["Alice" "Bob" "Charlie"];
isMatch = names == "Bob";           % scalar comparison
isMatch = matches(names,"Bob");     % vector-safe comparison
fullName = firstName + " " + lastName;
parts = split(names,",");

% Avoid: Character/cell arrays
names = {'Alice', 'Bob', 'Charlie'};
isMatch = strcmp(names,'Bob');
fullName = strcat(firstName,' ',lastName);
parts = cellfun(@(x) strsplit(x,','), names, UniformOutput=false);
```

String arrays support vectorized search, edit, and extraction functions:
```matlab
% Search
hasEmail = contains(T.Contact,"@");
isValid = startsWith(T.ID,"PRD-");
n = count(T.Text,"error");

% Edit
T.Name = upper(T.Name);
T.Name = strip(T.Name);                         % remove leading/trailing whitespace
T.Code = erase(T.Code,"-");                      % remove substrings
T.Status = replace(T.Status,"N/A","Unknown");     % replace substrings

% Extract and split
T.Domain = extractAfter(T.Email,"@");
T.First = extractBefore(T.FullName," ");
parts = split(T.Address,",");                    % split into columns
```

## Use `categorical` not coded numbers or cell strings
```matlab
T.Status = categorical(T.Status,[1 2 3],["High" "Medium" "Low"]);
highPriority = T(T.Status == "High",:);

T.Region = categorical(T.Region);

% Avoid: Numeric codes or low-cardinality strings for categories
T.Status = [1; 2; 1; 3];
T.Region = ["North"; "South"; "North"; "East"];  % few unique values - better as categorical
```

Use ordinal categorical for rankings and comparisons:
```matlab
T.Priority = categorical(T.Priority, ...
    ["Low" "Medium" "High" "Critical"], Ordinal=true);
urgent = T(T.Priority >= "High",:);
```

### Manage categories

Consolidate, rename, or reorder category levels:
```matlab
% Merge rare or related categories into one
T.Region = mergecats(T.Region,["Northeast" "Southeast"],"East");

% Rename categories
T.Status = renamecats(T.Status,["Act" "Inact"],["Active" "Inactive"]);

% Remove unused categories (e.g., after filtering rows)
T.Category = removecats(T.Category);

% Reorder for display or plotting
T.Size = reordercats(T.Size,["Small" "Medium" "Large"]);

% Count occurrences per category
countcats(T.Status)
```

---

Copyright 2026 The MathWorks, Inc.

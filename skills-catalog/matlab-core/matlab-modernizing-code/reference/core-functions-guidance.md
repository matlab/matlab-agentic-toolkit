
# Core Function Modernization

## Quick Reference: Function Mappings

| Deprecated Function | Recommended Replacement | Since | Category |
|---------------------|------------------------|-------|----------|
| trainNetwork | trainnet | R2024a | Deep Learning |
| LayerGraph | dlnetwork | R2024a | Deep Learning |
| SeriesNetwork | dlnetwork | R2024a | Deep Learning |
| DAGNetwork | dlnetwork | R2024a | Deep Learning |
| classify (DL) | minibatchpredict + scores2label | R2024a | Deep Learning |
| activations | minibatchpredict (with Outputs) | R2024a | Deep Learning |
| csvread | readmatrix | R2019a | File I/O |
| csvwrite | writematrix | R2019a | File I/O |
| dlmread | readmatrix | R2019a | File I/O |
| dlmwrite | writematrix | R2019a | File I/O |
| xlsread | readtable, readmatrix, readcell | R2019a | File I/O |
| xlswrite | writetable, writematrix, writecell | R2019a | File I/O |
| strmatch | startsWith, strncmp, matches | R2019b | Strings |
| uicontrol | uibutton, uidropdown, etc. | R2016a | UI/App |
| pkurtosis | spectralKurtosis | R2024b | Signal Processing |
| wavread/wavwrite | audioread/audiowrite | R2012b | Audio (Removed) |
| wavplay/wavrecord | audioplayer/audiorecorder | R2010a | Audio (Removed) |
| aviread/avifile | VideoReader/VideoWriter | R2010b | Video (Removed) |
| optimtool | Optimize Live Editor Task | R2021a | Optimization (Removed) |
| optimset | optimoptions | R2013a | Optimization |
| guide | appdesigner | R2025a | UI (Removed) |
| hgexport | exportgraphics | R2025a | Graphics (Removed) |
| fints | timetable | R2020a | Financial (Removed) |
| setoptions (plot) | dot notation | R2019a | Control Systems |
| stepDataOptions | chart properties | R2019a | Control Systems |
| impoly/imrect/imellipse | drawpolygon/drawrectangle/drawellipse | R2018b | Image Processing |
| imfreehand/impoint/imline | drawfreehand/drawpoint/drawline | R2018b | Image Processing |
| roifill | regionfill | R2019a | Image Processing |
| classregtree | fitctree/fitrtree | R2018a | Statistics (Removed) |
| svmtrain/svmclassify | fitcsvm/predict | R2018a | Statistics (Removed) |
| dataset | table | R2013b | Statistics |
| nominal/ordinal | categorical | R2013b | Statistics |
| simset/simget | Simulink.SimulationInput / get_param | R2009b | Simulink |
| Interpreted MATLAB Function | MATLAB Function block | R2022b | Simulink (To be removed) |
| Specialized Power Systems lib | Simscape Electrical | R2026a | Simulink (To be removed) |

---

## Deep Learning Toolbox Modernization

### trainNetwork → trainnet

**Status:** Not recommended as of R2024a

**Old Pattern (Avoid):**
```matlab
layers = [
    imageInputLayer([28 28 1])
    convolution2dLayer(3,8,'Padding','same')
    reluLayer
    fullyConnectedLayer(10)
    softmaxLayer
    classificationLayer];

net = trainNetwork(XTrain, YTrain, layers, options);
```

**Modern Pattern (Use This):**
```matlab
layers = [
    imageInputLayer([28 28 1])
    convolution2dLayer(3,8,'Padding','same')
    reluLayer
    fullyConnectedLayer(10)
    softmaxLayer];

net = trainnet(XTrain, YTrain, layers, "crossentropy", options);
```

**Why Modern is Better:**
- `trainnet` supports `dlnetwork` objects with broader architecture support
- Enables easier loss function specification (built-in or custom)
- Returns unified `dlnetwork` data type
- Typically faster than `trainNetwork`
- Supports networks imported from external platforms (PyTorch, TensorFlow)

**Key Difference:** Specify loss function explicitly instead of using output layers like `classificationLayer`.

---

### LayerGraph, SeriesNetwork, DAGNetwork → dlnetwork

**Status:** Not recommended as of R2024a

**Old Pattern (Avoid):**
```matlab
lgraph = layerGraph(layers);
lgraph = addLayers(lgraph, newLayers);
lgraph = connectLayers(lgraph, 'layer1', 'layer2');
net = trainNetwork(data, lgraph, options);
```

**Modern Pattern (Use This):**
```matlab
net = dlnetwork(layers);
% Or for complex architectures:
net = dlnetwork;
net = addLayers(net, layers1);
net = addLayers(net, layers2);
net = connectLayers(net, 'layer1', 'layer2');
net = initialize(net);

% Train with trainnet
net = trainnet(XTrain, YTrain, net, "crossentropy", options);
```

**Migration from existing networks:**
```matlab
% Convert DAGNetwork or SeriesNetwork to dlnetwork
dlnet = dag2dlnetwork(trainedNet);
```

**Why Modern is Better:**
- Unified data type for building, prediction, training, visualization, compression, and verification
- Supports custom training loops
- Better interoperability with external frameworks
- Required for modern training functions

---

### classify → minibatchpredict + scores2label

**Status:** Not recommended as of R2024a

**Old Pattern (Avoid):**
```matlab
YPred = classify(net, XTest);
```

**Modern Pattern (Use This):**
```matlab
scores = minibatchpredict(net, XTest);
YPred = scores2label(scores, classNames);
```

**For probability scores:**
```matlab
scores = minibatchpredict(net, XTest);
[YPred, probs] = scores2label(scores, classNames);
```

---

### activations → minibatchpredict with Outputs

**Status:** Not recommended as of R2024a

**Old Pattern (Avoid):**
```matlab
act = activations(net, X, 'conv1');
```

**Modern Pattern (Use This):**
```matlab
act = minibatchpredict(net, X, Outputs='conv1');
```

**Multiple layer outputs:**
```matlab
[act1, act2] = minibatchpredict(net, X, Outputs={'conv1', 'fc1'});
```

---

## File I/O Modernization

### csvread, dlmread → readmatrix

**Status:** Not recommended as of R2019a

**Old Pattern (Avoid):**
```matlab
M = csvread('data.csv');
M = dlmread('data.txt', '\t');
M = dlmread('data.csv', ',', 1, 0);  % Skip header row
```

**Modern Pattern (Use This):**
```matlab
M = readmatrix('data.csv');
M = readmatrix('data.txt', 'Delimiter', '\t');

% Skip header rows
opts = detectImportOptions('data.csv');
opts.DataLines = [2 Inf];
M = readmatrix('data.csv', opts);
```

**Why Modern is Better:**
- Better cross-platform support and performance
- Automatic detection of data format and types
- Import options for controlling the import process
- Better error handling and missing data management

---

### csvwrite, dlmwrite → writematrix

**Status:** Not recommended as of R2019a

**Old Pattern (Avoid):**
```matlab
csvwrite('output.csv', M);
dlmwrite('output.txt', M, '\t');
dlmwrite('output.csv', M, '-append');
```

**Modern Pattern (Use This):**
```matlab
writematrix(M, 'output.csv');
writematrix(M, 'output.txt', 'Delimiter', '\t');
writematrix(M, 'output.csv', 'WriteMode', 'append');
```

---

### xlsread → readtable, readmatrix, readcell

**Status:** Not recommended as of R2019a

**Old Pattern (Avoid):**
```matlab
[num, txt, raw] = xlsread('data.xlsx');
data = xlsread('data.xlsx', 'Sheet1', 'A2:D100');
```

**Modern Pattern (Use This):**
```matlab
% For tabular data (most common)
T = readtable('data.xlsx');
T = readtable('data.xlsx', 'Sheet', 'Sheet1', 'Range', 'A2:D100');

% For numeric matrix
M = readmatrix('data.xlsx');

% For cell array (mixed types)
C = readcell('data.xlsx');
```

**Why Modern is Better:**
- `readtable` preserves variable names and types
- Better handling of mixed data types
- Works consistently across platforms
- Better datetime and categorical support

---

### xlswrite → writetable, writematrix, writecell

**Status:** Not recommended as of R2019a

**Old Pattern (Avoid):**
```matlab
xlswrite('output.xlsx', data);
xlswrite('output.xlsx', data, 'Sheet1', 'A2');
```

**Modern Pattern (Use This):**
```matlab
% For tables
writetable(T, 'output.xlsx');
writetable(T, 'output.xlsx', 'Sheet', 'Sheet1', 'Range', 'A2');

% For matrices
writematrix(M, 'output.xlsx');

% For cell arrays
writecell(C, 'output.xlsx');
```

---

## String Function Modernization

### strmatch → startsWith, strncmp, matches

**Status:** Not recommended

**Old Pattern (Avoid):**
```matlab
idx = strmatch('abc', strArray);
idx = strmatch('abc', strArray, 'exact');
```

**Modern Pattern (Use This):**
```matlab
% Find strings starting with pattern
idx = find(startsWith(strArray, 'abc'));

% Find exact matches
idx = find(matches(strArray, 'abc'));

% Case-insensitive
idx = find(startsWith(strArray, 'abc', 'IgnoreCase', true));
```

---

### Character Arrays → String Arrays

**Recommendation:** Use string arrays for new code

**Old Pattern (Less Preferred):**
```matlab
name = 'John';
names = {'John', 'Jane', 'Bob'};
fullName = [firstName, ' ', lastName];
```

**Modern Pattern (Preferred):**
```matlab
name = "John";
names = ["John", "Jane", "Bob"];
fullName = firstName + " " + lastName;
```

**Why Modern is Better:**
- String arrays work better with modern MATLAB functions
- Easier concatenation with `+` operator
- Better missing value handling with `<missing>`
- More intuitive indexing

---

### strfind → contains (for string arrays)

**Recommendation:** Use `contains` for string array searches

**Old Pattern:**
```matlab
idx = ~cellfun('isempty', strfind(cellstr, pattern));
```

**Modern Pattern:**
```matlab
idx = contains(stringArray, pattern);
```

---

## UI/App Development Modernization

### uicontrol → Modern UI Components

**Status:** Not recommended. Use App Designer components.

**Old Pattern (Avoid):**
```matlab
fig = figure;
btn = uicontrol('Style', 'pushbutton', 'String', 'Click Me', ...
    'Position', [20 20 100 30], 'Callback', @buttonCallback);
edit = uicontrol('Style', 'edit', 'Position', [20 60 100 25]);
popup = uicontrol('Style', 'popupmenu', 'String', {'A','B','C'});
```

**Modern Pattern (Use This):**
```matlab
fig = uifigure;
btn = uibutton(fig, 'Text', 'Click Me', ...
    'Position', [20 20 100 30], 'ButtonPushedFcn', @buttonCallback);
edit = uieditfield(fig, 'Position', [20 60 100 25]);
dropdown = uidropdown(fig, 'Items', {'A','B','C'});
```

**UI Component Mapping:**
| uicontrol Style | Modern Component |
|-----------------|------------------|
| pushbutton | uibutton |
| edit | uieditfield |
| text | uilabel |
| popupmenu | uidropdown |
| listbox | uilistbox |
| checkbox | uicheckbox |
| radiobutton | uiradiobutton |
| slider | uislider |
| togglebutton | uibutton (with state) |

**Why Modern is Better:**
- Modern appearance consistent with App Designer
- Better styling and customization options
- Responsive layouts with uigridlayout
- Better touch/mobile support

---

## Security Recommendations

### str2num → str2double

**Recommendation:** Use `str2double` to avoid code injection

**Old Pattern (Security Risk):**
```matlab
% DANGEROUS: str2num uses eval internally
value = str2num(userInput);
```

**Modern Pattern (Safe):**
```matlab
% SAFE: str2double doesn't execute code
value = str2double(userInput);

% For arrays
values = str2double(split(userInput, ','));
```

**Why This Matters:**
- `str2num` uses `eval` internally and can execute arbitrary code
- User input like `"system('rm -rf /')"` could be executed
- `str2double` safely parses numeric strings only

---

### eval → Avoid When Possible

**Recommendation:** Avoid `eval` for security and performance

**Old Pattern (Avoid):**
```matlab
varName = 'data';
eval([varName ' = 42;']);
result = eval(['process_' methodName '(x)']);
```

**Modern Pattern (Use This):**
```matlab
% Use containers
data = containers.Map;
data('varName') = 42;

% Use function handles
methods = struct('method1', @process_method1, 'method2', @process_method2);
result = methods.(methodName)(x);

% Use dynamic field names
s.(varName) = 42;
```

---

## Design Pattern Modernization

### Table-Based Workflows

**Modern MATLAB emphasizes table-based data handling:**

```matlab
% Modern: Use tables for heterogeneous data
data = readtable('sensors.csv');
data.Timestamp = datetime(data.Timestamp);
data.Status = categorical(data.Status);

% Filter and analyze
recentData = data(data.Timestamp > datetime('today') - days(7), :);
summary = groupsummary(recentData, 'SensorID', 'mean', 'Value');
```

### Tall Arrays for Big Data

**For data that doesn't fit in memory:**

```matlab
% Modern: Use tall arrays
ds = datastore('bigdata/*.csv');
T = tall(ds);
result = gather(mean(T.Value));  % Processes in chunks
```

### Arguments Block for Input Validation

**Modern input validation pattern:**

```matlab
function result = processData(data, options)
    arguments
        data (:,:) double
        options.Method (1,1) string {mustBeMember(options.Method, ["fast","accurate"])} = "fast"
        options.Verbose (1,1) logical = false
    end
    % Function body
end
```

---

## Version Compatibility Notes

- **R2024a+:** Deep learning modernization (trainnet, dlnetwork)
- **R2019a+:** File I/O modernization (readmatrix, writematrix)
- **R2016b+:** String arrays introduced
- **R2016a+:** App Designer and uifigure components


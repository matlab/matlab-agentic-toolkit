
# Simulink Modernization

## Quick Reference: Function and Block Mappings

| Deprecated | Recommended Replacement | Since | Status |
|------------|------------------------|-------|--------|
| simset | Simulink.SimulationInput | R2009b | Not recommended |
| simget | get_param / model properties | R2009b | Not recommended |
| Interpreted MATLAB Function | MATLAB Function block | R2022b | To be removed |
| Specialized Power Systems lib | Simscape Electrical | R2026a | To be removed |
| Matrix Viewer | Array Plot / other scopes | Future | To be removed |
| VR Sink | Unreal Engine integration | Future | To be removed |
| find_system 'Variants' | 'MatchFilter' | R2022b | Deprecated |

---

## Simulation Configuration

### simset → Simulink.SimulationInput

**Status:** Not recommended since R2009b. Use `Simulink.SimulationInput` objects instead.

**Old Pattern (Not Recommended):**
```matlab
% Legacy simulation configuration
options = simset('SrcWorkspace', 'current');
sim('myModel', [], options);

% Or with multiple options
options = simset('Solver', 'ode45', 'MaxStep', 0.01);
simOut = sim('myModel', [0 10], options);
```

**Modern Pattern (Use This):**
```matlab
% Modern SimulationInput approach
simIn = Simulink.SimulationInput('myModel');

% Set variables from current workspace
simIn = setVariable(simIn, 'Kp', 10);
simIn = setVariable(simIn, 'Ki', 0.5);

% Set model parameters
simIn = setModelParameter(simIn, 'Solver', 'ode45');
simIn = setModelParameter(simIn, 'StopTime', '10');
simIn = setModelParameter(simIn, 'MaxStep', '0.01');

% Run simulation
simOut = sim(simIn);

% Access results
y = simOut.yout;
```

**For Multiple Variables (Load from MAT file):**
```matlab
simIn = Simulink.SimulationInput('myModel');
simIn = loadVariablesFromMATFile(simIn, 'parameters.mat');
simOut = sim(simIn);
```

**Why Modern is Better:**
- Compatible with `parsim` and `batchsim` for parallel simulations
- Configuration is separate from model (non-destructive)
- Better for parameter sweeps and Monte Carlo simulations
- Cleaner syntax for complex configurations

---

### simget → get_param / Model Properties

**Status:** Not recommended since R2009b.

**Old Pattern (Not Recommended):**
```matlab
% Get simulation options
opts = simget('myModel');
solver = opts.Solver;
```

**Modern Pattern (Use This):**
```matlab
% Use get_param for model configuration
solver = get_param('myModel', 'Solver');
stopTime = get_param('myModel', 'StopTime');

% Get multiple parameters
params = get_param('myModel', 'ObjectParameters');

% Or use Simulink.SimulationOutput properties
simOut = sim('myModel');
metadata = simOut.SimulationMetadata;
```

---

## Blocks to Avoid

### Interpreted MATLAB Function → MATLAB Function Block

**Status:** To be removed in a future release (announced R2022b).

**Old Pattern (Avoid):**
```
% Using Interpreted MATLAB Function block
% - Slow (calls MATLAB parser each step)
% - Cannot generate code
% - Limited to single input
```

**Modern Pattern (Use This):**
```matlab
% Use MATLAB Function block instead
function y = fcn(u)
    % Define inputs and outputs in the block editor
    y = myFunction(u);
end

% Or use built-in blocks:
% - Math Function block for common operations
% - Fcn block for simple expressions
% - MATLAB System block for System objects
```

**Comparison:**
| Feature | Interpreted MATLAB Function | MATLAB Function Block |
|---------|---------------------------|----------------------|
| Speed | Slow (interpreter) | Fast (compiled) |
| Code Generation | No | Yes |
| Multiple I/O | No (single input) | Yes |
| Debugging | Limited | Full MATLAB debugger |
| Future Support | Being removed | Fully supported |

**Migration Steps:**
1. Create a MATLAB Function block
2. Copy your function code into the block
3. Define input/output ports in the block signature
4. Test functionality

---

### Specialized Power Systems Library → Simscape Electrical

**Status:** Entire library to be removed in R2026a. Migrate to Simscape Electrical.

**Affected Blocks (Sample):**

| Deprecated Block | Replacement | Notes |
|-----------------|-------------|-------|
| Timer | Stair Generator | Simscape Electrical |
| On/Off Delay | Logic blocks | Simscape Electrical |
| First-Order Filter | Transfer Fcn blocks | Simscape Electrical |
| Total Harmonic Distortion | THD block | Improved version |
| Breaker | Circuit Breaker | Simscape Electrical |
| Three-Phase Breaker | Three-Phase Breaker | Simscape Electrical |
| Monostable | Logic blocks | Simscape Electrical |
| powergui | Solver Configuration | Simscape Electrical |
| Synchronized Pulse Generator | Pulse Generator (Thyristor) | Improved version |

**Migration Guide:**
```matlab
% Check for deprecated blocks in your model
find_system('myModel', 'Type', 'Block', 'ReferenceBlock', 'powerlib/*')

% Use the upgrade advisor
upgradeadvisor('myModel')
```

See [Upgrade Specialized Power Systems Models to use Simscape Electrical Blocks](https://www.mathworks.com/help/sps/ug/upgrade-sps-models-to-use-simscape-blocks.html) for detailed migration steps.

---

### Matrix Viewer → Array Plot / Scopes

**Status:** To be removed in a future release.

**Old Pattern (Avoid):**
```matlab
% Using Matrix Viewer block from DSP System Toolbox
% Limited functionality
```

**Modern Pattern (Use This):**
```matlab
% Use Array Plot for matrix visualization
% Or use standard scopes with logging

% Programmatic approach
simOut = sim('myModel');
matrixData = simOut.logsout.get('matrixSignal').Values.Data;
imagesc(matrixData(:,:,end));
colorbar;
```

---

### VR Sink → Unreal Engine Integration

**Status:** To be removed in a future release. Simulink 3D Animation Viewer has been removed.

**Modern Pattern:**
Use Unreal Engine integration for 3D visualization:
- Simulation 3D Scene Configuration block
- Simulation 3D Actor blocks
- Unreal Engine environment

See [Transition Virtual Reality World to Unreal Engine 3D Environment](https://www.mathworks.com/help/sl3d/transition-virtual-reality-world-to-unreal-engine-3d-environment.html).

---

## API Deprecations

### find_system 'Variants' → 'MatchFilter'

**Status:** Deprecated in R2022b.

**Old Pattern (Not Recommended):**
```matlab
% Legacy variants search
blocks = find_system('myModel', 'Variants', 'AllVariants');
```

**Modern Pattern (Use This):**
```matlab
% Modern approach using MatchFilter
blocks = find_system('myModel', 'MatchFilter', @Simulink.match.allVariants);

% Other useful match filters
blocks = find_system('myModel', 'MatchFilter', @Simulink.match.activeVariants);
blocks = find_system('myModel', 'MatchFilter', @Simulink.match.codeCompileVariants);
```

---

### Stateflow up() → getParent()

**Status:** Not recommended.

**Old Pattern (Not Recommended):**
```matlab
% Legacy parent access
parentObj = up(stateObj);
```

**Modern Pattern (Use This):**
```matlab
% Modern parent access
parentObj = getParent(stateObj);

% Or use the Parent property
parentObj = stateObj.Parent;
```

---

## Modern Simulation Patterns

### Parallel Simulations with parsim

```matlab
% Create array of SimulationInput objects
numSims = 100;
simIn(1:numSims) = Simulink.SimulationInput('myModel');

% Configure each simulation
for i = 1:numSims
    simIn(i) = setVariable(simIn(i), 'Kp', paramValues(i));
end

% Run in parallel
simOut = parsim(simIn, 'ShowProgress', 'on');

% Process results
for i = 1:numSims
    results(i) = simOut(i).yout;
end
```

### Batch Simulations

```matlab
% For large-scale simulations
simIn = Simulink.SimulationInput('myModel');
simIn = setModelParameter(simIn, 'SimulationMode', 'accelerator');

% Run batch
simOut = batchsim(simIn, 'ShowProgress', 'on');
```

### Fast Restart

```matlab
% Enable fast restart for parameter sweeps
set_param('myModel', 'FastRestart', 'on');

for i = 1:numIterations
    set_param('myModel/Gain', 'Gain', num2str(gains(i)));
    simOut = sim('myModel');
    results(i) = simOut.yout;
end

set_param('myModel', 'FastRestart', 'off');
```

---

## Version Compatibility Notes

- **R2026a:** Specialized Power Systems library removal
- **R2022b:** Interpreted MATLAB Function block deprecation announced, find_system 'Variants' deprecated
- **R2009b:** simset/simget deprecated, Simulink.SimulationInput introduced

---

## Summary: Items to Avoid

| Avoid | Use Instead | Reason |
|-------|-------------|--------|
| `simset` | `Simulink.SimulationInput` | Not compatible with parsim/batchsim |
| `simget` | `get_param` | Deprecated since R2009b |
| Interpreted MATLAB Function | MATLAB Function block | Slow, no code gen, being removed |
| Specialized Power Systems blocks | Simscape Electrical | Library removed in R2026a |
| Matrix Viewer | Array Plot / logging | Being removed |
| VR Sink | Unreal Engine | Being removed |
| `find_system(..., 'Variants', ...)` | `'MatchFilter'` | Deprecated syntax |


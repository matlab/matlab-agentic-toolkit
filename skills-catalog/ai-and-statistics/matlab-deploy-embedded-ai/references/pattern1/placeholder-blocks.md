# Simulink Placeholder Block Implementation

When `exportNetworkToSimulink` encounters layers it cannot map to native Simulink layer
blocks (e.g., `selfAttentionLayer`, custom reshape/permute layers), it creates **placeholder
subsystems**. Each placeholder is a subsystem containing `Inport -> Assertion -> Outport`
with unspecified output dimensions. These placeholders:

- Appear as red/warning blocks in the Simulink model
- Have no functional implementation (the Assertion block is a no-op)
- Block code generation because output dimensions are unresolved

You must build out each placeholder with a working implementation using either **Simulink
primitive blocks** or a **MATLAB Function block**.

## Step 1: Identify Placeholder Subsystems

After export, find all placeholders by looking for subsystems containing Assertion blocks:

```matlab
netPath = [modelName '/' modelName '_1'];  % Top-level network subsystem
allSubs = find_system(netPath, 'BlockType', 'SubSystem');

for i = 1:numel(allSubs)
    subsys = allSubs{i};
    assertions = find_system(subsys, 'SearchDepth', 1, 'BlockType', 'Assertion');
    if ~isempty(assertions)
        fprintf('PLACEHOLDER: %s\n', subsys);
    end
end
```

## Step 2: Choose Replacement Strategy

For each placeholder, decide between two approaches:

| Approach | When to Use | Example Ops |
|----------|------------|-------------|
| **Simulink primitives** | Simple math ops (add, multiply, constant) | Positional embedding (Sum + Constant) |
| **MATLAB Function block** | Complex tensor operations (reshape, permute, indexing, multi-step math) | Patch flatten, attention, channel shuffle |

**Prefer Simulink primitives** when the operation is a simple combination of add/multiply/constant.
**Use MATLAB Function blocks** when the operation involves reshape, permute, indexing, or
multi-step computation -- these are hard to express with Simulink wiring but easy in MATLAB code.

## Step 3: Clean the Placeholder Subsystem

Before adding your implementation, remove the stub contents:

```matlab
function cleanSubs(subsys)
% Delete all signal lines then any stub blocks (DimFix, Assertion, etc.)
lines = find_system(subsys, 'FindAll', 'on', 'LookUnderMasks', 'on', 'type', 'line');
for k = 1:numel(lines)
    try, delete_line(lines(k)); catch, end
end
try, delete_block([subsys '/Assertion']); catch, end
try, delete_block([subsys '/DimFix']); catch, end
end
```

## Approach A: Simulink Primitive Blocks

Use when the operation is simple math that maps directly to Simulink blocks.

**Example -- Positional embedding addition (add a learned constant):**
```matlab
subsys = [netPath '/pos_embed'];
cleanSubs(subsys);

% Store weights in model workspace
mdlWs = get_param(modelName, 'ModelWorkspace');
posEmbedWeights = single(loadedWeights.pos_embed);  % [embedDim x numTokens]
mdlWs.assignin('pos_embed_w', posEmbedWeights);

% Add Constant block for the positional embedding
add_block('simulink/Sources/Constant', [subsys '/PosConst'], ...
    'Value', 'pos_embed_w', ...
    'OutDataTypeStr', 'single', ...
    'SampleTime', '-1');

% Add Sum block
add_block('simulink/Math Operations/Sum', [subsys '/PosAdd'], 'Inputs', '++');

% Wire: input + constant -> output
add_line(subsys, 'in/1',       'PosAdd/1',  'autorouting', 'on');
add_line(subsys, 'PosConst/1', 'PosAdd/2',  'autorouting', 'on');
add_line(subsys, 'PosAdd/1',   'out/1',     'autorouting', 'on');
```

### Useful Simulink Primitive Blocks for DL Ops

| Simulink Block | Library Path | DL Use Case |
|---------------|-------------|-------------|
| Sum | `simulink/Math Operations/Sum` | Residual add, bias add, embedding add |
| Product | `simulink/Math Operations/Product` | Element-wise multiply, scaling |
| Constant | `simulink/Sources/Constant` | Weights, biases, embeddings |
| Gain | `simulink/Math Operations/Gain` | Fixed scalar multiply |
| Math Function | `simulink/Math Operations/Math Function` | exp, sqrt, reciprocal |
| MinMax | `simulink/Math Operations/MinMax` | Clamp, ReLU-like ops |

## Approach B: MATLAB Function Block

Use when the operation involves reshape, permute, indexing, or multi-step computation.
The MATLAB Function block runs codegen-compatible MATLAB code inside Simulink.

**Example -- Patch flatten (reshape + permute):**
```matlab
subsys = [netPath '/patch_flatten'];
cleanSubs(subsys);

% Add MATLAB Function block
add_block('simulink/User-Defined Functions/MATLAB Function', [subsys '/PatchFlatten']);

% Set the function body (must include %#codegen for code generation)
rt = sfroot;
ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', [subsys '/PatchFlatten']);
ch.Script = sprintf([...
    'function Y = patch_flatten_fn(X)\n' ...
    '%%#codegen\n' ...
    'Xp = permute(X, [3,2,1]);\n' ...           % [H,W,C] -> [C,W,H]
    'Y = reshape(Xp, %d, %d);\n'], embedDim, numPatches);

% Wire: input -> MATLAB Function -> output
add_line(subsys, 'in/1',          'PatchFlatten/1', 'autorouting', 'on');
add_line(subsys, 'PatchFlatten/1', 'out/1',         'autorouting', 'on');
```

**Example -- CLS token extraction (indexing):**
```matlab
subsys = [netPath '/cls_extract'];
cleanSubs(subsys);

add_block('simulink/User-Defined Functions/MATLAB Function', [subsys '/ClsExtract']);
ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', [subsys '/ClsExtract']);
ch.Script = sprintf([...
    'function Y = cls_extract_fn(X)\n' ...
    '%%#codegen\n' ...
    'Y = X(:, 1);\n']);                          % First token (CLS)

add_line(subsys, 'in/1',         'ClsExtract/1', 'autorouting', 'on');
add_line(subsys, 'ClsExtract/1', 'out/1',        'autorouting', 'on');
```

**Example -- CLS token prepend (concatenation with learned constant):**
```matlab
subsys = [netPath '/cls_prepend'];
cleanSubs(subsys);

% Store CLS token in model workspace
clsVal = single(reshape(loadedWeights.cls_token, embedDim, 1));
mdlWs.assignin('cls_token_w', clsVal);

% Constant for CLS token + MATLAB Function for concatenation
add_block('simulink/Sources/Constant', [subsys '/CLSConst'], ...
    'Value', 'cls_token_w', 'OutDataTypeStr', 'single', 'SampleTime', '-1');
add_block('simulink/User-Defined Functions/MATLAB Function', [subsys '/ClsPrepend']);
ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', [subsys '/ClsPrepend']);
ch.Script = sprintf([...
    'function Y = cls_prepend_fn(X, cls)\n' ...
    '%%#codegen\n' ...
    'Y = [cls, X];\n']);                         % Prepend CLS to patch sequence

add_line(subsys, 'in/1',        'ClsPrepend/1', 'autorouting', 'on');
add_line(subsys, 'CLSConst/1',  'ClsPrepend/2', 'autorouting', 'on');
add_line(subsys, 'ClsPrepend/1', 'out/1',       'autorouting', 'on');
```

**Example -- Multi-head self-attention (complex multi-step computation with weights):**

This is the most complex placeholder replacement. Each attention block needs weight
Constant blocks plus a MATLAB Function block implementing the full QKV projection,
scaled dot-product attention, and output projection.

```matlab
subsys = [netPath '/block0_attn'];
cleanSubs(subsys);

% Store attention weights in model workspace
mdlWs.assignin('b0_wqkv', single(wqkvMatrix));   % [3*embedDim, embedDim]
mdlWs.assignin('b0_bqkv', single(bqkvVector));   % [3*embedDim, 1]
mdlWs.assignin('b0_wout', single(woutMatrix));   % [embedDim, embedDim]
mdlWs.assignin('b0_bout', single(boutVector));   % [embedDim, 1]

% Constant blocks for weights
add_block('simulink/Sources/Constant', [subsys '/Wqkv'], ...
    'Value', 'b0_wqkv', 'OutDataTypeStr', 'single', 'SampleTime', '-1');
add_block('simulink/Sources/Constant', [subsys '/Bqkv'], ...
    'Value', 'b0_bqkv', 'OutDataTypeStr', 'single', 'SampleTime', '-1');
add_block('simulink/Sources/Constant', [subsys '/Wout'], ...
    'Value', 'b0_wout', 'OutDataTypeStr', 'single', 'SampleTime', '-1');
add_block('simulink/Sources/Constant', [subsys '/Bout'], ...
    'Value', 'b0_bout', 'OutDataTypeStr', 'single', 'SampleTime', '-1');

% MATLAB Function block with full attention computation
add_block('simulink/User-Defined Functions/MATLAB Function', [subsys '/AttnFn']);
ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', [subsys '/AttnFn']);
ch.Script = sprintf([...
    'function Y = multihead_attn(X, Wqkv, Bqkv, Wout, Bout)\n' ...
    '%%#codegen\n' ...
    'scale = single(1/sqrt(%d));\n' ...                       % 1/sqrt(headDim)
    'QKV = Wqkv * X + repmat(Bqkv, 1, %d);\n' ...            % Project to Q,K,V
    'Q = QKV(1:%d,:); K = QKV(%d+1:%d,:); V = QKV(%d+1:%d,:);\n' ...
    ... % Unroll heads -- no dynamic indexing, codegen-safe
    'Q1=Q(1:hd,:);   K1=K(1:hd,:);   V1=V(1:hd,:);\n' ...
    'Q2=Q(hd+1:2*hd,:); K2=K(hd+1:2*hd,:); V2=V(hd+1:2*hd,:);\n' ...
    ... % Per-head: scores = Q''*K * scale, softmax, output = V*attn''
    'sc1=(Q1''*K1)*scale; sm1=max(sc1,[],2); se1=exp(sc1-sm1); at1=se1./sum(se1,2); h1=V1*at1'';\n' ...
    ... % Concatenate heads and output projection
    'Y = Wout * [h1;h2;...;hN] + repmat(Bout, 1, %d);\n'], ...
    headDim, numTokens, embedDim, embedDim, 2*embedDim, ...
    2*embedDim, 3*embedDim, numTokens);

% Wire all inputs
add_line(subsys, 'in/1',    'AttnFn/1', 'autorouting', 'on');
add_line(subsys, 'Wqkv/1',  'AttnFn/2', 'autorouting', 'on');
add_line(subsys, 'Bqkv/1',  'AttnFn/3', 'autorouting', 'on');
add_line(subsys, 'Wout/1',  'AttnFn/4', 'autorouting', 'on');
add_line(subsys, 'Bout/1',  'AttnFn/5', 'autorouting', 'on');
add_line(subsys, 'AttnFn/1', 'out/1',   'autorouting', 'on');
```

**Key pattern for attention:** Unroll heads explicitly (Q1/K1/V1, Q2/K2/V2, ...) instead of
using a loop with dynamic indexing. Dynamic indexing is not codegen-safe, but unrolled heads
with hard-coded index ranges are.

## Step 4: Resolve Signal Dimensions and Save

After replacing all placeholders, update the model to resolve signal dimensions:

```matlab
set_param(modelName, 'SimulationCommand', 'update');
save_system(modelName);
fprintf('Model update: OK (signal dimensions resolved)\n');
```

If the update succeeds, all placeholder subsystems now have correctly-dimensioned outputs
and the model is ready for simulation and code generation.

## Key Rules for MATLAB Function Block Code

All code inside MATLAB Function blocks must be **codegen-compatible**:

- Always include `%#codegen` pragma
- Use only static array sizes (no variable-length outputs)
- No cell arrays, dynamic dispatch, or object handles
- No `try/catch`
- Reshape, permute, indexing, and basic math are all supported
- `repmat` is supported for broadcast patterns
- Unroll loops with known iteration counts -- no dynamic indexing
- All output dimensions must be determinable at compile time

## Storing Weights in Model Workspace

Weights for placeholder replacements are stored in the **model workspace**, not the base
workspace. This ensures they travel with the .slx file:

```matlab
mdlWs = get_param(modelName, 'ModelWorkspace');
mdlWs.assignin('weight_name', single(weightMatrix));
```

Constant blocks reference these by name: `'Value', 'weight_name'`.

## Helper Functions

### cleanSubs -- Remove placeholder stub contents

```matlab
function cleanSubs(subsys)
lines = find_system(subsys, 'FindAll', 'on', 'LookUnderMasks', 'on', 'type', 'line');
for k = 1:numel(lines)
    try, delete_line(lines(k)); catch, end
end
try, delete_block([subsys '/Assertion']); catch, end
try, delete_block([subsys '/DimFix']); catch, end
end
```

### getChart -- Access MATLAB Function block script programmatically

```matlab
function ch = getChart(rt, blockPath)
ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', blockPath);
end
```

Usage:
```matlab
rt = sfroot;
add_block('simulink/User-Defined Functions/MATLAB Function', blockPath);
ch = getChart(rt, blockPath);
ch.Script = sprintf('function Y = myFn(X)\n%%#codegen\nY = X + 1;\n');
```

## Looping Over Multiple Placeholders of the Same Type

When the same unsupported layer type appears many times (e.g., 12 attention blocks in a
transformer), parameterize the replacement in a loop:

```matlab
for b = 0:numBlocks-1
    subsys = [netPath '/block' num2str(b) '_attn'];
    cleanSubs(subsys);

    % Load block-specific weights
    wqkv = single(loadedWeights.(sprintf('block%d_wqkv', b)));
    bqkv = single(loadedWeights.(sprintf('block%d_bqkv', b)));
    wout = single(loadedWeights.(sprintf('block%d_wout', b)));
    bout = single(loadedWeights.(sprintf('block%d_bout', b)));

    % Store in model workspace with block-indexed names
    wn = sprintf('b%d_wqkv', b); mdlWs.assignin(wn, wqkv);
    bn = sprintf('b%d_bqkv', b); mdlWs.assignin(bn, bqkv);
    wo = sprintf('b%d_wout', b); mdlWs.assignin(wo, wout);
    bo = sprintf('b%d_bout', b); mdlWs.assignin(bo, bout);

    % Add Constant blocks referencing block-indexed workspace vars
    add_block('simulink/Sources/Constant', [subsys '/Wqkv'], ...
        'Value', wn, 'OutDataTypeStr', 'single', 'SampleTime', '-1');
    % ... (same pattern for Bqkv, Wout, Bout)

    % Add MATLAB Function block (same script for all blocks -- weights differ)
    add_block('simulink/User-Defined Functions/MATLAB Function', [subsys '/AttnFn']);
    ch = getChart(rt, [subsys '/AttnFn']);
    ch.Script = sprintf(attnScriptTemplate);

    % Wire
    add_line(subsys, 'in/1',    'AttnFn/1', 'autorouting', 'on');
    add_line(subsys, 'Wqkv/1',  'AttnFn/2', 'autorouting', 'on');
    % ... (wire remaining constants)
    add_line(subsys, 'AttnFn/1', 'out/1',   'autorouting', 'on');
end
```

This keeps the replacement script compact even when there are many identical placeholder types.


Copyright 2026 The MathWorks, Inc.

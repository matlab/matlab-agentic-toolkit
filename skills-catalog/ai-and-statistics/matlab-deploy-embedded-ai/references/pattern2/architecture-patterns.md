# Architecture-Specific Patterns for PyTorch/LiteRT Code Generation

Each model architecture has unique input format requirements and gotchas when using
`loadPyTorchExportedProgram` for code generation.

## LSTM Models

### Entry-Point Pattern

```matlab
function pred = predict_lstm(Xin)
%#codegen

persistent net;
if isempty(net)
    net = loadPyTorchExportedProgram('/absolute/path/to/lstm_model.pt2');
end

% Input: single [1 x seq_len x features] -- matches PyTorch [batch, T, C]
out = net.invoke(single(Xin));
pred = single(out);
end
```

### Input Type Specification

```matlab
% PyTorch LSTM expects [batch, seq_len, features]
inputType = coder.typeof(single(zeros(1, seq_len, num_features)), ...
    [1 seq_len num_features], [false false false]);
```

### C Input Layout

Generated C functions expect **column-major** input arrays. Your C test harness must
transpose from PyTorch's row-major layout:

```c
// PyTorch row-major: input[t * NUM_FEATURES + f]
// Generated C column-major: input[t + f * SEQ_LEN]
for (int t = 0; t < SEQ_LEN; t++)
    for (int f = 0; f < NUM_FEATURES; f++)
        c_input[t + f * SEQ_LEN] = pytorch_input[t * NUM_FEATURES + f];
```

### LSTM-Specific Notes

- PyTorch LSTMs include h_n[-1] selection, argmax, and other post-processing in the
  exported graph. All of these are handled transparently -- no need to manually strip
  or reimplement anything.
- Multi-layer LSTMs export and generate code cleanly regardless of layer count.

---

## MLP (Feedforward) Models

### Entry-Point Pattern

```matlab
function pred = predict_mlp(Xin)
%#codegen

persistent net;
if isempty(net)
    net = loadPyTorchExportedProgram('/absolute/path/to/mlp_model.pt2');
end

% Input: single [1 x num_features] -- matches PyTorch [batch, features]
out = net.invoke(single(Xin));
pred = single(out);
end
```

### Input Type Specification

```matlab
% PyTorch MLP expects [batch, features]
inputType = coder.typeof(single(zeros(1, num_features)), ...
    [1 num_features], [false false]);
```

### MLP-Specific Notes

- Simple FC + ReLU stacks export and generate code without any issues.
- All activation functions (ReLU, SiLU, GELU, etc.) are handled automatically.

---

## CNN Models

### Entry-Point Pattern

```matlab
function pred = predict_cnn(Xin)
%#codegen

persistent net;
if isempty(net)
    net = loadPyTorchExportedProgram('/absolute/path/to/cnn_model.pt2');
end

% Input: single [1 x C x H x W] -- matches PyTorch NCHW format
out = net.invoke(single(Xin));
pred = single(out);
end
```

### Input Type Specification

```matlab
% PyTorch CNN expects [batch, channels, height, width] (NCHW)
inputType = coder.typeof(single(zeros(1, 3, 224, 224)), ...
    [1 3 224 224], false(1, 4));
```

### CNN-Specific Notes

- **Channel shuffle, depthwise convolutions, grouped convolutions** -- all handled
  transparently. These ops that cause headaches in other import paths work cleanly here.
- **Global average pooling, adaptive pooling** -- handled automatically.

---

## Vision Transformer (ViT) Models

### Entry-Point Pattern

```matlab
function pred = predict_vit(Xin)
%#codegen

persistent net;
if isempty(net)
    net = loadPyTorchExportedProgram('/absolute/path/to/vit_model.pt2');
end

% Input: single [1 x 3 x 224 x 224] -- same as CNN (NCHW)
out = net.invoke(single(Xin));
pred = single(out);
end
```

### Input Type Specification

```matlab
% Same as CNN -- patch embedding is internal to the model
inputType = coder.typeof(single(zeros(1, 3, 224, 224)), ...
    [1 3 224 224], false(1, 4));
```

### ViT-Specific Notes

- **Multi-head self-attention** -- Q/K/V splitting and attention computation handled automatically.
- **Positional embeddings, GELU, CLS token, patch flattening** -- all handled automatically.
- **Large generated code** -- ViT with 12 transformer blocks generates substantial C code.
  Use `cfg.LargeConstantThreshold = 0` to keep weights in binary files.

### Key ViT Dimensions

```
embedDim = 192       % Token embedding dimension
numHeads = 3         % Multi-head attention
mlpDim = 768         % MLP hidden (4x embedDim)
numBlocks = 12       % Transformer blocks
numPatches = 196     % (224/16)^2 for 16x16 patches
numTokens = 197      % patches + CLS token
```

---

## Architecture Selection for Embedded Deployment

| Architecture | Params Range | Typical MCU Target | Flash Budget | Inference Time |
|-------------|-------------|-------------------|-------------|----------------|
| MLP | 1K-50K | Cortex-M0/M4 | 16-256 KB | < 1 ms |
| LSTM | 1K-100K | Cortex-M4/M7 | 64 KB-1 MB | < 1 ms |
| Small CNN | 100K-2M | Cortex-M7/A53 | 1-10 MB | 10-50 ms |
| Large CNN | 2M-10M | Cortex-A53+ | 10-50 MB | 30-200 ms |
| ViT | 5M+ | Cortex-A53+ | 20+ MB | 50-500 ms |

## PyTorch Features Handled Automatically

The following PyTorch features generate code without manual intervention:

LSTM gates, multi-layer LSTM, h_n[-1] selection, argmax, channel shuffle,
grouped/depthwise convolutions, global average pooling, multi-head attention,
GELU/SiLU/Mish activations, positional embeddings, batch normalization,
and residual connections.


Copyright 2026 The MathWorks, Inc.

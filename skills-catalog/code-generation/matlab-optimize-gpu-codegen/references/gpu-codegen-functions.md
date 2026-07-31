# GPU Coder Functions and Pragmas

When to use each GPU Coder function and pragma for controlling kernel
generation, parallel reductions, and memory management.

## Kernel Mapping Pragmas

### coder.gpu.kernelfun (Function-Level Auto-Mapping)

**Use when:** You want GPU Coder to automatically parallelize all eligible
loops in a function. Good default for most cases.

```matlab
function out = myFunction(in)
    coder.gpu.kernelfun;
    % GPU Coder analyzes all loops here and parallelizes where safe
    out = zeros(size(in));
    for i = 1:numel(in)
        out(i) = in(i)^2 + 1;
    end
end
```

### coder.gpu.kernel (Loop-Level Manual Control)

**Use when:** You need fine-grained control over a specific loop — either
the compiler can't prove independence but you know iterations are independent,
or you need specific thread/block dimensions for occupancy tuning.

Do NOT use before loops with reductions. Must place immediately before a
for-loop.

```matlab
% Basic — auto-compute launch params
coder.gpu.kernel();
for i = 1:N
    out(i) = compute(in(i));
end

% Explicit grid/block dimensions
coder.gpu.kernel([numBlocks, 1, 1], [threadsPerBlock, 1, 1]);
for i = 1:N
    out(i) = compute(in(i));
end

% With min blocks per SM (increases occupancy by limiting register use) and custom kernel name
coder.gpu.kernel([B, 1, 1], [T, 1, 1], minBlocksPerSM, "myKernel");
for i = 1:N
    out(i) = compute(in(i));
end
```

### coder.gpu.nokernel

**Use when:** You want to prevent GPU Coder from generating CUDA kernels for
a specific loop. Place immediately before a for-loop. Useful when a loop is
faster on CPU (e.g., short iteration count, complex branching) or when
parallelization would introduce correctness issues.

```matlab
coder.gpu.nokernel();
for i = 1:smallN
    out(i) = complexSerialWork(in(i), state);
end
```

## Optimized GPU Implementations

Functions that generate optimized CUDA kernels or library calls for common
operations. Use these instead of writing manual loops when the operation matches.

| Function | Description |
|---|---|
| `gpucoder.reduce` | Parallel reduction (sum, max, min, product) over array elements. Use instead of accumulator loops. Reduction function must be associative and commutative. |
| `gpucoder.sort` | Optimized GPU sort. Use instead of manual sorting loops. |
| `gpucoder.transpose` | Optimized GPU transpose with coalesced memory access. Use for real arrays. |
| `gpucoder.ctranspose` | Optimized GPU complex conjugate transpose. Use for complex arrays. |
| `gpucoder.matrixMatrixKernel` | Optimized kernel for matrix-matrix operations. Called automatically by GPU Coder when applicable. |
| `gpucoder.batchedMatrixMultiply` | Batched matrix multiply for multiple paired 2-D matrices (many small matrix multiplies in parallel). Use when multiplying several pairs of same-size matrices. |
| `gpucoder.batchedMatrixMultiplyAdd` | Batched matrix multiply with add (D = alpha*A*B + beta*C). Use for fused multiply-accumulate on batches of paired matrices. |
| `gpucoder.stridedMatrixMultiply` | Strided batched matrix multiply for 3-D arrays where matrices are stored with a fixed stride in memory. Use for contiguous 3-D array slices. |
| `gpucoder.stridedMatrixMultiplyAdd` | Strided batched matrix multiply with add for 3-D arrays. Combines strided access with fused multiply-accumulate. |
| `stencilfun` | Optimized GPU stencil operations (convolution, filtering). Applies a function over sliding windows of an array. Use for neighborhood operations like 2-D convolution or image filtering. |

**`gpucoder.reduce` example:**
```matlab
% BEFORE (serial accumulation — not parallelizable)
total = 0;
for i = 1:N
    total = total + data(i);
end

% AFTER (parallel reduction)
total = gpucoder.reduce(data, @plus);

% With dimension and preprocessing NVPs
colSums = gpucoder.reduce(matrix, @plus, dim=1);
squaredSum = gpucoder.reduce(data, @plus, preprocess=@(x) x.^2);
```

## Atomic Operations

**Use when:** Multiple threads must update the same memory location safely.
Atomics are slower than reductions but necessary when the update pattern
doesn't fit a clean reduction (e.g., histogram binning, sparse scatter-add).

**Prefer `gpucoder.reduce` over atomics when possible** — reductions avoid
contention and are significantly faster for regular patterns.

| Function | Description |
|---|---|
| `gpucoder.atomicAdd` | Atomically add value to variable in global or shared memory. Most common atomic — use for histograms, scatter-add. |
| `gpucoder.atomicCAS` | Atomically compare and swap value of variable in global or shared memory. Use for custom atomic operations. |

Available atomics: `gpucoder.atomicAdd`, `gpucoder.atomicCAS`, `gpucoder.atomicSub`, 
`gpucoder.atomicMax`, `gpucoder.atomicMin`, `gpucoder.atomicAnd`, `gpucoder.atomicOr`,
`gpucoder.atomicXor`, `gpucoder.atomicExch`, `gpucoder.atomicInc`, `gpucoder.atomicDec`.

**Example — histogram accumulation:**
```matlab
coder.gpu.kernel();
for i = 1:N
    bin = computeBin(data(i));
    counts(bin) = gpucoder.atomicAdd(counts(bin), 1);
end
```

## Memory Management

### coder.gpu.constantMemory

**Use when:** A read-only variable is accessed by every thread in a kernel
(e.g., filter coefficients, lookup tables). Place inside a parallelizable
loop body. GPU Coder loads the variable into device constant memory, which
is cached and optimized for broadcast reads. The variable must not be written
to within the kernel — GPU Coder ignores the pragma otherwise.

```matlab
function b = myFun(a,k)
    b = coder.nullcopy(zeros(size(a)));
    coder.gpu.kernel();
    for j = 1:256
        for i = 1:256
            coder.gpu.constantMemory(k);
            b(i,j) = a(i,j) + k(1) + k(2) + k(3);
        end
    end
end
```

### coder.gpu.persistentMemory

**Use when:** A persistent variable should remain allocated on the GPU across
function calls (e.g., state buffers, running accumulators). Keeps the data on
device between invocations, avoiding repeated host-to-device transfers. The
variable must be fixed-size and a supported GPU data type.

```matlab
function output = myPersistent(input)
    persistent pvar;
    if isempty(pvar)
        pvar = ones(size(input));
    end
    
    coder.gpu.persistentMemory(pvar);
    
    for i = 1:numel(input)
        pvar(i) = pvar(i) + input(i);
    end
    
    output = coder.nullcopy(input);
    for i = 1:numel(input)
        output(i) = pvar(i) * input(i);
    end
end
```

----

Copyright 2026 The MathWorks, Inc.

----

# parfor Code Analyser Messages

Complete catalog of `checkcode` / `codeIssues` messages for parfor (PF-prefixed
IDs). Use the message ID to quickly identify the category and fix approach.

## Variable Classification Errors

These are the hard problems — the skill's fix patterns target these.

| ID | Message | Fix pattern |
|----|---------|-------------|
| PFUNK | Unable to classify variable {0} in the body of the parfor loop. | Catch-all. Identify the conflicting access pattern (struct fields as reductions, indexed reduction, mixed roles). See Fixes 1, 4, 5. |
| PFSLO | Variable {0} is indexed using the parfor loop variable, but it is not a valid sliced output variable. | Invalid slicing: non-deterministic subscript, loop var in multiple dims, or other rule violation. See Fix 3. |
| PFSLW | Parfor loop variable {0} has multiple sliced accesses, but they do not all have the same list of subscripts. Each access to a sliced variable must use precisely the same list of subscripts. | Multiple subscript patterns on same variable. See Fix 2. |
| PFSLRD | Parfor loop variable {0} is accessed with an invalid combination of sliced indexing expressions and non-indexed reads. It is not valid to access the whole value of a sliced output variable. | Sliced write + full read on same variable. See Fix 4. |
| PFIIN | The input variable {0} should be initialized before the PARFOR loop. | Variable read before written — pre-allocate before the loop. |

## Temporary Variable Errors

Variable classified as temporary but used in a way that conflicts.

| ID | Message | Fix pattern |
|----|---------|-------------|
| PFUTMP | Temporary variable {0} must be set inside the parfor loop before it is used. | Ensure first reference in each iteration is a full assignment. See Fix 6. |
| PFUTVR | Variable {0} may have been intended as a reduction variable, but is an uninitialized temporary. | Initialise the variable before the parfor (e.g. `X = 0;`) to enable reduction classification. |
| PFTUS | The temporary variable {0} is used after the PARFOR loop on line {1}, but its value is not available after the loop. | Conditional assignment makes it temporary; restructure as sliced output + post-loop reduction. See Fix 7. |
| PFTUSW | The temporary variable {0} might be used after the PARFOR loop on line {1}. The value set on this line is not available after the loop. | Same as PFTUS (warning variant). See Fix 7. |

## Sliced Variable — Nested For Rules

These fire when a sliced variable is indexed via an inner `for` loop variable.

| ID | Message | Fix pattern |
|----|---------|-------------|
| PFFRNG | When indexing a sliced variable with a nested for loop variable, the range of the for loop variable must be a row vector of positive constant numbers or variables. | Make the inner loop range a literal or broadcast variable. See Fix 3(c). |
| PFCTXT | When indexing a sliced variable with a nested for loop variable, the sliced variable must be inside the for loop that defines the range of the for loop variable. | Move the sliced assignment inside the inner for loop, or collect into a temporary first. |
| PFMLTI | When indexing a sliced variable with a nested for loop variable, the for loop variable must not be assigned other than by its for statement. | Don't reassign the inner loop variable inside the loop body. |
| PFFSUB | Indexing a nested for loop variable is not supported in parfor loops. | Don't subscript `j(k)` — use a separate variable. |
| PFANON | Using a sliced output variable in an anonymous function is not supported in parfor loops. | Never write `fh = @() slicedOut(ii)` or similar |

## Reduction Variable Rules

| ID | Message | Fix pattern |
|----|---------|-------------|
| PFINCR | Using different reduction functions with the same reduction variable is not supported in parfor loops. | Use one reduction operation per variable, or split into multiple variables. |
| PFRNC | Parfor reduction variable {0} must be used in the same position in each assignment statement when using non-commutative reduction operations '*', '[,]', or '[;]'. | Keep the reduction variable on the same side (left or right) in every assignment. |
| PFNAR | Subtracting reduction variable {0} from expressions is not supported in parfor loops. | Rewrite as addition: `X = X + (-expr)` instead of `X = expr - X`. |
| PFRFH | The parfor reduction function {0} must either be a function name or a broadcast variable. | Don't use an expression as the reduction function — assign it to a variable first. |
| PFRIN | The reduction variable {0} might not be set before the PARFOR loop. | Initialise the reduction variable before parfor (e.g. `total = 0;`). |
| PFRUS | The reduction variable {0} might not be used after the PARFOR loop. | Performance warning — the reduction result is unused. Remove or use it. |

## Transparency Violations

These are straightforward "don't use X in parfor" — no classification analysis needed. In each case,
the prohibited function attempts to modify the workspace of the parfor loop in a non-transparent
way - i.e. not in the text of the program.

| ID | Message |
|----|---------|
| PFBFN | Use of this function is invalid inside a PARFOR loop because it accesses or modifies the workspace in a non-transparent way. |
| PFEVC | EVALIN('caller') and ASSIGNIN('caller') are invalid inside of a PARFOR loop. |
| PFEVB | Using EVALIN('base') or ASSIGNIN('base') inside a PARFOR loop refers to the worker machines' base workspaces. |
| PFWHOS | Using "who" or "whos" without "-file" is invalid inside a PARFOR loop because it accesses the workspace in a non-transparent way. |
| PFNF | Nested functions cannot be called from within parfor loops. |
| PFLD | 'load' must assign to an output variable in parfor loops. |
| PFSV | SAVE cannot be called in a PARFOR loop without the '-fromstruct' option. |
| PFNACK | 'narginchk' and 'nargoutchk' cannot be used in parfor loops. |
| PFNAIO | 'nargin' and 'nargout' require a function argument in parfor loops. |
| PFINPT | 'inputname' is not supported in parfor loops. |

## Structural Constraints

These are simple constraints on constructs that are illegal inside parfor.

| ID | Message |
|----|---------|
| PFBRK | break statements cannot be used inside a parfor loop. |
| PFRTN | return statements cannot be used inside a parfor loop. |
| PFSPMD | spmd statements cannot be used inside parfor loops. |
| PFPF | parfor loops cannot be used inside other parfor loops. |
| PFFORA | Assigning to for loop variables is not supported in parfor loops. |
| PFVSUB | Indexing parfor loop variables is not supported in parfor loops. |
| PFXST | Assigning to the parfor loop index variable is not supported in parfor loops. |
| PFANSLP | 'ans' is not supported as a parfor loop variable. |
| PFANSNS | 'ans' is not supported as a for loop variable in parfor loops. |
| PFRNG | The range of a PARFOR statement must be consecutive integers. |
| PFRNI | The parfor loop can only use a step size of 1 or -1. |
| PFVARS | Parfor loop contains too many variables. |

## Global and persistent data

Workers operating on the body of parfor have completely separate `global` and `persistent`
workspaces. Do not use `global` or `persistent` with parfor.

| ID | Message |
|----|---------|
| PFGLOB | Global variable declarations are not supported in parfor loops. |
| PFPERS | Persistent variable declarations are not supported in parfor loops. |
| PFGP | Avoid assigning to GLOBAL or PERSISTENT variable {0} inside a PARFOR loop. |
| PFGV | Avoid using GLOBAL variable {0} in a PARFOR loop. |


## Post-Loop Usage Warnings

| ID | Message |
|----|---------|
| PFOUS | The output variable {0} might not be used after the PARFOR loop. |
| PFUIX | The index variable {0} might be used after the PARFOR loop on line {1}, but it is unavailable after the loop. |
| PFUIXW | The index variable {0} might be used after the PARFOR loop on line {1}. The value set on this line is not available after the loop. |

## Broadcast Warning

| ID | Message |
|----|---------|
| PFBNS | The entire array or structure {0} is a broadcast variable. This might result in unnecessary communication overhead. |

**PFBNS is almost always harmless.** It is an informational performance hint,
not an error. The code is correct and will run fine. Do NOT attempt to "fix"
this warning unless the user specifically asks about performance — restructuring
code to silence PFBNS often introduces real classification errors (e.g. turning
a valid broadcast into a broken sliced variable). The safe response is to
acknowledge the warning and explain it has no effect on correctness.

----

Copyright 2026 The MathWorks, Inc.

----

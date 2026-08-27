# Node Navigation Patterns

Detailed workflows for browsing, searching, and navigating OPC UA server
address spaces programmatically.

## Decision Logic

| User Input | Workflow | Entry Function |
|------------|----------|----------------|
| Exact NodeId (e.g., `ns=3;s=1002`) | Direct Lookup | `opcuanode` / `findNodeById` |
| Browse path (e.g., `Demo/Mass/Nested/7`) | Hierarchical Browse | `.Children` per level |
| Explore / list available nodes | Hierarchical Browse | `.Children` property |
| Vague intent (e.g., "cooling status of Line1") | Hierarchical Browse | `.Children` with string matching |
| Node name or partial name | Hierarchical Browse | `.Children` with string matching |
| Broad/unscoped request (e.g., "all X nodes") | **STOP** — Ask user to narrow scope | Do not execute |

## Workflow A: Direct Node Lookup

Use when the user provides an exact namespace index and identifier.

**1. Validate inputs** — Ensure namespace index and identifier are provided.
If missing, ask the user before proceeding.

**2. Resolve the node:**

| Context | Resolution |
|---------|-----------|
| Connected client available | `node = opcuanode(index, id, uaClient);` |
| Source node/nodeList provided (scoped request) | `node = findNodeById(nodeList, nsInd, id);` |
| No connection, no scope | `node = opcuanode(index, id);` |

If the user specifies a scope (subtree), always use `findNodeById` —
never bypass with `opcuanode`.

**3. Interpret result:**
- `findNodeById` returns empty → no node found in that hierarchy.
- `opcuanode` returns `NodeType = 'Unknown'` → node does not exist on server.

**4. Method node handling** — If the node is a Method and `Parent` is
empty, re-resolve via `findNodeById`. Parent info is required for `invoke`.

**5. Next actions** — Variable → Read/Write | Method → Invoke (if parent
available) | Object → Browse children.

## Workflow B: Hierarchical Browse and Navigation

Use when the user provides a path, asks to explore a folder, or gives
semantic input (e.g., "cooling status of Line1").

**Precondition:** Before starting, confirm the user has specified a parent
folder or browse path. If the request is broad or unscoped (e.g., "find
all X nodes" with no parent), **STOP and ask the user to narrow scope**.
List top-level nodes if needed to help them choose.

**1. Identify intent:**

| Input Type | Example | Action |
|-----------|---------|--------|
| Explicit path | `Demo/Mass/Nested/7` | Split on `/` into tokens |
| Folder exploration | "show nodes under Demo" | Navigate to folder, list `.Children` |
| Semantic query | "cooling status of Line1" | Extract keywords as tokens |
| Ambiguous name, no path | "Browse all Byte16 matrix" | Ask user for parent folder |

**2. Get namespace root** — `ns = uaClient.Namespace;`

**3. Traverse level-by-level:**

```matlab
ns = uaClient.Namespace;
idx = arrayfun(@(n) strcmp(n.Name, 'Demo'), ns);
level1 = ns(idx);

children = level1.Children;
idx = arrayfun(@(n) strcmp(n.Name, 'Mass'), children);
level2 = children(idx);

children = level2.Children;
idx = arrayfun(@(n) strcmp(n.Name, 'Nested'), children);
level3 = children(idx);

children = level3.Children;
idx = arrayfun(@(n) strcmp(n.Name, '7'), children);
target = children(idx);
```

**4. Matching strategy:**
- Prefer exact match first.
- If exact fails → case-insensitive, then partial/contains (for semantic inputs).
- For semantic queries → match tokens at any level; prioritize nodes
  matching multiple tokens.

**5. Handle ambiguity:**
- Multiple matches at a level → present options to user for selection.
- Token cannot be resolved → stop, report which token failed and list
  available nodes at that level.

**5a. Progressive reveal checkpoint (MANDATORY)** — When searching
multiple siblings (e.g., checking subfolders at the same level for
matching nodes), stop after the first subfolder yields results. Present
findings to the user and ALWAYS end your response with a question like
"Would you like me to search other subfolders for more matches?" On each
subsequent iteration, present results and ask again before proceeding.
Never iterate through all siblings automatically.

**6. Batch processing for large child sets:**

```matlab
%% Tool call 1: Get children and count
children = target.Children;
numChildren = numel(children);
fprintf('Node has %d children.\n', numChildren);
```

```matlab
%% Tool call 2: Process batch 1-200
results = {};
for i = 1:min(200, numChildren)
    dt = children(i).ServerDataType;
    if strcmp(dt, 'Int32')
        results{end+1} = children(i).Name;
    end
end
fprintf('Checked %d/%d nodes. Found %d so far.\n', min(200, numChildren), numChildren, numel(results));
```

```matlab
%% Tool call 3: Process batch 201-400
for i = 201:min(400, numChildren)
    dt = children(i).ServerDataType;
    if strcmp(dt, 'Int32')
        results{end+1} = children(i).Name;
    end
end
fprintf('Checked %d/%d nodes. Found %d so far.\n', min(400, numChildren), numChildren, numel(results));
```

**7. Next actions** — Object → Browse children | Variable → Read/Write |
Method → Invoke (if parent available).

## Rules

- Always start from `uaClient.Namespace` and traverse via `.Children`.
- Always try the most targeted approach first — list top-level nodes,
  scope search to the relevant subtree.
- Never initiate a search on the entire namespace.
- Always follow progressive reveal — present results and stop. Only
  continue if the user asks for more.
- Never use `opcuanode`/`findNodeById` unless namespace index + identifier
  are explicitly provided.
- Preserve hierarchy order — do not skip levels unless handling semantic
  queries where the exact path is unknown.
- **Max depth:** Limit traversal to 5 levels below the starting node
  unless the user specifies a different depth.
- **Node-count safety:** If traversal visits more than 1000 nodes without
  completing, stop immediately, report partial results, and ask the user
  whether to continue or narrow scope.
- **Disconnection recovery:** If the session disconnects mid-traversal,
  reconnect (`connect(uaClient)`), then resume from the last unvisited
  subtree.

## Performance Guidelines

- Always check child count in a separate tool call before iterating.
  Batch in groups of 200 if count > 200 (one tool call per batch).
- Scope searches to the smallest relevant subtree before iterating.
- The `Server` folder (namespace index 0) contains OPC UA server
  infrastructure nodes — not user-defined data. Skip it unless
  explicitly asked about server properties.

## `browseNamespace` — GUI Only

**Never use `browseNamespace` in scripts or agent workflows.** It opens
an interactive graphical dialog that blocks the MATLAB session. Use
`uaClient.Namespace` and `.Children` traversal instead.

```matlab
% WRONG — blocks the session with a GUI:
% nodes = browseNamespace(uaClient);

% CORRECT — programmatic access:
ns = uaClient.Namespace;
idx = arrayfun(@(n) strcmp(n.Name, 'Counter'), ns);
node = ns(idx);
```

## Search by Name (Recursive Children Traversal)

```matlab
ns = uaClient.Namespace;
queue = ns(:);
results = [];
checked = 0;
while ~isempty(queue)
    batchEnd = min(200, numel(queue));
    batch = queue(1:batchEnd);
    queue(1:batchEnd) = [];
    idx = arrayfun(@(n) contains(n.Name, 'Temperature'), batch);
    results = [results; batch(idx)];
    for i = 1:numel(batch)
        ch = batch(i).Children;
        if ~isempty(ch)
            queue = [queue; ch(:)];
        end
    end
    checked = checked + numel(batch);
    fprintf('Searched %d nodes, found %d matches...\n', checked, numel(results));
end
fprintf('Found %d nodes matching "Temperature".\n', numel(results));
for i = 1:numel(results)
    fprintf('  %s (ns=%d, type=%s)\n', ...
        results(i).Name, results(i).NamespaceIndex, results(i).NodeType);
end
```

----

Copyright 2026 The MathWorks, Inc.

----

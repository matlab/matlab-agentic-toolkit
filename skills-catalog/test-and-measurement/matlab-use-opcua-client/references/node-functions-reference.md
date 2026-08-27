# Node Functions Reference

Syntax, arguments, and usage guidelines for the primary OPC UA node
discovery functions in the Industrial Communication Toolbox.

## findNodeById

Search a node list for a node matching a specific namespace index and identifier.

### Syntax

```matlab
% TEMPLATE — not executable (syntax signature)
foundNode = findNodeById(nodeList, nsInd, id)
```

### Input Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `nodeList` | Array of `opc.ua.Node` | Nodes to search through. Use `uaClient.Namespace` to search the entire namespace. |
| `nsInd` | Integer | Namespace index to match against the node's `NamespaceIndex` property. |
| `id` | `char`, `string`, or integer | Identifier to match against the node's `Identifier` property. |

### Output Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `foundNode` | `opc.ua.Node` | The node whose `NamespaceIndex` and `Identifier` match. Empty if not found. |

### Usage Guidelines

- Returns a **single** node (not an array) — there is at most one node per (nsInd, id) pair.
- Searches recursively; may query the server for further descendants.
- The returned node **retains parent information** — safe to use with `invoke`.
- Use when you know the namespace index and identifier but need the node in-context (with hierarchy info).

### Examples

```matlab
% Find the ServerCapabilities node (ns=0, id=2268)
uaClient = opcua("localhost", 51210);
connect(uaClient);
capNode = findNodeById(uaClient.Namespace, 0, 2268);
```

```matlab
% Find a node with string identifier
node = findNodeById(uaClient.Namespace, 5, "StaticData");
```

### Version History

| Version | Change |
|---------|--------|
| R2015b | Introduced |
| R2024a | Enhanced to find method nodes on OPC UA servers |

## opcuanode

Create OPC UA node objects directly from a known namespace index and identifier.

### Syntax

```matlab
% TEMPLATE — not executable (syntax signatures)
nodeList = opcuanode(index, id)
nodeList = opcuanode(index, id, uaClient)
```

### Input Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `index` | Numeric (scalar or array) | Namespace index. Data types: `single`, `double`, `int8`–`int64`, `uint8`–`uint64`. |
| `id` | Numeric, `char`, `string`, or cell array | Node identifier. Use cell array for mixed types (e.g., `{1001, 1002, 'BooleanDataItem'}`). |
| `uaClient` | `opc.ua.Client` | OPC UA client object. If connected, node properties are immediately retrieved from the server. |

### Behavior

| Form | What happens |
|------|-------------|
| `opcuanode(index, id)` | Creates node without server association. `Name` is set to `'index:id'`; other properties remain `'Unknown'` until a server operation associates it. |
| `opcuanode(index, id, uaClient)` | Immediately associates with the client. If connected, retrieves `Name`, `NodeType`, `ServerDataType`, etc. from the server. |

### Usage Guidelines

- Use **only** when you know the exact namespace index and identifier.
- The `id` argument must be a **single identifier** (numeric or string) — never a slash-separated path.
- Passing a browse path (e.g., `'Demo/Mass/Nested/7'`) **fails silently**: creates a node with `NodeType: 'Unknown'`.
- Nodes created via `opcuanode` **may lack parent information** (`Parent` empty):
  - When `Parent` is empty, `invoke()` fails with: *"Specified node has no parent information"*.
- For method invocation, check the node's `Parent` property first. If it is empty, re-resolve the node via `findNodeById` (or `.Children` navigation), which retains parent info; if it is non-empty, invoke directly.
- Can create arrays of nodes in one call by passing arrays/cell arrays for `index` and `id`.

### Examples

```matlab
% Create a node with server association
uaClient = opcua("opc.tcp://localhost:53530/OPCUA/SimulationServer2");
connect(uaClient);
myNode = opcuanode(2, 10225, uaClient);
```

```matlab
% Create multiple nodes at once
nodes = opcuanode([3, 3, 5], {1001, 1002, 'BooleanDataItem'}, uaClient);
values = readValue(uaClient, nodes);
```

### Limitations

| Limitation | Impact | Alternative |
|-----------|--------|-------------|
| No browse path support | Passing `'A/B/C'` creates invalid node silently | Walk path with `.Children` level-by-level |
| Parent may be empty | `invoke()` fails when `Parent` is empty | Check `Parent`; if empty, re-resolve via `findNodeById` or `.Children` navigation |

### Version History

| Version | Change |
|---------|--------|
| R2015b | Introduced |
| R2024a | Added ability to create method node objects (but still cannot invoke them) |

## getNamespace

Retrieve one layer of the OPC UA server namespace tree.

### Syntax

```matlab
% TEMPLATE — not executable (syntax signatures; ___ is doc placeholder)
nodes = getNamespace(uaClient)
nodes = getNamespace(uaClient, browseNode)
nodes = getNamespace(___, '-force')
```

### Input Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `uaClient` | `opc.ua.Client` | Connected OPC UA client object. |
| `browseNode` | `opc.ua.Node` | Node whose children to retrieve. If empty or omitted, retrieves the top-level namespace. |
| `'-force'` | Flag | Forces retrieval from the server, bypassing local cache. |

### Behavior

| Form | What happens |
|------|-------------|
| `getNamespace(uaClient)` | Returns the top-level namespace nodes. Equivalent to `uaClient.Namespace`. |
| `getNamespace(uaClient, browseNode)` | Retrieves only the children of `browseNode`. Stores them in `browseNode.Children`. |
| `getNamespace(___, '-force')` | Re-fetches from the server even if nodes are already cached locally. |

### Caching

- By default, returns cached nodes if they already exist locally (no server round-trip).
- Use `'-force'` to refresh from the server when you suspect the namespace has changed.
- The `uaClient.Namespace` property uses the same caching.

### Usage Guidelines

- Prefer `uaClient.Namespace` over `getNamespace(uaClient)` for cleaner syntax.
- Use `getNamespace(uaClient, node)` to explicitly populate a node's children before iterating.
- For large namespaces (thousands of children), scope queries to specific subtrees.

### Examples

```matlab
% Get top-level namespace
nodes = uaClient.Namespace;
```

```matlab
% Get children of a specific node
idx = arrayfun(@(n) strcmp(n.Name, 'Server'), uaClient.Namespace);
serverNode = uaClient.Namespace(idx);
children = getNamespace(uaClient, serverNode);
```

```matlab
% Force refresh from server
nodes = getNamespace(uaClient, '-force');
```

### Version History

| Version | Change |
|---------|--------|
| R2015b | Introduced |

## Quick Comparison

| Function | Use When | Returns | Has Parent Info | Can Invoke |
|----------|----------|---------|-----------------|------------|
| `findNodeById` | Know namespace index + identifier, need hierarchy context | Single node | Yes | Yes |
| `opcuanode` | Know exact namespace index + identifier, need quick access | Single/array of nodes | Sometimes (check `Parent`) | If `Parent` populated |
| `getNamespace` | Need to browse/explore one layer | Array of children | Yes | Yes |
| `.Children` | Navigate level-by-level, search by name | Array of children | Yes | Yes |

----

Copyright 2026 The MathWorks, Inc.

----

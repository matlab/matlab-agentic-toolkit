# Transaction Management — commit & rollback

## Basic Transaction Pattern

```matlab
conn.AutoCommit = 'off';

try
    sqlwrite(conn, "orders", orderData);
    sqlwrite(conn, "orderItems", itemData);
    commit(conn);
catch e
    rollback(conn);
    conn.AutoCommit = 'on';
    rethrow(e);
end

conn.AutoCommit = 'on';
```

## Critical Rules

- **ALWAYS** set `AutoCommit` to `'off'` before using `commit`/`rollback`.
- **ALWAYS** use `rollback(conn)` in `catch` blocks to undo partial changes.
- **ALWAYS** restore `AutoCommit` to `'on'` after the transaction block.
- **NEVER** use raw SQL `BEGIN`/`COMMIT`/`ROLLBACK` via `execute` — use MATLAB methods instead.
- If `AutoCommit` is `'on'` (default), each SQL statement auto-commits immediately — `commit`/`rollback` have no effect.

## Complete Example: Atomic Multi-Table Update

```matlab
conn = database("myDataSource", getSecret("dbUser"), getSecret("dbPass"));
conn.AutoCommit = 'off';

try
    % Reduce inventory
    execute(conn, "UPDATE inventory SET Quantity = Quantity - 10 WHERE ProductID = 42");

    % Record the shipment
    shipment = table(42, datetime("now"), 10, ...
        VariableNames=["ProductID", "ShipDate", "Quantity"]);
    sqlwrite(conn, "shipments", shipment);

    commit(conn);
catch e
    rollback(conn);
    conn.AutoCommit = 'on';
    close(conn);
    error("Shipment failed: %s", e.message);
end

conn.AutoCommit = 'on';
close(conn);
```

## Gotchas

- Transaction changes are invisible to other connections until `commit` is called.
- If the MATLAB session crashes before `commit`, all changes are lost (rolled back by the database).
- Some databases (e.g., SQLite) have limited concurrent transaction support.
- `AutoCommit` is a property of the connection object, not a function call.
- Place verification reads (e.g., `sqlread` to confirm) OUTSIDE the try/catch block, after `commit` — a read error inside the catch would trigger an unnecessary `rollback`.

----

Copyright 2026 The MathWorks, Inc.

----

# Transaction Management — commit & rollback

## Basic Transaction Pattern

```matlab
conn.AutoCommit = 'off';

try
    sqlwrite(conn, "orders", orderData);
    sqlwrite(conn, "orderItems", itemData);
    commit(conn);
    disp("Transaction committed.");
catch e
    rollback(conn);
    disp("Transaction rolled back: " + e.message);
end

conn.AutoCommit = 'on';
```

## Critical Rules

- **ALWAYS** set `AutoCommit` to `'off'` before using `commit`/`rollback`.
- **ALWAYS** use `rollback` in `catch` blocks to undo partial changes.
- **ALWAYS** restore `AutoCommit` to `'on'` after the transaction block.
- If `AutoCommit` is `'on'` (default), each SQL statement auto-commits immediately — `commit`/`rollback` have no effect.

## Complete Example: Atomic Multi-Table Update

```matlab
conn = database("myDataSource", getSecret("dbUser"), getSecret("dbPass"));
conn.AutoCommit = 'off';

try
    % Reduce inventory by 10 units (arithmetic update requires execute)
    execute(conn, "UPDATE inventory SET Quantity = Quantity - 10 WHERE ProductID = 42");

    % Record the shipment
    shipment = table(42, datetime("now"), 10, ...
        VariableNames=["ProductID", "ShipDate", "Quantity"]);
    sqlwrite(conn, "shipments", shipment);

    commit(conn);
    disp("Shipment recorded successfully.");
catch e
    rollback(conn);
    conn.AutoCommit = 'on'; %#ok<NASGU> restore before rethrowing
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

----

Copyright 2026 The MathWorks, Inc.

----

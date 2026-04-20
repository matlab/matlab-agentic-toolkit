---
name: matlab-map-database-objects
description: "Generates MATLAB Object Relational Mapping (ORM) code using Database Toolbox. Use when mapping MATLAB classes to database tables, reading/writing objects with ormread/ormwrite/ormupdate, defining Mappable classes, converting classes to SQL with orm2sql, or using object-oriented database workflows."
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# MATLAB Object Relational Mapper

Use when mapping MATLAB classes to relational database tables using the Object Relational Mapping (ORM) layer in Database Toolbox. Defines Mappable classes with property-to-column mappings and uses ormread, ormwrite, and ormupdate for CRUD operations on objects. Available since R2023b.

## When to Use This Skill

- Mapping MATLAB classes to database tables
- Reading database rows as MATLAB objects
- Writing MATLAB objects to database tables
- Updating database rows from modified objects
- Generating SQL CREATE TABLE from a class definition
- Object-oriented database workflows
- User mentions keywords: ORM, object relational mapping, Mappable, ormread, ormwrite, ormupdate, orm2sql, class mapping, property mapping, object database

## When NOT to Use

- Ad-hoc queries or data exploration — use `sqlread`/`fetch` with `RowFilter` instead
- Bulk imports/exports of thousands of rows — ORM is slower than `sqlwrite`/`sqlread` for bulk operations
- MongoDB, Cassandra, or Neo4j — ORM only works with relational databases (JDBC, ODBC, native MySQL/PostgreSQL/SQLite)
- MATLAB releases before R2023b — ORM is not available

## Critical Rules

### ORM Requirements
- **ALWAYS** inherit from `database.orm.mixin.Mappable` — this is required for ORM functionality.
- **ALWAYS** define at least one `PrimaryKey` property — ORM requires it for identity.
- **ALWAYS** use class-level attribute `TableName` to specify the database table name.
- **ALWAYS** include a constructor that handles `nargin == 0` (allows preallocation by ORM).
- ORM requires **R2023b or later**.

### Supported Connections
- ORM works with: JDBC, ODBC, PostgreSQL native, MySQL native, SQLite native, DuckDB native.
- ORM does **NOT** work with: MongoDB (mongoc), Cassandra (apacheCassandra), or Neo4j.

## Decision Framework

| Scenario | Use ORM | Use sqlread/sqlwrite |
|----------|---------|---------------------|
| Object identity and business logic needed | Yes | No |
| Class-based type safety required | Yes | No |
| Domain validation on read/write | Yes | No |
| Ad-hoc queries or exploration | No | Yes |
| Bulk operations (thousands of rows) | No | Yes (faster) |
| No object mapping needed | No | Yes |

## Core Concepts

### Defining a Mappable Class

A Mappable class maps MATLAB properties to database columns:

```matlab
classdef (TableName = "employees") Employee < database.orm.mixin.Mappable

    properties (PrimaryKey, ColumnName = "EmployeeID")
        ID int32
    end

    properties
        Name string
        Department string
        Salary double
    end

    properties (ColumnName = "HireDate", ColumnType = "date")
        StartDate datetime
    end

    methods
        function obj = Employee(id, name, dept, salary, startDate)
            if nargin ~= 0
                obj.ID = id;
                obj.Name = name;
                obj.Department = dept;
                obj.Salary = salary;
                obj.StartDate = startDate;
            end
        end

        function obj = promote(obj, raise)
            obj.Salary = obj.Salary + raise;
        end
    end
end
```

### Property Attributes Reference

| Attribute | Purpose | Example |
|-----------|---------|---------|
| `PrimaryKey` | Marks property as the primary key (required) | `properties (PrimaryKey)` |
| `ColumnName` | Maps property to a differently-named column | `properties (ColumnName = "EmpID")` |
| `ColumnType` | Specifies the database column type | `properties (ColumnType = "date")` |
| `TableName` | Class-level attribute for the target table name | `classdef (TableName = "employees")` |

### Common Mistakes

```matlab
% INCORRECT — class without PrimaryKey (ormwrite will error)
classdef (TableName = "employees") Employee < database.orm.mixin.Mappable
    properties
        Name string
        Dept string
    end
end
% ormwrite(conn, emp) → Error: No PrimaryKey defined

% CORRECT — PrimaryKey is required for ORM operations
classdef (TableName = "employees") Employee < database.orm.mixin.Mappable
    properties(PrimaryKey)
        EmployeeID int32
    end
    properties
        Name string
        Dept string
    end
end

% INCORRECT — class not inheriting Mappable
classdef Employee
    properties(PrimaryKey)
        EmployeeID int32
    end
end
% ormread(conn, "Employee") → Error! Not a Mappable class.

% CORRECT — must inherit from database.orm.mixin.Mappable
classdef Employee < database.orm.mixin.Mappable
    properties(PrimaryKey)
        EmployeeID int32
    end
end

% INCORRECT — constructor without nargin==0 guard
classdef (TableName = "emp") Employee < database.orm.mixin.Mappable
    methods
        function obj = Employee(id, name)
            obj.EmployeeID = id;
            obj.Name = name;
        end
    end
end
% ormread will fail because ORM needs to construct empty objects

% CORRECT — nargin==0 guard allows ORM to construct empty objects
classdef (TableName = "emp") Employee < database.orm.mixin.Mappable
    methods
        function obj = Employee(id, name)
            if nargin == 0
                return;
            end
            obj.EmployeeID = id;
            obj.Name = name;
        end
    end
end
```

### Writing Objects with `ormwrite`

```matlab
% Create and insert a single object
emp = Employee(1, "Alice", "Engineering", 95000, datetime(2023,3,15));
ormwrite(conn, emp);

% Create and insert an array of objects
emps = [Employee(2, "Bob", "Sales", 72000, datetime(2023,6,1)), ...
        Employee(3, "Carol", "Engineering", 105000, datetime(2022,1,10))];
ormwrite(conn, emps);
```

### Reading Objects with `ormread`

```matlab
% Read all objects
allEmployees = ormread(conn, "Employee");

% Read with a row filter
rf = rowfilter("Salary");
highEarners = ormread(conn, "Employee", RowFilter=rf.Salary > 90000);

% Refresh an existing object from database
emp = ormread(conn, emp);
```

### Updating Objects with `ormupdate`

```matlab
% Modify object in MATLAB
emp = promote(emp, 5000);

% Push changes to database
ormupdate(conn, emp);
```

### Deleting Records

ORM does not provide an `ormdelete` function. Use `execute` for deletion:

```matlab
execute(conn, "DELETE FROM employees WHERE EmployeeID = 42");
```

### Error Handling

```matlab
try
    ormwrite(conn, employeeObj);
catch ME
    if contains(ME.message, "UNIQUE") || contains(ME.message, "primary key")
        warning("Duplicate primary key. Use ormupdate instead.");
        ormupdate(conn, employeeObj);
    else
        rethrow(ME);
    end
end
```

### Generating SQL from Class Definition

```matlab
% View the CREATE TABLE SQL that corresponds to the class
sql = orm2sql(conn, "Employee");
disp(sql);
% Output: "CREATE TABLE employees (EmployeeID integer, Name text, ...)"
```

## Complete Examples

### Example 1: Full ORM Workflow — Define, Write, Read, Update

**Step 1: Define the class (save as `Product.m`):**

```matlab
classdef (TableName = "products") Product < database.orm.mixin.Mappable

    properties (PrimaryKey, ColumnName = "ProductNumber")
        ID int32
    end

    properties
        Name string
        Description string
        Quantity int32
    end

    properties (ColumnName = "UnitCost")
        CostPerItem double
    end

    properties (ColumnType = "date")
        InventoryDate datetime
    end

    methods
        function obj = Product(id, name, desc, cost, qty, invDate)
            if nargin ~= 0
                obj.ID = id;
                obj.Name = name;
                obj.Description = desc;
                obj.CostPerItem = cost;
                obj.Quantity = qty;
                obj.InventoryDate = invDate;
            end
        end

        function obj = restock(obj, amount)
            obj.Quantity = obj.Quantity + amount;
            obj.InventoryDate = datetime("today");
        end
    end
end
```

**Step 2: Use ORM operations (save as `ormWorkflow.m`):**

(Uses the `Product` class defined above.)

```matlab
% Connect to SQLite (no driver needed)
conn = sqlite("inventory.db", "create");

% Create and insert products
p1 = Product(1, "Widget", "Small widget", 9.99, 100, datetime(2024,1,1));
p2 = Product(2, "Gadget", "Large gadget", 29.99, 50, datetime(2024,1,1));
ormwrite(conn, [p1, p2]);

% Read all products back as objects
allProducts = ormread(conn, "Product");
disp(allProducts(1));

% Filter: find products under $15
rf = rowfilter("CostPerItem");
cheapProducts = ormread(conn, "Product", RowFilter=rf.CostPerItem < 15);

% Update: restock a product
cheapProducts(1) = restock(cheapProducts(1), 200);
ormupdate(conn, cheapProducts(1));

% Verify
refreshed = ormread(conn, cheapProducts(1));
disp(refreshed.Quantity); % Should be 300

close(conn);
```

## Best Practices

- **ALWAYS** define Mappable classes in their own `.m` file — one class per file (MATLAB requirement).
- **ALWAYS** include a constructor that handles `nargin == 0` (allows preallocation).
- **ALWAYS** mark exactly one property block with `PrimaryKey`.
- Use `ColumnName` when the MATLAB property name differs from the database column name.
- Use `ColumnType` for types that need explicit mapping (e.g., `"date"` for datetime).
- Use `ormread` with `RowFilter` to import only the objects you need — pushes filter to database.
- Use `orm2sql` to verify your class mapping matches the expected database schema before writing.
- Modify objects in MATLAB using class methods, then push changes with `ormupdate`.

## Common Patterns

### Pattern 1: Define-Write-Read-Update

```matlab
% Define class → Product.m
p = Product(1, "Item", "Desc", 9.99, 10, datetime("today"));
ormwrite(conn, p);
p = ormread(conn, p);        % Refresh from DB
p = restock(p, 50);          % Modify in MATLAB
ormupdate(conn, p);          % Push to DB
```

### Pattern 2: Filtered Read with Business Logic

```matlab
rf = rowfilter("Quantity");
lowStock = ormread(conn, "Product", RowFilter=rf.Quantity < 10);
for i = 1:numel(lowStock)
    lowStock(i) = restock(lowStock(i), 100);
    ormupdate(conn, lowStock(i));
end
```

### Pattern 3: Schema Verification

```matlab
sql = orm2sql(conn, "MyClass");
disp(sql); % Verify CREATE TABLE matches expectations
```

## Checklist

Before finalizing, verify:
- [ ] Mappable class inherits from `database.orm.mixin.Mappable`
- [ ] Class has `TableName` attribute on `classdef`
- [ ] At least one property block has `PrimaryKey` attribute
- [ ] Constructor handles `nargin == 0` for preallocation
- [ ] Class saved in its own `.m` file
- [ ] Connection established and verified (`isopen(conn)`)
- [ ] Connection type is supported (JDBC, ODBC, MySQL/PostgreSQL/SQLite/DuckDB native)
- [ ] R2023b or later (ORM not available in earlier releases)

## Troubleshooting

**Issue**: `ormwrite` fails with "class is not Mappable"
- **Solution**: Ensure the class inherits from `database.orm.mixin.Mappable`. The class definition must include `< database.orm.mixin.Mappable`.

**Issue**: `ormread` returns empty array
- **Solution**: Verify the table exists in the database using `sqlfind(conn, tableName)`. Verify the class `TableName` attribute matches the actual table name.

**Issue**: `ormupdate` doesn't change database values
- **Solution**: `ormupdate` matches rows by primary key. Verify the object's primary key property value exists in the database. Use `ormread` to refresh and check.

**Issue**: Property-to-column mapping is incorrect
- **Solution**: Use `orm2sql(conn, "ClassName")` to inspect the generated SQL. Verify `ColumnName` and `ColumnType` attributes match the database schema.

**Issue**: ORM functions not found ("Undefined function")
- **Solution**: ORM requires R2023b or later. Check your release with `ver('database')`. For older releases, use `sqlread`/`sqlwrite` instead.


----

Copyright 2026 The MathWorks, Inc.

----

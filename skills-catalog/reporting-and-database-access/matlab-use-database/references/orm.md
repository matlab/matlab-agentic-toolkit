# ORM — Object Relational Mapping (R2023b+)

## Defining a Mappable Class

```matlab
classdef Employee < database.orm.mixin.Mappable

    properties (PrimaryKey)
        EmployeeID int32
    end

    properties
        Name string
        Department string
        Salary double
    end

    properties (ColumnType = "date")
        HireDate datetime
    end

    methods
        function obj = Employee(id, name, dept, salary, hireDate)
            if nargin == 0
                return;
            end
            obj.EmployeeID = id;
            obj.Name = name;
            obj.Department = dept;
            obj.Salary = salary;
            obj.HireDate = hireDate;
        end

        function obj = promote(obj, raise)
            obj.Salary = obj.Salary + raise;
        end
    end
end
```

## Requirements

- Inherit from `database.orm.mixin.Mappable`
- Mark at least one property block `(PrimaryKey)`
- Constructor must handle `nargin == 0` (ORM constructs empty objects internally)
- Save class in its own `.m` file (one class per file)
- R2023b or later

## Optional Property Attributes

| Attribute | Purpose | Example |
|-----------|---------|---------|
| `PrimaryKey` | Marks property as the primary key (required) | `properties (PrimaryKey)` |
| `ColumnName` | Maps property to a differently-named column | `properties (ColumnName = "EmpID")` |
| `ColumnType` | Specifies the database column type | `properties (ColumnType = "date")` |
| `TableName` | Class-level: maps class to a differently-named table | `classdef (TableName = "emp") Employee` |

`TableName` defaults to the class name — only specify it when the database table name differs.

## CRUD Operations

### Write

```matlab
emp = Employee(1, "Alice", "Engineering", 95000, datetime(2024,3,15));
ormwrite(conn, emp);

% Write an array of objects
emps = [Employee(2, "Bob", "Sales", 72000, datetime(2023,6,1)), ...
        Employee(3, "Carol", "Engineering", 105000, datetime(2022,1,10))];
ormwrite(conn, emps);
```

### Read

```matlab
% Read all objects
allEmployees = ormread(conn, "Employee");

% Read with a filter
rf = rowfilter("Salary");
highEarners = ormread(conn, "Employee", RowFilter=rf.Salary > 90000);

% Refresh an existing object from database
emp = ormread(conn, emp);
```

### Update

```matlab
emp = promote(emp, 5000);
ormupdate(conn, emp);
```

### Delete

ORM does not provide `ormdelete`. Use `execute` for deletion:

```matlab
execute(conn, "DELETE FROM Employee WHERE EmployeeID = 42");
```

### Generate SQL from Class

```matlab
sql = orm2sql(conn, "Employee");
disp(sql);
```

## When to Use ORM vs sqlread/sqlwrite

| Scenario | Use ORM | Use sqlread/sqlwrite |
|----------|---------|---------------------|
| Object identity and business logic | Yes | No |
| Class-based type safety | Yes | No |
| Domain validation on read/write | Yes | No |
| Ad-hoc queries or exploration | No | Yes |
| Bulk operations (thousands of rows) | No | Yes (faster) |
| No object mapping needed | No | Yes |

## Error Handling

```matlab
try
    ormwrite(conn, emp);
catch ME
    if contains(ME.message, "UNIQUE") || contains(ME.message, "primary key")
        warning("Duplicate key. Using ormupdate instead.");
        ormupdate(conn, emp);
    else
        rethrow(ME);
    end
end
```

## Supported Connections

ORM works with: JDBC, ODBC, PostgreSQL native, MySQL native, SQLite native, DuckDB native.

ORM does NOT work with: MongoDB, Cassandra, Neo4j.

## Gotchas

- `ormwrite` errors on duplicate primary keys — use try/catch to fall back to `ormupdate`
- `ormupdate` matches rows by primary key — the object's PK must exist in the database
- `ormread` returns an empty array if no rows match — check with `isempty`
- Use `orm2sql` to verify the class mapping matches your database schema before writing
- ORM is slower than `sqlwrite`/`sqlread` for bulk operations — use functional CRUD for large batches

----

Copyright 2026 The MathWorks, Inc.

----

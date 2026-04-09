# Fixtures

## Setup/Teardown Hierarchy

ClassSetup → (MethodSetup → Test → MethodTeardown) × N → ClassTeardown

**Prefer `addTeardown`** over `TestMethodTeardown`/`TestClassTeardown` blocks. Reserve those blocks for unconditional cleanup unrelated to a specific resource.

## addTeardown

Call immediately after creating an artifact or changing state. Runs in LIFO order even if setup fails partway through.

```matlab
function testWithFile(testCase)
    filename = tempname;
    fid = fopen(filename, 'w');
    testCase.addTeardown(@() fclose(fid));
    testCase.addTeardown(@() delete(filename));
    % ... use file ...
end
```

## Built-in Fixtures

| Fixture | Constructor | Purpose |
|---|---|---|
| `WorkingFolderFixture` | `()` or `('WithSuffix', name)` | Temp working folder |
| `PathFixture` | `(folderPath)` or `(folderPath, IncludingSubfolders=true)` | Add folder to MATLAB path |
| `CurrentFolderFixture` | `(folderPath)` | Change current folder |
| `EnvironmentVariableFixture` | `(varName, value)` | Set environment variable |
| `SuppressedWarningsFixture` | `(warningID)` | Suppress specific warning |

## Choosing Scope

Use the narrowest scope that works. Only promote to `SharedTestFixtures` when multiple test classes need the same expensive resource.

| Scope | Where |
|---|---|
| Across test classes (DB, server) | `SharedTestFixtures` class attribute |
| One class (path, large data) | `applyFixture` / `addTeardown` in `TestClassSetup` |
| Each method | `applyFixture` / `addTeardown` in `TestMethodSetup` |
| Single test (temp file, figure) | `applyFixture` / `addTeardown` in test method |

## Custom Fixtures

```matlab
classdef DatabaseFixture < matlab.unittest.fixtures.Fixture

    properties
        Connection
    end

    methods
        function setup(fixture)
            fixture.Connection = database('testdb', 'user', 'pass');
            fixture.addTeardown(@() close(fixture.Connection));
        end
    end
end

% If the fixture accepts configuration, override isCompatible so the
% framework knows when two instances can share state.

% Usage as shared fixture:
classdef (SharedTestFixtures = {DatabaseFixture}) ...
    DatabaseTest < matlab.unittest.TestCase

    methods (Test)
        function testQuery(testCase)
            fixture = testCase.getSharedTestFixtures();
            conn = fixture{1}.Connection;
            result = fetch(conn, 'SELECT * FROM users');
            testCase.verifyNotEmpty(result);
        end
    end
end
```

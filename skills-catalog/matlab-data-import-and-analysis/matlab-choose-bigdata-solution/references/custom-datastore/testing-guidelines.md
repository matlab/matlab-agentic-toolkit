# Custom Datastore Testing Guidelines

Write and run these tests after implementing a custom datastore. Tests verify
the datastore integrates correctly with the MATLAB ecosystem.

Reference: https://www.mathworks.com/help/matlab/import_export/testing-guidelines-for-custom-datastores.html

## Test Class Template

```matlab
classdef tMyDatastore < matlab.unittest.TestCase

    properties (Constant)
        DataPath = "path/to/test/data"
    end

    methods (Test)
        function testConstruction(testCase)
            ds = MyDatastore(testCase.DataPath);
            testCase.verifyClass(ds, "MyDatastore");
            testCase.verifyTrue(hasdata(ds));
        end

        function testReadReturnsData(testCase)
            ds = MyDatastore(testCase.DataPath);
            [data, info] = read(ds);
            testCase.verifyNotEmpty(data);
            testCase.verifyTrue(isstruct(info));
        end

        function testReadallReturnsAllData(testCase)
            ds = MyDatastore(testCase.DataPath);
            allData = readall(ds);
            testCase.verifyNotEmpty(allData);
            testCase.verifyTrue(hasdata(ds), ...
                "readall must not advance the original datastore.");
        end

        function testPreviewDoesNotAdvancePosition(testCase)
            ds = MyDatastore(testCase.DataPath);
            preview(ds);
            testCase.verifyTrue(hasdata(ds), ...
                "preview must not advance the original datastore.");
            [data, ~] = read(ds);
            testCase.verifyNotEmpty(data);
        end

        function testResetAfterPartialRead(testCase)
            ds = MyDatastore(testCase.DataPath);
            read(ds);
            read(ds);
            reset(ds);
            testCase.verifyTrue(hasdata(ds));
        end

        function testHasdataExhaustion(testCase)
            ds = MyDatastore(testCase.DataPath);
            while hasdata(ds)
                read(ds);
            end
            testCase.verifyFalse(hasdata(ds));
        end

        function testProgressRange(testCase)
            ds = MyDatastore(testCase.DataPath);
            testCase.verifyEqual(progress(ds), 0);
            while hasdata(ds)
                read(ds);
                p = progress(ds);
                testCase.verifyGreaterThanOrEqual(p, 0);
                testCase.verifyLessThanOrEqual(p, 1);
            end
            testCase.verifyEqual(progress(ds), 1);
        end
    end
end
```

## Partition Tests (if Partitionable)

```matlab
        function testPartitionSumsToWhole(testCase)
            ds = MyDatastore(testCase.DataPath);
            allData = readall(ds);
            numParts = 3;

            partData = [];
            for idx = 1:numParts
                subds = partition(ds, numParts, idx);
                partData = [partData; readall(subds)]; %#ok<AGROW>
            end
            testCase.verifyEqual(numel(partData), numel(allData));
        end

        function testPartitionDoesNotAffectOriginal(testCase)
            ds = MyDatastore(testCase.DataPath);
            partition(ds, 3, 1);
            testCase.verifyTrue(hasdata(ds));
            allData = readall(ds);
            testCase.verifyNotEmpty(allData);
        end

        function testTallConstruction(testCase)
            ds = MyDatastore(testCase.DataPath);
            t = tall(ds);
            testCase.verifyClass(t, "tall");
        end
```

## Shuffle Tests (if Shuffleable)

```matlab
        function testShuffleReturnsNewDatastore(testCase)
            ds = MyDatastore(testCase.DataPath);
            dsShuffled = shuffle(ds);
            testCase.verifyClass(dsShuffled, "MyDatastore");
            testCase.verifyTrue(hasdata(dsShuffled));
        end

        function testShuffleDoesNotAffectOriginal(testCase)
            ds = MyDatastore(testCase.DataPath);
            shuffle(ds);
            testCase.verifyTrue(hasdata(ds));
        end
```

## What Each Test Verifies

| Test | What it catches |
|------|----------------|
| readall doesn't advance position | Missing or broken `copyElement` |
| preview doesn't advance position | Missing or broken `copyElement` |
| partition sums to whole | Incorrect `partition`/`maxpartitions` delegation |
| partition doesn't affect original | `partition` mutates instead of copying |
| tall construction | Missing `Partitionable` mixin or broken `partition` |
| progress range | Incorrect progress calculation |
| hasdata exhaustion | Broken iteration logic in `read`/`hasdata` |

----

Copyright 2026 The MathWorks, Inc.

----

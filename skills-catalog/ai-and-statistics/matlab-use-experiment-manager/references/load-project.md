# Operation: Load Project

> Shared rules, setup, the Modification Flow, validation, and API are in
> [common.md](common.md). Read it first.

Open a project in Experiment Manager and list its experiments.

No confirmation needed. Open project, list experiments, offer actions.

```matlab
clear classes
result = manageExperimentHelpers.loadProject('<projectPath>'); disp(result);
```

Then list:
```matlab
result = manageExperimentHelpers.listExperiments('<projectPath>'); disp(result);
```

After listing, offer the user follow-up actions ([create](create.md), [update](update.md),
[rename](rename.md), [duplicate](duplicate.md), [delete](delete.md)).

----

Copyright 2026 The MathWorks, Inc.

----

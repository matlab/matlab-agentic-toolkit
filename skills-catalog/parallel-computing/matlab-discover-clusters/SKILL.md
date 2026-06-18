---
name: matlab-discover-clusters
description: >
  Discover MATLAB Parallel Computing Toolbox clusters on the network and in
  the cloud, and manage their profiles — list, inspect, import, export, set
  default, validate, and delete. Use whenever the user asks what parallel
  computing resources, clusters, or cluster profiles they have or can use —
  e.g. "what parallel resources do I have", "show my cluster profiles",
  "list clusters", "what clusters can I run on", "where can I submit jobs"
  — and for any work with parcluster, parallel.listProfiles,
  parallel.defaultProfile, MJS / Generic / HPC Server / MJSComputeCloud
  clusters, .mlsettings files, or profile validation. Does NOT cover job
  submission, parpool, or parfor.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Discover MATLAB Clusters

A cluster profile is a saved set of properties (name, type, host, number of
workers, scheduler arguments) that lets MATLAB connect to a compute
resource. This skill covers the full profile lifecycle: discovering
clusters on the network, importing shared profiles, setting a default,
validating, and deleting.

## When to Use

- The user asks what parallel computing resources, clusters, or queues are available to them.
- The user wants to find clusters they can submit jobs to.
- The user has an `.mlsettings` profile file from an admin and needs to import it.
- The user wants to list, inspect, set the default for, validate, or delete a cluster profile.
- The user wants to export a cluster profile to share with colleagues.
- The user is calling `parcluster` or `parpool` and wants to know which resource it will use or which profile name to pass.

## When NOT to Use

- **Submitting jobs** (`batch`, `createJob`, `submit`, `parfeval`) — this skill stops at "the cluster is ready to use."
- **Pool lifecycle beyond profile selection** — `parpool` startup/shutdown, `gcp`, and pool destruction are separate concerns. Identifying which profile to pass to `parpool` is in scope.
- **GPU or parfor workflows** — covered by separate skills.

## Workflow

1. **List existing profiles** with `parallel.listProfiles` to see what is already configured.
2. **If the user is missing an expected resource or wants to search for additional clusters, discover them** with the bundled `discoverClusters` script (network and cloud).
3. **Add the cluster** as a profile — either by creating it from a discovered cluster (`saveAsProfile`) or importing a shared `.mlsettings` (`parallel.importProfile`).
4. **Set the default profile** with `parallel.defaultProfile` if appropriate.
5. **Validate** with `parallel.validateProfile` (R2025a+) or `validate(c)` on the cluster object before relying on it. Pass `NumWorkersToUse` (e.g. 2) or confirm with the user first — leaving it unset runs validation on the cluster's full worker count.
6. **Delete obsolete profiles** with `parallel.deleteProfile` (R2026a+) — confirm with the user first; deletion is irreversible.

After every step, verify before moving on — show the updated profile list, confirm the type/host/worker count, or check the validation report.

## Key Functions

| Function | Purpose | Available From |
|---|---|---|
| `parallel.listProfiles` | List profile names and the default | R2022b |
| `parallel.defaultProfile` | Get or set the default profile | R2022b |
| `parallel.importProfile` | Import a profile from `.mlsettings` | R2022b |
| `parallel.exportProfile` | Export a profile to `.mlsettings` | R2022b |
| `parcluster` | Construct a cluster object from a profile | R2022b |
| `cluster.saveAsProfile` | Save a cluster object as a new profile | R2022b |
| `parallel.validateProfile` | Validate a profile (standalone function) | R2025a |
| `validate(cluster)` | Validate via the cluster object | R2026a |
| `parallel.deleteProfile` | Delete a profile by name | R2026a |
| `discoverClusters` | Bundled with this skill — discover MJS / Generic / HPCServer / MJSComputeCloud | scripts/discoverClusters.p |
| `cluster.Type` | Property: `"Local"`, `"Threads"`, `"MJS"`, `"MJSComputeCloud"`, `"Slurm"`, `"PBSPro"`, `"LSF"`, `"HPCServer"`, `"Generic"` | R2022b |

For features above the R2022b floor, use the fallback noted in the patterns and announce the release gap to the user.

## Patterns

### Listing and inspecting profiles

Use `parallel.listProfiles` to get profile names and `parallel.defaultProfile()` (no args) to read the default. To inspect a profile, call `parcluster(name)` and read `cluster.Type` (string), `cluster.NumWorkers`, and (where applicable) `cluster.Host`. Do **not** parse `class(c)` — `Type` is the supported public property.

**`parcluster(name)` makes a network round-trip for MJS profiles** to fetch live properties from the scheduler. An unreachable or release-mismatched MJS will throw "Unable to connect to MATLAB Job Scheduler" — that is expected behavior, not a code bug. Always wrap `parcluster` in `try/catch` when iterating profiles, and report unreachable profiles distinctly from missing ones.

The `Threads` profile cannot be returned by `parcluster` at all — skip it explicitly.

Compare profile names with `strcmp` (or two `string`s), not `==`: comparing two `char` arrays with `==` does element-wise character comparison and errors when lengths differ.

```matlab
profiles = parallel.listProfiles;
defaultName = parallel.defaultProfile();

fprintf("\n%-25s %-10s %-10s  %s\n", "Profile", "Type", "Workers", "Default");
fprintf("%s\n", repmat('-', 1, 70));
for k = 1:numel(profiles)
    name = profiles{k};
    marker = "";
    if strcmp(name, defaultName); marker = "(default)"; end
    if strcmp(name, "Threads")
        fprintf("%-25s %-10s %-10s  %s\n", name, "Threads", "n/a", marker);
        continue
    end
    try
        c = parcluster(name);
        fprintf("%-25s %-10s %-10d  %s\n", name, string(c.Type), c.NumWorkers, marker);
    catch
        fprintf("%-25s %-10s %-10s  %s\n", name, "?", "?", marker + " unreachable");
    end
end
```

### Discover MJS, Generic, HPCServer, and MJSComputeCloud clusters

`discoverClusters` lives in this skill's `scripts/` folder. Add it to the path before first use:

```matlab
addpath(fullfile(skillRoot, "scripts"));   % skillRoot = directory containing this SKILL.md
```

The bundled `discoverClusters` function wraps the same internal discovery infrastructure used by the MATLAB Cluster Profile Manager UI. It returns a struct array with one entry per discovered cluster:

```matlab
clusters = discoverClusters();                                  % all scopes, 30s timeout
% Other forms:
%   discoverClusters(Scope="network", TimeoutSeconds=15)
%   discoverClusters(Scope="cloud")
```

Each entry has fields: `Type`, `Name`, `Host`, `NumWorkers`, `MatlabRelease`, `IsCompatible`, `CorrespondingProfiles`, and `Properties` (a struct holding every discovered property, indexed by name). For Generic clusters, `Properties` contains `PluginScriptsLocation`, `JobStorageLocation`, `AdditionalProperties`, etc. — everything needed to construct the cluster.

Display findings concisely and call out `IsCompatible == false` (release mismatch) and any cluster that already has `CorrespondingProfiles` set (already imported).

```matlab
clusters = discoverClusters();

if isempty(clusters)
    disp("No clusters discovered.");
    return
end

fprintf("Discovered %d clusters:\n", numel(clusters));
for k = 1:numel(clusters)
    profileNote = "no profile";
    if ~isempty(clusters(k).CorrespondingProfiles)
        profileNote = "profile: " + strjoin(string(clusters(k).CorrespondingProfiles), ", ");
    end
    compatNote = "compatible";
    if ~clusters(k).IsCompatible
        compatNote = "INCOMPATIBLE (" + clusters(k).MatlabRelease + ")";
    end
    fprintf("  [%d] %s '%s' on %s — %s, %s\n", ...
        k, clusters(k).Type, clusters(k).Name, clusters(k).Host, ...
        compatNote, profileNote);
end
```

**Do not** fall back to platform-specific CLI tools (`nodestatus`, `mjs status`) or hallucinated APIs (`parallel.cluster.find`, `parallel.cluster.discover`, `findResource`). Use `discoverClusters` — these alternatives either do not exist or bypass the supported discovery infrastructure.

If `discoverClusters` returns nothing, that does **not** mean the user has no cluster — not every Generic cluster is configured with a discoverable `.conf` file. Suggest the user contact their cluster administrator for a `.mlsettings` profile to import.

### Save a discovered MJS cluster as a profile

After discovery, construct an MJS cluster with `parallel.cluster.MJS(Name=, Host=)` and call `saveAsProfile(name)`. `saveAsProfile` is **void** — do not assign its return value.

`parallel.cluster.MJS(Name=,Host=)` connects to the MJS lookup service to validate the cluster and fetch live properties — it is not a cheap object construction step. If the cluster is unreachable it throws "Unable to connect to MATLAB Job Scheduler".

**MJS clusters can prompt for credentials in a MATLAB dialog** when the client connects, in two situations: the cluster has a non-zero `SecurityLevel`, or the cluster requires online licensing. The dialog blocks `parallel.cluster.MJS(...)` until the user responds; if it is dismissed without entering credentials, the call errors with "Operation aborted because no credentials were entered for user ...". Before running any code that constructs an MJS cluster object, **warn the user explicitly**: "About to connect to MJS cluster `<Name>` — switch to MATLAB now; a credentials dialog may appear and will block this command until you respond." Do not issue this warning when no MJS clusters were discovered or are being acted on — Generic, HPCServer, Local, and Threads profiles do not authenticate this way.

Always filter discovered clusters by `Type=="MJS"` before this pattern — discovery returns Generic / HPCServer / MJSComputeCloud entries too, and `parallel.cluster.MJS` against a Slurm headnode produces a confusing connection error.

```matlab
clusters = discoverClusters(Scope="network");

% Pick the first compatible MJS without an existing profile.
isMJS = string({clusters.Type}) == "MJS";
target = clusters(find(isMJS & [clusters.IsCompatible] & ...
    cellfun(@isempty, {clusters.CorrespondingProfiles}), 1));

c = parallel.cluster.MJS(Name=target.Name, Host=target.Host);
c.saveAsProfile(target.Name);
fprintf("Saved profile '%s'\n", target.Name);
```

Before calling `saveAsProfile(name)`, check `parallel.listProfiles` — if `name` is already taken, ask the user for an alternative (e.g. include the host) rather than silently overwriting or producing a duplicate.

### Save a discovered Generic (Slurm/PBS/LSF) cluster as a profile

Generic clusters surface through filesystem-based discovery — admins ship a `.conf` file describing the scheduler, and discovery picks it up from `matlabroot/toolbox/parallel/user/clusterprofiles`, `$MATLAB_CLUSTER_PROFILES_LOCATION`, `$HOME`, or `$HOME/Downloads`. The `Properties` struct on the discovered entry holds everything the `parallel.cluster.Generic` object needs.

`parallel.cluster.Generic` has **no `Name` property** — the profile name is passed to `saveAsProfile`.

```matlab
clusters = discoverClusters();
target = clusters(find(string({clusters.Type}) == "Generic" & ...
    [clusters.IsCompatible], 1));
p = target.Properties;

c = parallel.cluster.Generic;
c.NumWorkers = double(p.NumWorkers);
c.JobStorageLocation = char(p.JobStorageLocation);
c.PluginScriptsLocation = char(p.PluginScriptsLocation);
c.ClusterMatlabRoot = char(p.ClusterMatlabRoot);
c.OperatingSystem = char(p.OperatingSystem);
c.HasSharedFilesystem = logical(p.HasSharedFilesystem);
c.RequiresOnlineLicensing = logical(p.RequiresOnlineLicensing);

if isfield(p, 'AdditionalProperties')
    apFields = fieldnames(p.AdditionalProperties);
    for k = 1:numel(apFields)
        c.AdditionalProperties.(apFields{k}) = p.AdditionalProperties.(apFields{k});
    end
end

c.saveAsProfile(char(p.Name));
```

The same pattern works for any third-party scheduler discovered via `.conf` (Slurm, PBS Pro, LSF, Grid Engine, HTCondor) — the Type stays `Generic`; the scheduler is identified by the contents of `PluginScriptsLocation`.

### Import a shared profile, set as default, validate

```matlab
profileName = parallel.importProfile("team_cluster.mlsettings");
parallel.defaultProfile(profileName);
parallel.validateProfile(profileName);
```

`parallel.importProfile` returns the imported profile's name. `parallel.defaultProfile` with one argument sets the default and returns nothing useful — call `parallel.defaultProfile()` with no arguments to read it back.

### Validate a cluster (with stages)

Use `parallel.validateProfile` (R2025a+). It accepts `StagesToRun`, `StagesToSkip`, `NumWorkersToUse`, and `ReportFile` name-value arguments. There are no output arguments — validation prints a report and writes to `ReportFile` if requested.

Always pass `NumWorkersToUse` for newly discovered or shared clusters — without it, validation runs on the full worker count, which is rarely what the user wants and on a shared cluster (e.g. an `MJSComputeCloud` or a site MJS) consumes resources other people may be waiting for. Confirm with the user before validating on the full cluster.

```matlab
parallel.validateProfile("myProfile", ...
    StagesToRun=["parcluster", "job", "parpool"], ...
    NumWorkersToUse=4, ...
    ReportFile="validation-report.txt");
```

Valid stages (for most cluster types): `"parcluster"`, `"job"`, `"spmd-job"`, `"pool-job"`, `"parpool"`. The exact set varies by cluster `Type` — Threads-only profiles validate fewer stages.

On R2026a+, the same options are also exposed on the cluster object via `validate(cluster)`:

```matlab
c = parcluster("myProfile");
validate(c, StagesToRun=["parcluster", "job", "parpool"]);
```

For releases below R2025a, there is no scriptable validation API — direct the user to the Cluster Profile Manager UI (`Home > Parallel > Create and Manage Clusters`) and announce the release gap.

### Delete a profile

Always confirm with the user before deleting — `parallel.deleteProfile` is irreversible. List profiles first and read back the deletion target.

```matlab
parallel.deleteProfile("oldCluster");
```

For releases below R2026a, there is no public function for this. Direct the user to the Cluster Profile Manager UI (`Home > Parallel > Create and Manage Clusters` or `parallel.gui.ProfileManager.start`).

## Conventions

- **Always** read the profile list before mutating: `parallel.listProfiles` to see what exists, then `parallel.defaultProfile()` (no args) to see the default.
- **Always** verify `IsCompatible` before saving a discovered cluster as a profile — release mismatches will fail at job submit, not at profile creation.
- **Always** use `cluster.Type` to identify cluster kind — never `class(c)`.
- **Always** wrap `parcluster(name)` in `try/catch` when iterating profiles — for MJS profiles it makes a network round-trip that fails on unreachable or release-mismatched servers.
- **Always** compare profile names with `strcmp` (or two `string`s), not `==`. `parallel.listProfiles` returns a cell array of `char`, and `==` between two `char` arrays of different lengths errors.
- **Always** cap `NumWorkersToUse` (a small number like 2 is fine) when validating a freshly discovered or shared cluster, or confirm the worker count with the user first — leaving it unset runs validation on the cluster's full worker count.
- **Always** confirm with the user before deleting a profile — `parallel.deleteProfile` is irreversible.
- **Always** check `parallel.listProfiles` before calling `saveAsProfile(name)`. If `name` is already taken, ask the user for an alternative rather than overwriting or producing a duplicate.
- **Prefer** `parallel.listProfiles` over the deprecated `parallel.clusterProfiles`.
- **Prefer** `parallel.defaultProfile` over the deprecated `parallel.defaultClusterProfile`.
- **Prefer** `parallel.validateProfile` (R2025a+) — it does not require constructing the cluster object first. `validate(cluster)` exposes the same options but only landed in R2026a; on R2025a it is the standalone function or the GUI.

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---|---|---|
| `parallel.clusterProfiles` | Deprecated since R2022b (still works, not recommended). | `parallel.listProfiles` |
| `parallel.defaultClusterProfile(name)` | Deprecated since R2022b. | `parallel.defaultProfile(name)` |
| `class(c)` to identify cluster type | Returns the MATLAB class name (`'parallel.cluster.Local'`), not the profile type. | `c.Type` (returns `"Local"`, `"MJS"`, ...) |
| `parallel.cluster.find`, `parallel.cluster.discover`, `findResource` | None of these exist. | `discoverClusters` (bundled with this skill) |
| `nodestatus` via `system()` | CLI tool, platform-specific, not supported as an API. | `discoverClusters` |
| `parallel.cluster.removeProfile`, `parallel.removeProfile` | Hallucinated names — neither exists. | `parallel.deleteProfile` (R2026a+) |
| `[ok, msg] = validate(c)` | `validate` has no output arguments. | Call `validate(c)` (or `parallel.validateProfile`) and inspect the printed report or `ReportFile`. |
| `name = c.saveAsProfile(name)` | `saveAsProfile` is void — has no output arguments. | Call `c.saveAsProfile(name)` without assigning. |
| Setting `c.Name` on a `parallel.cluster.Generic` | `Generic` has no `Name` property — Name is set when the profile is saved. | Configure properties, then `c.saveAsProfile("<name>")`. |
| Calling `parcluster` on the `Threads` profile | Threads profiles cannot be returned by `parcluster`. | Skip Threads when iterating profiles. |

## Scripts

- [`scripts/discoverClusters.p`](scripts/discoverClusters.p) — discover clusters using the same infrastructure as the Cluster Profile Manager UI. Returns a struct array with `Type`, `Name`, `Host`, `NumWorkers`, `MatlabRelease`, `IsCompatible`, `CorrespondingProfiles`. Name-value options: `Scope` (`"all"`/`"network"`/`"cloud"`, default `"all"`), `TimeoutSeconds` (default 30).

----

Copyright 2026 The MathWorks, Inc.

----

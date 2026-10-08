# mpm API, matlab.toml schema & gotcha catalog

Load when you need exact command syntax, the full `matlab.toml` schema, `matlab.mpm.Package`
properties, or the complete gotcha list. SKILL.md carries the workflow; this file carries the
lookup detail.

## Command reference

### Repository management
```matlab
mpmListRepositories                                          % list configured repositories
mpmAddRepository("File Exchange", matlab.mpm.FileExchange)   % add File Exchange (not default everywhere)
mpmAddRepository("myRepo", "/path/to/repo")                  % add a folder-based repo
mpmRemoveRepository("myRepo")

% Custom/authenticated repo via RepositoryConfiguration (e.g. Artifactory):
jsonFile = "/path/to/repo-config.json";
cfg = matlab.mpm.RepositoryConfiguration(jsonFile);
mpmAddRepository(cfg)
```

#### repo-config.json schema
```json
{
  "schema_version": "1.0.0",
  "repository_configuration": [
    {
      "name": "corp-repo",
      "url": "https://mprs.corp.com:8080/",
      "type": "custom",
      "auth": {
        "type": "token",
        "access_token": "${ARTIFACTORY_TOKEN}"
      }
    }
  ]
}
```
- `schema_version` — always `"1.0.0"`
- `repository_configuration` — array of repository objects
- `name` — display name for `mpmListRepositories`
- `url` — base URL of the Package Repository Service (not raw Artifactory)
- `type` — `"custom"` for service-backed repos
- `auth.type` — `"token"` (bearer token authentication)
- `auth.access_token` — env-var placeholder `"${VAR_NAME}"` resolved at runtime; never a literal token

The `${…}` placeholder is resolved from the user's environment at runtime,
or from a MATLAB secret set with `setSecret` (e.g.
`setSecret("ARTIFACTORY_TOKEN")`). Tokens are never stored in the file itself.
Set the env var in the shell profile (e.g.
`export ARTIFACTORY_TOKEN=<your-read-token>`) or store it as a MATLAB secret
before launching MATLAB.

### Search & discovery
```matlab
mpmsearch("keyword")                                 % free-text KEYWORD search across indexed repos
mpmsearch(Name="Battery")                            % by exact name (case-sensitive)
mpmsearch(PackageSpecifier="Battery@1.1.0")          % by a name@version specifier
mpmsearch(Name="Battery", VersionRange="1.1.0")      % equivalently, split name + version range
mpmsearch(Name="Edge", VersionSelectionPolicy="all") % list all versions, not just newest
mpmsearch(Name="Edge", Repository="myRepo")          % scope to one repo (singular)
```
Three query forms: positional keyword (`mpmsearch("keyword")`), exact `Name=`, and
`PackageSpecifier=` (or `Name=` + `VersionRange=`) for name+version. Do **not** fuse a
version into `Name=` — `Name="Battery@1.1.0"` throws (`Name` must be a valid MATLAB
identifier). Keyword search **is** supported; it just only covers *indexed* repositories.
File Exchange and custom/service-backed (Artifactory/MPRS) repos are not indexed and return
empty with no error, so an empty result never means "not found" — discover File Exchange
submissions through the search endpoint (§ Finding a File Exchange submission), and query a
custom/service-backed repo through its REST API (§ Searching a custom repository) or try
names with `mpminstall(..., DryRun=true, Prompt=false)`.

### Install / uninstall
```matlab
mpminstall("Battery", Prompt=false)
mpminstall("Battery@1.2.0", Prompt=false)             % specify version
mpminstall("Battery@1.2.0@c1438758-4eaf-438f-b04f-6a7279735de5", Prompt=false) % specify version AND id
mpminstall("/path/to/package.mltbx", Prompt=false)    % install a completed MATLAB package
mpminstall("Battery", InstallDependencies=true, Prompt=false)  % default true — transitive resolution
mpminstall("Battery", DryRun=true, Prompt=false)      % preview, commit nothing
mpminstall("Battery", Temporary=true, Prompt=false)   % NOT re-registered on restart; files still land globally
mpminstall("Edge@3.2.10", AllowVersionReplacement=true, Prompt=false)    % replace a same-name/different-id package

mpmuninstall("Battery", Prompt=false)                       % remove package from the MATLAB path; retain files
mpmuninstall("Battery", Delete=true, Prompt=false)           % actually delete files from disk
mpmuninstall("Battery", Force=true, Prompt=false)            % remove even if depended on (may drop unrelated deps)
mpmuninstall("Battery", KeepUnusedDependencies=true, Prompt=false) % default false: orphaned deps auto-removed
```
`mpmuninstall` accepts a `matlab.mpm.Package` array — filter `mpmlist()` and pass the array, don't loop.

### Update
```matlab
mpmupdate("Edge", Prompt=false)                 % newest available version (default range "*")
mpmupdate("Edge", "3.2.10", Prompt=false)       % specify exact version (string, NOT ">=")
mpmupdate("Edge", Force=true, Prompt=false)     % override dependency/version-conflict guards
mpmupdate("Edge", DryRun=true, Prompt=false)    % preview
mpmupdate("Edge", UpdateDependencies="necessary", Prompt=false)  % default — update deps only if required
```
By default `mpmupdate` targets the **newest available version** — the version range defaults to
`"*"` (any version above the installed one); there is no within-major ceiling. The conservative
part is dependency handling: `UpdateDependencies` defaults to `"necessary"`, so transitive deps
move only when the new version requires it. `mpmupdate` refuses to treat a same-name/different-id
package as a version of the installed one — use `AllowVersionReplacement=true` on `mpminstall` to
swap identities.

### List & inspect
```matlab
mpmlist                          % all installed -> matlab.mpm.Package array
mpmlist("Battery")               % one package
mpmlist(Name="Battery")          % name-value form
```

For TOML project creation, package declarations, and project references, use the
`matlab-configure-toml-project` skill. For `.mltbx` authoring, use
`matlab-package-toolbox`.

## matlab.mpm.Package properties

20 public properties:

- Identity: `.Name` `.DisplayName` `.FormerNames` `.Version` `.ID`
- Descriptive: `.Summary` `.Readme` `.Tags` `.ReleaseCompatibility` `.Provider`
- Status (logical): `.Installed` `.DirectlyInstalled`
- Location: `.PackageRoot` · `.Folders` (folders added to the path) · `.Repository`
- Platform: `.SupportedPlatforms`
- Dependencies: `.Dependencies` (each has `.Name` `.VersionRange` `.ResolvedVersion` `.ID`) · `.InstalledDependencies` · `.MissingDependencies` (empty means all resolved)

On packages returned by `mpmsearch` (not yet installed), `.Folders`, `.Readme`, and
`.Dependencies` are empty — full metadata exists only after install. There is no `Temporary`
property, so you cannot tell after the fact which installs were temporary.

Read the property needed for the answer directly. For example, use `.PackageRoot`,
`.Repository`, `.Folders(k).Path`, `.SupportedPlatforms(k).Platform`, or
`.Dependencies(k).ResolvedVersion`. **`string(pkg)` / `fprintf("%s",…)` on a `Package`, or
on an object-valued property (`Provider`, `Dependencies`, `Repository`, `Folders`,
`SupportedPlatforms`), throws** — index to the scalar leaf field first (`.Folders(k).Path`,
not `string(.Folders)`). Scalar `disp(pkg)` works; converting a whole object array does not.

## Finding a File Exchange submission

`mpmsearch` never returns File Exchange (FX) results — the FX adapter is `noIndex`. To
discover an FX submission by keyword, call the MathWorks search endpoint directly and
read the **`package_name`** field: that is the identifier `mpminstall` needs.

```bash
curl -sS "https://www.mathworks.com/searchresults/results\
?c%5B%5D=fileexchange&q=<url-encoded keywords>\
&fl=title_en,url,summary_en,package_name,uuid&request_handler=select"
```

- **`c[]=fileexchange`** scopes to File Exchange; **`request_handler=select`** selects
  the lower-level handler that exposes `package_name`. The default *agent* search API
  (`/api/v1/agent/search`) does **not** return it.
- **`fl=`** is the field list. Request `package_name` and `uuid` explicitly; unknown
  field names are silently dropped, and `fl=*` is rejected (returns `null`).
- Response is Solr JSON: `response.docs[]`, each with:
  - **`package_name`** — the MPM install identifier. Feed this to `mpminstall`. It is a
    short identifier, and a distinct string from both the URL's numeric id and its slug.
  - **`uuid`** (= `container_uuid`; `asset_id` is the same value with an `add-ons:`
    prefix) — equals the resolved `Package.ID`. Use it only to **disambiguate** two
    same-titled submissions; it is **not** an `mpminstall` specifier.
  - `title_en`, `url` (`/matlabcentral/fileexchange/<id>-<slug>`), `summary_en`,
    `body_en` — for presenting candidates to the user.
- `response.numFound` is the total match count; page with `&page=N` / `&rows=N`.

File Exchange is a default known repository in R2026b (no `mpmAddRepository` needed; on
older setups add it with `mpmAddRepository("File Exchange", matlab.mpm.FileExchange)`).
Once you have the name:

```matlab
p = mpminstall("knownPackageName", DryRun=true, Prompt=false);  % resolves -> p.Version, p.ID, deps
mpminstall("knownPackageName", Prompt=false);                   % or "knownPackageName@1.2.0" for a version
```

**The search endpoint carries no version field, and FX versions cannot be enumerated
programmatically at all** — `mpmsearch(Name=…, VersionSelectionPolicy="all")` returns
empty because FX is `noIndex`. A `DryRun` install reports the version the *configured
registry* resolves, which can lag the version shown on the submission's FX web page (a
pre-release MATLAB may point at an integration registry — `matlab.mpm.FileExchange`
returns whatever URL the session targets, so never hardcode one). The FX web page (the
result `url`) is the only source of current version and full version history.

To confirm exact `mpm*` / `matlab.mpm.*` **function syntax**, use the `matlab-read-documentation`
skill — it owns MATLAB documentation lookup.

## Searching a custom repository (Repository Server REST API)

A custom/service-backed repository (an Artifactory-backed Package Repository Service) is
not indexed for `mpmsearch` either — it returns empty with no error. Query the service's
REST API directly; a bearer token is all that's required.

```bash
# A known name (case-insensitive; returns every version of that one package):
curl -sS -H "Authorization: Bearer ${ARTIFACTORY_TOKEN}" \
  <server_url>/v1/packages/by-name/<name>.json

# A known UUID:
curl -sS -H "Authorization: Bearer ${ARTIFACTORY_TOKEN}" \
  <server_url>/v1/packages/by-uuid/<uuid>.json

# Every package and version — the only way to enumerate the repository:
curl -sS -H "Authorization: Bearer ${ARTIFACTORY_TOKEN}" \
  <server_url>/v1/packages/index.json
```

The same calls from inside MATLAB, when no shell is available:

```matlab
opts = weboptions("HeaderFields", ["Authorization", "Bearer " + getenv("ARTIFACTORY_TOKEN")]);
manifests = webread(serverUrl + "/v1/packages/index.json", opts);
```

`<server_url>` is the MPRS **service** base URL — the same `url` used in
`repo-config.json`, **not** the raw Artifactory browse host (which has no
`/v1/packages/` shape). Each manifest object carries `name`, `displayName`, `id`,
`version`, `summary`, `provider.name`, `provider.organization`, `releaseCompatibility`,
`supportedPlatforms`, and `dependencies`.

**Decision rule:** use `by-name` when you already have a candidate name — it avoids
downloading the whole index. Use `index.json` to enumerate the repository, or for
attribute queries (by provider, platform, release compatibility, or keyword substring).
If `by-name` returns 404 and the name could be a substring, retry against the index and
substring-match. These endpoints are **read-only discovery**: install still goes through
`mpminstall` once the repository is registered (§ Repository management).

## Gotcha catalog (highest-impact first)

1. **Interactive prompts hang non-interactive sessions.** Pass `Prompt=false` on every
   install/uninstall/update and on `openProject`. A quiet, blocked session looks like a crash.
2. **Use a TOML project for a reproducible package environment.** In R2026b, opening a TOML
   project with `Prompt=false` additively installs its missing packages.
   Use `matlab-configure-toml-project` for project references and the full schema.
3. **Package dependencies use the package form**
   `{ version, id }`. The identity key is **`id`**, never `uuid` — even though its value is
   a UUID (e.g. `id = "c1438758-…"`); `uuid =` is not a recognized key. Use `matlab-configure-toml-project`
   for the project schema and reference projects.
4. **Only `mpmsearch(Name=…)` is case-sensitive.** `mpminstall`/`mpmuninstall`/`mpmupdate` and
   `mpmsearch(PackageSpecifier=…)` match names case-insensitively; only `mpmsearch(Name="Battery")`
   is exact-case. `mpmsearch` can miss what `mpminstall` resolves, so resolve a known name with
   `mpminstall(..., DryRun=true, Prompt=false)`.
5. **Same name, different ID = different packages.** `mpmupdate` won't cross them; use
   `AllowVersionReplacement=true` (or uninstall then install) to swap identity.
6. **`mpmupdate` goes to the newest available version by default** (version range defaults to
   `"*"`, no within-major ceiling). What's conservative is dependency handling —
   `UpdateDependencies="necessary"` moves transitive deps only when the new version requires it.
7. **`Force=true` is destructive.** On install it can remove other installed
   packages; on uninstall it can drop unrelated deps. Warn the user before running it.
8. **`Temporary=true` isn't ephemeral** — files persist globally. Normal uninstall removes the
   package from the MATLAB path; use `Delete=true` to remove files from disk. No way to query
   which installs were temporary.
9. **File Exchange: install by `package_name`; a default repo in R2026b.** `mpmsearch`
   never returns File Exchange results — discover a submission via the MathWorks search
   endpoint (`request_handler=select`) and install its **`package_name`** (see § Finding a
   File Exchange submission). A page title, the FX URL's numeric id, and its slug are
   **not** installable specifiers; neither is the `uuid` (disambiguation only). Resolve the
   name with `mpminstall(..., DryRun=true, Prompt=false)` before installing. FX versions
   cannot be enumerated programmatically.
10. **`proj.Dependencies` is the project file digraph, not packages.** Use `mpmlist` for
    package dependency information.
11. **Legacy File Exchange packages can break across releases.** Example: GUI Layout Toolbox
    v1 (`layout1`) uses the removed `handle.listener`; v2 (`layout2`, `uix.*` namespace) is
    current. `layout1` and `layout2` cannot coexist — this is a structural conflict, not a
    transient error. Check `.ReleaseCompatibility` and choose the compatible major.
12. **No pre-install content preview or restore command.** You see full metadata only
    after installation. Declare packages in `matlab.toml` and open the project with
    `Prompt=false` to provision them reproducibly.
13. **A stale open project silently suppresses auto-install.** `openProject(..., Prompt=false)`
    only auto-installs declared deps when it actually opens *this* project. If another project
    is already open (`currentProject` returns it), the call is a no-op for provisioning and
    `mpmlist` stays empty with no error. Close any open project first
    (`close(currentProject)` / check `matlab.project.rootProject`) before opening the target.
14. **`mpminstall` has no `Repository` argument.** It resolves across all registered repos;
    passing `Repository=` throws `Invalid argument name`. Scope by repo only on `mpmsearch`;
    for install, register the repo (`mpmAddRepository`) first, then install by name. Clear the
    on-disk cache with `matlab.mpm.internal.clearCache` (internal — test/cleanup only, not for
    shipped skill code).

## Additional notes (from the merged skills)

- **Credentials.** An install/update against an authenticated repo (Artifactory,
  private) can fail with `UnresolvedCredentialException` — the fix is user-side
  token / `.netrc` / credential-helper config, not a code change; flag it for the
  user. If credentials are unavailable and you have a local `.mltbx`,
  `matlab.addons.toolbox.installToolbox` installs it **without** dependency
  resolution as a last-resort fallback (prefer `mpminstall` otherwise).
- **UNC / folder-repo paths are platform-specific.** Linux/macOS use forward
  slashes (`"//server/share/path"`); Windows uses the UNC form
  (`"\\server\share"`). If a folder add fails with `'location' must be path to a
  folder`, invert the slashes. `mpmAddRepository` adds to the top of the search
  list (search-first); on a name collision the first hit wins — remove and re-add
  to reorder.
- **`Verbosity`** accepts only `"quiet"`, `"normal"`, or `"detailed"` on
  `mpminstall` / `mpmupdate` / `mpmuninstall`. Any other word (`"concise"`,
  `"verbose"`, …) errors.
- **Variable shadowing.** A package name reused as a variable, or a package
  function whose name shadows a built-in (a `Filter` package shadowing `filter`),
  can mask the installation. Confirm via `mpmlist` + `isfolder(pkg.PackageRoot)`,
  and `which -all <name>` to detect shadowing.
- **Diagnosing masked errors.** The MCP session can mask the real error behind
  "Array indices must be positive integers" (the hung-prompt symptom). A one-off
  MATLAB `-batch` run reveals the true error text — use it for diagnosis only
  (its installs do not persist).

----

Copyright 2026 The MathWorks, Inc.

----

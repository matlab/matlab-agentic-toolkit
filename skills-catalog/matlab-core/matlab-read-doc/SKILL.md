---
name: matlab-read-doc
keywords: docs documentation mathworks webread fetch lookup api reference function
description: "Guides the agent to reference official MathWorks Documentation and Help. Determine correct function syntax and workflows from user guides when deeper context is needed. Minimize iterations and repetitive trial and error.  Use this skill to: Identify correct syntax and configuration details. Retrieve relevant, version-specific (or release-specific) information from official documentation. Consult user guides when conceptual or workflow context is needed. Apply best practices."
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Use MathWorks Documentation

Systematic methodology for reading live MathWorks documentation. Provides a repeatable four-pass strategy (local catalog → `help` → user guide pages → reference pages) that turns documentation lookup into a predictable, efficient operation. Uses MATLAB's `webread` via MCP to fetch pages, with helper scripts that handle URL discovery, HTML parsing, and content extraction.

## When to Use

- You are answering a "How do I..." question related to MathWorks products and workflows
- You guessed a URL and got 404 — use this skill to discover the correct URL from the index
- You need to find which functions exist for a product or workflow — start with the local function catalog
- You need to verify a function's syntax, arguments, or deprecation status from the authoritative source
- You want to check MathWorks best practices for a specific workflow
- Training-data knowledge is uncertain or potentially out of date for a release-specific API
- The user asks what MathWorks recommends for a specific topic
- You want a systematic approach that finds the RIGHT page (not just A page) in minimal tool calls

## When NOT to Use

- The local `help` command is sufficient — prefer `help function_name` for API syntax; it's faster and always correct for the installed version
- The question is about general MATLAB programming patterns, not product-specific workflows
- You already have the authoritative answer from local `help` or a successfully fetched page

## Fast Paths

Not every task needs the full four-pass strategy. Match the task to the shortest path:

| Task                                 | Fast Path                                                                                                                      | Skip                               |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------- |
| Release notes / what's new           | Fetch `https://www.mathworks.com/help/{product}/release-notes.md` directly via `webread`, then extract the `## R20XXx` section | Steps 0-2 — no script needed       |
| Known standalone function, need ref page | Use a URL from a prior `extract_page_slugs` call, or construct `baseUrl + "ref/{name}.html"` for simple standalone functions | Steps 0-2 — but URL must come from a verified source, not guessed |
| Know the product, need function list | `get_local_function_list(product)`                                                                                             | Steps 1-4 — no web needed          |
| Unfamiliar API, no idea what exists  | Full four-pass strategy                                                                                                        | Nothing — use all steps            |

### Release notes

Release notes are available as clean markdown at `https://www.mathworks.com/help/{product}/release-notes.md`. Fetch this URL with `webread`, then extract the section between `## R20XXx` and the next `## R` header. No HTML parsing needed. Common product slugs: `matlab`, `simulink`, `ecoder`, `rtw`, `stateflow`, `fixedpoint`, `hdlcoder`.

## Help Center Page Hierarchy

- **Product landing page** — Lists top-level categories with short descriptions. Use to discover section slugs.
- **Intermediate category page** — Links to subcategories with one-line descriptions. No leaf content. Drill deeper.
- **Lowest-level category page** — Contains reference groups (functions, blocks, apps) then links to related topics and examples.
- **Topic pages** (`ug/` or product-specific path) — Conceptual or task-based content explaining how to use a feature.
- **Example pages** — Standalone worked examples with supporting files. May include live scripts, data files, or models.
- **Reference pages** (`ref/` or `slref/`) — Function, block, object, or property reference. Multiple subtypes: function ref, object ref, property list, block ref, app ref.
- **Getting started pages** (`gs/`) — Introductory tutorials for new users of a product.
- **Sequential topics** (STEP 1, 2, 3) indicate a workflow with an intended order.

## Choosing What to Fetch

MathWorks doc has two content layers that serve different purposes:

- **Guide pages** (user guide topics, typically under `ug/`) — Show *which* functions to call and in *what order*. Workflow-oriented. Best for learning a new API or deciding an approach. Note: not all products use `ug/` — some (Simulink, Statistics and Machine Learning) use different subdirectory structures. Always discover via the section index.
- **`ref/` pages** (function/object reference) — Show *exactly how* to call each function: full syntax, argument types, name-value pairs, valid enum values, return types, per-argument examples. Best when you know the function but need its exact signature. Some products use product-specific variants (e.g., Simulink uses `slref/`).

**You typically need both.** The `ug/` page tells you the recipe; the `ref/` page tells you the ingredient specifications. Skipping `ref/` means guessing at property names and argument values — which frequently fails because MathWorks APIs use domain-specific names that aren't intuitive (e.g., `"ArxmlFilePackaging"` not `"FilePackaging"`, `"StopTime"` not `"SimulationDuration"`).

### Page value signals (product-independent)

| Signal | Likely high value | Likely low value |
|---|---|---|
| Slug contains `programmatically`, `program-`, or `command-line` | Yes — always programmatic | — |
| Slug contains `property-map-functions` | Yes — API workflow | — |
| Slug contains `explorer`, `interactively`, `using-...editor` | — | Yes — GUI-only |
| Page type is `ref/` with object or function name | Yes — exact signatures | — |
| Page is very large (>30K) with product that has GUI+programmatic paths | — | Suspect GUI — measure before reading |
| Page under ~1500 chars between `Main Content` and footer | — | Likely a navigation stub or redirect |
| Slug starts with `example-` | Mixed — check if it opens with GUI wizard or live-script code |
| `ref/` page listing "-properties" in slug | Yes — property name/value lookup table |

### Four-pass strategy

**Entry rule:** If you have a function name from the user's request or from a `get_local_function_list` call in this session, start at Step 2. Do not skip Step 1 based on training-data knowledge alone — function names change between releases and guessed names waste calls.

1. **Discover functions via the local catalog:** Run `get_local_function_list('product', 'keyword')` to find which functions exist. **Only use this when you don't have a function name yet.**
2. **Get signatures with `help`:** Run `help functionName` or `help namespace`. If `help` answers your question, stop here — don't fetch the web page.
3. **Third pass (`ug/`):** If you need *workflow context* — which functions to call before/after, how they compose, or which of several approaches to take — fetch the `ug/` page with `programmatically` in the slug. This gives you the call sequence and overall pattern.
4. **Fourth pass (`ref/`):** If `help` was insufficient for a specific function (truncated output, missing name-value arguments from recent releases, need the full property enumeration, or need valid categories for a `find` call), fetch its `ref/` page. 

### When `help` is enough (most of the time)

- Syntax and basic arguments for any function
- Block descriptions (`help simulink/Gain`)
- Class and object reference (`help Simulink.SimulationInput`)
- Listing all functions in a namespace (`help matlab.io`) or methods on an object (`methods(obj)`)
- One-line descriptions of what each function does
- Input/output argument types
- Simple usage examples

### When `help` is NOT enough (fetch the web page)

- **Web `ref/` page:** name-value arguments added in recent releases; the full property name enumeration for a settings/properties object; valid enum values for an argument; which category strings are valid for a `find` call; `help` output is truncated or incomplete.
- **Web `ug/` page:** workflow context (what to call before/after); understanding how multiple functions compose together; the task has GUI and programmatic paths and you need to find the programmatic one; decision guides for choosing between approaches.

## URL Patterns

MathWorks documentation URLs follow these patterns. **Do not guess** — use the index to discover slugs.

### Building documentation URLs

All documentation URLs are versioned under `/help/releases/R20XXx/` and default to the installed MATLAB release. URL construction is handled internally by `fetch_product_index` — you do not need to build URLs manually. Get page URLs from one of these verified sources:

1. **`hrefs` output of `fetch_product_index`** — full URLs returned directly, ready to use
2. **`fullUrls` output of `extract_page_slugs`** — full URLs from a section index

`baseUrl` already includes the product path (e.g., `https://www.mathworks.com/help/releases/R2026a/autosar/`). Append only the sub-path: `baseUrl + "ref/name.html"` or `baseUrl + "ug/topic.html"`. Never re-add the product name.

### Page type patterns

| Page type       | Pattern                                     | Example                                                                        |
| --------------- | ------------------------------------------- | ------------------------------------------------------------------------------ |
| Product index   | `{base}/{product}/index.html`               | `https://www.mathworks.com/help/releases/R2025b/simulink/index.html`           |
| Section index   | `{base}/{product}/{section-slug}.html`      | `https://www.mathworks.com/help/releases/R2025b/simulink/block-libraries.html` |
| User guide page | `{base}/{product}/ug/{page-slug}.html`      | `https://www.mathworks.com/help/releases/R2025b/simulink/ug/some-topic.html`   |
| Reference page  | `{base}/{product}/ref/{function-name}.html` | `https://www.mathworks.com/help/releases/R2025b/matlab/ref/plot.html`          |

**URL structure varies by product.** Always crawl the section index to discover actual slugs — do not guess subdirectory names.

| Product          | Guide pages                                                        | Reference pages                                              |
| ---------------- | ------------------------------------------------------------------ | ------------------------------------------------------------ |
| `matlab`         | `matlab_prog/slug.html`, `matlab_oop/slug.html` — multiple subdirs | `ref/name.html`                                              |
| `simulink`       | `ug/slug.html`                                                     | `slref/name.html` (also `gui/` for configuration parameters) |
| `systemcomposer` | `ug/slug.html`                                                     | `ref/name.html`                                              |
| `autosar`        | `ug/slug.html`                                                     | `ref/name.html`                                              |
| `stateflow`      | `ug/slug.html`                                                     | `ref/name.html`                                              |

For MATLAB, flat slugs with no subdirectory (e.g. `debug-code.html`) are usually section navigation pages. When crawling a section index, hrefs appear as relative paths — prepend the base URL to construct the full URL.

Common product slugs: `matlab`, `simulink`, `systemcomposer`, `stateflow`, `autosar`, `ecoder`, `fixedpoint`, `stats`, `control`, `signal`, `dsp`, `deeplearning`, `images`, `optim`, `robust`, `mpc`, `sltest`, `parallel-computing`

## Scripts

MATLAB scripts automate the repetitive fetch-and-parse steps. These are **function files** — they require input arguments and must be called via `evaluate_matlab_code`, NOT `run_matlab_file`.

### How to invoke

Use `evaluate_matlab_code` with `project_path` set to this skill's `scripts/` directory (the "Base directory for this skill" shown at the top of this prompt, plus `/scripts`). 
Do NOT use `run_matlab_file` — these are functions that require input arguments.

```
Tool: evaluate_matlab_code
code: "[t, hrefs] = fetch_product_index('simulink', 'Modeling')"
project_path: "<base-directory-for-this-skill>/scripts"
```

### Script reference

| Script                      | Signature                                                         | Purpose                                                                                             |
| --------------------------- | ----------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `get_local_function_list.m` | `results = get_local_function_list(product, searchTerm)`          | Read complete categorized function list from local MATLAB install (fastest, works offline)          |
| `fetch_product_index.m`     | `[t, hrefs, baseUrl] = fetch_product_index(product, search, rel)` | Auto-detect release, fetch product index, return section links AND base URL for reuse               |
| `extract_page_slugs.m`      | `[slugs, fullUrls] = extract_page_slugs(sectionUrl)`              | Extract page slugs and full URLs from a section index                                               |
| `fetch_doc_page.m`          | `content = fetch_doc_page(url, maxChars, startChar)`              | Fetch a doc page and extract readable text (default 50K char limit). Pass `startChar` to paginate.  |
| `find_replacement.m`        | `find_replacement(url)`                                           | Search a page for deprecation/replacement language                                                  |
| `DocUtilities.m`            | Static class (not called directly)                                | Shared utilities: HTML stripping, link extraction, URL resolution. Used internally by other scripts |

---

## Workflow

Use the Fast Paths table above to determine which steps to skip. The full workflow below is for unfamiliar APIs where you don't know what exists.

### Step 1 — Try `help` first (when you have a function name)

If you have a function name from any source, start here:

```matlab
help set_param               % function reference
help Simulink.SimulationInput  % class reference
```

If `help` answers your question, stop here. This is the most common entry point.

### Step 1b — Discover functions via the catalog (when you don't have a name)

If you don't know what function to call, discover what exists:

```matlab
results = get_local_function_list('ecoder');
results = get_local_function_list('simulink', 'code generation');
```

Returns a table with Name, Purpose, and Category. If you don't know the product slug, call `get_local_function_list('unknown')` to list available slugs. Then proceed to Step 1 with the discovered function names.

### Step 2 — Navigate the product index to find the right page

`fetch_product_index` auto-detects the release, constructs the base URL, and returns section links:

```matlab
[t, hrefs, baseUrl] = fetch_product_index('simulink', 'Modeling');
```

The third output `baseUrl` is the resolved version-aware URL — reuse it for all subsequent fetches in this session.

### Step 3 — Fetch a section index to get page slugs

Use a URL from `hrefs` (returned by `fetch_product_index`) directly — do not construct URLs manually:

```matlab
[slugs, fullUrls] = extract_page_slugs(hrefs{2,1});
```

### Step 4 — Fetch and extract a specific page

```matlab
content = fetch_doc_page(fullUrls{3});           % from discovered URLs
```
For very large pages, limit output:
```
content = fetch_doc_page(pageUrl, 10000);        % limit to 10K chars
```

### Step 5 — Verify deprecation notices and replacements
When `help` shows "not recommended", find the recommended replacement on the web page:

```matlab
find_replacement(baseUrl + "ref/hist.html");
```

---

## Instructions

### HTML processing

HTML stripping is handled internally by the fetch scripts (`fetch_doc_page`, `fetch_product_index`, `find_replacement`). Do not reimplement HTML parsing — call the appropriate fetch script instead.

### URL discovery — never guess

- When a URL returns 404, go up one level (section index or product index) and read slugs from the page content.
- **Standalone function** ref page URLs (one dot or none: `plot`, `set_param`) can also be constructed directly: `baseUrl + "ref/{name}.html"` — since `baseUrl` already includes the product path.
- **Functions or objects with a namespace** (e.g., `Simulink.SimulationInput`, `autosar.api.create`): use `extract_page_slugs` on the relevant section index to discover the correct URL.
- All other URLs must be discovered from index pages. The `fetch_product_index` function returns full URLs in `hrefs` — use them directly.

### Variable naming

Avoid names that shadow MATLAB built-ins: `dir`, `input`, `length`, `size`, `path`. If already shadowed in the workspace, use `clear <name>` before calling the built-in.

### Product-specific URL patterns

- **MATLAB**: Has multiple subdirectories (`matlab_prog/`, `matlab_oop/`, `ref/`). Flat slugs with no subdirectory are almost always section navigation pages.
- **Simulink**: Uses `ug/` for guide pages, `slref/` for block/function reference, and `gui/` for configuration parameters.
- **System Composer, Stateflow**: Use `ug/` for guide pages, `ref/` for reference. Straightforward hierarchy.
- **Products with GUI+programmatic paths**: Large character counts don't guarantee programmatic content — GUI-documentation pages can be 20K+ of UI element descriptions. Look for `programmatically` or `program-` in the slug as a reliable signal.


### Release-specific documentation

- All URLs are versioned (`/help/releases/R20XXx/`). `fetch_product_index` defaults to the installed MATLAB release. Pass a release argument (e.g., `"R2024b"`) to target a different version.
- Always verify `help` output first — it's guaranteed to match the installed version.
- If web docs describe features not available in `help`, the user may be on an older release. Note this discrepancy rather than assuming the API exists.

---

Copyright 2026 The MathWorks, Inc.

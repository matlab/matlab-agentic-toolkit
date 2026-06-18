---
name: matlab-sharing
description: >
  Share MATLAB content by guiding users through uploading to GitHub, MATLAB Drive,
  or File Exchange, then generating "Open in MATLAB Online" URLs. Covers the full
  sharing workflow: choosing a platform, uploading content (automated via gh CLI
  for GitHub, manual for MATLAB Drive and File Exchange), and constructing the
  correct URL. Use when a user wants to share MATLAB code with others, open local
  files in MATLAB Online, generate an open-in-MATLAB-Online button or badge,
  or when an AI agent has generated MATLAB code locally and the user wants to
  share it or run it in MATLAB Online.
license: MathWorks BSD-3-Clause
metadata:
  author: MathWorks
  version: "1.0"
---

# Sharing MATLAB Content

Share MATLAB content by uploading to GitHub, MATLAB Drive, or File Exchange, then generating "Open in MATLAB Online" URLs that let recipients open the content directly in a browser.

## When to Use

- User has local MATLAB files and wants to open them in MATLAB Online
- User wants to share MATLAB code via a link that opens in MATLAB Online
- AI agent generated MATLAB code locally and user wants to run/open it in MATLAB Online
- User asks for an "Open in MATLAB Online" link, button, or badge
- User has content on GitHub/MATLAB Drive/File Exchange and wants the direct-open URL

## When NOT to Use

- User wants to try out MATLAB code without needing to upload anywhere
- User is asking about MATLAB Online features, licensing, or account setup
- User wants to run MATLAB code interactively in MATLAB Online without generating a shareable link

## Workflow

### 1. Identify the starting point

Ask what the user has:
- **Local files only** → they need to upload first, then generate the URL
- **Already on GitHub** → skip to URL generation (GitHub path)
- **Already on MATLAB Drive with a share link** → skip to URL generation (Drive path)
- **Already on File Exchange** → skip to URL generation (File Exchange path)

### 2. Help choose a path

If the user hasn't uploaded yet, recommend based on their goal:

| Goal | Recommended Path | Why |
|------|-----------------|-----|
| Quick sharing or personal use | GitHub | Fully automated via CLI; works for public repos |
| Share with specific people (private) | MATLAB Drive | Supports access control; no public repo needed |
| Share with the MATLAB community | File Exchange | Discoverable by all MATLAB users; includes ratings/reviews |
| Embed in documentation/README | GitHub | Supports badge images in markdown |

### 3. Guide the upload

Follow the appropriate path below.

### 4. Generate the URL

Use the exact templates in the URL Templates section. Present the final URL to the user.

If the user has multiple files, generate a separate URL for each file they want to open. To open all files at once:
- **GitHub:** omit the `file` param — clones the entire repo without opening a specific file
- **MATLAB Drive:** set `file=/` — opens the shared folder
- **File Exchange:** omit the `file` param — opens the full submission

### 5. Optionally generate a badge (GitHub path only)

If the user wants a clickable button for a README:

```markdown
[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](URL_HERE)
```

## URL Templates

### GitHub

```
https://matlab.mathworks.com/open/github/v1?repo=<owner>/<repo>&file=<relative-path>
```

| Parameter | Required | Description |
|-----------|----------|-------------|
| `repo` | Yes | `owner/reponame` (no `https://github.com/` prefix) |
| `host` | No | GitHub host (default: `github.com`). Required for GitHub Enterprise (e.g., `github.mathworks.com`) |
| `file` | No | Specific file to open after clone |
| `project` | No | MATLAB project file to open (e.g., `myProject.prj`) |
| `line` | No | Line number to navigate to |
| `focus` | No | Set to `true` to open in focused editor view |

There is NO `branch` or `tag` parameter. The URL always clones the default branch.

**URL generator tool:** Users can also generate these URLs interactively at `https://www.mathworks.com/products/matlab-online/git.html`

### MATLAB Drive

```
https://matlab.mathworks.com/open/matlabdrive/v1?namespace=SHARED&id=<share-uuid>&file=<filename>
```

| Parameter | Required | Description |
|-----------|----------|-------------|
| `namespace` | Yes | Always `SHARED` for shared content |
| `id` | Yes | UUID from the share link |
| `file` | Yes | Filename from the share link |

The `host` parameter is optional — it defaults to `gds.mathworks.com` if omitted.

### File Exchange

```
https://matlab.mathworks.com/open/fileexchange/v1?id=<submission-id>
```

| Parameter | Required | Description |
|-----------|----------|-------------|
| `id` | Yes | Numeric submission ID from the File Exchange URL |
| `file` | No | Specific file to open after download |
| `project` | No | MATLAB project file to open |
| `version` | No | Specific version of the submission |
| `line` | No | Line number to navigate to |
| `focus` | No | Set to `true` to open in focused editor view |

## GitHub Path: Step-by-Step

This is the only path with full CLI automation.

**Before running any commands**, verify the `gh` CLI is installed and authenticated:

1. Check installation: `gh --version`
2. Check authentication: `gh auth status`

If `gh` is not installed, guide the user to install it (e.g., `brew install gh` on macOS, or visit https://cli.github.com). If not authenticated, have the user run `gh auth login` before proceeding.

**If the user has local files not yet on GitHub**, run these commands for them:

```bash
# 1. Initialize and commit
git init my-project
cd my-project
cp /path/to/your/file.m .
git add .
git commit -m "Add MATLAB code"

# 2. Create public repo and push
gh repo create my-project --public --source=. --push
```

**Before running step 2**, warn the user explicitly: creating a `--public` repo makes the code visible to anyone on the internet. Ask them to confirm they are comfortable making the code public and to review the files being pushed. Only proceed with their explicit permission.

**Once the repo exists** (either just created or already on GitHub), construct the Open in MATLAB Online URL using the repo name and file path:

```
https://matlab.mathworks.com/open/github/v1?repo=<owner>/<repo>&file=<filename>
```

Present this final URL to the user.

## MATLAB Drive Path: Step-by-Step

There is no CLI for MATLAB Drive. MATLAB Drive sharing only works at the **folder level** — individual files cannot be shared directly. The user uploads all files into a folder, shares the folder, and the resulting share link targets a specific file within that folder.

**Give the user these instructions:**

1. Go to `https://drive.mathworks.com/`
2. Create a folder in MATLAB Drive
3. Upload all file(s) into that folder
4. Right-click the **folder** → **Share** → **Create Link**
5. Copy the share link and provide it back

**Once the user provides the share link**, extract the UUID and filename from it. The share link format is:
```
https://drive.matlab.com/sharing/<uuid>/<filename>
```

Then construct the Open in MATLAB Online URL:
```
https://matlab.mathworks.com/open/matlabdrive/v1?namespace=SHARED&id=<uuid>&file=<filename>
```

The same UUID can be used to open other files in the shared folder — just change the `file` parameter. To open the entire folder, set `file=/`.

Present this final URL to the user.

## File Exchange Path: Step-by-Step

There is no CLI for File Exchange.

**Give the user these instructions:**

1. Go to `https://www.mathworks.com/matlabcentral/fileexchange/`
2. Sign in and publish the submission
3. After publishing, provide the submission ID or the File Exchange page URL

**Once the user provides the submission ID or URL**, extract the numeric ID. The File Exchange URL format is:
```
https://www.mathworks.com/matlabcentral/fileexchange/<ID>-<title-slug>
```

Then construct the Open in MATLAB Online URL:
```
https://matlab.mathworks.com/open/fileexchange/v1?id=<ID>
```

To open a specific file within the submission, add the `file` parameter:
```
https://matlab.mathworks.com/open/fileexchange/v1?id=<ID>&file=<filename>
```

Omitting `file` opens the full submission.

Present this final URL to the user.

## Common Mistakes

| Mistake | Why It's Wrong | Correct Approach |
|---------|---------------|-----------------|
| Adding `&branch=main` to GitHub URL | Parameter doesn't exist; URL always clones default branch | Omit branch — only `repo`, `file`, and `project` are valid |
| Using `/open/drive/v1` for MATLAB Drive | Wrong path segment | Use `/open/matlabdrive/v1` |
| Using `?sharing=<uuid>` for MATLAB Drive | Wrong parameter format | Use `?namespace=SHARED&id=<uuid>&file=...` |
| Omitting `namespace` for Drive URLs | URL won't resolve without it | Always include `namespace=SHARED` |
| Including `https://github.com/` in the `repo` param | Format is `owner/repo` only | Strip the domain: `aanithap/my-project` not `https://github.com/aanithap/my-project` |
| Suggesting email or cloud storage | Doesn't give an "Open in MATLAB Online" experience | Use one of the 3 supported paths |

## Conventions

- Always present all 3 options when the user hasn't decided on an upload path
- Always use the exact URL templates — do not guess or interpolate URL patterns
- For GitHub: recommend `--public` for shareable links (private repos require auth)
- Never suggest a `branch` or `tag` parameter for GitHub URLs
- URL-encode file paths that contain spaces or special characters (e.g., `My File.m` → `My%20File.m`)

----

Copyright 2026 The MathWorks, Inc.

----

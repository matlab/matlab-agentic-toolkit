# Java Runtime Error Signatures

Verbatim MATLAB error-text patterns that fire Branch A of this skill. Match against these when a MATLAB script errors on a `java.*` API call.

## R2026a and later

**Verbatim text (captured live on R2026b; same message on R2026a):**

> This feature is attempting to execute Java code, but no runtime environment for Java applications has been found. Explore your options at MATLAB Support for OpenJDK.

**Match tokens:** *"no runtime environment for Java applications has been found"* — this phrase is stable.

**Embedded link:** the error contains an inline link to [`https://www.mathworks.com/matlab-openjdk`](https://www.mathworks.com/matlab-openjdk). Surface this link to the user; it is the MathWorks-sanctioned source for supported JDK versions.

## R2025a and R2025b

**Verbatim text (`{0}` is filled in with a path):**

> Unable to find Java library: {0}
> Please check if you have a MATLAB_JAVA environment variable.
> Note that MATLAB requires Java version 1.8 or higher.

**Match tokens:** *"Unable to find Java library"* — treat as equivalent to the R2026a+ text for routing purposes.

The message mentions an environment variable. Do not repeat that as the fix; follow Branch A.

## What to do after a match

Follow *Workflow — Branch A: Script Hits a Java API* in `SKILL.md`: present Option A and Option B from step 2, give the R2025a+ behavior from step 3, then re-run the script and verify with `jenv` (steps 4 and 5).

## What does NOT match

Do **not** fire Branch A on:

- `undefined function or variable 'java...'` — that is a MATLAB-syntax error, not a runtime-missing error.
- `No class definition found` / `java.lang.ClassNotFoundException` — Java is loaded, class path is wrong. Out of scope for this skill; the user is looking at `javaaddpath` / JAR-management guidance.
- License-related MATLAB launch failures — see the "When NOT to Use" section in `SKILL.md`.

----

Copyright 2026 The MathWorks, Inc.

----

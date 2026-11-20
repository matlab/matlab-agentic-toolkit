# Find a 6G Example in the Documentation

1. Find the 5G Toolbox "6G Exploration Library" section with `matlab-core:matlab-read-documentation`
   if it is installed; otherwise `webread` `https://www.mathworks.com/help/5g/<page>.html`. These
   pages list the workflow examples with a description; check all of them:
   - `6g-exploration-library` (the landing page also lists examples that are on no subpage)
   - `waveform-exploration-and-simulations`
   - `isac-and-ris`
   - `ai-for-6g`
2. Pick the example from its description. `fetch_doc_page` strips links, so read the
   `openExample` ids from the page's raw HTML:

   ```matlab
   html = webread("https://www.mathworks.com/help/5g/waveform-exploration-and-simulations.html");
   tok = regexp(html, "openExample\(&#39;([\w/]+)&#39;\)", "tokens");
   ids = unique(string([tok{:}]));
   ```

3. Examples from other products appear only as `ug/` links, such as
   `../<product>/ug/<page>.html`. Resolve the link against the subpage URL and run the same
   code on that page to get the `openExample` id.
4. Return to the `SKILL.md` workflow at step 3 and open the example.

----

Copyright 2026 The MathWorks, Inc.

----

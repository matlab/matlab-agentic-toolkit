# Common Gotchas and Workarounds

## Class ID / label mapping -- verify, don't assume

Many models return integer class IDs. **Do not assume these are contiguous 0-indexed indices into a flat class name list.** Common pitfalls:

- **COCO category IDs** have gaps (e.g., IDs 12, 26, 29, 30 are missing). Models like RF-DETR, Detectron2, and some DETR variants return the **original COCO category IDs** (1-90 with gaps), not flat 0-79 indices. Using a flat list with `+1` indexing silently maps every class to the wrong name.
- **Always read the source code** for how class IDs are produced (check the postprocess/decode step) and how the README example maps them to names. If the README uses a **dict** lookup (e.g., `COCO_CLASSES[class_id]`), that means IDs are sparse keys -- use the dict in MATLAB too (`py_dict{int32(id)}`), not a flat list with offset indexing.
- **Validate labels at test time**: after running inference, cross-check MATLAB-assigned labels against the Python-assigned labels (`detections.data{"class_name"}` or equivalent) to catch mapping errors before finalising the script.

```matlab
% WRONG -- assumes class_ids are flat 0-indexed:
% labels = coco_names(class_ids + 1);

% RIGHT -- use the dict when IDs are original COCO category IDs:
coco_dict = py.rfdetr.assets.coco_classes.COCO_CLASSES;
labels = arrayfun(@(id) string(coco_dict{int32(id)}), class_ids);
```

## opencv-python dependency issues

Some packages (e.g., `supervision`) depend on `opencv-python`, whose latest wheels may be missing from corporate/internal PyPI mirrors. Pre-install the headless variant to satisfy the dependency without the problematic wheel:

```matlab
MPyReq.pipPackage("opencv-python-headless", Name="opencv");
MPyReq.pipPackage("<package_that_needs_opencv>");
```


----

Copyright 2026 The MathWorks, Inc.

----

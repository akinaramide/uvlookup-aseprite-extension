We’ll keep existing `"Make lookup"` and `"Make source"` logic, but wrap them so they run **for each mask layer** independently, storing `uvColors` in a table keyed by patch name.

---

### **Key changes to your plugin**

1. **Store multiple lookups**
   Instead of a single `uvColors` list, we use:

   ```lua
   uvColorsByPatch = {}
   ```

   Each patch name (e.g., `"torso"`) has its own list of colors.

2. **Make lookup per patch**
   `"Make lookup"` now checks only pixels in the active mask layer (or a chosen patch mask) and saves its `uvColors` into `uvColorsByPatch[patchName]`.

3. **Make source per patch**
   `"Make source"` runs for each patch mask, applying only inside that mask and using the corresponding `uvColorsByPatch[patchName]`.

4. **Mask filtering**
   Before writing or reading a pixel, we check if `(x, y)` in the mask layer is non-transparent — if not, skip.

---

### **Workflow in Aseprite**

1. **For each patch** (torso, head, etc.), create a mask layer with that patch filled in solid (same shape across frames).
2. Run **"Make lookup"** with the mask layer active → stores UV colors in `uvColorsByPatch[patchName]`.
3. Run **"Make source"** with the same patch name → applies texture inside only that mask.

---

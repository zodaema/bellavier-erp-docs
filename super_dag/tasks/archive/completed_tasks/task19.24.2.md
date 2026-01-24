

# Task 19.24.2 — Legacy Validation Removal (PHP / JS Lean‑Up)

## Objective
Remove *all* legacy validation logic that still exists in PHP and JavaScript after Task 19.24.1, ensuring the system uses **only** `GraphValidationEngine` for validation.

This task prepares the codebase for the Lean‑Up Phase and stabilizes the validation architecture before Task 20.

---

## Scope of Removal

### PHP (Backend)
Remove legacy validation from:
- `dag_routing_api.php`  
  - Delete `validateGraphStructure()`  
  - Delete `checkSubgraphSignatureChange()`  
  - Delete fallback QC routing validators  
  - Delete any old inline validation code before save  
- `GraphValidationService.php` (if still present — delete entire file)
- Any helper function prefixed with:
  - `validateGraph*`
  - `validateRouting*`
  - `checkNode*`
  - `checkEdge*`  

All validation must go through:

```
GraphValidationEngine->validate(...)
```

### JavaScript (Frontend)
Remove legacy validation from:
- `graph_designer.js`
  - Delete `validateGraphBeforeSaveLegacy()`
  - Delete any QC-specific validation still lingering
  - Remove UI code showing old validation messages
- `conditional_edge_editor.js`
  - Ensure it performs *zero* validation (only UI)
- `GraphSaver.js`
  - No fallback / no inline validation

---

## Required Output After Removal
1. No JS function should perform validation logic (UI only).
2. No PHP function other than `GraphValidationEngine` should return validation errors.
3. `graph_validate`, `graph_save`, `graph_publish`, `graph_save_draft` must call only:
   ```
   $engine = new GraphValidationEngine(...);
   $result = $engine->validate(...);
   ```
4. No legacy validation error patterns (e.g., “QC missing fail_major”) should ever appear again.

---

## Acceptance Criteria

| Item | Status |
|------|--------|
| All legacy PHP validation removed | ☐ |
| All legacy JS validation removed | ☐ |
| Only `GraphValidationEngine` performs graph validation | ☐ |
| No fallback logic or duplicate warnings remain | ☐ |
| Validation output identical across save/validate/publish flows | ☐ |
| Test suite still passes after removal | ☐ |

---

## Next Step (19.24.3)
After completing 19.24.2, proceed to:
**19.24.3 — Consolidate helper/service classes (GraphHelper, ConditionEvaluator, IntentEngine) to remove duplication.**
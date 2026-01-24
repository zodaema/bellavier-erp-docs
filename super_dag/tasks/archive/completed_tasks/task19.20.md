

# Task 19.20 — Lean-Up Phase 1 (P1–T1)
## Extract GraphHelper & Remove Duplicate Helper Methods

### 🎯 Objective
Consolidate shared graph helper logic into a single reusable module (`GraphHelper.php`) and remove duplicate implementations from:
- `GraphValidationEngine`
- `SemanticIntentEngine`
- `ReachabilityAnalyzer`
- `GraphAutoFixEngine`
- `ApplyFixEngine`

This is a **Lean-Up only** task.  
**No behavior changes** are allowed.  
All validation, semantic, reachability, and autofix outputs must remain identical.

---

## 1. Create File: `source/BGERP/Dag/GraphHelper.php`

Create a new class with these methods:

### **1.1 buildNodeMap()**

Must support lookup by:
- `id_node`
- `temp_id`
- `node_code`

### **1.2 buildEdgeMap()**

Must return:
- `by_id`
- `by_from`
- `by_to`

Supports:
- `id_edge`
- `temp_id`
- `from_node_id`
- `to_node_id`

### **1.3 extractQCStatusesFromCondition()**

Rules:
- Skip conditions with `type = "default"`
- For token_property with `property = "qc_result.status"`:
  - Accept values: `pass`, `fail_minor`, `fail_major`
- For group conditions:
  - Recursively scan groups[*].conditions[*]

Implementation must match the canonical formats defined in:
- `validation_leanup_plan_v2.md`
- Task 19.16 (default route rules)

---

## 2. Update Engine Files

Modify the following files to use `GraphHelper` instead of private helper methods:

### **Files:**
- `source/BGERP/Dag/GraphValidationEngine.php`
- `source/BGERP/Dag/SemanticIntentEngine.php`
- `source/BGERP/Dag/ReachabilityAnalyzer.php`
- `source/BGERP/Dag/GraphAutoFixEngine.php`
- `source/BGERP/Dag/ApplyFixEngine.php`

### **For each file:**
1. Add:
   ```php
   use BGERP\Dag\GraphHelper;
   ```
2. Replace:
   - `$this->buildNodeMap(...)` → `GraphHelper::buildNodeMap(...)`
   - `$this->buildEdgeMap(...)` → `GraphHelper::buildEdgeMap(...)`
   - `$this->extractQCStatusesFromCondition(...)` → `GraphHelper::extractQCStatusesFromCondition(...)`
3. Remove the now-unused private methods:
   - `buildNodeMap()`
   - `buildEdgeMap()`
   - `extractQCStatusesFromCondition()`

**Do NOT** modify any validation logic.  
**Do NOT** change method signatures.  
**Do NOT** change output structures.

---

## 3. Post-Task Test Requirements

After completing the refactor, the following tests must produce identical results to before the Lean-Up:

### Run:
```
php tests/super_dag/ValidateGraphTest.php
php tests/super_dag/SemanticSnapshotTest.php
php tests/super_dag/AutoFixPipelineTest.php
```

### Acceptance Criteria:
- No new validation errors
- No differences in semantic intent snapshots
- Autofix suggestions remain identical
- No behavior regression
- No warnings in debug logs

---

## 4. Notes

- This is the **first** Lean-Up step.  
- This extraction reduces risk for Phase 2 refactors.  
- Behavior changes are strictly forbidden in this task.

---

## ✔ Status
**READY FOR IMPLEMENTATION**
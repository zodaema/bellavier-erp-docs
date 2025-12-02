

# Task 19.14 — Final Integration Sync: Validation, Autofix, Semantic Engine

**Status:** In Progress  
**Owner:** SuperDAG Core  
**Purpose:** Ensure every layer (UI → API → Engine → Execution) is synchronized after Tasks 19.7–19.13, with no fallback to legacy logic.

---

## 1. Objectives

1. Guarantee that **every validation event** (manual save, autosave, edge edit, node edit) flows through:
   - `SemanticIntentEngine`
   - `GraphValidationEngine`
   - `GraphAutoFixEngine` (optional)
2. Remove last hidden fallback paths:
   - Old QC routing validator  
   - Legacy work_center validator  
   - Legacy node field validator  
3. Unify error/warning output format across all screens.
4. Ensure risk scoring + semantic intents appear in:
   - Save dialog
   - Validate dialog
   - Autofix dialog
5. Ensure “Engine-first” lifecycle:
   - UI does not validate anything by itself  
   - UI only renders results provided by API  

---

## 2. Work Items

### **2.1 API: Final cleanup**
- Remove final calls to:
  - `DAGValidationService`  
  - `validateGraphStructureLegacy()`  
  - Any reference to `qcPass` / legacy condition  
- Ensure `graph_validate` = **single source of truth**

### **2.2 UI (graph_designer.js) alignment**
- Replace all client-side validation with:
  ```js
  const result = await api.validateGraph();
  ```
- Update:
  - Node editor save  
  - Edge editor save  
  - Autosave  
  - Manual save  

### **2.3 Autofix flow refinement**
- Ensure UI → API → UI loop is synchronous:
  1. Call `graph_validate`
  2. Show dialog
  3. Call `graph_autofix`
  4. Show preview
  5. Call `graph_apply_fixes`
  6. Reload graph + revalidate

### **2.4 Validation UI uniformity**
- Use same output rendering:
  - Error list  
  - Warning list  
  - Node context  
  - Edge context  
  - Intent badge  
  - Risk badge  
- Add expander for “Advanced technical details”

### **2.5 Remove deprecated UI components**
- Delete decision node panel (legacy)  
- Delete QC legacy field references  
- Delete split/join node panels  
- Delete wait-node UI  

---

## 3. Acceptance Criteria

| Requirement | Status |
|------------|--------|
| UI stops using any legacy validator | ☐ |
| All validation flows route to API only | ☐ |
| Autofix works end-to-end | ☐ |
| Validation results uniform across UI | ☐ |
| Legacy UI elements removed | ☐ |
| No console warnings | ☐ |

---

## 4. Output

After Task 19.14 completes:
- GraphDesigner is **100% engine-driven**
- No legacy validation remains
- Semantic validation & autofix behave predictably
- Stable foundation for **Task 19.15 — Reachability & Dead-end Detection**

---

**End of Task 19.14**


# Task 19.24.13 — JS Lean‑Up Mega‑Task (Unified 19.24.13–19.24.16)

This task instructs the AI Agent to execute the ENTIRE JavaScript Lean‑Up Phase in ONE consolidated run.  
It merges tasks 19.24.13, 19.24.14, 19.24.15, and 19.24.16 into a single unified refactor.

---

## 🎯 OBJECTIVE  
Perform a **full JS Lean‑Up Mega‑Pass** across the DAG Designer front‑end codebase, targeting:
- `graph_designer.js`
- `GraphHistoryManager.js` (only if needed)
- `conditional_edge_editor.js`
- Any DAG modules in `/assets/javascripts/dag/modules/`

Your mission is to **reduce code size**, **remove dead code**, **extract clean modules**, and **normalize structure** without altering behavior.

---

## 🛠️ SCOPE (Merged from 19.24.13 → 19.24.16)

### 1) Dead‑Code Removal — Phase 1  
- Detect and delete:
  - unused functions  
  - unreachable branches  
  - obsolete event listeners  
  - unused constants and variables  
  - duplicate functions  
- Ensure no UI functionality breaks.

### 2) Extract Graph IO Layer (GraphIOLayer.js)  
Move all logic related to:
- node extraction  
- edge extraction  
- style extraction  
- snapshot restoration  
OUT of `graph_designer.js` and into a new module:
```
/assets/javascripts/dag/modules/GraphIOLayer.js
```

### 3) Extract Graph Action Layer (GraphActionLayer.js)  
Move logic for user actions:
- addNode  
- addEdge  
- deleteNode  
- deleteEdge  
- applyTemplate  
into:
```
/assets/javascripts/dag/modules/GraphActionLayer.js
```

### 4) Dead‑Code Removal — Phase 2 (Aggressive Sweep)
- Remove all legacy hotkeys  
- Remove zombie code from pre‑SuperDAG era  
- Remove commented‑out legacy blocks  
- Remove TODOs that are obsolete  
- Reduce line count by 300–700 lines

### 5) Normalize Module Structure  
After refactoring, ensure EXACT 6 core modules exist:
1. GraphDesigner.js (UI orchestrator only)  
2. GraphHistoryManager.js  
3. GraphIOLayer.js  
4. GraphActionLayer.js  
5. ConditionalEdgeEditor.js  
6. GraphValidatorPreview.js (optional, generate if missing)

---

## 🔐 SAFETY RULES
- **Do not change behavior.** The visual and functional behavior of the DAG Designer must remain identical (same clicks → same result).
- **Do not alter condition evaluation logic.** All conditional edge logic must continue to flow through `ConditionEvaluator` and use the same JSON schema.
- **Do not alter validation / autofix contracts.** The shape of validation JSON, error/warning codes, and autofix payloads must remain unchanged.
- **Do not alter History / Undo–Redo semantics.**
  - Do not change the public API of `GraphHistoryManager` (push/undo/redo/beginGroup/endGroup).
  - Do not change grouping semantics (1 user action → 1 history step).
- **Do not touch PHP validation / execution engines.** This task is **JS-only**. Do not modify `GraphValidationEngine`, `SemanticIntentEngine`, `ApplyFixEngine`, หรือ PHP อื่น ๆ
- **Preserve Conditional Edge Editor DOM.** Do not break or restructure the DOM in a way that changes selectors or data bindings used by `conditional_edge_editor.js`.
- **Backward compatibility only.** Ifมี code ที่ดูเหมือนเก่าแต่ยังอาจถูกเรียกจากที่อื่น ให้ห่อไว้ด้วย comment:
  ```js
  // SAFE: preserved for compatibility
  ```
  แทนการลบทิ้งหากไม่มั่นใจ 100%
- **No new dependencies.** อย่าเพิ่ม third‑party libraries หรือ global variables ใหม่ ๆ

---

## ✔️ ACCEPTANCE CRITERIA
- JS line count reduced by at least **400–900 lines** รวมทุกไฟล์ที่เกี่ยวข้องกับ DAG Designer
- Modules แยกเป็น 6 ไฟล์สุดท้ายตามที่ระบุใน “Normalize Module Structure”
- **Undo/Redo ไม่เปลี่ยนพฤติกรรม**
  - สร้าง node/edge หลายครั้งแล้วกด Undo/Redo ต้องถอย/เดินทีละ action เท่าเดิม
  - Drag node แล้ว Undo ต้องย้อนกลับที่เดียว (ไม่ข้าม 2 ครั้ง)
- **Drag, Zoom, และ Edge creation ไม่เปลี่ยนพฤติกรรม**
  - ลาก node, ลาก edge, เลือก conditional edge แล้วใส่เงื่อนไข ต้องทำงานเหมือนเดิมทุกประการ
- **Validation / Autofix / QC Routing ทำงานเหมือนเดิม**
  - เรียก `graph_validate`, `graph_autofix`, `graph_apply_fixes` ได้ผลลัพธ์ JSON รูปแบบเดิม
  - Template QC “Pass → Next | Fail → Rework” ยัง validate & save ได้โดยไม่มี error
- **Test ทั้งหมดต้องผ่าน 100%** (รันหลัง refactor ทุกครั้ง)
  - `php tests/super_dag/ValidateGraphTest.php`
  - `php tests/super_dag/AutoFixPipelineTest.php`
  - `php tests/super_dag/SemanticSnapshotTest.php`
- **ไม่มี error ใหม่ใน console**
  - เปิด Graph Designer แล้วทดลองใช้ flow หลัก (เพิ่ม node/edge, ตั้ง QC, validate, save) ต้องไม่ขึ้น error/warning ใหม่ใน browser console
- โค้ดใหม่ต้องอ่านง่าย (split เป็น modules ตามแผน) และ comment สำคัญยังคงอยู่

---

## 🚀 OUTPUT  
The AI Agent should produce:

1. **New files**  
   - `GraphIOLayer.js`  
   - `GraphActionLayer.js`  
   - (optional) `GraphValidatorPreview.js`

2. **Patched graph_designer.js**  
   – greatly reduced, only orchestrating UI events  
   – delegating IO + actions to new modules

3. **Patched conditional_edge_editor.js**  
   – only condition UI logic remains

4. **Changelog + summary** inside `task19.24.13_results.md`.

---

---

## 🔒 Public API Contracts (สำคัญมาก — ห้ามเปลี่ยน)

### GraphHistoryManager.js
- `push(snapshot)`
- `undo()`
- `redo()`
- `beginGroup(actionType)`
- `endGroup()`
- `markBaseline()`
- `isModified()`
- `clear()`
- `getLength()`
- `getCurrentIndex()`
- `getBaselineIndex()`

### GraphIOLayer.js (ใหม่ — ต้องสร้าง)
- `export function buildGraphSnapshot(cy, meta = {})`
- `export function restoreGraphSnapshot(cy, snapshot)`
- `export function extractNodes(cy)`
- `export function extractEdges(cy)`

### GraphActionLayer.js (ใหม่ — ต้องสร้าง)
- `export function addNode(cy, options)`
- `export function addEdge(cy, options)`
- `export function deleteNode(cy, nodeId)`
- `export function deleteEdge(cy, edgeId)`
- `export function applyTemplate(cy, templateId, options = {})`

---

## 🧪 Manual Smoke Tests (ต้องระบุผลใน task19.24.13_results.md)

### 1) Basic Graph Flow
- สร้าง: START → OP1 → QC → END  
- ตั้ง QC “Pass → Next | Fail → Rework”  
- Validate → Save → Publish ต้องทำงานเหมือนเดิม

### 2) Undo/Redo Accuracy
- เพิ่ม node 3 ครั้ง → Undo 3 → Redo 3  
- Drag node 1 ครั้ง → Undo → Redo  
- ทุกขั้นตอนต้องย้อนทีละ 1 action ไม่ข้าม

### 3) Parallel Routing
- สร้าง Parallel Split/Merge  
- Validate ต้องไม่มี error semantic ใหม่

### 4) Conditional Edge Integration
- เปิด Conditional Edge Editor  
- เลือก field  
- Save condition  
- Validate ต้องผ่านเหมือนเดิม  
- ไม่มี error ใหม่ใน console

---

## 🛡️ Additional Safety
- ก่อนลบฟังก์ชัน/ตัวแปร ให้ search ทั้ง workspace  
- ถ้ามีความไม่แน่ใจ:  
```
```js
// SAFE: preserved for compatibility
```
```
- ห้ามแก้ไข DOM selector ที่ conditional_edge_editor.js ใช้  
- ห้ามเปลี่ยน filename หรือ path import ของไฟล์หลัก  
```

This task is ready to run.  
Perform a **single consolidated Lean-Up Mega‑Task** covering everything above.
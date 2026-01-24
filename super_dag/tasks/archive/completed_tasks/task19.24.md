# Task 19.24 — SuperDAG Lean‑Up Phase: Core Validation Layer Simplification (Pass 1)

You are working on Task 19.24 — SuperDAG Lean-Up Phase: Core Validation Layer Simplification (Pass 1).

Before we run any Lean-Up refactors, add SAFETY MARKERS (comments only) into the core SuperDAG engine PHP files to protect critical logic.

⚠️ HARD CONSTRAINTS (VERY IMPORTANT)
- DO NOT modify any behavior.
- DO NOT change any logic, conditions, or code paths.
- DO NOT change function signatures.
- DO NOT touch test files.
- DO NOT touch any `.md` documentation files (especially docs/super_dag/tasks/task19.24.md).
- Only insert PHP comments in the specified PHP files.
- No new classes, no new functions, no refactors in this step.

Target files (PHP ONLY):
1) source/BGERP/Dag/GraphValidationEngine.php
2) source/BGERP/Dag/SemanticIntentEngine.php
3) source/BGERP/Dag/ReachabilityAnalyzer.php
4) source/BGERP/Dag/GraphAutoFixEngine.php
5) source/BGERP/Dag/ApplyFixEngine.php
6) source/BGERP/Dag/GraphHelper.php

For each file, do the following:

------------------------------------------------
(1) GraphValidationEngine.php
------------------------------------------------
- Find the line:
    namespace BGERP\Dag;
  Immediately AFTER it, insert this line (as a single-line comment):

    // SAFETY: Do not modify core validation logic in Task 19.24 (Lean-Up Pass 1).

- Find the QC validation method (the method that validates QC routing), likely named something like:
    private function validateQCRouting(...
  or similar. Immediately ABOVE that function definition, insert:

    // IMPORTANT: QC routing behavior is stable and relied on by tests. Do not change logic in Lean-Up Pass 1.

Do NOT rename the function. If you cannot find a QC-specific method, do nothing for this part.

------------------------------------------------
(2) SemanticIntentEngine.php
------------------------------------------------
- Find:
    namespace BGERP\Dag;
  Immediately AFTER it, insert:

    // SAFETY: Do not modify semantic intent detection logic in Task 19.24 (Lean-Up Pass 1).

- Find the method responsible for parallel/merge intent analysis, likely:
    private function analyzeParallelIntent(...
  Immediately ABOVE that method, insert:

    // IMPORTANT: Parallel intent detection must remain deterministic. No logic changes in Lean-Up Pass 1.

If the method name is slightly different but clearly handles parallel/merge intent, use that. If you cannot find it, skip this specific comment.

------------------------------------------------
(3) ReachabilityAnalyzer.php
------------------------------------------------
- Find:
    namespace BGERP\Dag;
  Immediately AFTER it, insert:

    // SAFETY: Do not modify BFS/DFS core traversal logic in Task 19.24 (Lean-Up Pass 1).

- Find the main traversal method that builds reachability info (BFS/DFS over nodes/edges), e.g.:
    private function buildReachability(...
  or the core method that walks the graph. Immediately ABOVE that method, insert:

    // IMPORTANT: Reachability traversal outputs are validated by snapshot tests. Keep behavior unchanged in Pass 1.

If you’re unsure which method is the core traversal, pick the one that iterates over nodes/edges and drives reachability; otherwise, skip this comment.

------------------------------------------------
(4) GraphAutoFixEngine.php
------------------------------------------------
- Find:
    namespace BGERP\Dag;
  Immediately AFTER it, insert:

    // SAFETY: Auto-fix semantics and risk model must not change in Task 19.24 (Lean-Up Pass 1).

No other changes in this file.

------------------------------------------------
(5) ApplyFixEngine.php
------------------------------------------------
- Find:
    namespace BGERP\Dag;
  Immediately AFTER it, insert:

    // SAFETY: ApplyFixEngine must remain atomic and behavior-compatible in Task 19.24 (Lean-Up Pass 1).

No other changes in this file.

------------------------------------------------
(6) GraphHelper.php
------------------------------------------------
- Find:
    namespace BGERP\Dag;
  Immediately AFTER it, insert:

    // SAFETY: GraphHelper is the canonical hub for DAG utilities; do not change public behavior in Task 19.24 (Lean-Up Pass 1).

- Inside the class, near the top of the class body (just before the first public static utility method), insert this block comment:

    // TODO-PASS2: Move remaining extractor + path builder functions here after Task 20 (ETA Engine) is complete.

Do NOT change any existing methods or signatures.

------------------------------------------------
Validation after patch:
------------------------------------------------
- Ensure:
  - No .md files were modified.
  - Only comment lines were added.
  - No PHP syntax errors introduced.
  - Namespaces and use statements remain unchanged.
  - All existing tests should still pass after this (we will run the tests later).

This step is ONLY to add safety markers before Lean-Up. Do not start any refactor yet.

## Objective
ลดความซับซ้อนของ SuperDAG Validation Layer ให้พร้อมสำหรับ Task 20 (ETA Engine) โดยไม่แตะ logic ที่เสี่ยง แต่ “ลีนโค้ด” ที่ปลอดภัย 100%  
*ไม่เปลี่ยน behavior*  
*ไม่แตะ validation rules*  
*ไม่แตะ semantic intents*  
*ไม่แตะ autofix pipeline*  
*ไม่แตะ graph_save API*

## Scope (Pass 1 — Safe Lean-Up)
รายการด้านล่างคือ “สิ่งที่ลบได้ทันที” และ “สิ่งที่รวมไฟล์ได้ทันที” โดยไม่มีความเสี่ยง

### ✔ 1) ลบ debug logs และ leftover comments
- GraphValidationEngine.php  
- SemanticIntentEngine.php  
- ReachabilityAnalyzer.php  
- ApplyFixEngine.php  
- GraphAutoFixEngine.php  
- GraphHelper.php  

**ลบได้ทันที**:  
- `// TODO: legacy migration`  
- `// DEBUG:`  
- `// TEMP:`  
- `// Legacy`  
- `print_r`, `var_dump`, `error_log` (ยกเว้น error_log ที่อยู่ใน API)

---

### ✔ 2) รวม helper duplicates ที่ยังเหลือ
ไฟล์เหล่านี้ถูกทำซ้ำข้าม engine:

- `isParallelSplitNode()`
- `isParallelMergeNode()`
- `extractConditionStatuses()`
- `isDefaultRoute()`

**Action**: รวมทั้งหมดเข้า `GraphHelper.php` แล้วลบจาก engine อื่น  
(ไม่มี side-effect เพราะทุก engine ใช้ nodeMap/edgeMap เดียวกันแล้ว)

---

### ✔ 3) Normalize ค่า return structure ของ validation
ทุก engine จะ normalize structure ผ่าน:

- `ValidationResultBuilder::normalizeErrors()`
- `ValidationResultBuilder::normalizeWarnings()`

**Pass 1**:  
- รวม duplicated formatting  
- ไม่แตะ semantic content  

---

### ✔ 4) รวม path metadata builder
ปัจจุบันมีซ้ำใน 3 ไฟล์:

- GraphValidationEngine
- ReachabilityAnalyzer
- SemanticIntentEngine

**Action**:  
สร้างใน GraphHelper:

```
buildPathDetails($path, $nodeMap);
```

แล้วให้ทุก engine เรียกจากที่เดียว

---

### ✔ 5) Deprecate private legacy methods (ไม่ลบ)
Mark ว่า deprecated:

```
private function old_extractQC() { ... }
private function old_isSplit() { ... }
private function old_buildNodePaths() { ... }
```

เพราะบาง method ยัง referenced ใน test snapshot  
*(ลบใน Pass 2 หลัง Task 20)*

---

## Out of Scope (Pass 1)
**ห้ามแตะใน Task 19.24:**

- routing logic  
- semantic rules  
- semantic intent detection  
- error severity map  
- risk scoring  
- autofix risk model  
- test fixtures  
- snapshot outputs  

ทั้งหมดนี้ stable และเป็น foundation สำหรับ Task 20

---

## Deliverables
1. Lean-Up diff (ไม่เปลี่ยน behavior)
2. Updated GraphHelper functions
3. Deprecated legacy methods
4. ลบ debug code ทั้งหมด (ยกเว้น API logs)
5. ไม่มี test snapshot เปลี่ยนแปลง  
   - หาก snapshot เปลี่ยน ถือว่า Lean-Up ผิดรอบ ต้อง rollback
6. File นี้ (`task19.24.md`) อัพเดทเข้าระบบ

---

## Acceptance Criteria
- ไม่มี snapshot เปลี่ยน  
- ValidateGraphTest: 15/15 ผ่าน  
- SemanticSnapshotTest: 15/15 ผ่าน  
- AutoFixPipelineTest: 15/15 ผ่าน  
- โค้ดอ่านง่ายขึ้น 20–30%  
- โค้ด duplicate ใน engine ลดลง 60–80%  
- GraphHelper เป็น canonical hub ของทุก utility method  

---

## Status
**รอเริ่ม Lean-Up Diff (19.24.1 – 19.24.4)**  
หลังไฟล์นี้จะเริ่มทำ Lean-Up จริงในชุดย่อย 4 tasks:

- 19.24.1 — Remove Debug & Legacy Comments  
- 19.24.2 — Consolidate Helpers into GraphHelper  
- 19.24.3 — Normalize ValidationResult  
- 19.24.4 — Prepare Safe Deprecations for Pass 2

พร้อมเริ่มได้ทันที

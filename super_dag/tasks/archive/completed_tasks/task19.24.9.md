Task 19.24.9 — Extract & Slim GraphHistoryManager (Final Lean-Up)

Category: SuperDAG / Lean-Up / JS
Goal: ทำให้โค้ด Undo/Redo + HistoryManager “ลีนและชัด” โดย
	•	ตัด legacy API ที่ไม่ใช้แล้ว
	•	จำกัด public surface area ของ HistoryManager ให้เหลือชุด method เดียว
	•	เคลียร์ wrapper/ฟังก์ชันซ้ำใน graph_designer.js
	•	ยืนยันว่า behaviour Undo/Redo ยังเหมือน Task 19.24.8 ทุกประการ

สำคัญ: Task นี้ห้ามเปลี่ยนพฤติกรรมของ Undo/Redo
เป้าหมายคือ “จัดระเบียบ & ล้างของเก่า” เท่านั้น

⸻

0. Scope

ไฟล์ที่อนุญาตให้แก้:
	1.	assets/javascripts/dag/modules/GraphHistoryManager.js
	2.	assets/javascripts/dag/graph_designer.js
	3.	docs/super_dag/tasks/task19_24_9_results.md (เขียนสรุปผล)

ห้ามแตะ:
	•	PHP ทั้งหมด (รวม dag_routing_api.php)
	•	Validation/Autofix engine ฝั่ง backend
	•	Test PHP ทั้งหมด (ValidateGraphTest, AutoFixPipelineTest, SemanticSnapshotTest)

⸻

1) Normalize Public API ของ GraphHistoryManager

1.1 กำหนด “Public API ที่อนุญาตให้ใช้จริง”

ให้ตั้งชื่อ section ชัดเจนใน GraphHistoryManager.js:

// === Public API (Canonical) ===
// ใช้เฉพาะชุดนี้เท่านั้นจากโค้ดภายนอก

ชุด method ที่อนุญาต:
	•	constructor(options?)
	•	push(snapshot)
	•	undo() : snapshot|null
	•	redo() : snapshot|null
	•	reset() (ถ้ามี, ถ้าไม่มีไม่ต้องเพิ่ม)
	•	markBaseline()
	•	isModified() : boolean
	•	getBaselineIndex() : number (ถ้ามี)
	•	getCurrentIndex() : number (optional)
	•	getLength() : number (optional)

ถ้ามี method ไหนในนี้ยังไม่มีให้เพิ่มแบบง่าย ๆ โดยไม่เปลี่ยน logic เดิม

1.2 Legacy API: ตรวจ → Refactor → ลบ

ให้ค้นใน GraphHistoryManager.js ว่ามี method legacy ต่อไปนี้อยู่หรือไม่:
	•	saveState(cy)
	•	undoLegacy(cy)
	•	redoLegacy(cy)
	•	restoreState(cy, snapshot)
	•	อื่น ๆ ที่รับ cy เป็น parameter

ขั้นตอน:
	1.	ใน graph_designer.js ดูว่า ยังมีที่ไหนเรียก:
	•	graphHistoryManager.saveState(cy)
	•	graphHistoryManager.undo(cy) / undoLegacy(cy)
	•	graphHistoryManager.redo(cy) / redoLegacy(cy)
	•	graphHistoryManager.restoreState(...)
	2.	ถ้ายังมีการเรียก:
	•	เปลี่ยนให้เรียกผ่าน canonical flow:
	•	const snapshot = buildGraphSnapshot() → graphHistoryManager.push(snapshot)
	•	const snapshot = graphHistoryManager.undo() → restoreGraphSnapshot(snapshot)
	•	const snapshot = graphHistoryManager.redo() → restoreGraphSnapshot(snapshot)
	3.	เมื่อมั่นใจว่า ไม่มีการเรียก legacy methods จากที่ไหนแล้ว:
	•	ลบ method legacy ทั้งหมดออกจาก GraphHistoryManager.js
	•	ถ้าจำเป็นให้คง comment ไว้สั้น ๆ ในผลลัพธ์ (ในไฟล์ผลลัพธ์ task) ว่า “legacy API ถูกลบแล้วเพราะไม่มีคนใช้”

ถ้าเจอ method legacy บางตัวที่ยังจำเป็น เช่น getCurrentSnapshot()
ให้ย้ายมันไปอยู่ใน public API list ด้านบนและทำให้ ไม่ผูกกับ Cytoscape (pure snapshot object)

⸻

2) Clean-up ฝั่ง graph_designer.js ให้เรียกใช้ API เดียว

ตอนนี้ Undo/Redo + Save ใช้ canonical snapshot แล้วจาก Task 19.24.8 แต่ Task นี้จะ “เก็บบ้านให้เรียบร้อย”:

2.1 ตรวจจุดที่เรียก Undo/Redo ทั้งหมด

ใน graph_designer.js ให้หา:
	•	function undo()
	•	function redo()
	•	จุดที่ผูกกับปุ่ม UI / keyboard shortcuts:
	•	$('#btnUndo')...
	•	$('#btnRedo')...
	•	keyboard mapping: ctrl+z, ctrl+shift+z, meta+z, etc.

ให้ยืนยันว่า ทุกจุด:
	•	ใช้ pattern เดียวกัน:

function undo() {
    if (isAsyncOperationInProgress) { ... return; }
    if (!graphHistoryManager || !cy) return;

    const snapshot = graphHistoryManager.undo();
    if (!snapshot) return;

    restoreGraphSnapshot(snapshot);
}

	•	ไม่มีที่ไหนเรียก graphHistoryManager.undo(cy) หรือ undoLegacy อีก

2.2 ตรวจ saveState() ให้ใช้ snapshot อย่างเดียว

ฟังก์ชัน saveState() (ที่ Task 19.24.8 เพิ่งเขียน) ต้องเป็นแบบนี้:
	•	เช็ค flag: restoringFromHistory และ graphHistoryManager.isRestoring()
	•	สร้าง snapshot ผ่าน buildGraphSnapshot()
	•	ส่งให้ graphHistoryManager.push(snapshot)
	•	อัพเดทปุ่ม Undo/Redo + modified state

ต้องไม่มี:
	•	graphHistoryManager.saveState(cy)
	•	Logic ที่เขียน JSON เองซ้ำกับ buildGraphSnapshot()

⸻

3) ยืนยันว่า HistoryManager แยก concern ชัดเจน

3.1 ไม่ให้ GraphHistoryManager รู้จัก Cytoscape อีกแล้ว

หลังจากลบ legacy methods แล้ว:
	•	ใน GraphHistoryManager.js ต้องไม่มีคำว่า cy เลย (ค้นคำทั้งไฟล์)
	•	ห้ามเรียก method หรือ property ของ Cytoscape จากใน HistoryManager
	•	HistoryManager ควรทำงานกับ object snapshot อย่างเดียว

3.2 ให้ graph_designer เป็นคนจัดการ Cytoscape ทั้งหมด
	•	buildGraphSnapshot() = อ่านจาก cy → สร้าง snapshot
	•	restoreGraphSnapshot(snapshot) = เขียนกลับเข้า cy
	•	HistoryManager แค่ stack push/undo/redo, baseline logic เท่านั้น

⸻

4) เอกสารสรุปผล Task 19.24.9

ให้สร้างไฟล์:

docs/super_dag/tasks/task19_24_9_results.md

แนะนำโครงแบบนี้:

# Task 19.24.9 Results — GraphHistoryManager Slim & Cleanup

**Status:** ✅ COMPLETED  
**Date:** 2025-12-xx  
**Category:** SuperDAG / Lean-Up / Undo-Redo

---

## 1. What We Changed

### 1.1 GraphHistoryManager Public API

- Public methods:
  - push(snapshot)
  - undo() / redo()
  - markBaseline()
  - isModified()
  - …
- Removed legacy methods:
  - saveState(cy)
  - undoLegacy(cy)
  - redoLegacy(cy)
  - restoreState(cy, snapshot)

### 1.2 graph_designer.js Integration

- undo()/redo() now always:
  - call manager.undo()/redo()
  - call restoreGraphSnapshot(snapshot)
- saveState() now:
  - builds snapshot via buildGraphSnapshot()
  - pushes into manager

---

## 2. Safety & Tests

- No changes to PHP backend
- No changes to validation/autofix logic
- JS passes build/lint (ถ้ามี)
- Manual scenarios (Undo/Redo) behave identical to Task 19.24.8

---

## 3. Acceptance Checklist

- [x] GraphHistoryManager has no direct Cytoscape usage
- [x] No references to undoLegacy/saveState(cy)/redoLegacy in JS
- [x] Undo/Redo UI uses the new canonical API only
- [x] Manual tests:
  - Add → Undo → Redo
  - Move → Undo → Redo
  - Rename → Undo → Redo
  - Mixed actions → Undo/Redo step-by-step
- [x] Validation tests still pass (no code changes in PHP)


⸻

5) Acceptance Criteria (สำหรับจบ 19.24.9 จริง ๆ)

ต้องผ่านทั้งหมดนี้ถึงจะถือว่า “จบจริง”
	1.	GraphHistoryManager.js:
	•	ไม่มี cy ปรากฏในไฟล์
	•	ไม่มี method legacy (saveState(cy), undoLegacy, redoLegacy, restoreState)
	•	มี comment ชัดเจนว่า public API มีอะไรบ้าง
	2.	graph_designer.js:
	•	ทุก undo() / redo() ใช้ graphHistoryManager.undo()/redo() + restoreGraphSnapshot()
	•	saveState() ใช้ buildGraphSnapshot() + graphHistoryManager.push()
	•	ไม่มีการเรียก legacy method ใด ๆ ของ HistoryManager
	3.	Behaviour:
	•	ทดสอบ Undo/Redo แบบ manual แล้วได้ผลลัพธ์เหมือน Task 19.24.8
	•	ไม่เกิด bug ใหม่เกี่ยวกับ auto-save / ETag / modified state
	4.	Tests:
	•	php tests/super_dag/ValidateGraphTest.php → ผ่าน
	•	php tests/super_dag/AutoFixPipelineTest.php → ผ่าน
	•	php tests/super_dag/SemanticSnapshotTest.php → ผ่าน (ไม่มีผลจาก JS แต่ถือว่า regression check)

⸻
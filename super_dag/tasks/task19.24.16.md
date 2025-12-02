Task 19.24.16 — Normalize SuperDAG JS Module Structure

1. Objective

Normalize and finalize the SuperDAG frontend module structure so that each file has a clear, single responsibility, and cross–dependencies are minimal, predictable, and easy to reason about. This is the final structural clean‑up step before entering Phase 20 (ETA / Time Engine).

The goal is not to add new features, but to:
	•	Make the codebase easier to understand.
	•	Reduce accidental coupling between modules.
	•	Make future changes safer and cheaper.

⸻

2. Target Module Layout (Final Form)

Target structure for SuperDAG JS modules:
	1.	GraphDesigner.js
	•	Role: UI orchestrator & page controller.
	•	Responsibilities:
	•	Bootstrapping Cytoscape and UI widgets.
	•	Wiring event handlers (toolbar, keyboard, dialogs).
	•	Calling into GraphHistoryManager, GraphIOLayer, GraphActionLayer, ConditionalEdgeEditor, GraphValidatorPreview.
	•	Managing high‑level page state (currentGraphId, dirty flag, autosave timer).
	2.	GraphHistoryManager.js
	•	Role: Pure history engine.
	•	Responsibilities:
	•	Maintain snapshot stack (undo / redo).
	•	Grouping of actions (drag, batch operations).
	•	Provide a minimal public API:
	•	push(snapshot)
	•	undo()
	•	redo()
	•	markBaseline()
	•	isModified()
	•	clear()
	•	getLength()
	•	getCurrentIndex()
	•	getBaselineIndex()
	3.	GraphIOLayer.js
	•	Role: Graph I/O and snapshot marshalling.
	•	Responsibilities:
	•	Snapshot building from Cytoscape → { nodes, edges, meta }.
	•	Snapshot restore into Cytoscape.
	•	Mapping between internal node/edge structures and API payloads (if needed).
	•	No DOM access, no event bindings.
	4.	GraphActionLayer.js
	•	Role: Graph mutation primitives.
	•	Responsibilities:
	•	Node operations:
	•	addNode(), updateNodeData(), deleteNode(), duplicateNode().
	•	Edge operations:
	•	addEdge(), updateEdgeData(), deleteEdge().
	•	Lightweight helpers:
	•	generateNodeCode()
	•	getOutgoingEdgesCount()
	•	getIncomingEdgesCount()
	•	No direct DOM access; receives cy and parameters only.
	5.	ConditionalEdgeEditor.js
	•	Role: Conditional edge UI editor.
	•	Responsibilities:
	•	Render / update conditional edge editor dialog.
	•	Map UI selections → condition model.
	•	Call GraphActionLayer/GraphIOLayer via GraphDesigner (no direct Cytoscape).
	6.	GraphValidatorPreview.js (optional / thin layer)
	•	Role: Bridge between GraphValidationEngine (PHP) and JS UI.
	•	Responsibilities:
	•	Render validation results (errors, warnings, semantic conflicts).
	•	Show validation dialogs & checklists.
	•	No validation logic of its own (logic lives on the backend).

⸻

3. Scope of Changes

3.1 GraphDesigner.js
	•	Ensure GraphDesigner:
	•	Does not implement graph mutation logic inline.
	•	Does not marshal raw node/edge data (use GraphIOLayer).
	•	Does not contain history stack logic (use GraphHistoryManager).
	•	Allowed responsibilities:
	•	Wiring toolbar buttons → GraphActionLayer operations.
	•	Wiring keyboard shortcuts → GraphActionLayer / GraphHistoryManager.
	•	Calling GraphIOLayer for snapshot build/restore.
	•	Triggering validation API calls and passing results into UI.

3.2 GraphHistoryManager.js
	•	Confirm that:
	•	No direct reference to cy remains.
	•	No DOM access / jQuery / document usage.
	•	Only manipulates snapshots and indexes.
	•	Any UI updates based on undo/redo should live in GraphDesigner.js.

3.3 GraphIOLayer.js
	•	Confirm that:
	•	Knows how to:
	•	Extract nodes and edges from Cytoscape.
	•	Normalize to canonical snapshot format.
	•	Restore snapshot back into Cytoscape.
	•	Does not know about:
	•	Toolbar state.
	•	Validation dialogs.
	•	History stack.
	•	If there is stray logic (e.g. validation, action grouping) inside GraphIOLayer, move it out.

3.4 GraphActionLayer.js
	•	Ensure:
	•	Node/edge mutations are implemented here as small, focused functions.
	•	GraphDesigner.js does not re‑implement mutations inline.
	•	No DOM access; all DOM/UX belongs in GraphDesigner.
	•	Typical call path should look like:
	•	Button / key event (GraphDesigner) → GraphActionLayer (mutation) → GraphDesigner pushes snapshot → GraphHistoryManager.

3.5 ConditionalEdgeEditor.js
	•	Confirm:
	•	Only deals with:
	•	UI for condition groups.
	•	Mapping UI to condition JSON model.
	•	Does not:
	•	Call validation logic directly.
	•	Talk to backend API directly (done by GraphDesigner).

3.6 GraphValidatorPreview.js (ถ้ามี)
	•	Confirm:
	•	Only responsible for rendering / updating validation UI.
	•	No graph mutation, no history logic.

⸻

4. Safety Rules (ห้ามละเมิด)
	1.	No Behavior Change
	•	All existing behaviors (add node/edge, undo/redo, conditional edge editing, validation dialog) ต้องทำงานเหมือนเดิม.
	•	Tests:
	•	ValidateGraphTest.php
	•	AutoFixPipelineTest.php
	•	SemanticSnapshotTest.php
ต้องผ่านทั้งหมดหลัง refactor
	2.	No New Features
	•	ห้ามเพิ่มปุ่ม ห้ามเพิ่ม keyboard shortcuts
	•	ห้ามเปลี่ยนข้อความหรือ layout UI เว้นแต่จำเป็นต่อการแยก module
	3.	No New Global State
	•	ห้ามเพิ่ม global variables นอกเหนือจากที่มีอยู่แล้วใน GraphDesigner.js
	•	GraphHistoryManager, GraphIOLayer, GraphActionLayer ต้องเป็น pure modules (ผ่าน arguments/returns เท่านั้น)
	4.	Backward Compatibility
	•	ConditionalEdgeEditor ต้องยังอ่าน/เขียน condition model แบบเดิมได้
	•	Snapshot format ต้องยังเป็น canonical { nodes, edges, meta } ตาม 19.24.10–19.24.12
	•	Validation pipeline ห้ามเปลี่ยน API contract

⸻

5. Steps for the AI Agent (Cursor / Codex)

Important: ทำเป็น incremental commits/patches และรัน tests ทุกครั้ง

	1.	Phase 1 — Mapping
	•	เปิด graph_designer.js, GraphHistoryManager.js, GraphIOLayer.js, GraphActionLayer.js, ConditionalEdgeEditor.js, GraphValidatorPreview.js (ถ้ามี)
	•	ทำ quick map:
	•	ฟังก์ชันใดทำ IO
	•	ฟังก์ชันใดทำ mutation
	•	ฟังก์ชันใดเป็น purely UI
	2.	Phase 2 — Enforce Responsibility Boundaries
	•	ย้ายฟังก์ชันที่ผิดที่ไปหา module ที่ถูก:
	•	จาก GraphDesigner → GraphIOLayer / GraphActionLayer.
	•	จาก GraphIOLayer/GraphActionLayer → GraphDesigner (ถ้ามี DOM/UX แปลกปลอม).
	•	Update imports/exports ให้ถูกต้อง
	3.	Phase 3 — Simplify Call Paths
	•	ตรวจสอบการเรียกใช้:
	•	UI Event → GraphDesigner → GraphActionLayer → GraphIOLayer/History
	•	ลบ wrapper functions ที่กลายเป็น redundant หลัง refactor
	4.	Phase 4 — Clean Up & Comment
	•	เพิ่ม module headers สั้น ๆ ในแต่ละไฟล์:
	•	ชื่อ module
	•	Responsibility
	•	ห้ามเขียน logic ประเภทใดในไฟล์นี้
	•	ลบ TODO/comment ที่ล้าสมัยสำหรับ validation v1
	5.	Phase 5 — Run Tests
	•	รัน:
	•	php tests/super_dag/ValidateGraphTest.php
	•	php tests/super_dag/AutoFixPipelineTest.php
	•	php tests/super_dag/SemanticSnapshotTest.php
	•	ถ้า test ใด fail ให้แก้เฉพาะส่วนที่จำเป็น ห้าม disable test

⸻

6. Acceptance Criteria

Task 19.24.16 ถือว่าสำเร็จเมื่อ:
	1.	โครงสร้างไฟล์เป็นไปตาม Target Module Layout
	•	GraphDesigner.js = UI orchestrator (ไม่มี mutation/IO/historic logic)
	•	GraphHistoryManager.js = pure history module
	•	GraphIOLayer.js = pure snapshot/IO module
	•	GraphActionLayer.js = pure mutation module
	•	ConditionalEdgeEditor.js = pure edge condition UI
	•	GraphValidatorPreview.js = pure validation UI bridge (ถ้ามี)
	2.	ไม่มี Cross-Responsibility Smell ที่เห็นชัด
	•	ไม่มี DOM access ใน History/IO/Action modules
	•	ไม่มี history stack logicใน I/O / Action / Editor modules
	3.	Tests ผ่านทั้งหมด
	•	ValidateGraphTest = pass
	•	AutoFixPipelineTest = pass
	•	SemanticSnapshotTest = pass
	4.	Line Count ไม่สำคัญเท่าความชัดเจน
	•	ไม่จำเป็นต้องบีบ line count ให้ต่ำสุด
	•	สิ่งสำคัญคือ responsibility ชัด, dependency ตรง, และ logic ค้นหาได้ง่าย

⸻

7. Note to Future Self (Bellavier / SuperDAG Phase 20)

หลังจบ Task 19.24.16:
	•	SuperDAG frontend structure พร้อมสำหรับการเพิ่ม:
	•	ETA / Time Engine (Phase 20.x)
	•	SLA overlays / Gantt / capacity views
	•	Advanced QC / Machine coordination UI

ห้ามเปลี่ยนโครงสร้าง module ใหม่แบบไร้ทิศทางอีก ควรอ้างอิงเอกสารนี้ทุกครั้งก่อนจะเพิ่ม/แก้ SuperDAG frontend ในอนาคต

Task 19.24.8 — Fix แกน Undo/Redo + Normalize GraphHistoryManager

เป้าหมายหลัก:
ทำให้ Undo/Redo ของ Graph Designer “เชื่อถือได้” (state ย้อนถูกจริง) โดยไม่ไปยุ่ง validation หรือ engine อื่นเพิ่มเติม
โฟกัสแค่ 2 ส่วน:
	•	GraphHistoryManager
	•	การใช้ saveState() / undo / redo ใน graph_designer.js

⸻

1) วิเคราะห์ GraphHistoryManager (แต่ไม่โมก่อน)

ไฟล์เป้าหมาย (คาดว่า):
	•	assets/javascripts/dag/graph_history_manager.js
	•	หรือไฟล์ชื่อใกล้เคียงที่สร้าง window.GraphHistoryManager / window.graphHistoryManager

สิ่งที่ต้องทำ
	1.	อ่านโค้ดทั้งไฟล์ แล้วจดว่า:
	•	มี method อะไรบ้าง (pushState, push, undo, redo, clear, getCurrent, ฯลฯ)
	•	เก็บ state เป็นอะไร:
	•	cy.json() ทั้งก้อน?
	•	หรือเก็บแค่ nodes/edges?
	•	มี meta (zoom, pan, selection, graphId) ด้วยไหม?
	2.	เขียนโน้ตสรุป behavior ปัจจุบัน (ใส่ใน MD ของ task นี้):
	•	Stack โครงสร้างยังไง (array, pointer index, max size?)
	•	Undo/Redo มีการ “บันทึกซ้อน” (เรียก saveState ซ้ำ) ไหมเวลา apply state
	•	มี guard flag กัน loop ไหม (เช่น isRestoringState)

Output: สรุป behavior ปัจจุบันแบบสั้น ๆ 10–20 บรรทัดพอ (เพื่อใช้เป็นฐาน refactor)

⸻

2) นิยาม Snapshot มาตรฐาน (Canonical Snapshot)

สร้าง spec สำหรับ “หนึ่ง state ของกราฟ” ที่ Undo/Redo ต้องใช้ให้เหมือนกันทุกจุด

รูปแบบ snapshot (proposal):

{
  graphId: number | string,         // currentGraphId
  cyJson: object,                   // cy.json()
  meta: {
    selectedNodeId: string | null,  // id ของ node ที่เลือก (ถ้ามี)
    selectedEdgeId: string | null,  // id ของ edge ที่เลือก (ถ้ามี)
    pan: { x: number, y: number },  // cy.pan()
    zoom: number,                   // cy.zoom()
    timestamp: number               // Date.now() (optional)
  }
}

สิ่งที่ต้องทำ
	1.	เพิ่ม helper ใน graph_designer.js:

function buildGraphSnapshot() { ... }
function restoreGraphSnapshot(snapshot) { ... }

	•	buildGraphSnapshot():
	•	อ่านจาก cy:
	•	cy.json()
	•	selection ปัจจุบัน
	•	cy.pan(), cy.zoom()
	•	currentGraphId
	•	restoreGraphSnapshot(snapshot):
	•	cy.json(snapshot.cyJson)
	•	apply pan/zoom
	•	restore selection
	•	call helper ที่จำเป็น เช่น:
	•	clearPropertiesPanel()
	•	updateStartFinishToolbarState()
	•	updateUndoRedoButtons()
	•	graphStateManager.setModified() (ตาม logic ใหม่ด้านล่าง)

	2.	ยังไม่ต้องเปลี่ยนการเรียกใช้งานจริงในขั้นตอนนี้ แค่มี helper ให้พร้อม

⸻

3) ปรับ GraphHistoryManager ให้ใช้ Snapshot เดียวกัน

เป้าหมาย: ให้ GraphHistoryManager กลายเป็น “generic snapshot stack” ที่ไม่รู้รายละเอียด cytoscape โดยตรง

สิ่งที่ต้องทำในไฟล์ HistoryManager
	1.	เปลี่ยนโครงสร้าง internal ให้เก็บ snapshot ตาม spec ข้างบน:

this._stack = [];
this._index = -1;
this._baselineIndex = 0; // optional: สำหรับเช็ค isModified


	2.	API ที่ต้องรองรับ:

push(snapshot)          // หรือ pushState(snapshot)
undo() => snapshot|null
redo() => snapshot|null
clear()
canUndo() => boolean
canRedo() => boolean
markBaseline()          // สำหรับ “ state ที่ save แล้ว ”
isModified() => boolean // index !== baselineIndex


	3.	ระวังไม่ให้ undo() / redo() ไปเรียก saveState() โดยอ้อม:
	•	undo()/redo() ต้องคืนค่า snapshot เท่านั้น
	•	การ apply ลง cytoscape ต้องทำใน graph_designer.js ผ่าน restoreGraphSnapshot()
	•	เพิ่ม flag เช่น this._isRestoring = true ถ้าจำเป็น เพื่อให้ฝั่ง UI ไม่เผลอ saveState() ตอน restore

มี test เล็ก ๆ ในคอนโซลได้ เช่น สร้าง manager เปล่า ๆ แล้ว push/undo/redo ดู stack เป็นไปตามคาด

⸻

4) ผูก Undo/Redo ใน graph_designer.js ให้เรียบง่าย + ไม่วน

เป้าหมาย: ให้ flow เป็นแบบนี้เท่านั้น
	•	เวลา user ทำอะไรเปลี่ยนกราฟ → saveState() → graphHistoryManager.push(snapshot)
	•	เวลา user กด Undo / Redo:
	•	เรียก graphHistoryManager.undo() / redo()
	•	ได้ snapshot กลับมา
	•	restoreGraphSnapshot(snapshot)
	•	ห้าม saveState() ระหว่าง undo/redo

สิ่งที่ต้องทำใน graph_designer.js
	1.	ปรับ saveState():
	•	ใช้แค่:

function saveState() {
    if (!cy || !graphHistoryManager) return;
    const snapshot = buildGraphSnapshot();
    graphHistoryManager.push(snapshot);
    updateUndoRedoButtons();
    graphStateManager.setModified(); // หรือใช้ sync จาก history (ข้อ 2 ด้านล่าง)
}


	•	ห้ามทำอะไรเกี่ยวกับ undo/redo ในฟังก์ชันนี้

	2.	Sync graphStateManager กับ history:
	•	เมื่อโหลดกราฟใหม่ใน handleGraphLoaded():
	•	หลังจาก createCytoscapeInstance() และ saveState() initial:
	•	graphHistoryManager.markBaseline()
	•	หรือมี method graphHistoryManager.setBaselineToCurrent()
	•	ใน updateStatusIndicator / manual save success:
	•	หลังจาก save สำเร็จ:
	•	graphHistoryManager.markBaseline()
	•	graphStateManager.clearModified()
	•	ในทุกครั้งที่ Undo/Redo:
	•	หลังจาก restoreGraphSnapshot():
	•	ถ้า graphHistoryManager.isModified() → graphStateManager.setModified()
	•	ไม่งั้น graphStateManager.clearModified()
	3.	ปรับ Handler ของปุ่ม Undo/Redo:

function handleUndo() {
    if (!graphHistoryManager || !cy) return;
    const snapshot = graphHistoryManager.undo();
    if (!snapshot) return;

    restoringFromHistory = true;
    restoreGraphSnapshot(snapshot);
    restoringFromHistory = false;

    updateUndoRedoButtons();
    syncModifiedFromHistory();
}

function handleRedo() {
    // เหมือน undo แต่เรียก redo()
}

	•	ใน restoreGraphSnapshot() ถ้ามี logic ที่อาจกระทบ saveState() (ผ่าน event listener) ให้เช็ค restoringFromHistory ก่อน

	4.	ป้องกัน saveState() จาก Undo/Redo side-effect
	•	ในจุดที่เรียก saveState() (เช่น dragfree, create node, delete node, เปลี่ยน properties) ให้ห่อด้วย:

if (restoringFromHistory) return; // ข้ามถ้ามาจาก undo/redo
saveState();


	•	ประกาศตัวแปรบนสุดของไฟล์:

let restoringFromHistory = false;



⸻

5) Acceptance Criteria (ต้องผ่านทั้งหมด)
	1.	Behavior Manual Test (สำคัญสุด):
	•	Case 1: เพิ่ม node 3 ตัว → ขยับตำแหน่ง → Undo ย้อนทีละ step → ตำแหน่ง + จำนวน node ย้อนถูกทุกครั้ง → Redo กลับได้ครบ
	•	Case 2: สร้าง edge ระหว่าง node → Undo → edge หาย → Redo → edge กลับมา
	•	Case 3: เปลี่ยนชื่อ node → Undo → ชื่อย้อนกลับ → Redo → ชื่อใหม่กลับมา
	•	Case 4: ทำหลายๆ action สลับกัน (move + rename + add edge) → Undo/Redo ไม่ข้าม step หรือข้ามช็อต
	2.	Modified State / Save Button:
	•	หลังโหลด graph ใหม่ → ปุ่ม Save แสดงว่า “ไม่ dirty” (GraphStateManager isModified = false)
	•	ทำการแก้ไข 1 step → isModified = true
	•	Save manual → isModified = false อีกครั้ง
	•	Undo จนกลับเท่ากับ baseline → isModified = false
	•	Redo ให้มี state ใหม่จาก baseline → isModified = true
	3.	Auto-save / ETag:
	•	Auto-save ยังทำงานเหมือนเดิม (drag node → auto-save icon ทำงาน → ETag update ตามเดิม)
	•	Undo/Redo ไม่ trigger auto-save โดยตัวมันเอง (เว้นแต่มี logic อื่นตั้งใจทำ)
	4.	Tests ที่มีอยู่ต้องยังผ่านทั้งหมด:
	•	ValidateGraphTest.php → 15/15 ผ่าน
	•	AutoFixPipelineTest.php → 15/15 ผ่าน
	•	SemanticSnapshotTest.php → 15/15 ผ่าน (ถ้า logic intent ไม่เปลี่ยน ไม่ต้อง update snapshot)

✅ Task 19.15 — Reachability & Dead-End Detection (SuperDAG Reachability Engine)

Status: Pending
Owner: SuperDAG Core
Purpose: ตรวจสอบว่าใน Graph ไม่มี node ที่ไม่สามารถเข้าถึงได้ / ไม่มีทางออก / ไม่มีทางไปต่อ / ไม่มี infinite loop ที่ไม่ตั้งใจ

⸻

1. Objectives
	1.	สร้างระบบตรวจสอบ Reachability ทั้งหมดใน Graph:
	•	Unreachable node
	•	Orphan nodes (ไม่ถูกเชื่อมเลย)
	•	Nodes ก่อน END ที่ไม่มี outgoing route (dead-end)
	•	Infinite cycles ที่ไม่ตั้งใจ
	2.	แยกแยะระหว่าง:
	•	Dead-end ที่ตั้งใจ (เช่น ReworkSink, ScrapSink)
	•	Dead-end ที่ไม่ตั้งใจ (เช่น QC → Next แต่ลืมต่อ, Operation → ไม่มี edge)
	3.	เพิ่ม Semantic-aware detection:
	•	หาก node มี intent ประเภท sink.expected → ไม่เตือน
	•	หาก node เป็น part of a subflow → ไม่เตือน
	•	หาก node มี merge behavior → ไม่ถือว่า dead-end
	4.	ผนวกรวมเข้ากับ:
	•	GraphValidationEngine
	•	GraphAutoFixEngine
	•	SemanticIntentEngine

⸻

2. Work Items

2.1 Build Reachability Analyzer (new class)

ไฟล์ใหม่: source/BGERP/Dag/ReachabilityAnalyzer.php

ความสามารถ:
	•	BFS/DFS จาก START node
	•	เก็บ visited / unvisited nodes
	•	ตรวจสอบ node ที่ reachable แต่เป็น dead-end
	•	ตรวจสอบ unintentional cycles

Output:

[
   'unreachable_nodes' => [...],
   'dead_end_nodes' => [...],
   'cycles' => [...]
]


⸻

2.2 Integrate into GraphValidationEngine

เพิ่ม module ใหม่ในขั้นตอน validate:

$reachability = $this->reachabilityAnalyzer->analyze($nodes, $edges);
$this->applyReachabilityRules($reachability, $intents);

Rules:
	1.	Unreachable Node ⇒ Error
	2.	Dead-end Node ⇒ Warning/ Error ตาม intent
	3.	Cycle Node ⇒ Warning (unless intentional loop)

⸻

2.3 Semantic Mapping Rules

เพื่อไม่ให้เตือนเกินความจำเป็น:
	•	ถ้า node.type = ReworkSink / ScrapSink → dead-end = OK
	•	ถ้า node.intent = endpoint.expected → OK
	•	ถ้า node อยู่ใน parallel split ที่รอ merge → OK
	•	ถ้าเป็น sub-graph entry block → OK

⸻

2.4 Add AutoFix for Dead-End Nodes

ใน GraphAutoFixEngine:
	•	ถ้า dead-end ไม่ตั้งใจ → ทำ fix:
	•	เสนอ “Add End Node”
	•	เสนอ “Add Else Edge”
	•	เสนอ “Mark as Sink Node”
	•	ทุก fix ต้องมี risk score:
	•	auto หากชัดเจน (intent = rework / scrap)
	•	suggest หากไม่ชัด
	•	disabled หากเสี่ยงสูง

⸻

2.5 UI Updates

GraphDesigner
	•	เพิ่ม dead-end badge:
	•	🔚 สำหรับ dead-end
	•	🚫 สำหรับ unreachable
	•	เพิ่ม section ใหม่ใน Validate Modal:
	•	“Reachability Issues”
	•	แสดง list node + intent badges

Autofix Modal
	•	แสดง Fix suggestions จาก reachability analyzer

⸻

3. Acceptance Criteria

Requirement	Status
Detect unreachable nodes	☐
Detect dead-end nodes	☐
Detect cycles	☐
Semantic-aware (SINK / ScrapSink / subflow exempt)	☐
Autofix สามารถแก้ dead-end	☐
UI แสดงผล reachability	☐
ไม่มี false positive	☐
ไม่มี fallback ไป validation เก่า	☐


⸻

4. Output After Task 19.15

หลังจากเสร็จงาน:
	•	GraphDesigner จะรู้ทันทีว่าส่วนไหนของ DAG ถูกสร้างผิด
	•	ผู้ใช้จะไม่สามารถสร้างเส้นทางตันที่พัง execution ได้
	•	ระบบรู้ว่า dead-end ไหน “ตั้งใจ” / “ไม่ตั้งใจ”
	•	Autofix สามารถ fix ให้เองได้
	•	Routing Graph จะไม่สามารถอยู่ในสถานะพังเชิงโครงสร้างได้อีกเลย
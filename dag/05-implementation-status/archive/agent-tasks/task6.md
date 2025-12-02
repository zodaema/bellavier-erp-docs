✅ Task 6 — Operator Availability Fail-Open Logic

🎯 Objective

ปรับปรุง AssignmentEngine::filterAvailable() (เฉพาะ branch is_available + unavailable_until เท่านั้น)
เพื่อรองรับกรณีที่ table operator_availability ไม่มี row สำหรับ candidate ใดเลย
และทำให้ระบบ fail-open (คืน candidate เดิม) ตาม business logic ที่ต้องการ
โดยไม่กระทบ schema อื่นหรือ flow อื่น

⸻

📌 Background

ปัจจุบัน filterAvailable() ตรวจ schema ของ table operator_availability แล้วพบว่าเป็นแบบ:
	•	มี id_member
	•	มี is_available
	•	มี unavailable_until

จึงเข้า branch:

is_available + unavailable_until schema

แต่ปัญหาคือ:

❗กรณี table ว่าง (ไม่มี row เลย)

Query ที่ filter candidate เช่น:

SELECT id_member
FROM operator_availability
WHERE id_member IN (...)

→ ได้ผลลัพธ์ = 0 rows
→ intersect กับ candidate → เหลือ 0 คน
→ AssignmentEngine บังคับให้ “ไม่มีใคร available” ทั้งที่ไม่ควร

แต่ใน business logic ต้องการ:

ถ้ามี table แต่ไม่มีข้อมูลใด ๆ = ระบบยังไม่เริ่มใช้งาน availability → ถือว่า “ทุกคนว่าง” → fail-open

⸻

🧭 Requirements (Agent MUST follow)

1) จำกัดขอบเขตสิ่งที่อนุญาตให้แก้ไข

Agent ต้องแก้เฉพาะใน:

source/BGERP/Service/AssignmentEngine.php
→ เฉพาะเมธอด filterAvailable()
→ เฉพาะ branch schema “is_available + unavailable_until”

❌ ห้ามแก้ JobCreationService
❌ ห้ามแก้ flow อื่น
❌ ห้ามแก้ database schema
❌ ห้ามเพิ่ม class ใหม่
❌ ห้ามแก้ branch schema อื่น (เช่น is_active, status)

⸻

2) ต้องเพิ่ม fail-open logic 2 ชั้น (dual fallback)

2.1 Fail-open ชั้นที่ 1

ถ้า operator_availability ทั้ง table ว่าง:

SELECT COUNT(*) FROM operator_availability

ถ้าค่า = 0 → return $candidateIds ทันที

Log:

[AssignmentEngine] filterAvailable: operator_availability empty, using fail-open (keep all candidates)


⸻

2.2 Fail-open ชั้นที่ 2

ถ้า table มีข้อมูล แต่ ไม่มี row สำหรับ candidate ใดเลย

ตัวอย่าง SQL ที่ตรวจสอบ row ของ candidate:

SELECT id_member
FROM operator_availability
WHERE id_member IN (candidate list)
LIMIT 1

ถ้าไม่มี row กลับมา:

→ ถือว่า “candidate ยังไม่ถูก config ในระบบ” → fail-open
→ return $candidateIds เช่นกัน

Log:

[AssignmentEngine] filterAvailable: no availability rows for candidates, fail-open


⸻

3) ตัวอย่าง PSEUDO CODE (ตัวอย่างเท่านั้น ห้ามเขียนทับตรง ๆ)

Agent ต้องเข้าใจว่านี่เป็น ตัวอย่าง ไม่ใช่โค้ดจริง

// Stage 1 fail-open
$total = SELECT COUNT(*) FROM operator_availability;
if ($total === 0) {
    return $candidateIds; // keep all
}

// Stage 2 fail-open
$anyRow = SELECT id_member FROM operator_availability WHERE id_member IN (...) LIMIT 1;
if (!$anyRow) {
    return $candidateIds; // keep all
}

// Then do actual filtering using is_available + unavailable_until
$availableIds = [...]; // query
$filtered = intersect($candidateIds, $availableIds);
return $filtered;


⸻

4) Logging Requirements

ต้องเพิ่ม log ต่อไปนี้ เท่านั้น:

เมื่อ table ว่าง:

[AssignmentEngine] filterAvailable: operator_availability empty, using fail-open (keep all candidates)

เมื่อไม่มี row ของ candidate:

[AssignmentEngine] filterAvailable: no availability rows for candidates, fail-open

ไม่ต้อง log ซ้ำหรือเพิ่ม logging ที่ไม่จำเป็น

⸻

5) ห้ามเปลี่ยน behavior ของ schema อื่น
	•	หาก schema เป็น is_active
	•	หรือ schema เป็น status/date
	•	หรือ schema แบบ legacy

→ ต้องไม่แก้ logic เหล่านั้น
→ ต้องไม่แก้ signature เมธอด
→ ต้องไม่เพิ่มพารามิเตอร์

⸻

6) ต้องไม่ทำให้ test เดิมแตก
	•	HatthasilpaE2E_WorkQueueFilterTest ต้องยังผ่านเหมือนเดิม
	•	HatthasilpaAssignmentIntegrationTest (testFilterAvailableWithIsAvailableSchema) ต้องยังเก็บ behavior เดิมหลังมี fail-open

Fail-open ต้องเกิด เฉพาะกรณีไม่มี row เท่านั้น

⸻

📦 Deliverables

Agent ต้องส่งไฟล์ที่แก้ไข:
	•	source/BGERP/Service/AssignmentEngine.php

พร้อม:
	•	commit-style summary
	•	อธิบายจุดที่แก้
	•	ไม่มีโค้ดอื่นนอกเหนือจาก scope ที่อนุญาต

⸻

💡 หมายเหตุสำคัญ (ต้องอ่าน)

อย่า generate โครงสร้าง SQL ใหม่เอง เว้นแต่ตรวจจากโค้ดจริงก่อน
อย่าเดา field name เพิ่มเติมนอกจากที่เห็นใน log
อย่า generate โค้ดทั้งไฟล์ — ให้ patch เฉพาะส่วนที่เกี่ยวข้อง

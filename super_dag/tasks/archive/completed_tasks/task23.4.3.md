
task23.4.3 — ETA Consistency Corrections + Canonical-Aware ETA Comparison + Queue Model Normalization

Phase: 23.4 — ETA System (Advanced ETA Model)
Subphase: 23.4.3 — Fix Logic, Align Dimensions, Normalize Queue Model, Improve Audit Accuracy
Status: Ready-to-implement
Owner: BGERP / DAG Team
Target Files:
	•	source/BGERP/MO/MOEtaAuditService.php
	•	(optional) source/BGERP/MO/MOLoadEtaService.php
	•	(optional) source/BGERP/MO/MOLoadSimulationService.php

⸻

📌 1. Objective

เพิ่มความแม่นยำของระบบ ETA Audit ให้ตรวจจับความผิดปกติได้จริง
โดยแก้ปัญหา 3 จุดที่สำคัญที่สุด:
	1.	Queue Model ไม่สมบูรณ์ → queueConsistency ไม่ทำงานจริง
	2.	ETA vs Canonical เทียบ dimension ผิด (total vs per token)
	3.	Node workload mismatch ผูกผิดที่ (ใช้ qty จาก ETA)

รวมถึงเพิ่ม small optimization & caching เพื่อเตรียมเข้าสู่ 23.4.4 (ETA Caching Precompute)

⸻

📌 2. Scope

สิ่งที่จะทำใน Task23.4.3

A) Queue Model Normalization
	•	ให้ ETA ส่ง capacity_per_hour_ms ภายใน eta['queue_model']
	•	หรือ fallback load จาก Simulation
	•	AuditService จะ:
	•	ไม่ generate capacity เอง
	•	ใช้ค่า “ของจริง” จาก simulation หรือ ETA
	•	ถ้าไม่มี capacity ให้ skip queueConsistency อย่างถูกต้อง (ไม่พยายามเทียบผิด)

B) Canonical-Aware ETA Comparison

แก้ dimension mismatch:
	•	canonical: per-token duration
	•	ETA: total duration (execution_ms)

🎯 ต้อง normalize โดยใช้:

perTokenEta = execution_ms / qty
compare perTokenEta ↔ canonicalStats.avg_ms / p90_ms

C) Node Workload Comparison Correction

simulation workload = simulation node data
eta workload = eta node data

ไม่ใช้ qty จาก ETA อีกต่อไป
แต่ใช้:
	•	simulation → $node['total_workload_ms']
	•	eta → $etaNode['total_workload_ms']

D) Add Canonical Stats Cache

เพื่อเตรียมห้องเครื่องก่อนการทำงานใน 23.4.4

⸻

📌 3. Patch List (ต้องแก้ลงในโค้ด)

✅ 3.1 Patch: extractQueueModelFromEta()

เติม capacity_per_hour_ms ลงมาให้ถูกต้อง:

ถ้า ETA มีให้ใช้ของ ETA
ถ้า ETA ไม่มี → ดึงจาก SimulationEngine (ต้องเพิ่ม parameter ส่งเข้ามา)

ถ้าไม่เจอ capacity เลย → mark queueModel with capacity_available=false

⸻

✅ 3.2 Patch: compareEtaAndCanonical() — Per Token Comparison

แก้จากเดิมที่ใช้ execution_ms (total) ไปเปรียบเทียบ canonical (per token)

ใหม่:

$qty = max(1, (int)($eta['qty'] ?? $mo['qty'] ?? 1));
$perTokenEta = $executionMs / $qty;

if ($avgMs > 0 && $perTokenEta < $avgMs * 0.7) {
   $results['node_drifts'][] = [...];
}

if ($p90Ms > 0 && $perTokenEta > $p90Ms * 2) {
   $results['node_drifts'][] = [...];
}


⸻

✅ 3.3 Patch: compareSimulationAndEta() — Workload Comparison

แก้เป็น:

$simWorkload = $node['total_workload_ms'] ?? null;
$etaWorkload = $etaNode['total_workload_ms'] ?? null;

แทนการใช้ qty-based calculation

⸻

✅ 3.4 Patch: Canonical Stats Cache

เพิ่มใน class:

private $canonicalStatsCache = [];

และใน getter:

$key = "$productId:$routingId:$nodeId";
if (isset($this->canonicalStatsCache[$key])) {
    return $this->canonicalStatsCache[$key];
}

เพื่อให้ AuditService เร็วขึ้นมาก

⸻

📌 4. Acceptance Criteria

⭐ Primary
	•	Queue Model consistency ทำงานได้จริง (ไม่ silent fail)
	•	ETA vs Canonical เทียบ dimension ถูกต้อง
	•	Workload mismatch ไม่ขึ้นหลอนอีก
	•	ETA Audit สามารถ detect inconsistencies ได้เที่ยงตรงขึ้นอย่างน้อย 5 เท่า

⸻

📌 5. Developer Notes for Cursor

ใส่ใน prompt ให้ Agent ใช้โดยตรง:

Implement task23.4.3:

1. Normalize queue model inside MOEtaAuditService:
   - Use queue_model from ETA if provided
   - Else fallback to simulation’s station_load
   - If no capacity info → mark queueConsistency = SKIPPED

2. Fix ETA vs Canonical comparison:
   - Convert ETA execution_ms to per-token duration (divide by qty)
   - Compare per-token ETA vs avg_ms and p90_ms

3. Fix workload mismatch:
   - Use simulation node’s total_workload_ms
   - Use ETA node’s total_workload_ms
   - Remove dependency on eta['qty'] for workload check

4. Add canonicalStatsCache for getCanonicalDurationStatsForNode()

Modify:
- source/BGERP/MO/MOEtaAuditService.php
- source/BGERP/MO/MOLoadEtaService.php (only if needed)
- source/BGERP/MO/MOLoadSimulationService.php (only if needed)

Strict patching. Do not modify unrelated code.


⸻

📌 6. Test Plan

TC-A1: Queue Model Working
	•	ทำ simulation ให้ station_load ต่างกัน
	•	ตรวจว่า AuditService ให้ warning ปรับคิวชัดเจน

TC-A2: Canonical vs ETA
	•	ETA execution_ms = 100000 ms
	•	qty = 50
	•	canonical avg_ms = 1500
	•	perTokenEta = 2000 ms → ต้อง detect drift

TC-A3: Workload mismatch
	•	simulation workload = 2,000,000
	•	ETA workload = 3,500,000
	•	ต้อง detect workload drift

⸻

📌 7. Output

หลัง patch เสร็จ:
	•	ETA Audit หน้า dev tool จะแสดงผลแม่นขึ้นมาก
	•	การแจ้งเตือนคิวและ drift จะ “ตรงประเด็น”
	•	อนาคตสามารถนำข้อมูลนี้ไป feed ให้:
	•	Monitoring Dashboard
	•	Predictive Delay Alerts (Phase 24)
	•	AI Workload Balancing (Phase 25)

⸻
# Task 23.4.6 — ETA Self-Validation Routine + Monitoring Dashboard

## 1. Objective
เพิ่ม Self-Validation Layer ให้ ETA System เพื่อตรวจจับความผิดปกติแบบอัตโนมัติ และสร้าง Monitoring Dashboard (internal-only) สำหรับดู ETA Health แบบรวมศูนย์ โดยใช้ข้อมูลจาก:

- ETA Cache
- ETA Simulation
- ETA Audit
- Canonical Timeline Stats
- Work Center Load Stats

เป้าหมายคือทำให้ระบบ ETA:
- สามารถจับความผิดปกติได้เอง
- สามารถวิเคราะห์สาเหตุระดับ node/stage/station
- สามารถคาดการณ์ risk และ deviation
- มีหน้า Dashboard สำหรับทีม Production และ Management

---

## 2. Scope
### A. ETA Self-Validation Routine (Automated)
ระบบจะประมวลผล ETA Health ทุก 15 นาที (CLI cron) โดยตรวจสอบ:

#### 1) Cache-Level Validation
- cache hit rate ต่ำกว่า threshold ( < 60% )
- ค่าใน cache mismatch กับ actual routing version
- payload schema mismatch
- ETA envelope invalid (best > normal หรือ normal > worst)
- ETA time unrealistic (0, negative, > 30 days)

#### 2) Simulation vs ETA Drift
- simulation_ms ต่างจาก eta_normal_ms > threshold
- drift_ms > งานที่ผ่านมาย้อนหลัง (canonical avg)

#### 3) Node-Level Consistency
- node execution_ms ต่ำผิดปกติ (underflow)
- node waiting_ms สูงผิดปกติ (queue jam)
- node workload mismatch กับ work_center load จริง

#### 4) Stage-Level Consistency
- stage time multiply effect > 40%
- risk_factor spike

#### 5) Canonical Timeline Sync
- canonical avg drift > 50% จาก ETA avg
- missing canonical data (insufficient)

ผลลัพธ์: บันทึกชุดของ alerts → `mo_eta_health_log`

---

### B. ETA Monitoring Dashboard (Internal)
ไฟล์ใหม่: `tools/eta_monitor.php`

#### Features:
- Global ETA Health Overview (cards)
  - cache hit %
  - avg drift ms
  - node consistency %
  - stage consistency %
  - canonical sync %

- Health Alerts Table
  - timestamp
  - severity
  - mo_id
  - problem_code
  - drift_ms
  - recommended_action

- MO Detail View (link to ETA Audit)
  > tools/eta_audit.php?mo_id=123

- Station Load Insights
  - real load vs ETA predicted load

- Filter:
  - severity
  - date range
  - mo_id
  - problem type

---

## 3. Database
สร้าง migration ใหม่:

### `mo_eta_health_log`
| field | type | notes |
|-------|--------|--------|
| id | bigint | PK |
| org_id | int | tenant |
| mo_id | bigint | nullable |
| severity | tinyint | 1=info, 2=warning, 3=error |
| problem_code | varchar(100) | เช่น CACHE_DRIFT, NODE_INCONSISTENCY |
| expected_ms | bigint | nullable |
| actual_ms | bigint | nullable |
| drift_ms | bigint | nullable |
| details_json | json | compact payload |
| created_at | datetime | |

Indexes:
- org_id, severity
- created_at DESC

---

## 4. Services

### A. `MOEtaHealthService.php` (NEW)
ประมาณ 350–500 lines

#### Methods:
- `runFullScan()` — ใช้ใน cron
- `validateCache()` 
- `validateDrift()`
- `validateNodeConsistency()`
- `validateStageConsistency()`
- `validateCanonicalSync()`
- `aggregateHealthSummary()`
- `logAlert()`

---

### B. Cron Script
ไฟล์: `cron/eta_health_cron.php`

รัน:

php cron/eta_health_cron.php --org=maison_atelier

รันทุก 15 นาที

---

## 5. API Integration

### A. Add endpoint for dashboard
ไฟล์: `source/mo_eta_api.php`
เพิ่ม action:

?action=health-summary

Response:

{
“cache_hit_rate”: 0.84,
“avg_drift_ms”: 2280,
“node_consistency”: 0.91,
“stage_consistency”: 0.88,
“canonical_sync”: 0.79
}

Backward compatible.

---

## 6. Developer Notes
- Dashboard เป็น dev tool (ไม่ deploy ให้ user)
- Health routine ไม่ควร throw exception → log only
- ETA Cache ควร refresh เมื่อ drift_ms > 40%
- drift calculations ควร normalize ด้วย qty

---

## 7. Prompt สำหรับ Agent (สำคัญ)
ให้แทรกใน Cursor:

You are implementing Task 23.4.6.
Follow these requirements strictly:
	1.	Create new files:
	•	source/BGERP/MO/MOEtaHealthService.php
	•	cron/eta_health_cron.php
	•	tools/eta_monitor.php
	•	database/tenant_migrations/0009_mo_eta_health_log.php
	2.	Modify:
	•	source/mo_eta_api.php → add new “health-summary” endpoint
	3.	Ensure:
	•	No breaking changes to existing ETA API
	•	All calculations must use normalized ms
	•	All logs compact JSON only, no huge payloads
	•	Cron safe: no fatal errors; catch all exceptions
	•	Dashboard lightweight, Bootstrap 5 minimal
	•	No external assets, only inline styling
	4.	Run syntax validation after generation.

---

## 8. Deliverables
- New migration
- New service
- New cron runner
- New monitoring dashboard UI
- Updated API endpoint
- Documentation: `task23_4_6_results.md`

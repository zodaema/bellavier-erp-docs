

# Task 23.4.2 — ETA Audit Tool (Audit + Debugging + Cross-Check Layer)
**Phase 23 — MO ETA Engine (Advanced ETA Model B)**  
**Author: ChatGPT — Bellavier Protocol v2.0**  
**Status: Blueprint Ready (for AI Agent Implementation)**  
**Length: ~500 lines**

---

# 0. PURPOSE

ETA v1.1 (Task 23.4.1) เพิ่มทั้ง Queue Model, Stage Envelope และ Node-Level ETA fields ทำให้ระบบซับซ้อนขึ้น และจำเป็นต้องมี **“ETA Audit Tool”** เพื่อ:

- ตรวจสอบว่า ETA คำนวณถูกต้องหรือไม่  
- ตรวจสอบข้อมูลจาก Simulation Layer & Canonical Engine ว่าตรงกันไหม  
- หา outliers เช่น node ไหน delay ผิดธรรมชาติ  
- ตรวจสอบ bottleneck ที่โมเดลทำนายผิด  
- Debug ง่ายขึ้นในทีม Dev  
- ใช้สำหรับ Machine Learning Training (Phase 27–28)

Task 23.4.2 เป็นเครื่องมือภายใน (dev-only) และช่วยทำให้ ETA Engine แข็งแรงขึ้นมาก

---

# 1. GOALS OF THIS TASK

### 🎯 Goal A — Cross-Check 3 Sources
Cross-validate ข้อมูลจาก:
1. Simulation → node_projection, station_load, total_workload_ms  
2. ETA Engine → node_timeline, stage_timeline, ETA summary  
3. Canonical Engine → duration, p50/p90, event structure  

Audit Tool จะเช็ค consistency ระหว่าง 3 layers นี้

---

### 🎯 Goal B — Identify ETA Errors & Red Flags
ตรวจสอบปัญหาต่อไปนี้:
- node_start_at < station_available_at  
- execution_ms ไม่สอดคล้อง canonical avg_ms  
- overflow_ms < 0 (ไม่น่าจะเกิดขึ้น)  
- best/normal/worst ETA ไม่เรียงลำดับ  
- stage_complete_at < previous stage  
- delay_factor < 0 หรือ > 3.0  
- canonical sample_size ต่ำผิดปกติ (underfitting)  
- queue_ms มากเกิน (model mismatch)

---

### 🎯 Goal C — Build Dev Tool Interface
สร้าง dev tool ที่เข้าถึงผ่าน:

```
/tools/eta_audit.php?mo_id=1234
```

UI ใน Browser:
- Summary Cards  
- Node Table (timeline, wait, delay, canonical)  
- Stage Timeline  
- Bottleneck Analysis  
- Consistency Check Results  
- Export JSON  

---

# 2. FILES TO CREATE

### 2.1 `/tools/eta_audit.php`
Standalone Dev Tool script  
Requires:
- MOLoadSimulationService  
- MOLoadEtaService  
- TimeEventReader  
- CanonicalEventIntegrityValidator (optional mode)

Outputs HTML + optional JSON.

---

### 2.2 `/source/BGERP/MO/MOEtaAuditService.php`
Service class (approx 300–400 lines):

Methods:
- `compareSimulationAndEta()`
- `compareEtaAndCanonical()`
- `computeAlertLevel()`
- `detectOutlierNodes()`
- `summarizeStageConsistency()`
- `validateEtaEnvelope()`
- `exportJson()`

---

# 3. IMPLEMENTATION SPEC

## 3.1 MOEtaAuditService — Methods Detail

### (1) compareSimulationAndEta()
ตรวจสอบ consistency ระหว่าง Simulation กับ ETA:

- node count mismatch  
- mismatch duration_per_token_ms  
- mismatch total_workload_ms  
- station load mismatch  
- queue_ms mismatch (tolerance 10–15%)  

Result structure:

```
[
  'node_consistency' => [...],
  'station_consistency' => [...],
  'queue_consistency' => [...],
  'warnings' => [...],
  'errors' => [...],
]
```

---

### (2) compareEtaAndCanonical()
เทียบ ETA กับ canonical events:

ปัญหาที่ตรวจ:
- execution_ms < canonical avg (ผิดปกติ)  
- p90 > execution_ms × 2  
- sample_size < 3 → underfitting  
- canonical avg_ms = null → fallback usage  

---

### (3) detectOutlierNodes()
Nodes ที่มีค่า:
- delay_factor > 1.5  
- waiting_ms > 10% ของ execution_ms  
- canonical variance สูงมาก (p90/p50 > 1.8)  
- total_workload_ms สูงผิดปกติ  

ให้ flag เป็น:

- `HIGH_DELAY`
- `HIGH_QUEUE`
- `VARIANCE_SPIKE`
- `INSUFFICIENT_DATA`

---

### (4) summarizeStageConsistency()
ตรวจ stage timeline:

- stage_start_at < previous_complete_at → ERROR  
- stage_complete_at ล้น 24 ชม. (rare)  
- stage risk factor > 1.0 → red flag  

---

### (5) validateEtaEnvelope()
ตรวจว่า ETA summary ถูกต้อง:

```
eta_best <= eta_normal <= eta_worst
```

ถ้าไม่ใช่ → ERROR

---

### (6) exportJson()
ส่งออกข้อมูลทั้งหมดเป็น JSON ให้ Frontend หรือ Tools อื่นใช้ต่อ

---

# 4. DEV TOOL UI STRUCTURE (eta_audit.php)

Page Sections:

### (1) Header
- MO ID  
- Product Code  
- Qty  
- ETA summary

### (2) Simulation Snapshot
- Node Projection Table  
- Station Load  
- Worker Load  
- Bottlenecks  

### (3) ETA Snapshot
- Node Timeline Table  
- Stage Timeline  
- Envelope Summary  

### (4) Canonical Stats
- Table: node_id, avg, p50, p90, sample_size

### (5) Consistency Checks
Color coding:
- Green = OK  
- Yellow = Warning  
- Red = Error  

### (6) Outlier Report
แสดง nodes ที่เป็น delay driver

### (7) Export JSON Button

---

# 5. PATCH LOGIC FOR AGENT

ใน `task23.4.2_agent_prompt.md` ให้ขึ้นด้วย:

```
Goal: Implement ETA Audit Tool for Task 23.4.2
Files:
- tools/eta_audit.php (new)
- source/BGERP/MO/MOEtaAuditService.php (new)

Requirements:
- Compare ETA vs Simulation vs Canonical
- Detect inconsistencies (node, stage, station, queue)
- Compute delay/outlier nodes
- Show dev HTML UI
- Export JSON if ?json=1
- No DB writes allowed
```

---

# 6. SCOPE LIMITATIONS

ไม่ทำ:
- Frontend Vue UI (Phase 24)
- ML-based ETA correction (Phase 28)
- Multi-MO comparison
- Cross-MO batch audit

ทำเฉพาะ:
- Dev Tool  
- Debugging Layer  
- Consistency Scanner  

---

# 7. WHAT COMES AFTER 23.4.2

### 23.4.3 — ETA Result Caching  
- Cache 10–30 นาที  
- ลดเวลาคำนวณ 80–90%  

### 23.4.4 — ETA Confidence Score  
- ให้คะแนนความมั่นใจของ ETA  
- ใช้ canonical density + queue pressure  

---

# END OF FILE
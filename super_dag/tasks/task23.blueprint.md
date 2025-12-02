# Task 23 — Master Order (MO) Engine v1.5  
## Productionization Layer (Post–Self-Healing Era)

> **Objective**  
> ยกระดับระบบ MO (Legacy v2) ให้กลายเป็น “Productionization Layer” ที่เชื่อม  
> MO → Routing Graph Instances → Tokens → Canonical Timeline (Phase 22)  
> โดยไม่แก้ไข Business Rules เดิมของ `mo.php`  
> และเพิ่มเฉพาะ service layer + analytics layer + simulation layer เท่านั้น.

---

# 1. Core Principles (Non‑Negotiable)

1. **MO Legacy = Source of Truth**  
   - ห้ามแก้ lifecycle: draft → planned → in_progress → qc → done  
   - ห้ามแก้ business rules (plan/start/stop/cancel)

2. **start_production() = ทางเดียวที่ spawn token ได้**  
   - Task 23 จะไม่สร้าง backdoor spawn token
   - ต้องใช้ `JobCreationService::createDAGJob()` ตาม flow เดิมเท่านั้น

3. **Hatthasilpa โดยออกแบบ จะไม่ผูกกับ MO**  
   - MO = classic/oem line เท่านั้น  
   - Hatthasilpa ใช้ Job Ticket system

4. **Routing Graph Binding ใช้ระบบเดิมทั้งหมด**  
   - RoutingSetService  
   - ProductGraphBindingHelper  
   - id_routing_graph requirement  
   - Task 23 ทำงาน “เหนือ” ไม่ใช่ “แทน” Layer นี้

5. **Phase 22 เป็น Timeline Canon ของ Token Layer**  
   - Task 23 ต้องใช้ข้อมูลจาก:
     - flow_token  
     - token_event  
     - canonical events  
     - duration reconstruction engine  
     - repair orchestrator  

   เพื่อคำนวณ:
   - MO progress  
   - MO ETA  
   - MO workload  
   - rework impact

---

# 2. Scope Overview

Task 23 จะมีทั้งหมด 6 โมดูลหลัก:

1. **23.1 — MO Creation Extension Layer**  
2. **23.2 — Routing Assignment & Instance Binding Layer**  
3. **23.3 — Workload Planning & Load Simulation**  
4. **23.4 — MO ETA Engine (Timeline-Aware)**  
5. **23.5 — Rework Loop Integration**  
6. **23.6 — MO Reporting Layer & Analytics**

---

# 3. 23.1 — MO Creation Extension Layer  
### Goal
เพิ่ม “ความฉลาด” ให้การสร้าง MO โดยไม่แตะ API เดิม

### Sub‑Features
1. Suggest:
   - product → routing  
   - routing → expected node count  
   - estimated time per unit  

2. Warn:  
   - missing routing  
   - wrong routing version  
   - incompatible routing (product mismatch)  

3. Auto‑fill:
   - uom  
   - expected duration estimate  
   - expected WIP size  

4. Validate:
   - MO quantity < routing capability  
   - production_type == classic  
   - product graph binding exists  

---

# 4. 23.2 — Routing Assignment & Instance Binding Layer  
### Goal
ทำให้ MO เมื่อ start_production จะ “ปล่อยงานออกมา” ได้อย่าง deterministic

### Requirements
1. ใช้ `ProductGraphBindingHelper` (ของเดิม)  
2. ถ้าผู้ใช้ override routing ต้องตรวจ permission: `mo.override.graph`  
3. ต้องสร้าง GraphInstance แบบ 1-instance ต่อ 1 MO  
4. สร้าง token แบบ canonical-ready  
5. instance metadata:
   - id_graph_instance  
   - id_routing_graph  
   - mo_id  
   - qty  
   - version  

---

# 5. 23.3 — Workload Planning & Load Simulation  
### Goal
ให้ระบบคำนวณว่า “จะเกิดอะไรขึ้นต่อไปในโรงงานถ้า MO ใบนี้เริ่มเดินงาน”

### Inputs
- จำนวน token ต่อ node  
- average actual_duration_ms ของทุก node ตาม canonical timeline  
- worker capacity  
- station capacity  
- work_center capability  

### Outputs (ใหม่)
1. Station Load Simulation  
2. Worker Load Forecast  
3. Expected bottlenecks  
4. Scheduling prediction (8 ชม. ถัดไป)

---

# 6. 23.4 — MO ETA Engine (Timeline-Aware)  
### Goal
คำนวณ ETA ของ MO แบบละเอียด โดยใช้ engine ของ Phase 22

### Must Use
- TimeEventReader  
- TimelineReconstructionEngine  
- NodeDuration statistics  
- flow_token.start_at  
- flow_token.completed_at

### Deliverables
1. ETA per MO  
2. ETA per node group  
3. ETA per routing stage  
4. Delay detector  
5. SLA propagation model (QC → MO complete)

---

# 7. 23.5 — Rework Loop Integration  
### Goal
ทำให้ระบบรองรับการ rework ได้ตามความจริงของโรงงาน  

### Rework Types

1. **Unit‑Level Rework**  
   - token เฉพาะจุดต้องทำใหม่  
   - MO qty ไม่เปลี่ยน  
   - ต้อง insert rework token

2. **Batch Rework**  
   - token ทั้ง node group fail  
   - re-instance เฉพาะ node นั้น  
   - timeline ควรเชื่อม canonical ต่อได้

3. **Full‑MO Rework**  
   - MO fail ทั้งชุด  
   - ต้อง spawn instance ใหม่  
   - เก็บ historical instance

---

# 8. 23.6 — MO Reporting Layer & Analytics  
### Dashboard
- MO list with:
  - progress %
  - ETA
  - current bottleneck
  - WIP tokens
  - total actual vs predicted duration
  - delay cause analysis

### Reports
1. MO Performance Report  
2. Station Load Report  
3. Worker Productivity via Canonical Timeline  
4. Routing Effectiveness Report  
5. Rework Impact Report  

---

# 9. Data Model (Add‑On Only)
### ไม่แก้ตาราง MO เดิม  
เพิ่มแต่ metadata tables:

```
mo_eta_cache
  - mo_id
  - eta_at
  - predicted_finish_at
  - recomputed_at
  - engine_version

mo_load_simulation_cache
  - mo_id
  - simulation_json
  - updated_at
```

---

# 10. Integration with Phase 22  
### ทุกอย่างต้องอ่าน canonical timeline ผ่าน service layer:

- TimeEventReader  
- LocalRepairEngine  
- ReconstructionEngine  
- RepairOrchestrator  
- CanonicalEventIntegrityValidator

Task 23 ห้ามอ่าน event table ตรง

---

# 11. API Spec (New Endpoints)

### /mo/eta (GET)
Return ภาพรวม ETA ของ MO

### /mo/load-simulation (GET)
แสดง station load, worker load, bottleneck

### /mo/rework (POST)
สร้าง unit-level rework instance

### /mo/analytics (GET)
ดึง aggregated metrics

---

# 12. CLI Tools

```
php tools/mo_eta_recalc.php --mo=123
php tools/mo_load_sim.php --mo=123
php tools/mo_reconstruct.php --mo=123
php tools/mo_rework.php --mo=123 --unit=5
```

---

# 13. Test Plan

### Unit Tests
- Routing binding  
- load simulation  
- ETA model  
- rework injection  

### Integration Tests
- MO → start_production → tokens → events → ETA → reports  

### Stress Test
- 1,000 MOs  
- 200,000 tokens  
- 5M canonical events  

---

# 14. Developer Prompt (สำหรับ AI Agent)

```
You are implementing Task 23 — MO Engine v1.5.
You MUST NOT change any logic inside mo.php.
You may ONLY extend via service layer:
  - MOEtaService
  - MOLoadSimulator
  - MOReworkService
  - MOAnalyticsService

Use only TimeEventReader + ReconstructionEngine for timeline data.
Never query token_event directly.

All new code must be placed under:
  source/BGERP/MO/
  tools/mo_*.php
  docs/super_dag/tasks/results/task23_results.md
```

---

# End of Task 23 Blueprint

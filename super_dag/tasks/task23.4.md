# Task 23.4 — MO ETA Engine (Advanced ETA Model v1)
## Stage-level ETA • Node-level ETA • Delay Propagation • Queue Modeling
### Phase 23 — Workload Intelligence Layer

---

# 0. Executive Summary

**Objective:**  
สร้างระบบ ETA (Estimated Time of Arrival) สำหรับ MO ที่ใช้ข้อมูลจริงจาก  
Routing Graph + Canonical Timeline (Phase 22) + Simulation Load (Phase 23.3)  
เพื่อคำนวณเวลาผลิตที่ “แม่นยำระดับงานหัตถศิลป์”  
และรองรับ bottleneck propagation แบบโรงงานจริง

**ผลลัพธ์หลักของ Task 23.4**
1. ETA ของทั้ง MO (Best, Normal, Worst)
2. ETA ราย Stage (Stage Timeline)
3. ETA ราย Node (Node Timeline)
4. Waiting Time Estimation (คิวแต่ละ Work Center)
5. Delay Propagation (คอขวดส่งผล Stage → Stage → MO)
6. API ใหม่ `/mo/eta`
7. รวม Patch จาก Task 23.3 (p90_ms, capacity model, service constructor, code cleanup)

---

# 1. Scope & Non-Scope

## 1.1 In-Scope
- MO ETA Service (ใหม่): `MOLoadEtaService.php`
- Stage timeline โมเดล
- Node timeline โมเดล
- Queue-based delay modeling (แบบ simplified queue)
- p50/p90 propagation
- Integration กับ Load Simulation (23.3)
- API ใหม่: `mo_eta_api.php`
- Patch จาก 23.3 (.1, .2): canonical stats + capacity fix

## 1.2 Out-of-Scope
- ไม่ทำ Scheduling หรือ Rescheduling จริง
- ไม่แตะ Token Lifecycle
- ไม่ปรับสถานะ MO
- ไม่ส่ง Notification
- ไม่ทำ Real-time Refresh (ไว้ Phase 24)

---

# 2. Architecture Overview

```
MO
  → Routing Graph
     → Node List
        → Canonical Duration Stats (Phase 22)
           → Load Simulation (Phase 23.3)
              → Queue Model
                 → Stage ETA Model
                    → MO ETA Summary
```

Components ใหม่:
1. **DurationSelector:** canonical-first selector
2. **QueueModel:** predict waiting time per Work Center
3. **StageEtaModel:** stage-level propagation
4. **NodeEtaModel:** fine timeline
5. **MOEtaEngine:** orchestrate + merge + finalize
6. **API Layer:** route to service

---

# 3. ETA Computation Model

## 3.1 Duration Selector (per node)
Priority:
1. canonical `avg_ms`
2. canonical `p50_ms` (optional flag)
3. fallback: historic_avg
4. fallback: estimated_minutes × 60,000
5. default: 30 minutes

Store also:
- `p90_ms`
- `sample_size`
- `uses_canonical`

---

## 3.2 Queue Model (Work Center)

### หมายเหตุสำคัญ
Bellavier ERP ไม่มีคิวในระบบ token จริงขณะ simulation  
จึงต้องใช้ model จำลอง:

```
waiting_ms = (station_workload_ms / capacity_per_day_ms) × queue_factor
```

Where:
- `station_workload_ms` = workload ของ node ที่ใช้ work center เดียวกัน
- `capacity_per_day_ms` = headcount × work_hours × 3600000
- `queue_factor` = 0.8 (config)

Output:
```
[
  work_center_id => [
    'waiting_ms' => X,
    'capacity_per_day_ms' => Y,
    'current_load_ms' => Z
  ]
]
```

---

## 3.3 Stage ETA Propagation

Routing graph มีลำดับ stage อยู่แล้ว:

```
for stage in stages:
    stage_start_at = max(previous_stage_complete_at, now + waiting_time)
    stage_execution_ms = sum(node_workload_ms for nodes in stage)
    stage_complete_at = stage_start_at + stage_execution_ms
```

Store:
```
stage_timeline = [
  stage => {
    start_at,
    complete_at,
    execution_ms,
    waiting_ms
  }
]
```

---

## 3.4 Node ETA Model

Per node:
```
node_start_at = stage_start_at + cumulative_node_offset
node_complete_at = node_start_at + duration_per_token × qty
```

Store:
```
node_timeline = [
  node_id => {
    stage,
    start_at,
    complete_at,
    duration_per_token_ms,
    total_workload_ms,
    waiting_ms
  }
]
```

---

## 3.5 MO ETA Summary

```
eta_best     = stage[ last_stage ].start_at + sum(p50_ms × qty)
eta_normal   = stage[ last_stage ].complete_at
eta_worst    = eta_normal + (p90_ms × qty × overall_delay_factor)
```

Output JSON:
```
{
  "mo_id": 123,
  "eta": { "best": "...", "normal": "...", "worst": "..." },
  "stage_timeline": [...],
  "node_timeline": [...],
  "canonical_usage": true,
  "bottlenecks": [...]
}
```

---

# 4. Service Specification

Create:
```
source/BGERP/MO/MOLoadEtaService.php
```

## 4.1 Constructor
```
__construct(
    \mysqli $db,
    MOLoadSimulationService $loadSimService
)
```

## 4.2 Public Methods

### (1) computeETA(int $moId): array
Main orchestrator.

### (2) buildNodeDurationTable($mo)
Combine canonical duration + fallback + sample size.

### (3) buildQueueModel($nodeDurations)
Map work_center → waiting_ms

### (4) buildStageTimeline($mo, $nodeDurations, $queueModel)
Propagate each stage.

### (5) buildNodeTimeline($mo, $nodeDurations, $stageTimeline)
Compute each node’s timeline.

### (6) buildSummary($stageTimeline, $nodeTimeline)
Compute MO ETA.

---

# 5. API Design

Create file:
```
source/mo_eta_api.php
```

### Endpoint
```
GET /mo_eta_api.php?action=eta&id_mo=123
```

### Response
```
{
  "mo_id": 123,
  "eta": {
    "best": "2025-01-22 14:30:00",
    "normal": "2025-01-22 18:10:00",
    "worst": "2025-01-23 09:25:00"
  },
  "stage_timeline": [...],
  "node_timeline": [...],
  "canonical_usage": true,
  "bottlenecks": [...]
}
```

### Guard
- must_allow_code('mo.view')
- id_mo required
- only classic line
- routing_graph must exist
- use GET only

---

# 6. Patch Bundle (23.3 → 23.4 Hardening)

## 6.1 p90_ms propagation fix
In `MOLoadSimulationService → computeNodeDurations()`
- include:
```
'p50_ms' => $canonicalStats['p50_ms'] ?? null,
'p90_ms' => $canonicalStats['p90_ms'] ?? null,
```

## 6.2 capacity fix
Rename and correct:
```
capacity_per_day_ms = headcount × work_hours_per_day × 3600000
```

## 6.3 remove unused assistService
Delete property + constructor new

## 6.4 constructor normalization
Both services accept `$tenantDb` (not mysqli directly)

---

# 7. Test Plan

## 7.1 Unit Tests
- Duration selector
- Queue model
- Stage propagation accuracy
- P90 impact
- Bottleneck propagation

## 7.2 Integration Tests
- Real MO with 5–20 nodes
- High workload case (overflow)
- Zero capacity work center

## 7.3 CLI Tool
```
php tools/mo_eta.php --mo=123
```

---

# 8. Developer Prompt (ให้ AI Agent ใช้)

```
Implement Task 23.4 — MO ETA Engine (Advanced ETA v1).

You MUST NOT modify mo.php.
You MAY create/modify only:

  - source/BGERP/MO/MOLoadEtaService.php
  - source/mo_eta_api.php
  - docs/super_dag/tasks/results/task23_4_results.md
  - patches in MOLoadSimulationService according to task23.4.md

ETA model must follow:

  - canonical-first duration logic
  - queue-based waiting model
  - stage-level propagation
  - node-level ETA calculation
  - best/normal/worst-case ETA summary

Make sure to propagate p50_ms / p90_ms from canonical stats.
Use the corrected capacity_per_day_ms formula.
Service constructor must use tenantDb, not raw mysqli.

Follow EXACTLY the specification in task23.4.md.
```

---

# END OF TASK 23.4

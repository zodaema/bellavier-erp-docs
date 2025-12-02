# Task 23.3 — Workload Planning & Load Simulation Engine (v1)
## Station Load • Worker Load • Node-Level Throughput • Routing Projection

> **Objective**  
> ยกระดับระบบ MO ให้สามารถ “จำลองโหลดงานล่วงหน้า” ได้อย่างแม่นยำ โดยใช้ข้อมูลจาก:
> - Routing Graph (structure)
> - Canonical Timeline (Phase 22)
> - Node-level actual duration per product
> - Work Center capabilities
> - MO Quantity + Node count
>
> เพื่อสร้าง:
> - Station Load Simulation (ภายใน 8–24 ชม.)
> - Worker Load Forecast
> - Bottleneck Prediction
> - Node-Level Execution Projection
> - Routing-Based WIP Distribution
>
> ทั้งหมดนี้ **ไม่แตะ MO Legacy** และไม่แตะ token lifecycle — เป็น analytics layer เท่านั้น

---

# 1. Scope & Non-Scope

## 1.1 In-Scope
- New Engine: `MOLoadSimulationService.php`
- Station Load Simulation
- Worker Load Forecast
- Bottleneck Detection
- Node Throughput Projection
- Routing Expansion (token-level estimation)
- API: `/mo/load-simulation`
- Docs: `task23_3_results.md`

## 1.2 Out-of-Scope
- ไม่ทำ scheduling จริง
- ไม่ปรับสถานะ MO
- ไม่ปรับ heuristic ให้ไปแก้ routing
- ไม่แก้ token creation logic
- ไม่แตะ mo.php

---

# 2. High-Level Architecture

```
MO → Routing Graph → Node Count → Canonical Duration Stats
     → (qty multiplier)
         → Node Execution Projection
             → Station Load Projection
                 → Worker Load Projection
                     → Bottleneck Report
```

Components:
1. **Routing Expansion Layer**
2. **Canonical Duration Aggregator**
3. **Work Center Load Engine**
4. **Worker Capacity Model**
5. **Simulation Kernel**
6. **Bottleneck Detector**
7. **MO Projection Dashboard API**

---

# 3. Data Inputs Required

## 3.1 From MO
- id_mo  
- id_product  
- id_routing_graph  
- qty  
- production_type (must = classic)

## 3.2 From Routing Graph
Per node:
- node_id  
- node_type  
- stage  
- work_center_id  
- default_behavior_mode  
- requires_scan / batch flags  
- estimated_duration_ms (fallback)

## 3.3 From Canonical Timeline (Phase 22)
Per node-type:
- avg_actual_duration_ms  
- p50_ms  
- p90_ms  
- sample_size  
From:
- TimeEventReader  
- canonical events  
- reconstructed timelines  

## 3.4 From Work Center
- capacity_per_hour  
- worker_count  
- machine_count  
- operating_hours  
- skill_class (optional)

---

# 4. Simulation Model

## 4.1 Node Execution Projection

For each node:
```
token_per_node = qty
duration_per_token = canonical_avg or historic_avg or fallback
total_workload = token_per_node × duration_per_token
```

Sample output:
```
node_id: 12
node_type: stitch
stage: 3
work_center_id: 5
duration_per_token: 28000 ms
tokens: 50
total_ms: 1,400,000
```

## 4.2 Station Load Simulation

Per work_center:
```
sum(total_workload of all nodes assigned)
required_hours = total_ms / (capacity_per_hour_ms)
```

If shift = 8h:
```
overflow = required_hours - 8
```

## 4.3 Worker Load Forecast
```
required_workers = ceil(total_ms / (shift_hours × 3600000))
```

Consider multi-skill workers:
- If work_center has skill lock → assign only matching workers
- If multi-skill → distribute based on priority

## 4.4 Bottleneck Detector
Rules:
1. work_center_overflow > 20% → BOTTLENECK
2. p90_duration too high → RISK_NODE
3. stage delay propagation:
   - if stage X > stage X-1 by >30% → capacity mismatch

Output:
```
bottlenecks: [
  { work_center: 5, overflow_hours: 1.7 },
  { stage: 3, delay_factor: 1.32 }
]
```

---

# 5. Service Specification (NEW)

Create:
```
source/BGERP/MO/MOLoadSimulationService.php
```

## 5.1 Constructor
```
__construct(
    RoutingGraphService,
    TimeEventReader,
    WorkCenterService,
    MOLoadCacheRepository
)
```

## 5.2 Public Methods

### 1) runSimulation(int $moId): array
Main method.

### 2) simulateRoutingExpansion()
Return full list of nodes × qty.

### 3) computeNodeDurations()
Use canonical-first approach.

### 4) computeStationLoad()
Aggregate by work center.

### 5) detectBottlenecks()

### 6) buildResponse()
Wraps final JSON.

---

# 6. API Design

Create:
```
api/mo/load-simulation.php
```

### Endpoint
```
GET /mo/load-simulation?id_mo=123
```

### Response
```
{
  "mo_id": 123,
  "summary": {...},
  "station_load": [...],
  "worker_load": [...],
  "bottlenecks": [...],
  "node_projection": [...],
  "canonical_usage": true
}
```

### Guard Conditions
- must_allow_code('mo.view')
- MO must exist and be classic line
- id_routing_graph must exist
- Graph must be valid per 23.2 checks

---

# 7. Caching Layer (Optional)

Add table:
```
mo_load_simulation_cache
- mo_id
- simulation_json
- updated_at
```

Cache for 30 minutes.

---

# 8. Test Plan

## 8.1 Unit Tests
- Node expansion correct
- Duration calculation correct
- Station load aggregation correct
- Bottleneck detection logic

## 8.2 Integration Tests
- Real MO with real data
- Routing with cycles (should fail)
- Work center with 0 capacity

## 8.3 CLI Tool
```
php tools/mo_load_sim.php --mo=123
```

---

# 9. Developer Prompt

```
Implement Task 23.3 — Workload Planning & Load Simulation.

You MUST NOT modify mo.php.
You MAY create/modify only:

  - source/BGERP/MO/MOLoadSimulationService.php
  - api/mo/load-simulation.php
  - docs/super_dag/tasks/results/task23_3_results.md

Simulation must use canonical timeline first, historic duration second, fallback third.

Follow the spec in task23.3.md exactly.
```

---

# END OF TASK 23.3

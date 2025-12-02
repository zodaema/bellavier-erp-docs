

# Task 23.2 — MO Assist Hardening & Canonical-Aware Validation
## Routing Deviation Guard + Timeline-Backed Estimates

> **Objective**  
> ยกระดับ MO Assist Layer (จาก Task 23.1) ให้ “แข็งแรงและแม่นยำ” มากขึ้น โดย:
> - ทำให้ routing validation มีความลึก (graph structure, node behavior compatibility, version, binding)
> - ทำให้ estimated time ดึงจาก canonical timeline (Phase 22) อย่างถูกต้อง
> - เสริม error handling, logging, AI trace และ safety guard รอบ mo_assist_api.php
>
> งานนี้จะเป็นการ **Patch เชิงคุณภาพ (Hardening)** สำหรับ:
> - `MOCreateAssistService.php`
> - `mo_assist_api.php`
>
> โดยยังคงเคารพหลักการเดิม: **ห้ามแก้ mo.php หรือ core MO workflow**

---

# 1. Context & Constraints

## 1.1 จาก Task 23.1 ที่มีอยู่แล้ว

ตอนนี้ระบบมี:

- `MOCreateAssistService` (~450 บรรทัด)  
  - ให้ฟังก์ชัน: routing suggestion, routing validation, estimated time, node stats, preview ฯลฯ
- `mo_assist_api.php`  
  - 6 endpoints: `suggest`, `validate`, `preview`, `uom`, `estimate-time`, `node-stats`
- Non-intrusive: ไม่แตะ `mo.php`

แต่ยังมีจุดที่ "หละหลวม" อยู่ในมุมมอง Phase 22–23 เช่น:

- estimate time ใช้เพียง `flow_token.actual_duration_ms` แบบหยาบ ๆ  
- historic duration ไม่ filter ตาม product → เวลาปะปนกันระหว่าง products ต่างรุ่น
- graph validation ยังไม่ตรวจ cycle, orphan nodes, reachability
- node behavior compatibility (classic line vs node_mode) ยังไม่ถูกเช็ค
- API layer ยังไม่มี global try/catch + error normalization
- X-AI-Trace วัดเวลาเฉพาะ bootstrap ไม่ครอบ execution จริงของ handler

## 1.2 ข้อจำกัด (Non-Negotiable)

1. **ห้ามแตะ mo.php**
2. **ห้าม spawn token หรือแก้ไข MO lifecycle**
3. ใช้ Phase 22 services เป็น source-of-truth สำหรับ timeline:
   - `TimeEventReader`
   - `LocalRepairEngine`
   - `TimelineReconstructionEngine`
   - `CanonicalEventIntegrityValidator`
4. Query DB ตรงได้ แต่ต้องผ่าน `tenant_db()` / `core_db()` และไม่ทำให้ schema เปลี่ยน

---

# 2. High-Level Goals ของ Task 23.2

1. ทำให้ `MOCreateAssistService`:
   - รู้จัก **canonical timeline** จริงของ products
   - ตรวจ graph routing ลึกขึ้น (ไม่มี loop, ไม่มี orphan, node ถึงกันครบ)
   - ตรวจ node behavior compatibility สำหรับ classic line
   - ดึง historic duration ให้ถูกต้องตาม product + routing

2. ทำให้ `mo_assist_api.php`:
   - มี global error handling ที่ดี (try/catch → json_error)
   - X-AI-Trace ใช้เวลาการทำงานจริงของ handler
   - บังคับให้ method เป็น GET เท่านั้น (ตาม spec)

3. เตรียมฐานข้อมูลที่สะอาดสำหรับ Task 23.3–23.4 ที่จะใช้ timeline เหล่านี้ใน workload simulation / ETA engine.

---

# 3. Scope

## 3.1 In-Scope

1. แก้ไข/ขยาย `MOCreateAssistService.php` ในประเด็น:
   - estimateTime() → canonical-aware
   - getHistoricDuration() → product-aware + routing-aware
   - validateGraphStructure() → เพิ่ม cycle detection + reachability
   - ตรวจ node behavior mode ที่รองรับ classic line
   - ขยาย getNodeStats() ให้รองรับ stage/work_center summary (ถ้า schema รองรับ)

2. แก้ไข `mo_assist_api.php` ในประเด็น:
   - ย้าย X-AI-Trace ให้วัดเวลารวมของ handler จริง
   - เพิ่ม global try/catch
   - บังคับ HTTP method = GET
   - ปรับปรุง logging เมื่อเกิด error

3. เพิ่มเอกสาร `task23_2_results.md`

## 3.2 Out of Scope

- ไม่เพิ่ม endpoint ใหม่ (ใช้ชุดเดิม 6 ตัว)
- ไม่แตะ `mo.php`, `start_production`, หรือ core MO handlers
- ไม่ทำ UI/Frontend (จะไปอีก task)
- ไม่เริ่มทำ MO ETA engine (เป็น Task 23.4)

---

# 4. Detailed Design — MOCreateAssistService Hardening

## 4.1 estimateTime() → ใช้ Canonical Timeline

### ปัญหาเดิม

- ใช้ `flow_token.actual_duration_ms` แบบเฉลี่ย (ไม่ผ่าน TimeEventReader)
- ไม่รองรับกรณีที่ canonical events ถูก self-heal แล้ว

### แนวทางใหม่

1. สร้าง helper ภายใน service:

```php
private function getCanonicalDurationStatsForProductRouting($productId, $routingId): ?array
```

- Query tokens (flow_token) ที่:
  - ผูกกับ `id_graph_instance` ที่มาจาก `id_routing_graph = $routingId`
  - ผูกกับ MO ที่มี `id_product = $productId` (ผ่าน join: graph_instance → job_ticket → mo)
- ใช้ `TimeEventReader` เพื่ออ่าน duration ที่ canonical แล้ว
- คืนค่า:

```php
[
  'avg_ms' => ...,  // avg canonical duration per token
  'p50_ms' => ...,
  'p90_ms' => ...,
  'sample_size' => ...,
]
```

2. `estimateTime($productId, $routingId, $qty)`:
   - ถ้ามี canonical stats → ใช้ canonical avg_ms
   - ถ้าไม่มี stats → fallback ไปใช้ `flow_token.actual_duration_ms` หรือ default estimate
   - ส่งออกทั้ง per-unit และ total estimate

## 4.2 getHistoricDuration() → product-aware + routing-aware

### ปัญหาเดิม

- Filter ตาม routing เท่านั้น → ทำให้ cross-product ปนกันได้

### แนวทางใหม่

- JOIN เพิ่มเติม:
  - จาก flow_token → graph_instance → mo → product
  - WHERE product.id_product = :productId
- แยก method เป็น:

```php
private function getHistoricDurationForProductRouting($productId, $routingId): ?array
```

- ใช้ method นี้เป็น backend ของ estimateTime()

## 4.3 validateGraphStructure() → เพิ่ม cycle detection + reachability

### ปัญหาเดิม

- เช็คแค่ node count และบางส่วนของ structure แต่ไม่ตรวจ:
  - มี cycle หรือไม่
  - ทุก node reachable จาก root หรือไม่
  - มี leaf ที่ไม่มีเส้นทางจริงหรือไม่

### แนวทางใหม่

1. ดึง node + edge ของ routing graph ทั้งชุด
2. สร้าง adjacency list ใน memory
3. ทำ DFS/BFS:
   - ตรวจ cycle: ถ้าพบ back edge → error `GRAPH_CYCLE_DETECTED`
   - ตรวจ reachability: node ไหนไม่ reachable จาก root → warning หรือ error `UNREACHABLE_NODE`
4. เพิ่มผลลัพธ์เข้า validation report:

```php
$problems[] = [
  'code' => 'GRAPH_CYCLE_DETECTED',
  'severity' => 'error',
  'details' => [...],
];
```

## 4.4 Node Behavior Compatibility (Classic Line)

### Concept

- MO classic line ต้องใช้ node modes ที่รองรับ execution แบบ classic
- ตัวอย่าง: `CLASSIC_SCAN`, `QC_SINGLE`, ฯลฯ

### Implementation

1. ใน validateRouting():
   - ดึง node metadata (node_mode) จาก routing graph
   - ถ้าเจอ node_mode ที่เป็น `HATTHASILPA_*` หรือ mode ที่ incompatible → ใส่ warning/error
2. Report ให้ UI เห็นว่า routing นี้อาจไม่เหมาะกับ classic line

## 4.5 getNodeStats() → เพิ่ม Stage/Work Center Breakdown

ถ้า schema มี:
- stage / operation_group / work_center_id ใน node table

ให้ขยายผลลัพธ์:

```php
[
  'total_nodes' => ..., 
  'by_type' => [...],
  'by_stage' => [...],
  'by_work_center' => [...],
]
```

ถ้าไม่มี field พวกนี้ใน schema → ให้รองรับแบบ optional (try/catch + fallback)

---

# 5. Detailed Design — mo_assist_api Hardening

## 5.1 Global Error Handling

### ปัญหาเดิม

- ถ้า service โยน exception → กลายเป็น PHP error ที่ไม่สวย

### แนวทางใหม่

1. ห่อ switch(action) ด้วย try/catch:

```php
try {
    switch ($action) {
        ...
    }
} catch (Throwable $e) {
    LogHelper::error('mo_assist_api_error', [...]);
    json_error('Internal server error', 500, [
        'app_code' => 'MO_ASSIST_500',
        'hint' => 'Contact system administrator.',
    ]);
}
```

2. ใช้ LogHelper และไม่โยน stack trace กลับไปที่ client

## 5.2 X-AI-Trace Timing

### ปัญหาเดิม

- execution_ms ถูกเซ็ตก่อน handler รันจริง

### แนวทางใหม่

1. วัดเวลาแบบครอบทั้ง execution:

```php
$__t0 = microtime(true);

try {
    // handle action
} finally {
    $aiTrace = [..., 'execution_ms' => ...];
    header('X-AI-Trace: ' . json_encode($aiTrace, JSON_UNESCAPED_UNICODE));
}
```

2. ให้แน่ใจว่าต่อให้เกิด exception ก็ยังส่ง X-AI-Trace ออกไปได้

## 5.3 Enforce GET-only

1. ก่อนอ่าน `$_GET` / `$_REQUEST` ให้ตรวจ:

```php
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    json_error('Method Not Allowed', 405, ['allowed' => 'GET']);
}
```

2. เปลี่ยน `$action = $_REQUEST['action'] ?? '';` → `$action = $_GET['action'] ?? '';`

---

# 6. Files to Touch

1. `source/BGERP/MO/MOCreateAssistService.php`
   - เพิ่ม/แก้ methods:
     - estimateTime()
     - getHistoricDuration*()
     - validateGraphStructure()
     - getNodeStats()
   - เพิ่ม helper ใหม่สำหรับ canonical stats + behavior check

2. `source/mo_assist_api.php`
   - เพิ่ม global try/catch
   - ย้าย X-AI-Trace ไปท้าย execution
   - enforce GET method

3. `docs/super_dag/tasks/results/task23_2_results.md`
   - สรุป implementation + design decision

---

# 7. Test Plan

## 7.1 Unit Tests (ถ้ามีโครง PHPUnit อยู่แล้ว)

- ทดสอบ estimateTime():
  - เมื่อมี canonical events → ใช้ canonical avg
  - เมื่อไม่มี canonical events → fallback flow_token
- ทดสอบ validateGraphStructure():
  - graph ปกติ → ไม่มี error
  - มี cycle → GRAPH_CYCLE_DETECTED
  - มี node ไม่ reachable → UNREACHABLE_NODE
- ทดสอบ node behavior check:
  - classic-compatible graph → ok
  - hatthasilpa-only node → warning/error

## 7.2 Integration Tests

- เรียก `/mo_assist_api.php?action=estimate-time` ด้วย product+routing ที่มีประวัติจริง  
  → ได้ estimated time ที่สมเหตุสมผล
- เรียก `/mo_assist_api.php?action=validate` กับ routing ที่มี cycle (สร้าง test fixture)  
  → ได้ error code GRAPH_CYCLE_DETECTED
- ยิง request แบบ POST → ได้ 405

## 7.3 Error Handling Tests

- ทำให้ service โยน exception (เช่น db unavailable)  
  → API ตอบ 500 พร้อม json_error และ X-AI-Trace ถูกต้อง

---

# 8. Developer Prompt (สำหรับ AI Agent)

```
Implement Task 23.2 — MO Assist Hardening & Canonical-Aware Validation.

You MUST NOT modify mo.php.
You MAY modify only:
  - source/BGERP/MO/MOCreateAssistService.php
  - source/mo_assist_api.php
  - docs/super_dag/tasks/results/task23_2_results.md

Goals:
  - Make estimateTime() use canonical timeline (TimeEventReader) when available.
  - Make historic duration filters product + routing together.
  - Strengthen graph validation (cycle & reachability checks).
  - Add node behavior compatibility checks for classic line.
  - Harden mo_assist_api.php with proper try/catch, GET enforcement, and accurate X-AI-Trace timing.

Follow the design in this file exactly and keep changes non-intrusive.
```

---

# END OF TASK 23.2
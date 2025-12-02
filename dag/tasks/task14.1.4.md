# Task 14.1.4 — Routing V1 → V2 Migration (Execution Layer)

## Summary
Task 14.1.4 is the final phase of the Routing Migration series.  
It focuses on **execution-layer migration**, ensuring that all routing logic, token movement, and node transitions now use **Routing V2 (super_dag)** exclusively — while keeping backward compatibility during rollout.

This task prepares the system for **Task 14.2 (Master Schema V2)** by completing all routing-related migrations from V1 to V2.

---

## 🔒 Hard Constraints (Do NOT Violate)

Theseข้อกำหนดต้องถูกยึดแบบเคร่งครัดสำหรับ Task 14.1.4:

1. **ห้ามแตะ Time Engine / Session Engine**
   - ห้ามแก้ไฟล์หรือ logic ใด ๆ ที่เกี่ยวข้องกับ:
     - `TokenWorkSessionService` (ทั้ง namespace `BGERP\Service` และ `BGERP\Dag`)
     - start / pause / resume / complete session
     - stale session detection
     - conflict session rules
   - Task นี้ทำเฉพาะ **Routing Execution Layer** เท่านั้น

2. **ห้ามแก้ UI / JS Behavior**
   - ห้ามแก้:
     - `behavior_execution.js`
     - behavior UI panels
     - PWA / Work Queue / Job Ticket templates
     - HTML views / page definitions
   - ถ้าต้องการ refresh UI ให้ใช้ event ที่มีอยู่แล้ว (`BG:TokenRouted`) เท่านั้น (แต่ใน Task นี้ไม่ต้องเพิ่มอะไรใหม่)

3. **ห้ามแตะ Component / Stock / BOM Pipeline**
   - ห้ามแก้ไฟล์ที่อยู่ใน scope ของ Task 13.x:
     - Component*
     - Stock / Warehouse*
     - BOM*
   - Task 14.1.4 ทำเฉพาะ routing execution เท่านั้น

4. **ห้ามลบ / แก้ Schema Legacy Routing**
   - ห้าม `DROP` หรือเปลี่ยนโครงสร้างตาราง legacy routing ใด ๆ
   - Schema cleanup ทั้งหมด (drop routing V1, bom V1, stock V1, เอา dual-write ออก) จะถูกทำใน **Task 14.2**

5. **Backward Compatible เท่านั้น**
   - ห้ามเปลี่ยน response shape ของ API เดิม
   - ห้ามเปลี่ยน behavior ที่ observable จาก client (ยกเว้นกรณี error ที่เราเพิ่ม guard ไว้แล้วใน super_dag tasks ก่อนหน้า)
   - ถ้าจำเป็นต้องเพิ่ม field ให้เพิ่มแบบ optional เท่านั้น

---

# ✅ Scope of Task 14.1.4

### 1. Identify All Routing Execution Touchpoints

ค้นหาไฟล์/ฟังก์ชันที่มีการ “ขยับ token ตามกราฟ” จริง ๆ (execution layer):

- `source/dag_token_api.php`
- `source/dag_routing_api.php`
- `source/pwa_scan_api.php`
- `source/hatthasilpa_job_ticket.php`
- `source/dag_behavior_exec.php`
- `source/BGERP/Dag/DagExecutionService.php`
- `source/BGERP/Dag/BehaviorExecutionService.php`

ให้สร้าง **before/after mapping table** สำหรับแต่ละไฟล์ใน `task14.1.4_scan_results.md`:

- ระบุ V1 call เดิม:
  - `TokenLifecycleService` direct calls
  - `RoutingService` (V1)
  - direct SQL update token / node
  - legacy `moveToNextNode` / `transitionNode`
- ระบุ V2 call ใหม่ที่จะใช้แทน:
  - `DagExecutionService::moveToNextNode()`
  - `DagExecutionService::moveToNodeId()`
  - `DagExecutionService::validateTokenMovement()` (ถ้ามี)

**ห้ามแก้โค้ดก่อนที่จะเขียน mapping ให้ครบก่อน**

---

### 2. Replace All Routing V1 Calls with Routing V2 Service

Routing operations ทั้งหมดต้องใช้:

```php
BGERP\Dag\DagExecutionService
```

โดยเฉพาะ:

- `moveToNextNode()`
- `moveToNodeId()`
- `validateTokenMovement()` (หรือเมธอด validate ที่มีอยู่แล้วใน service)

**สิ่งที่ไม่อนุญาต:**

- ห้ามใช้ direct SQL ในการอัปเดต:
  - `token.current_node_id`
  - `token.status` (ยกเว้นผ่าน service ที่รองรับ)
- ห้ามเรียก `RoutingService` (V1) โดยตรง
- ห้ามเรียก `TokenLifecycleService` ตรง ๆ จาก API อีกต่อไป (ต้องผ่าน `DagExecutionService`)

ให้ refactor ให้เรียก DagExecutionService เท่านั้น และเก็บ **behavior เดิม** ของ API ให้เหมือนเดิม (input/output parameters และ response shape)

---

### 3. Ensure DAG Designer Metadata Is Respected

Routing engine ต้อง:

- อ่าน node metadata (behavior, requirements, flags) จาก V2 graph (super_dag)
- เดินตามกราฟ V2:
  - normal edges
  - rework edges
  - QC decision edges
  - split / join (ถ้ามี)
- เคารพเงื่อนไขที่ DAG Designer กำหนด:
  - rework path
  - end node
  - behavior-specific rules

ตรวจสอบร่วมกับ:

- `dag_routing_api.php` (metadata APIs)
- โครงสร้าง JSON V2 (super_dag routing structure)

ห้าม hard-code node id / edge id ใน execution layer

---

### 4. Backward Compatibility Guards

เพิ่ม compatibility layer ให้รองรับ:

```php
if (V2 routing exists for token/product/graph) {
    // ใช้ DagExecutionService V2 เป็นหลัก
} else if (legacy routing data still exists) {
    // fallback แบบ read-only หรือคืน error ที่ชัดเจน
}
```

**ห้าม** ทำให้:

- Job Tickets เก่าพัง
- MO เก่าที่ผูกกับ routing V1 ใช้ต่อไม่ได้ทันที
- batch scan เก่าพัง

ให้แน่ใจว่า:

- V2 override V1 เมื่อมีข้อมูล
- V1 ใช้ได้แค่ในกรณี “ไม่มี V2” และต้องไม่เปิดโอกาสสร้างงานใหม่บน V1 อีก

---

### 5. Execution Consistency Check

ต้องยืนยันว่า “ทุกครั้งที่ token ขยับ node” ผ่าน gateway เดียวกัน และใช้ guard เดียวกัน:

- **ห้าม** move ถ้า:
  - session ยัง active → `DAG_SESSION_STILL_ACTIVE`
  - component requirements ไม่ครบ → `COMPONENT_INCOMPLETE`
  - QC state ยังไม่ resolve → `QC_PENDING` (หรือโค้ดที่คุณใช้จริง)
  - edge ถูกห้าม (forbidden / ไม่มี edge ไป node นั้น) → `DAG_NO_NEXT_NODE` หรือ `DAG_TOKEN_INVALID`

ให้แน่ใจว่า:

- `BehaviorExecutionService` → เรียก `DagExecutionService`
- `dag_token_api.php` → เรียก `DagExecutionService`
- `pwa_scan_api.php` → เรียก `DagExecutionService`

และ error codes ต้องถูก map เป็น JSON response แบบเดียวกับที่ใช้ใน super_dag tasks ก่อนหน้า (Task 8–12, 13.x, etc.)

ตัวอย่าง error codes:

```text
DAG_TOKEN_INVALID
DAG_NO_NEXT_NODE
DAG_SESSION_STILL_ACTIVE
COMPONENT_INCOMPLETE
QC_PENDING
```

---

### 6. Logging & Telemetry Upgrade

ทุก routing event ต้อง log ไปที่:

- `dag_behavior_log`
- `token_history`
- (ถ้ามาจาก supervisor override) → ต้องผูกกับ supervisor session / actor

ให้เพิ่ม/ยืนยัน fields ต่อไปนี้ใน log (ถ้า schema รองรับอยู่แล้ว ให้ populate ให้ครบ):

- `routing_source` — ค่าที่เป็นไปได้ เช่น:
  - `behavior` (มาจาก behavior panel)
  - `qc` (มาจาก QC action)
  - `supervisor` (มาจาก supervisor override)
  - `system` (auto-routing หรือ background tasks)
- `old_node` — node ก่อนย้าย
- `new_node` — node หลังย้าย
- `graph_version` — กำหนดเป็น `'V2'` สำหรับ super_dag

ห้ามเปลี่ยน schema log ที่มีอยู่แล้ว แต่ให้เติมค่าใน fields ที่มีอยู่ (หรือเพิ่ม field ใหม่แบบ backward compatible เท่านั้น)

---

### 7. Documentation Deliverables

ให้สร้างไฟล์ 3 ไฟล์ใน `docs/dag/tasks/`:

#### `task14.1.4_scan_results.md`
ต้องมี:
- รายการ touchpoints ทั้งหมดที่เกี่ยวข้องกับ routing execution
- before/after mapping table ต่อไฟล์
- จุดที่ยัง fallback ไป V1 (ถ้ามี)

#### `task14.1.4_routing_matrix.md`
ต้องอธิบาย routing scenarios ที่รองรับใน V2:

- Normal node
- Split node
- Join node
- QC decision node
- Rework node
- End node

และอธิบายว่าแต่ละ scenario ใช้ `DagExecutionService` อย่างไร

#### `task14.1.4_results.md`
ต้องสรุป:
- ไฟล์ที่แก้ไขทั้งหมด
- จุดที่ migrate แล้วสำเร็จ
- Safety checks ที่ทำ (syntax, basic tests)
- Regression test list (API / UI ที่ควร test หลังจบ Task)

---

## 🚀 After Task 14.1.4

เมื่อ Task 14.1.4 เสร็จสมบูรณ์:

- Routing V1 ในชั้น execution layer ถือว่า “ปลดระวางแล้ว”
- ระบบใช้ **Routing V2 (super_dag)** เป็น source of truth สำหรับการขยับ token ทั้งหมด
- Adapter / compatibility layer ยังอยู่ (เพื่อไม่ให้ของเก่าแตก) แต่ V1 จะไม่ได้ถูกเรียกใน execution path ปกติอีก

จากนั้นคุณพร้อมสำหรับ:

### **Task 14.2 — Master Schema V2 (Final Cleanup)**

ซึ่งจะทำงานต่อไปนี้:

- drop legacy routing tables
- drop legacy BOM tables
- drop legacy stock tables
- merge dual-write columns ให้เหลือ V2 เดียว
- ลบ adapters / fallback ทั้งหมด
- finalize BGERP Core Spec: Routing / BOM / Stock V2 เป็นมาตรฐานเดียว

---

## Status

**Task 14.1.4 — READY FOR IMPLEMENTATION (Execution Routing V2 Only, No Time/Session/UI Changes)**


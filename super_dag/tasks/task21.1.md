

# Task 21.1 — Node Behavior Engine (Core Spec & Minimal Skeleton)

> **Goal (21.x overall)**  
> เปลี่ยน SuperDAG จากแค่ "เส้นทาง" ให้กลายเป็นระบบที่มี **Node Behavior จริง** (CUT / SEW / EDGE / PAINT / QC / PACK ฯลฯ) ที่ผูกกับ Token Execution Engine, Work Center, UOM, Leather GRN และ Time Engine ได้อย่างเป็นระบบ
>
> **Goal (Task 21.1 เฉพาะ)**  
> สร้าง **สเปกกลาง** และ **โครงกระดูก (skeleton)** ของ Node Behavior Engine แบบที่ยังไม่ยุ่งกับ UI/Worker App มากนัก แต่ทำให้ระบบรู้จักคำว่า `behavior_code` อย่างเป็นทางการ และมีที่ให้ plug-in logic ในอนาคต

---

## ขอบเขต Task 21.1

### 1) Behavior Model Spec (Conceptual)

ออกแบบและเขียนเอกสาร (ในโฟลเดอร์ `docs/super_dag/`) ดังนี้:

1. **ไฟล์ใหม่:** `docs/super_dag/node_behavior_model.md`
   - อธิบายแนวคิด Node Behavior ในระดับ system:
     - ความต่างระหว่าง `node_type` vs `behavior_code`
       - `node_type` = รูปแบบเชิงโครงสร้างของ node (operation / qc / wait / decision / start / end / sink ฯลฯ)
       - `behavior_code` = พฤติกรรมทางธุรกิจ เช่น `CUT_LEATHER`, `EDGE_PAINT`, `SEW_BODY`, `QC_FINAL`, `PACK_BOX` เป็นต้น
     - ความสัมพันธ์กับ:
       - Work Center / Work Station
       - UOM / unit cost / standard time
       - Leather GRN / Inventory movement (high level, ยังไม่ลงรายละเอียดบัญชี)
       - Time Model (sla_minutes / actual_duration_ms)
     - แนวคิด behavior แบบ plug-in (ในอนาคตสามารถเพิ่ม behavior ใหม่ เช่น `HOT_STAMP`, `GLUE`, `ASSEMBLE` ได้โดยไม่ต้องแก้ core)

   - กำหนด **Behavior Contract ระดับสูง** (interface ทางความคิด) เช่น:
     - Input หลัก ๆ ที่ behavior ต้องรู้: `token`, `node`, `job`, `work_center`, `time_context`
     - Output หลัก ๆ ที่ behavior ต้องคืน: `effects` (เช่น `wip_update`, `inventory_move`, `qc_result`, `status_change` ฯลฯ)
     - ระดับ abstraction: "Behavior ไม่สนใจ UI" และ "Behavior ไม่ยิง SQL เอง แต่ใช้ service layer"

2. **ไฟล์ใหม่:** `docs/super_dag/node_behavior_catalog_v1.md`
   - ขึ้นรายการ behavior batch แรกที่เราต้องการแน่นอนสำหรับ Atelier เครื่องหนัง (ระดับ *ชื่อและหมวดหมู่* ยังไม่ต้องลง logic):
     - กลุ่ม CUT:
       - `CUT_MAIN_PANEL`
       - `CUT_SMALL_PARTS`
     - กลุ่ม SEW:
       - `SEW_BODY`
       - `SEW_HANDLE`
       - `SEW_LINING`
     - กลุ่ม EDGE / PAINT:
       - `EDGE_PAINT_STANDARD`
       - `EDGE_PAINT_PREMIUM`
     - กลุ่ม QC:
       - `QC_IN_PROCESS`
       - `QC_FINAL`
     - กลุ่ม PACKING / LABEL:
       - `PACK_RETAIL`
       - `PACK_OEM`
       - `LABEL_ATTACH`
   - ใส่รายละเอียดสั้น ๆ ต่อ behavior ว่ามี **Intent** อะไร (เช่น ใช้เวลานาน/สั้น, sensitive ต่อช่าง, มี defect-high/low ฯลฯ)
   - ระบุว่า behavior ชุดนี้เป็น **V1 Catalog** ที่อาจขยายต่อได้ใน Task 21.x ถัดไป

---

### 2) PHP Skeleton: NodeBehaviorEngine (Minimal, No Business Logic Yet)

สร้างโครงกระดูก class กลาง ที่จะเป็น "หัวใจ" ของ Node Behavior Engine (แต่ใน Task 21.1 ยังไม่ implement logic จริง) โดย:

1. **ไฟล์ใหม่:** `source/BGERP/Dag/NodeBehaviorEngine.php`
   - Namespace: `BGERP\Dag`
   - ใช้ autoload pattern เดิมของโปรเจกต์
   - Structure ที่ต้องมี:

   ```php
   namespace BGERP\Dag;

   use BGERP\Helper\TimeHelper;
   use BGERP\Service\TokenLifecycleService;
   use BGERP\Service\TokenWorkSessionService;
   use BGERP\Service\DAGRoutingService;
   // TODO(21.1+): inject services via constructor when wiring into container

   class NodeBehaviorEngine
   {
       /**
        * Resolve behavior code for a given node.
        * Example: node_type=operation + node.behavior_code='CUT_MAIN_PANEL'
        */
       public function resolveBehaviorCode(array $node): ?string
       {
           // Task 21.1: minimal placeholder only, no complex rules yet.
           return $node['behavior_code'] ?? null;
       }

       /**
        * High-level entry point to execute behavior when a token is completed at a node.
        *
        * This method should NOT perform heavy logic in Task 21.1.
        * It only builds a normalized context array and returns a stubbed result.
        */
       public function buildExecutionContext(array $token, array $node, ?array $job = null): array
       {
           // Task 21.1: construct a minimal, well-typed context structure.
           return [
               'token' => [
                   'id_token' => $token['id_token'] ?? null,
                   'status'   => $token['status']   ?? null,
               ],
               'node' => [
                   'id_node'       => $node['id_node']       ?? null,
                   'node_code'     => $node['node_code']     ?? null,
                   'node_type'     => $node['node_type']     ?? null,
                   'behavior_code' => $node['behavior_code'] ?? null,
                   'work_center'   => $node['work_center_code'] ?? null,
                   'sla_minutes'   => $node['sla_minutes']   ?? null,
               ],
               'job' => $job ? [
                   'id_job'       => $job['id_job']       ?? null,
                   'job_type'     => $job['job_type']     ?? null,
                   'order_no'     => $job['order_no']     ?? null,
                   'product_code' => $job['product_code'] ?? null,
               ] : null,
               'time' => [
                   'now'      => TimeHelper::now(),
                   'timezone' => TimeHelper::getAppTimezone(),
               ],
               'meta' => [
                   'version' => '21.1',
               ],
           ];
       }

       /**
        * Stub: execute behavior and return a normalized result.
        *
        * In Task 21.1 this must NOT modify database.
        * Only shape the result structure for future tasks (21.2+).
        */
       public function executeBehavior(array $context): array
       {
           $behaviorCode = $context['node']['behavior_code'] ?? null;

           return [
               'ok'            => true,
               'behavior_code' => $behaviorCode,
               'effects'       => [
                   // Task 21.1: placeholders only, no business logic yet.
                   'wip'        => null,
                   'inventory'  => null,
                   'qc'         => null,
                   'routing'    => null,
               ],
               'meta' => [
                   'version'   => '21.1',
                   'executed'  => false, // will become true when real logic is added in 21.2+
                   'timestamp' => TimeHelper::toMysql(TimeHelper::now()),
               ],
           ];
       }
   }
   ```

   - **สำคัญ:** ใน Task 21.1 `executeBehavior()` ห้ามมี side effects กับ DB หรือ service layer — เป็นแค่ skeleton สำหรับ Task 21.2+ เท่านั้น

2. ยัง **ไม่ต้อง** wire NodeBehaviorEngine เข้า DAGRoutingService หรือ Worker API ใน Task 21.1  
   - แค่เตรียม class ให้พร้อมต่อการ integration ใน Task 21.2–21.3

---

### 3) Task Documentation

สร้าง / อัปเดตไฟล์เอกสาร:

1. **ไฟล์นี้:** `docs/super_dag/tasks/task21.md`
   - เก็บรายละเอียด Task 21.1 (ไฟล์ปัจจุบันที่คุณกำลังอ่านอยู่)
   - แนบรายการ deliverables:  
     - `node_behavior_model.md`  
     - `node_behavior_catalog_v1.md`  
     - `NodeBehaviorEngine.php`

2. **ไฟล์ใหม่:** `docs/super_dag/tasks/task21_1_results.md`
   - ให้ AI Agent สร้างหลังทำงานเสร็จ
   - เนื้อหาควรสรุป:
     - ไฟล์ใหม่ที่สร้าง
     - จุดสำคัญใน Behavior Model
     - โครงสร้างของ NodeBehaviorEngine
     - ข้อจำกัดของ Task 21.1 (no DB side effects, no wiring)

---

## ข้อจำกัดสำคัญ (Guardrails)

1. Task 21.1 เป็น **Spec + Skeleton เท่านั้น**  
   ❌ ห้ามต่อเข้ากับ Worker App / Token API / DAGRoutingService แบบ runtime  
   ❌ ห้ามมี SQL query ใหม่  
   ❌ ห้ามแก้ schema database  
   ✅ อนุญาตให้ใช้ TimeHelper เพื่อเตรียมโครง timestamp

2. ห้ามแตะโค้ดเหล่านี้ใน Task 21.1:
   - `worker_token_api.php`
   - `dag_token_api.php`
   - `dag_routing_api.php` (อนุญาตเฉพาะเพิ่ม use + TODO comment ถ้าจำเป็นมาก ๆ แต่อย่าเปลี่ยน logic)
   - `GraphDesigner.js` และ module JS อื่น ๆ ทั้งหมด

3. ต้องไม่ทำให้ tests ที่มีอยู่ในโฟลเดอร์ `tests/super_dag/` พัง

---

## Acceptance Criteria (สำหรับ Task 21.1)

- [ ] มีไฟล์ `docs/super_dag/node_behavior_model.md` และ `node_behavior_catalog_v1.md` พร้อมเนื้อหาครบตามขอบเขต
- [ ] มีไฟล์ `source/BGERP/Dag/NodeBehaviorEngine.php` พร้อม methods `resolveBehaviorCode()`, `buildExecutionContext()`, `executeBehavior()` ตามสเปก
- [ ] `executeBehavior()` ไม่มี side effects (ไม่เรียก Service/DB)
- [ ] ไม่มีการเปลี่ยนแปลงไฟล์ API/JS อื่น ๆ ยกเว้นการเพิ่ม use/namespace ถ้าจำเป็น
- [ ] Running test suite เดิมทั้งหมดยังผ่าน (โดยเฉพาะ SuperDAG tests)
- [ ] มีไฟล์ `docs/super_dag/tasks/task21_1_results.md` สรุปงานที่ทำ

เมื่อ Task 21.1 เสร็จ เราจะพร้อมสำหรับ:
- Task 21.2 — Wiring NodeBehaviorEngine เข้ากับ Token Completion Flow (แบบ read-only / dry-run)
- Task 21.3 — เพิ่ม behavior จริงชุดแรก (เช่น CUT_LEATHER, EDGE_PAINT, QC_FINAL) ผ่าน service layer
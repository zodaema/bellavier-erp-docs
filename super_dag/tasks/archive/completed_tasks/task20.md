

# Task 20 – ETA / Time Engine (Phase 1: Read‑Only ETA & SLA Warnings)

> **Goal (Phase 1)**  
> ใช้ข้อมูลเวลา (time model) ที่เราวางไว้ใน Task 19.5/19.6 + Parallel / Machine semantics จาก Task 18.x  
> เพื่อสร้าง **ETA / SLA Engine แบบ read‑only** (ยังไม่ควบคุม routing, ยังไม่ auto re‑route)  
> และแสดงผลใน UI (Graph Designer + Runtime View) ในระดับ "เตือน" และ "แสดงผล ETA" เท่านั้น

---

## 1. ขอบเขต (Scope)

### 1.1 IN SCOPE (ต้องทำใน Task 20)
- สร้าง **ETA/Time Engine** แบบ read‑only (ไม่เปลี่ยน routing ตัดสินใจ, ไม่ auto re‑route)
- อ่านข้อมูลจาก:
  - `routing_node.sla_minutes` (Task 19.5)
  - `flow_token.start_at`, `flow_token.actual_duration_ms` (Task 19.5)
  - `token_event.duration_ms` (Task 19.5)
  - Parallel + Merge semantics (Task 17, 18.1, 18.x)
- คำนวณ:
  - ETA ต่อ **node** (ถ้า token อยู่ node นี้ งานจะเสร็จเมื่อไหร่)
  - ETA ต่อ **block/segment** (optional ถ้าโค้ดรองรับง่าย)
  - SLA warning ระดับ basic:
    - `ON_TRACK`
    - `AT_RISK` (เข้าใกล้ SLA)
    - `BREACHING` (เกิน SLA แล้ว)
- Expose API / Service methods แบบ **ไม่เขียน DB** (pure compute + read‑only queries)
- เพิ่ม UI แสดง ETA / SLA status ใน:
  - Graph Designer (ดู ETA ใน properties panel ของ node)
  - Runtime view (ถ้ามีจุดแสดง token/งานคงค้าง ให้แสดง ETA/SLA ติดไปด้วย)

### 1.2 OUT OF SCOPE (ห้ามทำใน Task 20)
- ห้าม: เปลี่ยน routing decision ตาม ETA (no auto re‑route, no machine re‑assignment)
- ห้าม: แก้ business logic ของ ParallelMachineCoordinator (Task 18.1)  
  (อ่านข้อมูลได้ แต่ **ห้ามเปลี่ยนพฤติกรรม**)
- ห้าม: แก้ schema DB เพิ่ม column ใหม่ (ใช้เฉพาะที่มีอยู่แล้วใน Task 19.5)
- ห้าม: ทำ UI ที่เปลี่ยน structure ครั้งใหญ่ (เช่น redesign Graph Designer panel ใหม่ทั้งก้อน)  
  ให้เป็นการ **เติม field/indicator เพิ่ม** ใน panel ที่มีอยู่แล้ว

---

## 2. Design แนวคิด ETA / Time Engine

### 2.1 Time Concepts

อิงจาก `docs/super_dag/time_model.md` (Task 19.5) — ใช้แนวคิดต่อไปนี้:
- **Planned duration** ต่อ node: จาก `routing_node.sla_minutes` (หรือ `estimated_minutes` ถ้ามี logic รองรับ)
- **Actual duration**: จาก `flow_token.actual_duration_ms` / `token_event.duration_ms`
- **Start time**: `flow_token.start_at`
- **Now**: `DateTimeImmutable('now', system timezone)` หรือผ่าน TimeProvider ถ้ามี

### 2.2 ETA ระดับ Node (Single Token)

สำหรับ token หนึ่งตัวที่กำลังอยู่ใน node ปัจจุบัน:
- ถ้า node ยังไม่ complete:
  - ใช้ `start_at` + planned duration (`sla_minutes` หรือ `estimated_minutes`) เพื่อคำนวณ ETA
- ถ้า node complete แล้ว:
  - ใช้ actual duration เพื่อประเมิน performance vs SLA (เช่น used% ของ SLA)

### 2.3 SLA Status

ให้กำหนด enum / constant สำหรับ SLA Status:
- `ON_TRACK` – ยังไม่เข้าใกล้ SLA
- `AT_RISK` – ใกล้ถึง SLA (เช่น ใช้เวลาไปแล้ว ≥ 80% ของ SLA)
- `BREACHING` – เลย SLA ไปแล้ว

Threshold (80%) สามารถ hard‑code ระดับ service ได้ก่อนใน Phase 1  
ให้เขียน comment ไว้ชัดเจนสำหรับปรับใน Task ถัดไป

### 2.4 Parallel Blocks (READ‑ONLY)

ใน Phase 1:
- ให้อ่านข้อมูล parallel จากสิ่งที่มีแล้ว (parallel_group_id, merge semantics ฯลฯ)
- ETA ของ parallel block ให้ใช้แนวคิดง่ายๆ ก่อน:
  - "เวลา block = max(ETA ของแต่ละ branch)" สำหรับการประเมิน ETA โดยรวม
- ห้ามปรับแต่ง execution / merge logic (อ่านอย่างเดียว)

---

## 3. Implementation Plan (ทีละส่วน)

### 3.1 สร้าง Service ใหม่: `EtaEngine` (ชื่อ/namespace เสนอ)

**ไฟล์ใหม่ (เสนอ):**
- `source/BGERP/Dag/EtaEngine.php`

**หน้าที่ของ EtaEngine (Phase 1):**
- รับ input:
  - Graph structure (nodes, edges) — ใช้ GraphHelper / loaders ที่มีอยู่
  - Token state (จาก DB): ตำแหน่ง token ในกราฟ + `start_at` + `actual_duration_ms`
- ให้ method หลัก เช่น:
  - `computeNodeEtaForToken($graph, $token)` → object/array มี field:
    - `planned_finish_at`
    - `remaining_ms`
    - `status` (ON_TRACK / AT_RISK / BREACHING)
  - `computeEtaForGraph($graph, $tokens)` (optional – ถ้าทำทันและไม่ซับซ้อนเกินไป)

**ข้อกำหนดสำคัญ:**
- ต้องเป็น **pure compute** (no DB writes)
- เหมาะกับการถูกเรียกจาก API อื่น (เช่น dag_routing_api หรือ runtime API)
- ใช้ `GraphHelper` แทนการเขียน graph map ใหม่ (อย่า duplicate logic)

### 3.2 Integrate กับ DAGRoutingService / Runtime Layer

**ห้าม**ยุ่งกับ routing decision logic (routeToken/handleParallelSplit/handleMergeNode)  
ให้เพิ่มเฉพาะ methods ใหม่ เช่น:
- `getTokenEta($tokenId)` หรือ
- `getNodeEtaForToken($graphId, $tokenId)`

ถ้ารู้สึกว่าแยก class ดีแล้ว (EtaEngine)  
ให้ `DAGRoutingService` เรียกใช้ EtaEngine แค่บาง method ไม่ต้องย้าย logic เวลาเข้าไปใน DAGRoutingService เอง

### 3.3 Graph / Runtime API

ใน `dag_routing_api.php` ให้เพิ่ม action ใหม่ 
(ห้ามแก้ของเก่าที่ sensitive เช่น `graph_save`, `graph_validate` ฯลฯ):

ตัวอย่าง (เสนอ):
- `action=token_eta`  
  Input: `id_token` หรือ `token_id`  
  Output: JSON structure เช่น:
  ```json
  {
    "ok": true,
    "eta": {
      "planned_finish_at": "2025-12-31T10:30:00+07:00",
      "remaining_ms": 1234567,
      "sla_status": "AT_RISK",
      "node_code": "QC1"
    }
  }
  ```

**ข้อห้าม:**
- อย่ารวม action ใหม่กับ action เดิมที่มี logic หนาแน่นแล้ว  
  ให้แยกเคสใน `switch ($action)` ชัดเจน

### 3.4 UI Integration – Graph Designer

**เป้าหมาย:** เพิ่ม "ETA/SLA preview" ใน properties panel ของ node แบบ light‑weight

แนวทาง (แนะนำ):
- ใน properties panel ของ node (แท็บ Operation/QC ที่มีอยู่แล้ว) เพิ่ม section:
  - ETA Preview
    - ถ้า node มี `sla_minutes`:
      - แสดง: `SLA: 30 นาที` (หรือ `SLA: 0.5 ชม.`)
    - ถ้ามีข้อมูล runtime token ปัจจุบัน (ถ้า panel รู้ context token):
      - แสดง status: `On Track`, `At Risk`, `Breaching`
- ถ้า Graph Designer ตอนนี้ไม่รู้เรื่อง token runtime เลย  
  ให้เริ่มจาก **design‑time preview เท่านั้น** (อ่าน `sla_minutes` จาก node + พิมพ์ข้อความง่ายๆ)

> ถ้า integration กับ runtime view มีความเสี่ยง ให้เริ่มจาก design‑time เท่านั้น  
> แล้วค่อยเปิด runtime integration ใน Task 20.x ถัดไป

### 3.5 UI Integration – Runtime View (ถ้าทำได้ง่ายและปลอดภัย)

ถ้ามีหน้าที่แสดง token / WIP อยู่แล้ว (เช่น job board / token list / QC screen):
- เพิ่ม column/tooltip แสดง:
  - SLA status (สีเขียว/เหลือง/แดง – ยังไม่ต้อง fix ดีไซน์ แค่ใส่ text/class ให้พร้อมใช้ CSS)
  - ETA (เวลาเสร็จโดยคาดการณ์ เช่น `วันนี้ 13:45`)

ถ้า integration ยาก ให้ใส่ TODO comment และทำเฉพาะ GraphDesigner ก่อน

---

## 4. SAFETY GUARD (สำคัญมาก)

เมื่อใช้ AI Agent / Codex ช่วยเขียนโค้ด **ต้องป้องกันไม่ให้หลุด scope** ดังนี้:

1. **ห้ามปรับ routing decision logic**
   - ห้ามแก้ `routeToken()`, `handleParallelSplit()`, `handleMergeNode()`  
     ยกเว้นเพิ่ม call ไปหา EtaEngine แบบ read‑only

2. **ห้ามแก้ DB Schema**
   - ห้ามสร้าง migration ใหม่ใน Task 20  
   - ใช้ field ที่มีจาก Task 19.5 เท่านั้น

3. **ห้ามปรับ Validation Layer**
   - ห้ามแก้ `GraphValidationEngine`, `SemanticIntentEngine`, `GraphAutoFixEngine` ใน Task 20
   - Task 19.x validation ถือว่า "freeze" แล้ว

4. **ห้ามแตะ ParallelMachineCoordinator behavior**
   - อ่านข้อมูลจากมันได้  
   - แต่ห้ามแก้ logic การเลือก machine หรือ merge decision

5. **ต้องรัน tests เดิมให้ผ่านทั้งหมด**
   - `php tests/super_dag/ValidateGraphTest.php`
   - `php tests/super_dag/SemanticSnapshotTest.php`
   - `php tests/super_dag/AutoFixPipelineTest.php`

---

## 5. Acceptance Criteria

ให้เขียนใน `task20_results.md` หลังทำงานเสร็จ ว่าผ่านเงื่อนไขต่อไปนี้หรือไม่:

1. **EtaEngine มีอยู่จริง + มี Unit‑like Methods**
   - มีไฟล์ `EtaEngine.php` (หรือชื่อใกล้เคียง) ภายใต้ namespace ที่เหมาะสม
   - มี methods อย่างน้อย:
     - `computeNodeEtaForToken()` (หรือชื่อใกล้เคียง)
   - ไม่เขียน DB

2. **API `token_eta` ทำงานได้จริง**
   - เรียกผ่าน `dag_routing_api.php?action=token_eta&id_token=...` ได้
   - ได้ JSON ตาม spec (มี `planned_finish_at`, `remaining_ms`, `sla_status` อย่างน้อย)

3. **UI Graph Designer แสดง SLA/ETA Design‑Time Preview**
   - Properties panel ของ node แสดง SLA (จาก `sla_minutes`)
   - ไม่มี JS error ใน console เมื่อเปิด Graph Designer

4. **(Optional) Runtime ETA View**
   - ถ้ามี integration ให้ระบุใน `task20_results.md` ว่าทำส่วนไหน และ test อย่างไร

5. **Tests ทั้งหมดผ่าน**
   - SuperDAG tests (3 ไฟล์หลัก) ผ่านทั้งหมด
   - ไม่มี test ใหม่ที่ fail

6. **No Regression on Validation & Routing**
   - ไม่แก้ไฟล์ validation / auto‑fix / semantic engine
   - ไม่แก้ routing behavior เดิม

---

## 6. Prompt สำหรับ AI Agent (ให้วางใน Cursor)

เมื่อจะให้ AI Agent ช่วยเขียนโค้ด ให้ใช้ข้อความแนวนี้ (ปรับชื่อ path ให้ตรงกับโปรเจคจริง):

```text
คุณคือ Codex Agent ดูแล SuperDAG ในโฟลเดอร์ `source/BGERP/Dag` และ `assets/javascripts/dag/*`  
ตอนนี้อยู่ใน Phase Task 20 – ETA / Time Engine (Phase 1: read‑only ETA & SLA warnings)

ข้อห้ามสำคัญ:
- ห้ามแก้ routing decision (`routeToken`, `handleParallelSplit`, `handleMergeNode`)
- ห้ามแก้ validation layer (`GraphValidationEngine`, `SemanticIntentEngine`, `GraphAutoFixEngine`)
- ห้ามสร้าง migration ใหม่ หรือแก้ schema database
- ห้ามปรับ ParallelMachineCoordinator behavior (อ่านอย่างเดียว)

สิ่งที่ต้องทำ:
1) สร้าง EtaEngine (PHP) ใน `source/BGERP/Dag/EtaEngine.php` หรือ path ที่เหมาะสม  
   - มี method สำหรับคำนวณ ETA ของ token ตาม spec ใน `docs/super_dag/tasks/task20.md`
   - ใช้ข้อมูลจาก `routing_node.sla_minutes`, `flow_token.start_at`, `flow_token.actual_duration_ms`, `token_event.duration_ms`
   - รองรับกรณี simple + parallel แล้ว (อ่าน parallel semantics ได้ แต่ไม่แก้ logic execution)

2) Integrate EtaEngine เข้ากับ `DAGRoutingService` หรือ service runtime ที่เหมาะสม  
   - เพิ่ม method read‑only เช่น `getTokenEta($tokenId)`

3) เพิ่ม action ใหม่ใน `dag_routing_api.php` เช่น `action=token_eta`  
   - อ่าน token id → ใช้ EtaEngine → คืน JSON ตาม spec

4) ปรับ `assets/javascripts/dag/graph_designer.js`  
   - เพิ่ม section แสดง SLA/ETA preview ใน node properties panel  
   - ถ้า runtime token context ซับซ้อน ให้เริ่มจาก design‑time preview โดยใช้ `sla_minutes` เฉยๆ ก่อน

5) รัน tests:
   - `php tests/super_dag/ValidateGraphTest.php`
   - `php tests/super_dag/SemanticSnapshotTest.php`
   - `php tests/super_dag/AutoFixPipelineTest.php`

อย่าลืมอัปเดต `docs/super_dag/tasks/task20_results.md` สรุปสิ่งที่ทำ, files ที่แก้ และสถานะ tests
```

---
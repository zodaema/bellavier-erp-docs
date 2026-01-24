# Component Parallel Flow - Concept Flow

**Purpose:** Conceptual flow document for AI agents to understand Hatthasilpa Component Token architecture  
**Scope:** Hatthasilpa Line only (Work Queue / Job Ticket)  
**Date:** 2025-01-XX  
**Version:** 1.0

**⚠️ CRITICAL:** This document describes the **conceptual flow** and **physical reality** of Component Token system.  
Read this FIRST before implementing any Component Token features.

**⚠️ MECHANISM:** Component Token uses **Native Parallel Split** (`is_parallel_split` flag)  
**⚠️ MODULE GRAPH:** Component Token เดินใน **Module Graph** (Subgraph Template)

---

## 0. Scope / ขอบเขต

**✅ ใช้กับ:**
- **Hatthasilpa Line** เท่านั้น
- **Client หลัก:** Work Queue / Job Ticket
- **Production Model:** Parallel craftsmanship workflow
- **Mechanism:** Native Parallel Split + Module Graph (Subgraph Template)

**❌ ไม่เกี่ยวข้องกับ:**
- PWA Classic
- Classic Line
- OEM-style daily reporting
- Linear task system

**⚠️ IMPORTANT - Subgraph Concept:**
- Subgraph = Module Graph (Template) ไม่ใช่ Product Graph
- Component Token เดินใน Module Graph ที่ตรงกับ `component_code`
- Module Graph = "สูตรทำชิ้นส่วน" (Reusable Template)
- Product Graph ห้ามอ้างอิง Product Graph อื่น

**See Also:**
- `docs/dag/SUBGRAPH_MODULE_TEMPLATE_CONCEPT.md` - New Subgraph concept (Module Template)
- `docs/dag/SUBGRAPH_VS_COMPONENT_CONCEPT_AUDIT.md` - Subgraph vs Component comparison

---

## 0.1 “Natural Flow” Clarification (ตรงกับสิ่งที่เกิดในโรงงานจริง)

แนวคิด “ทำทีละชิ้นส่วน แล้วบางชิ้นไปต่อได้ก่อน” **ไม่ได้ทำโดยให้ Final Token (กระเป๋า 1 ใบ) วิ่งข้าม node ไปเอง**  
แต่ทำโดย **แยกงานเป็น Component Tokens** ตั้งแต่จุด split:

- **Final Token**: เป็นตัวแทน “กระเป๋า 1 ใบ” และมักจะ “รอ” อยู่ที่ split/assembly ตาม policy
- **Component Token**: เป็นตัวแทน “ชิ้นส่วน” (เช่น STRAP/BODY/FLAP) และสามารถ:
  - ไปทำ “ปอกบาง / ทาสีขอบ / QC ของชิ้นนั้น” ได้ทันที
  - โดยไม่ต้องรอให้ชิ้นส่วนอื่นเสร็จ

ดังนั้น “ไป node ถัดไปได้บางส่วน” = **Component Token ของชิ้นนั้นไปต่อ**  
ไม่ใช่ “Final Token ไปต่อทั้งใบ”

> ถ้าต้องการให้ Final Token ไปต่อทั้งใบทั้ง ๆ ที่ยังไม่ครบทุกชิ้นส่วนจริง ๆ  
> นั่นเป็น “โมเดลใหม่” (node ต้องรองรับ `consumes_components` แบบ subset ต่อ node) และต้องกำหนดกติกาใหม่เพิ่ม (ยังไม่ใช่ baseline ของเอกสารนี้)

---

## 0.2 Current Reality vs Target (เพื่อกันเอกสารพา implement ผิด)

เอกสารนี้มีทั้ง “ของที่ทำได้แล้ว” และ “ของที่เป็น TARGET” โปรดแยกให้ออก:

### ✅ มีอยู่แล้ว (Current)
- `flow_token.token_type` = `batch|piece|component`
- `flow_token.parallel_group_id`, `flow_token.parallel_branch_key`
- `flow_token.component_code` (SSOT ของ component identity เมื่อ `token_type='component'`)
- `flow_token.metadata` (สำหรับ payload อื่น ๆ ที่ยังไม่มี column)
- `routing_node.is_parallel_split`, `routing_node.is_merge_node`
- `routing_node.parallel_merge_policy` + (`parallel_merge_timeout_seconds`, `parallel_merge_at_least_count`) = **SSOT ของ merge readiness**
- `routing_node.merge_mode` (legacy/compat เท่านั้น — ไม่ควรใช้เป็น SSOT)

### 📋 ยังเป็น TARGET (อย่าเขียน code อิงว่ามีแล้ว)
- `routing_node.produces_component`, `routing_node.consumes_components` (ยังไม่มี column)
- `flow_token.status = 'merged'` (status ปัจจุบันไม่มี enum นี้)
- `merged_into_token_id`, `merged_component_tokens` เป็น “column จริง” (ยังไม่มี) → ให้มองเป็น **metadata target**

**Rule of thumb:** ถ้ายังไม่มี column → เก็บใน `flow_token.metadata` พร้อมชื่อ key ที่นิ่ง และต้องระบุว่าเป็น temporary

---

## 0.3 SSOT Summary (Runtime Today)

เพื่อให้ implement ถูกกับระบบจริง (ไม่หลงไปตามคำศัพท์ในเอกสารเก่า):

- **Merge readiness SSOT**: `routing_node.parallel_merge_policy` (และ fields คู่กัน)
- **Component identity SSOT** (token_type=component): `flow_token.component_code`
- **Work Queue visibility SSOT (ชั่วคราว)**: rule ใน API (อย่าไปสร้าง config DB ใหม่ก่อน flow ชัด)

---

## 1. Entity หลักในระบบ

### 1.1 Final Token (piece token)

**แทน:** "กระเป๋า 1 ใบ"

**คุณสมบัติ:**
- มี `final_serial` **ตั้งแต่ตอนสร้าง Hatthasilpa Job** (ไม่ต้องรอ Assembly)
- มี **ถาดงาน 1 ถาด** ผูกกับ Final Token ใบนั้น (1 ใบ = 1 ถาด)
- `token_type = 'piece'` หรือ `'final'` (ขึ้นอยู่กับ schema)
- เป็น **parent** ของ Component Tokens ทั้งหมด

**Database:**
```sql
flow_token:
  - id_token (PK)
  - token_type = 'piece' or 'final'
  - serial_number = final_serial (e.g., 'MA01-HAT-DIAG-20251201-00001-A7F3-X')
  - id_job_tray (FK to job_tray table) -- ถาดงาน
```

### 1.2 Component Token (token_type = 'component')

**แทน:** "ชิ้นส่วน" ของกระเป๋าใบนี้ เช่น BODY, FLAP, STRAP, LINING ฯลฯ

**Fields ที่ต้องมี:**
- `token_type = 'component'`
- `parent_token_id` → ชี้กลับไปที่ Final Token (MANDATORY)
- `parallel_group_id` → กลุ่ม parallel ของใบเดียวกัน
- `parallel_branch_key` → branch key เช่น "1", "2", "3"
- `component_code` → เช่น 'BODY', 'FLAP', 'STRAP'

**Database:**
```sql
flow_token:
  - id_token (PK)
  - token_type = 'component'
  - parent_token_id (FK to flow_token.id_token) -- MANDATORY
  - parallel_group_id (INT)
  - parallel_branch_key (VARCHAR)
  - component_code (VARCHAR) -- 'BODY', 'FLAP', 'STRAP', etc.
```

**กฎสำคัญ:**
- ❌ **ห้ามมี Component Token ที่ไม่มี parent_token_id**
- Component Token ทุกตัว "ต้องมีพ่อ" = Final Token
- ไม่มี Component ที่ลอยไม่มี parent_token_id

### 1.3 Job Tray (ถาดงาน)

**แทน:** Physical container ในโรงงาน

**คุณสมบัติ:**
- 1 Final Token = 1 ถาดงาน
- ชิ้นส่วนทุก component ของใบนี้ → ต้องอยู่ในถาดนี้
- ถาดมี QR/Tag ที่มี `final_serial` / `id_final_token`

**Database:**
```sql
job_tray:
  - id_tray (PK)
  - id_final_token (FK to flow_token.id_token)
  - final_serial (VARCHAR) -- For QR/Tag
  - tray_code (VARCHAR) -- Physical tray identifier
```

**Physical Reality:**
- ช่างหยิบ "ถาด F001" → ทำงานกับชิ้นส่วนของ F001 ทั้งหมด
- ไม่มี Flow ที่ component ของ F001 ไปกองรวมกับ F002/F003

---

## 2. จุดกำเนิดของ Final Serial และความสัมพันธ์กับ Component

### 2.1 ตอนสร้าง Hatthasilpa Job (Job Creation)

**เมื่อสร้าง Hatthasilpa Job:**

1. **ระบบสร้าง Final Token** ตามจำนวนใบที่ต้องผลิต
   - เช่น Job นี้ 5 ใบ → สร้าง Final Token 5 ตัว

2. **แต่ละ Final Token:**
   - มี `final_serial` **ทันที** (ไม่ต้องรอ Assembly)
   - มีถาดงานของตัวเอง (ใบละถาด)
   - `status = 'active'` หรือ `'waiting'`

3. **ในฐานข้อมูล:**
   - Final Token ถูกบันทึกใน `flow_token` (`token_type = 'piece'` หรือ `'final'`)
   - ถาดงานถูกสร้างและผูกกับ Final Token

**Workflow:**
```
Job Creation:
  → Create Final Token #1 (final_serial = 'F001')
  → Create Job Tray #1 (id_final_token = Final Token #1)
  → Create Final Token #2 (final_serial = 'F002')
  → Create Job Tray #2 (id_final_token = Final Token #2)
  → ... (repeat for all pieces)
```

**กฎสำคัญ:**
- ✅ **Final Serial เกิดตั้งแต่ Job Creation** (ไม่ใช่ที่ Assembly)
- ✅ Component Token ทุกตัว "ต้องมีพ่อ" = Final Token
- ❌ **ห้ามมี Component Token ที่ไม่มี parent_token_id**

---

## 3. Parallel Split → การสร้าง Component Token

### 3.1 Node-to-Component Mapping (with Module Graph)

**ใน routing_node (ของ Hatthasilpa Product Graph):**

**Option 1: Direct Nodes (No Module)**
```sql
routing_node:
  - produces_component = 'BODY', 'FLAP', 'STRAP'
  - consumes_components = '["BODY","FLAP","STRAP"]'
```

**Option 2: Subgraph Nodes (With Module Template) - RECOMMENDED**
```sql
routing_node (PARALLEL_SPLIT):
  - Outgoing Edge 1 → SUBGRAPH(BODY_MODULE) [produces_component='BODY']
  - Outgoing Edge 2 → SUBGRAPH(FLAP_MODULE) [produces_component='FLAP']
  - Outgoing Edge 3 → SUBGRAPH(STRAP_MODULE) [produces_component='STRAP']
```

**Module Graphs:**
```
BODY_MODULE (graph_type='module'):
   ENTRY → STITCH_BODY → EDGE_BODY → QC_BODY → EXIT

FLAP_MODULE (graph_type='module'):
   ENTRY → STITCH_FLAP → QC_FLAP → EXIT

STRAP_MODULE (graph_type='module'):
   ENTRY → STITCH_STRAP → EDGE_STRAP → QC_STRAP → EXIT
```

**Benefits of Option 2:**
- ✅ Module Graph = Reusable Template (ใช้ซ้ำได้หลาย Product)
- ✅ Version-controlled (module version = process version)
- ✅ Modular (change module = change process for all products)
- ✅ Consistent process (same module = same quality)

**Database:**
```sql
routing_graph:
  - graph_type = 'product' or 'module'
  - is_reusable_template = 1 (for module)

routing_node (in Product Graph):
  - node_type = 'subgraph'
  - subgraph_ref = '{"graph_id": MODULE_ID, "graph_version": "1.0", "mode": "same_token"}'
  - produces_component = 'BODY', 'FLAP', 'STRAP'
```

### 3.2 ตอนถึง Parallel Split Node (with Module Graph)

**เมื่อ Final Token เดินมาถึง node ที่เป็น parallel split** (`is_parallel_split = 1`):

1. **ระบบดู outgoing edges / target nodes:**
   - Check if target node is Subgraph node (Module Graph)
   - Check `produces_component` from target node or Module Graph

2. **สำหรับ Final Token ใบนั้น:**
   - สร้าง Component Tokens หลายตัว (ตามจำนวน branch)
   - ตั้งค่า:
     - `token_type = 'component'`
     - `parent_token_id = id_final_token` (MANDATORY)
     - `parallel_group_id` เดียวกันทุก component ของใบนี้
     - `parallel_branch_key` แตกต่างกัน เช่น "1", "2", "3"
     - `component_code` ตาม target node's `produces_component`

3. **ตัว Final Token เอง:**
   - เปลี่ยนสถานะเป็น `'waiting'` หรือ `'split'`
   - ยังอยู่ผูกกับถาดใบเดิม (ถาดไม่หายไปไหน)

**Workflow (with Module Graph):**
```
Final Token F001 arrives at Parallel Split Node:
  → Check outgoing edges:
    - Edge 1 → SUBGRAPH(BODY_MODULE) [produces_component='BODY']
    - Edge 2 → SUBGRAPH(FLAP_MODULE) [produces_component='FLAP']
    - Edge 3 → SUBGRAPH(STRAP_MODULE) [produces_component='STRAP']
  → Create Component Tokens:
    - Component Token #1: component_code='BODY', parent_token_id=F001
    - Component Token #2: component_code='FLAP', parent_token_id=F001
    - Component Token #3: component_code='STRAP', parent_token_id=F001
  → Component Tokens move to respective Module Graphs:
    - BODY Token → enters BODY_MODULE
    - FLAP Token → enters FLAP_MODULE
    - STRAP Token → enters STRAP_MODULE
  → Final Token F001: status='waiting', still linked to Tray F001
```

**Component Token Flow in Module:**
```
Component Token #1 (BODY) enters BODY_MODULE:
  → Create module instance (parent_instance_id = Product instance)
  → Component Token moves to BODY_MODULE.ENTRY
  → Execute: STITCH_BODY → EDGE_BODY → QC_BODY
  → Component Token reaches BODY_MODULE.EXIT
  → Component Token exits module → moves to MERGE node (Product Graph)
```

**กฎสำคัญ:**
- ✅ Component Token ทุกตัวต้องมี `parent_token_id` (ชี้ไป Final Token)
- ✅ Component Token เดินใน Module Graph (same token)
- ✅ Module Graph = Template (ไม่สร้าง Final Token ใหม่)
- ❌ **ห้ามมี Component Token ที่ไม่มี parent_token_id**

---

## 4. Physical Flow: ถาดงานในโรงงาน

**หลักคิด:**

**ชิ้นงานทุกอย่างของ Final Serial FXXXX → ต้องวิ่งไปกับ "ถาดของ FXXXX" เสมอ**

### 4.1 Physical Workflow

**ตอนเตรียมชิ้นส่วน:**
- ช่างตัด / เตรียมชิ้นส่วนหยิบ **"ถาด F001"** ไป
- ตัด/เตรียมชิ้น BODY/FLAP/STRAP ของ F001
- พอเสร็จ → ใส่กลับลง **"ถาด F001"**
- **ไม่มี Flow ที่ component ของ F001 ไปกองรวมกับ F002/F003**

**ตอนทำงาน Component:**
- Worker A รับงาน BODY ของ F001
- Worker A หยิบ **"ถาด F001"** ไป
- ทำงาน BODY → ใส่กลับลง **"ถาด F001"**
- Worker B รับงาน FLAP ของ F001
- Worker B หยิบ **"ถาด F001"** ไป
- ทำงาน FLAP → ใส่กลับลง **"ถาด F001"**

### 4.2 Digital ↔ Physical Mapping

**Digital:**
- Component Token ของ F001 มี `parent_token_id = FinalToken(F001)`
- Component Token ของ F001 มี `parallel_group_id = 100` (same group)

**Physical:**
- ชิ้นส่วนของ F001 อยู่ใน **"ถาด F001"**
- ถาด F001 มี QR/Tag ที่มี `final_serial = 'F001'`

**Mapping:**
- Digital graph ↔ Physical tray = **mapping ตรงกัน**
- `parent_token_id` = Physical tray relationship

**กฎสำคัญ:**
- ❌ **ห้ามปล่อยให้ชิ้นส่วนของใบหนึ่งไปปะปนกับถาดของอีกใบ** (ทั้งใน spec และใน logic)
- ✅ Digital relationship (`parent_token_id`) = Physical relationship (tray)

---

## 5. Component Work: ทำงาน parallel แยกช่าง แยกเวลา

### 5.1 ใน Work Queue

**กฎกลาง (Ideal UX Law): Work Queue = Job-level first**

เพื่อไม่ให้ UI รกและไม่ให้ช่างสับสน:
- หน้าแรกของ Work Queue **ต้องแสดงเป็น Card ระดับ Job ใหญ่** (เช่น กระเป๋ารุ่น X • 10 ใบ • อยู่ node CUT)
- งานย่อย (เช่น component_code = BODY/FLAP/STRAP) ต้องอยู่ใน **Modal/Detail** หลังคลิกเข้า Card
- Token-level/Component-level details เป็น “implementation detail” ที่ใช้ใน runtime ได้ แต่ **ไม่ควรถูกเอามากางเป็น list บนหน้าแรก**

> หมายเหตุ: ระบบปัจจุบันมี Job-level card แล้วใน mobile view (`work_queue.js` ใช้ `byJob` model) — แนวคิดนี้ยืนยันให้เป็น “กฎกลาง” ที่ทีม dev ยึดร่วมกัน

**หน้าที่ของ Card (หน้าแรก):**
- สรุปงานใหญ่ (job_ticket / product / due / current stage)
- บอกสถานะภาพรวมแบบคนอ่านง่าย เช่น “BODY ส่งต่อแล้ว 10/10, FLAP ยัง 0/10”
- เปิดทางให้กดเข้าไปทำงานจริงใน modal

**Component Token แสดงอย่างน้อย:**
- `component_code` (BODY / FLAP / STRAP)
- `final_serial` หรือรหัสใบงาน (เพื่อรู้ว่าของ F001)
- `parallel_group_id` (เพื่อรู้ว่าเป็นชุดเดียวกัน)

**UI Example (ภายใน Modal/Detail เท่านั้น):**
```
Job Card: "TOTE • 10 ใบ • CUT"
  → Open Modal:
     - BODY: required 10, cut_done 10, released 10, available 0
     - FLAP: required 10, cut_done 0, released 0, available 0
     - STRAP: required 10, cut_done 0, released 0, available 0
```

### 5.2 การทำงานของช่าง

**ตัวอย่าง:**
- Worker A → รับงาน BODY
- Worker B → รับงาน FLAP
- Worker C → รับงาน STRAP

**Flow:**

1. **Worker A เห็นใน Work Queue:**
   - Component Token: BODY ของ F001, F002, F003

2. **กด start:**
   ```php
   TokenWorkSessionService::startToken(component_token_id)
   ```

3. **ทำงาน:**
   - pause/resume ตามปกติ
   - Time tracked per component token

4. **กด complete:**
   ```php
   TokenWorkSessionService::completeToken(component_token_id)
   ```

**ผล:**
- เวลาแต่ละ component ถูกเก็บแยกใน `token_work_session` ของ component token
- สามารถรู้ได้ว่า:
  - BODY ของ F001 ใช้เวลากี่วินาที โดยใครทำ
  - FLAP ของ F001 ใช้เวลากี่วินาที โดยใครทำ
  - STRAP ของ F001 ใช้เวลากี่วินาที โดยใครทำ

**Database:**
```sql
token_work_session:
  - id_token = component_token_id
  - work_seconds = component work time
  - operator_name = worker name
```

---

## 6. Component QC

**Component แต่ละตัวสามารถมี QC node ของตัวเอง (QC component-level)**

**Behavior เช่น QC_SINGLE สามารถทำงานกับ component token ได้:**
- ใช้ `token_id = component token`
- เก็บผล QC ต่อ component แยกจาก final

**Workflow:**
```
Component Token: BODY (F001) arrives at QC_SINGLE node:
  → QC behavior executed on component token
  → Result: PASS
  → Component token routed to next node

Component Token: FLAP (F001) arrives at QC_SINGLE node:
  → QC behavior executed on component token
  → Result: FAIL
  → Component token routed to rework node
```

**Database:**
```sql
dag_behavior_log:
  - id_token = component_token_id
  - behavior_code = 'QC_SINGLE'
  - qc_result = 'pass' or 'fail'
```

**กฎสำคัญ:**
- ✅ Component-level QC = separate from final QC
- ✅ Component QC result stored per component token
- ✅ Component can be reworked independently

---

## 7. Assembly / Merge Node

### 7.1 Logic ที่ Assembly Node

**เมื่อถึง node ที่เป็น Assembly (merge):**

1. **Node มี `consumes_components = ["BODY","FLAP","STRAP"]`**

2. **ระบบตรวจ:**
   - Component tokens ของ F001 ที่อยู่ใน `parallel_group_id` นั้น → ครบทุก component หรือยัง?
   - ตรงกับ `consumes_components` หรือไม่?

3. **เมื่อครบ:**
   - **Re-activate Final Token** ของ F001 (`parent_token_id`)
     - `status = 'active'`
     - `current_node_id = assembly_node`
   - **Component Tokens (Current Reality):**
     - ให้ถือว่า component token “เสร็จ” โดยใช้ `status='completed'`
     - ถ้าต้องบันทึกว่า “ถูก merge แล้ว” ให้เก็บใน `flow_token.metadata` (temporary) เช่น:
       - `metadata.merge_state = 'merged'`
       - `metadata.merged_into_token_id = <final_token_id>`

**สำคัญ:**
- ✅ **Assembly ไม่ได้ generate Final Serial ใหม่**
- ✅ แต่ใช้ Final Serial ที่สร้างตั้งแต่ Job Creation
- ✅ Assembly = ขั้นรวมข้อมูล/เวลา/ช่างจาก Component Tokens เข้าสู่ Final Token

**Workflow:**
```
Component Tokens arrive at Assembly Node:
  - Component Token #1 (BODY, F001) arrives
  - Component Token #2 (FLAP, F001) arrives
  - Component Token #3 (STRAP, F001) arrives
  → System checks: All components arrived? (consumes_components = ["BODY","FLAP","STRAP"])
  → Yes: Re-activate Final Token F001
    - Final Token F001: status='active', current_node_id=assembly_node
    - Component Tokens (CURRENT): status='completed' (หรือ status เดิมตาม lifecycle)
    - Component Tokens (TARGET marker): ใช้ `flow_token.metadata` เช่น
      - `metadata.merge_state = 'merged'`
      - `metadata.merged_into_token_id = <final_token_id>`
```

### 7.2 ข้อมูลที่ Merge เข้า Final Token

**ตอน merge:**

**คำนวณ:**
- เวลา per component → `component_times` JSON
- max component time → `max_component_time`
- total component time → `total_component_time`

**รวบรวม:**
- ใครทำ component ไหน → `component_craftsmen`
- QC status component ไหนผ่าน/ไม่ผ่าน → `component_qc_status`
- รายชื่อ id component token → `merged_component_tokens`

**ทั้งหมดนี้เก็บเป็น metadata ของ Final Token** (Current: `flow_token.metadata`) เพื่อใช้:
- ETA calculation
- Analytics
- Storytelling
- Traceability

**Database (Current Reality):**
```sql
flow_token.metadata (Final Token):
  - component_times = {"BODY": 7200, "FLAP": 5400, "STRAP": 3600}
  - max_component_time = 7200
  - total_component_time = 16200
  - component_craftsmen = {"BODY": "Worker A", "FLAP": "Worker B", "STRAP": "Worker C"}
  - component_qc_status = {"BODY": "pass", "FLAP": "pass", "STRAP": "pass"}
  - merged_component_tokens = [101, 102, 103]
```

---

## 8. Assembly Work (ช่างประกอบ)

**เมื่อ Final Token ถูก re-activate ที่ Assembly node:**

**ช่าง Assembly เห็นใน Work Queue:**
- งาน: Final Token F001 (พร้อมสถานะว่า "components complete")
- หน้างาน:
  - หยิบ **"ถาด F001"** ที่รวบชิ้นส่วนไว้ทั้งหมดขึ้นมาทำ

**ระบบ:**
- ใช้ `TokenWorkSessionService` กับ Final Token
- เวลาที่ใช้ใน assembly เก็บใน final token แยกจาก component times

**Workflow:**
```
Final Token F001 (re-activated at Assembly node):
  → Worker D sees in Work Queue: "Final Token F001 (components complete)"

> **Reality guard (important):** โดย default ควร “ไม่แสดง component tokens ให้ Assembly worker”  
> และควรมี view/flag เฉพาะสำหรับ component workers เท่านั้น เพื่อไม่ให้ Work Queue กลายเป็นกอง token ปนกัน
  → Worker D picks up "Tray F001" (contains all components)
  → Worker D starts work:
    TokenWorkSessionService::startToken(final_token_id)
  → Worker D completes assembly:
    TokenWorkSessionService::completeToken(final_token_id)
  → Assembly time stored in final token (separate from component times)
```

**สุดท้าย:**
- **ETA ของใบนี้ = `max(component_times) + assembly_time`**

**Example:**
```
Component Times:
  - BODY: 2 hours (7200 seconds)
  - FLAP: 1.5 hours (5400 seconds)
  - STRAP: 1 hour (3600 seconds)

Max Component Time: 2 hours (BODY)
Assembly Time: 0.5 hours (1800 seconds)

ETA = 2 hours + 0.5 hours = 2.5 hours
```

---

## 9. Component Serial (ถ้ามี) = แค่ Label, ไม่ใช่กลไกผูกสัมพันธ์

**ถ้าใน DB ยังต้องมี component_serial:**

- ให้ถือว่าเป็นแค่ **label / human-readable ID**
- ความสัมพันธ์แท้จริงระหว่าง Final ↔ Component:
  - อยู่ที่ `parent_token_id` / `parallel_group_id`
  - (TARGET marker) `metadata.merged_into_token_id` ถ้าต้องการ tag ว่า component ถูก merge เข้ากับ final แล้ว
  - **ห้ามออกแบบ logic ว่า:**
    - "component_serial แบบนี้ต้องไปคู่กับ final_serial แบบนั้น"
  - **ความสัมพันธ์ทั้งหมดใช้ token graph เท่านั้น**

**Database:**
```sql
component_serial:
  - component_serial (VARCHAR) -- Just a label
  - id_component_token (FK) -- Real relationship
  - id_final_token (FK) -- Real relationship
```

**กฎสำคัญ:**
- ✅ Component Serial = Label only (human-readable)
- ✅ Real relationship = `parent_token_id` / `parallel_group_id`
- ❌ **ห้ามเขียนกฎจับคู่ Final ↔ Component ด้วย pattern ของเลข serial**

---

## 10. ข้อห้าม (Anti-pattern ที่ต้องระบุในเอกสารให้ชัด)

### 10.1 ❌ ห้ามมี Component Token ที่ไม่มี parent_token_id

**Rule:**
- Component Token ทุกตัวต้องมี `parent_token_id` (ชี้ไป Final Token)
- ไม่มี Component ที่ลอยไม่มี parent_token_id

**Validation:**
```php
// When creating component token
if (empty($componentToken['parent_token_id'])) {
    throw new Exception('Component token must have parent_token_id');
}
```

### 10.2 ❌ ห้าม generate Final Serial ที่ Assembly

**Rule:**
- Final Serial เกิดตั้งแต่ Job Creation (ไม่ใช่ที่ Assembly)
- Assembly = ขั้นรวมข้อมูล/เวลา/ช่างจาก Component Tokens เข้าสู่ Final Token

**Validation:**
```php
// At Assembly node
if ($finalToken['serial_number'] === null) {
    throw new Exception('Final serial must exist before assembly');
}
```

### 10.3 ❌ ห้ามปล่อยให้ชิ้นส่วนของใบหนึ่งไปปะปนกับถาดของอีกใบ

**Rule:**
- ชิ้นส่วนของ F001 ต้องอยู่ในถาด F001 เสมอ
- Digital relationship (`parent_token_id`) = Physical relationship (tray)

**Validation:**
```php
// When moving component token
$componentToken = fetchToken($componentTokenId);
$finalToken = fetchToken($componentToken['parent_token_id']);
$tray = fetchTray($finalToken['id_job_tray']);

// Ensure component belongs to correct tray
if ($tray['id_final_token'] !== $finalToken['id_token']) {
    throw new Exception('Component must belong to correct tray');
}
```

### 10.4 ❌ ห้ามเขียนกฎจับคู่ Final ↔ Component ด้วย pattern ของเลข serial

**Rule:**
- ใช้ `parent_token_id` + `parallel_group_id` เท่านั้น
- ห้ามใช้ pattern matching ของ serial numbers

**Anti-pattern:**
```php
// ❌ WRONG
if (substr($componentSerial, 0, 4) === substr($finalSerial, 0, 4)) {
    // Match by serial pattern
}

// ✅ CORRECT
if ($componentToken['parent_token_id'] === $finalToken['id_token']) {
    // Match by parent_token_id
}
```

### 10.5 ❌ ห้ามออกแบบ UI ที่ให้ช่าง Assembly ต้อง "เดินหา component ในกองรวม"

**Rule:**
- ช่าง Assembly ควรเห็นแค่ "ใบ F001" และหยิบถาด F001 ใบเดียว
- UI ต้องแสดง Final Token พร้อมสถานะว่า "components complete"
- ไม่ต้องแสดงรายการ component tokens ให้ช่าง Assembly

**UI Pattern:**
```
✅ CORRECT:
Work Queue (Assembly Worker):
  - Final Token F001 [Components: Complete] [Tray: F001]
  - Final Token F002 [Components: Complete] [Tray: F002]

❌ WRONG:
Work Queue (Assembly Worker):
  - Component Token: BODY (F001)
  - Component Token: FLAP (F001)
  - Component Token: STRAP (F001)
  - Component Token: BODY (F002)
  - ... (worker has to find components manually)
```

### 10.6 ❌ ห้ามใช้ Subgraph `fork` Mode สำหรับ Component Token

**Rule:**
- Component Token = Native Parallel Split (`is_parallel_split=1`)
- Component Token ≠ Subgraph `fork` mode (wrong mechanism)

**Reasons:**
1. Component Token = Product-specific (not reusable)
2. Component Token = Physical tray mapping (subgraph cannot handle)
3. Component Token = Native parallel split (no subgraph overhead)
4. Component Token = Component identity (`flow_token.component_code`) + node metadata (future: `produces_component`)
5. Subgraph fork = Reusable parallel module (different purpose)

**❌ WRONG: Using Subgraph fork**
```
MAIN GRAPH:
   CUT → SUBGRAPH(BAG_COMPONENTS_FORK) → ASSEMBLY

BAG_COMPONENTS_FORK (subgraph):
   ENTRY → SPLIT → [BODY, FLAP, STRAP] → JOIN → EXIT
```

**Problems:**
- ❌ Subgraph is product-specific (not reusable)
- ❌ Version-controlled subgraph for product components (too rigid)
- ❌ Different products have different components (not reusable)

**✅ CORRECT: Using Native Parallel Split**
```
MAIN GRAPH:
   CUT → PARALLEL_SPLIT (is_parallel_split=1) → [BODY, FLAP, STRAP] → MERGE (is_merge_node=1) → ASSEMBLY

BODY Branch:
   STITCH_BODY (produces_component='BODY') → QC_BODY

FLAP Branch:
   STITCH_FLAP (produces_component='FLAP') → QC_FLAP

STRAP Branch:
   STITCH_STRAP (produces_component='STRAP') → QC_STRAP
```

**Benefits:**
- ✅ Product-specific (graph = product routing)
- ✅ Flexible (changes with product design)
- ✅ Component-level QC (separate nodes per component)
- ✅ Native parallel split/merge (no subgraph overhead)

**See:** `docs/dag/SUBGRAPH_VS_COMPONENT_CONCEPT_AUDIT.md` for detailed comparison

---

## 11. Summary: Key Concepts

### 11.1 Entity Relationships

```
Final Token (F001)
  ├── Job Tray (Tray F001)
  └── Component Tokens:
      ├── Component Token #1 (BODY, parent_token_id=F001)
      ├── Component Token #2 (FLAP, parent_token_id=F001)
      └── Component Token #3 (STRAP, parent_token_id=F001)
```

### 11.2 Flow Summary

1. **Job Creation:** Create Final Token + Tray (final_serial exists)
2. **Parallel Split:** Create Component Tokens (parent_token_id = Final Token)
3. **Component Work:** Workers work on Component Tokens (parallel, separate time)
4. **Component QC:** QC per component (separate from final QC)
5. **Assembly:** Merge Component Tokens → Re-activate Final Token
6. **Assembly Work:** Worker assembles using Tray (all components in one tray)
7. **Final:** ETA = max(component_times) + assembly_time

### 11.3 Critical Rules

- ✅ Final Serial = Created at Job Creation (not at Assembly)
- ✅ Component Token = Must have parent_token_id
- ✅ Physical Tray = Digital parent_token_id relationship
- ✅ Component Time = Tracked separately per component
- ✅ Assembly = Re-activate Final Token (not create new)
- ✅ Module Graph = Template (Component Token เดินผ่าน same token)
- ✅ Product Graph ห้ามอ้างอิง Product Graph อื่น (อ้างได้เฉพาะ Module Graph)
- ❌ No Component Token without parent_token_id
- ❌ No Final Serial generation at Assembly
- ❌ No component mixing between trays
- ❌ No serial pattern matching for relationships
- ❌ No Product Graph reference from Subgraph (อ้างได้เฉพาะ Module Graph)
- ❌ No Final Token created in Module Graph

### 11.4 Subgraph Concept (NEW)

**NEW CONCEPT (v2.0):**
- Subgraph = Module Graph (Template) ไม่ใช่ Product Graph
- Product Graph อ้างได้เฉพาะ Module Graph
- Module Graph = "สูตรทำชิ้นส่วน" หรือ "ขั้นตอนย่อย"
- Component Token เดินใน Module Graph (same token)

**See:** `docs/dag/SUBGRAPH_MODULE_TEMPLATE_CONCEPT.md` for detailed new concept

---

**Last Updated:** 2025-01-XX  
**Version:** 1.1 (Aligned with Module Graph Concept)  
**Status:** Active Concept Flow  
**Maintained By:** Development Team


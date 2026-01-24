
# Task 18.3 — Start/Finish Node Rules & QC Panel (Form Schema / Policy JSON) Simplification

**Status:** NEW  
**Category:** Super DAG – Graph Designer UX & QC UX  
**Depends on:**  
- Task 17, 17.2 (Parallel / Merge semantics & validation)  
- Task 18, 18.1, 18.2 (Machine + Parallel + Node UX)  

> เป้าหมายของ Task นี้คือทำให้ SuperDAG ใช้ง่ายขึ้นอีกระดับ โดย:
> - กำหนดมาตรฐานของ Start/Finish node ให้ชัดเจน (1 graph = 1 Start + 1 Finish)  
> - ป้องกันไม่ให้ผู้ใช้สร้าง Start/Finish node แบบสแปม  
> - ซ่อนความซับซ้อนของ JSON ใน QC Panel จากผู้ใช้ทั่วไป (และให้ UI ปกติเป็น source of truth)  
> - ทำทุกอย่างแบบ **ชัดเจน, เดาเองไม่ได้, ห้ามตีความคลาดเคลื่อน** สำหรับ AI Agent

---

# 🎯 Objectives

1. **Start/Finish Node Rules**  
   - 1 Graph (1 routing_graph version) ควรมี Start node = 1 และ Finish node = 1 เท่านั้น (ใน Phase ปัจจุบัน)  
   - Toolbar จะ **ไม่อนุญาต** ให้สร้าง Start/Finish node เพิ่มเมื่อมีอยู่แล้วในกราฟ  
   - Backend validation ต้องตรวจและแจ้ง error ชัดเจนหากกราฟไม่มี Start/Finish หรือมีเกิน 1 ตัว

2. **QC Panel Simplification (Form Schema & QC Policy JSON)**  
   - ซ่อน JSON ทั้งสองส่วนจากผู้ใช้ทั่วไป (Form Schema JSON + QC Policy JSON)  
   - ให้ UI แบบ dropdown / checkbox เป็น **“ตัวจริง” (Source of Truth)**  
   - JSON เป็นแค่ representation ภายในที่ถูก generate จาก UI เท่านั้น  
   - เปิดดู JSON ได้เฉพาะโหมด Advanced/Developer (หรือ read-only หลังจากกดปุ่ม Show Advanced)

---

# 🧩 Scope

## In Scope

- Graph Designer (Start/Finish toolbar & validation):
  - `assets/javascripts/dag/graph_designer.js`
  - `assets/javascripts/dag/modules/GraphSaver.js`
  - `source/dag_routing_api.php` (graph validation)

- QC Panel (Form Schema & Policy JSON):
  - ส่วนของ UI ที่ใช้สำหรับ node type = QC (ใน `graph_designer.js` หรือ module QC แยกถ้ามี)
  - Logic การ build / sync JSON จาก UI

## Out of Scope

- เปลี่ยน schema ของ `routing_node` หรือ QC logs (ใช้ fields เดิม: form_schema_json, qc_policy ฯลฯ)  
- เปลี่ยน logic การคำนวณผล QC (pass/fail / rework / scrap)  
- เปลี่ยน flow ของ token runtime (engine ปัจจุบันใช้ต่อได้เลย)

---

# 1. Start/Finish Node Rules

## 1.1 UX Rules (Toolbar Behavior)

**Files:**
- `assets/javascripts/dag/graph_designer.js`

### 1.1.1 ความหมายของ Start / Finish ในระบบนี้

- **Start node** = จุดเดียวที่ระบบจะเริ่มปล่อย token เข้าสู่กราฟ  
- **Finish node** = จุดเดียวที่ token จะออกจากกราฟ (จบ flow)  
- Phase นี้:  
  - **1 graph = 1 Start + 1 Finish** (exactly one)  
  - ไม่รองรับ multi-start / multi-finish ใน UI (ถ้าต้องการในอนาคต ค่อยเพิ่ม flag พิเศษ)

### 1.1.2 Rule S1 — Exactly-one Start/Finish (สำหรับ Phase นี้)

- ต่อ 1 graph (1 routing_graph version):
  - ต้องมี **Start node = 1** (ไม่มาก/ไม่น้อยกว่านี้)  
  - ต้องมี **Finish node = 1**  
- ถ้าไม่มี หรือมีมากกว่า 1 ให้ถือว่าเป็น **error** ตอน save/publish

### 1.1.3 Rule S2 — Disable Toolbar Buttons When Already Present

**สำคัญ: ต้อง "disable ปุ่ม" ไม่ใช่แค่เตือนด้วยข้อความ**

- เมื่อกราฟมี Start node ≥ 1:
  - ปุ่มบน toolbar สำหรับสร้าง Start node ใหม่ต้อง:
    - ถูก disable/muted (เช่น `disabled=true`, class ปุ่มสีเทา)  
    - ไม่สามารถคลิกได้จริง (ห้ามสร้าง Start เพิ่ม)
    - แสดง tooltip ชัดเจน:  
      `มี Start node ในกราฟแล้ว ไม่สามารถสร้างเพิ่มได้`

- เมื่อกราฟมี Finish node ≥ 1:
  - ปุ่มบน toolbar สำหรับสร้าง Finish node ใหม่ต้อง:
    - ถูก disable เช่นเดียวกับ Start  
    - Tooltip: `มี Finish node ในกราฟแล้ว ไม่สามารถสร้างเพิ่มได้`

- ถ้า user ลบ Start หรือ Finish เดิมออกจากกราฟ:
  - ปุ่มที่เกี่ยวข้องต้องกลับมา enable ทันที (พร้อม tooltip ปกติ)

Implementation hints:

```js
function hasStartNode() {
  // scan all nodes in the graph (cy / internal model)
  // return true if ANY node has type === 'START' (หรือ flag ที่แทน START)
}

function hasFinishNode() {
  // scan all nodes for type === 'FINISH'
}

function updateStartFinishToolbarState() {
  if (hasStartNode()) {
    disableStartButton();
  } else {
    enableStartButton();
  }

  if (hasFinishNode()) {
    disableFinishButton();
  } else {
    enableFinishButton();
  }
}
```

- ต้องเรียก `updateStartFinishToolbarState()` ทุกครั้งที่:
  - โหลดกราฟจาก backend  
  - เพิ่ม node ใหม่  
  - ลบ node (โดยเฉพาะเมื่อ node นั้นเป็น Start หรือ Finish)

> ❗ ถ้ายังสามารถสร้าง Start/Finish ได้มากกว่า 1 จาก toolbar แสดงว่า **Task 18.3 ยังไม่สำเร็จ**

### 1.1.4 Rule S3 — Node Type ของ Start/Finish ต้องเป็น Read-only

- Node Type (เช่น `START`, `FINISH`, `OPERATION`, `QC`) ใน panel properties ถูกทำให้แสดงเป็น **label เท่านั้น** (มาจาก Task 18.2)
- สำหรับ Start/Finish:
  - แสดง label ชัดเจน เช่น `ประเภท: START` หรือ badge `[ START ]`
  - ผู้ใช้ไม่สามารถเปลี่ยน type เป็นอย่างอื่นได้  
  - ไม่มี select box / ไม่มี input / ไม่มีปุ่มเปลี่ยน type

> ห้ามมีกรณีที่ user คลิกเปลี่ยน Start → Operation ผ่าน UI ได้ ถ้าเกิดได้ถือว่าผิดสเปก

---

## 1.2 Backend Validation (Graph-level)

**Files:**
- `source/dag_routing_api.php`

เพิ่มขั้นตอนตรวจสอบในฟังก์ชัน validate graph (เช่น `validateGraphStructure()` หรือฟังก์ชันที่เรียกเมื่อทำการ save/publish graph):

### 1.2.1 Rule S4 — Validation ก่อน Save/Publish

เมื่อผู้ใช้กด save/publish graph:

1. โหลด node ทั้งหมดของ graph นั้น (ตาม id_graph / id_routing_graph version ปัจจุบัน)
2. นับจำนวน node ที่มี type = `START` และ type = `FINISH`
3. ตรวจเงื่อนไขต่อไปนี้ตามลำดับ:

- ถ้า `startCount === 0`:
  - return error JSON เช่น:

```json
{
  "ok": false,
  "error_code": "GRAPH_MISSING_START",
  "message": "Graph must have exactly 1 Start node."
}
```

- ถ้า `startCount > 1`:

```json
{
  "ok": false,
  "error_code": "GRAPH_MULTIPLE_START",
  "message": "Graph currently has multiple Start nodes. Please keep only one."
}
```

- ถ้า `finishCount === 0`:

```json
{
  "ok": false,
  "error_code": "GRAPH_MISSING_FINISH",
  "message": "Graph must have at least 1 Finish node."
}
```

- ถ้า `finishCount > 1`:

```json
{
  "ok": false,
  "error_code": "GRAPH_MULTIPLE_FINISH",
  "message": "Graph currently has multiple Finish nodes. Please keep only one."
}
```

- ถ้าผ่านทุกข้อ → ค่อยไปตรวจ validation อื่น ๆ (parallel/merge จาก Task 17.2, etc.) และอนุญาตให้ save/publish ได้

> ❗ ห้ามปล่อยให้กราฟที่ไม่มี Start/Finish หรือมีหลาย Start/Finish ผ่าน validation แม้จะมี toolbar guard แล้วก็ตาม — ต้องกันทั้งฝั่ง frontend และ backend

---

# 2. QC Panel Simplification — Form Schema & QC Policy JSON

**เป้าหมาย:** 
- User ปกติไม่ต้องยุ่งกับ JSON เลย (อ่านก็ไม่จำเป็น)  
- QC Mode + Checkbox ต่าง ๆ คือ source of truth  
- JSON ถูก generate และ sync แบบ one-way จาก UI → JSON

## 2.1 Elements ที่เกี่ยวข้อง

**Files (frontend):**
- ส่วน QC node properties ใน `assets/javascripts/dag/graph_designer.js`  
  (หรือ module QC เฉพาะ ถ้ามี)

**Fields ที่มีใน UI ปัจจุบัน:**
- `Form Schema` (textarea JSON)  
- `QC Mode` (dropdown — เช่น Basic Pass/Fail)  
- `Require Rework Edge` (checkbox)  
- `Allow Scrap` (checkbox)  
- `Allow Replacement` (checkbox)  
- `QC Policy JSON (Advanced)` (textarea JSON)

---

## 2.2 Rules สำหรับ Form Schema

### 2.2.1 Rule Q1 — Preset-driven / Auto-generated Form Schema

**User ไม่ต้องเขียน JSON เอง**  
**ห้ามออกแบบให้ user ต้องเติม JSON ด้วยมือ**

- Form Schema จะถูก generate จากค่า QC ที่ UI กำหนด เช่น `QC Mode`
- ตัวอย่าง behavior:

- เมื่อเลือก `QC Mode = Basic Pass/Fail`:

```json
{
  "fields": [
    {"name": "result", "type": "select", "options": ["pass", "fail"]}
  ]
}
```

- เมื่อเลือก `QC Mode = Pass/Fail + Defect Type` (ตัวอย่างสำหรับอนาคต):

```json
{
  "fields": [
    {"name": "result", "type": "select", "options": ["pass", "fail"]},
    {"name": "defect_type", "type": "select", "options": ["scratch", "stitch_off", "color_mismatch"]}
  ]
}
```

Implementation hints:

- สร้างฟังก์ชันช่วย เช่น:

```js
function buildFormSchemaFromQcSettings(settings) {
  // settings.qcMode, settings.extraOptions, etc.
  // return plain JS object representing the schema
}
```

- ทุกครั้งที่ `QC Mode` เปลี่ยน → เรียก `buildFormSchemaFromQcSettings()` → อัปเดตค่า schema ใน node data และ textarea (ถ้า advanced view ถูกเปิด)

### 2.2.2 Rule Q2 — ซ่อน JSON Form Schema สำหรับผู้ใช้ทั่วไป

- เปลี่ยน UI ของส่วน Form Schema จาก textarea ตรง ๆ ไปเป็นรูปแบบนี้:

```text
Form Schema
[ Show Form Schema (Advanced) ]
// เมื่อยังไม่กด → ไม่แสดง textarea เลย
// เมื่อกด → แสดง textarea ที่ใช้ดู JSON ที่ generate แล้ว
```

- ค่า default เมื่อเปิด QC node properties:
  - ไม่แสดง JSON Form Schema  
  - User ปกติจะเห็นเฉพาะ QC Mode และตัวเลือกง่าย ๆ

- ถ้ามีระบบ role/permission:
  - `developer` / `system_admin` → อาจอนุญาตให้แก้ JSON ได้ (optional)  
  - role ปกติ (planner / QC leader) → เห็น JSON แบบ read-only หรือไม่เห็นเลยก็ได้

### 2.2.3 Rule Q3 — Form Schema เป็น Derived State

- ถือว่า **source of truth** ของฟอร์ม QC = ค่า UI เช่น `QC Mode` + options อื่น ๆ  
- JSON Form Schema เป็นเพียง **derived state** ที่อัปเดตจาก UI ทุกครั้ง

> ห้ามให้สถานการณ์ที่ user แก้ JSON แล้ว UI ไม่รู้จัก หรือ UI/JSON ไม่ sync กัน

---

## 2.3 Rules สำหรับ QC Policy JSON

### 2.3.1 Rule Q4 — Checkbox / Dropdown เป็นตัวจริง, JSON เป็น Advanced

- ใช้ฟิลด์ใน UI เป็น source of truth:
  - `QC Mode`  
  - `Require Rework Edge`  
  - `Allow Scrap`  
  - `Allow Replacement`

- จาก fields เหล่านี้ ให้ generate QC Policy JSON เช่น:

```json
{
  "mode": "basic_pass_fail",
  "require_rework_edge": true,
  "allow_scrap": false,
  "allow_replacement": false
}
```

### 2.3.2 Rule Q5 — ซ่อน QC Policy JSON หลังปุ่ม Advanced

UI เป้าหมาย:

```text
QC Policy
- QC Mode: [ Basic Pass/Fail ▼ ]
- [ ] Require Rework Edge
- [ ] Allow Scrap
- [ ] Allow Replacement

[ Show QC Policy JSON (Advanced) ]
// ยังไม่กด → ไม่เห็น textarea เลย
// กดแล้ว → แสดง textarea ที่มี JSON ซึ่ง sync จาก options ด้านบน
```

- สำหรับ user ปกติ:  
  - textarea JSON เป็น read-only (ใช้ดูเฉย ๆ หากเขากด Show Advanced)  
- สำหรับ dev/admin (ถ้าจำเป็น):  
  - อาจมี toggle พิเศษให้เปลี่ยนไปใช้โหมด manual JSON edit (เป็น optional เฉพาะภายใน)

### 2.3.3 Rule Q6 — Sync จาก UI → JSON (One-way สำหรับ user ปกติ)

- ทุกครั้งที่มีการเปลี่ยนค่าใน UI ของ QC Policy (dropdown/checkbox):
  - เรียกฟังก์ชันสร้าง JSON เช่น `buildQcPolicyJsonFromUi()`
  - อัปเดตค่าที่เก็บใน node data และ textarea (ถ้าดูอยู่)

ตัวอย่างฟังก์ชัน:

```js
function buildQcPolicyJsonFromUi(nodeSettings) {
  return {
    mode: nodeSettings.qcMode,
    require_rework_edge: nodeSettings.requireReworkEdge,
    allow_scrap: nodeSettings.allowScrap,
    allow_replacement: nodeSettings.allowReplacement
  };
}
```

- ไม่จำเป็นต้อง parse JSON ย้อนกลับมาเพื่อ update UI สำหรับ user ปกติ  
  (ยกเว้นถ้ามีโหมด dev/manual JSON ซึ่งเป็น case พิเศษ)

---

## 2.4 GraphSaver Integration

**Files:**
- `assets/javascripts/dag/modules/GraphSaver.js`

### 2.4.1 Rule Q7 — Save จาก Node Data ไม่ใช่จาก Textarea

- เมื่อ GraphSaver รวบรวมข้อมูล node type = QC เพื่อส่งไป backend:
  - ต้องอ่านค่าจาก **node data object** (เช่น `node.data('qc_mode')`, `node.data('form_schema_json')`, `node.data('qc_policy')`)  
  - **ไม่ควรอ่านจาก textarea DOM** ตรง ๆ เพราะ textarea เป็นแค่ view ของ state

- ค่า minimum ที่ต้องส่งไปสำหรับ QC node:
  - `qc_mode` (string)  
  - flags (`require_rework_edge`, `allow_scrap`, `allow_replacement`)  
  - `form_schema_json` (stringified JSON)  
  - `qc_policy` หรือ fieldเทียบเท่า (stringified JSON)

> ถ้า textarea ถูกซ่อนอยู่ แต่อยาก save graph ได้ → ระบบต้อง save จาก node data เท่านั้น

---

# 🧪 Test Cases (ต้องเช็คกับ UI จริง)

## Start/Finish Rules

### S-TC1 — Graph ใหม่

- สร้างกราฟใหม่  
- Expected:
  - Toolbar: ปุ่ม Start/Finish active (กดได้)  
  - หลังสร้าง Start 1 ตัว → ปุ่ม Start บน toolbar ถูก disable (คลิกไม่ได้ + tooltip เตือน)  
  - หลังสร้าง Finish 1 ตัว → ปุ่ม Finish ถูก disable เช่นกัน

### S-TC2 — ลบ Start/Finish แล้วปุ่มต้องกลับมา

- ลบ Start node ออกจากกราฟ  
- Expected:
  - ปุ่ม Start บน toolbar กลับมา active กดได้อีกครั้ง

- ลบ Finish node  
- Expected:
  - ปุ่ม Finish กลับมา active

### S-TC3 — Validation ตอน Save/Publish

- ลองลบ Start node แล้วกด Save/Publish  
- Expected:
  - Backend return error `GRAPH_MISSING_START` พร้อม message: `Graph must have exactly 1 Start node.`  
- ลอง duplicate Start node ด้วยวิธีอื่น (เช่น copy/paste ถ้ามี) แล้วกด Save/Publish  
- Expected:
  - Backend return error `GRAPH_MULTIPLE_START`  
- ทำแบบเดียวกันสำหรับ Finish node

---

## QC Panel

### Q-TC1 — User ปกติไม่เห็น JSON ทันที

- เลือก QC node  
- Expected:
  - UI แสดงเฉพาะ QC Mode + checkbox (Require Rework Edge, Allow Scrap, Allow Replacement)  
  - ไม่เห็น textarea JSON ใด ๆ จนกว่าจะกดปุ่ม "Show ... (Advanced)"

### Q-TC2 — เปลี่ยน QC Mode แล้ว Form Schema เปลี่ยนเอง

- เปลี่ยน QC Mode จาก Basic → mode อื่น (ถ้ามี)  
- กดปุ่ม "Show Form Schema (Advanced)"  
- Expected:
  - JSON ใน textarea เปลี่ยนไปตาม preset ของ QC Mode ใหม่  
  - JSON ควรเป็น valid JSON เสมอ (parse ได้)

### Q-TC3 — เปลี่ยน Checkbox แล้ว Policy JSON เปลี่ยนเอง

- ติ๊ก/ไม่ติ๊ก Require Rework Edge / Allow Scrap / Allow Replacement  
- กด "Show QC Policy JSON (Advanced)"  
- Expected:
  - ค่าใน JSON ตรงกับ checkbox ที่เลือก  
  - ตัวแปร boolean ใน JSON เปลี่ยนสอดคล้องกับ UI

### Q-TC4 — Save/Reload แล้วค่าคงอยู่ครบ

- ตั้งค่า QC Mode + options ให้แตกต่างจาก default  
- Save graph  
- Reload editor แล้วโหลดกราฟเดิมขึ้นมา  
- Expected:
  - UI แสดง QC Mode และ checkbox ตามค่าที่เคยตั้ง  
  - เมื่อกด Show Advanced → JSON ทั้ง Form Schema และ QC Policy ตรงกับค่าที่เคยตั้งไว้ก่อนหน้า  
  - ไม่มี mismatch ระหว่าง UI กับ JSON

---

# 📝 Summary

Task 18.3 ทำสองเรื่องสำคัญพร้อมกัน:

1. **Start/Finish Node Standardization**  
   - Graph Designer มีมาตรฐานชัดเจน: 1 graph = 1 Start + 1 Finish  
   - Toolbar guard + backend validation ป้องกัน case error ตั้งแต่ต้น  
   - ช่วยให้การอ่านกราฟ, วิเคราะห์ token, เชื่อมกับระบบอื่นในอนาคต เป็นเรื่องตรงไปตรงมา

2. **QC Panel Simplification & JSON Encapsulation**  
   - ผู้ใช้ทั่วไปไม่ต้องแตะ JSON เลย  
   - QC ตั้งค่าจาก UI ปกติ (QC Mode + checkbox)  
   - Form Schema & QC Policy JSON ถูก generate อัตโนมัติและ sync จาก UI  
   - Dev/AI ยังเข้าถึง JSON ได้ผ่าน Advanced view เพื่อ debug/ต่อยอด

> เกณฑ์จบงาน: 
> - ผู้ใช้ทั่วไปสามารถสร้างกราฟ + ตั้งค่า QC ได้โดยไม่เคยเปิดดู JSON เลย แต่ระบบก็ทำงานถูกต้อง  
> - ถ้าเปิดดู JSON (Advanced) เมื่อใด ค่านั้นต้องสะท้อน UI ปัจจุบันเสมอ  
> - ไม่สามารถสร้าง Start/Finish ผ่าน toolbar ได้มากกว่า 1 ตัวในกราฟเดียวกัน และ backend ไม่ยอมรับกราฟที่ผิดกติกานี้
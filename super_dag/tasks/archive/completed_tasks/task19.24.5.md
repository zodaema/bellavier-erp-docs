# Task 19.24.5 — JavaScript Slimming (Phase 1: SuperDAG UI Core)

## Objective

ลดขนาดและความซับซ้อนของ **SuperDAG front-end layer** โดยไม่เปลี่ยนพฤติกรรมระบบ  
โฟกัสที่ 3 ไฟล์หลัก:

- `assets/javascripts/dag/graph_designer.js`
- `assets/javascripts/dag/modules/GraphSaver.js`
- `assets/javascripts/dag/modules/conditional_edge_editor.js`

เป้าหมาย Phase 1 คือ **ลบ/ยุบโค้ดที่ซ้ำซ้อนและ legacy** ซึ่งปัจจุบันถูกแทนที่ด้วย
- `GraphValidationEngine`
- `SemanticIntentEngine`
- `GraphAutoFixEngine` + `ApplyFixEngine`

เพื่อให้โค้ดอ่านง่ายและพร้อมต่อยอด ETA Engine (Task 20.x)

---

## Scope

### 1) `graph_designer.js` — Remove Legacy & Dead Logic

**ไฟล์:** `assets/javascripts/dag/graph_designer.js`  

โฟกัสเฉพาะส่วนที่เกี่ยวกับ SuperDAG Graph Designer (node/edge canvas, validate, autofix, save, publish)

ให้ AI Agent ทำสิ่งต่อไปนี้:

1. **ลบ Client-side Validation Logic ที่ซ้ำกับ Backend**

   - ค้นหาและลบฟังก์ชัน / บล็อกโค้ดที่:
     - วิเคราะห์โครงสร้างกราฟเอง เช่น loop nodes/edges เพื่อหา:
       - multi-outgoing edge rules
       - QC coverage
       - parallel split / merge rules
       - unreachable / dead-end node
     - ผลิต error / warning message เองเกี่ยวกับ graph correctness

   - หลังจบ Task 19.24.x:
     - การ validate ทั้งหมดต้องเรียกผ่าน API เท่านั้น:
       - `graph_validate`
       - `graph_save`
       - `graph_save_draft`
       - `graph_publish`
     - ฝั่ง JS ทำอย่างมากแค่:
       - แสดงผล errors/warnings จาก backend
       - เรียก autofix / apply_fixes

2. **ลบ Legacy Keyboard Shortcuts ที่ไม่ใช้แล้ว**

   - ค้นหา keyboard handler ที่สร้างหรือจัดการ node types ต่อไปนี้:
     - `split`, `join`, `wait`, decision node (legacy)
   - ถ้า UI ปัจจุบันไม่มีปุ่ม/เมนูให้สร้าง node เหล่านี้แล้ว:
     - ลบ shortcut handler เหล่านั้นออก
   - เก็บเฉพาะ shortcut ที่ยังมีปุ่มใน toolbar หรือ UX ปัจจุบันใช้จริง

3. **ลบ / รวม Event Handlers ที่ซ้ำซ้อน**

   - หากมี handler แยกระหว่าง:
     - click บนปุ่ม + keyboard shortcut
   - ให้รวม logic เข้า helper เดียว เช่น:
     - `performSave()` / `performValidate()` / `performAutoFix()`
   - ลบ event handler ที่:
     - ไม่ถูก bind ที่ไหนแล้ว
     - มี comment ว่า `legacy` หรือ `deprecated` และไม่มีการใช้งานจริง

4. **ลบ Debug / Console Logging ที่ไม่จำเป็น**

   - ลบ `console.log`, `console.warn`, `console.error` ที่ใช้ debug ชั่วคราว เช่น:
     - log โครงสร้างกราฟทั้งก้อน
     - log condition JSON ทั้งชุด
     - log qc_policy raw / normalized ที่เป็น dev-debug
   - ยกเว้น:
     - error ที่เกี่ยวข้องกับ UX จริง ๆ เช่น network error ที่ user ควรรู้

5. **คง Behavior ที่ผู้ใช้เห็นให้เหมือนเดิม**

   - ห้ามเปลี่ยน:
     - รูปแบบ payload ที่ส่งให้ API
     - ลำดับ flow: edit → validate → autofix → save/publish
   - ห้ามเปลี่ยน:
     - ชื่อ action หลัก เช่น `graph_validate`, `graph_autofix`, `graph_apply_fixes`
   - หากต้อง refactor ฟังก์ชัน:
     - ให้คง signature เดิม (parameters, return type) เท่าที่ทำได้

---

### 2) `GraphSaver.js` — Slim Serialization Layer

**ไฟล์:** `assets/javascripts/dag/modules/GraphSaver.js`

หน้าที่ของไฟล์นี้ควรเหลือแค่:

- อ่าน state จาก Graph Designer
- แปลงเป็น payload JSON สำหรับ API:
  - `graph_save`
  - `graph_save_draft`
  - `graph_publish`

ให้ AI Agent ทำสิ่งต่อไปนี้:

1. **ลบฟังก์ชันที่ซ้ำกับ Backend/Helper**

   - ค้นหา logic ที่พยายามทำงานเหล่านี้:
     - normalize node/edge structure
     - คำนวณ condition coverage หรือ routing pattern
     - สร้าง semantic information เอง
   - ถ้า logic นั้นมีใน backend อยู่แล้ว (`GraphHelper`, `SemanticIntentEngine`, ฯลฯ) ให้ลบจาก JS

2. **ลบ Legacy Validation Functions**

   - ยืนยันว่าไม่มีฟังก์ชัน:
     - `validateGraphStructure()`
     - หรือชื่ออื่นที่ทำ validation ก่อน save
   - ถ้าพบให้ลบออกหรือเปลี่ยนให้เรียก API validation แทน (ผ่าน graph_designer.js)

3. **ลดขนาดให้เหลือ core responsibilities**

   - สแกนหา helper functions ที่:
     - ไม่เคยถูกเรียกใช้อีกต่อไป (search ทั้ง project)
     - ทำงานคล้ายกันหลายตัว
   - ลบส่วนที่ไม่ใช้ และรวม logic ที่ซ้ำกันเข้าด้วยกัน

---

### 3) `conditional_edge_editor.js` — Remove Legacy QC/Decision Logic

**ไฟล์:** `assets/javascripts/dag/modules/conditional_edge_editor.js`

บทบาทของ module นี้: **UI-only editor**  
สำหรับสร้างและแก้ไข **conditional edge conditions** บน basis ของ unified condition model

ให้ AI Agent ทำสิ่งต่อไปนี้:

1. **ลบ Legacy QC Condition Parsing**

   - ลบฟังก์ชันที่ทำงานกับ:
     - free-text condition expression (เช่น parse string แบบ custom)
     - legacy field เช่น `qcPass`, `isPass`, `failed`, ฯลฯ
   - ปัจจุบัน ConditionEngine ใช้ model แบบ structured JSON แล้ว:
     - UI ควรแค่สร้าง object ตาม spec (field/operator/value/groups)

2. **ลบ UI-Level QC Coverage Validation**

   - ถ้ายังมี logic ฝั่ง editor ที่:
     - enforce ว่าต้องมี pass/fail_minor/fail_major ครบ
     - หรือเตือน missing statuses ด้วยตัวเอง
   - ให้ลบออกแล้วปล่อยให้ backend validation ทำ (GraphValidationEngine)

   - UI validation ที่ยังควรมี:
     - field ต้องไม่ว่าง
     - operator ต้องไม่ว่าง
     - value ต้องไม่ว่าง
     - รูปแบบ JSON ต้องถูกต้องก่อนส่ง

3. **ปรับ Template ให้ตรงกับ Spec ปัจจุบัน**

   - ตรวจ QC templates:
     - `Pass → Next | Fail → Rework`
     - 3-way routing ตาม Task 19.x
   - ลบ template เก่าที่ไม่สอดคล้องกับ:
     - QC Routing Safety Spec (Task 19.0–19.1)
     - Condition model แบบใหม่ (Task 19.1–19.6)

4. **รักษา UX Layout ปัจจุบัน**

   - อย่าแก้โครง UI หลัก:
     - Card-based condition groups
     - OR separators
     - Default route (Else) section
     - Advanced JSON view toggle
   - อนุญาต refactor เฉพาะภายใน:
     - การจัดการ state groups/conditions
     - การ serialize/deserialize condition model

---

## Non-Goals

ใน Task 19.24.5 **ห้ามทำสิ่งต่อไปนี้**:

- เพิ่ม routing feature ใหม่
- เปลี่ยน field names / structure ของ condition JSON
- เปลี่ยน API contract ของ:
  - `graph_validate`
  - `graph_autofix`
  - `graph_apply_fixes`
  - `graph_save` / `graph_save_draft` / `graph_publish`
- ลบหรือลดความสามารถของ Autofix UI
- แก้ไข test harness หรือ snapshot test (ถ้า fail ถือว่า clean-up แรงเกิน ให้ rollback จุดนั้น)

---

## Acceptance Criteria

เมื่อจบ Task 19.24.5 ต้องเป็นจริงทั้งหมด:

### A. graph_designer.js

- ไม่มีฟังก์ชันที่ทำ semantic/structural validation เอง  
  (ทุก validation ต้องมาจาก backend)
- ไม่มี keyboard shortcut สำหรับ node types ที่เลิกใช้แล้ว:
  - split, join, wait, decision
- ไม่มี debug `console.log`/`console.warn` ที่ไม่จำเป็นใน SuperDAG core

### B. GraphSaver.js

- ไม่เหลือฟังก์ชัน `validateGraphStructure()` หรือฟังก์ชันที่ทำ validation ก่อน save
- ไม่มี logic ที่ซ้ำกับ `GraphHelper` หรือ Semantic layer
- ไฟล์มีบทบาทชัดเจน: graph state → API payload

### C. conditional_edge_editor.js

- ไม่มี QC coverage validation ฝั่ง JS (coverage + semantics ให้ backend ทำ)
- ไม่มี free-text condition parsing หรือ legacy QC parsing
- Templates ที่มีอยู่สอดคล้องกับ spec 19.x ปัจจุบัน

### D. Tests & Runtime

- `php tests/super_dag/ValidateGraphTest.php` ผ่านทั้งหมด
- `php tests/super_dag/SemanticSnapshotTest.php` ผ่านทั้งหมด
- `php tests/super_dag/AutoFixPipelineTest.php` ผ่านทั้งหมด
- เปิดหน้า Graph Designer:
  - สร้าง/แก้ไข graph
  - ใช้ conditional edges
  - ใช้ validate + autofix + save/publish  
  **ต้องไม่มี JS error ใหม่ใน console**

---

## Notes for AI Agent

- ก่อนลบ logic ใด ให้ตรวจด้วย:
  - ยังมี reference อยู่ใน project หรือไม่ (searchทั้งโปรเจกต์)
  - มี test ใดอ้างอิง behavior นั้นอยู่หรือไม่
- ถ้าลบแล้ว test fail:
  - ให้ rollback เฉพาะจุดนั้น
  - ใส่ comment:  
    `// TODO(SuperDAG-LeanUp): legacy but still in use`  
    เพื่อกลับมาเก็บใน Phase ถัดไป
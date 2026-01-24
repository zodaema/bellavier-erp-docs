

# Task 19.24.3 – Lean-Up Pass 1 for `dag_routing_api.php`

## 1. เป้าหมาย (Goal)

ทำให้ไฟล์ `source/dag_routing_api.php` “ลีนขึ้น” รอบแรก **โดยไม่เปลี่ยนพฤติกรรม** ของระบบ:
- ตัดโค้ดที่เป็น legacy/dead code จริง ๆ ออก
- จัดโครงสร้างภายในไฟล์ให้เห็นภาพชัดขึ้น แต่ **ยังไม่แยก Service/Class ใหม่**
- เตรียมพื้นฐานสำหรับ Lean-Up ระยะถัดไป (19.24.4+)

> **สำคัญมาก:** Task นี้ห้ามเปลี่ยนพฤติกรรม API, JSON schema, หรือ SQL logic ที่ถูกใช้งานอยู่แล้ว

---

## 2. ขอบเขต (Scope)

### 2.1 ไฟล์ที่เกี่ยวข้องหลัก

- `source/dag_routing_api.php` **เท่านั้น**

### 2.2 ไฟล์ที่อ่านอย่างเดียว / ห้ามแก้ใน Task นี้

ใช้เพื่ออ่านอ้างอิง / ตรวจว่า logic ใหม่ยังสอดคล้อง:

- `source/BGERP/Dag/GraphValidationEngine.php`
- `source/BGERP/Dag/SemanticIntentEngine.php`
- `source/BGERP/Dag/GraphHelper.php`
- `source/BGERP/Dag/ReachabilityAnalyzer.php`
- `source/BGERP/Dag/GraphAutoFixEngine.php`
- `source/BGERP/Dag/ApplyFixEngine.php`

> ห้ามแก้ไฟล์ในกลุ่ม Engine เหล่านี้ใน Task 19.24.3

---

## 3. ข้อห้าม (Hard Constraints)

1. **ห้ามเปลี่ยน signature** ของ API actions ใน `dag_routing_api.php`:
   - ชื่อ action (`$_REQUEST['action']`)
   - รูปแบบ request/response JSON
   - HTTP status codes และ `app_code`

2. **ห้ามเปลี่ยน SQL queries** ที่เกี่ยวข้องกับ:
   - โหลด/บันทึกกราฟ (`routing_graph`, `routing_node`, `routing_edge`)
   - เวอร์ชันกราฟ / draft
   - ค่าที่ UI พึ่งพา เช่น `node_params`, `qc_policy`, `form_schema_json`

3. **ห้ามย้าย logic ออกไปต่างไฟล์** ใน Task นี้:
   - ยังไม่สร้าง service ใหม่ (เช่น `GraphApiService`)
   - ยังไม่ refactor เป็น class-based controller

4. **ห้ามลบโค้ดใด ๆ ที่ยังถูกเรียกใช้**:
   - ต้องตรวจด้วย “ค้นหา reference ทั้งโปรเจกต์” ก่อนลบเสมอ
   - ถ้าไม่มั่นใจว่าใช้หรือไม่ ให้คงไว้ก่อน (ค่อยลบใน Phase ถัดไป)

---

## 4. สิ่งที่ “อนุญาตให้ทำ” ใน 19.24.3

### 4.1 ลบ Legacy Validation / Dead Code ที่ไม่ได้ใช้งานแล้ว

ให้ค้นหา pattern ต่อไปนี้ใน `dag_routing_api.php`:

1. **ฟังก์ชัน validate graph แบบเก่า**
   - โค้ดที่เคยใช้ `validateGraphStructure()` หรือ logic ที่เราเพิ่งลบใน Task 19.24.2
   - ถ้ายังมี comment หรือ stub เหลืออยู่ที่ไม่ได้ถูกเรียกใช้ → สามารถ **ลบออกได้**

2. **โค้ดที่ถูก comment-out มานาน** และมี tag ประมาณนี้:
   - `// LEGACY`
   - `// DEPRECATED`
   - `// OLD`
   - `// TODO: remove after SuperDAG`
   - ให้พิจารณา:
     - ถ้า block นั้นไม่ถูกเรียกจาก action ใด ๆ แล้ว → ลบทิ้ง
     - ถ้าเป็นเพียง logging/debug ที่ไม่ critical → ลบทิ้งได้

3. **Debug / temporary logging** ที่ไม่ critical:
   - `error_log()` ที่ใช้ debug ระหว่างพัฒนา SuperDAG
   - `var_dump`, `print_r`, `die`, `exit` ที่ถูก comment ไว้
   - เฉพาะที่ไม่อยู่ใน error-handling จริง ๆ

> **Reminder:** ก่อนลบ logic ใหญ่ ให้ค้นหาทั้งโปรเจกต์ (project-wide search) ว่ายังมีการเรียกใช้ function/segment นั้นอยู่หรือไม่

---

### 4.2 จัดระเบียบโครงสร้างภายในไฟล์ (แต่ยังไม่ย้ายไฟล์)

ให้จัดโค้ดใน `dag_routing_api.php` ให้ “อ่านง่ายขึ้น” โดย:

1. เพิ่ม block comment แบบ Section เพื่อแบ่งส่วนหลัก ๆ:

   ตัวอย่างโครงสร้าง:

   ```php
   // ============================================================
   // 1. Bootstrap & Dependencies
   // ============================================================

   // ... require_once, use, setup ...


   // ============================================================
   // 2. Helper Functions (LOCAL ONLY)
   // ============================================================

   // ... helper functions ที่ใช้เฉพาะไฟล์นี้ ...


   // ============================================================
   // 3. Action Dispatch
   // ============================================================

   $action = $_REQUEST['action'] ?? null;
   switch ($action) {
       case 'graph_load':
           // ...
           break;

       case 'graph_save':
           // ...
           break;

       // ...
   }
   ```

2. ย้าย helper functions ที่กระจัดกระจายให้มาอยู่กลุ่มเดียวกันในส่วน “Helper Functions” ด้านบน **โดยไม่เปลี่ยนเนื้อหา**:

   - ห้ามแก้ logic หรือเพิ่ม parameter
   - แค่เลื่อนตำแหน่ง function ในไฟล์

3. จัด format ให้สม่ำเสมอ:
   - เว้นบรรทัดระหว่าง case ของ `switch($action)`
   - จัด indent ให้เรียบร้อย (4 spaces)
   - ปรับ comment ให้ตรงกับ code block ที่มันอธิบาย

> **สำคัญ:** การจัดระเบียบนี้ห้ามเปลี่ยนลำดับการทำงานของ action หรือ conditional logic ภายใน action ใด ๆ

---

## 5. Checklist สำหรับปลาย Task

เมื่อทำ 19.24.3 เสร็จ ต้องเช็คให้ครบ:

1. ✅ ไฟล์ `dag_routing_api.php` ยังสามารถ:
   - โหลดกราฟได้ (graph_load)
   - บันทึกกราฟได้ (graph_save)
   - บันทึก draft ได้ (graph_save_draft)
   - publish ได้ (graph_publish)
   - validate ได้ (graph_validate)
   - autofix pipeline ใช้งานได้

2. ✅ SuperDAG Tests ทั้งหมดต้องยังผ่าน:
   ```bash
   php tests/super_dag/ValidateGraphTest.php
   php tests/super_dag/SemanticSnapshotTest.php
   php tests/super_dag/AutoFixPipelineTest.php
   ```

3. ✅ ไม่เกิด error ใหม่ใน log จาก `dag_routing_api.php` (ตรวจ `logs/app.log` หรือที่เก็บ log ปัจจุบัน)

4. ✅ สร้างไฟล์สรุปผล:
   - `docs/super_dag/tasks/task19.24.3_results.md`  
   โดยระบุ:
   - บรรทัดที่ถูกลบ/ย้าย (ประมาณการ)
   - รายการ helper functions ที่ถูกย้ายไปรวมกลุ่ม
   - สิ่งที่ explicit ว่า “ยังไม่แตะ” (เช่น logic รูทใหญ่ของแต่ละ action)

---

## 6. Non-Goals (สิ่งที่ยังไม่ทำใน 19.24.3)

- ยัง **ไม่** แยก `dag_routing_api.php` ออกเป็นหลายไฟล์
- ยัง **ไม่** สร้าง `GraphApiService` หรือ class ใหม่
- ยัง **ไม่** ผูก dependency injection
- ยัง **ไม่** ปรับลด parameter/field ใด ๆ ใน JSON

สิ่งเหล่านี้จะถูกทำใน Task ถัดไป (19.24.4+)

---

## 7. TL;DR สำหรับ AI Agent

> “โฟกัสที่การ **ทำความสะอาด** `dag_routing_api.php` รอบแรก:  
> - ลบ legacy/dead code จริง ๆ ที่ไม่ถูกใช้แล้ว  
> - รวม helper functions ให้อยู่เป็นกลุ่มในไฟล์  
> - จัด Section/comment ให้โครงสร้างไฟล์อ่านง่ายขึ้น  
> - ห้ามเปลี่ยน behavior, ห้ามเปลี่ยน signature, ห้ามแตกไฟล์ใหม่  
> - รัน tests ทั้งหมดให้ผ่านเหมือนเดิม”
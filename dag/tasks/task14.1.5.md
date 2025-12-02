

# Task 14.1.5 — Targeted Legacy Reference Cleanup (Wave A)

**Status:** PLANNING → to be executed by AI Agent  
**Series:** Task 14.1.x — Pre‑cleanup before Task 14.2 (Master Schema V2)

---

## 1. Background & Intent

Task 14.2 (Master Schema V2 cleanup) ถูก *ยกเลิกชั่วคราว* เพราะยังพบการอ้างอิง legacy schema จำนวนมาก (เช่น `stock_item`, `bom_line`, `routing` V1, `id_stock_item`, `id_routing`) กระจายอยู่ในหลายไฟล์ ถ้าลบ schema ตอนนี้มีโอกาสทำระบบพังทั้งกระดานได้สูงมาก

**Task 14.1.5 = Plan A (Incremental Cleanup).**  
เป้าหมายคือ “กวาดเก็บ legacy references แบบย่อย ๆ ที่มีความเสี่ยงต่ำ” เพื่อค่อย ๆ ลดหนี้เทคนิค และค่อย ๆ ขยับเข้าใกล้ Task 14.2 อย่างปลอดภัยที่สุด โดย **ไม่แตะ schema** และ **ไม่เปลี่ยน behavior** ที่ผู้ใช้สัมผัสได้

> มอง Task 14.1.5 ว่าเป็น "Wave A" ของการล้าง legacy references ที่เน้นเก็บจุดที่ปลอดภัยก่อน (report‑only, helper‑only, no‑write) เพื่อเปิดทางให้ Wave B/C ตามมาในอนาคต

---

## 2. Scope ของ Task 14.1.5

### 2.1 หลักการเลือก Scope

ให้ AI Agent ยึดหลักดังนี้:

1. **แตะเฉพาะส่วนที่เป็น READ‑only หรือ helper เท่านั้น**
   - Report screens
   - Helper classes (resolvers, mappers)
   - API ที่ response ใช้เพื่อ UI read‑only เท่านั้น

2. **ไม่แตะส่วนที่มี WRITE/INSERT/UPDATE/DELETE**
   - ห้ามแก้ flow การสร้าง / แก้ไขข้อมูลที่ critical (MO, job ticket, routing execution, stock movement จริง)

3. **ไม่แตะส่วนที่ยังไม่เข้าใจธุรกิจ 100%**
   - ถ้า query มี join เยอะ / logic ซับซ้อน / พัวพันหลายตาราง และยังไม่มั่นใจ → ให้ข้าม (document ไว้ใน results แทน)

4. **ไม่แตะ schema / ไม่ลบ column / ไม่ drop table**
   - Task 14.1.5 เป็น *code‑level cleanup* เท่านั้น
   - งาน schema cleanup ทั้งหมดต้องไปทำใน Task 14.2+ เท่านั้น

### 2.2 กลุ่มไฟล์เป้าหมายใน Wave A

> หมายเหตุ: รายการนี้อ้างอิงจาก risk map ของ Task 14.2 ที่ถูก abort — ถ้า Agent พบว่าบางไฟล์มี dependency ซับซ้อนเกินไป ให้ข้ามและบันทึกในผลลัพธ์

**A. Stock / Material (อ่านอย่างเดียว)**
- `source/trace_api.php`
- `source/leather_cut_bom_api.php`
- `source/BGERP/Helper/MaterialResolver.php`

**B. BOM / Component (อ่านอย่างเดียว)**
- `source/component.php`
- `source/BGERP/Component/ComponentAllocationService.php` (เฉพาะส่วน read helper ที่ไม่กระทบ execution)

**C. Routing (อ่านอย่างเดียว / debug / helper)**
- `source/routing.php` (เฉพาะส่วนที่ยังใช้เป็น read‑only debug; ห้ามไป reopen write logic)
- `source/BGERP/Helper/LegacyRoutingAdapter.php` (สามารถ tidy up หรือหุ้ม fallback ให้ปลอดภัยขึ้น แต่ห้ามลบ)

> ถ้า Agent ตรวจพบว่าไฟล์ใด "ไม่มี" การอ้างอิง legacy แล้ว ให้บันทึกด้วย เพื่อให้เรารู้ว่าจุดนั้นปลอดภัยแล้ว

---

## 3. เป้าหมายของ Task 14.1.5

1. **ลดการอ้างอิงตรงไปยัง legacy tables/columns**
   - เช่น เปลี่ยนจากการ query `stock_item` ตรง ๆ มาใช้ `material` + adapter ที่มีอยู่แล้ว (ถ้ายังไม่ได้ migrate)
   - ใช้ helper ที่มีอยู่ เช่น `MaterialResolver`, `LegacyRoutingAdapter` แทนการเขียน SQL ตรงซ้ำ ๆ

2. **ทำให้ flow อ่านข้อมูลสอดคล้องกับภาพใหญ่ของ V2**
   - Stock → มาจาก `material` + `material_lot` (หรือ adapter ที่สร้างไว้ใน 14.1.1–14.1.2)
   - BOM → ใช้ service layer ที่อยู่ใน `BOMService` / component services แทน join legacy โดยตรง (ถ้าเป็นไปได้)
   - Routing → ให้ `DagExecutionService` และ routing V2 เป็นเจ้าหลัก, V1 ใช้แค่ fallback ผ่าน adapter

3. **สร้างเอกสารและ checklist ที่ update แล้ว**
   - บันทึกให้ชัดว่าไฟล์ไหน:
     - ✅ Migrate เรียบร้อย (ไม่มี legacy refs อีก)
     - ⚠️ ยังมี legacy refs แต่มีเหตุผล (เช่น ถูกใช้จริงใน flow ที่ยัง refactor ไม่เสร็จ)
     - ⛔ ห้ามแตะ (critical, รอ Task ใหญ่)

---

## 4. สิ่งที่ Agent "ทำได้" และ "ห้ามทำ" ใน Task 14.1.5

### 4.1 ทำได้

1. **Refactor Query (READ เท่านั้น)**
   - แทนที่การ select จาก `stock_item` ด้วย select จาก `material` (ใช้ patterns จาก Task 14.1.1 เป็นต้นแบบ)
   - ใช้ `JOIN material` แล้ว map field เดิมกลับไปให้ JSON shape เดิมยังอยู่ (เช่น alias เป็น `id_stock_item` ถ้าจำเป็น)

2. **ห่อ logic ไว้ใน Helper ที่มีอยู่แล้ว**
   - ถ้าเห็น query เดิมที่ duplicate กับ logic ใน `MaterialResolver` หรือ service อื่น ให้เปลี่ยนมาใช้ helper/service แทน

3. **เพิ่ม comments / deprecation notes**
   - Mark ตำแหน่งที่ยังใช้ legacy เช่น `// TODO(14.2): still uses bom_line`
   - เพิ่มคำเตือนว่า logic นี้ยังขึ้นกับ schema V1 และห้ามลบ table/column จนกว่า Task 14.2 จะปิด

4. **Update docs / scan notes**
   - Update เอกสารใน `docs/dag/tasks/task14.1.4_results.md` หรือสร้าง `task14.1.5_results.md` เพื่อสรุปสิ่งที่ทำและสิ่งที่ยังเหลือ

### 4.2 ห้ามทำ

1. ❌ ห้ามลบตาราง / column ใด ๆ (เช่น `stock_item`, `bom_line`, `routing` V1)
2. ❌ ห้ามลบ field จาก JSON response ที่ frontend ใช้อยู่
3. ❌ ห้ามเปลี่ยน behavior ที่ผู้ใช้มองเห็น (เช่น จำนวน row เปลี่ยน, filter เปลี่ยน, sort เปลี่ยน) ยกเว้นกรณีที่มี bug เด่นชัดและแก้ไขอย่างระมัดระวังพร้อมเขียนผลใน docs
4. ❌ ห้ามแก้ Time Engine, Token Engine, DAG Execution core (พวก `DagExecutionService`, `TokenWorkSessionService`, ฯลฯ)
5. ❌ ห้ามแก้ Component Binding / Component Enforcement logic (Task 13.x) ในงานชุดนี้

---

## 5. Workflow ที่แนะนำให้ AI Agent ใช้

ให้ Agent ทำงานตามลำดับนี้:

1. **Phase 0 — Re‑scan (ยืนยันสภาพล่าสุด)**
   - รัน scan เพื่อหาคำว่า `stock_item`, `bom_line`, `id_stock_item`, `id_routing`, `routing` table ใน codebase
   - เปรียบเทียบกับ risk map จาก `task14.2_scan_error_report.md`
   - อัปเดต findings ลงใน `docs/dag/tasks/task14.1.5_scan_results.md`

2. **Phase 1 — Refactor Low‑Risk READ Queries**
   - เลือกไฟล์ที่อยู่ในกลุ่ม A/B/C (ด้านบน) ที่เป็น read‑only
   - ใช้ patterns จาก Task 14.1.1–14.1.3 ในการ migrate query
   - รัน `php -l` ทุกไฟล์ที่แก้ และถ้ามี test suite เฉพาะ ให้รันด้วย (อย่างน้อย smoke tests)

3. **Phase 2 — Update Docs & Risk Map**
   - สร้าง/อัปเดต `docs/dag/tasks/task14.1.5_results.md`:
     - ไฟล์ไหน migrate แล้ว
     - ไฟล์ไหนยังคง legacy references → ระบุเหตุผลและ level of risk
   - ถ้าระหว่างทางพบ logic ที่เสี่ยง → เขียน section "DO NOT TOUCH UNTIL TASK 14.2" ให้ชัดเจน

4. **Phase 3 — Prepare for Task 14.2**
   - อัปเดต note ใน `task14.2_scan_error_report.md` หรือสร้าง section ใหม่ ว่า:
     - หลัง Task 14.1.5 เหลือ legacy refs อยู่ที่ไหนบ้าง
     - ถ้าจะทำ Task 14.2 ต่อ ขั้นตอนแรกควรแตะไฟล์ใดก่อน

---

## 6. Definition of Done (Task 14.1.5)

Task 14.1.5 ถือว่า **เสร็จสมบูรณ์** เมื่อ:

1. มีไฟล์ `docs/dag/tasks/task14.1.5_scan_results.md` ที่อัปเดตสภาพล่าสุดของ legacy refs แล้ว
2. มีไฟล์ `docs/dag/tasks/task14.1.5_results.md` ที่สรุปว่า:
   - ไฟล์ใดถูก migrate แล้ว (พร้อมตัวอย่าง pattern ที่ใช้)
   - ไฟล์ใดยังเหลือ legacy refs และเพราะเหตุใด
3. ไฟล์ในกลุ่ม A/B/C ที่เป็น read‑only ถูก migrate เท่าที่ปลอดภัยและสมเหตุสมผล โดย:
   - `php -l` ผ่านทุกไฟล์
   - ไม่มีการผิดรูปของ JSON response (ยืนยันด้วยการดูตัวอย่าง response อย่างน้อย 1 ชุดต่อ endpoint)
4. ไม่มีการแก้ schema / drop table / ลบ column ใน Task 14.1.5
5. มี note ชัดเจนใน docs ว่า Task 14.2 ยัง **ห้ามเริ่ม** จนกว่าจะ review ผลงาน Task 14.1.5 และ confirm ว่า legacy refs ลดลงจริง

---

## 7. หมายเหตุถึงมนุษย์ (Founder / Lead Engineer)

- Task 14.1.5 ตั้งใจให้เป็น **งานเก็บกวาดแบบค่อยเป็นค่อยไป** ไม่ใช่ big‑bang migration
- ทุกการเปลี่ยนแปลงควรอ่านง่าย, มี comment, และผูกกับหมายเลข task (14.1.5) เพื่อย้อนรอยได้
- เมื่อ Agent ทำงานเสร็จ แนะนำให้คุณ:
  1. เปิดอ่าน `task14.1.5_results.md`
  2. ดู diff ของไฟล์ในกลุ่ม A/B/C
  3. ลองยิง API ที่เกี่ยวข้อง 1–2 endpoint เพื่อเช็ค output ว่ายังเป็นไปตามที่คาดหวัง
- ถ้ารู้สึกว่า risk ยังสูง → สามารถสร้าง Task 14.1.6 เป็น "Wave B" ที่ละเอียดขึ้น หรือเลือกหยุดรอจนกว่าระบบจะนิ่งก่อนทำ Task 14.2

> เป้าหมายสุดท้าย: ค่อย ๆ ทำให้ codebase ขยับเข้าใกล้ Master Schema V2 โดยที่ไม่เสี่ยง "ถอนเสาเข็ม" ระบบที่ใช้งานอยู่ทุกวัน


# Task 19.16 — Final Validation Flow Consistency & QC 2-Way Routing

**Status:** Planned  
**Owner:** SuperDAG Core  
**Depends on:** Tasks 19.7–19.15

---

## 1. Objective

หลังจากเราเปลี่ยนมาใช้ `GraphValidationEngine` + `SemanticIntentEngine` + `GraphAutoFixEngine` และปิด Legacy Validator ส่วนใหญ่แล้ว ยังมีจุดที่ต้องเก็บรายละเอียดให้เรียบร้อย เพื่อให้:

1. **ทุก flow การ validate** (manual save, autosave, publish, autofix) ใช้ engine ใหม่เป็น **แหล่งความจริงเดียว** (single source of truth)
2. **QC 2-way routing** (Pass → Next, Else → Rework) ทำงานได้จริง โดยไม่โดนบล็อคด้วย error เก่า เช่น `QC_MISSING_ROUTES`
3. UI, API, Engine ส่งและแสดงผล error/warning ในรูปแบบเดียวกัน และไม่ถูกดึงข้อมูลจาก legacy structure อีกต่อไป

เป้าหมายของ Task 19.16 คือทำให้ Validation Layer เข้าสู่สภาวะ **consistent, predictable, engine-driven 100%** ก่อนเข้าสู่ Phase 20 (ETA/Time Engine).

---

## 2. Scope

### In Scope
- `GraphValidationEngine` (QC routing module, reachability already done in 19.15)
- `dag_routing_api.php` (graph_validate, graph_save, graph_save_draft, graph_publish)
- `graph_designer.js` (validate-before-save, error/warning rendering, autofix flow)

### Out of Scope (ไว้ Task ถัดไป)
- การลบไฟล์ legacy ออกจาก repo จริง ๆ (จะไปอยู่ Task 19.17+)
- การปรับ UI visual (badges, icons) เชิง cosmetic (จะไปอยู่ Task 19.16.x / 19.18)

---

## 3. Work Items

### 3.1 QC 2-Way Routing — Ensure Warning-only, Never Error

**File:** `source/BGERP/Dag/GraphValidationEngine.php`

1. เปิดดู method ที่เกี่ยวข้องกับ QC routing:
   - `validateQCRouting()` (structural, now light-check only หลัง 19.13.1)
   - `validateQCRoutingSemantic()` หรือ method ที่ใช้ rule set `QC_ROUTING` / error code `QC_MISSING_ROUTES` (ถ้ามีอยู่)

2. ยืนยันและปรับกติกาให้ชัดเจน:
   - **ไม่อนุญาตให้สร้าง error** ประเภท: `QC_MISSING_ROUTES` จากกรณีที่ขาด `fail_minor`, `fail_major` **ถ้า** มีอย่างน้อย:
     - route สำหรับ `qc_result.status == "pass"`, และ
     - default/else route (edge ที่ระบุว่าเป็น default หรือไม่มี condition)
   - ในกรณีนี้ ต้องลดเหลือแค่ **warning** หรือไม่เตือนเลย (ขึ้นกับ policy ที่กำหนดใน semantic document)

3. ถ้ายังมีโค้ดที่ push error ลักษณะนี้:
   ```php
   $errors[] = [ 'code' => 'QC_MISSING_ROUTES', ... ];
   ```
   ให้เปลี่ยนเป็น warning หรือเอาออกไปเลย แล้วใช้เฉพาะ semantic layer ที่ตรวจแบบ “soft” เท่านั้น.

4. เพิ่ม test case ในเอกสาร `qc_routing_test_cases.md` ให้ครอบคลุม:
   - Template: Pass → Next, Else → Rework (2 เส้น)
   - Expectation: `error_count = 0`, `warning_count >= 0`, ไม่มี error code `QC_MISSING_ROUTES`.

---

### 3.2 Normalize Default / Else Route Handling

**Files:**
- `source/BGERP/Dag/ConditionEvaluator.php`
- `assets/javascripts/dag/modules/conditional_edge_editor.js`
- `assets/javascripts/dag/modules/GraphSaver.js`

1. ยืนยันรูปแบบการเก็บ default/else route ใน edge condition:
   - ตัวอย่าง expected format:
     ```json
     {
       "type": "default"
     }
     ```

2. ใน `GraphSaver.js`:
   - ตรวจสอบว่าเมื่อผู้ใช้กดเลือก "Else / Default route" ใน UI, edge นั้นถูก serialize เป็น condition ที่ชัดเจน (เช่น `{"type":"default"}`) ไม่ใช่ `null`, `""`, `0`, หรือรูปแบบ legacy

3. ใน `ConditionEvaluator.php`:
   - ตรวจสอบว่า evaluator เข้าใจ default route ว่า:
     - ถ้า edge มี condition type = `default` → match สำหรับทุก case ที่ไม่ match edge อื่น ๆ ก่อนหน้า
   - ห้ามใช้ fallback แบบ “first edge wins” อีกต่อไป.

4. เพิ่ม test case ใน `qc_routing_test_cases.md` สำหรับ default route.

---

### 3.3 graph_validate / graph_save — Single Validation Source of Truth

**File:** `source/dag_routing_api.php`

1. ภายใต้ case:
   - `graph_validate`
   - `graph_save`
   - `graph_save_draft`
   - `graph_publish`

   ให้ตรวจสอบและยืนยันว่า:
   - **ไม่มีการเรียก** `validateGraphStructure()` รุ่นเก่าอีกต่อไป
   - **ไม่มีการสร้าง error/warning เพิ่มเติม** หลังจากได้ผลจาก `GraphValidationEngine` (ยกเว้น mapping/formatting)

2. รูปแบบมาตรฐานที่ต้องการ:
   ```php
   $engine = new GraphValidationEngine($db, $semanticEngine, $autoFixEngine?);
   $validation = $engine->validate($nodes, $edges, [
       'mode' => 'save' // or 'draft', 'publish'
   ]);

   // ใช้เฉพาะ $validation['errors'], ['warnings'], ['errors_detail'], ['warnings_detail']
   ```

3. `graph_save`:
   - ถ้า `error_count > 0` และไม่ใช่ autosave → block save, return error JSON พร้อม validation meta
   - ถ้า `error_count = 0` → ให้ดำเนินการ save ต่อได้
   - ถ้า `warning_count > 0` → ยังอนุญาต save แต่ต้องแนบ warning กลับไปให้ UI แสดง.

4. `graph_save_draft`:
   - อนุญาตให้ save ได้แม้มี errors บางชนิด (ถ้ามีนโยบาย soft validate สำหรับ draft) แต่ห้ามใช้ legacy rule; ต้องใช้ data set เดียวกับ `graph_validate` แล้วเลือก ignore บางรหัส error ที่อนุญาตได้.

---

### 3.4 UI Integration — ใช้ผลจาก API อย่างเดียว

**File:** `assets/javascripts/dag/graph_designer.js`

1. หา function ที่ใช้ validate ก่อน save เช่น:
   - `validateGraphBeforeSave()`
   - หรือ handler ของปุ่ม Save / Publish ที่เรียก API validate

2. ยืนยันว่า logic ภายใน **ไม่ทำ validation ฝั่ง frontend เอง** อีกต่อไป (Task 19.14 ตัดไปแล้ว แต่ให้ตรวจซ้ำอีกรอบ):
   - ไม่วน loop เช็ค QC route เอง
   - ไม่เช็ค work_center/work_station เอง
   - ไม่เช็ค parallel/merge เอง

3. UI ต้องอ่านข้อมูลจาก API ในรูปแบบ:
   ```js
   const { errors_detail, warnings_detail, score, intents } = validation;
   ```
   แล้ว render ตามนั้น (ไม่สำเนา logic เดิมใน JS).

4. เมื่อเจอ error code `QC_MISSING_ROUTES` จาก engine รุ่นเก่า (ถ้าหลงเหลือ) ให้ถือว่าเป็น bug และต้องไม่ถูกนำมาใช้แสดง (แต่หลังจากแก้ใน GraphValidationEngine แล้ว code นี้ไม่ควรถูกสร้างอีก).

---

### 3.5 Regression & Sanity Checks

1. ทดสอบกรณี QC 2-way routing:
   - Graph: START → OP → QC → (Pass) → FINISH, (Else) → REWORK_SINK
   - Expectation:
     - `graph_validate` → `error_count = 0`
     - อาจมี warning เบา ๆ หรือไม่มีเลย

2. ทดสอบกรณี QC ไม่มี Outgoing เลย:
   - Expectation: มี `warning` จาก `validateQCRouting()` (เช่น `QC_NO_OUTGOING_EDGES`), แต่ไม่พังระบบ.

3. ทดสอบ `graph_save`, `graph_save_draft`, `graph_publish` ให้แน่ใจว่า:
   - ใช้ result เดียวกับ `graph_validate`
   - ไม่มี error legacy message โผล่.

---

## 4. Acceptance Criteria

- [ ] ไม่มีการสร้าง error code `QC_MISSING_ROUTES` อีกต่อไปในกรณี QC 2-way routing (Pass + Else/Rework)
- [ ] Default/Else route ถูก serialize และ evaluate อย่างถูกต้อง โดย Condition Engine
- [ ] `graph_validate`, `graph_save`, `graph_save_draft`, `graph_publish` ใช้ `GraphValidationEngine` เป็น source เดียว
- [ ] UI (`graph_designer.js`) ไม่ทำ client-side validation logic ซ้ำกับ backend
- [ ] QC template "Pass → Next | Fail → Rework" สามารถ validate & save ได้โดยไม่มี error
- [ ] ไม่พบข้อความ error legacy ที่ขัดกับ spec ใหม่ใน Task 19.x

---

## 5. Notes

- Task 19.16 เป็นตัวปิด Phase 19 ในด้าน **"Behavior consistency"** ระหว่าง Engine, API, และ UI ก่อนเริ่ม Phase 20 (ETA / Time Modeling).
- การลบไฟล์ legacy, ลบโค้ดที่ไม่ถูกเรียกใช้อีกแล้ว จะถูกผลักไปไว้ใน Task 19.17+ เพื่อไม่ให้ปนกับงาน integration ครั้งนี้.
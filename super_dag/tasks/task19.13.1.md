

# Task 19.13.1 — QC & WorkCenter Semantic Rule Fix

## Objective
แก้ปัญหา Validation ที่ยัง "เข้มเกินไป" จาก GraphValidationEngine v3 ที่ทำให้:

1. QC Node ถูกบังคับว่าต้องมี 3 สถานะ (pass, fail_minor, fail_major) ทั้งที่ผู้ใช้งานตั้งใจใช้ 2-way routing (Pass + Else)
2. Work Center Rule ยังตรวจแบบเก่า ทำให้เตือนว่าผู้ใช้ "ไม่ได้เลือก Work Center" ทั้งที่เลือกแล้ว

## Goals
- ปรับ QC Routing Semantic ให้ตรงตาม Spec ใหม่ของ SuperDAG (2-way OK)
- ปรับ Work Center Semantic ให้ตรวจตาม field model ใหม่ (`work_center_code`)
- ลดระดับ Error → Warning ในกรณีตั้งใจใช้ routing แบบง่าย
- ป้องกัน false-positive เมื่อผู้ใช้ตั้งค่าถูกต้องแล้ว

---

## 1. GraphValidationEngine.php — QC Rule Update

### File:
`source/BGERP/Dag/Validation/GraphValidationEngine.php`

### Function to modify:
`validateQCRoutingSemantic()`

### Change 1 — ลดระดับ "Missing QC Status Coverage" เป็น Warning

1. ภายใน `validateQCRoutingSemantic()` ให้ค้นหา block ที่สร้าง error ข้อความประมาณ:
   - `"is missing edges for QC statuses"`
   - หรือข้อความเต็ม: `"All QC nodes must have edges covering pass, fail_minor, and fail_major."`

2. Block นี้ตอนนี้น่าจะเรียก helper เพิ่ม error เช่น:
   - `$this->addError(... 'QC_MISSING_STATUS_COVERAGE' ...)`
   - หรือ push เข้า `$errors_detail[]` โดยมี `severity` เป็น `error`.

3. ให้ปรับเป็น **Warning** แทน โดย:
   - ถ้าใช้ helper: เปลี่ยนจาก `addError` → `addWarning`
   - ถ้าสร้าง array เอง: เปลี่ยน `type` หรือ `severity` จาก `error` → `warning` และ push เข้า warnings list (`$warnings_detail`) แทน `$errors_detail`.

> NOTE: เพื่อความปลอดภัยใน Task 19.13.1 **ยังไม่ต้องเพิ่มเงื่อนไขซับซ้อนเรื่อง pass/non-pass route** 
> เพียงแค่ลดระดับจาก Error → Warning เพื่อไม่ block การบันทึกกราฟ

ผลลัพธ์ที่ต้องการ:
- กรณีที่ QC ขาด fail_minor / fail_major → ขึ้น Warning แต่ไม่ block save
- Logic ที่เหลือของ QC semantic ยังทำงานตามเดิม

---

## 2. GraphValidationEngine.php — WorkCenter Rule Fix

### Function (ตัวอย่างชื่อ):
อาจอยู่ใน `validateOperationSemantic()` หรือ method ใด ๆ ที่สร้างข้อความประมาณ:

> `"Operation node \"%s\" should have work center or team assigned."`

### Change 2 — ใช้ field `work_center_code` และ `team_category`

1. ค้นหาโค้ดที่สร้าง message ข้างต้น
2. ในเงื่อนไขก่อนเพิ่ม error/warning ให้แทนที่การอ่าน field เก่า เช่น:
   - `$node['id_work_center']`
   - `$node['work_center']`
   - `$node['work_station']`

   ด้วยเงื่อนไขใหม่:

   ```php
   $hasWorkCenter   = !empty($node['work_center_code'] ?? null);
   $hasTeamCategory = !empty($node['team_category'] ?? null);

   if (!$hasWorkCenter && !$hasTeamCategory) {
       // add warning as before
   }
   ```

3. ตรวจสอบว่า rule นี้ถูกเพิ่มเป็น **Warning** ไม่ใช่ Error (ถ้าปัจจุบันเป็น error ให้ลดระดับเป็น warning) — เพื่อไม่ block การ save ถ้าผู้ใช้ยังออกแบบกราฟอยู่

ผลลัพธ์ที่ต้องการ:
- ถ้าเลือก Work Center แล้ว (field `work_center_code` มีค่า) → ไม่เตือน
- ถ้าไม่ได้เลือก Work Center และไม่ได้เลือก Team Category → แค่ Warning (ไม่ block)

---

## 3. GraphSaver.js — ยืนยันว่าบันทึก work_center_code

### File:
`assets/javascripts/dag/modules/GraphSaver.js`

1. ค้นหาฟังก์ชันที่รวบรวม node data ก่อนส่งไป backend (เช่น `collectNodeData(node)` หรือคล้ายกัน)
2. ยืนยันว่ามีการเซ็ตค่า:

   ```js
   nodeData.work_center_code = node.work_center_code || selectedWorkCenterCode || null;
   ```

   - ถ้าในโค้ดมีการกำหนด `work_center_code` อยู่แล้ว → ไม่ต้องแก้
   - ถ้ายังไม่มี ให้เพิ่ม field นี้เข้าไปใน payload ที่ส่งกลับไป server

ผลลัพธ์ที่ต้องการ:
- เมื่อผู้ใช้เลือก Work Center ใน UI ค่า `work_center_code` ต้องถูก serialize กลับมาใน graph JSON ส่งเข้า API

---

## 4. Acceptance Criteria

- [ ] QC 2-way routing (Pass + Else/Rework) ไม่ถูก block ด้วย error เรื่อง missing fail_minor/fail_major อีกต่อไป
- [ ] การเตือนเรื่อง QC missing statuses ถูกลดระดับเป็น Warning เท่านั้น
- [ ] Work Center rule ตรวจจาก `work_center_code` + `team_category` แทน field legacy
- [ ] ถ้าเลือก Work Center แล้ว Warning จะไม่ขึ้นอีก
- [ ] ไม่มีการเรียกใช้ DAGValidationService กลับมาอีก
- [ ] GraphValidationEngine v3 ยังทำงานได้กับกราฟเก่า (backward compatible)

---

## 5. Notes

- Task 19.13.1 เป็น hotfix เชิง semantic เพื่อลด false-positive ใน UX ระหว่างที่ SuperDAG เข้าสู่ Phase 20
- ยังไม่แตะโครงสร้างใหญ่ของ Validation Engine หรือ Condition Engine
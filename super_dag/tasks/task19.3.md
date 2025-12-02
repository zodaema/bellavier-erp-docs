# Task 19.3 – SuperDAG QC & Routing Regression Map (Safety Test Pack)

**Objective:**  
สร้าง **Regression Map** และ **Test Pack** สำหรับ QC + Conditional Routing ทั้งหมดที่มาจาก Task 19.0, 19.1 และ 19.2 เพื่อป้องกันไม่ให้ใครมาแก้โค้ดในอนาคตแล้ว routing พังแบบเงียบ ๆ

Task นี้จะเน้นแค่:
- เอกสาร
- Test cases
- (ถ้าสะดวก) CLI test เล็ก ๆ

**ห้ามแก้ Logic** ของ Engine ใด ๆ ทั้งสิ้น

---

## 1. Scope

ครอบคลุม:

- QC routing (pass, fail_minor, fail_major)
- Conditional edges (เดี่ยว, multi-condition, multi-group)
- Default route (Else) แบบ explicit (expression: true)
- QC coverage rules
- Error behavior (unroutable, ambiguous)
- Legacy graph compatibility

ไม่ครอบคลุม / ห้ามแตะ:

- `DAGRoutingService` logic
- `ConditionEvaluator`
- Machine / Parallel / Merge semantics
- DB schema หรือ seed data

---

## 2. Deliverables

1. **Regression Map Document**  
   - ไฟล์: `docs/super_dag/tests/qc_routing_regression_map.md`
   - ต้องอธิบายแต่ละ scenario ว่า:
     - Graph หน้าตาเป็นอย่างไร (วาดด้วย text/ASCII ก็พอ)
     - Token อยู่ Node ใด, qc_result เป็นอะไร
     - Edge/Condition เป็นแบบไหน
     - ผลลัพธ์ที่ “ถูกต้อง” คืออะไร
     - มี event สำคัญอะไรบ้างใน token_event

2. **Test Case Catalog**  
   - ไฟล์: `docs/super_dag/tests/qc_routing_test_cases.md`
   - มีอย่างน้อย **20 test cases** แบ่งประเภทชัดเจน เช่น:
     - Simple QC pass/fail
     - Multi-group OR, AND ใน group
     - Default-only edge
     - No match → error_unroutable
     - Overlap → error_ambiguous
     - Legacy → New engine
     - Parallel + QC (minimal case)

3. **Optional Minimal CLI Test Harness**  
   - ไฟล์: `tests/super_dag/QCRoutingSmokeTest.php` (หรือชื่อใกล้เคียง)
   - CLI command:  
     `php tests/super_dag/QCRoutingSmokeTest.php`
   - ทำหน้าที่:
     - โหลด graph/fixtures ชุดเล็ก ๆ
     - ยิง scenario **คัดมาจากเอกสาร** (smoke set)
     - Print ผลแบบง่าย ๆ:
       - `PASS: [ID] description`
       - `FAIL: [ID] description – reason`
   - *ถ้าไม่ทำ harness* ให้ระบุในผลลัพธ์ว่า “Not Implemented (Document-only)”

4. **ผลสรุป Task**  
   - ไฟล์: `docs/super_dag/tasks/task19_3_results.md`
   - สรุป:
     - Test cases ที่ทำจริง
     - ช่องโหว่ / known gaps
     - ถ้ามี CLI harness → วิธีรัน
     - Guideline สำหรับคนจะมาเพิ่ม test ในอนาคต

---

## 3. Test Dimensions

ทุก test case ควรระบุว่าเกี่ยวกับอะไรบ้าง:

1. **QC Status**
   - pass
   - fail_minor
   - fail_major

2. **Condition Complexity**
   - Single condition
   - Multi-condition (AND)
   - Multi-group (OR of AND)

3. **Default Logic**
   - มี explicit default edge
   - ไม่มี default edge (full coverage)

4. **Graph Topology**
   - Linear
   - มี parallel (เคสเล็ก ๆ พอ)

5. **Origin Node**
   - From QC node
   - From non-QC operation node

6. **Data Origin**
   - New graphs (19.x format)
   - Legacy graphs (แปลงแล้ว)

---

## 4. Required Scenarios (ตัวอย่างบังคับ)

อย่างน้อยต้องมีเคสเหล่านี้ (ชื่อ scenario แล้วแต่คุณจะตั้ง):

1. **QC_PASS_SIMPLE**  
   - `qc_result.status = pass`  
   - มี edge เดียวเงื่อนไข pass → Finish

2. **QC_FAIL_MINOR_REWORK**  
   - status in [fail_minor, fail_major] → Rework  
   - `fail_minor` แล้วต้องไป Rework เท่านั้น

3. **QC_FAIL_MAJOR_SCRAP**  
   - `qc_result.status == fail_major` → Scrap / QC_Exception

4. **QC_DEFAULT_ELSE_ROUTE**  
   - มี edge เงื่อนไข pass  
   - มี Default edge (expression: true)  
   - status = ค่าอื่น → ต้องไปตาม default เท่านั้น

5. **NO_MATCH_UNROUTABLE**  
   - ไม่มี default  
   - status ไม่เข้าเงื่อนไขใดเลย → ต้อง error_unroutable

6. **AMBIGUOUS_MATCH_ERROR**  
   - สร้าง condition overlap แล้วใช้ qty test → ต้อง error “ambiguous”

7. **QC_TEMPLATE_A_BASIC_SPLIT**  
   - Template A จาก Task 19.2  
   - pass → Finish, fail_* → Rework

8. **QC_TEMPLATE_B_SEVERITY_QTY**  
   - Template B  
   - ใช้ severity + qty

9. **LEGACY_CONDITION_MIGRATION**  
   - ใช้ graph เก่าที่มี `condition_rule` หรือ decision node  
   - ยืนยันว่า semantics หลังแปลงยังเหมือนเดิม

10. **QC_PARALLEL_BRANCH_SAFE**  
    - QC ตัดสิน route ก่อนเข้า parallel block  
    - ยืนยันว่า parallel behavior ยังถูกต้อง

ส่วนอีก 10 test case คุณออกแบบได้ตามใจ แต่ต้องครอบคลุมมิติอื่น ๆ ด้วย

---

## 5. Regression Map Structure

ไฟล์ `qc_routing_regression_map.md` ควรมีโครงแบบนี้:

1. Introduction  
2. Global Assumptions  
3. Scenario Catalog (ต่อ 1 section ต่อ 1 scenario)
   - ID
   - Graph sketch
   - Preconditions
   - Steps
   - Expected Result
4. Edge Cases & Known Limitations  
5. How to Extend

---

## 6. Implementation Guardrails

- ห้ามแก้ logic ใน:
  - `DAGRoutingService`
  - `ConditionEvaluator`
  - `ParallelMachineCoordinator`
  - `MachineAllocationService`
- ห้ามแก้ schema หรือ seed data
- ห้ามเพิ่ม concept ใหม่ (เช่น weight, cost, priority routing ใหม่)
- ถ้า scenario ไหนไม่แน่ใจ → ให้บันทึกใน `task19_3_results.md` แทนการเดา logic เอง

---

## 7. Acceptance Criteria

- มี regression map อ่านรู้เรื่อง  
- มี test cases ≥ 20 เคส  
- เคสที่เกี่ยวกับ QC status ครบทุกแบบ  
- Legacy format ถูกทดสอบและบันทึกผล  
- ถ้าทำ CLI harness → รันได้จริง  
- ไม่มีการเปลี่ยน logic หรือ DB schema ใน Task นี้

---

# End of Task 19.3 Specification
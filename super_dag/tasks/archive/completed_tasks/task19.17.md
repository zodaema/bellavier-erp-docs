

# Task 19.17 — Semantic Routing Consistency & Intent Conflict Detection

**Status:** Planned  
**Owner:** SuperDAG Core  
**Depends on:** Tasks 19.7–19.16 (Validation, Semantic Engine, Reachability, QC 2-Way Routing)

---

## 1. Objective

หลังจากที่เรา:

- ย้าย validation หลักมาอยู่ใน `GraphValidationEngine`
- ใช้ `SemanticIntentEngine` สำหรับตีความโครงสร้างกราฟ
- ทำ Reachability / Dead-End Detection (Task 19.15)
- ปรับ QC Routing 2-way ให้ไม่โดน block (Task 19.16)

ตอนนี้ระบบสามารถ:

- ตรวจ error/ warning ที่ชัดเจน
- รู้ว่า graph มีทางตัน / node ที่ไปไม่ถึง / loop ที่ไม่ตั้งใจหรือไม่
- แยก default route / QC route / parallel ได้ระดับหนึ่ง

**Task 19.17** มีเป้าหมายเพื่อ “ปิดจบ semantic routing layer” โดย:

1. ตรวจสอบว่า **intent ที่อนุมานได้จากกราฟ** สอดคล้องกับ:
   - โครงสร้าง node/edge จริง
   - behavior / execution_mode / parallel flags
2. ตรวจจับกรณีที่ semantic ขัดแย้งกันเอง (intent conflict)
3. ทำให้ validation ในส่วน semantic routing **consistent** ทุก API action:
   - `graph_validate`
   - `graph_save`
   - `graph_save_draft`
   - `graph_publish`

หลังจบ Task 19.17, เราจะมั่นใจได้ว่า “graph ที่ผ่าน validation แล้ว” มี semantic ชัดเจน และไม่มีการตีความซ้อนทับ/สับสนก่อนเข้าสู่ Phase 20 (ETA / Time Engine).

---

## 2. Scope

### In Scope

- Semantic routing rules ที่เกี่ยวกับ:
  - Multi-exit nodes
  - Parallel split / merge
  - QC routing styles (2-way / 3-way / pass-only)
  - Endpoint intent (END, sink, subflow-end)
- Intent conflict detection:
  - Node-level conflicts
  - Edge-level conflicts
  - Pattern-level conflicts (เช่น ใช้ conditional + parallel ผสมผิดที่)
- Integration กับ:
  - `GraphValidationEngine`
  - `SemanticIntentEngine`
  - Validation UI

### Out of Scope

- การเพิ่ม feature ใหม่ของ SuperDAG (ETA, Simulation)
- การเปลี่ยนแปลง schema DB
- การ refactor แยกไฟล์/โมดูลครั้งใหญ่ (จะไปอยู่ในชุด Lean-Up Tasks แยกถัดไป)

---

## 3. Work Items

### 3.1 Define Semantic Routing Ruleset (Spec)

**File:** `docs/super_dag/semantic_intent_rules.md` (อัปเดต)

1. เพิ่ม section ใหม่: **Routing Style Rules**
   - ระบุรูปแบบ routing ที่อนุญาต เช่น:
     - Linear-only: 1 incoming, 1 outgoing
     - Multi-exit (conditional): 1 incoming, N outgoing (all conditional/default)
     - Parallel split: 1 incoming, N outgoing (parallel group, no condition)
     - Parallel merge: N incoming, 1 outgoing (merge node)
     - QC 2-way: QC node → Pass edge + default/else edge
     - QC 3-way: QC node → Pass, FailMinor, FailMajor
   - ระบุ pattern ที่ “ไม่อนุญาต” เช่น:
     - ผสม parallel split + conditional edge ใน node เดียว (ถ้า design ปัจจุบันไม่รองรับ)
     - END node ที่ยังมี outgoing edge
     - Node เดียวที่ถูกตีความเป็นทั้ง QC และ Operation (ผ่าน behavior/execution_mode)

2. ระบุ intent ที่ใช้สำหรับแต่ละ routing style:
   - `operation.linear_only`
   - `operation.multi_exit`
   - `parallel.true_split`
   - `parallel.merge`
   - `qc.two_way`
   - `qc.three_way`
   - `endpoint.true_end`
   - `sink.expected`
   - `unreachable.unintentional` (จาก Task 19.15)

---

### 3.2 Implement Intent Conflict Detection

**File:** `source/BGERP/Dag/SemanticIntentEngine.php` (หรือไฟล์ที่เกี่ยวข้อง)

1. เพิ่มเมธอด:
   ```php
   public function detectIntentConflicts(array $nodes, array $edges, array $intents): array
   ```
   ทำหน้าที่:
   - ตรวจสอบ intent ที่คำนวณได้แล้วจากโครงสร้าง graph
   - หา pattern ที่ขัดแย้ง เช่น:
     - Node มี intent เป็นทั้ง `parallel.true_split` และ `operation.multi_exit`
     - Node END มี outgoing edge แต่ถูกจัด intent เป็น `endpoint.true_end`
     - QC node มี edge ที่ใช้ non-QC field/condition แบบผิด pattern

2. รูปแบบผลลัพธ์:
   ```php
   [
     'errors' => [...],
     'warnings' => [...],
   ]
   ```

3. กำหนด error code เฉพาะ semantic เช่น:
   - `INTENT_CONFLICT_PARALLEL_CONDITIONAL`
   - `INTENT_CONFLICT_ENDPOINT_WITH_OUTGOING`
   - `INTENT_CONFLICT_QC_NON_QC_CONDITION`

---

### 3.3 Plug Conflicts into GraphValidationEngine

**File:** `source/BGERP/Dag/GraphValidationEngine.php`

1. เพิ่มขั้นตอนใน main `validate()` flow:
   - หลังจาก derive intents แล้ว
   - เรียกใช้ `SemanticIntentEngine::detectIntentConflicts()`
   - รวมผล conflicts เข้าไปใน `$validation['errors']` / `$validation['warnings']`

2. จัดกลุ่มในหมวด:
   - `category: 'semantic'`
   - `rule: 'INTENT_CONFLICT'`

---

### 3.4 UI: Render Semantic Conflicts Clearly

**File:** `assets/javascripts/dag/graph_designer.js`  
(และ/หรือ `assets/javascripts/dag/modules/validation_dialog.js` ถ้ามี)

1. ปรับการ render validation results:
   - ถ้า error/warning มี `category: 'semantic'` และ `rule: 'INTENT_CONFLICT'`
     - แสดง icon/label ต่างจาก error ปกติเล็กน้อย (เช่น prefix: `[Semantic] ...`)
   - แสดง `node_code` หรือ `edge` ที่เกี่ยวข้องเพื่อให้ผู้ใช้รู้ว่าควรแก้ตรงไหน

2. ไม่ต้องเพิ่ม validation ฝั่ง frontend — แค่ present ข้อมูลจาก backend.

---

### 3.5 Regression Cases

**File:** `docs/super_dag/tests/qc_routing_test_cases.md` (หรือสร้างไฟล์ใหม่ `semantic_routing_test_cases.md`)

เพิ่ม test cases อย่างน้อย 8 เคส:

1. Multi-exit conditional (合法):
   - Operation node มี 3 outgoing edges เป็น conditional + default
   - Expect: ไม่มี error semantic

2. Parallel split (合法):
   - Node มี flag parallel + N outgoing edges ปกติ
   - Expect: ไม่มี conflict

3. ผสม parallel + conditional (ผิด design):
   - Node ถูก mark เป็น parallel + มี conditional edge
   - Expect: semantic conflict error

4. END node มี outgoing edge:
   - Expect: error `INTENT_CONFLICT_ENDPOINT_WITH_OUTGOING`

5. QC 2-way + non-QC condition (ผิด pattern):
   - Edge จาก QC ใช้ field non-qc_result
   - Expect: warning หรือ error semantic (ตาม design)

6. Subflow sink (合法):
   - Node flagged เป็น sink.expected (เช่น ReworkSink)
   - มี incoming แต่ไม่มี outgoing
   - Expect: ไม่มี conflict

7. Endpoint multi-end (intentional vs unintentional):
   - 2 END nodes ที่ถูก mark ด้วย intent ต่างกัน (main end vs scrap end)
   - ต้องแยก intentional / unintentional ตาม config

8. Graph เล็ก ๆ ไม่มี semantic conflicts:
   - เพื่อ sanity check ว่า engine ไม่ฟ้องเกินจำเป็น.

---

## 4. Acceptance Criteria

- [ ] มี ruleset semantic routing ชัดเจนในเอกสาร `semantic_intent_rules.md`
- [ ] `SemanticIntentEngine` สามารถ detect intent conflicts ได้ในระดับ node/edge/pattern
- [ ] `GraphValidationEngine` เรียกใช้ conflict detection และรวมผลใน validation output
- [ ] UI แสดง semantic conflicts แยกจาก error ทั่วไปอย่างชัดเจน
- [ ] Test cases อย่างน้อย 8 เคสครอบคลุมกรณีสำคัญ และรันผ่าน (ไม่มี regression)
- [ ] ไม่มี false-positive สำคัญที่ขัดกับการใช้งานจริงของ Bellavier (เช่น QC 2-way ถูกฟ้องผิด)

---

## 5. Notes

- Task 19.17 เป็นขั้นตอน “ปิดกล่อง” semantic routing layer: หลังจากนี้ graph ที่ผ่าน validation จะไม่เพียงแค่ “ไม่พังด้านโครงสร้าง” แต่ยัง “ไม่ขัดแย้งเชิงความหมาย” ด้วย
- เมื่อ Task 19.17 เสร็จ จะพร้อมเข้าสู่ Phase 20 (ETA / Time Engine) โดยไม่ต้องกลัวว่า semantic ของ routing จะตีลังกาเวลาคำนวณเวลา / simulation.
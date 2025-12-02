

# GRAPH DESIGNER — FINAL REFACTOR PLAN (BELLAVIER STANDARD)

**Version:** 2025-11  
**Author:** Bellavier AI Architecture  
**Scope:** รวมปัญหา / จุดที่ต้องปรับปรุง / สิ่งที่ต้อง Refactor ให้ครบ 100% สำหรับ 5 ไฟล์หลักที่เกี่ยวข้องกับ Graph Designer และ Routing API

---

# 0. เป้าหมายของแผนนี้

1. รวม **ทุกข้อบกพร่องที่พบ** จากทั้ง 5 ไฟล์
2. รวม **ข้อเสนอแนะด้านสถาปัตยกรรม** ที่ต้องปรับให้ได้ระดับ Bellavier Standard
3. รวม **Test Cases**, **Pseudo-code**, **Checklist** เพื่อให้ AI Agent สามารถแก้ได้ครบถ้วน 100%
4. ป้องกันปัญหาเดิมกลับมาอีก
5. ทำให้ Graph Designer + Routing API พร้อมสำหรับ Phase DAG FULL MODE

---

# 1. ไฟล์ที่อยู่ในแผน (5 ไฟล์)

1. `dag_routing_api.php`
2. `routing_graph_designer.php`
3. `graph_save.js` / `GraphSaver.js`
4. `GraphAPI.js`
5. `DAGValidationService.php`

---

# 2. ปัญหาสำคัญร่วมกัน (Critical Issues Across All Files)

## CI-01 — JSON Normalization ไม่เป็นมาตรฐาน
หลายไฟล์ decode จาก DB แบบ manual เช่น:
```php
json_decode($row['form_schema_json'], true);
```
แต่ไม่ได้ใช้ helper กลาง `normalizeJsonField()`  
→ ทำให้ค่ากลับมาไม่สม่ำเสมอ, edge-case JSON invalid

**ต้องแก้:**  
ใช้ function กลางทุกที่:  
`normalizeJsonField($row, 'field')`.

---

## CI-02 — ID Handling ไม่สม่ำเสมอระหว่าง Temp ID และ Permanent ID
ปัญหาเกิดตอน autosave หรือ manual save:

- บางไฟล์ใช้ `_temp_id`
- บางไฟล์ใช้ `local_id`
- บางไฟล์ไม่มีการ mapping ก่อน validate

**ต้องแก้:**  
ให้ใช้มาตรฐานเดียว:  
`temp_id` = สตริง prefix `"temp-" . uuid()`

---

## CI-03 — ETag และ Row Version ไม่สอดคล้องกันในบางไฟล์
ปัญหาที่เกิดขึ้นใน autosave:

- ETag จาก API เป็นแบบ MD5
- แต่ front-end เก็บอีกแบบ
- หรือไม่มี strip quote

**ต้องแก้:**  
ใช้ module ใหม่ `ETagUtils.js` ทุกไฟล์

---

## CI-04 — Graph Validation กระจัดกระจายหลายตำแหน่ง
ตอนนี้ validation กระจายอยู่ใน:

- API
- Service
- Front-end

→ เสี่ยง logic ซ้ำซ้อน, error ไม่ตรงกัน

**ต้องแก้:**  
ย้ายกฎทั้งหมด → `DAGValidationService::validateGraphRuleSet()`

---

## CI-05 — Node Rule ไม่สอดคล้องกัน
ปัญหา:

- Operation ต้องมี `work_center` หรือ `team_category`
- QC node ต้องมี `qc_policy`
- Join/Split rule ไม่ตรงกันในบางไฟล์
- Node type ใหม่ (SUBGRAPH) ยังไม่รองรับทุกไฟล์

**ต้องแก้:**  
ใช้ RuleSet เดียวจาก `DAGValidationService`.

---

## CI-06 — Autosave Logic ไม่รองรับ Movement Changes เต็มที่
GraphSaver.js ทำงานถูกต้อง แต่:

- autosavePositions() ไม่ตรวจ dirty state
- บางครั้งเกิด race condition กับ manual save
- บางไฟล์ยังใช้ jQuery AJAX

**ต้องแก้:**  
ให้ autosave ทั้งหมดผ่าน `GraphAPI.autosavePositions()` เท่านั้น

---

## CI-07 — ไม่มี Graph Publish Checklist
ก่อน Publish ต้องตรวจสอบว่า:

1. ไม่มี cycles
2. มี START 1 จุด
3. มี END ≥ 1 จุด
4. ทุก node reachable
5. Operation มี team/work center
6. QC node config ถูกต้อง
7. ไม่มี temp-id หลงเหลือ

→ ตอนนี้ไม่มีระบบนี้

---

# 3. รายไฟล์ — ปัญหาและสิ่งที่ต้องแก้แบบละเอียด

---

# FILE 1: dag_routing_api.php

## Problem List
- [ ] JSON normalization ไม่ครบทุก field
- [ ] validateNodeCodes ไม่ใช้ระบบ translate
- [ ] db_fetch_one ยังอยู่ในไฟล์ (ควรย้ายไป DatabaseHelper)
- [ ] Missing final header in `finally`
- [ ] validation บางส่วน duplicate กับ DAGValidationService
- [ ] ไม่มี publish checklist

## Required Fixes
- [ ] เปลี่ยนทุก decode → normalizeJsonField()
- [ ] เปลี่ยน error message → translate keys
- [ ] ย้ายการ query meta graph → service layer
- [ ] รวม validation ทั้งหมด → DAGValidationService
- [ ] เพิ่ม publish checklist

---

# FILE 2: routing_graph_designer.php

## Problems
- [ ] ใช้ inline JS เยอะ → ไม่ maintainable
- [ ] บาง logic ซ้ำกับ GraphSaver
- [ ] dirty-state ไม่ถูกต้องหากเปิด modal หลายครั้ง
- [ ] modal reset ทำงานไม่สม่ำเสมอ
- [ ] sidebar และ node inspector แยก responsibilities ไม่ดี

## Required Fixes
- [ ] ย้าย UI logic → `GraphUI.js`
- [ ] ย้าย event handlers → `GraphEvents.js`
- [ ] modal reset state ทุกครั้งที่ open
- [ ] modal warn version reset ทุกครั้ง

---

# FILE 3: GraphSaver.js

## Problems
- [ ] canSave() ไม่ครอบคลุมกรณี autosave + manual race
- [ ] ไม่มี debounce สำหรับ autosave movement
- [ ] merge node/edge ไม่รองรับ subgraph
- [ ] edge guard validation อยู่ผิดชั้น (ควรอยู่ใน service)

## Fixes
- [ ] เพิ่ม debounce 150–250ms
- [ ] แยก manual save vs autosave เป็น state machine
- [ ] ย้าย guard validation → backend

---

# FILE 4: GraphAPI.js

## Problems
- [ ] ไม่มี api.getNodeProperties(), api.getAssignmentRules()
- [ ] error handling ไม่ครบทุก switch case
- [ ] ยังมี path hard-code บางตำแหน่ง
- [ ] ไม่มี retry logic

## Fixes
- [ ] เพิ่ม abstraction: GraphAPI.getNode(), GraphAPI.updateNode()
- [ ] เพิ่ม API: getAssignmentPreview(graphId)
- [ ] เพิ่ม retry 1 ครั้งหาก network drop

---

# FILE 5: DAGValidationService.php

## Problems
- [ ] join/split rules ยังไม่สมบูรณ์
- [ ] QC node rework logic ยังไม่ครอบคลุม
- [ ] ตรวจ reachable ยังไม่เช็ค isolated component
- [ ] ไม่มี summary (error type code + message key)

## Fixes
- [ ] เพิ่ม Rule: join-type exact count / split-type exact count
- [ ] เพิ่ม validation QC rework path
- [ ] เพิ่ม validation isolated node
- [ ] error type → structured code เช่น DAG.E001, DAG.W003

---

# 4. TEST CASES (สำคัญที่สุด)

## ✔ Required Test Suites

### A. Graph Structure
- [ ] START missing → error
- [ ] END missing → error
- [ ] Multiple START → error
- [ ] Cycle detection (normal)
- [ ] Cycle detection (rework ignored)
- [ ] Node unreachable → warning

### B. Node Rules
- [ ] Operation missing team/work_center → error
- [ ] QC missing qc_policy → error
- [ ] SUBGRAPH has valid inner structure

### C. Autosave
- [ ] Move node → autosave runs
- [ ] Move 20 nodes → debounce works
- [ ] Manual save interrupt autosave safely

### D. ETag
- [ ] Save with old ETag → 409
- [ ] Save fresh → success

---

# 5. PSEUDOCODE (BACKEND VALIDATION)

```
function validateGraph(graph):
    nodes = graph.nodes
    edges = graph.edges

    normalize(nodes)
    normalize(edges)

    check start-end rules
    check cycles (except rework/event)
    check join/split rules
    check reachable graph
    check node-specific rules
    check no temp-id
    check assignment rules

    return { errors: [...], warnings: [...] }
```

---

# 6. PSEUDOCODE (AUTOSAVE)

```
let dirty = false
let timer = null

function onGraphMove():
    dirty = true
    debounce(savePositions, 200)

function savePositions():
    if (!dirty) return
    dirty = false
    api.autosavePositions(graph)
```

---

# 7. CHECKLIST สำหรับ AI Agent

### สำหรับทุกไฟล์:
- [ ] JSON normalization → normalizeJsonField()
- [ ] ใช้มาตรฐาน temp-id เดียวกัน
- [ ] ทุก validation → ไปอยู่ใน DAGValidationService
- [ ] Error → structured code + translate key
- [ ] ETag ใช้มาตรฐานเดียวกัน
- [ ] autosave ใช้ GraphAPI อย่างเดียว
- [ ] publish checklist ครบทุกข้อ
- [ ] ทุกรหัส logic เขียนลง test cases

---

# 8. SUCCESS CRITERIA

- ระบบสามารถ save, autosave, publish ได้โดย **ไม่มี conflict**
- ไม่มี duplicate logic ระหว่าง API/Service/UI
- Validation เป็น single-source-of-truth
- รองรับ DAG FULL MODE (parallel lanes/subgraph/branching)
- ไม่มี node น่าสงสัย (missing team/workcenter)
- UI สะอาด / modal reset สมบูรณ์

---

# END OF DOCUMENT
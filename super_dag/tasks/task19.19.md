

# Task 19.19 — Validation Engine Lean‑Up Precheck Report

> **Status:** PLANNING / ANALYSIS ONLY  
> **Goal:** ทำเอกสาร “ภาพรวม Validation Engine ทั้งระบบ” ให้ชัดเจน ก่อนเริ่ม Lean‑Up / Refactor ใดๆ  
> **Important:** ห้ามแก้ PHP / JS logic ใน Task นี้ ให้ทำ **อ่าน / วิเคราะห์ / ทำแผน** เท่านั้น

---

## 1. Objective

ก่อนจะเข้าสู่ Lean‑Up Phase (refactor / cleanup / รวม logic) เราต้องมีภาพรวมชัดเจนของ:

1. Validation Engine ทั้งชุด (structural + semantic + QC + reachability + intent + autofix + applyfix)
2. จุดที่ยังซ้ำซ้อน / legacy / เสี่ยง regression
3. Dependency ระหว่างไฟล์หลัก (PHP / JS / Docs)
4. ความครอบคลุมของ Test Suite 19.18 ว่าปิดรูรั่วครบแค่ไหน

**Output ของ Task 19.19 คือเอกสาร “Precheck Report”** ที่ใช้เป็น input ให้ Task 19.20+ (Lean‑Up จริงจัง) โดยไม่แตะต้อง behavior ปัจจุบันแม้แต่นิดเดียว

---

## 2. Scope

### 2.1 รวมอยู่ในขอบเขต

ให้ AI Agent วิเคราะห์ / map / จัดหมวดหมู่เฉพาะส่วนที่เกี่ยวข้องกับ SuperDAG Validation Layer:

- PHP Backend
  - `source/BGERP/Dag/GraphValidationEngine.php`
  - `source/BGERP/Dag/SemanticIntentEngine.php`
  - `source/BGERP/Dag/ConditionEvaluator.php`
  - `source/BGERP/Dag/QCMetadataNormalizer.php`
  - `source/BGERP/Dag/ReachabilityAnalyzer.php`
  - `source/BGERP/Dag/GraphAutoFixEngine.php`
  - `source/BGERP/Dag/ApplyFixEngine.php`
  - `source/dag_routing_api.php` (เฉพาะส่วนที่เรียก validation / autofix / applyfix)

- Frontend JS
  - `assets/javascripts/dag/modules/graph_designer.js`
  - `assets/javascripts/dag/modules/conditional_edge_editor.js`
  - `assets/javascripts/dag/modules/GraphSaver.js`
  - อื่นๆ ที่เรียกใช้ validation / autofix / applyfix (ถ้ามี)

- Documentation / Tests
  - `docs/super_dag/tasks/task19_*.md`
  - `docs/super_dag/tests/*.md`
  - `docs/super_dag/condition_field_registry.md`
  - `docs/super_dag/semantic_intent_rules.md`
  - `docs/super_dag/time_model.md`
  - `tests/super_dag/*.php`
  - `tests/super_dag/fixtures/*.json`
  - `tests/super_dag/snapshots/*.json`

### 2.2 นอกขอบเขต (ห้ามแตะ)

- DAG Execution runtime (token movement, work sessions, machine binding)
- UI ส่วนอื่นที่ไม่เกี่ยวกับ Graph Designer
- Database schema (ห้ามเปลี่ยน column / table ใน Task นี้)
- งาน ETA / SLA / Time Engine (Phase 20+)

---

## 3. Deliverables (ไฟล์ที่ต้องสร้าง)

ให้ AI Agent สร้างไฟล์เอกสารใหม่ 4 ไฟล์ (markdown) ในโฟลเดอร์ `docs/super_dag/`:

1. **`validation_engine_map.md`**  
   แผนที่ high‑level ของ Validation Engine และแต่ละ module ทำหน้าที่อะไร

2. **`validation_dependency_graph.md`**  
   Diagram / table แสดง dependency ระหว่าง:
   - GraphValidationEngine
   - SemanticIntentEngine
   - ConditionEvaluator
   - QCMetadataNormalizer
   - ReachabilityAnalyzer
   - GraphAutoFixEngine
   - ApplyFixEngine
   - dag_routing_api actions
   - GraphDesigner / ConditionalEdgeEditor / GraphSaver

3. **`validation_risk_register.md`**  
   ตารางรวม “จุดเสี่ยง” ถ้า refactor:
   - บรรทัดไหน / module ไหน
   - เหตุผลว่าทำไมเสี่ยง (เช่น logic ซ้อน, ใช้ flag เดิม, dependency ซ่อนใน UI)
   - test case / fixture ไหนที่รองรับจุดนี้อยู่แล้ว (โยงไปที่ Task 19.18)

4. **`validation_leanup_plan.md`**  
   Draft แผน Lean‑Up แนะนำ (แต่ยังไม่ลงมือทำ):
   - แบ่งเป็น Phase 1, 2, 3
   - Phase ละ 3–5 bullet ว่าอยาก refactor อะไร
   - ใส่ “Impact Level” และ “Required Regression Coverage” (ต้องเพิ่ม fixture อะไรหรือไม่)

> หมายเหตุ: **Task 19.19 ห้ามแก้ไฟล์ PHP/JS ใดๆ** ให้ “อ่าน + วิเคราะห์ + เขียนเอกสาร” เท่านั้น

---

## 4. Detailed Instructions for AI Agent

### 4.1 ขั้นตอนที่ 1 — Inventory & Categorization

1. อ่านไฟล์ PHP/JS/Docs ตาม Scope
2. ทำ **รายการ function/method สำคัญ** ในแต่ละ module:
   - Input/Output (parameters, return)
   - ใช้ field ใดใน `routing_node`, `flow_token`, `token_event`
   - เรียก service/class ไหนต่อ
3. แบ่ง category ให้ชัดเจน:
   - Structural validation
   - Semantic / intent validation
   - QC‑specific validation
   - Reachability / dead‑end / cycle
   - AutoFix suggestion
   - ApplyFix execution
   - UI validation / wiring

**เขียนลงใน `validation_engine_map.md`**

---

### 4.2 ขั้นตอนที่ 2 — Dependency Graph

1. วาด dependency เป็น **table หรือ bullet graph** เช่น:

   - `dag_routing_api.php:action=graph_validate`  
     → calls `GraphValidationEngine::validate()`  
     → uses `SemanticIntentEngine`, `ReachabilityAnalyzer`, `ConditionEvaluator`, …

   - `graph_designer.js:validateGraphBeforeSave()`  
     → calls API `graph_validate`  
     → renders errors/warnings using …  

2. เน้นส่วนที่มี “วงจรซ้ำซ้อน” เช่น:
   - logic ซ้ำระหว่าง GraphValidationEngine กับ frontend
   - validation เก่าที่ยังเหลือ (legacy)

**เขียนลงใน `validation_dependency_graph.md`**

---

### 4.3 ขั้นตอนที่ 3 — Risk Register

สำหรับแต่ละจุดที่ “คิดจะ Lean‑Up ในอนาคต” ให้ทำตาราง:

- `module` — ชื่อไฟล์หรือ class
- `location` — function / method / comment สำคัญ
- `risk_reason` — ทำไมแตะแล้วเสี่ยง (เช่น behavior ใช้ในหลายจุด, ไม่มี test ครอบ)
- `test_coverage` — fixture ID / test case ID ที่ครอบ logic นี้ (เชื่อมกับ 19.18)
- `priority` — High / Medium / Low

ตัวอย่าง entries:

- GraphValidationEngine::validateQCRoutingSemantic  
- SemanticIntentEngine::analyzeEdges  
- GraphAutoFixEngine::suggestDeadEndFixes  
- ApplyFixEngine::applyNodeOperation

**เขียนลงใน `validation_risk_register.md`**

---

### 4.4 ขั้นตอนที่ 4 — Lean‑Up Plan Draft

1. จาก Risk Register ให้สรุปแผนคร่าวๆ แบ่งเป็น Phase:

   **Phase 1 — Quick Wins (Low risk / High clarity)**  
   - รวม duplicate validation rules ง่ายๆ  
   - ลบ legacy flags ที่ไม่ใช้แล้ว (ถ้าทดสอบผ่าน)  
   - จัดระเบียบ error codes / message mapping

   **Phase 2 — Structural Refactor (Medium risk)**  
   - แยก concern ของ GraphValidationEngine ให้ชัดเจน  
   - รวม logic QC routing ที่กระจายอยู่หลายที่  
   - ทำให้ ConditionEvaluator เป็น single source of truth สมบูรณ์

   **Phase 3 — Deep Clean & Preparation for ETA Engine (High risk)**  
   - Normalize time/SLA validation เข้ากับ time_model  
   - เตรียม interface สำหรับ Phase 20 (ETA / Simulation)

2. ใส่ในแต่ละ Phase:
   - Impact Level (Low/Medium/High)
   - ต้องเพิ่ม test/fixture หรือไม่
   - ต้องรัน regression suite ทั้งชุดหรือ subset ไหน

**เขียนลงใน `validation_leanup_plan.md`**

---

## 5. Constraints & Non‑Goals

- ❌ ห้ามแก้ไข business logic หรือเปลี่ยนพฤติกรรม validation ใดๆ
- ❌ ห้ามเพิ่ม/ลบ column ใน database
- ❌ ห้ามเพิ่ม feature ใหม่ใน Graph Designer (เฉพาะการ map/วิเคราะห์เท่านั้น)
- ✅ สามารถปรับปรุง / เพิ่มเอกสารได้เต็มที่
- ✅ สามารถเสนอไอเดีย Lean‑Up / Refactor ในเชิง design ได้ แต่ห้ามลงมือใน Task นี้

---

## 6. Acceptance Criteria

Task 19.19 ถือว่า **สำเร็จสมบูรณ์** เมื่อ:

1. ไฟล์ต่อไปนี้ถูกสร้างและมีเนื้อหาครบ:
   - `docs/super_dag/validation_engine_map.md`
   - `docs/super_dag/validation_dependency_graph.md`
   - `docs/super_dag/validation_risk_register.md`
   - `docs/super_dag/validation_leanup_plan.md`
2. ไม่มีการเปลี่ยนแปลงใดๆ ใน:
   - `source/BGERP/Dag/*.php`
   - `source/dag_routing_api.php`
   - `assets/javascripts/dag/**/*.js`
3. Regression test suite 19.18 ยังคงรันผ่านตามเดิม (ไม่ต้องเพิ่ม แต่ต้องไม่แตก)
4. เอกสารทั้งหมดอ่านแล้วเข้าใจภาพรวม validation engine ชัดเจนพอสำหรับเริ่ม Lean‑Up Phase (Task 19.20+)

---


# Task 19.13 — SuperDAG Legacy Cleanup & Deprecation Guardrails

**Category:** SuperDAG / Housekeeping / Safety  
**Depends on:**
- Task 17.x (Parallel / Split / Conditional Edge groundwork)
- Task 18.x (Parallel Machine & Merge Semantics)
- Task 19.0–19.12 (QC Safety, Condition Engine, SemanticIntent, Validator v3, AutoFix v3, ApplyFixEngine)

**Goal:**

ล้าง Technical Debt ของ SuperDAG รอบใหญ่ โดย **ปิด/ถอด/กันใช้** ฟีเจอร์ Legacy ที่ไม่สอดคล้องกับ Execution Model ปัจจุบัน และทำให้ codebase สะอาดพอสำหรับขึ้น Phase 20 (Time / ETA Engine) โดย **ไม่ทำให้กราฟเก่าพัง** (backward compatible, read-only tolerance).

> เป้าหมายคือ: ทำให้ SuperDAG มีแค่ 1 ชุดความจริง (single source of truth) สำหรับ:
> - Node Types (start, operation, qc, rework_sink, scrap_sink, end, etc.)
> - Edge Semantics (normal, conditional, rework, else/default)
> - Parallel / Merge Semantics
> - Validation & AutoFix Pipeline

---

## 1. Scope

### In-Scope
- Cleanup / Deprecation ของ **SuperDAG ฝั่ง Routing Designer**:
  - JS: `graph_designer.js` + modules ที่เกี่ยวข้อง
  - PHP API: `dag_routing_api.php`
  - PHP Core: SuperDAG-related services/helpers ที่ยังมี legacy branches
- UI Guardrails: ปิดปุ่ม / เมนู / keyboard shortcuts ที่ชี้ไป feature legacy
- Comment-level Deprecation: ใส่ `@deprecated` + คอมเมนต์ชัดเจนในโค้ดส่วนที่ยังต้องอยู่เพื่อ backward compatibility แต่ไม่ให้เรียกใช้จาก UI แล้ว

### Out-of-Scope
- ไม่ลบตาราง/คอลัมน์ใน DB (เช่น legacy split/join/wait fields) ใน task นี้
- ไม่ restructure ใหญ่ของ `dag_routing_api.php` (แค่ปิดทางเข้า legacy branches และใส่คอมเมนต์ให้ชัด)
- ไม่แตะ Time / ETA Engine (เป็น Phase 20)

---

## 2. Legacy Features ที่ต้องจัดการ

ใน Task นี้ให้มอง Legacy Feature เป็น 3 ระดับ:

1. **Blocked in UI** — ผู้ใช้ไม่สามารถสร้าง/แก้ feature นี้จาก Graph Designer ได้อีกต่อไป (soft delete)
2. **Soft-Deprecated in API** — API ยังอ่าน/โหลดได้ แต่ไม่อนุญาตเขียน/แก้/สร้างใหม่
3. **Runtime Tolerant** — Execution Engine / Loader ยังต้องรับได้ ถ้าใน DB มีข้อมูลเก่าอยู่

### 2.1 Node Types (Legacy)

Legacy node types / modes ที่ต้อง block จาก UI + API:
- `split`
- `join`
- `wait`
- Decision node type (ถ้าแยกเป็น node_type ต่างหาก)

การจัดการ:
- UI: ปิดปุ่มสร้าง / ซ่อน icon / disable keyboard shortcut
- API: reject `node_type` เหล่านี้ใน `node_create`, `node_update`
- Execution: ถ้ากราฟเก่าโหลดมาแล้วเจอ ให้ treat เป็น node ธรรมดา หรือ ignore flags (ตาม behavior เดิมที่ใช้ใน 17.2/19.x)

### 2.2 Parallel / Join Legacy Flags

- Legacy flags เช่น `is_split_node`, `is_join_node`, `join_type` แบบเก่า (ถ้าเคยใช้กับ node split/join)
- Logic เดิมที่เคย require มี split node ก่อน parallel

การจัดการ:
- UI: ยึด logic ตาม Task 17.2 / 18.x / 19.x ที่ใช้ **จำนวน outgoing edges** + `is_parallel_split` + merge node เป็นหลัก
- Backend: ถ้าเจอ legacy flag ใน DB:
  - อย่าพัง
  - แค่ ignore หรือ map ไป semantics ใหม่แบบ read-only

### 2.3 QC Legacy Logic

- Boolean QC pass/fail แบบเก่า (ก่อนใช้ `qc_result.status`)
- Decision node สำหรับ QC (เลิกใช้แล้ว → ใช้ Conditional Edge + ConditionEngine)

การจัดการ:
- UI: ไม่มีปุ่ม Decision node สำหรับ QC แล้ว
- API: ไม่ให้สร้าง decision node ใหม่, ไม่ให้บันทึก condition แบบเก่า (free-text แบบ raw JSON string โดยไม่มี field registry)
- Execution: ถ้ากราฟเก่ามี boolean qcPass → ให้ QCMetadataNormalizer + ConditionEvaluator รองรับอยู่แล้ว (เพียงอย่าลบ logic นั้นใน task นี้)

---

## 3. Graph Designer (JS) Cleanup

ไฟล์หลัก:
- `assets/javascripts/dag/graph_designer.js`
- `assets/javascripts/dag/modules/GraphSaver.js`
- `assets/javascripts/dag/modules/conditional_edge_editor.js`
- อื่น ๆ ที่ถูกอ้างจาก toolbar / keyboard shortcuts

### 3.1 Toolbar & Keyboard Shortcuts

**เป้าหมาย:** Toolbar และ Shortcuts ต้องสะท้อนเฉพาะ node/edge semantics ที่ยังใช้จริง:

1. ปิด/ซ่อนปุ่ม:
   - Create Split Node
   - Create Join Node
   - Create Wait Node
   - Create Decision Node (ถ้ามี)

2. Keyboard Shortcuts:
   - ถ้ามี hotkey สำหรับ split/join/wait/decision ให้ unbind หรือ map ไป behavior ใหม่ (ถ้าต้องการจริง ๆ) แต่ใน Task 19.13 แนะนำให้ **unbind และ comment ว่า deprecated**

### 3.2 Node Creation Logic

ในฟังก์ชันที่ใช้สร้าง node (เช่น `addNode`, `createNodeFromToolbar`, ฯลฯ):
- เพิ่ม guard ไม่ให้สร้าง node_type = `split`, `join`, `wait`, `decision`
- ถ้ารับ type เป็น string จาก UI ให้ whitelist เฉพาะ:
  - `start`, `operation`, `qc`, `rework_sink`, `scrap_sink`, `end` (และอื่น ๆ ที่จำเป็นจริง)

### 3.3 Conditional Edge Editor

ตรวจสอบว่า:
- ไม่มี UI path ที่เปิดให้กรอก free-text JSON อีกแล้ว
- ใช้ field registry + dropdown-only อย่างเดียว (ตาม Task 19.1–19.6)
- ถ้าพบโค้ดที่เขียนเผื่อ legacy format ให้:
  - คง converter/loader ไว้ (เพื่ออ่านกราฟเก่า)
  - แต่ปิด UI route ที่สามารถสร้าง condition แบบ legacy ได้

### 3.4 Advanced / Debug Controls

- ถ้ามี panel debug ที่ยังเรียกใช้ legacy diagnostic (เช่น split/join counters หรือ nodeType=decision) ให้:
  - คอมเมนต์ทิ้ง หรือ
  - ปรับให้อ้างอิง semantics ใหม่ (parallel/merge, conditional edges)

---

## 4. API Cleanup (dag_routing_api.php)

ไฟล์: `source/dag_routing_api.php`

### 4.1 Node API

ใน action ที่เกี่ยวกับ node เช่น:
- `node_create`
- `node_update`

ให้ทำ:
- Reject node_type legacy:

```php
if (in_array($nodeType, ['split', 'join', 'wait', 'decision'], true)) {
    return $this->errorResponse('LEGACY_NODE_TYPE_NOT_ALLOWED', 'Legacy node types (split/join/wait/decision) are deprecated and cannot be created/updated.');
}
```

- Comment อธิบายว่า legacy types ยังอ่านจาก DB ได้ แต่ห้ามสร้าง/แก้ผ่าน API

### 4.2 Edge / Routing API

- ตรวจสอบ logic ที่บังคับให้ต้องมี split node ก่อนสร้าง parallel branch
  - ย้าย logic ไปเช็คตาม semantics ใหม่ (จำนวน outgoing edges + is_parallel_split / merge node)
- ตรวจสอบ QC routing legacy validation ที่เคยอยู่ใน API:
  - ถ้าซ้ำกับ GraphValidationEngine v3 ให้ลบ/คอมเมนต์ และชี้ไปใช้ ValidationEngine แทน

### 4.3 Deprecated Branches

ไล่หา:
- `if ($legacyMode) {...}`
- `// TODO: remove after DAG v2`
- บล็อกที่ใช้ `routing.php` legacy adapter

ให้ทำอย่างใดอย่างหนึ่ง:
1. ถ้ายังจำเป็นสำหรับ read-only legacy → ใส่คอมเมนต์ `@deprecated` ชัดเจน และอย่าเรียกจาก path ใหม่ (super_dag)
2. ถ้าไม่ถูกเรียกใช้อีกแล้ว → คอมเมนต์ทิ้งทั้ง block หรือเตรียมลบ (ขึ้นกับการค้นอ้างอิง)

---

## 5. Service / Helper Cleanup

ตรวจสอบไฟล์เหล่านี้ (ชื่ออาจต่างเล็กน้อย ให้ค้นด้วยคำว่า `DAG`, `Routing`, `GraphDesigner`):
- `source/BGERP/Service/DAGRoutingService.php`
- `source/BGERP/Service/TokenLifecycleService.php`
- `source/BGERP/Dag/ConditionEvaluator.php`
- `source/BGERP/Dag/SemanticIntentEngine.php`
- `source/BGERP/SuperDAG/ParallelMachineCoordinator.php`

เป้าหมาย:
- ลบ references ที่ยังพูดถึง split/join/wait node โดยตรง (ใน comment หรือ logic) แล้วไม่ใช้จริงแล้ว
- ถ้าพบ logic branch ที่ handle legacy type โดยเฉพาะ:
  - ถ้ายังจำเป็น (กราฟเก่าใน DB) → คงไว้ แต่ใส่คอมเมนต์ `// LEGACY SUPPORT (read-only)` ชัดเจน
  - ถ้าไม่เคยถูกเรียกใช้แล้ว → เตรียมลบ (หรือคอมเมนต์ทั้ง block)

---

## 6. Backward Compatibility & Safety

สำคัญมาก — Task 19.13 ต้อง **ไม่ทำให้กราฟเก่าที่เคยสร้างใช้งานอยู่แล้วพัง**.

Constraints:
- Loader / Execution ต้องยังอ่านกราฟที่มี node_type = split/join/wait ได้โดยไม่ error (แต่ไม่ต้อง interpret พิเศษ)
- Conditional ที่เป็น legacy JSON format ต้องยัง evaluate ได้ผ่าน ConditionEvaluator (อย่าลบ converter)
- QC boolean legacy format (`qcPass` แบบเดิม) ต้องยัง normalize ได้โดย QCMetadataNormalizer

---

## 7. Tests & Validation

### 7.1 Manual Smoke Tests

เตรียม test cases:
1. กราฟใหม่ (ไม่มี legacy types) → สร้าง/แก้/validate/save ได้ปกติ
2. กราฟเก่า (มี split/join/wait/decision) → โหลดได้, แสดงได้, validate ได้ (อาจมี warning) แต่ไม่ให้เพิ่ม/แก้ legacy node เพิ่ม
3. Conditional Edge เดิม (free-text/legacy) → ถูกโหลดและแสดงใน UI editor ใหม่ได้โดยไม่พัง

### 7.2 CLI / Unit Tests (ถ้ามี)

- เพิ่ม test สำหรับ GraphValidationEngine v3 ที่วิ่งกับกราฟที่มี legacy node_type แล้วไม่ throw fatal
- เพิ่ม test สำหรับ dag_routing_api graph_validate / graph_autofix / graph_apply_fixes ว่าทำงานได้แม้มี legacy flags ใน node/edge

---

## 8. Documentation

สร้าง/อัปเดตไฟล์:
- `docs/super_dag/tasks/task19_13_results.md` — สรุปสิ่งที่ทำจริง, legacy features ที่ถูกปิด, known limitations
- (ถ้าจำเป็น) อัปเดต `docs/super_dag/task_index.md` เพื่อ mark Task 19.13 = DONE

---

## 9. Acceptance Criteria

- [ ] Toolbar และ keyboard shortcuts ไม่มีปุ่ม/ทางลัดสำหรับ split/join/wait/decision node อีกต่อไป
- [ ] GraphDesigner JS ไม่สามารถสร้าง node_type legacy ได้ผ่านทุก UI path
- [ ] dag_routing_api ปฏิเสธการสร้าง/แก้ไข node_type legacy ด้วย error code ที่ชัดเจน
- [ ] GraphValidationEngine v3 ทำงานได้ทั้งกับกราฟใหม่และกราฟเก่า (legacy-friendly)
- [ ] No new code พึ่งพา legacy flags/types อีกต่อไป (split/join/wait/decision)
- [ ] AutoFix + ApplyFixEngine ทำงานได้ปกติหลัง cleanup
- [ ] เอกสาร task19_13_results.md สรุปรายการ legacy ที่ถูกปิดอย่างครบถ้วน

---

## 10. Notes

- อย่าลบ logic legacy ที่ใช้ใน Runtime/Execution ถ้ายังไม่มั่นใจว่าไม่มีกราฟไหนใช้อยู่ — ให้ mark ด้วยคอมเมนต์ชัดเจนแทน
- Task 19.13 คือสะพานไปสู่ Phase 20: Time / ETA / Simulation. ยิ่ง codebase สะอาดเท่าไร งาน Phase 20 จะยิ่งแม่นและปลอดภัยเท่านั้น.

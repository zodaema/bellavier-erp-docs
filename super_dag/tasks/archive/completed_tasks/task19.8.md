

# Task 19.8 — Graph AutoFix Engine (Safe Quick-Fix for DAG & QC)

> Version: v1.0  
> Depends on: Task 19.5 (time model foundation), Task 19.6 (UX refactor), Task 19.7 (GraphValidationEngine)

## 1. Objective

Provide a **safe, deterministic AutoFix layer** that can repair the most common, low‑risk graph problems automatically (or semi‑automatically via UI confirmation), **without changing business semantics** and **without touching runtime tokens**.

The AutoFix Engine sits **on top of** `GraphValidationEngine`:
- `GraphValidationEngine` = tells us *what is wrong* (errors/warnings + context)  
- `GraphAutoFixEngine` = proposes *how to fix it safely* (patches)  

The goal is to:
- Reduce friction for graph designers (one click to fix common issues)
- Remove noisy warnings (especially QC routing coverage) by codifying patterns we actually use
- Keep all logic changes auditable and reversible

---

## 2. Scope (v1)

### 2.1 In‑scope AutoFix patterns (SAFE only)

v1 focuses on **simple, clearly safe** cases:

1. **QC Pass → Next, Else → Rework pattern**  
   - Pattern:
     - Source node type = `qc`
     - Exactly 1 conditional edge from QC with `qc_result.status == pass`
     - At least 1 non‑conditional edge from QC to a node labelled / behavior `REWORK_SINK` or `rework` behavior
     - `GraphValidationEngine` reports missing QC statuses (fail_minor, fail_major) for this QC node
   - AutoFix behaviour:
     - Treat the non‑conditional REWORK edge as the ELSE route
     - Generate either:
       - explicit conditions: `qc_result.status in {fail_minor, fail_major}` on that edge, **or**
       - set an `is_default_route = 1` flag (depending on existing schema)
     - Re‑run validation in memory to ensure errors disappear

2. **Mark explicit SINK nodes**  
   - Pattern:
     - Node has 0 outgoing edges
     - Node behavior/category in {`REWORK_SINK`, `SCRAP_SINK`, `TERMINAL`}
     - GraphValidationEngine currently warns about "dead‑end" node
   - AutoFix behaviour:
     - Set node flag `is_sink = 1` (or `node_category = sink` depending on schema)
     - Downgrade dead‑end warning for that node in future runs

3. **Default ELSE route clarification (non‑QC)**  
   - Pattern:
     - Node has ≥1 conditional edges
     - Exactly 1 non‑conditional edge
     - GraphValidationEngine warns about incomplete coverage
   - AutoFix behaviour:
     - Mark the non‑conditional edge as `is_default_route = 1`
     - Do **not** attempt to synthesize conditions; rely on ELSE semantics only

4. **START/END node metadata normalization (no structural changes)**  
   - Pattern:
     - Graph has exactly 1 visual START/END node but metadata flags missing/inconsistent
   - AutoFix behaviour:
     - Synchronize metadata fields (e.g. `is_start`, `is_end`) and labels with the visual nodes
     - **Important:** v1 does *not* auto‑create/remove START/END nodes; only normalizes flags for existing ones.

### 2.2 Out‑of‑scope (for v1)

The following are **explicitly out of scope** for 19.8 and must **not** be implemented by AI Agent in this task:

- Creating or deleting nodes
- Creating or deleting edges (except when a future task explicitly allows)
- Auto‑connecting isolated nodes
- Auto‑splitting or merging parallel branches
- Auto‑changing `work_center_code`, `behavior_code`, or `execution_mode`
- Any change that can alter business semantics without clear, deterministic rules

These can be considered for later tasks (e.g. 19.9+).

---

## 3. Architecture

### 3.1 New class: `GraphAutoFixEngine`

**Location:** `source/BGERP/Dag/GraphAutoFixEngine.php`

**Constructor:**
```php
class GraphAutoFixEngine
{
    private $db;

    public function __construct($db)
    {
        $this->db = $db;
    }

    /**
     * @param array $nodes  Normalized nodes array from loadGraphWithVersion()
     * @param array $edges  Normalized edges array from loadGraphWithVersion()
     * @param array $validationResult  Result from GraphValidationEngine->validate()
     * @param array $options  ['graphId' => int|null, 'mode' => 'draft'|'publish']
     * @return array [
     *   'fixes' => FixDefinition[],
     *   'patched_nodes' => array, // optional preview
     *   'patched_edges' => array, // optional preview
     * ]
     */
    public function suggestFixes(array $nodes, array $edges, array $validationResult, array $options = []): array
    {
        // Implemented in this task (v1 patterns only)
    }
}
```

### 3.2 FixDefinition structure

```php
[
  'id'          => 'FIX-QC-DEFAULT-REWORK-1',
  'type'        => 'QC_DEFAULT_REWORK',
  'severity'    => 'safe',          // 'safe' | 'risky' | 'manual-only'
  'target'      => [
      'node_id' => 123,
      'edge_id' => 456,
  ],
  'title'       => 'Treat rework edge as default QC fail route',
  'description' => 'QC node QC1 has a pass edge to Finish and a rework edge without conditions. This fix marks the rework edge as ELSE route for all failed QC statuses.',
  'operations'  => [
      // High-level operation list for UI or backend patcher
      [
          'op'        => 'set_edge_default_route',
          'edge_id'   => 456,
          'value'     => true,
      ],
      [
          'op'        => 'set_edge_condition_statuses',
          'edge_id'   => 456,
          'statuses'  => ['fail_minor', 'fail_major'],
      ],
  ],
]
```

> Note: v1 can choose either the `is_default_route` approach or the explicit `status in [...]` approach. The spec must be clear and consistent across backend + frontend.

---

## 4. Backend Changes

### 4.1 `dag_routing_api.php`

Add a new action `graph_autofix`:

- **Input:**
  - `id_graph` (required)
  - `mode` = `draft` or `publish`
- **Steps:**
  1. Load graph (nodes + edges) via existing loader
  2. Run `GraphValidationEngine->validate()`
  3. Run `GraphAutoFixEngine->suggestFixes()` with validation result
  4. Return JSON:

```jsonc
{
  "ok": true,
  "fix_count": 2,
  "fixes": [ FixDefinition, ... ],
  "patched_nodes": [...],   // optional preview for UI
  "patched_edges": [...]
}
```

> v1: **Do not apply fixes to DB in this API.** This endpoint only suggests fixes. Application of fixes is done explicitly via separate saveGraph call from UI.

### 4.2 Integration with `GraphValidationEngine`

- No changes to validation logic in this task, except when needed to:
  - Recognize the post‑fix state as valid
  - Downgrade warnings once a FixDefinition would resolve them

Example: if QC node fits the Pass→Next + Else→Rework pattern, and AutoFixEngine proposes `QC_DEFAULT_REWORK`, `GraphValidationEngine` should *not* still produce “QC statuses not covered” as an **error**. At most it should be a **warning with autofix hint**.

---

## 5. Frontend Changes (graph_designer.js)

### 5.1 New AutoFix flow

1. เมื่อผู้ใช้กด "Save graph":
   - เรียก `graph_validate` (ใช้ GraphValidationEngine ตาม Task 19.7)
   - ถ้ามี **fatal errors** → แสดง dialog เหมือนเดิม (บอก error ราย node)
   - ถ้ามี **errors/warnings ที่เข้าข่าย AutoFix** → แสดงปุ่ม `Auto-fix` ใน dialog

2. เมื่อผู้ใช้กดปุ่ม `Auto-fix`:
   - เรียก `graph_autofix` → รับรายการ `fixes` และ (ถ้ามี) `patched_nodes`/`patched_edges`
   - แสดง list ของ fix ทั้งหมดใน side panel:
     - title
     - description
     - affected node/edge (highlight ในกราฟ)
   - ให้ผู้ใช้เลือก:
     - `Apply all safe fixes`
     - หรือ tick เลือกบางข้อ แล้วกด `Apply selected`

3. เมื่อผู้ใช้กด Apply:
   - ใช้ `operations` จากแต่ละ FixDefinition ไป patch state ใน `GraphStateManager`/`GraphSaver`
   - รี‑render graph
   - เรียก `graph_validate` อีกครั้งแบบอัตโนมัติ

### 5.2 UX Principles

- **ไม่ auto‑fix เงียบ ๆ**: ต้องมีการยืนยันจากผู้ใช้ทุกครั้ง
- **แยกสี fix ตาม severity** (v1 มีแต่ `safe` ก็ใช้สีเดียวได้ก่อน)
- **แสดง node/edge ที่ได้รับผลกระทบ** โดย highlight ใน canvas

---

## 6. Safety & Constraints

1. AutoFixEngine v1 ต้องไม่เขียนลง DB โดยตรง  
   - การบันทึกเปลี่ยนแปลงกระทำผ่าน flow ปกติของ `saveGraph` เท่านั้น

2. ห้ามเปลี่ยนแปลง:
   - `work_center_code`, `behavior_code`, `execution_mode` ของ node
   - parallel flags (`is_parallel_split`, `is_merge_node`) และ merge policy

3. ห้ามสร้างหรือลบ nodes/edges ใน v1

4. AutoFixEngine ต้องเป็น **pure function** กับ inputs:
   - ไม่มี side effects นอกจากค่าที่ return กลับ

5. ทุก FixDefinition ต้องเป็น **idempotent**: เรียกซ้ำหลายครั้ง ผลลัพธ์ต้องเหมือนเดิม ไม่ทับค่าเก่าผิด ๆ

---

## 7. Test Cases

เพิ่มไฟล์: `docs/super_dag/tests/autofix_test_cases.md`

อย่างน้อย 10 test cases:

1. QC Pass→Finish + Else Rework → เพิ่ม default/conditions ให้อัตโนมัติ
2. QC มี 3 สถานะครบอยู่แล้ว → AutoFix ไม่เสนอ fix
3. QC มี pass อย่างเดียว ไม่มี rework → AutoFix ไม่เสนอ fix (ปล่อยให้เป็น error ปกติ)
4. REWORK_SINK ไม่มี outgoing edges → Mark as sink, warning หายไป
5. Node ปกติไม่มี outgoing edges → AutoFix ไม่ mark เป็น sink
6. Non‑QC node: 1 conditional + 1 normal edge → เสนอ set default route
7. Non‑QC node: 2 conditional edges + 0 normal edge → ไม่เสนอ default route fix
8. START/END flags ไม่ตรงกับ visual node → AutoFix เสนอ normalize
9. กราฟเดิม (legacy) ที่ผ่าน validation อยู่แล้ว → ไม่มี fix เสนอ
10. AutoFix ถูก apply แล้วรัน validate อีกครั้ง → ไม่มี error เดิมกลับมา

---

## 8. Acceptance Criteria

- [ ] มีไฟล์ `GraphAutoFixEngine.php` พร้อม method `suggestFixes()`
- [ ] `dag_routing_api.php` มี action `graph_autofix` (read‑only, no DB writes)
- [ ] `graph_designer.js` เรียก AutoFix flow ตามเงื่อนไข
- [ ] QC Pass→Next + Else→Rework pattern ไม่ทำให้เกิด error เรื่อง missing QC statuses อีก
- [ ] Dead‑end SINK nodes ไม่ถูกเตือนซ้ำหลัง mark
- [ ] ไม่มีการสร้าง/ลบ node หรือ edge ใน v1
- [ ] Routing semantics ไม่เปลี่ยนจากเดิม (ยกเว้นกรณีเติม condition ที่ตรงกับความตั้งใจเดิมอยู่แล้ว)
- [ ] เอกสาร `autofix_test_cases.md` เขียนครบอย่างน้อย 10 เคส
- [ ] `task19_8_results.md` สรุปสิ่งที่ implement จริง และข้อจำกัด (ถ้ามี)
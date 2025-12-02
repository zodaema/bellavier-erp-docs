
# Task 19.18 — Validation Regression Suite & Hardening Pass

**Status:** Planned  
**Owner:** SuperDAG Core  
**Depends on:** Tasks 19.7–19.17 (Full Validation Layer, Semantic Intent Engine, Reachability Analyzer, Default Route Normalization)

---

## 1. Objective

Task 19.18 มีเป้าหมายเพื่อสร้าง **“Regression Safety Net”** สำหรับ SuperDAG Validation Layer ก่อนจะเข้าสู่ Lean-Up Phase และ Phase 20 (ETA/Time Engine)

หลังจากโค้ด Validation / Semantic / Reachability / QC Routing ถูกพัฒนาอย่างรวดเร็วตลอด 19.x ทำให้จำเป็นอย่างยิ่งที่จะต้องเพิ่ม:

- **ตัวทดสอบอัตโนมัติ (Regression Tests)**
- **Graph Fixtures (Sample graphs 20–30 แบบ)**
- **Semantic Snapshot Tests**
- **Autofix → ApplyFix → Validate Pipeline Tests**

เพื่อป้องกัน regression และมั่นใจว่า Lean-Up รอบใหญ่จะไม่ทำให้ logic พัง

---

## 2. Scope

### In Scope
- CLI-based regression test harness  
- 20–30 test cases ครอบคลุมโครงสร้างหลักของ SuperDAG  
- Semantic Intent snapshot testing  
- QC routing test pack  
- Parallel / Multi-exit / Merge test pack  
- Reachability & Dead-end test pack  
- Autofix → ApplyFix → Validate pipeline tests  
- เอกสาร test suite เต็มรูปแบบ  

### Out of Scope
- UI tests  
- Database integration test (mock เท่านั้น)  
- Multi-tenant and multi-graph versioning (Task 19.19)  

---

## 3. Deliverables

### 3.1 New Test Harness

**File:** `tests/super_dag/ValidateGraphTest.php`

Features:

- CLI runnable:
  ```bash
  php tests/super_dag/ValidateGraphTest.php
  php tests/super_dag/ValidateGraphTest.php --test TC-101
  php tests/super_dag/ValidateGraphTest.php --category QC
  ```
- Automatic loading of fixtures from:
  ```
  tests/super_dag/fixtures/*.json
  ```
- Pretty-printed results (errors_detail, warnings_detail)
- Exit code: `0 = success`, `1 = failure`

---

### 3.2 Graph Fixtures (20–30 Cases)

**Directory:** `tests/super_dag/fixtures/`

Each file:  
```
graph_XXX_description.json
```

Cases include:

#### **QC Routing**
- TC-QC-01: Pass + Default (valid)
- TC-QC-02: 3‑way QC (valid)
- TC-QC-03: QC + non-QC condition (warning)
- TC-QC-04: QC with no outgoing edges (error)

#### **Parallel / Multi-exit**
- TC-PL-01: Parallel true split
- TC-PL-02: Parallel merge (valid)
- TC-PL-03: Conditional + parallel conflict (semantic error)
- TC-PL-04: Multi-exit conditional (valid)

#### **Reachability**
- TC-RC-01: Unreachable node (error)
- TC-RC-02: Dead-end non-sink (error)
- TC-RC-03: Dead-end sink.expected (valid)
- TC-RC-04: Cycle detection (warning)

#### **Endpoint**
- TC-END-01: END with outgoing edge (error)
- TC-END-02: Multi-end intentional (valid)
- TC-END-03: Multi-end unintentional (warning)

#### **Semantic**
- TC-SM-01: Conflicting intents (error)
- TC-SM-02: Simple linear flow (valid)
- TC-SM-03: Subflow entry/exit placeholder (pending 19.19)

---

### 3.3 Semantic Snapshot Testing

**File:**  
`tests/super_dag/SemanticSnapshotTest.php`

Function:

- รัน graph ผ่าน SemanticIntentEngine
- เก็บ snapshot ไว้ใน:
  ```
  tests/super_dag/snapshots/<graph>.snapshot.json
  ```
- เปรียบเทียบ semantic intent ทุกครั้งที่รัน
- Alert เมื่อ semantic “เปลี่ยนเองโดยไม่ตั้งใจ”  

---

### 3.4 Autofix Pipeline Tests

**File:**  
`tests/super_dag/AutoFixPipelineTest.php`

Flow:

```
Load → Validate → AutoFix → ApplyFix → Validate(after)
```

Expectations:

- error ลดลง
- ห้ามมี error ใหม่
- Semantic ไม่เพี้ยนหลัง autofix

---

### 3.5 Documentation

**File:**  
`docs/super_dag/tests/validation_regression_suite.md`

เนื้อหา:

- ตาราง test cases ทั้งหมด  
- วิธีรัน test suite  
- วิธีเพิ่ม test ใหม่  
- โครงสร้าง fixture JSON  
- ตัวอย่าง expected output  

### 3.6 Fixture JSON Format (Example)

Toลดความสับสนระหว่าง AI Agent หลายตัว ให้กำหนดรูปแบบ fixture ให้ชัดเจนตั้งแต่ต้น:

**Directory:**  
`tests/super_dag/fixtures/graph_TC_XXX_*.json`

**Structure (example):**
```json
{
  "id": "TC-QC-01",
  "label": "QC Pass + Default Rework",
  "meta": {
    "category": "QC",
    "description": "QC two-way routing: pass -> NEXT, else -> REWORK_SINK",
    "source": "semantic_routing_test_cases.md#TC-11"
  },
  "nodes": [
    {
      "id_node": 1,
      "node_code": "START",
      "node_type": "start",
      "behavior_code": null
    },
    {
      "id_node": 2,
      "node_code": "OP1",
      "node_type": "operation",
      "behavior_code": "CUT"
    },
    {
      "id_node": 3,
      "node_code": "QC1",
      "node_type": "operation",
      "behavior_code": "QC"
    },
    {
      "id_node": 4,
      "node_code": "FINISH",
      "node_type": "end",
      "behavior_code": null
    },
    {
      "id_node": 5,
      "node_code": "REWORK_SINK",
      "node_type": "sink",
      "behavior_code": null
    }
  ],
  "edges": [
    {
      "from": 1,
      "to": 2
    },
    {
      "from": 2,
      "to": 3
    },
    {
      "from": 3,
      "to": 4,
      "condition": {
        "groups": [
          {
            "operator": "AND",
            "conditions": [
              {
                "field": "qc_result.status",
                "op": "==",
                "value": "pass"
              }
            ]
          }
        ]
      }
    },
    {
      "from": 3,
      "to": 5,
      "condition": {
        "type": "default"
      }
    }
  ],
  "expected": {
    "error_count": 0,
    "min_warning_count": 0,
    "must_not_have_error_codes": [
      "QC_MISSING_ROUTES"
    ],
    "semantic_intents": [
      "qc.two_way"
    ]
  }
}
```

**Notes:**
- `id_node` values ใน fixture ไม่จำเป็นต้องตรงกับของจริงใน DB (ใช้แบบ in-memory ได้)
- ใช้ `meta.source` ผูกกับเอกสารเชิงอธิบาย เช่น `semantic_routing_test_cases.md`, `qc_routing_test_cases.md`
- `expected.semantic_intents` ใช้เทียบกับผลจาก `SemanticIntentEngine` / `GraphValidationEngine` เพื่อกัน regression
- ถ้าบาง test ไม่สนใจ intent ให้เว้น field `semantic_intents` ได้

---

## 4. Work Items

### 4.1 Build Test Harness  
- Create CLI runner  
- Add graphs loading  
- Add structured reporting  

### 4.2 Create 20–30 Fixture Graphs  
- QC cases  
- Parallel cases  
- Endpoint cases  
- Semantic conflict cases  
- Map fixtures to existing docs (e.g. semantic_routing_test_cases.md, qc_routing_test_cases.md) via meta.source

### 4.3 Snapshot Semantic Testing  
- Implement snapshot writer  
- Implement comparison logic  

### 4.4 Autofix Pipeline Testing  
- Integrate GraphAutoFixEngine + ApplyFixEngine  
- Compare before/after graph states  

### 4.5 Documentation  
- Explain test structure  
- Add contribution notes  

---

## 5. Acceptance Criteria

- [ ] Test harness runs from CLI with filtering by test ID or category  
- [ ] At least 20 fixtures exist and run successfully  
- [ ] Semantic intent snapshot tests created and passing  
- [ ] Autofix pipeline tests run successfully  
- [ ] No regressions introduced into existing tasks  
- [ ] Documentation added to `/docs/super_dag/tests/`  
- [ ] Test suite must be stable enough to support Lean-Up Phase  

---

## 6. Notes

Task 19.18 เป็น “เกราะเหล็ก” ก่อนเริ่ม Lean-Up Phase:

- ช่วยให้ refactor code ปลอดภัยขึ้น  
- ป้องกันไม่ให้ AI Agent ทำลาย logic เดิมโดยไม่ตั้งใจ  
- ทำให้ Phase 20 (ETA Engine) มีพื้นฐานที่แน่น  
- ลดเวลา debug ในอนาคตอย่างมาก  

หลังจบ 19.18 เราสามารถเข้าสู่ Lean-Up Phase ได้อย่างมั่นใจเต็ม 100%
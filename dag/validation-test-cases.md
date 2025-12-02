# DAG Routing Validation — Test Cases (Bellavier Standard)

_Last updated: {{DATE}}_

This document defines the **official test cases** for the Routing Graph Designer and Validation pipeline.

It is the single source of truth for how the system must behave in all key scenarios.

---

## 1. Conventions

Each test case follows this format:

```text
ID: TC-<AREA>-<NNN>
Title: <short description>

Graph Meta:
  created_at: <ISO or relative, e.g. NEW / OLD>
  version: <number if relevant>

Input:
  Nodes: [...]
  Edges: [...]
  (Only list fields relevant to the case.)

Expected:
  - errors: [codes/messages]
  - warnings: [codes/messages]
  - allow_save: true | false
```

Terminology:
- **NEW graph** = created_at ≥ `team_system_release_date` (see DAGValidationService config)
- **OLD graph** = created_at < that date
- Workforce rule code = `W_OP_MISSING_TEAM`
- Message standard:
  > `Operation node "<node_code>" must have team_category or work_center assigned.`

---

## 2. Operation Node – Workforce Requirements

### TC-OP-001 — Missing team/work_center (NEW graph → ERROR)

**Graph Meta:**
- created_at: NEW

**Input:**
- Node: `OP1` (type = `operation`)
  - team_category: `null`
  - id_work_center: `null`

**Expected:**
- errors:
  - code: `W_OP_MISSING_TEAM`
  - message: `Operation node "OP1" must have team_category or work_center assigned.`
- warnings: []
- allow_save: **false**

---

### TC-OP-002 — Missing team/work_center (OLD graph → WARNING)

**Graph Meta:**
- created_at: OLD

**Input:**
- Node: `OP1` (type = `operation`)
  - team_category: `null`
  - id_work_center: `null`

**Expected:**
- errors: []
- warnings:
  - code: `W_OP_MISSING_TEAM`
  - message: `Operation node "OP1" must have team_category or work_center assigned. (old graph: recommended to update)`
- allow_save: **true**

---

### TC-OP-003 — team_category only (NEW graph → OK)

**Input:**
- Node: `OP1` (type = `operation`)
  - team_category: `cutting`
  - id_work_center: `null`

**Expected:**
- errors: []
- warnings: []
- allow_save: **true**

---

### TC-OP-004 — work_center only (legacy → OK)

**Input:**
- Node: `OP1` (type = `operation`)
  - team_category: `null`
  - id_work_center: `10`

**Expected:**
- errors: []
- warnings: []
- allow_save: **true**

---

### TC-OP-005 — Both team_category + work_center (prefer team_category)

**Input:**
- Node: `OP1` (type = `operation`)
  - team_category: `sewing`
  - id_work_center: `10`

**Expected:**
- errors: []
- warnings: []
- allow_save: **true**
- Note: runtime should use `team_category` as primary routing hint.

---

### TC-OP-006 — Non-operation node should ignore workforce rule

**Input:**
- Node: `QC1` (type = `qc`) with no team_category, no work_center

**Expected:**
- errors: []
- warnings: [] (no `W_OP_MISSING_TEAM`)
- allow_save: **true**

---

## 3. Structural Rules (API Layer — validateGraphStructure)

These cases verify that **API-level structure validation** behaves correctly. Business rules (team/work_center, assignment, etc.) should NOT be handled here.

### TC-ST-001 — Simple linear graph (valid)

**Input:**
- Nodes: `START`, `OP1`, `END`
- Edges:
  - `START → OP1`
  - `OP1 → END`

**Expected:**
- errors: []
- warnings: []
- allow_save: **true**

---

### TC-ST-002 — Missing START node

**Input:**
- Nodes: `OP1`, `END`
- Edges: `OP1 → END`

**Expected:**
- errors: [missing_start]
- warnings: []
- allow_save: **false**

---

### TC-ST-003 — Missing END node

**Input:**
- Nodes: `START`, `OP1`
- Edges: `START → OP1`

**Expected:**
- errors: [missing_end]
- warnings: []
- allow_save: **false**

---

### TC-ST-004 — Cycle detected

**Input:**
- Nodes: `OP1`, `OP2`
- Edges: `OP1 → OP2`, `OP2 → OP1`

**Expected:**
- errors: [cycle_detected]
- warnings: []
- allow_save: **false**

---

### TC-ST-005 — Self-loop

**Input:**
- Node: `OP1`
- Edge: `OP1 → OP1`

**Expected:**
- errors: [self_loop]
- warnings: []
- allow_save: **false**

---

## 4. Split / Join Rules

### TC-SJ-001 — Split node with 2+ outgoing edges (valid)

**Input:**
- Node: `SPL1` (type = `split`)
- Edges: `SPL1 → OP1`, `SPL1 → OP2`

**Expected:**
- errors: []
- warnings: []

---

### TC-SJ-002 — Split node with only 1 outgoing edge (invalid)

**Expected:**
- errors: [invalid_split_degree]
- allow_save: **false**

---

### TC-SJ-003 — Join node with 2+ incoming edges (valid)

**Expected:**
- errors: []
- warnings: []

---

### TC-SJ-004 — Join node with 1 incoming edge (invalid)

**Expected:**
- errors: [invalid_join_degree]
- allow_save: **false**

---

## 5. Legacy Graph Compatibility

### TC-LG-001 — Old graph with missing team (warning)

Same as TC-OP-002.

---

### TC-LG-002 — Old graph with strange node ordering but structurally valid

**Expected:**
- errors: []
- warnings: []
- allow_save: **true**

---

## 6. API–Service Integration Cases

These test that **API and DAGValidationService work together correctly**.

### TC-INT-001 — API returns structure error, service still not called

**Scenario:**
- Graph has a cycle.

**Expected:**
- API returns `errors: [cycle_detected]` and **does not** inject `W_OP_MISSING_TEAM` from service.

---

### TC-INT-002 — Structure OK, business warning present

**Scenario:**
- Graph is structurally valid.
- Operation node missing team/work_center, OLD graph.

**Expected:**
- API returns `warnings: [W_OP_MISSING_TEAM]`, `errors: []`.
- allow_save: **true**.

---

### TC-INT-003 — Structure OK, business error present

**Scenario:**
- Graph structurally valid.
- NEW graph, operation node missing team/work_center.

**Expected:**
- errors: [`W_OP_MISSING_TEAM` as error]
- warnings: []
- allow_save: **false**

---

## 7. Notes for Implementation & QA

- These test cases must be implemented as:
  - Unit tests for DAGValidationService
  - Integration tests for dag_routing_api.php
- Any new rule must add:
  - At least one NEW test case in this file.
- AI Agent: **ห้ามลบ Test Case เก่า** ให้เพิ่มใหม่ด้านล่างเสมอ

---

End of file.

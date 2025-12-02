# DAG Validation Responsibility Matrix

_Last updated: {{DATE}}_

This document clearly defines **which layer is responsible for which validation rule** in the DAG Routing system.

Goal:
- Prevent duplicated logic
- Prevent inconsistent behavior
- Guide future refactors and AI Agents

---

## 1. Layers

- **API Layer** — `dag_routing_api.php`
  - Focus: Graph structure, basic integrity, HTTP contract
- **Validation Service** — `DAGValidationService.php`
  - Focus: Business rules, workforce requirements, assignment policy
- **Routing Service** — `DAGRoutingService.php`
  - Focus: Runtime behavior, token movement, concurrency, WIP

---

## 2. Matrix Table

### 2.1 Summary Table

| Validation Type                               | API Layer (dag_routing_api.php) | Validation Service (DAGValidationService) | Routing Service (DAGRoutingService) | Blocking? | Notes |
|----------------------------------------------|----------------------------------|-------------------------------------------|--------------------------------------|----------|-------|
| Node existence (id, type)                    | ✔                                |                                          |                                      | Yes      | Structure only |
| Start node existence                         | ✔                                |                                          |                                      | Yes      | Exactly one START |
| End node existence                           | ✔                                |                                          |                                      | Yes      | ≥ 1 END |
| Edge references valid                        | ✔                                |                                          |                                      | Yes      | from/to must exist |
| Cycle detection                              | ✔                                |                                          |                                      | Yes      | DAG only |
| Self-loop detection                          | ✔                                |                                          |                                      | Yes      | OP → OP not allowed |
| Split degree rules                           | ✔                                |                                          |                                      | Yes      | split must have ≥2 outgoing |
| Join degree rules                            | ✔                                |                                          |                                      | Yes      | join must have ≥2 incoming |
| Operation workforce (team/work_center)       | ✖                                | ✔                                         |                                      | Yes      | Code: `W_OP_MISSING_TEAM` |
| Assignment policy validity                   | ✖                                | ✔                                         |                                      | Yes      | team_lock, auto, etc. |
| Legacy compatibility (old vs new graph)      | ✖                                | ✔                                         |                                      | Mixed    | Warnings vs errors |
| Concurrency configuration validity           | ✖                                | ✔                                         | ✔                                    | Yes      | limit ≥ 0, etc. |
| WIP limit configuration validity             | ✖                                | ✔                                         | ✔                                    | Yes      | wip_limit ≥ 0 |
| Runtime concurrency enforcement              | ✖                                | ✖                                         | ✔                                    | Yes      | blocking at runtime |
| Runtime WIP enforcement                      | ✖                                | ✖                                         | ✔                                    | Yes      | queue or reject |
| Token assignment creation                    | ✖                                | ✖                                         | ✔                                    | No       | runtime only |
| Assignment logging                           | ✖                                | ✖                                         | ✔                                    | No       | debug/trace |

Legend:
- ✔ = responsible
- ✖ = must NOT handle this rule

---

## 3. Detailed Responsibilities

### 3.1 API Layer — `dag_routing_api.php`

**Must handle:**
- Node/edge presence and ids
- Node types basic validation
- Start/end existence
- Cycles
- Self-loops
- Split/Join minimum degrees

**Must NOT handle:**
- Any rule about team_category
- Any rule about id_work_center
- Any rule about assignment_policy
- Any legacy cutoff logic (old/new graph)

---

### 3.2 Validation Service — `DAGValidationService`

**Must handle:**
- Operation node workforce rule:
  - team_category or id_work_center required
  - `W_OP_MISSING_TEAM` as warning (old graph) or error (new graph)
- Assignment policy validation:
  - e.g., `assignment_policy = 'team_lock'` requires preferred_team_id
- Concurrency configuration validation:
  - node.concurrency_limit must be ≥ 0
- WIP configuration validation:
  - node.wip_limit must be ≥ 0
- Legacy compatibility rules

**Must NOT handle:**
- Basic structural graph issues (those belong to API)
- Runtime routing (moving tokens)

---

### 3.3 Routing Service — `DAGRoutingService`

**Must handle:**
- Moving tokens along edges
- Applying concurrency limits at runtime
- Applying WIP limits at runtime
- Creating assignments
- Logging assignments

**Must NOT handle:**
- Deciding whether an operation node is valid (team/work_center)
- Deciding if a graph is old/new
- Structural validation of graph

---

## 4. When Adding New Rules

Whenever a new validation rule is introduced:

1. Decide if it is **structure**, **business**, or **runtime**:
   - Structure → API
   - Business → DAGValidationService
   - Runtime → DAGRoutingService
2. Update this matrix.
3. Add test cases in `validation-test-cases.md`.
4. Add/update pseudocode in `validation-pseudocode.md` if needed.

---

## 5. Notes for AI Agent

- Do not duplicate rules between layers.
- When in doubt, prefer putting **business** rules in `DAGValidationService`.
- If you change responsibilities, you MUST update this matrix.

---

End of file.
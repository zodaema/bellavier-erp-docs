# QC System Spec

**Bellavier Group ERP – DAG System**

This spec defines how Quality Control (QC) nodes work, defect code tracking, multi-level QC flows, and how QC decisions affect token state.

---

## Purpose & Scope

- Defines QC nodes vs normal production nodes
- Specifies QC_SINGLE vs QC_REPAIR vs QC_FINAL flows
- Describes defect code storage and linkage to tokens/components
- Defines how QC affects token state (PASS / FAIL / REWORK / DISCARD)
- Handles multi-level QC scenarios (QC 1 → QC 2 → QC Final)
- **Out of scope:** UI design details (only behavior contracts)

---

## Key Concepts & Definitions

- **QC Node:** Special node type (`node_type='qc'`) that performs quality inspection
- **Defect Code:** Standardized code for QC failures (e.g., EP01, SEW05, CUT02)
- **QC_SINGLE:** Single-piece QC inspection (Hatthasilpa flow)
- **QC_REPAIR:** QC node dedicated to rework inspection
- **QC_FINAL:** Final QC before shipping (includes component completeness check)
- **Multi-Level QC:** Sequential QC nodes (QC 1 → QC 2 → QC Final)
- **Rework Edge:** Edge type that routes failed tokens back to rework node

---

## Data Model

### Table: `defect_catalog` (Proposed)

Stores standardized defect codes.

| Field | Type | Description |
|-------|------|-------------|
| `id_defect` | int PK | Primary key |
| `defect_code` | varchar(20) | Defect code (e.g., 'EP01', 'SEW05', 'CUT02') |
| `defect_name` | varchar(100) | English name |
| `defect_category` | varchar(50) | Category (CUT, EDGE, STITCH, ASSEMBLE, QC, etc.) |
| `severity` | enum | 'minor', 'major', 'critical' |
| `description` | text | Detailed description |
| `is_active` | tinyint(1) | Active flag |
| `created_at` | datetime | Standard timestamp |
| `updated_at` | datetime | Standard timestamp |

**Indexes:**
- PRIMARY KEY (`id_defect`)
- UNIQUE KEY `uq_defect_code` (`defect_code`)
- INDEX `idx_category` (`defect_category`)

### Table: `token_qc_result` (Proposed)

Stores QC inspection results for tokens.

| Field | Type | Description |
|-------|------|-------------|
| `id_qc_result` | int PK | Primary key |
| `id_token` | int FK | References `flow_token.id_token` |
| `id_node` | int FK | References `routing_node.id_node` (QC node) |
| `qc_decision` | enum | 'pass', 'fail', 'conditional_pass' |
| `defect_code` | varchar(20) | References `defect_catalog.defect_code` (if fail) |
| `defect_description` | text | Additional defect notes |
| `inspector_user_id` | int | Inspector user ID |
| `inspector_name` | varchar(255) | Inspector name (denormalized) |
| `component_completeness_checked` | tinyint(1) | Flag: component completeness was checked |
| `component_completeness_status` | enum | 'complete', 'incomplete', 'not_checked' |
| `inspected_at` | datetime | Inspection timestamp |
| `created_at` | datetime | Standard timestamp |
| `updated_at` | datetime | Standard timestamp |

**Indexes:**
- PRIMARY KEY (`id_qc_result`)
- INDEX `idx_token` (`id_token`)
- INDEX `idx_node` (`id_node`)
- INDEX `idx_decision` (`qc_decision`)
- INDEX `idx_defect_code` (`defect_code`)

### Defect Code Examples

| Defect Code | Name | Category | Severity |
|-------------|------|----------|----------|
| CUT02 | Warped edge | CUT | major |
| EP01 | Uneven paint | EDGE | minor |
| SEW05 | Thread break | STITCH | major |
| ASSEMBLE01 | Component mismatch | ASSEMBLE | critical |
| QC01 | Component incomplete | QC | critical |

---

## Event → Screen → Data Flow

### Scenario: Fail at QC 1 → Back to Previous Node

**Step 1: QC 1 Node**
- Token arrives at QC 1 node (after STITCH)
- Inspector reviews work
- Inspector marks FAIL with defect code: SEW05 (thread break)

**Step 2: Rework Routing**
- System:
  - Creates `token_qc_result`:
    - `qc_decision = 'fail'`
    - `defect_code = 'SEW05'`
  - Updates token: `status = 'completed'` (at QC 1 node)
  - Routes token via rework edge to STITCH node

**Step 3: Rework Token Creation**
- System creates rework token at STITCH node:
  - `parent_token_id = <original_token_id>`
  - `current_node_id = <STITCH_node_id>`
  - `status = 'ready'`
  - `rework_count = 1`

**Step 4: Rework Completion**
- Worker completes rework
- Token returns to QC 1
- If PASS → continues to next node
- If FAIL again → `rework_count++`, new rework or scrap if limit exceeded

### Scenario: Fail at QC 2 → Skip QC 1 or Go Back?

**Step 1: Multi-Level QC Flow**
- Token passes QC 1 → moves to QC 2
- Inspector at QC 2 marks FAIL with defect code: ASSEMBLE01 (component mismatch)

**Step 2: Rework Decision**
- System checks defect severity:
  - If `severity = 'critical'` → Route to ASSEMBLE node (skip QC 1)
  - If `severity = 'major'` → Route to previous node (QC 1 or STITCH)
  - If `severity = 'minor'` → Route to QC_REPAIR node

**Step 3: Rework Token Creation**
- System creates rework token at appropriate node
- Token history tracks: "Failed QC 2 → Rework at ASSEMBLE"

### Scenario: Final QC with Component Completeness Check

**Step 1: QC_FINAL Node**
- Token arrives at QC_FINAL node
- Behavior: `allows_component_binding = 1`, `allows_defect_capture = 1`

**Step 2: Component Completeness Check**
- System queries `job_component_serial` for this token's `final_piece_serial`
- Compares with BOM requirements:
  - Required: Hardware (1), Strap (1), Lining (1 set)
  - Bound: Hardware ✓, Strap ✓, Lining ✓
  - Status: Complete

**Step 3: QC Decision**
- Inspector reviews component bindings
- If complete → Inspector can mark PASS
- If incomplete → Must mark FAIL → Triggers rework
- System creates `token_qc_result`:
  - `qc_decision = 'pass'` or `'fail'`
  - `component_completeness_checked = 1`
  - `component_completeness_status = 'complete'` or `'incomplete'`

**Step 4: Token State Update**
- If PASS → Token moves to PACK node
- If FAIL → Token routes to rework node (ASSEMBLE or QC_REPAIR)

---

## Integration & Dependencies

- **Work Center Behavior:** `allows_defect_capture` controls which nodes can capture defect codes
- **Token Engine:** QC decisions trigger token state transitions (PASS → continue, FAIL → rework)
- **Component Binding:** QC_FINAL checks component completeness before shipping
- **Rework System:** QC failures trigger rework token creation
- **DAG Routing:** Rework edges route failed tokens back to appropriate nodes

---

## Implementation Roadmap (Tasks)

1. **Q-01:** Define QC data model and defect catalog
   - Create `defect_catalog` table
   - Seed common defect codes (CUT02, EP01, SEW05, ASSEMBLE01, QC01)
   - Create `token_qc_result` table
   - Migration file: `database/tenant_migrations/YYYY_MM_qc_system.php`

2. **Q-02:** Attach QC behavior to specific nodes
   - Extend `routing_node` table:
     - Add `qc_policy` JSON field (if not exists)
     - Store QC configuration (mode, defect codes, rework rules)
   - Link QC nodes to `work_center_behavior` (QC_FINAL, QC_REPAIR)

3. **Q-03:** Integrate QC with token engine and trace API
   - Extend `dag_token_api.php`:
     - `token_qc_pass` action → Creates QC result, routes token forward
     - `token_qc_fail` action → Creates QC result, routes token to rework
   - Extend `trace_api.php`:
     - Show QC results in token timeline
     - Display defect codes and rework history

4. **Q-04:** Add QC dashboards (data needs only)
   - QC metrics query:
     - Pass rate by node
     - Defect frequency by code
     - Rework rate by node
     - Component completeness failure rate
   - No UI design, only data structure

5. **Q-05:** Implement multi-level QC routing logic
   - Service: `QCRoutingService::determineReworkNode(int $tokenId, string $defectCode, int $currentQcNodeId)`
   - Logic:
     - Check defect severity
     - Determine rework target (skip QC 1 or go back)
     - Create rework token at appropriate node

6. **Q-06:** Add component completeness check at QC_FINAL
   - Service: `QCComponentService::checkCompleteness(int $tokenId)`
   - Queries `job_component_serial` for final_piece_serial
   - Compares with BOM requirements
   - Returns completeness status

**Constraints:**
- Must preserve existing `routing_node` structure (additive only)
- QC nodes must use `node_type='qc'` (existing enum)
- Must integrate with existing `dag_token_api.php` QC actions

---

**Source:** [REALITY_EVENT_IN_HOUSE.md](REALITY_EVENT_IN_HOUSE.md) Section 5, [DAG_Blueprint.md](DAG_Blueprint.md) Section 6  
**Related:** [SPEC_WORK_CENTER_BEHAVIOR.md](SPEC_WORK_CENTER_BEHAVIOR.md), [SPEC_TOKEN_ENGINE.md](SPEC_TOKEN_ENGINE.md), [SPEC_COMPONENT_SERIAL_BINDING.md](SPEC_COMPONENT_SERIAL_BINDING.md)  
**Last Updated:** December 2025


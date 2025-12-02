# Token Engine Spec

**Bellavier Group ERP – DAG System**

This spec defines how tokens represent work units, move through nodes, split from batches, and handle rework.

---

## Purpose & Scope

- Defines what a "token" is in system terms (Hatthasilpa vs Classic)
- Specifies batch token representation and split logic
- Defines token state machine and transitions
- Integrates with Work Center Behavior to determine token type
- Handles rework tokens and their linkage to originals
- **Out of scope:** Token assignment logic (covered in separate spec)

---

## Key Concepts & Definitions

- **Token:** Unit of work flowing through DAG nodes
- **Batch Token:** Represents multiple pieces processed together (from BATCH mode nodes)
- **Single Token:** Represents one piece (from SINGLE mode nodes)
- **Component Token:** Represents sub-assembly part (token_type='component')
- **Token Split:** Process of converting batch token into multiple single tokens
- **Rework Token:** Token created when original fails QC and needs rework
- **Parent Token:** Original token that spawned this token (via split or rework)

---

## Data Model

### Table: `flow_token` (Existing)

Current structure (from schema):

| Field | Type | Description |
|-------|------|-------------|
| `id_token` | int PK | Primary key |
| `id_instance` | int FK | References `job_graph_instance.id_instance` |
| `token_type` | enum | 'batch', 'piece', 'component' |
| `serial_number` | varchar(100) | Serial/lot identifier |
| `parent_token_id` | int FK | Parent token if split from another |
| `child_tokens` | json | Array of child token IDs if split occurred |
| `current_node_id` | int FK | Current node position (NULL if completed/scrapped) |
| `status` | enum | 'ready', 'active', 'waiting', 'paused', 'completed', 'scrapped' |
| `qty` | decimal(10,2) | Quantity (1.00 for piece, N for batch) |
| `metadata` | json | Custom data (material batch, operator notes, etc.) |
| `spawned_at` | datetime | Token creation time |
| `completed_at` | datetime | When token reached end node |
| `cancellation_type` | enum | 'qc_fail', 'redesign', 'permanent' |
| `replacement_token_id` | int FK | FK to replacement token if cancelled |
| `redesign_required` | tinyint(1) | Flag: needs redesign before continuing |
| `redesign_resolved_at` | datetime | When redesign resolved |
| `redesign_resolved_by` | int | Manager who resolved redesign |
| `cancellation_reason` | text | Detailed cancellation reason |

**Extensions Needed (Future):**

| Field | Type | Description |
|-------|------|-------------|
| `batch_session_id` | int FK | References batch session (if batch token) |
| `planned_qty` | decimal(10,2) | Planned quantity (for batch) |
| `actual_qty` | decimal(10,2) | Actual quantity (for batch yield tracking) |
| `scrap_qty` | decimal(10,2) | Scrap quantity (for batch) |
| `rework_count` | int | Number of times this token has been reworked |
| `rework_history` | json | Array of rework events |

---

## Event → Screen → Data Flow

### Scenario: Batch → Single Split (CUT node)

**Step 1: Batch Token Creation**
- Node: CUT (execution_mode: BATCH)
- Worker starts batch: planned_qty = 20 sets
- System creates batch token:
  - `token_type = 'batch'`
  - `qty = 20.00`
  - `planned_qty = 20.00`
  - `current_node_id = CUT node`

**Step 2: Batch Completion**
- Worker completes: actual_qty = 18 sets
- System updates batch token:
  - `actual_qty = 18.00`
  - `scrap_qty = 2.00`
  - `status = 'completed'` (at CUT node)

**Step 3: Token Split**
- System splits batch token into 18 single tokens:
  - Creates 18 new tokens:
    - `token_type = 'piece'`
    - `parent_token_id = <batch_token_id>`
    - `qty = 1.00`
    - `current_node_id = next_node_id` (STITCH)
  - Updates batch token:
    - `child_tokens = [123, 124, 125, ...]` (18 token IDs)
    - `status = 'completed'`

**Step 4: Single Tokens Continue**
- Each single token moves independently through remaining nodes
- Time Engine tracks each token separately
- Component binding occurs at ASSEMBLE node

### Scenario: Rework Token Creation (QC Fail)

**Step 1: QC Failure**
- Token A at QC_FINAL node
- Inspector marks FAIL with defect code (e.g., SEW05)
- System:
  - Updates Token A: `status = 'completed'`, `cancellation_type = 'qc_fail'`
  - Determines rework target node (from DAG rework edge)

**Step 2: Rework Token Creation**
- System creates rework token:
  - `token_type = 'piece'` (same as original)
  - `parent_token_id = <Token A id>`
  - `current_node_id = <rework_node_id>`
  - `status = 'ready'`
  - `rework_count = 1` (inherited from parent + 1)
  - `metadata = {"rework_reason": "SEW05", "original_token_id": <Token A id>}`

**Step 3: Rework Token Flow**
- Rework token moves through rework path
- If passes QC → continues to normal flow
- If fails again → `rework_count++`, new rework token or scrap if limit exceeded

### Scenario: Token State Transitions

**State Machine:**

```
CREATED (spawned_at)
    ↓
READY (at start node, not yet started)
    ↓
ACTIVE (worker started, Time Engine running)
    ↓
PAUSED (worker paused) → RESUMED → ACTIVE
    ↓
COMPLETED (node completed) → Next node → READY/ACTIVE
    ↓
    ├─→ REWORK_PENDING (QC fail) → Rework token created
    └─→ FINISHED (reached END node)
```

**Rules:**
- Only QC nodes can generate rework
- Rework always moves to dedicated rework node
- Token history must be immutable (audit trail)

---

## Integration & Dependencies

- **Work Center Behavior:** `execution_mode` determines token type (BATCH → batch token, SINGLE → single token)
- **Time Engine:** Tracks time per token (PER_PIECE) or per batch (PER_BATCH)
- **Component Binding:** Tokens carry component serial bindings at ASSEMBLE/QC nodes
- **QC System:** QC decisions trigger token state transitions (PASS → continue, FAIL → rework)

---

## Implementation Roadmap (Tasks)

1. **T-01:** Document current DB structure for tokens
   - Review existing `flow_token` schema
   - Document current status enum values
   - Document current token_type enum values

2. **T-02:** Design extensions for batch/single split
   - Add `batch_session_id`, `planned_qty`, `actual_qty`, `scrap_qty` fields
   - Design split logic: batch token → N single tokens
   - Preserve batch metadata in child tokens

3. **T-03:** Add API contracts for token state transitions
   - `token_start` → READY → ACTIVE
   - `token_pause` → ACTIVE → PAUSED
   - `token_resume` → PAUSED → ACTIVE
   - `token_complete` → ACTIVE → COMPLETED → Next node
   - `token_rework` → COMPLETED → REWORK_PENDING → Rework token created

4. **T-04:** Implement batch split logic
   - Service: `TokenSplitService::splitBatchToken(int $batchTokenId, int $actualQty)`
   - Creates N single tokens from batch token
   - Links via `parent_token_id` and `child_tokens` JSON

5. **T-05:** Implement rework token creation
   - Service: `TokenReworkService::createReworkToken(int $failedTokenId, string $defectCode, int $reworkNodeId)`
   - Creates rework token with proper linkage
   - Tracks rework_count and history

6. **T-06:** Integrate with trace API and dashboards
   - Extend `trace_api.php` to show token genealogy (parent/child relationships)
   - Show rework history in token details
   - Display batch → single split in timeline

7. **T-07:** Add token state validation
   - Prevent invalid transitions (e.g., PAUSED → COMPLETED without resume)
   - Validate node sequence (token cannot skip nodes)
   - Enforce rework limits (max 3 reworks per token)

**Constraints:**
- Must preserve existing `flow_token` structure (additive only)
- No breaking changes to current token status values
- Must integrate with existing `dag_token_api.php`

---

**Source:** [REALITY_EVENT_IN_HOUSE.md](REALITY_EVENT_IN_HOUSE.md) Section 1.5, [DAG_Blueprint.md](DAG_Blueprint.md) Section 5  
**Related:** [SPEC_WORK_CENTER_BEHAVIOR.md](SPEC_WORK_CENTER_BEHAVIOR.md), [SPEC_TIME_ENGINE.md](SPEC_TIME_ENGINE.md)  
**Last Updated:** December 2025


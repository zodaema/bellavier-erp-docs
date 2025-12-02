# Component Serial Binding Spec

**Bellavier Group ERP – DAG System**

This spec defines how component serials (hardware, straps, etc.) are bound to final product serials, where binding occurs, and how the system tracks component genealogy.

---

## Purpose & Scope

- Defines what a "component" is in this context (hardware, straps, metal sets, etc.)
- Specifies where component serials are generated (CUT? HARDWARE_ASSEMBLY? PACKING?)
- Defines binding model (job_ticket_serial ↔ component_serial)
- Supports multi-binding points (some components bound at Node A, others at Node B)
- Handles binding correction and component replacement
- **Out of scope:** Full component model with `product_component` table (future phase)

---

## Key Concepts & Definitions

- **Component:** Sub-assembly part that goes into final product (hardware, straps, lining, etc.)
- **Component Serial:** Serial number assigned to a component (e.g., "HW-2025-001")
- **Final Piece Serial:** Serial number of the final product (e.g., "MA01-HAT-DIAG-20251201-00001-A7F3-X")
- **Component Binding:** Linking component serial to final piece serial
- **Late Binding:** Binding occurs at Assembly/QC nodes, not at Cutting (batch mixing prevents early binding)
- **Component Type:** With Serial (hardware, straps) vs Without Serial (lining, internal panels) vs Disposable vs Reusable

---

## Data Model

### Table: `job_component_serial` (Existing - Task 13)

Current structure (from migration `2025_12_component_serial_binding.php`):

| Field | Type | Description |
|-------|------|-------------|
| `id_binding` | int PK | Primary key |
| `id_job_ticket` | int FK | References `job_ticket.id_job_ticket` |
| `id_instance` | int FK | References `job_graph_instance.id_instance` |
| `component_code` | varchar(64) | Component code (e.g., 'BODY', 'FLAP', 'STRAP') |
| `component_serial` | varchar(100) | Component serial number |
| `final_piece_serial` | varchar(100) | Final product serial (root serial) |
| `id_component_token` | int FK | References `flow_token.id_token` (if component token exists) |
| `id_final_token` | int FK | References `flow_token.id_token` (final piece token) |
| `bom_line_id` | int FK | References `bom_line.id_bom_line` (if linked to BOM) |
| `created_at` | datetime | Binding creation time |
| `updated_at` | datetime | Last update |
| `created_by` | int | User who created binding |

**Indexes:**
- PRIMARY KEY (`id_binding`)
- INDEX `idx_job_ticket` (`id_job_ticket`)
- INDEX `idx_component_serial` (`component_serial`)
- INDEX `idx_final_serial` (`final_piece_serial`)
- INDEX `idx_component_token` (`id_component_token`)
- INDEX `idx_final_token` (`id_final_token`)

### Component Stock Movement Model

Component lifecycle tracks stock changes precisely:

1. **component_stock_in** — initial receiving
2. **component_stock_out (picking)** — issued before assembly
3. **component_consumption** — consumed when bound to token
4. **component_scrap** — defect, broken hardware, or mismatched component

**Notes:**
- Binding does NOT equal stock out (picking event is separate)
- Scrap events must decrease stock and log cause
- Enables full traceability & cost accuracy

---

## Event → Screen → Data Flow

### Scenario: Bind at Assembly

**Step 1: Worker at ASSEMBLE Node**
- Screen: Work Queue → ASSEMBLE node
- Token arrives at ASSEMBLE node
- Behavior: `allows_component_binding = 1`

**Step 2: Component Selection**
- Worker selects components from picked stock:
  - Hardware: "HW-2025-001"
  - Strap: "STR-2025-045"
  - Lining: consumed (no serial)
- Worker inputs final_piece_serial: "MA01-HAT-DIAG-20251201-00001-A7F3-X"

**Step 3: Binding Creation**
- API: `hatthasilpa_component_api.php?action=bind_component_serial`
- System creates bindings:
  ```json
  {
    "job_ticket_id": 631,
    "component_code": "HARDWARE",
    "component_serial": "HW-2025-001",
    "final_piece_serial": "MA01-HAT-DIAG-20251201-00001-A7F3-X",
    "id_component_token": 1234,
    "id_final_token": 5678
  }
  ```

**Step 4: Stock Consumption**
- System records `component_consumption`:
  - Hardware "HW-2025-001" → consumed
  - Strap "STR-2025-045" → consumed
  - Stock decreased

### Scenario: Fix Incorrect Binding

**Step 1: QC Detects Mismatch**
- QC_FINAL node detects component serial mismatch
- Inspector marks FAIL with reason: "Component serial mismatch"

**Step 2: Unbind + Rebind**
- System:
  - Marks old binding as invalid (soft delete or flag)
  - Creates new binding with correct component serial
  - Logs replacement event

**Step 3: Component Replacement Tracking**
- Old component: "HW-2025-001" → scrapped (reason: mismatch)
- New component: "HW-2025-003" → bound
- Replacement tracked in `component_replacement` log

### Scenario: QC Checks Completeness Before Shipping

**Step 1: QC_FINAL Node**
- Token arrives at QC_FINAL node
- Behavior: `allows_component_binding = 1`

**Step 2: Component Completeness Check**
- System queries `job_component_serial` for this token's `final_piece_serial`
- Compares with BOM requirements:
  - Required: Hardware (1), Strap (1), Lining (1 set)
  - Bound: Hardware ✓, Strap ✓, Lining ✓
  - Status: Complete

**Step 3: QC Decision**
- If complete → Inspector can mark PASS
- If incomplete → Must mark FAIL → Triggers rework
- System logs component completeness status

### Scenario: Late Binding (Why Not at Cutting)

**Step 1: CUT Node (Batch)**
- CUT node processes batch (50 pieces)
- Components are NOT bound yet (batch mixing prevents binding)

**Step 2: Pieces Move Through Nodes**
- Pieces move through SKIVE, EDGE-PAINT, STITCH
- Still no component binding

**Step 3: ASSEMBLE Node**
- Worker selects components from picked stock
- Components bound to specific token
- Serial matches final assembly sequence

**Why Late Binding:**
- Cutting is batch → items get mixed
- QC happens before assembly
- Serial must match final assembly sequence

---

## Integration & Dependencies

- **Work Center Behavior:** `allows_component_binding` controls which nodes can bind components
- **Token Engine:** Component bindings linked to tokens via `id_component_token` and `id_final_token`
- **QC System:** QC_FINAL checks component completeness before shipping
- **BOM System:** BOM defines required components and quantities
- **Stock System:** Component stock movement (in/out/consumption/scrap) tracked separately

---

## Implementation Roadmap (Tasks)

1. **C-01:** Finalize DB model for component serial links
   - Review existing `job_component_serial` table (Task 13)
   - Add `component_replacement` table for replacement tracking (future)
   - Add `component_stock_movement` table for stock tracking (future)

2. **C-02:** Define APIs for bind/unbind/list
   - `hatthasilpa_component_api.php` (existing - Task 13):
     - `bind_component_serial` - Create binding
     - `get_component_serials` - List bindings
     - `get_component_panel` - UI panel data
   - Future: `unbind_component_serial` - Remove binding
   - Future: `replace_component_serial` - Replace with new component

3. **C-03:** Integrate with QC_FINAL and PACKING nodes
   - QC_FINAL: Check component completeness before PASS
   - PACKING: Validate all components bound before shipping
   - Show component list in QC panel

4. **C-04:** Add reporting for "component swap" incidents
   - Track component replacements
   - Report replacement frequency by component type
   - Identify problematic components (high replacement rate)

5. **C-05:** Extend trace_api for component genealogy
   - `trace_api.php` → `getComponentsForSerial()`:
     - Query `job_component_serial` (in addition to inventory_transaction_item)
     - Merge results from both sources
     - Show component tokens from DAG system

6. **C-06:** Integrate with BOM system
   - Link `bom_line_id` to component bindings
   - Validate binding against BOM requirements
   - Show BOM completeness in QC panel

**Constraints:**
- Stage 1: Capture & Expose only (no enforcement)
- Hatthasilpa line only (Classic line not supported yet)
- Must preserve existing `job_component_serial` structure (additive only)

---

**Source:** [REALITY_EVENT_IN_HOUSE.md](REALITY_EVENT_IN_HOUSE.md) Section 1.5, [DAG_Blueprint.md](DAG_Blueprint.md) Section 2  
**Related:** [SPEC_WORK_CENTER_BEHAVIOR.md](SPEC_WORK_CENTER_BEHAVIOR.md), [SPEC_QC_SYSTEM.md](SPEC_QC_SYSTEM.md)  
**Task Reference:** `docs/dag/tasks/task13.md`, `docs/dag/task13_2_component_read_api.md`  
**Last Updated:** December 2025


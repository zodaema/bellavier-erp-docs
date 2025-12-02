# Work Center Behavior Spec

**Bellavier Group ERP – DAG System**

This spec defines how Work Center Behavior controls node execution, UI rendering, and token/time/component integration.

---

## Purpose & Scope

- Defines structured behavior presets (CUT, EDGE, STITCH, QC_FINAL, etc.) that control how nodes execute
- Separates behavior (what the node does) from actual work_center rows (physical locations)
- Maps factory events → screens → data flow for batch vs single vs mixed execution
- Integrates with Token Engine, Time Engine, Component Binding, and QC systems
- **Out of scope:** Front-end UI design details (only behavior contracts)

---

## Key Concepts & Definitions

- **Work Center:** Physical location in factory (e.g., "CUT Station", "EDGE Bench")
- **Work Center Behavior:** Preset rules defining how a node type executes (CUT, EDGE, STITCH, QC_FINAL, etc.)
- **Execution Mode:** How worker executes the task (BATCH, SINGLE, MIXED)
- **Time Tracking Mode:** How time is recorded (PER_BATCH, PER_PIECE, NO_TIME)
- **UI Template Code:** Which UI template to render (CUT_DIALOG, EDGE_DIALOG, QC_PANEL, etc.)

---

## Data Model

### Table: `work_center_behavior`

Stores behavior presets that define node execution rules.

| Field | Type | Description |
|-------|------|-------------|
| `id_behavior` | int PK | Primary key |
| `code` | varchar(50) | Behavior code (CUT, EDGE, STITCH, QC_FINAL, etc.) |
| `name` | varchar(100) | English name |
| `description` | text | Behavior description |
| `is_hatthasilpa_supported` | tinyint(1) | Can be used in Hatthasilpa line |
| `is_classic_supported` | tinyint(1) | Can be used in Classic/PWA line |
| `execution_mode` | enum | BATCH, SINGLE, MIXED |
| `time_tracking_mode` | enum | PER_BATCH, PER_PIECE, NO_TIME |
| `requires_quantity_input` | tinyint(1) | Must input quantity before start |
| `allows_component_binding` | tinyint(1) | Node can bind component serials |
| `allows_defect_capture` | tinyint(1) | Node can capture defect codes |
| `supports_multiple_passes` | tinyint(1) | Supports multiple passes (e.g., EDGE rounds) |
| `ui_template_code` | varchar(50) | UI template selector (CUT_DIALOG, EDGE_DIALOG, QC_PANEL, etc.) |
| `default_expected_duration` | int (seconds) | Standard expected duration (for performance comparison) |
| `created_at` | datetime | Standard timestamp |
| `updated_at` | datetime | Standard timestamp |

**Indexes:**
- PRIMARY KEY (`id_behavior`)
- UNIQUE KEY `uq_behavior_code` (`code`)

### Table: `work_center_behavior_map`

Maps existing `work_center` rows to behavior presets.

| Field | Type | Description |
|-------|------|-------------|
| `id_work_center` | int FK | References `work_center.id_work_center` |
| `id_behavior` | int FK | References `work_center_behavior.id_behavior` |
| `override_settings` | json | Future: per-factory custom overrides (JSON) |
| `created_at` | datetime | Standard timestamp |
| `updated_at` | datetime | Standard timestamp |

**Indexes:**
- PRIMARY KEY (`id_work_center`, `id_behavior`)
- FOREIGN KEY (`id_work_center`) REFERENCES `work_center(id_work_center)` ON DELETE CASCADE
- FOREIGN KEY (`id_behavior`) REFERENCES `work_center_behavior(id_behavior)` ON DELETE CASCADE

### Behavior Preset Examples

#### CUT (Cutting – Batch)

```sql
INSERT INTO work_center_behavior (
    code, name, description,
    is_hatthasilpa_supported, is_classic_supported,
    execution_mode, time_tracking_mode,
    requires_quantity_input, allows_component_binding, allows_defect_capture,
    supports_multiple_passes, ui_template_code, default_expected_duration
) VALUES (
    'CUT', 'Cutting', 'Cutting raw materials into required shapes',
    1, 1,
    'BATCH', 'PER_BATCH',
    1, 0, 1,
    0, 'CUT_DIALOG', 1800
);
```

**Characteristics:**
- `execution_mode: BATCH` → Creates batch tokens
- `time_tracking_mode: PER_BATCH` → Time recorded at batch level
- `requires_quantity_input: 1` → Worker must input planned quantity
- `allows_component_binding: 0` → Component serials not generated yet
- `allows_defect_capture: 1` → Can capture defect codes (e.g., CUT02 – warped edge)
- `default_expected_duration: 1800` → 30 minutes per batch

#### EDGE (Edge Paint – Mixed)

```sql
INSERT INTO work_center_behavior (
    code, name, description,
    is_hatthasilpa_supported, is_classic_supported,
    execution_mode, time_tracking_mode,
    requires_quantity_input, allows_component_binding, allows_defect_capture,
    supports_multiple_passes, ui_template_code, default_expected_duration
) VALUES (
    'EDGE', 'Edge Paint', 'Edge painting with multiple rounds',
    1, 0,
    'MIXED', 'PER_BATCH',
    1, 0, 1,
    1, 'EDGE_DIALOG', 900
);
```

**Characteristics:**
- `execution_mode: MIXED` → Batch painting but time tracked per piece/round
- `time_tracking_mode: PER_BATCH` → Time recorded at batch level
- `requires_quantity_input: 1` → Worker inputs how many pieces to paint today
- `supports_multiple_passes: 1` → Supports rounds 1, 2, 3
- `default_expected_duration: 900` → 15 minutes per round

#### STITCH (Stitching – Hatthasilpa Single)

```sql
INSERT INTO work_center_behavior (
    code, name, description,
    is_hatthasilpa_supported, is_classic_supported,
    execution_mode, time_tracking_mode,
    requires_quantity_input, allows_component_binding, allows_defect_capture,
    supports_multiple_passes, ui_template_code, default_expected_duration
) VALUES (
    'STITCH', 'Stitching', 'Hand-stitching single pieces',
    1, 0,
    'SINGLE', 'PER_PIECE',
    0, 0, 1,
    0, 'HAT_SINGLE_TIMER', 3600
);
```

**Characteristics:**
- `execution_mode: SINGLE` → One worker, one piece
- `time_tracking_mode: PER_PIECE` → Time recorded per piece
- `requires_quantity_input: 0` → No quantity input (single piece)
- `allows_defect_capture: 1` → Can capture defect codes (e.g., SEW05 – thread break)
- `default_expected_duration: 3600` → 60 minutes per piece

#### QC_FINAL (Final Quality Control)

```sql
INSERT INTO work_center_behavior (
    code, name, description,
    is_hatthasilpa_supported, is_classic_supported,
    execution_mode, time_tracking_mode,
    requires_quantity_input, allows_component_binding, allows_defect_capture,
    supports_multiple_passes, ui_template_code, default_expected_duration
) VALUES (
    'QC_FINAL', 'Final Quality Control', 'Final inspection with component completeness check',
    1, 1,
    'SINGLE', 'PER_PIECE',
    0, 1, 1,
    0, 'QC_PANEL', 300
);
```

**Characteristics:**
- `execution_mode: SINGLE` → One piece at a time
- `allows_component_binding: 1` → Checks component binding completeness
- `allows_defect_capture: 1` → Captures defect codes
- `default_expected_duration: 300` → 5 minutes per piece

---

## Event → Screen → Data Flow

### Scenario: CUT 20 sets but only 18 real

**Step 1: MO Screen / Hatthasilpa Job Ticket**
- Planner creates MO: 10 bags → System calculates required cut pieces (X pieces per bag) → Total = 10 * X
- DAG determines first node uses Work Center = CUT

**Step 2: Work Queue – CUT Node**
- System loads behavior `CUT`:
  - `execution_mode = BATCH` → UI shows "Start batch cutting" dialog
  - `requires_quantity_input = 1` → Worker inputs "planned quantity = 20 sets"
- Worker clicks Start → Time Engine starts batch timer (no per-piece detail)

**Step 3: When work completes**
- Worker inputs "actual quantity = 18 sets" in completion dialog
- System:
  - Creates/updates batch token:
    - `planned_qty = 20`
    - `actual_qty = 18`
    - `scrap_qty = 2`
  - Marks 2 missing sets as scrap with reason (e.g., CUT02 – insufficient leather/damage)

**Step 4: System outputs**
- MO screen → Shows status: "CUT Completed (18/20) + scrap 2"
- CUT performance report → Shows batch scrap rate: 10%
- Token Engine → Knows next step (STITCH) has max input of 18 pieces (even if original MO planned 10 bags, system may split MO or store excess as component stock)

### Scenario: Worker forgot to press Pause during STITCH (Hatthasilpa)

**Step 1: Work Queue – STITCH Node**
- Behavior = STITCH (SINGLE, PER_PIECE)
- Worker clicks Start for piece #1 → Token A marked RUNNING + Time Engine starts

**Step 2: Worker forgot Pause → went to other work**
- Time Engine fail-safe (from SPEC_TIME_ENGINE):
  - If duration exceeds threshold (e.g., 3 hours vs expected 1 hour)
  - Marks state as "OVER_LIMIT" and alerts backend/reports
  - Still records time but flags "needs review" (not auto-defect)

**Step 3: UI display**
- Work Queue (Supervisor view) → Shows Token A = "Running (Over Limit)"
- Supervisor can:
  - Adjust time (manual correction)
  - Add comment: "Forgot to press Pause, went to help other work"

**Key point:** STITCH behavior indicates:
- This is single-piece work
- Time = per piece
- Time Engine uses `default_expected_duration` from behavior to detect "over limit"

### Scenario: EDGE multiple passes

**Step 1: Work Queue – EDGE Node**
- Behavior = EDGE (MIXED, PER_BATCH, supports_multiple_passes: 1)
- Worker inputs quantity: 10 pieces
- Worker clicks Start → Batch session starts

**Step 2: Multiple rounds**
- Round 1: Worker completes → System records round 1 completion
- Round 2: Worker starts → System records round 2 start
- Round 3: Worker completes → System records round 3 completion
- Total time: Sum of all rounds (tracked per batch)

**Step 3: System outputs**
- Token metadata: `{"rounds": 3, "round_times": [900, 850, 920]}`
- Performance report: Average round time per batch

### Scenario: QC_FINAL with component completeness check

**Step 1: Work Queue – QC_FINAL Node**
- Behavior = QC_FINAL (SINGLE, allows_component_binding: 1)
- Token arrives at QC_FINAL node

**Step 2: Component completeness check**
- System queries `job_component_serial` for this token's final_piece_serial
- Checks if all required components are bound (from BOM)
- If missing → QC cannot pass → Shows warning

**Step 3: QC decision**
- Inspector reviews component bindings
- If complete → Can mark PASS
- If incomplete → Must mark FAIL → Triggers rework

---

## Integration & Dependencies

- **Token Engine:** Behavior `execution_mode` determines token type (batch vs single)
- **Time Engine:** Behavior `time_tracking_mode` and `default_expected_duration` control time recording and over-limit detection
- **Component Binding:** Behavior `allows_component_binding` controls whether node can bind components
- **QC System:** Behavior `allows_defect_capture` controls whether node can capture defect codes
- **DAG Designer:** Behavior selection in designer maps to `work_center_behavior.code`

---

## Implementation Roadmap (Tasks)

1. **WC-01:** Create `work_center_behavior` table and seed presets (CUT, EDGE, STITCH, QC_FINAL, HARDWARE_ASSEMBLY, QC_REPAIR, etc.)
   - Migration file: `database/tenant_migrations/YYYY_MM_work_center_behavior.php`
   - Seed data: Insert all preset behaviors with correct attributes

2. **WC-02:** Create `work_center_behavior_map` table
   - Migration file: `database/tenant_migrations/YYYY_MM_work_center_behavior_map.php`
   - Foreign keys to `work_center` and `work_center_behavior`

3. **WC-03:** Implement mapping UI in `/work_centers` to attach behavior to work centers
   - Screen: Work Center management page
   - Action: Select behavior from dropdown
   - Store mapping in `work_center_behavior_map`

4. **WC-04:** Integrate behavior into work_queue rendering
   - Load behavior for each node's work center
   - Use `ui_template_code` to select UI template
   - Use `requires_quantity_input` to show/hide quantity field
   - Use `execution_mode` to determine batch vs single dialog

5. **WC-05:** Add over-limit hint using `default_expected_duration`
   - In work_queue, compare actual time vs `default_expected_duration`
   - Show warning if exceeded threshold (e.g., 150% of expected)
   - Integrates with SPEC_TIME_ENGINE over-limit detection

6. **WC-06:** Integrate behavior with Token Engine
   - When spawning tokens, check behavior `execution_mode`
   - If BATCH → Create batch token
   - If SINGLE → Create single token
   - If MIXED → Create batch token but track time per piece

7. **WC-07:** Integrate behavior with Component Binding
   - Check `allows_component_binding` before showing component binding UI
   - Only ASSEMBLE, QC_FINAL, PACK nodes allow binding

8. **WC-08:** Integrate behavior with QC System
   - Check `allows_defect_capture` before showing defect code selector
   - Link defect codes to behavior code (e.g., CUT02, EP01, SEW05)

**Constraints:**
- No breaking changes to Classic line yet
- Must preserve existing `work_center` table structure
- Behavior mapping is additive (existing work centers can remain unmapped initially)

---

**Source:** [REALITY_EVENT_IN_HOUSE.md](REALITY_EVENT_IN_HOUSE.md) Section 1  
**Related:** [DAG_IMPLEMENTATION_GUIDE.md](DAG_IMPLEMENTATION_GUIDE.md) Section 3  
**Last Updated:** December 2025


# Leather Stock Reality Spec

**Bellavier Group ERP – DAG System**

This spec defines the "Leather Reality Layer" that tracks leather stock by physical characteristics (size, quality, shape) rather than just total square feet, enabling accurate production planning and waste reduction.

---

## Purpose & Scope

- Tracks leather stock by physical characteristics (piece size, quality zone, shape, history)
- Implements Leather Steward workflow for bucketing leather pieces
- Provides reconciliation logic (system stock vs bucket reality)
- Generates warnings for planners when panel-grade stock is low
- Suggests small goods production when offcut ratio is high
- **Out of scope:** Precise centimeter-level tracking (approximate bucketing is sufficient)

---

## Key Concepts & Definitions

- **Leather Bucket:** Physical category of leather piece (FULL_HIDE, BIG_PANEL, MEDIUM_PARTS, SMALL_OFFCUT, SCRAP_OR_UNKNOWN)
- **Leather Steward:** Role responsible for bucketing leather pieces daily
- **Reconciliation:** Process of comparing system stock (T) vs bucket reality (B_total)
- **Panel Ratio:** Percentage of stock that is panel-grade (usable for large panels)
- **Offcut Ratio:** Percentage of stock that is small offcuts (usable for small goods)
- **Unknown Ratio:** Percentage of stock that cannot be categorized

---

## Data Model

### Table: `leather_bucket` (Proposed)

Stores leather pieces bucketed by physical characteristics.

| Field | Type | Description |
|-------|------|-------------|
| `id_bucket` | int PK | Primary key |
| `id_stock_item` | int FK | References `stock_item.id_stock_item` (if linked) |
| `bucket_type` | enum | 'FULL_HIDE', 'BIG_PANEL', 'MEDIUM_PARTS', 'SMALL_OFFCUT', 'SCRAP_OR_UNKNOWN' |
| `sq_ft` | decimal(10,2) | Square feet in this bucket |
| `quality_zone` | varchar(50) | 'prime', 'secondary', 'reject' (optional) |
| `shape_note` | text | Shape description (long, short, curved, etc.) |
| `source_job_id` | int FK | References `job_ticket.id_job_ticket` (if from production) |
| `bucketed_by` | int | Leather Steward user ID |
| `bucketed_at` | datetime | Bucketing timestamp |
| `created_at` | datetime | Standard timestamp |
| `updated_at` | datetime | Standard timestamp |

**Indexes:**
- PRIMARY KEY (`id_bucket`)
- INDEX `idx_bucket_type` (`bucket_type`)
- INDEX `idx_stock_item` (`id_stock_item`)

### Table: `leather_reality_snapshot` (Proposed)

Stores periodic snapshots of leather reality for trend analysis.

| Field | Type | Description |
|-------|------|-------------|
| `id_snapshot` | int PK | Primary key |
| `snapshot_date` | date | Snapshot date |
| `total_sq_ft` | decimal(10,2) | Total stock from system (T) |
| `bucket_total_sq_ft` | decimal(10,2) | Sum of all buckets (B_total) |
| `unknown_sq_ft` | decimal(10,2) | B_unknown = T - B_total (if B_total < T) |
| `panel_ratio` | decimal(5,2) | B_panel / T (percentage) |
| `offcut_ratio` | decimal(5,2) | (B_medium + B_small) / T (percentage) |
| `unknown_ratio` | decimal(5,2) | B_unknown / T (percentage) |
| `created_at` | datetime | Standard timestamp |

**Indexes:**
- PRIMARY KEY (`id_snapshot`)
- INDEX `idx_snapshot_date` (`snapshot_date`)

### Bucket Types

| Bucket Type | Description | Usable For |
|-------------|-------------|------------|
| FULL_HIDE | Full hide/side | Large panels, multiple pieces |
| BIG_PANEL | Large panel-size pieces | Large panels (front/back of bag) |
| MEDIUM_PARTS | Medium-sized pieces | Medium parts, straps |
| SMALL_OFFCUT | Small offcuts | Small goods (card holder, key charm) |
| SCRAP_OR_UNKNOWN | Unusable or uncategorized | Scrap, cannot be used |

---

## Event → Screen → Data Flow

### Scenario: Planner Tries to Create MO for Panel-Hungry Product

**Step 1: MO Creation Screen**
- Planner opens MO creation for Product X
- Product X requires large panels (front/back of bag)
- System checks leather reality:
  - Queries `leather_reality_snapshot` (latest)
  - Calculates: `panel_ratio = B_panel / T`

**Step 2: Warning Display**
- If `panel_ratio < 0.3` (30%):
  - System shows warning: "Stock number sufficient but panel-grade balance low (risk: cannot cut large panels)"
  - Planner can:
    - Proceed anyway (with acknowledgment)
    - Cancel and order more panel-grade leather

**Step 3: MO Creation**
- If planner proceeds → MO created
- System tracks: Product X requires panel-grade leather
- If cutting fails → System logs: "Insufficient panel-grade stock"

### Scenario: Leather Steward Bucketing Workflow

**Step 1: Leather Steward UI**
- Screen: `/leather_steward` or `/materials/leather_bucket`
- Leather Steward collects leather pieces from production floor
- Steward opens bucketing interface

**Step 2: Bucketing Process**
- Steward selects leather pieces
- For each piece:
  - Selects bucket type (FULL_HIDE, BIG_PANEL, MEDIUM_PARTS, SMALL_OFFCUT, SCRAP_OR_UNKNOWN)
  - Inputs sq_ft (approximate)
  - Optionally: quality_zone, shape_note
- Steward submits batch

**Step 3: Reconciliation**
- System calculates:
  - T = Total sq_ft from `stock_item` (system stock)
  - B_total = Sum of all buckets
  - If B_total < T → B_unknown = T - B_total (auto-categorized as SCRAP_OR_UNKNOWN)
  - If B_total > T → Warning: "Bucketed more than system stock, please verify"

**Step 4: KPI Calculation**
- System calculates ratios:
  - `panel_ratio = B_panel / T`
  - `offcut_ratio = (B_medium + B_small) / T`
  - `unknown_ratio = B_unknown / T`
- Creates `leather_reality_snapshot` record

### Scenario: System Suggests Small Goods When Offcut Ratio High

**Step 1: High Offcut Ratio Detection**
- System checks latest snapshot: `offcut_ratio > 0.5` (50%)
- System identifies: High accumulation of small offcuts

**Step 2: Suggestion Display**
- Planner dashboard shows:
  - "Offcut ratio high (55%) → Recommend producing small goods"
  - Lists products that can use offcuts:
    - Card Holder
    - Key Charm
    - Small Wallet

**Step 3: Planner Action**
- Planner can:
  - Create MO for small goods (uses offcuts)
  - Or ignore suggestion

---

## Integration & Dependencies

- **Stock System:** Leather stock tracked in `stock_item` table (T = system stock)
- **MO Planning:** MO creation checks leather reality before allowing creation
- **Product System:** Products can have `requires_panel_parts` flag
- **CUT Node:** CUT node can record residual pattern (what leather remains after cutting)

---

## Implementation Roadmap (Tasks)

1. **L-01:** Add leather reality tables
   - Create `leather_bucket` table
   - Create `leather_reality_snapshot` table
   - Migration file: `database/tenant_migrations/YYYY_MM_leather_reality.php`

2. **L-02:** Build Leather Steward UI/flow for bucketing
   - Screen: `/materials/leather_bucket` or `/leather_steward`
   - UI: Bucket selection, sq_ft input, batch submission
   - API: `leather_steward_api.php?action=bucket_leather`
   - Reconciliation logic: T vs B_total calculation

3. **L-03:** Add MO planner warnings based on ratios
   - Service: `LeatherRealityService::checkPanelAvailability(int $productId)`
   - Queries latest snapshot
   - Calculates panel_ratio
   - Returns warning if ratio < threshold (0.3)

4. **L-04:** Add "offcut product line" analytics
   - Query: Products that can use offcuts
   - Display: Offcut ratio + suggested products
   - Integration: Planner dashboard

5. **L-05:** Integrate with CUT node residual pattern
   - CUT node completion: Record residual pattern
   - Options: "1 large panel + small offcuts" or "small offcuts only"
   - Updates leather reality automatically

6. **L-06:** Add reconciliation reports
   - Report: Leather Reality Reconciliation
   - Shows: T vs B_total, unknown_ratio trend
   - Alerts: High unknown_ratio (needs better bucketing)

**Constraints:**
- Approximate bucketing is sufficient (no centimeter-level precision required)
- Must preserve existing `stock_item` structure (additive only)
- Leather Steward workflow is manual (no automatic bucketing)

---

**Source:** [REALITY_EVENT_IN_HOUSE.md](REALITY_EVENT_IN_HOUSE.md) Section 2  
**Related:** [SPEC_WORK_CENTER_BEHAVIOR.md](SPEC_WORK_CENTER_BEHAVIOR.md) (CUT node)  
**Last Updated:** December 2025


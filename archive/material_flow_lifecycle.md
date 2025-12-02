# Material Flow Lifecycle

**Generated:** December 2025  
**Purpose:** Complete lifecycle documentation for Material Pipeline (GRN → Material → Leather Sheet → CUT → BOM → DAG)  
**Task:** Task 13.15 — Schema Mapping & Material Pipeline Blueprint

---

## Overview

This document describes the complete lifecycle of materials from GRN intake through production to finish, focusing on the leather sheet traceability flow.

---

## Lifecycle Stages

### Stage 1: GRN Intake (Leather GRN Flow)

**Purpose:** Receive leather sheets into warehouse

**Actors:**
- Warehouse staff
- System (auto-generation)

**Steps:**

1. **Material Selection**
   - User selects material from `stock_item` (filtered by `material_type LIKE '%leather%'`)
   - System validates material exists and is leather type
   - **Source:** `stock_item.sku` (source of truth)

2. **GRN Header Creation**
   - System creates `material_lot` record:
     - `id_stock_item`: FK to `stock_item`
     - `lot_code`: Auto-generated or user input
     - `is_leather_grn`: Set to `1` (flag for Leather GRN flow)
     - `quantity`: Total quantity received
     - `area_sqft`: Total area (for leather)
     - `grade`: Quality grade (A, B, C, D)
     - `status`: Set to `'available'`

3. **Leather Sheet Creation**
   - For each physical sheet:
     - System creates `leather_sheet` record:
       - `sku_material`: FK to `material.sku` (legacy FK)
       - `id_lot`: FK to `material_lot.id_material_lot` (GRN lot)
       - `sheet_code`: Unique sheet identifier (auto-generated)
       - `area_sqft`: Sheet area
       - `area_remaining_sqft`: Initially equals `area_sqft`
       - `status`: Set to `'active'`
       - `batch_code`: Optional batch code

4. **Transaction Commit**
   - All records created in single transaction
   - If any step fails, entire transaction rolls back

**Tables Involved:**
- `stock_item` (read)
- `material_lot` (create)
- `leather_sheet` (create)

**Related Tasks:**
- Task 13.10: Unified Leather GRN Flow
- Task 13.11: Leather GRN Warehouse UX Overhaul

---

### Stage 2: Material Registration (Master Data)

**Purpose:** Ensure material master data exists

**Actors:**
- System (auto-creation if needed)
- Admin (manual creation)

**Steps:**

1. **Stock Item Creation** (if not exists)
   - System checks if `stock_item` with matching SKU exists
   - If not, creates `stock_item` record:
     - `sku`: Material SKU
     - `name`: Material name
     - `material_type`: Set to `'leather'`
     - `id_uom`: Unit of measure (e.g., sq.ft)
     - `is_active`: Set to `1`

2. **Legacy Material Creation** (if needed for compatibility)
   - System checks if `material` with matching SKU exists
   - If not, creates `material` record:
     - `sku`: Material SKU (must match `stock_item.sku`)
     - `name`: Material name
     - `category`: Set to `'Leather'`
     - `is_active`: Set to `1`

**Tables Involved:**
- `stock_item` (create/read)
- `material` (create/read, legacy)

**Note:** 
- `stock_item` is the **source of truth** for material SKU
- `material` is maintained for legacy compatibility

---

### Stage 3: Lot Creation (GRN Header)

**Purpose:** Create material lot/batch for tracking

**Actors:**
- System (auto-creation during GRN)

**Steps:**

1. **Lot Creation**
   - System creates `material_lot` record:
     - `id_stock_item`: FK to `stock_item`
     - `lot_code`: Unique lot code per material
     - `is_leather_grn`: Set to `1` for Leather GRN flow
     - `quantity`: Total quantity
     - `area_sqft`: Total area (for leather)
     - `grade`: Quality grade
     - `status`: Set to `'available'`

2. **Lot Validation**
   - System validates `id_stock_item` exists
   - System validates `lot_code` is unique per `id_stock_item`

**Tables Involved:**
- `material_lot` (create)
- `stock_item` (read)

---

### Stage 4: Leather Sheet Creation (Physical Inventory)

**Purpose:** Create physical leather sheet records

**Actors:**
- System (auto-creation during GRN)

**Steps:**

1. **Sheet Creation**
   - For each physical sheet:
     - System creates `leather_sheet` record:
       - `sku_material`: FK to `material.sku` (legacy)
       - `id_lot`: FK to `material_lot.id_material_lot` (GRN lot)
       - `sheet_code`: Unique sheet code
       - `area_sqft`: Sheet area
       - `area_remaining_sqft`: Initially equals `area_sqft`
       - `status`: Set to `'active'`

2. **Sheet Validation**
   - System validates `sku_material` exists in `material` table
   - System validates `id_lot` exists in `material_lot` table
   - System validates `sheet_code` is unique

**Tables Involved:**
- `leather_sheet` (create)
- `material` (read, legacy)
- `material_lot` (read)

---

### Stage 5: Sheet Usage → CUT BOM → CUT Behavior

**Purpose:** Use leather sheets for cutting operations

**Actors:**
- Production worker (CUT operator)
- System (auto-calculation)

**Steps:**

1. **Token Arrival at CUT Node**
   - DAG token arrives at CUT behavior node
   - System loads token context:
     - `token_id`: DAG token ID
     - `id_instance`: Graph instance
     - `id_job_ticket`: Job ticket
     - `id_product`: Product ID

2. **Material SKU Resolution** (Task 13.13)
   - System resolves material SKU from token:
     - Path: `flow_token` → `job_graph_instance` → `job_ticket` → `product` → `bom` → `bom_line`
     - Filters: `bom_line.material_sku` where `material_type LIKE '%leather%'`
     - Result: Primary leather material SKU

3. **BOM Loading** (Task 13.14)
   - System loads BOM lines for product:
     - Query: `bom_line` WHERE `id_bom` = (active BOM for product)
     - Filters: Leather materials only
     - Fields: `qty_plan`, `area_per_piece`, `material_sku`

4. **Sheet Selection** (Task 13.12)
   - User selects available leather sheets:
     - Query: `leather_sheet` WHERE `sku_material` = resolved SKU AND `status = 'active'` AND `area_remaining_sqft > 0`
     - User selects sheets to use
     - System creates `leather_sheet_usage_log` records:
       - `id_sheet`: Selected sheet ID
       - `token_id`: DAG token ID
       - `used_area`: Area used (calculated later)
       - `used_by`: Worker ID

5. **CUT Input** (Task 13.14)
   - User inputs actual quantities per BOM line:
     - `qty_actual`: Actual quantity cut
     - System calculates:
       - `area_used`: `qty_actual * area_per_piece`
       - `area_planned`: `qty_plan * area_per_piece`

6. **Overcut Classification** (Task 13.14)
   - If `qty_actual > qty_plan`:
     - System opens overcut classification popup
     - User classifies overcut:
       - `qty_extra_good`: Extra good pieces (kept for future use)
       - `qty_scrap`: Scrapped pieces
     - Validation: `qty_extra_good + qty_scrap ≤ (qty_actual - qty_plan)`

7. **CUT BOM Log Creation**
   - System creates `leather_cut_bom_log` records:
     - `token_id`: DAG token ID
     - `bom_line_id`: BOM line ID
     - `qty_plan`: Planned quantity
     - `qty_actual`: Actual quantity
     - `qty_scrap`: Scrapped quantity
     - `qty_extra_good`: Extra good pieces
     - `area_per_piece`: Area per piece
     - `area_planned`: Planned area
     - `area_used`: Used area

8. **Sheet Area Update**
   - System updates `leather_sheet.area_remaining_sqft`:
     - `area_remaining_sqft` = `area_remaining_sqft` - `used_area`
     - If `area_remaining_sqft <= 0`, set `status = 'depleted'`

9. **Cut Batch Creation** (Task 13.8)
   - System creates `cut_batch` record:
     - `token_id`: DAG token ID
     - `sheet_id`: Sheet ID
     - `total_components`: Total components cut
     - `cut_at`: Cut timestamp
     - `created_by`: Worker ID

**Tables Involved:**
- `flow_token` (read)
- `job_graph_instance` (read)
- `job_ticket` (read)
- `product` (read)
- `bom` (read)
- `bom_line` (read)
- `leather_sheet` (read/update)
- `leather_sheet_usage_log` (create)
- `leather_cut_bom_log` (create)
- `cut_batch` (create)

**Related Tasks:**
- Task 13.12: Leather Sheet Usage Binding
- Task 13.13: Auto Material SKU Detection
- Task 13.14: BOM-based CUT Input & Overcut Classification

---

### Stage 6: Component Allocation (Task 13.8)

**Purpose:** Link component serials to leather sheets and cut batches

**Actors:**
- System (auto-allocation)

**Steps:**

1. **Component Serial Generation**
   - System generates component serials for cut components
   - Creates `component_serial` records

2. **Allocation Creation**
   - System creates `component_serial_allocation` records:
     - `serial_id`: Component serial ID
     - `sheet_id`: Leather sheet ID
     - `cut_batch_id`: Cut batch ID (optional)
     - `area_used_sqft`: Area consumed by component

3. **Allocation Validation**
   - System validates `serial_id` is unique (one allocation per serial)
   - System validates `sheet_id` exists
   - System validates `cut_batch_id` exists (if set)

**Tables Involved:**
- `component_serial` (read)
- `component_serial_allocation` (create)
- `leather_sheet` (read)
- `cut_batch` (read)

**Related Tasks:**
- Task 13.8: Component Allocation & Leather Sheet Traceability

---

### Stage 7: WIP → QC → Finish

**Purpose:** Continue production flow after CUT

**Actors:**
- Production workers
- QC inspectors
- System (status updates)

**Steps:**

1. **Token Progression**
   - DAG token moves through workflow:
     - CUT → SEW → QC → FINISH
     - System updates `flow_token.status`

2. **QC Operations**
   - QC node processes tokens
   - System records QC results
   - Failed tokens may go to rework

3. **Finish**
   - Token reaches FINISH node
   - System marks token as completed
   - Component serials are finalized

**Tables Involved:**
- `flow_token` (update)
- `node_instance` (update)
- `component_serial` (update)

---

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ Stage 1: GRN Intake (Leather GRN Flow)                          │
│ ─────────────────────────────────────────────────────────────  │
│ 1. Material Selection (stock_item)                             │
│ 2. GRN Header Creation (material_lot)                           │
│ 3. Leather Sheet Creation (leather_sheet)                      │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Stage 2: Material Registration (Master Data)                    │
│ ─────────────────────────────────────────────────────────────  │
│ 1. Stock Item Creation (stock_item)                            │
│ 2. Legacy Material Creation (material, if needed)               │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Stage 3: Lot Creation (GRN Header)                              │
│ ─────────────────────────────────────────────────────────────  │
│ 1. Lot Creation (material_lot)                                  │
│ 2. Lot Validation                                               │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Stage 4: Leather Sheet Creation (Physical Inventory)            │
│ ─────────────────────────────────────────────────────────────  │
│ 1. Sheet Creation (leather_sheet)                               │
│ 2. Sheet Validation                                             │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Stage 5: Sheet Usage → CUT BOM → CUT Behavior                   │
│ ─────────────────────────────────────────────────────────────  │
│ 1. Token Arrival at CUT Node                                    │
│ 2. Material SKU Resolution (Task 13.13)                         │
│ 3. BOM Loading (Task 13.14)                                     │
│ 4. Sheet Selection (Task 13.12)                                 │
│ 5. CUT Input (Task 13.14)                                       │
│ 6. Overcut Classification (Task 13.14)                         │
│ 7. CUT BOM Log Creation (leather_cut_bom_log)                  │
│ 8. Sheet Area Update (leather_sheet)                            │
│ 9. Cut Batch Creation (cut_batch)                               │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Stage 6: Component Allocation (Task 13.8)                       │
│ ─────────────────────────────────────────────────────────────  │
│ 1. Component Serial Generation                                  │
│ 2. Allocation Creation (component_serial_allocation)           │
│ 3. Allocation Validation                                        │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ Stage 7: WIP → QC → Finish                                      │
│ ─────────────────────────────────────────────────────────────  │
│ 1. Token Progression                                             │
│ 2. QC Operations                                                │
│ 3. Finish                                                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Summary

### Material SKU Flow
```
stock_item.sku (source of truth)
    ↓
material_lot.id_stock_item → stock_item.id_stock_item
    ↓
leather_sheet.id_lot → material_lot.id_material_lot
    ↓
leather_sheet.sku_material → material.sku (legacy)
```

### BOM to CUT Flow
```
product.id_product
    ↓
bom.id_product → product.id_product
    ↓
bom_line.id_bom → bom.id_bom
    ↓
bom_line.material_sku (string, no FK)
    ↓
leather_cut_bom_log.bom_line_id → bom_line.id_bom_line
```

### Sheet Usage Flow
```
leather_sheet.id_sheet
    ↓
leather_sheet_usage_log.id_sheet → leather_sheet.id_sheet
    ↓
leather_sheet_usage_log.token_id → flow_token.id_token
    ↓
flow_token.id_instance → job_graph_instance.id_instance
    ↓
job_graph_instance.id_job_ticket → job_ticket.id_job_ticket
```

### Component Allocation Flow
```
component_serial.id_component_serial
    ↓
component_serial_allocation.serial_id → component_serial.id_component_serial
    ↓
component_serial_allocation.sheet_id → leather_sheet.id_sheet
    ↓
component_serial_allocation.cut_batch_id → cut_batch.id_cut_batch
```

---

## Key Points

1. **Source of Truth:** `stock_item.sku` is the source of truth for material SKU
2. **Legacy Support:** `material.sku` is maintained for legacy compatibility
3. **Dual FK:** `leather_sheet` has both legacy FK (`sku_material` → `material`) and new FK (`id_lot` → `material_lot`)
4. **String FK:** `bom_line.material_sku` is a string without FK constraint
5. **Transaction Safety:** All critical operations are wrapped in transactions
6. **Idempotency:** All operations are idempotent (safe to retry)

---

**End of Material Flow Lifecycle**


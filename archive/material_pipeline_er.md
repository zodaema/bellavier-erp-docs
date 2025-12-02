# Material Pipeline ER Diagram

**Generated:** December 2025  
**Purpose:** Entity-Relationship diagram for Material Pipeline (GRN → Material → Leather Sheet → CUT → BOM → DAG)  
**Task:** Task 13.15 — Schema Mapping & Material Pipeline Blueprint

---

## ER Diagram (Mermaid)

```mermaid
erDiagram
    %% Material Master Data
    MATERIAL {
        int id_material PK
        varchar sku UK "Unique SKU"
        varchar name
        int default_uom FK
        varchar category
        tinyint is_active
    }
    
    STOCK_ITEM {
        bigint id_stock_item PK
        varchar sku UK "Unique SKU"
        varchar name
        varchar material_type "leather, textile, hardware"
        int id_uom FK
        tinyint is_active
    }
    
    UNIT_OF_MEASURE {
        int id_unit PK
        varchar code
        varchar name
    }
    
    %% GRN & Lot Management
    MATERIAL_LOT {
        int id_material_lot PK
        bigint id_stock_item FK
        varchar lot_code
        decimal quantity
        int id_uom FK
        decimal area_sqft
        varchar grade
        tinyint is_leather_grn "Leather GRN flag"
    }
    
    %% Leather Sheet Inventory
    LEATHER_SHEET {
        int id_sheet PK
        varchar sku_material FK "Legacy: material.sku"
        int id_lot FK "GRN lot"
        varchar batch_code
        varchar sheet_code UK
        decimal area_sqft
        decimal area_remaining_sqft
        enum status "active, depleted, archived"
    }
    
    %% BOM Structure
    PRODUCT {
        int id_product PK
        varchar code
        varchar name
    }
    
    BOM {
        int id_bom PK
        int id_product FK
        varchar version
        tinyint is_active
    }
    
    BOM_LINE {
        int id_bom_line PK
        int id_bom FK
        varchar material_sku "String, no FK"
        int id_child_product FK "Sub-assembly"
        decimal qty
        int id_uom FK
        decimal waste_pct
    }
    
    %% CUT Operations
    LEATHER_CUT_BOM_LOG {
        int id_log PK
        int token_id FK
        int bom_line_id FK
        decimal qty_plan
        decimal qty_actual
        decimal qty_scrap
        decimal qty_extra_good
        decimal area_per_piece
        decimal area_planned
        decimal area_used
    }
    
    LEATHER_SHEET_USAGE_LOG {
        int id_usage PK
        int id_sheet FK
        int token_id FK
        decimal used_area
        int used_by FK
    }
    
    CUT_BATCH {
        int id_cut_batch PK
        int token_id FK
        int sheet_id FK
        int total_components
        datetime cut_at
        int created_by FK
    }
    
    %% Component Allocation
    COMPONENT_SERIAL {
        int id_component_serial PK
        varchar serial_number
    }
    
    COMPONENT_SERIAL_ALLOCATION {
        int id_alloc PK
        int serial_id FK
        int sheet_id FK
        int cut_batch_id FK
        decimal area_used_sqft
    }
    
    %% DAG Integration
    JOB_TICKET {
        int id_job_ticket PK
        int id_product FK
        int id_mo FK
    }
    
    JOB_GRAPH_INSTANCE {
        int id_instance PK
        int id_job_ticket FK
        int id_graph FK
    }
    
    FLOW_TOKEN {
        int id_token PK
        int id_instance FK
        enum status
    }
    
    %% Relationships - Material Master
    MATERIAL ||--o{ LEATHER_SHEET : "sku_material (legacy FK)"
    STOCK_ITEM ||--o{ MATERIAL_LOT : "id_stock_item"
    UNIT_OF_MEASURE ||--o{ MATERIAL : "default_uom"
    UNIT_OF_MEASURE ||--o{ STOCK_ITEM : "id_uom"
    UNIT_OF_MEASURE ||--o{ MATERIAL_LOT : "id_uom"
    UNIT_OF_MEASURE ||--o{ BOM_LINE : "id_uom"
    
    %% Relationships - GRN & Lot
    MATERIAL_LOT ||--o{ LEATHER_SHEET : "id_lot"
    
    %% Relationships - BOM
    PRODUCT ||--o{ BOM : "id_product"
    PRODUCT ||--o{ JOB_TICKET : "id_product"
    PRODUCT ||--o{ BOM_LINE : "id_child_product (sub-assembly)"
    BOM ||--o{ BOM_LINE : "id_bom"
    
    %% Relationships - Leather Sheet Usage
    LEATHER_SHEET ||--o{ LEATHER_SHEET_USAGE_LOG : "id_sheet"
    LEATHER_SHEET ||--o{ CUT_BATCH : "sheet_id"
    LEATHER_SHEET ||--o{ COMPONENT_SERIAL_ALLOCATION : "sheet_id"
    
    %% Relationships - CUT Operations
    FLOW_TOKEN ||--o{ LEATHER_CUT_BOM_LOG : "token_id"
    FLOW_TOKEN ||--o{ LEATHER_SHEET_USAGE_LOG : "token_id"
    FLOW_TOKEN ||--o{ CUT_BATCH : "token_id"
    BOM_LINE ||--o{ LEATHER_CUT_BOM_LOG : "bom_line_id"
    
    %% Relationships - Component Allocation
    COMPONENT_SERIAL ||--|| COMPONENT_SERIAL_ALLOCATION : "serial_id (unique)"
    CUT_BATCH ||--o{ COMPONENT_SERIAL_ALLOCATION : "cut_batch_id"
    
    %% Relationships - DAG Integration
    JOB_TICKET ||--o{ JOB_GRAPH_INSTANCE : "id_job_ticket"
    JOB_GRAPH_INSTANCE ||--o{ FLOW_TOKEN : "id_instance"
```

---

## Key Relationships Summary

### 1. Material Master Data Flow
```
STOCK_ITEM (source of truth)
    ↓ (id_stock_item)
MATERIAL_LOT (GRN lot)
    ↓ (id_lot)
LEATHER_SHEET (physical sheet)
```

**Legacy Path:**
```
MATERIAL (legacy)
    ↓ (sku_material)
LEATHER_SHEET (legacy FK)
```

### 2. BOM to CUT Flow
```
PRODUCT
    ↓ (id_product)
BOM
    ↓ (id_bom)
BOM_LINE
    ↓ (bom_line_id)
LEATHER_CUT_BOM_LOG (CUT results)
```

### 3. Leather Sheet Usage Flow
```
LEATHER_SHEET
    ↓ (id_sheet)
LEATHER_SHEET_USAGE_LOG (usage per token)
    ↓ (token_id)
FLOW_TOKEN (DAG token)
```

### 4. CUT Batch Flow
```
FLOW_TOKEN (DAG token)
    ↓ (token_id)
CUT_BATCH (cut operation)
    ↓ (sheet_id)
LEATHER_SHEET (sheet used)
    ↓ (sheet_id)
COMPONENT_SERIAL_ALLOCATION (component allocation)
```

### 5. DAG Integration Flow
```
JOB_TICKET (work order)
    ↓ (id_job_ticket)
JOB_GRAPH_INSTANCE (graph execution)
    ↓ (id_instance)
FLOW_TOKEN (work unit)
    ↓ (token_id)
LEATHER_CUT_BOM_LOG (CUT results)
LEATHER_SHEET_USAGE_LOG (sheet usage)
CUT_BATCH (cut batch)
```

---

## Foreign Key Constraints

### Direct FK Constraints (Enforced)
- `material_lot.id_stock_item` → `stock_item.id_stock_item`
- `leather_sheet.sku_material` → `material.sku` (legacy)
- `leather_sheet.id_lot` → `material_lot.id_material_lot`
- `bom.id_product` → `product.id_product`
- `bom_line.id_bom` → `bom.id_bom`
- `leather_cut_bom_log.token_id` → `flow_token.id_token`
- `leather_cut_bom_log.bom_line_id` → `bom_line.id_bom_line`
- `leather_sheet_usage_log.id_sheet` → `leather_sheet.id_sheet`
- `leather_sheet_usage_log.token_id` → `flow_token.id_token`
- `cut_batch.token_id` → `flow_token.id_token`
- `cut_batch.sheet_id` → `leather_sheet.id_sheet`
- `component_serial_allocation.serial_id` → `component_serial.id_component_serial`
- `component_serial_allocation.sheet_id` → `leather_sheet.id_sheet`
- `component_serial_allocation.cut_batch_id` → `cut_batch.id_cut_batch`

### String References (No FK Constraint)
- `bom_line.material_sku` → `stock_item.sku` (string match, no FK)
- `bom_line.material_sku` → `material.sku` (string match, no FK)

---

## Notes

1. **Dual Material Master:** Both `material` and `stock_item` exist with overlapping purposes
2. **Legacy FK:** `leather_sheet.sku_material` references `material(sku)` (legacy)
3. **New FK:** `leather_sheet.id_lot` references `material_lot` (new, Task 13.10)
4. **String FK:** `bom_line.material_sku` is a string without FK constraint
5. **No Direct Link:** `bom_line` has no direct FK to `stock_item` or `material` (only string `material_sku`)

---

**End of ER Diagram**


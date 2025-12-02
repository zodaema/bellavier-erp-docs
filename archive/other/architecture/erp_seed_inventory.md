# ERP Seed & Migration Inventory

**Generated:** 2025-12-09  
**Last Updated:** 2025-12-17  
**Purpose:** Complete inventory of seed data and migrations for master data initialization

**Recent Updates:**
- **Task 15.1 (2025-12-17):** Added PRESS work center and EMBOSS behavior
- **Task 16 (2025-12-16):** Added execution mode seeds and canonical behavior-mode mappings
- **Task 18 (2025-12-17):** Added machine seeds and default machine binding configuration

---

## Core Migration Files

### database/tenant_migrations/0001_init_tenant_schema_v2.php
- **Description:** Complete tenant schema initialization
- **Total Tables:** 122 tables
- **Creates:**
  - All production tables (`job_ticket`, `flow_token`, `routing_graph`, `routing_node`, `routing_edge`, etc.)
  - All audit/log tables (`token_event`, `assignment_log`, `routing_audit_log`, etc.)
  - All reference tables (`work_center`, `unit_of_measure`, `product`, `material`, etc.)
  - All DAG tables (`routing_graph`, `routing_node`, `routing_edge`, `node_instance`, `job_graph_instance`, etc.)
  - All assignment tables (`token_assignment`, `assignment_plan_job`, `assignment_plan_node`, etc.)
  - All serial/traceability tables (`job_ticket_serial`, `serial_link`, `product_trace`, etc.)
  - All team tables (`team`, `team_member`, `operator_availability`, `operator_leave`)
  - All component tables (`component_serial_binding`, `leather_sheet_usage`, `cut_bom`, etc.)
- **Notes:**
  - This is the master schema - all tables created here
  - Uses `migration_create_table_if_missing()` helper (idempotent)
  - Safe to run multiple times

---

### database/tenant_migrations/0002_seed_data.php
- **Description:** Tenant seed data (Essential + Sample)
- **Structure:**
  - Section 1: Essential Data (REQUIRED)
  - Section 2: Sample Data (OPTIONAL, can be skipped with `SKIP_SAMPLE_DATA=true`)

#### Section 1: Essential Data (REQUIRED)

##### 1. Permissions (89 permissions)
- **Table:** `permission`
- **Source:** From template DB (`bgerp_t_maison_atelier`)
- **Count:** 89 permissions
- **Examples:**
  - `adjust.manage`, `adjust.view`
  - `admin.role.manage`, `admin.settings.manage`, `admin.user.manage`
  - `hatthasilpa.job.ticket`, `hatthasilpa.job.wip.scan`, `hatthasilpa.material.lot`
  - `dag.routing.view`, `dag.routing.design.view`, `dag.routing.runtime.view`
  - `hatthasilpa.routing.view`, `hatthasilpa.routing.manage`
  - `dashboard.production.view`, `trace.view`, `trace.manage`
  - `work.queue.*` (view, operate, assign, plan, pin, help, monitor, etc.)
  - `leather.cut.bom.view`, `leather.cut.bom.manage`
  - `leather.sheet.view`, `leather.sheet.use`
  - `classic.job.ticket` (Classic mode permissions)
  - And many more...

##### 2. Tenant Roles (10 essential roles)
- **Table:** `tenant_role`
- **Source:** From template DB
- **Count:** 10 roles
- **Roles:**
  1. `owner` (ID=1) - Owner with full access (is_system=1)
  2. `admin` (ID=2) - Administrator role
  3. `viewer` (ID=3) - Viewer (read only)
  4. `production_manager` (ID=4) - Production manager
  5. `production_operator` (ID=5) - Production operator
  6. `artisan_operator` (ID=6) - Artisan operator
  7. `quality_manager` (ID=7) - Quality control manager
  8. `qc_lead` (ID=8) - QC lead
  9. `inventory_manager` (ID=9) - Inventory manager
  10. `planner` (ID=10) - Production planner
- **Notes:**
  - Fresh install: Explicit IDs 1-10, then AUTO_INCREMENT=11
  - Existing install: Idempotent insert (preserves existing IDs)

##### 3. Role-Permission Mappings
- **Table:** `tenant_role_permission`
- **Source:** From template DB
- **Count:** 370+ mappings
- **Mappings:**
  - `admin`: 50+ permissions (including `dashboard.production.view`, `DAG_SUPERVISOR_SESSIONS`)
  - `artisan_operator`: 6 permissions
  - `inventory_manager`: 27 permissions
  - `planner`: 16 permissions
  - `production_manager`: 33 permissions (including `dashboard.production.view`)
  - `production_operator`: 8 permissions
  - `qc_lead`: 9 permissions
  - `quality_manager`: 14 permissions
  - `viewer`: 4 permissions
- **Notes:**
  - Uses `migration_insert_if_not_exists()` (idempotent)

##### 4. Universal UoM (20 canonical units)
- **Table:** `unit_of_measure`
- **Source:** From template DB (`bgerp_t_maison_atelier.unit_of_measure`)
- **Count:** 20 units
- **Format:** `[code, name, description, is_active, is_system, locked]`
- **Units:**
  1. `pcs` - Piece (ชิ้นงาน) - System, Locked
  2. `mm` - Millimeter - System, Locked
  3. `m` - Meter - System, Locked
  4. `sqft` - Square Foot (ตารางฟุต) - System, Locked
  5. `roll` - Roll (ม้วนวัสดุ) - Not system, Not locked
  6. `yard` - Yard (หลา) - System, Locked
  7. `cm` - Centimeter - System, Locked
  8. `m2` - Square Meter (ตารางเมตร) - System, Locked
  9. `sheet` - Sheet (แผ่น) - System, Locked
  10. `gram` - Gram - System, Locked
  11. `kg` - Kilogram - System, Locked
  12. `ml` - Milliliter - System, Locked
  13. `liter` - Liter - System, Locked
  14. `cm2` - Square Centimeter (ตารางเซนติเมตร) - System, Locked
  15. `pair` - Pair - Not system, Not locked
  16. `box` - Box - Not system, Not locked
  17. `carton` - Carton - Not system, Not locked
  18. `dozen` - Dozen - Not system, Not locked
  19. `gross` - Gross - Not system, Not locked
  20. `ream` - Ream - Not system, Not locked
- **Notes:**
  - System units (`is_system=1`) are protected from deletion
  - Locked units (`locked=1`) cannot be modified
  - Idempotent insert based on `code`

##### 5. Canonical Work Centers (11 work centers - Task 15.1)
- **Table:** `work_center`
- **Source:** From template DB (`bgerp_t_maison_atelier.work_center`) + Task 15.1
- **Count:** 11 work centers (was 10, now 11 with PRESS)
- **Format:** `[code, name, description, headcount, work_hours_per_day, is_active, sort_order, is_system, locked]`
- **Work Centers:**
  1. `CUT` - Cutting (headcount=1, hours=8.00, sort=10, system=1, locked=1)
  2. `SKIV` - Skiving (Trim & Skiving Leather) (headcount=1, hours=8.00, sort=20, system=1, locked=1)
  3. `EDG` - Edging (Edge finish & polishing) (headcount=1, hours=8.00, sort=30, system=1, locked=1)
  4. `PRESS` - Logo Press / Hot Stamp (Task 15.1: Press Logo / Foil / Emboss operations) (headcount=1, hours=8.00, sort=35, system=1, locked=1)
  5. `GLUE` - Gluing (headcount=1, hours=8.00, sort=40, system=1, locked=1)
  6. `ASSEMBLY` - Assembly (Final assembly bench) (headcount=1, hours=8.00, sort=50, system=1, locked=1)
  7. `SEW` - Sewing (headcount=1, hours=8.00, sort=60, system=1, locked=1)
  8. `HW` - Hardware (Hardware, ZIP, Screw) (headcount=1, hours=8.00, sort=70, system=1, locked=1)
  9. `PACK` - Packing (headcount=1, hours=8.00, sort=80, system=1, locked=1)
  10. `QC_INITIAL` - QC Initial (Initial quality control) (headcount=1, hours=8.00, sort=90, system=1, locked=1)
  11. `QC_FINAL` - QC Final (Final quality control) (headcount=1, hours=8.00, sort=100, system=1, locked=1)
- **Notes:**
  - System work centers (`is_system=1`) are protected from deletion
  - Locked work centers (`locked=1`) cannot be modified
  - Idempotent insert based on `code`
  - **Task 15.1:** PRESS work center added for Logo Press / Hot Stamp / Emboss operations

##### 6. Work Center Behaviors (12 behaviors - Task 15.9, 15.1)
- **Table:** `work_center_behavior`
- **Source:** From template DB + Task 15.1
- **Count:** 12 behaviors (was 11, now 12 with EMBOSS)
- **Format:** `[code, name, description, is_hatthasilpa_supported, is_classic_supported, execution_mode, time_tracking_mode, requires_quantity_input, allows_component_binding, allows_defect_capture, supports_multiple_passes, ui_template_code, default_expected_duration, is_active, is_system, locked]`
- **Behaviors:**
  1. `CUT` - Cutting (BATCH mode, PER_BATCH time tracking, 1800s duration, system=1, locked=1)
  2. `EDGE` - Edge Paint (MIXED mode, PER_BATCH time tracking, 900s duration, system=1, locked=1)
  3. `STITCH` - Stitching (SINGLE mode, PER_PIECE time tracking, 3600s duration, system=1, locked=1)
  4. `QC_FINAL` - Final Quality Control (SINGLE mode, PER_PIECE time tracking, 300s duration, system=1, locked=1)
  5. `HARDWARE_ASSEMBLY` - Hardware Assembly (SINGLE mode, PER_PIECE time tracking, 1200s duration, system=1, locked=1)
  6. `QC_REPAIR` - QC Repair (SINGLE mode, PER_PIECE time tracking, 180s duration, system=1, locked=1)
  7. `QC_SINGLE` - QC Single (SINGLE mode, PER_PIECE time tracking, 180s duration, system=1, locked=1)
  8. `SKIVE` - Skiving (SINGLE mode, PER_PIECE time tracking, 1800s duration, system=1, locked=1)
  9. `GLUE` - Gluing (SINGLE mode, PER_PIECE time tracking, 600s duration, system=1, locked=1)
  10. `ASSEMBLY` - Assembly (SINGLE mode, PER_PIECE time tracking, 2400s duration, system=1, locked=1)
  11. `PACK` - Packing (SINGLE mode, PER_PIECE time tracking, 300s duration, system=1, locked=1)
  12. `QC_INITIAL` - QC Initial (SINGLE mode, PER_PIECE time tracking, 180s duration, system=1, locked=1)
  13. `EMBOSS` - Emboss (Task 15.1: Logo / Foil / Emboss hot stamping, SINGLE mode, PER_PIECE time tracking, 1200s duration, system=1, locked=1)
- **Notes:**
  - System behaviors (`is_system=1`) are protected from deletion
  - Locked behaviors (`locked=1`) cannot be modified
  - Idempotent insert based on `code`
  - **Task 15.1:** EMBOSS behavior added for PRESS work center

##### 7. Work Center → Behavior Mapping (11 mappings - Task 15.9, 15.1)
- **Table:** `work_center_behavior_map`
- **Source:** Canonical mapping from template DB + Task 15.1
- **Count:** 11 mappings (was 10, now 11 with PRESS → EMBOSS)
- **Mappings:**
  1. `CUT` → `CUT`
  2. `SKIV` → `SKIVE`
  3. `EDG` → `EDGE`
  4. `PRESS` → `EMBOSS` (Task 15.1)
  5. `GLUE` → `GLUE`
  6. `ASSEMBLY` → `ASSEMBLY`
  7. `SEW` → `STITCH`
  8. `HW` → `HARDWARE_ASSEMBLY`
  9. `PACK` → `PACK`
  10. `QC_INITIAL` → `QC_INITIAL`
  11. `QC_FINAL` → `QC_FINAL`
- **Notes:**
  - Canonical mappings for system work centers
  - Idempotent insert/update based on `id_work_center`
  - **Task 15.1:** PRESS → EMBOSS mapping added

##### 8. Execution Mode Registry & Canonical Mappings (Task 16)
- **Purpose:** Define valid execution modes and canonical behavior-mode mappings
- **Valid Execution Modes:**
  - `BATCH` - Batch processing mode
  - `HAT_SINGLE` - Hatthasilpa single piece mode
  - `CLASSIC_SCAN` - Classic scan-based mode
  - `QC_SINGLE` - QC single piece mode
- **Canonical Behavior → Mode Mappings:**
  - `CUT` → `BATCH`
  - `EDGE` → `BATCH`
  - `STITCH` → `HAT_SINGLE`
  - `QC_FINAL` → `QC_SINGLE`
  - `QC_SINGLE` → `QC_SINGLE`
  - `HARDWARE_ASSEMBLY` → `BATCH`
  - `QC_REPAIR` → `QC_SINGLE`
  - `EMBOSS` → `HAT_SINGLE` (Task 15.1)
- **Implementation:**
  - Managed by `BGERP\Dag\NodeTypeRegistry` class
  - Used for validation and auto-resolution in `dag_routing_api.php`
  - NodeType derivation: `{behavior_code}:{execution_mode}`

##### 9. Machine Seeds (Task 18)
- **Table:** `machine`
- **Source:** Default system machines for key work centers
- **Count:** 3 default machines (optional, can be extended)
- **Format:** `[machine_code, machine_name, work_center_code, cycle_time_seconds, batch_capacity, concurrency_limit, is_system, is_active]`
- **Machines:**
  1. `CUT_MACHINE_001` - Cutting Machine 1 (work_center: CUT, cycle_time: 300s, batch_capacity: 1, concurrency: 1, system=1, active=1)
  2. `EDG_MACHINE_001` - Edging Machine 1 (work_center: EDG, cycle_time: 180s, batch_capacity: 1, concurrency: 1, system=1, active=1)
  3. `SEW_MACHINE_001` - Sewing Machine 1 (work_center: SEW, cycle_time: 600s, batch_capacity: 1, concurrency: 1, system=1, active=1)
- **Notes:**
  - System machines (`is_system=1`) are protected from deletion
  - Machines can be extended per tenant
  - Used for machine-aware routing (Task 18)
  - Default `machine_binding_mode = NONE` for existing nodes

#### Section 2: Sample Data (OPTIONAL)

**Skip if:** `SKIP_SAMPLE_DATA=true` environment variable set

##### 1. Sample UoM (3 additional units)
- **Units:**
  - `dozen` - Dozen (โหล)
  - `gross` - Gross (โกรส)
  - `ream` - Ream (รีม)

##### 2. Sample Product Categories (4 categories)
- **Table:** `product_category`
- **Categories:**
  - `BAGS` - Bags (กระเป๋า)
  - `WALLETS` - Wallets (กระเป๋าสตางค์)
  - `BELTS` - Belts (เข็มขัด)
  - `ACCESSORIES` - Accessories (อุปกรณ์เสริม)

##### 3. Sample Warehouses & Locations
- **Table:** `warehouse`, `warehouse_location`
- **Warehouses:**
  - `MAIN` - Main Warehouse
    - Locations: `RAW` (Raw Materials), `WIP` (Work In Progress), `FG` (Finished Goods), `PKG` (Packaging Area), `STK` (Finished Stock), `QA` (QC/QA Area), `RET` (Returns), `SCRAP` (Scrap)
  - `STORE` - Retail Store
    - Locations: `DISPLAY` (Display Area), `BACK` (Back Stock)

##### 4. Sample Products (5 products)
- **Table:** `product`
- **Products:**
  - `BV-TOTE-001` - Classic Leather Tote (Category: BAGS)
  - `BV-SATCH-001` - Mini Satchel (Category: BAGS)
  - `BV-CLUTCH-001` - Evening Clutch (Category: BAGS)
  - `BV-WALLET-001` - Bifold Wallet (Category: WALLETS)
  - `BV-CARD-001` - Card Holder (Category: WALLETS)

##### 5. Sample Materials (Stock Items) (9 materials)
- **Table:** `stock_item` (legacy) / `material` (new)
- **Leather:**
  - `LEA-NAT-001` - Natural Veg-Tan Leather (sqft, lot-tracked)
  - `LEA-BLK-001` - Black Calfskin (sqft, lot-tracked)
  - `LEA-BRN-001` - Brown Nubuck (sqft, lot-tracked)
  - `LEA-NAV-001` - Navy Blue Saffiano (sqft, lot-tracked)
- **Thread:**
  - `THR-POL-BLK` - Black Polyester Thread (m, not lot-tracked)
  - `THR-POL-WHT` - White Polyester Thread (m, not lot-tracked)
  - `THR-POL-BRN` - Brown Polyester Thread (m, not lot-tracked)
- **Hardware:**
  - `HDW-SNAP-10MM` - 10mm Snap Button - Brass (pcs, not lot-tracked)
  - `HDW-BUCK-25MM` - 25mm Belt Buckle - Silver (pcs, not lot-tracked)
  - `HDW-ZIP-20CM` - 20cm Metal Zipper - Black (pcs, not lot-tracked)
  - `HDW-RING-25MM` - 25mm D-Ring - Brass (pcs, not lot-tracked)
- **Supplies:**
  - `SUP-EDGE-BLK` - Black Edge Paint (roll, lot-tracked)
  - `SUP-GLUE-001` - Leather Adhesive (roll, not lot-tracked)

---

### database/tenant_migrations/2025_12_align_master_data_schema.php
- **Description:** Align master data schema (UoM and Work Centers)
- **Purpose:** Add `code` columns and backfill data
- **Tables Modified:**
  - `unit_of_measure`: Add `code` column (if missing)
  - `work_center`: Add `code` column (if missing)
- **Notes:**
  - Backfills `code` from `name` if missing
  - Ensures canonical codes match seed data

---

## Permission Seed Files (Archive)

### database/seed_default_permissions.php
- **Description:** Reference file for default permissions per role
- **Purpose:** Defines ideal permission set for each role
- **Roles Defined:**
  - `owner`: Full access (bypasses all permission checks)
  - `admin`: System Administrator (50+ permissions)
  - `production_manager`: Production Manager (33 permissions)
  - `planner`: Production Planner (16 permissions)
  - `production_operator`: Production Operator (8 permissions)
  - `quality_manager`: Quality Control Manager (14 permissions)
  - `qc_lead`: QC Lead (9 permissions)
  - `inventory_manager`: Inventory Manager (27 permissions)
  - `warehouse_manager`: Warehouse Manager (30+ permissions)
  - `warehouse`: Warehouse Staff (10+ permissions)
  - `sales_manager`: Sales Manager (15+ permissions)
  - `sales`: Sales Representative (10+ permissions)
  - `sales_bv`: Sales (Bellavier Brand) (10+ permissions, `brand.scope.bv`)
  - `sales_oem`: Sales (OEM) (10+ permissions, `brand.scope.oem`)
  - `purchaser`: Purchasing Officer (15+ permissions)
  - `finance`: Finance Manager (10+ permissions)
  - `cost_accountant`: Cost Accountant (8+ permissions)
  - `finance_clerk`: Finance Clerk (5+ permissions)
  - `operations`: Operations Staff (15+ permissions)
  - `artisan_operator`: Artisan/Craftsman (6 permissions)
  - `auditor`: Internal Auditor (25+ permissions)
  - `auditor_readonly`: External Auditor (25+ permissions, read-only)
  - `viewer`: Read-Only Viewer (4 permissions)
- **Notes:**
  - This is a reference file (not executed automatically)
  - Use as template for resetting role permissions
  - All permissions defined with descriptions

---

## Feature Flag Migrations

### database/tenant_migrations/archive/2025_11_consolidated/2025_11_feature_flags.php
- **Description:** Feature flags system initialization
- **Tables Created:**
  - `feature_flag`: Global feature flag definitions
  - `feature_flag_scope`: Tenant-specific feature flag settings
- **Flags:**
  - `FF_CLASSIC_MODE`: Enable Classic production mode
  - `FF_CLASSIC_SHADOW_RUN`: Shadow run mode for Classic
  - (Additional flags may exist)
- **Notes:**
  - Feature flags control system behavior per tenant
  - Managed via `FeatureFlagService` and `admin_feature_flags_api.php`

---

## Permission Migration Files (Archive)

All permission migrations add new permissions to existing tenant databases:

### Archive Files:
- `2025_11_phase75_permissions.php`: Phase 7.5 permissions
- `2025_11_product_graph_binding_permissions.php`: Product-Graph Binding permissions
- `2025_11_trace_permissions.php`: Traceability permissions
- `2025_12_dag_supervisor_sessions_permission.php`: DAG Supervisor Sessions permission
- `2025_12_component_override_ui_permission.php`: Component Override UI permission
- `2025_12_component_serial_permissions.php`: Component Serial permissions
- `2025_12_component_binding_permissions.php`: Component Binding permissions
- `2025_12_leather_grn_permission.php`: Leather GRN permission
- `2025_12_leather_sheet_usage_permissions.php`: Leather Sheet Usage permissions
- `2025_12_leather_cut_bom_permissions.php`: Leather Cut BOM permissions

**Format:** All use `migration_insert_if_not_exists()` to add permissions idempotently

---

## Work Center & UOM Migration Files (Archive)

### Archive Files:
- `2025_12_wc_uom_add_code_columns.php`: Add `code` columns to `work_center` and `unit_of_measure`
- `2025_12_wc_uom_backfill_codes.php`: Backfill codes from names
- `2025_12_fix_null_wc_uom_codes.php`: Fix NULL codes
- `2025_12_drop_wc_uom_id_columns.php`: Drop old `id_work_center`/`id_unit` columns
- `2025_12_work_center_behavior.php`: Add work center behavior configuration
- `2025_12_work_center_behavior_map.php`: Add work center behavior mapping

**Purpose:** Migration from ID-based references to code-based references

---

## Seed Data Summary

### Essential Data (Always Seeded)
- **Permissions:** 89 permissions
- **Roles:** 10 tenant roles
- **Role-Permission Mappings:** 370+ mappings
- **UoM:** 20 universal units (system + locked)
- **Work Centers:** 11 canonical work centers (system + locked) - Task 15.1: Added PRESS
- **Work Center Behaviors:** 13 behaviors (system + locked) - Task 15.1: Added EMBOSS
- **Work Center → Behavior Mappings:** 11 canonical mappings - Task 15.1: Added PRESS → EMBOSS
- **Execution Modes:** 4 valid modes (BATCH, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE) - Task 16
- **Canonical Behavior-Mode Mappings:** 8 mappings - Task 16, Task 15.1: Added EMBOSS → HAT_SINGLE
- **Machines:** 3 default machines (optional) - Task 18

### Sample Data (Optional)
- **UoM:** 3 additional units
- **Categories:** 4 product categories
- **Warehouses:** 2 warehouses with 10 locations
- **Products:** 5 sample products
- **Materials:** 9 sample materials (leather, thread, hardware, supplies)

### Feature Flags
- Managed per-tenant via `feature_flag` and `feature_flag_scope` tables
- Common flags: `FF_CLASSIC_MODE`, `FF_CLASSIC_SHADOW_RUN`

---

## Migration Helpers

All migrations use helpers from `database/tools/migration_helpers.php`:
- `migration_create_table_if_missing()`: Create table if not exists
- `migration_insert_if_not_exists()`: Insert record if not exists
- `migration_add_column_if_missing()`: Add column if not exists
- `migration_add_index_if_missing()`: Add index if not exists
- `migration_fetch_value()`: Fetch single value from query
- All helpers are **idempotent** (safe to run multiple times)

---

## Seed Data Sources

- **Primary Source:** `bgerp_t_maison_atelier` (template/production tenant)
- **UoM Data:** From `bgerp_t_maison_atelier.unit_of_measure`
- **Work Center Data:** From `bgerp_t_maison_atelier.work_center`
- **Permission Data:** From `bgerp_t_maison_atelier.permission`
- **Role Data:** From `bgerp_t_maison_atelier.tenant_role`
- **Role-Permission Data:** From `bgerp_t_maison_atelier.tenant_role_permission`

---

## Running Migrations

### Manual Execution
```bash
# Run specific migration
php source/bootstrap_migrations.php --tenant=maison_atelier

# Run all migrations for all tenants
php source/bootstrap_migrations.php --all-tenants
```

### Automatic Execution
- Migrations run automatically on first API access (if enabled)
- Controlled by `AUTO_MIGRATIONS_ENABLED` in `config.php`

### Verification
```sql
-- Check migration status
SELECT * FROM tenant_schema_migrations 
WHERE version LIKE '%seed%' 
ORDER BY applied_at DESC;

-- Check seeded permissions
SELECT COUNT(*) FROM permission;

-- Check seeded roles
SELECT COUNT(*) FROM tenant_role;

-- Check seeded UoM
SELECT COUNT(*) FROM unit_of_measure WHERE is_system = 1;

-- Check seeded work centers
SELECT COUNT(*) FROM work_center WHERE is_system = 1;
```


# Bellavier Group ERP / Platform Overview

## Purpose & Vision
- Provide a multi-tenant ERP tailored for leather goods manufacturers (Hatthasilpa & Classic production lines)
- Separate **Platform Owner** governance (tenant provisioning, support) from **Tenant Operators** (day-to-day production)
- Enable small teams of artisans to work with minimal IT friction: large touch-friendly UI, kiosk mode roadmap, localized language
- Support traceability from raw material lots → production orders → QC → inventory & financial impact

## High-Level Architecture
- **Core Platform (bellavier_group_erp core DB)**
  - Accounts, organizations, permissions, platform roles
  - Tenant registry + provisioning utilities (`source/utils/provision.php`)
  - Platform console UI (hidden for tenant users)
- **Tenant Databases (per organization)**
  - Provisioned via migrations (`database/tenant_migrations/*`)
  - Contain operational tables (materials, inventory, MO, Hatthasilpa enhancements)
- **Runtime Separation**
  - `resolve_current_org()` selects DB connection per session
  - Permissions checked via `permission_allow_code()` for tenant scope and `platform_has_permission()` for platform scope

```
+-------------+        +-----------------+
| Platform DB |<-----> | Application PHP |
+-------------+        +-----------------+
       ^                       |
       | tenant provisioning   | runtime per-session
       v                       v
+-------------------+   +-------------------+
| Tenant DB (org A) |   | Tenant DB (org B) |
+-------------------+   +-------------------+
```

## Key Modules (Current State)
| Area | Description | Status |
|------|-------------|--------|
| Authentication & Org Switch | Multi-tenant login, org dropdown, session isolation | ✅ stable |
| User & Role Management | Tenant scoped (Owner/Admin etc.), invitations, platform admin separation | ✅ stable |
| Inventory (Stock, Locations, Lots) | CRUD for materials, warehouses, lot tracking tables | ✅ stable |
| Goods Movements (GRN/Issue/Transfer/Adjust) | Auto-refresh DataTables, per-tenant DB writes | ✅ stable |
| Manufacturing Orders (MO) | Create MO, track status, permission-based workflow, auto status from tickets | ✅ stable |
| **Job Ticket / WIP** ✨ | Full CRUD, WIP logs, tasks, QR codes, **task assignment**, **dependencies**, **auto-progress** | ✅ stable |
| **Operator Sessions** 🆕 | Individual operator tracking for concurrent work, pause time analytics | ✅ stable |
| **Production Schedule** 🆕 | Calendar view, drag-drop, auto-arrange, conflict detection, capacity chart | ✅ stable |
| **QC Fail & Rework** 🆕 | Attachments (photo/video/PDF), close/reopen workflow, mobile camera | ✅ stable |
| **BOM Management** 🆕 | Multi-level BOM, cost roll-up, availability check, tree view, compare, export | ✅ stable |
| **Routing** 🆕 | Production steps, standard times, sequence management, auto-increment | ✅ stable |
| Dashboard | Hatthasilpa-specific KPIs with real-time job ticket metrics, sample data generation | ✅ stable |
| Purchase RFQ | New module for material RFQ management | ✅ beta |
| **Platform Tools** 🆕 | Migration Wizard, Health Check, Platform Dashboard for super admins | ✅ stable |
| **PWA Scan Station V2** ⭐ | **100% Offline-capable** - Offline ticket lookup, IndexedDB cache, auto-refresh, 28 edge cases | ✅ **production** |
| **Exceptions Board** 🆕 | Real-time production issue monitoring (stuck jobs, QC fails, shortages) | ✅ stable |
| Permission System | RBAC with frontend integration (window.APP_PERMISSIONS) | ✅ stable |
| **DAG Production System** 🚀 | **Planning Complete** - Graph-based parallel production (Q1 2026) | 📋 planned |

## Data Model Highlights
### Core DB (shared)
- `account`, `account_org`, `organization`, `permission`, `tenant_role_template` etc.
- Platform-only tables: `platform_user`, `platform_role`, `platform_permission`
- Core migrations: `database/migrations/0001_core_bootstrap.php`

### Tenant DB (per org)
- Base schema: `database/tenant_migrations/0001_seed_core.php`
  - `unit_of_measure`, `product_category`, `product`, `warehouse`, `warehouse_location`
- Work centers: `0002_seed_work_centers.php`, `0003_add_work_center_status.php`
  - `work_center`, status tracking for production stations
- Other modules: `purchase_rfq`, `supplier_scorecard`, `atelier_job_ticket`, `atelier_wip_log`

### Relationships (tenant)
- `material_lot` ↔ `stock_item`, `unit_of_measure`
- `mo` references `product`, `unit_of_measure`
- `atelier_job_ticket` references `mo` (implemented)
- `atelier_job_task` references `atelier_job_ticket`, supports assignment, dependencies, auto-progress
- `atelier_wip_log` references `atelier_job_ticket`, tracks operator and quantity
- `atelier_task_operator_session` 🆕 references `atelier_job_task`, tracks individual operator work sessions
- QC tables (`qc_inspection`, `qc_inspection_item`) reference job tickets / lots
- `qc_fail_attachment` 🆕 references `qc_fail_event` for photos/videos/documents

## Current Dashboard Data Flow
- KPIs currently sourced from MO and job ticket data
- Snapshot (planned/in-progress/QC/completed) derived from `atelier_job_ticket` and `mo` status
- Charts: pulling counts per day/status/source; front-end builds ApexCharts from backend JSON data
- Dashboard uses real-time data from job tickets and WIP logs

## Recent Milestones
1. **Platform/Tenant Separation**
   - Tenancy-aware permissions, platform console toggles, migrations for platform roles
2. **Inventory & Lot Tracking**
   - Material lot tables, RFQ module, supplier scorecards scaffold
3. **Production Data**
   - MO table schema in tenant migrations, MO creation UI adjustments, default UoM fallback logic
4. **Dashboard Refactor**
   - Removed legacy orderlist widgets, introduced Hatthasilpa KPI cards, backend JSON endpoints simplified
5. **QC Fail & Rework Kick-off (Sprint 4)**
   - Web UI skeleton with filters/off-canvas ready, core API actions (`list`, `detail`, `create_fail`, `create_task`) implemented with i18n support
6. **Transactions Pages Refactor (GRN/Adjust/Issue/Transfer)**
   - Centralized shared lookups to `source/refs.php` (warehouses, locations, materials, uom_by_sku)
   - Updated all Transaction JS files to call `refs.php` for consistency
   - Removed duplicate lookup cases from individual endpoints (`grn.php`, `adjust.php`, `issue.php`, `transfer.php`)
   - Transaction endpoints now focus solely on `list` and `create` actions
7. **Master Data UI Enhancements**
   - Products: Added lightbox (GLightbox) for images in DataTable and asset modal, fixed category/UoM pre-selection in edit modal
   - Materials: Added lightbox for images, full i18n integration, fixed edit functionality and asset uploads
   - UoM: Added edit button, full i18n, Toast notifications for CRUD actions
   - Warehouses/Locations: Added edit buttons, CRUD workflows completed
8. **Job Ticket & WIP Log Module**
   - Complete CRUD for WIP logs with Operator field (Select2 with tags mode for historical + current users)
   - QR code generation for tickets (using `qrcode.js`)
   - MO summary integration in Job Ticket view
   - Backend schema enforcement (`ensure_wip_log_schema()`)
   - Robust i18n support for all actions/toasts/confirmations
9. **Inventory Transaction Code Refactoring (October 2025)**
   - Created centralized `InventoryHelper` class (`source/utils/InventoryHelper.php`) to eliminate code duplication
   - Refactored all transaction endpoints (GRN, Issue, Adjust, Transfer) to use helper methods
   - **Security improvements:** All UoM queries now use prepared statements (eliminated `real_escape_string` risks)
   - **Race condition fix:** Transaction codes use microsecond resolution to prevent collisions
   - **Consistency:** Standardized JSON responses and error handling across all endpoints
   - **Maintainability:** ~120 lines of duplicate logic removed, code reduction of 16.5% in business logic
   - **Testing:** Added test suite (`tools/test_refactored_inventory.php`) for validation
   - Backward compatible: maintains same API contracts, no frontend changes required
10. **Job Ticket Module Production-Ready Enhancements (October 2025)**
   - **MO Status Validation:** Block ticket creation from cancelled/completed MOs, warn when editing tickets of completed MOs
   - **Permission System Frontend Integration:** Added `window.APP_PERMISSIONS` injection, `get_user_permission_codes()` helper function
   - **MO Action Buttons:** Permission-based and status-aware button display (Plan/Start/Stop/Complete/Cancel only show when applicable)
   - **DataTable UI Fixes:** Removed `dom: 'lfrtip'` causing layout issues, removed conflicting inline CSS, standardized with theme
   - **Tasks/Logs Offcanvas Fix:** Fixed currentTicketId tracking to show correct Tasks/WIP Logs when switching between tickets
   - **Number Formatting:** Auto-remove decimal places for integers (100.0 → 100), preserve decimals when needed (100.5)
   - **MO Remaining Calculation Fix:** Corrected formula from `mo_qty - other` to `mo_qty - total` (other + current)
   - **JobTicketStatusService:** Auto-update MO status based on ticket/task states (released → in_progress → qc)
   - **Testing:** All 61 backend tests passing, no regression
11. **Migration System Refactor**
   - Centralized migration helpers in `database/tools/migration_helpers.php`
   - Support for both SQL and PHP migrations (`.sql` and `.php` files)
   - Automatic migration execution on first load via `AUTO_MIGRATIONS_ENABLED` config
   - Core migrations (`database/migrations/`) and tenant migrations (`database/tenant_migrations/`) run separately
   - Version tracking in `schema_migrations` (core) and `tenant_schema_migrations` (tenant)
   - Transaction-safe migration execution with rollback on failure
   - CLI and web-based migration runners available
   - **Fixed**: `run_tenant_migrations_for()` now runs both PHP and SQL migrations for all active tenants
10. **Stock Ledger Enhancements**
   - Added `lot_code` column to `stock_ledger` table for lot tracking across all transaction types
   - Migration: `0013_add_stock_ledger_lot_code.php` applied to all tenant databases
   - GRN/Adjust/Issue/Transfer now support lot tracking uniformly
   - Fixed GRN to use consistent `stock_ledger` schema (txn_code, txn_type, txn_date, reference)
11. **PHP 8.2 Upgrade & Quick Wins (October 2025)**
   - **PHP Version Upgrade:** MAMP upgraded from PHP 7.4.33 → 8.2.0
   - **OpenAPI Specification:** Complete Swagger documentation for all API endpoints
   - **Exceptions Board:** Real-time monitoring dashboard for production issues (stuck jobs, QC fails, rework loops, material shortages)
   - **PWA Scan Station V2:** Offline-first mobile app for WIP logging with quick/detail modes, task scanning, localStorage persistence
   - **Cache Fix:** Resolved PHP 8.2 OPcache aggressive caching issues causing tenant switching problems
   - **File Structure Refactor:** Platform pages refactored to follow standard structure (page/*.php, views/*.php, assets/javascripts/*, separate CSS/JS files)
12. **Platform Admin Tools (October 2025)**
   - **Migration Wizard:** UI tool for platform super admins to test and deploy tenant migrations
   - **Health Check System:** 30-test diagnostic dashboard (Core System, Database, Permissions, Migrations, Tenant Isolation, File System)
   - **Platform Dashboard:** Overview with tenant count, user count, migrations, health score, system status
   - **Platform Super Admin Full Access:** Can access all tenants without explicit account_org entries
13. **BOM & Routing Management (October 2025)**
   - **BOM CRUD:** Complete Bill of Materials management with multi-level BOM support
   - **BOM Features:** Cost roll-up, material availability check, BOM tree visualization, version comparison, export (PDF/Excel)
   - **Routing:** Production routing with steps, standard times, yield percentages, sequence management
   - **Auto-increment:** Smart sequence numbering for routing steps (0 = auto)
   - **Migrations:** `2025_10_bom_cost_system.php`, `2025_10_multilevel_bom.php` deployed
14. **Global Helper Functions (October 2025)**
   - **JavaScript:** `formatNumber(value, maxDecimals)` in `global_script.js` - format numbers by removing unnecessary decimals
   - **PHP:** `format_number($value, $maxDecimals)` in `global_function.php` - PHP equivalent for server-side formatting
   - **Refactored:** Removed duplicate formatNumber implementations from `bom.js`, `job_ticket.js`, `bom.php`
   - **Usage:** Available globally for all pages (BOM quantities, Job Ticket quantities, exports, reports)
   - **Documentation:** Complete guide in `docs/GLOBAL_HELPERS.md`

## Code Quality & Best Practices

### **Refactored Code (October 2025)**

**InventoryHelper Class** (`source/utils/InventoryHelper.php`)
- Centralizes common inventory transaction logic
- Provides reusable methods for all transaction types
- Ensures consistent validation and error handling
- Example usage:
```php
$helper = new InventoryHelper($tenantDb);

// Resolve UoM from SKU
$id_uom = $helper->resolveUom($sku, $providedUom);

// Convert quantity to base UoM
$converted = $helper->convertToBaseUom($sku, $qty, $fromUom);

// Generate unique transaction code (microsecond resolution)
$txn_code = $helper->generateTxnCode('GRN');

// Validate input data
$validation = $helper->validateTransactionInput($_POST);
if (!$validation['valid']) {
    InventoryHelper::jsonResponse(false, $validation['error']);
}

// Standard JSON response
InventoryHelper::jsonResponse(true, $data, 200);
```

### **Security Principles**
1. ✅ **Always use prepared statements** - No `real_escape_string` or string concatenation in queries
2. ✅ **Permission checks** - Every endpoint validates `permission_allow_code()` before operations
3. ✅ **Input validation** - Use helper methods or explicit type casting
4. ✅ **Timezone consistency** - Bangkok timezone set globally in `config.php` and per-connection
5. ✅ **Transaction safety** - Use `begin_transaction()` / `commit()` / `rollback()` for multi-statement operations

### **Code Organization**
```
source/
├── utils/
│   ├── InventoryHelper.php    ← Shared inventory logic
│   ├── ssdt.php                ← Server-side DataTables query builder
│   └── refs.php                ← Centralized lookup endpoints
├── grn.php                     ← Refactored with InventoryHelper
├── issue.php                   ← Refactored with InventoryHelper
├── adjust.php                  ← Refactored with InventoryHelper
├── transfer.php                ← Refactored with InventoryHelper
├── bom.php                     ← 🆕 BOM management API
├── routing.php                 ← 🆕 Routing management API
├── global_function.php         ← 🆕 Global helper functions (format_number, etc.)
└── platform_*_api.php          ← 🆕 Platform tools (migration, health, dashboard)

assets/javascripts/
├── global_script.js            ← 🆕 Global JS helpers (formatNumber, etc.)
├── bom/bom.js                  ← 🆕 BOM frontend
├── routing/routing.js          ← 🆕 Routing frontend
└── platform/                   ← 🆕 Platform tools frontend
    ├── migration_wizard.js
    ├── health_check.js
    └── exceptions_board.js

views/
├── bom.php                     ← 🆕 BOM UI
├── routing.php                 ← 🆕 Routing UI
├── platform_*.php              ← 🆕 Platform tools UI
└── pwa_scan_v2.php             ← 🆕 PWA Scan Station V2
```

## API Endpoints (Key Patterns)
### Centralized Lookups (`source/refs.php`)
Shared reference data for dropdowns across modules:
- `GET refs.php?action=warehouses` → `{ ok: true, data: [{id_warehouse, code, name}, ...] }`
- `GET refs.php?action=locations&id_warehouse=N` → `{ ok: true, data: [{id_location, code, name}, ...] }`
- `GET refs.php?action=materials` → `{ ok: true, data: [{sku, description}, ...] }`
- `GET refs.php?action=uom_by_sku&sku=XXX` → `{ ok: true, data: {id_unit, code, name} | null }`

**Usage pattern in frontend:**
```javascript
const REFS = 'source/refs.php';
$.getJSON(REFS, { action: 'warehouses' }).done(resp => { /* populate dropdown */ });
```

### Transaction Endpoints
Each endpoint now handles only domain-specific actions:
- `source/grn.php`: `list`, `create` (Goods Receipt Note)
- `source/adjust.php`: `list`, `create` (Stock Adjustment)
- `source/issue.php`: `list`, `create` (Issue/Return)
- `source/transfer.php`: `list`, `create` (Stock Transfer)

All lookups delegated to `refs.php` for consistency.

## Recently Completed (October 30, 2025)

### **Production Schedule** ✅
- ✅ Calendar-based MO/Job Ticket scheduling with FullCalendar
- ✅ Drag-and-drop event resizing and moving
- ✅ Auto-arrange algorithm for optimal scheduling
- ✅ Conflict detection and warnings
- ✅ Find gaps API for available time slots
- ✅ Capacity chart (Chart.js) with real-time updates

### **Job Ticket Task Management** ✅
- ✅ Task assignment to specific users
- ✅ Task dependencies (predecessor/successor)
- ✅ Auto-calculated progress from WIP logs
- ✅ Status workflow with validation (Start, Pause, Resume, Complete)
- ✅ Multi-tenant support

### **QC Fail & Rework** ✅
- ✅ Attachment uploads (photos, videos, PDFs)
- ✅ Close/reopen workflow
- ✅ Mobile camera integration
- ✅ Image preview and management

### **Operator Session System** ✅ **[MAJOR ENHANCEMENT]**
- ✅ Individual operator session tracking for concurrent work
- ✅ Smart status calculation based on active sessions
- ✅ Accurate progress from multiple operators
- ✅ Per-operator pause time tracking
- ✅ Performance analytics capabilities

### **PWA v2 Alignment** ✅
- ✅ Event types aligned with Mobile WIP (start, hold, resume, fail, complete)
- ✅ Removed non-standard events (progress, qc_check)
- ✅ Full consistency across all WIP logging systems

## Pending / Roadmap
- **Supplier Scorecard UI** – surface metrics from `atelier_supplier_score`, auto-scoring based on delivery/quality
- **UX Enhancements** – kiosk mode for shop-floor, large touch-friendly buttons, voice commands (future)
- **Automated Testing** – PHPUnit for backend, Playwright for frontend E2E tests
- **Performance Optimization** – database indexing, query optimization, caching strategies
- **QC Dashboard** – metrics and reports for fail events

## Technical Stack Notes
- PHP (MAMP) with procedural + class mix; jQuery + ApexCharts on frontend
- Auto-refresh utility (`assets/javascripts/datatables/auto_refresh.js`) used across modules
- DataTables for list pages; server-side scripts in `source/*.php`
- Provisioning script `source/utils/provision.php` manages tenant DB migrations
- Session-based org context (`$_SESSION['current_org_code']`); no multi-org concurrency per session
- Image lightbox: GLightbox integrated for Products and Materials modules
- Internationalization: `lang/en.php` and `lang/th.php` with common keys for consistency
- Select2 used for enhanced dropdowns with tags mode and custom options

## Deployment & Environment
- Current environment: macOS (MAMP), **PHP 8.2.0** (upgraded from 7.4.33)
- Databases: MySQL (per tenant + core)
- No build pipeline; frontend assets managed manually (jQuery, ApexCharts, DataTables, Select2, GLightbox, jsTree)
- **Cache Management:** PHP OPcache configured for development (disabled or low revalidation frequency)
- **Browser Cache Busting:** Automatic ?v=filemtime() for local CSS/JS files

### Migration Management
- **Auto-migration**: Set `AUTO_MIGRATIONS_ENABLED = true` in `config.php` for automatic migration on first load
- **Manual migration commands**:
  - Core migrations: `php source/bootstrap_migrations.php` (runs all core migrations)
  - Tenant migrations: `php source/bootstrap_migrations.php --tenant=<org_code>` (runs tenant migrations for specific org)
  - All tenants: migrations auto-run for all tenants via `run_tenant_migrations_for_all()` when enabled
- **Web-based runner**: `source/run_tenant_migrations.php` (JSON API for current tenant)
- **Migration types**: Both `.sql` (multi-query SQL) and `.php` (programmatic) files supported
- **Version tracking**: Migrations tracked in `schema_migrations` (core) and `tenant_schema_migrations` (tenant)
- **Important**: Tenant migrations run in sequential order (0001, 0002, etc.) - use sequential numbering for new migrations
- **Current tenant migrations**: 
  - `0001_init_tenant_schema.php` - Complete unified tenant schema (ready for production deployment)
  - Includes: core tables, master data, products/materials, manufacturing (BOM/routing/MO/job tickets/WIP), inventory with lot tracking

## Testing & Data Integrity
- Manual testing via UI and SQL queries
- Dashboard endpoints return JSON; front-end handles empty datasets gracefully
- Transaction pages tested: GRN, Adjust, Issue/Return, Transfer (all CRUD operations functional)
- Need to add automated tests (PHPUnit/Playwright planned for Sprint 5)

## Glossary
- **Platform Owner/Super Admin**: Maintains global tenants, platform roles, uses platform tools (Migration Wizard, Health Check, Platform Dashboard)
- **Tenant Owner**: Manages users, inventory, production for a specific org
- **MO (Manufacturing Order)**: Production order for finished goods
- **Job Ticket**: Planned work packet for artisans (schema + UI implemented, task management in progress)
- **WIP Log**: Work-in-progress tracking entries for job tickets (CRUD complete)
- **BOM (Bill of Materials)**: Multi-level material list with quantities, costs, and availability tracking
- **Routing**: Production process steps with standard times, sequences, and yield percentages
- **Lot**: Traceable batch of material (e.g., leather lot)
- **RFQ**: Request for Quotation for material procurement
- **refs.php**: Centralized lookup endpoint for shared reference data (warehouses, locations, materials, UoM)
- **PWA (Progressive Web App)**: Offline-first mobile application for shop floor WIP logging
- **Exceptions Board**: Real-time dashboard for monitoring production issues (stuck jobs, QC fails, shortages)

## Contact & Next Steps
- **Current Status**: PHP 8.2 deployed, Platform tools complete, BOM/Routing stable
- **Next Priorities**: Production Schedule, Job Ticket task management, Automated testing
- **Documentation**: Keep this file updated as modules evolve; document breaking changes in migration notes

## Best Practices

### **Development Standards**
1. **Global Helpers**
   - Use `formatNumber()` (JS) and `format_number()` (PHP) for number formatting
   - Available globally, no need to create local implementations
   - See `docs/GLOBAL_HELPERS.md` for usage guide

2. **API Endpoints**
   - Use `refs.php` for shared lookups in new transaction pages
   - Return consistent JSON: `{ ok: true/false, data: ..., error: ... }`
   - Always use prepared statements for SQL queries

3. **Frontend**
   - Follow i18n patterns with common keys (`common.*`, module-specific keys)
   - Implement CRUD with consistent Toast notifications and error handling
   - Add lightbox for images using GLightbox standard
   - Use standard file structure: `page/*.php`, `views/*.php`, `assets/javascripts/*/`, `assets/stylesheets/*/`

4. **Database**
   - Write PHP migrations (`.php`) instead of SQL for complex schema changes
   - Use migration helpers for adding columns (`migration_add_column_if_missing`)
   - Always check schema existence before altering tables
   - Test migrations on dev tenant before deploying to all tenants

5. **Platform Tools**
   - Use Migration Wizard UI for deploying tenant migrations (no manual SQL)
   - Run Health Check after major changes to verify system integrity
   - Platform super admins can access all tenants without explicit permissions

6. **Cache Management**
   - PHP files: Auto-cleared by disabling/reducing OPcache revalidation frequency
   - JS/CSS files: Auto cache-busted with `?v=filemtime()` in production
   - Browser cache: Use Cmd+Shift+R (hard reload) during development


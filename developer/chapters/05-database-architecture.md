# Chapter 5 — Database Architecture

**Last Updated:** January 2025  
**Purpose:** Explain database structure, migration strategy, and database operations  
**Audience:** Developers working on database operations, migrations, and data modeling

---

## Overview

The Bellavier Group ERP uses a multi-tenant database architecture with complete data isolation per organization. The system consists of a core database for platform-level data and separate tenant databases for organization-specific data.

**Key Components:**
- Core database (`bgerp`) - Platform-level data (13 tables)
- Tenant databases (`bgerp_t_{org_code}`) - Organization-specific data (122 tables)
- **Total:** 135 tables
- Migration system (PHP-based, not SQL)
- `BootstrapMigrations` helper (Task 19)

**Design Principles:**
- ✅ Complete data isolation per tenant
- ✅ No cross-tenant queries possible
- ✅ PHP-based migrations (idempotent, safe)
- ✅ Automatic tenant database creation

---

## Key Concepts

### 1. Multi-Tenant Database Design

**Core Database (`bgerp`):**
- **Purpose**: Platform-level data shared across all tenants
- **Total Tables:** 13 tables
- **Contains**:
  - User accounts (`account`, `account_group`, `account_org`)
  - Organizations (`organization`, `organization_domain`)
  - Permissions (`permission`, `platform_permission`)
  - Platform roles (`platform_role`, `platform_role_permission`, `platform_user`, `platform_user_role`)
  - System (`account_invite`, `admin_notifications`, `system_logs`)
  - Migration tracking (`schema_migrations`)

**Tenant Databases (`bgerp_t_{org_code}`):**
- **Purpose**: Organization-specific data, completely isolated
- **Total Tables:** 122 tables
- **Naming Pattern**: `bgerp_t_{org_code}` (e.g., `bgerp_t_default`, `bgerp_t_maison_atelier`)
- **Contains**:
  - Master Data (11 tables): account, organization, permission, tenant_role, product_category, uom, warehouse, etc.
  - Product & BOM (9 tables): product, bom, bom_item, bom_line, product_graph_binding, pattern, etc.
  - Material & Inventory (12 tables): material, material_lot, stock_item, inventory_transaction, leather_sheet, etc.
  - Component System (8 tables): component_master, component_serial, component_serial_binding, etc.
  - Manufacturing Orders (3 tables): mo, mo_eta_cache, mo_eta_health_log
  - Job Tickets & Tasks (5 tables): job_ticket, job_task, wip_log (soft-delete), task_operator_session, etc.
  - DAG Routing System (15 tables): routing_graph, routing_node, routing_edge, flow_token, token_event, etc.
  - Token System (10 tables): flow_token, token_event, token_work_session, node_instance, etc.
  - Work Centers & Teams (8 tables): work_center, work_center_behavior, team, team_member, etc.
  - Quality Control (5 tables): qc_inspection, qc_fail_event, qc_rework_task, etc.
  - Assignment System (5 tables): assignment_plan_job, assignment_log, assignment_decision_log, etc.
  - People Integration (6 tables): people_availability_cache, people_operator_cache, etc.
  - Production & Analytics (8 tables): production_output_daily, mv_cycle_time_analytics, etc.
  - Serial Number System (5 tables): serial_generation_log, serial_quarantine, etc.
  - Traceability (5 tables): trace_access_log, trace_export_job, trace_note, etc.
  - And more... (See PROJECT_AUDIT_REPORT.md for complete list)
  - Migration tracking (`tenant_schema_migrations`)

**Data Isolation:**
- ✅ Complete isolation: Each tenant's data is in a separate database
- ✅ No cross-tenant queries: Impossible to accidentally query another tenant's data
- ✅ Tenant resolution: Handled by bootstrap layer automatically

### 2. Table Naming Conventions

**Core Database Tables:**
- `account` - User accounts
- `organization` - Organizations/tenants
- `permission` - Permission definitions
- `platform_role` - Platform roles
- `platform_user` - Platform user mappings
- `schema_migrations` - Migration tracking

**Tenant Database Tables:**
- `atelier_*` - Atelier/Manufacturing tables
- `routing_*` - DAG routing tables
- `flow_*` - Token flow tables
- `tenant_schema_migrations` - Migration tracking

**Naming Pattern:**
- Use `snake_case` for table names
- Use `snake_case` for column names
- Prefix with module name if needed (e.g., `atelier_job_ticket`)

### 3. Soft-Delete Pattern

**Only WIP Logs Use Soft-Delete:**
- `atelier_wip_log` - Has `deleted_at` and `deleted_by` columns
- **All other tables**: Hard delete (no soft-delete)

**Soft-Delete Filter:**
```sql
-- ✅ Correct: Always filter soft-deleted records
SELECT * FROM atelier_wip_log 
WHERE id_job_task=? AND deleted_at IS NULL

-- ❌ Wrong: Missing soft-delete filter
SELECT * FROM atelier_wip_log WHERE id_job_task=?
```

**Why Only WIP Logs:**
- WIP logs are audit trail records
- Need to preserve history for compliance
- Other tables don't need soft-delete

---

## Core Components

### BootstrapMigrations

**Location:** `source/BGERP/Migration/BootstrapMigrations.php`  
**Namespace:** `BGERP\Migration`  
**Status:** ✅ Migrated to PSR-4 (Task 19)

**Purpose:**
Execute database migrations for core and tenant databases.

**Key Methods:**

#### 1. Run Core Migrations

```php
BootstrapMigrations::run_core_migrations(): void
```

**Purpose:** Execute migrations for core database.

**Usage:**
```php
use BGERP\Migration\BootstrapMigrations;

BootstrapMigrations::run_core_migrations();
```

**What It Does:**
- Scans `database/migrations/` directory
- Executes PHP migration files
- Tracks applied migrations in `schema_migrations` table
- Idempotent (safe to run multiple times)

#### 2. Run Tenant Migrations for Specific Org

```php
BootstrapMigrations::run_tenant_migrations_for(string $orgCode): void
```

**Purpose:** Execute migrations for specific tenant database.

**Usage:**
```php
use BGERP\Migration\BootstrapMigrations;

BootstrapMigrations::run_tenant_migrations_for('default');
BootstrapMigrations::run_tenant_migrations_for('maison_atelier');
```

**What It Does:**
- Connects to tenant database (`bgerp_t_{org_code}`)
- Scans `database/tenant_migrations/` directory
- Executes PHP migration files
- Tracks applied migrations in `tenant_schema_migrations` table
- Idempotent (safe to run multiple times)

#### 3. Run Tenant Migrations for All Orgs

```php
BootstrapMigrations::run_tenant_migrations_for_all(): void
```

**Purpose:** Execute migrations for all tenant databases.

**Usage:**
```php
use BGERP\Migration\BootstrapMigrations;

BootstrapMigrations::run_tenant_migrations_for_all();
```

**What It Does:**
- Finds all active organizations
- Runs migrations for each tenant database
- Handles errors gracefully (continues with next org)
- Idempotent (safe to run multiple times)

#### 4. Ensure Admin Seeded

```php
BootstrapMigrations::ensure_admin_seeded($coreDb): void
```

**Purpose:** Ensure platform admin user exists.

**Usage:**
```php
use BGERP\Migration\BootstrapMigrations;

$coreDb = core_db();
BootstrapMigrations::ensure_admin_seeded($coreDb);
```

**What It Does:**
- Checks if platform admin exists
- Creates admin user if missing
- Sets up default permissions
- Idempotent (safe to run multiple times)

### Legacy Wrapper Functions

**Location:** `source/bootstrap_migrations.php`  
**Status:** ✅ Thin wrapper (Task 19)

**Purpose:**
Backward compatibility for legacy code that uses function-style migration calls.

**Functions:**
- `run_core_migrations()` → `BootstrapMigrations::run_core_migrations()`
- `run_tenant_migrations_for($orgCode)` → `BootstrapMigrations::run_tenant_migrations_for()`
- `run_tenant_migrations_for_all()` → `BootstrapMigrations::run_tenant_migrations_for_all()`
- `ensure_admin_seeded($db)` → `BootstrapMigrations::ensure_admin_seeded()`

**Usage:**
```php
// Old way (still works)
require_once __DIR__ . '/bootstrap_migrations.php';
run_tenant_migrations_for('default');

// New way (recommended)
use BGERP\Migration\BootstrapMigrations;
BootstrapMigrations::run_tenant_migrations_for('default');
```

---

## Migration Strategy

### PHP-Based Migrations (NOT SQL)

**Why PHP, Not SQL:**
- ✅ Idempotent (safe to run multiple times)
- ✅ Can check conditions before applying
- ✅ Can use helper functions
- ✅ Can handle errors gracefully
- ✅ Can rollback if needed

**Migration File Format:**
```php
<?php
/**
 * Migration: 2025_11_description
 * Description: Add new column to table
 */
require_once __DIR__ . '/../tools/migration_helpers.php';

return function (mysqli $db): void {
    // Add column if missing
    migration_add_column_if_missing(
        $db,
        'table_name',
        'column_name',
        '`column_name` VARCHAR(100) NOT NULL DEFAULT \'\' COMMENT \'Description\''
    );
    
    // Add index if missing
    migration_add_index_if_missing(
        $db,
        'table_name',
        'idx_column_name',
        'INDEX `idx_column_name` (`column_name`)'
    );
    
    // Optimize table after index creation
    $db->query("ANALYZE TABLE `table_name`");
};
```

**Naming Convention:**
- Format: `YYYY_MM_description.php` (e.g., `2025_11_tenant_user_accounts.php`)
- **NOT** `NNNN_` format (won't appear in Migration Wizard UI)
- Use migration_run_php_migration() with 'tenant_migrations' table

**Migration Helpers:**
- `migration_add_column_if_missing()` - Add column if not exists
- `migration_add_index_if_missing()` - Add index if not exists
- `migration_create_table_if_missing()` - Create table if not exists
- `migration_insert_if_not_exists()` - Insert data if not exists
- `migration_modify_column_if_different()` - Update column definition

### Migration Tracking

**Core Database:**
- Table: `schema_migrations`
- Columns: `version` (VARCHAR), `applied_at` (DATETIME)
- Tracks: Core database migrations

**Tenant Databases:**
- Table: `tenant_schema_migrations`
- Columns: `version` (VARCHAR), `applied_at` (DATETIME)
- Tracks: Tenant database migrations

**Migration Execution:**
- Scans migration directory
- Checks if migration already applied
- Executes only unapplied migrations
- Records applied migrations in tracking table

---

## Adding New Tables Safely

### Step 1: Create Migration File

**File:** `database/tenant_migrations/YYYY_MM_table_name.php`

**Example:**
```php
<?php
require_once __DIR__ . '/../tools/migration_helpers.php';

return function (mysqli $db): void {
    migration_create_table_if_missing(
        $db,
        'new_table',
        "CREATE TABLE `new_table` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(255) NOT NULL,
            `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            INDEX `idx_name` (`name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
    );
};
```

### Step 2: Run Migration

**For Specific Tenant:**
```bash
php source/bootstrap_migrations.php --tenant=default
```

**For All Tenants:**
```bash
php source/bootstrap_migrations.php --all-tenants
```

**Via Code:**
```php
use BGERP\Migration\BootstrapMigrations;
BootstrapMigrations::run_tenant_migrations_for('default');
```

### Step 3: Verify Migration

**Check Migration Applied:**
```sql
SELECT * FROM tenant_schema_migrations 
WHERE version='YYYY_MM_table_name' 
ORDER BY applied_at DESC;
```

**Verify Table Exists:**
```sql
SHOW TABLES LIKE 'new_table';
DESCRIBE new_table;
```

### Step 4: Update Documentation

- Update `docs/DATABASE_SCHEMA_REFERENCE.md`
- Document table structure
- Document relationships
- Document indexes

---

## Tenant Onboarding → DB Creation Guide

### Step 1: Create Organization

**In Core Database:**
```sql
INSERT INTO organization (code, name, status) 
VALUES ('new_tenant', 'New Tenant Name', 1);
```

### Step 2: Create Tenant Database

**Database Name:** `bgerp_t_new_tenant`

**Create Database:**
```sql
CREATE DATABASE `bgerp_t_new_tenant` 
CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### Step 3: Run Initial Schema Migration

**Migration File:** `database/tenant_migrations/0001_init_tenant_schema.php`

**Run Migration:**
```php
use BGERP\Migration\BootstrapMigrations;
BootstrapMigrations::run_tenant_migrations_for('new_tenant');
```

**What It Does:**
- Creates all base tables
- Creates indexes
- Sets up initial structure

### Step 4: Run All Migrations

**Run All Migrations:**
```php
use BGERP\Migration\BootstrapMigrations;
BootstrapMigrations::run_tenant_migrations_for('new_tenant');
```

**What It Does:**
- Applies all migrations in order
- Creates all tables, columns, indexes
- Sets up complete schema

### Step 5: Seed Initial Data (Optional)

**Create Seed Migration:**
```php
// database/tenant_migrations/0002_seed_initial_data.php
return function (mysqli $db): void {
    // Insert initial data
    migration_insert_if_not_exists(
        $db,
        'table_name',
        ['column' => 'value'],
        "column='value'"
    );
};
```

---

## Developer Responsibilities

### When Working with Database

**MUST:**
- ✅ Use prepared statements (100% coverage)
- ✅ Use correct database connection (`$tenantDb` or `$coreDb`)
- ✅ Filter soft-deleted records (for WIP logs: `WHERE deleted_at IS NULL`)
- ✅ Use two-step fetch + merge for cross-DB queries
- ✅ Use transactions for multi-step operations
- ✅ Handle errors gracefully

**DO NOT:**
- ❌ Use raw SQL without prepared statements
- ❌ Mix tenant and core database connections
- ❌ Forget soft-delete filter (for WIP logs)
- ❌ Use cross-DB JOINs in prepared statements
- ❌ Create SQL files for migrations (use PHP)

### When Creating Migrations

**MUST:**
- ✅ Use PHP migration files (not SQL)
- ✅ Use migration helpers (idempotent functions)
- ✅ Follow naming convention (`YYYY_MM_description.php`)
- ✅ Test migration locally first
- ✅ Document migration in migration file
- ✅ Update schema documentation

**DO NOT:**
- ❌ Create SQL files (`.sql`)
- ❌ Use `NNNN_` format (use `YYYY_MM_` format)
- ❌ Skip idempotency checks
- ❌ Hardcode database names
- ❌ Forget to require migration_helpers.php

---

## Common Pitfalls

### 1. Missing Soft-Delete Filter

**Problem:**
```php
// ❌ Wrong: Includes deleted records
$stmt = $tenantDb->prepare("SELECT * FROM atelier_wip_log WHERE id_job_task=?");
```

**Solution:**
```php
// ✅ Correct: Filter soft-deleted
$stmt = $tenantDb->prepare("SELECT * FROM atelier_wip_log WHERE id_job_task=? AND deleted_at IS NULL");
```

### 2. Cross-Database JOIN

**Problem:**
```php
// ❌ Wrong: Cross-DB JOIN in prepared statement
SELECT t.*, u.name 
FROM atelier_job_task t 
LEFT JOIN bgerp.account u ON u.id_member=t.assigned_to
```

**Solution:**
```php
// ✅ Correct: Two-step fetch + merge
// (See Chapter 2 for complete example)
```

### 3. SQL Migration Files

**Problem:**
```sql
-- ❌ Wrong: SQL file
-- database/tenant_migrations/0012_add_column.sql
ALTER TABLE table_name ADD COLUMN new_column VARCHAR(100);
```

**Solution:**
```php
// ✅ Correct: PHP migration file
// database/tenant_migrations/2025_11_add_column.php
return function (mysqli $db): void {
    migration_add_column_if_missing($db, 'table_name', 'new_column', '...');
};
```

### 4. Wrong Migration Naming

**Problem:**
```php
// ❌ Wrong: NNNN_ format
// database/tenant_migrations/0012_add_column.php
```

**Solution:**
```php
// ✅ Correct: YYYY_MM_ format
// database/tenant_migrations/2025_11_add_column.php
```

---

## Examples

### Example 1: Creating a New Table

```php
<?php
// database/tenant_migrations/2025_11_custom_table.php
require_once __DIR__ . '/../tools/migration_helpers.php';

return function (mysqli $db): void {
    migration_create_table_if_missing(
        $db,
        'custom_table',
        "CREATE TABLE `custom_table` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(255) NOT NULL,
            `value` TEXT,
            `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            INDEX `idx_name` (`name`),
            INDEX `idx_created_at` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
    );
    
    // Optimize table
    $db->query("ANALYZE TABLE `custom_table`");
};
```

### Example 2: Adding a Column

```php
<?php
// database/tenant_migrations/2025_11_add_status_column.php
require_once __DIR__ . '/../tools/migration_helpers.php';

return function (mysqli $db): void {
    migration_add_column_if_missing(
        $db,
        'custom_table',
        'status',
        '`status` ENUM(\'active\', \'inactive\', \'archived\') NOT NULL DEFAULT \'active\' COMMENT \'Status\''
    );
    
    // Add index on status
    migration_add_index_if_missing(
        $db,
        'custom_table',
        'idx_status',
        'INDEX `idx_status` (`status`)'
    );
};
```

### Example 3: Running Migrations

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';
use BGERP\Migration\BootstrapMigrations;

// Run for specific tenant
BootstrapMigrations::run_tenant_migrations_for('default');

// Run for all tenants
BootstrapMigrations::run_tenant_migrations_for_all();

// Run core migrations
BootstrapMigrations::run_core_migrations();
```

---

## Reference Documents

### Database Documentation

- **Schema Reference**: `docs/DATABASE_SCHEMA_REFERENCE.md` - Complete table structures
- **Migration Guide**: `docs/bootstrap/Task/task19.md` - Migration system details
- **Migration Naming**: `docs/MIGRATION_NAMING_STANDARD.md` - Naming conventions

### Migration Code

- **BootstrapMigrations**: `source/BGERP/Migration/BootstrapMigrations.php`
- **Migration Helpers**: `database/tools/migration_helpers.php`
- **Legacy Wrapper**: `source/bootstrap_migrations.php`

### Task Documentation

- **Task 19**: `docs/bootstrap/Task/task19.md` - PSR-4 migration details

---

## Future Expansion

### Planned Enhancements

1. **Migration Rollback**
   - Rollback support
   - Migration versioning
   - Safe rollback procedures

2. **Migration Testing**
   - Automated migration tests
   - Schema validation
   - Data integrity checks

3. **Database Sharding**
   - Horizontal scaling
   - Shard management
   - Data distribution

4. **Read Replicas**
   - Read-only replicas
   - Load balancing
   - Performance optimization

---

**Previous Chapter:** [Chapter 4 — Permission Architecture](../chapters/04-permission-architecture.md)  
**Next Chapter:** [Chapter 6 — API Development Guide](../chapters/06-api-development-guide.md)


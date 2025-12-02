# 🗄️ Phase 8: Database Schema Specification

**Detailed database schema for Product-Graph Binding system**

---

## 📋 Table: `product_graph_binding`

### Purpose
Links products to routing graphs with version management, mode support, and effective date ranges.

### Schema

```sql
CREATE TABLE product_graph_binding (
    -- Primary Key
    id_binding INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique binding ID',
    
    -- Foreign Keys
    id_product INT NOT NULL COMMENT 'FK to product(id_product)',
    id_graph INT NOT NULL COMMENT 'FK to routing_graph(id_graph)',
    
    -- Version Management
    graph_version_pin VARCHAR(10) DEFAULT NULL COMMENT 'Pinned graph version (NULL = use latest published)',
    
    -- Production Mode
    default_mode ENUM('hatthasilpa','classic','hybrid') DEFAULT 'hatthasilpa' 
        COMMENT 'Default production mode for this binding',
    
    -- Status
    is_active TINYINT(1) DEFAULT 1 COMMENT 'Is this binding currently active',
    
    -- Effective Date Range
    effective_from DATETIME DEFAULT CURRENT_TIMESTAMP 
        COMMENT 'When this binding became effective',
    effective_until DATETIME DEFAULT NULL 
        COMMENT 'When this binding expires (NULL = indefinite)',
    
    -- Priority (for multiple bindings)
    priority INT DEFAULT 0 
        COMMENT 'Priority if multiple active bindings (higher = preferred)',
    
    -- Notes
    notes TEXT NULL COMMENT 'Admin notes about this binding',
    
    -- Source Tracking
    source ENUM('manual','migration','api','system') DEFAULT 'manual' 
        COMMENT 'Source of binding creation (manual=user, migration=backfill, api=programmatic, system=auto)',
    
    -- Audit Fields
    created_by INT NULL COMMENT 'User who created this binding',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_by INT NULL COMMENT 'User who last updated',
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Foreign Key Constraints
    FOREIGN KEY (id_product) REFERENCES product(id_product) ON DELETE CASCADE,
    FOREIGN KEY (id_graph) REFERENCES routing_graph(id_graph) ON DELETE RESTRICT,
    FOREIGN KEY (created_by) REFERENCES member(id_member) ON DELETE SET NULL,
    FOREIGN KEY (updated_by) REFERENCES member(id_member) ON DELETE SET NULL,
    
    -- Indexes
    UNIQUE KEY uniq_product_graph_active (
        id_product, 
        id_graph, 
        is_active, 
        effective_from
    ) COMMENT 'Prevent duplicate active bindings',
    
    -- Note: One active binding per product+mode enforced at application level
    -- (Cannot use unique constraint because we need multiple bindings for different modes)
    -- Service layer must ensure: WHERE id_product=? AND default_mode=? AND is_active=1 returns at most 1 row
    
    INDEX idx_product (id_product) COMMENT 'Fast product lookups',
    INDEX idx_graph (id_graph) COMMENT 'Fast graph lookups',
    INDEX idx_active (is_active, effective_from, effective_until) 
        COMMENT 'Filter active bindings by date range',
    INDEX idx_mode (default_mode) COMMENT 'Filter by production mode',
    INDEX idx_priority (priority DESC) COMMENT 'Sort by priority',
    INDEX idx_source (source) COMMENT 'Filter by source',
    
    -- Table Options
    ENGINE=InnoDB 
    DEFAULT CHARSET=utf8mb4 
    COLLATE=utf8mb4_unicode_ci
    COMMENT='Binding between products and routing graphs with version management'
);
```

### Column Details

| Column | Type | Null | Default | Description |
|--------|------|------|---------|-------------|
| `id_binding` | INT | NO | AUTO_INCREMENT | Primary key |
| `id_product` | INT | NO | - | Product ID (FK) |
| `id_graph` | INT | NO | - | Graph ID (FK) |
| `graph_version_pin` | VARCHAR(10) | YES | NULL | Pinned version or NULL for latest |
| `default_mode` | ENUM | NO | 'hatthasilpa' | Production mode |
| `is_active` | TINYINT(1) | NO | 1 | Active status |
| `effective_from` | DATETIME | NO | CURRENT_TIMESTAMP | Start date |
| `effective_until` | DATETIME | YES | NULL | End date (NULL = indefinite) |
| `priority` | INT | NO | 0 | Priority for multiple bindings |
| `notes` | TEXT | YES | NULL | Admin notes |
| `source` | ENUM | NO | 'manual' | Source of binding (manual/migration/api/system) |
| `created_by` | INT | YES | NULL | Creator user ID |
| `created_at` | DATETIME | NO | CURRENT_TIMESTAMP | Creation timestamp |
| `updated_by` | INT | YES | NULL | Last updater user ID |
| `updated_at` | DATETIME | NO | CURRENT_TIMESTAMP ON UPDATE | Update timestamp |

### Business Rules

1. **One Active Binding Per Product+Mode (CRITICAL):**
   - Only one binding can be `is_active=1` for the same `id_product` + `default_mode` combination
   - When creating a new active binding, **MUST deactivate all other active bindings** for the same product+mode
   - Enforced at application/service layer (not database constraint due to multi-mode support)
   - Query pattern: `SELECT COUNT(*) FROM product_graph_binding WHERE id_product=? AND default_mode=? AND is_active=1` must return ≤ 1

2. **Version Pinning:**
   - If `graph_version_pin` is NULL, use latest **stable** published version (`is_stable=1`)
   - If provided, must be a valid published version that exists in `routing_graph_version`
   - Version must belong to the bound graph (`routing_graph.id_graph`)

3. **Effective Date Range:**
   - `effective_from` defaults to NOW()
   - `effective_until` NULL means indefinite
   - Only bindings with `effective_from <= NOW()` and (`effective_until IS NULL` OR `effective_until >= NOW()`) are considered active

4. **Graph Binding Validation (MANDATORY):**
   - Graph must be `status='published'` (cannot bind unpublished graphs)
   - If pinning version, version must exist and be published
   - Graph must be stable (`is_stable=1`) for auto-selection (latest stable)
   - Validation enforced at API/service layer before binding creation

5. **Graph Deletion:**
   - `ON DELETE RESTRICT` prevents deleting graphs with active bindings
   - Must deactivate all bindings before deleting graph

6. **Product Deletion:**
   - `ON DELETE CASCADE` removes all bindings when product is deleted

7. **Future: Variant Support (Placeholder):**
   - For products with variants (color, size), consider `product_variant_graph_binding` table
   - Structure: `id_variant_binding`, `id_product_variant`, `id_graph`, `default_mode`, etc.
   - Not implemented in Phase 8, but schema designed to allow easy extension

---

## 📋 Table: `product_graph_binding_audit`

### Purpose
Complete audit trail for all binding changes (create, update, activate, deactivate, delete).

### Schema

```sql
CREATE TABLE product_graph_binding_audit (
    -- Primary Key
    id_audit INT AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique audit ID',
    
    -- Foreign Keys
    id_binding INT NOT NULL COMMENT 'FK to product_graph_binding(id_binding)',
    id_product INT NOT NULL COMMENT 'FK to product (denormalized for queries)',
    id_graph INT NOT NULL COMMENT 'FK to routing_graph (denormalized)',
    
    -- Action Type
    action ENUM('created','updated','activated','deactivated','deleted') NOT NULL 
        COMMENT 'Type of action performed',
    
    -- Change Details
    old_values JSON NULL COMMENT 'Previous values (for updates)',
    new_values JSON NULL COMMENT 'New values',
    
    -- Source Tracking
    source ENUM('manual','migration','api','system') DEFAULT 'manual' 
        COMMENT 'Source of change (manual=user, migration=backfill, api=programmatic, system=auto)',
    
    -- Audit Metadata
    changed_by INT NULL COMMENT 'User who made the change',
    changed_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT 'When change occurred',
    reason TEXT NULL COMMENT 'Reason for change',
    
    -- Foreign Key Constraints
    FOREIGN KEY (id_binding) REFERENCES product_graph_binding(id_binding) ON DELETE CASCADE,
    FOREIGN KEY (changed_by) REFERENCES member(id_member) ON DELETE SET NULL,
    
    -- Indexes
    INDEX idx_product (id_product) COMMENT 'Fast product audit queries',
    INDEX idx_graph (id_graph) COMMENT 'Fast graph audit queries',
    INDEX idx_changed_at (changed_at DESC) COMMENT 'Chronological queries',
    INDEX idx_action (action) COMMENT 'Filter by action type',
    INDEX idx_binding (id_binding) COMMENT 'Binding history queries',
    INDEX idx_source (source) COMMENT 'Filter by source',
    
    -- Table Options
    ENGINE=InnoDB 
    DEFAULT CHARSET=utf8mb4 
    COLLATE=utf8mb4_unicode_ci
    COMMENT='Audit trail for product-graph binding changes'
);
```

### Column Details

| Column | Type | Null | Default | Description |
|--------|------|------|---------|-------------|
| `id_audit` | INT | NO | AUTO_INCREMENT | Primary key |
| `id_binding` | INT | NO | - | Binding ID (FK) |
| `id_product` | INT | NO | - | Product ID (denormalized) |
| `id_graph` | INT | NO | - | Graph ID (denormalized) |
| `action` | ENUM | NO | - | Action type |
| `old_values` | JSON | YES | NULL | Previous values |
| `new_values` | JSON | YES | NULL | New values |
| `source` | ENUM | NO | 'manual' | Source of change (manual/migration/api/system) |
| `changed_by` | INT | YES | NULL | User ID |
| `changed_at` | DATETIME | NO | CURRENT_TIMESTAMP | Timestamp |
| `reason` | TEXT | YES | NULL | Reason for change |

### JSON Structure Examples

**old_values / new_values:**
```json
{
  "id_graph": 7,
  "graph_version_pin": "2.3",
  "default_mode": "hatthasilpa",
  "is_active": true,
  "effective_from": "2025-11-01 00:00:00"
}
```

---

## 🔍 Query Patterns

### Get Active Binding for Product

```sql
SELECT pgb.*, rg.code as graph_code, rg.name as graph_name
FROM product_graph_binding pgb
INNER JOIN routing_graph rg ON rg.id_graph = pgb.id_graph
WHERE pgb.id_product = ?
    AND pgb.is_active = 1
    AND pgb.effective_from <= NOW()
    AND (pgb.effective_until IS NULL OR pgb.effective_until >= NOW())
    AND (pgb.default_mode = ? OR pgb.default_mode IS NULL)
ORDER BY pgb.priority DESC, pgb.effective_from DESC
LIMIT 1;
```

### Get All Active Bindings for Product

```sql
SELECT pgb.*, rg.code as graph_code, rg.name as graph_name
FROM product_graph_binding pgb
INNER JOIN routing_graph rg ON rg.id_graph = pgb.id_graph
WHERE pgb.id_product = ?
    AND pgb.is_active = 1
    AND pgb.effective_from <= NOW()
    AND (pgb.effective_until IS NULL OR pgb.effective_until >= NOW())
ORDER BY pgb.priority DESC, pgb.default_mode, pgb.effective_from DESC;
```

### Get Binding History

```sql
SELECT pga.*, m.username as changed_by_name
FROM product_graph_binding_audit pga
LEFT JOIN member m ON m.id_member = pga.changed_by
WHERE pga.id_product = ?
ORDER BY pga.changed_at DESC
LIMIT ? OFFSET ?;
```

### Check if Graph Can Be Deleted

```sql
SELECT COUNT(*) as active_bindings
FROM product_graph_binding
WHERE id_graph = ?
    AND is_active = 1
    AND effective_from <= NOW()
    AND (effective_until IS NULL OR effective_until >= NOW());
-- If count > 0, cannot delete
```

### Get Products Using Graph

```sql
SELECT p.id_product, p.sku, p.name, pgb.graph_version_pin, pgb.default_mode
FROM product_graph_binding pgb
INNER JOIN product p ON p.id_product = pgb.id_product
WHERE pgb.id_graph = ?
    AND pgb.is_active = 1
ORDER BY p.sku;
```

---

## 🔄 Migration Strategy

### Step 1: Create Tables

**File:** `database/tenant_migrations/2025_11_product_graph_binding.php`

```php
<?php
require_once __DIR__ . '/../tools/migration_helpers.php';

return function (mysqli $db): void {
    // Create product_graph_binding table
    migration_create_table_if_missing($db, 'product_graph_binding', $sql);
    
    // Create product_graph_binding_audit table
    migration_create_table_if_missing($db, 'product_graph_binding_audit', $sqlAudit);
};
```

### Step 2: Backfill (Optional)

**File:** `database/tenant_migrations/2025_11_product_graph_binding_backfill.php`

```php
<?php
require_once __DIR__ . '/../tools/migration_helpers.php';

return function (mysqli $db): void {
    // Find default graphs
    // Create bindings for existing products
    // Log results
};
```

### Step 3: Verify

```sql
-- Check table exists
SHOW TABLES LIKE 'product_graph_binding';

-- Check indexes
SHOW INDEXES FROM product_graph_binding;

-- Check foreign keys
SELECT 
    CONSTRAINT_NAME, 
    TABLE_NAME, 
    COLUMN_NAME, 
    REFERENCED_TABLE_NAME, 
    REFERENCED_COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'product_graph_binding'
    AND REFERENCED_TABLE_NAME IS NOT NULL;
```

---

## 📊 Additional Performance Indexes

### Recommended Indexes for Phase 8

**For `routing_graph` table:**
```sql
-- Composite index for list_graphs queries (tenant-aware)
INDEX idx_tenant_mode_status_updated (
    tenant_id, 
    production_type, 
    status, 
    updated_at DESC
) COMMENT 'Fast list_graphs queries with mode/status filter';

-- If tenant_id not in routing_graph, use:
INDEX idx_mode_status_updated (
    production_type, 
    status, 
    updated_at DESC
) COMMENT 'Fast list_graphs queries';
```

**For `routing_graph_version` table:**
```sql
-- Composite index for latest stable version lookup
INDEX idx_graph_stable_published (
    id_graph, 
    is_stable, 
    published_at DESC
) COMMENT 'Fast latest stable version queries';
```

**For `product_graph_binding` table:**
```sql
-- Composite index for active binding lookup (already exists: idx_active)
-- Additional index for product+mode lookup
INDEX idx_product_mode_active (
    id_product, 
    default_mode, 
    is_active
) COMMENT 'Fast active binding lookup per product+mode';
```

**Migration:**
```php
// In migration file
migration_add_index_if_missing(
    $db,
    'routing_graph',
    'idx_mode_status_updated',
    'INDEX idx_mode_status_updated (production_type, status, updated_at DESC)'
);

migration_add_index_if_missing(
    $db,
    'routing_graph_version',
    'idx_graph_stable_published',
    'INDEX idx_graph_stable_published (id_graph, is_stable, published_at DESC)'
);

migration_add_index_if_missing(
    $db,
    'product_graph_binding',
    'idx_product_mode_active',
    'INDEX idx_product_mode_active (id_product, default_mode, is_active)'
);

// Additional performance indexes for scaling
migration_add_index_if_missing(
    $db,
    'routing_graph',
    'idx_org_status_type',
    'INDEX idx_org_status_type (id_org, status, production_type)'
);

migration_add_index_if_missing(
    $db,
    'product_graph_binding_audit',
    'idx_changed_at_action',
    'INDEX idx_changed_at_action (changed_at DESC, action)'
);
```

## 📊 Index Performance

### Expected Query Performance

| Query Type | Index Used | Expected Rows | Performance |
|------------|------------|---------------|-------------|
| Get active binding by product | `idx_product` + `idx_active` | 1-5 | < 1ms |
| List all bindings for product | `idx_product` | 1-10 | < 1ms |
| Get products using graph | `idx_graph` | 1-100 | < 5ms |
| Audit history by product | `idx_product` + `idx_changed_at` | 10-1000 | < 10ms |
| Check active bindings | `idx_active` | 1-1000 | < 10ms |

### Index Maintenance

- Indexes are automatically maintained by InnoDB
- No manual maintenance required
- Monitor with `SHOW INDEX FROM product_graph_binding`

---

## 🔒 Security Considerations

### Tenant Isolation

All queries must include tenant filtering:

```sql
SELECT pgb.*
FROM product_graph_binding pgb
INNER JOIN product p ON p.id_product = pgb.id_product
WHERE pgb.id_product = ?
    AND p.id_org = ?  -- Tenant isolation
    AND pgb.is_active = 1;
```

### Data Integrity

1. **Foreign Key Constraints:**
   - Prevent orphaned bindings
   - Prevent invalid product/graph references

2. **Unique Constraint:**
   - Prevents duplicate active bindings
   - Enforced at database level

3. **Cascade Rules:**
   - Product deletion → Bindings deleted
   - Graph deletion → Prevented if bindings exist
   - User deletion → Audit trail preserved (SET NULL)

---

## 📈 Future Enhancements

### Potential Additions

1. **Soft Delete:**
   ```sql
   ADD COLUMN deleted_at DATETIME NULL;
   ADD INDEX idx_deleted (deleted_at);
   ```

2. **Version History:**
   ```sql
   CREATE TABLE product_graph_binding_version (
       id_version INT AUTO_INCREMENT PRIMARY KEY,
       id_binding INT NOT NULL,
       version_snapshot JSON NOT NULL,
       created_at DATETIME DEFAULT CURRENT_TIMESTAMP
   );
   ```

3. **A/B Testing:**
   ```sql
   ADD COLUMN is_experiment TINYINT(1) DEFAULT 0;
   ADD COLUMN experiment_group VARCHAR(50) NULL;
   ```

---

**Last Updated:** 2025-11-12


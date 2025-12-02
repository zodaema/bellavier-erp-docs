# Database Naming Policy - Canonical Table Names

**Date:** November 15, 2025  
**Status:** 📋 Policy Document - Awaiting Approval  
**Purpose:** Zero-downtime migration from legacy `hatthasilpa_*` to canonical names

---

## 🎯 **Problem Statement**

### **Current Issue:**
- Tables named `hatthasilpa_*` but store **ALL production types** (hatthasilpa/oem/hybrid)
- Name suggests "Hatthasilpa only" but reality is "unified production tables"
- Creates confusion: `SELECT * FROM hatthasilpa_job_ticket WHERE production_type='oem'` looks contradictory
- Technical debt accumulates as new code references misleading names

### **Impact:**
- ❌ New developers/AI agents misunderstand table purpose
- ❌ Code written with wrong context
- ❌ Queries look contradictory
- ❌ Future maintenance confusion

---

## ✅ **Solution: Canonical Naming**

### **Target State:**
- **Canonical tables:** `job_ticket`, `job_task`, `wip_log`, `task_operator_session`, `job_ticket_status_history`
- **No production-line prefix** in table names
- **Use `production_type` column** to distinguish production lines

### **Benefits:**
- ✅ Names reflect reality (unified tables)
- ✅ Clear and consistent
- ✅ No confusion for new developers
- ✅ Future-proof

---

## 📋 **Migration Strategy: Zero-Downtime Path**

### **Phase 1: Create Canonical VIEWs (IMMEDIATE - Zero Downtime)**

**Goal:** New code uses canonical names, old code continues working

**Actions:**
1. Create VIEWs pointing to existing tables:
   ```sql
   CREATE VIEW job_ticket AS SELECT * FROM hatthasilpa_job_ticket;
   CREATE VIEW job_task AS SELECT * FROM hatthasilpa_job_task;
   CREATE VIEW wip_log AS SELECT * FROM hatthasilpa_wip_log;
   CREATE VIEW task_operator_session AS SELECT * FROM hatthasilpa_task_operator_session;
   CREATE VIEW job_ticket_status_history AS SELECT * FROM hatthasilpa_job_ticket_status_history;
   ```

2. **VIEWs are updatable** (INSERT/UPDATE/DELETE work) because:
   - Column mapping is 1:1
   - No functions/computed columns
   - Direct table reference

3. **New code MUST use canonical names:**
   ```php
   // ✅ CORRECT (new code)
   SELECT * FROM job_ticket WHERE production_type = 'oem';
   
   // ⚠️ DEPRECATED (old code - still works but should migrate)
   SELECT * FROM hatthasilpa_job_ticket WHERE production_type = 'oem';
   ```

**Timeline:** Immediate (can deploy now)

---

### **Phase 2: Update Service Layer (WEEK 1-2)**

**Goal:** All new code uses canonical names

**Actions:**
1. Update Service classes to use canonical names:
   ```php
   // OLD
   $stmt = $db->prepare("SELECT * FROM hatthasilpa_job_ticket WHERE id_job_ticket=?");
   
   // NEW
   $stmt = $db->prepare("SELECT * FROM job_ticket WHERE id_job_ticket=?");
   ```

2. Add comments in code:
   ```php
   /**
    * ⚠️ DEPRECATED: Use job_ticket instead of hatthasilpa_job_ticket
    * This table stores ALL production types (hatthasilpa/oem/hybrid)
    * Canonical name: job_ticket
    */
   ```

3. Update API endpoints gradually

**Timeline:** 1-2 weeks

---

### **Phase 3: Add Guard Rules (WEEK 2)**

**Goal:** Prevent new code from using legacy names

**Actions:**
1. Add to `.cursorrules` or lint config:
   ```
   # Block legacy table names in new code
   - Pattern: FROM hatthasilpa_|INSERT INTO hatthasilpa_|UPDATE hatthasilpa_
   - Action: Warn + suggest canonical name
   - Auto-fix: Replace with canonical name
   ```

2. Add to code review checklist:
   - [ ] No `hatthasilpa_*` table references in new code
   - [ ] All queries use canonical names (`job_ticket`, `job_task`, etc.)

**Timeline:** Week 2

---

### **Phase 4: Rename Tables (FUTURE - 3-6 months)**

**Goal:** Physical tables use canonical names

**Prerequisites:**
- ✅ All new code uses canonical names
- ✅ All API endpoints migrated
- ✅ All UI pages migrated
- ✅ Maintenance window available

**Actions:**
1. **Rename physical tables:**
   ```sql
   RENAME TABLE hatthasilpa_job_ticket TO job_ticket_real,
                hatthasilpa_job_task TO job_task_real,
                hatthasilpa_wip_log TO wip_log_real,
                hatthasilpa_task_operator_session TO task_operator_session_real,
                hatthasilpa_job_ticket_status_history TO job_ticket_status_history_real;
   ```

2. **Recreate canonical VIEWs pointing to real tables:**
   ```sql
   CREATE OR REPLACE VIEW job_ticket AS SELECT * FROM job_ticket_real;
   CREATE OR REPLACE VIEW job_task AS SELECT * FROM job_task_real;
   -- etc.
   ```

3. **Create compatibility VIEWs (temporary):**
   ```sql
   CREATE VIEW hatthasilpa_job_ticket AS SELECT * FROM job_ticket_real;
   CREATE VIEW hatthasilpa_job_task AS SELECT * FROM job_task_real;
   -- etc. (for old code that hasn't migrated yet)
   ```

4. **Update foreign keys gradually** (one by one)

**Timeline:** 3-6 months (when ready)

---

### **Phase 5: Remove Compatibility VIEWs (FUTURE - 6-12 months)**

**Goal:** Complete migration

**Prerequisites:**
- ✅ All code uses canonical names
- ✅ No references to `hatthasilpa_*` in codebase
- ✅ Analytics/reports migrated

**Actions:**
1. Drop compatibility VIEWs:
   ```sql
   DROP VIEW IF EXISTS hatthasilpa_job_ticket;
   DROP VIEW IF EXISTS hatthasilpa_job_task;
   -- etc.
   ```

2. Rename `*_real` tables to canonical names:
   ```sql
   RENAME TABLE job_ticket_real TO job_ticket,
                job_task_real TO job_task,
                -- etc.
   ```

3. Recreate VIEWs pointing to canonical tables (for consistency)

**Timeline:** 6-12 months

---

## 🔧 **Migration Helper: `resolveTable()`**

### **Purpose:**
Allow migrations to work with both canonical and legacy names (zero-downtime)

### **Function:**
```php
function migration_resolve_table(mysqli $db, string $preferred, string $fallback): string {
    // Check preferred (canonical) name first
    $result = $db->query("SHOW TABLES LIKE '{$preferred}'");
    if ($result && $result->num_rows > 0) {
        return $preferred;
    }
    
    // Check fallback (legacy) name
    $result = $db->query("SHOW TABLES LIKE '{$fallback}'");
    if ($result && $result->num_rows > 0) {
        return $fallback;
    }
    
    throw new RuntimeException("Neither '{$preferred}' nor '{$fallback}' exists");
}
```

### **Usage in Migrations:**
```php
// Resolve table names (works in both phases)
$t_job_ticket = migration_resolve_table($db, 'job_ticket', 'hatthasilpa_job_ticket');
$t_job_task = migration_resolve_table($db, 'job_task', 'hatthasilpa_job_task');

// Use resolved names
migration_add_column_if_missing($db, $t_job_ticket, 'graph_version', '...');
```

**Benefit:** Same migration works before and after table rename!

---

## 📊 **Table Name Mapping**

| Legacy Name | Canonical Name | Status |
|-------------|----------------|--------|
| `hatthasilpa_job_ticket` | `job_ticket` | ✅ VIEW created |
| `hatthasilpa_job_task` | `job_task` | ✅ VIEW created |
| `hatthasilpa_wip_log` | `wip_log` | ✅ VIEW created |
| `hatthasilpa_task_operator_session` | `task_operator_session` | ✅ VIEW created |
| `hatthasilpa_job_ticket_status_history` | `job_ticket_status_history` | ✅ VIEW created |

---

## 📝 **Naming Conventions**

### **Canonical Table Names:**
- ✅ `job_ticket` - Main work order (all production types)
- ✅ `job_task` - Work steps (all production types)
- ✅ `wip_log` - Event logs (all production types)
- ✅ `task_operator_session` - Operator sessions (all production types)
- ✅ `job_ticket_status_history` - Status history (all production types)

### **Column Names:**
- ✅ `production_type` ENUM('hatthasilpa','oem','hybrid') - Distinguishes production line
- ✅ No production-line prefix in column names

### **Index Names:**
- ✅ `idx_production_type_status` - Neutral, no production-line reference
- ✅ `idx_station_code` - Neutral

---

## ⚠️ **Rules for Developers**

### **DO:**
- ✅ Use canonical names (`job_ticket`, `job_task`) in **all new code**
- ✅ Use `production_type` column to filter production lines
- ✅ Use `migration_resolve_table()` in migrations

### **DON'T:**
- ❌ Use `hatthasilpa_*` table names in **new code**
- ❌ Hard-code table names in migrations (use `resolveTable()`)
- ❌ Assume table name indicates production type (use `production_type` column)

---

## 🎯 **Implementation Checklist**

### **Phase 1: VIEW Creation (IMMEDIATE)**
- [ ] Create migration: `2025_11_canonical_table_views.php`
- [ ] Create VIEWs: `job_ticket`, `job_task`, `wip_log`, `task_operator_session`, `job_ticket_status_history`
- [ ] Verify VIEWs are updatable
- [ ] Test INSERT/UPDATE/DELETE on VIEWs
- [ ] Deploy to all tenant databases

### **Phase 2: Service Layer Update (WEEK 1-2)**
- [ ] Update `ProductionTypeResolver` to use canonical names
- [ ] Update `HatthasilpaJobTicketService` to use canonical names
- [ ] Update `ClassicJobTicketService` to use canonical names
- [ ] Update API endpoints gradually
- [ ] Add deprecation comments

### **Phase 3: Guard Rules (WEEK 2)**
- [ ] Add lint rules for `hatthasilpa_*` pattern
- [ ] Add to code review checklist
- [ ] Document in developer guide

### **Phase 4: Table Rename (FUTURE - 3-6 months)**
- [ ] Verify all code uses canonical names
- [ ] Schedule maintenance window
- [ ] Rename physical tables
- [ ] Recreate VIEWs
- [ ] Create compatibility VIEWs
- [ ] Update foreign keys

### **Phase 5: Cleanup (FUTURE - 6-12 months)**
- [ ] Verify no `hatthasilpa_*` references
- [ ] Drop compatibility VIEWs
- [ ] Rename `*_real` to canonical names
- [ ] Final verification

---

## 📚 **Documentation Updates**

### **Files to Update:**
1. `docs/database/01-schema/DATABASE_SCHEMA_REFERENCE.md` - Use canonical names
2. `docs/routing_graph_designer/PHASE8_PRODUCTION_TYPE_COMPLETE_GUIDE.md` - Add warning
3. `docs/guide/API_DEVELOPMENT_GUIDE.md` - Use canonical names in examples
4. Developer onboarding docs - Explain canonical naming

---

## 🎯 **Success Criteria**

### **Phase 1 Complete When:**
- ✅ VIEWs created and tested
- ✅ New code can use canonical names
- ✅ Old code still works

### **Phase 2 Complete When:**
- ✅ All new code uses canonical names
- ✅ Service layer updated
- ✅ API endpoints updated

### **Phase 4 Complete When:**
- ✅ Physical tables renamed
- ✅ VIEWs point to real tables
- ✅ Compatibility VIEWs created
- ✅ System fully functional

### **Phase 5 Complete When:**
- ✅ Compatibility VIEWs removed
- ✅ All tables use canonical names
- ✅ No legacy references in codebase

---

## ⚠️ **Risks & Mitigation**

### **Risk 1: VIEW Performance**
- **Risk:** VIEWs might be slower than direct table access
- **Mitigation:** MySQL optimizes simple VIEWs (SELECT * FROM table) - performance is identical
- **Test:** Benchmark VIEW vs table queries

### **Risk 2: Foreign Key Constraints**
- **Risk:** Foreign keys reference `hatthasilpa_*` names
- **Mitigation:** Update FKs gradually in Phase 4, use compatibility VIEWs temporarily

### **Risk 3: Old Code Breaks**
- **Risk:** Old code using `hatthasilpa_*` might break after rename
- **Mitigation:** Compatibility VIEWs in Phase 4, gradual migration

---

## 📋 **Migration File Template**

```php
<?php
/**
 * Migration: YYYY_MM_description
 * Description: [Description]
 * 
 * ⚠️ IMPORTANT: Use migration_resolve_table() for table names
 * This allows migration to work with both canonical and legacy names
 */

require_once __DIR__ . '/../tools/migration_helpers.php';

return function (mysqli $db): void {
    // Resolve table names (supports both canonical and legacy)
    $t_job_ticket = migration_resolve_table($db, 'job_ticket', 'hatthasilpa_job_ticket');
    $t_job_task = migration_resolve_table($db, 'job_task', 'hatthasilpa_job_task');
    
    // Use resolved names
    migration_add_column_if_missing($db, $t_job_ticket, 'column_name', '...');
};
```

---

## ✅ **Summary**

### **Current State:**
- Tables: `hatthasilpa_job_ticket`, `hatthasilpa_job_task`, etc.
- Problem: Names don't reflect reality (store all production types)

### **Target State:**
- Tables: `job_ticket`, `job_task`, etc. (canonical names)
- Filter by: `production_type` column (not table name)

### **Migration Path:**
1. **Phase 1:** Create VIEWs (zero-downtime, immediate)
2. **Phase 2:** Update code (1-2 weeks)
3. **Phase 3:** Add guards (week 2)
4. **Phase 4:** Rename tables (3-6 months)
5. **Phase 5:** Remove compatibility (6-12 months)

---

**Last Updated:** November 15, 2025  
**Status:** 📋 Policy Document - Awaiting Approval  
**Next Step:** Review and approve before implementation


# Phase 9: People System Integration - Paused Summary

**Status:** ⏸️ **PAUSED** (Future Project - Not Started)  
**Date Paused:** November 15, 2025  
**Reason:** People DB system is a future project, not yet started

---

## 📋 **Executive Summary**

Phase 9 infrastructure code has been prepared and is **ready for future use**. All code includes safety checks to prevent errors if Phase 9 tables don't exist yet. The system will gracefully fallback to regular queries.

**Current Status:**
- ✅ Infrastructure code created (T19-T22)
- ✅ Safety checks implemented (no errors if tables missing)
- ✅ Backward compatible with existing system
- ⏸️ Waiting for People DB system to be available

---

## 📁 **Files Created/Modified**

### **1. Database Migration**
**File:** `database/tenant_migrations/2025_11_people_integration.php` (128 lines)

**Purpose:** Creates 5 cache tables for People DB integration

**Tables Created:**
1. `people_operator_cache` - Operator profiles cache
2. `people_team_cache` - Team information cache
3. `people_availability_cache` - Operator availability cache
4. `people_masking_policy` - Privacy masking policy
5. `people_sync_error_log` - Sync error audit log

**Status:** ✅ Migration file ready, **NOT YET RUN** (waiting for People DB)

**To Deploy:**
```bash
# When People DB is ready, run:
php tools/run_tenant_migrations.php <tenant_code>
```

---

### **2. People Sync Service**
**File:** `source/BGERP/Service/PeopleSyncService.php` (546 lines)

**Purpose:** Read-only sync from People DB to cache tables

**Key Methods:**
- `syncPull(array $options)` - Pull data from People DB and cache
- `getOperator(int $operatorId, bool $applyMasking, ?int $viewerId)` - Get operator info from cache
- `getTeam(int $teamId)` - Get team info from cache
- `getOperatorAvailability(int $operatorId, string $date)` - Get availability from cache
- `applyMasking(array $operator, int $viewerId)` - Apply privacy masking

**Safety Features:**
- ✅ Checks table existence before querying (returns `null` if tables don't exist)
- ✅ Handles People DB connection failures gracefully
- ✅ Returns empty results if People DB unavailable

**Environment Variables Required (when People DB ready):**
```env
PEOPLE_DB_HOST=localhost
PEOPLE_DB_PORT=3306
PEOPLE_DB_USER=root
PEOPLE_DB_PASSWORD=password
PEOPLE_DB_NAME=people_db
```

**Status:** ✅ Code ready, **safe to use** (won't error if tables missing)

---

### **3. People API Endpoints**
**File:** `source/people_api.php` (261 lines)

**Purpose:** API endpoints for People System integration

**Endpoints:**
1. `sync_pull` - Manual sync trigger (admin only)
   - POST `/source/people_api.php?action=sync_pull`
   - Options: `operators`, `teams`, `availability`

2. `lookup` - Operator lookup with masking
   - GET `/source/people_api.php?action=lookup&operator_id=5`

3. `lookup_team` - Team lookup
   - GET `/source/people_api.php?action=lookup_team&team_id=3`

4. `lookup_availability` - Availability lookup
   - GET `/source/people_api.php?action=lookup_availability&operator_id=5&date=2025-11-15`

**Status:** ✅ Code ready, **safe to use** (won't error if tables missing)

---

### **4. Cron Script**
**File:** `tools/cron/people_sync.php` (69 lines)

**Purpose:** Periodic sync from People DB to cache tables

**Usage:**
```bash
php tools/cron/people_sync.php <tenant_code>
```

**Scheduled:** Not yet scheduled (waiting for People DB)

**Status:** ✅ Script ready, **safe to run** (won't error if tables missing)

---

### **5. Assignment Resolver Integration**
**File:** `source/BGERP/Service/AssignmentResolverService.php` (Modified)

**Changes Made:**
- Added `PeopleSyncService` integration in constructor
- Modified `getAvailableTeams()` to use People cache first, fallback to regular query
- Added table existence check before querying People cache

**Key Code Location:**
- Line 23-35: Constructor with PeopleSyncService initialization
- Line 504-624: `getAvailableTeams()` with People cache integration

**Safety Features:**
- ✅ Checks `people_team_cache` table existence before querying
- ✅ Falls back to regular `team` table query if People cache unavailable
- ✅ Catches exceptions and logs errors gracefully

**Status:** ✅ Code ready, **backward compatible** (works with or without People cache)

---

### **6. Supporting Service Updates**
**Files Modified:**
- `source/BGERP/Service/TokenLifecycleService.php` - Added `tenantCode` parameter
- `source/BGERP/Service/DAGRoutingService.php` - Added `tenantCode` parameter
- `source/assignment_api.php` - Passes `tenantCode` to AssignmentResolverService
- `source/dag_routing_api.php` - Passes `tenantCode` to DAGRoutingService

**Changes:**
- All services now accept optional `tenantCode` parameter
- If `tenantCode` is `null`, People cache integration is disabled
- If `tenantCode` is provided, People cache integration is enabled

**Status:** ✅ Code ready, **backward compatible** (works with or without tenantCode)

---

## 🔒 **Safety Guarantees**

### **1. No Errors if Tables Missing**
All code checks table existence before querying:
```php
// Example from PeopleSyncService.php
$checkTable = $this->tenantDb->query("SHOW TABLES LIKE 'people_operator_cache'");
if (!$checkTable || $checkTable->num_rows === 0) {
    return null; // Safe fallback
}
```

### **2. Graceful Fallback**
AssignmentResolverService falls back to regular queries:
```php
// If People cache fails, use regular team table
try {
    // Try People cache
} catch (\Exception $e) {
    // Fallback to regular query
    error_log("People cache lookup failed, falling back to regular query");
}
```

### **3. Optional Integration**
People cache integration is optional:
- If `tenantCode` is `null` → People cache disabled
- If `tenantCode` is provided → People cache enabled (if tables exist)

---

## 🚀 **Resume Implementation Checklist**

When People DB is ready, follow these steps:

### **Step 1: Verify People DB Connection**
```bash
# Test People DB connection
mysql -h <PEOPLE_DB_HOST> -P <PEOPLE_DB_PORT> -u <PEOPLE_DB_USER> -p <PEOPLE_DB_NAME>
```

### **Step 2: Set Environment Variables**
```env
PEOPLE_DB_HOST=localhost
PEOPLE_DB_PORT=3306
PEOPLE_DB_USER=root
PEOPLE_DB_PASSWORD=password
PEOPLE_DB_NAME=people_db
```

### **Step 3: Run Migration**
```bash
# Run migration for each tenant
php tools/run_tenant_migrations.php <tenant_code>
```

### **Step 4: Verify Tables Created**
```sql
SHOW TABLES LIKE 'people_%';
-- Should show:
-- people_operator_cache
-- people_team_cache
-- people_availability_cache
-- people_masking_policy
-- people_sync_error_log
```

### **Step 5: Test Sync**
```bash
# Manual sync test
php tools/cron/people_sync.php <tenant_code>
```

### **Step 6: Verify Integration**
- Test `AssignmentResolverService` uses People cache
- Test API endpoints work correctly
- Test masking policy works

### **Step 7: Schedule Cron Job**
```cron
# Add to crontab (sync every 15 minutes)
*/15 * * * * php /path/to/tools/cron/people_sync.php <tenant_code>
```

### **Step 8: Continue with T23-T24**
- T23: UI Integration - Add People info display
- T24: Testing & DoD - Create integration tests

---

## 📊 **Code Statistics**

- **Files Created:** 4 files
  - Migration: 128 lines
  - PeopleSyncService: 546 lines
  - people_api.php: 261 lines
  - Cron script: 69 lines
  - **Total:** ~1,004 lines

- **Files Modified:** 5 files
  - AssignmentResolverService.php: ~30 lines added
  - TokenLifecycleService.php: ~5 lines added
  - DAGRoutingService.php: ~3 lines added
  - assignment_api.php: ~3 lines added
  - dag_routing_api.php: ~2 lines added
  - **Total:** ~43 lines modified

---

## 🔍 **Key Design Decisions**

### **1. Read-Only Sync**
- People DB is read-only source
- ERP never writes to People DB
- All writes go to cache tables in tenant DB

### **2. Cache TTL**
- Default: 15 minutes
- Configurable via constructor parameter
- Expires automatically, sync refreshes

### **3. Privacy Masking**
- Respects operator consent policy
- Supports: ACCEPTED, MASK_NAME, HIDE_AVATAR, REJECTED
- Applied per viewer (operator ID)

### **4. Fallback Strategy**
- Always falls back to regular queries if People cache unavailable
- Never breaks existing functionality
- Logs errors for debugging

---

## ⚠️ **Important Notes**

1. **Migration Not Run:** Tables don't exist yet, code is safe
2. **People DB Schema:** Code assumes standard schema, may need adjustment
3. **Environment Variables:** Not set yet, defaults to localhost
4. **Cron Job:** Not scheduled yet
5. **Testing:** Not tested yet (waiting for People DB)

---

## 📝 **Next Steps (When Resuming)**

1. **Verify People DB Schema**
   - Check actual table/column names
   - Update `PeopleSyncService.php` queries if needed

2. **Test Connection**
   - Verify People DB connection works
   - Test sync functionality

3. **Run Migration**
   - Create cache tables
   - Verify tables created correctly

4. **Test Integration**
   - Test AssignmentResolverService uses cache
   - Test API endpoints
   - Test masking policy

5. **Continue Implementation**
   - T23: UI Integration
   - T24: Testing & DoD
   - T25: Metrics & Alerts
   - T26: Rollout & Feature Flags

---

## 🔗 **Related Documentation**

- `docs/routing_graph_designer/PHASE7_10_TASK_BOARD.md` - Full Phase 9 task details
- `docs/routing_graph_designer/CURRENT_STATUS.md` - Current project status
- `docs/routing_graph_designer/REMAINING_TASKS.md` - Remaining tasks

---

**Last Updated:** November 15, 2025  
**Status:** ⏸️ **PAUSED** - Ready for future implementation


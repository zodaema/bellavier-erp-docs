# 🗑️ Linear System Deprecation & Removal Guide

**Status:** ⚠️ **UPDATED** (Task 25.3-25.5 Changes)  
**Created:** November 2, 2025  
**Last Updated:** January 2025  
**Purpose:** Safe removal of Linear task-based system after DAG adoption  
**Target Date:** Q3 2026 (after 6+ months of DAG stability)

**⚠️ Important Update (Task 25.3-25.5):**
- Classic DAG mode was **deprecated and removed**
- Classic Line now uses **Linear mode exclusively**
- Hatthasilpa Line uses **DAG mode exclusively**
- This guide now focuses on **removing Classic Linear extended mode** (job_task, wip_log) only
- Classic minimal mode (job_ticket + output stats) will remain

---

## ⚠️ **CRITICAL WARNING**

**DO NOT execute removal steps until:**
1. ✅ DAG system proven stable (6+ months in production)
2. ✅ All Linear jobs converted to DAG
3. ✅ All users trained on DAG system
4. ✅ Management approval obtained
5. ✅ Full database backup completed

**Premature removal = Data loss & system failure!**

---

## 🎯 **Why Remove Linear?**

### **Problems with Dual-Mode:**
- 🔴 Code complexity (2x maintenance cost)
- 🔴 User confusion (which system to use?)
- 🔴 Database bloat (2 sets of tables)
- 🔴 Testing complexity (2x test scenarios)
- 🔴 Documentation burden (2 systems to document)

### **Benefits of Single DAG System:**
- ✅ Simpler codebase
- ✅ Unified user experience
- ✅ Better performance (no routing overhead)
- ✅ Easier maintenance
- ✅ Lower training cost

---

## 📊 **Pre-Removal Checklist**

### **1. System Stability Check**

```sql
-- Check Hatthasilpa DAG job success rate
SELECT 
    COUNT(*) as total_dag_jobs,
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed,
    ROUND(SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) as success_rate
FROM job_ticket
WHERE production_type = 'hatthasilpa'
AND routing_mode = 'dag'
AND created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH);

-- Target: success_rate >= 95%
-- Note: Classic DAG was deprecated (Task 25.3-25.5)
```

### **2. Linear Job Migration Status**

```sql
-- Check remaining Classic Linear extended mode jobs
-- (Classic minimal mode will remain, only extended mode should be removed)
SELECT 
    COUNT(*) as remaining_extended_linear_jobs,
    GROUP_CONCAT(ticket_code SEPARATOR ', ') as job_codes
FROM job_ticket
WHERE production_type = 'classic'
AND routing_mode = 'linear'
AND EXISTS (
    SELECT 1 FROM job_task WHERE job_task.id_job_ticket = job_ticket.id_job_ticket
);

-- Target: remaining_extended_linear_jobs = 0
-- Note: Classic minimal mode (job_ticket only, no job_task) will remain
```

### **3. User Adoption**

```sql
-- Check operator activity (last 30 days)
SELECT 
    'DAG' as system,
    COUNT(DISTINCT te.operator_user_id) as unique_operators
FROM token_event te
WHERE te.event_time >= DATE_SUB(NOW(), INTERVAL 30 DAY)

UNION ALL

SELECT 
    'Linear' as system,
    COUNT(DISTINCT wl.operator_user_id) as unique_operators
FROM atelier_wip_log wl
WHERE wl.event_time >= DATE_SUB(NOW(), INTERVAL 30 DAY)
AND wl.deleted_at IS NULL;

-- Target: Linear unique_operators = 0 (no activity)
```

### **4. Data Completeness**

```sql
-- Verify all historical data migrated
SELECT 
    COUNT(*) as unmigrated_tasks
FROM atelier_job_task t
WHERE NOT EXISTS (
    SELECT 1 FROM node_instance ni
    WHERE ni.legacy_task_id = t.id_job_task
);

-- Target: unmigrated_tasks = 0
```

---

## 🗂️ **Removal Steps (Execute in Order)**

### **Phase 1: Mark as Deprecated (1 week)**

**Step 1.1: UI Warnings**
```php
// Add to source/atelier_job_ticket.php
if ($routingMode === 'linear') {
    echo json_encode([
        'ok' => false,
        'error' => 'Linear mode is deprecated. Please use DAG mode.',
        'deprecated_since' => '2026-06-01'
    ]);
    exit;
}
```

**Step 1.2: Disable Linear Job Creation**
```javascript
// In job ticket creation UI
if (routingMode === 'linear') {
    Swal.fire({
        icon: 'error',
        title: 'Linear Mode Deprecated',
        text: 'Please create DAG jobs only. Linear system will be removed soon.',
        showCancelButton: false
    });
    return false;
}
```

**Step 1.3: Email Notification**
- Send email to all users
- "Linear system will be removed on [DATE]"
- "Convert remaining jobs or they will be archived"

---

### **Phase 2: Convert Remaining Jobs (2-4 weeks)**

**Step 2.1: Generate Conversion Report**
```sql
-- Export remaining Linear jobs
SELECT 
    id_job_ticket,
    ticket_code,
    job_name,
    status,
    target_qty,
    created_at
FROM atelier_job_ticket
WHERE routing_mode = 'linear'
ORDER BY created_at DESC;
```

**Step 2.2: Auto-Convert Completed Jobs**
```php
// Create script: migrate_completed_linear_jobs.php
// For each completed Linear job:
//   1. Create default linear graph (Task1 → Task2 → Task3)
//   2. Create job_graph_instance
//   3. Create node_instances from tasks
//   4. Create tokens from serial numbers
//   5. Create token_events from wip_logs
//   6. Update job_ticket.routing_mode = 'dag'
```

**Step 2.3: Manual Migration for Active Jobs**
- Contact supervisors
- Convert job-by-job with supervision
- Ensure no production disruption

---

### **Phase 3: Archive Historical Data (1 week)**

**Step 3.1: Create Archive Database**
```sql
CREATE DATABASE bgerp_archive_linear;

USE bgerp_archive_linear;

-- Copy tables
CREATE TABLE archived_job_task LIKE bgerp_t_default.atelier_job_task;
CREATE TABLE archived_wip_log LIKE bgerp_t_default.atelier_wip_log;
CREATE TABLE archived_operator_session LIKE bgerp_t_default.atelier_task_operator_session;

-- Copy data
INSERT INTO archived_job_task SELECT * FROM bgerp_t_default.atelier_job_task;
INSERT INTO archived_wip_log SELECT * FROM bgerp_t_default.atelier_wip_log;
INSERT INTO archived_operator_session SELECT * FROM bgerp_t_default.atelier_task_operator_session;
```

**Step 3.2: Export to CSV**
```bash
mysqldump -u root -proot bgerp_archive_linear > linear_archive_$(date +%Y%m%d).sql
gzip linear_archive_$(date +%Y%m%d).sql
```

**Step 3.3: Verify Archive**
```sql
-- Compare row counts
SELECT 
    'Tasks' as table_name,
    (SELECT COUNT(*) FROM bgerp_t_default.atelier_job_task) as original,
    (SELECT COUNT(*) FROM bgerp_archive_linear.archived_job_task) as archived;
```

---

### **Phase 4: Remove Linear Code (2-3 days)**

**Step 4.1: Database Cleanup**
```sql
-- ⚠️ DANGEROUS - Backup first!

-- Drop Linear tables (tenant DB)
DROP TABLE IF EXISTS atelier_task_operator_session;
DROP TABLE IF EXISTS atelier_wip_log;
DROP TABLE IF EXISTS atelier_job_task;

-- Remove routing_mode column (no longer needed)
ALTER TABLE atelier_job_ticket DROP COLUMN routing_mode;

-- Clean up indexes
-- (no longer needed after table drops)
```

**Step 4.2: Remove Backend Code**
```bash
# Remove or comment out Linear-specific functions
# Files to modify:
# - source/atelier_job_ticket.php (Linear task APIs)
# - source/pwa_scan_api.php (getJobTasksByTicket, lookupJobTask)
# - source/service/OperatorSessionService.php (task-based logic)
# - source/service/JobTicketStatusService.php (task status updates)
```

**Step 4.3: Remove Frontend Code**
```javascript
// Remove from pwa_scan.js
// - renderLinearView() function
// - submitLinearEvent() function
// - task dropdowns
// - task-related UI elements

// Keep only:
// - renderDAGView()
// - submitDAGEvent()
```

**Step 4.4: Update Documentation**
```bash
# Archive old docs
mkdir docs/archive/2026-q3-linear-removal
mv docs/*LINEAR*.md docs/archive/2026-q3-linear-removal/

# Update references
grep -r "Linear" docs/ | grep -v archive
# Update each file to remove Linear references
```

---

### **Phase 5: Testing & Verification (1 week)**

**Step 5.1: Smoke Tests**
```bash
# Test DAG job creation
# Test token spawn
# Test token movement
# Test PWA scanning
# Test operator workflows
```

**Step 5.2: Performance Check**
```sql
-- Compare query performance before/after
EXPLAIN SELECT * FROM flow_token WHERE id_instance = 1;
-- Should be faster without routing overhead
```

**Step 5.3: User Acceptance Testing**
- Get 5-10 operators to test
- Verify all workflows still work
- Collect feedback

---

## 🔄 **Rollback Plan (If Removal Fails)**

**If critical issues found after removal:**

### **Emergency Rollback Steps:**

1. **Stop all production work** (emergency only)

2. **Restore Linear tables from archive:**
```sql
USE bgerp_t_default;

CREATE TABLE atelier_job_task LIKE bgerp_archive_linear.archived_job_task;
CREATE TABLE atelier_wip_log LIKE bgerp_archive_linear.archived_wip_log;
CREATE TABLE atelier_task_operator_session LIKE bgerp_archive_linear.archived_operator_session;

INSERT INTO atelier_job_task SELECT * FROM bgerp_archive_linear.archived_job_task;
INSERT INTO atelier_wip_log SELECT * FROM bgerp_archive_linear.archived_wip_log;
INSERT INTO atelier_task_operator_session SELECT * FROM bgerp_archive_linear.archived_operator_session;

ALTER TABLE atelier_job_ticket ADD COLUMN routing_mode ENUM('linear', 'dag') DEFAULT 'dag';
```

3. **Restore code from Git:**
```bash
git revert <commit_hash_of_removal>
git push
```

4. **Notify users:**
- "Temporarily restored Linear system"
- "We are investigating issues with DAG"

---

## 📊 **Success Metrics After Removal**

| Metric | Target | Measurement |
|--------|--------|-------------|
| Code lines removed | >2000 lines | `git diff --stat` |
| Database size reduction | >30% | `SHOW TABLE STATUS` |
| API response time | <50ms | Load testing |
| User complaints | 0 critical | Support tickets |
| System uptime | 99.9%+ | Monitoring |

---

## 📝 **Post-Removal Documentation**

### **Update These Files:**
- [x] `README.md` - Remove Linear references
- [x] `docs/DATABASE_SCHEMA_REFERENCE.md` - Remove Linear tables
- [x] `docs/SERVICE_API_REFERENCE.md` - Remove Linear APIs
- [x] `docs/USER_MANUAL.md` - Remove Linear workflows
- [x] `STATUS.md` - Update system state
- [x] `CHANGELOG_*.md` - Document removal

### **Create New Archive:**
- `docs/archive/LINEAR_SYSTEM_HISTORY.md` - Historical reference
- `docs/archive/LINEAR_TO_DAG_MIGRATION.md` - Migration story
- `docs/archive/LESSONS_LEARNED.md` - What we learned

---

## 🎓 **Lessons for Future AI Agents**

### **Key Takeaways:**

1. **Dual-mode was intentional safety net**
   - Not a permanent architecture
   - Designed for safe migration
   - Always had removal plan

2. **Migration takes 6-12 months**
   - Don't rush deprecation
   - Users need time to adapt
   - System needs stability proof

3. **Always archive before deletion**
   - Regulatory compliance
   - Historical analysis
   - Emergency rollback

4. **Communicate early & often**
   - Warn users months in advance
   - Provide migration guides
   - Offer training sessions

---

## ⏰ **Timeline Summary**

| Phase | Duration | Start | End |
|-------|----------|-------|-----|
| 1. Deprecation Warning | 1 week | 2026-06-01 | 2026-06-07 |
| 2. Job Conversion | 4 weeks | 2026-06-08 | 2026-07-05 |
| 3. Data Archive | 1 week | 2026-07-06 | 2026-07-12 |
| 4. Code Removal | 3 days | 2026-07-13 | 2026-07-15 |
| 5. Testing | 1 week | 2026-07-16 | 2026-07-22 |
| **Total** | **7 weeks** | | |

---

**Last Updated:** November 2, 2025  
**Next Review:** After DAG proves stable (Q2 2026)  
**Owner:** System Architect / Tech Lead


# Phase 2: Team Integration - Deployment Guide

**Version:** 1.0  
**Date:** November 6, 2025  
**Target:** Production Deployment

---

## ✅ **Pre-Deployment Checklist**

### **1. Database Backup**
```bash
# Backup all tenant databases
mysqldump -u root -p bgerp_t_default > backup_default_$(date +%Y%m%d).sql
mysqldump -u root -p bgerp_t_maison_atelier > backup_maison_$(date +%Y%m%d).sql
```

### **2. Code Review**
- ✅ All tests passed (10/10 unit tests)
- ✅ No PHP syntax errors
- ✅ JavaScript linted
- ✅ No console.log() in production code
- ✅ Configuration reviewed

### **3. Server Requirements**
- PHP 7.4+ (7.4 or 8.0+ recommended)
- MySQL 5.7+ or MariaDB 10.3+
- 512MB RAM minimum (1GB+ recommended)
- Modern browser support (Chrome 90+, Firefox 88+, Safari 14+)

---

## 🚀 **Deployment Steps**

### **Step 1: Pull Latest Code**

```bash
cd /Applications/MAMP/htdocs/bellavier-group-erp

# If using Git
git pull origin main

# Verify files
ls -la source/config/assignment_config.php
ls -la source/BGERP/Service/TeamExpansionService.php  # ปัจจุบันเก็บโค้ดหลัก (ไฟล์ใน source/service/ เป็น shim)
ls -la database/tenant_migrations/2025_11_team_integration.php
```

### **Step 2: Run Database Migration**

```bash
# Check current migration status
php -r "
require 'config.php';
\$db = tenant_db('DEFAULT');
\$result = \$db->query('SELECT migration FROM tenant_migrations ORDER BY applied_at DESC LIMIT 5');
while(\$row = \$result->fetch_assoc()) { echo \$row['migration'] . \"\\n\"; }
"

# Run migration for all tenants
php database/tools/run_migrations.php

# Or manually for specific tenant
php -r "
require 'config.php';
require 'database/tools/migration_helpers.php';
\$db = tenant_db('DEFAULT');
migration_run_php_migration(\$db, 'database/tenant_migrations/2025_11_team_integration.php', 'tenant_migrations', 'migration');
"
```

**Expected Output:**
```
=== Phase 2: Team Integration Schema ===
[1/4] Extending team_member table...
[2/4] Creating assignment_decision_log table...
[3/4] Creating member_leave table...
[4/4] Adding performance indexes...
✅ Phase 2 schema migration completed successfully!
```

### **Step 3: Verify Database Schema**

```bash
php -r "
require 'config.php';
\$db = tenant_db('DEFAULT');

// Check tables exist
\$tables = ['assignment_decision_log', 'member_leave'];
foreach(\$tables as \$table) {
    \$result = \$db->query(\"SHOW TABLES LIKE '\$table'\");
    echo \$table . ': ' . ((\$result && \$result->num_rows > 0) ? '✅ EXISTS' : '❌ MISSING') . \"\\n\";
}

// Check team_member columns
echo \"\\nteam_member columns:\\n\";
\$result = \$db->query('DESCRIBE team_member');
while(\$row = \$result->fetch_assoc()) {
    echo '  - ' . \$row['Field'] . ' (' . \$row['Type'] . \")\\n\";
}
"
```

**Expected Output:**
```
assignment_decision_log: ✅ EXISTS
member_leave: ✅ EXISTS

team_member columns:
  - id_team (int(11))
  - id_member (int(11))
  - role (enum)
  - capacity_per_day (decimal(10,2))
  - sort_priority (tinyint(4))
  - unavailable_from (datetime)
  - unavailable_until (datetime)
  - active (tinyint(1))
```

### **Step 4: Test Backend APIs**

```bash
# Test workload_summary endpoint
curl -X GET "http://localhost/source/team_api.php?action=workload_summary&team_id=1" \
  --cookie "PHPSESSID=your_session" | jq

# Test workload_summary_all endpoint
curl -X GET "http://localhost/source/team_api.php?action=workload_summary_all" \
  --cookie "PHPSESSID=your_session" | jq

# Test assignment_preview endpoint
curl -X GET "http://localhost/source/team_api.php?action=assignment_preview&team_id=1" \
  --cookie "PHPSESSID=your_session" | jq
```

**Expected:** All endpoints should return `{"ok": true, ...}`

### **Step 5: Clear Cache**

```bash
# If using OPcache
sudo systemctl reload php-fpm

# Or restart Apache/Nginx
sudo systemctl restart apache2
# or
sudo systemctl restart nginx
```

### **Step 6: Test Frontend**

1. **Open Manager Assignment page**
   - URL: `http://localhost/manager_assignment.php`
   - Verify team dropdown appears in "Bulk Assign" modal
   - Check workload indicators show (🟢 🟡 🔴)

2. **Test Team Assignment**
   - Select 1-2 tokens
   - Click "Bulk Assign"
   - Select a team from dropdown
   - Verify preview modal shows
   - Click "Yes, assign"
   - Verify success message

3. **Open Team Management page**
   - URL: `http://localhost/team_management.php`
   - Verify workload indicators appear on team cards
   - Click a team → verify drawer opens
   - Check member availability display

### **Step 7: Run Automated Tests**

```bash
# Run unit tests
php tests/phase2/TeamExpansionServiceTest.php

# Expected: 10/10 PASSED
```

### **Step 8: Monitor Logs**

```bash
# Watch PHP error log
tail -f /var/log/apache2/error.log
# or
tail -f /var/log/php-fpm/error.log

# Watch MySQL slow query log (if enabled)
tail -f /var/log/mysql/mysql-slow.log
```

---

## 🔧 **Configuration**

### **Assignment Config (Optional)**

Edit `source/config/assignment_config.php`:

```php
// Change load balancing mode
public const LOAD_BALANCING_MODE = 'least_loaded';
// Options: 'round_robin', 'least_loaded', 'priority_weighted'

// Adjust overload threshold
public const OVERLOADED_THRESHOLD_TOKENS = 5;  // Show warning at 5+ tokens

// Decision log retention
public const DECISION_LOG_RETENTION_DAYS = 90;  // Keep 90 days
```

**⚠️ Important:** Clear OPcache after config changes!

---

## 🐛 **Troubleshooting**

### **Issue: Migration fails with "Table already exists"**

**Solution:**
```bash
# Check if tables exist
php -r "
require 'config.php';
\$db = tenant_db('DEFAULT');
\$result = \$db->query('SHOW TABLES LIKE \"assignment_decision_log\"');
echo (\$result && \$result->num_rows > 0) ? 'Exists' : 'Not found';
"

# If exists, mark migration as applied
php -r "
require 'config.php';
\$db = tenant_db('DEFAULT');
\$db->query(\"INSERT IGNORE INTO tenant_migrations (migration, applied_at) VALUES ('2025_11_team_integration', NOW())\");
echo 'Migration marked as applied';
"
```

### **Issue: Workload shows as 0 for all teams**

**Causes:**
1. No active tokens in system
2. No members in teams
3. API endpoint not accessible

**Debug:**
```bash
# Check team membership
php -r "
require 'config.php';
\$db = tenant_db('DEFAULT');
\$result = \$db->query('SELECT id_team, COUNT(*) as cnt FROM team_member WHERE active=1 GROUP BY id_team');
while(\$row = \$result->fetch_assoc()) {
    echo \"Team \" . \$row['id_team'] . \": \" . \$row['cnt'] . \" members\\n\";
}
"

# Check active tokens
php -r "
require 'config.php';
\$db = tenant_db('DEFAULT');
\$result = \$db->query(\"SELECT COUNT(*) as cnt FROM token_assignment WHERE status IN ('assigned','started','paused')\");
\$row = \$result->fetch_assoc();
echo \"Active assignments: \" . \$row['cnt'] . \"\\n\";
"
```

### **Issue: Team dropdown doesn't appear**

**Solutions:**
1. Clear browser cache (Ctrl+Shift+R)
2. Check JavaScript console for errors
3. Verify `team_api.php` is accessible
4. Check permissions (`manager.team` required)

### **Issue: Assignment fails with "No available members"**

**Causes:**
1. All members marked unavailable
2. All members on leave
3. Production mode mismatch (OEM team assigned to Hatthasilpa job)

**Check:**
```bash
php -r "
require 'config.php';
require 'source/BGERP/Service/TeamExpansionService.php';
\$db = tenant_db('DEFAULT');
\$service = new \BGERP\Service\TeamExpansionService(\$db);
try {
    \$result = \$service->expandTeamToMembers(1, 'hatthasilpa');
    echo \"Available: \" . \$result['available_count'] . \"/\" . \$result['total_count'] . \"\\n\";
    foreach(\$result['members'] as \$m) {
        \$status = \$m['is_available'] ? '✅' : '❌';
        echo \"  \$status \" . \$m['name'] . \" (load: \" . \$m['current_load'] . \")\\n\";
    }
} catch (Exception \$e) {
    echo 'Error: ' . \$e->getMessage() . \"\\n\";
}
"
```

---

## 📊 **Post-Deployment Monitoring**

### **Day 1-3: Watch closely**

Monitor:
- ✅ API response times (should be < 500ms)
- ✅ Assignment success rate (should be > 95%)
- ✅ Decision log growth (should be 1 record per assignment)
- ✅ Browser console errors (should be 0)

**Query Performance:**
```sql
-- Check decision log size
SELECT COUNT(*) FROM assignment_decision_log;

-- Check average workload
SELECT 
    t.name,
    COUNT(ta.id_assignment) as total_assignments,
    COUNT(DISTINCT tm.id_member) as members,
    COUNT(ta.id_assignment) / COUNT(DISTINCT tm.id_member) as avg_per_member
FROM team t
JOIN team_member tm ON tm.id_team = t.id_team AND tm.active = 1
LEFT JOIN token_assignment ta ON ta.assigned_to_user_id = tm.id_member 
    AND ta.status IN ('assigned','started','paused')
GROUP BY t.id_team;
```

### **Week 1: Validate load balancing**

```sql
-- Check assignment distribution
SELECT 
    a.name,
    COUNT(ta.id_assignment) as assignments,
    MAX(ta.assigned_at) as last_assignment
FROM account a
JOIN token_assignment ta ON ta.assigned_to_user_id = a.id_member
WHERE ta.assigned_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY a.id_member
ORDER BY assignments DESC;
```

**Expected:** Distribution should be fairly even (within ±20%)

### **Month 1: Review decision logs**

```sql
-- Top decision reasons
SELECT 
    decision_reason,
    COUNT(*) as count
FROM assignment_decision_log
WHERE decided_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY decision_reason
ORDER BY count DESC
LIMIT 10;
```

---

## 🗑️ **Rollback Plan**

If critical issues arise:

### **1. Stop new assignments**
```php
// In assignment_config.php, temporarily disable
public const ENABLE_DECISION_LOGGING = false;

// Or redirect team assignments to manual
// (Remove team options from UI temporarily)
```

### **2. Restore database (if needed)**
```bash
# Restore from backup
mysql -u root -p bgerp_t_default < backup_default_20251106.sql

# Mark migration as not applied
php -r "
require 'config.php';
\$db = tenant_db('DEFAULT');
\$db->query(\"DELETE FROM tenant_migrations WHERE migration='2025_11_team_integration'\");
"
```

### **3. Revert code**
```bash
# If using Git
git revert <commit-hash>
git push origin main

# Or manually remove files
mv source/config/assignment_config.php source/config/assignment_config.php.bak
mv source/BGERP/Service/TeamExpansionService.php source/BGERP/Service/TeamExpansionService.php.bak  # ปรับเป็นขั้นตอนใหม่หากต้องสำรอง (shim เดิมอยู่ที่ source/service/)
```

---

## ✅ **Success Criteria**

Phase 2 is successfully deployed when:

- ✅ Migration completed on all tenants
- ✅ All 10 unit tests pass
- ✅ Team dropdown appears in Manager Assignment
- ✅ Workload indicators show real-time data
- ✅ Team assignment works end-to-end
- ✅ Decision logs are created
- ✅ No JavaScript errors in console
- ✅ No PHP errors in logs
- ✅ API response times < 500ms
- ✅ Manager feedback is positive

---

## 📞 **Support Contacts**

| Role | Contact | Availability |
|------|---------|--------------|
| Lead Developer | - | 24/7 |
| DBA | - | Mon-Fri 9-18:00 |
| DevOps | - | Mon-Fri 9-18:00 |

---

## 📚 **Related Documentation**

- User Guide: `PHASE2_USER_GUIDE.md`
- API Reference: `PHASE2_API_REFERENCE.md`
- Technical Spec: `PHASE2_TEAM_INTEGRATION_DETAILED_PLAN.md`

---

**End of Deployment Guide**

**Good luck with the deployment! 🚀**


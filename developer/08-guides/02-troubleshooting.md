# 🔧 Troubleshooting Guide - Bellavier Group ERP

**For:** Production Schedule System + Permission System  
**Last Updated:** October 27, 2025

---

## 🚨 Common Issues & Solutions

### **1. "Failed to load schedule" Error**

**Symptoms:**
- Red alert at top of page
- Calendar empty
- Summary shows "-"

**Causes & Solutions:**

#### **A. Browser Cache**
```bash
# Solution:
1. Clear browser cache (Ctrl+Shift+Delete)
2. Hard refresh (Ctrl+Shift+R or Cmd+Shift+R)
3. Try incognito/private window
```

#### **B. JavaScript Not Loaded**
```bash
# Check:
1. Open DevTools (F12)
2. Network tab
3. Look for schedule.js → should be Status 200

# If 404:
Check file exists: assets/javascripts/atelier/schedule.js
Check page config: page/atelier_schedule.php includes schedule.js
```

#### **C. API Returns "unauthorized"**
```bash
# Check:
1. DevTools → Network → atelier_schedule.php
2. Response tab → should see {"ok":true,...}

# If {"ok":false,"error":"unauthorized"}:
- Check: User is logged in
- Check: PHPSESSID cookie is sent
- Check: Session is active

# Solution:
Logout and login again
```

#### **D. Permission Denied**
```bash
# Check permissions:
php -r "
require_once 'config.php';
require_once 'source/permission.php';

\$member = ['id_member' => 1]; // Your user ID
\$_SESSION['current_org_code'] = 'maison_atelier';

\$hasView = permission_allow_code(\$member, 'schedule.view');
echo 'schedule.view: ' . (\$hasView ? 'YES ✅' : 'NO ❌') . \"\\n\";
"

# If NO:
Run: php tools/sync_permissions_to_tenants.php
Then assign in Admin UI
```

---

### **2. Permissions Not Showing in Admin UI**

**Symptoms:**
- Click "ดู" on role → shows empty list
- Shows "[]" or 0 permissions

**Causes & Solutions:**

#### **A. Permission Table Missing**
```bash
# Check:
php -r "
\$tenantDb = tenant_db('maison_atelier');
\$res = \$tenantDb->query('SHOW TABLES LIKE \"permission\"');
echo 'Permission table exists: ' . (\$res->num_rows > 0 ? 'YES' : 'NO') . \"\\n\";
"

# If NO:
php tools/sync_permissions_to_tenants.php
```

#### **B. Permission ID Mismatch**
```bash
# Check:
php -r "
\$coreDb = core_db();
\$tenantDb = tenant_db('maison_atelier');

\$coreId = \$coreDb->query(\"SELECT id_permission FROM permission WHERE code='dashboard.view'\")->fetch_assoc()['id_permission'];
\$tenantId = \$tenantDb->query(\"SELECT id_permission FROM permission WHERE code='dashboard.view'\")->fetch_assoc()['id_permission'];

echo \"Core ID: \$coreId\\n\";
echo \"Tenant ID: \$tenantId\\n\";
echo \"Match: \" . (\$coreId === \$tenantId ? 'NO PROBLEM' : 'MISMATCH!') . \"\\n\";
"

# If MISMATCH (expected - different DBs):
This is normal! Permission assignment uses CODE mapping, not ID
Check that admin_rbac.php uses code-based mapping
```

#### **C. Role Not Synced**
```bash
# Check:
php -r "
\$tenantDb = tenant_db('maison_atelier');
\$count = \$tenantDb->query('SELECT COUNT(*) as cnt FROM tenant_role')->fetch_assoc()['cnt'];
echo \"Tenant roles: \$count (should be 23)\\n\";
"

# If less than 23:
Run sync script (check sync_permissions_to_tenants.php)
```

---

### **3. "Permission Denied" on Admin Pages**

**Symptoms:**
- Can't access Admin → Roles & Permissions
- 403 Forbidden error

**Causes & Solutions:**

#### **A. User Not Admin**
```bash
# Check user role:
php -r "
\$coreDb = core_db();
\$member_id = 1; // Your user ID
\$org_code = 'maison_atelier';

\$org = fetch_org_by_code(\$org_code);
\$res = \$coreDb->query(\"SELECT ag.group_name 
    FROM account_org ao
    JOIN account_group ag ON ag.id_group = ao.id_group
    WHERE ao.id_member = \$member_id AND ao.id_org = \" . \$org['id_org']);

\$role = \$res->fetch_assoc()['group_name'];
echo \"Your role: \$role\\n\";
echo \"Is admin: \" . (in_array(\$role, ['owner', 'admin']) ? 'YES' : 'NO') . \"\\n\";
"

# If NO:
Contact tenant owner to assign admin role
```

#### **B. Missing Permissions**
```bash
# Assign admin permissions:
1. Login as owner
2. Admin → Roles & Permissions
3. Select your role
4. Check: org.user.manage, org.role.assign
5. Save
```

---

### **4. Drag & Drop Not Working**

**Symptoms:**
- Can't drag MO on calendar
- MO doesn't move

**Causes & Solutions:**

#### **A. No Edit Permission**
```bash
# Check:
window.CAN_EDIT_SCHEDULE  (in browser console)

# If false:
Assign schedule.edit permission to your role
```

#### **B. MO is Completed**
```
Completed MO cannot be edited (by design)
Change status to 'in_progress' if testing
```

#### **C. JavaScript Error**
```bash
# Check console:
F12 → Console tab
Look for errors

# Common:
- FullCalendar not loaded
- jQuery not loaded
```

---

### **5. Auto-arrange Not Working**

**Symptoms:**
- Button doesn't respond
- No changes after click

**Causes & Solutions:**

#### **A. No Permission**
```bash
# Check schedule.auto_arrange permission
Assign to your role if missing
```

#### **B. Feature Disabled**
```sql
-- Check config:
SELECT config_value FROM production_schedule_config 
WHERE config_key = 'enable_auto_arrange';

-- If '0' (disabled):
UPDATE production_schedule_config 
SET config_value = '1' 
WHERE config_key = 'enable_auto_arrange';
```

#### **C. No MO to Arrange**
```bash
# All MO need due_date for auto-arrange
UPDATE mo SET due_date = '2025-11-30' WHERE due_date IS NULL;
```

---

### **6. Capacity Shows "-" or 0%**

**Symptoms:**
- Capacity average shows "-"
- Chart doesn't render

**Causes & Solutions:**

#### **A. No Scheduled MO**
```sql
-- MO must have scheduled_start_date and scheduled_end_date
SELECT COUNT(*) FROM mo 
WHERE scheduled_start_date IS NOT NULL 
AND scheduled_end_date IS NOT NULL;

-- If 0: Schedule some MO first (drag & drop or auto-arrange)
```

#### **B. Chart.js Error**
```bash
# Check console for:
"ctx.getContext is not a function"

# This is cosmetic when no data
# Will auto-fix when MO are scheduled
```

#### **C. Wrong Capacity Mode**
```sql
-- Check mode:
SELECT config_value FROM production_schedule_config 
WHERE config_key = 'capacity_mode';

-- Should be: 'simple' (for Phase 1)
-- If different, update:
UPDATE production_schedule_config 
SET config_value = 'simple' 
WHERE config_key = 'capacity_mode';
```

---

### **7. Migration Failed**

**Symptoms:**
- Error when running migration
- Tables not created

**Causes & Solutions:**

#### **A. SQL Syntax Error**
```bash
# Check error message carefully
# Common: Missing column (e.g., due_date)

# Solution: Run migration for correct tenant
php tools/run_tenant_migrations.php maison_atelier
```

#### **B. Table Already Exists**
```bash
# Migrations are idempotent
# Can run multiple times safely
# "Table already exists" is not an error
```

#### **C. Permission Denied**
```bash
# Check MySQL user permissions
GRANT ALL ON bgerp_t_*.* TO 'your_user'@'localhost';
FLUSH PRIVILEGES;
```

---

### **8. MO Not Appearing on Calendar**

**Symptoms:**
- Created MO but not visible on calendar

**Checklist:**

```sql
-- 1. MO must have schedule dates OR due_date
SELECT id_mo, mo_code, scheduled_start_date, scheduled_end_date, due_date 
FROM mo 
WHERE id_mo = YOUR_MO_ID;

-- 2. MO status must not be completed/done/cancelled
SELECT id_mo, mo_code, status FROM mo WHERE id_mo = YOUR_MO_ID;

-- 3. MO must be in current month view
-- Check: scheduled dates fall within calendar view range

-- 4. Filter not hiding it
-- Check: Filter status = "All" or matches MO status
-- Check: "Show Completed" checked if status is completed
```

**Quick Fix:**
```sql
-- Add schedule to MO:
UPDATE mo SET 
    scheduled_start_date = '2025-10-28',
    scheduled_end_date = '2025-11-01',
    is_scheduled = 1
WHERE id_mo = YOUR_MO_ID;
```

---

## 🔍 Debugging Tools

### **1. Check Session:**
```php
// Add to any PHP file:
echo '<pre>';
print_r($_SESSION);
echo '</pre>';

// Check:
- $_SESSION['login'] = 1
- $_SESSION['member']['id_member'] exists
- $_SESSION['current_org_code'] set
```

---

### **2. Check Permissions:**
```bash
php -r "
require_once 'config.php';
require_once 'source/permission.php';

\$member = ['id_member' => 1];
\$_SESSION['current_org_code'] = 'maison_atelier';

\$perms = get_user_permission_codes(\$member);
echo 'Total permissions: ' . count(\$perms) . \"\\n\";
echo 'Has schedule.view: ' . (in_array('schedule.view', \$perms) ? 'YES' : 'NO') . \"\\n\";
"
```

---

### **3. Check Database Connection:**
```bash
php -r "
require_once 'config.php';

\$coreDb = core_db();
\$tenantDb = tenant_db('maison_atelier');

echo 'Core DB: ' . (\$coreDb ? 'Connected ✅' : 'Failed ❌') . \"\\n\";
echo 'Tenant DB: ' . (\$tenantDb ? 'Connected ✅' : 'Failed ❌') . \"\\n\";
"
```

---

### **4. Check API Endpoints:**
```bash
# Test event_list API:
curl -s "http://localhost:8888/bellavier-group-erp/source/atelier_schedule.php?action=event_list&start=2025-10-01&end=2025-10-31" \
  -H "Cookie: PHPSESSID=YOUR_SESSION_ID" | jq .

# Should return: {"ok":true,"events":[...]}
# If unauthorized: Session expired or invalid
```

---

## 📞 Getting Help

### **Self-Service:**
1. Check this troubleshooting guide
2. Check browser console (F12 → Console)
3. Check Network tab (F12 → Network)
4. Check PHP error logs

### **Escalation:**

**For Technical Issues:**
- Review logs: `/var/log/apache2/error.log`
- Check database: Run diagnostic queries above
- Document: URL, user role, error message, screenshots

**For Permission Issues:**
- Check: Admin → Roles & Permissions
- Verify: User has required permissions
- Re-sync: `php tools/sync_permissions_to_tenants.php`

---

## 📊 Diagnostic Queries

### **Quick Health Check:**

```sql
-- 1. Count permissions
SELECT 
    (SELECT COUNT(*) FROM bgerp.permission) as core_perms,
    (SELECT COUNT(*) FROM bgerp_t_maison_atelier.permission) as tenant_perms,
    (SELECT COUNT(*) FROM bgerp_t_maison_atelier.tenant_role) as tenant_roles;

-- Expected: 93, 93, 23

-- 2. Count scheduled MO
SELECT 
    COUNT(*) as total_mo,
    SUM(CASE WHEN is_scheduled = 1 THEN 1 ELSE 0 END) as scheduled,
    SUM(CASE WHEN is_scheduled = 0 THEN 1 ELSE 0 END) as unscheduled
FROM mo;

-- 3. Check schedule changes
SELECT COUNT(*) as changes_today
FROM schedule_change_log
WHERE DATE(changed_at) = CURDATE();
```

---

## ⚡ Quick Fixes

### **Reset Schedule:**
```sql
-- Clear all schedules (for testing):
UPDATE mo SET 
    scheduled_start_date = NULL,
    scheduled_end_date = NULL,
    is_scheduled = 0;

DELETE FROM schedule_change_log;
```

---

### **Reset Permissions:**
```bash
# Re-sync all permissions:
php tools/sync_permissions_to_tenants.php

# Re-assign from templates:
php -r "
require_once 'config.php';
\$coreDb = core_db();
\$tenants = ['DEFAULT', 'maison_atelier'];

foreach (\$tenants as \$org) {
    \$tenantDb = tenant_db(\$org);
    
    // Delete all assignments
    \$tenantDb->query('DELETE FROM tenant_role_permission');
    
    // Re-copy from templates
    // (run full script from earlier conversation)
}
"
```

---

### **Recreate Config:**
```sql
-- If production_schedule_config missing:
CREATE TABLE IF NOT EXISTS production_schedule_config (
    id_config INT AUTO_INCREMENT PRIMARY KEY,
    config_key VARCHAR(100) NOT NULL UNIQUE,
    config_value TEXT,
    description VARCHAR(255),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

INSERT INTO production_schedule_config (config_key, config_value, description) VALUES
('capacity_mode', 'simple', 'Capacity calculation mode: simple, work_center, skill_based'),
('use_routing_std_time', '1', 'Calculate MO duration from routing STD time'),
('default_work_hours', '8', 'Default work hours per day'),
('work_days', 'mon,tue,wed,thu,fri,sat', 'Working days'),
('daily_capacity_simple', '10', 'Daily MO capacity for simple mode'),
('enable_auto_arrange', '1', 'Enable auto-arrange feature'),
('schedule_horizon_days', '90', 'Schedule planning horizon in days');
```

---

## 🔥 Emergency Procedures

### **System Completely Broken:**

```bash
# 1. Restore from backup
mysql -u root -p bgerp_t_maison_atelier < backup_tenant_YYYYMMDD.sql

# 2. Verify
php -r "
\$tenantDb = tenant_db('maison_atelier');
echo 'Connected: ' . (\$tenantDb ? 'YES' : 'NO') . \"\\n\";
"

# 3. Re-run migrations
php tools/run_tenant_migrations.php maison_atelier

# 4. Re-sync permissions
php tools/sync_permissions_to_tenants.php

# 5. Test in browser
```

---

### **Data Corruption:**

```sql
-- Check referential integrity:
SELECT m.id_mo, m.mo_code 
FROM mo m
LEFT JOIN product p ON p.id_product = m.id_product
WHERE p.id_product IS NULL;

-- If rows found: orphaned MO (product deleted)
-- Fix: Set to default product or delete MO
```

---

## 📝 Log Files

### **Apache/Nginx:**
```bash
# Apache:
tail -f /var/log/apache2/error.log

# Nginx:
tail -f /var/log/nginx/error.log
```

### **PHP:**
```bash
# Check php.ini for error_log location
php -i | grep error_log

# Tail it:
tail -f /path/to/php_error.log
```

### **Application:**
```bash
# Check error_log() calls in code:
grep -r "error_log" source/

# Custom logs:
tail -f /tmp/bellavier_erp.log  # If configured
```

---

## 🎯 Prevention

### **Best Practices:**

1. **Before Making Changes:**
   - Backup database
   - Test in staging first
   - Document changes

2. **Regular Maintenance:**
   - Clear browser cache weekly
   - Review error logs daily
   - Run health checks monthly

3. **Permission Management:**
   - Use templates for new roles
   - Sync permissions after adding features
   - Document custom permissions

---

## ✅ Verification Checklist

After any fix, verify:

- [ ] Login works
- [ ] Dashboard loads
- [ ] Navigate to Production Schedule
- [ ] Calendar shows MO
- [ ] Summary calculates correctly
- [ ] Admin pages accessible
- [ ] Permissions display correctly
- [ ] No console errors (F12)

---

## 📞 Support

**If issue persists after troubleshooting:**

1. **Collect Information:**
   - URL where error occurs
   - User role (owner/admin/etc.)
   - Browser (Chrome/Firefox/Safari)
   - Error message (exact text)
   - Screenshots (DevTools Network + Console)

2. **Check Documentation:**
   - PERMISSION_MANAGEMENT_GUIDE.md
   - PRODUCTION_SCHEDULE_USER_GUIDE.md
   - SYSTEM_ARCHITECTURE.md

3. **Create Issue Report:**
   - Date/time of issue
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment (dev/staging/production)

---

## 🎊 Summary

**Most Common Issues:**
1. Browser cache → Clear cache
2. Permissions not synced → Run sync script
3. Session expired → Logout/login

**Prevention:**
- Regular maintenance
- Use provided tools
- Follow documentation

**Recovery:**
- Backup exists
- Migrations reversible
- Tools available

**Status:** 🟢 **System is stable and well-supported**


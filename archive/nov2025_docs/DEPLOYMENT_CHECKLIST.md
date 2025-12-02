# 🚀 Deployment Checklist - Production Schedule System

**Target:** Production Environment  
**Date:** Ready for deployment  
**Version:** Phase 1 (MVP)

---

## ✅ Pre-Deployment Verification

### **1. Database Verification** ✅

```bash
# Check if migrations completed
php tools/run_tenant_migrations.php maison_atelier

# Expected: "All migrations up to date"
```

**Verify tables exist:**
- [x] `production_schedule_config`
- [x] `schedule_change_log`
- [x] `permission` (in tenant DB)
- [x] `tenant_role`
- [x] `tenant_role_permission`

**Verify columns exist:**
- [x] `mo.scheduled_start_date`
- [x] `mo.scheduled_end_date`
- [x] `mo.lead_time_days`
- [x] `mo.is_scheduled`
- [x] `work_center.headcount`
- [x] `work_center.work_hours_per_day`

---

### **2. Permission Verification** ✅

```bash
# Check permissions synced
php -r "
require_once 'config.php';
\$tenantDb = tenant_db('maison_atelier');
\$count = \$tenantDb->query('SELECT COUNT(*) as cnt FROM permission')->fetch_assoc()['cnt'];
echo \"Permissions: \$count (should be 93)\\n\";
"
```

**Expected:**
- [x] 93 permissions in tenant DB
- [x] 4 schedule permissions exist
- [x] All roles have appropriate assignments

---

### **3. Code Verification** ✅

**Files exist:**
- [x] `source/atelier_schedule.php`
- [x] `source/service/ScheduleService.php`
- [x] `source/service/CapacityCalculator.php`
- [x] `page/atelier_schedule.php`
- [x] `views/atelier_schedule.php`
- [x] `assets/javascripts/hatthasilpa/schedule.js`
- [x] `assets/stylesheets/hatthasilpa/schedule.css`

**Routes configured:**
- [x] `index.php` includes `'atelier_schedule' => 'atelier_schedule.php'`

---

### **4. Browser Testing** ✅

**Test in browser:**
- [x] Login successful
- [x] Navigate to Manufacturing → Production Schedule
- [x] Calendar renders
- [x] MO displays correctly
- [x] Summary panel shows stats
- [x] No console errors (except minor cosmetic)

---

## 📋 Deployment Steps

### **Step 1: Backup** (5 minutes)

```bash
# Backup databases
mysqldump -u root -p bgerp > backup_core_$(date +%Y%m%d).sql
mysqldump -u root -p bgerp_t_maison_atelier > backup_tenant_$(date +%Y%m%d).sql

# Backup code
tar -czf backup_code_$(date +%Y%m%d).tar.gz /path/to/bellavier-group-erp
```

---

### **Step 2: Deploy Code** (10 minutes)

```bash
# Option A: Git deployment (if using git)
git add .
git commit -m "feat: Production Schedule System Phase 1 + Permission Refactor"
git push origin main

# On production server:
git pull origin main

# Option B: Manual deployment
# 1. Upload files via FTP/SFTP
# 2. Ensure file permissions are correct (755 for dirs, 644 for files)
```

---

### **Step 3: Run Migrations** (5 minutes)

```bash
# On production server:
cd /path/to/bellavier-group-erp

# Run for each tenant
php tools/run_tenant_migrations.php DEFAULT
php tools/run_tenant_migrations.php maison_atelier

# Expected output:
# ✅ Running migration: 2025_01_schedule_system
# ✅ Migration completed successfully
```

---

### **Step 4: Sync Permissions** (2 minutes)

```bash
# Sync all permissions from core to tenants
php tools/sync_permissions_to_tenants.php

# Expected output:
# ✅ Synced 93 permissions to DEFAULT
# ✅ Synced 93 permissions to maison_atelier
```

---

### **Step 5: Verify Deployment** (10 minutes)

**Database Verification:**
```bash
# Check tables exist
php -r "
require_once 'config.php';
\$tenantDb = tenant_db('maison_atelier');

\$tables = ['production_schedule_config', 'schedule_change_log', 'permission', 'tenant_role'];
foreach (\$tables as \$table) {
    \$res = \$tenantDb->query(\"SHOW TABLES LIKE '\$table'\");
    echo (\$res && \$res->num_rows > 0 ? '✅' : '❌') . \" \$table\\n\";
}
"
```

**Permission Verification:**
```bash
# Check permissions assigned
php -r "
require_once 'config.php';
\$tenantDb = tenant_db('maison_atelier');

\$res = \$tenantDb->query(\"SELECT code FROM permission WHERE code LIKE 'schedule.%'\");
while (\$row = \$res->fetch_assoc()) {
    echo '✅ ' . \$row['code'] . \"\\n\";
}
"
```

---

### **Step 6: Browser Testing** (10 minutes)

**Test Checklist:**

1. **Login**
   - [ ] User can login successfully
   - [ ] Session persists

2. **Navigation**
   - [ ] Manufacturing menu visible
   - [ ] Production Schedule link appears

3. **Schedule Page**
   - [ ] Calendar loads
   - [ ] No error alerts
   - [ ] Buttons visible (Auto-arrange, Check Conflicts, etc.)

4. **Data Display**
   - [ ] Existing MO appear on calendar
   - [ ] Summary panel shows correct stats
   - [ ] Filter works

5. **Interactions** (if applicable)
   - [ ] Can drag & drop MO
   - [ ] Can click Auto-arrange
   - [ ] Modals open correctly

---

### **Step 7: User Training** (15 minutes)

**Quick Training Session:**

1. **Show features:**
   - Calendar views (Month/Week/Day)
   - Filter & search
   - Summary panel

2. **Demonstrate:**
   - Drag & drop MO
   - Auto-arrange
   - Check conflicts
   - Find gaps

3. **Provide documentation:**
   - `docs/PRODUCTION_SCHEDULE_USER_GUIDE.md`
   - Quick reference card (if created)

---

## 🔄 Post-Deployment

### **Monitoring (First 7 days):**

```sql
-- Daily checks

-- 1. Schedule usage
SELECT COUNT(*) as changes_today
FROM schedule_change_log
WHERE DATE(changed_at) = CURDATE();

-- 2. Active scheduled MO
SELECT COUNT(*) as scheduled_mo
FROM mo
WHERE is_scheduled = 1 AND status NOT IN ('completed', 'done', 'cancelled');

-- 3. Permission system health
SELECT 
    (SELECT COUNT(*) FROM permission) as total_permissions,
    (SELECT COUNT(*) FROM tenant_role) as total_roles,
    (SELECT COUNT(*) FROM tenant_role_permission WHERE allow = 1) as total_assignments;
```

---

### **Performance Monitoring:**

**Metrics to track:**
- Page load time (target: < 2s)
- API response time (target: < 500ms)
- Database query time (target: < 100ms)
- User engagement (daily active users)

---

### **Issue Reporting:**

**If issues found:**

1. **Check logs:**
   ```bash
   tail -f /var/log/apache2/error.log  # Apache
   tail -f /var/log/nginx/error.log    # Nginx
   ```

2. **Check database:**
   ```sql
   SELECT * FROM schedule_change_log ORDER BY changed_at DESC LIMIT 10;
   ```

3. **Check browser console:**
   - F12 → Console tab
   - Look for JavaScript errors

4. **Contact support:**
   - Include: URL, user role, browser, error message
   - Attach: screenshots, console logs

---

## ✅ Post-Deployment Checklist

### **Day 1:**
- [ ] All users can access schedule page
- [ ] No critical errors reported
- [ ] Performance acceptable
- [ ] Data displaying correctly

### **Week 1:**
- [ ] Schedule being used actively
- [ ] No data corruption
- [ ] Permissions working correctly
- [ ] User feedback collected

### **Month 1:**
- [ ] Feature adoption measured
- [ ] Performance metrics reviewed
- [ ] User training effectiveness assessed
- [ ] Plan Phase 2 enhancements (if needed)

---

## 🎯 Success Criteria

**Deployment considered successful if:**

- ✅ Zero critical bugs
- ✅ System available 99%+ uptime
- ✅ All users can access features
- ✅ Performance targets met
- ✅ Positive user feedback

---

## 📊 Rollout Strategy

### **Option A: Big Bang** (Recommended for small team)
- Deploy to all users at once
- Quick training session (15 min)
- Monitor closely for first week

### **Option B: Phased Rollout**
- Week 1: Owner + Admin only
- Week 2: Production Manager + Planner
- Week 3: All users

**Recommendation for Bellavier:** **Option A** (small team, low risk)

---

## 🎉 Ready to Deploy!

**All checks passed:** ✅  
**Documentation complete:** ✅  
**Code tested:** ✅  
**Permissions configured:** ✅  

**Status:** 🟢 **APPROVED FOR PRODUCTION DEPLOYMENT**

**Deploy with confidence!** 🚀


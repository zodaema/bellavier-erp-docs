# 🚀 Serial Number System - Next Steps

**Last Updated:** November 9, 2025  
**Status:** ✅ Core Complete | ✅ Validation Complete | ✅ Hardening Complete

---

## 📋 Immediate Next Steps (Priority Order)

### **Step 1: Apply Feature Flags Migration** 🔴 **HIGH PRIORITY**

**Purpose:** Enable feature flags table for gradual rollout control

**Action:**
```bash
# Apply migration via Migration Wizard UI or CLI
php source/bootstrap_migrations.php --tenant=default
php source/bootstrap_migrations.php --tenant=maison_atelier
```

**Verify:**
```sql
-- Check table exists
SHOW TABLES LIKE 'tenant_feature_flags';

-- Check migration applied
SELECT * FROM tenant_schema_migrations WHERE version = '2025_11_feature_flags';
```

**Expected Result:**
- ✅ `tenant_feature_flags` table created in all tenant databases
- ✅ Migration recorded in `tenant_schema_migrations`

---

### **Step 2: Enable Feature Flags for Test Tenant** 🟡 **MEDIUM PRIORITY**

**Purpose:** Enable standardized serial generation for testing

**Action (SQL):**
```sql
-- Enable HAT serial standardization for test tenant (ID: 1 = DEFAULT)
INSERT INTO tenant_feature_flags (tenant_id, flag_key, flag_value, enabled_by, notes)
VALUES (1, 'FF_SERIAL_STD_HAT', 'on', 1, 'Testing standardized serial generation')
ON DUPLICATE KEY UPDATE flag_value = 'on';

-- Enable OEM serial standardization for test tenant
INSERT INTO tenant_feature_flags (tenant_id, flag_key, flag_value, enabled_by, notes)
VALUES (1, 'FF_SERIAL_STD_OEM', 'on', 1, 'Testing standardized OEM serial generation')
ON DUPLICATE KEY UPDATE flag_value = 'on';
```

**Or via API (if UI created):**
- Navigate to Platform Console → Feature Flags Management
- Enable `FF_SERIAL_STD_HAT` and `FF_SERIAL_STD_OEM` for test tenant

**Verify:**
```sql
SELECT * FROM tenant_feature_flags WHERE tenant_id = 1;
```

**Expected Result:**
- ✅ Feature flags enabled for test tenant
- ✅ Serial generation uses `UnifiedSerialService` when flags are 'on'

---

### **Step 3: Test Background Jobs** 🟡 **MEDIUM PRIORITY**

**Purpose:** Verify consistency checker and outbox worker function correctly

**Action:**

#### **3.1 Test Consistency Checker (Dry Run):**
```bash
cd /Applications/MAMP/htdocs/bellavier-group-erp
php cron/serial_consistency_checker.php --dry-run
```

**Expected Output:**
- ✅ Processes all tenants
- ✅ Reports found issues (if any)
- ✅ No errors

#### **3.2 Test Consistency Checker (Live):**
```bash
php cron/serial_consistency_checker.php
```

**Expected Result:**
- ✅ Fixes missing links automatically
- ✅ Quarantines invalid serials
- ✅ Reports summary statistics

#### **3.3 Test Outbox Worker (Dry Run):**
```bash
php cron/serial_outbox_worker.php --dry-run
```

**Expected Output:**
- ✅ Processes pending outbox entries
- ✅ Reports retry attempts
- ✅ No errors

#### **3.4 Test Outbox Worker (Live):**
```bash
php cron/serial_outbox_worker.php
```

**Expected Result:**
- ✅ Retries failed Core DB links
- ✅ Updates outbox status
- ✅ Reports success/failure counts

---

### **Step 4: Set Up Cron Jobs** 🟡 **MEDIUM PRIORITY**

**Purpose:** Automate background jobs for production

**Action:**

#### **4.1 Add to Crontab:**
```bash
# Edit crontab
crontab -e

# Add these lines:
# Hourly consistency check
0 * * * * cd /Applications/MAMP/htdocs/bellavier-group-erp && php cron/serial_consistency_checker.php >> logs/serial_consistency.log 2>&1

# Every 5 minutes outbox retry
*/5 * * * * cd /Applications/MAMP/htdocs/bellavier-group-erp && php cron/serial_outbox_worker.php >> logs/serial_outbox.log 2>&1
```

#### **4.2 Create Log Directory:**
```bash
mkdir -p /Applications/MAMP/htdocs/bellavier-group-erp/logs
chmod 755 /Applications/MAMP/htdocs/bellavier-group-erp/logs
```

#### **4.3 Verify Cron Jobs:**
```bash
# List cron jobs
crontab -l | grep serial

# Check logs (after first run)
tail -f logs/serial_consistency.log
tail -f logs/serial_outbox.log
```

**Expected Result:**
- ✅ Cron jobs scheduled
- ✅ Logs created after first run
- ✅ Jobs execute automatically

---

### **Step 5: Test Public Verify API** 🟢 **LOW PRIORITY**

**Purpose:** Verify public API endpoint is accessible

**Action:**

#### **5.1 Test with cURL:**
```bash
# Test with valid serial (replace with actual serial from your system)
curl -X GET "http://localhost:8888/bellavier-group-erp/api/public/serial/verify/MA01-HAT-TEST-20251109-00001-XXXX-X" \
  -H "Accept: application/json"

# Test with invalid serial
curl -X GET "http://localhost:8888/bellavier-group-erp/api/public/serial/verify/INVALID-SERIAL" \
  -H "Accept: application/json"

# Test rate limiting (make 61 requests quickly)
for i in {1..61}; do
  curl -X GET "http://localhost:8888/bellavier-group-erp/api/public/serial/verify/TEST-SERIAL" \
    -H "Accept: application/json"
done
```

**Expected Results:**
- ✅ Valid serial returns `{"ok": true, "valid": true, ...}`
- ✅ Invalid serial returns `{"ok": false, "error": "Serial not found or invalid"}`
- ✅ Rate limit returns HTTP 429 after 60 requests

#### **5.2 Test CORS:**
```javascript
// In browser console (different origin)
fetch('http://localhost:8888/bellavier-group-erp/api/public/serial/verify/MA01-HAT-TEST-20251109-00001-XXXX-X')
  .then(r => r.json())
  .then(console.log);
```

**Expected Result:**
- ✅ CORS headers present
- ✅ Request succeeds from different origin

---

### **Step 6: Test Monitoring API** 🟢 **LOW PRIORITY**

**Purpose:** Verify metrics API returns correct data

**Action:**

#### **6.1 Test Metrics API:**
```bash
# Login first to get session cookie
# Then test metrics API
curl -X GET "http://localhost:8888/bellavier-group-erp/source/platform_serial_metrics_api.php?action=summary" \
  -H "Cookie: PHPSESSID=..." \
  -H "Accept: application/json"

# Test generation rate
curl -X GET "http://localhost:8888/bellavier-group-erp/source/platform_serial_metrics_api.php?action=generation_rate&days=7" \
  -H "Cookie: PHPSESSID=..." \
  -H "Accept: application/json"

# Test link health
curl -X GET "http://localhost:8888/bellavier-group-erp/source/platform_serial_metrics_api.php?action=link_health" \
  -H "Cookie: PHPSESSID=..." \
  -H "Accept: application/json"
```

**Expected Result:**
- ✅ Returns JSON with metrics data
- ✅ No errors
- ✅ Data matches database state

---

### **Step 7: Gradual Rollout Plan** 🟢 **LOW PRIORITY**

**Purpose:** Enable feature flags gradually for production tenants

**Rollout Schedule:**

**Week 1:** Test Tenant Only
- Enable `FF_SERIAL_STD_HAT` for test tenant
- Monitor metrics and logs
- Verify no issues

**Week 2:** One Production Tenant
- Enable `FF_SERIAL_STD_HAT` for one production tenant (e.g., `maison_atelier`)
- Monitor closely
- Verify serial generation works correctly

**Week 3:** All Hatthasilpa Tenants
- Enable `FF_SERIAL_STD_HAT` for all Hatthasilpa tenants
- Monitor metrics
- Verify consistency

**Week 4:** OEM Test Tenant
- Enable `FF_SERIAL_STD_OEM` for test tenant
- Monitor OEM serial generation

**Week 5:** All OEM Tenants
- Enable `FF_SERIAL_STD_OEM` for all OEM tenants
- Complete rollout

**SQL for Rollout:**
```sql
-- Enable for specific tenant
UPDATE tenant_feature_flags 
SET flag_value = 'on', enabled_at = UTC_TIMESTAMP(), enabled_by = 1
WHERE tenant_id = ? AND flag_key = 'FF_SERIAL_STD_HAT';

-- Check status
SELECT tenant_id, flag_key, flag_value, enabled_at 
FROM tenant_feature_flags 
WHERE flag_key IN ('FF_SERIAL_STD_HAT', 'FF_SERIAL_STD_OEM')
ORDER BY tenant_id, flag_key;
```

---

## 📊 Testing Checklist

### **Pre-Production Testing:**

- [ ] **Feature Flags Migration Applied**
  - [ ] `tenant_feature_flags` table exists
  - [ ] Migration recorded in `tenant_schema_migrations`

- [ ] **Feature Flags Enabled for Test Tenant**
  - [ ] `FF_SERIAL_STD_HAT` = 'on'
  - [ ] `FF_SERIAL_STD_OEM` = 'on'

- [ ] **Background Jobs Tested**
  - [ ] Consistency checker runs successfully
  - [ ] Outbox worker runs successfully
  - [ ] Cron jobs scheduled

- [ ] **Public API Tested**
  - [ ] Valid serial verification works
  - [ ] Invalid serial returns error
  - [ ] Rate limiting works
  - [ ] CORS headers present

- [ ] **Monitoring API Tested**
  - [ ] Summary endpoint works
  - [ ] Generation rate endpoint works
  - [ ] Link health endpoint works
  - [ ] Error metrics endpoint works

- [ ] **Integration Verified**
  - [ ] Job ticket creation generates serials (when flag enabled)
  - [ ] Token spawn reuses serials correctly
  - [ ] Dual-link consistency verified
  - [ ] OEM serial generation works

---

## 🎯 Recommended Order of Execution

1. **Apply Feature Flags Migration** (5 minutes)
2. **Enable Feature Flags for Test Tenant** (2 minutes)
3. **Test Background Jobs** (10 minutes)
4. **Set Up Cron Jobs** (5 minutes)
5. **Test Public API** (5 minutes)
6. **Test Monitoring API** (5 minutes)
7. **Gradual Rollout** (5 weeks)

**Total Time:** ~30 minutes for immediate steps

---

## 🔗 Related Documents

- `SERIAL_HARDENING_COMPLETE.md` - Hardening completion summary
- `SERIAL_SYSTEM_READINESS.md` - Overall system readiness
- `SERIAL_VALIDATION_TEST_PLAN.md` - Validation test plan
- `SERIAL_PUBLIC_VERIFY_API.md` - Public API documentation
- `SERIAL_MONITORING.md` - Monitoring documentation

---

## 💡 Tips

- **Start with test tenant:** Always test with test tenant first before enabling for production
- **Monitor closely:** Watch logs and metrics during first week of rollout
- **Have rollback plan:** Feature flags can be disabled instantly if issues occur
- **Backup first:** Always backup databases before applying migrations in production


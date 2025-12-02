# ⏰ Serial Number System - Cron Jobs Setup Guide

**Purpose:** คู่มือการตั้งค่า Cron Jobs สำหรับ Background Workers  
**Last Updated:** November 9, 2025  
**Status:** ✅ **Production Ready**

---

## 🎯 Overview

Serial Number System ต้องการ Background Workers 2 ตัวเพื่อรักษาความสอดคล้องของข้อมูลและจัดการ failed operations:

1. **Consistency Checker** - ตรวจสอบและแก้ไข inconsistencies ทุกชั่วโมง
2. **Outbox Worker** - Retry failed Core DB links ทุก 5 นาที

---

## 📋 Prerequisites

- ✅ PHP CLI available (`php -v`)
- ✅ Database connections working (`core_db()` and `tenant_db()`)
- ✅ Cron service running (`crontab -l`)
- ✅ Write permissions for log directory (`storage/logs/`)

---

## 🚀 Step-by-Step Setup

### **Step 1: Verify Scripts Are Executable**

```bash
cd /path/to/bellavier-group-erp

# Test Consistency Checker
php cron/serial_consistency_checker.php --dry-run

# Test Outbox Worker
php cron/serial_outbox_worker.php
```

**Expected Output:**
- Consistency Checker: Shows summary of checks (dry-run mode)
- Outbox Worker: Shows "No pending entries" or retry attempts

---

### **Step 2: Create Log Directory**

```bash
mkdir -p storage/logs
chmod 755 storage/logs
```

---

### **Step 3: Add Cron Jobs**

#### **Option A: Edit Crontab Directly**

```bash
crontab -e
```

#### **Option B: Add via Script**

```bash
# Backup existing crontab
crontab -l > crontab_backup_$(date +%Y%m%d).txt

# Add new jobs
(crontab -l 2>/dev/null; echo "") | crontab -
(crontab -l 2>/dev/null; echo "# Serial Number System - Consistency Checker (Hourly)"; echo "0 * * * * cd /path/to/bellavier-group-erp && php cron/serial_consistency_checker.php >> storage/logs/serial_consistency.log 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "# Serial Number System - Outbox Worker (Every 5 minutes)"; echo "*/5 * * * * cd /path/to/bellavier-group-erp && php cron/serial_outbox_worker.php >> storage/logs/serial_outbox.log 2>&1") | crontab -
```

---

### **Step 4: Cron Job Entries**

**Copy these lines to your crontab (replace `/path/to/bellavier-group-erp` with actual path):**

```cron
# Serial Number System - Consistency Checker (Hourly)
# Runs at minute 0 of every hour (00:00, 01:00, 02:00, ...)
0 * * * * cd /path/to/bellavier-group-erp && php cron/serial_consistency_checker.php >> storage/logs/serial_consistency.log 2>&1

# Serial Number System - Outbox Worker (Every 5 minutes)
# Runs every 5 minutes (00:00, 00:05, 00:10, 00:15, ...)
*/5 * * * * cd /path/to/bellavier-group-erp && php cron/serial_outbox_worker.php >> storage/logs/serial_outbox.log 2>&1
```

**For MAMP (macOS):**

```cron
# Serial Number System - Consistency Checker (Hourly)
0 * * * * cd /Applications/MAMP/htdocs/bellavier-group-erp && /Applications/MAMP/bin/php/php8.2.0/bin/php cron/serial_consistency_checker.php >> storage/logs/serial_consistency.log 2>&1

# Serial Number System - Outbox Worker (Every 5 minutes)
*/5 * * * * cd /Applications/MAMP/htdocs/bellavier-group-erp && /Applications/MAMP/bin/php/php8.2.0/bin/php cron/serial_outbox_worker.php >> storage/logs/serial_outbox.log 2>&1
```

---

### **Step 5: Verify Cron Jobs**

```bash
# List all cron jobs
crontab -l

# Check if cron service is running (Linux)
systemctl status cron

# Check cron logs (Linux)
tail -f /var/log/cron

# Check cron logs (macOS)
log show --predicate 'process == "cron"' --last 1h
```

---

## 📊 Monitoring & Logs

### **Log Files:**

- **Consistency Checker:** `storage/logs/serial_consistency.log`
- **Outbox Worker:** `storage/logs/serial_outbox.log`

### **View Logs:**

```bash
# Tail consistency checker logs
tail -f storage/logs/serial_consistency.log

# Tail outbox worker logs
tail -f storage/logs/serial_outbox.log

# View last 50 lines
tail -n 50 storage/logs/serial_consistency.log
```

### **Log Rotation (Optional):**

```bash
# Add to crontab (rotate logs weekly)
0 0 * * 0 cd /path/to/bellavier-group-erp && mv storage/logs/serial_consistency.log storage/logs/serial_consistency_$(date +%Y%m%d).log && mv storage/logs/serial_outbox.log storage/logs/serial_outbox_$(date +%Y%m%d).log
```

---

## 🔍 Troubleshooting

### **Problem: Cron Jobs Not Running**

**Check:**
1. ✅ Cron service is running
2. ✅ PHP path is correct (`which php` or full path to PHP binary)
3. ✅ File permissions (scripts are executable)
4. ✅ Log directory exists and is writable

**Debug:**
```bash
# Test cron job manually
cd /path/to/bellavier-group-erp
php cron/serial_consistency_checker.php --dry-run

# Check cron logs for errors
grep CRON /var/log/syslog  # Linux
log show --predicate 'process == "cron"' --last 1h  # macOS
```

---

### **Problem: "Permission Denied" Errors**

**Fix:**
```bash
# Make scripts executable
chmod +x cron/serial_consistency_checker.php
chmod +x cron/serial_outbox_worker.php

# Check log directory permissions
chmod 755 storage/logs
chown www-data:www-data storage/logs  # Linux (adjust user/group)
```

---

### **Problem: Database Connection Errors**

**Check:**
1. ✅ `config.php` is readable
2. ✅ Database credentials are correct
3. ✅ Database server is accessible from cron context

**Fix:**
```bash
# Test database connection from CLI
php -r "require 'config.php'; require 'source/global_function.php'; \$db = core_db(); echo 'Core DB: ' . (\$db ? 'OK' : 'FAILED') . PHP_EOL;"
```

---

## 📈 Expected Behavior

### **Consistency Checker (Hourly):**

**Normal Output:**
```
=== Serial Consistency Checker ===
Started at: 2025-11-09 15:00:00
Mode: LIVE

Processing tenant: Bellavier Atelier (DEFAULT)
  ✅ Completed

Processing tenant: Maison Atelier (maison_atelier)
  ✅ Completed

=== Summary ===
Tenants processed: 2
Missing tenant links: 0
Missing core links: 0
Invalid formats: 0
Orphaned serials: 0
Fixed: 0
Quarantined: 0
Errors: 0

Completed at: 2025-11-09 15:00:01
✅ Success!
```

**When Issues Found:**
```
Found 5 missing core links
Found 2 invalid serial formats
Found 10 orphaned serials
Fixed: 5
Quarantined: 12
```

---

### **Outbox Worker (Every 5 minutes):**

**Normal Output:**
```
=== Serial Link Outbox Worker ===
Started at: 2025-11-09 15:05:00
Mode: LIVE

Processing tenant: Bellavier Atelier (DEFAULT)
  No pending entries
  ✅ Completed

=== Summary ===
Tenants processed: 2
Pending found: 0
Retried: 0
Succeeded: 0
Failed retry: 0
Marked dead: 0
Errors: 0

Completed at: 2025-11-09 15:05:01
✅ Success!
```

**When Retries Occur:**
```
Found 3 pending entries
Retrying entry ID: 123 (serial: MA01-HAT-BAG-20251109-00027-A9K2-X, retry: 2)
  ✅ Succeeded
Retried: 3
Succeeded: 3
```

---

## 🚨 Alerting

### **Set Up Alerts for:**

1. **Consistency Check Failures:**
   - Alert if `Errors: > 0` in log
   - Alert if `Quarantined: > 10` in log

2. **Outbox Dead Entries:**
   - Alert if `Marked dead: > 0` in log
   - Alert if `Failed retry: > 5` in log

3. **Cron Job Not Running:**
   - Alert if log file hasn't been updated in 2 hours (consistency checker)
   - Alert if log file hasn't been updated in 10 minutes (outbox worker)

---

## 📚 Related Documents

- `SERIAL_HARDENING_COMPLETE.md` - Complete hardening implementation
- `SERIAL_MONITORING.md` - Monitoring metrics and dashboards
- `SERIAL_NUMBER_IMPLEMENTATION.md` - Implementation guide

---

**Status:** ✅ **Production Ready**  
**Last Updated:** November 9, 2025


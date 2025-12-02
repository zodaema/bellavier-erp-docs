# ⏰ Production Dashboard - Cron Jobs Setup Guide

**Purpose:** คู่มือการตั้งค่า Cron Jobs สำหรับ Production Dashboard Materialized Tables Refresh  
**Last Updated:** November 15, 2025  
**Status:** ✅ **Production Ready**

---

## 🎯 Overview

Production Dashboard ใช้ Materialized Tables เพื่อเพิ่มประสิทธิภาพการ query ข้อมูล WIP, Bottlenecks, และ Trends. ต้องมี Cron Job เพื่อ refresh ข้อมูลในตารางเหล่านี้เป็นระยะ:

1. **High-Frequency Refresh** (ทุก 1 นาที): `mv_token_flow_summary`, `mv_node_bottlenecks`, `mv_team_workload`
2. **Medium-Frequency Refresh** (ทุก 5 นาที): `mv_cycle_time_analytics`
3. **Low-Frequency Refresh** (ทุก 15 นาที): `mv_dashboard_trends`

---

## 📋 Prerequisites

- ✅ PHP CLI available (`php -v`)
- ✅ Database connections working (`core_db()` and `tenant_db()`)
- ✅ Cron service running (`crontab -l`)
- ✅ Migration `2025_11_production_dashboard` รันแล้ว
- ✅ Materialized tables สร้างแล้ว (`mv_token_flow_summary`, `mv_node_bottlenecks`, `mv_team_workload`, `mv_cycle_time_analytics`, `mv_dashboard_trends`)

---

## 🚀 Step-by-Step Setup

### **Step 1: Verify Script Is Executable**

```bash
cd /path/to/bellavier-group-erp

# Test refresh script (single tenant)
php tools/cron/refresh_dashboard_materialized_tables.php --tenant=DEFAULT

# Test refresh script (all tenants)
php tools/cron/refresh_dashboard_materialized_tables.php
```

**Expected Output:**
```
=== Refreshing Dashboard Materialized Tables for Tenant: DEFAULT ===

Refreshing mv_token_flow_summary...
✓ Done

Refreshing mv_node_bottlenecks...
✓ Done

Refreshing mv_team_workload...
✓ Done

Refreshing mv_cycle_time_analytics...
✓ Done

Refreshing mv_dashboard_trends...
✓ Done

=== Refresh Complete ===
```

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
(crontab -l 2>/dev/null; echo "# Production Dashboard - High-Frequency Refresh (Every 1 minute)"; echo "* * * * * cd /path/to/bellavier-group-erp && php tools/cron/refresh_dashboard_materialized_tables.php >> storage/logs/dashboard_refresh.log 2>&1") | crontab -
```

---

### **Step 4: Cron Job Entries**

**Recommended Schedule (Single Job - Refreshes All Tables):**

```cron
# Production Dashboard - Materialized Tables Refresh (Every 1 minute)
# Refreshes: mv_token_flow_summary, mv_node_bottlenecks, mv_team_workload (every run)
#            mv_cycle_time_analytics (every 5 minutes via script logic)
#            mv_dashboard_trends (every 15 minutes via script logic)
* * * * * cd /path/to/bellavier-group-erp && php tools/cron/refresh_dashboard_materialized_tables.php >> storage/logs/dashboard_refresh.log 2>&1
```

**For MAMP (macOS):**

```cron
# Production Dashboard - Materialized Tables Refresh (Every 1 minute)
* * * * * cd /Applications/MAMP/htdocs/bellavier-group-erp && /Applications/MAMP/bin/php/php8.2.0/bin/php tools/cron/refresh_dashboard_materialized_tables.php >> storage/logs/dashboard_refresh.log 2>&1
```

**Alternative: Separate Jobs for Different Frequencies (Advanced):**

```cron
# High-frequency refresh (every 1 minute)
* * * * * cd /path/to/bellavier-group-erp && php tools/cron/refresh_dashboard_materialized_tables.php --tables=summary,bottlenecks,workload >> storage/logs/dashboard_refresh_high.log 2>&1

# Medium-frequency refresh (every 5 minutes)
*/5 * * * * cd /path/to/bellavier-group-erp && php tools/cron/refresh_dashboard_materialized_tables.php --tables=cycle_time >> storage/logs/dashboard_refresh_medium.log 2>&1

# Low-frequency refresh (every 15 minutes)
*/15 * * * * cd /path/to/bellavier-group-erp && php tools/cron/refresh_dashboard_materialized_tables.php --tables=trends >> storage/logs/dashboard_refresh_low.log 2>&1
```

**Note:** Current script implementation refreshes all tables in one run. For separate frequencies, you would need to modify the script to accept `--tables` parameter.

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

# Check script output logs
tail -f storage/logs/dashboard_refresh.log
```

---

### **Step 6: Test Cron Job Execution**

```bash
# Manually trigger cron job
php tools/cron/refresh_dashboard_materialized_tables.php --tenant=DEFAULT

# Check if data was populated
mysql -u root -proot bgerp_t_default -e "SELECT COUNT(*) FROM mv_token_flow_summary;"
mysql -u root -proot bgerp_t_default -e "SELECT COUNT(*) FROM mv_node_bottlenecks;"
mysql -u root -proot bgerp_t_default -e "SELECT COUNT(*) FROM mv_team_workload;"
mysql -u root -proot bgerp_t_default -e "SELECT COUNT(*) FROM mv_cycle_time_analytics;"
mysql -u root -proot bgerp_t_default -e "SELECT COUNT(*) FROM mv_dashboard_trends;"
```

---

## 📊 Materialized Tables Details

### **mv_token_flow_summary**
- **Purpose:** WIP summary by graph/node/team
- **Refresh Frequency:** Every 1 minute
- **Retention:** Last 24 hours
- **Columns:** `snapshot_at`, `graph_id`, `node_id`, `team_id`, `wip_count`, `completed_count`, `waiting_count`

### **mv_node_bottlenecks**
- **Purpose:** Bottleneck detection (nodes with high queue depth)
- **Refresh Frequency:** Every 1 minute
- **Retention:** Last 24 hours
- **Columns:** `snapshot_at`, `node_id`, `node_code`, `node_name`, `queue_depth`, `avg_wait_minutes`, `bottleneck_score`

### **mv_team_workload**
- **Purpose:** Team workload and capacity utilization
- **Refresh Frequency:** Every 1 minute
- **Retention:** Last 24 hours
- **Columns:** `snapshot_at`, `team_id`, `team_name`, `team_category`, `active_tokens`, `waiting_tokens`, `avg_load`

### **mv_cycle_time_analytics**
- **Purpose:** Cycle time statistics (p50, p95, avg)
- **Refresh Frequency:** Every 5 minutes (recommended)
- **Retention:** Last 7 days
- **Columns:** `snapshot_at`, `node_id`, `team_id`, `period_start`, `period_end`, `token_count`, `avg_minutes`

### **mv_dashboard_trends**
- **Purpose:** Daily trends (lead time, throughput)
- **Refresh Frequency:** Every 15 minutes (recommended)
- **Retention:** Last 30 days
- **Columns:** `snapshot_at`, `period_date`, `production_type`, `graph_id`, `tokens_completed`, `tokens_spawned`, `avg_lead_time_hours`, `throughput_per_day`

---

## 🔍 Troubleshooting

### **Problem: Cron Jobs Not Running**

**Diagnostic Steps:**
1. ✅ Cron service is running
2. ✅ Script path is correct (use absolute path)
3. ✅ PHP CLI path is correct (check `which php`)
4. ✅ Database server is accessible from cron context
5. ✅ Log directory exists and is writable

**Solutions:**
```bash
# Test cron job manually
php tools/cron/refresh_dashboard_materialized_tables.php --tenant=DEFAULT

# Check cron logs for errors
grep CRON /var/log/syslog  # Linux
log show --predicate 'process == "cron"' --last 1h  # macOS

# Verify script permissions
chmod +x tools/cron/refresh_dashboard_materialized_tables.php
```

---

### **Problem: No Data in Materialized Tables**

**Possible Causes:**
1. Cron job not running
2. No tokens/data in source tables (`flow_token`, `token_assignment`, etc.)
3. Database connection issues

**Solutions:**
```bash
# Check if cron job ran
tail -f storage/logs/dashboard_refresh.log

# Manually refresh
php tools/cron/refresh_dashboard_materialized_tables.php --tenant=DEFAULT

# Check source data
mysql -u root -proot bgerp_t_default -e "SELECT COUNT(*) FROM flow_token WHERE status = 'active';"
mysql -u root -proot bgerp_t_default -e "SELECT COUNT(*) FROM token_assignment;"
```

---

### **Problem: High CPU/Memory Usage**

**Possible Causes:**
1. Refresh frequency too high
2. Large dataset (many tokens/nodes/teams)
3. Complex queries taking too long

**Solutions:**
1. Reduce refresh frequency (e.g., every 2-5 minutes instead of every 1 minute)
2. Add indexes to source tables (if missing)
3. Optimize queries in refresh functions
4. Consider refreshing only specific tables based on frequency needs

---

## 📝 Log Rotation (Optional)

**Add to crontab (rotate logs weekly):**

```cron
# Rotate dashboard refresh logs (weekly, every Sunday at 2 AM)
0 2 * * 0 cd /path/to/bellavier-group-erp && mv storage/logs/dashboard_refresh.log storage/logs/dashboard_refresh_$(date +\%Y\%m\%d).log && touch storage/logs/dashboard_refresh.log
```

---

## ✅ Verification Checklist

- [ ] Script executable and tested manually
- [ ] Log directory created and writable
- [ ] Cron job added to crontab
- [ ] Cron service running
- [ ] Log file shows successful executions
- [ ] Materialized tables populated with data
- [ ] Dashboard API returns data (not empty)
- [ ] Performance acceptable (< 5 seconds per refresh)

---

## 🔗 Related Documentation

- `tools/cron/refresh_dashboard_materialized_tables.php` - Cron script source code
- `database/tenant_migrations/2025_11_production_dashboard.php` - Migration file
- `source/dashboard_api.php` - Dashboard API endpoints
- `docs/routing_graph_designer/PHASE7_10_TASK_BOARD.md` - Phase 10 implementation details

---

## 📞 Support

If you encounter issues:
1. Check `storage/logs/dashboard_refresh.log` for errors
2. Verify database connections (`core_db()`, `tenant_db()`)
3. Test script manually: `php tools/cron/refresh_dashboard_materialized_tables.php --tenant=DEFAULT`
4. Review cron service logs for execution errors

---

**Last Updated:** November 15, 2025  
**Version:** 1.0.0


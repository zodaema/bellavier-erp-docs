# Migration Files Audit & Fix Plan

**Date:** November 3, 2025  
**Purpose:** Audit ALL migration files and standardize naming  
**Status:** 🔴 In Progress

---

## 📋 Current Migration Files

```
database/tenant_migrations/
├─ 0001_init_tenant_schema.php (34.66 KB) - ❓ Check format
├─ 0002_seed_sample_data.php (9.15 KB) - ❓ Check format
├─ 0003_performance_indexes.php (5.11 KB) - ❓ Check format
├─ 0004_session_improvements.php (6.07 KB) - ❓ Check format
├─ 0005_serial_tracking.php (1.80 KB) - ❓ Check format
├─ 0006_serial_unique_trigger.php (2.22 KB) - ❓ Check format
├─ 0007_progress_event_type.php (2.39 KB) - ❓ Check format
├─ 0008_dag_foundation.php (17.51 KB) - ❓ Check format
├─ 0009_work_queue_support.php (10.70 KB) - ❓ Check format (this is known wrong!)
├─ 2025_11_migrate_users_to_tenant.php (7.12 KB) - ✅ Correct
└─ 2025_11_tenant_user_accounts.php (8.99 KB) - ✅ Correct
```

---

## 🔍 Audit Results

### Migration History Analysis:
```
tenant_migrations table (UI Wizard):
- Used by Migration Wizard ✅
- Format: Mixed (YYYY_MM_ AND NNNN_)
- Active migrations: 0004, 0005, 0006, 0007, 0008, 2025_10, etc.

tenant_schema_migrations table (CLI):
- Used by bootstrap_migrations.php
- Format: NNNN_
- Active migrations: 0009_work_queue_support
```

### Issue Found:
Both format types are being used! Need to standardize.

---

## 📝 Action Plan

Will be updated after audit...


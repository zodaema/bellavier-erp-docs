# Rollback Plan - Phase 7-10 Integration

**Purpose:** Safe rollback procedures for each phase to minimize production impact

**Last Updated:** November 11, 2025

---

## 🔄 General Rollback Principles

1. **Feature Flags First:** Always disable feature flags before rolling back migrations
2. **Data Preservation:** Never drop tables/columns with production data without backup
3. **Gradual Rollback:** Rollback in reverse order (Phase 10 → Phase 7)
4. **Testing:** Test rollback in staging before production

---

## Phase 7: Assignment System Rollback

### Step 1: Disable Feature Flags
```php
// In config.php or feature flag system
setFeatureFlag('enable_assignment_runtime', false);
setFeatureFlag('enable_assignment_preview', false);
```

### Step 2: Stop Auto-Assignment
- Tokens will fall back to manual assignment (existing `NodeAssignmentService`)
- No new `assignment_log` entries created
- Existing assignments remain valid

### Step 3: Rollback Migration (Optional - Only if needed)
```sql
-- ⚠️ WARNING: Only if no production data exists
-- Check first: SELECT COUNT(*) FROM assignment_log;

-- If safe to rollback:
ALTER TABLE assignment_plan_node DROP COLUMN IF EXISTS priority;
ALTER TABLE assignment_plan_job DROP COLUMN IF EXISTS priority;
DROP TABLE IF EXISTS assignment_log;
DROP TABLE IF EXISTS leave_request;
DROP TABLE IF EXISTS operator_availability;
DROP TABLE IF EXISTS team_availability;
```

### Step 4: Code Rollback
- Revert `TokenLifecycleService::spawnTokens()` - Remove `resolveAndAssignToken()` call
- Revert `DAGRoutingService::routeToNode()` - Remove `resolveAssignmentForToken()` call
- Keep `AssignmentResolverService.php` (can be disabled via feature flag)

**Rollback Time:** ~15 minutes  
**Data Loss Risk:** Low (only assignment_log audit trail)

---

## Phase 8: OEM Integration Rollback

### Step 1: Disable Feature Flags
```php
setFeatureFlag('enable_oem_mode', false);
setFeatureFlag('oem_shadow_run', false);
```

### Step 2: Stop OEM Processing
- Existing job tickets continue normal flow
- New tickets use standard DAG routing
- Scan stations fall back to manual mode

### Step 3: Rollback Migration (Optional)
```sql
-- ⚠️ WARNING: Check data first
-- SELECT COUNT(*) FROM oem_job_ticket;
-- SELECT COUNT(*) FROM oem_job_ticket_step;

-- If safe:
DROP TABLE IF EXISTS oem_job_ticket_step;
DROP TABLE IF EXISTS oem_job_ticket;
DROP TABLE IF EXISTS oem_scan_rule;
```

### Step 4: Code Rollback
- Revert OEM-specific endpoints in `dag_token_api.php`
- Remove OEM Kanban UI files
- Keep OEM scan rules table (can be empty)

**Rollback Time:** ~20 minutes  
**Data Loss Risk:** Medium (OEM job ticket data)

---

## Phase 9: People System Integration Rollback

### Step 1: Disable Feature Flags
```php
setFeatureFlag('enable_people_integration_readonly', false);
```

### Step 2: Stop Sync Jobs
- Disable cron jobs: `people_sync_operators.php`, `people_sync_teams.php`
- Cache expires naturally (TTL-based)
- Fallback to local `account` table

### Step 3: Rollback Migration (Optional)
```sql
-- ⚠️ WARNING: Check sync_error_log first
-- SELECT COUNT(*) FROM people_sync_error_log;

-- If safe:
DROP TABLE IF EXISTS people_sync_error_log;
DROP TABLE IF EXISTS people_operator_cache;
DROP TABLE IF EXISTS people_team_cache;
DROP TABLE IF EXISTS people_availability_cache;
DROP TABLE IF EXISTS people_masking_policy;
```

### Step 4: Code Rollback
- Remove `PeopleSyncService.php` calls
- Revert `AssignmentResolverService` to use local `account` table only
- Keep cache tables (can be empty)

**Rollback Time:** ~15 minutes  
**Data Loss Risk:** Low (cache data only, can rebuild)

---

## Phase 10: Production Dashboard Rollback

### Step 1: Disable Feature Flags
```php
setFeatureFlag('enable_production_dashboard', false);
```

### Step 2: Stop Materialized View Refresh
- Disable cron: `refresh_dashboard_materialized_views.php`
- Views remain but not refreshed
- Dashboard UI shows "Data unavailable"

### Step 3: Rollback Migration (Optional)
```sql
-- ⚠️ WARNING: Check materialized view data
-- SELECT COUNT(*) FROM mv_token_flow_summary;
-- SELECT COUNT(*) FROM mv_node_bottlenecks;
-- SELECT COUNT(*) FROM mv_team_workload;
-- SELECT COUNT(*) FROM mv_cycle_time_analytics;

-- If safe:
DROP TABLE IF EXISTS mv_cycle_time_analytics;
DROP TABLE IF EXISTS mv_team_workload;
DROP TABLE IF EXISTS mv_node_bottlenecks;
DROP TABLE IF EXISTS mv_token_flow_summary;
```

### Step 4: Code Rollback
- Remove dashboard API endpoints
- Remove materialized view refresh cron
- Keep dashboard UI files (can show "Coming soon")

**Rollback Time:** ~10 minutes  
**Data Loss Risk:** Low (analytics data only)

---

## 🚨 Emergency Rollback (All Phases)

### Complete System Rollback
```php
// Disable all feature flags
setFeatureFlag('enable_assignment_runtime', false);
setFeatureFlag('enable_oem_mode', false);
setFeatureFlag('enable_people_integration_readonly', false);
setFeatureFlag('enable_production_dashboard', false);
```

**Effect:**
- System returns to pre-Phase 7 state
- All new features disabled
- Existing data preserved
- Manual assignment only

**Rollback Time:** ~5 minutes  
**Data Loss Risk:** None

---

## 📋 Rollback Checklist

Before rolling back any phase:

- [ ] Backup database (full dump)
- [ ] Disable feature flags
- [ ] Stop background jobs/cron
- [ ] Verify no active users using feature
- [ ] Test rollback in staging
- [ ] Document rollback reason
- [ ] Notify stakeholders

After rollback:

- [ ] Verify system functionality
- [ ] Check error logs
- [ ] Monitor for 24 hours
- [ ] Update rollback log

---

## 🔍 Rollback Log Template

```markdown
## Rollback Log Entry

**Date:** YYYY-MM-DD HH:MM
**Phase:** Phase X
**Reason:** [Brief description]
**Rolled Back By:** [User]
**Duration:** X minutes
**Data Loss:** Yes/No
**Issues Encountered:** [Any problems]
**Resolution:** [How it was resolved]
```

---

## ⚠️ Critical Notes

1. **Never rollback migrations with production data** without backup
2. **Feature flags are safer** than code rollback (can re-enable quickly)
3. **Test rollback procedures** in staging quarterly
4. **Document all rollbacks** for audit trail
5. **Monitor system** for 48 hours after rollback

---

## 📞 Emergency Contacts

- **Lead Architect:** [Contact]
- **Database Admin:** [Contact]
- **DevOps:** [Contact]

---

**Version:** 1.0  
**Last Review:** November 11, 2025  
**Next Review:** February 11, 2026 (Quarterly)


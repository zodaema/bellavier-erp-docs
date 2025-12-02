# Feature Flags v2 - Implementation Complete (Archived)

Status: Completed (Nov 16, 2025)

Scope:
- CoreDB-only feature flag system with:
  - `feature_flag_catalog` (global catalog)
  - `feature_flag_tenant` (per-tenant overrides; tenant_scope = organization.code)
- Removal of legacy usages of `feature_flag` table
- Admin UI integration under admin_organizations

Key Changes:
- Migration (repurposed): `database/migrations/0003_feature_flag_tenant_tables.php`
  - Creates `feature_flag_catalog` and `feature_flag_tenant`
  - Seeds `FF_SERIAL_STD_HAT` in catalog and per-tenant overrides (maison_atelier=ON, others=OFF)
- Cleanup (legacy): removed all usage of legacy `feature_flag` (if present)
- Service:
  - `source/BGERP/Service/FeatureFlagService.php` with `getFlagValue(feature_key, tenant_scope)`
  - `source/BGERP/Service/TokenLifecycleService.php` uses `FeatureFlagService` for `FF_SERIAL_STD_HAT`
- Admin API:
  - `source/admin_feature_flags_api.php`
    - `list` (JOIN catalog+tenant, returns `effective_value`)
    - `upsert_tenant` (per-tenant override)
    - `define_flag` (catalog)
    - `delete_flag` (catalog, blocks protected flags)
- UI:
  - `assets/javascripts/admin/organizations.js` Feature Flags panel updated to show/toggle `effective_value`

Tests:
- `tests/Integration/FeatureFlagAdminTest.php` (service + schema v2) - PASS
- `tests/Integration/HatthasilpaE2E_SerialStdEnforcementTest.php` - PASS
- `tests/Integration/HatthasilpaE2E_WorkQueueFilterTest.php` - PASS

Notes:
- Tenant databases no longer own any `feature_flag` tables
- All gating reads are sourced from Core DB



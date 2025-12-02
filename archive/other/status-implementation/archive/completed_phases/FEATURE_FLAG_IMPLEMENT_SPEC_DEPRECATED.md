# Feature Flag Implement Spec (Deprecated) - Archived

This document has been superseded by Feature Flags v2 (CoreDB Catalog + Tenant Overrides).

See: `docs/status-implementation/archive/completed_phases/FEATURE_FLAGS_V2_IMPLEMENTATION.md`

Summary:
- Old design suggested tenant-level `feature_flag` tables and per-tenant migrations.
- New canonical design stores:
  - Global catalog in `feature_flag_catalog`
  - Per-tenant overrides in `feature_flag_tenant` (tenant_scope = organization.code)
- All runtime/services/APIs revised to use the v2 schema in Core DB only.



# Core Doctrines Summary (SSOT)

This file is a short, actionable summary of the core doctrines that should not be lost.

## 1) Reliability-first

- Data integrity over speed.
- Explicit behavior over hidden magic.
- No silent failures.
- Prefer staged rollout + feature flags + tests.

## 2) Backward compatibility

- Do not break existing API contracts unless explicitly authorized.
- Preserve thin wrappers for legacy compatibility when they exist.

## 3) Security-by-default (enterprise posture)

For reachable APIs:

- Bootstrap required: `TenantApiBootstrap::init()` or `CoreApiBootstrap::init()`.
- Rate limiting required after auth.
- Request validation required (`RequestValidator::make`).
- CSRF required for state-changing actions.
- Standard JSON output contract (`json_success/json_error`).
- Idempotency for create operations.
- ETag/If-Match for concurrency-safe updates.
- Maintenance mode gate.
- Execution time tracking.

## 4) Tenant isolation

- All data access must use the tenant DB handle.
- Never query cross-tenant tables.

## 5) Product governance: Published = Immutable

- A published product revision is immutable.
- New work must pin a runtime-compatible snapshot.
- Do not “fallback to live tables” for new production-critical work.

## 6) Time doctrine (CUT)

- Micro ledger is authoritative; projection is rebuildable.
- Do not use projections for authorization or punishment.
- Do not derive “Production Intent Time” from averages automatically.

## References

- `docs/developer/01-policy/DEVELOPER_POLICY.md`
- `docs/ROADMAP_LUXURY_WORLD_CLASS.md`
- `docs/06-specs/PUBLISHED_IMMUTABLE_CONTRACT.md`

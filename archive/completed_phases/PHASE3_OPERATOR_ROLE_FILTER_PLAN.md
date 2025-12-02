# Phase 3: Operator Role Filter Plan

**Version:** 0.4 (Ready for Implementation)
**Status:** Planning (Finalized)
**Owner:** AI Agent (Nov 7, 2025)

---

## 🎯 Goal

Ensure every feature that lists or assigns **people** in the production flow only shows **eligible operator roles** by default, while keeping the capability to optionally include other roles (supervisor, manager) via configuration.

This prevents managers/admins from appearing in operator pickers, reduces noise, and prepares the system for role-based task assignment.

> ⚠️ Key principle: UI filters are *not* trusted. All API endpoints must enforce role filtering server side via the shared service described below.

---

## 🔍 Current Usage Survey (Nov 6, 2025)

| Context | UI / API | Source | Current Logic | Issue |
|---------|----------|--------|---------------|-------|
| **Manager Assignment – Tokens tab** | `users_for_assignment` | `hatthasilpa_job_ticket.php` (POST) | Fetches from `account` + `account_org` (all tenant users) | Managers/Admins appear; no role filter |
| **Manager Assignment – Plans tab** | same as above | same API | same | same |
| **Hatthasilpa Job Ticket Modal** | `users_for_assignment` (GET) | `hatthasilpa_job_ticket.php` | same | same |
| **Bulk assignment (Node Assignment)** | `get_available_operators` | `assignment_api.php` | Reads `tenant_user_role` but only checks `id_tenant_role > 1` | Includes non-operator roles (planner, QC, etc.) |
| **Token Management** | `get_operators` | `token_management_api.php` | `tenant_user_role` join, no role filter | same |
| **Team Management – Add members** | `available_operators` | `team_api.php` | `account` + `account_org` (user_type = tenant_user) | Same issue |
| **Team People Monitor** | `people_monitor_list` | `team_api.php` | Currently returns all `account` entries | Same |
| **Team Member Drawer (People Now)** | Reuses People Monitor | same | same |
| **Future: Help Mode / PWA** | (needs verification) | `pwa_scan/work_queue.js` | currently does NOT fetch operator list (no change) | N/A |

> ✅ Other endpoints (TeamExpansionService, workload APIs) already operate on `team_member`, so the list of operators there is indirect and controlled via team membership.

---

## 📦 Target Architecture

1. **Central Helper / Service**
   - Create `source/service/OperatorDirectoryService.php` (tentative name)
   - Responsibilities:
     - Resolve operator `id_member` list for a tenant/org
     - Fetch detailed operator profile (name, username, workload, data source, resolved path)
     - Support options: include/exclude teams, filter by status, allow override list
     - Cache results per-request and optionally provide tenant-level TTL cache (e.g. 30s) to reduce repeated Core DB calls when multiple widgets hit the service simultaneously.
   - All endpoints must consume this service (no direct `SELECT ... FROM account ...` left in controllers).
   - During bootstrap, validate configuration; on `ConfigException`, log with tenant/org context and block usage.

2. **Configuration**
   - New config file `config/operator_roles.php` (or inside `assignment_config.php`)
   - Define **role families** and inheritance mapping:
     ```php
     OPERATOR_ROLE_CODES        = ['production_operator','artisan_operator'];
     SUPERVISOR_ROLE_CODES      = ['production_supervisor','quality_manager'];
     ADMIN_ROLE_CODES           = ['production_manager','tenant_admin'];

     ROLE_INHERITANCE = [
         'production_operator' => ['senior_production_operator','apprentice_operator'],
         'artisan_operator'    => ['artisan_trainee']
     ];

     ACCOUNT_GROUP_FALLBACK = ['production_operator','artisan_operator'];
     ALLOWED_EXTRA_MEMBERS  = []; // manual overrides

     PEOPLE_MONITOR_INCLUDE_SUPERVISORS = false; // tenant-level default toggle
     DEFAULT_FALLBACK_TTL_DAYS = 14; // auto-disable fallback after X days
     ```
   - Helper `OperatorRoleConfig::getAllowedRoles($options)` should expand inheritance recursively and validate configuration. If operator roles missing, throw explicit exception (e.g. `ConfigException`).
   - Provide `OperatorRoleConfig::maskUsername($username)` to enforce PDPA masking uniformly (`user****56` pattern).

3. **Role Resolution Rules**
   1. Prefer **Tenant roles** (`tenant_user_role` + `tenant_role.code`). Include only codes defined in config (after inheritance expansion).
   2. Fallback: **Account groups** (`account_org` + `account_group.group_name`). Only use when tenant roles missing. Log warning for visibility including tenant/org identifiers.
   3. Always require `account.status = 1` (active) and ignore soft-deleted/archived users.
   4. Option `allow_team_members_as_operator` (default false) – when enabled, treat members listed in `team_member` as operator candidates even if role mapping missing. Record warning log with tenant/org, member count, and include timestamp; automatically disable after `DEFAULT_FALLBACK_TTL_DAYS` unless re-enabled manually. Emit WARN once per day while active.
   5. Deduplicate multi-role members (choose lowest privilege role first, e.g. operator before supervisor) so they appear once.
   6. Returned payload should include `source` attribute (e.g. `tenant_role`, `account_group_fallback`, `team_member_fallback`) and `resolved_via` summarizing path (e.g. `tenant_role`, `fallback_with_ttl`).

4. **Service Signature & Observability**
   - Methods should accept both `tenantId` and `orgId` to future-proof multi-org tenants:
     ```php
     getOperatorIds(int $tenantId, int $orgId, array $options = []): array
     getOperatorProfiles(int $tenantId, int $orgId, array $options = []): array
     ```
   - Options support: `include_roles`, `include_supervisors` (default false), `exclude_member_ids`, `allow_team_members_as_operator`, `include_inactive` (for audits only), `bypass_cache` (for admin tools).
   - Emit metrics (compatible with existing logging stack):
     - `opdir.resolve.success`
     - `opdir.resolve.zero_result`
     - `opdir.resolve.fallback_used`
     - `opdir.cache.hit` / `opdir.cache.miss`
     - `opdir.sql.ms` (timer)
   - Log structured events (JSON) including tenantId/orgId, options, fallback usage, TTL status, zero-result hints.

5. **Reusable Output**
   - Standard item schema:
     ```json
     {
       "id_member": 1005,
       "username": "user****56",
       "display_name": "Test Operator",
       "role_code": "production_operator",
       "current_load": 2,
       "teams": [1, 5],
       "source": "tenant_role",
       "resolved_via": "tenant_role"
     }
     ```
   - Only expose PDPA-safe fields. Mask username in service layer when viewer lacks `people.view_detail` permission.
   - Add `hint_code` + `hint_detail` to response metadata when applicable.

6. **Zero-Result Handling**
   - Service returns `hint_code` for known conditions:
     - `'NO_OPERATOR_ROLE'` – no roles configured / resolved (`hint_detail`: guidance + link to config doc)
     - `'FALLBACK_IN_USE'` – fallback via team members currently active (`hint_detail`: include TTL remaining)
   - UI shows informative banner with link/button to admin guide or audit script instead of generic “No data”.

---

## 🛠️ Implementation Outline

### Step 1: Create Operator Directory Service
1. File: `source/service/OperatorDirectoryService.php`
2. Methods (minimum):
   - `getOperatorIds(int $tenantId, int $orgId, array $options = []): array`
   - `getOperatorProfiles(int $tenantId, int $orgId, array $options = []): array`
   - Internal helpers: `resolveRoleCodes($options)`, `filterByRoleCodes(array $rows, array $options)`, `buildPayload(array $rows)`, `enforceFallbackTTL(array $options)`
3. Query design:
   - One CTE/UNION combining tenant roles + fallback groups + optional team member fallback with `source` column.
   - Optional join to aggregated workload view (tokens, work sessions) to return `current_load` efficiently.
   - Per-request cache (static property) and optional tenant TTL cache via simple array + timestamp. Respect fallback TTL to auto-disable `allow_team_members_as_operator` if expired (and log).
   - Throw explicit `ConfigException` if operator role definitions missing/empty. Catch, log, rethrow with context.

### Step 2: Wire Service into APIs (mandatory)
- `hatthasilpa_job_ticket.php?action=users_for_assignment` (both GET & POST callers)
- `assignment_api.php?action=get_available_operators`
- `token_management_api.php?action=get_operators`
- `team_api.php?action=available_operators`
- `team_api.php?action=people_monitor_list`
- Any other endpoint returning user lists must be refactored to this service (enforced via CI lint rule).

Each endpoint should:
- Use the service and pass context-specific options (e.g. People Monitor allow supervisors toggle reads `PEOPLE_MONITOR_INCLUDE_SUPERVISORS`, but allow per-request override parameter for canary).
- Preserve existing response structure but include new fields (`source`, `resolved_via`, `hint_code`, `hint_detail` when empty).
- Remove direct SQL on `account` tables.
- Log usage when fallbacks triggered. Ensure inactive/soft-deleted users filtered before response.

### Step 3: Update Frontend Logic
- Manager Assignment (Tokens/Plans) & Hatthasilpa modal: no code change beyond expecting potential empty lists + hints.
- People Monitor: add optional toggle “รวมหัวหน้างาน/ควบคุมคุณภาพ” ที่อ่านค่าเริ่มต้นจาก config (`PEOPLE_MONITOR_INCLUDE_SUPERVISORS`). Toggle ส่ง `include_supervisors=true/false` ไป API และแสดง `source` badge ใน hover.
- Handle no-operator banner using `hint_code` + `hint_detail`.
- Ensure bulk assign (team + individual) handles zero operators gracefully.
- Align PDPA masking format across all UI components (reuse value from API, no extra masking in JS).

### Step 4: Data Validation / Migration
- Provide CLI script `tools/audit_operator_roles.php` supporting modes:
  - default – human-readable report with summary of gaps
  - `--fix` – assign roles automatically (optional)
  - `--lint` – machine-readable warnings for CI/CD (exit code > 0 on issues)
- Script should detect:
  - members in `team_member` without operator role mapping
  - fallback usage older than TTL (per tenant/org)
  - config anomalies (missing inheritance definitions)
- Document Ops procedure to maintain `tenant_user_role` when adding new staff.
- During rollout set `allow_team_members_as_operator=true` for canary tenants if necessary, then disable after cleanup (auto TTL + audit log ensures visibility).

### Step 5: Configuration, Documentation & CI Guardrails
- Add `config/operator_roles.php` (or extend `assignment_config.php`) documenting role families, inheritance, toggles, TTL behaviour, PDPA masking helper.
- Update `PHASE2_API_REFERENCE.md` to note operator-only responses and new fields/options.
- Create `docs/OPERATOR_ROLE_CONFIGURATION.md` explaining how to add new operator roles/permissions, inheritance rules, and fallback TTL management.
- Update `STATUS.md` / `ROADMAP_V4.md` post-implementation.
- Add CI lint script to fail build if new controller/API code contains `SELECT .* FROM account` without using the service.
- Provide sample config snippet for developers (appendix or separate SPEC if needed).

### Step 6: Deployment Strategy
1. **Canary** – enable filtering for Team Management + People Monitor only. Monitor metrics (`opdir.*`), logs (`source`, `hint_code`, fallback warnings, TTL countdown).
2. Run audit script (`--lint`) nightly; fix role mappings. Ensure fallback TTL countdown tracked and auto disable test runs (verify WARN log).
3. After data clean, expand to Manager Assignment & Token Management. Disable `allow_team_members_as_operator` (should auto-disable after TTL, but verify). Continue monitoring metrics (target `opdir.cache.hit` > 70%, `opdir.sql.ms` P95 < 200ms).
4. Add static scan/lint (CI guard) to prevent new direct queries to `account` in APIs.

---

## 🔬 Testing Strategy

1. **Unit Tests**
   - OperatorDirectoryService covering role codes, inheritance expansion, supervisor inclusion, dedupe, fallback, TTL expiry, PDPA masking, metrics emission.
   - Config validation tests (missing role arrays, malformed inheritance) expect `ConfigException`.
2. **Integration Tests**
   - API endpoints return only operator roles by default.
   - With `include_supervisors=true`, supervisor roles appear with `source='tenant_role'` and badge.
   - Regression: People Monitor counts remain correct; `hint_code` + `hint_detail` present when empty.
   - Verify fallback TTL auto-disables and logs once expired.
3. **Manual QA**
   - Manager Assignment dropdowns exclude admin/manager users.
   - Team Management add-member modal matches filtered list.
   - People Monitor toggle works; displays supervisors when enabled and masks username when permissions missing.
   - Token Management “Assign to operator” search limited appropriately.
   - Canary metrics tracked via dashboard; zero-result scenario shows banner with audit link.
4. **Edge Cases**
   - Tenant with no operators → display banner + hint.
   - Mixed-role users (operator + supervisor) appear once with operator role.
   - New custom role added via config shows correctly without code change (inheritance expansion).
   - `allow_team_members_as_operator` path tested then auto-disabled by TTL (log verifies).
   - Multi-org tenant: ensure service respects both tenantId + orgId.
   - Cache invalidation: verify `bypass_cache` option for admin tools.

---

## ⚠️ Risks & Mitigations

| Risk | Description | Mitigation |
|------|-------------|------------|
| Misconfigured roles | Operators missing role mapping → no one visible | Provide audit script (`--lint`, `--fix`), show UI banner with hint, allow temporary fallback via `allow_team_members_as_operator` + TTL + warning logs |
| Legacy data | Some orgs still rely on `account_org` groups | Keep fallback + log warning, schedule migration to tenant roles |
| Performance | Multiple widgets hitting Core DB | Implement per-request cache + optional tenant TTL cache; reuse workload aggregated query; monitor `opdir.sql.ms` |
| Future role expansion | Need to include nested roles or supervisors/QC | Config-based inheritance + UI toggle; document process |
| PDPA exposure | Sensitive fields leaked | Limit API fields, enforce uniform masking format via service |
| Config errors | Missing role arrays causing runtime failure | Throw explicit `ConfigException` during service bootstrap, include tenant/org in log |
| Fallback overuse | allow_team_members_as_operator left on too long | TTL auto-disable + daily WARN log + audit script report |
| Regression via direct queries | Dev adds new API bypassing service | CI lint guard + code review checklist |

---

## 📅 Suggested Timeline

1. **Day 1:** Implement OperatorDirectoryService + config (with inheritance, TTL, logging, metrics, masking), create unit test skeleton, update `users_for_assignment`, `available_operators`, deploy canary (Team Management & People Monitor).
2. **Day 2:** Update remaining APIs (`assignment_api`, `token_management_api`, `people_monitor_list`), add unit/integration tests, create audit script (supporting `--lint`), add CI guard and metrics wiring.
3. **Day 3:** Run audit fixes, verify fallback TTL auto-disable + metrics targets (cache hit >70%, `opdir.sql.ms` P95 < 200ms), expand rollout to Manager Assignment & Token Management, update documentation, deploy globally.

---

## ✅ Next Actions
- [ ] Review plan with Planning AI / stakeholders
- [ ] Confirm operator role codes, inheritance, supervisor list (default vs. custom)
- [ ] Approve timeline & resource allocation
- [ ] Build OperatorDirectoryService + config scaffolding (include tenantId/orgId, observability, TTL enforcement)
- [ ] Implement API integrations + tests + CI guard
- [ ] Run audit (`--lint`) + canary rollout, monitor fallback TTL & metrics
- [ ] Proceed with full deployment after sign-off

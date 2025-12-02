# 🛡️ Enterprise API Helpers - Implementation Status

**Version:** 1.0  
**Date:** November 8, 2025, 15:00 ICT  
**Purpose:** ติดตามสถานะการ integrate Enterprise helpers (RateLimiter, RequestValidator, Idempotency) ใน API ทั้งระบบ

---

## ✅ APIs with Enterprise Features (9 files)

| File | Rate Limiting | Request Validator | Idempotency | ETag/If-Match | Maintenance Mode | Execution Time | DatabaseHelper | PSR-4 | Header Refactor | Status |
|------|---------------|------------------|-------------|---------------|------------------|----------------|----------------|-------|----------------|--------|
| `work_centers.php` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **Complete** |
| `materials.php` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **Complete** |
| `dashboard.php` | ✅ | - | - | - | ✅ | ✅ | ✅ | ✅ | ✅ | **Complete** |
| `bom.php` | ✅ | ✅ | ✅ | - | ✅ | ✅ | ✅ | ✅ | ✅ | **Complete** |
| `qc_rework.php` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **Complete** |
| `system_log.php` | ✅ | ✅ | - | - | ✅ | ✅ | ✅ | ✅ | ✅ | **Complete** |
| `hatthasilpa_job_ticket.php` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **Complete** |
| `hatthasilpa_schedule.php` | ✅ | ✅ | ✅ | - | ✅ | ✅ | ✅ | ✅ | ✅ | **Complete** |
| `assignment_api.php` | ✅ | ✅ | ✅ | - | ✅ | ✅ | ✅ | ✅ | ✅ | **Complete** |
| `team_api.php` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **Complete** 🆕 |

**Total:** 9/57 API files (16%)

---

## ❌ APIs without Enterprise Features (48 files)

### High Priority (Core Production APIs)

| File | Priority | Reason |
|------|----------|--------|
| `dag_token_api.php` | 🟡 **MEDIUM** | DAG token operations, future system |
| `dag_routing_api.php` | 🟡 **MEDIUM** | DAG routing, future system |
| `assignment_plan_api.php` | 🟡 **MEDIUM** | Assignment planning |

### Platform Admin APIs

| File | Priority | Reason |
|------|----------|--------|
| `platform_health_api.php` | 🟢 **LOW** | Health check, read-only |
| `platform_dashboard_api.php` | 🟢 **LOW** | Dashboard metrics, read-only |
| `platform_roles_api.php` | 🟡 **MEDIUM** | Role management |
| `platform_tenant_owners_api.php` | 🟡 **MEDIUM** | Tenant owner management |
| `platform_migration_api.php` | 🟢 **LOW** | Migration operations, admin only |
| `tenant_users_api.php` | 🟡 **MEDIUM** | Tenant user management |
| `exceptions_api.php` | 🟢 **LOW** | Exception logging |

### Inventory & Material Management

| File | Priority | Reason |
|------|----------|--------|
| `products.php` | 🟡 **MEDIUM** | Product CRUD operations |
| `product_categories.php` | 🟢 **LOW** | Category management |
| `uom.php` | 🟢 **LOW** | Unit of measure management |
| `warehouses.php` | 🟡 **MEDIUM** | Warehouse management |
| `locations.php` | 🟡 **MEDIUM** | Location management |
| `stock_on_hand.php` | 🟡 **MEDIUM** | Stock queries |
| `stock_card.php` | 🟢 **LOW** | Stock card reports |
| `mo.php` | 🟡 **MEDIUM** | Manufacturing orders |

### Transaction APIs

| File | Priority | Reason |
|------|----------|--------|
| `grn.php` | 🟡 **MEDIUM** | Goods receipt notes |
| `transfer.php` | 🟡 **MEDIUM** | Stock transfers |
| `adjust.php` | 🟡 **MEDIUM** | Stock adjustments |
| `issue.php` | 🟡 **MEDIUM** | Material issues |
| `purchase_rfq.php` | 🟢 **LOW** | Purchase RFQ |
| `routing.php` | 🟢 **LOW** | Routing management |
| `refs.php` | 🟢 **LOW** | Reference data |

### Other APIs

| File | Priority | Reason |
|------|----------|--------|
| `hatthasilpa_jobs_api.php` | 🟡 **MEDIUM** | Jobs API |
| `token_management_api.php` | 🟡 **MEDIUM** | Token management |
| `pwa_scan_api.php` | 🟡 **MEDIUM** | PWA scan operations |
| `dashboard_qc_metrics.php` | 🟢 **LOW** | QC metrics dashboard |
| `sales_report.php` | 🟢 **LOW** | Sales reports |
| `notifications.php` | ⏸️ **DEFERRED** | User requested to skip |

### Legacy/Admin Files (Lower Priority)

| File | Priority | Reason |
|------|----------|--------|
| `admin_rbac.php` | 🟢 **LOW** | Admin RBAC |
| `admin_org.php` | 🟢 **LOW** | Admin org management |
| `member.php` | 🟢 **LOW** | Member management |
| `profile.php` | 🟢 **LOW** | User profile |
| `lang_switch.php` | 🟢 **LOW** | Language switching |
| `page.php` | 🟢 **LOW** | Page routing |
| `import_csv.php` | 🟢 **LOW** | CSV import |
| `export_csv.php` | 🟢 **LOW** | CSV export |
| `run_tenant_migrations.php` | 🟢 **LOW** | Migration runner |
| `bootstrap_migrations.php` | 🟢 **LOW** | Migration bootstrap |
| `invite_accept.php` | 🟢 **LOW** | Invite acceptance |
| `member_login.php` | 🟢 **LOW** | Login handler |

---

## 📋 Implementation Checklist Template

สำหรับแต่ละ API ที่จะ migrate:

- [ ] Add comprehensive docblock (Purpose, Features, CRITICAL INVARIANTS)
- [ ] Add `require_once __DIR__ . '/../vendor/autoload.php';`
- [ ] Import helpers: `use BGERP\Helper\RateLimiter;`, `use BGERP\Helper\RequestValidator;`, `use BGERP\Helper\Idempotency;`
- [ ] Add execution timer: `$__t0 = microtime(true);`
- [ ] Add maintenance mode check: `if (file_exists(__DIR__ . '/../storage/maintenance.flag'))`
- [ ] Add Correlation ID: `$cid = $_SERVER['HTTP_X_CORRELATION_ID'] ?? bin2hex(random_bytes(8));`
- [ ] Add AI Trace metadata (will update with execution_ms later)
- [ ] Add Rate Limiting: `RateLimiter::check($member, 120, 60, 'endpoint_name');`
- [ ] Replace manual validation with `RequestValidator::make()`
- [ ] Add Idempotency for create operations
- [ ] Add ETag/If-Match for update operations
- [ ] Add Cache-Control headers for read operations
- [ ] Update error handling to use `app_code`
- [ ] Add execution_ms tracking in AI-Trace
- [ ] Wrap switch in top-level try-catch
- [ ] Update error contract to use `internal_error` key
- [ ] Test syntax: `php -l source/file.php`

---

## 🎯 Migration Priority Order

### Phase 1: Critical Production APIs (7 files)
1. ✅ `hatthasilpa_job_ticket.php` - Core job ticket operations
2. ✅ `assignment_api.php` - Work assignments
3. ✅ `hatthasilpa_schedule.php` - Production scheduling
4. ✅ `team_api.php` - Team management
5. `dag_token_api.php` - DAG tokens (future system)
6. `dag_routing_api.php` - DAG routing (future system)
7. `assignment_plan_api.php` - Assignment planning

### Phase 2: Platform & Tenant Management (7 files)
8. `platform_roles_api.php`
9. `platform_tenant_owners_api.php`
10. `tenant_users_api.php`
11. `exceptions_api.php`
12. `platform_health_api.php` (read-only, minimal changes)
13. `platform_dashboard_api.php` (read-only, minimal changes)
14. `platform_migration_api.php` (admin only)

### Phase 3: Inventory & Material Management (8 files)
15. `products.php`
16. `warehouses.php`
17. `locations.php`
18. `mo.php`
19. `stock_on_hand.php`
20. `product_categories.php`
21. `uom.php`
22. `stock_card.php`

### Phase 4: Transaction APIs (5 files)
23. `grn.php`
24. `transfer.php`
25. `adjust.php`
26. `issue.php`
27. `purchase_rfq.php`

### Phase 5: Other APIs (5 files)
28. `hatthasilpa_jobs_api.php`
29. `token_management_api.php`
30. `pwa_scan_api.php`
31. `dashboard_qc_metrics.php`
32. `sales_report.php`
33. `routing.php`
34. `refs.php`

### Phase 6: Legacy/Admin Files (19 files)
- Lower priority, can be migrated gradually

---

## 📊 Progress Tracking

**Current Status:**
- ✅ **9 APIs** with Enterprise features (16%)
- ⚠️ **1 API** with partial features (1.8%)
- ❌ **47 APIs** without Enterprise features (82.5%)

**Recent Progress (Nov 8, 2025):**
- ✅ `hatthasilpa_job_ticket.php` - Complete with DatabaseHelper + PSR-4
- ✅ `hatthasilpa_schedule.php` - Complete with DatabaseHelper + PSR-4
- ✅ `assignment_api.php` - Complete with Enterprise features
- ✅ `team_api.php` - Complete with Enterprise features + Header Refactoring
- ✅ PSR-4 Migration: ScheduleService, CapacityCalculator (4 files), OperatorRoleConfig
- ✅ Header Management Refactoring: `set_cache_header()` helper + auto Content-Type

**Target:**
- 🎯 **100%** of production APIs (Phase 1-3) by end of Q4 2025
- 🎯 **100%** of all APIs by end of Q1 2026

---

## 🔗 Related Documentation

- [API Structure Audit](./API_STRUCTURE_AUDIT.md) - Complete API standards
- [API Development Guide](./guide/API_DEVELOPMENT_GUIDE.md) - Complete development guide (Enterprise+ Edition)
- [Development Guides Index](./guide/README.md) - All development guides
- [Developer Policy](./DEVELOPER_POLICY.md) - Development guidelines
- [.cursorrules](../.cursorrules) - AI agent governance rules

---

**Last Updated:** November 8, 2025, 23:45 ICT


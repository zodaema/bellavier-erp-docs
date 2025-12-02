# 📋 Phase 7-10 Implementation Guide - สรุปแผนและเอกสารที่ต้องรู้

**วันที่สร้าง:** 11 พฤศจิกายน 2025  
**สถานะ:** Phase 7 In Progress (20%) - T1✅, T2✅, T5✅ | T3-T9 Pending  
**Timeline:** 4-6 weeks total (Phase 7: 1-2 weeks, Phase 8: 1-1.5 weeks, Phase 9: 1 week, Phase 10: 1-1.5 weeks)

---

## 🎯 สถานะปัจจุบัน (Current Status)

### ✅ Phase 1-6: Complete - Production Ready
- **Phase 1:** Critical Features ✅
- **Phase 2:** Important Features ✅
- **Phase 3:** Validation Rules ✅
- **Phase 4:** Runtime Semantics ✅
- **Phase 5:** UI/UX ✅
- **Phase 6:** Testing & Rollout ✅

### 🚧 Phase 7: Assignment System Integration - In Progress (20%)

| Task | Status | Description |
|------|--------|-------------|
| **T1: Database Schema** | ✅ Complete | `team_availability`, `operator_availability`, `leave_request`, `assignment_log` tables created |
| **T2: Assignment Resolver Service** | ✅ Complete | `AssignmentResolverService.php` - PIN > PLAN > AUTO precedence |
| **T3: Assignment API Endpoints** | ⏳ Pending | `assignment/preview`, `assignment/override`, `assignment/pin`, `assignment/plan` CRUD |
| **T4: Runtime Integration** | ⏳ Pending | Wire `TokenLifecycleService` and `DAGRoutingService` to resolver |
| **T5: Manager Assignment UI** | ✅ Complete | Activity tab, Tokens tab with preview, Quick actions (PIN, OVERRIDE, HELP) |
| **T6: Operator Work Queue UI** | ⏳ Pending | Show assignment reason, queue position, help/reassign badges |
| **T7: Testing & DoD** | ⏳ Pending | Unit tests (30 cases), Integration tests (20 cases) |
| **T8: Metrics & Alerts** | ⏳ Pending | Assignment metrics, alerts for failures |
| **T9: Rollout & Feature Flags** | ⏳ Pending | Gradual rollout plan, feature flags |

### 📋 Phase 8-10: Planned (Ready to Start)

**Phase 8:** Job Ticket (OEM) Integration (1-1.5 weeks)
- T10-T18: OEM schema, API, UI, Reports, Testing

**Phase 9:** People System Integration (1 week)
- T19-T26: People cache, Sync adapter, API, UI, Testing

**Phase 10:** Production Dashboard Integration (1-1.5 weeks)
- T27-T34: Materialized tables, Dashboard API, UI (WIP/Bottlenecks/Trends), Testing

---

## 📚 เอกสารที่ต้องอ่านก่อนเริ่ม Implement (Mandatory Reading)

### 🚨 Critical Documents (อ่านก่อนเริ่มงาน)

#### 1. **API Development Guide** ⭐⭐⭐
**ไฟล์:** `docs/guide/API_DEVELOPMENT_GUIDE.md`
**เวลา:** 30 นาที
**เนื้อหา:**
- API template structure (`source/api_template.php`)
- Enterprise features checklist
- PSR-4 service layer integration
- Idempotency, Rate Limiting, ETag, Concurrency Control
- Error code policy
- Security standards

**Key Points:**
- ใช้ `api_template.php` เป็น starting point เสมอ
- ทุก API ต้องมี: Auth, Rate Limiting, Tenant Resolution, Service Binding
- ใช้ `RequestValidator::make()` สำหรับ input validation
- ใช้ `Idempotency::guard()` และ `Idempotency::store()` สำหรับ create operations
- ใช้ ETag + If-Match สำหรับ concurrency control

#### 2. **Phase 7-10 Task Board** ⭐⭐⭐
**ไฟล์:** `docs/routing_graph_designer/PHASE7_10_TASK_BOARD.md`
**เวลา:** 45 นาที
**เนื้อหา:**
- Detailed task breakdown สำหรับ Phase 7-10
- Database schema specifications
- API endpoint specifications
- UI/UX requirements
- Testing requirements
- Success criteria

**Key Points:**
- Phase 7: Assignment System (PIN > PLAN > AUTO precedence)
- Phase 8: OEM Integration (batch-first, no tokens)
- Phase 9: People Integration (read-only sync)
- Phase 10: Production Dashboard (real-time WIP/Throughput)

#### 3. **Current Status** ⭐⭐
**ไฟล์:** `docs/routing_graph_designer/CURRENT_STATUS.md`
**เวลา:** 15 นาที
**เนื้อหา:**
- System maturity assessment
- Completed phases summary
- Next steps

#### 4. **Database Migration Guide** ⭐⭐
**ไฟล์:** `database/MIGRATION_GUIDE.md`
**เวลา:** 20 นาที
**เนื้อหา:**
- Migration file naming (`YYYY_MM_description.php`)
- Idempotent helper functions
- FK-safe operations
- Best practices

**Key Points:**
- ทุก migration ต้อง idempotent (รันซ้ำได้)
- ใช้ helper functions: `migration_create_table_if_missing()`, `migration_add_column_if_missing()`
- FK operations ต้อง wrap ด้วย `SET FOREIGN_KEY_CHECKS=0/1`
- Back-fill data สำหรับ existing records

#### 5. **PSR-4 Architecture** ⭐⭐
**ไฟล์:** `composer.json` (autoload section)
**เวลา:** 10 นาที
**เนื้อหา:**
- PSR-4 autoloading structure
- Service layer organization
- Namespace conventions

**Key Points:**
- Services อยู่ใน `source/BGERP/Service/`
- ใช้ `use` statements แทน `require_once`
- Service files ที่เรียก service อื่น ใช้ autoload (ไม่ต้อง `require_once`)
- Type hints: ใช้ `\mysqli` แทน `mysqli` (global class)

---

## 🏗️ Architecture Patterns ที่ต้องรู้

### 1. **Multi-Tenant Architecture**
- **Core DB:** `bgerp` (shared data)
- **Tenant DB:** `bgerp_t_{org_code}` (tenant-specific data)
- **Cross-DB Queries:** 2-step pattern (query Core → query Tenant)
- **Tenant Resolution:** `resolve_current_org()` → `tenant_db($org['code'])`

### 2. **Service Layer Pattern**
- **Location:** `source/BGERP/Service/`
- **Naming:** `{Feature}Service.php` (e.g., `AssignmentResolverService.php`)
- **Dependencies:** ใช้ `use` statements (PSR-4 autoloading)
- **Database:** Constructor injection (`__construct(\mysqli $db)`)

### 3. **API Development Pattern**
```php
// Standard structure (from api_template.php)
1. Session + Autoload + Config
2. Auth check (must_allow_routing)
3. Maintenance mode check
4. Rate limiting (RateLimiter::check)
5. Tenant resolution (resolve_current_org)
6. Database connection (DatabaseHelper)
7. Service binding (ServiceFactory::fromApiFile)
8. Action routing (switch ($action))
9. Error handling (try-catch with json_error)
```

### 4. **Assignment Precedence**
```
PIN > PLAN > AUTO
- PIN: assignment_plan_node/job with highest priority
- PLAN: assignment_plan_node/job ordered by priority
- AUTO: team_category matching + load balancing
```

### 5. **Feature Flags Pattern**
```php
// Check feature flag
if (!getFeatureFlag('enable_assignment_runtime', false)) {
    return ['method' => 'MANUAL']; // Fallback
}

// Rollout plan: Gradual (10% → 50% → 100%)
```

---

## 🔧 Technical Requirements

### Database
- **Migration Files:** `database/tenant_migrations/YYYY_MM_description.php`
- **Idempotent:** ทุก migration รันซ้ำได้
- **FK-Safe:** Wrap FK operations ด้วย `SET FOREIGN_KEY_CHECKS=0/1`
- **Indexes:** Performance indexes สำหรับ queries

### API Endpoints
- **Template:** `source/api_template.php`
- **Validation:** `RequestValidator::make()`
- **Idempotency:** `Idempotency::guard()` + `Idempotency::store()`
- **Concurrency:** ETag + If-Match headers
- **Rate Limiting:** `RateLimiter::check()`
- **Permissions:** `must_allow_routing($member, 'view'|'manage')`

### Services
- **Location:** `source/BGERP/Service/`
- **PSR-4:** ใช้ `use` statements
- **Type Hints:** `\mysqli` สำหรับ database connection
- **Error Handling:** Throw `\RuntimeException` with descriptive messages

### Frontend
- **jQuery:** Main framework
- **DataTables:** สำหรับ table display
- **SweetAlert2:** สำหรับ dialogs
- **i18n:** `t('key', 'fallback')` สำหรับ translations
- **Toastr:** สำหรับ notifications (configured in `graph_designer.js`)

---

## 📋 Phase 7: Next Steps (T3-T9)

### T3: Assignment API Endpoints (Day 4-5)
**Files to Create:**
- `source/assignment_api.php` (อาจมีอยู่แล้ว - เพิ่ม endpoints)

**Endpoints to Implement:**
1. `assignment/preview` - GET (read-only, returns assignment explanation)
2. `assignment/override` - POST (manual override)
3. `assignment/pin` - POST (set/unset PIN)
4. `assignment/plan` - CRUD (create, update, delete, list)

**Key Requirements:**
- Permission checks (`must_allow_routing($member, 'manage')`)
- Input validation (`RequestValidator::make()`)
- Idempotency support (create endpoints)
- Assignment log creation
- Alternatives[] with metrics (preview endpoint)

### T4: Runtime Integration (Day 6-7)
**Files to Modify:**
- `source/BGERP/Service/TokenLifecycleService.php`
- `source/BGERP/Service/DAGRoutingService.php`

**Changes:**
1. **TokenLifecycleService::spawnToken():**
   - Call `AssignmentResolverService::resolveAssignment()`
   - Log to `assignment_log`
   - Set token `assigned_to_type` and `assigned_to_id`
   - Handle queue if limits reached

2. **DAGRoutingService::routeToNode():**
   - Check if assignment needed
   - Call resolver if not assigned
   - Handle queue if limits reached

### T6: Operator Work Queue UI (Day 9-10)
**Files to Modify:**
- `assets/javascripts/work_queue/operator_work_queue.js`

**Enhancements:**
- Show assignment reason (why assigned)
- Show "Helped by ..." badge (help mode)
- Show "Reassigned from ..." badge (reassign)
- Show queue position (if queued)
- Show estimated wait time

### T7: Testing & DoD (Day 11-12)
**Files to Create:**
- `tests/Unit/AssignmentResolverServiceTest.php` (30 test cases)
- `tests/Integration/AssignmentIntegrationTest.php` (20 test cases)

**Test Coverage:**
- PIN precedence (node > job)
- PLAN precedence (node > job)
- AUTO assignment logic
- Availability filtering
- WIP/concurrency limits
- Queue position calculation
- Round-robin tie-breaker
- Edge cases

**Success Criteria:**
- All unit tests passing (30/30)
- All integration tests passing (20/20)
- p95 resolve latency < 50ms
- Assignment log accuracy 100%

### T8: Metrics & Alerts (Day 12)
**Metrics to Track:**
- `assignment_resolve_latency_ms` (histogram)
- `assignment_auto_ratio` (counter)
- `team_load_variance` (gauge)

**Alerts:**
- `assignment_auto_failure_rate > 2%` over 5 minutes → Alert

### T9: Rollout & Feature Flags (Day 13-14)
**Feature Flags:**
- `enable_assignment_runtime` (default: false)
- `enable_assignment_preview` (default: false)

**Rollout Plan:**
1. Week 1: Test graphs only
2. Week 2: 10% of production graphs
3. Week 3: 50% of production graphs
4. Week 4: 100% of production graphs

---

## 🔗 Dependencies & Integration Points

### Phase 7 Dependencies:
- ✅ T1: Database schema (Complete)
- ✅ T2: AssignmentResolverService (Complete)
- ⏳ T3: API endpoints (needs T2)
- ⏳ T4: Runtime integration (needs T2, T3)
- ✅ T5: Manager UI (Complete)
- ⏳ T6: Operator UI (needs T4)
- ⏳ T7: Testing (needs T3, T4)
- ⏳ T8: Metrics (needs T4)
- ⏳ T9: Rollout (needs T7, T8)

### Phase 8 Dependencies:
- Needs Phase 7 (assignment system)

### Phase 9 Dependencies:
- Can start in parallel with Phase 7 (independent)

### Phase 10 Dependencies:
- Needs Phase 7 (assignment data)
- Needs Phase 8 (OEM data)

---

## ⚠️ Critical Warnings

### 1. **PSR-4 Compliance**
- ❌ **NEVER** use `require_once` for services in `BGERP/Service/`
- ✅ **ALWAYS** use `use BGERP\Service\...` statements
- ✅ Services ที่เรียก service อื่น ใช้ autoload (Composer จัดการให้)

### 2. **Tenant Isolation**
- ✅ **ALWAYS** verify tenant context (`resolve_current_org()`)
- ✅ **ALWAYS** use tenant DB (`tenant_db($org['code'])`)
- ❌ **NEVER** query cross-tenant data
- ✅ Test cross-tenant isolation

### 3. **Database Migrations**
- ✅ **ALWAYS** make migrations idempotent
- ✅ **ALWAYS** wrap FK operations with `SET FOREIGN_KEY_CHECKS=0/1`
- ✅ **ALWAYS** back-fill data for existing records
- ✅ **ALWAYS** add performance indexes

### 4. **API Development**
- ✅ **ALWAYS** use `api_template.php` as starting point
- ✅ **ALWAYS** include: Auth, Rate Limiting, Tenant Resolution
- ✅ **ALWAYS** validate inputs (`RequestValidator::make()`)
- ✅ **ALWAYS** handle errors (`json_error()` with app_code)
- ✅ **ALWAYS** support idempotency (create endpoints)

### 5. **Error Handling**
- ✅ **ALWAYS** use `json_error()` with `app_code`
- ✅ **ALWAYS** log errors (`error_log()`)
- ✅ **ALWAYS** include `X-AI-Trace` header
- ✅ **ALWAYS** return meaningful error messages

---

## 📖 Reference Documents

### Core Documents:
1. **`docs/routing_graph_designer/PHASE7_10_TASK_BOARD.md`** - Detailed task breakdown
2. **`docs/routing_graph_designer/CURRENT_STATUS.md`** - Current status
3. **`docs/routing_graph_designer/REMAINING_TASKS.md`** - Remaining tasks summary
4. **`docs/routing_graph_designer/FULL_DAG_DESIGNER_ROADMAP.md`** - Complete roadmap

### Development Guides:
5. **`docs/guide/API_DEVELOPMENT_GUIDE.md`** - API development standards
6. **`database/MIGRATION_GUIDE.md`** - Migration best practices
7. **`docs/developer/01-policy/DEVELOPER_POLICY.md`** - Developer standards

### Architecture:
8. **`docs/assignment-team/01-requirements/ASSIGNMENT_ENGINE_REQUIREMENTS.md`** - Assignment requirements
9. **`source/api_template.php`** - API template (reference implementation)

### Code Examples:
10. **`source/hatthasilpa_jobs_api.php`** - Example API implementation
11. **`source/BGERP/Service/AssignmentResolverService.php`** - Service example
12. **`assets/javascripts/manager/assignment.js`** - Frontend example

---

## 🎯 Quick Start Checklist

### Before Starting ANY Task:

- [ ] ✅ อ่าน `PHASE7_10_TASK_BOARD.md` (45 นาที)
- [ ] ✅ อ่าน `API_DEVELOPMENT_GUIDE.md` (30 นาที)
- [ ] ✅ อ่าน `MIGRATION_GUIDE.md` (20 นาที)
- [ ] ✅ อ่าน `CURRENT_STATUS.md` (15 นาที)
- [ ] ✅ ตรวจสอบ `api_template.php` (10 นาที)
- [ ] ✅ ตรวจสอบ existing code patterns (grep, codebase_search)
- [ ] ✅ Verify database schema (check existing migrations)
- [ ] ✅ Verify service structure (check `BGERP/Service/`)

### For Each Task:

- [ ] ✅ Copy `api_template.php` (if creating API)
- [ ] ✅ Follow PSR-4 autoloading (use statements)
- [ ] ✅ Make migrations idempotent
- [ ] ✅ Add input validation
- [ ] ✅ Add error handling
- [ ] ✅ Add tests
- [ ] ✅ Update documentation
- [ ] ✅ Test in browser (if UI)

---

## 📊 Success Criteria Summary

### Phase 7:
- ✅ Auto-assign coverage ≥ 80%
- ✅ Team load variance ลด ≥ 25%
- ✅ p95 resolve latency < 50ms
- ✅ Assignment log accuracy 100%

### Phase 8:
- ✅ Late-step detection accuracy ≥ 95%
- ✅ Sequence validation 100% accurate

### Phase 9:
- ✅ People outage → ERP continues (degraded) 100%
- ✅ Sync latency < 5s/1k records
- ✅ Cache hit rate > 95%

### Phase 10:
- ✅ Dashboard p95 latency < 1.5s
- ✅ Adoption ≥ 90% of Managers within 2 weeks

---

**Last Updated:** November 11, 2025  
**Status:** 📋 Ready for Implementation  
**Next:** Start Phase 7 T3 - Assignment API Endpoints


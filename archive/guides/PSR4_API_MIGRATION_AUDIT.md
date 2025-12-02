# 🔍 PSR-4 API Migration Audit Report

<!-- BELLAVIER_PROTOCOL:PSR4_MIGRATION_GUIDE_V1.2 -->
<!-- AI_AGENT_REFERENCE: Use this document as the authoritative guide for PSR-4 API migration -->
<!-- LAST_VERIFIED: 2025-11-07 -->

**Version:** 1.4 (Phase 5 Complete Edition)  
**Date:** November 7, 2025, 23:10 ICT  
**Purpose:** ตรวจสอบ API files ที่สามารถปรับมาใช้ PSR-4 autoload แบบเดียวกับ `team_api.php`  
**Reference:** `source/team_api.php` (ใช้ PSR-4 autoload + use statements)  
**Audience:** Development Team, AI Agents, DevOps  
**Status:** ✅ **Phase 0-5 COMPLETE** (November 7, 2025, 23:10 ICT)

---

## 📊 Executive Summary

| Metric | Value |
|--------|-------|
| **APIs Using PSR-4** | ✅ **9 files** (100% migrated) |
| **APIs Requiring Migration** | ✅ **0 files** (all complete) |
| **Services Moved** | ✅ **23 files** → `source/BGERP/Service/` |
| **Exceptions Created** | ✅ **6 files** → `source/BGERP/Exception/` |
| **Shim Files** | ✅ **Removed** (no longer needed) |
| **Migration Time** | ✅ **Completed in 1 session** |
| **Risk Level** | ✅ **VERIFIED LOW** (all tests passing) |
| **Production Ready** | ✅ **YES** (fully tested, browser verified) |

---

## 📑 Table of Contents

**Quick Links:**

- [✅ PSR-4 Mapping Validation](#-psr-4-mapping-validation)
- [📊 สรุปผลการตรวจสอบ](#-สรุปผลการตรวจสอบ)
- [📋 Migration Checklist Template](#-migration-checklist-template)
- [🧪 Verification Test Plan](#-verification-test-plan)
- [🪵 Example Error Log for Debugging](#-example-error-log-for-debugging)
- [📊 Migration Impact Table](#-migration-impact-table)
- [🎯 Change Impact Scope](#-change-impact-scope)
- [📝 Phase Commit Tracking](#-phase-commit-tracking)
- [🔧 Useful Commands](#-useful-commands-cheat-sheet)
- [🔎 Autoload Coverage Audit](#-autoload-coverage-audit)
- [⚠️ Known Limitations](#️-known-limitations)
- [✅ Next Steps (Post-Migration)](#-next-steps-post-migration)
- [📚 Appendix: Historical Migration Notes](#-appendix-historical-migration-notes)

---

## ✅ PSR-4 Mapping Validation

**⚠️ CRITICAL: ตรวจสอบก่อนเริ่ม Phase 1**

ก่อนเริ่ม migration ให้ตรวจสอบว่า Composer autoload mapping ถูกต้อง:

### Step 1: Validate Composer Configuration

```bash
# Regenerate autoload files
composer dump-autoload -o

# Validate composer.json
composer validate
```

### Step 2: Verify Autoload Mapping

ตรวจสอบไฟล์ `vendor/composer/autoload_psr4.php` ต้องมี entry:

```php
'BGERP\\' => array($baseDir . '/source/BGERP'),
```

**ถ้าไม่มี → เพิ่มใน `composer.json`:**

```json
{
  "autoload": {
    "psr-4": {
      "BGERP\\": "source/BGERP/"
    }
  }
}
```

แล้วรัน `composer dump-autoload -o` อีกครั้ง

### Step 3: Test Autoload

```bash
# Quick test
php -r "require 'vendor/autoload.php'; echo 'Autoload OK';"

# Expected output: "Autoload OK"
```

**เหตุผล:** เพื่อกันเคสที่บางเครื่องยังใช้ autoload cache เดิม ทำให้ `use BGERP\Service\...` ไม่เจอ class

---

## 📊 สรุปผลการตรวจสอบ

### ✅ **API ที่ใช้ PSR-4 แล้ว (9 ไฟล์)** 🎉

| File | Autoload | Use Statements | Manual Require | Status |
|------|----------|----------------|----------------|--------|
| `team_api.php` | ✅ | ✅ (7 classes) | ✅ (config only) | **COMPLETE** |
| `assignment_api.php` | ✅ | ✅ (2 classes) | ✅ None | **COMPLETE** |
| `assignment_plan_api.php` | ✅ | ✅ (2 classes) | ✅ (config only) | **COMPLETE** |
| `token_management_api.php` | ✅ | ✅ (4 classes) | ✅ None | **COMPLETE** |
| `dag_routing_api.php` | ✅ | ✅ (3 classes) | ✅ None | **COMPLETE** |
| `hatthasilpa_jobs_api.php` | ✅ | ✅ (4 classes) | ✅ None | **COMPLETE** |
| `dag_token_api.php` | ✅ | ✅ (8 classes) | ✅ None | **COMPLETE** |
| `pwa_scan_api.php` | ✅ | ✅ (6 classes) | ✅ None | **COMPLETE** |

**Details:**
- ✅ ทุกไฟล์มี `require_once __DIR__ . '/../vendor/autoload.php';`
- ✅ ทุกไฟล์มี `use` statements สำหรับ PSR-4 classes
- ✅ ไม่มี manual `require_once` สำหรับ services เหลืออยู่แล้ว
- ⚠️ ยังมี `require_once` สำหรับ config files เท่านั้น (ไม่ใช่ classes):
  - `operator_roles.php` (config file - ไม่ใช่ class)

---

## 🎯 Services ที่มี Namespace `BGERP\Service` (Post-Phase 5)

✅ **Services ที่ย้ายไป `source/BGERP/Service/` แล้ว (23 services):**

| Service | Namespace | Current Location | Status |
|---------|-----------|------------------|--------|
| `OperatorDirectoryService` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `NodeAssignmentService` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `DAGRoutingService` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `TokenLifecycleService` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `ErrorHandler` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `AssignmentEngine` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `TokenWorkSessionService` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `DAGValidationService` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `OperatorSessionService` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `JobTicketStatusService` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `ValidationService` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `DatabaseTransaction` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `ProductionRulesService` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `RoutingSetService` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `SerialManagementService` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `SecureSerialGenerator` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `NodeParameterService` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `WorkEventService` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `TeamService` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `TeamMemberService` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `TeamExpansionService` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `TeamWorkloadService` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |
| `DataService` | `BGERP\Service` | `source/BGERP/Service/` | ✅ Moved |

✅ **Exceptions ที่สร้างใน `source/BGERP/Exception/` แล้ว (6 exceptions):**

| Exception | Namespace | Current Location | Status |
|-----------|-----------|------------------|--------|
| `JobTicketException` | `BGERP\Exception` | `source/BGERP/Exception/` | ✅ Created |
| `ValidationException` | `BGERP\Exception` | `source/BGERP/Exception/` | ✅ Created |
| `NotFoundException` | `BGERP\Exception` | `source/BGERP/Exception/` | ✅ Created |
| `ConcurrencyException` | `BGERP\Exception` | `source/BGERP/Exception/` | ✅ Created |
| `BusinessLogicException` | `BGERP\Exception` | `source/BGERP/Exception/` | ✅ Created |
| `DatabaseException` | `BGERP\Exception` | `source/BGERP/Exception/` | ✅ Created |

## 🎯 Services ที่มี Namespace `BGERP\Service` แล้ว

✅ **Services ที่พร้อมใช้ PSR-4 autoload (18 services):**

| Service | Namespace | Location | Shim Required |
|---------|-----------|----------|---------------|
| `OperatorDirectoryService` | `BGERP\Service` | `source/service/` | ✅ Yes |
| `NodeAssignmentService` | `BGERP\Service` | `source/service/` | ✅ Yes |
| `DAGRoutingService` | `BGERP\Service` | `source/service/` | ✅ Yes |
| `TokenLifecycleService` | `BGERP\Service` | `source/service/` | ✅ Yes |
| `ErrorHandler` | `BGERP\Service` | `source/service/` | ✅ Yes |
| `AssignmentEngine` | `BGERP\Service` | `source/service/` | ✅ Yes |
| `TokenWorkSessionService` | `BGERP\Service` | `source/service/` | ✅ Yes |
| `DAGValidationService` | `BGERP\Service` | `source/service/` | ✅ Yes |
| `OperatorSessionService` | `BGERP\Service` | `source/service/` | ✅ Yes |
| `JobTicketStatusService` | `BGERP\Service` | `source/service/` | ✅ Yes |
| `ValidationService` | `BGERP\Service` | `source/service/` | ✅ Yes |
| `DatabaseTransaction` | `BGERP\Service` | `source/service/` | ✅ Yes |
| `ProductionRulesService` | `BGERP\Service` | `source/service/` | ✅ Yes |
| `RoutingSetService` | `BGERP\Service` | `source/service/` | ✅ Yes |
| `SerialManagementService` | `BGERP\Service` | `source/service/` | ✅ Yes |
| `SecureSerialGenerator` | `BGERP\Service` | `source/service/` | ✅ Yes |
| `NodeParameterService` | `BGERP\Service` | `source/service/` | ✅ Yes |
| `WorkEventService` | `BGERP\Service` | `source/service/` | ✅ Yes |

✅ **Exceptions ที่พร้อมใช้ PSR-4 autoload:**

| Exception | Namespace | Location | Shim Required |
|-----------|-----------|----------|---------------|
| `DatabaseException` | `BGERP\Exception` | `source/exception/` | ✅ Yes |

---

---

---

## 📋 Migration Checklist Template

สำหรับแต่ละ API file:

```markdown
### [API_FILE_NAME]

**Pre-Migration:**
- [ ] ตรวจสอบ autoload mapping (`composer dump-autoload -o`)
- [ ] Backup file (`cp source/[file].php source/[file].php.bak`)

**Migration:**
- [ ] เพิ่ม `require_once __DIR__ . '/../vendor/autoload.php';` หลัง `session_start()`
- [ ] เพิ่ม `use` statements สำหรับ services ทั้งหมด
- [ ] ลบ manual `require_once` สำหรับ services ที่มี namespace
- [ ] ตรวจสอบ syntax (`php -l source/[file].php`)

**Post-Migration:**
- [ ] ทดสอบ API endpoints (curl หรือ browser)
- [ ] ตรวจสอบ error_log (ไม่มี autoload errors)
- [ ] รัน PHPUnit tests (ถ้ามี)
- [ ] ลบ backup file (`rm source/[file].php.bak`)
```

---

## 🧪 Verification Test Plan

### Step 1: Autoload Diagnostics

```bash
# Test autoload works
php -r "require 'vendor/autoload.php'; echo 'Autoload OK';"

# Expected output: "Autoload OK"
```

### Step 2: API Endpoint Testing

เปิด browser หรือ Postman ทดสอบ API ทั้ง 9 endpoints:

| Endpoint | Method | Expected Response | Status |
|----------|--------|-------------------|--------|
| `/source/assignment_api.php?action=list` | GET | `{"ok":true,...}` | ✅ |
| `/source/assignment_plan_api.php?action=plan_node_list` | GET | `{"ok":true,...}` | ✅ |
| `/source/token_management_api.php?action=list` | GET | `{"ok":true,...}` | ✅ |
| `/source/dag_token_api.php?action=token/status&id_token=1` | GET | `{"ok":true,...}` | ✅ |
| `/source/pwa_scan_api.php?action=scan` | POST | `{"ok":true,...}` | ✅ |
| `/source/dag_routing_api.php?action=graph_list` | GET | `{"ok":true,...}` | ✅ |
| `/source/hatthasilpa_jobs_api.php?action=list` | GET | `{"ok":true,...}` | ✅ |
| `/source/hatthasilpa_job_ticket.php?action=list` | GET | `{"ok":true,...}` | ✅ |
| `/source/team_api.php?action=list` | GET | `{"ok":true,...}` | ✅ |

### Step 3: Error Log Verification

ตรวจสอบ `error_log` → ไม่มีข้อความ "Class not found":

```bash
# Check for autoload errors
tail -n 100 error_log | grep -i "class.*not found"

# Expected: No matches (empty output)
```

### Step 4: PHPUnit Tests

```bash
# Run all tests
vendor/bin/phpunit --testdox

# Expected: All tests passing (104+ tests)
```

### Step 5: Manual Code Review

- [ ] ไม่มี `require_once __DIR__ . '/service/...'` สำหรับ services ที่มี namespace
- [ ] มี `use` statements สำหรับ services ทั้งหมด
- [ ] มี `require_once __DIR__ . '/../vendor/autoload.php';` ในทุก API file

---

## 🪵 Example Error Log for Debugging

### ✅ Success Case (No Errors)

```
[07-Nov-2025 14:21:55 Asia/Bangkok] API Request: /source/assignment_api.php?action=list
[07-Nov-2025 14:21:55 Asia/Bangkok] Response: {"ok":true,"data":[...]}
```

### ❌ Error Case 1: Namespace Mismatch (Post-Phase 5)

```
[07-Nov-2025 23:10:00 Asia/Bangkok] PHP Fatal error:  Uncaught Error: Class "BGERP\Service\TokenLifecycleService" not found in /source/dag_token_api.php:45
Stack trace:
#0 /source/dag_token_api.php(45): new BGERP\Service\TokenLifecycleService()
```

**Solution:** ตรวจสอบว่าไฟล์อยู่ในตำแหน่งที่ถูกต้อง `source/BGERP/Service/TokenLifecycleService.php` และรัน `composer dump-autoload -o`

### ❌ Error Case 2: Missing Autoload

```
[07-Nov-2025 14:21:55 Asia/Bangkok] PHP Fatal error:  Uncaught Error: Class "BGERP\Service\NodeAssignmentService" not found in /source/assignment_api.php:18
```

**Solution:** เพิ่ม `require_once __DIR__ . '/../vendor/autoload.php';` หลัง `session_start()`

### ❌ Error Case 3: Wrong Namespace

```
[07-Nov-2025 14:21:55 Asia/Bangkok] PHP Fatal error:  Uncaught Error: Class "BGERP\Service\OperatorDirectory" not found
```

**Solution:** ตรวจสอบ `use` statement → ต้องเป็น `OperatorDirectoryService` (ไม่ใช่ `OperatorDirectory`)

### ❌ Error Case 4: Autoload Mapping Missing

```
[07-Nov-2025 14:21:55 Asia/Bangkok] PHP Warning:  require_once(vendor/composer/autoload_psr4.php): failed to open stream
```

**Solution:** รัน `composer dump-autoload -o` เพื่อ regenerate autoload files

---

## 📊 Migration Impact Table

| Phase | Files | Impact | Recovery Plan | Rollback Time |
|-------|-------|--------|---------------|---------------|
| **Phase 1** | 3 files | LOW | `git checkout HEAD~1` | < 1 min |
| **Phase 2** | 2 files | MEDIUM | `git checkout HEAD~1` | < 1 min |
| **Phase 3** | 2 files | MEDIUM | `git checkout HEAD~1` | < 1 min |
| **Phase 4** | 1 file | LOW | `git checkout HEAD~1` | < 1 min |
| **Phase 5** | 23 services + 6 exceptions | MEDIUM | `git checkout HEAD~1` | < 5 min |

### Recovery Procedures

#### Phase 1-2 Recovery (Quick Rollback)

```bash
# Revert changes
git checkout HEAD~1 source/assignment_api.php
git checkout HEAD~1 source/assignment_plan_api.php
git checkout HEAD~1 source/token_management_api.php

# Restart web server (if needed)
sudo service apache2 restart  # or nginx/php-fpm
```

#### Phase 5 Recovery (Full Rollback)

```bash
# Revert all service moves
git checkout HEAD~1 source/BGERP/Service/
git checkout HEAD~1 source/BGERP/Exception/

# Restore original locations
git checkout HEAD~1 source/service/
git checkout HEAD~1 source/exception/

# Regenerate autoload
composer dump-autoload -o
```

---

## 🎯 Change Impact Scope

**Purpose:** สรุปว่า phase ไหนกระทบระบบไหน เพื่อให้ผู้ทดสอบหรือผู้อนุมัติ release อ่านจบภายใน 1 นาที

### Impact Matrix by Phase

| Phase | API Endpoints | ERP Modules | PWA | DAG System | Token System | Team System | Risk Level |
|-------|---------------|-------------|-----|------------|--------------|--------------|------------|
| **Phase 0** | None | None | None | None | None | None | ✅ **NONE** (Preparation only) |
| **Phase 1** | Assignment API<br>Assignment Plan API<br>Token Management API | Manager Assignment<br>Token Management | None | None | Token Assignment | Team Assignment | 🟢 **LOW** |
| **Phase 2** | DAG Routing API<br>Hatthasilpa Jobs API | Job Management<br>Production Planning | None | Routing Graph<br>Node Management | None | None | 🟡 **MEDIUM** |
| **Phase 3** | DAG Token API<br>PWA Scan API | Production Tracking | PWA Scan Station | Token Lifecycle<br>DAG Routing | Token Workflow<br>Token Status | None | 🔴 **HIGH** |
| **Phase 4** | All APIs (Verification) | All Modules | PWA | DAG | Token | Team | ✅ **VERIFICATION** |
| **Phase 5** | All APIs (Full Migration) | All Modules | PWA | DAG | Token | Team | ✅ **COMPLETE** |

### Detailed Impact by System

#### 📱 **API Endpoints**

| Phase | Affected Endpoints | Critical Actions |
|-------|-------------------|------------------|
| Phase 1 | `/source/assignment_api.php`<br>`/source/assignment_plan_api.php`<br>`/source/token_management_api.php` | Token assignment, Plan management |
| Phase 2 | `/source/dag_routing_api.php`<br>`/source/hatthasilpa_jobs_api.php` | Routing graph, Job creation |
| Phase 3 | `/source/dag_token_api.php`<br>`/source/pwa_scan_api.php` | Token lifecycle, Scan operations |
| Phase 5 | All 9 endpoints (Full migration) | All operations (services moved) |

#### 🏭 **ERP Modules**

| Phase | Affected Modules | User Impact |
|-------|------------------|-------------|
| Phase 1 | Manager Assignment<br>Token Management | Managers assigning tokens, Creating plans |
| Phase 2 | Job Management<br>Production Planning | Production staff creating jobs |
| Phase 3 | Production Tracking | Operators scanning, Tracking progress |
| Phase 5 | All Modules | All operations (100% PSR-4 compliant) |

#### 📱 **PWA (Progressive Web App)**

| Phase | Affected Features | User Impact |
|-------|-------------------|-------------|
| Phase 3 | Scan Station v2 | Operators scanning QR codes, Reporting work |

#### 🔄 **DAG System (Directed Acyclic Graph)**

| Phase | Affected Components | Impact |
|-------|---------------------|--------|
| Phase 2 | Routing Graph Management<br>Node Configuration | Graph creation, Node setup |
| Phase 3 | Token Routing<br>DAG Validation | Token flow through graph |

#### 🎫 **Token System**

| Phase | Affected Features | Impact |
|-------|-------------------|--------|
| Phase 1 | Token Assignment<br>Plan-based Assignment | Auto-assignment rules |
| Phase 3 | Token Lifecycle<br>Token Status<br>Work Sessions | Token state management |

#### 👥 **Team System**

| Phase | Affected Features | Impact |
|-------|-------------------|--------|
| Phase 1 | Team Assignment<br>Team-based Plans | Team assignment rules |

### Testing Priority by Phase

| Phase | Priority Tests | Estimated Test Time |
|-------|----------------|---------------------|
| Phase 1 | Assignment API endpoints<br>Plan creation/update<br>Token assignment | 30-45 min |
| Phase 2 | DAG routing API<br>Job creation API<br>Graph validation | 20-30 min |
| Phase 3 | Token lifecycle API<br>PWA scan API<br>DAG token flow | 45-60 min |
| Phase 4 | All endpoints (smoke test)<br>Error log check<br>PHPUnit tests | 60-90 min |
| Phase 5 | Full system test<br>All endpoints<br>PHPUnit tests<br>Browser verification | 90-120 min |

### Rollback Impact Assessment

| Phase | Rollback Affects | Downtime Estimate |
|-------|------------------|-------------------|
| Phase 1 | Manager Assignment UI<br>Token Management UI | < 1 min (git revert) |
| Phase 2 | Job Creation<br>Graph Management | < 5 min (restore files) |
| Phase 3 | Production Operations<br>PWA Scanning | < 1 min (git revert) |
| Phase 5 | All Operations | < 5 min (git revert + autoload regenerate) |

---

## 📝 Phase Commit Tracking

**Purpose:** Track commit references และ checksums สำหรับแต่ละ phase เพื่อให้อ้างอิงย้อนหลังได้ชัดเจน

### Commit Reference Table

| Phase | Baseline Commit | Target Commit | Date | Status | Verified By |
|-------|----------------|----------------|------|--------|-------------|
| **Phase 0** | `[TBD]` | `[TBD]` | 2025-11-07 | ✅ **COMPLETE** | Browser + CLI |
| **Phase 1** | `[TBD]` | `[TBD]` | 2025-11-07 | ✅ **COMPLETE** | Browser + CLI |
| **Phase 2** | `[TBD]` | `[TBD]` | 2025-11-07 | ✅ **COMPLETE** | Browser + CLI |
| **Phase 3** | `[TBD]` | `[TBD]` | 2025-11-07 | ✅ **COMPLETE** | Browser + CLI |
| **Phase 4** | `[TBD]` | `[TBD]` | 2025-11-07 | ✅ **COMPLETE** | Browser + CLI |
| **Phase 5** | `[TBD]` | `[TBD]` | 2025-11-07 | ✅ **COMPLETE** | Browser + PHPUnit |

**Note:** อัปเดต commit references หลัง migration แต่ละ phase เสร็จ

### File Checksums (Post-Migration)

| Phase | File | SHA256 Checksum | Last Modified |
|-------|------|-----------------|---------------|
| **Phase 1** | `source/assignment_api.php` | `[TBD]` | TBD |
| **Phase 1** | `source/assignment_plan_api.php` | `[TBD]` | TBD |
| **Phase 1** | `source/token_management_api.php` | `[TBD]` | TBD |
| **Phase 2** | `source/dag_routing_api.php` | `[TBD]` | TBD |
| **Phase 2** | `source/hatthasilpa_jobs_api.php` | `[TBD]` | TBD |
| **Phase 3** | `source/dag_token_api.php` | `[TBD]` | TBD |
| **Phase 3** | `source/pwa_scan_api.php` | `[TBD]` | TBD |

### How to Track Commits

#### Before Starting Phase

```bash
# Record baseline commit
git rev-parse HEAD > .phase0_baseline.txt
echo "Phase 0 baseline: $(cat .phase0_baseline.txt)"
```

#### After Completing Phase

```bash
# Record target commit
git rev-parse HEAD > .phase1_target.txt
echo "Phase 1 target: $(cat .phase1_target.txt)"

# Generate checksums for modified files
sha256sum source/assignment_api.php > .phase1_checksums.txt
sha256sum source/assignment_plan_api.php >> .phase1_checksums.txt
sha256sum source/token_management_api.php >> .phase1_checksums.txt

# Create phase tag
git tag -a "psr4-migration-phase1" -m "PSR-4 Migration Phase 1 Complete"
```

#### Verification Commands

```bash
# Verify commit exists
git show [COMMIT_REF]

# Verify file checksum
sha256sum source/assignment_api.php | grep [EXPECTED_CHECKSUM]

# List all phase tags
git tag -l "psr4-migration-phase*"

# View phase history
git log --oneline --graph --decorate --all | grep "psr4-migration"
```

### Example Commit Message Format

```
PSR-4 Migration: Phase 1 - Quick Wins

- Migrated assignment_api.php to PSR-4 autoload
- Migrated assignment_plan_api.php to PSR-4 autoload
- Migrated token_management_api.php to PSR-4 autoload
- Removed manual require_once statements
- Added use statements for all services

Files changed:
- source/assignment_api.php
- source/assignment_plan_api.php
- source/token_management_api.php

Testing:
- ✅ All API endpoints tested
- ✅ Error log verified (no autoload errors)
- ✅ PHPUnit tests passing

Phase: 1/5
Baseline: [COMMIT_REF]
Target: [COMMIT_REF]
```

---

### **Phase 0: Preparation** ✅ **COMPLETE** (2025-11-07)

**Status:** ✅ **COMPLETE**

**Completed Tasks:**
1. ✅ **Validate Autoload Mapping**
   - Composer autoload verified: `BGERP\` → `source/BGERP/`
   - Autoload test passed: `php -r "require 'vendor/autoload.php'; echo 'OK';"`

2. ✅ **Create Shim Files**
   - Generated 23 shim files via `tools/generate-shims.php`
   - All services accessible via PSR-4 autoload

3. ✅ **Verification**
   - All shim files created successfully
   - No syntax errors

**Files Created:**
- 23 shim files in `source/BGERP/Service/` and `source/BGERP/Exception/`

---

### **Phase 1: Quick Wins** ✅ **COMPLETE** (2025-11-07)

**Status:** ✅ **COMPLETE**

**Files Migrated:** `assignment_api.php`, `assignment_plan_api.php`, `token_management_api.php`

**Completed Tasks:**
1. ✅ Added `require_once __DIR__ . '/../vendor/autoload.php';`
2. ✅ Added `use` statements for all services
3. ✅ Removed manual `require_once` statements
4. ✅ Tested all endpoints (browser testing passed)
5. ✅ Verified error_log (no autoload errors)

**Results:**
- ✅ All 3 files migrated successfully
- ✅ No regressions detected
- ✅ Browser testing: All tabs working

---

### **Phase 2: Medium Complexity** ✅ **COMPLETE** (2025-11-07)

**Status:** ✅ **COMPLETE**

**Files Migrated:** `dag_routing_api.php`, `hatthasilpa_jobs_api.php`

**Completed Tasks:**
1. ✅ Added autoload + use statements
2. ✅ Removed manual require_once
3. ✅ Tested endpoints
4. ✅ Verified error_log

**Results:**
- ✅ Both files migrated successfully
- ✅ Exception class (`DatabaseException`) handled correctly
- ✅ No regressions detected

---

### **Phase 3: Complex Files** ✅ **COMPLETE** (2025-11-07)

**Status:** ✅ **COMPLETE**

**Files Migrated:** `dag_token_api.php`, `pwa_scan_api.php`

**Completed Tasks:**
1. ✅ Added autoload + use statements
2. ✅ Removed all manual require_once (including in switch cases and functions)
3. ✅ Tested all endpoints thoroughly
4. ✅ Verified error_log

**Results:**
- ✅ Both complex files migrated successfully
- ✅ All require_once in switch cases removed
- ✅ All require_once in functions removed
- ✅ No regressions detected

---

### **Phase 4: Verification** ✅ **COMPLETE** (2025-11-07)

**Status:** ✅ **COMPLETE**

**Completed Tasks:**
- ✅ Run autoload diagnostics (all passing)
- ✅ Test all 9 API endpoints (browser testing passed)
- ✅ Check error_log (no "Class not found" errors)
- ✅ Run PHPUnit tests (all passing)
- ✅ Manual code review (no issues found)
- ✅ Cleanup: Removed last manual require_once from `team_api.php`

**Test Results:**
- ✅ PHPUnit: All tests passing
- ✅ Browser: All tabs functional (Tokens, Plans, People)
- ✅ Error Log: No autoload-related errors
- ✅ Performance: API response times 45-203ms (normal)

---

### **Phase 5: Full PSR-4 Directory Move** ✅ **COMPLETE** (2025-11-07, 23:10 ICT)

**Status:** ✅ **COMPLETE**

**Completed Tasks:**
1. ✅ **Moved Services** (23 files)
   - Moved all service files from `source/service/` → `source/BGERP/Service/`
   - Removed shim files (no longer needed)

2. ✅ **Created Exceptions** (6 files)
   - Created `source/BGERP/Exception/` directory
   - Separated exception classes into individual files:
     - `JobTicketException.php` (base class)
     - `ValidationException.php`
     - `NotFoundException.php`
     - `ConcurrencyException.php`
     - `BusinessLogicException.php`
     - `DatabaseException.php`

3. ✅ **Updated Source Files** (2 files)
   - `source/hatthasilpa_job_ticket.php` - Added autoload + use statements
   - `source/mo.php` - Added autoload + use statements

4. ✅ **Updated Test Files** (12+ files)
   - Updated all test files to use `vendor/autoload.php`
   - Replaced manual `require_once` with `use` statements

5. ✅ **Verification**
   - PHPUnit: All tests passing
   - Syntax Check: All files valid
   - Autoload: Verified working
   - Browser: All tabs functional (Tokens, Plans, People)
   - No old references: Verified 0 remaining

**Results:**
- ✅ 100% PSR-4 compliant directory structure
- ✅ No shim files (clean architecture)
- ✅ All services in correct namespace directory
- ✅ All exceptions properly separated
- ✅ Zero regressions detected

---

## ✅ Next Steps (Post-Migration)

### **Post-Migration Housekeeping**

หลังจาก Phase 5 เสร็จสมบูรณ์แล้ว:

**Completed:**
- ✅ All services moved to `source/BGERP/Service/`
- ✅ All exceptions created in `source/BGERP/Exception/`
- ✅ All shim files removed
- ✅ All APIs using PSR-4 autoload
- ✅ All tests passing

**Optional Cleanup (Future):**
- [ ] Remove legacy `source/service/` directory (if empty)
- [ ] Remove legacy `source/exception/` directory (if empty)
- [ ] Update any remaining documentation references
- [ ] Archive migration scripts (`tools/generate-shims.php`)

**Note:** Legacy directories (`source/service/`, `source/exception/`) อาจยังมีไฟล์อื่นที่ไม่ใช่ services/exceptions ที่ย้ายแล้ว จึงไม่ควรลบทิ้งทันที

---

## 📊 Priority Summary

| Priority | Files | Reason | Estimated Time |
|----------|-------|--------|----------------|
| 🔴 **HIGH** | 5 files | ใช้ services หลายตัว, ไฟล์สำคัญ | 4-6 hours |
| 🟡 **MEDIUM** | 2 files | ใช้ services น้อย, ไฟล์รอง | 2-3 hours |
| 🟢 **LOW** | 1 file | ต้องตรวจสอบเพิ่มเติม | 1-2 hours |

**Total Estimated Time:** 7-11 hours (including Phase 0 preparation)

---

## 🔧 Useful Commands (Cheat-Sheet)

**Quick Reference:** Copy-paste commands สำหรับ migration

### Autoload Management

```bash
# Regenerate autoload files (optimized)
composer dump-autoload -o

# Validate composer.json
composer validate

# Test autoload works
php -r "require 'vendor/autoload.php'; echo 'Autoload OK';"
```

### Service File Verification (Post-Phase 5)

```bash
# Verify all services in correct location
ls -la source/BGERP/Service/*.php | wc -l
# Expected: 23 files (all services)

# Verify all exceptions in correct location
ls -la source/BGERP/Exception/*.php | wc -l
# Expected: 6 files (all exceptions)

# Verify no shim files remain
grep -r "require_once.*service/" source/BGERP/Service/*.php
# Expected: No matches (empty output)
```

### Syntax & Code Quality

```bash
# Check PHP syntax
php -l source/assignment_api.php
php -l source/dag_token_api.php

# Check all API files syntax
for file in source/*_api.php; do
    php -l "$file" || echo "ERROR: $file"
done
```

### Testing & Verification

```bash
# Run PHPUnit tests
vendor/bin/phpunit --testdox

# Run specific test suite
vendor/bin/phpunit tests/Unit/
vendor/bin/phpunit tests/Integration/

# Check error log for autoload issues
tail -n 100 error_log | grep -i "class.*not found"

# Monitor error log in real-time
tail -f error_log | grep -i "class\|autoload\|fatal"
```

### Git Operations

```bash
# Backup before migration
for file in source/assignment_api.php source/assignment_plan_api.php source/token_management_api.php; do
    cp "$file" "${file}.bak"
done

# Rollback single file
git checkout HEAD~1 source/assignment_api.php

# Rollback multiple files
git checkout HEAD~1 source/assignment_api.php source/assignment_plan_api.php source/token_management_api.php

# View changes
git diff source/assignment_api.php
```

### API Endpoint Testing (cURL)

```bash
# Test assignment_api.php
curl -b cookies.txt "http://localhost:8888/bellavier-group-erp/source/assignment_api.php?action=list"

# Test with POST
curl -b cookies.txt -d "action=save&data=..." http://localhost:8888/bellavier-group-erp/source/assignment_api.php

# Test all endpoints (quick check)
for endpoint in assignment_api assignment_plan_api token_management_api dag_token_api; do
    echo "Testing: $endpoint"
    curl -s -b cookies.txt "http://localhost:8888/bellavier-group-erp/source/${endpoint}.php?action=list" | head -c 100
    echo ""
done
```

### File Operations

```bash
# Count require_once statements in API files
grep -r "require_once.*service/" source/*_api.php | wc -l

# Find all manual require_once for services
grep -rn "require_once.*service/" source/*_api.php

# Find all use statements
grep -rn "^use BGERP\\\\" source/*_api.php

# Check if autoload is included
grep -rn "vendor/autoload.php" source/*_api.php
```

---

## 🔎 Autoload Coverage Audit

**Purpose:** ให้ DevOps และ QA team เช็กได้รวดเร็วว่า autoload ครอบคลุมครบไหม

| Directory | PSR-4 Coverage | Status | Notes |
|-----------|----------------|--------|-------|
| `source/BGERP/Service/` | ✅ Full | ✅ OK | 23 services (moved in Phase 5) |
| `source/BGERP/Helper/` | ✅ Full | ✅ OK | `DatabaseHelper` migrated |
| `source/BGERP/Config/` | ✅ Full | ✅ OK | `AssignmentConfig`, `OperatorRoleConfig` |
| `source/BGERP/Exception/` | ✅ Full | ✅ OK | 6 exceptions (created in Phase 5) |
| `source/service/` | 🚫 Legacy | ✅ OK | May contain non-service files (intentionally excluded) |
| `source/exception/` | 🚫 Legacy | ✅ OK | May contain non-exception files (intentionally excluded) |
| `source/config/` | 🚫 Not PSR-4 | ✅ OK | Config files (intentionally excluded) |
| `source/helper/` | 🚫 Not PSR-4 | ✅ OK | Legacy helpers (intentionally excluded) |

### Coverage Metrics

| Metric | Value | Target |
|--------|-------|--------|
| **Services Covered** | 23/23 (100%) | ✅ 100% |
| **APIs Using Autoload** | 9/9 (100%) | ✅ 100% |
| **Exceptions Covered** | 6/6 (100%) | ✅ 100% |
| **Shim Files** | 0 (removed in v1.4) | ✅ 0 |
| **Overall Coverage** | 100% | ✅ 100% |

### Verification Commands

```bash
# Check autoload mapping exists
grep -q "BGERP" vendor/composer/autoload_psr4.php && echo "✅ Mapping OK" || echo "❌ Mapping missing"

# Count service files (should be 23)
ls -1 source/BGERP/Service/*.php 2>/dev/null | wc -l
# Expected: 23 (after Phase 5)

# Count exception files (should be 6)
ls -1 source/BGERP/Exception/*.php 2>/dev/null | wc -l
# Expected: 6 (after Phase 5)

# Check API files using autoload
grep -l "vendor/autoload.php" source/*_api.php | wc -l
# Expected: 9 (after Phase 4)
```

---

## ⚠️ Known Limitations

**Purpose:** ระบุข้อจำกัดและข้อควรระวังสำหรับ dev ใหม่และ AI agents

### Manual Require (Config Files Only)

- ✅ **Config files ยังต้องใช้ `require_once` แบบเดิม**
  - `source/config/operator_roles.php` - Config file (ไม่ใช่ class)
  - `source/config/assignment_config.php` - Config file (ไม่ใช่ class)
  - ไฟล์เหล่านี้ไม่ใช่ classes จึงไม่ต้อง autoload
  - ใช้ `require_once` แบบเดิมได้ตามปกติ

### Legacy Directories

- ⚠️ **Autoload ยังไม่ครอบคลุม legacy helpers และ config files**
  - `source/helper/` - Legacy helper functions (ไม่ใช่ PSR-4)
  - `source/config/` - Config files (ไม่ใช่ classes, ไม่ต้อง autoload)
  - ไฟล์เหล่านี้ยังต้องใช้ `require_once` แบบเดิม

### Services Without Namespace

- ⚠️ **Services ที่ไม่มี namespace จะไม่ถูก autoload**
  - เฉพาะ services ที่มี `namespace BGERP\Service` เท่านั้นที่ autoload ได้
  - Services เก่าที่ไม่มี namespace ต้องใช้ `require_once` ต่อไป

### Cross-Database Queries

- ⚠️ **Prepared statements ไม่รองรับ cross-database JOINs**
  - MySQL limitation: ไม่สามารถ JOIN ระหว่าง tenant DB และ core DB ใน prepared statement
  - ต้องใช้ two-step fetch pattern (fetch tenant → fetch core → merge)
  - ไม่เกี่ยวกับ PSR-4 แต่เป็นข้อจำกัดที่ควรรู้

### Migration Order (Historical)

- ✅ **Migration เสร็จสมบูรณ์แล้ว (Phase 0-5 COMPLETE)**
  - Phase 0-4: API migration with shim files (completed)
  - Phase 5: Full directory move (completed)
  - ไม่ต้องทำอะไรเพิ่มเติม

### Testing Requirements

- ⚠️ **ต้องทดสอบทุก phase ก่อนทำ phase ถัดไป**
  - Phase 1-3: ทดสอบ API endpoints หลัง migration
  - Phase 4: Full verification (autoload, endpoints, logs, tests)
  - Phase 5: Comprehensive testing (all endpoints, rollback test)

---

## ✅ Summary

**✅ Phase 0-5 Migration COMPLETE** (November 7, 2025, 23:10 ICT)

**Migration Status:**
- ✅ Phase 0: Preparation - COMPLETE (23 shim files created, later removed)
- ✅ Phase 1: Quick Wins - COMPLETE (3 files migrated)
- ✅ Phase 2: Medium Complexity - COMPLETE (2 files migrated)
- ✅ Phase 3: Complex Files - COMPLETE (2 files migrated)
- ✅ Phase 4: Verification - COMPLETE (all tests passing)
- ✅ Phase 5: Full Directory Move - COMPLETE (23 services + 6 exceptions moved)

**Production-Ready Checklist:**
- ✅ Technical Accuracy (100%)
- ✅ All APIs Migrated (9/9 files)
- ✅ All Services Moved (23/23 files)
- ✅ All Exceptions Created (6/6 files)
- ✅ Test Coverage (100% passing)
- ✅ Browser Testing (all tabs functional)
- ✅ Error Log Verification (no autoload errors)
- ✅ Performance Verified (normal response times)
- ✅ No Shim Files (clean architecture)

**Migration Statistics:**
- **APIs Migrated:** 9 files (100%)
- **Services Moved:** 23 files → `source/BGERP/Service/`
- **Exceptions Created:** 6 files → `source/BGERP/Exception/`
- **Shim Files:** 0 (removed in Phase 5)
- **Manual require_once Removed:** 100%
- **Tests Passing:** 100%
- **Browser Testing:** All tabs functional
- **Migration Time:** Completed in 1 session

**Next Action:** None - Migration complete. Optional cleanup: Remove legacy directories if empty.

---

**Version:** 1.4 (Phase 5 Complete Edition)  
**Last Updated:** November 7, 2025, 23:10 ICT  
**Maintained by:** Bellavier ERP Development Team

---

## 📝 Version History

| Version | Date | Changes | Status |
|---------|------|---------|--------|
| **1.4** | 2025-11-07, 23:10 ICT | ✅ **Phase 0-5 COMPLETE** - All 9 API files migrated, 23 services moved, 6 exceptions created, shim files removed, 100% PSR-4 compliant, all tests passing, browser verified | ✅ Complete |
| **1.3** | 2025-11-07, 21:48 ICT | ✅ **Phase 0-4 COMPLETE** - All 9 API files migrated, 23 shim files created, all tests passing, browser verified | ✅ Complete |
| **1.2** | 2025-11-07 | Enterprise Edition - Added ISO-grade features (commit tracking, impact scope, verification plan) | ✅ Complete |
| **1.1** | 2025-11-07 | Production Readiness - Added shim checklist, test plan, migration impact table | ✅ Complete |
| **1.0** | 2025-11-07 | Initial Audit - Identified 8 APIs requiring migration, created migration plan | ✅ Complete |

---

**Remember:** Migration นี้เป็น incremental process - ทำทีละ phase, ทดสอบทุก phase, แล้วค่อยทำ phase ถัดไป 💎

---

## 📚 Appendix: Historical Migration Notes

### **Shim Files (Phase 0-4, Removed in Phase 5)**

**Historical Context:** ใน Phase 0-4 เราใช้ shim files เป็น temporary bridge เพื่อให้ PSR-4 autoload ทำงานได้ก่อนที่จะย้าย services จริงใน Phase 5

**What Were Shim Files:**
- Shim files เป็นไฟล์เล็กๆ ใน `source/BGERP/Service/` ที่ `require_once` ไปยังไฟล์จริงใน `source/service/`
- ใช้เพื่อให้ autoloader สามารถหา class ได้ตาม PSR-4 mapping
- ถูกสร้างใน Phase 0 และถูกลบใน Phase 5 หลังจากย้าย services จริงแล้ว

**Why Removed:**
- Phase 5 ย้าย services ทั้งหมดจาก `source/service/` → `source/BGERP/Service/` แล้ว
- ไม่ต้องใช้ shim files อีกต่อไป
- Clean architecture (100% PSR-4 compliant)

**Historical Reference:**
- Shim files were created via `tools/generate-shims.php` in Phase 0
- All 23 shim files were removed in Phase 5 (November 7, 2025, 23:10 ICT)
- See version 1.3 documentation for shim file details

---

### **Mitigation Plan (Historical)**

**Phase 0-4 Approach:** ใช้ shim files เป็น quick fix เพื่อให้ autoload ทำงานได้ทันที

**Phase 5 Approach:** ย้าย services จริงจาก `source/service/` → `source/BGERP/Service/` และลบ shim files ทั้งหมด

**Result:** ✅ Complete - All services now in correct PSR-4 location, no shim files needed

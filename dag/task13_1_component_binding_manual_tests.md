# Task 13.1 – Hatthasilpa Component API Manual Validation

**Task ID:** 13.1  
**Status:** 🟡 **IN PROGRESS**  
**Related Task:** task13.md (DAG Task 13 - Component Serial Binding)  
**Purpose:** Manual validation of `hatthasilpa_component_api.php` before UI integration

---

## 1. Context

### Goal

พิสูจน์ให้แน่ชัดว่า `hatthasilpa_component_api.php` ใช้งานได้จริงครบทุกกรณีพื้นฐาน ก่อนเอาไปผูกกับ UI / Job Ticket / Workcenter

### Scope

เฉพาะ 2 actions นี้ (ยังไม่แตะ UI):
- `action=bind_component_serial` - Create component serial binding
- `action=get_component_serials` - Get component serials for a job

### Files & Areas ที่เกี่ยวข้อง

ให้ Agent โฟกัสไฟล์/ส่วนนี้เท่านั้น (ห้ามออกนอกกรอบ):
- **API หลัก:** `source/hatthasilpa_component_api.php`
- **ตารางที่เกี่ยวข้องใน tenant DB:**
  - `job_ticket`
  - `job_component_serial`
- **Feature Flag (อ่านจาก core DB):**
  - `FF_HAT_COMPONENT_SERIAL_BINDING` (ผ่าน `FeatureFlagService`)
- **Permission / Auth:**
  - `must_allow_code($member, 'hatthasilpa.job.ticket')`
  - `memberDetail->thisLogin()`

---

## 2. API Summary

### 2.1 Action: `bind_component_serial`

**Method:** POST  
**Permission:** `hatthasilpa.job.ticket`  
**Feature Flag:** `FF_HAT_COMPONENT_SERIAL_BINDING` (must be enabled)

**Input (JSON):**
```json
{
  "job_ticket_id": 631,                    // Required: int, min:1
  "component_code": "BODY",                // Optional: string, max:64
  "component_serial": "MA01-HAT-...-BODY",  // Required: string, max:100
  "final_piece_serial": "MA01-HAT-...",    // Optional: string, max:100
  "id_component_token": 1234,              // Optional: int, min:1
  "id_final_token": 5678,                  // Optional: int, min:1
  "bom_line_id": 10                        // Optional: int, min:1
}
```

**Output (Success):**
```json
{
  "ok": true,
  "data": {
    "id_binding": 1,
    "message": "Component serial bound successfully"
  }
}
```

**Output (Error):**
```json
{
  "ok": false,
  "error": "error_message",
  "app_code": "HAT_COMPONENT_XXX_ERROR_CODE",
  "errors": {} // if validation error
}
```

### 2.2 Action: `get_component_serials`

**Method:** GET  
**Permission:** `hatthasilpa.job.ticket`  
**Feature Flag:** Not required (read-only)

**Input (Query Parameters):**
```
?action=get_component_serials&job_ticket_id=631
```

**Output (Success):**
```json
{
  "ok": true,
  "data": {
    "component_serials": [
      {
        "id_binding": 1,
        "component_code": "BODY",
        "component_serial": "MA01-HAT-DIAG-20251201-00001-A7F3-X-BODY",
        "final_piece_serial": "MA01-HAT-DIAG-20251201-00001-A7F3-X",
        "id_component_token": 1234,
        "id_final_token": 5678,
        "bom_line_id": null,
        "created_at": "2025-12-01 10:00:00",
        "created_by": 1
      }
    ]
  }
}
```

**Output (Empty):**
```json
{
  "ok": true,
  "data": {
    "component_serials": []
  }
}
```

---

## 3. Test Environment

### 3.1 Prerequisites

- ✅ Tenant database with `job_component_serial` table (migration applied)
- ✅ Feature flag `FF_HAT_COMPONENT_SERIAL_BINDING` exists in Core DB
- ✅ At least one `job_ticket` record exists (for testing)
- ✅ User with permission `hatthasilpa.job.ticket`
- ✅ Valid session/login

### 3.2 Test Configuration

**Base URL:** `http://localhost/bellavier-group-erp/source/hatthasilpa_component_api.php`

**Sample Job Ticket ID:** `631` (replace with actual ID from your tenant DB)

**Feature Flag Setup:**
- Feature flag must be added to Core DB `feature_flag_catalog`:
  ```sql
  INSERT INTO feature_flag_catalog (feature_key, display_name, description, default_value, is_protected)
  VALUES ('FF_HAT_COMPONENT_SERIAL_BINDING', 'Hatthasilpa Component Serial Binding', 'Enable component serial binding for Hatthasilpa line', 0, 0)
  ON DUPLICATE KEY UPDATE updated_at=NOW();
  ```
- Enable for tenant (example):
  ```sql
  INSERT INTO feature_flag_tenant (feature_key, tenant_scope, value)
  VALUES ('FF_HAT_COMPONENT_SERIAL_BINDING', 'maison_atelier', 1)
  ON DUPLICATE KEY UPDATE value=1;
  ```

---

## 4. Test Matrix

### 4.1 `bind_component_serial` – Happy Paths

| TC | Test Case | Input | Expected Output | Status | Notes |
|----|-----------|-------|-----------------|--------|-------|
| **TC1** | Basic bind with minimal fields | `job_ticket_id`: valid ID<br>`component_serial`: "TEST-COMP-001"<br>No optional fields | `ok: true`<br>`data.id_binding` > 0<br>Row inserted in DB<br>Log entry in PHP error log | ⬜ Pending | |
| **TC2** | Bind with all optional fields | `job_ticket_id`: valid<br>`component_code`: "BODY"<br>`component_serial`: "TEST-COMP-002"<br>`final_piece_serial`: "TEST-FINAL-001"<br>`id_component_token`: valid token ID<br>`id_final_token`: valid token ID<br>`bom_line_id`: valid BOM line ID | `ok: true`<br>All fields saved correctly<br>Types correct (int/null) | ⬜ Pending | |
| **TC3** | Multi-bind on same job_ticket | Bind 3 components (BODY, LINING, HARDWARE) to same `job_ticket_id` | All 3 calls return `ok: true`<br>3 rows in `job_component_serial`<br>All linked to same `job_ticket_id` | ⬜ Pending | |

**Note:** Stage 1 = "Capture & Expose" - no uniqueness enforcement yet.

### 4.2 `bind_component_serial` – Error / Guard Cases

| TC | Test Case | Input | Expected Output | Status | Notes |
|----|-----------|-------|-----------------|--------|-------|
| **TC4** | Feature flag disabled | Feature flag `FF_HAT_COMPONENT_SERIAL_BINDING` = 0 for tenant | `ok: false`<br>`app_code`: `HAT_COMPONENT_403_FEATURE_DISABLED`<br>HTTP 403 | ⬜ Pending | |
| **TC5** | Validation fail – missing required fields | Missing `job_ticket_id` OR `component_serial` = "" | `ok: false`<br>`app_code`: `HAT_COMPONENT_400_VALIDATION`<br>`errors` object with failed keys | ⬜ Pending | |
| **TC6** | job_ticket not found | `job_ticket_id`: 99999 (non-existent) | `ok: false`<br>`app_code`: `HAT_COMPONENT_404_JOB_NOT_FOUND`<br>HTTP 404 | ⬜ Pending | |
| **TC7** | Unauthorized (not logged in) | No session / incognito mode | `ok: false`<br>`app_code`: `AUTH_401_UNAUTHORIZED`<br>HTTP 401 | ⬜ Pending | May be intercepted before switch-case |
| **TC8** | Permission denied | User logged in but no `hatthasilpa.job.ticket` permission | `ok: false`<br>Error from `must_allow_code()` | ⬜ Pending | Record actual error message |

### 4.3 `get_component_serials` – Cases

| TC | Test Case | Input | Expected Output | Status | Notes |
|----|-----------|-------|-----------------|--------|-------|
| **TC9** | No bindings yet | `job_ticket_id`: valid but no bindings | `ok: true`<br>`data.component_serials`: `[]` (empty array) | ⬜ Pending | |
| **TC10** | With bindings | `job_ticket_id`: from TC1-TC3 | `ok: true`<br>`component_serials`: array matching DB<br>Sorted by `component_code`, `component_serial` | ⬜ Pending | |
| **TC11** | Validation error | `job_ticket_id`: missing / 0 / negative | `ok: false`<br>`app_code`: `HAT_COMPONENT_400_VALIDATION` | ⬜ Pending | |
| **TC12** | Unauthorized / Permission denied | Same as TC7/TC8 but for `get_component_serials` | Consistent behavior with `bind_component_serial` | ⬜ Pending | |

---

## 5. Execution Log

### 5.1 Test Execution Record

**Tester:** _________________  
**Date:** _________________  
**Environment:** _________________  
**Tenant:** _________________  
**Base URL:** _________________

| TC | Test Case | Result | HTTP Status | Response Time | Notes / Issues |
|----|-----------|--------|-------------|---------------|----------------|
| TC1 | Basic bind minimal | ⬜ Pass / ⬜ Fail | | | |
| TC2 | Bind with all fields | ⬜ Pass / ⬜ Fail | | | |
| TC3 | Multi-bind same job | ⬜ Pass / ⬜ Fail | | | |
| TC4 | Feature flag disabled | ⬜ Pass / ⬜ Fail | | | |
| TC5 | Validation fail | ⬜ Pass / ⬜ Fail | | | |
| TC6 | Job not found | ⬜ Pass / ⬜ Fail | | | |
| TC7 | Unauthorized | ⬜ Pass / ⬜ Fail | | | |
| TC8 | Permission denied | ⬜ Pass / ⬜ Fail | | | |
| TC9 | No bindings | ⬜ Pass / ⬜ Fail | | | |
| TC10 | With bindings | ⬜ Pass / ⬜ Fail | | | |
| TC11 | Validation error (get) | ⬜ Pass / ⬜ Fail | | | |
| TC12 | Unauthorized (get) | ⬜ Pass / ⬜ Fail | | | |

### 5.2 Sample Responses

**TC1 Success Response:**
```json
{
  "ok": true,
  "data": {
    "id_binding": 1,
    "message": "Component serial bound successfully"
  }
}
```

**TC4 Feature Flag Disabled:**
```json
{
  "ok": false,
  "error": "Feature flag FF_HAT_COMPONENT_SERIAL_BINDING is disabled",
  "app_code": "HAT_COMPONENT_403_FEATURE_DISABLED",
  "feature_flag": "FF_HAT_COMPONENT_SERIAL_BINDING",
  "tenant_scope": "maison_atelier"
}
```

**TC5 Validation Error:**
```json
{
  "ok": false,
  "error": "validation_failed",
  "app_code": "HAT_COMPONENT_400_VALIDATION",
  "errors": {
    "job_ticket_id": ["The job_ticket_id field is required."],
    "component_serial": ["The component_serial field is required."]
  }
}
```

---

## 6. Known Issues / Next Tasks

### 6.1 Issues Found During Testing

| Issue ID | Description | Severity | Status | Notes |
|----------|-------------|----------|--------|-------|
| | | | | |

### 6.2 Next Steps

- [ ] Fix any bugs found during testing (create Task 13.1.x if needed)
- [ ] Proceed to Phase 3: Read Path & API Exposure (Task 13.2)
- [ ] Add automated tests (Task 13.6)

---

## 7. Definition of Done

Task 13.1 ถือว่า "จบ" ก็ต่อเมื่อ:

- ✅ `docs/dag/task13_1_component_binding_manual_tests.md` มี test case ครบตาม matrix และมีช่องให้กรอกผลจริง
- ✅ `docs/api/examples/hatthasilpa_component_api.http` สร้างเสร็จ ใช้ยิงเทสได้จริง
- ✅ ทดสอบอย่างน้อย 3–5 เคส (happy + error) แล้ว JSON ตรงตาม expectation
- ✅ ไม่มีการเปลี่ยน business logic / app_code โดยไม่จำเป็น
- ✅ ถ้ามี bug → ถูกจดใน section "Known Issues / Next Tasks"

---

**Document Created:** December 2025  
**Status:** 🟡 IN PROGRESS  
**Next:** Execute manual tests and fill execution log


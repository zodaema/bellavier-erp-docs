# Task 13.2 – Component Read Path & API Exposure

**Task ID:** 13.2  
**Status:** ✅ **COMPLETED**  
**Related Tasks:** 
- task13.md (DAG Task 13 - Component Serial Binding)
- task13_1_component_binding_manual_tests.md (Task 13.1 - Manual Validation)

**Purpose:** Prepare a stable, UI-ready read model for Hatthasilpa component serial bindings, using `hatthasilpa_component_api.php`. This task focuses on read path & UI-ready shape without changing write behavior.

---

## 1. Context & Goal

### Background

Task 13.2 extends the component serial binding API (`hatthasilpa_component_api.php`) to provide stable, UI-ready read endpoints. This task:

- **Stabilizes** `get_component_serials` action with optional filters
- **Adds** `get_component_panel` action for UI panel display
- **Does NOT change** existing write behavior (`bind_component_serial`)
- **Does NOT modify** database schema or feature flags

### Goal

Create a stable read model that:
- Supports filtering component serials by `component_code` and `final_piece_serial`
- Provides job_ticket context alongside component serials for UI panels
- Maintains backward compatibility with Task 13.1 test documentation
- Uses consistent error handling and response formats

---

## 2. API Changes

### 2.1 `get_component_serials` (Updated)

**Method:** GET  
**Permission:** `hatthasilpa.job.ticket`  
**Feature Flag:** Not required (read-only)

#### Input Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `action` | string | Yes | Must be `get_component_serials` |
| `job_ticket_id` | int | Yes | Job ticket ID (min: 1) |
| `component_code` | string | No | Filter by component code (max: 64) |
| `final_piece_serial` | string | No | Filter by final piece serial (max: 100) |

#### Sample Requests

**Basic (no filters):**
```
GET /source/hatthasilpa_component_api.php?action=get_component_serials&job_ticket_id=631
```

**With component_code filter:**
```
GET /source/hatthasilpa_component_api.php?action=get_component_serials&job_ticket_id=631&component_code=BODY
```

**With final_piece_serial filter:**
```
GET /source/hatthasilpa_component_api.php?action=get_component_serials&job_ticket_id=631&final_piece_serial=MA01-HAT-DIAG-20251201-00001-A7F3-X
```

**With both filters:**
```
GET /source/hatthasilpa_component_api.php?action=get_component_serials&job_ticket_id=631&component_code=BODY&final_piece_serial=MA01-HAT-DIAG-20251201-00001-A7F3-X
```

#### Output Format

**Success (with bindings):**
```json
{
  "ok": true,
  "data": {
    "component_serials": [
      {
        "id_binding": 1,
        "job_ticket_id": 631,
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

**Success (empty):**
```json
{
  "ok": true,
  "data": {
    "component_serials": []
  }
}
```

**Validation Error:**
```json
{
  "ok": false,
  "error": "validation_failed",
  "app_code": "HAT_COMPONENT_400_VALIDATION",
  "errors": {
    "job_ticket_id": ["The job_ticket_id field is required."]
  }
}
```

**Job Not Found:**
```json
{
  "ok": false,
  "error": "Job ticket not found",
  "app_code": "HAT_COMPONENT_404_JOB_NOT_FOUND",
  "job_ticket_id": 99999
}
```

#### Implementation Details

- **Ordering:** Results ordered by `created_at ASC`, `id_binding ASC`
- **Filtering:** Optional filters are applied as AND conditions
- **Validation:** Job ticket existence is validated before querying component serials
- **Backward Compatibility:** Existing behavior from Task 13.1 is preserved

---

### 2.2 `get_component_panel` (New)

**Method:** GET  
**Permission:** `hatthasilpa.job.ticket`  
**Feature Flag:** Not required (read-only)

#### Input Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `action` | string | Yes | Must be `get_component_panel` |
| `job_ticket_id` | int | Yes | Job ticket ID (min: 1) |

#### Sample Request

```
GET /source/hatthasilpa_component_api.php?action=get_component_panel&job_ticket_id=631
```

#### Output Format

**Success (with bindings):**
```json
{
  "ok": true,
  "data": {
    "job_ticket": {
      "job_ticket_id": 631,
      "job_code": "MA-HT-0001",
      "final_piece_serial": "MA01-HAT-DIAG-20251201-00001-A7F3-X",
      "product_name": "Example Product"
    },
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

**Success (empty bindings):**
```json
{
  "ok": true,
  "data": {
    "job_ticket": {
      "job_ticket_id": 631,
      "job_code": "MA-HT-0001",
      "final_piece_serial": null,
      "product_name": "Example Product"
    },
    "component_serials": []
  }
}
```

**Error Cases:**
- Same validation / 404 / permission style as `get_component_serials`
- If job_ticket not found: `app_code: "HAT_COMPONENT_404_JOB_NOT_FOUND"`

#### Implementation Details

- **Job Ticket Info:** Loaded from `job_ticket` table with LEFT JOIN to `product` for product name
- **Final Piece Serial:** Retrieved from first component binding (if exists)
- **Component Serials:** Same query logic as `get_component_serials` (reused)
- **Ordering:** Component serials ordered by `created_at ASC`, `id_binding ASC`

---

## 3. Test Notes

### 3.1 Manual Test Checklist

**For `get_component_serials`:**

- [ ] Basic request (no filters) returns all bindings for job
- [ ] Filter by `component_code` returns only matching bindings
- [ ] Filter by `final_piece_serial` returns only matching bindings
- [ ] Both filters work together (AND condition)
- [ ] Empty result returns `[]` array (not null)
- [ ] Invalid `job_ticket_id` returns 404 error
- [ ] Missing `job_ticket_id` returns validation error
- [ ] Unauthorized access returns 401 error

**For `get_component_panel`:**

- [ ] Returns job_ticket info + component_serials array
- [ ] `final_piece_serial` populated from first binding (if exists)
- [ ] `product_name` populated from product table (if linked)
- [ ] Empty bindings returns empty array (not null)
- [ ] Invalid `job_ticket_id` returns 404 error
- [ ] Missing `job_ticket_id` returns validation error
- [ ] Unauthorized access returns 401 error

### 3.2 Relation to Task 13.1

This task extends the test matrix from Task 13.1:

- **TC9-TC12** (from Task 13.1) still apply to `get_component_serials`
- **New test cases** should cover:
  - Filtering by `component_code`
  - Filtering by `final_piece_serial`
  - `get_component_panel` happy path
  - `get_component_panel` error cases

### 3.3 Simple curl Examples

**Test get_component_serials with filter:**
```bash
curl -X GET "http://localhost/bellavier-group-erp/source/hatthasilpa_component_api.php?action=get_component_serials&job_ticket_id=631&component_code=BODY" \
  -H "Cookie: PHPSESSID=your_session_id"
```

**Test get_component_panel:**
```bash
curl -X GET "http://localhost/bellavier-group-erp/source/hatthasilpa_component_api.php?action=get_component_panel&job_ticket_id=631" \
  -H "Cookie: PHPSESSID=your_session_id"
```

---

## 4. Files Modified/Created

### Modified Files

- ✅ `source/hatthasilpa_component_api.php`
  - Updated `get_component_serials` action:
    - Added optional filters (`component_code`, `final_piece_serial`)
    - Added `job_ticket_id` validation
    - Changed ordering to `created_at ASC, id_binding ASC`
    - Added `job_ticket_id` to response
  - Added `get_component_panel` action:
    - Loads job_ticket info with product name
    - Returns job_ticket + component_serials array
    - Reuses component serials query logic

### Created Files

- ✅ `docs/dag/task13_2_component_read_api.md` (this file)

### Updated Files

- ✅ `docs/api/examples/hatthasilpa_component_api.http` (see next section)

---

## 5. Key Behavioral Changes

### 5.1 `get_component_serials` Changes

**Before (Task 13.1):**
- No optional filters
- Ordering: `component_code, component_serial`
- No job_ticket validation

**After (Task 13.2):**
- ✅ Optional filters: `component_code`, `final_piece_serial`
- ✅ Ordering: `created_at ASC, id_binding ASC` (more stable)
- ✅ Job ticket existence validated
- ✅ `job_ticket_id` included in response

**Backward Compatibility:**
- ✅ Existing requests (without filters) still work
- ✅ Response format extended (additive only)
- ✅ No breaking changes to existing behavior

### 5.2 New Action: `get_component_panel`

- ✅ Provides job_ticket context for UI panels
- ✅ Combines job info + component serials in one call
- ✅ Reduces number of API calls needed for UI

---

## 6. Definition of Done

Task 13.2 is **DONE** when:

- ✅ `get_component_serials`:
  - Validates inputs according to spec
  - Supports optional filters (`component_code`, `final_piece_serial`)
  - Returns JSON in documented format (success/empty/error)
  - Validates job_ticket existence
- ✅ `get_component_panel` implemented:
  - Returns job_ticket info + component_serials array
  - Uses same error handling style as `get_component_serials`
  - Reuses component serials query logic
- ✅ `docs/dag/task13_2_component_read_api.md` created with:
  - Context, API spec, examples, DoD
- ✅ `docs/api/examples/hatthasilpa_component_api.http` updated with:
  - Working request/response examples for new/updated actions
- ✅ `php -l source/hatthasilpa_component_api.php` passes
- ✅ No other files were modified

---

## 7. How to Manually Test

### Using HTTP Examples File

1. Open `docs/api/examples/hatthasilpa_component_api.http` in VS Code with REST Client extension
2. Replace `{jobTicketId}` with actual job_ticket_id from your tenant DB
3. Ensure you are logged in and have `hatthasilpa.job.ticket` permission
4. Execute examples for:
   - `get_component_serials` with filters
   - `get_component_panel` success case
   - `get_component_panel` error cases

### Using curl

See section 3.3 for curl examples.

### Expected Results

- All requests return valid JSON
- Success responses match documented format
- Error responses use consistent `app_code` values
- Filters work correctly (AND condition)
- Empty results return `[]` (not null)

---

**Document Created:** December 2025  
**Status:** ✅ COMPLETED  
**Next:** Task 13.3+ (Future phases for BOM integration, enforcement, etc.)


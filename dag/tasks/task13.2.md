🧠 Prompt สำหรับ AI Agent – Task 13.2

You are an AI refactoring / feature implementation agent working on **Bellavier Group ERP – DAG / Hatthasilpa line**.

Your current task is:

# Task 13.2 – Component Read Path & API Exposure

**Goal:**  
Prepare a **stable, UI-ready read model** for Hatthasilpa component serial bindings, using `hatthasilpa_component_api.php`.  
You must NOT change existing write behavior, only extend/stabilize read behavior.

---

## 0. Context You MUST Read First

Before editing anything, carefully read:

1. `docs/dag/task13.md`
   - High-level design for **Component Serial Binding** (Task 13).

2. `docs/dag/task13_1_component_binding_manual_tests.md`
   - Especially:
     - API Summary for:
       - `action=bind_component_serial`
       - `action=get_component_serials`
     - Test Matrix (TC1–TC12)
     - Next Steps section (mentions Task 13.2)

3. `docs/api/examples/hatthasilpa_component_api.http`
   - Understand current request/response patterns.

4. `source/hatthasilpa_component_api.php`
   - Understand current implementation of:
     - `bind_component_serial`
     - `get_component_serials`
   - Note: This file already uses:
     - Tenant bootstrap
     - `FeatureFlagService`
     - `must_allow_code($member, 'hatthasilpa.job.ticket')`
     - `job_component_serial` table

Do **NOT** touch any other DAG or ERP files.

---

## 1. Scope of THIS Task (13.2)

You are only allowed to work in:

- `source/hatthasilpa_component_api.php`
- Documentation under:
  - `docs/dag/task13_2_component_read_api.md` (NEW)
  - `docs/api/examples/hatthasilpa_component_api.http` (UPDATE ONLY)

You MUST NOT:
- Change any other API file.
- Change database schema.
- Change feature flag or permission behavior.
- Change error codes that already exist.

---

## 2. Functional Requirements

### 2.1 Stabilize `action=get_component_serials`

The existing `get_component_serials` must be:

- **Strict on input**:
  - Required: `job_ticket_id` (int, >0)
  - Optional:
    - `component_code` (string, max 64)
    - `final_piece_serial` (string, max 100)
- **Consistent in output**:
  - On success:
    ```json
    {
      "ok": true,
      "data": {
        "component_serials": [
          {
            "id_binding": 1,
            "job_ticket_id": 631,
            "component_code": "BODY",
            "component_serial": "MA01-HAT-...",
            "final_piece_serial": "MA01-HAT-...",
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
  - On empty result:
    ```json
    {
      "ok": true,
      "data": {
        "component_serials": []
      }
    }
    ```
  - On validation error:
    - Use `HAT_COMPONENT_400_VALIDATION` as app_code
    - Must match style described in `task13_1_component_binding_manual_tests.md`
  - On job_ticket not found:
    - Use `HAT_COMPONENT_404_JOB_NOT_FOUND` (if defined already, reuse; otherwise define in a consistent way with Task 13 spec)

**Implementation details:**

- Use the same DB table: `job_component_serial`
- Join with `job_ticket` only if needed for validation (but for now, output is based on `job_component_serial` rows).
- Support optional filters:
  - If `component_code` is provided, filter by it.
  - If `final_piece_serial` is provided, filter by it.
- Order:
  - Default order: `created_at ASC`, `id_binding ASC`.

**Important:**  
Do **NOT** break existing behavior used in Task 13.1 test documentation.  
If there is a discrepancy between current implementation and doc, align to the **doc spec** from Task 13.1 (but keep app_codes consistent).

---

### 2.2 Add a New Read Action: `action=get_component_panel`

This is a **read-only helper** for future UI panels.

**Input:**

- Method: `GET`
- Params:
  - `action=get_component_panel`
  - `job_ticket_id` (required, int, >0)

**Output (success):**

```json
{
  "ok": true,
  "data": {
    "job_ticket": {
      "job_ticket_id": 631,
      "job_code": "MA-HT-0001",
      "final_piece_serial": "MA01-HAT-DIAG-20251201-00001-A7F3-X",
      "product_name": "Example Product"      // if easily available, else null
    },
    "component_serials": [
      {
        "id_binding": 1,
        "component_code": "BODY",
        "component_serial": "MA01-HAT-...-BODY",
        "final_piece_serial": "MA01-HAT-...",
        "id_component_token": 1234,
        "id_final_token": 5678,
        "bom_line_id": null,
        "created_at": "2025-12-01 10:00:00",
        "created_by": 1
      }
    ]
  }
}

Output (empty bindings):

{
  "ok": true,
  "data": {
    "job_ticket": {
      "job_ticket_id": 631,
      "job_code": "MA-HT-0001",
      "final_piece_serial": "MA01-HAT-DIAG-20251201-00001-A7F3-X",
      "product_name": "Example Product"
    },
    "component_serials": []
  }
}

Output (error cases):
	•	Same validation / 404 / permission style as get_component_serials.
	•	If job_ticket not found:
	•	ok: false
	•	app_code: "HAT_COMPONENT_404_JOB_NOT_FOUND"

Implementation Notes:
	•	This endpoint should:
	•	Validate job_ticket_id.
	•	Load basic job_ticket info from job_ticket table:
	•	id_job_ticket
	•	job_code or equivalent
	•	final_piece_serial (if available in schema; if not, use null)
	•	product_name (if easily joined; otherwise null)
	•	Load component bindings from job_component_serial (reuse logic from get_component_serials to avoid duplicate query logic).
	•	Do NOT implement BOM/expected-component logic in this task. That will come in later tasks (13.3+).

⸻

3. Non-Functional Requirements
	•	Use existing bootstrap pattern in hatthasilpa_component_api.php.
	•	Respect:
	•	FeatureFlagService usage.
	•	must_allow_code($member, 'hatthasilpa.job.ticket').
	•	Existing app_code naming conventions.
	•	No new tables.
	•	No schema changes.
	•	No changes to bind_component_serial logic.

⸻

4. Documentation to Update / Create

4.1 Create docs/dag/task13_2_component_read_api.md

Content structure:
	1.	Title + Metadata
	•	Task ID: 13.2
	•	Status: COMPLETED (after finishing)
	•	Related: task13.md, task13_1_component_binding_manual_tests.md
	2.	Context & Goal
	•	Brief recap of Component Serial Binding
	•	Explain that this task focuses on read path & UI-ready shape
	3.	API Changes
	•	Document final spec for:
	•	get_component_serials
	•	get_component_panel
	•	For each:
	•	Method, params, sample requests
	•	Sample success/empty/error responses
	•	Notes on filter behavior
	4.	Test Notes
	•	Manual test checklist:
	•	Simple curl / HTTP examples
	•	Minimal happy & error cases
	•	Mention relation to Task 13.1 test matrix (TC9–TC12 especially).
	5.	Definition of Done
	•	JSON shape stable
	•	No breaking changes to existing actions
	•	Docs updated
	•	Syntax checks passed

4.2 Update docs/api/examples/hatthasilpa_component_api.http
	•	Add new examples for:
	•	GET get_component_serials with filters
	•	GET get_component_panel success case
	•	GET get_component_panel for not found / error case

Ensure the examples match the final implementation exactly.

⸻

5. Safety Rails (Very Important)

You MUST follow these rules:
	1.	Do NOT change:
	•	Any other APIs outside hatthasilpa_component_api.php.
	•	Any DB schemas or migrations.
	•	Any global helpers.
	2.	Do NOT:
	•	Rename existing actions.
	•	Change existing app_code values already used by Task 13.1 doc (unless they’re obviously wrong and you update the doc accordingly).
	3.	Do:
	•	Keep responses strictly JSON.
	•	Reuse existing error helpers / patterns inside the file.
	•	Keep all new logic self-contained.
	4.	After changes:
	•	Run: php -l source/hatthasilpa_component_api.php
	•	Ensure no syntax errors.

⸻

6. Acceptance Criteria

Task 13.2 is DONE when:
	•	get_component_serials:
	•	Validates inputs according to spec.
	•	Supports optional filters (component_code, final_piece_serial).
	•	Returns JSON in the documented format (success/empty/error).
	•	get_component_panel implemented:
	•	Returns job_ticket info + component_serials array.
	•	Uses same error handling style as get_component_serials.
	•	docs/dag/task13_2_component_read_api.md created with:
	•	Context, API spec, examples, DoD.
	•	docs/api/examples/hatthasilpa_component_api.http updated with:
	•	Working request/response examples for the new/updated actions.
	•	php -l source/hatthasilpa_component_api.php passes.
	•	No other files were modified.

At the end, output a short summary:
	•	Files modified/created
	•	Key behavioral changes
	•	How to manually test using the .http file

# Task 24.6.4 Results — Classic Line Hardening, Ticket Creation Fix, DAG Binding

**Date:** 2025-11-29  
**Status:** ✅ **COMPLETED**  
**Objective:** Make Job Tickets created from UI (Classic Line) 100% correct — no Hybrid/Linear/Manual Production Mode options, and must bind DAG Instance (flow_graph_instance) immediately upon ticket creation

---

## Executive Summary

Task 24.6.4 successfully hardened Classic Line ticket creation to ensure all tickets created from the UI are automatically set as Classic Line with DAG routing mode, with immediate DAG instance binding. The system now automatically determines production type and routing mode, removes manual selection options, and ensures tickets are ready for lifecycle actions immediately after creation.

**Key Achievements:**
- ✅ Auto-determined `production_type = 'classic'` and `routing_mode = 'dag'` for all UI-created tickets
- ✅ Removed production mode selection from create modal
- ✅ Immediate DAG instance binding upon ticket creation
- ✅ Token generation integrated into create workflow
- ✅ Removed Hybrid option from UI dropdowns
- ✅ Fixed `bind_param` type string errors
- ✅ Resolved ENUM mapping issues (classic ↔ oem)
- ✅ Cleaned up legacy `assigned_operator_id` code

---

## Implementation Details

### 1. UI Cleanup - Removed Production Mode Selection

**Files Modified:**
- `views/job_ticket.php`
- `assets/javascripts/hatthasilpa/job_ticket.js`

**Changes:**
1. **Removed Process Mode Select:**
   - Removed `<div class="col-md-6">` block containing `#ticket_process_mode` select element
   - Removed all JavaScript logic related to reading `process_mode` from UI
   - Removed validation checks for `process_mode`

2. **Hardcoded Production Type:**
   - In `gatherTicketPayload()`, hardcoded `payload.production_type = 'classic'` and `payload.routing_mode = 'dag'`
   - Removed `selectors.ticketProcessMode` and all related references

3. **Removed Hybrid Option:**
   - Removed `hybrid` option from `#filter-production-type` dropdown
   - Added comments in code: "HYBRID RESERVED — NOT IN USE IN V1"

### 2. Backend Create Action Fix

**File:** `source/job_ticket.php`

**Changes:**

1. **Auto-determined Production Type:**
   ```php
   // Task 24.6.4: Auto-determine line_type & routing_mode
   // All tickets from this UI are Classic Line with DAG routing mode
   $productionType = 'classic'; // Always Classic Line
   $routingMode = 'dag'; // Always DAG mode
   ```

2. **DAG Instance Binding:**
   - After ticket creation, immediately creates graph instance using `GraphInstanceService::createInstanceForTicket()`
   - Creates node instances for all routing graph nodes
   - Spawns tokens based on `target_qty` using `TokenLifecycleService`

3. **ENUM Mapping:**
   - Maps logical name `'classic'` to DB ENUM `'oem'` before INSERT
   - Maps DB ENUM `'oem'` back to `'classic'` in API responses (list, get)

4. **Helper Function:**
   - Created `normalize_production_type()` helper function for consistent mapping across all lifecycle actions

### 3. Fixed Critical Bugs (AI Audit Feedback)

1. **Lifecycle Actions Production Type Check:**
   - **Problem:** Lifecycle actions used `production_type !== 'classic'` but DB stores `'oem'` for Classic tickets
   - **Fix:** Updated all lifecycle actions (start, pause, resume, complete, cancel, restore) to use `normalize_production_type()` helper
   - **Impact:** Classic tickets can now use lifecycle actions correctly

2. **bind_param Type String Error:**
   - **Problem:** `$processModeVal` was bound as integer (`i`) instead of string (`s`)
   - **Fix:** Corrected type string from `'ssiisississis'` to `'ssiisisssssis'`
   - **Impact:** Prevents silent warnings and data truncation

3. **Consistent Production Type Mapping:**
   - **Problem:** Inconsistent mapping between logical name ('classic') and DB enum ('oem')
   - **Fix:** Centralized mapping via `normalize_production_type()` helper
   - **Impact:** Consistent behavior across all code paths

### 4. Code Cleanup - Removed Legacy Fields

**Files Modified:**
- `source/job_ticket.php`

**Changes:**
1. **Removed `assigned_operator_id` Backward Compatibility:**
   - Removed `get_job_owner_column()` function
   - Removed all fallback logic to `assigned_operator_id`
   - Simplified column existence checks (assumes migration complete)
   - Direct use of `job_owner_id` in all SQL queries

2. **Simplified INSERT/UPDATE Statements:**
   - Removed conditional column existence checks
   - Streamlined `bind_param` type strings
   - Removed duplicate column selections in queries

### 5. Legacy Ticket Migration

**Status:** Migration script (`tools/job_ticket_migrate_classic.php`) was created but later deemed unnecessary for Dev environment and deleted.

**Decision:** Focus on new ticket creation logic rather than migrating existing tickets, as Dev environment can be reset if needed.

---

## Files Modified

### Backend
- `source/job_ticket.php`
  - Auto-determined `production_type` and `routing_mode` in create action
  - Added DAG instance binding after ticket creation
  - Added `normalize_production_type()` helper function
  - Fixed lifecycle actions to use correct production type mapping
  - Removed legacy `assigned_operator_id` code
  - Fixed `bind_param` type strings

### Frontend
- `views/job_ticket.php`
  - Removed process mode select element
  - Removed Hybrid option from production type filter
  
- `assets/javascripts/hatthasilpa/job_ticket.js`
  - Removed `selectors.ticketProcessMode` and related logic
  - Hardcoded `production_type = 'classic'` and `routing_mode = 'dag'` in payload
  - Removed `process_mode` validation

### Migration Files
- `database/tenant_migrations/0001_init_tenant_schema_v2.php`
  - Consolidated job ticket schema changes (moved from `2025_11_28_add_job_ticket_assigned_operator.php`)

---

## Testing & Validation

### Manual Testing Checklist
- ✅ Create new Classic ticket from UI → automatically set as Classic DAG
- ✅ Modal has no production mode options
- ✅ Create ticket → can immediately Start/Pause/Resume/Complete
- ✅ No Hybrid option in UI dropdowns
- ✅ All tickets have `graph_instance_id` and tokens from creation
- ✅ Lifecycle actions work correctly for Classic tickets
- ✅ Production type mapping works consistently

### Error Fixes
- ✅ Fixed `bind_param` type string mismatches
- ✅ Fixed ENUM mapping issues (classic ↔ oem)
- ✅ Fixed duplicate column errors in queries
- ✅ Fixed lifecycle actions production type checks

---

## Acceptance Criteria Status

- ✅ Users creating Job Ticket from UI → get Classic DAG only
- ✅ Modal has no production mode selection
- ✅ Create ticket → can immediately Start/Pause/Resume/Complete
- ✅ No Hybrid appears in UI/API
- ✅ All tickets have `graph_instance_id` + tokens from creation
- ✅ Legacy ticket migration script created (deleted as unnecessary for Dev)

---

## Notes

1. **Production Type Mapping:**
   - Logical name: `'classic'` (used in API/UI)
   - DB ENUM value: `'oem'` (stored in database)
   - Always use `normalize_production_type()` helper for consistency

2. **DAG Instance Binding:**
   - All Classic tickets now have graph instance created immediately upon creation
   - Tokens are spawned based on `target_qty`
   - Tickets are ready for lifecycle actions without additional setup

3. **Code Simplification:**
   - Removed complex backward compatibility logic
   - Simplified codebase assumes migration is complete
   - Direct use of `job_owner_id` throughout codebase

---

## Related Tasks

- **Task 24.6.3:** Job Owner refactoring (completed before this task)
- **Task 24.6.5:** Hatthasilpa View + Creation Status Hardening (next task)

---

## Commit Message Recommendation

```
feat(job_ticket): auto-determine Classic DAG mode and bind instance on creation

- Auto-set production_type='classic' and routing_mode='dag' for UI-created tickets
- Remove production mode selection from create modal
- Bind DAG instance immediately upon ticket creation
- Fix production type mapping for lifecycle actions
- Remove legacy assigned_operator_id code
- Fix bind_param type string errors

Task: 24.6.4
```

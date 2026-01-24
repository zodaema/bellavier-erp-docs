# Task 28.10 Results: Separate API Endpoints

**Status:** ✅ **COMPLETE**  
**Date:** 2025-12-12  
**Type:** Documentation Only (No Code Changes)

---

## Summary

Task 28.10 has been completed by creating comprehensive API contract documentation. All endpoints exist and work correctly. Contracts are now clearly defined and documented in a dedicated API contracts document.

---

## Files Created

### 1. API Contracts Document

**File:** `docs/super_dag/02-api/DAG_GRAPH_API_CONTRACTS_V1.md`

**Content:**
- ✅ Scope & Non-Goals
- ✅ SSOT & Version Identity definitions
- ✅ Endpoint Contracts (7 endpoints):
  - `graph_validate_design`
  - `graph_autosave`
  - `graph_save_draft`
  - `node_update_properties`
  - `graph_publish`
  - `graph_versions` (read-only)
  - `graph_version_compare` (read-only)
- ✅ Write Routing Rules
- ✅ Node Update Specifics (including known gotcha)
- ✅ Observability (DEV only)
- ✅ Minimal End-to-End Flows (4 flows)
- ✅ Error Code Reference

**Key Features:**
- Complete request/response examples (copy-paste ready)
- Forbidden keys/fields clearly listed
- Error codes with descriptions
- Known gotchas documented (e.g., node_code resolution)
- Contract matrix summary

---

## Files Updated

### 1. Task 28 Master Document

**File:** `docs/super_dag/tasks/task28_GRAPH_VERSIONING_IMPLEMENTATION.md`

**Changes:**
- ✅ Added API contracts document to Reference Documents
- ✅ Updated Task 28.10 status: IN PROGRESS → COMPLETE
- ✅ Updated Progress section: Contracts documentation Pending → COMPLETE
- ✅ Updated Acceptance Criteria: All items marked complete
- ✅ Updated Phase 4 status: IN PROGRESS → COMPLETE
- ✅ Updated Next Steps: Phase 4 docs complete, Task 28.12 remains deferred
- ✅ Updated Task 28.12: Added condition to start (deferred, optional)

---

## Acceptance Checklist

### Endpoints Existence
- [x] `node_update_properties` endpoint exists and works correctly
- [x] `graph_save_draft` endpoint exists and works correctly
- [x] `graph_autosave` endpoint exists and works correctly
- [x] `graph_validate_design` endpoint exists and works correctly
- [x] `graph_publish` endpoint exists and works correctly

### Contracts Definition
- [x] Contracts clearly defined (documented in `DAG_GRAPH_API_CONTRACTS_V1.md`)
- [x] Source of truth rules documented (payload-only for save/validate)
- [x] Limited merge rules documented (autosave, node_update)
- [x] Forbidden keys/fields documented
- [x] Error codes documented

### Documentation
- [x] API contracts document created
- [x] Request/response examples provided
- [x] End-to-end flows documented
- [x] Known gotchas documented
- [x] Master document updated with links

### No Code Changes
- [x] No JavaScript files modified
- [x] No PHP files modified
- [x] Only documentation files created/updated

---

## Contract Matrix (Summary)

| Operation | Source of Truth | DB Merge? | Validation | Version Impact |
|-----------|-----------------|-----------|------------|----------------|
| `graph_validate_design` | UI payload ONLY | ❌ NEVER | Full graph | None (no save) |
| `graph_autosave` | UI payload + DB (positions) | ✅ Yes (positions only) | Minimal (syntax) | None |
| `graph_save_draft` | **UI payload ONLY** | ❌ **NEVER** | Full graph (warnings only) | Draft only |
| `node_update_properties` | UI payload + DB (node config) | ✅ Yes (config only) | Node-level only | None |
| `graph_publish` | Current draft (from DB) | N/A | Full graph (errors block) | Creates Published |

---

## Critical Rules Documented

1. **Draft-Only Writes:** All write operations require `canonical='draft'` and active draft
2. **Payload-Only for Save/Validate:** `graph_save_draft` and `graph_validate_design` use UI payload ONLY (no DB merge)
3. **Limited Merge for Autosave/NodeUpdate:** `graph_autosave` and `node_update_properties` merge into existing draft (limited scope)
4. **Published Immutability:** Published/Retired versions are immutable (403 error on write attempts)

---

## Next Steps

- ✅ Phase 4 documentation complete
- 📋 Task 28.12 (runtime→allow_new_jobs migration) remains DEFERRED (optional, not a blocker)
- 📋 Future: Consider Task 28.12 after Node Behavior milestone (if applicable)

---

## Notes

- All endpoints were already implemented in previous tasks (28.2, 28.11, etc.)
- This task focused solely on documentation, not implementation
- No code changes were made (docs-only task)
- API contracts document serves as the authoritative reference for Graph Designer persistence operations

---

**Task 28.10: COMPLETE** ✅


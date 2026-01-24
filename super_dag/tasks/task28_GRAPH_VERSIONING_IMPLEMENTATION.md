# Task 28: Graph Versioning & Immutability Implementation

**Status:**  IN PROGRESS (Phase 4 docs pending)
**Priority:** 🔴 **CRITICAL**  
**Category:** Graph Lifecycle / Data Integrity / ERP Safety  
**Date:** 2025-12-12

---

## Executive Summary

**Goal:** Implement Graph Versioning system to ensure Published graphs are immutable and Draft/Published states are clearly separated.

**Why Critical:**
- Current system allows editing Published graphs, causing production chaos
- No clear distinction between Draft and Published states
- Product bindings can be affected by graph edits
- Violates ERP production safety principles

**Reference Documents:**
- `docs/super_dag/01-concepts/GRAPH_VERSIONING_AND_PRODUCT_BINDING.md` (Core concept)
- `docs/super_dag/01-concepts/RUNTIME_ENABLED_AUDIT_AND_MIGRATION.md` (Runtime migration)
- `docs/super_dag/00-audit/PHASE_A_RUNTIME_UI_REMOVAL_SUMMARY.md` (Phase A complete)
- `docs/super_dag/00-audit/PRODUCT_MODAL_VERSIONING_AUDIT.md` (Product Modal audit)
- `docs/super_dag/02-api/DAG_GRAPH_API_CONTRACTS_V1.md` (Phase 4 contracts)

---

## Terminology (Critical - Prevents Confusion)

**Graph-Level Status:**
- **Active** = Graph is in use (shown in list)
- **Archived** = Graph is soft-deleted (hidden from list, but data preserved)

**Version-Level Status:**
- **Draft** = Editable workspace (not published)
- **Published** = Immutable snapshot (can be used for new jobs)
- **Retired** = Published snapshot that remains viewable but disallowed for new jobs (`allow_new_jobs=0`)

**Key Distinction:**
- **Archived (Graph)** = Soft-deleted graph (entire graph hidden)
- **Retired (Version)** = Old published version (still viewable, but not for new jobs)

**Why This Matters:**
Using "Archived" for both Graph and Version causes confusion. They serve different purposes:
- Graph Archived = Entire graph is deleted/hidden
- Version Retired = Specific version is deprecated but still viewable

---

## Current State Assessment

### ✅ What Already Exists

1. **Database Schema:**
   - `routing_graph_version` table exists
   - Additive schema updates applied (status/allow_new_jobs/config_json) ✅

2. **Service Layer:**
   - `GraphVersionService::listVersions()` ✅
   - `GraphVersionService::compareVersions()` ✅
   - `GraphVersionService::publish()` ✅ (creates published snapshot + auto-creates new draft)

3. **API Endpoints (Separated Contracts):**
   - `graph_versions` ✅ (list versions incl. draft)
   - `graph_version_compare` ✅
   - `graph_publish` ✅
   - `graph_save_draft` ✅ (payload-only)
   - `graph_validate_design` ✅ (payload-only, no persistence)
   - `graph_autosave` ✅ (positions-only, limited merge)
   - `node_update_properties` ✅ (node-level only, draft-only)

4. **UI Components:**
   - Version info + selector ✅
   - Published/Retired read-only mode ✅
   - Create Draft from Published ✅
   - Publish confirmation dialog ✅

5. **Editor Safety & Observability (DEV):**
   - SSOT reset owner (GraphDesigner) ✅
   - DEBUG_DAG gate system ✅
   - DAG_TEST harness + metrics schema enforcement ✅

### ❌ What's Missing

1. **API Contract Documentation:**
   - Write the final API reference (Phase 4 docs) ⏳

2. **Runtime/Allow New Jobs Migration (Optional / Deferred):**
   - Migrate legacy Runtime toggle semantics to version-level `allow_new_jobs` (Task 28.12) 📋

3. **Hardening (Optional):**
   - Add small smoke checks / CI hooks to prevent regression (no syntax-loop edits) 📋

---

## Implementation Phases

### Phase 1: Safety Net (Immediate - Stop Damage)

**Priority:** 🔴 **CRITICAL**  
**Timeline:** 3-5 days  
**Risk:** 🟢 **LOW** (Read-only enforcement, no data migration)

**Goal:** Prevent further damage by enforcing Published immutability.

**✅ Recommended Execution Order (For Quickest Real-World Impact):**
1. **Task 28.3** - Product Viewer Isolation (prevents products from seeing Draft) ✅ **COMPLETE**
2. **Task 28.1** - Published Read-Only (prevents editing Published) ✅ **COMPLETE**
3. **Task 28.2** - Save Routing (ensures Save creates Draft from Published) ✅ **COMPLETE**

**Rationale:** Task 28.3 is highest impact (production safety), then 28.1 (prevents accidental edits), then 28.2 (completes the safety net).

**Phase 1 Status:** ✅ **COMPLETE** - All 3 tasks finished!

#### Task 28.1: Published Graph Read-Only Enforcement

**Status:** 📋 **PLANNED**  
**Effort:** 4-6 hours  
**Dependencies:** None

**What:**
- Disable all editing controls when viewing Published graph
- Show "Create Draft" button only (hide Save, Edit controls)
- Add visual indicator (🔒 Read-only badge)
- Block save operations on Published graphs

**Files to Modify:**
- `assets/javascripts/dag/graph_designer.js` - Add read-only mode detection
- `assets/javascripts/dag/modules/GraphActionLayer.js` - Block mutations in read-only mode
- `views/routing_graph_designer.php` - Add read-only UI indicators

**Acceptance Criteria:**
- [ ] Published graph shows 🔒 Read-only badge
- [ ] Save button disabled when viewing Published
- [ ] Drag/Add/Delete blocked when viewing Published
- [ ] "Create Draft" button visible when viewing Published

---

#### Task 28.2: Save Routing (Draft vs Published)

**Status:** 📋 **PLANNED**  
**Effort:** 6-8 hours  
**Dependencies:** Task 28.1

**What:**
- Update save logic: If viewing Published → Show confirmation modal → Create draft → Switch to draft
- Update save logic: Save always writes to draft (never overwrites published)
- Add validation: Block save to published graph

**🔒 Source of Truth Rule (CRITICAL):**
- `graph_save_draft` / `graph_validate_design`: Nodes/edges come from **UI payload ONLY** (no DB merge)
- DO NOT merge with existing DB data (except for node_update_properties/autosave)
- UI payload is the source of truth

**🔒 UX Outcome (MANDATORY):**

When user clicks "Save" while viewing Published graph:

1. **Show Confirmation Modal:**
   ```
   Create new Draft from v2 (Published)?
   
   This will create a new Draft version (v3) based on the
   current Published version (v2).
   
   ⚠️ Important:
   • Published version v2 will remain unchanged
   • New Draft v3 will be created for editing
   • Product bindings will continue using v2
   
   [ Create Draft ]   [ Cancel ]
   ```

2. **After Confirmation:**
   - Create new Draft (v3) based on current Published state
   - Switch UI to Draft mode immediately
   - Show badge: "v3 (Draft) 🟡"
   - Enable all editing controls
   - Show success message: "Draft v3 created from Published v2"

**Files to Modify:**
- `source/dag/Graph/Service/GraphSaveEngine.php` - Add draft check, enforce payload-only source of truth
- `source/dag_routing_api.php` - Update `graph_save` action, reject DB merge
- `assets/javascripts/dag/graph_designer.js` - Update save handler, show confirmation modal

**Acceptance Criteria:**
- [ ] Save on Published graph shows confirmation modal (not automatic)
- [ ] After confirmation, creates Draft and switches to Draft mode
- [ ] Save on Draft graph updates Draft (not Published)
- [ ] API rejects direct save to Published graph
- [ ] API uses payload as source of truth (no DB merge)
- [ ] User sees clear success message: "Draft v3 created from Published v2"
- [ ] UI switches to Draft mode with correct badge

---

#### Task 28.3: Product Viewer Isolation

**Status:** ✅ **COMPLETE**  
**Effort:** 6-8 hours  
**Dependencies:** None

**What:**
- Enforce Product Modal reads from published snapshot only
- Add validation to reject draft versions in product context
- Update `ProductGraphBindingHelper::getGraphVersion()` to enforce published-only
- Add context parameter to API endpoints (`context=product`)
- Update frontend preview function to handle Draft rejection

**Files to Modify:**
- `source/BGERP/Helper/ProductGraphBindingHelper.php` - Add published-only check
  - Update `getGraphVersion()` to check `status = 'published'`
  - Update `validateBinding()` to reject Draft versions
- `source/dag_routing_api.php` - Add context parameter
  - Update `graph_viewer` action to enforce Published-only when `context=product`
  - Update `get_graph` action (if exists) similarly
- `assets/javascripts/products/product_graph_binding.js` - Update preview function
  - Add `context=product` parameter to API calls
  - Handle Draft version rejection with clear error message

**Reference:**
- See `docs/super_dag/00-audit/PRODUCT_MODAL_VERSIONING_AUDIT.md` for detailed audit and implementation plan

**Acceptance Criteria:**
- [x] Product viewer only shows Published/Retired versions
- [x] API rejects Draft versions in product context (`context=product`)
- [x] Error message clear when Draft is requested
- [x] `ProductGraphBindingHelper::getGraphVersion()` enforces `status = 'published'`
- [x] `ProductGraphBindingHelper::validateBinding()` rejects Draft versions
- [x] Frontend shows appropriate error message for Draft rejection

**Results:** See `docs/super_dag/tasks/results/task28.3.results.md`

---

### Phase 2: Versioning Core

**Priority:** 🟡 **HIGH**  
**Timeline:** 1-2 weeks  
**Risk:** 🟡 **MEDIUM** (Database migration, new service logic)

**Goal:** Implement core versioning infrastructure.

**⚠️ Note:** Phase 2 requires careful database schema review. See "Schema Migration Strategy" below.

#### Task 28.4: Database Schema Updates

**Status:** ✅ **COMPLETE**  
**Effort:** 4-6 hours  
**Dependencies:** None

**What:**
- Add `allow_new_jobs` field to `routing_graph_version` table
- Add `status` field (published/retired) - Note: "retired" not "archived" to avoid confusion with graph-level soft-delete
- Add `config_json` field (graph-level config)
- **Decision:** Use existing `version` (VARCHAR) - no need for `version_number` (INT)

**🔒 Schema Migration Strategy (CRITICAL):**

**Step 1: Audit Existing Schema** ✅ **COMPLETE**
- ✅ Checked `routing_graph_version` table structure
- ✅ Verified `version` is VARCHAR(20) (not INT)
- ✅ Documented current schema state

**Step 2: Migration Approach (Option A - Additive)** ✅ **IMPLEMENTED**
- ✅ Added new fields alongside existing ones
- ✅ Kept `version` (VARCHAR) - existing field (backward compatible)
- ✅ No `version_number` needed (version string is sufficient)

**Files Created:**
- ✅ `database/tenant_migrations/2025_12_graph_versioning_schema.php`

**Files Modified:**
- ✅ `docs/developer/05-database/01-schema-reference.md` - Updated schema docs

**Acceptance Criteria:**
- [x] Existing schema audited and documented
- [x] Migration approach decided (additive - Option A)
- [x] Migration script created and tested
- [x] All new fields added with proper indexes
- [x] Backward compatibility maintained (existing `version` field still works)
- [x] Schema docs updated

**Results:** See `docs/super_dag/tasks/results/task28.4.results.md`

---

#### Task 28.5: Implement GraphVersionService::publish()

**Status:** ✅ **COMPLETE**  
**Effort:** 8-10 hours  
**Dependencies:** Task 28.4 ✅ (COMPLETE - schema ready)

**What:**
- Implement `publish()` method in `GraphVersionService`
- Create immutable snapshot in `routing_graph_version`
- Auto-increment version number
- Auto-create new draft after publish
- Update graph status to 'published'
- Add transaction safety

**Files Modified:**
- ✅ `source/dag/Graph/Service/GraphVersionService.php` - Implemented publish()

**Acceptance Criteria:**
- [x] Publish creates immutable snapshot
- [x] Version number auto-increments (using MAX from routing_graph_version)
- [x] New draft created automatically
- [x] Transaction rollback on failure
- [x] Uses new schema fields (status, allow_new_jobs, config_json)
- [x] Graph status updated to 'published'

**Results:** See `docs/super_dag/tasks/results/task28.5.results.md`

---

#### Task 28.6: Create GraphVersionResolver Service

**Status:** ✅ **COMPLETE**  
**Effort:** 6-8 hours  
**Dependencies:** Task 28.5 ✅ (COMPLETE)

**What:**
- Create `GraphVersionResolver` service
- Implement `resolveGraphForProduct($productId)`
- Implement `resolveGraphForJob($jobId)`
- Enforce resolution rules (Section 5.1 of concept doc)

**Files Created:**
- ✅ `source/dag/Graph/Service/GraphVersionResolver.php`

**Files to Modify (Optional - Future Integration):**
- `source/BGERP/Helper/ProductGraphBindingHelper.php` - Can use resolver
- `source/BGERP/Service/JobCreationService.php` - Can use resolver

**Acceptance Criteria:**
- [x] Product resolution uses published snapshot only
- [x] Job resolution uses snapshot from job creation
- [x] Draft versions rejected in production context
- [x] Clear error messages
- [x] Enforces resolution rules (Section 5.1)

**Results:** See `docs/super_dag/tasks/results/task28.6.results.md`

---

### Phase 3: UX (Eliminate Confusion)

**Priority:** 🟡 **HIGH**  
**Timeline:** 1-2 weeks  
**Risk:** 🟢 **LOW** (UI changes, no data migration)

**Goal:** Make UI clear about version state and editability.

#### Task 28.7: Version Bar UI

**Status:** ✅ **COMPLETE**  
**Effort:** 3-4 hours (Simplified implementation)  
**Dependencies:** Task 28.5 ✅

**What:**
- ✅ Simplified version info display under graph title
- ✅ Show current version (v2.0) with status badge
- ✅ Minimal, non-intrusive design using Bootstrap classes
- ✅ No custom CSS or complex modules

**Files Modified:**
- ✅ `views/routing_graph_designer.php` - Added simple version info div
- ✅ `assets/javascripts/dag/graph_designer.js` - Added version info update logic

**Files Removed:**
- ❌ `assets/stylesheets/dag/version_bar.css` - Not needed (using Bootstrap)
- ❌ VersionBar.js module - Not used (simplified approach)

**Acceptance Criteria:**
- [x] Version info displays under graph title
- [x] Shows current version number (e.g., "v2.0")
- [x] Shows status badge (Published/Draft/Retired)
- [x] Uses existing Bootstrap styling (no custom CSS)
- [x] Integrates seamlessly with existing UI
- [x] Non-intrusive, minimal design

**Results:** See `docs/super_dag/tasks/results/task28.7.results.md`

---

#### Task 28.8: Version Selector Dropdown

**Status:** ✅ **COMPLETE**  
**Effort:** 4-5 hours  
**Dependencies:** Task 28.7 ✅

**What:**
- ✅ Implement Version Selector dropdown next to version info
- ✅ Populate with all versions (Draft, Published, Retired) including draft from API
- ✅ Add version badges (Draft=warning, Published=success, Retired=secondary)
- ✅ Implement version switching (reload canvas with selected version)
- ✅ Enforce read-only mode when viewing published/retired

**Files Modified:**
- ✅ `source/dag/Graph/Service/GraphVersionService.php` - Updated `listVersions()` to include draft
- ✅ `source/dag/Graph/Repository/GraphMetadataRepository.php` - Updated `getVersions()` to include status field
- ✅ `source/dag/dag_graph_api.php` - Added version parameter support to `graph_get`
- ✅ `views/routing_graph_designer.php` - Added version selector dropdown
- ✅ `assets/javascripts/dag/graph_designer.js` - Implemented version selector logic and switching

**Acceptance Criteria:**
- [x] Dropdown shows all versions (including draft)
- [x] Badges indicate status (Bootstrap badges)
- [x] Switching versions reloads canvas
- [x] Read-only mode enforced for Published/Retired

---

#### Task 28.9: Publish Confirmation Dialog

**Status:** ✅ **COMPLETE**  
**Effort:** 4-6 hours  
**Dependencies:** Task 28.5 ✅ (COMPLETE)

**What:**
- ✅ Implement publish confirmation dialog with detailed warnings
- ✅ Add warning messages (immutability, products/jobs impact, auto-create draft)
- ✅ Handle post-publish behavior (refresh versions, switch to new draft if auto-created)
- ✅ Show version number in dialog and success message
- ✅ Block publish when viewing Published/Retired (only Draft can be published)
- ✅ Disable publish button during pending requests
- ✅ Error handling in modal (keep modal open on error)

**Files Modified:**
- ✅ `assets/javascripts/dag/graph_designer.js` - Enhanced publish dialog and response handling
  - Updated `publishGraph()` to check current identity and pending requests
  - Enhanced `doPublishGraph()` with detailed confirmation modal
  - Updated `handlePublishResponse()` to refresh versions and switch to new draft
  - Added `updatePublishButtonState()` function
  - Integrated button state updates in identity change callback

**Acceptance Criteria:**
- [x] Dialog shows before publish with detailed warnings
- [x] Warning messages clear (immutability, products/jobs impact, auto-create draft)
- [x] Post-publish refreshes versions list
- [x] Post-publish switches to new draft if auto-created, otherwise switches to published
- [x] User sees success toast message
- [x] Publish blocked when viewing Published/Retired
- [x] Publish button disabled during pending requests
- [x] Error handling keeps modal open and shows error message
- [x] Uses debugLogger.core() for all logging (gated by DEBUG_DAG)

**Results:** See `docs/super_dag/tasks/results/task28.9.results.md`

---

### Phase 4: Editor Persistence Contract

**Priority:** 🟢 **MEDIUM**  
**Timeline:** 1 week  
**Risk:** 🟢 **LOW** (API clarification, no breaking changes)  
**Status:** 🟡 **IN PROGRESS**

**Goal:** Clarify and enforce API contracts for different save operations.

**Progress:**
- ✅ Task 28.13: Node Config Panel Persistence (COMPLETE)
- 🟡 Task 28.10: Separate API Endpoints (IN PROGRESS - endpoints implemented, contracts documentation pending)
- ✅ Task 28.11: Autosave Contract Definition (COMPLETE)

#### Task 28.10: Separate API Endpoints

**Status:** ✅ **COMPLETE**  
**Effort:** 6-8 hours  
**Dependencies:** Task 28.2 ✅

**What:**
- ✅ Ensure `node_update_properties` endpoint exists (verified and fixed - supports node_code-first updates)
- ✅ Ensure `graph_save_draft` endpoint exists (implemented in Task 11.3)
- ⚠️ Ensure `graph_autosave` endpoint exists (partially implemented - see Task 28.11)
- Define clear contracts (Section 6.3 of concept doc)

**🔒 API Contracts (MANDATORY - No Mixing):**

| Operation | Source of Truth | DB Merge? | Validation Scope | Version Impact |
|-----------|-----------------|-----------|------------------|----------------|
| `node_update_properties` | UI payload + DB (node config) | ✅ Yes (config only) | Node-level only | None |
| `graph_autosave` | UI payload + DB (positions) | ✅ Yes (positions only) | Minimal (syntax) | None |
| `graph_save_draft` | **UI payload ONLY** | ❌ **NEVER** | Full graph | Draft only |
| `graph_validate_design` | **UI payload ONLY** | ❌ **NEVER** | Full graph | None (no save) |
| `graph_publish` | Current draft (from DB) | N/A | Full graph | Creates Published |

**🔒 Critical Rules:**
- `graph_save_draft` / `graph_validate_design`: NEVER merge DB, use payload only
- `node_update_properties` / `graph_autosave`: CAN merge DB (limited scope)
- Each operation has ONE clear purpose - do not mix contexts
- DO NOT call `graph_save` from `node_update` (causes context mismatch)

**Files to Modify:**
- `source/dag_routing_api.php` - Add/verify endpoints, enforce contracts
- `source/dag/dag_graph_api.php` - Add/verify endpoints, enforce contracts
- `docs/API_REFERENCE.md` - Document contracts clearly

**Progress:**
- ✅ `node_update_properties`: Implemented and fixed (supports `node_code`-first updates, loads draft by `draft_id`, persists to same draft row)
- ✅ `graph_save_draft`: Implemented (Task 11.3 - manual save routes to draft only)
- ✅ `graph_autosave`: Implemented (Task 12 - autosave positions migrated to `graph_autosave` endpoint, Task 28.11 - contract finalized)
- ✅ Contracts documentation: COMPLETE (see `docs/super_dag/02-api/DAG_GRAPH_API_CONTRACTS_V1.md`)

**Acceptance Criteria:**
- [x] `node_update_properties` endpoint exists and works correctly (supports node_code-first updates)
- [x] `graph_save_draft` endpoint exists and works correctly (manual save routes to draft)
- [x] `graph_autosave` endpoint exists (autosave positions migrated)
- [x] Contracts clearly defined and enforced (documented in `DAG_GRAPH_API_CONTRACTS_V1.md`)
- [x] No cross-contamination (node_update doesn't call graph_save)
- [x] Source of truth rules enforced (payload-only for save/validate)
- [x] API docs updated with contracts (complete - see `docs/super_dag/02-api/DAG_GRAPH_API_CONTRACTS_V1.md`)

---

#### Task 28.11: Autosave Contract Definition

**Status:** ✅ **COMPLETE**  
**Effort:** 4-6 hours  
**Dependencies:** Task 28.10 ✅ (IN PROGRESS - endpoints exist)

**What:**
- ✅ Define what autosave can do (positions only)
- ✅ Define what autosave cannot do (full graph validation, node properties)
- ✅ Implement safe merge logic (already exists in `updateDraftPositions()`)
- ✅ Add validation to prevent autosave on Published (frontend + backend gates)
- ✅ Add business fields rejection in autosave payload

**🔒 Autosave Contract (Finalized):**

**Allowed:**
- ✅ Node positions only: `position_x`, `position_y`
- ✅ Node identifier: `id_node`, `node_code`
- ✅ Node label: `node_name` (non-business field)
- ✅ Merge into existing draft graph (positions only)

**Forbidden:**
- ❌ Node add/delete
- ❌ Edge add/delete
- ❌ Node property mutation: `node_config`, `properties`, `qc_policy`, `work_center_code`, `team_category`, `estimated_minutes`, `sla_minutes`, `wip_limit`, `concurrency_limit`, `assignment_policy`, `preferred_team_id`, `allowed_team_ids`, `forbidden_team_ids`, `machine_binding_mode`, `machine_codes`, `is_parallel_split`, `is_merge_node`, `merge_policy`, `split_policy`, `join_type`, `io_contract_json`
- ❌ Graph structure mutation: `edges`, `payload_json`, `graph_config`, `full_graph`
- ❌ Validation
- ❌ Draft creation
- ❌ Published mutation

**Files Modified:**
- ✅ `source/dag/dag_graph_api.php` - Added business fields validation in `graph_autosave` handler (lines 1604-1650)
  - Added `$forbiddenBusinessFields` array with comprehensive list of business logic fields
  - Added validation loop to reject nodes containing forbidden fields
  - Added security audit logging for rejected fields
  - Preserved existing `updateDraftPositions()` merge logic (positions-only merge)

**Frontend (Already Implemented - Verified):**
- ✅ `assets/javascripts/dag/graph_designer.js` - Autosave handler (lines 3314-3435)
  - Gate: Blocks autosave on Published/Retired (identity.ref !== 'draft')
  - Payload: Positions-only (`id_node`, `node_code`, `position_x`, `position_y`, `node_name`)
  - Silent failure: Returns silently if not draft (no toast, no network)

**Backend Implementation:**
- ✅ Published/Retired gate: Rejects write operations (lines 1545-1559)
- ✅ Forbidden keys check: Rejects `edges`, `payload_json`, `graph_config`, `full_graph` (lines 1585-1602)
- ✅ Business fields check: Rejects business logic fields in nodes array (lines 1615-1631)
- ✅ Safe merge: `updateDraftPositions()` updates only positions, preserves graph structure

**Acceptance Criteria:**
- [x] Autosave only saves positions (frontend payload + backend validation)
- [x] Autosave doesn't validate full graph (no validation in autosave flow)
- [x] Autosave blocked on Published (frontend gate + backend gate - double protection)
- [x] Safe merge logic implemented (existing `updateDraftPositions()` method)
- [x] Business fields rejected (comprehensive validation added)
- [x] No regression (Node Config Save, graph_save_draft, publish flow untouched)

**Results:**
- ✅ Autosave contract finalized and enforced
- ✅ Positions-only contract verified (frontend + backend)
- ✅ Published/Retired blocking verified (double protection)
- ✅ Business fields validation added (comprehensive list)
- ✅ No syntax errors
- ✅ No regression in other flows

---

#### Task 28.13: Node Config Panel Persistence (Task 13.x)

**Status:** ✅ **COMPLETE**  
**Effort:** 2-3 hours  
**Dependencies:** Task 28.10 (node_update_properties endpoint)

**What:**
- Fix Node Config side panel disappearing after successful save
- Keep panel visible after save (Option A - recommended)
- Re-render form with fresh values from response
- Update node data in memory from response
- Preserve selected node reference

**Problem:**
After successful `node_update_properties` (ok:true), the side node config panel disappeared and never came back until full page refresh. This was caused by the success handler calling `$panel.slideUp(200)`, which hid the panel, but the open logic never called `.show()` or `.slideDown()` to restore it.

**Solution (Option A - Keep Panel Visible):**
- Remove panel close logic from success handler
- Update node data from response (normalize `node_config`, update properties)
- Re-render form with fresh values using `renderNodePropertiesForm()`
- Keep panel visible so user can continue editing

**Files Modified:**
- ✅ `assets/javascripts/dag/graph_designer.js` - Updated node config save success handler (lines 9095-9148)
  - Removed `$panel.slideUp(200)` call
  - Added node data update from response
  - Added form re-render with fresh values
  - Preserved `currentlySelectedNode` reference

**Key Changes:**
1. **Success Handler (lines 9095-9148):**
   - Removed panel close logic (`$panel.slideUp(200)`)
   - Added node data normalization from response (`node_config` string → object)
   - Added property updates from `response.properties` if available
   - Added form re-render: `loadWorkCenters()` → `loadTeams()` → `renderNodePropertiesForm()`

2. **UI Behavior:**
   - Panel remains visible after save
   - Form shows fresh values from backend
   - User can continue editing without reopening panel
   - Clicking same node again opens panel immediately (no refresh needed)

**Acceptance Criteria:**
- [x] Panel remains visible after successful save
- [x] Form re-renders with fresh values from response
- [x] Node data updated in memory from response
- [x] User can click same node again and panel shows immediately
- [x] User can click different node and panel shows that node's config
- [x] No syntax errors (verified with `node -c`)
- [x] No linter errors

**Results:**
- ✅ Panel persistence fixed - no more disappearing after save
- ✅ Better UX - user can continue editing without reopening panel
- ✅ Fresh data display - form shows latest values from backend
- ✅ Minimal change - only modified success handler (low risk)

---

### Phase 5: Runtime/Allow New Jobs Migration (Optional)

**Priority:** 🟡 **HIGH** (Clarifies confusion)  
**Timeline:** 1-2 weeks  
**Risk:** 🟡 **MEDIUM** (Migration of existing flags)

**Goal:** Migrate Runtime feature flag to version-level "Allow New Jobs".

**Note:** This phase is documented separately in `RUNTIME_ENABLED_AUDIT_AND_MIGRATION.md`.  
Implementation should follow that document's migration plan.

#### Task 28.12: Runtime Migration (Deferred)

**Status:** 📋 **DEFERRED**  
**Dependencies:** Phase 1-4 complete ✅

**Condition to Start:**
- ✅ Phase 1-4 complete (all safety nets and contracts finalized)
- 📋 Node Behavior milestone complete (if applicable)
- 📋 Product team decision on migration priority

**Reference:** See `docs/super_dag/01-concepts/RUNTIME_ENABLED_AUDIT_AND_MIGRATION.md`

**Note:** This task is optional and can remain deferred indefinitely. The current system works with legacy Runtime toggle semantics. Migration to version-level `allow_new_jobs` is a future enhancement, not a blocker.

---

## Risk Assessment

### High Risk Areas

1. **Database Migration (Task 28.4)**
   - Risk: Breaking existing version data
   - Mitigation: Test migration on staging, backup before migration

2. **Publish Logic (Task 28.5)**
   - Risk: Corrupting published graphs
   - Mitigation: Transaction safety, comprehensive testing

3. **Save Routing (Task 28.2)**
   - Risk: Users lose work if Draft creation fails
   - Mitigation: Clear error messages, rollback on failure

### Low Risk Areas

1. **UI Changes (Phase 3)**
   - Risk: User confusion during transition
   - Mitigation: Clear messaging, gradual rollout

2. **Read-Only Enforcement (Task 28.1)**
   - Risk: Users frustrated by blocked actions
   - Mitigation: Clear UI indicators, "Create Draft" button prominent

---

## Dependencies & Prerequisites

### Must Complete First

1. ✅ **Phase A: Runtime UI Removal** - COMPLETE
2. 📋 **Task 28.1** - Published Read-Only (blocks Task 28.2)
3. 📋 **Task 28.4** - Schema Updates (blocks Task 28.5)

### Can Work in Parallel

- Task 28.1 and Task 28.3 (both read-only enforcement)
- Task 28.7 and Task 28.8 (both UI components)
- Task 28.10 and Task 28.11 (both API contracts)

### External Dependencies

- None (self-contained within Graph system)

---

## Testing Strategy

### Unit Tests

- [ ] `GraphVersionService::publish()` - Test snapshot creation
- [ ] `GraphVersionService::rollback()` - Test version restoration
- [ ] `GraphVersionResolver` - Test resolution rules
- [ ] Save routing logic - Test Draft vs Published behavior

### Integration Tests

- [ ] Publish flow end-to-end
- [ ] Draft creation from Published
- [ ] Product viewer isolation
- [ ] Version switching in UI

### Manual Testing

- [ ] User workflow: Draft → Publish → Edit → Save
- [ ] Read-only mode enforcement
- [ ] Version Bar display
- [ ] Version Selector functionality
- [ ] Draft-only write routing: node_update_properties / graph_save_draft / graph_autosave
- [ ] Metrics schema + DAG_TEST smoke run (DEV only)

---

## Success Criteria

**Phase 1 Complete When:**
- ✅ Published graphs cannot be edited (Task 28.1) ✅
- ✅ Save always creates/updates Draft (Task 28.2) ✅
- ✅ Product viewer only shows Published (Task 28.3) ✅

**Phase 1 Status:** ✅ **COMPLETE** - All criteria met!

**Phase 2 Complete When:**
- ✅ Publish creates immutable snapshot
- ✅ Version resolver enforces rules
- ✅ Database schema supports versioning

**Phase 3 Complete When:**
- ✅ Version Bar shows current state
- ✅ Version Selector allows history viewing
- ✅ Publish dialog confirms action ✅

**Phase 4 Complete When:**
- ✅ All endpoints exist and work correctly (COMPLETE)
- ✅ Node Config Panel persistence fixed (Task 28.13)
- ✅ Autosave contract defined and enforced (Task 28.11)
- ✅ Contracts clearly defined and documented (COMPLETE - see `docs/super_dag/02-api/DAG_GRAPH_API_CONTRACTS_V1.md`)

**Phase 4 Status:** ✅ **COMPLETE** - All criteria met!

**Overall Complete When:**
- ✅ Graph lifecycle is clear (Draft → Published → Retired)
- ✅ UI doesn't mislead users
- ✅ APIs don't mix contexts
- ✅ Production safety guaranteed
- ✅ Terminology is clear (Graph: Active/Archived, Version: Draft/Published/Retired)

---

## Notes

- **Focus:** Graph Lifecycle ONLY (not Product/Job/Runtime except for context)
- **Breaking Changes:** Minimal (mostly additive)
- **Backward Compatibility:** Maintained where possible
- **Rollback Plan:** Each phase can be rolled back independently

---

## Related Tasks

- Task 27.26: DAG Routing API Refactor (may overlap)
- Phase A: Runtime UI Removal (COMPLETE)

---

**Next Steps:**
- ✅ Phase 4 API contract docs complete (Task 28.10 - see `docs/super_dag/02-api/DAG_GRAPH_API_CONTRACTS_V1.md`)
- 📋 Task 28.12 (runtime→allow_new_jobs migration) remains DEFERRED - optional enhancement, not a blocker
- 📋 Future: Consider Task 28.12 after Node Behavior milestone (if applicable)

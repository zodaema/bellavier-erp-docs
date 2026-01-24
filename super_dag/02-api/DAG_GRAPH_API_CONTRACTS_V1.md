# DAG Graph API Contracts v1

**Version:** 1.0  
**Date:** 2025-12-12  
**Status:** ✅ **FINALIZED**  
**Scope:** Graph Designer Persistence Contracts

---

## 1. Scope & Non-Goals

### Scope

This document defines the **persistence contracts** for Graph Designer operations:

- ✅ Graph save operations (draft vs published)
- ✅ Node position autosave
- ✅ Node property updates
- ✅ Graph validation (no persistence)
- ✅ Graph publishing

### Non-Goals

- ❌ Product binding semantics (see `GRAPH_VERSIONING_AND_PRODUCT_BINDING.md`)
- ❌ Job creation workflows
- ❌ Runtime execution contracts
- ❌ Subgraph resolution rules

**Reference:** See `docs/super_dag/01-concepts/GRAPH_VERSIONING_AND_PRODUCT_BINDING.md` for product binding and version resolution rules.

---

## 2. SSOT & Version Identity

### Version Identity Structure

The UI maintains a **Single Source of Truth (SSOT)** identity object:

```javascript
{
  graphId: 1957,           // Graph ID (integer)
  ref: 'draft',            // 'draft' | 'published' | 'retired'
  versionId: null,         // Version ID (for published/retired)
  draftId: 74,            // Draft ID (for draft only)
  versionLabel: 'v2.0',   // Human-readable version label
  reqSeq: 123             // Request sequence number (optional, for trace)
}
```

### Critical Rules

**1. Draft-Only Writes:**
- ✅ `graph_save_draft` - Only works on draft
- ✅ `graph_autosave` - Only works on draft
- ✅ `node_update_properties` - Only works on draft
- ❌ Published/Retired versions are **immutable**

**2. Payload-Only Operations:**
- ✅ `graph_save_draft` - Uses UI payload ONLY (no DB merge)
- ✅ `graph_validate_design` - Uses UI payload ONLY (no persistence)
- ⚠️ `graph_autosave` - Merges positions into existing draft (limited merge)
- ⚠️ `node_update_properties` - Merges node config into existing draft (limited merge)

**3. Version Status Resolution:**
- `canonical='draft'` → Draft version
- `canonical='published:v2.0'` → Published version v2.0
- `canonical='retired:v1.0'` → Retired version v1.0
- If `canonical` not provided, backend resolves from graph status

---

## 3. Endpoint Contracts

### 3.1. `graph_validate_design`

**Purpose:** Validate graph structure without persistence.

**Allowed Mutation Scope:** None (read-only validation)

**Required Params:**
- `action`: `'graph_validate_design'`
- `id_graph`: `integer` (min: 1)
- `nodes`: `string` (JSON array of nodes)
- `edges`: `string` (JSON array of edges)

**Optional Params:**
- `canonical`: `string` (e.g., `'draft'`, `'published:v2.0'`)
- `reqSeq`: `integer` (request sequence for trace)
- `context`: `string` (`'designer'` | `'product'` | `'job'`)

**Forbidden Keys:** None (validation-only, no write)

**Example Request (form-urlencoded):**
```
POST /source/dag/dag_graph_api.php
Content-Type: application/x-www-form-urlencoded

action=graph_validate_design
&id_graph=1957
&nodes=[{"id":"OPERATION1","nodeType":"operation","label":"Cut Fabric",...}]
&edges=[{"id":"edge1","source":"OPERATION1","target":"OPERATION2",...}]
&canonical=draft
&context=designer
&reqSeq=123
```

**Example Response (ok:true):**
```json
{
  "ok": true,
  "valid": true,
  "warnings": [
    {
      "type": "structure",
      "message": "Node OPERATION1 has no outgoing edges",
      "node_code": "OPERATION1"
    }
  ],
  "errors": []
}
```

**Example Response (ok:false):**
```json
{
  "ok": false,
  "error": "Validation failed",
  "app_code": "DAG_ROUTING_400_VALIDATION",
  "meta": {
    "errors": [
      {
        "field": "nodes",
        "message": "Invalid node structure: missing required field 'nodeType'"
      }
    ]
  }
}
```

**Error Codes:**
- `DAG_ROUTING_400_VALIDATION` - Validation failed (invalid payload structure)
- `DAG_ROUTING_400_INVALID_JSON` - Invalid JSON in nodes/edges
- `DAG_ROUTING_404_GRAPH` - Graph not found

---

### 3.2. `graph_autosave`

**Purpose:** Save node positions only (lightweight autosave).

**Allowed Mutation Scope:** Positions only (`position_x`, `position_y`, `node_name`)

**Required Params:**
- `action`: `'graph_autosave'`
- `id_graph`: `integer` (min: 1)
- `nodes`: `string` (JSON array with position data only)

**Optional Params:**
- `canonical`: `string` (must be `'draft'` for write)
- `reqSeq`: `integer`
- `context`: `string` (`'designer'` | `'product'` | `'job'`)

**Forbidden Keys (Top-Level):**
- `edges` - Cannot modify edges
- `payload_json` - Cannot send full payload
- `graph_config` - Cannot modify graph config
- `full_graph` - Cannot send full graph

**Forbidden Keys (In Node Objects):**
- `node_config` - Cannot modify node config
- `properties` - Cannot modify properties
- `qc_policy` - Cannot modify QC policy
- `work_center_code` - Cannot modify work center
- `team_category` - Cannot modify team category
- `estimated_minutes` - Cannot modify estimated minutes
- `sla_minutes` - Cannot modify SLA minutes
- `wip_limit` - Cannot modify WIP limit
- `concurrency_limit` - Cannot modify concurrency limit
- `assignment_policy` - Cannot modify assignment policy
- `preferred_team_id` - Cannot modify preferred team
- `allowed_team_ids` - Cannot modify allowed teams
- `forbidden_team_ids` - Cannot modify forbidden teams
- `machine_binding_mode` - Cannot modify machine binding
- `machine_codes` - Cannot modify machine codes
- `is_parallel_split` - Cannot modify parallel split flag
- `is_merge_node` - Cannot modify merge node flag
- `merge_policy` - Cannot modify merge policy
- `split_policy` - Cannot modify split policy
- `join_type` - Cannot modify join type
- `io_contract_json` - Cannot modify IO contract

**Allowed Keys (In Node Objects):**
- `id_node` - Node DB ID (integer, optional)
- `node_code` - Node code identifier (string, required if no id_node)
- `position_x` - X position (integer, required)
- `position_y` - Y position (integer, required)
- `node_name` - Node label (string, optional, non-business field)

**Example Request:**
```
POST /source/dag/dag_graph_api.php
Content-Type: application/x-www-form-urlencoded

action=graph_autosave
&id_graph=1957
&nodes=[{"id_node":123,"node_code":"OPERATION1","position_x":100,"position_y":200,"node_name":"Cut Fabric"}]
&canonical=draft
&context=designer
&reqSeq=456
```

**Example Response (ok:true):**
```json
{
  "ok": true,
  "message": "Position updates saved to draft",
  "draft_id": 74,
  "updated_nodes": 1
}
```

**Example Response (ok:false - Published/Retired):**
```json
{
  "ok": false,
  "error": "Cannot modify Published/Retired version",
  "app_code": "DAG_ROUTING_403_READ_ONLY_VERSION",
  "error": "READ_ONLY_VERSION",
  "message": "Cannot modify Published/Retired version. Create or switch to Draft.",
  "version_status": "published"
}
```

**Example Response (ok:false - Forbidden Field):**
```json
{
  "ok": false,
  "error": "Autosave cannot modify node properties",
  "app_code": "DAG_ROUTING_400_AUTOSAVE_FORBIDDEN_FIELD",
  "error": "AUTOSAVE_FORBIDDEN_FIELD",
  "message": "Autosave can only update positions. Forbidden field in node: node_config",
  "forbidden_field": "node_config"
}
```

**Error Codes:**
- `DAG_ROUTING_403_READ_ONLY_VERSION` - Cannot autosave on Published/Retired
- `DAG_ROUTING_400_AUTOSAVE_FORBIDDEN_KEY` - Forbidden key in top-level payload
- `DAG_ROUTING_400_AUTOSAVE_FORBIDDEN_FIELD` - Forbidden field in node object
- `DAG_ROUTING_400_NO_DRAFT` - No active draft exists (must save draft first)
- `DAG_ROUTING_400_INVALID_JSON` - Invalid JSON in nodes array
- `DAG_ROUTING_500_AUTOSAVE_FAILED` - Internal error during autosave

**Backend Behavior:**
- Loads existing draft by `id_graph`
- Merges position updates into existing draft payload
- Preserves graph structure (nodes, edges unchanged)
- Updates only `position_x`, `position_y`, `node_name` fields

---

### 3.3. `graph_save_draft`

**Purpose:** Save full graph to draft (manual save).

**Allowed Mutation Scope:** Full graph structure (nodes + edges)

**Required Params:**
- `action`: `'graph_save_draft'`
- `id_graph`: `integer` (min: 1)
- `nodes`: `string` (JSON array of nodes)
- `edges`: `string` (JSON array of edges)

**Optional Params:**
- `draft_id`: `integer` (if updating existing draft)
- `canonical`: `string` (must be `'draft'` for write)
- `context`: `string` (`'designer'` | `'product'` | `'job'`)
- `reqSeq`: `integer`
- `version_note`: `string` (optional note for draft)

**Forbidden Keys:** None (full payload expected)

**Critical Rule:** **Payload-Only Source of Truth**
- Backend uses UI payload ONLY (no DB merge)
- Existing draft data is replaced (not merged)
- UI payload is the authoritative source

**Example Request:**
```
POST /source/dag/dag_graph_api.php
Content-Type: application/x-www-form-urlencoded

action=graph_save_draft
&id_graph=1957
&draft_id=74
&nodes=[{"id":"OPERATION1","nodeType":"operation","label":"Cut Fabric","position_x":100,"position_y":200,...}]
&edges=[{"id":"edge1","source":"OPERATION1","target":"OPERATION2",...}]
&canonical=draft
&context=designer
&reqSeq=789
&version_note=Updated work centers
```

**Example Response (ok:true):**
```json
{
  "ok": true,
  "message": "Draft saved successfully",
  "draft_id": 74,
  "mode": "draft",
  "validation_warnings": [
    {
      "type": "structure",
      "message": "Node OPERATION1 has no outgoing edges",
      "node_code": "OPERATION1"
    }
  ]
}
```

**Example Response (ok:false - Published/Retired):**
```json
{
  "ok": false,
  "error": "Cannot modify Published/Retired version",
  "app_code": "DAG_ROUTING_403_READ_ONLY_VERSION",
  "error": "READ_ONLY_VERSION",
  "message": "Cannot modify Published/Retired version. Create or switch to Draft.",
  "version_status": "published"
}
```

**Error Codes:**
- `DAG_ROUTING_403_READ_ONLY_VERSION` - Cannot save to Published/Retired
- `DAG_ROUTING_400_VALIDATION` - Validation failed
- `DAG_ROUTING_400_INVALID_PAYLOAD_SHAPE` - Invalid payload structure
- `DAG_ROUTING_400_INVALID_JSON` - Invalid JSON in nodes/edges
- `DAG_ROUTING_500_SAVE_FAILED` - Internal error during save

**Backend Behavior:**
- Normalizes payload using `GraphPayloadNormalizer`
- Validates graph structure (warnings only, no errors for draft)
- Saves to `routing_graph_draft` table
- Creates new draft if none exists, updates existing draft if `draft_id` provided

---

### 3.4. `node_update_properties`

**Purpose:** Update node properties/config in draft (node-level only).

**Allowed Mutation Scope:** Node properties/config only (not positions, not graph structure)

**Required Params:**
- `action`: `'node_update_properties'`
- `id_graph`: `integer` (min: 1)
- `draft_id`: `integer` (min: 1)
- Node identifier: At least one of:
  - `id_node`: `integer` (min: 1) OR
  - `node_code`: `string` (non-empty)

**Optional Params:**
- `canonical`: `string` (must be `'draft'` for write)
- `context`: `string` (`'designer'` | `'product'` | `'job'`)
- `reqSeq`: `integer`
- Node property fields (see Allowed Fields below)

**Forbidden Keys:** None (properties sent as individual fields or `properties` JSON)

**Allowed Fields (Node Properties):**
- `work_center_code` - Work center code (string)
- `team_category` - Team category (string: `'cutting'` | `'sewing'` | `'qc'` | `'finishing'` | `'general'`)
- `estimated_minutes` - Estimated minutes (integer, nullable)
- `sla_minutes` - SLA minutes (integer, nullable)
- `wip_limit` - WIP limit (integer, nullable)
- `concurrency_limit` - Concurrency limit (integer, nullable)
- `assignment_policy` - Assignment policy (string: `'auto'` | `'team_hint'` | `'team_lock'`)
- `preferred_team_id` - Preferred team ID (integer, nullable)
- `allowed_team_ids` - Allowed team IDs (JSON array or JSON string)
- `forbidden_team_ids` - Forbidden team IDs (JSON array or JSON string)
- `node_config` - Node config (JSON object or JSON string)
- `qc_policy` - QC policy (JSON object or JSON string)

**Example Request:**
```
POST /source/dag/dag_graph_api.php
Content-Type: application/x-www-form-urlencoded

action=node_update_properties
&id_graph=1957
&draft_id=74
&node_code=OPERATION1
&work_center_code=SKIV
&node_config={}
&canonical=draft
&context=designer
&reqSeq=101
```

**Example Response (ok:true):**
```json
{
  "ok": true,
  "draft_id": 74,
  "id_graph": 1957,
  "node_code": "OPERATION1",
  "id_node": 123,
  "updated_fields": ["work_center_code", "node_config"]
}
```

**Example Response (ok:false - Node Not Found):**
```json
{
  "ok": false,
  "error": "Validation failed",
  "app_code": "DAG_ROUTING_400_VALIDATION",
  "meta": {
    "errors": [
      {
        "field": "node_code",
        "message": "Node \"OPERATION1\" not found in draft payload for draft_id=74"
      }
    ]
  }
}
```

**Known Gotcha:**
- **Node must exist in draft payload:** If `node_code` is provided but node doesn't exist in draft, backend returns 400.
- **Solution:** Ensure draft graph is loaded and node exists in draft before calling `node_update_properties`.
- **Workaround:** Use `graph_save_draft` first to ensure node exists in draft, then call `node_update_properties`.

**Error Codes:**
- `DAG_ROUTING_403_READ_ONLY_VERSION` - Cannot update node in Published/Retired
- `DAG_ROUTING_400_VALIDATION` - Validation failed (missing node identifier, node not found)
- `DAG_ROUTING_404_DRAFT_ID` - Draft not found for provided `draft_id`
- `DAG_GRAPH_500_ERROR` - Internal error (JSON encode/decode failure, etc.)

**Backend Behavior:**
- Loads draft by `id_graph` and `draft_id` (hard lock)
- Finds node by `id_node` (if provided) OR `node_code` (if provided)
- Merges allowed fields into node object
- Persists updated draft payload back to same `draft_id`
- Does NOT modify positions or graph structure

---

### 3.5. `graph_publish`

**Purpose:** Publish current draft to create immutable published version.

**Allowed Mutation Scope:** Creates new published version (does not modify existing published)

**Required Params:**
- `action`: `'graph_publish'`
- `id_graph`: `integer` (min: 1)

**Optional Params:**
- `version_note`: `string` (optional note for published version)

**Forbidden Keys:** None (publish uses current draft from DB, not payload)

**Critical Rule:** **Uses Current Draft from DB**
- Backend loads current active draft from database
- Does NOT accept nodes/edges in payload
- Creates immutable snapshot in `routing_graph_version`
- Auto-creates new draft after publish (if configured)

**Example Request:**
```
POST /source/dag/dag_graph_api.php
Content-Type: application/x-www-form-urlencoded

action=graph_publish
&id_graph=1957
&version_note=Production ready v2.0
```

**Example Response (ok:true):**
```json
{
  "ok": true,
  "message": "Graph published successfully",
  "version": "v2.0",
  "version_id": 45,
  "published_at": "2025-12-12 10:30:00",
  "new_draft_id": 75,
  "auto_created_draft": true
}
```

**Example Response (ok:false - No Draft):**
```json
{
  "ok": false,
  "error": "No active draft to publish",
  "app_code": "DAG_ROUTING_400_NO_DRAFT",
  "message": "Cannot publish - no active draft exists. Save draft first."
}
```

**Error Codes:**
- `DAG_ROUTING_400_NO_DRAFT` - No active draft exists
- `DAG_ROUTING_400_VALIDATION` - Validation failed
- `DAG_ROUTING_500_PUBLISH_FAILED` - Internal error during publish

**Backend Behavior:**
- Loads active draft from `routing_graph_draft` table
- Validates draft structure (full validation, errors block publish)
- Creates immutable snapshot in `routing_graph_version`
- Auto-increments version number
- Optionally creates new draft after publish
- Updates graph status to `'published'`

---

### 3.6. `graph_versions` (Read-Only)

**Purpose:** List all versions (draft, published, retired) for a graph.

**Allowed Mutation Scope:** None (read-only)

**Required Params:**
- `action`: `'graph_versions'`
- `graphId`: `integer` (min: 1)

**Example Response:**
```json
{
  "ok": true,
  "versions": [
    {
      "version": "v2.0",
      "status": "published",
      "published_at": "2025-12-12 10:30:00",
      "published_by": 1,
      "version_id": 45
    },
    {
      "version": "v1.0",
      "status": "retired",
      "published_at": "2025-11-01 08:00:00",
      "published_by": 1,
      "version_id": 44
    }
  ],
  "draft": {
    "draft_id": 75,
    "status": "active",
    "updated_at": "2025-12-12 11:00:00"
  }
}
```

---

### 3.7. `graph_version_compare` (Read-Only)

**Purpose:** Compare two versions (published/retired only).

**Allowed Mutation Scope:** None (read-only)

**Required Params:**
- `action`: `'graph_version_compare'`
- `graphId`: `integer` (min: 1)
- `version1`: `string` (e.g., `'v2.0'`)
- `version2`: `string` (e.g., `'v1.0'`)

**Example Response:**
```json
{
  "ok": true,
  "comparison": {
    "nodes_added": 2,
    "nodes_removed": 1,
    "nodes_modified": 3,
    "edges_added": 1,
    "edges_removed": 0
  }
}
```

---

## 4. Write Routing Rules

### Manual Save → `graph_save_draft`

**When:** User clicks "Save Draft" button

**Route:** `action=graph_save_draft`

**Payload:** Full graph (nodes + edges)

**Contract:** Payload-only (no DB merge)

---

### Autosave Positions → `graph_autosave`

**When:** User drags nodes (debounced autosave)

**Route:** `action=graph_autosave`

**Payload:** Positions only (`id_node`, `node_code`, `position_x`, `position_y`, `node_name`)

**Contract:** Limited merge (positions only, preserves graph structure)

**Gate:** Must be in draft mode (frontend + backend gates)

---

### Node Config Save → `node_update_properties`

**When:** User saves node properties form

**Route:** `action=node_update_properties`

**Payload:** Node properties only (not positions, not graph structure)

**Contract:** Limited merge (node properties only, preserves positions and graph structure)

**Gate:** Must be in draft mode (`canonical='draft'`, `draft_id` required)

---

### Publish → `graph_publish`

**When:** User clicks "Publish" button

**Route:** `action=graph_publish`

**Payload:** None (uses current draft from DB)

**Contract:** Creates immutable snapshot

**Gate:** Must have active draft

---

## 5. Node Update Specifics

### Node Identifier Resolution

Backend supports **node_code-first** resolution:

1. **If `id_node` provided (integer > 0):**
   - Use `id_node` directly
   - Match node in draft by `id_node`

2. **If `node_code` provided (string):**
   - Load draft payload by `draft_id`
   - Find node by `node_code` (match `node['node_code']` OR `node['id']`)
   - Extract `id_node` from found node (if exists)

3. **If both provided:**
   - Prefer `id_node` (more specific)
   - Fallback to `node_code` if `id_node` not found

### Properties Structure

Backend accepts properties in two formats:

**Format 1: Individual Fields (Recommended)**
```
work_center_code=SKIV
&team_category=cutting
&estimated_minutes=30
&node_config={}
&qc_policy={"mode":"basic_pass_fail"}
```

**Format 2: Properties JSON (Alternative)**
```
properties={"work_center_code":"SKIV","team_category":"cutting","estimated_minutes":30}
```

**Normalization:**
- JSON strings are decoded automatically
- Empty strings → `null`
- Numeric strings → integers (for numeric fields)
- Arrays preserved (for `allowed_team_ids`, `forbidden_team_ids`)

### Known Gotcha: Node Not Found

**Problem:** If `node_code` is provided but node doesn't exist in draft payload, backend returns 400.

**Example Error:**
```json
{
  "ok": false,
  "error": "Validation failed",
  "app_code": "DAG_ROUTING_400_VALIDATION",
  "meta": {
    "errors": [
      {
        "field": "node_code",
        "message": "Node \"OPERATION1\" not found in draft payload for draft_id=74"
      }
    ]
  }
}
```

**Root Cause:**
- Draft payload doesn't contain node with matching `node_code`
- Node might be new (not yet saved to draft)
- Draft might be stale (node removed)

**Solution:**
1. **Ensure draft exists:** Call `graph_save_draft` first to ensure node exists in draft
2. **Verify node_code:** Check that node has `node_code` in draft payload
3. **Use id_node:** If node has `id_node` in draft, use `id_node` instead of `node_code`

**Working Example:**
```bash
# Step 1: Save draft (ensures node exists)
curl -X POST "http://localhost/source/dag/dag_graph_api.php" \
  -d "action=graph_save_draft" \
  -d "id_graph=1957" \
  -d "nodes=[{\"id\":\"OPERATION1\",\"nodeType\":\"operation\",...}]" \
  -d "edges=[]" \
  -d "canonical=draft"

# Step 2: Update node properties (node now exists in draft)
curl -X POST "http://localhost/source/dag/dag_graph_api.php" \
  -d "action=node_update_properties" \
  -d "id_graph=1957" \
  -d "draft_id=74" \
  -d "node_code=OPERATION1" \
  -d "work_center_code=SKIV" \
  -d "node_config={}" \
  -d "canonical=draft"
```

---

## 6. Observability (DEV Only)

### DEBUG_DAG Channels

**Purpose:** Gated logging for development/debugging

**Channels:**
- `core` - SSOT, identity, reqSeq, routing decisions
- `ui` - UI events, selector changes, panel visibility
- `perf` - Timing, RAF, resize events
- `test` - Test harness, metrics, assertions

**Usage:**
```javascript
// Enable debug logging
window.DEBUG_DAG = {
  core: true,
  ui: false,
  perf: false,
  test: true
};

// Use in code
debugLogger.core('[NodeSave] submit', { identity, node });
debugLogger.ui('[Panel] opened', { nodeId });
debugLogger.perf('[Autosave] duration', { ms: 150 });
```

**Silence Contract:**
- Default: All channels OFF (no noise)
- Only errors logged by default (`console.error` or `debugLogger.error`)
- All debug logs gated by `window.DEBUG_DAG`

### DAG_TEST Harness

**Purpose:** Test harness for Graph Designer operations (DEV only)

**Usage:**
```javascript
// Enable test mode
window.DEBUG_DAG = { test: true };

// Run tests
await window.DAG_TEST.runAll();
```

**Metrics Schema:**
- `recordDagMetric(type, payload)` - Record metric event
- Metrics include: `phase`, `submitId`, `graphId`, `canonical`, `draftId`, `ok`, `error`
- Assertions check for expected metrics within time window

**Note:** DAG_TEST and metrics are DEV-only features, not used in production.

---

## 7. Minimal End-to-End Flows

### Flow 1: Switch Published → Create Draft → Draft Editable

**Step 1:** User views Published version
- UI shows read-only mode
- "Create Draft" button visible

**Step 2:** User clicks "Create Draft"
- Frontend calls `graph_save_draft` with full graph payload
- Backend creates new draft (even if viewing Published)
- Backend switches graph to draft mode

**Step 3:** UI switches to draft mode
- `versionController.setIdentity({ ref: 'draft', draftId: 75, ... })`
- UI enables editing controls
- Badge shows "v3 (Draft) 🟡"

**API Calls:**
```
POST graph_save_draft
  id_graph=1957
  nodes=[...full graph...]
  edges=[...full graph...]
  canonical=draft
```

---

### Flow 2: Draft Manual Save Graph

**Step 1:** User edits graph (adds/removes nodes/edges)

**Step 2:** User clicks "Save Draft"
- Frontend collects current graph state from Cytoscape
- Frontend calls `graph_save_draft` with full payload

**Step 3:** Backend saves to draft
- Normalizes payload
- Validates structure (warnings only)
- Saves to `routing_graph_draft` table

**API Calls:**
```
POST graph_save_draft
  id_graph=1957
  draft_id=75
  nodes=[...current state...]
  edges=[...current state...]
  canonical=draft
  context=designer
```

---

### Flow 3: Draft Autosave Positions

**Step 1:** User drags node (position changes)

**Step 2:** Debounced autosave triggers
- Frontend gate: Check `identity.ref === 'draft'`
- If not draft: Return silently (no request)

**Step 3:** Frontend sends positions only
- Collect positions: `[{id_node: 123, node_code: 'OPERATION1', position_x: 100, position_y: 200}]`
- Call `graphAPI.autosavePositions()`

**Step 4:** Backend merges positions
- Load existing draft
- Update only position fields
- Preserve graph structure

**API Calls:**
```
POST graph_autosave
  id_graph=1957
  nodes=[{"id_node":123,"node_code":"OPERATION1","position_x":100,"position_y":200}]
  canonical=draft
  context=designer
```

---

### Flow 4: Draft Node Update Properties

**Step 1:** User opens node properties panel

**Step 2:** User changes node properties (e.g., work center)

**Step 3:** User clicks "Save"
- Frontend gate: Check `identity.ref === 'draft'` and `identity.draftId` exists
- If not draft: Show toast, return (no request)

**Step 4:** Frontend sends node properties
- Collect properties: `{work_center_code: 'SKIV', node_config: {}}`
- Call `node_update_properties`

**Step 5:** Backend updates node in draft
- Load draft by `draft_id`
- Find node by `node_code` or `id_node`
- Merge properties into node
- Persist updated draft

**API Calls:**
```
POST node_update_properties
  id_graph=1957
  draft_id=75
  node_code=OPERATION1
  work_center_code=SKIV
  node_config={}
  canonical=draft
  context=designer
```

---

## 8. Error Code Reference

### 4xx Client Errors

| Code | Description | When |
|------|-------------|------|
| `DAG_ROUTING_400_VALIDATION` | Validation failed | Invalid payload structure, missing required fields |
| `DAG_ROUTING_400_INVALID_JSON` | Invalid JSON | Malformed JSON in nodes/edges/properties |
| `DAG_ROUTING_400_INVALID_PAYLOAD_SHAPE` | Invalid payload shape | Payload normalization failed |
| `DAG_ROUTING_400_NO_DRAFT` | No draft exists | Autosave/publish requires active draft |
| `DAG_ROUTING_400_AUTOSAVE_FORBIDDEN_KEY` | Forbidden key in autosave | Autosave contains `edges`, `payload_json`, etc. |
| `DAG_ROUTING_400_AUTOSAVE_FORBIDDEN_FIELD` | Forbidden field in node | Autosave node contains `node_config`, `qc_policy`, etc. |
| `DAG_ROUTING_403_READ_ONLY_VERSION` | Read-only version | Attempting to write to Published/Retired |
| `DAG_ROUTING_404_GRAPH` | Graph not found | Invalid `id_graph` |
| `DAG_ROUTING_404_DRAFT_ID` | Draft not found | Invalid `draft_id` or draft not active |
| `DAG_ROUTING_409_VERSION` | Version conflict | ETag mismatch (concurrent edit) |

### 5xx Server Errors

| Code | Description | When |
|------|-------------|------|
| `DAG_ROUTING_500_SAVE_FAILED` | Save operation failed | Internal error during save |
| `DAG_ROUTING_500_AUTOSAVE_FAILED` | Autosave failed | Internal error during autosave |
| `DAG_ROUTING_500_PUBLISH_FAILED` | Publish failed | Internal error during publish |
| `DAG_GRAPH_500_ERROR` | Internal server error | Generic internal error (JSON encode/decode, DB error, etc.) |

---

## 9. Summary

### Contract Matrix

| Operation | Source of Truth | DB Merge? | Validation | Version Impact |
|-----------|-----------------|-----------|------------|----------------|
| `graph_validate_design` | UI payload ONLY | ❌ NEVER | Full graph | None (no save) |
| `graph_autosave` | UI payload + DB (positions) | ✅ Yes (positions only) | Minimal (syntax) | None |
| `graph_save_draft` | **UI payload ONLY** | ❌ **NEVER** | Full graph (warnings only) | Draft only |
| `node_update_properties` | UI payload + DB (node config) | ✅ Yes (config only) | Node-level only | None |
| `graph_publish` | Current draft (from DB) | N/A | Full graph (errors block) | Creates Published |

### Critical Rules

1. **Draft-Only Writes:** All write operations require `canonical='draft'` and active draft
2. **Payload-Only for Save/Validate:** `graph_save_draft` and `graph_validate_design` use UI payload ONLY (no DB merge)
3. **Limited Merge for Autosave/NodeUpdate:** `graph_autosave` and `node_update_properties` merge into existing draft (limited scope)
4. **Published Immutability:** Published/Retired versions are immutable (403 error on write attempts)

---

## 10. Task 28.12 — Stability Lock

**Status:** ✅ **COMPLETE**  
**Purpose:** Prevent regression in write routing and versioning contracts

### Regression Locks

**DEV-only Assertions:**
- `assertDraftWriteContextDev(actionName, payload)` - Helper function that validates:
  - Identity must be draft (`identity.ref === 'draft'`)
  - `draftId` must exist
  - Action must match operation type:
    - Manual save → `graph_save_draft`
    - Autosave → `graph_autosave`
    - Node save → `node_update_properties`
- Assertions are gated by `DEBUG_DAG.core` or `DEBUG_DAG.test`
- Zero impact when debug is off (silent return)

**Assertion Points (4 locations):**
1. Manual save (`performActualSave`) - Before `$.ajax` call
2. Quick fix save (`applyQuickFixAction`) - Before `$.ajax` call
3. Autosave positions (`saveGraph` silent=true) - Before `graphAPI.autosavePositions()`
4. Node config save (submit handler) - Before `$.ajax` call

**Audit Script:**
- Path: `scripts/audit_dag_write_routing.sh`
- Purpose: Prevent accidental merge of wrong endpoints
- Checks:
  - No `action: 'graph_save'` in manual write paths
  - Must find `graph_save_draft`, `graph_autosave`, `node_update_properties`
  - Must find `assertDraftWriteContextDev` helper
- Exit code: 0 = PASS, 1 = FAIL

**DAG_TEST T6:**
- Test: `T6_writeRoutingSanity()`
- Validates write routing assertions
- Checks that wrong actions are rejected
- DEV-only (requires `DEBUG_DAG.test` or `DEBUG_DAG.core`)

### Explicit Invariants

1. **Draft-Only Writes:**
   - All write operations require `canonical='draft'` and active draft
   - Published/Retired versions are immutable

2. **Autosave Positions-Only:**
   - `graph_autosave` can only update positions (`position_x`, `position_y`, `node_name`)
   - Cannot modify node properties or graph structure

3. **Product Context Published-Only:**
   - Product viewer (`context=product`) only shows Published/Retired versions
   - Draft versions rejected with 403 error

### Acceptance Checklist

**Draft Mode:**
- [x] Manual save → `graph_save_draft` (assertion validates)
- [x] Autosave drag → `graph_autosave` (assertion validates)
- [x] Node config save → `node_update_properties` (assertion validates)

**Published Mode:**
- [x] Autosave silent return (no request, frontend gate)
- [x] Node save blocked (toast + no request, frontend gate)
- [x] Manual save blocked (toast + no request, frontend gate)

**Audit Script:**
- [x] `bash scripts/audit_dag_write_routing.sh` → PASS

**DAG_TEST:**
- [x] `await window.DAG_TEST.T6_writeRoutingSanity()` → PASS (DEV mode)

---

**End of Document**

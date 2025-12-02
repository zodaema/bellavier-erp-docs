# Behavior App Contract

**Status:** Active Specification  
**Date:** 2025-01-XX  
**Version:** 1.2 (Aligned with actual code implementation)  
**Category:** SuperDAG / Node Behavior Engine

**⚠️ CRITICAL CONCEPT:** Node Behavior = **App** บนแพลตฟอร์ม BGERP  
**ไม่ใช่แค่ if/else เล็กๆ ใน TokenLifecycle**

**📋 Status Legend:**
- ✅ **Current** - Implemented and working
- 🚧 **Partial** - Partially implemented
- 📋 **Target / TODO** - Planned but not yet implemented

---

## 1. Core Concept: Behavior as App

### 1.1 Architectural Principle

**Node Behavior เป็น "แอปหนึ่งตัว" บนแพลตฟอร์ม BGERP** ที่มี:

1. **API ของตัวเอง** (`dag_behavior_exec.php` + `BehaviorExecutionService`)
2. **UI Layer ของตัวเอง** (`behavior_ui_templates.js`, `behavior_execution.js`)
3. **Domain + Rules ของตัวเอง** (เช่น QC_FINAL ต้องตามหลัง QC_SINGLE)
4. **Logging / Audit ของตัวเอง** (Behavior → canonical events → canonical timeline)

### 1.2 Client Apps

**Work Queue, PWA Scan, Job Ticket = Client Apps** ที่เรียก Behavior App

- **ไม่อนุญาตให้ logic behavior ไปโผล่ใน API อื่น**
- **Behavior-specific rules ต้อง centralized ใน BehaviorExecutionService + dag_behavior_exec**
- **Client Apps แค่ mount / call Behavior UI + Execution API**

**Analogy:** เหมือนเวลาเว็บใช้ Stripe Checkout / Payment Widget — เราไม่เขียนฟอร์มเองหมดทุกหน้า

### 1.3 Behavior App as Orchestrator (Not God Service)

**✅ BehaviorExecutionService = จุดรวม rule ที่เป็น "Behavior-specific"**

**Behavior-specific rules (อยู่ใน BehaviorExecutionService):**
- STITCH ห้าม complete ก่อน start
- QC_FINAL ต้องมี component ครบก่อน complete
- CUT ต้องมี quantity input ก่อน start
- Worker ownership validation
- Session state validation (active/paused)

**❌ Domain rules อื่น (อยู่ใน service domain ของมันเอง):**
- **Routing logic** → `DagExecutionService`, `DAGRoutingService`
- **Inventory movement** → `InventoryService`, `MaterialService`
- **Component binding** → `ComponentBindingService`
- **Serial generation** → `ComponentSerialService`
- **Token lifecycle** → `TokenLifecycleService`, `TokenWorkSessionService`

**Behavior App เป็น Orchestrator:**
- Behavior App **เรียกใช้ / trigger** domain services อื่นผ่าน canonical events
- Behavior App **ไม่ duplicate logic** ที่อยู่ใน domain services
- Behavior App **validate behavior-specific rules** แล้ว delegate ไปยัง domain services

**Example Flow:**
```
BehaviorExecutionService::execute()
  → Validate behavior-specific rules (e.g., session state, worker ownership)
  → Call TokenWorkSessionService (session management)
  → Call DagExecutionService (routing)
  → Call ComponentBindingService (component binding)
  → Generate canonical events
```

---

## 2. API Contract

### 2.1 Endpoint

**File:** `source/dag_behavior_exec.php`  
**Method:** `POST`  
**Content-Type:** `application/json`

### 2.2 Request Schema

```json
{
  "behavior_code": "STITCH" | "CUT" | "EDGE" | "QC_SINGLE" | ...,
  "source_page": "work_queue" | "pwa_scan" | "job_ticket",
  "action": "stitch_start" | "cut_complete" | "qc_pass" | ...,
  "context": {
    "token_id": 123,
    "node_id": 456,
    "work_center_code": "WC_STITCH_01",
    "mo_id": 789,
    "job_ticket_id": 101,
    "extra": {}
  },
  "form_data": {
    "pause_reason": "break",
    "notes": "Additional notes",
    "cut_quantity": 10,
    "defect_code": "SCRATCH",
    ...
  }
}
```

### 2.3 Response Schema

#### Success Response

```json
{
  "ok": true,
  "effect": "stitch_session_started" | "cut_completed_and_routed" | "qc_pass_and_routed",
  "session_id": 12345,
  "log_id": 67890,
  "token_id": 123,
  "behavior_code": "STITCH",
  "session_summary": {
    "total_seconds": 3600,
    "pause_seconds": 300,
    "net_seconds": 3300
  },
  "routing": {
    "moved": true,
    "from_node_id": 456,
    "to_node_id": 789,
    "completed": false
  }
}
```

#### Error Response

```json
{
  "ok": false,
  "error": "BEHAVIOR_INVALID_CONTEXT" | "BEHAVIOR_TOKEN_CLOSED" | "COMPONENT_INCOMPLETE" | ...,
  "app_code": "BEHAVIOR_400_INVALID_CONTEXT" | "BEHAVIOR_409_TOKEN_CLOSED" | "DAG_409_COMPONENT_INCOMPLETE" | ...,
  "message": "Token ID is required" | "Token is already closed" | "จำเป็นต้องผูก Serial ให้ครบก่อนทำขั้นตอนถัดไป",
  "action": "stitch_start",
  "behavior_code": "STITCH",
  "token_status": "completed",
  "missing": [
    {
      "component_type": "LEATHER",
      "required_count": 1,
      "bound_count": 0
    }
  ],
  "suggested_action": "กรุณาผูก Serial ให้ครบก่อน"
}
```

### 2.4 Error Codes

| Error Code | HTTP Status | App Code | Description |
|------------|-------------|----------|-------------|
| `BEHAVIOR_INVALID_CONTEXT` | 400 | `BEHAVIOR_400_INVALID_CONTEXT` | Missing required context (token_id, node_id, etc.) |
| `BEHAVIOR_TOKEN_CLOSED` | 409 | `BEHAVIOR_409_TOKEN_CLOSED` | Token is already completed/cancelled/scrapped |
| `BEHAVIOR_SESSION_ALREADY_ACTIVE` | 409 | `BEHAVIOR_409_SESSION_ALREADY_ACTIVE` | Session already active for this token and worker |
| `BEHAVIOR_NO_ACTIVE_SESSION` | 400 | `BEHAVIOR_400_NO_ACTIVE_SESSION` | No active session found (for pause/resume/complete) |
| `BEHAVIOR_WORKER_MISMATCH` | 403 | `BEHAVIOR_403_WORKER_MISMATCH` | Session belongs to different worker |
| `COMPONENT_INCOMPLETE` | 409 | `DAG_409_COMPONENT_INCOMPLETE` | Required component serials not bound |
| `unsupported_behavior` | 400 | `BEHAVIOR_400_UNSUPPORTED` | Behavior code not supported |
| `invalid_source_page` | 400 | `DAG_BEHAVIOR_400_INVALID_SOURCE_PAGE` | Invalid source_page value |

**📋 Target Error Codes (Planned but not yet implemented):**

| Error Code | HTTP Status | App Code | Description |
|------------|-------------|----------|-------------|
| `CUT_OVER_PRODUCTION_WARNING` | 200 | `BEHAVIOR_200_OVER_PRODUCTION` | CUT: Produced quantity exceeds expected (warning, not error) |
| `CUT_WASTE_REQUIRED` | 400 | `BEHAVIOR_400_WASTE_REASON_REQUIRED` | CUT: Waste quantity > 0 but reason not provided |
| `CUT_BATCH_SUMMARY_MISMATCH` | 400 | `BEHAVIOR_400_BATCH_SUMMARY_MISMATCH` | CUT: Total produced + scrapped does not match input quantity |
| `QC_FINAL_PRECEDENCE_VIOLATION` | 409 | `BEHAVIOR_409_QC_FINAL_PRECEDENCE` | QC_FINAL: Token has not passed QC_SINGLE yet |

### 2.5 Rate Limiting

**📋 Target / TODO:** Full rate limiting implementation

- **Endpoint:** `dag_behavior_exec`
- **Target Limit:** 60 requests per 60 seconds per user
- **Target Implementation:** `RateLimiter::check($member, 60, 60, 'dag_behavior_exec')`
- **Current Status:** 🚧 Partial - Rate limiter may be implemented but needs verification

### 2.6 Authentication & Authorization

- **Required:** Valid session (`memberDetail::thisLogin()`)
- **Permission:** Behavior-specific permissions (e.g., `hatthasilpa.job.ticket`)
- **Tenant Scope:** All requests scoped to current tenant DB

---

## 3. UI Contract

### 3.1 Frontend Entry Point

**File:** `assets/javascripts/dag/behavior_execution.js`  
**Global Object:** `window.BGBehaviorExec`

**✅ Current Implementation:** Task 27.1 - Generic dispatcher by `ui_template`

### 3.2 Behavior Grouping by UI Template

**✅ Current Pattern (Task 27.1):** Behaviors are grouped by `ui_template`, not individual `behavior_code`

**Behavior Families:**

1. **Hatthasilpa Single-Timer** (`ui_template = HAT_SINGLE_TIMER`)
   - Members: `STITCH`, `HARDWARE_ASSEMBLY`, `SKIVE`, `GLUE`, `ASSEMBLY`, `PACK`, `EMBOSS`
   - Handler: `executeHatSingle(node, task)` (reuses STITCH pattern)
   - Actions: `{behavior}_start`, `{behavior}_pause`, `{behavior}_resume`, `{behavior}_complete`

2. **QC Panel** (`ui_template = QC_PANEL`)
   - Members: `QC_SINGLE`, `QC_FINAL`, `QC_INITIAL`, `QC_REPAIR`
   - Handler: `executeQcSingle(node, task)`
   - Actions: `qc_pass`, `qc_fail`, `qc_rework`, `qc_send_back`

3. **Cut Dialog** (`ui_template = CUT_DIALOG`)
   - Members: `CUT`
   - Handler: `executeCut(node, task)`
   - Actions: `cut_start`, `cut_complete`

4. **Edge Dialog** (`ui_template = EDGE_DIALOG`)
   - Members: `EDGE`
   - Handler: `executeEdge(node, task)`
   - Actions: `edge_start`, `edge_complete`

**📋 Target Generic Dispatcher (Planned but NOT YET IMPLEMENTED):**

```javascript
// This is the TARGET pattern, not current implementation
function executeBehavior(node, task) {
    const behaviorCode = node.behavior_code;
    const uiTemplate = node.ui_template || node.behavior_ui_template;

    switch (uiTemplate) {
        case 'HAT_SINGLE_TIMER':
            // Used by: STITCH, HARDWARE_ASSEMBLY, SKIVE, GLUE, ASSEMBLY, PACK, EMBOSS
            return executeHatSingle(node, task);

        case 'QC_PANEL':
            // Used by: QC_SINGLE, QC_FINAL, QC_INITIAL, QC_REPAIR
            return executeQcSingle(node, task);

        case 'CUT_DIALOG':
            return executeCut(node, task);

        case 'EDGE_DIALOG':
            return executeEdge(node, task);

        default:
            console.warn(
                '[BehaviorExecution] Unsupported UI template',
                uiTemplate,
                'for behavior',
                behaviorCode
            );
            break;
    }
}
```

**✅ Current Client App Pattern:**
- Client apps call `BGBehaviorExec.send(payload, callback)` directly
- Each behavior has its own registered handler via `BGBehaviorUI.registerHandler(behaviorCode, handler)`
- Handlers are per-behavior, not template-based

**📋 Target Client App Pattern:**
- Client apps should call `executeBehavior(node, task)` as entry point (when implemented)
- Mapping to specific handlers is driven by `ui_template`, not `behavior_code`
- This allows new behaviors to be executable by just seeding DB (if they share existing `ui_template`)

**⚠️ Important for AI Agents:**
- **Current:** Use per-behavior handlers and direct `BGBehaviorExec.send()` calls
- **Target:** Template-based dispatcher is planned but **NOT YET IMPLEMENTED**
- **Do NOT generate `executeBehavior()` dispatcher code** until explicitly requested

### 3.3 Build Payload

```javascript
const payload = window.BGBehaviorExec.buildPayload(baseContext, action, formData);
```

**Parameters:**
- `baseContext`: Object with `behavior_code`, `source_page`, `token_id`, `node_id`, etc.
- `action`: String action identifier (e.g., `stitch_start`, `cut_complete`)
- `formData`: Object with form field values

**Returns:** Standardized payload object ready for API call

### 3.4 Send Request

```javascript
window.BGBehaviorExec.send(payload, function(res) {
    if (res.ok) {
        // Handle success
        if (res.routing && res.routing.moved) {
            notifySuccess('Work completed and routed to next node', 'STITCH');
        } else {
            notifySuccess('Work completed', 'STITCH');
        }
    } else {
        // Handle error
        notifyError(res.message || res.error, 'Behavior Execution');
    }
});
```

### 3.5 UI Templates

**File:** `assets/javascripts/dag/behavior_ui_templates.js`  
**Global Object:** `window.BGBehaviorUI`

**Get Template (by behavior_code):**
```javascript
const template = window.BGBehaviorUI.getTemplate(behaviorCode);
```

**✅ Current Implementation (Per-Behavior Handlers):**

**Current Pattern:** Each behavior has its own registered handler

```javascript
// STITCH handler
window.BGBehaviorUI.registerHandler('STITCH', {
    init: function($panel, baseContext) {
        $panel.find('#btn-stitch-start').on('click', function() {
            const formData = { /* ... */ };
            const payload = window.BGBehaviorExec.buildPayload(baseContext, 'stitch_start', formData);
            window.BGBehaviorExec.send(payload, function(res) { /* ... */ });
        });
    }
});

// SKIVE handler (similar pattern)
window.BGBehaviorUI.registerHandler('SKIVE', {
    init: function($panel, baseContext) {
        $panel.find('#btn-skive-start').on('click', function() {
            const formData = { /* ... */ };
            const payload = window.BGBehaviorExec.buildPayload(baseContext, 'skive_start', formData);
            window.BGBehaviorExec.send(payload, function(res) { /* ... */ });
        });
    }
});
```

**📋 Target Pattern (Template-Based Handlers - NOT YET IMPLEMENTED):**

**Future:** Template-based handlers that work for all behaviors sharing the same `ui_template`

```javascript
// Handler for HAT_SINGLE_TIMER template (shared by STITCH, SKIVE, GLUE, etc.)
window.BGBehaviorUI.registerHandler('HAT_SINGLE_TIMER', {
    init: function($panel, baseContext) {
        const behaviorCode = baseContext.behavior_code.toLowerCase();
        // Generic handler that works for all single-piece behaviors
        $panel.find(`#btn-${behaviorCode}-start`).on('click', function() {
            const formData = { /* ... */ };
            const payload = window.BGBehaviorExec.buildPayload(baseContext, `${behaviorCode}_start`, formData);
            window.BGBehaviorExec.send(payload, function(res) { /* ... */ });
        });
    }
});
```

**⚠️ Important for AI Agents:**
- **Current:** Use per-behavior handlers (`registerHandler('STITCH', ...)`)
- **Target:** Template-based handlers are planned but **NOT YET IMPLEMENTED**
- **Do NOT generate template-based handler code** until explicitly requested
- When adding new behaviors, follow existing per-behavior pattern

### 3.6 Event Lifecycle

1. **User Action** → Frontend handler triggered
2. **Build Payload** → `BGBehaviorExec.buildPayload()`
3. **Send Request** → `BGBehaviorExec.send()` → `dag_behavior_exec.php`
4. **Backend Execution** → `BehaviorExecutionService::execute()`
5. **Response** → Frontend callback executed
6. **UI Update** → Refresh token list, update status, show notifications
7. **Routing Event** → If token routed, dispatch `BG:TokenRouted` custom event

---

## 4. Logging Contract

### 4.1 Behavior Action Log

**📋 Target / TODO:** Full `dag_behavior_log` implementation

**Table:** `dag_behavior_log` (may not be fully implemented yet)

**Columns:**
- `id_log` (PK)
- `id_token` (nullable)
- `id_node` (nullable)
- `behavior_code` (VARCHAR)
- `action` (VARCHAR)
- `source_page` (VARCHAR)
- `context_json` (JSON)
- `form_data_json` (JSON)
- `created_at` (DATETIME)

**Purpose:** Audit trail for all behavior actions

**Current Status:** 🚧 Partial
- ✅ `BehaviorExecutionService::logBehaviorAction()` method exists
- 🚧 May not be called for all behaviors yet
- 📋 **Primary audit trail:** Canonical events via `TokenEventService` (see 4.2)

**Note:** Canonical events are the **primary source of truth** for behavior execution timeline. `dag_behavior_log` is a supplementary audit table for behavior-specific metadata.

### 4.2 Canonical Events

**✅ Current:** Primary audit trail mechanism

**Behavior Execution → Canonical Events → Canonical Timeline**

**Canonical Event Types:**
- `TOKEN_*` - Token lifecycle events
- `NODE_*` - Node transition events
- `COMP_*` - Component binding events
- `INVENTORY_*` - Inventory movement events

**Implementation:** `TokenEventService::persistEvent()`

**Status:** ✅ **Primary source of truth** for behavior execution timeline

### 4.3 Logging Format

**Standardized Log Format:**
```
[DAG_BEHAVIOR_EXEC] {CID} | User: {userId} | Org: {orgCode} | Behavior: {behaviorCode} | Action: {action} | Source: {sourcePage} | Token: {tokenId} | Node: {nodeId}
```

**Example:**
```
[DAG_BEHAVIOR_EXEC] a1b2c3d4 | User: 123 | Org: maison_atelier | Behavior: STITCH | Action: stitch_start | Source: work_queue | Token: 456 | Node: 789
```

---

## 5. Domain Rules Contract

### 5.1 Behavior-Specific Rules (✅ Current / 📋 Target)

**Behavior-specific rules = Rules ที่เกี่ยวกับ behavior execution semantics เท่านั้น**

**✅ Current (Implemented):**

**STITCH / Single-Piece Behaviors:**
- ✅ ห้าม complete ก่อน start
- ✅ ห้าม pause/resume ถ้าไม่มี active session
- ✅ Worker ต้องเป็นคนเดียวกับที่ start session
- ✅ Session state validation (active/paused)

**CUT (Batch Mode):**
- ✅ ต้องมี quantity input ก่อน start (form validation)
- ✅ Batch mode: Single session per batch, no per-piece tracking
- ✅ Form fields: `qty_produced` (required), `qty_scrapped` (optional), `reason` (optional)
- ✅ สามารถ generate component serials อัตโนมัติ (via ComponentSerialService) - 📋 Partial implementation
- ✅ สามารถ auto-bind serials ถ้า requested (via ComponentBindingService) - 📋 Partial implementation
- ✅ Leather sheet usage tracking (via LeatherSheetService)
- ✅ BOM-based cut result tracking
- 📋 **Target:** Over-production warning (when `qty_produced > expected`)
- 📋 **Target:** Waste tracking enforcement (when `qty_scrapped > 0`, require `reason`)

**QC Behaviors:**
- ✅ Pass/fail/rework actions
- ✅ Component completeness check (via DagExecutionService)

**📋 Target / TODO (Planned but not yet fully enforced):**

**QC_FINAL:**
- 📋 **Target:** ต้องตามหลัง QC_SINGLE (validation in BehaviorExecutionService) - **NOT YET ENFORCED**
- ✅ ต้องมี component serials ผูกครบก่อน complete (partially implemented via DagExecutionService)

**CUT (Additional Rules):**
- 📋 **Target:** Over-production warning when `qty_produced > expected_quantity`
- 📋 **Target:** Waste tracking enforcement when `qty_scrapped > 0` (require `reason` field)
- 📋 **Target:** Batch summary validation (total produced + scrapped should match input quantity)

**Note:** Rules marked as 📋 are architectural targets. When implementing new features or fixing bugs, prioritize implementing these rules.

### 5.2 Behavior App as Orchestrator (Not God Service)

**✅ Behavior-specific rules ต้องอยู่ใน:**
- `BehaviorExecutionService` (backend validation)
- `dag_behavior_exec.php` (API-level validation)

**❌ Domain rules อื่น (อยู่ใน service domain ของมันเอง):**
- **Routing logic** → `DagExecutionService`, `DAGRoutingService`
- **Inventory movement** → `InventoryService`, `MaterialService`
- **Component binding** → `ComponentBindingService`
- **Serial generation** → `ComponentSerialService`
- **Token lifecycle** → `TokenLifecycleService`, `TokenWorkSessionService`

**Behavior App Pattern:**
1. Validate behavior-specific rules (e.g., session state, worker ownership)
2. Call domain services (e.g., `TokenWorkSessionService`, `DagExecutionService`)
3. Generate canonical events
4. Return standardized response

**ไม่อนุญาตให้:**
- Logic behavior ไปโผล่ใน `worker_token_api.php`
- Logic behavior ไปโผล่ใน `pwa_scan_api.php`
- Logic behavior ไปโผล่ใน `job_ticket.php`
- Behavior App duplicate logic ที่อยู่ใน domain services

---

## 6. Backend Implementation Pattern

### 6.1 Behavior Family Handlers (✅ Current - Task 27.1)

**Pattern:** Behaviors are grouped into families that share execution semantics

**✅ Current Implementation in `BehaviorExecutionService::execute()` (as of Task 27.1):**

```php
switch ($behaviorCode) {
    // --- STITCH: Still uses dedicated handler (may refactor to handleSinglePiece in future) ---
    case 'STITCH':
        return $this->handleStitch($sourcePage, $action, $context, $formData);
    
    // --- Hatthasilpa Single-Timer behaviors (reuse handleSinglePiece) ---
    case 'HARDWARE_ASSEMBLY':
    case 'SKIVE':
    case 'GLUE':
    case 'ASSEMBLY':
    case 'PACK':
    case 'EMBOSS':
        return $this->handleSinglePiece($behaviorCode, $sourcePage, $action, $context, $formData);
    
    // --- Batch / Mixed behaviors ---
    case 'CUT':
        return $this->handleCut($sourcePage, $action, $context, $formData);
    
    case 'EDGE':
        return $this->handleEdge($sourcePage, $action, $context, $formData);
    
    // --- QC behaviors (reuse handleQc) ---
    case 'QC_SINGLE':
    case 'QC_FINAL':
    case 'QC_INITIAL':
    case 'QC_REPAIR':
        return $this->handleQc($sourcePage, $action, $context, $formData);
    
    default:
        return [
            'ok' => false,
            'error' => 'unsupported_behavior',
            'behavior_code' => $behaviorCode
        ];
}
```

**Key Points:**
- ✅ **Current State:** `STITCH` uses dedicated `handleStitch()` method (legacy, but stable)
- ✅ **Current State:** Other single-piece behaviors (`HARDWARE_ASSEMBLY`, `SKIVE`, `GLUE`, `ASSEMBLY`, `PACK`, `EMBOSS`) use `handleSinglePiece()` generic handler
- ✅ **Current State:** Multiple `behavior_code` values can map to the same handler family
- ✅ `handleQc()` is a generic handler for all QC behaviors
- 📋 **Future:** `STITCH` may be refactored to use `handleSinglePiece()` for consistency, but **NOT YET**
- ✅ This pattern prevents code explosion when adding new behaviors

### 6.2 Handler Family Methods (✅ Current Implementation)

**✅ Current Handler Methods:**

1. **`handleStitch($sourcePage, $action, $context, $formData)`**
   - Used by: `STITCH` only
   - Actions: `stitch_start`, `stitch_pause`, `stitch_resume`, `stitch_complete`
   - Note: Legacy handler, may be refactored to `handleSinglePiece()` in future

2. **`handleSinglePiece($behaviorCode, $sourcePage, $action, $context, $formData)`**
   - Used by: `HARDWARE_ASSEMBLY`, `SKIVE`, `GLUE`, `ASSEMBLY`, `PACK`, `EMBOSS`
   - Actions: `{behavior}_start`, `{behavior}_pause`, `{behavior}_resume`, `{behavior}_complete`
   - Generic handler that accepts `$behaviorCode` as first parameter

3. **`handleCut($sourcePage, $action, $context, $formData)`**
   - Used by: `CUT` only
   - Actions: `cut_start`, `cut_complete`
   - Batch mode handler

4. **`handleEdge($sourcePage, $action, $context, $formData)`**
   - Used by: `EDGE` only
   - Actions: `edge_start`, `edge_complete`
   - Mixed mode handler

5. **`handleQc($sourcePage, $action, $context, $formData)`**
   - Used by: `QC_SINGLE`, `QC_FINAL`, `QC_INITIAL`, `QC_REPAIR`
   - Actions: `qc_pass`, `qc_fail`, `qc_rework`, `qc_send_back`
   - Generic handler for all QC behaviors

**Parameter Signature:**
All handlers use: `(string $sourcePage, string $action, array $context, array $formData)`
Except `handleSinglePiece()` which adds `$behaviorCode` as first parameter: `(string $behaviorCode, string $sourcePage, string $action, array $context, array $formData)`

---

## 7. Client App Integration

### 7.1 Work Queue Integration

**File:** `page/work_queue.php`, `assets/javascripts/dag/work_queue.js`

**Pattern:**
1. Load Behavior UI templates: `behavior_ui_templates.js`
2. Load Behavior execution: `behavior_execution.js`
3. Mount Behavior UI: `BGBehaviorUI.getTemplate(behaviorCode)`
4. Register handlers: `BGBehaviorUI.registerHandler(behaviorCode, handler)`
5. Call Behavior API: `BGBehaviorExec.send(payload, callback)`

**ไม่อนุญาตให้:**
- Direct token status modification
- Direct session management
- Direct DAG routing

### 7.2 PWA Scan Integration

**File:** `page/pwa_scan.php`, `assets/javascripts/dag/pwa_scan.js`

**Pattern:** Same as Work Queue

**ไม่อนุญาตให้:**
- Direct token status modification
- Direct session management
- Direct DAG routing

### 7.3 Job Ticket Integration

**File:** `page/job_ticket.php`, `assets/javascripts/atelier/job_ticket.js`

**Pattern:** Same as Work Queue

**ไม่อนุญาตให้:**
- Direct token status modification
- Direct session management
- Direct DAG routing

---

## 8. Future Features

### 8.1 Anomaly Detection

**Behavior-specific analytics:**
- Detect unusual patterns (e.g., too many pauses, too long sessions)
- Alert on behavior-specific anomalies

### 8.2 Behavior-Specific Analytics

**Metrics per behavior:**
- Average execution time per behavior
- Success/failure rates per behavior
- Component binding rates per behavior

### 8.3 Behavior Versioning

**Support behavior versioning:**
- `behavior_version` field in `work_center_behavior`
- Backward compatibility handling
- Migration path for behavior updates

---

## 9. Compliance Checklist

### 9.1 Backend Compliance

- [x] ✅ All behavior-specific logic in `BehaviorExecutionService`
- [x] ✅ All behavior API calls go through `dag_behavior_exec.php`
- [x] ✅ No behavior logic in `worker_token_api.php`
- [x] ✅ No behavior logic in `pwa_scan_api.php`
- [x] ✅ Behavior family handlers implemented (Task 27.1)
- [ ] 🚧 All behavior actions logged to `dag_behavior_log` (partial)
- [x] ✅ All behavior events generate canonical events (primary audit trail)

### 9.2 Frontend Compliance

- [x] ✅ All behavior UI uses `BGBehaviorUI` templates
- [x] ✅ All behavior execution uses `BGBehaviorExec.send()`
- [x] ✅ Generic dispatcher `executeBehavior(node, task)` implemented (Task 27.1)
- [x] ✅ No direct token status modification from client
- [x] ✅ No direct session management from client
- [x] ✅ No direct DAG routing from client
- [x] ✅ Behavior handlers registered via `BGBehaviorUI.registerHandler()`

### 9.3 Integration Compliance

- [x] ✅ Work Queue = Client App only
- [x] ✅ PWA Scan = Client App only
- [x] ✅ Job Ticket = Client App only
- [x] ✅ All behavior calls go through Behavior App API
- [x] ✅ All behavior UI uses Behavior App templates

---

## 10. References

- **Node Behavior Model:** `docs/developer/03-superdag/01-core/node_behavior_model.md`
- **Work Center Behavior Spec:** `docs/developer/03-superdag/03-specs/SPEC_WORK_CENTER_BEHAVIOR.md`
- **System Wiring Guide:** `docs/developer/SYSTEM_WIRING_GUIDE.md`
- **API Standards:** `docs/developer/04-api/03-api-standards.md`

---

**Last Updated:** 2025-01-XX (v1.1 - Updated per Task 27.1)  
**Maintained By:** Development Team

---

## Changelog

### v1.1 (2025-01-XX)
- ✅ Added "Behavior Family + ui_template" section (Task 27.1)
- ✅ Clarified Behavior App as Orchestrator (not God Service)
- ✅ Marked Current vs Target / TODO status
- ✅ Updated UI Contract to reflect `executeBehavior(node, task)` pattern
- ✅ Updated Backend section to reflect family handler pattern
- ✅ Clarified that canonical events are primary audit trail

### v1.0 (2025-01-XX)
- Initial specification


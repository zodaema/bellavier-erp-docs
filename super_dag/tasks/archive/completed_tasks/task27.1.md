# Task 27.1 — Node Behavior Integration

## ⚠️ CRITICAL CONCEPT: Behavior = App

**Node Behavior = App บนแพลตฟอร์ม BGERP** (ไม่ใช่แค่ if/else เล็กๆ)

- **API ของตัวเอง:** `dag_behavior_exec.php` + `BehaviorExecutionService`
- **UI Layer ของตัวเอง:** `behavior_ui_templates.js`, `behavior_execution.js`
- **Domain + Rules ของตัวเอง:** Centralized ใน BehaviorExecutionService
- **Logging / Audit ของตัวเอง:** Behavior → canonical events → canonical timeline

**Work Queue, PWA Scan, Job Ticket = Client Apps** ที่เรียก Behavior App

- **ไม่อนุญาตให้ logic behavior ไปโผล่ใน API อื่น**
- **ทุก behavior rule ต้อง centralized ใน BehaviorExecutionService + dag_behavior_exec**

**Reference:** `docs/developer/03-superdag/03-specs/BEHAVIOR_APP_CONTRACT.md`

---

## Objective

Make every defined `work_center_behavior` executable end-to-end by:

1. Ensuring **every behavior_code has a backend execution handler** in `BehaviorExecutionService`.
2. Providing a **generic frontend execution entrypoint** that dispatches by `ui_template` instead of hard-coding behavior codes.
3. Keeping existing specific handlers (STITCH, CUT, EDGE, QC) intact while reusing them for compatible behaviors.
4. **Maintaining Behavior = App architecture:** All behavior logic centralized, Client Apps only call Behavior App API.

---

## 1. Behavior Codes Overview

Total behavior codes defined in `work_center_behavior` (seeded via `0002_seed_data.php`): **13**

### Core Behaviors

- `CUT` — Cutting (BATCH, PER_BATCH, `CUT_DIALOG`)
- `EDGE` — Edge Paint (MIXED, PER_BATCH, `EDGE_DIALOG`)
- `STITCH` — Stitching (SINGLE, PER_PIECE, `HAT_SINGLE_TIMER`)
- `QC_FINAL` — Final QC (SINGLE, PER_PIECE, `QC_PANEL`)
- `HARDWARE_ASSEMBLY` — Hardware Assembly (SINGLE, PER_PIECE, `HAT_SINGLE_TIMER`)
- `QC_REPAIR` — QC Repair (SINGLE, PER_PIECE, `QC_PANEL`)
- `QC_SINGLE` — QC Single (SINGLE, PER_PIECE, `QC_PANEL`)

### Additional Behaviors

- `SKIVE` — Skiving (SINGLE, PER_PIECE, `HAT_SINGLE_TIMER`)
- `GLUE` — Gluing (SINGLE, PER_PIECE, `HAT_SINGLE_TIMER`)
- `ASSEMBLY` — Assembly (SINGLE, PER_PIECE, `HAT_SINGLE_TIMER`)
- `PACK` — Packing (SINGLE, PER_PIECE, `HAT_SINGLE_TIMER`)
- `QC_INITIAL` — Initial QC (SINGLE, PER_PIECE, `QC_PANEL`)
- `EMBOSS` — Emboss / Hot stamp (SINGLE, PER_PIECE, `HAT_SINGLE_TIMER`)

---

## 2. Behavior Grouping (Execution Semantics)

To avoid exploding the number of handlers, behaviors are grouped by execution semantics and UI template.

### 2.1 Hatthasilpa Single-Timer (reuse STITCH handler)

All of these share:

- `execution_mode = SINGLE`
- `time_tracking_mode = PER_PIECE`
- `ui_template = HAT_SINGLE_TIMER`

Members:

- `STITCH`
- `HARDWARE_ASSEMBLY`
- `SKIVE`
- `GLUE`
- `ASSEMBLY`
- `PACK`
- `EMBOSS`

**Execution behavior**

Use the same flow as STITCH:

- Start / pause / resume / complete per piece
- Time tracking per piece
- Any downstream analytics can still differentiate by `behavior_code`

### 2.2 QC Behaviors (reuse QC handler)

All of these share:

- `execution_mode = SINGLE`
- `time_tracking_mode = PER_PIECE`
- `ui_template = QC_PANEL`

Members:

- `QC_SINGLE`
- `QC_FINAL`
- `QC_INITIAL`
- `QC_REPAIR`

**Execution behavior**

Use the same QC flow:

- Pass / fail / rework actions
- Per-piece evaluation
- Routing / next-node logic can still branch by `behavior_code` if needed

### 2.3 Batch / Mixed (existing special behaviors)

Kept as-is:

- `CUT` (BATCH, PER_BATCH, `CUT_DIALOG`)
- `EDGE` (MIXED, `EDGE_DIALOG`)

---

## 3. Backend Changes — BehaviorExecutionService

File: `source/BGERP/Dag/BehaviorExecutionService.php`

Within the relevant method, the `switch ($behaviorCode)` is updated to:

```php
switch ($behaviorCode) {
    // --- Hatthasilpa Single-Timer behaviors (reuse STITCH handler) ---
    case 'STITCH':
    case 'HARDWARE_ASSEMBLY':
    case 'SKIVE':
    case 'GLUE':
    case 'ASSEMBLY':
    case 'PACK':
    case 'EMBOSS':
        return $this->handleStitch($payload);

    // --- Batch / Mixed behaviors ---
    case 'CUT':
        return $this->handleCut($payload);

    case 'EDGE':
        return $this->handleEdge($payload);

    // --- QC behaviors (reuse common QC handler) ---
    case 'QC_SINGLE':
    case 'QC_FINAL':
    case 'QC_INITIAL':
    case 'QC_REPAIR':
        return $this->handleQc($payload);

    default:
        return $this->unsupportedBehavior($behaviorCode);
}
```

Notes:

- No new handler methods are introduced.
- Existing handlers `handleStitch`, `handleCut`, `handleEdge`, `handleQc` are reused.
- `unsupportedBehavior()` now only triggers for truly unknown codes (not seeded in DB).

---

## 4. Frontend Changes — Generic Behavior Dispatcher

File: `behavior_execution.js` (main behavior execution script for the DAG runtime UI)

A new generic dispatcher is introduced:

```js
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

Implementation notes:

- Existing functions (`executeHatSingle`, `executeCut`, `executeEdge`, `executeQcSingle`) are **not** modified.
- Other UI components should call `executeBehavior(node, task)` instead of switching on specific `behavior_code` wherever possible.
- Decision is driven by `ui_template`, so any new behavior using an existing template automatically becomes executable.

---

## 5. Resulting System Behavior

After applying Task 27.1:

1. All 13 behavior codes are **fully executable** from the DAG runtime:
   - No more `unsupported_behavior` for seeded codes.
   - All nodes with valid `behavior_code` and `ui_template` respond to user actions.

2. Backend:
   - Token execution routes every known behavior to an appropriate handler.
   - Behavior-specific differentiation is preserved via `behavior_code` in logs, analytics, and routing.

3. Frontend:
   - Execution UI is driven by `ui_template` instead of hard-coded behavior lists.
   - New behaviors that share semantics with existing ones can be onboarded by seeding DB only (no extra JS/PHP needed).

---

## 6. Architecture Compliance

### 6.1 Behavior = App Principle

**✅ Implemented:**
- All behavior logic in `BehaviorExecutionService`
- All behavior API calls go through `dag_behavior_exec.php`
- All behavior UI uses `BGBehaviorUI` templates
- All behavior execution uses `BGBehaviorExec.send()`

**❌ Forbidden:**
- Behavior logic in `worker_token_api.php`
- Behavior logic in `pwa_scan_api.php`
- Direct token status modification from client
- Direct session management from client
- Direct DAG routing from client

### 6.2 Client App Pattern

**Work Queue / PWA Scan / Job Ticket:**
1. Load Behavior UI templates: `behavior_ui_templates.js`
2. Load Behavior execution: `behavior_execution.js`
3. Mount Behavior UI: `BGBehaviorUI.getTemplate(behaviorCode)`
4. Register handlers: `BGBehaviorUI.registerHandler(behaviorCode, handler)`
5. Call Behavior API: `BGBehaviorExec.send(payload, callback)`

**Reference:** `docs/developer/03-superdag/03-specs/BEHAVIOR_APP_CONTRACT.md`

---

## 7. Checklist

- [x] Group all behaviors into execution-semantic families.
- [x] Update `BehaviorExecutionService` switch to cover all 13 behaviors.
- [x] Add generic `executeBehavior(node, task)` in `behavior_execution.js`.
- [x] Maintain Behavior = App architecture (all logic centralized).
- [x] Document Behavior App Contract.
- [ ] Refactor existing call sites to use `executeBehavior` instead of behavior-specific switches (optional follow-up task).
- [ ] Extend analytics/reporting to surface metrics per `behavior_code` family (future task).

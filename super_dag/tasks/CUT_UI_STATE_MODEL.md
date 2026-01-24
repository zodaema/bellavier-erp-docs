# CUT UI State Model

**Document Type:** Enterprise UI Architecture Contract  
**Status:** 🔒 **LOCKED** - Single Source of Truth for CUT UI Behavior  
**Last Updated:** 2026-01-13

---

## Executive Summary

This document defines the **deterministic state machine** for CUT behavior UI. It serves as the **UI Constitution** that all implementations must follow. No UI logic may deviate from this model without explicit architectural approval.

**Core Principle:** `UI = f(SystemState)` — UI is a pure function of system state, not events.

---

## State Machine Definition

### Primary State: `CUT_PHASE`

```typescript
type CUT_PHASE = 
  | 'IDLE'           // Modal closed / not initialized
  | 'SELECTING'      // Phase 1: Task Selection (Component → Role → Material)
  | 'RUNNING'        // Phase 2: Active Cutting Session (Timer active, modal locked)
  | 'COMPLETED'      // Phase 3: Post-Save Summary (Success message + release options)
  | 'ERROR'          // Error state (recoverable or fatal)
```

### Secondary State: `SESSION_STATUS`

```typescript
type SESSION_STATUS = 
  | null              // No session (IDLE or SELECTING)
  | 'RUNNING'         // Active session (from backend SSOT)
  | 'ENDED'           // Session completed (from backend SSOT)
  | 'ABORTED'         // Session aborted (from backend SSOT)
```

### Complete State Object

```typescript
interface CUT_UI_STATE {
  // Primary state
  phase: CUT_PHASE;
  
  // Session state (SSOT from backend)
  session: {
    id: number | null;
    uuid: string | null;
    status: SESSION_STATUS;
    startedAt: number | null;  // Unix timestamp (ms)
    endedAt: number | null;     // Unix timestamp (ms)
    durationSeconds: number | null;
  };
  
  // Task selection (Phase 1)
  selection: {
    component: Component | null;
    role: Role | null;
    material: Material | null;
    step: 1 | 2 | 3;  // Current step in Phase 1
  };
  
  // Execution state (Phase 2)
  execution: {
    selectedSheet: LeatherSheet | null;
    quantity: number | null;
    usedArea: number | null;  // For leather (computed from constraints)
    timerActive: boolean;
    isSaving: boolean;
  };
  
  // UI control
  modal: {
    locked: boolean;      // Modal cannot be closed (Phase 2 RUNNING only)
    degraded: boolean;    // Backend unavailable, using localStorage hint
  };
}
```

---

## Phase Definitions

### Phase: `IDLE`

**When:** Modal is closed or not yet initialized.

**UI Display:**
- ❌ No CUT UI visible
- ❌ Modal closed

**Allowed Transitions:**
- `IDLE` → `SELECTING`: User opens CUT modal (no active session)
- `IDLE` → `RUNNING`: User opens CUT modal (active session exists, auto-restore)

**State Requirements:**
- `session.id = null`
- `session.status = null`
- `selection.component = null`
- `selection.role = null`
- `selection.material = null`

---

### Phase: `SELECTING` (Phase 1)

**When:** User is selecting Component → Role → Material.

**UI Display:**
- ✅ **SHOW:** `#cut-phase1-task-selection`
- ✅ **SHOW:** Progress indicator (Step 1/2/3 badges)
- ✅ **SHOW:** Component list (Step 1)
- ✅ **SHOW:** Role list (Step 2, after component selected)
- ✅ **SHOW:** Material list (Step 3, after role selected)
- ✅ **SHOW:** "Start Cutting" button (enabled only when all 3 steps complete)
- ❌ **HIDE:** `#cut-phase2-cutting-session`
- ❌ **HIDE:** `#cut-phase3-summary`
- ❌ **HIDE:** Legacy form fields (deprecated)

**State Requirements:**
- `session.id = null` (no active session)
- `session.status = null`
- `selection.step = 1 | 2 | 3`
- `modal.locked = false` (user can close modal)

**Allowed Transitions:**
- `SELECTING` → `RUNNING`: User clicks "Start Cutting" → `cut_session_start` API success
- `SELECTING` → `IDLE`: User closes modal (no session started)
- `SELECTING` → `ERROR`: API error (recoverable, stay in SELECTING)

**Transition Logic:**
```javascript
// SELECTING → RUNNING
if (selection.component && selection.role && selection.material) {
  // Call cut_session_start API
  // On success:
  state.phase = 'RUNNING';
  state.session.id = response.session_id;
  state.session.status = 'RUNNING';
  state.session.startedAt = parseTimestamp(response.started_at);
  state.modal.locked = true;
}
```

---

### Phase: `RUNNING` (Phase 2)

**When:** Active cutting session is in progress (timer running, modal locked).

**UI Display:**
- ✅ **SHOW:** `#cut-phase2-cutting-session`
- ✅ **SHOW:** Component + Role + Material header (VERY PROMINENT)
- ✅ **SHOW:** Timer display (server-time SSOT)
- ✅ **SHOW:** Quantity input
- ✅ **SHOW:** Leather sheet selector (if material is leather)
- ✅ **SHOW:** Used area display (if leather, read-only, computed from constraints)
- ✅ **SHOW:** "Save & End Session" button (enabled when qty > 0 and sheet selected if leather)
- ✅ **SHOW:** "Cancel" button (abort session)
- ❌ **HIDE:** `#cut-phase1-task-selection`
- ❌ **HIDE:** `#cut-phase3-summary`
- ❌ **HIDE:** Legacy form fields

**State Requirements:**
- `session.id != null` (MUST exist, from backend SSOT)
- `session.status = 'RUNNING'` (from backend SSOT)
- `session.startedAt != null`
- `execution.timerActive = true`
- `modal.locked = true` (user CANNOT close modal)
- `modal.degraded = false | true` (true if backend unavailable but localStorage hint exists)

**Allowed Transitions:**
- `RUNNING` → `COMPLETED`: User clicks "Save & End Session" → `cut_session_end` API success
- `RUNNING` → `SELECTING`: User clicks "Cancel" → `cut_session_abort` API success
- `RUNNING` → `ERROR`: API error (recoverable, stay in RUNNING, show error message)

**Transition Logic:**
```javascript
// RUNNING → COMPLETED
if (execution.quantity > 0 && (!isLeather || execution.selectedSheet)) {
  // Call cut_session_end API
  // On success:
  state.phase = 'COMPLETED';
  state.session.status = 'ENDED';
  state.session.endedAt = parseTimestamp(response.ended_at);
  state.session.durationSeconds = response.duration_seconds;
  state.modal.locked = false;
}

// RUNNING → SELECTING (Cancel/Abort)
// Call cut_session_abort API
// On success:
state.phase = 'SELECTING';
state.session.id = null;
state.session.status = null;
state.modal.locked = false;
// Clear execution state but keep selection (user can retry)
```

**Critical Constraints:**
1. **Modal Lock:** Modal MUST be locked (`modal.locked = true`). User cannot:
   - Close modal (X button disabled)
   - Click backdrop (disabled)
   - Press ESC (disabled)
   - Navigate away (show `beforeunload` warning)
2. **Session Recovery:** If page refresh during RUNNING:
   - Call `get_active_cut_session` API
   - If session exists → restore to RUNNING phase
   - If API fails but localStorage hint exists → degraded mode (soft-lock)
3. **No Pause:** Pause functionality is REMOVED. Only Start, Save/Complete, and Cancel.

---

### Phase: `COMPLETED` (Phase 3)

**When:** Session ended successfully, showing summary and release options.

**UI Display:**
- ✅ **SHOW:** `#cut-phase3-summary`
- ✅ **SHOW:** Success message ("Cut session saved successfully!")
- ✅ **SHOW:** Summary table with component progress
- ✅ **SHOW:** Release buttons (if `available_to_release_qty > 0`)
- ❌ **HIDE:** `#cut-phase1-task-selection`
- ❌ **HIDE:** `#cut-phase2-cutting-session`

**State Requirements:**
- `session.status = 'ENDED'`
- `session.endedAt != null`
- `session.durationSeconds != null`
- `modal.locked = false`

**Allowed Transitions:**
- `COMPLETED` → `SELECTING`: Auto-return after 2 seconds (or user clicks "Continue Cutting")
- `COMPLETED` → `IDLE`: User closes modal

**Transition Logic:**
```javascript
// COMPLETED → SELECTING (Auto-return)
setTimeout(() => {
  state.phase = 'SELECTING';
  // Keep selection (component, role, material) for user convenience
  // Clear execution state
  state.execution.quantity = null;
  state.execution.selectedSheet = null;
  state.execution.usedArea = null;
  // Reset selection step to 1 (or keep at 3 if user wants to cut same material again)
}, 2000);
```

---

### Phase: `ERROR`

**When:** Recoverable or fatal error occurred.

**UI Display:**
- ✅ **SHOW:** Error message (user-friendly)
- ✅ **SHOW:** Retry button (if recoverable)
- ❌ **HIDE:** All phase-specific UI blocks

**State Requirements:**
- `error.message` (user-friendly)
- `error.recoverable` (boolean)
- `error.phase` (which phase error occurred in)

**Allowed Transitions:**
- `ERROR` → `SELECTING`: User clicks retry (if recoverable)
- `ERROR` → `IDLE`: User closes modal (fatal error)

---

## Transition Rules

### Deterministic Transition Table

| From Phase | Event | Condition | To Phase | Action |
|------------|-------|-----------|----------|--------|
| `IDLE` | `modal.open` | No active session | `SELECTING` | Initialize Phase 1 |
| `IDLE` | `modal.open` | Active session exists | `RUNNING` | Restore session from backend |
| `SELECTING` | `cut_session_start.success` | All selections complete | `RUNNING` | Lock modal, start timer |
| `SELECTING` | `modal.close` | No session started | `IDLE` | Clear state |
| `RUNNING` | `cut_session_end.success` | Save completed | `COMPLETED` | Unlock modal, show summary |
| `RUNNING` | `cut_session_abort.success` | Cancel clicked | `SELECTING` | Clear session, unlock modal |
| `COMPLETED` | `auto_return` | 2 seconds elapsed | `SELECTING` | Reset execution state |
| `COMPLETED` | `modal.close` | User closes | `IDLE` | Clear all state |
| Any | `api.error` | API call failed | `ERROR` | Show error, stay in current phase if recoverable |

### Forbidden Transitions

❌ **NEVER allow:**
- `RUNNING` → `SELECTING` (without aborting session first)
- `COMPLETED` → `RUNNING` (session already ended)
- `IDLE` → `RUNNING` (without session existing)
- `SELECTING` → `COMPLETED` (must go through RUNNING)

---

## UI Block Visibility Rules

### Phase 1 (SELECTING)

```javascript
// SHOW
$('#cut-phase1-task-selection').show();
$('#cut-phase1-step1').show();  // If step === 1
$('#cut-phase1-step2').show();  // If step === 2
$('#cut-phase1-step3').show();  // If step === 3

// HIDE
$('#cut-phase2-cutting-session').hide();
$('#cut-phase3-summary').hide();
$('.legacy-cut-form').hide();  // Deprecated
```

### Phase 2 (RUNNING)

```javascript
// SHOW
$('#cut-phase2-cutting-session').show();
$('#cut-phase2-component-name').text(componentCode);
$('#cut-phase2-role-name').text(roleName);
$('#cut-phase2-material-name').text(materialName);
$('#cut-phase2-leather-section').toggle(isLeather);

// HIDE
$('#cut-phase1-task-selection').hide();
$('#cut-phase3-summary').hide();
$('.legacy-cut-form').hide();
```

### Phase 3 (COMPLETED)

```javascript
// SHOW
$('#cut-phase3-summary').show();
$('#cut-phase3-summary-table').show();  // SSOT for summary data

// HIDE
$('#cut-phase1-task-selection').hide();
$('#cut-phase2-cutting-session').hide();
```

---

## Legacy UI Isolation

### Rule: Legacy UI Must Be Isolated, Not Hidden

**Current Problem:**
- Legacy form fields are hidden with `display:none` in same DOM
- Causes "flash" when state changes
- No clear separation between Enterprise and Legacy modes

**Enterprise Solution:**

```typescript
type CUT_UI_MODE = 'ENTERPRISE' | 'LEGACY';

interface CUT_UI_CONFIG {
  mode: CUT_UI_MODE;
  // If mode === 'ENTERPRISE', legacy DOM is not rendered at all
  // If mode === 'LEGACY', enterprise DOM is not rendered at all
}
```

**Implementation:**
1. **Template Separation:** Two separate templates (not same template with hide/show)
2. **DOM Separation:** Never render both in same DOM tree
3. **Lifecycle Separation:** Different initialization and cleanup logic

**Decision Required:**
- ✅ **Option A:** Work Queue = Enterprise CUT only (deprecate Legacy)
- ✅ **Option B:** Legacy CUT = separate route/page (not in Work Queue)

**Recommendation:** Option A (deprecate Legacy in Work Queue context).

---

## State Recovery & Persistence

### Backend SSOT (Single Source of Truth)

**Primary Authority:**
- `get_active_cut_session` API → Returns current session state
- `cut_session` table → Database record (authoritative)

**UI Recovery Flow:**
```javascript
// On modal open or page refresh
async function recoverState() {
  const response = await getActiveCutSession();
  
  if (response.session && response.session.status === 'RUNNING') {
    // Restore to RUNNING phase
    state.phase = 'RUNNING';
    state.session.id = response.session.session_id;
    state.session.status = 'RUNNING';
    state.modal.locked = true;
  } else {
    // No active session → SELECTING
    state.phase = 'SELECTING';
    state.session.id = null;
  }
}
```

### localStorage (UX Hint Only)

**Purpose:** Non-authoritative hint for degraded mode (backend unavailable).

**Usage:**
- ✅ Store session hint when session starts
- ✅ Use for degraded mode (backend check failed but hint exists)
- ❌ NEVER use as primary source for state decisions
- ❌ NEVER use to determine if session exists

**Degraded Mode:**
```javascript
// Backend check failed
if (backendCheckFailed && localStorageHint && localStorageHint.status === 'RUNNING') {
  state.modal.locked = true;
  state.modal.degraded = true;
  // Show retry overlay (user can retry backend check)
  // Do NOT unlock modal (prevent accidental state loss)
}
```

---

## UI Controller Contract

### Required Controller Interface

```typescript
interface CUT_UI_CONTROLLER {
  // State management
  getState(): CUT_UI_STATE;
  setState(newState: Partial<CUT_UI_STATE>): void;
  
  // Phase transitions
  transitionTo(phase: CUT_PHASE): void;
  
  // Rendering
  render(state: CUT_UI_STATE): void;
  
  // Event handlers (delegate to controller)
  onStartSession(): Promise<void>;
  onEndSession(): Promise<void>;
  onAbortSession(): Promise<void>;
  onCancel(): void;
}
```

### Controller Rules

1. **Single Authority:** Only controller may change `state.phase`
2. **Pure Rendering:** `render(state)` is pure function (no side effects)
3. **No Direct DOM:** Handlers must call controller methods, not manipulate DOM directly
4. **Deterministic:** Same state always produces same UI

### Forbidden Patterns

❌ **DO NOT:**
```javascript
// Direct DOM manipulation in handlers
$('#cut-phase1-task-selection').hide();
$('#cut-phase2-cutting-session').show();

// Direct state mutation in handlers
cutPhaseState.currentPhase = 'phase2';
```

✅ **DO:**
```javascript
// Use controller
CUTUI.transitionTo('RUNNING');
CUTUI.render(CUTUI.getState());
```

---

## Calm UI Principles

### Definition: "Calm UI"

UI that is:
- **Predictable:** User always knows what will happen next
- **Quiet:** No unexpected animations or flashes
- **Stable:** State changes are explicit and visible
- **Boring (in a good way):** No surprises

### Implementation Rules

1. **No Flash:** Never show/hide blocks without explicit user action or deterministic transition
2. **No Animation:** Avoid animations during state transitions (use instant show/hide)
3. **Clear Feedback:** Every action must have clear, immediate feedback
4. **No Hidden State:** User must always know current phase and what they can do next

### Examples

❌ **Bad (Not Calm):**
```javascript
// Flash: Legacy form appears briefly
$('.legacy-cut-form').show();  // Flash!
setTimeout(() => $('.legacy-cut-form').hide(), 100);
```

✅ **Good (Calm):**
```javascript
// Deterministic: Only show what should be shown
if (state.phase === 'SELECTING') {
  $('#cut-phase1-task-selection').show();
  $('#cut-phase2-cutting-session').hide();
}
```

---

## Validation Rules

### Phase 1 → Phase 2 Transition

**Required:**
- `selection.component != null`
- `selection.role != null`
- `selection.material != null`

**Validation:**
```javascript
function canStartSession(state: CUT_UI_STATE): boolean {
  return !!(
    state.selection.component &&
    state.selection.role &&
    state.selection.material
  );
}
```

### Phase 2 → Phase 3 Transition

**Required:**
- `execution.quantity > 0`
- `execution.selectedSheet != null` (if material is leather)
- `session.id != null` (session must exist)

**Validation:**
```javascript
function canEndSession(state: CUT_UI_STATE): boolean {
  if (!state.session.id) return false;
  if (!state.execution.quantity || state.execution.quantity <= 0) return false;
  
  const isLeather = isLeatherMaterial(state.selection.material);
  if (isLeather && !state.execution.selectedSheet) return false;
  
  return true;
}
```

---

## Error Handling

### Error States

```typescript
interface CUT_ERROR {
  message: string;           // User-friendly message
  recoverable: boolean;       // Can user retry?
  phase: CUT_PHASE;          // Which phase error occurred in
  action?: string;           // Suggested action (e.g., "retry", "reload")
}
```

### Error Recovery

**Recoverable Errors:**
- API timeout → Show retry button, stay in current phase
- Validation error → Show error message, stay in current phase
- Network error → Show retry button, stay in current phase

**Fatal Errors:**
- Backend unavailable (degraded mode exhausted) → Show error, allow modal close
- Invalid session state → Show error, reset to SELECTING

---

## Testing Requirements

### State Machine Tests

1. **Transition Tests:** Every allowed transition must be tested
2. **Forbidden Transition Tests:** Every forbidden transition must be prevented
3. **State Recovery Tests:** Recovery from backend and localStorage must work
4. **Degraded Mode Tests:** Degraded mode behavior must be tested

### UI Rendering Tests

1. **Visibility Tests:** Each phase must show/hide correct blocks
2. **Button State Tests:** Buttons must be enabled/disabled correctly
3. **Modal Lock Tests:** Modal must be locked/unlocked correctly

---

## Implementation Checklist

### Phase 1: State Model (This Document)
- [x] Define state machine
- [x] Define phase transitions
- [x] Define UI visibility rules
- [x] Define controller contract

### Phase 2: Controller Implementation
- [ ] Create `CUT_UI_CONTROLLER` class
- [ ] Implement `getState()` / `setState()`
- [ ] Implement `transitionTo()`
- [ ] Implement `render()`

### Phase 3: Legacy Isolation
- [ ] Decide: Deprecate Legacy or separate route
- [ ] Remove Legacy DOM from Enterprise template
- [ ] Test: No flash or legacy UI appearance

### Phase 4: Refactor Handlers
- [ ] Replace direct DOM manipulation with controller calls
- [ ] Replace direct state mutation with controller calls
- [ ] Test: All transitions work through controller

### Phase 5: Calm UI
- [ ] Remove all animations/flashes
- [ ] Ensure deterministic rendering
- [ ] Test: UI is predictable and stable

---

## References

- `docs/super_dag/tasks/archive/task31/task31_CUT_UX_REDESIGN_OPTION_A.md` - Original UX design
- `docs/super_dag/tasks/archive/task31/task31_CUT_SESSION_TIMING_SPEC.md` - Session timing SSOT
- `docs/super_dag/tasks/archive/task31/task31_CUT_SSOT_ARCHITECTURE_LOCK.md` - Architecture decisions

---

## Document Status

**Status:** 🔒 **LOCKED**  
**Version:** 1.0  
**Last Updated:** 2026-01-13  
**Next Review:** After controller implementation

**Change Log:**
- 2026-01-13: Initial document created (Enterprise UI Architecture Contract)

---

**⚠️ WARNING FOR FUTURE DEVELOPERS:**

This document is the **UI Constitution**. Any deviation from this state model must be:
1. Documented with architectural rationale
2. Approved by architecture review
3. Updated in this document

**DO NOT** modify UI behavior without updating this document first.

# Work Modal Timer Deprecation Plan (Phase 2)

**Goal:** Prepare safe removal of the legacy Work Modal timer block in a future phase without behavior changes. This phase introduces an explicit **primary timer element contract** and rewires writes to use it, while leaving DOM and BGTimeEngine behavior intact.

## Scope (Phase 2)
- ✅ Define a single **primary timer element** adapter.
- ✅ Rewire timer updates (WorkModalController + work_queue legacy path) to use adapter.
- ✅ Preserve CUT/non-CUT behavior and BGTimeEngine flow.
- ✅ Document fallback interval writer conditions.
- ❌ No DOM removal.
- ❌ No timer logic refactor.
- ❌ No changes to BGTimeEngine.

## Primary timer element contract
**Single adapter contract:**
- **CUT/CUTTING context** → `#cut-phase2-timer`
- **Non-CUT context** → `#workModalTimer`
- **Fallback (CUT element missing)** → `#workModalTimer`

**Implementation:**
- WorkModalController: `getPrimaryTimerElement()`
- work_queue legacy modal path: `getPrimaryWorkModalTimerElement()` (delegates to WorkModalController when available)

## Inventory + rewired callsites
### WorkModalController
- `_renderTimerDisplay()` → uses `getPrimaryTimerElement()`
- Work-queue modal static text (populate path) → uses `getPrimaryTimerElement({ behaviorCode })`
- `_syncTimer()` → routes BGTimeEngine payload + dataset updates to `getPrimaryTimerElement({ behaviorCode })`
- `_pauseTimer()` → unregisters via `getPrimaryTimerElement()`

### work_queue legacy modal path
- Pause handler → uses `getPrimaryWorkModalTimerElement()` for payload updates/unregister
- Resume handler → uses `getPrimaryWorkModalTimerElement()` for payload updates/register
- `populateWorkModal()` → uses `getPrimaryWorkModalTimerElement()` for dataset + registration
- `closeWorkModal()` → uses `getPrimaryWorkModalTimerElement()` for unregister

## Remaining dependencies (Phase 3 blockers)
1. **Legacy modal DOM block** (Elapsed Time card wrapper + children in `views/work_queue.php`).
2. **Legacy dataset contract** used by BGTimeEngine (`data-status`, `data-work-seconds-sync`, `data-last-server-sync`).
3. **Legacy modal timer updates in `work_queue.js`** (now adapter-wired but still active).
4. **WorkModalController fallback interval writer** (see next section).
5. **Legacy UI bindings** referencing `#workModalStartTime` / `#workModalStartTimeValue`.

## Fallback interval writer (keep, document, gate)
**Location:** `WorkModalController._syncTimer()`.

**When it runs:**
- If **BGTimeEngine path is unavailable**, i.e. when:
  - primary timer element missing, **or**
  - `BGTimeEngine` is undefined, **or**
  - `currentToken.timer` missing (no server timer payload).

**What it does:**
- Computes `snapshot` and writes display via `_renderTimerDisplay()`.
- Starts a local `setInterval()` only when `snapshot.isActive` is true.

**Multi-writer avoidance:**
- The BGTimeEngine path is short-circuited by `hasBGTimeEnginePath`; when active it **clears** the interval and returns early, preventing dual writers.

## Required steps before Phase 3 removal
1. **CUT-only timer migration**: confirm all CUT flows render and update `#cut-phase2-timer` consistently.
2. **Legacy modal adapter retirement**: migrate/disable `work_queue.js` legacy modal timer writes where WorkModalController is authoritative.
3. **Legacy DOM removal plan**: remove `#workModalTimerWrapper` + inner legacy timer markup from `views/work_queue.php` only after the above steps are fully validated.
4. **Behavior SSOT confirmation**: ensure any behavior-specific timer UI is mapped to core contracts without altering canonical fields.

## Verification checklist (manual)
- [ ] Non-CUT modal shows legacy timer block and ticks with BGTimeEngine.
- [ ] CUT modal hides legacy timer wrapper and uses `#cut-phase2-timer` only.
- [ ] Pause/resume/complete flows still update timer correctly.
- [ ] No double-writer intervals (check console + network; ensure only BGTimeEngine logs when active).
- [ ] `#workModalTimerWrapper` remains the sole visibility toggle for legacy block.

## Reference matrix (post-adapter)
| Writer / Location | Trigger | Primary Element Contract | Notes |
| --- | --- | --- | --- |
| `WorkModalController._renderTimerDisplay()` | Fallback interval writer | `getPrimaryTimerElement()` | Writes timer text only. |
| `WorkModalController._syncTimer()` | Modal open/rehydrate | `getPrimaryTimerElement({ behaviorCode })` | BGTimeEngine path preferred, interval fallback only when BGTimeEngine path unavailable. |
| `WorkModalController._pauseTimer()` | Modal close/pause | `getPrimaryTimerElement()` | Unregisters timer from BGTimeEngine. |
| `work_queue.js pauseToken()` | Pause click | `getPrimaryWorkModalTimerElement()` | Updates payload via BGTimeEngine. |
| `work_queue.js resumeToken()` | Resume click | `getPrimaryWorkModalTimerElement()` | Updates payload via BGTimeEngine + register. |
| `populateWorkModal()` | Modal open (legacy path) | `getPrimaryWorkModalTimerElement()` | Sets dataset + register. |
| `closeWorkModal()` | Modal close (legacy path) | `getPrimaryWorkModalTimerElement()` | Unregisters from BGTimeEngine. |

---

### Evidence (adapter implementation)
- WorkModalController adapter: `getPrimaryTimerElement()`.
- work_queue legacy adapter: `getPrimaryWorkModalTimerElement()`.

(See file references in the summary for exact line ranges.)

# Work Modal Legacy Timer Audit (Elapsed Time card)

**Date:** 2026-01-18

## Executive summary (5 bullets)

- The legacy Elapsed Time block is rendered in the Work Queue modal template and must be treated as a **public DOM contract** (`#workModalTimer`, `#workModalStartTime`, `#workModalStartTimeValue`). Evidence: `views/work_queue.php:575-586`.
- Multiple JS modules touch `#workModalTimer` (writes + dataset writes + BGTimeEngine interactions), mainly:
  - `assets/javascripts/pwa_scan/work_queue.js`
  - `assets/javascripts/pwa_scan/WorkModalController.js`
  Evidence in Reference Matrix below.
- CUT modal uses the same `#workModal` template and **hides** the legacy elapsed-time block, while using `#cut-phase2-timer` for the visible timer. Evidence: `WorkModalController.js:844-867` (hide) and `WorkModalController.js:939-986` (routes timer element).
- The reason `#workModalTimer` can appear “not updating realtime” is primarily registration/activation policy:
  - BGTimeEngine only ticks **registered** elements and only registers when `data-status === 'active'`. Evidence: `work_queue_timer.js:65-76`.
  - In paused/non-active states the element won’t tick; updates may only occur when a snapshot write happens (e.g. pause/resume handlers call `updateTimerFromPayload`). Evidence: `work_queue.js:2383-2394`, `work_queue.js:2432-2449`.
- Decision (audit-only): **do not remove yet**. Safest current stance is **✅ Keep (compat)** (or **✅ Keep but hide only in CUT**, which is already done in WorkModalController). Removing would require coordinated template + JS changes, and there is still a fallback interval writer that targets `#workModalTimer`. Evidence: `WorkModalController.js:992-1025`.

---

## Commands requested + results

### Requested commands

- `rg "#workModalTimer" -n assets/`
- `rg "workModalStartTime" -n assets/`
- `rg "registerTimerElement|unregisterTimerElement|updateTimerFromPayload" -n assets/`
- `rg "setInterval|setTimeout" -n assets/ | rg -i "timer|elapsed|workModal|cut-phase2"`

### Environment constraint

`rg` (ripgrep) is **not available** in this environment (`zsh: command not found: rg`). Therefore, evidence was collected using the IDE search tooling (`grep_search`), which provides equivalent outputs (paths + line numbers + matched lines).

---

# A) Reference Matrix (table)

Legend:

- **Read**: reads from DOM
- **Write**: sets `.text()`/`.textContent`/`.html()`
- **Dataset write**: sets `data-*` (`data-token-id`, `data-status`, `data-work-seconds-sync`, `data-last-server-sync`)
- **Toggle**: show/hide/visibility
- **Register/Unregister/UpdatePayload**: BGTimeEngine calls
- **Custom loop**: interval/setTimeout loop that updates timer

| Selector | File path + line range (evidence) | Type of usage | Context | Risk if removed |
|---|---|---|---|---|
| `#workModalTimer` | `views/work_queue.php:575-586` | Rendered HTML (`<h1 id="workModalTimer">00:00:00</h1>`) | Work Queue modal baseline | **High**: public DOM contract referenced by multiple JS call sites. |
| `#workModalStartTime` | `views/work_queue.php:582-584` | Rendered HTML (`<div id="workModalStartTime">...`) | Work Queue modal baseline | **Med**: part of same card and shown in non-CUT modal. |
| `#workModalStartTimeValue` | `views/work_queue.php:583` | Rendered HTML (`<span id="workModalStartTimeValue">`) | Work Queue modal baseline | **Med**: written by JS in legacy modal path. |
| `#workModalTimer` | `assets/javascripts/pwa_scan/work_queue.js:2666-2688` | Write + dataset write + register (`BGTimeEngine.registerTimerElement`) | Legacy Work Queue modal path (`populateWorkModal`) | **High**: breaks legacy modal path unless removed/rewired. |
| `#workModalStartTimeValue` | `assets/javascripts/pwa_scan/work_queue.js:2694-2701` | Write (`.text(...)`) | Legacy Work Queue modal path (`populateWorkModal`) | **Med**: breaks started-at display in legacy modal path. |
| `#workModalTimer` | `assets/javascripts/pwa_scan/work_queue.js:2383-2394` | Dataset write + update payload (`updateTimerFromPayload`) + unregister fallback | Pause handler in modal | **High**: pause flow touches legacy timer element directly. |
| `#workModalTimer` | `assets/javascripts/pwa_scan/work_queue.js:2432-2449` | Dataset write + update payload + register | Resume handler in modal | **High**: resume flow touches legacy timer element directly. |
| `#workModalTimer` | `assets/javascripts/pwa_scan/work_queue.js:2804-2808` | Unregister (`BGTimeEngine.unregisterTimerElement`) | Modal close cleanup | **Med**: safe cleanup requires adjusting if element removed. |
| `#workModalTimer` | `assets/javascripts/pwa_scan/WorkModalController.js:155-169` | Toggle (`visibility:hidden`, `data-timer-pending`) | WorkModalController-managed modal (flash prevention) | **Med**: removal changes timer reveal/flash behavior on that path. |
| `#workModalTimer` | `assets/javascripts/pwa_scan/WorkModalController.js:939-986` | Dataset write + update payload + register (default); CUT routes to `#cut-phase2-timer` | WorkModalController-managed modal | **High**: central controller path. |
| `#workModalTimer` | `assets/javascripts/pwa_scan/WorkModalController.js:844-877` | Toggle hide/show (and optional wrapper selection) | CUT vs non-CUT modal | **Med**: used to hide legacy card for CUT.
| `#workModalStartTime` | `assets/javascripts/pwa_scan/WorkModalController.js:844-877` | Toggle hide/show | CUT vs non-CUT modal | **Low/Med**: display-only; still expected in non-CUT.
| `#workModalTimer` | `assets/javascripts/pwa_scan/WorkModalController.js:164-169` | Write (`$workTimer.text(...)`) | Fallback render method | **Med**: demonstrates direct writer still exists.
| `#workModalTimer` | `assets/javascripts/pwa_scan/WorkModalController.js:992-1025` | **Custom loop** (`setInterval(...)` writing via `_renderTimerDisplay`) | Fallback ticker (non-BGTimeEngine path) | **High**: proves legacy element is still a write target if BGTimeEngine path not taken. |

### Wrapper/container note (Elapsed Time card wrapper)

`WorkModalController` attempts to use `#workModalTimerWrapper, .work-modal-timer-wrapper` as a wrapper selector but falls back to the element itself.

- Evidence (wrapper selection): `WorkModalController.js:846-859` and `WorkModalController.js:868-876`.
- Evidence (template has no wrapper id/class): `views/work_queue.php:575-586`.

---

# B) Runtime contexts

## B1) Where is legacy block rendered?

- Rendered in `views/work_queue.php` inside `#workModal`:
  - Work modal root: `views/work_queue.php:550-555`
  - Elapsed Time card: `views/work_queue.php:575-586`

## B2) Show/hide behavior by default

- Default HTML: visible by default (no `d-none`, no inline `display:none`) on the card. Evidence: `views/work_queue.php:575-586`.

- Runtime show/hide is driven by WorkModalController based on behavior:
  - CUT/standalone app: hide legacy timer + started-at. Evidence: `WorkModalController.js:844-867`.
  - Non-CUT: show legacy timer + started-at. Evidence: `WorkModalController.js:867-877`.

## B3) Does CUT reuse the same modal template?

Yes.

- WorkModalController targets `$('#workModal')` as the modal root. Evidence: `WorkModalController.js:33-34`.
- CUT-specific logic runs inside `_populateModal()` and hides elements in that same modal. Evidence: `WorkModalController.js:844-867`.

---

# C) Can we remove it?

## Decision

### ✅ Keep (compat) — Recommended now

**Why:**

- IDs are rendered in template and are referenced by multiple JS code paths:
  - Template: `views/work_queue.php:575-586`
  - Legacy modal JS path: `work_queue.js:2666-2688`, `work_queue.js:2694-2701`
  - WorkModalController path: `WorkModalController.js:939-986`
  - WorkModalController fallback interval mode still writes to `#workModalTimer`: `WorkModalController.js:992-1025`

### ✅ Keep but hide only in CUT — Also valid and already implemented in controller

- Hide in CUT: `WorkModalController.js:844-867`.
- CUT uses a different visible timer element: selection in `_syncTimer()` routes to `#cut-phase2-timer` for CUT. Evidence: `WorkModalController.js:939-949`.

### ✅ Remove (safe) — Not supported by current evidence

To mark removal as safe, all of the following must be proven with code evidence:

- No remaining JS references to `#workModalTimer`, `#workModalStartTime`, `#workModalStartTimeValue`.
- No remaining fallback writers or intervals targeting `#workModalTimer` (currently exists). Evidence: `WorkModalController.js:992-1025`.
- Legacy modal path (`populateWorkModal`) is removed or unreachable (currently exists). Evidence: `work_queue.js:2599-2790`.

---

# D) If removal becomes safe (conditional plan; no implementation)

Because current evidence indicates **not safe yet**, this section is a hypothetical plan for later.

## D1) Safe removal plan

1. Remove HTML block in `views/work_queue.php`:
   - Remove Elapsed Time card containing:
     - `#workModalTimer`
     - `#workModalStartTime`
     - `#workModalStartTimeValue`
   Evidence of location: `views/work_queue.php:575-586`.

2. Remove JS references and cleanup:

- `assets/javascripts/pwa_scan/work_queue.js`
  - Remove/replace `populateWorkModal()` timer setup and text writes. Evidence: `work_queue.js:2666-2688` and `work_queue.js:2694-2701`.
  - Remove/replace pause/resume timer update calls. Evidence: `work_queue.js:2383-2394` and `work_queue.js:2432-2449`.
  - Remove/replace modal close timer unregister. Evidence: `work_queue.js:2804-2808`.

- `assets/javascripts/pwa_scan/WorkModalController.js`
  - Remove hide/show logic for legacy timer and started-at. Evidence: `WorkModalController.js:844-877`.
  - Remove/replace `visibility` pending logic if it targets removed element. Evidence: `WorkModalController.js:155-169`.
  - Remove/replace fallback interval writer that writes `#workModalTimer`. Evidence: `WorkModalController.js:992-1025`.

3. Verify no runtime errors:

- Open modal for a default behavior token.
- Open modal for CUT token.
- Pause/resume in modal.
- Confirm no console errors for missing selectors.

## D2) Files expected to change

- `views/work_queue.php`
- `assets/javascripts/pwa_scan/work_queue.js`
- `assets/javascripts/pwa_scan/WorkModalController.js`

---

## Appendix: Evidence excerpts

### Elapsed Time card template

`views/work_queue.php:575-586` renders:

- `#workModalTimer`
- `#workModalStartTime`
- `#workModalStartTimeValue`

### BGTimeEngine registration policy

`assets/javascripts/pwa_scan/work_queue_timer.js:65-76`:

- `registerTimerElement()` returns early when `data-status` is not `'active'`.

### WorkModalController fallback interval mode

`assets/javascripts/pwa_scan/WorkModalController.js:992-1025`:

- uses `setInterval(...)` calling `_renderTimerDisplay(...)` which writes `#workModalTimer` (`WorkModalController.js:164-169`).

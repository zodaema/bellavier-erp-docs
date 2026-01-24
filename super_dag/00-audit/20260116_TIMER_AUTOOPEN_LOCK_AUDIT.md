# 20260116 — Timer + Auto-open + Lock Audit (Work Queue / Work Modal)

## Goal
Audit timer rendering (including `00:00:00` flash and `-60s` drift symptoms) and F5 refresh auto-open/lock behavior in Bellavier ERP. This report:

- Maps **all timer UI writers** and classifies them by type.
- Defines the **true SSOT chain** for timer values across API responses.
- Provides **evidence-based** root-cause hypotheses for:
  - Flash to `00:00:00`
  - `-60s` drift
- Audits **F5 auto-open** and the **`__ACTIVE_TOKEN_LOCK__`** mechanism.
- Provides **runtime instrumentation** snippets (no code changes required).
- Provides **two minimal fix plans** (choose one ticker owner).

## Constraints
- No backend contract changes.
- Evidence-based from repository code only.

---

## Scope / Evidence (Files reviewed)

- `views/work_queue.php`
- `assets/javascripts/pwa_scan/work_queue.js`
- `assets/javascripts/pwa_scan/work_queue_timer.js`
- `assets/javascripts/pwa_scan/WorkModalController.js`
- `assets/javascripts/dag/behavior_execution.js` (CUT UI timer)
- `assets/javascripts/pwa_scan/token_card/TokenCardParts.js`
- `source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php`
- `source/dag_token_api.php`

---

## Canonical Terms

- **Work Queue timer UI (cards):** `.work-timer-active` / `.timer-display`
- **Work Modal timer UI:** `#workModalTimer` (initial HTML shows `00:00:00`)
- **BGTimeEngine:** Frontend drift-corrected ticker in `work_queue_timer.js`
- **WorkModalController ticker:** Modal-specific `setInterval` in `WorkModalController._syncTimer()`
- **CUT timer:** `#cut-phase2-timer` (behavior panel timer, separate from `#workModalTimer`)

---

## 1) Timer Writers Audit (UI write map)

### 1.1 Timer writer classification

- **Type (1) Interval ticker** — `setInterval` writes repeatedly.
- **Type (2) One-shot render** — one-time write (e.g., initial populate).
- **Type (3) External engine / hook** — helper updates DOM or dataset (e.g., BGTimeEngine update from payload).

### 1.2 Timer UI Writer Table

| WriterName | File:Line | Type | Trigger | WritesWhichElement | UsesWhichData |
|---|---:|---:|---|---|---|
| `WorkModalController._renderTimerDisplay()` | `WorkModalController.js:164-173` | (2) | Called by `_syncTimer()` and initial sync | `#workModalTimer`, also `#modalTimer, .modal-timer` | `currentToken.timer.work_seconds` + tail (via `_getTimerSnapshot()`) |
| `WorkModalController._syncTimer()` | `WorkModalController.js:930-960` | (1) | Modal open / rehydrate | Writes via `_renderTimerDisplay()` | Snapshot derived from `token.timer.work_seconds`, `token.timer.last_server_sync`, `token.session_status` |
| WorkModal “static timer text” in `_populateModal()` | `WorkModalController.js:812-817` | (2) | Populate modal after fetch | `#workModalTimer` | `token.timer.work_seconds` |
| `populateWorkModal()` (legacy modal path) | `work_queue.js:2629-2667` | (2) + (3) | `openWorkModal()` show modal | `#workModalTimer` text + dataset + register BGTimeEngine | `token.timer.work_seconds`, `token.timer.last_server_sync`, `token.timer.status` |
| Pause handler updates timer from API response | `work_queue.js:2340...` (see pause flow) | (3) | Click `#btnWorkPause` | `#workModalTimer` (dataset + display via BGTimeEngine) | Uses `resp.timer` -> `BGTimeEngine.updateTimerFromPayload()` |
| Resume handler sets status + last sync and registers engine | `work_queue.js:2403...` (see resume flow; line-visible sample earlier) | (3) | Click `#btnWorkResume` | `#workModalTimer` dataset + register | Uses **client time** `new Date().toISOString()` for `data-last-server-sync`, does **not** apply `resp.timer.work_seconds` |
| `BGTimeEngine.ensureTicking()` + `setInterval(tickAll, 1000)` | `work_queue_timer.js:110-118` | (1) | First registration | Updates all tracked timers | Dataset contract: `data-work-seconds-sync`, `data-last-server-sync`, `data-status` |
| `BGTimeEngine.updateSpanTimer()` | `work_queue_timer.js:179-226` | (1) | Tick loop | `.timer-display` or element text | `displaySeconds = syncSeconds + diffSeconds` when active |
| `TokenCardParts.renderTimer()` initial HTML | `TokenCardParts.js:223-274` | (2) | Card render | `.timer-display` initial value | `time.workSeconds` (`data-work-seconds-sync`, `data-last-server-sync`) |
| CUT behavior ticker | `behavior_execution.js:1708-1747` | (1) | CUT UI running | `#cut-phase2-timer` | CUT session state (`startedAt`, `pausedTotalSeconds`) |

---

## 2) Timer SSOT Determination

### 2.1 Backend SSOT (Work Session Timer DTO)

**Single Source of Truth (backend):** `WorkSessionTimeEngine::calculateTimer()`

- File: `source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php`
- Evidence:
  - Declared as SSOT and outputs Timer DTO (`work_seconds`, `last_server_sync`, `status`) (`31-52`, `69-132`).

### 2.2 Frontend SSOT contract (BGTimeEngine)

BGTimeEngine is a **projection/ticker** that expects a server snapshot:

- File: `assets/javascripts/pwa_scan/work_queue_timer.js`
- Required dataset attributes (contract):
  - `data-work-seconds-sync`
  - `data-last-server-sync`
  - `data-status`
  - (and `data-token-id` for duplicate prevention)
- Calculation:
  - `displaySeconds = syncSeconds + floor((nowMs - lastSyncMs)/1000)` if `status === 'active'` (`187-205`).

### 2.3 SSOT chain by API surface

- **`get_work_queue` → token cards**
  - `TokenCardParts.renderTimer()` emits initial timer + dataset (`TokenCardParts.js:248-263`).
  - BGTimeEngine ticks from dataset.

- **`get_token_detail` → WorkModalController path**
  - Modal controller uses `token.timer.*` as base and ticks internally (`WorkModalController.js:930-960`).

- **`pause_token` response**
  - Backend returns `timer` DTO:
    - `dag_token_api.php:3833-3845`
  - Legacy modal handler applies it via `BGTimeEngine.updateTimerFromPayload` (pause flow in `work_queue.js`).

- **`resume_token` response**
  - Backend returns `timer` DTO and also refreshes session/token (`dag_token_api.php:3942-3973`).
  - Legacy resume handler **does not apply `resp.timer.work_seconds`** to dataset; it sets `data-last-server-sync` from client time and registers engine.

---

## 3) Root Cause — `00:00:00` Flash (evidence-based)

### Timeline (Work Modal legacy path)

- **T0**: Modal timer HTML starts as `00:00:00`
  - `views/work_queue.php:579-581`

- **T1**: `populateWorkModal(token)` writes timer.
  - If `token.timer` exists:
    - sets dataset and writes initial display (`work_queue.js:2642-2663`).
  - Else:
    - forces `00:00:00` (`work_queue.js:2665-2667`).

- **T2**: On Resume click (`#btnWorkResume`)
  - UI updates lock state immediately (`work_queue.js` modal handlers region).
  - **Resume handler updates dataset incompletely**:
    - sets `data-status = 'active'`
    - sets `data-last-server-sync = new Date().toISOString()` (client time)
    - registers BGTimeEngine
    - **but does not set `data-work-seconds-sync` from `resp.timer.work_seconds`**

- **T3**: BGTimeEngine tick uses `data-work-seconds-sync || 0`
  - `work_queue_timer.js:187-200`
  - If dataset is missing/0 at that moment, UI can flash at 0.

### Conclusion
The flash is explainable by a **snapshot gap**: resume flow can re-enable ticking while the modal element has **no correct `work_seconds` snapshot** applied.

---

## 4) Root Cause — `-60s` Drift (what is proven vs what needs runtime proof)

### What is proven from code

- **Double-writer risk exists** for `#workModalTimer`:
  - BGTimeEngine can write it (registered in `populateWorkModal`: `work_queue.js:2661-2663`).
  - WorkModalController also writes it directly via its own interval (`WorkModalController.js:930-960`).

This creates non-deterministic behavior:

- Two independent tickers can overwrite each other.
- They may use different bases/anchors (dataset vs controller snapshot) at different times.

### What is NOT proven from code alone

A literal “subtract 60 seconds” for `#workModalTimer` is not directly visible in the work queue timer engine. BGTimeEngine adds `diffSeconds` to the snapshot.

However, CUT timer logic does subtract pauses (minutes × 60 and running pause increments) for `#cut-phase2-timer` (`behavior_execution.js:1114-1115`, `1719-1730`). That is a different element, but it is evidence that other timers on the same page may have different time math.

### Conclusion
`-60s` drift for `#workModalTimer` is most plausibly explained by **writer race / SSOT mismatch** (two tickers + inconsistent snapshot updates), but **requires runtime instrumentation** to confirm which writer overwrote what and when.

---

## 5) F5 Auto-open + Lock Audit

### 5.1 Auto-open entry point after `get_work_queue`

After `get_work_queue` success:

- File: `assets/javascripts/pwa_scan/work_queue.js`
- Logic:
  - `work_queue.js:502-512`:
    - If `window.autoOpenActiveToken` exists → call it with flattened tokens.
    - Else → fallback to local `autoOpenModalForActiveToken(flatTokens)`.
    - Then sets `window.__HAS_AUTO_OPENED_ACTIVE_TOKEN__ = true`.

### 5.2 Auto-open failure modes proven by code

- **Mode A: Controller not ready (no retry), but flag is set**
  - If `autoOpenActiveToken()` returns early (e.g., controller not ready), `work_queue.js` still sets `__HAS_AUTO_OPENED_ACTIVE_TOKEN__ = true` (`511`).
  - This prevents further attempts on the same page load.

- **Mode B: userId mismatch / resolution differences**
  - `autoOpenModalForActiveToken()` uses:
    - `Number(window.APP_USER_ID || window.currentUserId || currentOperatorId || 0)` (`work_queue.js:2532-2535`).
  - WorkModalController internal lock logic uses:
    - `_getCurrentUserId()` with multiple globals (`WorkModalController.js:55-60`).
  - If any path uses a narrower set of globals, it can fail to match operator → no auto-open.

### 5.3 `__ACTIVE_TOKEN_LOCK__` mechanism (set/clear + influence)

#### Set points
- From `get_work_queue` response compute:
  - `work_queue.js:450-457` (computed lock from tokens)
- From modal start:
  - `work_queue.js:2314-2318`
- From WorkModalController state:
  - `WorkModalController._setActiveTokenLockFromState()` (`79-93`)

#### Clear points
- On complete:
  - `work_queue.js:2465-2470`
- WorkModalController explicit clear:
  - `_clearActiveTokenLock()` (`WorkModalController.js:104-112`)

#### Close blocking
- Bootstrap modal attributes prevent close via backdrop/ESC:
  - `views/work_queue.php:551-552`
- WorkModalController close handler blocks close if active or lock fallback says active:
  - `WorkModalController.js:204-216`

---

## 6) Runtime Instrumentation (No code changes)

> Paste into browser console to capture evidence of writers, dataset snapshots, and interval duplication.

### 6.1 Hook DOM writes to `#workModalTimer` (jQuery `.text()`)

```js
(() => {
  const $ = window.jQuery;
  if (!$) return console.warn('no jQuery');

  const orig = $.fn.text;
  $.fn.text = function (...args) {
    try {
      if (this[0] && this[0].id === 'workModalTimer' && args.length) {
        console.log('[TIMER_WRITE][jQuery.text]', args[0]);
        console.log(new Error().stack);
      }
    } catch (e) {}
    return orig.apply(this, args);
  };
})();
```

### 6.2 MutationObserver for timer text/dataset changes

```js
(() => {
  const el = document.getElementById('workModalTimer');
  if (!el) return console.warn('no #workModalTimer');
  const obs = new MutationObserver(() => {
    console.log('[TIMER_MUTATION]', el.textContent, el.dataset);
  });
  obs.observe(el, { childList: true, characterData: true, subtree: true });
  window.__TIMER_OBS__ = obs;
})();
```

### 6.3 Hook BGTimeEngine calls

```js
(() => {
  const eng = window.BGTimeEngine;
  if (!eng) return console.warn('no BGTimeEngine');

  ['registerTimerElement','unregisterTimerElement','updateTimerFromPayload'].forEach((k) => {
    if (typeof eng[k] !== 'function') return;
    const orig = eng[k];
    eng[k] = function (...args) {
      console.log('[BGTimeEngine.' + k + ']', args);
      console.log(new Error().stack);
      return orig.apply(this, args);
    };
  });
})();
```

### 6.4 Hook `setInterval/clearInterval` to detect duplicates

```js
(() => {
  const origSet = window.setInterval;
  const origClr = window.clearInterval;
  const map = new Map();

  window.setInterval = function (fn, ms, ...rest) {
    const id = origSet(fn, ms, ...rest);
    map.set(id, { ms, stack: new Error().stack });
    console.log('[setInterval]', id, ms, map.get(id).stack);
    return id;
  };

  window.clearInterval = function (id) {
    if (map.has(id)) console.log('[clearInterval]', id, map.get(id));
    map.delete(id);
    return origClr(id);
  };

  window.__INTERVAL_MAP__ = map;
})();
```

### 6.5 Snapshot helper

```js
window.__dumpTimer = () => {
  const el = document.getElementById('workModalTimer');
  const wmc = window.workModalController;

  console.table({
    ui_text: el?.textContent,
    data_status: el?.dataset?.status,
    data_workSecondsSync: el?.dataset?.workSecondsSync,
    data_lastServerSync: el?.dataset?.lastServerSync,
    lock: JSON.stringify(window.__ACTIVE_TOKEN_LOCK__ || {}),
    token_session_status: wmc?.currentToken?.session_status,
    token_timer_work_seconds: wmc?.currentToken?.timer?.work_seconds,
    token_timer_last_server_sync: wmc?.currentToken?.timer?.last_server_sync
  });
};
```

---

## 7) Minimal Fix Plans (2 Options)

### Option A — BGTimeEngine is the only ticker for `#workModalTimer`

**Idea:** The modal timer should follow the same dataset contract as token cards. WorkModalController should not directly tick `#workModalTimer`.

- Pros:
  - One unified frontend timer system.
  - Uses documented dataset contract.
- Cons:
  - Requires ensuring modal always has correct dataset snapshot.

**Minimum change direction:**

- On resume, apply `resp.timer` via `BGTimeEngine.updateTimerFromPayload(#workModalTimer, resp.timer)` instead of only setting `last_server_sync` to client time.
- Avoid/disable the modal-owned `setInterval` writer for `#workModalTimer`.

### Option B — WorkModalController is the only ticker for `#workModalTimer`

**Idea:** Cards continue to use BGTimeEngine, but modal timer is controller-owned; modal element should not be registered with BGTimeEngine.

- Pros:
  - Modal’s behavior is fully deterministic within controller.
  - Easy to ensure close/rehydrate clears interval.
- Cons:
  - Two different timer engines on same page (cards vs modal).
  - Must avoid accidental BGTimeEngine registration of modal element.

---

## 8) Patch Instructions Summary (high-level)

> This section is intentionally high-level; choose Option A or B before patching.

### 8.1 Resume flow snapshot correctness

- File: `assets/javascripts/pwa_scan/work_queue.js`
- Target: `#btnWorkResume` handler

**Requirement:** Ensure `data-work-seconds-sync` and `data-last-server-sync` reflect **server snapshot** (`resp.timer`) on resume.

### 8.2 Auto-open reliability

- File: `assets/javascripts/pwa_scan/work_queue.js`

**Requirement:**

- Only set `window.__HAS_AUTO_OPENED_ACTIVE_TOKEN__ = true` if open attempt actually started.
- If controller not ready, retry rather than permanently marking as “already tried”.

### 8.3 Lock correctness

- Ensure all lock setters/clearers use a canonical user id resolution (same global sources).
- Avoid lock being cleared late (should be immediate on pause/complete, consistent with UI).

---

## Appendix A — Hard Evidence Snippets (Selected)

### A1) Modal timer initial HTML is `00:00:00`

- `views/work_queue.php:579-581`

### A2) `populateWorkModal` writes dataset and registers BGTimeEngine

- `work_queue.js:2642-2663`

### A3) BGTimeEngine calculation uses dataset snapshot + diff

- `work_queue_timer.js:187-205`

### A4) WorkModalController interval ticker writes timer directly

- `WorkModalController.js:930-960`

### A5) CUT timer subtracts pauses

- `behavior_execution.js:1719-1730`

---

## Status
This `.md` captures the audit deliverables requested:

- SSOT Map
- Double Writer Map
- Root cause conclusions (evidence-based)
- Runtime instrumentation plan
- Minimal fix plan with 2 options
- Patch instructions summary

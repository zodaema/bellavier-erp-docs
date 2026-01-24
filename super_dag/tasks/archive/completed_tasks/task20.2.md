

# Task 20.2 — Official Timezone Normalization Layer  
(BGERP Time Engine Phase 2)

## Objective
Establish a single, canonical, system-wide timezone normalization layer for all SuperDAG / ETA / SLA / Token operations. Replace scattered timezone handling with a unified mechanism ensuring consistency, determinism, and future-proofing for multi-region deployments.

---


## What This Task Will Deliver

### 0. Time Usage Analysis (Pre-step)
Before implementing the new TimeHelper and timezone layer, perform a quick audit of existing time handling so that future refactors can converge on the same helper.

**Scope:**
- PHP: search across all `*_api.php`, `Service/` classes, and `BGERP/Dag/` modules for:
  - `date_default_timezone_set` / `ini_set('date.timezone', ...)`
  - direct `new DateTime(...)` / `new DateTimeImmutable(...)`
  - bare `time()`, `date(...)`, `strtotime(...)`
  - any custom helper that returns `DateTime` / timestamps
- JS: search in `assets/javascripts/` for:
  - direct `new Date()`
  - `Date.parse(...)`
  - manual `(new Date()).toISOString()`

**Deliverable:**
- Create `docs/super_dag/time/time_usage_audit.md` summarizing:
  - File path
  - Function / method
  - Current timezone/source (implicit/explicit)
  - Notes (e.g. "candidate for TimeHelper", "leave as-is for now")

**Usage:**
- Use this audit as a map for:
  - Which APIs should be migrated to `TimeHelper` immediately in Task 20.2 (SuperDAG / ETA / SLA scope)
  - Which modules will be refactored in later Time Engine phases (e.g. 20.x / 21.x) so that all APIs eventually share the same helper and canonical timezone behavior.

### 1. PHP Layer (Backend)
Create a new core utility:

**File:** `source/BGERP/Helper/TimeHelper.php`  
**Provides:**
- `now()` — returns DateTimeImmutable in canonical timezone
- `parse($string)` — parse any time in any format → canonical timezone
- `utc()` — convert to UTC
- `local()` — convert to system-local
- `normalize($dt)` — force timezone normalization
- `isValid($dt)` — safe validator

### 2. Canonical Timezone Definition
Add global constant:

```
define('BGERP_TIMEZONE', 'Asia/Bangkok');
```

### 3. Integration Points (must adopt new TimeHelper)
- DAGRoutingService (token timestamp read/write)
- EtaEngine (ETA computation)
- SLA evaluation modules
- Future WIP/Cycle-Time engine
- API responses (normalize before return)
- DB writes (timestamps normalized)

### 4. API Guarantee
All timestamps returned from:
- `/dag_routing_api.php?action=token_eta`
- `/dag_routing_api.php?action=...`
- SuperDAG validation API

Must return timestamps in **canonical timezone only**.

### 5. JS Runtime Layer
Create a thin client-side normalization helper:

**File:** `assets/javascripts/dag/modules/GraphTimezone.js`

Functions:
- `normalize(ts)` → returns canonical ISO string
- `toLocal(ts)`
- `fromLocal(ts)`
- `isValid(ts)`

### 6. Replace Old / Ad-hoc Timehandling
Remove all:
- `new Date()` usage without timezone normalization
- `Date.parse(...)` from graph_designer.js
- Manual `(new Date()).toISOString()` formatting
- Bare `strtotime(...)` in PHP

### 7. Apply to ETA Preview Panel
Every timestamp shown in the Graph Designer ETA panel must use:
```
GraphTimezone.normalize(...)
```

### 8. Safety Guards
- Throw warning if any module attempts to create a timestamp without timezone
- Add runtime assertion inside TimeHelper::parse()

---

## Acceptance Criteria
- All timestamps in backend normalized with TimeHelper
- All timestamps in frontend normalized with GraphTimezone.js
- `token_eta` API returning canonical timezone timestamps
- No usage of bare `Date()` or `strtotime()` across DAG modules
- All tests continue to pass (45/45)
- No regressions in routing, validation, or ETA engine

---

## Notes
This task does NOT include:
- SLA panel UI (that is Task 20.3)
- Frontend date formatting preferences
- Multi-timezone support (future phase)

---

Task 20.2 is now ready for execution in Cursor AI Agent.
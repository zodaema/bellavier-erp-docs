

# Task 23.6 — MO Update Integration & ETA Cache Consistency

> Phase 23 — Close the MO layer loop before going to Phase 24 (Job Ticket Sync).
>
> Objective: Whenever an MO is **updated** (qty/routing/product/version/etc.),
> the ETA/Simulation/Health stack must react correctly and remain consistent —
> without blocking core MO operations.

---

## 1. Context

By Task 23.5 we already have:

- `MOCreateAssistService` providing preview + ETA hints.
- `MOLoadSimulationService` and `MOLoadEtaService` as the ETA/Simulation engine.
- `MOEtaCacheService` for caching ETA results per MO (with signature + TTL).
- `MOEtaHealthService` for logging ETA-related health signals.
- `mo.php` already wired for **create/plan/cancel/complete** events.
- `TokenLifecycleService` calling `MOEtaHealthService::onTokenCompleted()`.

**But currently:**

- MO **updates** (edit qty, change routing, change product, etc.) are not fully
  integrated with the ETA cache and health engine.
- It is possible for ETA cache to become **stale** or **misleading** after
  important MO field changes.

Task 23.6 closes this gap by binding MO update operations to the ETA/Health
stack in a consistent and non-destructive way.

---

## 2. Goals

1. **ETA cache stays consistent** when MO is updated.
2. **Relevant changes** (qty, routing, product, dates) automatically trigger
   cache invalidation + recompute.
3. **Health service** is aware of MO updates (for future monitoring).
4. **Non-blocking:** any ETA/Health failure must **not** block the MO update.
5. Maintain **backward compatibility** with existing ETA cache rows and
   existing MO flows.

---

## 3. Non-Goals

- No changes to Job Ticket logic (Phase 24 responsibility).
- No UI changes in this task (frontend integration later).
- No new feature flags.
- No advanced analytics or AI logic.

---

## 4. Affected Components

### 4.1 `source/mo.php`

- `handleUpdate()` (and any other update-related handlers if present).
- Possibly shared helpers for loading old/new MO data.

### 4.2 `source/BGERP/MO/MOEtaCacheService.php`

- Signature logic and cache invalidation.
- Public API to recompute ETA given MO data or MO ID.

### 4.3 `source/BGERP/MO/MOEtaHealthService.php`

- New logging entry point for MO updates.
- Potential helpers for classifying update impact.

### 4.4 (Optional) `source/BGERP/MO/MOLoadEtaService.php`

- Reuse existing `computeETAFromMoData()` for recalculation.
- Ensure no duplicated logic.

---

## 5. Functional Requirements

### 5.1 MO Update Detection

When an MO is updated via `mo.php` (e.g. `handleUpdate()`):

- Load **previous** MO state (before update).
- Load **new** MO state (after applying request payload).
- Detect if any **ETA-sensitive fields** changed:

  - `product_id` (or equivalent product reference)
  - `qty` (or `quantity` / `quantity_planned`)
  - `routing_id` / `graph_template_id` / binding reference
  - `routing_version` / `routing_hash` (if present)
  - any `planned_start_at` / `planned_due_at` fields, if available

- If **no relevant changes**, do **nothing** (no cache invalidation).
- If **any relevant field changed**:

  1. Invalidate existing ETA cache entry (if any) for that MO.
  2. Trigger recompute (best-effort, non-blocking).
  3. Notify `MOEtaHealthService` that an MO update occurred.

### 5.2 ETA Cache Signature

`MOEtaCacheService` MUST ensure that the cache **signature** already reflects
(or is updated to reflect) the fields from 5.1, including at least:

- `mo_id`
- `product_id`
- `qty`
- `routing_id`
- `routing_version` and/or `routing_hash` (if available)
- `engine_version` (ETA engine version string/number)

If signature logic is already present but missing any of the above, it must be
extended **in a backward-compatible way**:

- Old rows must still be readable without fatal errors.
- If a cached row does not contain the new fields, treat it as **stale** and
  recompute.

### 5.3 Recompute Behavior

When recompute is triggered after an MO update:

- Use existing methods (e.g. `computeEtaAndAudit()` / `computeETAFromMoData()`)
  to recompute ETA.
- If recompute succeeds:

  - Store new ETA + signature in cache.
  - Optionally log a **"mo_eta_updated"** event to `MOEtaHealthService`.

- If recompute fails (exception, DB error, etc.):

  - Log warning using existing logging helper.
  - Do **not** prevent the MO from being updated.
  - Leave cache empty or mark as invalid — but **never** return stale data as
    if it were fresh.

### 5.4 Health Logging

`MOEtaHealthService` must expose a method such as:

```php
public function onMoUpdated(int $moId, array $diff): void;
```

or equivalent, where:

- `$diff` summarizes which ETA-sensitive fields changed.
- Implementation can be minimal for now (e.g. log_to_file / log_to_db with a
  generic `MO_UPDATED` type, plus changed fields in JSON).

The purpose is to make MO update events **visible** in future health/monitoring
and timeline investigations.

### 5.5 Non-Blocking Guarantee

Under **no circumstance** may ETA/Health errors block MO updates.

- All calls to `MOEtaCacheService` and `MOEtaHealthService` from `mo.php`
  should be wrapped in `try/catch`.
- Errors should be logged but **not thrown back** to the caller.
- If this is already partially implemented, extend it to cover the new
  update-related calls as well.

---

## 6. Implementation Outline

### 6.1 `mo.php`

1. Locate `handleUpdate()` (or equivalent update handler).
2. Before persisting the update:

   - Load existing MO row → `$oldMo`.

3. After successful update:

   - Load new MO row → `$newMo`.
   - Compute a diff of fields listed in 5.1.
   - If diff is empty → return as usual.
   - If diff is non-empty:

     - Call `MOEtaCacheService::invalidateForMo($moId)`.
     - Call a recompute helper, e.g. `MOEtaCacheService::getOrCompute($moId)`
       or a dedicated method for **forced recompute**.
     - Call `MOEtaHealthService::onMoUpdated($moId, $diff)`.

4. All ETA/Health calls **must be** inside `try/catch`.

### 6.2 `MOEtaCacheService.php`

1. Ensure we have clear public API methods:

   - `invalidateForMo(int $moId): void`
   - `getOrCompute(int $moId): array` (or similar)
   - Possibly `recomputeForMo(int $moId): array` if needed.

2. Update `buildSignature()` to include all ETA-sensitive fields.

3. When loading from cache, if the signature does **not match** current MO
   data, treat cache as stale and recompute.

4. If recompute fails, return a safe default (e.g. empty array) and let the
   caller decide how to proceed.

### 6.3 `MOEtaHealthService.php`

1. Add a public method for MO update logging:

   ```php
   public function onMoUpdated(int $moId, array $diff): void
   {
       // Minimal implementation: log to DB or file.
   }
   ```

2. Reuse existing logging helpers / DB schema if available; if not, make the
   implementation minimal and non-intrusive.

3. Ensure that any exceptions thrown here are caught at the caller side
   (`mo.php`).

---

## 7. Testing & Validation

### 7.1 Manual Test Scenarios

1. **Qty Change Only**
   - Create MO with qty = 10.
   - Confirm ETA cache created.
   - Update MO: qty = 20.
   - Verify:
     - Cache entry is invalidated and recomputed.
     - `MOEtaHealthService::onMoUpdated()` is called (via logs).

2. **Routing Change**
   - Create MO with routing A.
   - Update MO to routing B.
   - Verify signature change and cache recompute.

3. **No ETA-sensitive Changes**
   - Update MO description or non-ETA field.
   - Verify that cache is **not** invalidated/recomputed.

4. **Recompute Failure**
   - Simulate an error inside ETA computation (e.g. temporarily break DB or
     force an exception in `MOLoadEtaService`).
   - Update MO with ETA-sensitive change.
   - Verify MO update still succeeds; errors only appear in logs.

### 7.2 Code-Level Checks

- `mo.php` remains readable and consistent with existing style.
- No circular dependencies introduced (MO → ETA, ETA → MO, etc.).
- No new global state.

---

## 8. Deliverables

1. Updated `mo.php` with MO update → ETA/Health integration.
2. Updated `MOEtaCacheService.php` with enhanced signature and invalidation.
3. Updated `MOEtaHealthService.php` with `onMoUpdated()` logic.
4. (Optional) Minor refactor in `MOLoadEtaService.php` to reuse computation
   logic.
5. `docs/super_dag/tasks/results/task23_6_results.md` summarizing:

   - Changes per file.
   - Example diff of MO update → cache behavior.
   - Known limitations.

---

## 9. Developer Prompt (for AI Agent)

Use the following prompt when implementing this task in Cursor:

```text
You are working on Task 23.6 — MO Update Integration & ETA Cache Consistency.

Goal:
- When MO is updated (qty/product/routing/version/etc.), ETA cache and
  MOEtaHealthService must react correctly, without blocking the MO update.

Constraints:
- Do NOT change Job Ticket logic.
- Do NOT add new feature flags.
- Do NOT introduce breaking changes to existing APIs.
- All ETA/Health operations must be best-effort and non-blocking.

Steps:
1) Open `source/mo.php` and implement update → ETA/Health integration in
   `handleUpdate()` (or equivalent):
   - Load old MO.
   - Perform update.
   - Load new MO.
   - Detect ETA-sensitive field changes.
   - If changed → invalidate ETA cache, recompute, and call
     `MOEtaHealthService::onMoUpdated()`.
   - Wrap all calls in try/catch.

2) Open `source/BGERP/MO/MOEtaCacheService.php`:
   - Ensure `buildSignature()` covers: mo_id, product_id, qty, routing_id,
     routing_version/hash, engine_version.
   - If signature mismatch → treat cache as stale and recompute.
   - Add or confirm `invalidateForMo()` and `getOrCompute()` (or equivalent).

3) Open `source/BGERP/MO/MOEtaHealthService.php`:
   - Add `onMoUpdated(int $moId, array $diff): void`.
   - Implementation can be minimal: log a generic `MO_UPDATED` event with
     changed fields.
   - Ensure it is safe to call from `mo.php` (exceptions handled at caller).

4) Run PHP syntax check (e.g. `php -l`) on modified files.
5) Execute basic manual tests described in Section 7.1.
6) Create `docs/super_dag/tasks/results/task23_6_results.md` summarizing the
   work.

Preserve existing coding style and logging conventions throughout.
```
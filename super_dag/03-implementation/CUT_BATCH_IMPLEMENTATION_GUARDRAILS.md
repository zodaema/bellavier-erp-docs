# CUT Batch Implementation Guardrails

**Status:** Implementation Guardrails (Level 2)  
**Date:** 2026-01-18  
**Category:** SuperDAG / Implementation / CUT Batch

**Scope:** Prevent regressions and mis-implementations of CUT batch grouping + batch sessions.

**Derives from:**
- `docs/super_dag/01-canonical/HATTHASILPA_CANONICAL_PRODUCTION_SPEC.md` (Level 0)
- `docs/super_dag/02-specs/CUT_BATCH_EXECUTION_MODEL.md` (Level 1)

**Important:** This document does **not** redefine Canonical or Spec logic. It only constrains implementation choices.

---

## 1) DO Rules (Required Implementation Behaviors)

1. **DO resolve CUT UI by `group_key`** (one group card, one batch session).
2. **DO require a real `session_id`** to consider a batch session active/paused/completed.
3. **DO open CUT modal in pre-start state** when no batch session exists for the group.
4. **DO enforce single active batch session per `group_key`** (reject or supersede duplicates deterministically).
5. **DO map UI status from batch session** (not from per-token session projections).
6. **DO treat queue output as projection** (display only; never a permission gate).
7. **DO keep per-token sessions read-only** if present (legacy projection only).
8. **DO keep timer ownership singular** (one authoritative batch timer per `group_key`).

---

## 2) DO NOT Rules (Explicit Forbidden Patterns)

1. **DO NOT infer session state** from empty objects, legacy token sessions, or non-null flags without a valid `session_id`.
2. **DO NOT render per-token CUT cards** for grouped tokens under the same `group_key`.
3. **DO NOT treat queue as permission** to start or block work.
4. **DO NOT allow multiple active/paused batch sessions** for the same `group_key`.
5. **DO NOT reintroduce per-token timers** or per-token session writers as authoritative.
6. **DO NOT create session state from client time** when server session is absent.

---

## 3) Common Failure Modes (Root Causes to Guard Against)

### 3.1 Inferring Session State Without `session_id`
- **Symptom:** UI shows “paused/active” even when session does not exist.
- **Guardrail:** If `session_id` is missing, treat as **no session** → pre-start.

### 3.2 Per-token CUT Cards
- **Symptom:** Multiple cards for same batch appear in Work Queue.
- **Guardrail:** Always aggregate tokens by `group_key` for CUT.

### 3.3 Queue-as-Permission
- **Symptom:** UI blocks work because queue says “not ready”.
- **Guardrail:** Queue is projection only; must not gate work.

### 3.4 Multiple Batch Sessions per `group_key`
- **Symptom:** Conflicting timers, duplicated state, ambiguous controls.
- **Guardrail:** Enforce single authoritative session; others become superseded/legacy.

### 3.5 Per-token Timers / Writers Return
- **Symptom:** Timer drift or multiple writers for same CUT batch.
- **Guardrail:** Only one authoritative batch timer is allowed.

---

## 4) Invalid Implementations (Examples)

### Example A — Inferring state without session_id
**Invalid:**
```pseudo
if (cut_session) status = 'paused' // cut_session is empty object
```
**Why invalid:** session state must require a real `session_id`.

### Example B — Rendering per-token CUT cards
**Invalid:**
```pseudo
for token in cut_tokens:
  renderCutCard(token)
```
**Why invalid:** CUT cards must be grouped by `group_key`.

### Example C — Multiple active sessions per group
**Invalid:**
```pseudo
createSession(group_key) // no check for existing active/paused session
```
**Why invalid:** only one active batch session per `group_key`.

### Example D — Per-token timer writers
**Invalid:**
```pseudo
startTokenTimer(token_id) // each token writes time
```
**Why invalid:** authoritative timer is batch-level only.

### Example E — Queue as permission gate
**Invalid:**
```pseudo
if (!queueReady) blockStart()
```
**Why invalid:** queue is projection, not authorization.

---

## 5) Validation Checklist (Before Merge)
- [ ] CUT modal shows **pre-start** when session is missing.
- [ ] Only **one CUT card** per `group_key`.
- [ ] Only **one active session** per `group_key`.
- [ ] No per-token timer writers or state sources.
- [ ] Queue output does not block or grant permission.

---

## 6) Non-Goals
- Redefining Canonical ontology.
- Changing CUT batch grouping rules.
- Introducing new timer engines.
- Rewriting session lifecycle spec.

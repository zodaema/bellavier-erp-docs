---
# WQ2 Reference — Strict Authoritative Auto-Restore (Frozen Contract)

Status: **Reference implementation**

This document describes the **WQ2 (Strict)** Work Queue auto-restore behavior as a **frozen reference**.
It is intended to be reused by all behaviors (CUT + non-CUT) without modifying SSOT rules.

## Scope and invariants

- WQ2 auto-restore uses **authoritative sources only**.
- Projection-based auto-open is **forbidden**.
- Fail-open is required: UI must not permanently block work when authoritative fetch fails.
- Session vocabularies are **not normalized/merged**.
- Client must not store “truth” (no localStorage SSOT).

## Why projection auto-open is forbidden

`get_work_queue` includes a **projection** of session state (`session_status`, `operator_user_id`, `time_summary`, etc.).
This projection exists for display and convenience; it is not authoritative and can be stale.

Auto-opening the modal based on projection can:

- Open the wrong token after refresh.
- Violate Frozen SSOT Law by using non-authoritative state to decide the operator’s current active work.
- Create cross-behavior coupling (behavior-specific timing/status semantics leaking into platform behavior).

Therefore, WQ2 restore decisions must be made from the authoritative endpoint only.

## Why operatorId is not required client-side

The authoritative endpoint derives the operator identity from the server session (`thisLogin`).

- The frontend may have `APP_USER_ID` unset or delayed.
- Relying on a client-side operator id can cause restore to fail even when the user is authenticated.

WQ2 may log missing operator id for diagnostics, but it must not block the authoritative fetch on that basis.

## Fail-open philosophy

When authoritative fetch fails (network/auth/HTML/non-JSON):

- Clear authoritative lock sources (do not “stick” to an old lock).
- Do not enforce exclusivity based on non-authoritative state.
- Provide minimal user messaging (warn once).

Fail-open ensures operators can continue work even if the restore path is temporarily unavailable.

## Frozen contract: authoritative session shape

WQ2 restore logic relies only on the following stable fields for the authoritative “winner” session:

```json
{
  "session_type": "cut_session" | "token_work_session",
  "session_status_raw": "RUNNING" | "PAUSED" | "active" | "paused",
  "token_id": 123,
  "node_id": 456,
  "behavior_code": "CUT" | "EDGE" | "STITCH" | "QC" | "PACK" | null
}
```

### Notes

- `session_type` and `session_status_raw` are preserved verbatim from the underlying authority:
  - CUT authority: `cut_session.status` in (`RUNNING`, `PAUSED`)
  - non-CUT authority: `token_work_session.status` in (`active`, `paused`)
- No normalization to `active|paused|none` is performed at this layer.
- WQ2 tolerates `token_id` being provided as either `token_id` or `id_token` (alias tolerance).

## Restore behavior (strict)

### 1) If winner is ACTIVE

- Winner is:
  - CUT: `session_status_raw === 'RUNNING'`
  - non-CUT: `session_status_raw === 'active'`
- WQ2 auto-opens the modal for `token_id`.
- If the winner token is not present in the rendered list, WQ2 opens modal via token detail fetch.

### 2) If winner is PAUSED (NO AUTO-OPEN)

- Winner is:
  - CUT: `session_status_raw === 'PAUSED'`
  - non-CUT: `session_status_raw === 'paused'`
- WQ2 must **not** auto-open.
- WQ2 must **not** show an error.
- WQ2 shows one inline hint:
  - “You have paused work. Resume from the list.”

### 3) If no winner

- Do nothing (no modal auto-open).

## Reuse guidance for EDGE / STITCH / QC / PACK / future behaviors

- Behaviors must not implement their own platform-level restore logic.
- Implement behavior-specific UI inside the modal, but keep WQ2 restore rules identical.
- If a behavior needs additional detail to render, fetch it after modal opens via behavior-specific endpoints.
- Do not change the authoritative decision source:
  - winner selection remains derived from `get_operator_authoritative_sessions`.

## Diagnostics (expected in development)

WQ2 produces restore diagnostics keys such as:

- `A_FETCH_FAILED` (with http status, content-type, response prefix)
- `B_NO_ACTIVE_SESSION`
- `B_PAUSED_SESSION`
- `C_MODAL_OPEN_FAILED`
- `D_WINNER_TOKEN_NOT_IN_LIST`

These diagnostics are for debugging and must not change SSOT.

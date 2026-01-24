# Future AI Context — Architecture Guardrails (Core vs Node Behaviors)

This document exists to prevent architectural drift when working on features, behaviors, and integrations.

## 1) Mental model (neutral, system-wide)

### 1.1 Core = "OS" (the bloodstream)
The following elements are the system "OS" and must be treated as the baseline platform:

- DAG routing + token lifecycle (e.g., `flow_token`, routing invariants)
- Work Queue / Modal baseline UX contract
- Legacy execution/session model used by most nodes (e.g., `token_work_session` and its derived timer behavior)
- Assignment + permission policy as the platform contract
- Monitoring/manager dashboards as platform consumers of canonical status fields

Core changes are high-risk because they can break unrelated nodes and pages.

### 1.2 Node Behavior = "Application" (plug-in running on the OS)
A Node Behavior is an application that runs *inside* the core platform UX:

- It renders a UI inside the modal/queue panel
- It may call behavior-specific endpoints/services
- It must not redefine global platform rules unless explicitly instructed

Behaviors can evolve independently, but they must integrate via explicit adapter/projection layers.

### 1.3 Change classification (how to reason about risk)
Treat changes differently based on blast radius:

- **Tier 0 — Behavior-local:** changes confined to a single behavior’s UI + endpoints + ledger.
- **Tier 1 — Adapter/Projection:** changes that map behavior state into canonical core contracts (safe when additive + backwards-compatible).
- **Tier 2 — Core contract:** changes to canonical fields consumed by multiple pages (queue/modal/monitoring). Requires explicit decision + migration plan.
- **Tier 3 — Core kernel:** routing/session/permission semantics. Highest risk; only change with explicit approval and a rollback plan.

Default stance: **prefer Tier 0–1**. Avoid Tier 2–3 unless explicitly instructed.

## 2) Single Source of Truth (SSOT) rules

### 2.1 SSOT is scoped
SSOT must be scoped to the domain that owns it:

- Core SSOT (platform-wide): routing + canonical token state + platform policy
- Behavior SSOT (behavior-scoped): behavior-specific ledger/state *only for that behavior*

A behavior may have its own ledger/table/service for its internal timing/events.
That does not make the behavior the SSOT for the whole platform.

### 2.2 Do not promote behavior SSOT to platform SSOT
Unless a design decision explicitly says so, do not:

- Replace the platform session model for all nodes with a behavior ledger
- Change platform timing semantics globally because one behavior has different semantics
- Require non-behavior pages to depend on behavior-only tables/services

### 2.3 Projection is not authority
A **projection** (adapter-mapped status, `time_summary`, derived flags) may be used for UI display and monitoring, but it must not be treated as an authorization gate.

- **Ledger/Kernel** decides what is allowed.
- **Projection** decides what is shown.

If a UI needs to block an action, it must rely on a server-side guard or an explicit canonical policy field from core.

## 3) Integration pattern (how behaviors should connect to the core)

### 3.1 Prefer adapters/projections over core rewrites
When a behavior needs to appear in core UI (queue/modal/monitoring), do it via:

- Adapter mapping into the canonical contract
  - Example: map behavior status values into the platform’s canonical `session_status` (`active`/`paused`/`none`)
- Projection fields for display
  - Example: optional `time_summary` object for display/reporting, computed from the behavior’s ledger
- Guardrails for safety
  - Example: concurrency guard so an operator cannot run conflicting work in parallel

### 3.2 Canonical contract first
Core pages (queue/modal/monitoring) should consume a stable, canonical contract.
Behavior-specific fields may be included as optional debug/detail fields but should not be the only source.

### 3.3 Canonical contracts to preserve
The following contracts are considered platform-level and must remain stable unless explicitly approved:

- `session_status` (canonical activity signal): `active | paused | none`
- `time_summary` (optional projection for display/reporting): `{ presence_seconds, effort_seconds, first_started_at, last_activity_at, is_running? }`
- Concurrency policy (operator cannot run conflicting active work in parallel)

Behaviors may extend payloads with behavior-specific details, but must not force core pages to depend on those details.

## 4) Hard rules for future agents

- Do not treat any Node Behavior as the platform/OS.
- Do not refactor platform routing/session/permission semantics as a side effect of improving one behavior.
- Do not change canonical contracts (`session_status`, queue/modal baseline contract) without an explicit decision and migration plan.
- If a change affects multiple nodes/pages, stop and request confirmation before proceeding.
- Keep fixes local:
  - Prefer patching the behavior itself
  - Or patching adapter/projection code paths that feed canonical UI contracts
- Pre-flight checklist (required before implementing):
  - Identify the change tier (0–3) and expected blast radius.
  - List the canonical fields touched (if any) and all consumers (queue/modal/monitoring/manager).
  - Confirm which table/service is SSOT for the change.
  - Define rollback (feature flag, revert path, or safe no-op fallback).

## 5) Copy/paste snippet (Windsurf Rules style)

---
trigger: always_on
---

<architecture_guardrails>
- Treat **Core DAG + token lifecycle + canonical UI contracts** as the platform "OS" (bloodstream).
- Treat **Node Behaviors** as "Applications" running on the platform.
- SSOT is **scoped**:
  - Platform SSOT remains platform-owned.
  - Behavior SSOT may exist only for that behavior’s internal ledger/state.
- Never promote a behavior’s internal SSOT to replace platform SSOT unless explicitly instructed.
- Integrate behaviors via adapter/projection layers:
  - Map behavior statuses into canonical fields (e.g., `session_status: active|paused|none`).
  - Provide optional projection objects for display/reporting (e.g., `time_summary`).
  - Enforce safety guardrails (e.g., concurrency policy) without rewriting core.
- Classify changes by tier (0–3) and default to Tier 0–1 (behavior-local or adapter/projection).
- Projection is not authority: UI display may use projections, but authorization must come from server-side guards or explicit canonical policy fields.
</architecture_guardrails>

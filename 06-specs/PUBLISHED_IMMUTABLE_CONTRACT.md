# Published = Immutable (Product Revision) — Contract & Hardening Notes

**Status:** Canonical policy (recommended)  
**Audience:** Product / Engineering / QA  
**Scope:** Product Revisions → MO / Job Ticket / Hatthasilpa Jobs runtime safety

---

## 1) Goal (Why this exists)

Bellavier ERP’s operational safety principle:

- **A published revision must be immutable immediately.**
- Any MO/Job created against a revision must remain **reproducible** and **auditable** forever.
- No “silent drift” caused by later edits to live tables.

This document defines the contract and records the hardening patches applied to enforce it.

---

## 2) Definitions

- **Published revision**: `product_revision.status = 'published'`
- **Pinned revision binding**: `mo.product_revision_id` and/or `job_ticket.product_revision_id` references a concrete revision id.
- **Snapshot**: JSON payload stored in `product_revision.snapshot_json` representing the immutable config at publish time.
- **Runtime-compatible snapshot**: A snapshot that matches the current contract and is safe for production job creation.

---

## 3) Policy A (Recommended): Strict, versioned snapshot contract

### 3.1 Contract rule

For production-critical flows (especially **Hatthasilpa/DAG**):

- **Create MO / create Job / start production is allowed only when the pinned revision is runtime-compatible AND contains the required snapshot sections.**
- Legacy published revisions without required snapshot sections are **viewable** but **NOT eligible** for new work.

### 3.2 How we evolve in the future (no breaking old work)

When introducing new fields/features that matter to runtime:

- **Do NOT require the new field retroactively.**
- **Bump snapshot schema version** (e.g. `products.runtime_snapshot.v2`) and add new optional fields.
- Runtime/readiness/validators must be **multi-version readers** (accept v1 and v2), but “eligibility for new work” can require v2.
- If a new required field is needed for new production, users must **create a new draft revision and publish** (new revision captures the new field).

### 3.3 Non-negotiables

- **Never mutate snapshots of referenced (in-use) revisions.**
- If a published revision is already referenced by jobs, its snapshot must remain unchanged.

### 3.4 Classic Line “relaxation” (what is relaxed vs what is NOT)

Classic Line can be *less demanding* than Hatthasilpa in terms of **routing graph** requirements, but it should **NOT** be relaxed on immutability fundamentals.

**Relaxed for Classic Line:**

- Graph-related fields are **not required** for eligibility:
  - `snapshot.graph.*`
  - `snapshot.graph.component_mapping`

**Still strict for Classic Line (recommended):**

- The revision must still be **runtime-compatible** and include a **structure snapshot**:
  - `snapshot.schema_version = products.runtime_snapshot.v1` (or later)
  - `snapshot.structure.schema_version = products.structure.v2` (or later)
  - `snapshot.structure.components` present (array)

**Rationale:**

- Classic production does not need DAG routing to be stable, but it still needs BOM/constraints to be reproducible for:
  - material planning / material checks
  - inventory accounting / traceability
  - auditability (“what did we build, with what inputs?”)

**Optional transitional mode (timeboxed, not recommended long-term):**

- If we must keep legacy Classic products running temporarily, we can introduce a feature-flagged “Compatibility Mode”:
  - allow creating Classic work from legacy revisions **only when** the new feature is not required
  - always show a UI warning + log an audit entry
  - disable any feature that depends on missing snapshot data

This transitional mode must have an explicit end date and migration plan (publish new revisions).

---

## 4) Runtime snapshot contract (current)

### 4.1 Required fields (for new work eligibility)

The minimum required contract for **new work**:

- `snapshot.schema_version = 'products.runtime_snapshot.v1'`
- `snapshot.structure.schema_version = 'products.structure.v2'`
- `snapshot.structure.components` is an array (may be empty only if policy explicitly allows “empty BOM products”)

Optional but strongly recommended for full user clarity:

- `snapshot.bom.items[]` (aggregated BOM per unit)
- `snapshot.graph.graph_version_id` (Hatthasilpa)
- `snapshot.graph.component_mapping` (Hatthasilpa)

> Note: Older snapshots may not contain these. That is exactly what Policy A prevents from being used for new work.

---

## 5) What happens to “legacy revisions”

### 5.1 Legacy revision behavior

A legacy published revision that does not contain the required snapshot sections:

- **Can be displayed** in Revision Details UI
- **Cannot be used** to create MO/Job or start production

### 5.2 How to handle legacy products that must continue producing

- Create a **new draft revision** derived from the legacy revision (or from current product state)
- Enter missing new fields/config
- Publish the new revision
- New MO/Jobs will pin to the new revision

This preserves immutability for the legacy revision while allowing business continuity.

---

## 6) Hardening patches applied (Audit outcome)

### 6.1 Strict revision gating (no more “fallback to live tables” for new work)

**File:** `source/BGERP/Service/ProductRevisionService.php`

We enforced strict runtime compatibility:

- `snapshot.schema_version` must match `products.runtime_snapshot.v1`
- `snapshot.structure.schema_version` must match `products.structure.v2`
- `snapshot.structure.components` must exist and be an array

Impact:

- `getActivePublishedRevisionIdForJob()` returns `null` unless snapshot is compatible.
- `isRevisionAllowedForNewJobs()` and `isRevisionSelectableForJobBinding()` are strict.
- This prevents creating MO/Job against “published but uncaptured” revisions.

### 6.2 Runtime snapshot now contains human-meaningful sections

**File:** `source/BGERP/Product/ProductRevisionService.php`

We expanded publish-time snapshot building so published revisions capture:

- `structure` (Material Architecture V2): components + materials + constraints
- `bom.items` aggregated per unit (from structure)
- `graph` details (best-effort): version + code/name
- `graph.component_mapping` snapshot (best-effort)

Impact:

- “Revision Details” can show what was actually configured at publish time.
- New revisions have a consistent immutable record.

### 6.3 Revision Details UI: summary for non-technical users

**File:** `assets/javascripts/products/product_workspace.js`

We added:

- A **Configuration summary** section in the Revision Details modal
- Raw JSON moved under “Raw snapshot JSON”
- If a revision snapshot does not include structure (legacy), UI shows **Not captured** instead of misleading “0”.

---

## 7) Known remaining gaps (next hardening milestones)

### 7.1 Graph runtime determinism

Current risk:

- `GraphInstanceService` creates node instances from `routing_node` (live graph), not an explicit graph version snapshot.

Required improvement:

- Job instance creation must become deterministic against a pinned graph version (or versioned node snapshot).

### 7.2 Mandatory revision pin on all production paths

Required improvement:

- All Job/MO creation paths must fail if they cannot pin a valid revision.
- Avoid any “legacy job created without revision binding” paths.

---

## 7.x Phase 2 hardening applied (Graph runtime determinism + hard gate)

### 7.x.1 Hatthasilpa graph version gating

**File:** `source/BGERP/Service/ProductRevisionService.php`

- Hatthasilpa revisions eligible for **new work** now require a pinned `product_revision.graph_version_id` that points to a published `routing_graph_version`.
- Classic Line remains relaxed on graph requirements (no graph pin required for eligibility).

### 7.x.2 Persist pinned graph version into runtime records

**Files:**

- `source/BGERP/Service/JobCreationService.php`
- `source/BGERP/Service/GraphInstanceService.php`
- `source/job_ticket.php`

Changes:

- Job creation now persists:
  - `job_ticket.product_revision_id` (mandatory)
  - `job_ticket.id_routing_graph` and `job_ticket.graph_version` (from the revision’s pinned graph version)
- `GraphInstanceService::createInstance()` now accepts optional `$graphVersion` and writes to `job_graph_instance.graph_version` when the column exists.

### 7.x.3 Deterministic DAG routing from version snapshot

**Files:**

- `source/BGERP/Service/GraphSnapshotRuntimeService.php` (new)
- `source/BGERP/Service/DAGRoutingService.php`
- `source/BGERP/Service/TokenLifecycleService.php`

Changes:

- Added a runtime helper that loads `routing_graph_version.payload_json` based on `job_graph_instance.graph_version` (or `job_ticket.graph_version`) and provides node/edge lookups.
- `DAGRoutingService` and `TokenLifecycleService` now prefer snapshot-based routing/edge counts/start-node when available, and only fall back to live tables for legacy jobs.

### 7.x.4 Hard gate: no more “legacy jobs without revision pin” for new work

**Files:**

- `source/hatthasilpa_jobs_api.php`
- `source/job_ticket.php`
- `source/BGERP/Service/JobCreationService.php`

Changes:

- Job creation/update now fails when a job-safe `product_revision_id` cannot be resolved.
- Removed “warn and continue without revision pinning” behavior for new Hatthasilpa jobs.

---

## 8) Operational checklist (dev / QA)

- **Publishing a revision must build a snapshot that includes `structure`** and (Hatthasilpa) `graph.graph_version_id`.
- **MO creation** must pin `product_revision_id` and validate it.
- **Job creation** must pin `product_revision_id` and validate it.
- “Revision Details” must show a meaningful summary without requiring JSON knowledge.

---

## 9) Decision record

We adopt **Policy A (Strict contract)** for production safety:

- Immutable published revisions
- Versioned snapshot evolution
- No retroactive requirements
- No using legacy uncaptured revisions for new work


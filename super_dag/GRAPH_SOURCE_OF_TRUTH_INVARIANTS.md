# Graph Source of Truth - System Invariants

**Document Type**: Architecture Contract  
**Status**: Locked (Post-Ghost Graph Fix)  
**Date**: 14-Dec-2025

---

## Purpose

This document declares **immutable system invariants** that prevent Ghost Graph issues. These rules must be enforced by code and cannot be violated without explicit architectural decision.

---

## Core Invariants

### INVARIANT 1: Published Graph Immutability

**Rule**: Published and retired graph versions are **immutable**. Their data cannot be modified directly.

**Enforcement Points**:
- `routing_graph_version.payload_json` (snapshot) is the **only source of truth** for published versions
- Main tables (`routing_graph`, `routing_node`, `routing_edge`) may be out of sync with published snapshots
- When loading `version='published'` or specific version string → **MUST** read from `routing_graph_version` snapshot
- When loading `version='published'` → **MUST NOT** read from main tables or draft payloads
- Autosave operations **MUST NOT** write to published graphs (must create draft first)

**Violation Consequences**: Ghost data, position drift, configuration changes

---

### INVARIANT 2: Draft Graph Isolation

**Rule**: Draft graphs are **isolated** from published versions. Draft operations cannot affect published data.

**Enforcement Points**:
- Draft payload stored in `routing_graph_draft.draft_payload_json` is **independent** from published snapshots
- Creating a draft **MUST NOT** modify published version data
- Deleting/discarding a draft **MUST NOT** modify published version data
- Draft payload structure: `{ nodes: [...], edges: [...], metadata: {...} }` (no `graph` field)
- When loading `version='latest'` with active draft → **MUST** load from draft payload (not main tables)
- When loading `version='latest'` without active draft → **MUST** load from main tables (published state)

**Violation Consequences**: Draft changes affecting published views, ghost data

---

### INVARIANT 3: Source-of-Truth Determinism

**Rule**: Each graph context has a **single, deterministic source of truth**. No ambiguity allowed.

**Enforcement Points**:
- `version='published'` → Source: `routing_graph_version.payload_json` (snapshot)
- `version='latest'` with active draft → Source: `routing_graph_draft.draft_payload_json` (draft payload)
- `version='latest'` without active draft → Source: `routing_graph` + `routing_node` + `routing_edge` (main tables)
- `version='v2.0'` (specific) → Source: `routing_graph_version.payload_json` where `version='v2.0'`
- Backend **MUST** return data from the correct source based on requested version
- Frontend **MUST** send explicit version parameter (never ambiguous)

**Violation Consequences**: Wrong data returned, source confusion, ghost data

---

### INVARIANT 4: Autosave Context Restrictions

**Rule**: Autosave operations are **forbidden** in read-only contexts (published/retired views).

**Enforcement Points**:
- Autosave **MUST NOT** execute when `graph.status === 'published'` or `graph.status === 'retired'`
- Autosave **MUST NOT** execute when `isReadOnlyMode === true`
- Autosave **MUST** check graph status before writing
- Autosave **MUST** create draft first if attempting to modify published graph
- Autosave position updates **MUST** target draft payload (if active draft exists) or main tables (if no draft)

**Violation Consequences**: Published graphs modified, data corruption, immutability violation

---

### INVARIANT 5: API Response Shape Normalization

**Rule**: API responses **MUST** have consistent shape regardless of source (draft or published).

**Enforcement Points**:
- All `graph_get` responses **MUST** return: `{ graph: {...}, nodes: [...], edges: [...], draft: {...}, ... }`
- Draft payload structure (`{ nodes, edges, metadata }`) **MUST** be normalized to include `graph` object
- Graph metadata **MUST** be loaded from main table when draft payload doesn't include it
- Frontend **MUST NOT** need to know whether data came from draft or published source
- Response shape **MUST** be frontend-agnostic (same structure for all contexts)

**Violation Consequences**: Frontend logic complexity, payload structure mismatches, decode failures

---

## Derived Rules

### Rule 6: ETag Uniqueness per Context

**Rule**: ETag **MUST** be unique per version/draft context to prevent stale cache.

**Enforcement Points**:
- ETag **MUST** include `draft_id` when active draft exists
- ETag **MUST** include `version` string when loading specific version
- ETag **MUST** change when draft is created/deleted/modified
- ETag **MUST** be different for `version='published'` vs `version='latest'` (when draft exists)

**Violation Consequences**: Stale cache, 304 Not Modified with wrong data

---

### Rule 7: Version Parameter Explicitness

**Rule**: Frontend **MUST** send explicit version parameter. Backend **MUST** honor it.

**Enforcement Points**:
- Frontend **MUST** send `version='published'` when viewing published version
- Frontend **MUST** send `version='latest'` when viewing draft (or allow draft)
- Backend **MUST NOT** override requested version with draft data
- Backend **MUST** return data from source matching requested version

**Violation Consequences**: Wrong version returned, draft override, ghost data

---

## Invariant Enforcement Checklist

### Backend Enforcement

- [ ] `loadGraphWithVersion()` enforces source-of-truth determinism (INVARIANT 3)
- [ ] `GraphService::getGraph()` never overrides requested version (INVARIANT 3)
- [ ] `GraphVersionService::publish()` syncs main tables after snapshot creation (INVARIANT 1)
- [ ] `GraphDraftService::saveDraft()` isolates draft from published (INVARIANT 2)
- [ ] `dag_graph_api.php` normalizes response shape (INVARIANT 5)
- [ ] ETag calculation includes context identifiers (Rule 6)

### Frontend Enforcement

- [ ] `loadGraph()` sends explicit version parameter (Rule 7)
- [ ] `handleGraphLoaded()` validates response matches requested version (INVARIANT 3)
- [ ] `scheduleAutoSave()` checks read-only mode (INVARIANT 4)
- [ ] `createDraftFromPublishedInternal()` isolates draft creation (INVARIANT 2)
- [ ] `GraphLoader` handles response shape consistently (INVARIANT 5)

---

## Violation Detection

### Red Flags (Must Investigate)

1. Published graph positions/configs change after draft operations
2. API returns draft data when `version='published'` requested
3. Autosave writes to published graph without draft
4. Response shape differs between draft and published contexts
5. ETag collision between draft and published contexts

---

### INVARIANT 8: Write-Path Exclusivity

Rule: Each mutation operation MUST write to exactly one storage target.

- Draft mutations → routing_graph_draft ONLY
- Published publish → routing_graph_version ONLY
- Main tables → only via publish sync step
- No API is allowed to write to multiple graph stores in one request

Violation Consequences: Partial updates, ghost state, irreproducible bugs

---

## Notes

- These invariants are **post-fix** (after Ghost Graph resolution)
- Violations indicate architectural regression, not runtime bugs
- All invariants must be verified before any refactoring
- New features must respect all invariants



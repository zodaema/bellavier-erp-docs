# Operational Safety & Change Governance for Product System

**Version:** 1.0  
**Date:** January 2026  
**Status:** 📋 **DRAFT FOR APPROVAL**  
**Domain:** Products / Components / Constraints / Graph Binding  
**System:** Bellavier ERP  
**Goal:** Prevent production, inventory, and WIP corruption caused by live configuration changes

---

## 1. Problem Statement

The system currently allows modification of:
- Product Components
- Constraints
- Graph Bindings
- Related configuration

Even when the product has already been used in production or inventory operations.

**Risks:**
- ❌ Incorrect inventory deduction
- ❌ Inconsistent WIP execution
- ❌ Non-reproducible production history
- ❌ Silent data corruption

---

## 2. Core Principle (Must Hold True)

> **No operational entity (inventory, job, token, WIP) may change its behavior or meaning after it has started.**

**Therefore:**
- Products are **design-time objects**
- Jobs / Tokens are **runtime snapshots**
- Runtime must **never depend on mutable design-time data**

---

## 3. Product Usage State Model (Authoritative)

Every Product MUST have a usage state derived from system data.

### 3.1 Product Usage States

| State | Meaning | Allowed Actions |
|-------|---------|----------------|
| **DRAFT** | Product never used | Full edit allowed |
| **ACTIVE** | Used historically, no active WIP | Limited edit |
| **IN_PRODUCTION** | Has active jobs/tokens | Core edits forbidden |
| **RETIRED** | Deprecated | Read-only |

### 3.2 State Derivation Rules (No manual override)

| Condition | State |
|-----------|-------|
| No job / token / inventory record exists | **DRAFT** |
| Has completed jobs but no active WIP | **ACTIVE** |
| Has at least one active job/token | **IN_PRODUCTION** |
| Explicitly retired | **RETIRED** |

**Critical:** State must be **computed**, not stored as a manual flag.

---

## 4. Change Classification (Critical)

All product changes are classified as either:

### 4.1 Breaking Changes (Core-Breaking)

Changes that alter production meaning:
- Constraints (qty, size, length, area, count)
- Component material mapping
- Graph binding / routing
- Unit / measurement logic
- BOM structure

**➡️ Breaking changes MUST NOT be applied in place once product ≠ DRAFT.**

### 4.2 Non-Breaking Changes (Safe)

Examples:
- UI labels
- Descriptions
- Display order
- Notes / metadata
- Cosmetic UI behavior

**➡️ Allowed in ACTIVE, forbidden in IN_PRODUCTION.**

---

## 5. Enforcement Rules (Hard Gates)

### Rule 1 — DRAFT
- ✅ All edits allowed
- ✅ No restriction

### Rule 2 — ACTIVE
- ❌ Breaking changes forbidden
- ✅ Non-breaking changes allowed
- UI must clearly indicate "Product already used"

### Rule 3 — IN_PRODUCTION
- ❌❌ All core edits forbidden
- UI must be read-only for:
  - Constraints
  - Components
  - Graph bindings
- Must show reason:
  > "Product is currently in production. Changes are locked to protect active jobs."

### Rule 4 — RETIRED
- Read-only
- No edits allowed

---

## 6. Runtime Snapshot Requirement (Mandatory)

### 6.1 Snapshot Creation

When a Job / MO / Token is created, system MUST snapshot:
- Product ID + Product Revision (implicit or explicit)
- Components (resolved)
- Constraints (final resolved values)
- Graph binding (resolved DAG)
- Computed quantities

### 6.2 Runtime Execution Rule
- Runtime entities MUST reference snapshot data only
- Runtime MUST NOT read live product tables

**This guarantees reproducibility and auditability.**

---

## 7. Concurrency Control (Multi-User Safety)

### 7.1 Optimistic Locking

Any product update must include:
- `updated_at` or `row_version`

Update must fail with:
- **409 CONFLICT** if version mismatch

### 7.2 UI Behavior on Conflict
- Show message:
  > "This product was modified by another user. Please reload."
- No silent overwrite

---

## 8. Role / Constraint Change Policy (Linked Rule)

- Changing Role is **always a breaking change**
- Therefore:
  - Allowed only in **DRAFT**
  - In other states → must be blocked or force new revision

**Note:** This policy is already implemented (January 2026) with confirmation dialog.

---

## 9. Revision Strategy (Phase 2 – Optional but Recommended)

Instead of editing:
- Create Product Revision v2
- New jobs use v2
- Existing jobs remain on v1

**This enables:**
- Continuous improvement
- Zero production risk
- Full traceability

---

## 10. UX / UI Requirements

### 10.1 Visual Indicators
- Show product state badge: **DRAFT / ACTIVE / IN_PRODUCTION**
- Disabled sections must explain why

### 10.2 Confirmation
- Any destructive action must warn user
- No silent data loss

---

## 11. Non-Goals (Explicit)

This spec does NOT:
- Define UI design details
- Define database schema changes
- Define migration scripts
- Define reporting or analytics

---

## 12. Definition of "System Is Safe"

System is considered production-safe when:
- ✅ No breaking change can affect active or historical jobs
- ✅ Inventory deduction logic is deterministic
- ✅ All production behavior is reproducible
- ✅ Multi-user edits cannot corrupt data

---

## 13. Summary (Executive)

> **Design-time data must freeze before runtime begins.**

Any system that violates this rule will eventually corrupt inventory and production history.

This spec ensures Bellavier ERP behaves like a real industrial system, not a mutable admin panel.

---

## 14. Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| Product Usage State Model | 📋 **TODO** | Need to implement state derivation |
| Change Classification | 📋 **TODO** | Need to classify all change types |
| Enforcement Rules | 📋 **TODO** | Need to implement gates |
| Runtime Snapshot | 📋 **TODO** | Need to verify snapshot creation |
| Concurrency Control | 📋 **TODO** | Need to implement optimistic locking |
| Role Change Policy | ✅ **DONE** | Implemented with confirmation (Jan 2026) |
| Revision Strategy | 📋 **PHASE 2** | Optional, future enhancement |
| Visual Indicators | 📋 **TODO** | Need to add state badges |

---

## 15. Related Documents

- **Implementation Plan:** `docs/super_dag/plans/OPERATIONAL_SAFETY_IMPLEMENTATION_PLAN.md`
- **Current State Analysis:** See implementation plan for detailed analysis
- **Existing Functions:**
  - `validateProductState()` - Partial (checks `is_draft`/`is_active` only)
  - `checkProductUsage()` - Soft-check (warnings only, not blocking)
  - ETag support - Partial (some endpoints have it, not all)

---

**Status:** 📋 **DRAFT FOR APPROVAL**  
**Next Action:** Review and approve spec, then begin Phase 1 implementation  
**Priority:** 🔴 **HIGH** (Production safety critical)  
**Implementation Plan:** See `docs/super_dag/plans/OPERATIONAL_SAFETY_IMPLEMENTATION_PLAN.md`


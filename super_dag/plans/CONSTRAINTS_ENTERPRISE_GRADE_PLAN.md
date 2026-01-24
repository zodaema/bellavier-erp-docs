# Constraints System - Enterprise Grade Enhancement Plan

**Date:** January 5, 2026  
**Purpose:** Transform Constraints System to Enterprise Grade (SAP/Apple level)  
**Status:** 📋 **PLANNING** - Baseline Audit Required  
**Scope:** BOM Constraints & Material Role System

---

## 🎯 Objectives

Transform the Constraints System to achieve:
- **Enterprise-grade reliability** (SAP/Apple level)
- **Zero UI churn** (prevent layout drift)
- **Zero regressions** (contract tests + schema versioning)
- **Deterministic behavior** (versioned APIs, documented contracts)

---

## 🚨 HARD GATE RULE

**ABSOLUTE RULE (HARD GATE):**
You are **FORBIDDEN** to modify any UI code, UI layout, CSS, or front-end behavior **UNTIL ALL THREE are completed and committed:**

1. ✅ **Contract Tests** (API contracts locked)
2. ✅ **Schema Versioning Plan + Enforcement** (breaking changes versioned)
3. ✅ **UI Placement Rules + Layout Map** (deterministic placement)

**If any of the above is not possible, STOP and produce a risk report + alternative safe plan.**

**Do not "best-effort" UI changes.**

---

## 📋 Workflow (Non-Negotiable Order)

### Step 0: Baseline Audit ✅ (CURRENT STEP)
- [x] Identify exact UI surface that would be changed later
- [x] Identify endpoints + DB tables involved
- [x] Output: `/docs/audit/CONSTRAINTS_UI_CHANGE_BASELINE.md`

### Step 1: Contract Spec + Tests ✅ **COMPLETE**
- [x] Create contract spec document: `docs/contracts/products/constraints_contract_v1.md`
- [x] Implement contract tests: `tests/Contract/ProductApiConstraintsContractTest.php`
- [x] Add golden fixtures: 5 fixtures in `tests/fixtures/contracts/products/`
- [x] Add Contract testsuite to `phpunit.xml`
- [x] Deliverable: Contract tests passing in CI (run: `vendor/bin/phpunit --testsuite Contract`)

### Step 2: Schema Versioning (NOT STARTED)
- [ ] Create schema versioning policy
- [ ] Implement enforcement mechanism
- [ ] Add schema version metadata
- [ ] Deliverable: Versioning policy + enforcement

### Step 3: UI Layout Map + Placement Rules (NOT STARTED)
- [ ] Create UI layout map
- [ ] Create UI placement rules
- [ ] Add lightweight enforcement check
- [ ] Deliverable: Layout map + rules + enforcement

### Step 4: UI Change Plan (NOT STARTED)
- [ ] Only after Step 1-3 are green → propose UI changes
- [ ] UI proposal must reference layout map regions + placement rules
- [ ] UI changes must be minimal-diff and cannot alter unrelated layout
- [ ] Deliverable: UI change plan (NOT implementation)

---

## 📁 File Plan (What Will Be Added/Modified)

### New Documents to Create

#### Contract Documents
- `docs/contracts/products/contract_v1.md` - API contract specification
- `tests/contract/ProductConstraintsContractTest.php` - Contract tests
- `tests/fixtures/contracts/products/` - Golden JSON fixtures

#### Schema Versioning Documents
- `docs/schema/SCHEMA_VERSIONING_POLICY.md` - Versioning policy
- `database/schema_versions/` - Schema version tracking (if needed)

#### UI Documents
- `docs/ui/UI_LAYOUT_MAP.md` - Layout ownership map
- `docs/ui/UI_PLACEMENT_RULES.md` - Placement rules
- `tests/ui/LayoutEnforcementTest.php` - Layout enforcement checks (if feasible)

#### Audit Documents
- `docs/super_dag/00-audit/CONSTRAINTS_UI_CHANGE_BASELINE.md` - Baseline audit (Step 0)

### Files to Modify (After Steps 1-3 Complete)

#### API Files (Minor additions only)
- `source/product_api.php` - Add schema_version metadata (if needed)

#### Database Files (Versioning only)
- Migration files - Add version tracking (if needed)

#### Tests (Additions only)
- Add contract tests
- Add layout enforcement tests (if feasible)

### Files NOT to Modify (Until Step 4)

- ❌ `assets/javascripts/products/product_components.js` (UI code - FORBIDDEN until Step 1-3 complete)
- ❌ `views/products/product_components.php` (UI layout - FORBIDDEN until Step 1-3 complete)
- ❌ Any CSS files (FORBIDDEN until Step 1-3 complete)
- ❌ Any HTML templates (FORBIDDEN until Step 1-3 complete)

---

## 🎯 Acceptance Criteria

### Step 1: Contract Tests
- [ ] Contract spec document complete
- [ ] Contract tests added + command to run documented
- [ ] Golden fixtures added
- [ ] Tests fail on breaking changes (field removal, type change, enum removal)
- [ ] CI command: `vendor/bin/phpunit tests/contract/`

### Step 2: Schema Versioning
- [ ] Schema versioning policy document complete
- [ ] Schema version surfaced (meta/header/table) + mechanism explained
- [ ] Enforcement mechanism documented
- [ ] Breaking changes require version bump OR compatibility layer
- [ ] Version lookup mechanism documented

### Step 3: UI Placement Rules
- [ ] UI layout map document complete
- [ ] UI placement rules document complete
- [ ] Lightweight UI enforcement check added (if feasible)
- [ ] Layout regions and boundaries documented
- [ ] Placement constraints documented

### Step 4: UI Change Plan
- [ ] Only after Step 1-3 are green
- [ ] UI proposal references layout map regions + placement rules
- [ ] UI changes are minimal-diff
- [ ] UI changes do not alter unrelated layout

---

## 🚦 Quality Bar (Enterprise)

- **Minimal diff:** Do not refactor unrelated code
- **Deterministic behavior:** No time-dependent tests without mocks
- **Backward compatibility first:** Adapters over breaking changes unless versioned
- **Documentation must be enough:** For another engineer to continue without you

---

## 📊 Risk Assessment

**High Risk:**
- UI enforcement may be difficult without JavaScript testing framework
- Schema versioning may require database changes
- Contract tests may require significant test infrastructure

**Mitigation:**
- Use simplest enforceable mechanism consistent with repo stack
- If enforcement not feasible, document risk + alternative approach
- Prioritize documentation over automation where needed

---

**Status:** 📋 **STEP 0 IN PROGRESS**  
**Next Action:** Complete Baseline Audit document  
**Blockers:** None (starting fresh)


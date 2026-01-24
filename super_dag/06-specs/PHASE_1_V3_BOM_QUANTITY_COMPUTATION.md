# PATCH: BOM Quantity = Computed from Constraints (UI-first → CRUD → Audit → Enforce)

## Objective (Non-negotiable)

1. Users must **NOT** manually calculate BOM Quantity in normal flow.
2. Quantity **MUST** be computed from Constraints fields: `width`, `length`, `thickness`, `piece_count`.
3. Constraints input unit **MUST** be fixed across the system: choose **ONE** unit (mm OR cm) and lock it.
4. Computation **MUST** output `qty_required` in the material's configured default UoM (already enforced at material creation).
5. **Reuse-first**: do **NOT** create new concepts/tables unless proven missing by evidence search.

---

## Phase A — Decide Fixed Input Unit (LOCK)

Pick exactly one:
- **Option 1:** mm (recommended for production precision)
- **Option 2:** cm (recommended for human-friendly pattern dimensions)

### Implementation Rule

- UI shows unit label **fixed** (no dropdown).
- Stored `constraints_json` **MUST** include `unit_locked: "mm"` (or `"cm"`) for audit clarity.
- **Thickness unit is ALWAYS mm** regardless of chosen width/length unit.
  - For this patch, thickness **MUST** be stored & displayed in mm **ALWAYS**. (LOCK)
  - `width`/`length` unit is fixed (mm or cm), `thickness` always mm.

---

## Phase B — UI: Add/Upgrade Constraints Editor inside Materials (BOM)

### Location

- Existing "Materials (BOM)" table in Edit Component modal.
- Constraints button already exists (gear icon). Use it as entry point.
- **DO NOT** create new tabs or new top-level screens.

### Required UI Fields (for relevant Material Role)

Constraints modal must allow input:
- `width` (number, required when `basis=AREA`)
- `length` (number, required when `basis=AREA` or `LENGTH`)
- `thickness_mm` (number, optional now but **MUST** be present for roles that need it; store anyway)
- `piece_count` (integer, default 1, required)
- `waste_factor_percent` (optional, default 0)
- `note` (optional)

### Definition: piece_count

- `piece_count` means: **number of identical pieces of THIS MATERIAL required per ONE product unit**.
- It **MUST NOT** represent production batch quantity.
- It **MUST NOT** be derived from order quantity.
- **Note:** `piece_count` is always per-product-unit, never per-order.

### Basis Type (do NOT let user choose unless necessary)

- `basis_type` **MUST** be derived automatically from `material.default_uom_code`:
  - `sqft` / `sqm` → `AREA`
  - `yard` / `m` → `LENGTH`
  - `piece` / `pcs` → `COUNT`
- UI may display read-only badge: `Computed as AREA/LENGTH/COUNT`.

### Role Applicability

- Constraints editor **MUST** only appear for roles that need consumption constraints.
- Use existing `MaterialRoleValidationService` rules; if role is not applicable, show "Not required".

### UX Rules

- Quantity input in BOM row becomes:
  - **read-only display** by default (computed)
  - show badge: "Computed" / "Incomplete constraints" / "Overridden"
- If constraints incomplete:
  - show status "Incomplete"
  - **block save/update** of that BOM row until constraints filled (STRICT) unless override mode enabled.

#### Constraints Editor Contextual Display

Constraints modal **MUST** display:
- Material name (read-only)
- Material role (read-only)
- `default_uom_code` (read-only badge)
- Computed `basis_type` badge (e.g., "Computed as AREA")
- **Purpose:** So user understands WHY the formula is what it is.

#### Validation Feedback (Explainable)

- If constraints are incomplete, UI **MUST** highlight exactly which fields are missing.
- Avoid generic "Invalid constraints" errors.
- **Purpose:** UX for factory users = must be fast, not guesswork.

### Remove Useless/Duplicate Inputs

- Do **NOT** ask user to type "Material Specification" free text.
- Materials must be selected from existing dropdown; role selected; constraints configure consumption.

---

## Phase C — CRUD: Persist Constraints and Compute qty_required (Server is SSOT)

### Affected Endpoints

Reuse existing endpoints already verified:
- `add_component_material`
- `update_component_material`
- `remove_component_material`

### Data Contract

**Client sends:**
- `constraints_json` (JSON string) containing:
  - `unit_locked`
  - `width`, `length`, `thickness_mm`, `piece_count`, `waste_factor_percent`
  - **Client MUST NOT send `basis_type`** (see rule below)

**Server must:**
1. **Derive `basis_type` server-side from `material.default_uom_code`** (client MUST NOT be trusted).
2. If client sends `basis_type`, it **MUST be ignored** (or validated strictly and rejected on mismatch).
3. Validate `constraints_json` shape per derived `basis_type`.
4. Compute `qty_required` deterministically.
5. Persist `constraints_json` (existing column) and `qty_required` (existing field) in **ONE** operation.
6. Return computed `qty_required` + flags:
   - `computed_from_constraints=true`
   - `constraint_status`: `COMPLETE` | `INCOMPLETE` | `OVERRIDDEN`
   - `basis_type`, `uom_code`

**Rationale:**
- `basis_type` = logic, not input.
- Prevents state mismatch between material UoM vs constraint.
- Prevents silent bugs and state drift between UI ↔ API.

### Manual Override (Exception Path)

- Keep it, but gated:
  - `override_mode=1` requires `override_reason` (non-empty)
  - `qty_required` allowed only when `override_mode=1`
  - log change via `ProductReadinessService::logConfigChange()` with before/after hashes (no `JSON_SORT_KEYS` usage)

---

## Phase D — Computation Engine (MUST be server-side)

Create or reuse a single function/class:
- `BomQuantityCalculator::compute($materialUomCode, $constraints) : float|int`
or equivalent inside existing service (reuse-first).

### Conversion Rules (must be explicit)

#### 1) AREA (sqft / sqm)

**Inputs:**
- `width`, `length` in fixed unit (mm or cm)
- `piece_count`
- `waste_factor_percent`

**Steps:**
1. Convert width/length → meters:
   - if unit is `mm`: `meters = mm / 1000`
   - if unit is `cm`: `meters = cm / 100`
2. `area_sqm = width_m * length_m * piece_count`
3. `area_sqm *= (1 + waste_factor/100)`

**Output:**
- if `materialUomCode == "sqm"`: `qty = area_sqm`
- if `materialUomCode == "sqft"`: `qty = area_sqm * 10.76391041671`

**Rounding:**
- keep 4 decimals for area units.

#### 2) LENGTH (m / yard)

**Inputs:**
- `length` in fixed unit (mm or cm)
- `piece_count`
- `waste_factor_percent`

**Steps:**
1. Convert length → meters
2. `total_m = length_m * piece_count`
3. `total_m *= (1 + waste_factor/100)`

**Output:**
- if `uom == "m"`: `qty = total_m`
- if `uom == "yard"`: `qty = total_m * 1.0936132983`

**Rounding:**
- keep 4 decimals for length units.

#### 3) COUNT (piece / pcs)

**Inputs:**
- `piece_count`
- `waste_factor_percent` optional:
  - `qty = ceil(piece_count * (1 + waste/100))`

**Output:**
- integer

### Hard Rule: Thickness Is NOT Part of Quantity Formula (Phase 1)

- `thickness_mm` is a **production constraint only**, not a consumption factor.
- Quantity computation **MUST NEVER** use thickness to derive volume or material usage.
- **Rationale:** Prevents agent from "over-smart" volume calculations that break the entire BOM system.

**Any future volume-based computation is OUT OF SCOPE for Phase 1** and requires:
- New phase document
- Explicit material role whitelist
- Explicit approval

**Storage:**
- Still store `thickness_mm` because it is needed for production constraints later (skive/target thickness).

---

## Phase E — AUDIT: Find all usage of qty_required before enforcing read-only

Before flipping UI to read-only, you **MUST** audit:

1. Where `qty_required` is currently used (reports, costing, purchasing, planning, inventory).
2. Whether any code assumes `qty_required` is user-entered.
3. Whether any code recomputes totals from `qty_required`.

### Deliverable (MANDATORY)

Produce an audit note with evidence in **table format**:

| Module | File | Line | Read/Write | Assumption about qty_required | Impact Level |
|--------|------|------|------------|------------------------------|--------------|
| Example: Purchasing | `source/purchasing_api.php` | 145 | Read | Assumes user-entered | HIGH |
| Example: Costing | `source/costing.php` | 230 | Read | Aggregates from qty_required | MED |
| Example: Export | `source/export_bom.php` | 89 | Read | Uses qty_required for PDF | LOW |

**Impact Level Definitions:**
- **HIGH:** Code assumes `qty_required` is user-entered or performs critical calculations
- **MED:** Code aggregates or displays `qty_required` but logic can adapt
- **LOW:** Code only reads `qty_required` for display/reporting

**Purpose:** Actionable audit that can be reviewed quickly, not an essay.

### After Audit, Implement Change

- `qty_required` becomes computed default.
- manual entry is allowed only via `override_mode`.

---

## Phase F — Implementation Order (STRICT)

1. Add Constraints Modal UI fields + wire client payload (but do not enforce read-only yet).
2. Implement server validation + computation + persistence (CRUD).
3. Run audit and list impacted modules; patch them if needed (minimal diffs).
4. Switch UI quantity to read-only + computed badges + strict blocking for incomplete constraints.
5. Add unit/integration tests for:
   - AREA sqft
   - AREA sqm
   - LENGTH yard
   - COUNT piece
   - invalid constraints
   - override path

---

## Guardrails (Do NOT break system)

- No new tabs/screens.
- No free-text material specification.
- No new UoM creation.
- No Node Behavior / routing logic.
- Graph SSOT unaffected.
- **Backward compatibility:**
  - Existing BOM rows without `constraints_json`:
    - show "Incomplete"
    - allow temporary override **ONLY** if `override_mode` is used with reason (optional based on `product.manage` permission)

### Legacy Physical Specifications (Display-Only)

- **Legacy Physical Specifications text:**
  - **MUST** remain display-only
  - **MUST NOT** be read by any quantity computation
  - **MUST NOT** be auto-migrated into `constraints_json`

**Rationale:** Prevents agent from attempting to "smart migrate" text → constraints and corrupting data.

---

## Acceptance Criteria (must pass)

- ✅ A user can configure constraints for a material role, save, and see `qty` auto computed in the material's UoM.
- ✅ `qty_required` is not editable by default.
- ✅ Manual override requires reason and logs.
- ✅ Audit report exists with evidence links.
- ✅ No new spaghetti fields/tables; reuse-first compliance.

---

## Related Documents

- `PHASE_1_IMPLEMENTATION_CANONICAL_PROMPT.md` - Phase 1 constitution and rules
- `PHASE_1_V3_PATCH_PLAN.md` - V3 BOM Role Constraints implementation
- `PRODUCTS_COMPONENTS_V3_CONCEPT.md` - V3 architecture concepts

---

## Status

**Created:** 2026-01-03  
**Status:** Planning  
**Owner:** Development Team

---

## One-Line Philosophy

**If a decision makes quantity easier for the system but harder for humans, it is WRONG.**

This principle guides all architectural and UX decisions in this patch. The system serves factory users, not the other way around.


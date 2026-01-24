# Phase 1 V3 Implementation — Patch Plan

**Version:** 1.0  
**Date:** 2025-12-25  
**Status:** Awaiting Approval

---

## 📋 Overview

This document outlines the **Phase 1 implementation plan** for Products & Components V3 — BOM-Driven Production Constraints (Role-Based).

**Canonical Reference:**
- Primary: `docs/super_dag/01-concepts/PRODUCTS_COMPONENTS_V3_CONCEPT.md`
- Secondary: `docs/DATABASE_SCHEMA_PRODUCTS_COMPONENTS.md`

**Invariants (NON-NEGOTIABLE):**
- I1: Material Constraints SSOT = `product_component_material.constraints_json`
- I2: Slot Spec Scope = `quantity_per_product`, `is_required`, `dimensions_json` only
- I3: Data-Driven UI = Generate from `material_role_field` (no hardcoding)
- I4: Graph is Slot SSOT = Slots from `routing_node.anchor_slot` only

---

## 🎯 Phase 1 Scope

### ✅ What We Build

1. **Database (Additive Only)**
   - Extend `product_component_material`: `role_code`, `constraints_json`
   - Create `material_role_catalog` table
   - Create `material_role_field` table
   - Create `product_component_slot_spec` table
   - Seed 8 roles + minimal fields (MAIN_MATERIAL, LINING)

2. **API**
   - Extend BOM CRUD: support `role_code`, `constraints_json`
   - New read endpoints: list roles, list role fields
   - Role-based validation service
   - Audit logging on constraints changes

3. **UI**
   - BOM table: Role dropdown + Configure button
   - Role-based Configure Modal (data-driven)
   - Deprecate slot-level constraints section

4. **Legacy Handling**
   - `product_config_component_slot`: read-only only
   - No writes to legacy table (except migration with `__legacy_migration_only`)

---

## 📦 Patch Breakdown

### **Patch 1: Database Migrations**

**Files to Create:**
1. `database/tenant_migrations/2025_12_v3_bom_role_constraints.php`
   - Extend `product_component_material`: add `role_code`, `constraints_json`
   - Create `material_role_catalog` table
   - Create `material_role_field` table (with FK to `material_role_catalog`)
   - Create `product_component_slot_spec` table

2. `database/tenant_migrations/2025_12_v3_seed_role_catalog.php`
   - Seed 8 roles: MAIN_MATERIAL, LINING, REINFORCEMENT, HARDWARE, THREAD, EDGE_FINISH, ADHESIVE, PACKAGING
   - Seed minimal fields for MAIN_MATERIAL and LINING

**Changes:**
- **Additive only** (no DROP, no ALTER destructive)
- `role_code` = `NOT NULL DEFAULT 'MAIN_MATERIAL'` (enforce SSOT)
- FK: `material_role_field.role_code` → `material_role_catalog.role_code` (ON UPDATE CASCADE, ON DELETE RESTRICT)
- `applies_to_line` = ENUM('classic', 'hatthasilpa', 'both') (not 'component', 'product', 'both')
- **Table Engine/Charset Policy:** All new tables use `ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci` (match existing schema)
- **Unique Key:** `product_component_slot_spec` must have `UNIQUE KEY uk_product_anchor_slot (id_product, anchor_slot)` to prevent duplicate slot specs per product
- **constraints_json Validation:** Must be JSON object `{}` only (not array `[]`, not stringified JSON). If received as string → decode and assert `is_array()` and `array_is_list()` = false

**Validation:**
- Migration syntax check: `php -l`
- FK integrity check: `SHOW CREATE TABLE`
- Seed data count: 8 roles + fields for MAIN_MATERIAL + LINING
- Table engine/charset: All tables use InnoDB + utf8mb4_unicode_ci
- Unique key: `product_component_slot_spec` has `UNIQUE (id_product, anchor_slot)`

---

### **Patch 1 Output Contract**

**When Patch 1 is complete, the database MUST answer these questions:**

1. **"BOM line ไหนเป็น role อะไร?"**
   - Query: `SELECT id_pcm, role_code FROM product_component_material WHERE id_product_component = ?`
   - Expected: Every BOM line has `role_code` (NOT NULL, default 'MAIN_MATERIAL')

2. **"role นี้ต้องกรอก field อะไรบ้าง?"**
   - Query: `SELECT field_key, field_type, required FROM material_role_field WHERE role_code = ? ORDER BY display_order`
   - Expected: Returns field definitions for role (data-driven UI)

3. **"slot spec ของ product/slot นี้คืออะไร (ถ้ามี)?"**
   - Query: `SELECT * FROM product_component_slot_spec WHERE id_product = ? AND anchor_slot = ?`
   - Expected: Returns slot properties (quantity, is_required, dimensions) or NULL if not set

4. **"ไม่มีอะไรเขียนลง legacy table"**
   - Evidence: No production code writes to `product_config_component_slot` (guard script passes)

**Verification Queries:**
```sql
-- Check role_code constraint
SHOW CREATE TABLE product_component_material;
-- Expected: role_code VARCHAR(50) NOT NULL DEFAULT 'MAIN_MATERIAL'

-- Check FK integrity
SHOW CREATE TABLE material_role_field;
-- Expected: CONSTRAINT fk_role_field_role FOREIGN KEY (role_code) REFERENCES material_role_catalog(role_code)

-- Check unique key
SHOW CREATE TABLE product_component_slot_spec;
-- Expected: UNIQUE KEY uk_product_anchor_slot (id_product, anchor_slot)

-- Count roles
SELECT COUNT(*) FROM material_role_catalog WHERE is_active = 1;
-- Expected: 8

-- Count fields for MAIN_MATERIAL
SELECT COUNT(*) FROM material_role_field WHERE role_code = 'MAIN_MATERIAL';
-- Expected: >= 1 (minimal fields)

-- Count fields for LINING
SELECT COUNT(*) FROM material_role_field WHERE role_code = 'LINING';
-- Expected: >= 1 (minimal fields)
```

---

### **Patch 2: Validation Service**

**Files to Create:**
1. `source/BGERP/Service/MaterialRoleValidationService.php`
   - `validateRoleConstraints(int $materialId, string $roleCode, array $constraintsJson): array`
   - `validateFieldType(string $fieldType, $value, array $fieldDef): bool`
   - `validateSelectOption(string $value, array $optionsJson): bool`
   - Returns error taxonomy: `missing_required_field`, `invalid_type`, `invalid_option`

**Files to Extend:**
- None (new service)

**Changes:**
- Role-based validation (required fields check)
- Field type validation (number, text, boolean, select, json)
- Select option validation (value ∈ options_json[].value)
- **constraints_json must be object:** Assert `is_array()` and `array_is_list()` = false (reject arrays, stringified JSON)
- Error format matches taxonomy from V3 Concept

**Validation:**
- Unit tests: `tests/Unit/MaterialRoleValidationServiceTest.php`
- Test cases: missing field, invalid type, invalid option, valid constraints

---

### **Patch 3: API Endpoints (BOM CRUD Extension)**

**Files to Extend:**
1. `source/product_api.php`
   - Extend `handleAddComponentMaterial()`: accept `role_code`, `constraints_json`
   - Extend `handleUpdateComponentMaterial()`: accept `role_code`, `constraints_json` (currently empty)
   - Add audit logging: call `ProductReadinessService::logConfigChange()` on constraints update

2. `source/BGERP/Service/ProductComponentService.php`
   - Extend `addMaterial()`: accept `role_code`, `constraints_json`
   - Extend `updateMaterial()`: accept `role_code`, `constraints_json`
   - Validate constraints using `MaterialRoleValidationService`

**New Endpoints:**
1. `list_material_roles` → `handleListMaterialRoles()`
   - Returns: `material_role_catalog` filtered by `applies_to_line` (if product is hatthasilpa/classic)
   
2. `list_role_fields` → `handleListRoleFields()`
   - Input: `role_code` (required)
   - Returns: `material_role_field` for role (for data-driven UI)

**Changes:**
- BOM CRUD accepts `role_code` (defaults to 'MAIN_MATERIAL' if not provided)
- BOM CRUD accepts `constraints_json` (validated via `MaterialRoleValidationService`)
- **constraints_json handling:** If received as string → decode, then assert is object (not array)
- Audit log writes on `role_code` or `constraints_json` change
- **Audit log keys (required):**
  - `id_product` (required)
  - `id_product_component` (required)
  - `id_product_component_material` (required, material line ID)
  - `config_type` = 'v3_bom_role_change' or 'v3_bom_constraints_change'
  - `old_value` / `new_value` (JSON) OR `before_hash` / `after_hash` + `diff`
- Error responses use error taxonomy: `V3_MISSING_FIELD`, `V3_INVALID_TYPE`, `V3_INVALID_OPTION`
- **Error response shape:** `errors[]` each has: `{type, code, field_key?, message}`. If role invalid/missing → `field_key=null`

**Validation:**
- API tests: `tests/Integration/ProductBOMV3ApiTest.php`
- Test cases: add material with role, update constraints, validation errors, audit log

---

### **Patch 4: UI Updates (BOM Table + Configure Modal)**

**Files to Extend:**
1. `views/products.php`
   - BOM table: Add "Role" column (dropdown)
   - BOM table: Add "Configure" button per line
   - BOM table: Add status badge (✅ complete / ⚠ incomplete)
   - Deprecate slot-level constraints section: Remove OR make read-only summary

2. `assets/javascripts/products/product_components.js`
   - `loadComponentForEdit()`: Load BOM with role + constraints
   - `handleBOMRoleChange()`: On role change, load role fields
   - `handleConfigureConstraints()`: Open data-driven modal
   - `renderConstraintsForm()`: Generate form from `material_role_field` API response
   - `saveBOMLineConstraints()`: Save `role_code` + `constraints_json`
   - `validateBOMLineConstraints()`: Check required fields + types
   - `updateBOMStatusBadge()`: Show ✅/⚠ based on validation

**New Files:**
1. `assets/javascripts/products/material_role_constraints.js` (optional, if logic is large)
   - Encapsulate role-based constraints UI logic

**Changes:**
- BOM table shows role dropdown (populated from `list_material_roles` API)
- Configure button opens modal with data-driven form (from `list_role_fields` API)
- Form fields render based on `field_type` (number, text, boolean, select, json)
- Validation errors display using error taxonomy
- Status badge reflects validation state (complete/incomplete)
- Slot-level constraints section: **removed** OR **read-only summary only**

**Validation:**
- Manual test: Edit component → BOM table shows role + configure
- Manual test: Configure modal is data-driven (not hardcoded)
- Manual test: Slot-level constraints section is gone or read-only

---

### **Patch 5: Legacy Deprecation Guard**

**Files to Create:**
1. `scripts/dev/check_legacy_writes.php` (DEV-only)
   - Grep patterns (must catch all cases):
     - `UPDATE.*product_config_component_slot`
     - `INSERT.*product_config_component_slot`
     - `REPLACE.*product_config_component_slot`
     - Multi-line patterns (heredoc/nowdoc): Use broader pattern `product_config_component_slot` with context lines
   - Report violations (must be empty or only `__legacy_migration_only`)

**Files to Extend:**
- None (guard script only)

**Changes:**
- Machine-checkable rule: No production code writes to `product_config_component_slot`
- Migration scripts must have `__legacy_migration_only` label + guard

**Validation:**
- Run guard script: `php scripts/dev/check_legacy_writes.php`
- Expected: No violations (or only migration scripts with label)

---

## 📊 Implementation Order

**Recommended Order:**
1. **Patch 1** (Database) → Foundation
2. **Patch 2** (Validation Service) → Reusable by API
3. **Patch 3** (API) → Backend complete
4. **Patch 4** (UI) → Frontend complete
5. **Patch 5** (Legacy Guard) → Safety net

**Alternative Order (if parallel work):**
- Patch 1 + Patch 2 (can be done in parallel)
- Patch 3 (depends on Patch 1 + 2)
- Patch 4 (depends on Patch 3)
- Patch 5 (can be done anytime)

---

## ✅ Definition of Done (Per Patch)

### Patch 1 (Database)
- [ ] Migrations run cleanly (no errors)
- [ ] Role + field seed data present (8 roles + MAIN_MATERIAL/LINING fields)
- [ ] FK integrity enforced (`material_role_field.role_code` → `material_role_catalog.role_code`)
- [ ] `product_component_material.role_code` = NOT NULL DEFAULT 'MAIN_MATERIAL'
- [ ] `product_component_slot_spec` table exists (slot properties only)

### Patch 2 (Validation Service)
- [ ] `MaterialRoleValidationService` validates required fields
- [ ] `MaterialRoleValidationService` validates field types
- [ ] `MaterialRoleValidationService` validates select options
- [ ] Error taxonomy matches: `missing_required_field`, `invalid_type`, `invalid_option`
- [ ] Unit tests pass (80%+ coverage)

### Patch 3 (API)
- [ ] BOM CRUD supports `role_code` + `constraints_json`
- [ ] `list_material_roles` endpoint returns roles filtered by `applies_to_line`
- [ ] `list_role_fields` endpoint returns fields for role (data-driven)
- [ ] Validation errors follow error taxonomy
- [ ] Audit log writes on `role_code` or `constraints_json` change
- [ ] Integration tests pass

### Patch 4 (UI)
- [ ] BOM table shows role dropdown + configure button
- [ ] Configure modal is fully data-driven (from `material_role_field` API)
- [ ] Status badge reflects validation state (✅/⚠)
- [ ] Slot-level constraints section: **removed** OR **read-only summary**
- [ ] Manual test: Edit component → BOM → Configure → Save works

### Patch 5 (Legacy Guard)
- [ ] Guard script runs without violations
- [ ] Migration scripts have `__legacy_migration_only` label + guard
- [ ] No production code writes to `product_config_component_slot`

---

## 🚫 What We MUST NOT Build

- ❌ Slot-level constraint tables (v2, v3, renamed, disguised)
- ❌ Component-level constraint blobs
- ❌ Hardcoded constraint forms per role
- ❌ New `material_specification` fields
- ❌ Silent fallback to legacy tables

---

## 🔍 Evidence Requirements

**Every patch must include:**
- File paths + line numbers for changes
- Evidence that invariants are not violated
- Evidence that legacy table is not written to (except migration)
- Test results (unit/integration/manual)

---

## ⚠️ Risk Mitigation

**Risk 1: Breaking existing BOM CRUD**
- **Mitigation:** Additive-only changes, default `role_code='MAIN_MATERIAL'`, `constraints_json` nullable

**Risk 2: UI hardcodes fields**
- **Mitigation:** Enforce data-driven UI (form generated from API), code review checklist

**Risk 3: Legacy table still used**
- **Mitigation:** Guard script (Patch 5), code review, grep checks

**Risk 4: Validation errors not user-friendly**
- **Mitigation:** Error taxonomy standardized, UI displays clear messages

---

## 📝 Next Steps

1. **Review this plan** (stakeholder approval)
2. **Start Patch 1** (database migrations)
3. **Implement sequentially** (Patch 1 → 2 → 3 → 4 → 5)
4. **Test after each patch** (unit + integration + manual)
5. **Document changes** (CHANGELOG.md, STATUS.md)

---

**End of Patch Plan**


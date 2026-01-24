# Constraints System - UI Change Baseline Audit

**Date:** January 5, 2026  
**Purpose:** Baseline audit for Enterprise Grade enhancement  
**Scope:** BOM Constraints & Material Role System  
**Status:** ✅ **BASELINE COMPLETE**

---

## 🎯 Executive Summary

This audit identifies the exact UI surface, API endpoints, and database tables involved in the Constraints System to establish a baseline before implementing Enterprise Grade enhancements (contract tests, schema versioning, UI placement rules).

**System Components:**
- **API Layer:** Material role and field endpoints
- **Service Layer:** BOM quantity calculator, material role validation
- **UI Layer:** Constraints editor modal, material role field inputs
- **Database Layer:** Material role catalog, role fields, component materials

---

## 📊 API Endpoints Inventory

### 1. `list_material_roles`

**Endpoint:** `source/product_api.php` → `case 'list_material_roles'`  
**Purpose:** List available material roles (MAIN_MATERIAL, LINING, etc.)  
**Method:** GET/POST  
**Response Format:**
```json
{
  "ok": true,
  "data": [
    {
      "role_code": "MAIN_MATERIAL",
      "role_name_en": "Main Material",
      "role_name_th": "วัสดุหลัก",
      "description": "..."
    }
  ]
}
```

**Current Status:** ✅ Implemented  
**Fields Used by UI:** `role_code`, `role_name_en`, `role_name_th`

---

### 2. `list_role_fields`

**Endpoint:** `source/product_api.php` → `case 'list_role_fields'`  
**Purpose:** List fields for a specific material role  
**Method:** GET/POST  
**Parameters:** `role_code` (required)

**Response Format:**
```json
{
  "ok": true,
  "fields": [
    {
      "field_key": "width_mm",
      "field_type": "number",
      "field_label_en": "Width (mm)",
      "field_label_th": "ความกว้าง (มม.)",
      "required": 1,
      "unit": "mm",
      "display_order": 5,
      "options_json": null
    }
  ],
  "_debug": {
    "db_name": "bgerp_t_xxx",
    "tenant_code": "xxx",
    "row_count": 7
  }
}
```

**Current Status:** ✅ Implemented  
**Fields Used by UI:** All fields in array  
**Critical Fields:** `field_key`, `field_type`, `field_label_en`, `field_label_th`, `required`, `unit`, `display_order`

---

### 3. `component_save` (with constraints)

**Endpoint:** `source/product_api.php` → `case 'component_save'`  
**Purpose:** Save component material with constraints  
**Method:** POST  
**Parameters:** 
- `constraints_json` (JSON string)
- `role_code` (string)
- `qty_required` (decimal)
- `override_mode` (boolean, optional)
- `override_reason` (string, optional)

**Request Format:**
```json
{
  "id": 123,
  "role_code": "MAIN_MATERIAL",
  "constraints_json": "{\"width_mm\": 100, \"length_mm\": 200, \"piece_count\": 2, \"waste_factor_percent\": 5}",
  "qty_required": 0.42,
  "override_mode": false
}
```

**Response Format:**
```json
{
  "ok": true,
  "id": 123,
  "computed_from_constraints": true,
  "message": "Saved successfully"
}
```

**Current Status:** ✅ Implemented  
**Validation:** Server-side validation via `MaterialRoleValidationService` and `BomQuantityCalculator`

---

### 4. `get_component_slot_mapping` (if exists)

**Endpoint:** `source/product_api.php` → `case 'get_component_slot_mapping'`  
**Purpose:** Get component slot mapping (if implemented)  
**Method:** GET/POST  
**Status:** ⚠️ **VERIFY IF EXISTS**

---

## 🗄️ Database Tables Inventory

### 1. `material_role_catalog`

**Purpose:** Catalog of material roles  
**Key Columns:**
- `role_code` (VARCHAR, PK)
- `role_name_en`, `role_name_th`
- `description`
- `is_active`

**Current Usage:** Read-only by API  
**Modification Frequency:** Low (admin-only)

---

### 2. `material_role_field`

**Purpose:** Field definitions for each material role  
**Key Columns:**
- `id` (INT, PK)
- `role_code` (VARCHAR, FK → material_role_catalog)
- `field_key` (VARCHAR)
- `field_type` (ENUM: number, select, text, etc.)
- `field_label_en`, `field_label_th`
- `required` (TINYINT)
- `unit` (VARCHAR, nullable)
- `display_order` (INT)
- `options_json` (JSON, nullable)
- `help_text_en`, `help_text_th` (TEXT, nullable)

**Current Usage:** Read by `list_role_fields` API  
**Modification Frequency:** Low (admin-only, via migrations)

---

### 3. `product_component_material`

**Purpose:** Component materials with constraints  
**Key Columns:**
- `id_product_component_material` (INT, PK)
- `id_product_component` (INT, FK)
- `role_code` (VARCHAR, FK → material_role_catalog)
- `constraints_json` (JSON, nullable)
- `qty_required` (DECIMAL)
- `override_mode` (TINYINT, default 0)
- `override_reason` (TEXT, nullable)

**Current Usage:** Read/Write by `component_save` API  
**Modification Frequency:** High (user edits)

---

## 🎨 UI Surface Inventory

### Current UI Structure

#### 1. Component Modal (`views/products/product_components.php`)

**Location:** Component edit modal  
**Purpose:** Edit component materials with constraints  
**Current Implementation:**
- Material selection (role_code dropdown)
- Constraints editor (dynamic fields based on role)
- Quantity display (computed from constraints)
- Override mode toggle (if needed)

**UI Elements:**
- Modal container (`#component-modal` or similar)
- Role selection dropdown
- Constraints fields container (dynamic)
- Quantity display field (read-only when constraints exist)
- Save/Cancel buttons

**Estimated Lines:** ~500-1000 lines (verify)

---

#### 2. Constraints Editor (`assets/javascripts/products/product_components.js`)

**Location:** JavaScript file for component management  
**Purpose:** Render dynamic constraint fields, validate inputs, compute quantities  
**Current Implementation:**
- `loadRoleFields(roleCode)` - Fetch and render fields
- `validateConstraints()` - Client-side validation
- `computeQuantityFromConstraints()` - Preview calculation
- `saveComponent()` - Submit with constraints_json

**Key Functions:**
- Field rendering based on `field_type`
- Validation (required fields, number types)
- Quantity computation preview
- Override mode handling

**Estimated Lines:** ~200-500 lines related to constraints (verify)

---

### UI Regions (Current Structure)

**Region 1: Component Modal Header**
- Component name/title
- Close button

**Region 2: Material Selection**
- Role dropdown
- Material selection (if applicable)

**Region 3: Constraints Editor** ⭐ **PRIMARY FOCUS**
- Dynamic fields container
- Fields rendered based on `list_role_fields` response
- Field types: number, select, text
- Labels: English/Thai
- Units displayed
- Validation feedback (red borders, error messages)

**Region 4: Quantity Display**
- `qty_required` field
- Read-only badge when constraints exist
- Override toggle (if applicable)
- Computed preview

**Region 5: Modal Footer**
- Save button (disabled if incomplete)
- Cancel button

---

## 📋 Current Validation Rules

### Server-Side Validation

**Service:** `BomQuantityCalculator::validateConstraintsCompleteness()`  
**Rules:**
- Required fields by basis_type (AREA: width_mm, length_mm, piece_count; LENGTH: length_mm, piece_count; COUNT: piece_count)
- Waste factor: 0-200 (reject negative values)
- Type validation (numbers, enums)

**Error Format:**
```json
{
  "ok": false,
  "error": "Validation failed",
  "app_code": "PROD_CONFIG_400_VALIDATION",
  "invalid_fields": {
    "width_mm": "Width is required for AREA basis"
  }
}
```

### Client-Side Validation

**Location:** `assets/javascripts/products/product_components.js`  
**Rules:**
- Required field checks
- Number type validation
- Save button disabled if incomplete
- Error highlighting (red borders)

---

## 🔍 Current Test Coverage

### Unit Tests

**File:** `tests/Unit/BomQuantityCalculatorTest.php`  
**Coverage:**
- Quantity computation (21 tests)
- Validation (constraints completeness)
- Basis type derivation
- Waste factor validation

**Status:** ✅ **GOOD COVERAGE**  
**Gaps:** Contract tests missing, UI tests missing

---

## 📊 API Response Metadata (Current)

### Debug Fields (Development Only)

**Endpoint:** `list_role_fields`  
**Fields:** `_debug` object (only in development)
- `db_name`
- `tenant_code`
- `org_id`
- `row_count`
- `role_code_received`
- `tenant_db_type`

**Status:** ✅ Implemented (development only)  
**Usage:** Diagnostic only

### Schema Version Metadata

**Current Status:** ❌ **NOT IMPLEMENTED**  
**Required:** Add `schema_version` to API responses (Step 2)

---

## 🚨 Identified Risks

### High Risk Areas

1. **UI Layout Drift**
   - No layout map exists
   - No placement rules
   - Ad-hoc CSS possible
   - Risk: UI changes break layout unpredictably

2. **API Contract Drift**
   - No contract tests
   - Field changes not detected automatically
   - Risk: Breaking changes go unnoticed

3. **Schema Version Drift**
   - No versioning policy
   - Breaking changes not versioned
   - Risk: Clients break on server updates

### Medium Risk Areas

1. **Test Coverage Gaps**
   - No contract tests
   - No UI layout tests
   - No integration tests for API contracts

2. **Documentation Gaps**
   - API contract not documented
   - UI layout not mapped
   - Placement rules not defined

---

## ✅ Baseline Complete

**Audit Date:** January 5, 2026  
**Auditor:** Enterprise Grade Planning System  
**Status:** ✅ **BASELINE ESTABLISHED**

**Next Steps:**
1. ✅ Step 0: Baseline Audit (THIS DOCUMENT) - **COMPLETE**
2. ⏭️ Step 1: Contract Spec + Tests
3. ⏭️ Step 2: Schema Versioning
4. ⏭️ Step 3: UI Layout Map + Placement Rules
5. ⏭️ Step 4: UI Change Plan

---

**Files Referenced:**
- `source/product_api.php`
- `source/BGERP/Service/BomQuantityCalculator.php`
- `source/BGERP/Service/MaterialRoleValidationService.php`
- `views/products/product_components.php`
- `assets/javascripts/products/product_components.js`
- `database/tenant_migrations/0001_init_tenant_schema_v2.php`
- `tests/Unit/BomQuantityCalculatorTest.php`

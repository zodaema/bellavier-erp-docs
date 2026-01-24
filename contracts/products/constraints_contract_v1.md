# Product Constraints API Contract v1

**Version:** v1  
**Date:** January 5, 2026  
**Status:** ✅ **LOCKED - Contract Specification**  
**Purpose:** API contract specification for Constraints System endpoints  
**Scope:** Material roles, role fields, and component material constraints

---

## 📋 Overview

This contract locks the API request/response shapes for the Constraints System to prevent breaking changes and ensure backward compatibility.

**Owned Endpoints:**
1. `list_material_roles` - List available material roles
2. `list_role_fields` - List fields for a specific role
3. `component_save` (add/update with constraints) - Save component material with constraints
4. `get_component_slot_mapping` - Get component slot mapping (verify if exists)

**Contract Rules:**
- Field names and types are locked
- Response structure is locked
- Error format is locked
- Breaking changes require version bump (v1 → v2)

---

## 1. list_material_roles

### Request

**Method:** GET or POST  
**Action:** `list_material_roles`

**Parameters:**
- `applies_to_line` (optional, string): Filter by production line ('classic', 'hatthasilpa', 'both')
- `include_inactive` (optional, integer): Include inactive roles (0 or 1, default 0)

**Example:**
```
GET source/product_api.php?action=list_material_roles&applies_to_line=hatthasilpa
POST source/product_api.php
  action=list_material_roles
  applies_to_line=hatthasilpa
```

---

### Response (Success)

**HTTP Status:** 200  
**Content-Type:** `application/json`

```json
{
  "ok": true,
  "roles": [
    {
      "role_code": "MAIN_MATERIAL",
      "name_en": "Main Material",
      "name_th": "วัสดุหลัก",
      "applies_to_line": "both",
      "display_order": 0,
      "is_active": 1
    },
    {
      "role_code": "LINING",
      "name_en": "Lining",
      "name_th": "ผ้าซับใน",
      "applies_to_line": "both",
      "display_order": 1,
      "is_active": 1
    }
  ]
}
```

---

### Response Schema (Success)

| Field | Type | Required | Nullable | Notes |
|-------|------|----------|----------|-------|
| `ok` | boolean | ✅ Yes | ❌ No | Must be `true` |
| `roles` | array | ✅ Yes | ❌ No | Array of role objects (may be empty `[]`) |
| `roles[].role_code` | string | ✅ Yes | ❌ No | Unique role identifier (e.g., 'MAIN_MATERIAL') |
| `roles[].name_en` | string | ✅ Yes | ❌ No | English name |
| `roles[].name_th` | string | ✅ Yes | ❌ No | Thai name |
| `roles[].applies_to_line` | string | ✅ Yes | ❌ No | Enum: 'classic', 'hatthasilpa', 'both' |
| `roles[].display_order` | integer | ✅ Yes | ❌ No | Display order (0-based) |
| `roles[].is_active` | integer | ✅ Yes | ❌ No | 0 or 1 (boolean as int) |

---

### Response (Error)

**HTTP Status:** 400, 401, 500  
**Content-Type:** `application/json`

```json
{
  "ok": false,
  "error": "Failed to list material roles",
  "app_code": "PROD_500_LIST_ROLES"
}
```

---

### Response Schema (Error)

| Field | Type | Required | Nullable | Notes |
|-------|------|----------|----------|-------|
| `ok` | boolean | ✅ Yes | ❌ No | Must be `false` |
| `error` | string | ✅ Yes | ❌ No | Error message (translatable) |
| `app_code` | string | ✅ Yes | ❌ No | Application error code |

---

### Compatibility Notes

- `roles` array may be empty `[]` if no roles match filter
- `is_active` is integer (0/1), not boolean (locked for consistency)
- Response is ordered by `display_order ASC, role_code ASC`

---

## 2. list_role_fields

### Request

**Method:** GET or POST  
**Action:** `list_role_fields`

**Parameters:**
- `role_code` (required, string): Material role code (e.g., 'MAIN_MATERIAL')

**Example:**
```
GET source/product_api.php?action=list_role_fields&role_code=MAIN_MATERIAL
POST source/product_api.php
  action=list_role_fields
  role_code=MAIN_MATERIAL
```

---

### Response (Success)

**HTTP Status:** 200  
**Content-Type:** `application/json`

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
    },
    {
      "field_key": "length_mm",
      "field_type": "number",
      "field_label_en": "Length (mm)",
      "field_label_th": "ความยาว (มม.)",
      "required": 1,
      "unit": "mm",
      "display_order": 6,
      "options_json": null
    },
    {
      "field_key": "grain_direction",
      "field_type": "select",
      "field_label_en": "Grain Direction",
      "field_label_th": "ทิศทางลาย",
      "required": 0,
      "unit": null,
      "display_order": 20,
      "options_json": [
        {"value": "parallel", "label": "Parallel"},
        {"value": "perpendicular", "label": "Perpendicular"}
      ]
    }
  ],
  "_debug": {
    "db_name": "bgerp_t_xxx",
    "tenant_code": "xxx",
    "org_id": 1,
    "row_count": 7,
    "role_code_received": "MAIN_MATERIAL",
    "tenant_db_type": "mysqli"
  }
}
```

---

### Response Schema (Success)

| Field | Type | Required | Nullable | Notes |
|-------|------|----------|----------|-------|
| `ok` | boolean | ✅ Yes | ❌ No | Must be `true` |
| `fields` | array | ✅ Yes | ❌ No | Array of field objects (may be empty `[]`) |
| `fields[].field_key` | string | ✅ Yes | ❌ No | Field identifier (e.g., 'width_mm', 'piece_count') |
| `fields[].field_type` | string | ✅ Yes | ❌ No | Enum: 'text', 'number', 'select', 'boolean', 'json' |
| `fields[].field_label_en` | string | ✅ Yes | ❌ No | English label |
| `fields[].field_label_th` | string | ✅ Yes | ❌ No | Thai label |
| `fields[].required` | integer | ✅ Yes | ❌ No | 0 or 1 (boolean as int) |
| `fields[].unit` | string | ✅ No | ✅ Yes | Unit string (e.g., 'mm', 'pcs', '%') or `null` |
| `fields[].display_order` | integer | ✅ Yes | ❌ No | Display order (0-based) |
| `fields[].options_json` | array\|null | ✅ No | ✅ Yes | Options array for 'select' type, or `null` |
| `fields[].options_json[].value` | string | ✅ Yes* | ❌ No | *Required if options_json is array |
| `fields[].options_json[].label` | string | ✅ Yes* | ❌ No | *Required if options_json is array |
| `_debug` | object | ❌ No | ✅ Yes | **DEV-ONLY** (non-contract, may be absent) |
| `_debug.db_name` | string | ❌ No | ✅ Yes | **DEV-ONLY** |
| `_debug.tenant_code` | string | ❌ No | ✅ Yes | **DEV-ONLY** |
| `_debug.org_id` | integer | ❌ No | ✅ Yes | **DEV-ONLY** |
| `_debug.row_count` | integer | ❌ No | ✅ Yes | **DEV-ONLY** |
| `_debug.role_code_received` | string | ❌ No | ✅ Yes | **DEV-ONLY** |
| `_debug.tenant_db_type` | string | ❌ No | ✅ Yes | **DEV-ONLY** |

---

### Response (Error)

**HTTP Status:** 400, 401, 500  
**Content-Type:** `application/json`

**Example 1: Missing role_code**
```json
{
  "ok": false,
  "error": "Role code is required",
  "app_code": "PROD_400_MISSING_ROLE_CODE"
}
```

**Example 2: Invalid role_code**
```json
{
  "ok": false,
  "error": "Invalid or inactive role code",
  "app_code": "PROD_400_INVALID_ROLE_CODE"
}
```

---

### Response Schema (Error)

| Field | Type | Required | Nullable | Notes |
|-------|------|----------|----------|-------|
| `ok` | boolean | ✅ Yes | ❌ No | Must be `false` |
| `error` | string | ✅ Yes | ❌ No | Error message (translatable) |
| `app_code` | string | ✅ Yes | ❌ No | Application error code |

---

### Compatibility Notes

- `fields` array may be empty `[]` if role has no fields defined
- `required` is integer (0/1), not boolean (locked for consistency)
- `unit` is `null` for non-number fields (e.g., select, text, boolean)
- `options_json` is `null` for non-select fields, or array for select fields
- `_debug` object is **DEV-ONLY** (non-contract):
  - ✅ Contract tests must allow `_debug` to exist or be absent
  - ❌ UI code must NOT depend on `_debug` fields
  - ❌ Contract tests must NOT assert `_debug` structure/value
- Response is ordered by `display_order ASC, field_key ASC`

---

## 3. component_save (with constraints)

### Request

**Method:** POST  
**Action:** `add_component_material` or `update_component_material`

**Parameters:**

**For add_component_material:**
- `component_id` (required, integer): Component ID
- `material_sku` (required, string): Material SKU
- `role_code` (optional, string): Material role code (default: 'MAIN_MATERIAL')
- `constraints_json` (optional, string): JSON string of constraints object `{}`
- `qty_required` (optional, decimal): Quantity required (default: 1.0)
- `uom_code` (optional, string): UoM code
- `is_primary` (optional, integer): 0 or 1 (default: 1)
- `priority` (optional, integer): Priority (default: 1)
- `notes` (optional, string): Notes
- `override_mode` (optional, boolean): Enable override mode (default: false)
- `override_reason` (optional, string): Override reason (required if override_mode=true)

**For update_component_material:**
- `material_id` (required, integer): Material ID (id_pcm)
- `role_code` (optional, string): Material role code
- `constraints_json` (optional, string\|null): JSON string of constraints object `{}` or `null`
- `qty_required` (optional, decimal): Quantity required
- `override_mode` (optional, boolean): Enable override mode
- `override_reason` (optional, string): Override reason (required if override_mode=true)
- (Other fields same as add)

**Example (add_component_material):**
```json
POST source/product_api.php
{
  "action": "add_component_material",
  "component_id": 123,
  "material_sku": "LEATHER-001",
  "role_code": "MAIN_MATERIAL",
  "constraints_json": "{\"width_mm\": 100, \"length_mm\": 200, \"piece_count\": 2, \"waste_factor_percent\": 5}",
  "qty_required": 0.42
}
```

---

### Response (Success)

**HTTP Status:** 200  
**Content-Type:** `application/json`

```json
{
  "ok": true,
  "id": 456,
  "computed_from_constraints": true,
  "qty_required": 0.42,
  "message": "Material added successfully"
}
```

---

### Response Schema (Success)

| Field | Type | Required | Nullable | Notes |
|-------|------|----------|----------|-------|
| `ok` | boolean | ✅ Yes | ❌ No | Must be `true` |
| `id` | integer | ✅ Yes | ❌ No | Created/updated material ID (id_pcm) |
| `computed_from_constraints` | boolean | ✅ Yes | ❌ No | `true` if qty computed from constraints, `false` if override |
| `qty_required` | number | ✅ No | ✅ Yes | Computed quantity (float/decimal) or `null` |
| `message` | string | ✅ Yes | ❌ No | Success message (translatable) |

---

### Response (Validation Error)

**HTTP Status:** 400  
**Content-Type:** `application/json`

**Example: Invalid constraints_json format**
```json
{
  "ok": false,
  "error": "Invalid constraints_json format",
  "app_code": "V3_INVALID_TYPE",
  "errors": [
    {
      "type": "invalid_type",
      "code": "V3_INVALID_TYPE",
      "field_key": null,
      "message": "constraints_json must be a valid JSON object"
    }
  ]
}
```

**Example: Validation failed (incomplete constraints)**
```json
{
  "ok": false,
  "error": "Validation failed",
  "app_code": "V3_VALIDATION_FAILED",
  "errors": [
    {
      "type": "missing_field",
      "code": "V3_REQUIRED_FIELD",
      "field_key": "width_mm",
      "message": "Width is required for AREA basis"
    },
    {
      "type": "invalid_value",
      "code": "V3_INVALID_VALUE",
      "field_key": "waste_factor_percent",
      "message": "Waste factor cannot be negative (must be >= 0)"
    }
  ],
  "invalid_fields": {
    "width_mm": "Width is required for AREA basis",
    "waste_factor_percent": "Waste factor cannot be negative (must be >= 0)"
  }
}
```

---

### Response Schema (Validation Error)

| Field | Type | Required | Nullable | Notes |
|-------|------|----------|----------|-------|
| `ok` | boolean | ✅ Yes | ❌ No | Must be `false` |
| `error` | string | ✅ Yes | ❌ No | Error message (translatable) |
| `app_code` | string | ✅ Yes | ❌ No | Application error code (e.g., 'V3_VALIDATION_FAILED', 'V3_INVALID_TYPE') |
| `errors` | array | ✅ No | ✅ Yes | Array of error detail objects (may be present) |
| `errors[].type` | string | ✅ No | ❌ No | Error type (e.g., 'missing_field', 'invalid_value', 'invalid_type') |
| `errors[].code` | string | ✅ No | ❌ No | Error code |
| `errors[].field_key` | string\|null | ✅ No | ✅ Yes | Field key that failed validation, or `null` |
| `errors[].message` | string | ✅ No | ❌ No | Error message |
| `invalid_fields` | object | ✅ No | ✅ Yes | Object with field_key → error message mapping (may be present) |
| `invalid_fields.*` | string | ✅ Yes* | ❌ No | *Each key is a field_key, value is error message |

---

### Response (Other Errors)

**HTTP Status:** 400, 404, 500  
**Content-Type:** `application/json`

**Example: Material not found (update only)**
```json
{
  "ok": false,
  "error": "Material not found",
  "app_code": "PROD_404_MATERIAL_NOT_FOUND"
}
```

**Example: Missing material_id (update only)**
```json
{
  "ok": false,
  "error": "Material ID is required",
  "app_code": "PROD_400_MISSING_MATERIAL_ID"
}
```

---

### Compatibility Notes

- `constraints_json` must be valid JSON object `{}` (not array `[]`, not stringified twice)
- `constraints_json` may be `null` or empty string (treated as `null`)
- `computed_from_constraints` is `false` when `override_mode=true`
- `qty_required` in response is the computed/override value (may differ from request)
- `errors` array may be present or absent (depends on validation service)
- `invalid_fields` object may be present or absent (depends on validation service)
- When both `errors` and `invalid_fields` present, `invalid_fields` is the canonical source for UI display

---

## 4. get_component_slot_mapping

**Status:** ✅ **PRESENT** (but not used in Constraints System)

**As of January 5, 2026:**
- Endpoint handler exists: `handleGetComponentSlotMapping()`
- Switch case exists: `case 'get_component_slot_mapping'`
- **Usage:** Used for component slot mapping (separate from constraints)
- **Scope:** This endpoint is NOT part of Constraints System contract
- **Decision:** Exclude from Constraints contract (different domain)

**Contract Scope:**
- This endpoint is NOT included in Constraints contract v1
- Constraints contract covers: `list_material_roles`, `list_role_fields`, `component_save` only
- `get_component_slot_mapping` may be covered in separate contract (Component Mapping domain)

---

**Note:** If `get_component_slot_mapping` becomes relevant to Constraints System in future, create v2 contract or separate contract document.

---

## 🔒 Breaking Change Definition

A change is considered **BREAKING** if any of the following occurs:

1. **Field Removal:**
   - Removing a required field (e.g., removing `ok`, `fields`, `roles`)
   - Removing a field that UI depends on (e.g., removing `field_key` from fields[])

2. **Field Rename:**
   - Changing field name without version bump/adapter (e.g., `fields` → `data`, `roles` → `items`)

3. **Type Change:**
   - Changing field type (e.g., `string` → `number`, `array` → `object`)
   - Changing integer to boolean or vice versa (e.g., `required: 1` → `required: true`)

4. **Structure Change:**
   - Changing root key (e.g., `fields` → `data.fields`)
   - Changing array to object or vice versa
   - Removing array items structure (e.g., fields[] items lose required fields)

5. **Error Format Change:**
   - Removing `invalid_fields` object when UI depends on it
   - Changing error code format without version bump

6. **Required/Optional Change:**
   - Making required field optional (e.g., `ok` becomes optional)
   - Making optional field required (e.g., `_debug` becomes required)

**Non-Breaking Changes:**
- Adding new optional fields (e.g., adding `metadata` object)
- Adding new array items (e.g., new role in roles[])
- Changing error messages (if `app_code` stays the same)
- Adding new error codes (new codes, not changing existing ones)

---

## 📝 Version History

| Version | Date | Changes | Breaking |
|---------|------|---------|----------|
| v1 | 2026-01-05 | Initial contract specification | - |

---

## 🔗 Related Documents

- **Baseline Audit:** `docs/super_dag/00-audit/CONSTRAINTS_UI_CHANGE_BASELINE.md`
- **Implementation Plan:** `docs/super_dag/plans/CONSTRAINTS_ENTERPRISE_GRADE_PLAN.md`
- **API Structure Audit:** `docs/API_STRUCTURE_AUDIT.md` (if exists)

---

**Contract Status:** ✅ **LOCKED v1**  
**Last Updated:** January 5, 2026  
**Maintained By:** Enterprise Architecture Team


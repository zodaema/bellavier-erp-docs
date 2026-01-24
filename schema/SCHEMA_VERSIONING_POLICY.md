# Schema Versioning Policy

**Version:** 1.0  
**Date:** January 5, 2026  
**Status:** ✅ **LOCKED - Enterprise Policy**  
**Purpose:** Define schema versioning rules for Constraints System and future systems  
**Scope:** Database schema, API schema, DTO schema

---

## 📋 Overview

This policy defines how schema changes are versioned, classified, and enforced to prevent breaking changes and ensure backward compatibility.

**Core Principle:**
> "No silent breaking change" — Every breaking change requires explicit version bump (v1 → v2) OR a compatibility layer (adapter).

---

## 🎯 Scope

### Database Schema
- Tables: `material_role_catalog`, `material_role_field`, `product_component_material`
- Domain: `products.constraints`
- Version Registry: `app_schema_version` table

### API Schema
- Endpoints: `list_material_roles`, `list_role_fields`, `component_save`
- Domain: `products.constraints`
- Version Format: `products.constraints.v1`, `products.constraints.v2`, etc.
- Surface: `meta.schema_version` in JSON responses

### DTO Schema
- Request/Response shapes (locked by Contract v1)
- Field types, required/optional, nullable rules
- Error format contracts

---

## 🔒 Breaking vs Non-Breaking Changes

### Non-Breaking Changes (v1 stays v1)

**Allowed without version bump:**

1. **Adding Optional Fields:**
   - Adding new top-level keys (e.g., `meta`, `metadata`)
   - Adding new fields to array items (e.g., new field in `fields[]`)
   - Adding new enum values (e.g., new `field_type` value)

2. **Adding Optional Metadata:**
   - Adding `meta.schema_version` (non-breaking addition)
   - Adding `_debug` fields (DEV-ONLY, non-contract)

3. **Expanding Arrays:**
   - Adding new items to `roles[]` array
   - Adding new items to `fields[]` array

4. **Error Message Changes:**
   - Changing error message text (if `app_code` stays the same)
   - Adding new error codes (new codes, not changing existing ones)

5. **Database:**
   - Adding new columns (nullable, with defaults)
   - Adding new indexes
   - Adding new tables (not referenced by existing contracts)

**Example:**
```json
// v1 response (before)
{
  "ok": true,
  "fields": [...]
}

// v1 response (after - non-breaking)
{
  "ok": true,
  "meta": { "schema_version": "products.constraints.v1" },
  "fields": [...]
}
```

---

### Breaking Changes (Requires v1 → v2)

**Requires version bump OR adapter:**

1. **Field Removal:**
   - Removing a required field (e.g., removing `ok`, `fields`, `roles`)
   - Removing a field that UI depends on (e.g., removing `field_key` from `fields[]`)

2. **Field Rename:**
   - Changing field name without version bump/adapter (e.g., `fields` → `data`, `roles` → `items`)

3. **Type Change:**
   - Changing field type (e.g., `string` → `number`, `array` → `object`)
   - Changing integer to boolean or vice versa (e.g., `required: 1` → `required: true`)

4. **Structure Change:**
   - Changing root key (e.g., `fields` → `data.fields`)
   - Changing array to object or vice versa
   - Removing array items structure (e.g., `fields[]` items lose required fields)

5. **Required/Optional Change:**
   - Making required field optional (e.g., `ok` becomes optional)
   - Making optional field required (e.g., `_debug` becomes required)

6. **Error Format Change:**
   - Removing `invalid_fields` object when UI depends on it
   - Changing error code format without version bump

7. **Database:**
   - Removing columns
   - Renaming columns
   - Changing column types (e.g., `VARCHAR` → `INT`)
   - Removing tables
   - Changing foreign key constraints

**Example:**
```json
// v1 response (before)
{
  "ok": true,
  "fields": [...]
}

// v2 response (breaking - requires version bump)
{
  "ok": true,
  "meta": { "schema_version": "products.constraints.v2" },
  "data": { "fields": [...] }  // ← BREAKING: fields → data.fields
}
```

---

## 📊 Version Format

### API Schema Version

**Format:** `{domain}.{subdomain}.v{number}`

**Examples:**
- `products.constraints.v1` - Constraints System v1
- `products.constraints.v2` - Constraints System v2 (breaking changes)
- `products.components.v1` - Components System v1 (future)
- `dag.routing.v1` - DAG Routing System v1 (future)

**Location in Response:**
```json
{
  "ok": true,
  "meta": {
    "schema_version": "products.constraints.v1"
  },
  "fields": [...]
}
```

**Both Success and Error Responses:**
```json
// Success
{
  "ok": true,
  "meta": { "schema_version": "products.constraints.v1" },
  "fields": [...]
}

// Error
{
  "ok": false,
  "meta": { "schema_version": "products.constraints.v1" },
  "error": "...",
  "app_code": "..."
}
```

---

### Database Schema Version

**Format:** Integer (1, 2, 3, ...)

**Registry Table:** `app_schema_version`

**Structure:**
```sql
CREATE TABLE app_schema_version (
  domain_key VARCHAR(100) PRIMARY KEY,
  schema_version INT NOT NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  notes TEXT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Example:**
```sql
INSERT INTO app_schema_version (domain_key, schema_version, notes)
VALUES ('products.constraints', 1, 'Initial Constraints System schema')
ON DUPLICATE KEY UPDATE schema_version = 1, updated_at = NOW();
```

---

## 🔄 Migration Rules

### Database Migrations

**Rule 1: Version Bump on Breaking Changes**
- If migration removes/renames columns → bump `app_schema_version.schema_version`
- If migration changes column types → bump version
- If migration removes tables → bump version

**Rule 2: Non-Breaking Migrations**
- Adding nullable columns → no version bump
- Adding indexes → no version bump
- Adding new tables → no version bump (if not referenced by contracts)

**Rule 3: Migration File Naming**
- Use existing migration naming: `YYYY_MM_description.php`
- Include version bump in migration if breaking:
  ```php
  // At end of migration
  $db->query("
    INSERT INTO app_schema_version (domain_key, schema_version, notes)
    VALUES ('products.constraints', 2, 'Breaking: removed deprecated columns')
    ON DUPLICATE KEY UPDATE schema_version = 2, updated_at = NOW()
  ");
  ```

**Rule 4: Rollback Strategy**
- Keep old migration files (never delete)
- Document rollback procedure in migration file comments
- If breaking change, provide adapter/migration path

---

### API Schema Migrations

**Rule 1: Version Bump on Breaking Changes**
- If response structure changes (breaking) → bump `meta.schema_version`
- If field types change → bump version
- If required fields change → bump version

**Rule 2: Non-Breaking Additions**
- Adding `meta` object → no version bump (v1 stays v1)
- Adding optional fields → no version bump
- Adding new enum values → no version bump

**Rule 3: Adapter Pattern (Optional)**
- If keeping v1 alive alongside v2:
  - Create `mapV2toV1()` adapter function
  - Or use query parameter: `?schema_version=v1` or `?schema_version=v2`
  - Document in API contract

**Rule 4: Deprecation Policy**
- v1 must remain supported for minimum 6 months after v2 release
- Deprecation notice in `meta.deprecated` field:
  ```json
  {
    "ok": true,
    "meta": {
      "schema_version": "products.constraints.v1",
      "deprecated": true,
      "deprecation_date": "2026-07-01",
      "migration_guide": "https://docs.example.com/migration-v1-to-v2"
    }
  }
  ```

---

## 🛡️ Enforcement

### Runtime Checks

**1. API Response Validation:**
- All responses must include `meta.schema_version`
- Version must match domain (e.g., `products.constraints.v1`)
- Both success and error responses must have version

**2. Database Version Registry:**
- `app_schema_version` table must exist
- Domain `products.constraints` must have version row
- Version must match API `meta.schema_version` (e.g., DB version 1 = API v1)

**3. Contract Tests:**
- Contract tests validate `meta.schema_version` exists
- Contract tests validate version format
- Contract tests fail if version missing or incorrect

### Change Detection

**Breaking Change Detection:**
- Contract tests compare against golden fixtures
- If fixture structure changes (breaking) → contract test fails
- Developer must:
  1. Update contract spec to v2
  2. Bump `meta.schema_version` to v2
  3. Bump `app_schema_version.schema_version` to 2
  4. Update golden fixtures to v2
  5. Update contract tests to validate v2

**Non-Breaking Change Detection:**
- Adding optional fields → contract tests allow (allowlist pattern)
- Contract tests validate required fields still present
- Contract tests validate types unchanged

---

## 📝 Version History

### products.constraints Domain

| Version | Date | Changes | Breaking | Notes |
|---------|------|---------|----------|-------|
| v1 | 2026-01-05 | Initial Constraints System | - | Initial contract, DB schema, API endpoints |

---

## 🔗 Related Documents

- **Contract Spec:** `docs/contracts/products/constraints_contract_v1.md`
- **Baseline Audit:** `docs/super_dag/00-audit/CONSTRAINTS_UI_CHANGE_BASELINE.md`
- **Implementation Plan:** `docs/super_dag/plans/CONSTRAINTS_ENTERPRISE_GRADE_PLAN.md`

---

## ✅ Acceptance Criteria

**Step 2 Complete When:**
- [x] Policy document exists and is actionable
- [ ] `meta.schema_version` present in all 3 endpoint responses (success + error)
- [ ] `app_schema_version` table exists with `products.constraints` domain
- [ ] Enforcement tests pass (validate version presence)
- [ ] Contract tests updated to allow `meta` as optional key
- [ ] All tests pass: `vendor/bin/phpunit --testsuite Contract`
- [ ] No UI files touched

---

**Policy Status:** ✅ **LOCKED v1.0**  
**Last Updated:** January 5, 2026  
**Maintained By:** Enterprise Architecture Team

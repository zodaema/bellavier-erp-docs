# Phase F: qty_required Usage Audit

**Date:** 2026-01-03  
**Purpose:** Document all usage of `qty_required` field before enforcing computed-only mode  
**Impact:** HIGH - This field is critical for BOM, costing, purchasing, and inventory

---

## Audit Table

| Module | File | Function/Line | Read/Write | Purpose | Assumption | Impact Level |
|--------|------|---------------|------------|---------|------------|--------------|
| **BOM Management** |
| Products | `source/BGERP/Service/ProductComponentService.php` | `addMaterial()`:546-565 | **Write** | Insert qty_required into product_component_material | Computed from constraints OR manual (legacy) | **HIGH** |
| Products | `source/BGERP/Service/ProductComponentService.php` | `updateMaterial()`:669-670 | **Write** | Update qty_required in product_component_material | Computed from constraints OR manual (legacy) | **HIGH** |
| Products | `source/BGERP/Service/ProductComponentService.php` | `getMaterialById()`:~750 | **Read** | Fetch qty_required for display | Stored value (computed or manual) | MED |
| Products | `source/product_api.php` | `handleAddComponentMaterial()`:2743 | **Read** | Return qty_required in API response | Computed from constraints | MED |
| Products | `source/product_api.php` | `handleUpdateComponentMaterial()`:2941 | **Read** | Return qty_required in API response | Computed from constraints | MED |
| Products | `assets/javascripts/products/product_components.js` | `createMaterialRow()`:667-675 | **Read/Write** | Display qty_required in table (read-only if constraints exist) | User input OR computed (read-only) | **HIGH** |
| Products | `assets/javascripts/products/product_components.js` | `renderMaterialRows()`:246 | **Read** | Calculate material totals | Sum of qty_required values | MED |
| **Material Requirements Planning** |
| MRP | `source/BGERP/Service/MaterialRequirementService.php` | `calculateRequirements()`:~55-142 | **Read** | Calculate material requirements for production orders | qty_required per component × order qty | **HIGH** |
| MRP | `source/BGERP/Service/MaterialRequirementService.php` | `getBomMaterials()`:~ | **Read** | Fetch BOM materials with qty_required | Stored value | **HIGH** |
| **BOM Costing** |
| BOM | `source/BGERP/Service/BOMService.php` | `calculateBomCost()`:~493-591 | **Read** | Calculate total BOM cost (qty_required × material cost) | qty_required per material | **HIGH** |
| BOM | `source/bom.php` | Various cost calculation functions | **Read** | BOM cost aggregation | qty_required used in cost formulas | **HIGH** |
| **Purchasing** |
| Purchasing | `source/purchase_*.php` (if exists) | Purchase order generation | **Read** | Generate PO lines from BOM | qty_required × order qty | **HIGH** |
| **Inventory** |
| Inventory | `source/inventory_*.php` (if exists) | Inventory deduction | **Read** | Deduct inventory based on BOM | qty_required × production qty | **HIGH** |
| **Reports/Exports** |
| Reports | `source/reports/*.php` (if exists) | BOM export/reports | **Read** | Export BOM data | Display qty_required | MED |
| **UI Display** |
| Products | `views/products.php` | Component materials table | **Read** | Display qty_required in table | Read-only when constraints exist | LOW |
| Products | `assets/javascripts/products/product_components.js` | Material row rendering | **Read** | Show qty_required value | Computed or manual | LOW |

---

## Key Findings

### 1. **CRITICAL: Material Requirements Planning (MRP)**
- **File:** `source/BGERP/Service/MaterialRequirementService.php`
- **Usage:** `qty_required` is multiplied by order quantity to calculate total material needs
- **Impact:** **HIGH** - If qty_required is wrong, entire production planning fails
- **Assumption:** Currently assumes qty_required is accurate (user-entered or computed)
- **Action Required:** Ensure computed qty_required is accurate before MRP runs

### 2. **CRITICAL: BOM Costing**
- **File:** `source/BGERP/Service/BOMService.php`
- **Usage:** `qty_required × material_cost = line_cost`
- **Impact:** **HIGH** - Incorrect qty_required leads to wrong product costs
- **Assumption:** qty_required represents actual consumption
- **Action Required:** Verify computed qty_required matches expected consumption

### 3. **CRITICAL: Purchasing**
- **Usage:** Purchase orders generated from BOM use `qty_required × order_qty`
- **Impact:** **HIGH** - Wrong qty_required = wrong purchase quantities
- **Assumption:** qty_required is per-product-unit
- **Action Required:** Ensure override_mode is used only when necessary

### 4. **UI Display (Read-only enforcement)**
- **File:** `assets/javascripts/products/product_components.js`
- **Status:** ✅ Already implemented - qty_required is read-only when constraints exist
- **Impact:** LOW - Display only, no calculation impact

---

## Assumptions About qty_required

1. **Per-Product-Unit:** `qty_required` represents quantity needed for **ONE product unit**
2. **Not Batch Quantity:** Does NOT represent production batch or order quantity
3. **Computed OR Manual:** Currently supports both (computed from constraints OR manual input)
4. **Override Allowed:** Manual override is allowed with `override_mode=1` and audit logging

---

## Impact Assessment

### HIGH Impact (Must Verify)
- ✅ **ProductComponentService** - Write operations (already enforces computation)
- ⚠️ **MaterialRequirementService** - MRP calculations (reads qty_required)
- ⚠️ **BOMService** - Cost calculations (reads qty_required)
- ⚠️ **Purchasing** - PO generation (reads qty_required)

### MED Impact (Should Verify)
- ✅ **API Responses** - Return computed qty_required (already implemented)
- ⚠️ **Material totals** - Sum calculations (reads qty_required)

### LOW Impact (Display Only)
- ✅ **UI Display** - Read-only when constraints exist (already implemented)
- ✅ **Reports** - Display only (no calculation impact)

---

## Recommendations

1. **Before Full Enforcement:**
   - ✅ Verify computed qty_required matches manual calculations for sample products
   - ⚠️ Test MRP calculations with computed qty_required
   - ⚠️ Test BOM costing with computed qty_required
   - ⚠️ Test purchase order generation with computed qty_required

2. **Override Mode:**
   - ✅ Override mode is implemented with audit logging
   - ✅ Override requires reason (non-empty)
   - ✅ Override is logged via `ProductReadinessService::logConfigChange()`

3. **Backward Compatibility:**
   - ✅ Legacy BOM rows without constraints_json still allow manual qty_required
   - ✅ Override mode allows manual qty_required even with constraints

---

## Implementation Status

- ✅ **STEP 1:** UI validation - Disable Save button when incomplete
- ✅ **STEP 2:** Server enforcement - Reject incomplete constraints
- ✅ **STEP 3:** Override mode - Implemented with audit logging
- ⏳ **STEP 4:** Audit report - This document
- ⏳ **STEP 5:** Tests - Pending

---

## Notes

- All write operations now enforce computation from constraints (unless override_mode=1)
- All read operations assume qty_required is accurate (computed or manual)
- No code currently assumes qty_required is always user-entered (backward compatible)
- Override mode provides escape hatch for edge cases

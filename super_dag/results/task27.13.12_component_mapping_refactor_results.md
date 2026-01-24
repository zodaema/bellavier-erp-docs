# Task 27.13.12 - Component Mapping Refactor Results

> **Status:** ✅ COMPLETE  
> **Completed:** 2025-12-06  
> **Developer:** AI Assistant

---

## 📋 Summary

Refactor Component Mapping ให้ใช้ V2 Architecture ที่ mapping ไปยัง `product_component` (Layer 2) แทนที่จะ mapping ไป `component_type_catalog` (Layer 1) โดยตรง

---

## ✅ Completed Items

### 1. Database Migration

**File:** `database/tenant_migrations/2025_12_component_mapping_refactor.php`

**Changes:**
- Added `id_product` column to `graph_component_mapping`
- Added `id_product_component` column to `graph_component_mapping`
- Added unique key `uk_product_graph_slot (id_product, id_graph, anchor_slot)`
- Added `expected_component_type` column to `routing_node`
- Dropped incorrect FK `fk_gcm_component_type`
- Truncated existing mappings (CTO-approved for dev environment)

### 2. Service Updates

**File:** `source/BGERP/Service/ComponentMappingService.php`

**New V2 Methods:**
- `getMappingsForProduct(int $productId, int $graphId)` - Get all mappings for a product
- `setMappingV2(int $productId, int $graphId, string $anchorSlot, int $productComponentId, ...)` - Save mapping
- `removeMappingV2(int $productId, int $graphId, string $anchorSlot)` - Remove mapping
- `validateMappingsCompleteV2(int $productId, int $graphId)` - Check if all slots mapped
- `duplicateMappingsForProduct(int $sourceProductId, int $targetProductId)` - For product duplication

### 3. API Endpoints

**File:** `source/product_api.php`

| Endpoint | Method | Description |
|----------|--------|-------------|
| `get_product_components_for_mapping` | GET | Get product components for dropdown |
| `get_component_mappings_v2` | GET | Get mappings for product + graph |
| `save_component_mapping_v2` | POST | Save a mapping (upsert) |

### 4. UI Updates

**File:** `assets/javascripts/products/product_graph_binding.js`

**Changes:**
- `loadProductComponentsForMapping()` - Fetch Layer 2 components
- `renderComponentMappingTable()` - Show Product Components in dropdown (optgroups)
- `checkDuplicateMappings()` - Real-time duplicate detection
- `showDuplicateWarning()` - Visual feedback (red border + warning)
- Block save if duplicates exist
- Hide Component Mapping tab for Classic products

**File:** `assets/javascripts/products/product_components.js`
- Fixed duplicate optgroup headers in Component Type dropdown

### 5. Product Duplication

**File:** `source/product_api.php` (handleDuplicate function)

**Enhanced to duplicate:**
- ✅ Product base data
- ✅ Product assets (existing)
- ✅ Graph binding (existing)
- ✅ Product components (NEW)
- ✅ Product component materials/BOM (NEW)
- ✅ Graph component mappings (NEW)

**UI:** New modal with checkboxes for selective duplication

---

## 🔧 Architecture

### Before (V1)
```
graph_component_mapping
  ├─ id_graph
  ├─ anchor_slot
  └─ component_code → component_type_catalog (Layer 1)
```

### After (V2)
```
graph_component_mapping
  ├─ id_graph
  ├─ id_product (NEW)
  ├─ anchor_slot
  ├─ id_product_component → product_component (Layer 2) (NEW)
  └─ component_code (derived from product_component)
```

---

## 📁 Files Modified/Created

| File | Action |
|------|--------|
| `database/tenant_migrations/2025_12_component_mapping_refactor.php` | Created |
| `source/BGERP/Service/ComponentMappingService.php` | Updated |
| `source/product_api.php` | Updated |
| `assets/javascripts/products/product_graph_binding.js` | Updated |
| `assets/javascripts/products/product_components.js` | Fixed |

---

## 🔗 Integration Points

1. **Product Configuration** → Component Mapping tab shows product components
2. **Product Duplication** → Copies components, BOM, and mappings
3. **Product Readiness** → Checks mapping completeness (Hatthasilpa only)
4. **Graph Designer** → Uses anchor_slot as placeholder
5. **Token Spawn** → Resolves mapping to get component_code

---

## 🧪 Testing

- ✅ Component Mapping dropdown shows correct components
- ✅ Duplicate detection works real-time
- ✅ Save blocked when duplicates exist
- ✅ Product duplication copies all new elements
- ✅ Classic products: Component Mapping tab hidden
- ✅ Hatthasilpa products: Full mapping workflow

---

## 📝 Notes

- V1 methods deprecated but kept for backward compatibility
- `component_code` still stored for legacy compatibility
- UI uses Select2 for enhanced dropdowns (when available)


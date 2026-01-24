# Task 25.3 Results — Product Module: Phase 1 (Rebuild Foundation)

**Phase:** 25 — Classic Line Stabilization  
**Status:** ✅ **COMPLETED**  
**Date:** 2025-11-29  
**Owner:** System Engineering (Bellavier Group ERP)

---

## 📋 Summary

Task 25.3 เป็นการเริ่มต้น "Product Module Rebuild" โดยวางฐานรากของ Product module ให้สอดคล้องกับหลักคิดใหม่:

> **1 Product = 1 Production Line (classic หรือ hatthasilpa)**  
> **Classic line ไม่ใช้ DAG/Routing Graph ในการวางแผนการผลิต**  
> **DAG/Token/Work Queue เป็นของ Hatthasilpa line เท่านั้น**

---

## ✅ Completed Deliverables

### 1. ProductMetadataResolver Service ✅

**File:** `source/BGERP/Product/ProductMetadataResolver.php`

- ✅ สร้าง service ใหม่สำหรับ resolve product metadata
- ✅ `resolve(int $productId): array` - Resolve metadata ครบถ้วน
- ✅ `loadProduct(int $productId)` - โหลดข้อมูล product หลัก
- ✅ `resolveProductionLine(array $product): string` - Map production_lines SET → 'classic'/'hatthasilpa'
- ✅ `loadRoutingForHatthasilpa(array $product)` - โหลด routing binding (เฉพาะ Hatthasilpa)
- ✅ `assembleMetadata(...)` - สร้าง metadata structure

**Behavior:**
- Classic line: ไม่บังคับ routing, routing = null ถ้าไม่มี
- Hatthasilpa line: โหลด routing binding (ถ้ามี)
- Support `production_lines` SET field ที่มี 'hatthasilpa' หรือ 'oem'/'classic'

### 2. Product API (Central Endpoint) ✅

**File:** `source/product_api.php`

- ✅ สร้าง API กลางสำหรับ Product Page operations
- ✅ `get_metadata` - เรียก ProductMetadataResolver
- ✅ `bind_routing` - Bind graph สำหรับ Hatthasilpa เท่านั้น
- ✅ `unbind_routing` - Unbind graph สำหรับ Hatthasilpa เท่านั้น
- ✅ `get_classic_dashboard` - Proxy ไป product_stats_api.php
- ✅ `update_product_info` - Stub สำหรับ Task 25.4

**Validation:**
- ✅ เช็ก `production_line` ก่อน bind/unbind
- ✅ Error ถ้าพยายาม bind/unbind Classic product
- ✅ ใช้ latest stable version อัตโนมัติ (no version pinning)

### 3. Product Page Refactor ✅

**File:** `views/products.php`

- ✅ ลบ/suppress Pattern Version UI (`product-pattern-versions`)
- ✅ ลบ Graph Version Select จาก binding modal
- ✅ ลบ Default Mode Select (ใช้ production_line จาก product แทน)
- ✅ เปลี่ยน Labels: "Atelier" → "Hatthasilpa", "OEM" → "Classic"
- ✅ เปลี่ยน Values: "atelier" → "hatthasilpa", "oem" → "classic"
- ✅ เปลี่ยน IDs: `edit_production_line_atelier` → `edit_production_line_hatthasilpa`

**Classic Dashboard Tab:**
- ✅ มี Classic Production Overview tab (จาก Task 25.2)
- ✅ Classic line ไม่บังคับให้มี graph binding

### 4. Product Graph Binding Modal Refactor ✅

**File:** `assets/javascripts/products/product_graph_binding.js`

- ✅ ลบ Graph Version Select logic
- ✅ ลบ Version Pinning logic (`loadGraphVersions`, `checkVersionChanges`)
- ✅ ลบ Hybrid Mode (เหลือเฉพาะ hatthasilpa/classic)
- ✅ เปลี่ยน Binding API จาก `products.php` → `product_api.php`
- ✅ เปลี่ยน Form Submission:
  - ใช้ `bind_routing` action (ไม่ใช่ `bind_graph`)
  - ไม่ส่ง `graph_version_pin` (ใช้ latest stable อัตโนมัติ)
  - ไม่ส่ง `default_mode` (ใช้ production_line จาก product)
- ✅ เปลี่ยน Unbind API:
  - ใช้ `unbind_routing` action
  - ส่ง `id_product` (ไม่ใช่ `id_binding`)

---

## 🔧 Technical Details

### Product Model (New Standard)

**Fields ที่ใช้งาน:**
- `id_product`
- `sku`
- `name`
- `production_lines` (SET: 'hatthasilpa', 'oem'/'classic')
- `is_active`
- `id_routing_graph` (nullable, สำหรับ Hatthasilpa)

**Fields ที่ ignore (legacy):**
- `template_version`
- `is_versioned`
- `id_template`
- `id_product_template`

**Note:** Legacy fields ยังอยู่ใน DB (จะลบใน Task 25.6)

### Production Line Mapping

```php
// ProductMetadataResolver::resolveProductionLine()
if (contains 'hatthasilpa') → 'hatthasilpa'
if (contains 'oem' or 'classic') → 'classic'
default → 'classic'
```

### Routing Binding Behavior

**Hatthasilpa:**
- ✅ ต้องมี routing binding (valid = false ถ้าไม่มี)
- ✅ ใช้ latest stable version อัตโนมัติ
- ✅ Bind/Unbind ผ่าน `product_api.php`

**Classic:**
- ✅ ไม่บังคับ routing (routing = null ได้)
- ✅ ไม่ต้อง bind/unbind
- ✅ ใช้ Classic Dashboard แทน

---

## 📁 Files Modified

### New Files Created
1. `source/BGERP/Product/ProductMetadataResolver.php` (211 lines)
2. `source/product_api.php` (315 lines)

### Files Modified
1. `views/products.php`
   - ลบ Pattern Version UI
   - ลบ Graph Version Select
   - ลบ Default Mode Select
   - เปลี่ยน Labels/Values/IDs

2. `assets/javascripts/products/product_graph_binding.js`
   - ลบ Version Pinning logic
   - ลบ Hybrid Mode
   - เปลี่ยน API endpoints
   - Simplify binding form

---

## ✅ Acceptance Criteria Status

| Criteria | Status |
|----------|--------|
| เปิด Product Page → โหลด metadata ผ่าน `product_api.php?action=get_metadata` | ✅ |
| ไม่มี UI ที่เกี่ยวกับ Template Version | ✅ |
| Production Line แสดงชัดเจนว่า Classic/Hatthasilpa | ✅ |
| Classic Products → เปิด Classic Dashboard ได้, ไม่บังคับ graph binding | ✅ |
| Hatthasilpa Products → Graph binding ผ่าน modal ทำงานได้ | ✅ |
| PHP syntax check ผ่าน | ✅ |
| JS ไม่มี error (console warnings only) | ✅ |

---

## 🔮 Next Steps

Task 25.3 เป็น Phase 1 (Foundation) เท่านั้น งานต่อไป:

- **Task 25.4** — Product Creation Flow
  - UI สำหรับสร้าง Product ใหม่
  - เลือก Production Line (Classic/Hatthasilpa)
  - Duplicate → Draft

- **Task 25.5** — Product Index + Filtering
  - หน้า list + filter ตาม line, type, active
  - Search optimization

- **Task 25.6** — DB Cleanup
  - Migration ลบ legacy template/version columns
  - Normalize `production_line` field

---

## 📝 Notes

### Backward Compatibility
- ✅ Legacy fields ยังอยู่ใน DB (ไม่ลบใน Task นี้)
- ✅ Service/API ไม่ใช้ legacy fields
- ✅ UI ซ่อน legacy controls แต่ยังไม่ลบโครงสร้างออกทั้งหมด

### Known Limitations
- Version pinning ถูกลบออกแล้ว (ใช้ latest stable อัตโนมัติ)
- Hybrid mode ถูกลบออกแล้ว (เหลือ classic/hatthasilpa เท่านั้น)
- Default Mode Select ถูกลบ (ใช้ production_line จาก product แทน)

### Testing Recommendations
1. ทดสอบเปิด Product Page (Classic/Hatthasilpa)
2. ทดสอบ Bind/Unbind routing (Hatthasilpa เท่านั้น)
3. ทดสอบ Classic Dashboard (Classic เท่านั้น)
4. ทดสอบ Backward compatibility (product เดิมที่มี binding เก่า)

---

**Status:** ✅ **COMPLETED** (2025-11-29)


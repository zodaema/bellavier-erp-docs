# Graph API Actions Analysis

**Date:** 2025-12-18  
**Purpose:** วิเคราะห์การใช้งาน 3 graph actions เพื่อหาความซ้ำซ้อน

---

## 📊 สรุปการใช้งาน

### 1. `graph_get` (Source of Truth - routing_graph_designer)

**เรียกใช้จาก:**
- ✅ **`page/routing_graph_designer.php`** - หน้า Graph Designer (Source of Truth)
  - โหลด `graph_designer.js` → เรียก `graph_get` (9 จุด)
  - โหลด `GraphLoader.js` → เรียก `graph_get` (1 จุด)
  - โหลด `GraphAPI.js` → เรียก `graph_get` (1 จุด)

**จุดที่เรียกใช้ใน `graph_designer.js`:**
- `loadGraph()` - โหลด graph เมื่อเลือกจาก sidebar (บรรทัด 736)
- `handleVersionConflict()` - reload หลัง conflict (บรรทัด 1151)
- `saveGraph()` - reload หลัง save (บรรทัด 1374)
- `publishGraph()` - reload หลัง publish (บรรทัด 1718)
- `discardDraft()` - reload หลัง discard (บรรทัด 1774)
- และอื่นๆ (รวม 9 จุด)

**ใช้สำหรับ:**
- ✅ **Graph Designer (routing_graph_designer)** - โหลด graph สำหรับแก้ไข
- ✅ ใช้ `loadGraphWithVersion()` → มีการแปลง `node_type` แล้ว
- ✅ มี graph variables, node capabilities, ETag support

**Response Format:**
```json
{
  "ok": true,
  "graph": {...},
  "nodes": [...],
  "edges": [...],
  "graph_vars": [...],
  "node_capabilities": {...}
}
```

---

### 2. `graph_view` (DEPRECATED - 2025-12-18)

**สถานะ:** ⚠️ **DEPRECATED** - Guarded with logging

**เรียกใช้จาก:**
- ❌ **ไม่พบการเรียกใช้ใน frontend code**
- ⚠️ **อาจถูกเรียกจาก backend/script/external client** (กำลังตรวจสอบผ่าน error_log)

**ใช้สำหรับ:**
- ❓ อาจจะใช้ใน backend/internal หรือ external integration
- ✅ ใช้ `loadGraphWithVersion()` → มีการแปลง `node_type` แล้ว
- ✅ มี projection support (summary/design/runtime)

**Deprecation Plan:**
- **2025-12-18:** Marked as deprecated, added guard + logging
- **Monitoring:** Check error_log for `[dag_routing_api] DEPRECATED action graph_view`
- **Removal:** After 30-60 days of no usage (or confirmed no external usage)
- ✅ มี permission checks แยกตาม projection

**Response Format:**
```json
{
  "ok": true,
  "graph": {...},
  "nodes": [...],
  "edges": [...],
  "summary": {...}
}
```

---

### 3. `graph_viewer` (Product Graph Binding)

**เรียกใช้จาก:**
- `assets/javascripts/products/product_graph_binding.js` (2 จุด)
  - `renderGraphPreview()` - แสดง preview ใน container (บรรทัด 1013)
  - `showGraphPreviewWithViewer()` - **แต่ใช้ `get_graph` แทน!** (บรรทัด 1798)

**ใช้สำหรับ:**
- ✅ **Product Graph Binding** - แสดง graph preview
- ⚠️ Query โดยตรง (ไม่ใช้ `loadGraphWithVersion()`)
- ✅ เพิ่งเพิ่มการแปลง `node_type` แล้ว (2025-12-18)

**Response Format:**
```json
{
  "ok": true,
  "graph": {...},
  "nodes": [...],
  "edges": [...],
  "summary": {...}
}
```

---

## 🔍 ปัญหาที่พบ

### 1. `graph_viewer` ซ้ำซ้อนกับ `graph_get`

**ปัญหา:**
- `graph_viewer` query โดยตรง แทนที่จะใช้ `loadGraphWithVersion()`
- ทำให้ code duplication และอาจมี bug ที่ไม่ sync กัน

**ตัวอย่าง:**
- `product_graph_binding.js` บรรทัด 1798 ใช้ `get_graph` แทน `graph_viewer` ใน `showGraphPreviewWithViewer()`
- แสดงว่า developer เองก็รู้ว่า `graph_viewer` ไม่ดีพอ

### 2. `graph_view` ไม่ถูกใช้

**ปัญหา:**
- ไม่พบการเรียกใช้ใน frontend
- อาจเป็น legacy code หรือ deprecated

---

## 💡 คำแนะนำ

### Option 1: Refactor `graph_viewer` ให้ใช้ `loadGraphWithVersion()`

**ข้อดี:**
- ลด code duplication
- ใช้ logic เดียวกันกับ source of truth
- แก้ปัญหา node_type conversion อัตโนมัติ

**ข้อเสีย:**
- ต้อง refactor code

### Option 2: Deprecate `graph_viewer` และใช้ `graph_get` แทน

**ข้อดี:**
- ใช้ API เดียวกันกับ Graph Designer (source of truth)
- ลด maintenance burden

**ข้อเสีย:**
- ต้องแก้ frontend code ที่ใช้ `graph_viewer`

### Option 3: Deprecate `graph_view` (ถ้าไม่ใช้)

**ข้อดี:**
- ลด code ที่ไม่จำเป็น

---

## ✅ สรุป

1. **`graph_get`** = Source of Truth ✅ 
   - ใช้ใน **`routing_graph_designer`** (หน้า Graph Designer)
   - เรียกผ่าน `graph_designer.js`, `GraphLoader.js`, `GraphAPI.js`
   - ใช้ `loadGraphWithVersion()` → มีการแปลง `node_type` แล้ว

2. **`graph_view`** = DEPRECATED ⚠️ 
   - **สถานะ:** Deprecated 2025-12-18, guarded with logging
   - ไม่พบการเรียกใช้ใน frontend
   - อาจถูกเรียกจาก backend/script/external client (กำลังตรวจสอบ)
   - **แผนลบ:** หลัง 30-60 วันถ้าไม่มี log usage

3. **`graph_viewer`** = Refactored ✅ 
   - ใช้ใน **`product_graph_binding.js`** (หน้า Product Graph Binding)
   - ✅ **Refactored แล้ว (2025-12-18)** - ใช้ `loadGraphWithVersion()` เหมือน `graph_get`
   - สอดคล้องกับ source of truth แล้ว

4. **`graph_by_code`** = DEPRECATED ⚠️ 
   - **สถานะ:** Deprecated 2025-12-18, guarded with logging
   - ไม่พบการเรียกใช้ใน frontend
   - **แผนลบ:** หลัง 30-60 วันถ้าไม่มี log usage

**สถานะ:**
- ✅ `graph_get` - Source of Truth (ใช้ใน routing_graph_designer)
- ✅ `graph_viewer` - Refactored แล้ว (ใช้ `loadGraphWithVersion()`)
- ⚠️ `graph_view` - **DEPRECATED** (guarded + logging)
- ⚠️ `graph_by_code` - **DEPRECATED** (guarded + logging)

**Deprecation Strategy:**
- **Phase 1 (2025-12-18):** Mark as deprecated, add guard + logging
- **Phase 2 (2026-01-18 ~ 2026-02-18):** Review error_log, remove if no usage


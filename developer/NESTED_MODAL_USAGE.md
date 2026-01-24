# NestedModalManager - วิธีใช้งานสำหรับ Developer

**Version:** 1.0  
**Date:** January 2026  
**Status:** ✅ **Production Ready**  
**Purpose:** แก้ปัญหา nested modal z-index และ backdrop stacking อัตโนมัติ

---

## 📋 ภาพรวม

`NestedModalManager` เป็นระบบกลางที่จัดการ z-index และ backdrop สำหรับ nested Bootstrap 5 modals อัตโนมัติ แก้ปัญหาที่ backdrop ของ modal ชั้นในไม่บัง parent modal และ backdrop บัง modal ตัวเอง

**ปัญหาที่แก้:**
- ✅ Backdrop ของ nested modal บัง parent modal ได้ถูกต้อง
- ✅ Backdrop ไม่บัง modal ตัวเอง
- ✅ Modal ซ้อนกันหลายชั้นทำงานได้ถูกต้อง
- ✅ ไม่ต้องจัดการ z-index เอง

---

## 🚀 วิธีใช้งานพื้นฐาน

### วิธีที่ 1: Auto-Manage (แนะนำ - ง่ายที่สุด)

```javascript
// เพียงแค่เรียก autoManage() แทน new bootstrap.Modal()
const modal = NestedModalManager.autoManage('#my-modal');
modal.show();
```

### วิธีที่ 2: Manual Register

```javascript
// สร้าง modal instance เอง แล้ว register
const modalEl = document.getElementById('my-modal');
const modal = new bootstrap.Modal(modalEl);
NestedModalManager.getInstance().register(modalEl, modal);
modal.show();
```

### วิธีที่ 3: Auto-Detection (อัตโนมัติ)

**ไม่ต้องทำอะไร!** `NestedModalManager` จะตรวจจับและจัดการ modal อัตโนมัติเมื่อ modal ถูกเปิด (show.bs.modal event)

```javascript
// แค่ใช้ Bootstrap Modal ปกติ
const modal = new bootstrap.Modal('#my-modal');
modal.show(); // NestedModalManager จะจัดการให้อัตโนมัติ
```

---

## 📖 API Reference

### Static Methods

#### `NestedModalManager.autoManage(modalEl, options)`

Auto-manage modal พร้อมสร้าง Bootstrap Modal instance

**Parameters:**
- `modalEl` (HTMLElement|string): Modal element หรือ CSS selector
- `options` (Object, optional): Bootstrap Modal options
  - `backdrop` (boolean, default: true): แสดง backdrop
  - `keyboard` (boolean, default: true): ปิดด้วย ESC key
  - `focus` (boolean, default: true): Focus modal เมื่อเปิด

**Returns:** `bootstrap.Modal` instance

**Example:**
```javascript
// เปิด modal พร้อม auto-manage
const modal = NestedModalManager.autoManage('#my-modal', {
  backdrop: true,
  keyboard: false
});
modal.show();
```

#### `NestedModalManager.getInstance()`

ดึง global manager instance

**Returns:** `NestedModalManager` instance

**Example:**
```javascript
const manager = NestedModalManager.getInstance();
const depth = manager.getStackDepth();
console.log('Active modals:', depth);
```

### Instance Methods

#### `register(modalEl, modalInstance, options)`

Register modal สำหรับการจัดการ z-index อัตโนมัติ

**Parameters:**
- `modalEl` (HTMLElement|string): Modal element หรือ selector
- `modalInstance` (bootstrap.Modal, optional): Modal instance ที่มีอยู่แล้ว
- `options` (Object, optional): Bootstrap Modal options

**Returns:** `bootstrap.Modal` instance

**Example:**
```javascript
const manager = NestedModalManager.getInstance();
const modal = manager.register('#my-modal', null, {
  backdrop: true,
  keyboard: true
});
```

#### `unregister(modalEl)`

ยกเลิกการ register modal (cleanup event handlers)

**Parameters:**
- `modalEl` (HTMLElement|string): Modal element หรือ selector

**Example:**
```javascript
const manager = NestedModalManager.getInstance();
manager.unregister('#my-modal');
```

#### `getStackDepth()`

นับจำนวน modal ที่กำลังแสดงอยู่

**Returns:** `number`

**Example:**
```javascript
const manager = NestedModalManager.getInstance();
if (manager.getStackDepth() > 3) {
  console.warn('Too many nested modals!');
}
```

#### `reset()`

Reset manager (unregister ทุก modal)

**Example:**
```javascript
const manager = NestedModalManager.getInstance();
manager.reset(); // Cleanup all
```

---

## 🎯 ตัวอย่างการใช้งานจริง

### ตัวอย่าง 1: Nested Modals (Modal ซ้อนกัน)

```javascript
// Parent Modal
const parentModal = NestedModalManager.autoManage('#parent-modal');

// Child Modal (เปิดจาก parent)
$('#btn-open-child').on('click', function() {
  const childModal = NestedModalManager.autoManage('#child-modal');
  childModal.show();
});

// Grandchild Modal (เปิดจาก child)
$('#btn-open-grandchild').on('click', function() {
  const grandchildModal = NestedModalManager.autoManage('#grandchild-modal');
  grandchildModal.show();
});
```

**ผลลัพธ์:**
- Parent modal: z-index 1055, backdrop: 1050
- Child modal: z-index 1085, backdrop: 1080 (บัง parent modal)
- Grandchild modal: z-index 1115, backdrop: 1110 (บัง child modal)

### ตัวอย่าง 2: Product Components (ใช้จริงในระบบ)

```javascript
// Component Modal
const componentModal = NestedModalManager.autoManage('#product-component-modal');

// Constraints Modal (nested)
$('#btn-config-constraints').on('click', function() {
  const constraintsModal = NestedModalManager.autoManage('#material-constraints-modal');
  constraintsModal.show();
});
```

### ตัวอย่าง 3: Fallback Pattern (ถ้า Manager ไม่โหลด)

```javascript
function initModal() {
  const modalEl = document.getElementById('my-modal');
  
  // ใช้ NestedModalManager ถ้ามี, fallback เป็น Bootstrap Modal ปกติ
  const modal = window.NestedModalManager?.autoManage(modalEl) 
    || new bootstrap.Modal(modalEl);
  
  return modal;
}
```

---

## 🔧 การตั้งค่า (Configuration)

### Z-Index Strategy

**Default Values:**
- `baseZIndex`: 1055 (Bootstrap 5 default)
- `zIndexIncrement`: 30 (เพิ่ม 30 ต่อ modal level)
- `backdropOffset`: 5 (backdrop อยู่ต่ำกว่า modal 5 ระดับ)

**Stacking Example:**
```
Modal 1: z-index 1055, backdrop: 1050
Modal 2: z-index 1085, backdrop: 1080 (บัง modal 1)
Modal 3: z-index 1115, backdrop: 1110 (บัง modal 2)
```

### Custom Configuration (ถ้าต้องการ)

```javascript
// ต้องแก้ไขใน NestedModalManager.js โดยตรง
// ไม่แนะนำให้แก้ไขเอง เว้นแต่มีเหตุผลเฉพาะ
```

---

## 📝 Migration Guide

### Before (Manual Z-Index)

```javascript
// ❌ วิธีเก่า: จัดการ z-index เอง
const modal1 = new bootstrap.Modal('#modal1');
const modal2 = new bootstrap.Modal('#modal2');

$('#modal1').css('z-index', '1055');
$('#modal2').css('z-index', '1085');
$('.modal-backdrop').eq(0).css('z-index', '1050');
$('.modal-backdrop').eq(1).css('z-index', '1080');
```

### After (NestedModalManager)

```javascript
// ✅ วิธีใหม่: อัตโนมัติ
const modal1 = NestedModalManager.autoManage('#modal1');
const modal2 = NestedModalManager.autoManage('#modal2');
// Z-index จัดการให้อัตโนมัติ!
```

---

## 🔌 Integration

### 1. Load Script

เพิ่มใน page definition:

```php
// page/your_page.php
$page_detail['jquery'][N] = domain::getDomain() . '/assets/javascripts/core/NestedModalManager.js';
```

**สำคัญ:** ต้องโหลดก่อน modal code ที่ใช้มัน

### 2. ใช้ใน Module JS

```javascript
// assets/javascripts/your_module/your_module.js
(function($) {
  'use strict';
  
  let myModal = null;
  
  function initModal() {
    if (!myModal) {
      // ใช้ NestedModalManager
      myModal = window.NestedModalManager?.autoManage('#my-modal') 
        || new bootstrap.Modal('#my-modal');
    }
  }
  
  $('#btn-open-modal').on('click', function() {
    initModal();
    myModal.show();
  });
})(jQuery);
```

---

## 🎨 CSS Considerations

### ไม่ต้องเขียน CSS z-index เอง

**ถ้าใช้ NestedModalManager แล้ว ไม่ต้องเขียน CSS z-index:**

```css
/* ❌ ไม่ต้องเขียน */
#my-modal.show {
  z-index: 1055 !important;
}

/* ✅ NestedModalManager จัดการให้อัตโนมัติ */
```

### Select2 Dropdowns

**ยังคงต้องใช้ z-index fix สำหรับ Select2:**

```css
/* ✅ ยังคงต้องใช้ */
.select2-container--open {
  z-index: 1060 !important;
}
```

---

## 🐛 Troubleshooting

### ปัญหา: Modal ถูก backdrop บัง

**สาเหตุ:** NestedModalManager ไม่ได้ register modal

**แก้ไข:**
1. ตรวจสอบว่า `NestedModalManager.js` โหลดแล้ว
2. ใช้ `NestedModalManager.autoManage()` แทน `new bootstrap.Modal()`
3. ตรวจสอบ console สำหรับ errors

### ปัญหา: Z-Index Conflict

**สาเหตุ:** มี CSS z-index ที่ override

**แก้ไข:**
1. ลบ manual z-index CSS สำหรับ modal ที่ใช้ NestedModalManager
2. ตรวจสอบ `global_styles.css` สำหรับ conflicting rules
3. ใช้ `!important` เฉพาะเมื่อจำเป็น

### ปัญหา: Modal ไม่แสดง

**สาเหตุ:** Modal ถูก re-parent ไปยัง `<body>` แล้ว restore ไม่ได้

**แก้ไข:**
- NestedModalManager จะพยายาม restore modal กลับตำแหน่งเดิมเมื่อปิด
- ถ้า restore ไม่ได้ modal จะอยู่ใต้ `<body>` (ปลอดภัย)

### Debug Mode

**เปิด debug mode:**

```javascript
// เปิด debug ใน console
window.DEBUG_NESTED_MODAL = true;

// ดู stack depth
const manager = NestedModalManager.getInstance();
console.log('Stack depth:', manager.getStackDepth());
```

---

## ✅ Best Practices

1. **ใช้ `autoManage()` เสมอ** สำหรับ modal ใหม่
2. **ลบ manual z-index CSS** เมื่อ migrate
3. **โหลด manager ก่อน modal code** ใน page definition
4. **ใช้ fallback pattern** ถ้า manager อาจไม่โหลด
5. **ตรวจสอบ stack depth** ถ้ามี modal ซ้อนกันมาก

---

## 📚 ตัวอย่างจากระบบจริง

### Product Components Module

```javascript
// assets/javascripts/products/product_components.js

// Component Modal
const componentModal = NestedModalManager.autoManage('#product-component-modal');

// Constraints Modal (nested)
const constraintsModal = NestedModalManager.autoManage('#material-constraints-modal', {
  backdrop: true,
  keyboard: true,
  focus: true
});
```

---

## 🔗 Related Files

- **Implementation:** `assets/javascripts/core/NestedModalManager.js`
- **Documentation:** `docs/core/NESTED_MODAL_MANAGER.md`
- **Usage Example:** `assets/javascripts/products/product_components.js`
- **CSS:** `assets/stylesheets/global_styles.css`

---

## 📝 Changelog

### v1.0 (2026-01-XX)
- Initial release
- Auto-detection สำหรับ modal ที่ไม่ได้ register
- DOM re-parenting เพื่อแก้ปัญหา stacking context
- Backdrop association แบบ deterministic
- Z-index conflict detection และ warning

---

## ❓ FAQ

**Q: ต้อง register ทุก modal ไหม?**  
A: ไม่จำเป็น NestedModalManager จะตรวจจับอัตโนมัติ แต่แนะนำให้ใช้ `autoManage()` เพื่อความชัดเจน

**Q: ใช้กับ modal ที่มีอยู่แล้วได้ไหม?**  
A: ได้ ใช้ `register(modalEl, existingInstance)` หรือให้ auto-detection จัดการ

**Q: มีผลกับ modal ที่ไม่ใช้ NestedModalManager ไหม?**  
A: ไม่มีผล modal ที่ไม่ได้ register จะทำงานปกติตาม Bootstrap

**Q: Z-index conflict เกิดขึ้นเมื่อไหร่?**  
A: เมื่อ modal ใกล้กันเกินไป (zIndexIncrement น้อย) หรือมี CSS override

---

**Status:** ✅ Production Ready  
**Maintainer:** Bellavier ERP Team  
**License:** Internal Use Only

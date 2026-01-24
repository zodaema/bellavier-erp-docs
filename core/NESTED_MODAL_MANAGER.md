# NestedModalManager - Centralized Nested Modal Management

**Version:** 1.0  
**Date:** January 2026  
**Status:** ✅ **Production Ready**  
**Purpose:** Solve nested modal z-index and backdrop stacking issues across the application

---

## 📋 Overview

`NestedModalManager` is a centralized utility that automatically manages z-index stacking for nested Bootstrap 5 modals. It solves the common problem where backdrop of a nested modal doesn't properly cover parent modals.

**Core Problem Solved:**
> When opening a modal inside another modal, the backdrop of the nested modal should cover the parent modal, not just its backdrop. This requires careful z-index management that `NestedModalManager` handles automatically.

---

## 🚀 Quick Start

### Basic Usage

```javascript
// Simple: Auto-manage a modal
const modal = NestedModalManager.autoManage('#my-modal');

// Show the modal
modal.show();
```

### Advanced Usage

```javascript
// Get manager instance for multiple modals
const manager = NestedModalManager.getInstance();

// Register modals in order
const modal1 = manager.register('#parent-modal');
const modal2 = manager.register('#child-modal', null, {
  backdrop: true,
  keyboard: true,
  focus: true
});

// Manager automatically handles z-index stacking
modal1.show();
modal2.show(); // Will be above modal1 with proper backdrop
```

---

## 📖 API Reference

### Static Methods

#### `NestedModalManager.autoManage(modalEl, options)`

Auto-manage a modal with default settings.

**Parameters:**
- `modalEl` (HTMLElement|string): Modal element or CSS selector
- `options` (Object, optional): Bootstrap Modal options
  - `backdrop` (boolean, default: true): Show backdrop
  - `keyboard` (boolean, default: true): Close on ESC
  - `focus` (boolean, default: true): Focus modal on show

**Returns:** `bootstrap.Modal` instance

**Example:**
```javascript
const modal = NestedModalManager.autoManage('#my-modal', {
  backdrop: true,
  keyboard: false
});
```

#### `NestedModalManager.getInstance()`

Get the global singleton manager instance.

**Returns:** `NestedModalManager` instance

**Example:**
```javascript
const manager = NestedModalManager.getInstance();
const depth = manager.getStackDepth();
```

### Instance Methods

#### `register(modalEl, modalInstance, options)`

Register a modal for automatic z-index management.

**Parameters:**
- `modalEl` (HTMLElement|string): Modal element or selector
- `modalInstance` (bootstrap.Modal, optional): Existing modal instance
- `options` (Object, optional): Bootstrap Modal options

**Returns:** `bootstrap.Modal` instance

#### `unregister(modalEl)`

Unregister a modal (cleanup event handlers).

**Parameters:**
- `modalEl` (HTMLElement|string): Modal element or selector

#### `getStackDepth()`

Get current number of active modals.

**Returns:** `number`

#### `reset()`

Reset manager (unregister all modals).

---

## 🎯 Z-Index Strategy

### Default Values

- **Base Z-Index:** 1050 (Bootstrap 5 default)
- **Increment:** +20 per modal level
- **Backdrop Offset:** -1 from modal z-index

### Stacking Example

```
Level 0 (First Modal):
  Modal:     z-index 1050
  Backdrop:  z-index 1049

Level 1 (Second Modal):
  Modal:     z-index 1070
  Backdrop:  z-index 1051 (above previous modal 1050)

Level 2 (Third Modal):
  Modal:     z-index 1090
  Backdrop:  z-index 1071 (above previous modal 1070)
```

**Key Rule:** Each backdrop must be above the previous modal's z-index, not just its backdrop.

---

## 📝 Migration Guide

### Before (Manual Z-Index)

```javascript
// ❌ Old way: Manual z-index management
const modal1 = new bootstrap.Modal('#modal1');
const modal2 = new bootstrap.Modal('#modal2');

$('#modal1').css('z-index', '1055');
$('#modal2').css('z-index', '1075');
$('.modal-backdrop').eq(0).css('z-index', '1054');
$('.modal-backdrop').eq(1).css('z-index', '1074');
```

### After (NestedModalManager)

```javascript
// ✅ New way: Automatic management
const modal1 = NestedModalManager.autoManage('#modal1');
const modal2 = NestedModalManager.autoManage('#modal2');
// Z-index handled automatically!
```

---

## 🔧 Integration

### 1. Load the Script

Add to your page definition:

```php
// page/your_page.php
$page_detail['jquery'][N] = domain::getDomain() . '/assets/javascripts/core/NestedModalManager.js';
```

Or via core index:

```php
$page_detail['jquery'][N] = domain::getDomain() . '/assets/javascripts/core/index.js';
```

### 2. Use in Your Code

```javascript
// In your module JS file
(function($) {
  'use strict';
  
  let myModal = null;
  
  function initModal() {
    if (!myModal) {
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

### Remove Manual Z-Index

If you're using `NestedModalManager`, remove manual z-index CSS:

```css
/* ❌ Remove this */
#my-modal.show {
  z-index: 1055 !important;
}

/* ✅ NestedModalManager handles it automatically */
```

### Select2 Dropdowns

Keep Select2 z-index fix (it needs to be above modals):

```css
.select2-container--open {
  z-index: 1060 !important;
}
```

---

## 🐛 Troubleshooting

### Modal Not Stacking Correctly

**Problem:** Nested modal backdrop doesn't cover parent modal.

**Solution:**
1. Ensure `NestedModalManager.js` is loaded before your modal code
2. Use `NestedModalManager.autoManage()` instead of `new bootstrap.Modal()`
3. Check browser console for errors

### Z-Index Conflicts

**Problem:** Custom z-index CSS conflicts with manager.

**Solution:**
1. Remove manual z-index CSS for managed modals
2. Use `!important` only if necessary (manager uses inline styles)
3. Check `global_styles.css` for conflicting rules

### Multiple Managers

**Problem:** Creating multiple manager instances.

**Solution:**
- Always use `NestedModalManager.autoManage()` or `getInstance()`
- Don't create `new NestedModalManager()` manually

---

## 📚 Examples

### Example 1: Simple Nested Modals

```javascript
// Parent modal
const parentModal = NestedModalManager.autoManage('#parent-modal');

// Child modal (opened from parent)
$('#btn-open-child').on('click', function() {
  const childModal = NestedModalManager.autoManage('#child-modal');
  childModal.show();
});
```

### Example 2: Modal with Custom Options

```javascript
const modal = NestedModalManager.autoManage('#my-modal', {
  backdrop: 'static', // Prevent closing on backdrop click
  keyboard: false,    // Disable ESC key
  focus: true
});
```

### Example 3: Check Stack Depth

```javascript
const manager = NestedModalManager.getInstance();
const depth = manager.getStackDepth();

if (depth > 2) {
  console.warn('Too many nested modals!');
}
```

---

## ✅ Best Practices

1. **Always use `autoManage()`** for new modals
2. **Remove manual z-index CSS** when migrating
3. **Load manager before modal code** in page definitions
4. **Check stack depth** if you have many nested modals
5. **Use fallback** if manager not available:
   ```javascript
   const modal = window.NestedModalManager?.autoManage('#modal')
     || new bootstrap.Modal('#modal');
   ```

---

## 🔗 Related Files

- **Implementation:** `assets/javascripts/core/NestedModalManager.js`
- **CSS:** `assets/stylesheets/global_styles.css` (legacy modal rules)
- **Usage Example:** `assets/javascripts/products/product_components.js`

---

## 📝 Changelog

### v1.0 (2026-01-XX)
- Initial release
- Automatic z-index stacking
- Backdrop management
- Event-based updates

---

**Status:** ✅ Production Ready  
**Maintainer:** Bellavier ERP Team  
**License:** Internal Use Only

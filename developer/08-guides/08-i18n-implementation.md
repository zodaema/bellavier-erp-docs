# 🌐 i18n Implementation Guide

**วันที่:** 15 พฤศจิกายน 2025  
**วัตถุประสงค์:** คู่มือการใช้งานและโครงสร้างระบบ i18n  
**สถานะ:** ✅ Ready for Implementation

---

## 📋 สารบัญ

1. [โครงสร้างระบบ i18n](#โครงสร้างระบบ-i18n)
2. [การใช้งานใน PHP (Backend)](#การใช้งานใน-php-backend)
3. [การใช้งานใน JavaScript (Frontend)](#การใช้งานใน-javascript-frontend)
4. [การใช้งานใน Views](#การใช้งานใน-views)
5. [การใช้งานใน API](#การใช้งานใน-api)
6. [Translation Files Structure](#translation-files-structure)
7. [Parameter Replacement](#parameter-replacement)
8. [Language Switching](#language-switching)
9. [Best Practices](#best-practices)
10. [Examples](#examples)

---

## 🏗️ โครงสร้างระบบ i18n

### Core Components:

1. **Translation Functions** (`source/global_function.php`):
   - `app_language()` - ดึงภาษาปัจจุบัน (default: 'th')
   - `set_app_language($lang)` - ตั้งค่าภาษา
   - `app_translator()` - ดึง dictionary ของภาษาปัจจุบัน
   - `translate($key, $default, $params)` - แปลข้อความ

2. **Translation Files**:
   - `lang/en.php` - English (default language)
   - `lang/th.php` - Thai translation

3. **Frontend Integration** (`views/template/general.template.php`):
   - `window.APP_LANG` - ภาษาปัจจุบัน
   - `window.APP_I18N` - Translation dictionary (JSON)

4. **Language Switching** (`source/lang_switch.php`):
   - API endpoint สำหรับเปลี่ยนภาษา
   - เก็บใน session

---

## 💻 การใช้งานใน PHP (Backend)

### Basic Usage:

```php
// Simple translation
echo translate('common.action.save', 'Save');
// Output: "Save" (English) or "บันทึก" (Thai)

// With default fallback
echo translate('common.action.save', 'Save');
// If key not found: returns "Save"

// Without default (uses key as fallback)
echo translate('common.action.save');
// If key not found: returns "common.action.save"
```

### Parameter Replacement:

```php
// Translation key with parameter
translate('job_ticket.step.default_name', 'Step {seq}', ['seq' => 1])
// lang/en.php: 'job_ticket.step.default_name' => 'Step {seq}'
// Output: "Step 1" (English) or "ขั้นตอนที่ 1" (Thai)

// Multiple parameters
translate('user.greeting', 'Hello {name}, you have {count} messages', [
    'name' => 'John',
    'count' => 5
])
```

### Function Signature:

```php
function translate($key, $default = '', $params = [])
```

**Parameters:**
- `$key` (string) - Translation key (e.g., 'common.action.save')
- `$default` (string) - English fallback text (required for i18n)
- `$params` (array) - Parameters for replacement (optional)

**Returns:** Translated string

---

## 🎨 การใช้งานใน JavaScript (Frontend)

### Setup:

```javascript
// Define t() function at top of file
const t = (key, fallback) => window.APP_I18N?.[key] ?? fallback ?? key;
```

### Basic Usage:

```javascript
// Simple translation
const saveText = t('common.action.save', 'Save');
// Output: "Save" (English) or "บันทึก" (Thai)

// In HTML
$('#save-btn').text(t('common.action.save', 'Save'));

// In alerts
Swal.fire(t('common.success', 'Success'), t('common.saved', 'Saved'), 'success');
```

### Parameter Replacement:

```javascript
// Manual parameter replacement
const stepText = t('job_ticket.step.default_name', 'Step {seq}').replace('{seq}', 1);

// Or create helper function
function translateWithParams(key, fallback, params) {
    let text = t(key, fallback);
    if (params) {
        Object.keys(params).forEach(k => {
            text = text.replace(`{${k}}`, params[k]);
        });
    }
    return text;
}

const stepText = translateWithParams('job_ticket.step.default_name', 'Step {seq}', {seq: 1});
```

---

## 📄 การใช้งานใน Views

### PHP Rendering:

```php
<!-- Basic -->
<h1><?php echo translate('accounting.title', 'Accounting System'); ?></h1>

<!-- With data-i18n attribute (for JavaScript updates) -->
<h1 class="page-title" data-i18n="accounting.title">
    <?php echo translate('accounting.title', 'Accounting System'); ?>
</h1>

<!-- In buttons -->
<button><?php echo translate('common.action.save', 'Save'); ?></button>

<!-- In table headers -->
<th><?php echo translate('common.table.id', 'ID'); ?></th>
```

### JavaScript Updates:

```javascript
// Update elements with data-i18n attribute
function updateI18n() {
    document.querySelectorAll('[data-i18n]').forEach(el => {
        const key = el.getAttribute('data-i18n');
        el.textContent = t(key, el.textContent);
    });
}
```

---

## 🔌 การใช้งานใน API

### Error Messages:

```php
// Before (❌ WRONG):
json_error('Permission denied - Managers only', 403, ['app_code' => 'ASSIGN_403_FORBIDDEN']);

// After (✅ CORRECT):
json_error(
    translate('assignment.error.forbidden_managers_only', 'Permission denied - Managers only'), 
    403, 
    ['app_code' => 'ASSIGN_403_FORBIDDEN']
);
```

### Success Messages:

```php
// Before (❌ WRONG):
json_success(['message' => 'Job ticket created successfully', 'data' => $data]);

// After (✅ CORRECT):
json_success([
    'message' => translate('hatthasilpa_job_ticket.success.created', 'Job ticket created successfully'),
    'data' => $data
]);
```

### Validation Errors:

```php
// With parameter replacement
json_error(
    translate('job_ticket.error.mo_cancelled', 'Cannot create ticket from {status} MO', ['status' => $moStatus]), 
    400,
    ['app_code' => 'HTJT_400_MO_CANCELLED']
);
```

---

## 📁 Translation Files Structure

### File Location:
- `lang/en.php` - English (default)
- `lang/th.php` - Thai translation

### Structure:

```php
<?php
return [
    // Common actions
    'common.action.save' => 'Save',
    'common.action.edit' => 'Edit',
    'common.action.delete' => 'Delete',
    
    // Module-specific
    'accounting.title' => 'Accounting System',
    'accounting.form.amount' => 'Amount',
    
    // With parameters
    'job_ticket.step.default_name' => 'Step {seq}',
    'user.greeting' => 'Hello {name}, you have {count} messages',
];
```

### Key Naming Convention:

```
{module}.{category}.{item}
```

**Examples:**
- `common.action.save` - Common actions, Save button
- `accounting.title` - Accounting module, Title
- `job_ticket.error.missing_product` - Job ticket module, Error category, Missing product

---

## 🔄 Parameter Replacement

### In Translation Files:

```php
// lang/en.php
'job_ticket.step.default_name' => 'Step {seq}',
'user.greeting' => 'Hello {name}, you have {count} messages',

// lang/th.php
'job_ticket.step.default_name' => 'ขั้นตอนที่ {seq}',
'user.greeting' => 'สวัสดี {name} คุณมีข้อความ {count} ข้อความ',
```

### Usage:

```php
// PHP
translate('job_ticket.step.default_name', 'Step {seq}', ['seq' => 1])
// Output: "Step 1" or "ขั้นตอนที่ 1"

translate('user.greeting', 'Hello {name}', ['name' => 'John', 'count' => 5])
// Output: "Hello John, you have 5 messages" or "สวัสดี John คุณมีข้อความ 5 ข้อความ"
```

```javascript
// JavaScript (manual replacement)
let text = t('job_ticket.step.default_name', 'Step {seq}');
text = text.replace('{seq}', 1);
```

---

## 🌍 Language Switching

### Current Language:

```php
// Get current language
$lang = app_language(); // Returns 'th' or 'en'

// Set language
set_app_language('en'); // Switch to English
set_app_language('th'); // Switch to Thai
```

### Language Switch API:

```php
// POST to: source/lang_switch.php
// Data: { lang: 'en' } or { lang: 'th' }
// Redirects back to referer
```

### Frontend Language:

```javascript
// Get current language
const lang = window.APP_LANG; // 'th' or 'en'

// Get translation dictionary
const translations = window.APP_I18N; // Object with all translations
```

---

## ✅ Best Practices

### 1. Always Use English Default:

```php
// ✅ GOOD
translate('common.action.save', 'Save')

// ❌ BAD
translate('common.action.save', 'บันทึก')
```

### 2. Use Descriptive Keys:

```php
// ✅ GOOD
translate('accounting.form.amount', 'Amount')
translate('job_ticket.error.missing_product', 'Missing product')

// ❌ BAD
translate('amount', 'Amount')
translate('error1', 'Error')
```

### 3. Keep app_code in API Errors:

```php
// ✅ GOOD
json_error(
    translate('assignment.error.forbidden', 'Permission denied'), 
    403, 
    ['app_code' => 'ASSIGN_403_FORBIDDEN']
);

// ❌ BAD (missing app_code)
json_error(translate('assignment.error.forbidden', 'Permission denied'), 403);
```

### 4. Use data-i18n in Views:

```html
<!-- ✅ GOOD -->
<h1 data-i18n="accounting.title">
    <?php echo translate('accounting.title', 'Accounting System'); ?>
</h1>

<!-- ❌ BAD (no data-i18n) -->
<h1><?php echo translate('accounting.title', 'Accounting System'); ?></h1>
```

### 5. No Hardcoded Text:

```php
// ❌ BAD
echo "บันทึกสำเร็จ";
json_error('เกิดข้อผิดพลาด', 400);

// ✅ GOOD
echo translate('common.toast.saved', 'Saved successfully');
json_error(translate('common.error.generic', 'An error occurred'), 400);
```

---

## 📝 Examples

### Example 1: View File

```php
<!-- views/accounting.php -->
<div class="page-header">
    <h1 class="page-title" data-i18n="accounting.title">
        <?php echo translate('accounting.title', 'Accounting System'); ?>
    </h1>
</div>

<button class="btn btn-primary" data-i18n="common.action.save">
    <?php echo translate('common.action.save', 'Save'); ?>
</button>
```

### Example 2: JavaScript File

```javascript
// assets/javascripts/accounting/accounting.js
const t = (key, fallback) => window.APP_I18N?.[key] ?? fallback ?? key;

// In event handler
$('#save-btn').on('click', function() {
    Swal.fire(
        t('common.success', 'Success'),
        t('accounting.toast.saved', 'Expense saved successfully'),
        'success'
    );
});
```

### Example 3: API File

```php
// source/accounting.php
if (!$member) {
    json_error(
        translate('accounting.error.unauthorized', 'Unauthorized'), 
        401, 
        ['app_code' => 'ACCOUNTING_401_UNAUTHORIZED']
    );
}

json_success([
    'message' => translate('accounting.success.created', 'Expense created successfully'),
    'data' => $expenseData
]);
```

### Example 4: With Parameters

```php
// Translation files
// lang/en.php
'job_ticket.step.default_name' => 'Step {seq}',
'user.greeting' => 'Hello {name}, you have {count} messages',

// lang/th.php
'job_ticket.step.default_name' => 'ขั้นตอนที่ {seq}',
'user.greeting' => 'สวัสดี {name} คุณมีข้อความ {count} ข้อความ',

// Usage
echo translate('job_ticket.step.default_name', 'Step {seq}', ['seq' => 1]);
// Output: "Step 1" or "ขั้นตอนที่ 1"

echo translate('user.greeting', 'Hello {name}', ['name' => 'John', 'count' => 5]);
// Output: "Hello John, you have 5 messages" or "สวัสดี John คุณมีข้อความ 5 ข้อความ"
```

---

## 🚨 Critical Rules

### 1. English Default Only:

- ✅ **ต้องใช้ภาษาอังกฤษเป็น default** ใน `translate()` function
- ❌ **ห้าม hardcode ภาษาไทย** ในโค้ด
- ❌ **ห้ามใช้ emoji/symbols** ในโค้ด (ใช้ใน translation files ได้)

### 2. Translation Keys:

- ✅ **ใช้ key ที่ชัดเจน** (module.category.item)
- ✅ **เพิ่ม keys ในทั้ง `lang/en.php` และ `lang/th.php`**
- ❌ **ห้ามใช้ key ที่ไม่ชัดเจน** (เช่น 'error1', 'msg')

### 3. API Error Handling:

- ✅ **เก็บ app_code ไว้** (สำหรับ error handling และ logging)
- ✅ **ใช้ translate() สำหรับ user-facing messages**
- ❌ **ห้ามลบ app_code** ออกจาก error responses

---

## 📚 Related Documentation

- [Views i18n Audit Report](./VIEWS_I18N_AUDIT.md) - รายละเอียดไฟล์ที่ต้องแก้ไข
- [STATUS.md](../../STATUS.md) - สถานะโปรเจคและ i18n standardization

---

**เอกสารนี้สร้างเมื่อ:** 15 พฤศจิกายน 2025  
**อัปเดตล่าสุด:** 15 พฤศจิกายน 2025  
**สถานะ:** ✅ Ready for Implementation


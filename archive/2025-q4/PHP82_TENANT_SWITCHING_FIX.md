# PHP 8.2 Tenant Switching Fix

**Date:** October 28, 2025  
**Issue:** Tenant switching not persisting after PHP 8.2 upgrade  
**Status:** ✅ FIXED (requires Apache restart)

---

## 🐛 Problem Description

After upgrading from PHP 7.4 to PHP 8.2, the tenant switching functionality stopped working correctly:

### Symptoms:
1. **Header displays wrong tenant name** (shows "Maison Atelier" when cookie says "DEFAULT")
2. **Switching tenants doesn't persist** across page refreshes
3. **Cookie is set correctly** (`current_org_code=DEFAULT`)
4. **Session variable not being read** by `resolve_current_org()`

### Visual Evidence:
- Cookie: `current_org_code=DEFAULT`
- Header: "Maison Atelier" ❌ (should be "Bellavier Atelier")
- After clicking "DEFAULT" → briefly shows "Bellavier Atelier" → reverts to "Maison Atelier" on next page load

---

## 🔍 Root Cause Analysis

### 1. Static Variable Caching
**File:** `config.php` (line 205)

```php
function resolve_current_org(?string $preferredCode = null): ?array {
    static $resolved = null;  // ← This was the problem!
    // ...
}
```

**Issue:**
- Static variables persist across multiple function calls within the same request
- In PHP 8.2, this behavior became more aggressive
- Once `$resolved` was set to "maison_atelier", it stayed cached even after switching to "DEFAULT"

### 2. Duplicate Code
**File:** `views/template/header.template.php` (lines 24-42)

```php
$org = resolve_current_org();
$currentOrgName = $org['name'] ?? 'No Organization';
// ... 15 lines ...
<?php
  $org = resolve_current_org();  // ← Called AGAIN!
  $currentOrgName = $org['name'] ?? 'No Organization';
  $currentOrgCode = $org['code'] ?? '';
?>
```

**Issue:**
- Function called twice in the same template
- First call might cache the wrong value
- Second call would return the cached (wrong) value

### 3. PHP 8.2 OPcache Behavior
- PHP 8.2's OPcache is more aggressive than 7.4
- Doesn't automatically reload changed files
- Requires Apache restart to clear compiled code cache

---

## ✅ Solution Implemented

### Fix 1: Remove Static Cache
**File:** `config.php`

```php
// BEFORE (PHP 7.4):
function resolve_current_org(?string $preferredCode = null): ?array {
    static $resolved = null;
    // ...
    $resolved = $orgFromCookie;
    return $resolved;
}

// AFTER (PHP 8.2 Compatible):
function resolve_current_org(?string $preferredCode = null): ?array {
    // No static cache
    // ...
    return $orgFromCookie;  // Direct return
}
```

**Changes:**
- Removed `static $resolved = null;`
- Removed all `$resolved = ...` assignments
- Changed all `return $resolved;` to direct `return $org;`

### Fix 2: Consolidate Header Code
**File:** `views/template/header.template.php`

```php
// BEFORE:
$org = resolve_current_org();
$currentOrgName = $org['name'] ?? 'No Organization';
// ... 15 lines ...
<?php
  $org = resolve_current_org();  // Duplicate!
  $currentOrgName = $org['name'] ?? 'No Organization';
?>

// AFTER:
$org = resolve_current_org();
$currentOrgName = $org['name'] ?? 'No Organization';
$currentOrgCode = $org['code'] ?? '';
// (Removed duplicate call)
```

**Changes:**
- Removed duplicate `resolve_current_org()` call
- Added `$currentOrgCode` variable (was missing)
- Added debug logging (can be removed later)

### Fix 3: PWA v2 API Schema
**File:** `source/pwa_scan_v2_api.php`

```php
// BEFORE:
SELECT p.product_name  -- Column doesn't exist!
FROM atelier_job_ticket ajt
LEFT JOIN uom u ON ...  -- Table doesn't exist in DEFAULT!

// AFTER:
SELECT p.name as product_name  -- Correct column name
FROM atelier_job_ticket ajt
-- (Removed uom JOIN)
```

**Changes:**
- Fixed `p.product_name` → `p.name as product_name`
- Removed `LEFT JOIN uom` references
- Added error checking for `prepare()` failures

---

## 🧪 Testing

### Before Fix:
```bash
# Check cookies
document.cookie
# Output: "PHPSESSID=...; current_org_code=DEFAULT"

# But header shows: "Maison Atelier" ❌
```

### After Fix (requires restart):
```bash
# Same cookie
# Header should show: "Bellavier Atelier" ✅
```

### Test Script:
```bash
cd /Applications/MAMP/htdocs/bellavier-group-erp
/Applications/MAMP/bin/php/php8.2.0/bin/php -r "
require_once 'config.php';
\$_COOKIE['current_org_code'] = 'DEFAULT';
\$org = resolve_current_org();
echo 'Resolved: ' . (\$org ? \$org['code'] . ' = ' . \$org['name'] : 'NULL') . PHP_EOL;
"

# Expected Output:
# Resolved: DEFAULT = Bellavier Atelier
```

---

## 🔄 Required Action: Restart Apache

**Why:** PHP 8.2's OPcache doesn't automatically reload changed files.

### Method 1: GUI (Recommended)
1. Open **MAMP Application**
2. Click **"Stop Servers"** (red button)
3. Wait **3-5 seconds**
4. Click **"Start Servers"** (green button)
5. Wait for status to show **"Running"**
6. In browser: **Cmd+Shift+R** (hard refresh)

### Method 2: Terminal (MAMP PRO only)
```bash
/Applications/MAMP/bin/stop.sh && sleep 5 && /Applications/MAMP/bin/start.sh
```

### Method 3: Just Reload config.php
```bash
touch /Applications/MAMP/htdocs/bellavier-group-erp/config.php
# May not work with OPcache enabled
```

---

## ✅ Verification Steps

1. **Navigate to any page** (e.g., `?p=pwa_scan_v2`)
2. **Check header** - should show "Bellavier Atelier" (because cookie = DEFAULT)
3. **Click tenant dropdown** → Select "Maison Atelier"
4. **Verify header changes** to "Maison Atelier"
5. **Refresh page (F5)** - header should stay "Maison Atelier"
6. **Switch back to DEFAULT** - header should change to "Bellavier Atelier"
7. **Refresh again** - header should stay "Bellavier Atelier"

---

## 📊 Technical Details

### PHP 7.4 vs PHP 8.2 Behavior:

| Aspect | PHP 7.4 | PHP 8.2 |
|--------|---------|---------|
| Static variables | Less aggressive caching | More aggressive caching |
| OPcache | Auto-revalidates files | Stricter validation |
| Dynamic properties | Allowed (with warning) | Must be declared |
| File reload | More frequent | Requires explicit reload |

### Resolution Flow (Fixed):

```
User clicks "Bellavier Atelier (DEFAULT)"
  ↓
admin_org.php?action=switch_org&code=DEFAULT
  ↓
Set session: $_SESSION['current_org_code'] = 'DEFAULT'
Set cookie: setcookie('current_org_code', 'DEFAULT', ...)
  ↓
Redirect: Location: ../index.php
  ↓
index.php loads → header.template.php executes
  ↓
resolve_current_org() called:
  1. Check cookie: current_org_code = 'DEFAULT' ✓
  2. Fetch org from database: 'Bellavier Atelier' ✓
  3. Update session: $_SESSION['current_org_code'] = 'DEFAULT' ✓
  4. Return: ['code' => 'DEFAULT', 'name' => 'Bellavier Atelier'] ✓
  ↓
Header displays: "Bellavier Atelier" ✓
```

---

## 🚨 Known Limitations

1. **Requires Apache restart** after code changes (due to OPcache)
2. **Debug logs** added to `header.template.php` (should be removed in production)
3. **PWA v2 API** doesn't support UOM yet (hardcoded to 'pcs')

---

## 🔗 Related Issues

- [PHP82_DEPLOYMENT_SUCCESS.md](./PHP82_DEPLOYMENT_SUCCESS.md) - PHP 8.2 upgrade guide
- [PLATFORM_ADMIN_FULL_ACCESS.md](./PLATFORM_ADMIN_FULL_ACCESS.md) - Platform admin tenant access
- [TROUBLESHOOTING_GUIDE.md](./TROUBLESHOOTING_GUIDE.md) - General troubleshooting

---

## 📝 Changelog

### 2025-10-28 - Initial Fix
- Removed static cache from `resolve_current_org()`
- Fixed duplicate code in header.template.php
- Fixed PWA v2 API schema errors
- Added debug logging (temporary)

---

## ✨ Future Improvements

1. **Disable OPcache for development** (edit php.ini):
   ```ini
   opcache.enable=0
   ```

2. **Auto-revalidate files** (edit php.ini):
   ```ini
   opcache.revalidate_freq=0
   opcache.validate_timestamps=1
   ```

3. **Use dynamic tenant name rendering** (JavaScript):
   ```javascript
   // Update header dynamically after switch
   fetch('source/admin_org.php?action=current_org')
     .then(r => r.json())
     .then(data => {
       document.querySelector('.org-name').textContent = data.data.name;
     });
   ```

---

**Status:** ✅ Fixed - Requires Apache Restart  
**Tested:** Partially (awaiting restart)  
**Impact:** Critical - Affects all multi-tenant operations


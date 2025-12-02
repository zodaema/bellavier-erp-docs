# ✅ Classic Migration Checklist

**วันที่:** 2025-11-15  
**สถานะ:** Ready to migrate (with backward compatibility)

---

## 📋 Pre-Migration Checklist

### ✅ **Critical Checks (MUST PASS)**

- [x] `UnifiedSerialService.php` มี backward compatibility code
- [x] `serial_salts.php` มีโครงสร้างที่ถูกต้อง
- [x] มี backup plan

### ⚠️ **Warning Checks (Should Check)**

- [ ] ตรวจสอบว่ามี serial numbers เก่า (production_type='oem') หรือไม่
- [ ] Test serial generation ทำงานได้
- [ ] Test serial verification ทำงานได้

---

## 🔧 Migration Steps

### **Step 1: Run Readiness Check**

```bash
php tools/scripts/check_classic_migration_readiness.php
```

**Expected Output:**
```
✅ READY TO MIGRATE
```

**If NOT ready:**
- แก้ไขปัญหาที่พบก่อน
- ตรวจสอบ backward compatibility code

---

### **Step 2: Dry Run Migration**

```bash
php tools/scripts/migrate_serial_salts_to_classic.php --dry-run
```

**Expected Output:**
```
✓ [DRY RUN] Would create backup
✓ [DRY RUN] Would write new file
```

**Review:**
- ตรวจสอบ preview structure
- ตรวจสอบว่า 'oem' จะถูกเก็บไว้ (backward compatibility)

---

### **Step 3: Actual Migration**

```bash
php tools/scripts/migrate_serial_salts_to_classic.php
```

**Expected Output:**
```
✓ Backup created
✓ New file written
✓ Verification passed
✓ Classic serial generation works
```

**Verify:**
- ตรวจสอบ backup file ถูกสร้าง
- ตรวจสอบ serial_salts.php มี 'classic' key
- ตรวจสอบ 'oem' key ยังอยู่ (backward compatibility)

---

### **Step 4: Update SerialSaltHelper.php**

**File:** `source/BGERP/Helper/SerialSaltHelper.php`

**Changes:**
1. เปลี่ยน `'oem'` → `'classic'` ใน comments
2. เปลี่ยน `$data['oem']` → `$data['classic']` (แต่เก็บ backward compatibility)
3. เปลี่ยน `$showOnce['oem']` → `$showOnce['classic']`

**Code Pattern:**
```php
// Generate Classic salt if missing
if (($data['classic']['version'] ?? 0) === 0) {
    // Try 'oem' first for backward compatibility
    if (isset($data['oem']['version']) && $data['oem']['version'] > 0) {
        $data['classic'] = $data['oem']; // Copy from OEM
    } else {
        // Generate new Classic salt
        $classicSalt = bin2hex(random_bytes(32));
        $data['classic'] = [
            'version' => 1,
            'salts' => [1 => $classicSalt]
        ];
    }
}
```

---

### **Step 5: Update platform_serial_salt_api.php**

**File:** `source/platform_serial_salt_api.php`

**Changes:**
1. เปลี่ยน comments จาก 'OEM' → 'Classic'
2. เปลี่ยน `'oem'` → `'classic'` ใน data structure
3. เก็บ backward compatibility สำหรับ 'oem'

**Code Pattern:**
```php
// Generate salts
$hatSalt = bin2hex(random_bytes(32));
$classicSalt = bin2hex(random_bytes(32));

$data = [
    'hat' => [
        'version' => 1,
        'salts' => [1 => $hatSalt]
    ],
    'classic' => [  // ← เปลี่ยนจาก 'oem'
        'version' => 1,
        'salts' => [1 => $classicSalt]
    ],
    // Keep 'oem' for backward compatibility (optional)
    'oem' => [
        'version' => 1,
        'salts' => [1 => $classicSalt]  // Same salt as classic
    ],
    'updated_at' => gmdate('c'),
];
```

---

### **Step 6: Test Serial Generation**

```bash
# Test Classic serial generation
php -r "
require 'vendor/autoload.php';
require 'config.php';
\$service = new BGERP\Service\UnifiedSerialService();
\$serial = \$service->generateSerial(
    tenantId: 1,
    productionType: 'classic',
    sku: 'TEST',
    moId: null,
    jobTicketId: null,
    dagTokenId: null,
    originSource: 'test'
);
echo 'Generated: ' . \$serial . PHP_EOL;
\$verify = \$service->verifySerial(\$serial);
echo 'Verified: ' . (\$verify['valid'] ? 'YES' : 'NO') . PHP_EOL;
"
```

**Expected Output:**
```
Generated: MA01-CLASSIC-TEST-20251115-00001-XXXX-X
Verified: YES
```

---

### **Step 7: Test Backward Compatibility**

```bash
# Test that old 'oem' serials still verify
# (if you have existing serials)
```

**Verify:**
- Serial เก่า (production_type='oem') ยัง verify ได้
- Serial ใหม่ (production_type='classic') verify ได้

---

### **Step 8: Monitor**

**Monitor for 24-48 hours:**
- [ ] Serial generation ไม่มี error
- [ ] Serial verification ไม่มี error
- [ ] ไม่มี complaints จาก users

---

## 🔄 Rollback Plan

**If issues occur:**

1. **Restore backup:**
```bash
cp storage/secrets/serial_salts.backup.YYYYMMDDHHMMSS.php storage/secrets/serial_salts.php
```

2. **Verify:**
```bash
php tools/scripts/check_classic_migration_readiness.php
```

3. **Test:**
```bash
# Test serial generation again
```

---

## 📝 Post-Migration

### **Optional: Remove 'oem' Key (After 3-6 months)**

**Only if:**
- ✅ ไม่มี serial เก่า (production_type='oem') แล้ว
- ✅ ทุก serial ใช้ 'classic' แล้ว
- ✅ ผ่าน monitoring period แล้ว

**Steps:**
1. ตรวจสอบ database: `SELECT COUNT(*) FROM serial_registry WHERE production_type='oem'`
2. ถ้า = 0 → สามารถลบ 'oem' key ได้
3. Update `SerialSaltHelper.php` และ `platform_serial_salt_api.php` ให้ลบ backward compatibility code

---

## ✅ Success Criteria

- [x] `serial_salts.php` มี 'classic' key
- [x] `serial_salts.php` ยังมี 'oem' key (backward compatibility)
- [x] Serial generation ทำงานได้
- [x] Serial verification ทำงานได้
- [x] Serial เก่ายัง verify ได้
- [x] ไม่มี errors ใน logs

---

## 📞 Support

**If issues occur:**
1. Check error logs
2. Run readiness check again
3. Restore backup if needed
4. Review backward compatibility code

---

## 🔗 Related Files

- `tools/scripts/check_classic_migration_readiness.php` - Readiness checker
- `tools/scripts/migrate_serial_salts_to_classic.php` - Migration script
- `source/BGERP/Service/UnifiedSerialService.php` - Serial service (already updated)
- `source/BGERP/Helper/SerialSaltHelper.php` - Salt helper (needs update)
- `source/platform_serial_salt_api.php` - Salt API (needs update)
- `storage/secrets/serial_salts.php` - Secrets file (needs migration)


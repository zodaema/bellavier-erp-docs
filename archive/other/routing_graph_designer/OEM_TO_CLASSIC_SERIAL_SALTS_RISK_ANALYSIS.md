# 🔍 ความเสี่ยงการเปลี่ยน OEM → Classic ใน Serial Salts

**วันที่:** 2025-11-15  
**สถานะ:** ⚠️ **CRITICAL RISK** - ต้องแก้ไขพร้อมกันหลายไฟล์

---

## 📋 สรุปปัญหา

`UnifiedSerialService.php` เปลี่ยนเป็นใช้ `'classic'` แล้ว แต่ไฟล์ที่เกี่ยวข้องยังใช้ `'oem'` อยู่:

1. ✅ `UnifiedSerialService.php` - เปลี่ยนเป็น `'classic'` แล้ว (line 620, 669)
2. ❌ `serial_salts.php` - ยังเป็น `'oem'` อยู่
3. ❌ `SerialSaltHelper.php` - ยังใช้ `'oem'` อยู่
4. ❌ `platform_serial_salt_api.php` - ยังใช้ `'oem'` อยู่
5. ❌ Environment variables - ยังเป็น `SERIAL_SECRET_SALT_OEM`

---

## ⚠️ ความเสี่ยงที่พบ

### 1. **Serial Generation จะ Fail** 🔴 **CRITICAL**

**ปัญหา:**
```php
// UnifiedSerialService.php line 620
$type = $isHatthasilpa ? 'hat' : 'classic'; // ← เปลี่ยนเป็น 'classic' แล้ว

// แต่ serial_salts.php ยังเป็น:
'oem' => [
    'version' => 1,
    'salts' => [1 => '...']
]
```

**ผลกระทบ:**
- `getSaltForVersion()` จะหา `$secrets['classic']` แต่ไม่เจอ
- จะ fallback ไปที่ environment variable `SERIAL_SECRET_SALT_OEM`
- ถ้าไม่มี env var → **RuntimeException: ERR_MISSING_SALT**
- **Serial generation จะ fail ทันที**

---

### 2. **Serial Verification จะ Fail** 🔴 **CRITICAL**

**ปัญหา:**
```php
// UnifiedSerialService.php::verifySerial() line 302
$salt = $this->getSaltForVersion($row['production_type'], $saltVersion);
// ถ้า $row['production_type'] = 'classic' แต่ไฟล์มี 'oem'
```

**ผลกระทบ:**
- Serial numbers ที่สร้างไว้แล้วใช้ salt `'oem'`
- ถ้าเปลี่ยนเป็น `'classic'` → จะหา salt ไม่เจอ
- **Hash verification จะ fail** → Serial จะถูก reject เป็น counterfeit

---

### 3. **Backward Compatibility** 🟡 **MEDIUM**

**ปัญหา:**
- Serial numbers ที่สร้างไว้แล้ว (production_type='oem') ใช้ salt `'oem'`
- ถ้าเปลี่ยนเป็น `'classic'` → จะ verify ไม่ได้

**ผลกระทบ:**
- Serial numbers เก่าจะ verify ไม่ผ่าน
- ต้องมี backward compatibility check

---

### 4. **Migration Complexity** 🟡 **MEDIUM**

**ต้องเปลี่ยนพร้อมกัน:**
1. `serial_salts.php` - เปลี่ยน key `'oem'` → `'classic'`
2. `SerialSaltHelper.php` - เปลี่ยนทุกที่ที่ใช้ `'oem'`
3. `platform_serial_salt_api.php` - เปลี่ยนทุกที่ที่ใช้ `'oem'`
4. Environment variables - เปลี่ยน `SERIAL_SECRET_SALT_OEM` → `SERIAL_SECRET_SALT_CLASSIC`
5. Database - เปลี่ยน `production_type='oem'` → `'classic'` ใน serial_registry

---

## ✅ แนวทางแก้ไข (Recommended)

### **Option A: Backward Compatibility (แนะนำ)** ⭐

**เปลี่ยนไฟล์ทั้งหมดพร้อมกัน + เพิ่ม backward compatibility:**

```php
// UnifiedSerialService.php::getSaltForVersion()
private function getSaltForVersion(string $productionType, int $version): string
{
    $isHatthasilpa = ($productionType === 'hatthasilpa');
    $type = $isHatthasilpa ? 'hat' : 'classic';
    
    // Try secrets file first
    $secretsFile = __DIR__ . '/../../storage/secrets/serial_salts.php';
    if (file_exists($secretsFile)) {
        try {
            $secrets = include $secretsFile;
            
            // Try 'classic' first (new)
            if (isset($secrets['classic']['salts'][$version])) {
                $salt = $secrets['classic']['salts'][$version];
                if ($salt && strlen($salt) === 64) {
                    return $salt;
                }
            }
            
            // Fallback to 'oem' for backward compatibility (old serials)
            if (isset($secrets['oem']['salts'][$version])) {
                $salt = $secrets['oem']['salts'][$version];
                if ($salt && strlen($salt) === 64) {
                    return $salt;
                }
            }
        } catch (Exception $e) {
            // Fall through to environment variables
            error_log("Failed to read secrets file: " . $e->getMessage());
        }
    }
    
    // Fallback to environment variables (try both)
    $baseKey = $isHatthasilpa ? 'SERIAL_SECRET_SALT_HAT' : 'SERIAL_SECRET_SALT_CLASSIC';
    $legacyKey = $isHatthasilpa ? 'SERIAL_SECRET_SALT_HAT' : 'SERIAL_SECRET_SALT_OEM';
    
    // Try versioned salt first
    if ($version >= 2) {
        $versionedKey = "{$baseKey}_V{$version}";
        $salt = getenv($versionedKey);
        if ($salt) return $salt;
        
        // Try legacy versioned
        $legacyVersionedKey = "{$legacyKey}_V{$version}";
        $salt = getenv($legacyVersionedKey);
        if ($salt) return $salt;
    }
    
    // Try base salt (new)
    $salt = getenv($baseKey);
    if ($salt) return $salt;
    
    // Fallback to legacy (backward compatibility)
    $salt = getenv($legacyKey);
    if ($salt) return $salt;
    
    throw new RuntimeException("ERR_MISSING_SALT: Missing {$baseKey} or {$legacyKey} environment variable or secrets file");
}
```

**ข้อดี:**
- ✅ Backward compatible (serial เก่ายัง verify ได้)
- ✅ ไม่ต้อง migrate ข้อมูลเก่า
- ✅ ปลอดภัยกว่า

**ข้อเสีย:**
- ⚠️ Code ซับซ้อนขึ้นเล็กน้อย
- ⚠️ ต้อง maintain ทั้ง 'oem' และ 'classic' ชั่วคราว

---

### **Option B: Clean Migration (ถ้าไม่มี serial เก่า)**

**เปลี่ยนทุกไฟล์พร้อมกัน:**

1. **serial_salts.php:**
```php
return array (
  'hat' => [...],
  'classic' => [  // ← เปลี่ยนจาก 'oem'
    'version' => 1,
    'salts' => [
      1 => '2e5ddf56f1704f9dc1d422e1c939dc747d5d0bd8398a14cc233475112c3797a9',
    ],
  ],
  'updated_at' => '2025-11-15T...',
);
```

2. **SerialSaltHelper.php:**
```php
// เปลี่ยนทุก 'oem' → 'classic'
if (($data['classic']['version'] ?? 0) === 0) {
    $classicSalt = bin2hex(random_bytes(32));
    $data['classic'] = [
        'version' => 1,
        'salts' => [1 => $classicSalt]
    ];
}
```

3. **platform_serial_salt_api.php:**
```php
// เปลี่ยนทุก 'oem' → 'classic'
'classic' => [
    'version' => 1,
    'salts' => [1 => $classicSalt]
],
```

4. **Environment Variables:**
```bash
# เปลี่ยนจาก
SERIAL_SECRET_SALT_OEM=...
# เป็น
SERIAL_SECRET_SALT_CLASSIC=...
```

5. **Database Migration:**
```sql
-- Update serial_registry
UPDATE serial_registry 
SET production_type = 'classic' 
WHERE production_type = 'oem';
```

**ข้อดี:**
- ✅ Clean และ consistent
- ✅ ไม่มี legacy code

**ข้อเสีย:**
- ❌ **Serial เก่าจะ verify ไม่ได้** (ถ้ามี)
- ❌ ต้อง migrate ข้อมูลเก่า

---

## 🎯 คำแนะนำ

### **ถ้ามี Serial Numbers เก่าใน Production:**
→ ใช้ **Option A (Backward Compatibility)**

### **ถ้ายังไม่มี Serial Numbers ใน Production:**
→ ใช้ **Option B (Clean Migration)**

---

## 📝 Checklist สำหรับ Migration

- [ ] ตรวจสอบว่ามี serial numbers เก่า (production_type='oem') หรือไม่
- [ ] ถ้ามี → ใช้ Option A
- [ ] ถ้าไม่มี → ใช้ Option B
- [ ] เปลี่ยน `serial_salts.php`
- [ ] เปลี่ยน `SerialSaltHelper.php`
- [ ] เปลี่ยน `platform_serial_salt_api.php`
- [ ] เปลี่ยน Environment variables (ถ้ามี)
- [ ] Update `UnifiedSerialService.php` (ถ้าใช้ Option A)
- [ ] Test serial generation
- [ ] Test serial verification (ทั้งใหม่และเก่า)
- [ ] Update documentation

---

## 🔗 ไฟล์ที่ต้องแก้ไข

1. `source/storage/secrets/serial_salts.php`
2. `source/BGERP/Helper/SerialSaltHelper.php`
3. `source/platform_serial_salt_api.php`
4. `source/BGERP/Service/UnifiedSerialService.php` (ถ้าใช้ Option A)
5. Environment variables (ถ้ามี)
6. Database migration (ถ้าใช้ Option B)

---

## ⚠️ Critical Warning

**DO NOT** เปลี่ยน `serial_salts.php` โดยไม่เปลี่ยนไฟล์อื่นพร้อมกัน  
**DO NOT** เปลี่ยนโดยไม่มี backward compatibility ถ้ามี serial เก่า  
**DO NOT** เปลี่ยนใน production โดยไม่ test ก่อน


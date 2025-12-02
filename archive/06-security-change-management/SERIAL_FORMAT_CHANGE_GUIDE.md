# 🔄 Serial Number Format - Change Guide

**Purpose:** คู่มือการปรับเปลี่ยน Serial Number Format  
**Last Updated:** November 9, 2025  
**Status:** ✅ **Change Management Guide**

---

## 🎯 คำถาม: ปรับเปลี่ยน Serial Code ง่ายหรือยาก?

### **คำตอบ: ขึ้นอยู่กับประเภทการเปลี่ยนแปลง**

| ประเภทการเปลี่ยนแปลง | ความยาก | เวลา | ข้อควรระวัง |
|---------------------|---------|------|------------|
| **เปลี่ยนความยาว/รูปแบบ** | 🔴 **ยากมาก** | 2-4 สัปดาห์ | ต้องรองรับ backward compatibility |
| **เพิ่ม/ลบ component** | 🔴 **ยากมาก** | 2-4 สัปดาห์ | ต้อง migrate ข้อมูลเก่า |
| **เปลี่ยน algorithm (checksum/hash)** | 🟡 **ปานกลาง** | 1-2 สัปดาห์ | ต้อง versioning |
| **เปลี่ยน validation rules** | 🟢 **ง่าย** | 1-3 วัน | แก้ regex/validation logic |
| **เปลี่ยน display format** | 🟢 **ง่ายมาก** | 1-2 ชั่วโมง | แก้ที่ UI layer เท่านั้น |

---

## 📊 สถานะปัจจุบัน

### **Format ปัจจุบัน (v1.0):**

```
{TENANT}-{PROD_TYPE}-{SKU}-{YYYYMMDD}-{SEQ}-{HASH-4}-{CHECKSUM}
Example: MA01-HAT-DIAG-20251109-00057-A7F3-X
```

### **จุดที่ Hardcode Format:**

1. **Regex Pattern** (`UnifiedSerialService.php:49`):
   ```php
   private const SERIAL_REGEX = '/^([A-Z0-9]{2,8})-([A-Z]{2,4})-([A-Z0-9]{2,8})-(\d{8})-(\d{5})-([A-Z0-9]{4})-([A-Z0-9])$/';
   ```

2. **Checksum Algorithm** (`UnifiedSerialService.php:549`):
   ```php
   private function computeChecksum(string $raw): string
   ```

3. **Hash Algorithm** (`UnifiedSerialService.php:549`):
   ```php
   private function makeHash4(...): string
   ```

4. **Database Schema** (`serial_registry` table):
   - `serial_code` VARCHAR(100) - เก็บ serial ทั้งหมด
   - `hash_signature` VARCHAR(64) - เก็บ full hash
   - `hash_salt_version` INT - version ของ salt

5. **Backward Compatibility Logic** (`verifySerial()`):
   - Format detection
   - Legacy format support

---

## 🔴 การเปลี่ยนแปลงที่ยาก (Breaking Changes)

### **1. เปลี่ยน Format Structure**

**ตัวอย่าง:** เปลี่ยนจาก `{TENANT}-{PROD}-{SKU}-{DATE}-{SEQ}-{HASH}-{CHECKSUM}`  
เป็น `{TENANT}-{PROD}-{SKU}-{DATE}-{SEQ}-{HASH}` (ลบ checksum)

**ความยาก:** 🔴 **ยากมาก**

**สิ่งที่ต้องทำ:**
1. ✅ สร้าง format version system
2. ✅ Update `SERIAL_REGEX` constant
3. ✅ Update `generateSerial()` method
4. ✅ Update `verifySerial()` method (รองรับทั้ง v1.0 และ v2.0)
5. ✅ Update checksum algorithm (หรือลบออก)
6. ✅ Migration script สำหรับ serials ที่มีอยู่แล้ว
7. ✅ Update documentation
8. ✅ Update tests

**เวลา:** 2-4 สัปดาห์

**ตัวอย่าง Code Changes:**

```php
// BEFORE (v1.0):
private const SERIAL_REGEX_V1 = '/^([A-Z0-9]{2,8})-([A-Z]{2,4})-([A-Z0-9]{2,8})-(\d{8})-(\d{5})-([A-Z0-9]{4})-([A-Z0-9])$/';

// AFTER (v2.0):
private const SERIAL_REGEX_V2 = '/^([A-Z0-9]{2,8})-([A-Z]{2,4})-([A-Z0-9]{2,8})-(\d{8})-(\d{5})-([A-Z0-9]{4})$/';
private const SERIAL_FORMAT_VERSION = 2; // New constant

// Format detection:
private function detectFormatVersion(string $serial): int {
    if (preg_match(self::SERIAL_REGEX_V2, $serial)) {
        return 2;
    } elseif (preg_match(self::SERIAL_REGEX_V1, $serial)) {
        return 1;
    }
    return 0; // Unknown format
}
```

---

### **2. เพิ่ม Component ใหม่**

**ตัวอย่าง:** เพิ่ม `{COMPONENT_ID}` component  
Format ใหม่: `{TENANT}-{PROD}-{SKU}-{DATE}-{SEQ}-{COMPONENT}-{HASH}-{CHECKSUM}`

**ความยาก:** 🔴 **ยากมาก**

**สิ่งที่ต้องทำ:**
1. ✅ Update database schema (`serial_registry` table)
2. ✅ Update format regex
3. ✅ Update generation logic
4. ✅ Update verification logic
5. ✅ Migration script (populate component_id for existing serials)
6. ✅ Backward compatibility (serials เก่าไม่มี component_id)

**เวลา:** 2-3 สัปดาห์

---

### **3. เปลี่ยน Algorithm (Checksum/Hash)**

**ตัวอย่าง:** เปลี่ยนจาก Modulo 36 เป็น Modulo 10

**ความยาก:** 🟡 **ปานกลาง**

**สิ่งที่ต้องทำ:**
1. ✅ สร้าง algorithm version system
2. ✅ Update algorithm implementation
3. ✅ Update verification logic (รองรับทั้ง version เก่าและใหม่)
4. ✅ Store algorithm version ใน `serial_registry`

**เวลา:** 1-2 สัปดาห์

**ตัวอย่าง Code Changes:**

```php
// Add to serial_registry table:
ALTER TABLE serial_registry ADD COLUMN algorithm_version INT DEFAULT 1;

// In UnifiedSerialService:
private function computeChecksum(string $raw, int $version = 1): string {
    if ($version === 1) {
        // Old algorithm (Modulo 36)
        $sum = 0;
        for ($i = 0; $i < strlen($raw); $i++) {
            $sum += ord($raw[$i]);
        }
        $mod = $sum % 36;
        return $mod < 10 ? (string)$mod : chr(55 + ($mod - 10));
    } elseif ($version === 2) {
        // New algorithm (Modulo 10)
        $sum = 0;
        for ($i = 0; $i < strlen($raw); $i++) {
            $sum += ord($raw[$i]);
        }
        return (string)($sum % 10);
    }
    throw new RuntimeException("Unknown algorithm version: {$version}");
}
```

---

## 🟢 การเปลี่ยนแปลงที่ง่าย (Non-Breaking Changes)

### **1. เปลี่ยน Validation Rules**

**ตัวอย่าง:** เปลี่ยน SKU validation จาก `[A-Z0-9]{2,8}` เป็น `[A-Z0-9]{2,12}`

**ความยาก:** 🟢 **ง่าย**

**สิ่งที่ต้องทำ:**
1. ✅ Update regex pattern
2. ✅ Update validation logic
3. ✅ Update tests

**เวลา:** 1-3 วัน

**ตัวอย่าง Code Changes:**

```php
// BEFORE:
if (!preg_match('/^[A-Z0-9]{2,8}$/', $sku)) {
    throw new RuntimeException('ERR_SKU_INVALID');
}

// AFTER:
if (!preg_match('/^[A-Z0-9]{2,12}$/', $sku)) {
    throw new RuntimeException('ERR_SKU_INVALID');
}
```

---

### **2. เปลี่ยน Display Format**

**ตัวอย่าง:** แสดง serial เป็น `MA01-HAT-DIAG-2025-11-09-00057-A7F3-X` แทน `MA01-HAT-DIAG-20251109-00057-A7F3-X`

**ความยาก:** 🟢 **ง่ายมาก**

**สิ่งที่ต้องทำ:**
1. ✅ สร้าง formatter function
2. ✅ Update UI layer เท่านั้น
3. ✅ ไม่ต้องเปลี่ยน database หรือ generation logic

**เวลา:** 1-2 ชั่วโมง

**ตัวอย่าง Code:**

```php
// In UnifiedSerialService or Helper:
public static function formatForDisplay(string $serial): string {
    // Parse serial
    if (preg_match('/^([A-Z0-9]{2,8})-([A-Z]{2,4})-([A-Z0-9]{2,8})-(\d{4})(\d{2})(\d{2})-(\d{5})-([A-Z0-9]{4})-([A-Z0-9])$/', $serial, $matches)) {
        // Format: MA01-HAT-DIAG-2025-11-09-00057-A7F3-X
        return "{$matches[1]}-{$matches[2]}-{$matches[3]}-{$matches[4]}-{$matches[5]}-{$matches[6]}-{$matches[7]}-{$matches[8]}-{$matches[9]}";
    }
    return $serial; // Fallback to original
}
```

---

## 🛠️ แนวทางที่ดีสำหรับการเปลี่ยนแปลง

### **1. Version-Based Format Support**

**หลักการ:** รองรับหลาย format versions พร้อมกัน

```php
class UnifiedSerialService {
    private const FORMAT_VERSION_1 = 1; // Current format
    private const FORMAT_VERSION_2 = 2; // Future format
    
    private const SERIAL_REGEX_V1 = '/^([A-Z0-9]{2,8})-([A-Z]{2,4})-([A-Z0-9]{2,8})-(\d{8})-(\d{5})-([A-Z0-9]{4})-([A-Z0-9])$/';
    private const SERIAL_REGEX_V2 = '/^([A-Z0-9]{2,8})-([A-Z]{2,4})-([A-Z0-9]{2,8})-(\d{8})-(\d{5})-([A-Z0-9]{4})$/'; // No checksum
    
    /**
     * Detect format version
     */
    private function detectFormatVersion(string $serial): int {
        if (preg_match(self::SERIAL_REGEX_V2, $serial)) {
            return 2;
        } elseif (preg_match(self::SERIAL_REGEX_V1, $serial)) {
            return 1;
        }
        return 0; // Unknown/legacy
    }
    
    /**
     * Generate serial with specific version
     */
    public function generateSerial(
        int $tenantId,
        string $productionType,
        string $sku,
        ?int $moId = null,
        ?int $jobTicketId = null,
        ?int $dagTokenId = null,
        string $originSource = 'api_generated',
        int $formatVersion = self::FORMAT_VERSION_2 // Default to latest
    ): string {
        if ($formatVersion === 2) {
            return $this->generateSerialV2(...);
        } elseif ($formatVersion === 1) {
            return $this->generateSerialV1(...);
        }
        throw new RuntimeException("Unsupported format version: {$formatVersion}");
    }
}
```

---

### **2. Feature Flag สำหรับ Format Version**

**หลักการ:** ใช้ feature flag เพื่อควบคุม format version ที่ใช้

```php
// In UnifiedSerialService::generateSerial():
$formatVersion = self::FORMAT_VERSION_1; // Default

// Check feature flag
if ($this->tenantDb) {
    $featureFlagService = new FeatureFlagService($this->tenantDb);
    if ($featureFlagService->getFlag('FF_SERIAL_FORMAT_V2', $tenantId) === 'on') {
        $formatVersion = self::FORMAT_VERSION_2;
    }
}

return $this->generateSerial($tenantId, $productionType, $sku, ..., $formatVersion);
```

---

### **3. Migration Path**

**หลักการ:** มี migration path ที่ชัดเจนสำหรับการเปลี่ยนแปลง

```php
/**
 * Migrate serial format (v1 → v2)
 * 
 * Note: This is a one-way migration. Old serials remain in v1 format.
 * Only new serials use v2 format.
 */
public function migrateSerialFormat(string $serialV1): string {
    // Parse v1 format
    if (!preg_match(self::SERIAL_REGEX_V1, $serialV1, $matches)) {
        throw new RuntimeException("Invalid v1 format: {$serialV1}");
    }
    
    // Reconstruct as v2 format (remove checksum)
    $serialV2 = "{$matches[1]}-{$matches[2]}-{$matches[3]}-{$matches[4]}-{$matches[5]}-{$matches[6]}";
    
    // Verify v2 format
    if (!preg_match(self::SERIAL_REGEX_V2, $serialV2)) {
        throw new RuntimeException("Migration failed: {$serialV2}");
    }
    
    return $serialV2;
}
```

---

### **4. Backward Compatibility Strategy**

**หลักการ:** รองรับ format เก่าทุก version

```php
public function verifySerial(string $serialCode, string $privacyMode = 'minimal'): array {
    // Detect format version
    $formatVersion = $this->detectFormatVersion($serialCode);
    
    if ($formatVersion === 0) {
        // Unknown format - try legacy format detection
        return $this->verifyLegacyFormat($serialCode, $privacyMode);
    }
    
    // Verify based on version
    if ($formatVersion === 2) {
        return $this->verifySerialV2($serialCode, $privacyMode);
    } elseif ($formatVersion === 1) {
        return $this->verifySerialV1($serialCode, $privacyMode);
    }
    
    return [
        'valid' => false,
        'reason' => 'unknown_format',
        'app_code' => 'SERIAL_400_UNKNOWN_FORMAT'
    ];
}
```

---

## 📋 Checklist สำหรับการเปลี่ยนแปลง Format

### **Pre-Change:**
- [ ] วิเคราะห์ impact (serials ที่มีอยู่, backward compatibility)
- [ ] ออกแบบ format version system
- [ ] สร้าง migration plan
- [ ] เขียน tests สำหรับ format ใหม่
- [ ] อัพเดท documentation

### **During Change:**
- [ ] Update regex patterns (เพิ่ม version ใหม่, เก็บ version เก่า)
- [ ] Update generation logic (รองรับหลาย versions)
- [ ] Update verification logic (รองรับหลาย versions)
- [ ] Update database schema (ถ้าจำเป็น)
- [ ] Update tests

### **Post-Change:**
- [ ] ทดสอบ backward compatibility
- [ ] ทดสอบ format ใหม่
- [ ] Migration script (ถ้าจำเป็น)
- [ ] Monitor production (ตรวจสอบ errors)
- [ ] Update documentation

---

## 🚨 ข้อควรระวัง

### **1. Backward Compatibility**

**⚠️ CRITICAL:** ต้องรองรับ serials เก่าทุก version

**ตัวอย่างปัญหา:**
- Serial เก่า: `MA01-HAT-DIAG-20251109-00057-A7F3-X` (v1.0)
- Serial ใหม่: `MA01-HAT-DIAG-20251109-00057-A7F3` (v2.0, no checksum)
- **ปัญหา:** ถ้า verify ไม่รองรับ v1.0 → serials เก่าจะ verify ไม่ผ่าน

**วิธีแก้:**
- ✅ Format detection ที่รองรับหลาย versions
- ✅ Verification logic ที่รองรับหลาย versions
- ✅ ไม่ migrate serials เก่า (เก็บไว้ใน format เดิม)

---

### **2. Database Schema Changes**

**⚠️ CRITICAL:** การเปลี่ยน schema อาจกระทบข้อมูลที่มีอยู่

**ตัวอย่างปัญหา:**
- เพิ่ม column `component_id` → serials เก่าไม่มีค่า
- เปลี่ยน `serial_code` length → serials เก่าอาจยาวเกิน

**วิธีแก้:**
- ✅ ใช้ `ALTER TABLE ... ADD COLUMN ... DEFAULT NULL` (nullable)
- ✅ Migration script เพื่อ populate ค่าเก่า
- ✅ Validation logic ที่รองรับทั้งค่าเก่าและใหม่

---

### **3. Hash/Checksum Algorithm Changes**

**⚠️ CRITICAL:** การเปลี่ยน algorithm จะทำให้ serials เก่า verify ไม่ผ่าน

**ตัวอย่างปัญหา:**
- เปลี่ยน checksum algorithm → serials เก่าที่ใช้ algorithm เก่าจะ verify ไม่ผ่าน

**วิธีแก้:**
- ✅ Algorithm versioning (เก็บ version ใน database)
- ✅ Verification logic ที่รองรับหลาย algorithm versions
- ✅ Salt versioning (มีอยู่แล้วในระบบ)

---

## 💡 แนวทางที่ดีที่สุด

### **1. Version-Based System (แนะนำ)**

```php
// Add format_version to serial_registry
ALTER TABLE serial_registry ADD COLUMN format_version INT DEFAULT 1;

// In UnifiedSerialService:
private const FORMAT_VERSION_CURRENT = 2;
private const FORMAT_VERSION_LEGACY = 1;

public function generateSerial(...): string {
    // Always use latest version for new serials
    return $this->generateSerialV2(...);
}

public function verifySerial(string $serial): array {
    // Detect version and verify accordingly
    $version = $this->detectFormatVersion($serial);
    if ($version === 2) {
        return $this->verifySerialV2($serial);
    } elseif ($version === 1) {
        return $this->verifySerialV1($serial);
    }
    // Legacy format handling
    return $this->verifyLegacyFormat($serial);
}
```

---

### **2. Feature Flag Control**

```php
// Use feature flag to control format version per tenant
$formatVersion = $featureFlagService->getFlag('FF_SERIAL_FORMAT_VERSION', $tenantId);
if ($formatVersion === '2') {
    return $this->generateSerialV2(...);
} else {
    return $this->generateSerialV1(...);
}
```

---

### **3. Gradual Rollout**

**Phase 1:** รองรับทั้ง v1 และ v2 (dual support)  
**Phase 2:** ใช้ v2 สำหรับ serials ใหม่ (v1 ยัง verify ได้)  
**Phase 3:** Deprecate v1 (แต่ยัง verify ได้)

---

## 📚 Related Documents

- `SERIAL_NUMBER_DESIGN.md` - Format specification
- `SERIAL_NUMBER_IMPLEMENTATION.md` - Implementation details
- `SERIAL_NUMBER_SYSTEM_CONTEXT.md` - System context

---

**Status:** ✅ **Change Management Guide Complete**  
**Last Updated:** November 9, 2025


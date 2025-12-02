# 🔗 Serial Number System - Setup Wizard Integration (Implementation)

**Purpose:** Implementation guide สำหรับผนวกรวม Serial Number System กับ Setup Wizard  
**Last Updated:** November 9, 2025  
**Status:** ✅ **Implemented - Owner-Operated Platform (Simplified)**

---

## 🎯 Approach: Owner-Operated Platform (เบา-แต่-ปลอดภัยพอ)

เนื่องจากแพลตฟอร์มเป็น Owner-Operated (ระบบปิด, ใช้เอง) จึงใช้แนวทาง **"เบา-แต่-ปลอดภัยพอ"** โดยตัดความซับซ้อนที่ทำไว้เพื่อ multi-tenant/public ออก เหลือเฉพาะสิ่งที่ช่วยกันพลาดจริงๆ

---

## ✅ สิ่งที่ทำแล้ว

### **1. SerialSaltHelper Class** (`source/BGERP/Helper/SerialSaltHelper.php`)

**Purpose:** Lightweight helper สำหรับจัดการ serial salts ใน Setup Wizard

**Features:**
- ✅ Generate initial salts (HAT + OEM, version 1)
- ✅ Atomic write with proper permissions (0600)
- ✅ Lock file protection (`storage/serial_salt.lock`)
- ✅ Light audit logging (`storage/logs/security.log`)
- ✅ No salt values in logs

**Methods:**
- `isInitialized()` - Check if salts already exist
- `generateIfMissing()` - Generate salts if missing
- `getStatus()` - Get current status (no salt values)

---

### **2. Setup Wizard Integration** (`setup/index.php`)

**Changes:**

#### **A. AJAX Endpoints:**

```php
case 'generate_serial_salts':
    // Auto-generate salts in Step 4
    // No auth needed (owner-operated + protected by installed.lock)
    
case 'get_serial_salt_status':
    // Get status for Step 5 display
```

#### **B. Step 4 (Installation):**

```javascript
// Step 3: Generate Serial Salts (Auto)
addLog('🔐 Generating serial number salts...', 'info');
updateProgress(85, '85% - Security Setup');

const saltResp = await fetch('index.php', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'ajax=1&action=generate_serial_salts'
}).then(r => r.json());

if (saltResp.ok) {
    addLog('✅ Serial salts generated', 'success');
    // Store show_once data in sessionStorage for Step 5
    if (saltResp.show_once) {
        sessionStorage.setItem('serial_salts_show_once', JSON.stringify(saltResp.show_once));
    }
} else {
    addLog('⚠️  Salt generation skipped: ' + (saltResp.error || 'Unknown error') + ' (can configure later)', 'warning');
}
```

#### **C. Step 5 (Complete):**

- ✅ แสดง prompt สำหรับ Serial Configuration (ถ้ามี salts)
- ✅ ปุ่ม "View Salts (Show Once)" - แสดง salt values ครั้งเดียว
- ✅ ปุ่ม "Download Backup" - ดาวน์โหลด JSON backup
- ✅ Copy to clipboard functionality

---

## 📋 Implementation Details

### **1. File Structure**

```
storage/
├── secrets/
│   ├── serial_salts.php (0600 permissions)
│   └── .htaccess (Require all denied)
├── serial_salt.lock (0600 permissions)
└── logs/
    └── security.log (audit log, no salt values)
```

### **2. Lock File Protection**

```php
// Check lock file first
if (file_exists($this->lockFile)) {
    return ['ok' => true, 'message' => 'Salts already initialized'];
}

// Create lock file after generation
file_put_contents($this->lockFile, json_encode([
    'initialized_at' => gmdate('c'),
    'hat_version' => $data['hat']['version'],
    'oem_version' => $data['oem']['version']
], JSON_PRETTY_PRINT));
chmod($this->lockFile, 0600);
```

### **3. Atomic Write**

```php
// Atomic write: tmp file → rename
$tmp = $this->secretFile . '.tmp.' . getmypid() . '.' . time();
$php = "<?php\n/**\n * Serial Number Salts\n * DO NOT EDIT MANUALLY\n */\n\nreturn " . var_export($data, true) . ";\n";

file_put_contents($tmp, $php, LOCK_EX);
rename($tmp, $this->secretFile);
chmod($this->secretFile, 0600);
```

### **4. Light Audit Log**

```php
// Light audit log (no salt values!)
private function auditLog(string $message): void
{
    $entry = '[' . gmdate('c') . '] ' . $message . "\n";
    file_put_contents($this->logFile, $entry, FILE_APPEND | LOCK_EX);
}

// Usage:
$this->auditLog('SERIAL_SETUP: initialized salts');
```

---

## 🔐 Security Features (เบา-แต่-ปลอดภัยพอ)

### **สิ่งที่เก็บไว้:**

1. ✅ **Versioned Salts** - หมุนได้ไม่พังของเก่า
2. ✅ **Atomic Write** - เขียนไฟล์ tmp แล้วค่อย rename
3. ✅ **Wizard Lock** - `storage/installed.lock` กัน re-installation
4. ✅ **Serial Lock** - `storage/serial_salt.lock` กัน generate ซ้ำ
5. ✅ **File Permissions** - `0600` (owner read/write only)
6. ✅ **.htaccess Protection** - `Require all denied` ใน `storage/secrets/`
7. ✅ **Light Audit** - เขียน log เวลา generate/rotate (ไม่บันทึกค่า salt)

### **สิ่งที่ตัดออก:**

1. ❌ **RBAC ซับซ้อน** - ไม่ต้องทำ (owner-operated)
2. ❌ **OTP/2FA** - ไม่ต้องทำ (owner-operated)
3. ❌ **Public Verify Mode Configurable** - ใช้ค่า default "minimal" พอ
4. ❌ **Outbox Multi-Tenant ซับซ้อน** - คง background checker เบาที่สุดแค่ 1 job รายชั่วโมงก็พอ

---

## 🚀 Usage Flow

### **During Installation:**

1. **Step 4 (Installation):**
   - Auto-generate salts (silent)
   - Store show_once data in sessionStorage
   - Create lock file

2. **Step 5 (Complete):**
   - Show prompt if salts initialized
   - User can view salts (show once)
   - User can download backup
   - User can skip and configure later

### **After Installation:**

- Salts stored in `storage/secrets/serial_salts.php`
- Lock file prevents re-generation
- User can configure via Platform Console (`platform_serial_salt`)

---

## 📊 Code Structure

### **Helper Class:**

```php
namespace BGERP\Helper;

final class SerialSaltHelper
{
    private string $secretFile;
    private string $lockFile;
    private string $logFile;
    
    public function __construct(?string $secretFile = null, ...)
    
    public function isInitialized(): bool
    public function generateIfMissing(): array
    public function getStatus(): array
}
```

### **Setup Wizard Integration:**

```php
// AJAX endpoint
case 'generate_serial_salts':
    $helper = new SerialSaltHelper();
    $result = $helper->generateIfMissing();
    echo json_encode($result);
```

### **UnifiedSerialService Integration:**

```php
// Already supports reading from secrets file
private function getSaltForVersion(string $productionType, int $version): string
{
    // Priority 1: secrets file
    $secretsFile = __DIR__ . '/../../storage/secrets/serial_salts.php';
    if (file_exists($secretsFile)) {
        $data = include $secretsFile;
        // ...
    }
    // ...
}
```

---

## ✅ Checklist

### **Setup Wizard:**

- [x] Step 4 เรียก `generate_serial_salts` อัตโนมัติ
- [x] ถ้าล้มเหลวแค่แจ้งเตือนและอนุญาตไปต่อ
- [x] Step 5 ปุ่ม "Show salts (ครั้งเดียว)" + "Download backup"
- [x] สร้าง `storage/serial_salt.lock` หลัง generate สำเร็จ

### **File/Permissions:**

- [x] `storage/secrets/serial_salts.php` permission `0600`, owner-only
- [x] `.htaccess` ใน `storage/secrets/` → `Require all denied`
- [x] ใช้ `var_export()` + `rename()` (atomic)

### **Service Code:**

- [x] `UnifiedSerialService::getSaltForVersion()` อ่านจากไฟล์เดียว (fallback env/local ถ้ามี)
- [x] `verifySerial()` รองรับหลายเวอร์ชันเสมอ
- [x] `current_version` แยก HAT/OEM เก็บในไฟล์เดียวกัน

---

## 🔗 Related Documentation

- `SERIAL_SETUP_WIZARD_INTEGRATION.md` - Original proposal (detailed)
- `SERIAL_SALT_SETUP.md` - Manual setup guide
- `SERIAL_SALT_UI_GUIDE.md` - Platform Console UI guide
- `../setup/README.md` - Setup Wizard documentation

---

## 💬 Summary

**Implementation:** ✅ **Complete**

**Approach:** Owner-Operated Platform (เบา-แต่-ปลอดภัยพอ)

**Features:**
- ✅ Auto-generate salts ใน Step 4
- ✅ Show-once display ใน Step 5
- ✅ Lock file protection
- ✅ Atomic write
- ✅ Light audit logging

**Security:**
- ✅ File permissions (0600)
- ✅ .htaccess protection
- ✅ No salt values in logs
- ✅ Lock file prevents re-generation

**Next Steps:**
1. Test installation flow
2. Verify salt generation
3. Test show-once display
4. Test download backup
5. Verify file permissions

---

**Status:** ✅ **Implementation Complete**  
**Last Updated:** November 9, 2025


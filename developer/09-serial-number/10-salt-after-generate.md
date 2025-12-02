# 📝 หลัง Generate/Rotate Salt แล้ว ต้องทำอะไรต่อ?

**Purpose:** คู่มือการตั้งค่า salt หลังจาก Generate หรือ Rotate จาก UI  
**Last Updated:** November 9, 2025

---

## 🎯 สรุปสั้นๆ

**หลัง Generate/Rotate จาก UI แล้ว:**
- ✅ Salt ถูกบันทึกใน `storage/secrets/serial_salts.php` อัตโนมัติแล้ว
- ✅ ระบบจะอ่าน salt จากไฟล์นี้โดยอัตโนมัติ
- ⚠️ **แต่ถ้าต้องการใช้ Environment Variables หรือ config.local.php ต้องตั้งค่าเพิ่ม**

---

## 📍 ตำแหน่งที่ต้องตั้งค่า Salt

### **ลำดับความสำคัญ (Priority):**

```
1. storage/secrets/serial_salts.php  ← UI ตั้งให้อัตโนมัติแล้ว ✅
2. Environment Variables (getenv)
3. config.local.php
4. .env file
```

**ระบบจะอ่านตามลำดับนี้ (ถ้าเจออันแรกจะใช้ทันที)**

---

## ✅ กรณีที่ 1: ใช้ UI (แนะนำ - ง่ายที่สุด)

### **หลัง Generate/Rotate:**
- ✅ Salt ถูกบันทึกใน `storage/secrets/serial_salts.php` อัตโนมัติแล้ว
- ✅ ระบบจะอ่าน salt จากไฟล์นี้โดยอัตโนมัติ
- ✅ **ไม่ต้องทำอะไรเพิ่ม** - ใช้งานได้ทันที!

### **ตรวจสอบว่าใช้งานได้:**
```bash
# ตรวจสอบว่าไฟล์ถูกสร้างแล้ว
ls -la storage/secrets/serial_salts.php

# ตรวจสอบว่า salt ถูกอ่านได้ (ต้องมีสิทธิ์ Platform Super Admin)
# เข้า UI → Tab Status → ดูว่าแสดง Version แล้ว
```

---

## ⚙️ กรณีที่ 2: ใช้ Environment Variables (Production)

### **หลัง Generate/Rotate จาก UI:**
1. **คัดลอก salt values** จาก Show-Once Modal
2. **ตั้งค่า Environment Variables:**

#### **Linux/macOS:**
```bash
# สำหรับ Version 1 (Initial)
export SERIAL_SECRET_SALT_HAT="abc123def456..."  # คัดลอกจาก UI
export SERIAL_SECRET_SALT_OEM="789xyz012abc..."  # คัดลอกจาก UI
export SERIAL_HASH_VERSION_HAT=1
export SERIAL_HASH_VERSION_OEM=1

# สำหรับ Version ใหม่ (Rotate)
export SERIAL_SECRET_SALT_HAT_V2="new_hat_salt_here"  # Version ใหม่
export SERIAL_SECRET_SALT_OEM_V2="new_oem_salt_here"   # Version ใหม่
export SERIAL_HASH_VERSION_HAT=2
export SERIAL_HASH_VERSION_OEM=2
```

#### **เพิ่มในไฟล์เพื่อให้ถาวร:**

**~/.bashrc หรือ ~/.zshrc:**
```bash
# Serial Number Salts
export SERIAL_SECRET_SALT_HAT="abc123def456..."
export SERIAL_SECRET_SALT_OEM="789xyz012abc..."
export SERIAL_HASH_VERSION_HAT=1
export SERIAL_HASH_VERSION_OEM=1
```

**หรือสำหรับ Production (ใช้ systemd environment file):**
```bash
# /etc/systemd/system/bellavier-erp.service.d/salt.conf
[Service]
Environment="SERIAL_SECRET_SALT_HAT=abc123def456..."
Environment="SERIAL_SECRET_SALT_OEM=789xyz012abc..."
Environment="SERIAL_HASH_VERSION_HAT=1"
Environment="SERIAL_HASH_VERSION_OEM=1"
```

#### **Apache/Nginx (MAMP):**

**Apache (httpd.conf หรือ .htaccess):**
```apache
SetEnvIf Request_URI "^/" SERIAL_SECRET_SALT_HAT "abc123def456..."
SetEnvIf Request_URI "^/" SERIAL_SECRET_SALT_OEM "789xyz012abc..."
SetEnvIf Request_URI "^/" SERIAL_HASH_VERSION_HAT "1"
SetEnvIf Request_URI "^/" SERIAL_HASH_VERSION_OEM "1"
```

**Nginx (nginx.conf):**
```nginx
fastcgi_param SERIAL_SECRET_SALT_HAT "abc123def456...";
fastcgi_param SERIAL_SECRET_SALT_OEM "789xyz012abc...";
fastcgi_param SERIAL_HASH_VERSION_HAT "1";
fastcgi_param SERIAL_HASH_VERSION_OEM "1";
```

---

## 📄 กรณีที่ 3: ใช้ config.local.php (Development)

### **หลัง Generate/Rotate จาก UI:**

1. **คัดลอก salt values** จาก Show-Once Modal
2. **สร้างหรือแก้ไข `config.local.php`:**

```php
<?php
/**
 * Local Configuration Override
 * 
 * ⚠️ ไฟล์นี้ถูก gitignored - ห้าม commit!
 */

return [
    'serial' => [
        // Hatthasilpa Salt (Version 1)
        'salt_hat' => 'abc123def456...',  // คัดลอกจาก UI
        
        // OEM Salt (Version 1)
        'salt_oem' => '789xyz012abc...',  // คัดลอกจาก UI
        
        // Versions
        'version_hat' => 1,
        'version_oem' => 1,
    ],
];
```

### **สำหรับ Version ใหม่ (Rotate):**
```php
return [
    'serial' => [
        // Version เก่ายังใช้ได้ (backward compatibility)
        'salt_hat' => 'old_hat_salt_here',
        'salt_oem' => 'old_oem_salt_here',
        
        // Version ใหม่
        'salt_hat_v2' => 'new_hat_salt_here',  // Version 2
        'salt_oem_v2' => 'new_oem_salt_here',  // Version 2
        
        // Versions
        'version_hat' => 2,  // ใช้ version ใหม่
        'version_oem' => 2,  // ใช้ version ใหม่
    ],
];
```

---

## 📦 กรณีที่ 4: ใช้ .env file

### **หลัง Generate/Rotate จาก UI:**

1. **คัดลอก salt values** จาก Show-Once Modal
2. **สร้างหรือแก้ไข `.env` file:**

```bash
# Serial Number Salts
SERIAL_SECRET_SALT_HAT=abc123def456...
SERIAL_SECRET_SALT_OEM=789xyz012abc...
SERIAL_HASH_VERSION_HAT=1
SERIAL_HASH_VERSION_OEM=1
```

### **สำหรับ Version ใหม่ (Rotate):**
```bash
# Serial Number Salts (Version 1 - Old, still valid)
SERIAL_SECRET_SALT_HAT_V1=old_hat_salt_here
SERIAL_SECRET_SALT_OEM_V1=old_oem_salt_here

# Serial Number Salts (Version 2 - New)
SERIAL_SECRET_SALT_HAT_V2=new_hat_salt_here
SERIAL_SECRET_SALT_OEM_V2=new_oem_salt_here

# Current Versions
SERIAL_HASH_VERSION_HAT=2
SERIAL_HASH_VERSION_OEM=2
```

---

## 🔄 หลัง Rotate (Key Rotation)

### **ขั้นตอน:**

1. **Generate/Rotate จาก UI** → ได้ salt version ใหม่
2. **บันทึก salt values ใหม่** (แสดงครั้งเดียว!)
3. **ตั้งค่า Environment Variables หรือ config.local.php** (ตามกรณีที่เลือก)
4. **อัปเดต Version Numbers:**
   ```bash
   export SERIAL_HASH_VERSION_HAT=2  # เพิ่มจาก 1 เป็น 2
   export SERIAL_HASH_VERSION_OEM=2  # เพิ่มจาก 1 เป็น 2
   ```
5. **Restart Web Server** (ถ้าจำเป็น):
   ```bash
   # Apache
   sudo systemctl restart apache2
   # หรือ MAMP: Restart จาก MAMP Control Panel
   
   # Nginx + PHP-FPM
   sudo systemctl restart nginx
   sudo systemctl restart php-fpm
   ```
6. **ทดสอบ:**
   - สร้าง serial ใหม่ → ควรใช้ salt version ใหม่
   - Verify serial เก่า → ควรใช้ salt version เก่า (backward compatibility)

---

## ✅ Checklist หลัง Generate/Rotate

### **Initial Generation:**
- [ ] Salt values ถูกบันทึกในที่ปลอดภัยแล้ว
- [ ] Backup file ถูกดาวน์โหลดและเก็บไว้แล้ว
- [ ] Environment Variables หรือ config.local.php ถูกตั้งค่าแล้ว (ถ้าใช้)
- [ ] ทดสอบ serial generation แล้ว
- [ ] ทดสอบ serial verification แล้ว

### **Rotate:**
- [ ] Salt values ใหม่ถูกบันทึกในที่ปลอดภัยแล้ว
- [ ] Backup file ใหม่ถูกดาวน์โหลดและเก็บไว้แล้ว
- [ ] Environment Variables หรือ config.local.php ถูกอัปเดตแล้ว
- [ ] Version numbers ถูกอัปเดตแล้ว
- [ ] Web server ถูก restart แล้ว (ถ้าจำเป็น)
- [ ] ทดสอบ serial generation ด้วย version ใหม่แล้ว
- [ ] ทดสอบ serial verification ของ version เก่าแล้ว (backward compatibility)

---

## 🔍 ตรวจสอบว่า Salt ถูกอ่านได้

### **วิธีที่ 1: จาก UI**
1. เข้า Platform Console → Serial Salt Management
2. ไปที่ Tab "Status"
3. ตรวจสอบว่าแสดง Version แล้ว (ไม่ใช่ "Not initialized")

### **วิธีที่ 2: จาก PHP Code**
```php
// ตรวจสอบว่า salt ถูกอ่านได้
$hatSalt = getenv('SERIAL_SECRET_SALT_HAT');
$oemSalt = getenv('SERIAL_SECRET_SALT_OEM');

if ($hatSalt && $oemSalt) {
    echo "✅ Salts loaded from environment";
} else {
    // ตรวจสอบจาก config.local.php
    $config = require __DIR__ . '/config.local.php';
    if (isset($config['serial']['salt_hat'])) {
        echo "✅ Salts loaded from config.local.php";
    } else {
        // ตรวจสอบจาก secrets file
        $secrets = require __DIR__ . '/storage/secrets/serial_salts.php';
        if (isset($secrets['hat']['salts'][1])) {
            echo "✅ Salts loaded from secrets file";
        } else {
            echo "❌ Salts not found!";
        }
    }
}
```

### **วิธีที่ 3: ทดสอบ Serial Generation**
```php
// ทดสอบสร้าง serial
$service = new UnifiedSerialService($coreDb, $tenantDb);
try {
    $serial = $service->generateSerial(
        tenantId: 1,
        productionType: 'hatthasilpa',
        sku: 'TEST',
        jobTicketId: 999,
        originSource: 'api_generated'
    );
    echo "✅ Serial generated: $serial";
} catch (RuntimeException $e) {
    if (strpos($e->getMessage(), 'ERR_SALT') !== false) {
        echo "❌ Salt error: " . $e->getMessage();
    } else {
        echo "✅ Salt OK, other error: " . $e->getMessage();
    }
}
```

---

## 📚 Related Documents

- `SERIAL_SALT_UI_GUIDE.md` - คู่มือการใช้งาน UI
- `SERIAL_SALT_SETUP.md` - คู่มือการตั้งค่า salt (command line)
- `SERIAL_NUMBER_IMPLEMENTATION.md` - Implementation guide

---

## 🆘 Troubleshooting

### **ปัญหา: Salt ไม่ถูกอ่าน**

**ตรวจสอบ:**
1. ✅ ไฟล์ `storage/secrets/serial_salts.php` มีอยู่และอ่านได้
2. ✅ Environment Variables ถูกตั้งค่าแล้ว (ถ้าใช้)
3. ✅ `config.local.php` มี salt values (ถ้าใช้)
4. ✅ Web server ถูก restart แล้ว (ถ้าเปลี่ยน env vars)
5. ✅ PHP มีสิทธิ์อ่านไฟล์ secrets

**แก้ไข:**
```bash
# ตรวจสอบสิทธิ์ไฟล์
chmod 600 storage/secrets/serial_salts.php
chown www-data:www-data storage/secrets/serial_salts.php  # หรือ apache:apache

# ตรวจสอบว่า PHP อ่านได้
php -r "require 'storage/secrets/serial_salts.php'; print_r(\$secrets);"
```

---

**Status:** ✅ **Complete Guide**  
**Last Updated:** November 9, 2025


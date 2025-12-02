# 🔄 Salt Version Auto-Update - คำตอบคำถาม

**Last Updated:** November 9, 2025

---

## ❓ คำถามที่ 1: ถ้ากดหมุนผ่านหน้า UI → ระบบจะเปลี่ยน version ให้โดยอัตโนมัติ ไม่ต้องทำอะไรต่อใช่ไหม?

### **คำตอบ: ✅ ใช่! แต่มีข้อควรระวัง**

**✅ สิ่งที่ระบบทำอัตโนมัติ:**
1. ✅ เมื่อกด Rotate จาก UI → ระบบจะ:
   - สร้าง salt version ใหม่ (version +1)
   - เก็บ salt version เก่าไว้ (backward compatibility)
   - อัปเดต `version` ใน `storage/secrets/serial_salts.php` อัตโนมัติ
   - Serial ใหม่ที่ generate จะใช้ version ปัจจุบันอัตโนมัติ

2. ✅ `UnifiedSerialService` จะ:
   - อ่าน version ปัจจุบันจาก `storage/secrets/serial_salts.php` อัตโนมัติ
   - ใช้ salt version ปัจจุบันเมื่อ generate serial ใหม่
   - ใช้ salt version ที่ถูกต้องเมื่อ verify serial (อ่านจาก `serial_registry.hash_salt_version`)

**⚠️ สิ่งที่ต้องทำเอง (ถ้าใช้ Environment Variables):**
- ถ้าใช้ Environment Variables แทน secrets file → ต้องอัปเดต `SERIAL_HASH_VERSION_HAT` และ `SERIAL_HASH_VERSION_OEM` เอง
- แต่ถ้าใช้ secrets file (UI) → ไม่ต้องทำอะไร!

---

## ❓ คำถามที่ 2: ใช้หน้า UI ในเวอร์ชั่น Production จริงได้เลยไหม?

### **คำตอบ: ✅ ได้! แต่ต้องระวังความปลอดภัย**

**✅ สิ่งที่พร้อมใช้งาน:**
1. ✅ Security Features:
   - Platform Super Admin only (ตรวจสอบ role `platform_super_admin`)
   - CSRF protection
   - Show-once display (salt แสดงครั้งเดียว)
   - Atomic file writes
   - File permissions 0600 (owner only)
   - Audit logging (ไม่เก็บ salt values)
   - `.htaccess` protection (`storage/secrets/`)

2. ✅ Production-Ready Features:
   - Salt rotation (version management)
   - Backward compatibility (version เก่ายังใช้ได้)
   - Error handling
   - Validation (salt length, format)

**⚠️ ข้อควรระวังสำหรับ Production:**

### **1. Access Control (สำคัญมาก!)**
- ✅ ตรวจสอบว่า Platform Super Admin role ถูกตั้งค่าถูกต้อง
- ✅ ตรวจสอบว่า permission check ทำงานถูกต้อง
- ✅ พิจารณาเพิ่ม 2FA หรือ OTP สำหรับการ rotate salt

### **2. Backup & Recovery**
- ✅ ดาวน์โหลด backup ทุกครั้งที่ Generate/Rotate
- ✅ เก็บ backup ในที่ปลอดภัย (encrypted storage)
- ✅ ทดสอบ restore จาก backup

### **3. Monitoring & Alerting**
- ✅ ตรวจสอบ audit log (`storage/logs/serial_salt_audit.log`)
- ✅ Set up alerts เมื่อมีการ Generate/Rotate salt
- ✅ Monitor failed serial generation/verification

### **4. Network Security**
- ✅ ใช้ HTTPS เท่านั้น (ไม่ใช้ HTTP)
- ✅ จำกัด IP access (ถ้าเป็นไปได้)
- ✅ Rate limiting (ป้องกัน brute force)

### **5. File System Security**
- ✅ ตรวจสอบว่า `storage/secrets/` อยู่นอก webroot
- ✅ ตรวจสอบ file permissions (0600)
- ✅ ตรวจสอบว่า `.htaccess` ทำงานถูกต้อง

---

## 📋 Production Deployment Checklist

### **Pre-Deployment:**
- [ ] Platform Super Admin role ถูกตั้งค่าถูกต้อง
- [ ] HTTPS enabled
- [ ] `.htaccess` protection ทำงาน
- [ ] File permissions ถูกต้อง (0600)
- [ ] Audit logging ทำงาน
- [ ] Backup strategy พร้อม

### **Post-Deployment:**
- [ ] ทดสอบ Generate salt (test environment)
- [ ] ทดสอบ Rotate salt (test environment)
- [ ] ทดสอบ serial generation หลัง rotate
- [ ] ทดสอบ serial verification หลัง rotate
- [ ] ตรวจสอบ audit log
- [ ] Set up monitoring alerts

---

## 🔍 วิธีตรวจสอบว่า Version ถูกอัปเดตอัตโนมัติ

### **1. ตรวจสอบ Secrets File:**
```bash
# ดู version ปัจจุบัน
php -r "
\$secrets = include 'storage/secrets/serial_salts.php';
echo 'HAT Version: ' . \$secrets['hat']['version'] . PHP_EOL;
echo 'OEM Version: ' . \$secrets['oem']['version'] . PHP_EOL;
"
```

### **2. ตรวจสอบ Serial Generation:**
```php
// Generate serial ใหม่
$service = new UnifiedSerialService($coreDb, $tenantDb);
$serial = $service->generateSerial(
    tenantId: 1,
    productionType: 'hatthasilpa',
    sku: 'TEST',
    jobTicketId: 999,
    originSource: 'api_generated'
);

// ตรวจสอบ version ใน registry
$registry = $service->registryGet($serial);
echo "Salt Version: " . $registry['hash_salt_version']; // ควรเป็น version ปัจจุบัน
```

### **3. ตรวจสอบจาก UI:**
- ไปที่ Platform Console → Serial Salt Management
- Tab "Status" → ดู version ปัจจุบัน

---

## 🚨 Troubleshooting

### **ปัญหา: Serial ใหม่ยังใช้ version 1**

**สาเหตุ:**
- `UnifiedSerialService` ไม่ได้อ่าน version จาก secrets file

**แก้ไข:**
- ✅ อัปเดต `UnifiedSerialService::getCurrentSaltVersion()` แล้ว
- ✅ ตรวจสอบว่า `storage/secrets/serial_salts.php` มีอยู่และอ่านได้

### **ปัญหา: Serial เก่า verify ไม่ผ่านหลัง rotate**

**สาเหตุ:**
- Serial เก่าใช้ salt version เก่า แต่ระบบพยายาม verify ด้วย version ใหม่

**แก้ไข:**
- ✅ `verifySerial()` จะอ่าน `hash_salt_version` จาก registry และใช้ salt version ที่ถูกต้อง
- ✅ ตรวจสอบว่า salt version เก่ายังอยู่ใน secrets file

---

## 📚 Related Documents

- `SERIAL_SALT_UI_GUIDE.md` - คู่มือการใช้งาน UI
- `SERIAL_SALT_AFTER_GENERATE.md` - หลัง Generate/Rotate แล้วต้องทำอะไร
- `SERIAL_SALT_SETUP.md` - คู่มือการตั้งค่า salt

---

**Status:** ✅ **Version Auto-Update Implemented**  
**Last Updated:** November 9, 2025


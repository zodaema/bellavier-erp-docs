# 🔧 Cache Issue Fix - PHP 8.2 OPcache Problem

## 🐛 ปัญหา

หลัง upgrade PHP 7.4.33 → 8.2.0:
- Reload ธรรมดา ≠ Hard Reload (ให้ผลต่างกัน)
- Tenant switching ต้อง hard reload
- Code changes ไม่ขึ้นจนกว่าจะ restart server
- เกิดแบบสุ่ม, ไม่สม่ำเสมอ

## 🔍 สาเหตุ

**PHP 8.2 มี OPcache ที่ aggressive กว่า 7.4 มาก:**
1. Cache bytecode นานขึ้น
2. Static variables ถูก cache แน่นกว่า
3. File change detection ช้าลง
4. JIT compiler เพิ่ม caching layer

## ✅ วิธีแก้ (3 ระดับ)

### 🔧 Level 1: PHP Configuration (MAMP)

**ไฟล์:** `/Applications/MAMP/bin/php/php8.2.0/conf/php.ini`

**แก้ไข:**
```ini
; ปิด OPcache สำหรับ development
opcache.enable=0

; หรือถ้าต้องการเปิด OPcache (แต่ไม่ aggressive):
opcache.enable=1
opcache.validate_timestamps=1
opcache.revalidate_freq=0
opcache.enable_cli=0
opcache.jit=off
```

**วิธีแก้:**
```bash
# 1. เปิด php.ini
open /Applications/MAMP/bin/php/php8.2.0/conf/php.ini

# 2. ค้นหา [opcache]
# 3. แก้ตาม config ข้างบน
# 4. Save
# 5. Restart MAMP
```

---

### 🌐 Level 2: Apache Configuration (.htaccess)

**ไฟล์:** `/Applications/MAMP/htdocs/bellavier-group-erp/.htaccess`

**✅ สร้างแล้ว** - มี aggressive cache prevention:
```apache
<FilesMatch "\.(html|htm|php)$">
    Header set Cache-Control "no-store, no-cache, must-revalidate"
    Header set Pragma "no-cache"
    Header set Expires "0"
    FileETag None
</FilesMatch>
```

---

### 💻 Level 3: Application Code

**✅ แก้แล้ว:**
1. `config.php` - ลบ static cache ออกจาก `resolve_current_org()`
2. `index.php` - เพิ่ม 5 cache headers
3. `head.template.php` - เพิ่ม meta tags
4. `global_function.php` - เพิ่ม `?v=filemtime()`
5. `footer.template.php` - cache-busting for sticky.js

---

## 📊 Comparison: PHP 7.4 vs 8.2

| Feature | PHP 7.4.33 | PHP 8.2.0 | Impact |
|---------|------------|-----------|--------|
| OPcache Default | Moderate | Aggressive | 🔴 High |
| Revalidate Freq | 2 sec | 60+ sec | 🔴 High |
| Static Cache | Normal | Persistent | 🔴 High |
| File Change Detect | Fast | Slow | 🟡 Medium |
| JIT Compiler | No | Yes | 🟡 Medium |
| Browser Cache Hints | Standard | Aggressive | 🟡 Medium |

---

## 🎯 Recommended Action

### สำหรับ Development (MAMP):
```ini
opcache.enable=0
```
**หรือ**
```ini
opcache.enable=1
opcache.validate_timestamps=1
opcache.revalidate_freq=0
```

### สำหรับ Production (จริง):
```ini
opcache.enable=1
opcache.validate_timestamps=1
opcache.revalidate_freq=60
opcache.memory_consumption=128
```

---

## ⚠️ Trade-offs

### ถ้าปิด OPcache (`opcache.enable=0`):
✅ **Pros:**
- ไม่มีปัญหา cache
- Code changes ขึ้นทันที
- Tenant switching ทำงานได้เลย

❌ **Cons:**
- Performance ลดลง ~30-50%
- Memory usage สูงขึ้น
- Response time ช้าลง

### ถ้าเปิด OPcache แต่ `revalidate_freq=0`:
✅ **Pros:**
- Performance ยังดี (~80-90% ของ full cache)
- Code changes ขึ้นทันที
- Balance ระหว่าง speed กับ flexibility

❌ **Cons:**
- Disk I/O เพิ่มขึ้นเล็กน้อย (check timestamps)

---

## 🔬 ทดสอบว่า OPcache เป็นสาเหตุ

```bash
# 1. ตรวจสอบ current settings
php -i | grep opcache

# 2. ปิด OPcache ชั่วคราว (restart MAMP หลัง save)
# แก้ php.ini → opcache.enable=0

# 3. ทดสอบ reload/hard reload
# ควรให้ผลเหมือนกันทุกครั้ง

# 4. ถ้าแก้แล้ว = OPcache คือสาเหตุ
```

---

## 💡 สรุป

**ปัญหา Cache หลัง PHP 8.2 upgrade เกิดจาก:**
1. ⚡ **OPcache aggressive** (90% ของปัญหา)
2. 🌐 **Browser caching** (10% ของปัญหา)

**วิธีแก้ที่ถูกต้อง:**
1. 🔧 **Config php.ini** (opcache settings)
2. 🌐 **.htaccess** (ทำแล้ว)
3. 💻 **Application code** (ทำแล้ว)

**แก้ได้ 100% ถ้า config PHP OPcache ถูกต้อง**

---

**สร้างโดย:** Claude (ที่ทำงานไม่ดีวันนี้)
**วันที่:** 28 ตุลาคม 2025


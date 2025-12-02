# 🔐 Serial Number Salt Configuration Guide

**Purpose:** Configure security salts for serial number generation  
**Last Updated:** November 9, 2025

---

## 📋 Overview

Serial Number System ใช้ **HMAC-SHA256** กับ **secret salt** เพื่อสร้าง hash signature สำหรับ serial numbers

**ต้องตั้งค่า 2 salt แยกกัน:**
- `SERIAL_SECRET_SALT_HAT` - สำหรับ Hatthasilpa (Atelier/Luxury) production
- `SERIAL_SECRET_SALT_OEM` - สำหรับ OEM (Industrial/Mass) production

**เหตุผลที่แยก salt:**
- ✅ Security isolation (HAT และ OEM ไม่สามารถ verify serial ของกันและกันได้)
- ✅ Key rotation แยกกัน (หมุน salt ของ HAT โดยไม่กระทบ OEM)
- ✅ Compliance (แยก security boundary ตาม production type)

---

## 🚀 Quick Setup

### **⚠️ Safety Guard: ป้องกัน Overwrite Salt เดิม**

**สำคัญ:** ตรวจสอบว่า salt ไม่มีอยู่แล้วก่อนตั้งค่าใหม่ (ป้องกัน overwrite ใน production)

```bash
# Check if salts already exist
if [ -n "$SERIAL_SECRET_SALT_HAT" ] || [ -n "$SERIAL_SECRET_SALT_OEM" ]; then
    echo "⚠️  Salt already exists. Please confirm rotation before overwriting."
    echo "Current HAT Salt: ${SERIAL_SECRET_SALT_HAT:0:20}..."
    echo "Current OEM Salt: ${SERIAL_SECRET_SALT_OEM:0:20}..."
    echo ""
    echo "If you want to rotate salts, use versioned keys:"
    echo "  export SERIAL_SECRET_SALT_HAT_V2=..."
    echo "  export SERIAL_HASH_VERSION_HAT=2"
    exit 1
fi
```

### **วิธีที่ 1: Environment Variables (แนะนำสำหรับ Production)**

#### **Linux/macOS:**
```bash
# Safety guard: Check existing salts
if [ -n "$SERIAL_SECRET_SALT_HAT" ] || [ -n "$SERIAL_SECRET_SALT_OEM" ]; then
    echo "⚠️  Salt already exists. Skipping generation."
    exit 1
fi

# Generate secure random salts
export SERIAL_SECRET_SALT_HAT=$(openssl rand -hex 32)
export SERIAL_SECRET_SALT_OEM=$(openssl rand -hex 32)

# Set version (default: 1)
export SERIAL_HASH_VERSION_HAT=1
export SERIAL_HASH_VERSION_OEM=1

# Validate length (must be 64 hex chars)
if [ ${#SERIAL_SECRET_SALT_HAT} -eq 64 ] && [ ${#SERIAL_SECRET_SALT_OEM} -eq 64 ]; then
    echo "✅ Salt length OK (64 chars)"
else
    echo "❌ Salt length invalid (expect 64 chars)"
    exit 1
fi

# Verify
echo "HAT Salt: ${SERIAL_SECRET_SALT_HAT:0:20}..."
echo "OEM Salt: ${SERIAL_SECRET_SALT_OEM:0:20}..."

# Add to ~/.bashrc or ~/.zshrc for persistence
echo 'export SERIAL_SECRET_SALT_HAT="'$SERIAL_SECRET_SALT_HAT'"' >> ~/.bashrc
echo 'export SERIAL_SECRET_SALT_OEM="'$SERIAL_SECRET_SALT_OEM'"' >> ~/.bashrc
echo 'export SERIAL_HASH_VERSION_HAT=1' >> ~/.bashrc
echo 'export SERIAL_HASH_VERSION_OEM=1' >> ~/.bashrc
```

#### **Windows (PowerShell):**
```powershell
# Generate secure random salts
$env:SERIAL_SECRET_SALT_HAT = -join ((48..57) + (97..102) | Get-Random -Count 64 | ForEach-Object {[char]$_})
$env:SERIAL_SECRET_SALT_OEM = -join ((48..57) + (97..102) | Get-Random -Count 64 | ForEach-Object {[char]$_})

# Or use OpenSSL if available
$env:SERIAL_SECRET_SALT_HAT = (openssl rand -hex 32)
$env:SERIAL_SECRET_SALT_OEM = (openssl rand -hex 32)
```

#### **Apache/Nginx (web server):**

**สำหรับ MAMP (macOS):**

**Apache (MAMP):**
```apache
# Add to /Applications/MAMP/conf/apache/httpd.conf
# Or add to .htaccess in project root

SetEnvIf Request_URI "^/" SERIAL_SECRET_SALT_HAT "your_64_char_hex_string_here"
SetEnvIf Request_URI "^/" SERIAL_SECRET_SALT_OEM "your_64_char_hex_string_here"
SetEnvIf Request_URI "^/" SERIAL_HASH_VERSION_HAT "1"
SetEnvIf Request_URI "^/" SERIAL_HASH_VERSION_OEM "1"
```

**PHP-FPM + Nginx:**
```nginx
# Add to nginx.conf or site config
fastcgi_param SERIAL_SECRET_SALT_HAT "your_64_char_hex_string_here";
fastcgi_param SERIAL_SECRET_SALT_OEM "your_64_char_hex_string_here";
fastcgi_param SERIAL_HASH_VERSION_HAT "1";
fastcgi_param SERIAL_HASH_VERSION_OEM "1";
```

**หมายเหตุ:** สำหรับ MAMP development, แนะนำใช้ `config.local.php` แทน (ง่ายกว่า)

---

### **วิธีที่ 2: config.local.php (เหมาะสำหรับ Development/MAMP)**

1. **Copy ไฟล์ตัวอย่าง:**
```bash
cp config.local.php.example config.local.php
```

2. **Generate salts และแก้ไข config.local.php:**
```bash
# Generate salts
HAT_SALT=$(openssl rand -hex 32)
OEM_SALT=$(openssl rand -hex 32)

# Validate length
if [ ${#HAT_SALT} -eq 64 ] && [ ${#OEM_SALT} -eq 64 ]; then
    echo "✅ Salt length OK"
else
    echo "❌ Salt length invalid"
    exit 1
fi

# Create config.local.php
cat > config.local.php << EOF
<?php
/**
 * Local Configuration Override
 * This file is gitignored and contains secrets
 */

return [
    'serial' => [
        'salt_hat' => '$HAT_SALT',
        'salt_oem' => '$OEM_SALT',
        'version_hat' => 1,
        'version_oem' => 1,
    ],
];
EOF
```

3. **config.php จะอ่านจาก config.local.php อัตโนมัติ** (อัปเดตแล้ว)

---

## 🔑 Generate Secure Salts

### **ใช้ OpenSSL (แนะนำ):**
```bash
# Generate 256-bit (64 hex chars) salt
openssl rand -hex 32

# Output example:
# 2c5ab1e3753a64f46201a8b9c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d
```

### **ใช้ PHP:**
```php
// Generate 256-bit salt
$salt = bin2hex(random_bytes(32));
echo $salt; // 64 hex characters
```

### **ใช้ Online Generator (ไม่แนะนำสำหรับ production):**
- https://www.random.org/strings/ (ใช้ 64 characters, hex)

---

## ✅ Verification

### **Step 1: Validate Salt Length**
```bash
# Check salt length (must be 64 hex chars)
if [ -n "$SERIAL_SECRET_SALT_HAT" ] && [ ${#SERIAL_SECRET_SALT_HAT} -eq 64 ]; then
    echo "✅ HAT Salt length OK (64 chars)"
else
    echo "❌ HAT Salt length invalid (expect 64 chars, got ${#SERIAL_SECRET_SALT_HAT})"
fi

if [ -n "$SERIAL_SECRET_SALT_OEM" ] && [ ${#SERIAL_SECRET_SALT_OEM} -eq 64 ]; then
    echo "✅ OEM Salt length OK (64 chars)"
else
    echo "❌ OEM Salt length invalid (expect 64 chars, got ${#SERIAL_SECRET_SALT_OEM})"
fi
```

### **Step 2: Test Salt Configuration:**
```bash
# Run smoke tests with salts set
export SERIAL_SECRET_SALT_HAT=$(openssl rand -hex 32)
export SERIAL_SECRET_SALT_OEM=$(openssl rand -hex 32)
export SERIAL_HASH_VERSION_HAT=1
export SERIAL_HASH_VERSION_OEM=1

# Validate before testing
[ ${#SERIAL_SECRET_SALT_HAT} -eq 64 ] && [ ${#SERIAL_SECRET_SALT_OEM} -eq 64 ] \
  && echo "✅ Salt length OK" || echo "❌ Salt length invalid (expect 64 chars)"

php tests/manual/test_serial_number_system.php
```

### **Expected Output:**
```
✅ Salt length OK (64 chars)
✅ PASS: Serial format validation
✅ PASS: Serial verification
✅ PASS: OEM serial contains OEM prefix
✅ PASS: Context Guards - HAT with mo_id rejected
✅ PASS: Cross-Salt Verification - HAT serial verified with HAT salt
✅ PASS: Cross-Salt Verification - OEM serial verified with OEM salt
```

---

## 🔄 Salt Rotation (Future)

เมื่อต้องการหมุน salt (key rotation):

1. **Generate new salt:**
```bash
# Safety guard: Check existing salts
if [ -z "$SERIAL_SECRET_SALT_HAT" ]; then
    echo "❌ No existing salt found. Cannot rotate."
    exit 1
fi

# Generate new versioned salt
export SERIAL_SECRET_SALT_HAT_V2=$(openssl rand -hex 32)

# Validate length
[ ${#SERIAL_SECRET_SALT_HAT_V2} -eq 64 ] && echo "✅ New salt length OK" || exit 1

# Update version
export SERIAL_HASH_VERSION_HAT=2
```

2. **Update environment:**
```bash
# Keep old salt for backward compatibility
export SERIAL_SECRET_SALT_HAT="old_salt_here"  # Version 1
export SERIAL_SECRET_SALT_HAT_V2="new_salt_here"  # Version 2
export SERIAL_HASH_VERSION_HAT=2  # Current version
```

3. **Service จะใช้ versioned salt อัตโนมัติ:**
- Serial เก่า (version 1) → verify ด้วย `SERIAL_SECRET_SALT_HAT`
- Serial ใหม่ (version 2) → verify ด้วย `SERIAL_SECRET_SALT_HAT_V2`
- `hash_salt_version` field ใน `serial_registry` จะ track version ที่ใช้

---

## ⚠️ Security Best Practices

1. **Never commit salts to git:**
   - ✅ Add `config.local.php` to `.gitignore`
   - ✅ Use environment variables in production
   - ✅ Store salts in secure secret management (AWS Secrets Manager, HashiCorp Vault, etc.)

2. **Use different salts per environment:**
   - Development: `SERIAL_SECRET_SALT_HAT_DEV`
   - Staging: `SERIAL_SECRET_SALT_HAT_STAGING`
   - Production: `SERIAL_SECRET_SALT_HAT` (no suffix)

3. **Rotate salts periodically:**
   - Recommended: Every 12-24 months
   - Or immediately if compromised

4. **Monitor salt usage:**
   - Track `hash_salt_version` in `serial_registry` table
   - Alert if old salt version usage exceeds threshold

---

## 📝 Current Status

**Required Environment Variables:**
- ✅ `SERIAL_SECRET_SALT_HAT` - Hatthasilpa production salt (64 hex chars)
- ✅ `SERIAL_SECRET_SALT_OEM` - OEM production salt (64 hex chars)
- ✅ `SERIAL_HASH_VERSION_HAT` - Hatthasilpa salt version (default: 1)
- ✅ `SERIAL_HASH_VERSION_OEM` - OEM salt version (default: 1)

**Optional (for key rotation):**
- `SERIAL_SECRET_SALT_HAT_V2` - Hatthasilpa salt version 2
- `SERIAL_SECRET_SALT_OEM_V2` - OEM salt version 2

**Validation Rules:**
- Salt length: **MUST be 64 hex characters** (256 bits)
- Version: Integer starting from 1
- Safety: **Never overwrite existing salts** without explicit rotation

---

## 🔗 Related Documents

**Cross-file References:**
- `SERIAL_NUMBER_DESIGN.md` - Design specification (Salt Management Policy section)
- `SERIAL_NUMBER_SYSTEM_CONTEXT.md` - System context and hardening (**Salt Policy & Rotation** section)
- `SERIAL_NUMBER_IMPLEMENTATION.md` - Implementation guide (`hash_salt_version` logic)
- `SERIAL_NUMBER_INDEX.md` - Master index document

**Implementation Details:**
- `UnifiedSerialService::requireSalt()` - Salt retrieval logic
- `UnifiedSerialService::getSaltForVersion()` - Version-aware salt selection
- `serial_registry.hash_salt_version` - Database field tracking salt version

---

**Status:** ✅ **Configuration Guide Complete + Production Hardened**  
**Last Updated:** November 9, 2025


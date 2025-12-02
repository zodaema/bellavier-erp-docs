# 🔐 Quick Setup: Serial Number Salts

## วิธีตั้งค่า Salt Environment Variables

### **วิธีที่ 1: ใช้ Environment Variables (แนะนำ)**

```bash
# Generate secure random salts
export SERIAL_SECRET_SALT_HAT=$(openssl rand -hex 32)
export SERIAL_SECRET_SALT_OEM=$(openssl rand -hex 32)

# Verify
echo "HAT Salt: ${SERIAL_SECRET_SALT_HAT:0:20}..."
echo "OEM Salt: ${SERIAL_SECRET_SALT_OEM:0:20}..."
```

### **วิธีที่ 2: ใช้ config.local.php (Development)**

1. Copy ไฟล์ตัวอย่าง:
```bash
cp config.local.php.example config.local.php
```

2. Generate salts และแก้ไข config.local.php:
```bash
# Generate salts
HAT_SALT=$(openssl rand -hex 32)
OEM_SALT=$(openssl rand -hex 32)

# Update config.local.php
cat > config.local.php << EOF
<?php
return [
    'serial' => [
        'salt_hat' => '$HAT_SALT',
        'salt_oem' => '$OEM_SALT',
    ],
];
EOF
```

### **วิธีที่ 3: ใช้ .env file**

1. Copy ไฟล์ตัวอย่าง:
```bash
cp .env.example .env
```

2. Generate salts และแก้ไข .env:
```bash
# Generate salts
HAT_SALT=$(openssl rand -hex 32)
OEM_SALT=$(openssl rand -hex 32)

# Update .env
sed -i '' "s/CHANGE_ME_HAT_SALT_HERE/$HAT_SALT/" .env
sed -i '' "s/CHANGE_ME_OEM_SALT_HERE/$OEM_SALT/" .env
```

## ✅ Verify Setup

```bash
# Run tests
export SERIAL_SECRET_SALT_HAT=$(openssl rand -hex 32)
export SERIAL_SECRET_SALT_OEM=$(openssl rand -hex 32)
php tests/manual/test_serial_number_system.php
```

## 📚 ดูรายละเอียดเพิ่มเติม

อ่าน `docs/serial_number/02-setup-config/SERIAL_SALT_SETUP.md` สำหรับคำแนะนำแบบละเอียด

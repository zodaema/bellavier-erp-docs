# 🧪 Serial Number System - Testing Guide

**Purpose:** คู่มือทดสอบ Serial Number System แบบเห็นภาพง่าย  
**Last Updated:** November 9, 2025

---

## 🎯 Quick Test Overview

| Component | Test Method | Expected Result |
|-----------|-------------|-----------------|
| **Consistency Checker** | Run dry-run | Shows summary of checks |
| **Outbox Worker** | Run dry-run | Shows pending entries |
| **Public Verify API** | curl command | Returns JSON response |
| **Feature Flags** | Run script | Enables flags for tenant |

---

## 1️⃣ ทดสอบ Consistency Checker

### **Step 1: Run Dry-Run (ไม่แก้ไขข้อมูล)**

```bash
cd /Applications/MAMP/htdocs/bellavier-group-erp
php cron/serial_consistency_checker.php --dry-run
```

### **ผลลัพธ์ที่คาดหวัง:**

```
=== Serial Consistency Checker ===
Started at: 2025-11-09 15:30:00
Mode: DRY RUN

Processing tenant: Bellavier Atelier (DEFAULT)
  Found 1 missing core links
  Found 2 invalid serial formats
  Found 32 orphaned serials
  ✅ Completed

Processing tenant: Maison Atelier (maison_atelier)
  ✅ Completed

=== Summary ===
Tenants processed: 2
Missing tenant links: 0
Missing core links: 1
Invalid formats: 2
Orphaned serials: 32

Completed at: 2025-11-09 15:30:01
```

### **Step 2: Run Live (แก้ไขข้อมูลจริง)**

```bash
php cron/serial_consistency_checker.php
```

**⚠️ คำเตือน:** Live run จะแก้ไขข้อมูลจริง! ใช้เฉพาะเมื่อพร้อม

### **ผลลัพธ์ที่คาดหวัง:**

```
=== Serial Consistency Checker ===
Started at: 2025-11-09 15:30:00
Mode: LIVE

Processing tenant: Bellavier Atelier (DEFAULT)
  Found 1 missing core links
  Fixed: 1
  Found 2 invalid serial formats
  Quarantined: 2
  Found 32 orphaned serials
  Quarantined: 32
  ✅ Completed

=== Summary ===
Tenants processed: 2
Missing tenant links: 0
Missing core links: 1
Invalid formats: 2
Orphaned serials: 32
Fixed: 1
Quarantined: 34
Errors: 0

Completed at: 2025-11-09 15:30:01
✅ Success!
```

### **Step 3: ทดสอบเฉพาะ Tenant เดียว**

```bash
php cron/serial_consistency_checker.php --dry-run --tenant=DEFAULT
```

---

## 2️⃣ ทดสอบ Outbox Worker

### **Step 1: Run Dry-Run**

```bash
php cron/serial_outbox_worker.php --dry-run
```

### **ผลลัพธ์ที่คาดหวัง (ไม่มี pending entries):**

```
=== Serial Link Outbox Worker ===
Started at: 2025-11-09 15:35:00
Mode: DRY RUN

Processing tenant: Bellavier Atelier (DEFAULT)
  No pending entries
  ✅ Completed

Processing tenant: Maison Atelier (maison_atelier)
  No pending entries
  ✅ Completed

=== Summary ===
Tenants processed: 2
Pending found: 0
Retried: 0
Succeeded: 0
Failed: 0
Marked dead: 0
Errors: 0

Completed at: 2025-11-09 15:35:01
✅ Success!
```

### **Step 2: Run Live (ถ้ามี pending entries)**

```bash
php cron/serial_outbox_worker.php
```

### **ผลลัพธ์ที่คาดหวัง (ถ้ามี pending entries):**

```
=== Serial Link Outbox Worker ===
Started at: 2025-11-09 15:35:00
Mode: LIVE

Processing tenant: Bellavier Atelier (DEFAULT)
  Found 3 pending entries
    ✅ Linked: MA01-HAT-BAG-20251109-00027-A9K2-X → token 123
    ✅ Linked: MA01-HAT-BAG-20251109-00028-B7F3-Y → token 124
    ⚠️  Failed (retry 2/10): MA01-HAT-BAG-20251109-00029-C8G4-Z - Connection timeout
  ✅ Completed

=== Summary ===
Tenants processed: 1
Pending found: 3
Retried: 3
Succeeded: 2
Failed: 1
Marked dead: 0
Errors: 0

Completed at: 2025-11-09 15:35:02
✅ Success!
```

---

## 3️⃣ ทดสอบ Public Verify API

### **Step 1: ทดสอบ Serial ที่ไม่มีอยู่ (404)**

```bash
curl -v "http://localhost:8888/bellavier-group-erp/source/api/public/serial_verify_api.php?serial=TEST-SERIAL-123"
```

### **ผลลัพธ์ที่คาดหวัง:**

```json
{
    "ok": false,
    "error": "Serial not found or invalid",
    "reason": "unknown",
    "app_code": "SERIAL_404_NOT_FOUND"
}
```

**HTTP Headers:**
```
HTTP/1.1 404 Not Found
X-Correlation-Id: a1b2c3d4e5f6...
X-AI-Trace: eyJtb2R1bGUiOiJzZXJpYWxfdmVyaWZ5X2FwaSIsImFjdGlvbiI6InZlcmlmeSIsInNlcmlhbCI6IlRFU1QtU0VSSUFMLTEyMyIsInRpbWVzdGFtcCI6IjIwMjUtMTEtMDlUMTU6MzA6MDBaIiwicmVxdWVzdF9pZCI6ImExYjJjM2Q0ZTVmNi4uLiIsImV4ZWN1dGlvbl9tcyI6MTIuMzQsInN0YXR1cyI6ImVycm9yIiwiZXJyb3IiOiJ1bmtub3duIn0=
```

### **Step 2: ทดสอบ Serial ที่มีอยู่ (200)**

**ก่อนอื่นต้องสร้าง serial จริง:**

```bash
# สร้าง serial ผ่าน API หรือ UI
# แล้วทดสอบ verify
curl -v "http://localhost:8888/bellavier-group-erp/source/api/public/serial_verify_api.php?serial=MA01-HAT-BAG-20251109-00027-A9K2-X"
```

### **ผลลัพธ์ที่คาดหวัง:**

```json
{
    "ok": true,
    "valid": true,
    "verified": true,
    "serial": "MA01-HAT-BAG-20251109-00027-A9K2-X",
    "status": "active",
    "production_type": "hatthasilpa",
    "scope": "piece",
    "data": {
        "tenant": "MA01",
        "sku": "BAG",
        "manufactured_at": "2025-11-09T00:00:00Z",
        "status": "active",
        "origin": "job_ticket",
        "visibility": "public"
    }
}
```

**HTTP Headers:**
```
HTTP/1.1 200 OK
X-Correlation-Id: a1b2c3d4e5f6...
X-AI-Trace: eyJtb2R1bGUiOiJzZXJpYWxfdmVyaWZ5X2FwaSIsImFjdGlvbiI6InZlcmlmeSIsInNlcmlhbCI6Ik1BMDEtSEFULUJBRy0yMDI1MTEwOS0wMDAyNy1BOUsyLVgiLCJ0aW1lc3RhbXAiOiIyMDI1LTExLTA5VDE1OjMwOjAwWiIsInJlcXVlc3RfaWQiOiJhMWIyYzNkNGU1ZjYuLi4iLCJleGVjdXRpb25fbXMiOjE1LjY3LCJzdGF0dXMiOiJzdWNjZXNzIn0=
```

### **Step 3: ทดสอบ Rate Limiting (429)**

```bash
# ส่ง request มากกว่า 60 ครั้งใน 1 ชั่วโมง
for i in {1..65}; do
  curl -s "http://localhost:8888/bellavier-group-erp/source/api/public/serial_verify_api.php?serial=TEST-$i" | head -5
  sleep 1
done
```

### **ผลลัพธ์ที่คาดหวัง (หลัง request ที่ 61):**

```json
{
    "ok": false,
    "error": "Rate limit exceeded. Maximum 60 requests per hour per IP.",
    "app_code": "SERIAL_429_RATE_LIMIT"
}
```

**HTTP Headers:**
```
HTTP/1.1 429 Too Many Requests
Retry-After: 3600
X-Correlation-Id: a1b2c3d4e5f6...
```

### **Step 4: ทดสอบ Invalid Format (400)**

```bash
curl -v "http://localhost:8888/bellavier-group-erp/source/api/public/serial_verify_api.php?serial=INVALID@FORMAT#123"
```

### **ผลลัพธ์ที่คาดหวัง:**

```json
{
    "ok": false,
    "error": "Invalid serial code format",
    "app_code": "SERIAL_400_INVALID_FORMAT"
}
```

### **Step 5: ทดสอบ Missing Serial Code (400)**

```bash
curl -v "http://localhost:8888/bellavier-group-erp/source/api/public/serial_verify_api.php"
```

### **ผลลัพธ์ที่คาดหวัง:**

```json
{
    "ok": false,
    "error": "Missing serial code. Usage: /api/public/serial/verify/{serial_code}",
    "app_code": "SERIAL_400_MISSING_CODE"
}
```

---

## 4️⃣ ทดสอบ Feature Flags Script

### **Step 1: Run Script**

```bash
php tools/enable_feature_flags_test.php
```

### **ผลลัพธ์ที่คาดหวัง:**

```
=== Enable Feature Flags for Test Tenant ===
Started at: 2025-11-09 15:40:00

Found tenant: Bellavier Atelier (DEFAULT)
Tenant ID: 1

Enabling FF_SERIAL_STD_HAT...
  ✅ FF_SERIAL_STD_HAT enabled
Enabling FF_SERIAL_STD_OEM...
  ✅ FF_SERIAL_STD_OEM enabled

Verifying flags...
  FF_SERIAL_STD_HAT: ✅ ON
  FF_SERIAL_STD_OEM: ✅ ON

All feature flags for tenant 1:
  - FF_SERIAL_STD_HAT: on (enabled: 2025-11-09 15:40:00)
    Notes: Testing standardized serial generation
  - FF_SERIAL_STD_OEM: on (enabled: 2025-11-09 15:40:00)
    Notes: Testing standardized OEM serial generation

✅ Feature flags enabled successfully!
Completed at: 2025-11-09 15:40:01
```

---

## 5️⃣ ทดสอบแบบ Visual (Browser)

### **Public Verify API - ใช้ Browser**

1. เปิด Browser ไปที่:
   ```
   http://localhost:8888/bellavier-group-erp/source/api/public/serial_verify_api.php?serial=TEST-SERIAL-123
   ```

2. กด F12 เพื่อเปิด Developer Tools

3. ไปที่ Tab **Network** → คลิก request → ดู **Headers** และ **Response**

4. ตรวจสอบ:
   - ✅ `X-Correlation-Id` header มีค่า
   - ✅ `X-AI-Trace` header มีค่า (base64 encoded)
   - ✅ Response JSON มี `app_code` ใน error cases

### **ตัวอย่าง Response Headers:**

```
Response Headers:
  Content-Type: application/json; charset=utf-8
  X-Correlation-Id: a1b2c3d4e5f6...
  X-AI-Trace: eyJtb2R1bGUiOiJzZXJpYWxfdmVyaWZ5X2FwaSIs...
```

---

## 6️⃣ ทดสอบแบบ Comprehensive (All-in-One)

### **สร้าง Test Script:**

```bash
#!/bin/bash
# test_serial_system.sh

echo "🧪 Testing Serial Number System..."
echo ""

echo "1️⃣ Testing Consistency Checker (Dry-Run)..."
php cron/serial_consistency_checker.php --dry-run
echo ""

echo "2️⃣ Testing Outbox Worker (Dry-Run)..."
php cron/serial_outbox_worker.php --dry-run
echo ""

echo "3️⃣ Testing Public Verify API (Invalid Serial)..."
curl -s "http://localhost:8888/bellavier-group-erp/source/api/public/serial_verify_api.php?serial=TEST-123" | python3 -m json.tool
echo ""

echo "4️⃣ Testing Feature Flags Script..."
php tools/enable_feature_flags_test.php
echo ""

echo "✅ All tests completed!"
```

### **Run Test Script:**

```bash
cd tools/scripts/testing
chmod +x test_serial_system.sh
./test_serial_system.sh
```

**Note:** Script location moved to `tools/scripts/testing/test_serial_system.sh`

---

## 7️⃣ ทดสอบ Enterprise Features (API Headers)

### **ตรวจสอบ Headers:**

```bash
# Test Correlation ID
curl -v "http://localhost:8888/bellavier-group-erp/source/api/public/serial_verify_api.php?serial=TEST" 2>&1 | grep -i "correlation\|ai-trace"

# Expected:
# < X-Correlation-Id: a1b2c3d4e5f6...
# < X-AI-Trace: eyJtb2R1bGUiOiJzZXJpYWxfdmVyaWZ5X2FwaSIs...
```

### **Decode AI-Trace Header:**

```bash
# Get AI-Trace header
TRACE=$(curl -s -D - "http://localhost:8888/bellavier-group-erp/source/api/public/serial_verify_api.php?serial=TEST" | grep "X-AI-Trace" | cut -d' ' -f2 | tr -d '\r')

# Decode base64
echo "$TRACE" | base64 -d | python3 -m json.tool
```

### **ผลลัพธ์ที่คาดหวัง:**

```json
{
    "module": "serial_verify_api",
    "action": "verify",
    "serial": "TEST",
    "timestamp": "2025-11-09T15:30:00Z",
    "request_id": "a1b2c3d4e5f6...",
    "execution_ms": 12.34,
    "status": "error",
    "error": "unknown"
}
```

---

## 8️⃣ ทดสอบ Maintenance Mode

### **Step 1: สร้าง Maintenance Flag**

```bash
touch storage/maintenance.flag
```

### **Step 2: ทดสอบ API**

```bash
curl -v "http://localhost:8888/bellavier-group-erp/source/api/public/serial_verify_api.php?serial=TEST"
```

### **ผลลัพธ์ที่คาดหวัง:**

```json
{
    "ok": false,
    "error": "service_unavailable",
    "app_code": "CORE_503_MAINT"
}
```

**HTTP Headers:**
```
HTTP/1.1 503 Service Unavailable
Retry-After: 60
```

### **Step 3: ลบ Maintenance Flag**

```bash
rm storage/maintenance.flag
```

---

## 📊 Checklist การทดสอบ

### **Consistency Checker:**
- [ ] Dry-run ทำงานได้
- [ ] Live run แก้ไขข้อมูลได้ (ถ้าพร้อม)
- [ ] แสดง summary ถูกต้อง
- [ ] ไม่มี syntax errors

### **Outbox Worker:**
- [ ] Dry-run ทำงานได้
- [ ] Live run retry entries ได้ (ถ้ามี)
- [ ] แสดง summary ถูกต้อง
- [ ] ไม่มี syntax errors

### **Public Verify API:**
- [ ] Invalid serial → 404 with app_code
- [ ] Missing serial → 400 with app_code
- [ ] Invalid format → 400 with app_code
- [ ] Rate limit → 429 with Retry-After
- [ ] Maintenance mode → 503 with Retry-After
- [ ] Headers: X-Correlation-Id, X-AI-Trace
- [ ] AI-Trace มี execution_ms

### **Feature Flags Script:**
- [ ] Enable flags สำเร็จ
- [ ] Verify flags ถูกต้อง
- [ ] แสดง all flags
- [ ] ไม่มี errors

---

## 🔗 Related Documents

- `SERIAL_CRON_SETUP.md` - Cron jobs setup guide
- `SERIAL_PUBLIC_VERIFY_API.md` - Public API documentation
- `SERIAL_SALT_UI_GUIDE.md` - Salt management UI guide

---

**Status:** ✅ **Complete Testing Guide**  
**Last Updated:** November 9, 2025


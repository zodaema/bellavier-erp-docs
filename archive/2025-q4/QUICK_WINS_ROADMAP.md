# 🚀 Quick Wins Roadmap (2-4 สัปดาห์)

## Overview
อัปเกรดและเพิ่มฟีเจอร์สำคัญที่ส่งผลทันทีต่อการใช้งานจริง

---

## ✅ Task 1: PHP 8.2 Upgrade

### Current State
- PHP 7.4.33 (EOL: Nov 2022 - **ไม่ได้รับ security patches แล้ว!**)
- 2,458 PHP files ใน codebase
- MAMP มี PHP 8.2.0 อยู่แล้ว

### Breaking Changes to Fix
1. **Deprecated Features:**
   - `${var}` string interpolation → `{$var}`
   - `create_function()` → closures
   - `each()` → `foreach()`
   - Implicit float to int conversions

2. **Type System:**
   - Mixed return types (already using string in some places)
   - Null parameter defaults
   - Property declarations

3. **MySQLi Changes:**
   - Error handling (exceptions by default)
   - Result handling changes

### Steps
```bash
# 1. Scan for deprecated code
php8.2 -l $(find . -name "*.php")

# 2. Run compatibility checker
composer require --dev phpcompatibility/php-compatibility
vendor/bin/phpcs --standard=PHPCompatibility --runtime-set testVersion 8.2 source/

# 3. Fix issues systematically
# 4. Update MAMP config to use PHP 8.2
# 5. Test all critical paths
```

### Expected Impact
- ✅ Security patches for 2+ years
- ✅ Performance boost (15-20% faster)
- ✅ Better error messages
- ✅ Null-safe operator, match expressions

---

## 📚 Task 2: OpenAPI Specification

### Goals
- Generate Swagger UI for all APIs
- Enable frontend teams to work independently
- Auto-validate requests/responses

### APIs to Document (Priority Order)

**Tier 1: Core Operations (ใช้งานทุกวัน)**
1. `/source/mo_api.php` - Manufacturing Orders
2. `/source/atelier_job_api.php` - Job Tickets
3. `/source/atelier_wip_api.php` - WIP Logs
4. `/source/qc_api.php` - QC Inspections
5. `/source/inventory_api.php` - Inventory Transactions

**Tier 2: Administration**
6. `/source/admin_rbac.php` - Roles & Permissions
7. `/source/admin_org.php` - Organizations
8. `/source/platform_migration_api.php` - Migrations

**Tier 3: Reports & Analytics**
9. `/source/dashboard.php` - Dashboard Data
10. `/source/atelier_schedule.php` - Production Schedule

### Implementation
```yaml
# Create openapi.yaml
openapi: 3.0.0
info:
  title: Bellavier Group ERP API
  version: 1.0.0
paths:
  /source/mo_api.php:
    get:
      parameters:
        - name: action
          in: query
          schema:
            enum: [list, detail, create, update, delete]
      responses:
        200:
          content:
            application/json:
              schema:
                type: object
                properties:
                  ok: {type: boolean}
                  data: {type: object}
```

### Tools
- Swagger UI (`/docs/swagger/`)
- Postman collection export
- Auto-generated client SDKs

---

## 🚨 Task 3: Exceptions Board

### Purpose
แดชบอร์ดสำหรับ **ตรวจจับปัญหาอัตโนมัติ** ก่อนจะกลายเป็นวิกฤติ

### Metrics to Track

**1. Stuck Jobs**
```sql
-- MOs stuck > 3 days without progress
SELECT mo_code, DATEDIFF(NOW(), updated_at) as days_stuck
FROM mo
WHERE status = 'in-progress' 
  AND DATEDIFF(NOW(), updated_at) > 3
```

**2. Rework Loops**
```sql
-- Job tickets with > 2 QC failures
SELECT 
  ajt.ticket_code,
  COUNT(qfe.id_fail_event) as fail_count
FROM atelier_job_ticket ajt
JOIN qc_fail_event qfe ON qfe.entity_id = ajt.id_job_ticket
WHERE qfe.status != 'resolved'
GROUP BY ajt.id_job_ticket
HAVING fail_count > 2
```

**3. QC Fail Spikes**
```sql
-- Sudden increase in failures (> 2x avg)
SELECT 
  DATE(reported_at) as date,
  COUNT(*) as fails,
  AVG(COUNT(*)) OVER (ORDER BY DATE(reported_at) ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING) as avg_7d
FROM qc_fail_event
WHERE reported_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY DATE(reported_at)
HAVING fails > (avg_7d * 2)
```

**4. Material Shortages**
```sql
-- Products with stock below min level
SELECT p.sku, p.product_name, soh.qty, soh.min_qty
FROM stock_on_hand soh
JOIN product p ON p.id_product = soh.id_product
WHERE soh.qty < soh.min_qty
```

### UI Components
- `/views/exceptions_board.php`
- Real-time alerts (SweetAlert2 toast)
- Auto-refresh every 30 seconds
- Filter by severity (critical/warning/info)
- Quick actions (assign, escalate, resolve)

---

## 📱 Task 4: PWA Scan Station

### Requirements
- **Offline-first**: ทำงานได้โดยไม่ต้องมี internet
- **2-click flow**: Scan → Action → Done
- **Camera integration**: สแกน barcode/QR ด้วยกล้อง
- **Queue management**: เก็บ actions ไว้ sync ทีหลัง

### Core Features

**1. Scan Input**
```javascript
// Support multiple input methods
- Camera (QR/Barcode scanner)
- Manual entry (keyboard)
- NFC tag (future)
```

**2. Action Menu**
```javascript
const actions = [
  'start_job',      // เริ่มงาน
  'stop_job',       // หยุดงาน
  'complete_qty',   // บันทึกจำนวน
  'report_defect',  // รายงานข้อบกพร่อง
  'transfer_lot'    // โอนสินค้า
];
```

**3. Offline Queue**
```javascript
// Service Worker + IndexedDB
self.addEventListener('sync', async (event) => {
  if (event.tag === 'sync-actions') {
    await syncPendingActions();
  }
});
```

### Files to Create
- `/views/pwa_scan_station.php`
- `/assets/javascripts/pwa/scanner.js`
- `/assets/javascripts/pwa/sw.js` (Service Worker)
- `/manifest.json` (PWA manifest)

---

## 🎯 Success Metrics

| Task | Metric | Target |
|------|--------|--------|
| PHP 8.2 | Compatibility | 100% |
| PHP 8.2 | Performance | +15% faster |
| OpenAPI | API coverage | 80% (20+ endpoints) |
| Exceptions | Detection rate | 90% before escalation |
| PWA Scan | Time per action | < 5 seconds |
| PWA Scan | Offline uptime | 99% |

---

## Timeline

```
Week 1:
  ✅ PHP 8.2 compatibility scan
  ✅ Fix critical issues
  ✅ Test core modules
  ⏸️  OpenAPI spec (50%)

Week 2:
  ✅ PHP 8.2 deployment
  ✅ OpenAPI spec complete
  ✅ Exceptions board v1
  ⏸️  PWA scan (30%)

Week 3:
  ✅ PWA scan station (offline + camera)
  ✅ Integration testing
  ✅ UAT with shop floor

Week 4:
  ✅ Production deployment
  ✅ Documentation
  ✅ Training materials
  🎉 DONE!
```

---

## Next Steps

1. **Start with PHP 8.2 compatibility check**
2. Create compatibility report
3. Fix issues by priority (critical → high → medium)
4. Run comprehensive tests

---

**Status: Ready to execute! 🚀**

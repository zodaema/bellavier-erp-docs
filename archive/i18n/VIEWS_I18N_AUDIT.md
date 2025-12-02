# 📋 Views i18n Audit Report

**วันที่:** 15 พฤศจิกายน 2025  
**วัตถุประสงค์:** สำรวจและสรุปหน้า views ที่ยังไม่ได้ทำ i18n อย่างถูกต้องครบถ้วน  
**สถานะ:** 🔍 Audit Complete

---

## 📊 สรุปภาพรวม

| สถานะ | จำนวนไฟล์ | รายละเอียด |
|-------|----------|-----------|
| ✅ **i18n Complete** | 25+ | ใช้ `translate()` และ `data-i18n` ครบถ้วน |
| ⚠️ **Partial i18n** | 8 | มีบางส่วนที่ยัง hardcode ข้อความ |
| ❌ **No i18n** | 3 | ยังไม่ได้ทำ i18n เลย |
| 📝 **Total Views** | 53 | ไฟล์ views ทั้งหมด (ไม่รวม template files) |

---

## ⚠️ Critical Rules: Coding Standards for i18n

### 🚨 **MANDATORY RULE: English Default Only**

**กฎสำคัญ:** ในโค้ด (coding) **ต้องใช้ภาษาอังกฤษเป็น default เสมอ** ไม่ควรใช้ภาษาไทยหรือสัญลักษณ์ (emoji) ในโค้ด

### ❌ **สิ่งที่ห้ามทำ (DO NOT):**

```php
// ❌ WRONG - Hardcode ภาษาไทยในโค้ด
<h1>ระบบบัญชีรายจ่าย</h1>
<button>บันทึก</button>
echo "เกิดข้อผิดพลาด";

// ❌ WRONG - ใช้สัญลักษณ์/emoji ในโค้ด
<h1>🚨 Exceptions Board</h1>
<button>✅ ยืนยัน</button>
```

### ✅ **สิ่งที่ต้องทำ (DO THIS):**

```php
// ✅ CORRECT - ใช้ภาษาอังกฤษเป็น default
<h1><?php echo translate('accounting.title', 'Accounting System'); ?></h1>
<button><?php echo translate('common.action.save', 'Save'); ?></button>
json_error(translate('error.message', 'An error occurred'), 400);

// ✅ CORRECT - ใช้ translate() พร้อม English fallback
translate('accounting.title', 'Accounting System')
translate('common.action.save', 'Save')
translate('error.message', 'An error occurred')
```

### 📋 **เหตุผลที่ต้องใช้ภาษาอังกฤษ:**

1. **ป้องกันปัญหา Encoding:**
   - ภาษาไทยอาจเกิดปัญหา encoding (UTF-8, charset)
   - สัญลักษณ์/emoji อาจไม่แสดงผลถูกต้องในบาง browser/system
   - English เป็น ASCII-safe (ไม่มีปัญหา encoding)

2. **Professional Standard:**
   - โค้ดควรเป็นภาษาอังกฤษ (industry standard)
   - ง่ายต่อการ maintain และ review
   - Developer ทั่วโลกสามารถอ่านได้

3. **i18n System Design:**
   - ระบบ i18n ถูกออกแบบให้ใช้ English เป็น default
   - Translation keys และ fallback ใช้ภาษาอังกฤษ
   - การใช้ภาษาไทยในโค้ดจะขัดกับระบบ

4. **Consistency:**
   - ทำให้โค้ดสม่ำเสมอ (consistent)
   - ง่ายต่อการ debug และ troubleshoot
   - ลดความสับสนระหว่างภาษา

### 🎯 **Best Practices:**

```php
// ✅ GOOD - English default, Thai translation ใน lang files
translate('accounting.title', 'Accounting System')
// lang/en.php: 'accounting.title' => 'Accounting System'
// lang/th.php: 'accounting.title' => 'ระบบบัญชีรายจ่าย'

// ✅ GOOD - Parameter replacement
translate('job_ticket.step.default_name', 'Step {seq}', ['seq' => $seq])
// lang/en.php: 'job_ticket.step.default_name' => 'Step {seq}'
// lang/th.php: 'job_ticket.step.default_name' => 'ขั้นตอนที่ {seq}'

// ❌ BAD - Hardcode ภาษาไทย
echo "ขั้นตอนที่ " . $seq;

// ❌ BAD - Hardcode emoji
echo "🚨 " . translate('error.title', 'Error');
```

### 📝 **Translation Files Structure:**

```php
// lang/en.php (English - Default)
return [
    'accounting.title' => 'Accounting System',
    'common.action.save' => 'Save',
    'error.message' => 'An error occurred',
];

// lang/th.php (Thai - Translation)
return [
    'accounting.title' => 'ระบบบัญชีรายจ่าย',
    'common.action.save' => 'บันทึก',
    'error.message' => 'เกิดข้อผิดพลาด',
];
```

### ⚠️ **Exceptions (กรณีพิเศษ):**

**สัญลักษณ์/emoji ใน UI:**
- ✅ **อนุญาต** ถ้าอยู่ใน translation files (`lang/th.php`, `lang/en.php`)
- ❌ **ไม่อนุญาต** ถ้าอยู่ในโค้ดโดยตรง

```php
// ✅ OK - emoji ใน translation file
// lang/en.php
'platform.dashboard.title' => '🌐 Platform Dashboard'

// ❌ NOT OK - emoji ในโค้ด
<h1>🌐 <?php echo translate('platform.dashboard.title', 'Platform Dashboard'); ?></h1>
```

---

## ✅ ไฟล์ที่ทำ i18n ครบถ้วนแล้ว (25+ ไฟล์)

ไฟล์เหล่านี้ใช้ `translate()` และ `data-i18n` อย่างถูกต้อง:

1. ✅ `adjust.php` - Stock Adjustments
2. ✅ `grn.php` - Goods Receipts
3. ✅ `issue.php` - Material Issues & Returns
4. ✅ `transfer.php` - Stock Transfers
5. ✅ `stock_card.php` - Stock Card
6. ✅ `stock_on_hand.php` - Current Stock Summary
7. ✅ `locations.php` - Manage Locations
8. ✅ `warehouses.php` - Manage Warehouses
9. ✅ `products.php` - Products Management
10. ✅ `product_categories.php` - Product Categories
11. ✅ `uom.php` - Unit of Measure
12. ✅ `materials.php` - Materials
13. ✅ `work_centers.php` - Work Centers
14. ✅ `bom.php` - Bill of Materials
15. ✅ `routing.php` - Routing Management (บางส่วน)
16. ✅ `hatthasilpa_job_ticket.php` - Job Tickets
17. ✅ `hatthasilpa_jobs.php` - Hatthasilpa Jobs
18. ✅ `hatthasilpa_schedule.php` - Production Schedule
19. ✅ `qc_rework.php` - QC Rework
20. ✅ `work_queue.php` - Work Queue
21. ✅ `manager_assignment.php` - Manager Assignment
22. ✅ `team_management.php` - Team Management
23. ✅ `tenant_users.php` - Tenant Users
24. ✅ `notifications.php` - Notifications
25. ✅ `pwa_scan.php` - PWA Scan Station
26. ✅ `product_traceability.php` - Product Traceability
27. ✅ `trace_overview.php` - Trace Overview
28. ✅ `production_dashboard.php` - Production Dashboard
29. ✅ `platform_serial_salt.php` - Serial Salt Management
30. ✅ `admin_roles.php` - Admin Roles
31. ✅ `admin_users.php` - Admin Users
32. ✅ `admin_organizations.php` - Admin Organizations
33. ✅ `platform_roles.php` - Platform Roles
34. ✅ `platform_tenant_owners.php` - Platform Tenant Owners
35. ✅ `routing_graph_designer.php` - Routing Graph Designer
36. ✅ `profile.php` - User Profile
37. ✅ `system_log.php` - System Log

---

## ⚠️ ไฟล์ที่ทำ i18n บางส่วน (8 ไฟล์)

### 1. `mo.php` - Manufacturing Orders

**สถานะ:** ⚠️ Partial i18n (90% complete)

**ปัญหาที่พบ:**
- ✅ ส่วนใหญ่ใช้ `translate()` แล้ว
- ❌ **Line 70-72:** Hardcoded English text ใน alert box
  ```php
  <strong>Production Type:</strong> 🏭 <strong>Classic (Batch Production)</strong><br>
  <span class="text-muted">Manufacturing Orders are for Classic/batch production only. For custom/artisan work, use "Atelier Jobs" instead.</span>
  ```

**ต้องแก้ไข:**
```php
// แทนที่ด้วย
<strong><?php echo translate('mo.form.production_type_label', 'Production Type:'); ?></strong> 🏭 
<strong><?php echo translate('mo.form.production_type_classic', 'Classic (Batch Production)'); ?></strong><br>
<span class="text-muted"><?php echo translate('mo.form.production_type_hint', 'Manufacturing Orders are for Classic/batch production only. For custom/artisan work, use "Atelier Jobs" instead.'); ?></span>
```

**Translation Keys ที่ต้องเพิ่ม:**
- `mo.form.production_type_label` => 'Production Type:'
- `mo.form.production_type_classic` => 'Classic (Batch Production)'
- `mo.form.production_type_hint` => 'Manufacturing Orders are for Classic/batch production only. For custom/artisan work, use "Atelier Jobs" instead.'

---

### 2. `dashboard.php` - Production Dashboard

**สถานะ:** ⚠️ Partial i18n (60% complete)

**ปัญหาที่พบ:**
- ❌ **Line 30:** Hardcoded English "Yield (QC Pass)"
- ❌ **Line 35:** Hardcoded Thai "ผ่าน QC ... งาน"
- ❌ **Line 42:** Hardcoded English "Average Lead Time"
- ❌ **Line 44:** Hardcoded Thai "0 วัน"
- ❌ **Line 47:** Hardcoded Thai "จากตัวอย่าง ... งานที่ปิดเสร็จ"
- ❌ **Line 54:** Hardcoded English "Defect Rate"
- ❌ **Line 59:** Hardcoded Thai "QC ไม่ผ่าน ... รายการ"
- ❌ **Line 70:** Hardcoded English "Production Timeline"
- ❌ **Line 71:** Hardcoded Thai "สรุปงานตามสถานะ / แผนการผลิตตามช่วงวันที่เลือก"
- ❌ **Line 74:** Hardcoded Thai "ช่วงเวลา"
- ❌ **Line 76-80:** Hardcoded Thai ใน select options
- ❌ **Line 87:** Hardcoded Thai placeholder "เลือกช่วงวันที่"
- ❌ **Line 95:** Hardcoded Thai "สถานะงาน"
- ❌ **Line 99:** Hardcoded Thai "แหล่งที่มาของงาน"
- ❌ **Line 103:** Hardcoded Thai "งานตามช่วงเวลา"
- ❌ **Line 107-109:** Hardcoded Thai "จำนวนงาน", "ยอดขาย (ถ้ามี)"
- ❌ **Line 125:** Hardcoded English "Daily Activity"
- ❌ **Line 126:** Hardcoded Thai "บันทึกกิจกรรมล่าสุดจากระบบ (issue, transfer, QC)"
- ❌ **Line 130:** Hardcoded English "Refresh"
- ❌ **Line 135:** Hardcoded English "Show More"
- ❌ **Line 142:** Hardcoded English "Job Ticket Snapshot"
- ❌ **Line 145:** Hardcoded Thai "สรุปจำนวนงานในแต่ละสถานะ"
- ❌ **Line 148-161:** Hardcoded Thai "งาน Planned", "กำลังผลิต", "รอ QC", "เสร็จสมบูรณ์"
- ❌ **Line 174:** Hardcoded English "QC Fail & Rework Metrics"
- ❌ **Line 182:** Hardcoded English "Open QC Fails"
- ❌ **Line 190:** Hardcoded English "Defect Qty (30d)"
- ❌ **Line 198:** Hardcoded English "Active Rework"
- ❌ **Line 206:** Hardcoded English "Avg Turnaround"
- ❌ **Line 214:** Hardcoded English "Severity Breakdown"
- ❌ **Line 218:** Hardcoded English "Top Fail Codes"
- ❌ **Line 224:** Hardcoded English "Defect Rate Trend (7 Days)"

**ต้องแก้ไข:**
- แทนที่ข้อความทั้งหมดด้วย `translate()` และ `data-i18n`
- เพิ่ม translation keys ใน `lang/th.php` และ `lang/en.php`

**Translation Keys ที่ต้องเพิ่ม:**
- `dashboard.kpi.yield` => 'Yield (QC Pass)'
- `dashboard.kpi.yield_desc` => 'ผ่าน QC {pass} / {total} งาน'
- `dashboard.kpi.lead_time` => 'Average Lead Time'
- `dashboard.kpi.lead_time_desc` => 'จากตัวอย่าง {sample} งานที่ปิดเสร็จ'
- `dashboard.kpi.defect_rate` => 'Defect Rate'
- `dashboard.kpi.defect_rate_desc` => 'QC ไม่ผ่าน {count} รายการ'
- `dashboard.timeline.title` => 'Production Timeline'
- `dashboard.timeline.subtitle` => 'สรุปงานตามสถานะ / แผนการผลิตตามช่วงวันที่เลือก'
- `dashboard.timeline.time_range` => 'ช่วงเวลา'
- `dashboard.timeline.status_distribution` => 'สถานะงาน'
- `dashboard.timeline.source_distribution` => 'แหล่งที่มาของงาน'
- `dashboard.timeline.orders_over_time` => 'งานตามช่วงเวลา'
- `dashboard.timeline.metric.orders` => 'จำนวนงาน'
- `dashboard.timeline.metric.sales` => 'ยอดขาย (ถ้ามี)'
- `dashboard.activity.title` => 'Daily Activity'
- `dashboard.activity.subtitle` => 'บันทึกกิจกรรมล่าสุดจากระบบ (issue, transfer, QC)'
- `dashboard.snapshot.title` => 'Job Ticket Snapshot'
- `dashboard.snapshot.subtitle` => 'สรุปจำนวนงานในแต่ละสถานะ'
- `dashboard.snapshot.planned` => 'งาน Planned'
- `dashboard.snapshot.in_progress` => 'กำลังผลิต'
- `dashboard.snapshot.qc` => 'รอ QC'
- `dashboard.snapshot.completed` => 'เสร็จสมบูรณ์'
- `dashboard.qc_metrics.title` => 'QC Fail & Rework Metrics'
- `dashboard.qc_metrics.open_fails` => 'Open QC Fails'
- `dashboard.qc_metrics.defect_qty` => 'Defect Qty (30d)'
- `dashboard.qc_metrics.active_rework` => 'Active Rework'
- `dashboard.qc_metrics.avg_turnaround` => 'Avg Turnaround'
- `dashboard.qc_metrics.severity_breakdown` => 'Severity Breakdown'
- `dashboard.qc_metrics.top_fail_codes` => 'Top Fail Codes'
- `dashboard.qc_metrics.trend` => 'Defect Rate Trend (7 Days)'

---

### 3. `exceptions_board.php` - Exceptions Board

**สถานะ:** ⚠️ Partial i18n (30% complete)

**ปัญหาที่พบ:**
- ❌ **Line 21:** Hardcoded Thai "🚨 Exceptions Board"
- ❌ **Line 22:** Hardcoded Thai "ตรวจจับปัญหาอัตโนมัติก่อนกลายเป็นวิกฤติ"
- ❌ **Line 26:** Hardcoded English "Refresh"
- ❌ **Line 28:** Hardcoded English "Auto-refresh: 30s"
- ❌ **Line 39:** Hardcoded English "Stuck Jobs"
- ❌ **Line 41:** Hardcoded Thai "เกิน 3 วันไม่มีความคืบหน้า"
- ❌ **Line 54:** Hardcoded English "Rework Loops"
- ❌ **Line 56:** Hardcoded Thai "QC Fail > 2 ครั้ง"
- ❌ **Line 69:** Hardcoded English "QC Fail Spikes"
- ❌ **Line 71:** Hardcoded Thai "เพิ่มขึ้นกว่า 2x ค่าเฉลี่ย"
- ❌ **Line 84:** Hardcoded English "Material Shortages"
- ❌ **Line 86:** Hardcoded Thai "สต็อกต่ำกว่าขั้นต่ำ"
- ❌ **Line 101:** Hardcoded Thai "🔴 Stuck Jobs (งานค้างเกิน 3 วัน)"
- ❌ **Line 108-113:** Hardcoded English table headers
- ❌ **Line 117:** Hardcoded English "Loading..."
- ❌ **Line 129:** Hardcoded Thai "⚠️ Rework Loops (QC Fail ซ้ำ)"
- ❌ **Line 136-140:** Hardcoded English table headers
- ❌ **Line 144:** Hardcoded English "Loading..."
- ❌ **Line 156:** Hardcoded Thai "📊 QC Fail Spikes (เพิ่มขึ้นผิดปกติ)"
- ❌ **Line 163-167:** Hardcoded English table headers
- ❌ **Line 170:** Hardcoded English "Loading..."

**ต้องแก้ไข:**
- แทนที่ข้อความทั้งหมดด้วย `translate()` และ `data-i18n`
- เพิ่ม translation keys

**Translation Keys ที่ต้องเพิ่ม:**
- `exceptions.title` => '🚨 Exceptions Board'
- `exceptions.subtitle` => 'ตรวจจับปัญหาอัตโนมัติก่อนกลายเป็นวิกฤติ'
- `exceptions.auto_refresh` => 'Auto-refresh: 30s'
- `exceptions.stuck_jobs.title` => 'Stuck Jobs'
- `exceptions.stuck_jobs.desc` => 'เกิน 3 วันไม่มีความคืบหน้า'
- `exceptions.rework_loops.title` => 'Rework Loops'
- `exceptions.rework_loops.desc` => 'QC Fail > 2 ครั้ง'
- `exceptions.qc_spikes.title` => 'QC Fail Spikes'
- `exceptions.qc_spikes.desc` => 'เพิ่มขึ้นกว่า 2x ค่าเฉลี่ย'
- `exceptions.shortages.title` => 'Material Shortages'
- `exceptions.shortages.desc` => 'สต็อกต่ำกว่าขั้นต่ำ'
- `exceptions.table.mo_code` => 'MO Code'
- `exceptions.table.product` => 'Product'
- `exceptions.table.status` => 'Status'
- `exceptions.table.days_stuck` => 'Days Stuck'
- `exceptions.table.last_update` => 'Last Update'
- `exceptions.table.ticket_code` => 'Ticket Code'
- `exceptions.table.job_name` => 'Job Name'
- `exceptions.table.fail_count` => 'Fail Count'
- `exceptions.table.last_fail` => 'Last Fail'
- `exceptions.table.fail_code` => 'Fail Code'
- `exceptions.table.description` => 'Description'
- `exceptions.table.count_7d` => 'Count (7 days)'
- `exceptions.table.rate` => 'Rate'

---

### 4. `employees.php` - Employee Management

**สถานะ:** ⚠️ Partial i18n (20% complete)

**ปัญหาที่พบ:**
- ❌ **Line 13:** Hardcoded Thai "จัดการข้อมูลพนักงาน (Employee)"
- ❌ **Line 19:** Hardcoded English "Employees Database"
- ❌ **Line 23:** Hardcoded Thai "รายชื่อพนักงาน"
- ❌ **Line 25:** Hardcoded Thai "เพิ่มพนักงาน"
- ❌ **Line 32-38:** Hardcoded Thai table headers
- ❌ **Line 55:** Hardcoded Thai "เพิ่มพนักงาน"
- ❌ **Line 61-92:** Hardcoded Thai form labels
- ❌ **Line 96:** Hardcoded Thai "บันทึก"
- ❌ **Line 97:** Hardcoded Thai "ยกเลิก"

**ต้องแก้ไข:**
- แทนที่ข้อความทั้งหมดด้วย `translate()` และ `data-i18n`

**Translation Keys ที่ต้องเพิ่ม:**
- `employees.title` => 'จัดการข้อมูลพนักงาน (Employee)'
- `employees.card.title` => 'Employees Database'
- `employees.list.title` => 'รายชื่อพนักงาน'
- `employees.action.add` => 'เพิ่มพนักงาน'
- `employees.table.id` => '#'
- `employees.table.name` => 'ชื่อ-นามสกุล'
- `employees.table.position` => 'ตำแหน่ง'
- `employees.table.tax_id` => 'รหัสบัตรประชาชน'
- `employees.table.nationality` => 'สัญชาติ'
- `employees.table.status` => 'สถานะ'
- `employees.table.actions` => 'ตัวเลือก'
- `employees.modal.title_add` => 'เพิ่มพนักงาน'
- `employees.form.name` => 'ชื่อ-นามสกุล'
- `employees.form.position` => 'ตำแหน่ง'
- `employees.form.department` => 'แผนก'
- `employees.form.phone` => 'เบอร์โทร'
- `employees.form.email` => 'อีเมล'
- `employees.form.tax_id` => 'เลขผู้เสียภาษี'
- `employees.form.nationality` => 'สัญชาติ'
- `employees.form.active` => 'Active'

---

### 5. `accounting.php` - Accounting/Expense Management

**สถานะ:** ⚠️ Partial i18n (10% complete)

**ปัญหาที่พบ:**
- ❌ **Line 40:** Hardcoded English "Multiple Edit:"
- ❌ **Line 44:** Hardcoded Thai "เปลี่ยนหมวดหมู่"
- ❌ **Line 53:** Hardcoded Thai "เปลี่ยนวิธีชำระเงิน"
- ❌ **Line 61:** Hardcoded Thai "ส่งอนุมัติ"
- ❌ **Line 62:** Hardcoded Thai "ลบรายการ"
- ❌ **Line 67:** Hardcoded Thai "ระบบบัญชีรายจ่าย"
- ❌ **Line 69:** Hardcoded English "Management" และ "Accounting"
- ❌ **Line 77:** Hardcoded Thai "สรุปเอกสาร (ตามการกรองปัจจุบัน)"
- ❌ **Line 79:** Hardcoded Thai "สร้าง ภ.พ.36"
- ❌ **Line 81:** Hardcoded Thai "สร้าง ภ.พ.30"
- ❌ **Line 84:** Hardcoded Thai "มุมมองยื่นภาษี"
- ❌ **Line 97:** Hardcoded English "Accounting Database"
- ❌ **Line 100:** Hardcoded English "Refresh"
- ❌ **Line 106:** Hardcoded Thai "เพิ่มรายจ่าย"
- ❌ **Line 107:** Hardcoded English "Filter"
- ❌ **Line 116-152:** Hardcoded Thai ใน filter form
- ❌ **Line 157:** Hardcoded Thai table headers
- ❌ **Line 166:** Hardcoded Thai "เพิ่มรายการรายจ่าย"
- ❌ **Line 171-235:** Hardcoded Thai form labels และ placeholders

**ต้องแก้ไข:**
- แทนที่ข้อความทั้งหมดด้วย `translate()` และ `data-i18n`

**Translation Keys ที่ต้องเพิ่ม:**
- `accounting.title` => 'ระบบบัญชีรายจ่าย'
- `accounting.multiple_edit.title` => 'Multiple Edit:'
- `accounting.multiple_edit.change_category` => 'เปลี่ยนหมวดหมู่'
- `accounting.multiple_edit.change_payment_method` => 'เปลี่ยนวิธีชำระเงิน'
- `accounting.multiple_edit.submit_approval` => 'ส่งอนุมัติ'
- `accounting.multiple_edit.delete_items` => 'ลบรายการ'
- `accounting.summary.title` => 'สรุปเอกสาร (ตามการกรองปัจจุบัน)'
- `accounting.summary.generate_pp36` => 'สร้าง ภ.พ.36'
- `accounting.summary.generate_pp30` => 'สร้าง ภ.พ.30'
- `accounting.summary.tax_view` => 'มุมมองยื่นภาษี'
- `accounting.card.title` => 'Accounting Database'
- `accounting.action.add` => 'เพิ่มรายจ่าย'
- `accounting.action.filter` => 'Filter'
- `accounting.filter.date` => 'วันที่'
- `accounting.filter.date.all` => 'ทั้งหมด'
- `accounting.filter.date.today` => 'วันนี้'
- `accounting.filter.date.7days` => '7 วันที่ผ่านมา'
- `accounting.filter.date.this_month` => 'เดือนนี้'
- `accounting.filter.date.last_month` => 'เดือนที่แล้ว'
- `accounting.filter.date.this_year` => 'ปีนี้'
- `accounting.filter.date.custom` => 'กำหนดเอง'
- `accounting.filter.category` => 'หมวดหมู่'
- `accounting.filter.category.all` => 'ทุกหมวดหมู่'
- `accounting.filter.payment_method` => 'วิธีการชำระเงิน'
- `accounting.filter.payment_method.all` => 'ทุกวิธี'
- `accounting.filter.status` => 'สถานะ'
- `accounting.filter.status.all` => 'ทุกสถานะ'
- `accounting.filter.status.approved` => 'อนุมัติแล้ว'
- `accounting.filter.status.pending` => 'รออนุมัติ'
- `accounting.filter.status.rejected` => 'ไม่อนุมัติ'
- `accounting.filter.status.draft` => 'ฉบับร่าง'
- `accounting.filter.reset` => 'ล้างข้อมูล'
- `accounting.table.id` => 'ID'
- `accounting.table.date` => 'วันที่'
- `accounting.table.category` => 'หมวดหมู่'
- `accounting.table.item` => 'รายการ'
- `accounting.table.payee` => 'ผู้รับเงิน'
- `accounting.table.net_amount` => 'ยอดสุทธิ'
- `accounting.table.recorded_by` => 'ผู้บันทึก'
- `accounting.table.status` => 'สถานะ'
- `accounting.table.actions` => 'จัดการ'
- `accounting.modal.title_add` => 'เพิ่มรายการรายจ่าย'
- `accounting.form.date` => 'วันที่เกิดรายการ'
- `accounting.form.amount` => 'จำนวนเงิน (ไม่รวม VAT)'
- `accounting.form.has_vat` => 'มี VAT 7% (ยอด VAT: {amount})'
- `accounting.form.withholding_tax` => 'หักภาษี ณ ที่จ่าย'
- `accounting.form.withholding_tax_amount` => 'ยอดหัก:'
- `accounting.form.category` => 'หมวดหมู่'
- `accounting.form.pp36_required` => 'ต้องยื่น ภ.พ.36 (สำหรับค่าบริการต่างประเทศ เช่น Facebook, Google Ads)'
- `accounting.form.payment_method` => 'วิธีการชำระเงิน'
- `accounting.form.payee` => 'ผู้รับเงิน'
- `accounting.form.payee_type.vendor` => 'ผู้ขาย/บริการ (Vendor)'
- `accounting.form.payee_type.employee` => 'พนักงาน (Employee)'
- `accounting.form.payee_type.text` => 'ระบุเอง (Text)'
- `accounting.form.description` => 'รายละเอียด'
- `accounting.form.receipt` => 'ใบเสร็จ/ใบกำกับ'
- `accounting.form.slip` => 'สลิปโอนเงิน'
- `accounting.form.view_current` => 'ดูไฟล์ปัจจุบัน'
- `accounting.form.delete_file` => 'ลบ'

---

### 6. `vendors.php` - Vendor Management

**สถานะ:** ⚠️ Partial i18n (70% complete)

**ปัญหาที่พบ:**
- ❌ **Line 13:** Hardcoded Thai "จัดการข้อมูลผู้รับเงิน (Vendors)"
- ❌ **Line 19:** Hardcoded Thai "ฐานข้อมูลผู้รับเงิน"
- ❌ **Line 21:** Hardcoded Thai " เพิ่มผู้รับเงินใหม่"
- ❌ **Line 30-37:** Hardcoded Thai table headers
- ❌ **Line 53:** Hardcoded Thai "เพิ่มผู้รับเงินใหม่"
- ❌ **Line 62-64:** Hardcoded Thai tab labels
- ❌ **Line 72-100:** Hardcoded Thai form labels

**ต้องแก้ไข:**
- แทนที่ข้อความที่เหลือด้วย `translate()` และ `data-i18n`

**Translation Keys ที่ต้องเพิ่ม:**
- `vendors.title` => 'จัดการข้อมูลผู้รับเงิน (Vendors)'
- `vendors.card.title` => 'ฐานข้อมูลผู้รับเงิน'
- `vendors.action.add` => 'เพิ่มผู้รับเงินใหม่'
- `vendors.tabs.info` => 'ข้อมูลทั่วไป'
- `vendors.tabs.bank` => 'ข้อมูลธนาคาร'
- `vendors.tabs.docs` => 'เอกสารแนบ'
- `vendors.form.name` => 'ชื่อผู้รับเงิน/บริษัท'
- `vendors.form.type` => 'ประเภทผู้รับเงิน'
- `vendors.form.type.corporate` => 'นิติบุคคล'
- `vendors.form.type.individual` => 'บุคคลธรรมดา'
- `vendors.form.tax` => 'เลขประจำตัวผู้เสียภาษี'
- `vendors.form.nationality` => 'สัญชาติ'
- `vendors.form.nationality.thai` => 'ไทย'
- `vendors.form.nationality.foreign` => 'ต่างชาติ'
- `vendors.form.country` => 'ประเทศ'
- `vendors.form.address` => 'ที่อยู่'

---

### 7. `purchase_rfq.php` - Purchase RFQ

**สถานะ:** ⚠️ Partial i18n (5% complete)

**ปัญหาที่พบ:**
- ❌ **Line 4:** Hardcoded English "Purchase RFQ"
- ❌ **Line 6:** Hardcoded English "Procurement"
- ❌ **Line 7:** Hardcoded English "RFQ"
- ❌ **Line 13:** Hardcoded Thai "รายการขอเสนอราคา (RFQ)"
- ❌ **Line 14:** Hardcoded Thai "สร้าง RFQ"
- ❌ **Line 21-28:** Hardcoded English table headers
- ❌ **Line 44:** Hardcoded Thai "สร้าง RFQ"
- ❌ **Line 52-82:** Hardcoded English form labels
- ❌ **Line 88:** Hardcoded Thai "รายการวัสดุ"
- ❌ **Line 89:** Hardcoded Thai "เพิ่มรายการ"
- ❌ **Line 95-99:** Hardcoded Thai table headers

**ต้องแก้ไข:**
- แทนที่ข้อความทั้งหมดด้วย `translate()` และ `data-i18n`

**Translation Keys ที่ต้องเพิ่ม:**
- `rfq.title` => 'Purchase RFQ'
- `rfq.breadcrumb.procurement` => 'Procurement'
- `rfq.breadcrumb.rfq` => 'RFQ'
- `rfq.card.title` => 'รายการขอเสนอราคา (RFQ)'
- `rfq.action.create` => 'สร้าง RFQ'
- `rfq.table.id` => '#'
- `rfq.table.code` => 'RFQ Code'
- `rfq.table.supplier` => 'Supplier'
- `rfq.table.requested_by` => 'Requested By'
- `rfq.table.requested_at` => 'Requested At'
- `rfq.table.delivery_target` => 'Delivery Target'
- `rfq.table.status` => 'Status'
- `rfq.modal.title_create` => 'สร้าง RFQ'
- `rfq.form.code` => 'RFQ Code'
- `rfq.form.supplier` => 'Supplier'
- `rfq.form.requested_by` => 'Requested By'
- `rfq.form.requested_date` => 'Requested Date'
- `rfq.form.target_delivery` => 'Target Delivery'
- `rfq.form.status` => 'Status'
- `rfq.form.status.draft` => 'Draft'
- `rfq.form.status.submitted` => 'Submitted'
- `rfq.form.status.awarded` => 'Awarded'
- `rfq.form.status.cancelled` => 'Cancelled'
- `rfq.form.remarks` => 'Remarks'
- `rfq.items.title` => 'รายการวัสดุ'
- `rfq.items.action.add` => 'เพิ่มรายการ'
- `rfq.items.table.material` => 'วัสดุ (SKU)'
- `rfq.items.table.qty` => 'จำนวนที่ต้องการ'
- `rfq.items.table.uom` => 'หน่วย'
- `rfq.items.table.spec` => 'รายละเอียดสเปค'

---

### 8. `routing.php` - Routing Management

**สถานะ:** ⚠️ Partial i18n (80% complete)

**ปัญหาที่พบ:**
- ❌ **Line 32:** Hardcoded English "Steps"
- ❌ **Line 33:** Hardcoded English "Total Time"
- ❌ **Line 89:** Hardcoded English "Seq"
- ❌ **Line 91:** Hardcoded English "0=Auto"
- ❌ **Line 94:** Hardcoded English "Step Name" และ placeholder "เช่น ตัด, เย็บ, QC"
- ❌ **Line 98:** Hardcoded English "Step Code" และ placeholder "CUT, SEW"
- ❌ **Line 100-120:** Hardcoded English form labels

**ต้องแก้ไข:**
- แทนที่ข้อความที่เหลือด้วย `translate()` และ `data-i18n`

**Translation Keys ที่ต้องเพิ่ม:**
- `routing.table.steps` => 'Steps'
- `routing.table.total_time` => 'Total Time'
- `routing.steps.form.seq` => 'Seq'
- `routing.steps.form.seq_auto` => '0=Auto'
- `routing.steps.form.step_name` => 'Step Name'
- `routing.steps.form.step_name_placeholder` => 'เช่น ตัด, เย็บ, QC'
- `routing.steps.form.step_code` => 'Step Code'
- `routing.steps.form.step_code_placeholder` => 'CUT, SEW'
- `routing.steps.form.work_center` => 'Work Center'
- `routing.steps.form.estimated_hours` => 'Estimated Hours'
- `routing.steps.form.predecessor` => 'Predecessor'
- `routing.steps.form.instructions` => 'Instructions'

---

## ❌ ไฟล์ที่ยังไม่ได้ทำ i18n เลย (3 ไฟล์)

### 1. `platform_dashboard.php` - Platform Dashboard

**สถานะ:** ❌ No i18n (0% complete)

**ปัญหาที่พบ:**
- ❌ **Line 13:** Hardcoded English "🌐 Platform Dashboard"
- ❌ **Line 16:** Hardcoded English "Platform Console"
- ❌ **Line 17:** Hardcoded English "Dashboard"
- ❌ **Line 34:** Hardcoded English "Total Tenants"
- ❌ **Line 52:** Hardcoded English "Total Users"
- ❌ **Line 70:** Hardcoded English "Migrations"
- ❌ **Line 88:** Hardcoded English "System Health"
- ❌ **Line 100+:** Hardcoded English ในส่วนอื่นๆ

**ต้องแก้ไข:**
- แทนที่ข้อความทั้งหมดด้วย `translate()` และ `data-i18n`
- เพิ่ม translation keys

**Translation Keys ที่ต้องเพิ่ม:**
- `platform.dashboard.title` => '🌐 Platform Dashboard'
- `platform.dashboard.breadcrumb.console` => 'Platform Console'
- `platform.dashboard.breadcrumb.dashboard` => 'Dashboard'
- `platform.dashboard.stats.tenants` => 'Total Tenants'
- `platform.dashboard.stats.users` => 'Total Users'
- `platform.dashboard.stats.migrations` => 'Migrations'
- `platform.dashboard.stats.health` => 'System Health'
- `platform.dashboard.quick_actions.title` => 'Quick Actions'
- `platform.dashboard.quick_actions.create_tenant` => 'Create Tenant'
- `platform.dashboard.quick_actions.run_migration` => 'Run Migration'
- `platform.dashboard.quick_actions.health_check` => 'Health Check'

---

### 2. `platform_health_check.php` - Platform Health Check

**สถานะ:** ❌ No i18n (0% complete)

**ปัญหาที่พบ:**
- ❌ **Line 23:** Hardcoded English "🏥 System Health Check"
- ❌ **Line 26:** Hardcoded English "Platform Console"
- ❌ **Line 27:** Hardcoded English "Health Check"
- ❌ **Line 39:** Hardcoded English "Overall System Health"
- ❌ **Line 40:** Hardcoded English "Running diagnostics..."
- ❌ **Line 44:** Hardcoded English "Run All Tests"
- ❌ **Line 58:** Hardcoded English "🔧 Core System"
- ❌ **Line 59:** Hardcoded English "Not tested"
- ❌ **Line 60:** Hardcoded English "Click "Run All Tests" to start"
- ❌ **Line 68:** Hardcoded English "💾 Database"
- ❌ **Line 78:** Hardcoded English "🔐 Permissions"
- ❌ **Line 88:** Hardcoded English "🔄 Migrations"
- ❌ **Line 98:** Hardcoded English "🏢 Tenants"
- และอื่นๆ

**ต้องแก้ไข:**
- แทนที่ข้อความทั้งหมดด้วย `translate()` และ `data-i18n`
- เพิ่ม translation keys

**Translation Keys ที่ต้องเพิ่ม:**
- `platform.health.title` => '🏥 System Health Check'
- `platform.health.breadcrumb.console` => 'Platform Console'
- `platform.health.breadcrumb.health` => 'Health Check'
- `platform.health.overall.title` => 'Overall System Health'
- `platform.health.overall.running` => 'Running diagnostics...'
- `platform.health.action.run_all` => 'Run All Tests'
- `platform.health.category.core` => '🔧 Core System'
- `platform.health.category.database` => '💾 Database'
- `platform.health.category.permissions` => '🔐 Permissions'
- `platform.health.category.migrations` => '🔄 Migrations'
- `platform.health.category.tenants` => '🏢 Tenants'
- `platform.health.status.not_tested` => 'Not tested'
- `platform.health.status.click_to_start` => 'Click "Run All Tests" to start'

---

### 3. `platform_migration_wizard.php` - Migration Wizard

**สถานะ:** ❌ No i18n (0% complete)

**ปัญหาที่พบ:**
- ❌ **Line 25:** Hardcoded English "🧙‍♂️ Migration Wizard"
- ❌ **Line 28:** Hardcoded English "Platform Console"
- ❌ **Line 29:** Hardcoded English "Migration Wizard"
- ❌ **Line 37:** Hardcoded English "Platform Super Admin Tool:" และ description
- ❌ **Line 49:** Hardcoded Thai "เลือก Migration File"
- ❌ **Line 52:** Hardcoded English "Refresh"
- ❌ **Line 56:** Hardcoded Thai "เลือก migration file ที่ต้องการ deploy"
- ❌ **Line 60:** Hardcoded English "Loading..."
- ❌ **Line 68:** Hardcoded Thai "ยืนยันและไปขั้นตอนถัดไป"
- ❌ **Line 79:** Hardcoded Thai "เลือก Tenants"
- ❌ **Line 83:** Hardcoded Thai "เลือก tenant ที่ต้องการ deploy migration"
- ❌ **Line 87:** Hardcoded English "Select All"
- ❌ **Line 90:** Hardcoded English "Deselect All"
- ❌ **Line 100:** Hardcoded English "Next: Test Migration"
- และอื่นๆ

**ต้องแก้ไข:**
- แทนที่ข้อความทั้งหมดด้วย `translate()` และ `data-i18n`
- เพิ่ม translation keys

**Translation Keys ที่ต้องเพิ่ม:**
- `platform.migration_wizard.title` => '🧙‍♂️ Migration Wizard'
- `platform.migration_wizard.breadcrumb.console` => 'Platform Console'
- `platform.migration_wizard.breadcrumb.wizard` => 'Migration Wizard'
- `platform.migration_wizard.info.title` => 'Platform Super Admin Tool:'
- `platform.migration_wizard.info.description` => 'Test and deploy tenant migrations safely.'
- `platform.migration_wizard.step1.title` => 'เลือก Migration File'
- `platform.migration_wizard.step1.description` => 'เลือก migration file ที่ต้องการ deploy'
- `platform.migration_wizard.step1.confirm` => 'ยืนยันและไปขั้นตอนถัดไป'
- `platform.migration_wizard.step2.title` => 'เลือก Tenants'
- `platform.migration_wizard.step2.description` => 'เลือก tenant ที่ต้องการ deploy migration'
- `platform.migration_wizard.step2.select_all` => 'Select All'
- `platform.migration_wizard.step2.deselect_all` => 'Deselect All'
- `platform.migration_wizard.step2.next` => 'Next: Test Migration'

---

## 📝 ไฟล์พิเศษ (Special Cases)

### `routing_graph_help.php` - Routing Graph Help Modal

**สถานะ:** ⚠️ Partial i18n (Thai content - ควรทำ i18n)

**ปัญหาที่พบ:**
- ❌ เนื้อหาทั้งหมดเป็นภาษาไทย hardcode
- ❌ เป็น modal help ที่มีเนื้อหามาก (400+ บรรทัด)
- ❌ ควรทำ i18n เพื่อรองรับภาษาอังกฤษ

**คำแนะนำ:**
- แบ่งเนื้อหาเป็น sections และใช้ translation keys
- อาจใช้วิธี load content จาก JSON หรือ separate PHP files

---

## 🎯 สรุปและคำแนะนำ

### สถานะโดยรวม:
- ✅ **47%** ของ views ทำ i18n ครบถ้วนแล้ว
- ⚠️ **15%** ของ views ทำ i18n บางส่วน (ต้องแก้ไขเพิ่มเติม)
- ❌ **6%** ของ views ยังไม่ได้ทำ i18n เลย
- 📝 **32%** เป็นไฟล์อื่นๆ (templates, error pages, etc.)

### ลำดับความสำคัญในการแก้ไข:

**Priority 1 (High):**
1. `accounting.php` - ใช้บ่อยมาก, มี hardcode มาก
2. `dashboard.php` - หน้าแรกที่ผู้ใช้เห็น, มี hardcode มาก
3. `exceptions_board.php` - ใช้บ่อย, มี hardcode มาก

**Priority 2 (Medium):**
4. `employees.php` - ใช้บ่อย, มี hardcode ปานกลาง
5. `vendors.php` - ใช้บ่อย, มี hardcode น้อย
6. `mo.php` - ใช้บ่อย, มี hardcode น้อยมาก (แค่ 1 alert box)

**Priority 3 (Low):**
7. `purchase_rfq.php` - ใช้น้อย
8. `routing.php` - ใช้บ่อยแต่ hardcode น้อย
9. `platform_dashboard.php` - Platform admin only
10. `platform_health_check.php` - Platform admin only
11. `platform_migration_wizard.php` - Platform admin only

### ขั้นตอนการแก้ไข:

1. **เพิ่ม Translation Keys:**
   - เพิ่ม keys ใน `lang/en.php` (English default)
   - เพิ่ม keys ใน `lang/th.php` (Thai translation)

2. **แก้ไข Views:**
   - แทนที่ hardcoded text ด้วย `translate()`
   - เพิ่ม `data-i18n` attributes สำหรับ JavaScript

3. **ทดสอบ:**
   - เปลี่ยนภาษาและตรวจสอบว่าข้อความเปลี่ยนถูกต้อง
   - ตรวจสอบว่าไม่มีข้อความตกหล่น

### ตัวอย่างการแก้ไข:

**Before (❌ WRONG - Hardcode ภาษาไทย):**
```php
<h1 class="page-title">ระบบบัญชีรายจ่าย</h1>
```

**After (✅ CORRECT - English default):**
```php
<h1 class="page-title my-auto" data-i18n="accounting.title">
    <?php echo translate('accounting.title', 'Accounting System'); ?>
</h1>
```

**Translation Files:**
```php
// lang/en.php
'accounting.title' => 'Accounting System',

// lang/th.php
'accounting.title' => 'ระบบบัญชีรายจ่าย',
```

### ⚠️ **Critical Reminder:**

**เมื่อแก้ไข views:**
1. ✅ **ต้องใช้ภาษาอังกฤษเป็น default** ใน `translate()` function
2. ✅ **ห้าม hardcode ภาษาไทย** ในโค้ด
3. ✅ **ห้ามใช้ emoji/symbols** ในโค้ด (ใช้ใน translation files ได้)
4. ✅ **เพิ่ม translation keys** ในทั้ง `lang/en.php` และ `lang/th.php`
5. ✅ **ทดสอบการเปลี่ยนภาษา** ว่าทำงานถูกต้อง

---

## 📜 JavaScript Files i18n Audit

### 📊 สรุปภาพรวม JavaScript Files

| สถานะ | จำนวนไฟล์ | รายละเอียด |
|-------|----------|-----------|
| ✅ **i18n Complete** | 30+ | ใช้ `const t = (key, fallback) => window.APP_I18N?.[key] ?? fallback ?? key;` ครบถ้วน |
| ⚠️ **Partial i18n** | 5 | มีบางส่วนที่ยัง hardcode ข้อความ |
| ❌ **No i18n** | 8 | ยังไม่ได้ทำ i18n เลย |
| 📝 **Total JS Files** | 63 | ไฟล์ JavaScript ทั้งหมด |

---

### ✅ ไฟล์ที่ทำ i18n ครบถ้วนแล้ว (30+ ไฟล์)

ไฟล์เหล่านี้ใช้ `const t = (key, fallback) => window.APP_I18N?.[key] ?? fallback ?? key;` อย่างถูกต้อง:

1. ✅ `products/products.js` - Products Management
2. ✅ `products/product_graph_binding.js` - Product Graph Binding
3. ✅ `dag/graph_designer.js` - Graph Designer
4. ✅ `trace/product_traceability.js` - Product Traceability
5. ✅ `trace/trace_overview.js` - Trace Overview
6. ✅ `dashboard/production_dashboard.js` - Production Dashboard
7. ✅ `pwa_scan/pwa_scan.js` - PWA Scan Station
8. ✅ `hatthasilpa/job_ticket.js` - Job Tickets
9. ✅ `mo/mo.js` - Manufacturing Orders
10. ✅ `pwa_scan/work_queue.js` - Work Queue
11. ✅ `manager/assignment.js` - Manager Assignment
12. ✅ `dag/graph_sidebar.js` - Graph Sidebar
13. ✅ `dag/graph_sidebar_debug.js` - Graph Sidebar Debug
14. ✅ `hatthasilpa/jobs.js` - Hatthasilpa Jobs
15. ✅ `platform/serial_salt.js` - Serial Salt
16. ✅ `token/management.js` - Token Management
17. ✅ `hatthasilpa/schedule.js` - Production Schedule
18. ✅ `team/management.js` - Team Management
19. ✅ `qc_rework/qc_rework.js` - QC Rework
20. ✅ `token/redesign.js` - Token Redesign
21. ✅ `tenant/users.js` - Tenant Users
22. ✅ `platform/roles.js` - Platform Roles
23. ✅ `admin/roles.js` - Admin Roles
24. ✅ `admin/organizations.js` - Admin Organizations
25. ✅ `platform/tenant_owners.js` - Tenant Owners
26. ✅ `admin/users.js` - Admin Users
27. ✅ `bom/bom.js` - Bill of Materials
28. ✅ `materials/materials.js` - Materials
29. ✅ `routing/routing.js` - Routing Management
30. ✅ `work_centers/work_centers.js` - Work Centers
31. ✅ `dashboard/qc_fail_widget.js` - QC Fail Widget
32. ✅ `system_log/system_log.js` - System Log
33. ✅ `issue/issue.js` - Material Issues
34. ✅ `transfer/transfer.js` - Stock Transfers
35. ✅ `adjust/adjust.js` - Stock Adjustments
36. ✅ `stock_card/stock_card.js` - Stock Card
37. ✅ `stock_on_hand/stock_on_hand.js` - Stock On Hand
38. ✅ `grn/grn.js` - Goods Receipts
39. ✅ `locations/locations.js` - Locations
40. ✅ `warehouses/warehouses.js` - Warehouses
41. ✅ `uom/uom.js` - Unit of Measure
42. ✅ `vendors/vendors.js` - Vendors
43. ✅ `product_categories/product_categories.js` - Product Categories
44. ✅ `notifications/header_notifications.js` - Header Notifications
45. ✅ `pwa_scan/offline-queue.js` - Offline Queue

---

### ⚠️ ไฟล์ที่ทำ i18n บางส่วน (ต้องแก้ไขเพิ่มเติม)

#### 1. `dashboard/dashboard.js` ⚠️

**สถานะ:** ⚠️ Partial i18n (มี `t()` function แต่ยังมี hardcode บางส่วน)

**ปัญหาที่พบ:**
- ✅ มี `const t = (key, fallback) => window.APP_I18N?.[key] ?? fallback ?? key;`
- ❌ Hardcode: `'0 วัน'` (line 117)
- ❌ Hardcode: `'ไม่มีข้อมูล'` (line 133)
- ❌ Hardcode: `'Error'` (line 105)

**Translation Keys ที่ต้องเพิ่ม:**
```javascript
// lang/en.php
'dashboard.kpi.lead_time_days' => '{days} days',
'dashboard.activity.no_data' => 'No data available',
'dashboard.error.generic' => 'Error',

// lang/th.php
'dashboard.kpi.lead_time_days' => '{days} วัน',
'dashboard.activity.no_data' => 'ไม่มีข้อมูล',
'dashboard.error.generic' => 'เกิดข้อผิดพลาด',
```

**ตัวอย่างการแก้ไข:**
```javascript
// Before (❌ WRONG):
$('[data-kpi="lead-time"]').text(data.lead_time || '0 วัน');

// After (✅ CORRECT):
$('[data-kpi="lead-time"]').text(data.lead_time || t('dashboard.kpi.lead_time_days', '0 days', {days: 0}));
```

---

#### 2. `mo/mo.js` ⚠️

**สถานะ:** ⚠️ Partial i18n (มี `t()` function แต่ยังมี hardcode บางส่วน)

**ปัญหาที่พบ:**
- ✅ มี `const t = (key, fallback) => window.APP_I18N?.[key] ?? fallback ?? key;`
- ❌ Hardcode: `'✅ ${resp.suggested.graph_name} (Recommended)'` (line 52) - emoji ในโค้ด

**คำแนะนำ:**
- ควรย้าย emoji ไปไว้ใน translation files

---

### ❌ ไฟล์ที่ยังไม่ได้ทำ i18n เลย (Priority High)

#### 1. `accounting/accounting.js` ❌

**สถานะ:** ❌ No i18n (ไม่มี `t()` function, มี hardcode text มาก)

**ปัญหาที่พบ:**
- ❌ ไม่มี `const t = (key, fallback) => ...`
- ❌ Hardcode text ใน DataTable language config (line 70)
- ❌ Hardcode text ใน error messages
- ❌ Hardcode text ใน Swal.fire() dialogs
- ❌ Hardcode text ใน toastr notifications

**ตัวอย่าง hardcode ที่พบ:**
```javascript
// Line 70
language: { url: window.location.origin + "/assets/vendor/datatables/plug-ins/1.13.6/i18n/th.json" },

// Line 60
render: (data) => data ? new Date(data).toLocaleDateString('th-TH', { year: '2-digit', month: '2-digit', day: '2-digit' }) : '',

// และอื่นๆ อีกมาก
```

**Translation Keys ที่ต้องเพิ่ม:**
```javascript
// lang/en.php
'accounting.table.language_url' => '/assets/vendor/datatables/plug-ins/1.13.6/i18n/en.json',
'accounting.date.format' => 'en-US',
'accounting.toast.saved' => 'Expense saved successfully',
'accounting.toast.deleted' => 'Expense deleted successfully',
'accounting.swal.confirm_delete' => 'Are you sure you want to delete this expense?',
'accounting.swal.delete_success' => 'Deleted',
'accounting.swal.delete_error' => 'Error',

// lang/th.php
'accounting.table.language_url' => '/assets/vendor/datatables/plug-ins/1.13.6/i18n/th.json',
'accounting.date.format' => 'th-TH',
'accounting.toast.saved' => 'บันทึกรายจ่ายสำเร็จ',
'accounting.toast.deleted' => 'ลบรายจ่ายสำเร็จ',
'accounting.swal.confirm_delete' => 'คุณแน่ใจหรือไม่ว่าต้องการลบรายจ่ายนี้?',
'accounting.swal.delete_success' => 'ลบสำเร็จ',
'accounting.swal.delete_error' => 'เกิดข้อผิดพลาด',
```

**ตัวอย่างการแก้ไข:**
```javascript
// Before (❌ WRONG):
const AccountingApp = {
    // ... no t() function
    language: { url: window.location.origin + "/assets/vendor/datatables/plug-ins/1.13.6/i18n/th.json" },
};

// After (✅ CORRECT):
const AccountingApp = {
    // Add t() function at top
    t: (key, fallback) => window.APP_I18N?.[key] ?? fallback ?? key,
    
    // Use translation
    language: { 
        url: window.location.origin + this.t('accounting.table.language_url', '/assets/vendor/datatables/plug-ins/1.13.6/i18n/en.json')
    },
};
```

---

#### 2. `employees/employees.js` ❌

**สถานะ:** ❌ No i18n (ไม่มี `t()` function, มี hardcode ภาษาไทยมาก)

**ปัญหาที่พบ:**
- ❌ ไม่มี `const t = (key, fallback) => ...`
- ❌ Hardcode ภาษาไทย: `'แก้ไข'` (line 29)
- ❌ Hardcode ภาษาไทย: `'เพิ่มพนักงาน'` (line 42)
- ❌ Hardcode ภาษาไทย: `'แก้ไขพนักงาน'` (line 60)
- ❌ Hardcode ภาษาไทย: `'สำเร็จ'`, `'ผิดพลาด'`, `'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์'` (lines 76-81)

**Translation Keys ที่ต้องเพิ่ม:**
```javascript
// lang/en.php
'employees.action.edit' => 'Edit',
'employees.modal.title_add' => 'Add Employee',
'employees.modal.title_edit' => 'Edit Employee',
'employees.toast.success' => 'Success',
'employees.toast.error' => 'Error',
'employees.toast.network_error' => 'Cannot connect to server',
'employees.status.active' => 'Active',
'employees.status.inactive' => 'Inactive',

// lang/th.php
'employees.action.edit' => 'แก้ไข',
'employees.modal.title_add' => 'เพิ่มพนักงาน',
'employees.modal.title_edit' => 'แก้ไขพนักงาน',
'employees.toast.success' => 'สำเร็จ',
'employees.toast.error' => 'ผิดพลาด',
'employees.toast.network_error' => 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์',
'employees.status.active' => 'ใช้งาน',
'employees.status.inactive' => 'ไม่ใช้งาน',
```

**ตัวอย่างการแก้ไข:**
```javascript
// Before (❌ WRONG):
render: data => `<a href="#" class="btn btn-sm btn-warning edit-btn" data-id="${data}">แก้ไข</a>`

// After (✅ CORRECT):
const t = (key, fallback) => window.APP_I18N?.[key] ?? fallback ?? key;
render: data => `<a href="#" class="btn btn-sm btn-warning edit-btn" data-id="${data}">${t('employees.action.edit', 'Edit')}</a>`
```

---

#### 3. `exceptions_board/exceptions_board.js` ❌

**สถานะ:** ❌ No i18n (ไม่มี `t()` function, มี hardcode ภาษาไทยมาก)

**ปัญหาที่พบ:**
- ❌ ไม่มี `const t = (key, fallback) => ...`
- ❌ Hardcode ภาษาไทย: `'✅ ไม่มีงานค้าง'` (line 41)
- ❌ Hardcode ภาษาไทย: `'${job.days_stuck} วัน'` (line 50)
- ❌ Hardcode ภาษาไทย: `'✅ ไม่มี Rework Loop'` (line 64)
- ❌ Hardcode ภาษาไทย: `'${loop.fail_count} ครั้ง'` (line 72)
- ❌ Hardcode ภาษาไทย: `'✅ ไม่พบ QC Fail Spike'` (line 86)
- ❌ Hardcode: `'Error'`, `'Failed to load exceptions data'` (line 34)

**Translation Keys ที่ต้องเพิ่ม:**
```javascript
// lang/en.php
'exceptions.stuck_jobs.empty' => 'No stuck jobs',
'exceptions.stuck_jobs.days' => '{days} days',
'exceptions.rework_loops.empty' => 'No rework loops',
'exceptions.rework_loops.fail_count' => '{count} times',
'exceptions.fail_spikes.empty' => 'No QC fail spikes found',
'exceptions.error.load_failed' => 'Failed to load exceptions data',
'exceptions.action.view' => 'View',

// lang/th.php
'exceptions.stuck_jobs.empty' => 'ไม่มีงานค้าง',
'exceptions.stuck_jobs.days' => '{days} วัน',
'exceptions.rework_loops.empty' => 'ไม่มี Rework Loop',
'exceptions.rework_loops.fail_count' => '{count} ครั้ง',
'exceptions.fail_spikes.empty' => 'ไม่พบ QC Fail Spike',
'exceptions.error.load_failed' => 'โหลดข้อมูล exceptions ไม่สำเร็จ',
'exceptions.action.view' => 'ดู',
```

**ตัวอย่างการแก้ไข:**
```javascript
// Before (❌ WRONG):
if (!jobs.length) {
    tbody.innerHTML = '<tr><td colspan="6" class="text-center text-muted">✅ ไม่มีงานค้าง</td></tr>';
    return;
}

// After (✅ CORRECT):
const t = (key, fallback) => window.APP_I18N?.[key] ?? fallback ?? key;
if (!jobs.length) {
    tbody.innerHTML = `<tr><td colspan="6" class="text-center text-muted">${t('exceptions.stuck_jobs.empty', 'No stuck jobs')}</td></tr>`;
    return;
}
```

---

#### 4. `purchase/rfq.js` ❌

**สถานะ:** ❌ No i18n (ไม่มี `t()` function, มี hardcode บางส่วน)

**ปัญหาที่พบ:**
- ❌ ไม่มี `const t = (key, fallback) => ...`
- ❌ Hardcode: `'เช่น ความหนา 1.4-1.6mm'` (line 73) - placeholder text
- ❌ Hardcode: `'--'` (line 94) - select option
- ❌ Hardcode text ใน error messages และ notifications

**Translation Keys ที่ต้องเพิ่ม:**
```javascript
// lang/en.php
'rfq.form.spec_placeholder' => 'e.g., Thickness 1.4-1.6mm',
'rfq.form.select_option' => '--',
'rfq.toast.saved' => 'RFQ saved successfully',
'rfq.toast.error' => 'Error saving RFQ',

// lang/th.php
'rfq.form.spec_placeholder' => 'เช่น ความหนา 1.4-1.6mm',
'rfq.form.select_option' => '--',
'rfq.toast.saved' => 'บันทึก RFQ สำเร็จ',
'rfq.toast.error' => 'เกิดข้อผิดพลาดในการบันทึก RFQ',
```

---

#### 5. `platform_migration_wizard/platform_migration_wizard.js` ❌

**สถานะ:** ❌ No i18n (ไม่มี `t()` function, มี hardcode มาก)

**ปัญหาที่พบ:**
- ❌ ไม่มี `const t = (key, fallback) => ...`
- ❌ Hardcode: `'ไม่พบ migration files'` (line 44)
- ❌ Hardcode: `'Error'`, `'Failed to load migrations'` (line 32)
- ❌ Hardcode: `'Network error'` (line 36)
- ❌ Hardcode text ใน UI elements และ messages

**Translation Keys ที่ต้องเพิ่ม:**
```javascript
// lang/en.php
'migration_wizard.no_files' => 'No migration files found',
'migration_wizard.error.load_failed' => 'Failed to load migrations',
'migration_wizard.error.network' => 'Network error',
'migration_wizard.warnings' => '{count} warnings',

// lang/th.php
'migration_wizard.no_files' => 'ไม่พบ migration files',
'migration_wizard.error.load_failed' => 'โหลด migrations ไม่สำเร็จ',
'migration_wizard.error.network' => 'เกิดข้อผิดพลาดเครือข่าย',
'migration_wizard.warnings' => '{count} คำเตือน',
```

---

#### 6. `platform_health_check/platform_health_check.js` ❌

**สถานะ:** ❌ No i18n (ไม่มี `t()` function, มี hardcode มาก)

**ปัญหาที่พบ:**
- ❌ ไม่มี `const t = (key, fallback) => ...`
- ❌ Hardcode: `'Running...'` (line 14)
- ❌ Hardcode: `'Error'`, `'Failed to run tests'` (line 28)
- ❌ Hardcode: `'Failed to connect to API'` (line 32)
- ❌ Hardcode: `'All passed'`, `'{failed} failed'`, `'{warnings} warnings'` (lines 86-92)

**Translation Keys ที่ต้องเพิ่ม:**
```javascript
// lang/en.php
'health_check.running' => 'Running...',
'health_check.error.run_failed' => 'Failed to run tests',
'health_check.error.api_failed' => 'Failed to connect to API',
'health_check.status.all_passed' => 'All passed',
'health_check.status.failed' => '{count} failed',
'health_check.status.warnings' => '{count} warnings',

// lang/th.php
'health_check.running' => 'กำลังรัน...',
'health_check.error.run_failed' => 'รัน tests ไม่สำเร็จ',
'health_check.error.api_failed' => 'เชื่อมต่อ API ไม่สำเร็จ',
'health_check.status.all_passed' => 'ผ่านทั้งหมด',
'health_check.status.failed' => 'ล้มเหลว {count} รายการ',
'health_check.status.warnings' => '{count} คำเตือน',
```

---

#### 7. `platform/dashboard.js` ❌

**สถานะ:** ❌ No i18n (ไม่มี `t()` function, มี hardcode มาก)

**ปัญหาที่พบ:**
- ❌ ไม่มี `const t = (key, fallback) => ...`
- ❌ Hardcode: `'No tenants found'` (line 51)
- ❌ Hardcode: `'Active'`, `'Inactive'` (lines 58-59)

**Translation Keys ที่ต้องเพิ่ม:**
```javascript
// lang/en.php
'platform.dashboard.no_tenants' => 'No tenants found',
'platform.dashboard.status.active' => 'Active',
'platform.dashboard.status.inactive' => 'Inactive',

// lang/th.php
'platform.dashboard.no_tenants' => 'ไม่พบ tenants',
'platform.dashboard.status.active' => 'ใช้งาน',
'platform.dashboard.status.inactive' => 'ไม่ใช้งาน',
```

---

#### 8. `global_script.js` ❌

**สถานะ:** ❌ No i18n (ไม่มี `t()` function, มี hardcode ภาษาไทย)

**ปัญหาที่พบ:**
- ❌ ไม่มี `const t = (key, fallback) => ...`
- ❌ Hardcode ภาษาไทย: `'อัปเดตล่าสุด: '` (line 97)
- ❌ Hardcode locale: `'th-TH'` (line 96)

**Translation Keys ที่ต้องเพิ่ม:**
```javascript
// lang/en.php
'global.last_update' => 'Last updated: ',
'global.date.locale' => 'en-US',

// lang/th.php
'global.last_update' => 'อัปเดตล่าสุด: ',
'global.date.locale' => 'th-TH',
```

**ตัวอย่างการแก้ไข:**
```javascript
// Before (❌ WRONG):
const formattedDateTime = now.toLocaleString('th-TH', options);
$('span.updateLastUpdateTimestamp').text('อัปเดตล่าสุด: ' + formattedDateTime);

// After (✅ CORRECT):
const t = (key, fallback) => window.APP_I18N?.[key] ?? fallback ?? key;
const locale = t('global.date.locale', 'en-US');
const formattedDateTime = now.toLocaleString(locale, options);
$('span.updateLastUpdateTimestamp').text(t('global.last_update', 'Last updated: ') + formattedDateTime);
```

---

#### 9. `login/login.js` ❌

**สถานะ:** ❌ No i18n (ไม่มี `t()` function, มี hardcode ภาษาอังกฤษ)

**ปัญหาที่พบ:**
- ❌ ไม่มี `const t = (key, fallback) => ...`
- ❌ Hardcode: `'Please enter your Email'` (line 85)
- ❌ Hardcode: `'Please enter your Password'` (line 90)
- ❌ Hardcode: `'Your Password is wrong. Please check your Password'` (line 95)
- ❌ Hardcode: `'Your Email is wrong. Please check your Email'` (line 99)

**Translation Keys ที่ต้องเพิ่ม:**
```javascript
// lang/en.php
'login.error.email_required' => 'Please enter your Email',
'login.error.password_required' => 'Please enter your Password',
'login.error.password_wrong' => 'Your Password is wrong. Please check your Password',
'login.error.email_wrong' => 'Your Email is wrong. Please check your Email',

// lang/th.php
'login.error.email_required' => 'กรุณากรอกอีเมล',
'login.error.password_required' => 'กรุณากรอกรหัสผ่าน',
'login.error.password_wrong' => 'รหัสผ่านไม่ถูกต้อง กรุณาตรวจสอบรหัสผ่าน',
'login.error.email_wrong' => 'อีเมลไม่ถูกต้อง กรุณาตรวจสอบอีเมล',
```

---

### 📋 สรุปและคำแนะนำสำหรับ JavaScript Files

### ลำดับความสำคัญในการแก้ไข:

**Priority 1 (High):**
1. `accounting/accounting.js` - ใช้บ่อยมาก, มี hardcode มาก
2. `employees/employees.js` - ใช้บ่อย, มี hardcode ภาษาไทยมาก
3. `exceptions_board/exceptions_board.js` - ใช้บ่อย, มี hardcode ภาษาไทยมาก
4. `global_script.js` - ใช้ทุกหน้า, มี hardcode ภาษาไทย

**Priority 2 (Medium):**
5. `login/login.js` - หน้าแรกที่ผู้ใช้เห็น
6. `dashboard/dashboard.js` - หน้าแรก, มี hardcode บางส่วน
7. `purchase/rfq.js` - ใช้บ่อย, มี hardcode น้อย

**Priority 3 (Low):**
8. `platform_migration_wizard/platform_migration_wizard.js` - Platform admin only
9. `platform_health_check/platform_health_check.js` - Platform admin only
10. `platform/dashboard.js` - Platform admin only
11. `mo/mo.js` - มี hardcode น้อยมาก (แค่ emoji)

### ขั้นตอนการแก้ไข JavaScript Files:

1. **เพิ่ม t() function ที่ต้นไฟล์:**
   ```javascript
   const t = (key, fallback) => window.APP_I18N?.[key] ?? fallback ?? key;
   ```

2. **แทนที่ hardcoded text:**
   ```javascript
   // Before (❌ WRONG):
   Swal.fire('สำเร็จ', 'บันทึกสำเร็จ', 'success');
   
   // After (✅ CORRECT):
   Swal.fire(t('common.success', 'Success'), t('common.saved', 'Saved'), 'success');
   ```

3. **เพิ่ม Translation Keys:**
   - เพิ่ม keys ใน `lang/en.php` (English default)
   - เพิ่ม keys ใน `lang/th.php` (Thai translation)

4. **ทดสอบ:**
   - เปลี่ยนภาษาและตรวจสอบว่าข้อความเปลี่ยนถูกต้อง
   - ตรวจสอบว่าไม่มีข้อความตกหล่น

### ⚠️ **Critical Reminder สำหรับ JavaScript:**

**เมื่อแก้ไข JavaScript files:**
1. ✅ **ต้องเพิ่ม `const t = (key, fallback) => window.APP_I18N?.[key] ?? fallback ?? key;` ที่ต้นไฟล์**
2. ✅ **ต้องใช้ภาษาอังกฤษเป็น default** ใน `t()` function
3. ✅ **ห้าม hardcode ภาษาไทย** ในโค้ด
4. ✅ **ห้ามใช้ emoji/symbols** ในโค้ด (ใช้ใน translation files ได้)
5. ✅ **เพิ่ม translation keys** ในทั้ง `lang/en.php` และ `lang/th.php`
6. ✅ **ทดสอบการเปลี่ยนภาษา** ว่าทำงานถูกต้อง

---

## 📊 สถิติ

### Views Files:
- **Total Views:** 53 files
- **Complete i18n:** 37 files (70%)
- **Partial i18n:** 8 files (15%)
- **No i18n:** 3 files (6%)
- **Special cases:** 5 files (9%)

### JavaScript Files:
- **Total JS Files:** 63 files
- **Complete i18n:** 45 files (71%)
- **Partial i18n:** 5 files (8%)
- **No i18n:** 8 files (13%)
- **Vendor/Library:** 5 files (8%)

---

## 🔌 API Files i18n Audit

### 📊 สรุปภาพรวม API Files

| สถานะ | จำนวนไฟล์ | รายละเอียด |
|-------|----------|-----------|
| ✅ **i18n Complete** | 5+ | ใช้ `translate()` ใน error messages และ user-facing text ครบถ้วน |
| ⚠️ **Partial i18n** | 3 | มีบางส่วนที่ยัง hardcode ข้อความ |
| ❌ **No i18n** | 50+ | ยังไม่ได้ทำ i18n เลย (ใช้ app_code แต่ไม่มี translate) |
| 📝 **Total API Files** | 64 | ไฟล์ API ทั้งหมด (source/*.php) |
| 📝 **Total Service Files** | 36 | ไฟล์ Service ทั้งหมด (BGERP/Service/*.php) |

---

### ✅ ไฟล์ที่ทำ i18n ครบถ้วนแล้ว (5+ ไฟล์)

ไฟล์เหล่านี้ใช้ `translate()` ใน error messages และ user-facing text อย่างถูกต้อง:

1. ✅ `qc_rework.php` - QC Rework API (ใช้ translate() บางส่วน)
2. ✅ `global_function.php` - Global functions (มี translate() function definition)
3. ✅ `lang_switch.php` - Language Switch API
4. ✅ `BGERP/Service/OperatorDirectoryService.php` - Operator Directory Service

**หมายเหตุ:** ไฟล์ API ส่วนใหญ่ใช้ `app_code` สำหรับ error handling ซึ่งเป็นมาตรฐานที่ดี แต่ยังไม่มี `translate()` สำหรับ user-facing messages

---

### ⚠️ ไฟล์ที่ทำ i18n บางส่วน (ต้องแก้ไขเพิ่มเติม)

#### 1. `qc_rework.php` ⚠️

**สถานะ:** ⚠️ Partial i18n (ใช้ `translate()` บางส่วน)

**ปัญหาที่พบ:**
- ✅ ใช้ `translate()` ในบาง error messages (line 72)
- ❌ Hardcode: `'forbidden'` (line 99) - ควรใช้ translate()
- ❌ Hardcode text ใน success messages และ error messages อื่นๆ

**ตัวอย่าง:**
```php
// ✅ GOOD - ใช้ translate()
json_error(translate('qc_rework.error.no_org', 'Cannot determine current organization'), 500, ['app_code' => 'QC_500_NO_ORG']);

// ❌ BAD - Hardcode
json_error('forbidden', 403, ['app_code' => 'QC_403_FORBIDDEN']);
```

**Translation Keys ที่ต้องเพิ่ม:**
```php
// lang/en.php
'qc_rework.error.forbidden' => 'Access forbidden',
'qc_rework.error.no_org' => 'Cannot determine current organization',
'qc_rework.success.created' => 'QC fail event created successfully',
'qc_rework.success.updated' => 'QC fail event updated successfully',

// lang/th.php
'qc_rework.error.forbidden' => 'ไม่มีสิทธิ์เข้าถึง',
'qc_rework.error.no_org' => 'ไม่สามารถระบุองค์กรปัจจุบันได้',
'qc_rework.success.created' => 'สร้าง QC fail event สำเร็จ',
'qc_rework.success.updated' => 'อัปเดต QC fail event สำเร็จ',
```

---

#### 2. `hatthasilpa_job_ticket.php` ⚠️

**สถานะ:** ⚠️ Partial i18n (ใช้ `translate()` ใน comments แต่ยังไม่มีใน error messages)

**ปัญหาที่พบ:**
- ❌ Hardcode: `'unauthorized'`, `'no_org'`, `'service_unavailable'`, `'validation_failed'` (lines 66, 71, 77, 110)
- ❌ Hardcode text ใน success messages และ error messages

**Translation Keys ที่ต้องเพิ่ม:**
```php
// lang/en.php
'hatthasilpa_job_ticket.error.unauthorized' => 'Unauthorized',
'hatthasilpa_job_ticket.error.no_org' => 'Cannot determine current organization',
'hatthasilpa_job_ticket.error.service_unavailable' => 'Service unavailable',
'hatthasilpa_job_ticket.error.validation_failed' => 'Validation failed',
'hatthasilpa_job_ticket.success.created' => 'Job ticket created successfully',
'hatthasilpa_job_ticket.success.updated' => 'Job ticket updated successfully',

// lang/th.php
'hatthasilpa_job_ticket.error.unauthorized' => 'ไม่มีสิทธิ์',
'hatthasilpa_job_ticket.error.no_org' => 'ไม่สามารถระบุองค์กรปัจจุบันได้',
'hatthasilpa_job_ticket.error.service_unavailable' => 'บริการไม่พร้อมใช้งาน',
'hatthasilpa_job_ticket.error.validation_failed' => 'การตรวจสอบข้อมูลล้มเหลว',
'hatthasilpa_job_ticket.success.created' => 'สร้าง job ticket สำเร็จ',
'hatthasilpa_job_ticket.success.updated' => 'อัปเดต job ticket สำเร็จ',
```

---

#### 3. `assignment_api.php` ⚠️

**สถานะ:** ⚠️ Partial i18n (ยังไม่มี `translate()` ใน error messages)

**ปัญหาที่พบ:**
- ❌ Hardcode: `'Permission denied - Managers only'` (line 86)
- ❌ Hardcode: `'unauthorized'`, `'no_org'`, `'service_unavailable'` (lines 44, 49, 55)

**Translation Keys ที่ต้องเพิ่ม:**
```php
// lang/en.php
'assignment.error.unauthorized' => 'Unauthorized',
'assignment.error.no_org' => 'Cannot determine current organization',
'assignment.error.service_unavailable' => 'Service unavailable',
'assignment.error.forbidden_managers_only' => 'Permission denied - Managers only',
'assignment.success.assigned' => 'Token assigned successfully',

// lang/th.php
'assignment.error.unauthorized' => 'ไม่มีสิทธิ์',
'assignment.error.no_org' => 'ไม่สามารถระบุองค์กรปัจจุบันได้',
'assignment.error.service_unavailable' => 'บริการไม่พร้อมใช้งาน',
'assignment.error.forbidden_managers_only' => 'ไม่มีสิทธิ์ - เฉพาะผู้จัดการเท่านั้น',
'assignment.success.assigned' => 'มอบหมาย token สำเร็จ',
```

**ตัวอย่างการแก้ไข:**
```php
// Before (❌ WRONG):
json_error('Permission denied - Managers only', 403, ['app_code' => 'ASSIGN_403_FORBIDDEN']);

// After (✅ CORRECT):
json_error(translate('assignment.error.forbidden_managers_only', 'Permission denied - Managers only'), 403, ['app_code' => 'ASSIGN_403_FORBIDDEN']);
```

---

### ❌ ไฟล์ที่ยังไม่ได้ทำ i18n เลย (Priority High)

#### 1. `purchase_rfq.php` ❌

**สถานะ:** ❌ No i18n (ไม่มี `translate()` ใน error messages)

**ปัญหาที่พบ:**
- ❌ Hardcode: `'Invalid action'` (line 128)
- ❌ Hardcode: `'unauthorized'`, `'no_org'`, `'service_unavailable'` (lines 71, 89, 79)
- ❌ Hardcode text ใน success messages และ error messages

**Translation Keys ที่ต้องเพิ่ม:**
```php
// lang/en.php
'purchase_rfq.error.unauthorized' => 'Unauthorized',
'purchase_rfq.error.no_org' => 'Cannot determine current organization',
'purchase_rfq.error.service_unavailable' => 'Service unavailable',
'purchase_rfq.error.invalid_action' => 'Invalid action',
'purchase_rfq.success.created' => 'RFQ created successfully',
'purchase_rfq.success.updated' => 'RFQ updated successfully',

// lang/th.php
'purchase_rfq.error.unauthorized' => 'ไม่มีสิทธิ์',
'purchase_rfq.error.no_org' => 'ไม่สามารถระบุองค์กรปัจจุบันได้',
'purchase_rfq.error.service_unavailable' => 'บริการไม่พร้อมใช้งาน',
'purchase_rfq.error.invalid_action' => 'Action ไม่ถูกต้อง',
'purchase_rfq.success.created' => 'สร้าง RFQ สำเร็จ',
'purchase_rfq.success.updated' => 'อัปเดต RFQ สำเร็จ',
```

---

#### 2. `products.php` ❌

**สถานะ:** ❌ No i18n (ไม่มี `translate()` ใน error messages)

**ปัญหาที่พบ:**
- ❌ Hardcode text ใน error messages และ success messages
- ❌ Hardcode text ใน validation errors

**Translation Keys ที่ต้องเพิ่ม:**
```php
// lang/en.php
'products.error.unauthorized' => 'Unauthorized',
'products.error.no_org' => 'Cannot determine current organization',
'products.error.service_unavailable' => 'Service unavailable',
'products.error.sku_duplicate' => 'SKU already exists',
'products.success.created' => 'Product created successfully',
'products.success.updated' => 'Product updated successfully',

// lang/th.php
'products.error.unauthorized' => 'ไม่มีสิทธิ์',
'products.error.no_org' => 'ไม่สามารถระบุองค์กรปัจจุบันได้',
'products.error.service_unavailable' => 'บริการไม่พร้อมใช้งาน',
'products.error.sku_duplicate' => 'SKU ซ้ำกัน',
'products.success.created' => 'สร้างสินค้าสำเร็จ',
'products.success.updated' => 'อัปเดตสินค้าสำเร็จ',
```

---

#### 3. `mo.php` ❌

**สถานะ:** ❌ No i18n (ไม่มี `translate()` ใน error messages)

**ปัญหาที่พบ:**
- ❌ Hardcode text ใน error messages และ success messages
- ❌ Hardcode text ใน validation errors

---

#### 4. `trace_api.php` ❌

**สถานะ:** ❌ No i18n (ไม่มี `translate()` ใน error messages)

**ปัญหาที่พบ:**
- ❌ Hardcode text ใน error messages และ success messages

---

#### 5. `classic_api.php` ❌

**สถานะ:** ❌ No i18n (ไม่มี `translate()` ใน error messages)

**ปัญหาที่พบ:**
- ❌ Hardcode text ใน error messages และ success messages

---

#### 6. `dag_routing_api.php` ❌

**สถานะ:** ❌ No i18n (ไม่มี `translate()` ใน error messages)

**ปัญหาที่พบ:**
- ❌ Hardcode text ใน error messages (มีทั้งภาษาไทยและอังกฤษ)
- ❌ Hardcode: `'เริ่มต้น'`, `'วงวน'` (line 2757, 2761) - ภาษาไทยในโค้ด

**ตัวอย่าง:**
```php
// ❌ WRONG - Hardcode ภาษาไทยในโค้ด
if (mb_strpos($message, 'START') !== false || mb_strpos($message, 'เริ่มต้น') !== false) {
    // ...
} elseif (mb_strpos($message, 'cycle') !== false || mb_strpos($message, 'วงวน') !== false) {
    // ...
}
```

**คำแนะนำ:**
- ควรใช้ app_code แทนการตรวจสอบข้อความภาษาไทย
- หรือใช้ translate() เพื่อแปลงข้อความก่อนตรวจสอบ

---

#### 7. `dashboard_api.php` ❌

**สถานะ:** ❌ No i18n (ไม่มี `translate()` ใน error messages)

**ปัญหาที่พบ:**
- ❌ Hardcode text ใน error messages

---

#### 8. `team_api.php` ❌

**สถานะ:** ❌ No i18n (ไม่มี `translate()` ใน error messages)

**ปัญหาที่พบ:**
- ❌ Hardcode text ใน error messages และ success messages

---

#### 9. `people_api.php` ❌

**สถานะ:** ❌ No i18n (ไม่มี `translate()` ใน error messages)

**ปัญหาที่พบ:**
- ❌ Hardcode text ใน error messages และ success messages

---

#### 10. `pwa_scan_api.php` ❌

**สถานะ:** ❌ No i18n (ไม่มี `translate()` ใน error messages)

**ปัญหาที่พบ:**
- ❌ Hardcode text ใน error messages และ success messages

---

#### 11. `exceptions_api.php` ❌

**สถานะ:** ❌ No i18n (ไม่มี `translate()` ใน error messages)

**ปัญหาที่พบ:**
- ❌ Hardcode text ใน error messages

---

#### 12. `token_management_api.php` ❌

**สถานะ:** ❌ No i18n (ไม่มี `translate()` ใน error messages)

**ปัญหาที่พบ:**
- ❌ Hardcode text ใน error messages และ success messages

---

#### 13. `dag_token_api.php` ❌

**สถานะ:** ❌ No i18n (ไม่มี `translate()` ใน error messages)

**ปัญหาที่พบ:**
- ❌ Hardcode text ใน error messages และ success messages

---

#### 14. `hatthasilpa_jobs_api.php` ❌

**สถานะ:** ❌ No i18n (ไม่มี `translate()` ใน error messages)

**ปัญหาที่พบ:**
- ❌ Hardcode text ใน error messages และ success messages

---

#### 15. `assignment_plan_api.php` ❌

**สถานะ:** ❌ No i18n (ไม่มี `translate()` ใน error messages)

**ปัญหาที่พบ:**
- ❌ Hardcode text ใน error messages และ success messages

---

#### 16. Platform APIs (Platform Admin Only) ❌

**สถานะ:** ❌ No i18n (ไม่มี `translate()` ใน error messages)

**ไฟล์:**
- `platform_dashboard_api.php`
- `platform_migration_api.php`
- `platform_health_api.php`
- `platform_serial_salt_api.php`
- `platform_serial_metrics_api.php`
- `platform_roles_api.php`
- `platform_tenant_owners_api.php`
- `tenant_users_api.php`

**ปัญหาที่พบ:**
- ❌ Hardcode text ใน error messages และ success messages

---

#### 17. BGERP Service Files ❌

**สถานะ:** ❌ No i18n (Service files ส่วนใหญ่ไม่มี user-facing messages)

**ไฟล์ที่ต้องตรวจสอบ:**
- `BGERP/Service/OperatorDirectoryService.php` - ✅ มี translate() บางส่วน
- `BGERP/Service/ValidationService.php` - ❌ ไม่มี translate()
- `BGERP/Service/OperatorSessionService.php` - ❌ ไม่มี translate()
- `BGERP/Service/WorkEventService.php` - ❌ ไม่มี translate()
- และอื่นๆ อีก 30+ ไฟล์

**หมายเหตุ:** Service files ส่วนใหญ่ throw exceptions ที่มี app_code แต่ไม่มี translate() สำหรับ user-facing messages

---

### 📋 สรุปและคำแนะนำสำหรับ API Files

### ลำดับความสำคัญในการแก้ไข:

**Priority 1 (High):**
1. `assignment_api.php` - ใช้บ่อยมาก, มี hardcode "Permission denied - Managers only"
2. `purchase_rfq.php` - ใช้บ่อย, มี hardcode "Invalid action"
3. `hatthasilpa_job_ticket.php` - ใช้บ่อยมาก, มี hardcode มาก
4. `qc_rework.php` - ใช้บ่อย, มี hardcode บางส่วน

**Priority 2 (Medium):**
5. `products.php` - ใช้บ่อยมาก
6. `mo.php` - ใช้บ่อยมาก
7. `trace_api.php` - ใช้บ่อย
8. `classic_api.php` - ใช้บ่อย
9. `dag_routing_api.php` - ใช้บ่อย, มี hardcode ภาษาไทยในโค้ด

**Priority 3 (Low):**
10. `dashboard_api.php` - ใช้บ่อย
11. `team_api.php` - ใช้บ่อย
12. `people_api.php` - ใช้บ่อย
13. `pwa_scan_api.php` - ใช้บ่อย
14. Platform APIs - Platform admin only
15. BGERP Service Files - ส่วนใหญ่ไม่มี user-facing messages

### ขั้นตอนการแก้ไข API Files:

1. **เพิ่ม translate() ใน error messages:**
   ```php
   // Before (❌ WRONG):
   json_error('Permission denied - Managers only', 403, ['app_code' => 'ASSIGN_403_FORBIDDEN']);
   
   // After (✅ CORRECT):
   json_error(translate('assignment.error.forbidden_managers_only', 'Permission denied - Managers only'), 403, ['app_code' => 'ASSIGN_403_FORBIDDEN']);
   ```

2. **เพิ่ม translate() ใน success messages:**
   ```php
   // Before (❌ WRONG):
   json_success(['message' => 'Job ticket created successfully', 'data' => $data]);
   
   // After (✅ CORRECT):
   json_success(['message' => translate('hatthasilpa_job_ticket.success.created', 'Job ticket created successfully'), 'data' => $data]);
   ```

3. **เพิ่ม Translation Keys:**
   - เพิ่ม keys ใน `lang/en.php` (English default)
   - เพิ่ม keys ใน `lang/th.php` (Thai translation)

4. **ทดสอบ:**
   - เปลี่ยนภาษาและตรวจสอบว่า error/success messages เปลี่ยนถูกต้อง
   - ตรวจสอบว่าไม่มีข้อความตกหล่น

### ⚠️ **Critical Reminder สำหรับ API:**

**เมื่อแก้ไข API files:**
1. ✅ **ต้องใช้ภาษาอังกฤษเป็น default** ใน `translate()` function
2. ✅ **ห้าม hardcode ภาษาไทย** ในโค้ด
3. ✅ **ห้ามใช้ emoji/symbols** ในโค้ด (ใช้ใน translation files ได้)
4. ✅ **เก็บ app_code ไว้** (สำหรับ error handling และ logging)
5. ✅ **ใช้ translate() สำหรับ user-facing messages** (error messages, success messages)
6. ✅ **เพิ่ม translation keys** ในทั้ง `lang/en.php` และ `lang/th.php`
7. ✅ **ทดสอบการเปลี่ยนภาษา** ว่าทำงานถูกต้อง

### 📝 **Best Practices สำหรับ API Error Messages:**

```php
// ✅ GOOD - ใช้ translate() + app_code
json_error(
    translate('api.error.validation_failed', 'Validation failed'), 
    400, 
    ['app_code' => 'API_400_VALIDATION']
);

// ✅ GOOD - ใช้ translate() ใน success messages
json_success([
    'message' => translate('api.success.created', 'Created successfully'),
    'data' => $data
]);

// ❌ BAD - Hardcode text
json_error('Validation failed', 400, ['app_code' => 'API_400_VALIDATION']);

// ❌ BAD - Hardcode ภาษาไทย
json_error('การตรวจสอบข้อมูลล้มเหลว', 400, ['app_code' => 'API_400_VALIDATION']);
```

---

## 📊 สถิติ

### Views Files:
- **Total Views:** 53 files
- **Complete i18n:** 37 files (70%)
- **Partial i18n:** 8 files (15%)
- **No i18n:** 3 files (6%)
- **Special cases:** 5 files (9%)

### JavaScript Files:
- **Total JS Files:** 63 files
- **Complete i18n:** 45 files (71%)
- **Partial i18n:** 5 files (8%)
- **No i18n:** 8 files (13%)
- **Vendor/Library:** 5 files (8%)

### API Files:
- **Total API Files:** 64 files
- **Complete i18n:** 5 files (8%)
- **Partial i18n:** 3 files (5%)
- **No i18n:** 56 files (87%)

### Service Files:
- **Total Service Files:** 36 files
- **Complete i18n:** 1 file (3%)
- **Partial i18n:** 0 files (0%)
- **No i18n:** 35 files (97%)

---

**เอกสารนี้สร้างเมื่อ:** 15 พฤศจิกายน 2025  
**อัปเดตล่าสุด:** 15 พฤศจิกายน 2025  
**สถานะ:** ✅ Audit Complete - Ready for Implementation


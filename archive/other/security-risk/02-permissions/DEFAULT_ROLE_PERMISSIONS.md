# Default Role Permissions Reference

> **สร้างเมื่อ:** 27 ตุลาคม 2025  
> **สถานะ:** Production Ready ✅

---

## 📋 ภาพรวม

เอกสารนี้แสดงรายการ **Default Permissions** สำหรับแต่ละ Role ในระบบ  
Permissions เหล่านี้จะถูก **seed ครั้งเดียว** เมื่อสร้าง tenant ใหม่

### หลักการ:
- ✅ **Seed ครั้งเดียว** - เมื่อ provision tenant ใหม่เท่านั้น
- ✅ **Admin มีอิสระ** - แก้ไข permissions ได้เต็มที่หลังจากนั้น
- ✅ **ไม่มี Auto-Reset** - ไม่มีระบบ sync ที่จะ override การแก้ไขของ admin
- ✅ **Reference สำหรับ Reset** - ใช้เป็นมาตรฐานเมื่อต้องการ reset role กลับสู่ค่าเริ่มต้น

---

## 🎯 Default Permissions แต่ละ Role

### 1. **Owner** (89 permissions)
**คำอธิบาย:** เจ้าขององค์กร - สิทธิ์เต็ม

**Permissions:** ทุกอย่างในระบบ (ALL)

---

### 2. **Admin** (48 permissions)
**คำอธิบาย:** ผู้ดูแลระบบองค์กร

**หมวดหมู่:**
- **Core:** session.login, dashboard.view, reports.view
- **Administration:** admin.role.manage, admin.settings.manage, admin.user.manage, org.*
- **Master Data:** products.*, materials.*, product_categories.*, uom.*
- **Manufacturing:** mo.*, bom.*, routing.*, work_centers.*, workcenter.*
- **Inventory:** warehouses.*, locations.*, stock_on_hand.view, stock_card.view, inventory.view
- **Transactions:** grn.*, issue.*, transfer.*, adjust.*
- **QC:** qc.fail.view
- **System:** system.log.view

**Total:** 48 permissions

---

### 3. **Production Manager** (32 permissions)
**คำอธิบาย:** ผู้จัดการฝ่ายผลิต

**หมวดหมู่:**
- **Core:** session.login, dashboard.view, reports.view
- **MO:** mo.create, mo.view, mo.plan, mo.start_stop, mo.complete, mo.cancel
- **Schedule:** schedule.* (view, edit, auto_arrange, config)
- **Planning:** bom.*, routing.*, work_centers.*, workcenter.*
- **Atelier:** atelier.job.ticket, atelier.dashboard.view, atelier.job.wip.scan
- **QC:** qc.inspect, qc.fail.*, qc.rework.manage, qc.spec.view
- **Reference:** materials.view, products.view, stock_on_hand.view, stock_card.view

**Total:** 32 permissions

---

### 4. **Planner** (16 permissions)
**คำอธิบาย:** ผู้วางแผนการผลิต

**หมวดหมู่:**
- **Core:** session.login, dashboard.view, reports.view
- **Planning:** mo.view, mo.plan, mo.create
- **Schedule:** schedule.* (view, edit, auto_arrange, config)
- **Reference:** bom.view, routing.view, work_centers.view, workcenter.view, products.view, materials.view, stock_on_hand.view

**Total:** 16 permissions

---

### 5. **Production Operator** (8 permissions)
**คำอธิบาย:** พนักงานฝ่ายผลิต / ช่าง

**หมวดหมู่:**
- **Core:** session.login, dashboard.view
- **Work:** mo.view, mo.start_stop, atelier.job.ticket, atelier.job.wip.scan
- **QC:** qc.inspect, atelier.qc.checklist

**Total:** 8 permissions

---

### 6. **Quality Manager** (14 permissions)
**คำอธิบาย:** ผู้จัดการฝ่ายควบคุมคุณภาพ

**หมวดหมู่:**
- **Core:** session.login, dashboard.view, reports.view
- **QC:** qc.inspect, qc.fail.*, qc.rework.manage, qc.rework_scrap, qc.spec.*, atelier.qc.checklist
- **Reference:** mo.view, atelier.job.ticket, products.view

**Total:** 14 permissions

---

### 7. **QC Lead** (9 permissions)
**คำอธิบาย:** หัวหน้า QC / ผู้ตรวจสอบคุณภาพ

**หมวดหมู่:**
- **Core:** session.login, dashboard.view
- **QC:** qc.inspect, qc.fail.*, qc.spec.view, atelier.qc.checklist
- **Reference:** mo.view, products.view

**Total:** 9 permissions

---

### 8. **Inventory Manager** (27 permissions)
**คำอธิบาย:** ผู้จัดการสินค้าคงคลัง

**หมวดหมู่:**
- **Core:** session.login, dashboard.view, reports.view
- **Inventory:** inventory.* (view, adjust, cyclecount, issue, receive, transfer)
- **Stock:** stock_on_hand.view, stock_card.view
- **Warehouse:** warehouses.*, locations.*, warehouse.location.manage
- **Transactions:** grn.*, issue.*, transfer.*, adjust.*
- **Reference:** materials.view, products.view

**Total:** 27 permissions

---

### 9. **Warehouse Manager** (23 permissions)
**คำอธิบาย:** ผู้จัดการคลังสินค้า

**หมวดหมู่:**
- **Core:** session.login, dashboard.view, reports.view
- **Warehouse:** warehouses.*, locations.*, warehouse.* (location.manage, label_print)
- **Transactions:** grn.*, issue.*, transfer.*, adjust.*
- **Stock:** inventory.view, stock_on_hand.view, stock_card.view
- **Reference:** materials.view, products.view

**Total:** 23 permissions

---

### 10. **Warehouse (Staff)** (10 permissions)
**คำอธิบาย:** พนักงานคลัง / ผู้ปฏิบัติงาน

**หมวดหมู่:**
- **Core:** session.login, dashboard.view
- **Operations:** grn.receive, issue.view, transfer.view, adjust.view
- **Reference:** stock_on_hand.view, locations.view, warehouses.view, materials.view

**Total:** 10 permissions

---

### 11. **Sales Manager** (10 permissions)
**คำอธิบาย:** ผู้จัดการฝ่ายขาย

**หมวดหมู่:**
- **Core:** session.login, dashboard.view, reports.view
- **Sales:** so.create, so.approve, delivery.create, sales.price.manage
- **Reference:** products.view, product_categories.view, stock_on_hand.view

**Total:** 10 permissions

---

### 12. **Sales** (6 permissions)
**คำอธิบาย:** พนักงานขาย

**หมวดหมู่:**
- **Core:** session.login, dashboard.view
- **Sales:** so.create, delivery.create
- **Reference:** products.view, stock_on_hand.view

**Total:** 6 permissions

---

### 13. **Sales (Bellavier)** (7 permissions)
**คำอธิบาย:** พนักงานขาย - แบรนด์ Bellavier

**Permissions:** เหมือน Sales + brand.scope.bv

**Total:** 7 permissions

---

### 14. **Sales (OEM)** (7 permissions)
**คำอธิบาย:** พนักงานขาย - OEM

**Permissions:** เหมือน Sales + brand.scope.oem

**Total:** 7 permissions

---

### 15. **Purchaser** (11 permissions)
**คำอธิบาย:** เจ้าหน้าที่จัดซื้อ

**หมวดหมู่:**
- **Core:** session.login, dashboard.view, reports.view
- **Purchasing:** pr.*, po.*, atelier.purchase.rfq
- **Materials:** materials.view, atelier.material.lot
- **Reference:** stock_on_hand.view

**Total:** 11 permissions

---

### 16. **Finance** (7 permissions)
**คำอธิบาย:** ผู้จัดการการเงิน

**หมวดหมู่:**
- **Core:** session.login, dashboard.view, reports.view
- **Costing:** costing.view, costing.post
- **Reference:** products.view, materials.view

**Total:** 7 permissions

---

### 17. **Cost Accountant** (5 permissions)
**คำอธิบาย:** นักบัญชีต้นทุน

**หมวดหมู่:**
- **Core:** session.login, dashboard.view, reports.view
- **Costing:** costing.view, costing.post

**Total:** 5 permissions

---

### 18. **Finance Clerk** (4 permissions)
**คำอธิบาย:** เจ้าหน้าที่การเงิน

**หมวดหมู่:**
- **Core:** session.login, dashboard.view, reports.view
- **Costing:** costing.view (read-only)

**Total:** 4 permissions

---

### 19. **Operations** (9 permissions)
**คำอธิบาย:** เจ้าหน้าที่ปฏิบัติการ

**หมวดหมู่:**
- **Core:** session.login, dashboard.view
- **View Only:** mo.view, bom.view, routing.view, work_centers.view, workcenter.view, inventory.view, stock_on_hand.view

**Total:** 9 permissions

---

### 20. **Artisan Operator** (6 permissions)
**คำอธิบาย:** ช่างฝีมือ / Craftsman

**หมวดหมู่:**
- **Core:** session.login, dashboard.view
- **Atelier:** atelier.job.ticket, atelier.job.wip.scan, atelier.qc.checklist
- **Reference:** mo.view

**Total:** 6 permissions

---

### 21. **Auditor** (26 permissions)
**คำอธิบาย:** ผู้ตรวจสอบภายใน

**หมวดหมู่:**
- **Core:** session.login, dashboard.view, reports.view, system.log.view
- **View All:** *.view permissions ทุกอย่าง (products, materials, mo, bom, routing, inventory, stock, warehouse, locations, grn, issue, transfer, adjust, qc, uom, costing, atelier)

**Total:** 26 permissions

---

### 22. **Auditor (Read-Only)** (25 permissions)
**คำอธิบาย:** ผู้ตรวจสอบภายนอก - อ่านอย่างเดียว

**Permissions:** เหมือน Auditor (ไม่มี system.log.view)

**Total:** 25 permissions

---

### 23. **Viewer** (3 permissions)
**คำอธิบาย:** ผู้ดู - อ่านอย่างเดียว

**หมวดหมู่:**
- **Core:** session.login, dashboard.view, reports.view

**Total:** 3 permissions

---

## 🔧 วิธีการใช้งาน

### สร้าง Tenant ใหม่:
```bash
# ระบบจะ seed permissions อัตโนมัติ
php tools/provision_tenant.php NEW_TENANT_CODE
```

### Reset Role กลับค่าเริ่มต้น:
1. เปิดไฟล์ `database/seed_default_permissions.php`
2. ดู permissions ของ role ที่ต้องการ
3. ใช้หน้า Admin → Roles & Permissions เพื่อ manual assign ตามนั้น

### แก้ไข Default (ถาวร):
1. แก้ไขไฟล์ `database/seed_default_permissions.php`
2. รัน `php tools/update_role_templates.php` (ถ้ามี) เพื่ออัพเดท templates
3. Tenant ใหม่จะได้ defaults ที่อัพเดตแล้ว
4. Tenant เก่าไม่เปลี่ยนแปลง (ต้อง manual update)

---

## 📊 สถิติ

| Category | Count | Details |
|----------|-------|---------|
| Total Roles | 23 | ครอบคลุมทุกหน้าที่ |
| Total Permissions | 89 | ครอบคลุมทุก module |
| Roles with Login | 23/23 | 100% ✅ |
| Roles with Dashboard | 23/23 | 100% ✅ |
| Min Permissions | 3 | Viewer |
| Max Permissions | 89 | Owner |
| Avg Permissions | ~15 | ตามหน้าที่ของแต่ละ role |

---

## ⚠️ ข้อควรระวัง

1. **ห้าม run sync scripts** - จะ override การแก้ไขของ admin
2. **Backup ก่อน reset** - ถ่ายภาพ permissions ปัจจุบันก่อน reset
3. **Test ใน staging** - ทดสอบ permissions ใน tenant ทดสอบก่อน
4. **Document changes** - บันทึกการแก้ไข permissions ที่สำคัญ

---

## 🔗 เอกสารที่เกี่ยวข้อง

- [Permission Management Guide](PERMISSION_MANAGEMENT_GUIDE.md)
- [Platform Admin Guide](PLATFORM_ADMIN_FULL_ACCESS.md)
- [Troubleshooting Guide](TROUBLESHOOTING_GUIDE.md)

---

**Last Updated:** 27 October 2025


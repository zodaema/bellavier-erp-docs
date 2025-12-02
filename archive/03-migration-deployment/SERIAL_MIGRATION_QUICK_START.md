# ⚡ Quick Start: Apply Serial System Migration via UI

**เวลา:** 5-10 นาที  
**สำหรับ:** Platform Super Admins  
**Target:** `2025_11_serial_system_integration.php` → ทั้งสอง tenants

---

## 🎯 ขั้นตอนสั้นๆ

### **1. เข้าสู่ระบบ**
- Login ด้วย Platform Super Admin account

### **2. เปิด Migration Wizard**
- Sidebar → **Platform Console** → **Migration Wizard**
- หรือ URL: `index.php?p=platform_migration_wizard`

### **3. เลือก Migration File**
- คลิก **`2025_11_serial_system_integration.php`**
- คลิก **"ยืนยันและไปขั้นตอนถัดไป"**

### **4. เลือก Tenants**
- ✅ ติ๊ก `maison_atelier`
- ✅ ติ๊ก `default`
- คลิก **"Next: Test Migration"**

### **5. Test Migration**
- คลิก **"Test Migration"**
- รอผลลัพธ์ (10-30 วินาที)
- ✅ ตรวจสอบว่าไม่มี errors

### **6. Deploy Migration**
- คลิก **"Deploy Migration"**
- ยืนยัน: **"Yes, Deploy"**
- รอผลลัพธ์ (10-30 วินาที)

### **7. ตรวจสอบผลลัพธ์**
- ✅ Deployment Results แสดง: Success 2/2
- ✅ Logs แสดง: Tables created, Indexes added

---

## ✅ Success Criteria

- ✅ Test Migration: Success (no errors)
- ✅ Deploy Migration: Success 2/2 tenants
- ✅ Tables created: `serial_link_outbox`, `token_spawn_log`, `serial_quarantine`
- ✅ Indexes added: `uniq_ticket_seq`, `idx_ticket_unspawned`

---

## 📚 ดูรายละเอียด

อ่าน `SERIAL_MIGRATION_VIA_UI.md` สำหรับคำแนะนำแบบละเอียด

---

**Status:** ✅ **Ready to Execute**  
**Last Updated:** November 9, 2025


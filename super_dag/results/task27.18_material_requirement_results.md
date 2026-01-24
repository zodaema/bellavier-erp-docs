# Task 27.18 - Material Requirement & Reservation Results

> **Status:** ✅ BACKEND COMPLETE  
> **Completed:** 2025-12-06  
> **Developer:** AI Assistant

---

## 📋 Summary

สร้างระบบ Material Requirement & Reservation สำหรับคำนวณความต้องการวัสดุจาก BOM และจัดการ Stock Reservations

---

## ✅ Completed Items

### 1. Migration (4 Tables)
- `material_requirement` - ความต้องการวัสดุต่อ Job
- `material_reservation` - การจองวัสดุ (soft-lock)
- `material_allocation` - การจัดสรรวัสดุให้ Token
- `material_requirement_log` - Audit trail

**File:** `database/tenant_migrations/2025_12_material_requirement.php`

### 2. Services (3 Services)

#### MaterialRequirementService
- `calculateRequirements()` - คำนวณวัสดุจาก BOM × target_qty
- `getRequirements()` - ดึงรายการวัสดุที่ต้องการ
- `checkAvailability()` - ตรวจสอบ stock พร้อมใช้งาน
- `recalculateRequirements()` - คำนวณใหม่เมื่อ target เปลี่ยน
- `getJobMaterialSummary()` - สรุปสถานะวัสดุต่อ Job

**File:** `source/BGERP/Service/MaterialRequirementService.php`

#### MaterialReservationService
- `createReservations()` - จองวัสดุตาม FIFO
- `releaseReservationsForJob()` - ปล่อยการจอง
- `expireOldReservations()` - หมดอายุอัตโนมัติ
- `getReservationsForJob()` - ดึงรายการจอง

**File:** `source/BGERP/Service/MaterialReservationService.php`

#### MaterialAllocationService
- `allocateToToken()` - จัดสรรวัสดุให้ Token
- `consumeMaterials()` - ใช้วัสดุเมื่อ Token เสร็จ
- `returnMaterials()` - คืนวัสดุ (rework/cancel)
- `recordWaste()` - บันทึก waste/scrap

**File:** `source/BGERP/Service/MaterialAllocationService.php`

### 3. API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `calculate_requirements` | POST | คำนวณความต้องการวัสดุ |
| `get_requirements` | GET | ดึงรายการวัสดุ |
| `recalculate_requirements` | POST | คำนวณใหม่ |
| `check_availability` | GET | ตรวจสอบ stock |
| `create_reservations` | POST | จองวัสดุ |
| `release_reservations` | POST | ปล่อยการจอง |
| `get_reservations` | GET | ดูรายการจอง |
| `get_job_material_summary` | GET | สรุปสถานะ |

**File:** `source/material_requirement_api.php`

---

## 📊 Material Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     MATERIAL FLOW                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. JOB CREATED                                             │
│     ├─ calculateRequirements()                              │
│     └─ Insert into material_requirement                     │
│                                                             │
│  2. AVAILABILITY CHECK                                      │
│     ├─ checkAvailability()                                  │
│     ├─ Compare stock vs required                            │
│     └─ Mark shortages                                       │
│                                                             │
│  3. RESERVATION (Soft-lock)                                 │
│     ├─ createReservations()                                 │
│     ├─ FIFO from material_lot                               │
│     └─ Insert into material_reservation                     │
│                                                             │
│  4. ALLOCATION (Hard-link to Token)                         │
│     ├─ allocateToToken()                                    │
│     ├─ Convert reservations → allocations                   │
│     └─ Insert into material_allocation                      │
│                                                             │
│  5. CONSUMPTION (Token Completed)                           │
│     ├─ consumeMaterials()                                   │
│     └─ Deduct from material_lot                             │
│                                                             │
│  6. RETURN/WASTE (If needed)                                │
│     ├─ returnMaterials()                                    │
│     └─ recordWaste()                                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔗 Integration Points

1. **Job Creation** → Auto-calculate requirements
2. **Job Start** → Create reservations
3. **Token Start** → Allocate materials
4. **Token Complete** → Consume materials
5. **Job Cancel** → Release reservations
6. **Rework** → Return and re-allocate

---

## 🚀 Future UI Work (Phase 2)

- Job detail page: Material requirements panel
- Material shortage warnings in job list
- Reservation expiry notifications
- Material consumption dashboard

---

## 📁 Files Created

| File | Purpose |
|------|---------|
| `database/tenant_migrations/2025_12_material_requirement.php` | Migration |
| `source/BGERP/Service/MaterialRequirementService.php` | Calculation service |
| `source/BGERP/Service/MaterialReservationService.php` | Reservation service |
| `source/BGERP/Service/MaterialAllocationService.php` | Allocation service |
| `source/material_requirement_api.php` | API endpoints |

---

## ✅ Verification

```bash
# Migration ran successfully
✓ material_requirement table created
✓ material_reservation table created
✓ material_allocation table created
✓ material_requirement_log table created

# PHP syntax check
✓ MaterialRequirementService.php - No errors
✓ MaterialReservationService.php - No errors
✓ MaterialAllocationService.php - No errors
✓ material_requirement_api.php - No errors
```

---

## 📝 Notes

- UI สำหรับแสดง Material Requirements ใน Job detail page จะทำในระยะถัดไป
- ระบบรองรับการจองแบบ FIFO จาก lots
- Reservation มี expiration (default 72 hours)
- ทุก action มี audit log ใน material_requirement_log


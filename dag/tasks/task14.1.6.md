

# Task 14.1.6 — Wave B Cleanup (Target: Remove Remaining Legacy References)

## Objective
Wave B มุ่งเน้นการลบ legacy references ระดับกลาง (Medium–High Risk) ที่ยังคงหลงเหลืออยู่ก่อนที่จะเข้าสู่ Task 14.2 (Master Schema V2).  
ทุกการแก้ไขเป็นแบบ **safe**, **incremental**, และ **backward compatible** — ไม่แตะ WRITE operations และไม่ลบ schema ใดๆ

---

## Scope

### 1. Files to Migrate (Medium–High Risk)
| File | Action | Notes |
|------|--------|-------|
| `bom.php` | Remove stock_item references (READ) | คงผลลัพธ์ JSON เหมือนเดิม |
| `BOMService.php` | Remove `stock_item` joins (READ) | ใช้ `material` table 100% |
| `component.php` | Remove legacy `stock_item` lookups | Must verify before migration |
| `ComponentAllocationService.php` | Remove V1 material mapping | READ-only migration |

---

## Out of Scope
- No schema deletion (e.g., stock_item, bom_line)
- No write migration
- No changes to routing, time engine, or session engine
- No ComponentBinding enforcement changes
- No UI refactor

---

## Migration Strategy

### 1. Material Adapter (Migration Guard)
ทุกไฟล์ที่ migrate ต้องใช้:
- Prefer-V2
- Fallback-V1 (minimal)
- Null-safe fields
- Consistent JSON shape

### 2. BOM Adapter
สร้าง mini adapter สำหรับ:
- id_material → id_stock_item translation (if required)
- backward-compatible columns:
  - `description`
  - `material_type`
  - `unit`
  - `color`

### 3. Verification
หลัง migrate:
- Syntax check
- Cross-file diff vs baselines
- Simulated API output comparison (before/after)

---

## Deliverables

### 1. Code Migration
- Updated `bom.php`
- Updated `BOMService.php`
- Updated `component.php`
- Updated `ComponentAllocationService.php`

### 2. Documentation
- `task14.1.6_results.md` — summary
- Updated `task14.2_scan_error_report.md` — residue verification

---

## Expected Outcome
หลังจบ Task 14.1.6:
- Legacy references ลดลง ~60–70%
- V2 material pipeline stable 100%
- BOM pipeline stable 100%
- Component pipeline ready สำหรับ enforcement phase
- ระบบพร้อมเข้าสู่ Task 14.2 (Master Schema V2 Cleanup)

---

### Hard Constraints (ห้ามแตะเด็ดขาดใน Task 14.1.6)

ใน Task นี้ **ห้าม** แก้ไขสิ่งต่อไปนี้:

1. **WRITE Operations ทั้งหมด**
   - INSERT / UPDATE / DELETE / REPLACE
   - โดยเฉพาะในไฟล์:
     - `bom.php` (action บันทึก / อัปเดต BOM)
     - `component.php` (action เพิ่ม/แก้ไข component master)
     - `ComponentAllocationService.php` (allocation logic ใดๆ)

2. **Schema / Migration เดิม**
   - ห้ามสร้าง migration ใหม่
   - ห้ามลบ column / table ใดๆ (เช่น `stock_item`, `bom_line`)

3. **Business Logic หลัก**
   - ห้ามเปลี่ยน logic ใน:
     - ComponentBinding*
     - ComponentSerial*
     - Stock movement / Warehouse allocation
     - Time Engine / Session Engine
   - งานนี้คือ “อ่าน material จาก V2 ให้มากที่สุด” เท่านั้น

> ถ้า Agent รู้สึกว่าจำเป็นต้องแก้ WRITE logic หรือ schema ให้ **หยุด** และเขียน note เพิ่มใน `task14.2_scan_error_report.md` แทน

---

## Per-file Checklist (ต้องทำ / ต้องไม่ทำ)

### A. `bom.php`
**ต้องทำ**
- ค้นทุกจุดที่ JOIN `stock_item`
- เปลี่ยนให้ใช้ `material` table / MaterialResolver แทน
- คง **shape ของ JSON เดิม**:
  - column เดิมเช่น `id_stock_item`, `description`, `material_type` ยังต้องมี (ถ้าไม่มี ให้ map จาก `material` หรือคืนค่าเป็น `null`)

**ห้ามทำ**
- ห้ามแตะ action ที่เป็น WRITE (add/update/delete BOM)
- ห้ามเปลี่ยนชื่อ action, parameter, หรือ response root key

---

### B. `BOMService.php`
**ต้องทำ**
- ลบ/แก้ JOIN ที่ใช้ `stock_item` → ใช้ `material` 100%
- ถ้า service คืน object/array ให้คง key เดิมทั้งหมด

**ห้ามทำ**
- ห้ามเปลี่ยน signature ของ public method
- ห้ามเปลี่ยน exception type หรือ error code

---

### C. `component.php`
**ต้องทำ**
- ตรวจทุก action ว่ามีการ lookup `stock_item` หรือไม่
- ถ้ามี → เปลี่ยนไปใช้ `material` หรือ adapter
- รักษา API contract เดิมของแต่ละ action (ชื่อ, input, output)

**ห้ามทำ**
- ห้ามเพิ่ม/ลบ action ใหม่ในไฟล์นี้
- ห้ามเปลี่ยน permission checks เดิม

---

### D. `ComponentAllocationService.php`
**ต้องทำ**
- เปลี่ยน logic ที่ map `id_stock_item` → material ให้ใช้ V2 material
- ถ้าไม่มั่นใจว่า logic ปัจจุบันยังใช้งานอยู่ ให้ log note เพิ่มใน `task14.2_scan_error_report.md`

**ห้ามทำ**
- ห้ามเปลี่ยน behavior หลักของ allocation (จอง / ปล่อย / คำนวณจำนวน)
- ห้ามเปลี่ยน public API (method ชื่อเดิม, parameter เดิม)

---

## Verification Steps (สำหรับ AI Agent + มนุษย์)

หลัง migrate เสร็จ **ต้อง** ทำอย่างน้อย:

1. **PHP Syntax**
   - รัน `php -l` กับไฟล์ที่ถูกแก้ทั้งหมด:
     - `bom.php`
     - `BOMService.php`
     - `component.php`
     - `ComponentAllocationService.php`

2. **API Smoke Test (ถ่าย log ก่อน/หลัง ถ้าเป็นไปได้)**
   - เรียก `bom.php?action=list` ด้วยเงื่อนไขเดิมที่เคยใช้
   - เรียก API ใดๆ ที่ใช้ `BOMService` (ถ้ามี route ตรง)
   - เรียก `component.php?action=component_list` (หรือชื่อ action เดิมในระบบ)
   - ถ้ามี endpoint ที่ใช้ `ComponentAllocationService` ให้เรียกด้วย

3. **Compare JSON Shape**
   - ยืนยันว่า keys หลักๆ ยังอยู่เหมือนเดิม:
     - `id_stock_item` (อาจเป็น null แต่ key ต้องมีถ้ามีอยู่ก่อน)
     - `material_type`, `description`, `unit`, `color` เป็นต้น
   - ถ้า value ต่างได้ (เพราะเปลี่ยน source) ให้บันทึกไว้ใน `task14.1.6_results.md` ว่า “expected drift”

4. **Update Scan Report**
   - รัน search หา `stock_item` อีกครั้งในทั้ง project
   - อัปเดต `task14.2_scan_error_report.md` ว่าเหลือ legacy references ที่ใดบ้าง (หรือ 0 ถ้าหมดแล้ว)
   
---

## Notes
Task 14.1.6 จะเป็น Wave สุดท้ายของ “Code Cleanup ก่อนลบ Legacy Schema”.  
เมื่อเสร็จแล้ว สามารถเข้าสู่ Task 14.2 ได้อย่างปลอดภัยโดยไม่เสี่ยงพังระบบหลัก.
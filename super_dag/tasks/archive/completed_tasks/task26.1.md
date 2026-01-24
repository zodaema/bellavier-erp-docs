

# Task 26.1 — Product Core Cleanup & Consolidation  
**Status:** Planned  
**Owner:** AI Agent (Cursor)  
**Reviewer:** Core ERP Architect  

---

## 🎯 เป้าหมายของ Task 26.1

ทำการ “จัดระเบียบใหม่” (Consolidation) ของระบบสินค้า (Product Module) ให้พร้อมใช้งานจริงสำหรับ MO, Job Ticket และ Inventory โดยเน้น **ความถูกต้อง**, **ความเป็นระบบ**, **ไม่มี Legacy code**, และสอดคล้องกับ **Production Line Model (Classic / Hatthasilpa)** ที่เพิ่งรีเฟรชใน Task 25.7

---

## 🔧 ขอบเขตงาน (Scope)

### 1. Product Core Fields Cleanup
- ตรวจสอบและจัดเรียงฟิลด์ที่จำเป็นต่อการใช้งานจริง:
  - `name`
  - `description`
  - `sku`
  - `price` (if applicable)
  - `production_line` (classic / hatthasilpa)
  - `is_draft`
- ลบหรือซ่อนฟิลด์ legacy ที่ไม่ใช้แล้ว เช่น:
  - pattern versioning
  - default_mode
  - oem/atelier flags
  - legacy production_lines array
- ปรับ UI ให้ clean และ professional

---

### 2. Product Editing & Validation Rules (New Standard)
เพิ่มกติกาให้แข็งแรง:
- ชื่อสินค้า: required  
- SKU: required, unique (per tenant)  
- Production Line:
  - สามารถเลือก ≤ 1 ค่า (ราคาถูกบังคับเพียงหนึ่ง ไม่ใช่ multi-select)  
  - หากเปลี่ยน line → ต้องมี warning / confirm  
- Draft Mode:
  - หาก `is_draft = 1` → ซ่อนจาก MO/Job Ticket  
  - หาก duplicate → default เป็น draft  
- i18n: ใช้ `translate()` ทุกข้อความ

---

### 3. Product Assets Consolidation  
ทำให้ระบบ assets เป็นระเบียบ:
- Product Images (main + gallery)
- Material specifications (optional)
- Pattern files (เฉพาะ Hatthasilpa)

**ปรับปรุง UI:**
- แยกเป็น sections ชัดเจน  
- API upload ควรเข้าทาง endpoint เดียว (product_api.php)

---

### 4. Remove Pattern Version Model (Legacy)
สิ่งที่ต้องลบ:
- UI elements (dropdown / buttons / indicators)
- PHP fallback ที่ยังเหลืออยู่
- JS handlers ที่ยัง reference versioning

เป้าหมาย:  
**Product = หนึ่ง Pattern (สำหรับ Hatthasilpa)**  
ถ้าต้องการเวอร์ชันใหม่ → Duplicate → Edit → Publish

---

### 5. Product Duplicate 2.0  
ขยาย duplicate ให้สมบูรณ์ขึ้น:
- Duplicate:
  - core fields
  - images
  - pattern files
  - routing binding (เฉพาะ Hatthasilpa)
- ตั้งค่าสถานะเป็น draft  
- เปิด edit modal ทันที  
- ปรับ wording ให้ professional และใช้ i18n

---

### 6. Product Metadata API — Expansion  
ปรับ `product_api.php`:
- เพิ่ม endpoint:
  - `get_full` → metadata ครบชุด
  - `duplicate`
  - `update_core_fields`
  - `upload_asset`
- เพิ่ม error model (ตามมาตรฐาน ERP)

---

### 7. UI Refactor (products.php + JS)
- ปรับ UI ให้ clean:
  - 2 แท็บ:
    - Product Info
    - Production (Classic / Hatthasilpa)
  - แสดง tab Graph Binding เฉพาะ Hatthasilpa
  - Classic → แสดง Classic Dashboard เท่านั้น
- แก้ wording:
  - OEM → Classic
  - Atelier → Hatthasilpa
- ใช้ CSS standards ใหม่ตาม Enterprise Style Guide  
- แก้ปัญหา modal ติดค่าเดิมหลังปิด

---

## 📦 ผลลัพธ์ที่ต้องได้เมื่อทำ Task เสร็จ

1. Product Module พร้อมใช้งานระดับ production  
2. UI สะอาด professional ตามมาตรฐาน Bellavier Group  
3. ไม่มี legacy code / fields / UI elements  
4. Duplicate ทำงานครบ ทั้ง assets และ metadata  
5. Product พร้อมเชื่อมต่อกับ MO และ Inventory (Task 26.2 / Task 27)

---

## 📘 เอกสารที่ต้องอัปเดต
- `task_index.md`
- `Product Module Architecture.md`
- `Enterprise Frontend Standards.md`
- `API Governance — product_api.md`

---

## 🧩 Notes สำหรับ Cursor
- ทุกข้อความ UI → ต้องใช้ `translate()`  
- Default language → English  
- ห้ามใส่ emoji ในโค้ดจริง  
- Comments ต้องเป็นระดับ enterprise  
- JS: ใช้มาตรฐาน Error/Response Model ใหม่  
- PHP: ห้าม shortcut syntax แบบ echo short tag  

---

**พร้อมสำหรับ Task 26.1 ให้ Cursor รันเลยครับ**
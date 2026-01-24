# Task 26.3 — Product Module Phase 3: Publish Lifecycle + Metadata Panel Revamp  
**Status:** TODO  
**Owner:** AI Agent (Cursor)  

**Guardrails (MUST READ BEFORE CODING)**  
ใช้มาตรฐานเดียวกับทั้งโปรเจกต์:

- docs/developer/01-policy/DEVELOPER_POLICY.md  
- docs/developer/02-quick-start/AI_QUICK_START.md  
- docs/developer/02-quick-start/GLOBAL_HELPERS.md  
- docs/developer/02-quick-start/QUICK_START.md  

> Cursor ห้ามเขียนโค้ดแบบ freestyle เอง ต้องยึดตาม Policy + Helper ที่กำหนดไว้เสมอ  
> ถ้าจะถามว่าอะไรคือ “มาตรฐาน Bellavier Group” ให้ถือว่าอยู่ในไฟล์ด้านบนทั้งหมด  

---

## 0. Background & Scope

ตอนนี้ Product Module มี `production_line` (classic / hatthasilpa) และเริ่มมี dashboard + graph binding แล้ว  
แต่ **ยังไม่มี “วงจรชีวิตการเผยแพร่สินค้า (Publish Lifecycle)”** ที่ชัดเจน:

- ยังไม่มีสถานะ Draft / Published  
- Product ที่ยังไม่พร้อมใช้งาน อาจถูกเลือกไปใช้ใน MO / Job Ticket / Hatthasilpa Jobs ได้  
- Metadata Panel ยังแสดงข้อมูลไม่ชัดเจนว่า product นี้ “พร้อมใช้ในระบบจริงแล้วหรือยัง”

จุดมุ่งหมายของ Task 26.3:

1. เพิ่มระบบ **Draft / Published** ให้ Product  
2. ทำให้คนในโรงงานแยกออกชัดเจนว่า “อันไหนใช้จริง / อันไหนแค่แบบร่าง”  
3. ป้องกันไม่ให้ Product ที่เป็น Draft หลุดไปใช้ใน MO / Job Ticket / Hatthasilpa Jobs  
4. ปรับ Metadata Panel ให้เหมาะกับ Phase ปัจจุบัน (Classic + Hatthasilpa coexist)  

---

## 1. 🎯 Objectives

### 1.1 Publish Lifecycle for Products

- เพิ่ม flag ใน DB:
  - `product.is_published TINYINT(1) DEFAULT 0`  
- กำหนด semantics:
  - `is_published = 0` → Draft  
  - `is_published = 1` → Published  
- เพิ่มปุ่มบนหน้า Product:
  - `Publish Product` → Draft → Published  
  - `Unpublish (Back to Draft)` → Published → Draft  
- ป้องกันการใช้งาน Product ที่ไม่ Published ใน:
  - MO Creation (classic line)  
  - Job Ticket Creation (classic line)  
  - Hatthasilpa Jobs Creation  
  - Graph Binding (Hatthasilpa binding UI / API)  

> หลักคิด: Product ใดที่จะถูกใช้ในการผลิตจริง ต้องเป็น Published เท่านั้น  

---

### 1.2 Product Status Badge

- แสดงสถานะใน Product List และใน Product Detail Modal:

  - Draft:
    - Badge สีเหลือง (เช่น `badge bg-warning-subtle text-warning-emphasis` หรือเทียบเท่า)
    - Text: `"Draft"`
  - Published:
    - Badge สีเขียว (เช่น `badge bg-success-subtle text-success-emphasis`)
    - Text: `"Published"`

- ค่า default สำหรับ product เดิมทั้งหมด:
  - Existing products → set เป็น `Published` โดย migration (ดู Section 4)

---

### 1.3 Metadata Panel Revamp (Phase 3)

ปรับ panel ด้านขวา / ด้านบนของ Product Modal (ที่ใช้แสดง metadata) ให้ชัดเจนขึ้น:

- แสดง:

  1. **Production Line**
     - `"Classic"` หรือ `"Hatthasilpa"` (ใช้ i18n + text EN เป็น default)
  2. **Graph Binding Support**
     - `"Supports Graph Binding: Yes/No"`  
     - Hatthasilpa → Yes  
     - Classic → No (ไม่ควร bind graph แล้ว ตาม Task 25.x)
  3. **Routing Link (เฉพาะ Hatthasilpa)**
     - แสดงสรุป `routing_name` (เช่น `Default Hatthasilpa Route`)  
     - ปุ่ม `"Open Routing"` → เปิดหน้า DAG Designer / Routing binding ตาม URL ปัจจุบันที่ใช้ในโปรเจกต์
  4. **Technical Information (Collapsible)**
     - ใส่ข้อมูลเช่น:
       - product ID
       - production_line (raw value)
       - created_at / updated_at
       - internal flags (is_published, supports_graph)  
     - ทั้ง section นี้อยู่ใน `<details>` หรือ collapse panel เพื่อไม่ให้รบกวน UI หลัก

---

### 1.4 API Updates (`product_api.php`)

เพิ่ม/ปรับ endpoint ดังนี้:

1. `action=publish`
   - Input:
     - `id_product` (POST/GET ตาม pattern เดิมของ product_api)
   - Behavior:
     - ตรวจสอบว่ามี product จริง
     - ถ้า product ยังไม่มี production_line ให้ถือว่าเป็น `classic` โดย default (แต่ในสถานการณ์จริงควรมีแล้วจาก Task 25.x)
     - Set `is_published = 1`
     - คืน JSON success โดยใช้ global helper (เช่น `json_success()`)

2. `action=unpublish`
   - Input:
     - `id_product`
   - Behavior:
     - ตรวจสอบว่ามี product จริง
     - ตรวจสอบว่า product ยังไม่ถูกใช้งานใน MO/Job Ticket/Hatthasilpa ที่ active อยู่ (ถ้ามี rule นี้อยู่แล้ว ให้ reuse / ถ้ายังไม่มี ให้ทำแบบ soft-check + warning ในอนาคต)
     - Set `is_published = 0`
     - คืน JSON success

3. Validation for usage:
   - ใน action ที่เกี่ยวข้อง (อาจจะอยู่ในไฟล์อื่น แต่ให้ใช้ `product_api` เป็นจุดศูนย์กลางของ validation logic ผ่าน helper function ของ ProductMetadataResolver):

     - MO Creation:
       - Reject ถ้า `product.is_published = 0`
     - Job Ticket Creation:
       - Reject ถ้า product เป็น draft
     - Hatthasilpa Jobs Creation:
       - Reject ถ้า product เป็น draft
     - Graph Binding:
       - ถ้า product เป็น draft → disallow bind และ return JSON error

   - ข้อสำคัญ:
     - ใช้ global JSON helpers ในการตอบ error เช่น:
       - `json_error('Product is not published and cannot be used in production.', 'PRODUCT_NOT_PUBLISHED');`

---

### 1.5 UI/UX

#### Product List (`views/products.php` + JS)

- เพิ่ม column “Status”
  - ใช้ badge จากข้อ 1.2
  - รองรับ sorting/filtering ได้ (ถ้า DataTable รองรับอยู่แล้ว)
- เพิ่ม Publish / Unpublish action:
  - ปุ่มใน dropdown ของแต่ละ row หรือใน detail modal
  - ใช้ SweetAlert (Swal) สำหรับ confirm:
    - `"Publish this product?"`, `"Unpublish this product?"`
  - หลังจากสำเร็จ → reload table / refresh row

#### Product Detail Modal

- แสดง Status badge ชัดเจนด้านบน (ใกล้ชื่อ product)
- ปุ่ม:
  - ถ้า Draft → แสดงปุ่ม `"Publish Product"`
  - ถ้า Published → แสดงปุ่ม `"Unpublish (Back to Draft)"`

#### Disable Actions เมื่อเป็น Draft

- ใน Modal / UI:
  - ถ้า product เป็น Draft:
    - Disable ปุ่ม “Create MO from this Product” (ถ้ามีในอนาคต)
    - Disable ปุ่ม Graph Binding (Hatthasilpa)
    - แสดง helper text:
      - `"This product is in Draft status and cannot be used in production yet."`

---

## 2. Technical Deliverables (สำหรับ Cursor)

### 2.1 Backend

#### 2.1.1 Migration

- สร้างไฟล์ migration:  
  `database/tenant_migrations/2025_xx_add_product_publish_flag.php`

- ทำสิ่งต่อไปนี้:
  1. `ALTER TABLE product ADD COLUMN is_published TINYINT(1) NOT NULL DEFAULT 0;`
  2. ตั้งค่า product ทั้งหมดที่มีอยู่ให้ `is_published = 1` (published ทั้งหมด)
  3. เพิ่ม index:
     - `idx_product_is_published` (optional แต่แนะนำ เผื่อใช้ filter บ่อย)

> ใช้ DB helper / migration helper ตาม pattern เดิม ห้ามเขียน raw mysqli inline แบบมั่ว ๆ  

#### 2.1.2 ProductMetadataResolver

ไฟล์: `source/BGERP/Product/ProductMetadataResolver.php`

- เพิ่มให้ resolver:
  - อ่าน `is_published`
  - เติม field ลงใน metadata:
    - `is_published` (bool/int)
  - ถ้ายังไม่ได้เติม `supports_graph` / `production_line` ใน metadata ให้ทำให้ครบ และให้สอดคล้องกับสิ่งที่ทำใน Task 25.x

#### 2.1.3 product_api.php

ไฟล์: `source/product_api.php`

- เพิ่ม actions:
  - `publish`
  - `unpublish`
- ใช้:
  - i18n helper: `translate('products.api.publish_success', 'Product has been published successfully.')`
  - global JSON helpers: `json_success`, `json_error`
- ห้าม:
  - inline SQL (ต้องใช้ DB abstraction / helper ของโปรเจกต์)
  - เขียนข้อความ error ตรง ๆ โดยไม่ผ่าน i18n

- เตรียม helper function สำหรับ validation ที่ endpoint อื่นสามารถ reuse ได้:
  - เช่น `assertProductIsPublished($idProduct)`:
    - ถ้าไม่ published → throw / return standardized JSON error

---

### 2.2 Frontend

#### 2.2.1 products.php (View)

ไฟล์: `views/products.php`

- เพิ่ม Status column ใน table header
- เพิ่มแสดง Status badge ในแต่ละ row (Server-side หรือ JS render ตามโครงสร้างปัจจุบัน)
- ใน modal:
  - แสดง Status badge ข้าง ๆ ชื่อ product
  - เพิ่มปุ่ม Publish / Unpublish ใน footer หรือ header area

> ใช้ข้อความในภาษาอังกฤษเป็น default + ผ่าน `translate()` เสมอ  

#### 2.2.2 products.js

ไฟล์: `assets/javascripts/products/products.js` (หรือชื่อที่ใช้อยู่จริง)

- เพิ่ม function:

  - `handlePublishProduct(productId)`  
    - แสดง Swal confirm  
    - call `product_api.php?action=publish`  
    - handle error / success ด้วย helper เดิม  
    - reload table / refresh modal  

  - `handleUnpublishProduct(productId)`  
    - เหมือนด้านบน แต่เรียก `action=unpublish`

- ปรับ render metadata panel:
  - อ่าน `is_published` และ `production_line` จาก metadata API (ถ้า fetch อยู่แล้ว ให้เพิ่ม field)
  - แสดง:
    - Status badge
    - Production Line
    - Supports Graph Binding
    - Routing link (Hatthasilpa เท่านั้น)
    - Technical Information (collapsible area)

- ใช้:
  - JS error helper ที่มีอยู่ (`showError`, `showToast` ฯลฯ ตามไฟล์ GLOBAL_HELPERS.md)
  - SweetAlert (Swal) version ที่โปรเจกต์ใช้อยู่แล้ว

---

## 3. Tests & Validation

### 3.1 Functional Tests

1. **Migration**
   - รัน migration บน dev:
     - ตาราง `product` มี column `is_published`
     - products เดิมทั้งหมดมี `is_published = 1`

2. **Create New Product**
   - เมื่อสร้าง product ใหม่:
     - ค่า default ต้องเป็น `Draft` (`is_published = 0`)
     - UI แสดง badge Draft
     - ปุ่ม “Publish Product” แสดงอยู่

3. **Publish / Unpublish**
   - กด Publish:
     - สถานะเปลี่ยนเป็น Published
     - Badge เปลี่ยนเป็น Published
   - กด Unpublish:
     - สถานะกลับเป็น Draft
     - ถ้าถูกใช้ใน MO/Job Ticket/Hatthasilpa ที่ active อยู่ และมี business rule พิเศษ ให้ทำตาม spec ที่เขียนไว้ (ถ้ายังไม่มี rule → อนุญาต และค่อยเพิ่มในอนาคต)

4. **Usage Blocking**
   - ลองสร้าง MO ใหม่ด้วย Product = Draft:
     - ต้อง error: `"Product is not published and cannot be used in production."`
   - ลองสร้าง Job Ticket ใหม่ด้วย Product = Draft:
     - ต้อง error เช่นกัน
   - ลองสร้าง Hatthasilpa Job ด้วย Product = Draft:
     - ต้อง error เช่นกัน
   - ลอง bind graph ให้ Hatthasilpa Product ที่เป็น Draft:
     - ต้องถูก block

5. **Metadata Panel**
   - เปิด Product Modal:
     - เห็น Status badge + Production Line + Supports Graph Binding + Routing info (Hatthasilpa) + Technical section

---

## 4. Non-Goals (สิ่งที่ยังไม่ทำใน Task นี้)

- ยัง **ไม่ทำ**:
  - Soft lock/remove ของ MO / Job Ticket / Hatthasilpa Jobs ที่ใช้ product ที่ถูก unpublish ไปแล้ว (จะจัดการใน Task หลังได้ ถ้าจำเป็น)
  - Versioning ของ Product (ยังยึดตามแนวคิด “Product = Version” ที่ตกลงกันแล้ว)
  - การ import/export publish state แบบ bulk

---

## 5. Guardrails (ย้ำอีกครั้ง)

เมื่อ Cursor ลงมือทำ Task 26.3:

1. ต้องอ่าน:
   - `DEVELOPER_POLICY.md`
   - `AI_QUICK_START.md`
   - `GLOBAL_HELPERS.md`
   - `QUICK_START.md`
2. Default language ในโค้ด = EN
3. ใช้ `translate()` สำหรับข้อความทุกประเภทที่ user จะเห็น (ยกเว้น low-level debug log)
4. Error JSON:
   - ใช้ global helpers
   - มี error_code เสมอ
5. JS:
   - ห้ามใช้ `alert()` และ `confirm()` → ใช้ Swal / toast helper
6. ห้ามล้างโค้ดเดิมโดยไม่จำเป็น:
   - Refactor เฉพาะส่วนที่เกี่ยวข้องเท่านั้น
   - อย่าลบ logic เก่าออกถ้ายังไม่เข้าใจ role ของมัน

---

## 6. Cursor Execution Prompt (ให้ Cursor ก็อปไปใช้ตรง ๆ)

> **ภารกิจของคุณ (Cursor) ใน Task 26.3:**  
> 
> 1. อ่านไฟล์ Policy ทั้งหมดในส่วน Guardrails (DEVELOPER_POLICY, AI_QUICK_START, GLOBAL_HELPERS, QUICK_START) จนเข้าใจ  
> 2. Implement ทุกหัวข้อใน Section 2 (Backend + Frontend + Migration) ตามลำดับ  
> 3. ใช้ `translate()` สำหรับข้อความ UI/ข้อความ error ทั้งหมด (default EN)  
> 4. ใช้ JSON helpers เดิมของโปรเจกต์สำหรับ responses และ error handling  
> 5. ห้ามใช้ inline SQL; ต้องใช้ abstraction layer เดิม  
> 6. เขียนโค้ดโดยคิดถึงความปลอดภัย, readability และ maintainability ระดับ Enterprise (Bellavier Group Standard)  
> 7. หลังเขียนเสร็จ ต้องอัปเดต `task26_3_results.md` สรุปไฟล์ที่แก้, พฤติกรรมใหม่ และข้อจำกัดที่ยังไม่ทำใน Task นี้  
> 
> **สำคัญ:**  
> - ห้ามลบโค้ดเดิมโดยไม่จำเป็น  
> - ถ้าจำเป็นต้อง refactor, ต้องอธิบายใน results ว่าทำไม  
> - โค้ดทั้งหมดต้องผ่าน syntax check (PHP + JS) ก่อนส่งมอบ
# Task 25.3 — Product Module: Phase 1 (Rebuild Foundation)

**Phase:** 25 — Classic Line Stabilization  
**Focus:** Product Module Rewrite (Part 1)  
**Owner:** System Engineering (Bellavier Group ERP)

---

# 🎯 Objective

Task 25.3 คือการเริ่มต้น "Product Module Rebuild" อย่างเป็นระบบ โดยมีเป้าหมายใหญ่อยู่ว่า:

> **ทำให้สินค้ามีฐานข้อมูลที่เรียบง่าย, สะอาด, และรองรับ Bind Routing (DAG) เต็มรูปแบบ**  
> โดยไม่ต้องมี Legacy Logic หรือ Template Versioning อีกต่อไป

ใน Task นี้เราจะวาง “ฐานราก” ของ Product module ก่อน เพื่อให้ Task 25.4–25.6 สามารถเดินหน้าได้อย่างลื่นไหล

---

# 📌 Scope (ครอบคลุมแค่ Phase 1)

### สิ่งที่จะทำใน Task 25.3:
1. **ล้าง Legacy Fields ที่ไม่ใช้แล้วใน Product Table**
2. **กำหนด Model ใหม่ของ Product = 1 Template = 1 Version**
3. **สร้าง ProductMetadataResolver.php (service ใหม่)**  
   - อ่านข้อมูลสำคัญของ Product  
   - Validate routing binding  
   - Prepare data สำหรับ Product Page (Classic Dashboard, Routing, Info)
4. **สร้าง API กลางสำหรับ Product Page (`product_api.php`)**
5. **Refactor Product Graph Binding Modal ให้รองรับรูปแบบใหม่**
6. **วางโครงสร้างงานสำหรับ Task 25.4–25.6**

> ❗ งานนี้ยังไม่แตะเรื่อง Stock/Inventory  
> ❗ ยังไม่แตะเรื่อง Variant หรือ SKU Expansion  
> ❗ ยังไม่แตะรายละเอียด UI มากนัก (โฟกัส Backend foundation)

---

# 🧱 1. Product Model (New Standard)

เปลี่ยนจาก:
- Product อาจมี template หลาย version  
- มี table เก่า ๆ ที่ไม่ได้ใช้ (legacy fields)

เป็นแบบใหม่:

1 Product = 1 Routing Binding = 1 Template (Implicit)

### Product Fields ที่ต้องคงอยู่:
- id_product  
- product_code (หรือ slug)  
- product_name  
- product_type  
- sku  
- is_active  
- id_routing_graph (nullable → จนกว่าจะ bind)  
- created_at  
- updated_at  

### Fields ที่ควรลบ/Ignore จากระบบ
(ให้ Cursor ลบจาก UI/Service/API แต่ยังไม่ลบออกจาก DB เวลานี้)

- template_version  
- is_versioned  
- id_template  
- id_product_template  
- legacy fields ทั้งหมดที่ไม่ได้ใช้งาน  

(การ migrate ลบคอลัมน์ออกจริง ๆ จะอยู่ใน Task 25.6)

---

# 🧠 2. ProductMetadataResolver (NEW SERVICE)

File:  
`source/BGERP/Product/ProductMetadataResolver.php`

### ความสามารถของ service นี้:
- Load product core info
- Load routing binding
- Validate ว่า routing graph สามารถใช้งานได้สำหรับ product
- Resolve production_type → classic / hatthasilpa (จาก product_type)
- ส่งคืน metadata สำหรับการใช้งานหน้า Product Detail

### Output ตัวอย่าง:

```json
{
  "ok": true,
  "product": {
    "id": 123,
    "name": "iPhone 16 Classic Case – Mint",
    "sku": "IP16-MNT",
    "product_type": "classic"
  },
  "routing": {
    "id_graph": 88,
    "graph_name": "Classic Case v3",
    "graph_mode": "dag",
    "node_count": 14,
    "valid": true
  },
  "classic": {
    "dashboard_enabled": true
  }
}


⸻

🔌 3. Product API — product_api.php

สร้างไฟล์ใหม่:

source/product_api.php

รองรับ action:
	•	get_metadata
	•	เรียก ProductMetadataResolver
	•	update_product_info (ยังไม่ implement แต่เตรียม route ไว้)
	•	unbind_routing
	•	bind_routing (ใช้ ProductGraphBindingHelper)
	•	get_classic_dashboard (proxy ไป product_stats_api)

เป้าหมาย:
ให้หน้า Product ใช้ API เดียว ไม่ควรยิงหลาย endpoint อีกต่อไป

⸻

🖥 4. Product Page Refactor (Phase 1)

หน้า:
views/product.php

เป้าหมาย:
	•	ใช้ ProductMetadataResolver ในการโหลดข้อมูล
	•	UI ต้องแสดง:
	•	Product basic info
	•	Routing binding info
	•	Classic Production Overview tab
	•	legacy template/version UI ควรซ่อนทั้งหมด

⸻

🔧 5. Product Graph Binding Modal (Refactor)

ต้องแก้ให้รองรับ model ใหม่:
	•	ไม่ต้องให้ผู้ใช้เลือก Template version
	•	การ Bind = Bind routing graph กับ product โดยตรง 1:1
	•	เมื่อ bind ให้โชว์ node_count + graph_name + graph_mode

ไม่ต้องแตะ DAG Designer ใน Task นี้

⸻

🏁 6. Acceptance Criteria
	•	เปิด Product Page → โหลดเร็วขึ้น ไม่ error
	•	ไม่มี UI ที่เกี่ยวกับ Template/Version อีกต่อไป
	•	ProductMetadataResolver คืนค่าถูกต้อง
	•	Bind Routing ทำงานถูกต้อง และไม่หลุดเป็น Hybrid
	•	Product Graph Binding Modal ไม่ซับซ้อนอีกต่อไป

⸻

🔮 7. Next Tasks (หลัง 25.3)
	•	Task 25.4 — Product Creation Flow (New UI + Simplified Creation)
	•	Task 25.5 — Product Index + Filtering + Search Engine Optimization
	•	Task 25.6 — DB Cleanup (ลบ template legacy schema)

⸻

🛠 Appendix A — Cursor Implementation Prompt

ให้ใช้เมื่อสั่ง AI Agent (Cursor) รัน Task 25.3 ทั้งหมด

You will modify multiple files in this task.

1. Create new file:
   source/BGERP/Product/ProductMetadataResolver.php
   - Implement resolve(), loadProduct(), loadRouting(), assembleMetadata()

2. Create: source/product_api.php
   - Implement action=get_metadata
   - Wire resolver
   - Add structure for bind_routing, unbind_routing, update_product_info (empty handlers)

3. Modify:
   views/product.php
   - Remove template/version UI
   - Add new metadata loader (JS)
   - Add Classic Dashboard tab container

4. Modify:
   assets/javascripts/product_graph_binding.js
   - Simplify modal
   - Remove template version logic
   - Use new metadata API

5. Ensure ClassicProductionStatsService patch remains untouched.

Ensure: 
- PHP passes syntax check
- JS loads without errors
- Backward compatibility maintained


# Task 25.3 — Product Module: Phase 1 (Rebuild Foundation)

**Phase:** 25 — Classic Line Stabilization & Product Foundation  
**Focus:** Product Module Rewrite (Part 1)  
**Owner:** System Engineering (Bellavier Group ERP)

---

# 🎯 Objective

Task 25.3 คือการเริ่มต้น “Product Module Rebuild” อย่างเป็นระบบ โดยยึดตามหลักคิดใหม่ที่เราตกผลึกแล้วว่า:

> **1 Product = 1 Template = 1 Version = 1 Production Line**  
> ถ้าจะเปลี่ยนเวอร์ชันงาน / เปลี่ยนวัสดุ / เปลี่ยนวิธีผลิต → ให้สร้าง Product ใหม่เลย

และ:

> **Classic line ไม่ใช้ DAG / Routing Graph ในการวางแผนการผลิต**  
> DAG / Token / Work Queue เป็นของ Hatthasilpa line เท่านั้น

ดังนั้น Task นี้จะโฟกัสที่ “ฐานราก” ของ Product module ให้สอดคล้องกับแนวคิดข้างต้น เพื่อให้ Task 25.4–25.6 เดินต่อได้แบบไม่กลายเป็นสปาเก็ตตี้

---

# 📌 Scope (Phase 1 เท่านั้น)

### สิ่งที่จะทำใน Task 25.3

1. **นิยาม Product Model ใหม่ให้ชัดเจน**
   - 1 Product = 1 Production Line (classic หรือ hatthasilpa)
   - ไม่มี Hybrid / Multi-line ใน Product เดียว
2. **ล้าง Legacy Template/Version Concept ออกจาก UI + Service ชั้นบน**
   - ยังไม่ลบคอลัมน์จาก DB (ค่อยไปทำใน Task 25.6)
3. **สร้าง ProductMetadataResolver.php (service ใหม่)**
   - อ่านข้อมูล Product + Production Line
   - สำหรับ Hatthasilpa: load routing binding (ถ้ามี)
   - สำหรับ Classic: ไม่บังคับให้มี routing, ไม่ error ถ้าไม่มี graph
4. **สร้าง Product API กลางสำหรับ Product Page (`product_api.php`)**
   - ให้หน้า Product ยิงแค่ endpoint เดียวเป็นหลัก
5. **Refactor Product Page + Graph Binding Modal ให้เข้ากับ model ใหม่**
   - Classic: ใช้ Classic Dashboard + Info, ไม่บังคับ binding DAG
   - Hatthasilpa: ใช้ DAG Binding เต็มรูปแบบ
6. **วางโครงสำหรับ Task 25.4–25.6**
   - ให้ Cursor ทำงานต่อจาก foundation นี้ได้โดยไม่ต้องย้อนรื้อโครงสร้างอีก

> ❗ ยังไม่แตะ Inventory / Stock  
> ❗ ยังไม่แตะ Variant / SKU Expansion  
> ❗ UI ปรับเท่าที่จำเป็นเพื่อรองรับ logic ใหม่ (โฟกัส backend foundation ก่อน)

---

# 🧱 1. Product Model (New Standard)

## 1.1 หลักการ

- ทุก Product ต้องมี **production_line** ที่ชัดเจน:
  - `"classic"` — ใช้ MO + Job Ticket แบบง่าย, เก็บสถิติ output ต่อวัน, ไม่ใช้ DAG/Token ในการวางแผน
  - `"hatthasilpa"` — ใช้ DAG / Token / Work Queue แบบละเอียด
- ถ้าอยากมี “ดีไซน์เดียวกันแต่ผลิตได้ 2 line” → ให้สร้าง 2 Products แยกกัน แล้วไปจัดกลุ่ม (family/model_code) ทีหลัง

## 1.2 Fields ที่ต้องคงอยู่ (ระดับ conceptual)

ในชั้น Service / API / UI ให้ถือว่า product มีโครงประมาณนี้:

- `id_product`
- `product_code` หรือ `slug` (unique)
- `product_name`
- `product_type` (เพื่อต่อยอด future logic เช่น case, bag, strap)
- `production_line` — `"classic"` หรือ `"hatthasilpa"` (single value)
- `sku`
- `is_active`
- `id_routing_graph` (nullable, **ใช้เฉพาะ hatthasilpa**)
- `created_at`
- `updated_at`

> ถ้าใน DB ตอนนี้ยังไม่มี `production_line` ให้ Cursor ใช้ field ที่มีอยู่ (เช่น `production_type`, `oem_flag`, ฯลฯ) เป็น bridge ชั่วคราว โดย mapping: OEM → classic, Atelier → hatthasilpa แล้วค่อยไป normalize จริงใน Task 25.6

## 1.3 Fields Legacy ที่ควร “Ignore ในระดับโค้ด”

ให้ Cursor **หยุดใช้งาน** field พวกนี้จาก Service / API / UI (แต่ยังไม่ต้องลบจาก DB):

- `template_version`
- `is_versioned`
- `id_template`
- `id_product_template`
- ทุก field ที่หมายถึง “template versioning” แบบเดิม

การลบคอลัมน์จริง ๆ จะทำใน Task 25.6

---

# 🧠 2. ProductMetadataResolver (NEW SERVICE)

**File:**  
`source/BGERP/Product/ProductMetadataResolver.php`

## 2.1 หน้าที่หลัก

Service นี้คือ “จุดรวมความจริงของ Product 1 ชิ้น” สำหรับหน้า Product Detail:

1. โหลดข้อมูล product หลัก (core info)
2. Resolve `production_line` ให้ชัดเจน (`classic` / `hatthasilpa`)
3. โหลดข้อมูล routing binding (ถ้ามี และถ้า product เป็น Hatthasilpa)
4. ตอบกลับ metadata ที่หน้า Product จะใช้ เช่น:
   - basic info
   - line info
   - routing info (เฉพาะ Hatthasilpa)
   - classic dashboard availability

## 2.2 Behavior ตาม Production Line

### ถ้า `production_line = "classic"`

- **ไม่บังคับ** ว่าต้องมี `id_routing_graph`
- ถ้าไม่มี graph:
  - อย่า error  
  - ให้ `routing` กลับมาเป็น `null` หรือ object แบบ `{"bound": false, ...}`
- ใส่ flag ว่า classic dashboard ใช้ได้ เช่น:

```json
"classic": {
  "dashboard_enabled": true
}
```

### ถ้า `production_line = "hatthasilpa"`

- ต้องพยายามโหลด routing graph ที่ถูก bind (ผ่าน helper เดิม เช่น `ProductGraphBindingHelper`)
- ถ้าไม่มี graph:
  - ให้ `routing.valid = false` และใส่ reason เพื่อให้ UI แสดง warning
- ถ้าเจอ graph:
  - ใส่ข้อมูล เช่น `graph_id`, `graph_name`, `graph_mode` (`dag`), `node_count`, `line_type = "hatthasilpa"`

## 2.3 Output ตัวอย่าง

```json
{
  "ok": true,
  "product": {
    "id": 123,
    "name": "iPhone 16 Classic Case – Mint",
    "sku": "IP16-MNT",
    "product_type": "case",
    "production_line": "classic"
  },
  "routing": null,
  "classic": {
    "dashboard_enabled": true
  },
  "hatthasilpa": {
    "routing_required": false
  }
}
```

สำหรับ Hatthasilpa:

```json
{
  "ok": true,
  "product": {
    "id": 456,
    "name": "Rebello Key Case – Hatthasilpa Edition",
    "sku": "RB-HAT-001",
    "product_type": "key_case",
    "production_line": "hatthasilpa"
  },
  "routing": {
    "id_graph": 88,
    "graph_name": "Hatthasilpa – Key Case v3",
    "graph_mode": "dag",
    "node_count": 14,
    "valid": true
  },
  "classic": {
    "dashboard_enabled": false
  },
  "hatthasilpa": {
    "routing_required": true
  }
}
```

---

# 🔌 3. Product API — `product_api.php`

**File:**  
`source/product_api.php`

สร้าง API กลางสำหรับ Product Page ให้รองรับ action ดังนี้ (Phase 1):

1. `get_metadata`
   - รับ `id_product`
   - ใช้ `ProductMetadataResolver` โหลด metadata
   - คืน JSON ตามโครงด้านบน

2. `bind_routing` (เฉพาะ Hatthasilpa)
   - รับ `id_product`, `id_graph`
   - เช็กว่า product.production_line = `"hatthasilpa"`
     - ถ้าไม่ใช่ → return error `ERR_NOT_HATTHASILPA_PRODUCT`
   - ใช้ `ProductGraphBindingHelper` ทำ binding
   - อย่าแตะ Classic line

3. `unbind_routing` (เฉพาะ Hatthasilpa)
   - ถอด binding graph ออกจาก product
   - ใช้กติกาเดียวกับ bind_routing เรื่อง production_line check

4. `get_classic_dashboard` (proxy)
   - Proxy ไปหา `product_stats_api.php` (endpoint ที่ทำใน Task 25.2)
   - ใช้สำหรับโหลด Classic Production Overview tab

5. `update_product_info` (เตรียม route ไว้)
   - Phase นี้ยังไม่ต้อง implement logic update จริง
   - แค่เตรียม endpoint + skeleton function เผื่อใช้ใน Task 25.4

> ทุก action ต้องใช้ header / auth / error format ตามมาตรฐาน ERP เดิม (อย่าเปลี่ยนโครงสร้าง error response)

---

# 🖥 4. Product Page Refactor (Phase 1)

**File:**  
`views/product.php` (หรือ `views/products.php` ตามโครงจริงในโปรเจกต์)

## 4.1 เป้าหมาย

1. หน้า Product ไม่ควรไปยิง API หลายตัวแบบกระจัดกระจายอีกต่อไป
2. UI ต้อง:
   - แสดง Product basic info
   - แสดง Production Line (Classic vs Hatthasilpa)
   - แสดง Routing Binding status สำหรับ Hatthasilpa
   - แสดง Classic Production Overview tab (สำหรับ Classic)
3. Legacy UI ที่เกี่ยวกับ Template/Version ต้องถูกซ่อน/ลบออก

## 4.2 งานที่ต้องทำ

- เปลี่ยน label ทั้งหมด:
  - “Atelier” → “Hatthasilpa”
  - “OEM” → “Classic”
- เวลาโหลดหน้า:
  - JavaScript ควรเรียก `product_api.php?action=get_metadata&id_product=...`
  - เอาข้อมูลจาก metadata มา render card ด้านบน (product summary)
- Tab ด้านล่าง:
  - ถ้า `production_line = "classic"`:
    - แสดง tab **Classic Production Overview** (เรียก `get_classic_dashboard`)
    - Graph Binding tab:
      - แสดงข้อความ: “Classic line ไม่ใช้ DAG Routing (optional only)” หรือปิดไปเลยใน Phase 1
  - ถ้า `production_line = "hatthasilpa"`:
    - แสดง Graph Binding tab เต็มรูปแบบ
    - Classic Overview tab สามารถซ่อน หรือแสดงเป็น “ไม่รองรับสำหรับ Hatthasilpa”

---

# 🔧 5. Product Graph Binding Modal (Refactor)

**File:**  
`assets/javascripts/product_graph_binding.js` (และ view/modals ที่เกี่ยวข้อง)

## 5.1 กติกาใหม่

1. ไม่ต้องมี Template Version ให้เลือกอีกต่อไป
2. การ Bind = **Bind routing graph กับ product ตรง ๆ แบบ 1:1**
3. Validation:
   - ถ้า product.production_line = `"classic"`:
     - ให้ JS ป้องกันไม่ให้เปิด modal binding หรือแสดงเป็น read-only
   - ถ้า product.production_line = `"hatthasilpa"`:
     - ให้เปิด modal ได้ตามปกติ และส่ง request ไป `product_api.php?action=bind_routing`

## 5.2 UI Behavior

- เมื่อเปิด modal:
  - ดึง metadata (ถ้ายังไม่มีใน memory) เพื่อรู้ว่า product เป็น line ไหน
  - ถ้าเป็น Hatthasilpa:
    - แสดง list ของ graphs ที่เลือกได้
    - แสดง node_count, graph_name, graph_mode ใน summary
  - ถ้าเป็น Classic:
    - ซ่อน control ทั้งหมด หรือแสดงข้อความว่า:
      > “Product นี้เป็น Classic line, ไม่ต้องตั้งค่า DAG Routing”

- เมื่อ bind/unbind สำเร็จ:
  - ให้ refresh metadata ในหน้าหลัก (เพื่อ update status ใน header)

---

# 🧪 6. Acceptance Criteria

1. เปิด Product Page แล้ว:
   - โหลด metadata ผ่าน `product_api.php?action=get_metadata` ได้ถูกต้อง
   - ไม่ error จาก legacy template/version fields
2. UI:
   - ไม่มี layout หรือ control ที่พูดถึง Template Version / Pattern Version อีก
   - Production Line แสดงชัดเจนว่า Classic / Hatthasilpa
3. Classic Products:
   - สามารถเปิด Classic Production Overview tab ได้
   - ไม่บังคับให้มี graph binding
   - Graph Binding UI ไม่สร้างความสับสน (ปิดหรือบอกชัดเจนว่าไม่จำเป็น)
4. Hatthasilpa Products:
   - Graph binding ผ่าน modal ทำงานได้ (bind / unbind) ผ่าน product_api
   - ถ้าไม่มี graph → metadata ระบุ `routing.valid = false` และ UI แสดง warning
5. Syntax:
   - PHP syntax check ผ่านทุกไฟล์ที่แตะ
   - JS ไม่มี error บน console เมื่อลองเปิดหน้า Product

---

# 🔮 7. Next Tasks (หลัง 25.3)

- **Task 25.4 — Product Creation Flow**
  - UI สำหรับสร้าง Product ใหม่ให้สอดคล้องกับ model:
    - เลือก Production Line
    - Duplicate → Draft
- **Task 25.5 — Product Index + Filtering**
  - หน้า list + filter ตาม line, type, active, family
- **Task 25.6 — DB Cleanup**
  - Migration ลบ legacy template/version columns ออกจาก DB
  - Normalize field `production_line` ให้ชัดเจน

---

# 🛠 Appendix A — Cursor Implementation Prompt

> ให้ใช้ section นี้เป็น prompt หลักสำหรับ Cursor / AI Agent เมื่อ implement Task 25.3

You will modify multiple files to implement Task 25.3.

## 1) Create ProductMetadataResolver

**File:** `source/BGERP/Product/ProductMetadataResolver.php`

- Implement a service class with roughly these methods:
  - `public function resolve(int $productId): array`
  - `private function loadProduct(int $productId): ?array`
  - `private function resolveProductionLine(array $product): string`
  - `private function loadRoutingForHatthasilpa(array $product): ?array`
  - `private function assembleMetadata(...): array`
- Logic:
  - Load product row
  - Map production_line (classic / hatthasilpa) from existing fields
  - For classic: do not require routing; routing can be null
  - For hatthasilpa: use existing helpers to load bound graph (if any)
  - Return metadata in the JSON structures described above
- Do not introduce any dependency on DAG for classic products.

## 2) Create Product API

**File:** `source/product_api.php`

- Follow existing API structure and auth helpers (similar to other `*_api.php`).
- Implement action handlers:
  - `get_metadata` — call ProductMetadataResolver and return JSON
  - `bind_routing` — only allow if product.production_line = "hatthasilpa"
  - `unbind_routing` — only allow if product.production_line = "hatthasilpa"
  - `get_classic_dashboard` — proxy to product_stats_api
  - `update_product_info` — create empty stub (no logic yet)
- Use consistent error format with existing APIs.
- Do not change ClassicProductionStatsService.

## 3) Refactor Product View

**File:** `views/product.php` (or the actual product detail view file)

- Replace any “Atelier” wordings with “Hatthasilpa”.
- Replace any “OEM” wordings with “Classic”.
- Remove or hide any UI that allows selecting template version or pattern version.
- Add JS snippet (or hook into existing JS) so that on page load it calls:
  - `product_api.php?action=get_metadata&id_product=...`
- Use the response to:
  - Render product basic info (name, sku, production_line)
  - Show different tabs/sections for Classic vs Hatthasilpa:
    - Classic: show “Classic Production Overview” tab container
    - Hatthasilpa: show “Routing / Graph Binding” tab

## 4) Refactor Product Graph Binding Modal

**File:** `assets/javascripts/product_graph_binding.js` (and any related modal markup)

- Remove logic for template version selection.
- Ensure the modal:
  - Checks product.production_line (from metadata or a global JS state)
  - If `hatthasilpa`:
    - Allow bind/unbind via `product_api.php?action=bind_routing` / `unbind_routing`
  - If `classic`:
    - Do not allow binding (either hide controls or show read-only message)
- After successful bind/unbind, refresh metadata in the main product view.

## 5) General Renaming Cleanup

- Where Product UI still uses “Atelier” → rename to “Hatthasilpa”.
- Where Product UI still uses “OEM” → rename to “Classic”.
- Do not rename DB columns yet; only adjust surface labels and service logic.

## 6) Validation

- Run PHP lint (syntax check) on all modified PHP files.
- Ensure the Product page loads without JS errors.
- Confirm that:
  - Classic products can open Classic dashboard via product_api proxy.
  - Hatthasilpa products can bind/unbind routing correctly via Product API.

If any part is unclear, prefer to keep behavior backward-compatible and add TODO comments rather than inventing new features.
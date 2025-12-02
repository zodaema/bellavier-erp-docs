
# Task 23.1 — MO Creation Extension Layer  
## Smart MO Creation + Routing Verification (Non-Intrusive)

> **Objective**  
> พัฒนาความสามารถของการสร้าง MO (Manufacturing Order) ให้ฉลาดขึ้น โดยไม่แก้ logic ดั้งเดิมของ `mo.php` แต่เพิ่ม “layer ใหม่” สำหรับแนะนำ, ตรวจสอบ, และ validate ความถูกต้องก่อนการสร้าง MO ตามกติกาเดิมของระบบ.

---

# 1. Core Principles

1. **ห้ามแก้ handler เดิมใน mo.php**  
2. **Layer ใหม่นี้ทำงานก่อน create() ของ legacy API**  
3. ใช้ข้อมูลจาก:  
   - ProductGraphBindingHelper  
   - RoutingSetService  
   - ProductCatalog  
   - TimeEventReader (optional estimate)  
4. ให้ข้อมูล:  
   - Suggestion  
   - Warning  
   - Validation  
   โดยไม่แก้ข้อมูลของผู้ใช้โดยตรง นอกจากได้รับคำสั่ง

---

# 2. High-Level Design

เมื่อผู้ใช้เปิดหน้า “Create MO”:

1. ผู้ใช้เลือก product  
2. Layer 23.1 จะทำงานอัตโนมัติ:
   - แนะนำ routing  
   - ตรวจว่ามี id_routing_graph ผูกกับ product  
   - Validate ว่า product นี้รองรับ classic line  
   - แสดง estimated time จาก timeline stats  
   - แสดงจำนวน nodes ที่ต้องผลิต  
   - แสดง UOM ที่สอดคล้องกับ product  
3. ผู้ใช้ปรับแต่ง → ส่งข้อมูลไป create() ตามเดิม

---

# 3. Features in Detail

## 3.1 Routing Suggestion Engine

ใช้ `RoutingSetService::getTemplatesForProduct($productId)`  
ถ้ามีหลาย routing:
- จัดอันดับตาม version (ล่าสุดก่อน)
- แจ้งผู้ใช้ว่ามี routing อื่นที่เข้ากันได้

ถ้าไม่มี routing:
- แสดง error: “Product X ไม่มี routing ที่รองรับการผลิต classic line”

---

## 3.2 Product–Routing Integrity Check

ตรวจสอบ:

1. id_product มี mapping อยู่ใน product_graph_binding หรือไม่  
2. routing version ตรงหรือใหม่กว่า  
3. routing นั้นรองรับ production_type = classic  
4. graph structure ไม่เป็น orphan (root + leaf ครบ)  
5. ตรวจว่า routing นั้นมีทุก node ที่จำเป็นตาม category ของสินค้า

Output:
```
{
  ok: true/false,
  errors: [...],
  warnings: [...],
  suggested_routing: id
}
```

---

## 3.3 Estimated Time Calculation (Optional)

ใช้ข้อมูลจาก:
- flow_token (historic)
- canonical events
- node-level duration stats  

คำนวณ:
- estimated_time_per_unit  
- estimated_total_time = qty × per_unit

ถ้า product ยังไม่มี historic duration:
- แสดง: “ยังไม่มีข้อมูลเวลาจริงจากการผลิตก่อนหน้า”

---

## 3.4 Auto-Fill: UOM + Metadata

- ดึง UOM จาก product (ผ่าน UOMService)  
- เติม default uom_code ใน form  
- แสดง conversion (ถ้ามี)

---

## 3.5 Quantity Validation

1. qty > 0  
2. qty ≤ max_routing_capacity (ถ้ามี config)  
3. qty ไม่เกิน WIP limit (ถ้ามี config)  
4. qty สอดคล้องกับ UOM (บาง product อาจต้องผลิตทีละคู่ / ทีละเซต)

---

## 3.6 Preview: Node Expansion

ให้ผู้ใช้เห็นว่า MO นี้จะกลายเป็น:
- token X nodes  
- Y total tokens  
- Z stages  
- sample queue impact

ใช้ข้อมูลจาก routing graph:
```
token_count = routing.node_count × qty
```

---

# 4. UI/UX Spec (สำหรับ Agent)

## 4.1 New Panel: “MO Smart Assistant”
โชว์ข้อมูล:
- Suggested routing  
- Node count  
- Estimated time  
- Warning list  
- Dependency check  
- Can-proceed status  

สี:
- green = recommended  
- yellow = warning  
- red = error  

---

## 4.2 Validation Summary

ก่อนผู้ใช้กด create:
- ถ้า error → ห้าม submit  
- ถ้า warning → แสดงปุ่ม “Confirm Anyway”  
- ถ้า ok → submit ปกติ  

---

# 5. Backend Architecture

## 5.1 New Service: MOCreateAssistService

ไฟล์:
```
source/BGERP/MO/MOCreateAssistService.php
```

Methods:
```
suggestRouting($productId)
validateRouting($productId, $routingId)
estimateTime($productId, $routingId, $qty)
getNodeStats($routingId)
buildCreatePreview($productId, $routingId, $qty)
```

## 5.2 Endpoint ใหม่ (ไม่แตะ mo.php)

```
/mo/assist/suggest
/mo/assist/validate
/mo/assist/preview
```

All GET requests.

---

# 6. Safety & Non-Scope

❌ ห้ามแก้ create(), plan(), start(), stop(), cancel(), start_production()  
❌ ห้ามแก้ routing engine  
❌ ห้าม spawn token ใน task 23.1  
❌ ยังไม่แตะ MO ETA (เป็น 23.4)  
❌ ยังไม่แตะ rework (เป็น 23.5)

---

# 7. Output / Deliverables

1. `MOCreateAssistService.php` (core logic)  
2. New endpoints `mo/assist/*.php`  
3. UI panel ในหน้า create MO  
4. Documentation file: `task23_1_results.md`  
5. Jest-like test cases (PHPUnit style)

---

# 8. Developer Prompt (สำหรับ AI Agent)

```
Implement Task 23.1 — MO Creation Extension Layer.

DO NOT modify mo.php or any legacy MO handler.

Create new service:
  source/BGERP/MO/MOCreateAssistService.php

Create endpoints under:
  api/mo/assist/

Implement:
  - Routing suggestion
  - Routing validation
  - Estimated time calculation
  - Node expansion preview
  - Warning/error reporting

All logic must be non-intrusive and only extend existing behaviors.
```

---

# END OF TASK 23.1
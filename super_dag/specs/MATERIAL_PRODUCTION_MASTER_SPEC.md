# Material & Production Master Specification

**Version**: Dec 2025  
**Status**: Finalized Concept  
**Purpose**: Foundation spec for Material Management and Production workflows

---

## 🎯 Core Concept: Two Production Lines

ระบบมี **2 แนวทางการผลิต** ที่แตกต่างกัน:

### 🟧 A. Hatthasilpa Line (Craft / Signature / High-labor)
- **Control Level**: Component-level (ละเอียด)
- **Technology**: Graph Designer + Node Behavior + Token
- **Material Tracking**: Real-time tracking ระหว่างการทำงาน
- **Example**: CUT Node สามารถ track วัสดุที่ใช้จริงได้

### 🟦 B. Classic Line (Mass / Batch)
- **Control Level**: MO-level (รวม)
- **Technology**: ไม่ใช้ Graph Node
- **Material Tracking**: Material Issue (เบิกล่วงหน้า) ก่อนเริ่มงาน
- **Workflow**: ช่างทำงานแบบเดิม แต่ระบบรู้การใช้วัสดุ

**Design Principle**: ใช้งานง่าย, ไม่รบกวน workflow ช่าง, แต่ได้ accuracy ระดับ ERP

**⚠️ CRITICAL: Two-Tier Approach (Revised Dec 2025)**

- **Hatthasilpa = Hermès-Level Precision**: SKU movement, Component-level, Graph-based, Full traceability
- **Classic = Standard ERP**: Simplified flow, Material Issue, Aggregate tracking, Practical approach

**เหตุผล**: Classic Line ไม่ต้องใช้มาตรฐาน Hermès เพราะ volume สูง, workflow ต่าง, และ ROI ของ granular tracking ไม่คุ้มค่า

---

## 🟧 HATTHASILPA LINE — Node Behavior Design

### ⭐ CRITICAL: Graph = Process Engine (ไม่ใช่ Component Engine)

**⚠️ FIRST PRINCIPLE: Graph ขับเคลื่อน Process ไม่ใช่ Components**

**Graph Designer is a Process Engine.**

**It does not model components.**

**Components live in BOM and Node Behaviors, not in Graph structure.**

---

**บทบาทแท้จริงของ Graph / Node / Token:**

✅ **Graph = เส้นทางการทำงาน (Process Flow)**
- ใครทำงานไหน → ที่ Node ไหน
- งานชุดนี้แยกกันทำแบบขนานได้ไหม
- งานชุดนี้ต้องรออีกสายหนึ่งก่อนประกอบไหม
- งานนี้เริ่ม–หยุด–พัก–จบตอนไหน (จับเวลา, Productivity)
- ตก QC แล้วจะวกกลับไปซ่อม หรือ Recut ใหม่จากต้นสาย

❌ **Graph ไม่ได้มีหน้าที่:**
- สั่งว่าต้องตัด BODY กี่ชิ้น
- สั่งว่า STRAP ใช้ Scrap S หรือ Full Sheet
- สั่งว่า Reinforcement เล็ก ๆ อยู่ตรงไหน
- เขียน How-to ว่าช่างต้องทำ Step 1–2–3 ยังไง

**Graph = "เส้นทางวิ่งของงาน" (Process Lane)**

**ไม่ใช่ "แบบแปลนชิ้นส่วน" (Component Blueprint)**

---

### ⭐ CRITICAL: 3-Layer Architecture (Design vs Operation vs Inventory)

**⚠️ สำคัญมาก: แยก 3 เลเยอร์ให้ชัดเจน เพื่อไม่ให้สับสนระหว่าง "BOM", "Graph", "Node Behavior", และ "Inventory Tracking"**

#### 🧱 Layer 1 — Product / BOM (Design Level)

**กฎสุดแข็ง:**

- **ทุกชิ้นที่อยู่ในกระเป๋า = ต้องอยู่ใน BOM เสมอ**
- **Critical**: BODY / FLAP / STRAP / GUSSET / ฯลฯ
- **Non-critical**: piping, edge binding, card slot patch, reinforcement, logo tab, ฯลฯ

**ใช้ BOM เป็นฐานในการ:**
- Material Requirement
- Material Forecast / Can Produce
- Costing

**👉 ตรงนี้ ไม่มีคำว่า "ไม่ต้องใส่" เลย**

**ถ้าไม่อยู่ใน BOM → ไม่มีอะไรไปสั่งให้เบิกหนังมา**

**⚠️ สำคัญ: BOM = ข้อมูลสนับสนุน, ไม่ใช่แกนหลักของ Graph**

- BOM บอกว่า กระเป๋าใบนี้ใช้วัสดุอะไรบ้าง, ประมาณเท่าไร
- จะละเอียดแค่ไหน ขึ้นกับ "คนออกแบบผลิตภัณฑ์" ไม่ใช่ "คนเขียน Graph"
- Graph ไม่จำเป็นต้องรู้รายละเอียด BOM ทั้งหมด

---

#### 🧩 Layer 2 — Graph / Nodes / Tokens (Process Level)

**⚠️ CRITICAL: Graph = Process Engine, ไม่ใช่ Component Engine**

**Graph = เส้นทางวิ่งของงาน (Process Lane), ไม่ใช่แบบแปลนชิ้นส่วน**

**บทบาทของ Graph:**
- แบ่งสายงาน (CUT, EDGE, SEW, ASSEMBLE, QC, PACK)
- จัดงานให้ช่างทีละ Batch / Token
- ทำให้เห็นว่า งานวิ่งไปตรงไหน ถึงไหนแล้ว, คอขวดอยู่ที่เลนไหน
- เป็น "โครงกระดูกของ process" ไม่ใช่โครงกระดูกของกระเป๋า

**Graph ไม่จำเป็นต้องรู้:**
- ชิ้นส่วนชื่ออะไร (BODY, STRAP, FLAP)
- Node นี้ = BODY_FRONT, Node นั้น = BODY_BACK
- แต่ละ Node ต้องตัด component อะไรบ้าง

**Graph เล่าแค่ว่า:**
- ใบนี้ มี "สาย A / B / C" (Process Lanes)
- A, B, C จะตัดก่อนพร้อมกัน, หรือให้สายไหนเริ่มก่อนก็ได้ (Parallel)
- ทุกสายต้องมาจบที่ Assembly Node เดียวกัน (Convergence)
- Assembly Node จะนับว่างานใบนี้ "พร้อม" เมื่อ Critical lanes ครบ

**ช่างในแต่ละ Node จะจัดการเองว่าบนโต๊ะตัวเองต้องตัดอะไรบ้าง**

**ระบบสนใจแค่ว่า Node ใช้เวลานานเท่าไร / WIP อยู่ที่จุดไหน / มีของให้สายถัดไปเมื่อไร**

---

### ⭐ CRITICAL: Component Flow vs Process Flow (V3 Final - New)

**⚠️ สำคัญมาก: Component Flow และ Process Flow เป็นคนละเรื่องกัน**

#### Process Flow (อยู่ใน Graph)

**Graph = เส้นทางของ Process Nodes:**
- Start → CUT → Stitch → QC → Assembly → Final QC → Finish

**Process Flow บอกว่า:**
- งานวิ่งไป Node ไหนบ้าง
- Node ไหนทำขนานกันได้
- Node ไหนต้องรอก่อน

**Graph ไม่บอกว่า:**
- Component แต่ละชนิดไป Node ไหนต่อ
- BODY ไป Stitch Body, FLAP ไป Stitch Flap

---

#### Component Flow (มาจาก Component Mapping - BOM/Product Config)

**⚠️ CRITICAL: CUT Node ผลิตชุดของ Components ตาม BOM → ไม่ผูกกับ Token**

**หลัง CUT เสร็จ:**
- Components ที่ถูกผลิตขึ้นจะ **ไม่เคลื่อนเป็นก้อนเดียวตาม Token อีกต่อไป**
- แต่จะ **"ไหลเข้าสู่งานถัดไปของตัวเองตามประเภทของ Component นั้น"**
- ซึ่งถูกกำหนดไว้แล้วจาก **Product Component Mapping** (จาก BOM / Product Config)

**Component Mapping กำหนดว่า:**
- Component BODY → ไป Node "Stitch Body"
- Component FLAP → ไป Node "Stitch Flap"
- Component STRAP → ไป Node "Stitch Strap"
- Component CARD_SLOT → อาจไม่ต้องผ่าน Stitch (skip node)

---

#### Component Output → Downstream Nodes

**⚠️ CRITICAL: Downstream Nodes จะรับงานตามจำนวน Component Ready (ไม่ใช่ Token-based)**

**ตัวอย่างหลัง CUT เสร็จ:**

```
CUT Batch: Aimee Mini – 10 bags

Component Output:
- BODY usable = 9 ชิ้น → เข้าคิวของ "Stitch Body Node" (9 ชิ้น)
- FLAP usable = 10 ชิ้น → เข้าคิวของ "Stitch Flap Node" (10 ชิ้น)
- STRAP usable = 10 ชิ้น → เข้าคิวของ "Stitch Strap Node" (10 ชิ้น)
```

**ช่างแต่ละ Node จึงมองเห็นงานตามจำนวนชิ้นที่พร้อมจริง ๆ ไม่ใช่ตาม Token**

**Work Queue ของ Stitch Body Node:**
- เห็น: BODY components 9 ชิ้น (ไม่เห็น Token 10 ใบ)
- เริ่มทำงานได้ทันที (ไม่ต้องรอ FLAP, STRAP)

---

#### Component Completion Independence

**⚠️ CRITICAL: Component อาจเสร็จไม่เท่ากันในแต่ละสาย**

**เพราะ Component เสร็จไม่เท่ากัน:**

- Node Stitch Body อาจเริ่มงานก่อน Stitch Flap (BODY เสร็จก่อน)
- Node Stitch Strap อาจยังไม่มีชิ้นส่วนเพียงพอ (STRAP ยังไม่เสร็จ)

**นี่คือพฤติกรรมโรงงานจริง:**
- ตัดชิ้นไหนเสร็จก่อน → ไปต่อได้เลย
- ช่างไม่ต้องรอชิ้นอื่น
- ไม่ต้องรอให้ Token "ครบทุก Component"

---

#### Assembly = Token Bundle (Critical Components Only)

**⚠️ CRITICAL: Token จะกลับมาเกี่ยวข้องอีกครั้งตอน Assembly เท่านั้น**

**Assembly เป็น Node เดียวที่ต้องใช้ Critical Components แบบ bundle**

**เพราะตอนประกอบเราต้องการรู้ว่า "ชุดไหนรวมกันเป็น 1 ใบได้ครบ"**

**จำนวนใบที่ประกอบได้ = minimum ของ Critical Components**

```
จำนวนใบที่ประกอบได้ = minimum(
  BODY.available / BODY.required,
  FLAP.available / FLAP.required,
  STRAP.available / STRAP.required,
  GUSSET.available / GUSSET.required
)
```

**Assembly Node:**
- รับ Components จากทุก Stitch Nodes (BODY, FLAP, STRAP, GUSSET)
- Bundle Components เป็น Token (1 Token = 1 ใบ)
- ใช้ minimum formula เพื่อคำนวณจำนวน Token ที่ประกอบได้

**Example:**
- Stitch Body เสร็จ: BODY 9 ชิ้น
- Stitch Flap เสร็จ: FLAP 10 ชิ้น
- Stitch Strap เสร็จ: STRAP 8 ชิ้น (required = 2) → ทำได้ 4 ใบ

**Assembly Result:**
- minimum(9/1, 10/1, 8/2) = minimum(9, 10, 4) = **4 ใบ**
- สร้าง Token 4 ใบ (พร้อมสำหรับ Final QC → Finish)
- Components ที่เหลือ (BODY 5 ชิ้น, FLAP 6 ชิ้น, STRAP 0 ชิ้น) → เก็บไว้รอ Token ถัดไป

---

#### Key Principles

**1. CUT Node → Component Output (ไม่ผูกกับ Token)**
- CUT ผลิตชุดของ Components ตาม BOM
- ไม่แตก Token ออกเป็นหลายเส้น
- แต่แตก "Component Output" ให้แต่ละ Node ถัดไปรับงานตาม Mapping

**2. Component Mapping (จาก BOM/Product Config)**
- Component ทุกชนิดต้องมี Mapping ของตัวเองว่าไป Node ไหนต่อ
- Mapping มาจาก BOM / Product Config (ไม่ใช่ Graph)
- Graph ไม่ต้องรู้ Component Flow

**3. Downstream Nodes (Stitch/QC) = Component-based Queue**
- รับงานตามจำนวน Component Ready (ไม่ใช่ Token-based)
- Stitch Body → เห็น BODY components
- Stitch Flap → เห็น FLAP components
- QC → เห็น components ที่ต้องตรวจ

**4. Assembly = Token Bundle**
- ใช้ Critical Components แบบ bundle
- Bundle Components เป็น Token (1 Token = 1 ใบ)
- Token ใช้ track ระดับ macro (ใบงานแต่ละใบ)

**5. Token ≠ Component Flow**
- Token ใช้ track เฉพาะระดับ macro (ใบงานแต่ละใบ)
- ไม่ใช้ track component flow
- Component Flow = Component Mapping (BOM/Product Config)

**6. Graph ≠ Component Flow**
- Graph คงใช้อธิบาย Process-level nodes เฉย ๆ
- Component-level flow มาจาก Component Mapping (ไม่ใช่ Graph)
- การที่ CUT แตกเป็นหลายสาย = Component Mapping ไม่ใช่ Graph แตก Token

---

#### Example Flow (Complete Picture)

```
1. CUT Batch (10 bags) → Component Output:
   - BODY: 9 usable → Component Queue "Stitch Body" (9 ชิ้น)
   - FLAP: 10 usable → Component Queue "Stitch Flap" (10 ชิ้น)
   - STRAP: 10 usable → Component Queue "Stitch Strap" (10 ชิ้น)

2. Stitch Body Node:
   - เห็น: BODY components 9 ชิ้น (ready)
   - เริ่มทำงานได้ทันที (ไม่ต้องรอ FLAP/STRAP)
   - หลังเสร็จ → BODY components 9 ชิ้น → Component Queue "QC Body" หรือ "Assembly"

3. Stitch Flap Node:
   - เห็น: FLAP components 10 ชิ้น (ready)
   - เริ่มทำงานได้ทันที
   - หลังเสร็จ → FLAP components 10 ชิ้น → Component Queue "Assembly"

4. Stitch Strap Node:
   - เห็น: STRAP components 10 ชิ้น (ready)
   - เริ่มทำงานได้ทันที
   - หลังเสร็จ → STRAP components 10 ชิ้น → Component Queue "Assembly"

5. Assembly Node:
   - รับ Components จากทุก Stitch Nodes
   - Bundle: minimum(9 BODY, 10 FLAP, 10 STRAP) = 9 ใบ
   - สร้าง Token 9 ใบ (พร้อม Final QC)
   - Components ที่เหลือ → เก็บไว้รอ Token ถัดไป
```

**ผลลัพธ์:**
- ระบบลื่นไหลแบบโรงงานจริง
- ตัดชิ้นไหนเสร็จก่อน → ไปต่อได้เลย
- ช่างไม่ต้องรอชิ้นอื่น
- ไม่ต้องรอให้ Token "ครบทุก Component"
- รองรับกรณีที่บาง Component ไม่ต้องผ่านบาง Node (Component Mapping)

---

#### 🎯 Layer 2.1 — Node Behavior / Payload (Operation Detail)

**⚠️ สำคัญ: Component tracking อยู่ใน Node Behavior, ไม่ใช่ Graph Structure**

**หลักการที่ถูกต้อง:**

**ถ้ามีอะไรต้องตัดจริงบนโต๊ะ → Node Behavior ต้องรู้ว่าต้องตัดมัน**

**แปลว่า:**
- **Components (Critical + Non-critical) อยู่ใน Node Behavior Payload**
- **Graph Structure ไม่ต้องรู้ Components**
- Node CUT Behavior: เก็บว่าใช้หนังจากผืนไหน, ตัดมาได้กี่ชิ้น (รวมเป็นกลุ่ม)
- Node QC Behavior: เก็บว่าผ่าน/ไม่ผ่าน, defect อะไร
- Node STITCH Behavior: เก็บเวลา, คนเย็บ
- **แต่ ไม่ได้ไปแตกเป็น HOW-TO ว่าทำมือซ้าย มือขวา, ดึงไหมกี่ครั้ง**

**ช่างเป็นเจ้าของ How-to ใน Node**

- ระบบไม่สั่งว่าจะตัด reinforcement ชิ้นไหนก่อน
- ระบบมีหน้าที่จับเวลา, บันทึกว่าใครทำ, เกิดอะไรขึ้น โดยไม่ก้าวก่ายเทคนิค

**🔹 Critical Components (ต้องละเอียด)**

ใน CUT UI ต่อ Component:

| Component | Required | Usable | Waste | (ถาม Over-cut) |
|-----------|----------|--------|-------|----------------|
| BODY      | 1        | [input]| [input]| [✓]           |
| FLAP      | 1        | [input]| [input]|                |

**ใช้สำหรับ:**
- นับ "ทำได้กี่ใบจริง"
- Traceability + Defect / QC / Serial mapping
- วิเคราะห์ productivity / waste ที่สำคัญ

**🔸 Non-critical Components (ต้อง "มี", แต่ไม่ต้องละเอียดเท่า)**

ใน CUT UI:

| Component / Group        | Required | Actual produced | Waste (optional) |
|--------------------------|----------|-----------------|------------------|
| EDGE_BINDING (รอบปาก)    | 2        | [input]         | [input opt]      |
| CARD_SLOT_PATCH (3 ใบ)   | 3        | [input]         | [input opt]      |

**ไม่ต้อง:**
- แยก usable per piece
- คิด over-cut per component
- Split SKU แยกราย component
- Log waste reason ลึกเท่า BODY/FLAP (อาจจะ optional)

**ต้อง:**
- ให้ช่างเห็น "ลิสต์ของที่ต้องตัด"
- ให้รู้ว่า required เท่าไร
- ให้มีที่กรอก actual รวม อย่างน้อยแค่พอปิด node ได้

**👉 คำตอบสุดท้ายของ "ถ้าไม่ใส่ใน Node Cut แล้วจะสั่งให้ใครตัด?"**

**ใช่ครับ ต้องใส่**

**แต่เราแยก "ระดับความละเอียด" ระหว่าง Critical vs Non-critical**

---

#### 🔶 Critical Component Bundle Definition (CRITICAL RULE)

**⭐ Mandatory Rule: Bag Completion Logic**

**A bag is counted as "1 completed unit" only when ALL Critical Components**
**(BODY, FLAP, STRAP, GUSSET) reach usable quantity that satisfies BOM × quantity.**

**Formula:**
```
จำนวนใบที่ทำได้ = minimum(
  BODY.usable / BODY.required,
  FLAP.usable / FLAP.required,
  STRAP.usable / STRAP.required,
  GUSSET.usable / GUSSET.required
)
```

**Key Points:**
- **Non-critical components DO NOT affect unit completion quantity**
- Critical Components = bottleneck ที่กำหนดจำนวนใบ
- ถ้า Critical Component ใดขาด → ใบนั้นประกอบไม่ได้
- Non-critical สามารถเติมทีหลังได้ (workflow จริงของโรงงาน)

**Example:**
- BODY usable = 10, required = 1 → สามารถทำได้ 10 ใบ
- FLAP usable = 8, required = 1 → สามารถทำได้ 8 ใบ
- STRAP usable = 18, required = 2 → สามารถทำได้ 9 ใบ
- GUSSET usable = 7, required = 1 → สามารถทำได้ 7 ใบ
- **Result: ทำได้ 7 ใบ** (minimum = GUSSET)
- Non-critical (EDGE_BINDING, CARD_SLOT) ไม่ได้ใช้ในการคำนวณ

---

#### 🔶 Non-critical Visibility Rule (MANDATORY)

**⭐ Mandatory Rule: All BOM Components Must Appear in CUT Node UI**

**Rule:**
- **All components listed in BOM must always appear in CUT Node UI**
- **Users CANNOT remove or skip non-critical components**
- **Non-critical components require 'actual produced' input**, even in aggregate form

**Rationale:**
- ป้องกันช่างลืมกรอก → ทำให้ material consumption เพี้ยน
- ป้องกัน Agent ตีความผิดและซ่อน component ที่ไม่สำคัญ
- ระบบต้องรู้ทุก component ที่ถูกตัด (แม้จะ aggregate)

**UI Behavior:**
- Non-critical components appear as read-only rows (ไม่สามารถลบได้)
- Required field: `actual produced` (minimum to close node)
- Optional field: `waste` (ถ้าต้องการกรอก)
- Cannot hide or skip → system validation will enforce

---

#### 🔶 Serial Mapping Scope (CRITICAL RULE)

**⭐ Mandatory Rule: Only Critical Components Eligible for Serial Mapping**

**Rule:**
- **Only Critical Components are eligible for serial mapping**
- **Non-critical components are recorded for consumption validation only**
- **Non-critical will NOT be part of serial traceability chain**

**Rationale:**
- Serial traceability จำเป็นเฉพาะชิ้นส่วนที่สำคัญ (Critical)
- Non-critical ไม่ใช่ bottleneck → ไม่ต้อง map serial
- ลดความซับซ้อนของระบบ serial mapping

**Implementation:**
- Serial number mapping → BODY, FLAP, STRAP, GUSSET only
- Non-critical (EDGE_BINDING, CARD_SLOT, etc.) → no serial mapping
- Traceability chain → Critical Components only

---

#### 📦 Layer 3 — Inventory & Scrap (SKU / Leather Object Level)

**Two-Tier Tracking:**

- **Critical Components**: ละเอียด (ดีเทลระดับ Hermès)
  - Track per component
  - Over-cut tracking
  - Waste reason required
  - Serial mapping

- **Non-critical Components**: Aggregate แต่ไม่ ignore
  - Consumption คิดรวม per material (area_per_piece * quantity ทั้ง critical + non-critical)
  - ไม่ต้อง track per non-critical piece
  - ไม่ต้องมี scrap/overcut per non-critical component
  - ไม่ต้อง map serial → non-critical

**Material Flow:**
1. วัสดุทุกตัว (แม้จะใช้กับ Non-critical อย่างเดียว) → ต้องอยู่ใน BOM ✅
2. Material Requirement จะดูจาก BOM + จำนวนใบ ✅
3. Material Reservation / Issue จะจองหนังตาม Requirement นั้น ✅
   - ไม่มี scrap → ใช้ full hide
   - มี remnant → ใช้ remnant
4. ตอน CUT (Node Behavior):
   - ทุก component (critical + non-critical) ใช้หนังจาก reservation เดียวกัน
   - Consumption ทาง inventory → คิดรวม per material
   - Scrap / remnant handling แยกเป็น logic ตาม spec (S/M/L, remnant ≥ 6 sq.ft ฯลฯ)

---

### ⭐ BODY / STRAP / FLAP ควรอยู่ตรงไหน?

**⚠️ IMPORTANT: Components ไม่ใช่แกนหลักของ Graph**

**ใช้ BODY/STRAP/FLAP แค่ใน 2 ที่:**

✅ **1. สำหรับคิด "จำนวนใบที่ทำได้จริง" และ Serial/Traceability**
- แค่บอกว่า "งานสายนี้คือกลุ่มของ Critical Components ชุดนึง"
- ไม่ต้องแตกละเอียดถึงระดับทุกชิ้น reinforce / piping

✅ **2. สำหรับทำ reporting / analytics ย้อนหลัง**
- ดูว่า waste ส่วนใหญ่หายไปกับงานสาย BODY หรือสาย STRAP
- ดูเวลาผ่าน Node ที่เกี่ยวข้องกับ BODY lane vs FLAP lane ฯลฯ

❌ **แต่ ไม่เอา BODY/STRAP ไปเป็นตัวกำหนด Graph**
- ไม่ต้องแยก Node ออกมาเยอะ ๆ (Node BODY_FRONT, Node BODY_BACK, Node CARD_SLOT)
- Graph เล่าแค่ Process flow (สายไหนทำขนาน, เมื่อไรมาอ assembly)

**Components อยู่ใน BOM และ Node Behaviors, ไม่ใช่ใน Graph structure**

---

### CUT Node Behavior (Layer 0–3: Finalized)

#### ⭐ CRITICAL: CUT Node = Batch Workflow (ไม่ใช่ Token-by-Token)

**⚠️ FIRST PRINCIPLE: CUT Node ทำงานแบบ Batch, ไม่ใช่ใบต่อใบ**

**แนวคิดหลัก:**
- **CUT Node = งาน batch รวมหลาย token**
- **Work Queue: รวม tokens ของ CUT Node เป็น 1 Batch Card**
- **CUT Workspace: แต่ละ Component มี Start/Finish ของตัวเอง**

**❌ ผิด (เดิม):**
- 1 token = 1 card → กด Start/Pause/Complete ทีละใบ

**✅ ถูก (ใหม่):**
- Group tokens โดย (product_id, node_id, assignee_id) → 1 Batch Card
- Card มีปุ่มเดียว: "เข้าสู่หน้าตัด (CUT Workspace)"
- ภายใน Workspace: แต่ละ Component มี Start/Finish ของตัวเอง

---

#### 3 สิ่งที่ระบบต้องบันทึก:

1. **ผืนที่ใช้ตัด** (Leather Sheet / Scrap S/M/L) - **เลือกก่อน Start Component**
2. **จำนวนที่ "ใช้ได้" ต่อ Component** (Usable quantity per component - Critical ละเอียด, Non-critical aggregate)
3. **จำนวนที่ "เสีย" ต่อ Component** (Waste quantity per component - Critical required, Non-critical optional)

---

### ⭐ CUT Node Batch Workflow (V3 Final - Detailed Implementation)

#### ⚠️ PRINCIPLE — หัวใจของแนวคิดใหม่ทั้งหมด

**0.1 Graph = Process Logic ไม่ได้ Track Component**
- Node ใช้เพื่อกำกับ flow และจับเวลา
- Node ไม่ควร track ว่า BODY/FLAP/STRAP ตัดไปกี่ชิ้น
- Component detail อยู่ใน Product Config (BOM)

**0.2 CUT ไม่ทำงานแบบ Token-by-Token ในโลกจริง**
- ช่างจะตัดเป็น "จำนวนต่อชิ้นส่วน" ไม่ใช่ "ใบต่อใบ"
- จึงต้องรวม Token ที่เหมือนกันเป็น CUT batch

**0.3 หนัง = หนึ่งออบเจกต์ต่อหนึ่งชิ้นเสมอ (Sheet/Scrap)**
- ทุกครั้งที่แบ่ง → ระบบต้อง "แตกตัว" เป็นหลายออบเจกต์ใหม่
- ห้ามคิดหนังเป็นตัวเลขรวมอีกต่อไป

**0.4 การเลือกหนังต้องเกิด "ขณะทำงาน" เสมอ (Dynamic Selection)**
- ⚠️ **Hatthasilpa ห้าม reserve ล่วงหน้า**
- ช่างตัดเลือกหนังตอนเริ่มงาน → ระบบ record ตามจริง

**0.5 ถ้าตัดเกิน / ตัดเสีย → ช่างต้องกรอกเพราะระบบคิดเองไม่ได้**
- ป้อนตัวเลข
- ระบบถามต่อว่าเกิน = usable หรือ waste?

**0.6 ก่อน Complete node ต้องยืนยันสถานะหนังเสมอ**
- เลือกว่าหนัง leftover:
  - กลายเป็น WASTE
  - กลายเป็น SCRAP S/M/L
  - กลับเข้า FULL SHEET
- ถ้าช่างลืม → ระบบ lock / แจ้งเตือน / ให้ Manager ตัดสิน

---

#### Step 1: CUT Card UI — แนวคิดใหม่ (สำคัญที่สุด)

**1.1 Token จะไม่ถูกแสดงแบบใบละใบอีกต่อไป**

**สำหรับ Node CUT เท่านั้น:**

**Grouping Logic:**
- รวม token ทั้งหมดที่เป็น "สินค้าเดียวกัน"
- และ "ถูก assign ให้ช่างคนเดียวกัน"
- → กลายเป็น **CUT Batch Card เดียว**

**Unassigned Group:**
- Tokens ที่ Node CUT เดียวกัน + Product เดียวกัน + ยังไม่ assign ใคร
- รวมเป็น "Unassigned CUT Batch"

**Batch Card Display:**
- Example: `"Cut Batch: Aimee Mini – 10 bags"`
- หรือ: `"Cut Batch: Aimee Mini – 24 bags (Unassigned)"`

**Card Actions:**
- ❌ **ไม่มี** Start/Pause/Complete buttons (เหมือน behavior อื่น)
- ✅ **มีปุ่มเดียว**: `[เข้าสู่หน้าตัด (CUT Workspace)]`

---

#### Step 2: CUT Workspace Interface

**1.2 เข้าหน้า CUT Batch จะเห็นอะไร**

**Header:**
```
Cut Batch: Aimee Mini – 10 bags
-----------------------------------------
```

**Component Table (กลางจอ):**

```
Components (Required quantities)

[ ] BODY Front – 10 pcs
[ ] BODY Back – 10 pcs
[ ] FLAP – 10 pcs
[ ] STRAP – 10 pcs
[ ] CARD SLOT – 30 pcs
[ ] LINING PANEL – 10 pcs
...
```

**Key Points:**
- ✅ ทุก component แสดงออกมา (ทั้ง critical + non-critical) → เพราะต้องตัดจริง
- ✅ แต่ละ component แยก "กดเริ่มตัด" ได้เอง
- ✅ Operator ค่อย ๆ ไล่ทำทีละ component ตามความถนัด (ไม่ต้องทำตามลำดับบรรทัด)

---

#### Step 3: เลือกหนัง (Dynamic Leather Selection)

**🟥 กฎเหล็ก: Hatthasilpa ห้ามจองวัสดุล่วงหน้า**

**เหตุผล:**
- งานจริงต้องดู defect และสีเป๊ะต่อหน้าเท่านั้น
- การเลือกหนังต้องเกิด "ขณะทำงาน" เสมอ (Dynamic Selection)

**🟦 วิธีเลือกหนัง (NEW RULE)**

**เมื่อคลิก component → UI เปิด "Select Leather Source":**

**มีให้เลือก:**
- Full Sheet (ขนาด 25–30 sq.ft.)
- Scrap S/M/L (ที่ลงทะเบียนไว้)
- Remnant ใหญ่ (≥ 6 sq.ft ที่ลงทะเบียนไว้)

**Filter:**
- จำกัดรายการเฉพาะ **"ชนิดหนังที่ BOM ต้องการ"**
- เฉพาะ sheet/remnant ที่ `status = 'available'`

**🟦 เลือกได้แค่ "ทีละแผ่น / ต่อ component run" เท่านั้น**

**เหตุผล:**
- เพื่อควบคุมปริมาณอย่างถูกต้อง
- เพื่อให้ระบบคำนวณ remaining sq.ft ได้จริง
- เพื่อให้ UI ไม่ซับซ้อน

**Summary (ใต้ component row):**
```
ใช้:
  - HIDE-001 (full sheet, 24 sq.ft)

ตัดได้สูงสุด ~ 18 ใบ (จาก area/area_per_piece)
```

**Validation:**
- ระบบตรวจว่า "ของที่เลือก" รองรับจำนวนที่ต้องตัดได้ไหม
- ถ้าผ่าน → `[Start]` button ของ component นั้น → **active**

**⚠️ CRITICAL RULE: Start button disabled จนกว่าจะเลือกหนังให้เสร็จก่อน**

**⚠️ IMPORTANT: ไม่มี Reservation ล่วงหน้า → เลือกหนังตอนเริ่มงาน component เท่านั้น**

---

#### Step 4: เริ่มงาน CUT (Start Cutting)

**เมื่อกด `[Start]` ที่ component row:**

**Process:**
1. เลือกหนังเสร็จ → ระบบคำนวณ capacity คร่าว ๆ
2. ปุ่ม `[Start]` จะ active
3. ระบบเริ่มจับเวลา
4. ช่างเริ่มตัดตาม pattern จริง

**System State:**
- `component_status = 'in_progress'`
- บันทึก `time_start` (สำหรับ productivity)
- UI highlight row → "กำลังตัดอยู่"

**Workflow:**
- ช่างทำงานบนโต๊ะ
- **ยังไม่จำเป็นต้องมาแตะจอระหว่างตัด**
- **ระบบแค่จับเวลาใน background**

---

#### Step 5: ป้อนผลลัพธ์การตัด (Cut Result Input)

**เมื่อกด `[Finish]` ที่ component row:**

**ช่างจะกรอกตัวเลข:**

```
Component: BODY FRONT
Required = 10
Actual Cut = __ (ช่างกรอก)
```

---

**🟩 4.1 Actual = Required → จบง่าย**

- บันทึกผล → `component_status = 'done'`
- ไป Step 6 (Sheet Finalization)

---

**🟨 4.2 Actual > Required → แสดง Over-cut Dialog**

**Modal 1: Over-cut Classification**

```
Over-cut: +2 pcs
Please classify:

( ) Usable Over-cut (kept for future)
( ) Waste (discarded)
```

**ถ้าเลือก "Usable Over-cut":**
- เก็บเข้า `component_overcut_inventory`
- ผูกกับ `leather_object` ที่ใช้ (ถ้าจำเป็น)
- บันทึก → ไป Step 6 (Sheet Finalization)

**ถ้าเลือก "Waste":**
- บันทึกเป็น waste/consumption
- ไป Step 6 (Sheet Finalization)

---

**🟥 4.3 Actual < Required → งานจริงตัดไม่พอ**

**Modal 2: Cut Short Handling**

```
Cut short by 3 pcs.
What do you want to do?

( ) Continue using the same sheet
( ) Withdraw sheet and select a new sheet
( ) Mark sheet as used up (becomes scrap/waste)
```

**If "Continue using the same sheet":**
- Component status → `in_progress` (ยังไม่ done)
- ช่างสามารถเลือกหนังใหม่และ Start อีกครั้ง

**If "Withdraw sheet and select a new sheet":**
- Sheet ปัจจุบัน → Finalize (Step 6)
- Component กลับเป็น `not_started`
- ช่างเลือกหนังใหม่ → Start อีกครั้ง

**If "Mark sheet as used up":**
- Sheet → Finalize as waste/scrap (Step 6)
- Component → Record actual ที่ได้จริง (ยังไม่ครบ required)
- ระบบแสดง warning: "Component not fully completed"

---

**After Finish (ถ้า Actual >= Required):**
- `component_status = 'done'`
- แสดง summary ใต้ row:
  ```
  ผลตัด: usable 11 (ใช้กับ batch นี้ 10 + overcut 1), waste 1
  ```
- ไป Step 6 (Sheet Finalization)

---

#### Step 6: Sheet Finalization Logic — แก้ปัญหาช่างลืมกดถอน

**⚠️ CRITICAL: ก่อน Complete node → ระบบบังคับให้ Finalize Sheet**

**🟥 กฎ: ระบบจะตรวจ sq.ft อัตโนมัติ**

**สำหรับทุก sheet ที่ถูกเลือกใช้ใน component นี้:**

**Modal: Sheet Finalization**

```
Sheet: HIDE-001 (24 sq.ft)
Remaining: ~6 sq.ft (estimated)

What do you want to do with remaining leather?

( ) Used Up → WASTE
( ) Remaining Piece → Register as SCRAP
( ) Still Mostly Full → Return to Inventory
```

**System Auto-Detection:**
- ถ้าเหลือ > 15 sq.ft → ถือเป็น **Full Sheet** (Return to Inventory)
- ถ้าเหลือ 1–6 sq.ft → **Scrap M/L** (Register as SCRAP)
- ถ้าเหลือ < 1 sq.ft → **Scrap S** (Register as SCRAP หรือ WASTE)

**Process:**
1. ช่างเลือก classification
2. ถ้า "Register as SCRAP" → ไป Step 7 (SCRAP Registration)
3. ถ้า "Return to Inventory" → Sheet `status = 'available'` กลับเข้า inventory
4. ถ้า "WASTE" → Sheet `status = 'consumed'`, record waste

**⚠️ ถ้าช่างไม่เลือก → ปิด Node ไม่ได้**

**ถ้าช่างหนีงาน → ระบบ lock sheet และแจ้งผู้จัดการ**

---

#### Step 7: SCRAP Registration — เวอร์ชันโรงงานใช้จริง

**หลัง finalize sheet (ถ้าเลือก "Register as SCRAP"):**

**UI: SCRAP Registration Form**

ช่างกรอก:
- **Approx width/height** (cm หรือ inch)
- **Surface condition** (dropdown: good, minor defect, major defect)
- **Estimated sq.ft** (auto-calculate หรือ manual)
- **Size Classification** (S/M/L - auto หรือ manual)

**Physical Labeling:**
- ช่างเขียน Label (รหัส + ขนาด)
- Example: `MINT-03 / 6 sqft`

**Storage:**
- นำไปเก็บใน "คลัง Scrap" (ตามสี/ไซส์)

**System:**
- สร้าง `leather_object` SKU ใหม่ (ถ้า ≥ 6 sq.ft) หรือ
- เพิ่มเข้า scrap pool (ถ้า < 6 sq.ft)

**⚠️ ไม่ยุ่งยาก และทำเฉพาะคนที่ดูแลวัสดุ (Supervisor)**

---

#### Step 8: Close CUT Node (Batch Complete)

**เงื่อนไข:**
- ทุก component ที่ "จำเป็นสำหรับ Node CUT" ต้อง `status = 'done'`
- **ทุก sheet ที่ใช้แล้ว ต้อง Finalize เรียบร้อยแล้ว** (Step 6)
- (ถ้าอนุญาต partial: critical ต้องครบ, non-critical อาจเหลือไว้ batch ถัดไป)

**System Calculation:**
```
จำนวนใบที่ตัดได้จริง = minimum(
  BODY.usable / BODY.required,
  FLAP.usable / FLAP.required,
  STRAP.usable / STRAP.required,
  GUSSET.usable / GUSSET.required
)
```

**Result:**
- บันทึกใน payload ของ token batch:
  ```
  CUT Batch #123 → สามารถส่งต่อให้ downstream ได้ 10 ใบ
  ```

**Component Output (Post-CUT):**
- **ไม่แตก Token ออกเป็นหลายเส้น**
- แต่แตก "Component Output" ให้แต่ละ Node ถัดไปรับงานตาม Component Mapping:
  - BODY 9 ชิ้น → Component Queue "Stitch Body" (9 ชิ้น)
  - FLAP 10 ชิ้น → Component Queue "Stitch Flap" (10 ชิ้น)
  - STRAP 10 ชิ้น → Component Queue "Stitch Strap" (10 ชิ้น)

**Token State (สำหรับ CUT Node):**
- Token ทั้ง 10 ใบเปลี่ยน state → `ready` (แต่ Token ไม่ได้แตกออกไปยัง Downstream Nodes)
- Components ที่ผลิตได้ถูกส่งไปยัง Downstream Nodes ตาม Component Mapping แทน
- Token จะกลับมาเกี่ยวข้องอีกครั้งตอน Assembly (Bundle Components เป็น Token)

**ถ้า usable มากกว่า total required:**
- ส่วนเกินไปอยู่ที่ over-cut inventory
- แต่ Component Output ยังคงส่งตาม usable ที่ได้จริง

---

### ❌ ปัญหาเดิม

UI เดิมให้กรอก "จำนวนที่ตัดได้" + "จำนวนที่เสีย" รวม ๆ

**ปัญหา:**
- ❌ ไม่รู้ว่าตัด Component ไหนเกิน / ขาด
- ❌ ไม่รู้ว่าตัดเกิน → ถือว่า usable หรือ waste

---

### ✅ แนวทางใหม่ (Finalized)

**UI ต้องแยกตาม Component**

#### ตัวอย่าง Component ของกระเป๋า 1 ใบ:

| Component | Required | ตัดได้จริง | ตัดเสีย |
|-----------|----------|------------|---------|
| BODY      | 1        | [input]    | [input] |
| FLAP      | 1        | [input]    | [input] |
| STRAP     | 2        | [input]    | [input] |

---

### 🔑 กรณี "ตัดเกิน" ที่ต้องรองรับ (MOST IMPORTANT)

#### Case A — ตัดเกินแบบ usable (Over-cut usable)

**Scenario**: Required = 1 แต่ช่างตัดได้ 2 อัน (ดีทั้งคู่)

**System Behavior**:
- ระบบต้องถาม: _"ชิ้นส่วนที่เกินนี้ต้องการบันทึกเป็น Stock usable (Over-cut Inventory) ไหม?"_

**User Choice**:
- **YES** → เก็บเป็นทรัพย์สินมีค่า ใช้ในงานถัดไป
  - เก็บเข้า `component_overcut_inventory`
  - `limit = actual - required`
  
- **NO** → ถือว่าใช้หมด ไม่ต้อง track

---

#### Case B — ตัดเสีย (Waste)

**Scenario**: Required = 1 แต่ช่างตัดได้ 0, ตัดเสีย 1

**System Behavior**:
- ระบบต้องให้กรอก **defect/waste reason** ด้วย
- บันทึกเป็น waste/consumption ตามปกติ

---

#### Case C — ตัดเกินแล้วไม่ได้ใช้ในอนาคต

**Scenario**: Over-cut ถูกใช้โดยงานอื่นจนหมด limit

**System Behavior**:
- Over-cut inventory ถูกใช้โดยงานอื่น
- Warehouse ปรับลด limit ของ original work = 0
- **ไม่กระทบ MO เดิม** (เพราะ over-cut = asset ส่วนกลาง ไม่ใช่ของงานนั้นอีกแล้ว)

---

## 🟧 เศษหนัง S / M / L (Scrap Management)

### ⭐ Remnant Size Classification Logic (CRITICAL)

**หลัง CUT Node เสร็จ → ระบบต้องจัดหมวดหมู่ Remnant/Scrap ตามขนาด:**

#### 1. Remnant ใหญ่ (≥ 6–8 sq.ft) = Register เป็น SKU ใหม่

**🔶 Mandatory Split Rule (Hatthasilpa) - CRITICAL**

**⭐ Rule: CUT Node ต้องทำ Split SKU เสมอ เมื่อสร้าง remnant ≥ 6 sq.ft**

**Whenever a CUT Node produces a remnant >= 6 sq.ft,**
**the system MUST create a child SKU (leather_object) automatically.**

**This rule is MANDATORY for traceability.**

**Process:**
- **System automatically creates child SKU** (ไม่ใช่ optional)
- ต้องติด label (เขียนมือ)
- ต้องเข้า workflow **"Register Remnant"** (Supervisor-operated)
- เก็บเป็น `leather_object` แบบเดียวกับ Full Sheet
- ใช้แทน Full Sheet ได้ในงานต่อไป
- Status: `available` (พร้อมใช้งาน)

**Implementation:**
- Post-CUT processing → Check remnant size
- If remnant >= 6 sq.ft → **MUST trigger split** (auto)
- Create `leather_object` with SKU code: `REM-{COLOR}-{AREA}sqft`
- Create `leather_split` + `leather_split_output` records
- Notify Supervisor to register remnant (physical labeling)

**Labeling Method:**
- ใช้ **"Label เปล่า + เขียนมือ"**
- ไม่ใช้เครื่องพิมพ์, ไม่ใช้ QR (เพราะ cutting table ไม่สะดวกติดสติ๊กเกอร์พิมพ์)
- เขียน 2 อย่างเท่านั้น:
  1. รหัสหนังสั้น (เช่น `MINT-03`)
  2. ขนาดโดยประมาณ (เช่น `12 sqft`)

**SKU Code Format:** `REM-{COLOR}-{AREA}sqft` (เช่น `REM-MINT-12sqft`)

---

#### 2. Remnant กลาง (1–6 sq.ft) = ปรับเป็น Scrap "L" หรือ "M"

**Process:**
- ไม่ต้องติด label
- เข้า pool ตามสี+ขนาด
- `object_id = NULL` (aggregated)
- `is_aggregated = TRUE`

**Size Classification:**
- 1–3 sq.ft → Scrap "M"
- 3–6 sq.ft → Scrap "L"

---

#### 3. Remnant เล็ก (< 1 sq.ft) = Scrap "S"

**Process:**
- ไม่ track รายชิ้น
- เข้า pool รวม (`object_id = NULL`, `is_aggregated = TRUE`)

---

**เหตุผล:**
- ต้นทุนแรงงานไม่พัง (ไม่ต้องติด label ทุกชิ้น)
- ยังรักษา traceability เฉพาะชิ้นที่มีมูลค่า (≥ 6 sq.ft)

---

### Hatthasilpa Line

**CUT Node ต้องรองรับ:**
- ✅ เลือก ผืนเต็ม (Full Sheet)
- ✅ เลือก Remnant ใหญ่ (≥ 6 sq.ft) - ใช้แทน Full Sheet
- ✅ เลือก Scrap S/M/L (สำหรับชิ้นเล็ก)
- ✅ เก็บเศษใหม่เข้า S/M/L อัตโนมัติหลังตัด
- ✅ Track เศษรายชิ้น (เฉพาะ Remnant ใหญ่ = SKU)

#### ⭐ Remnant Registration Workflow (NEW)

**หลังช่างตัดเสร็จและมี remnant ใหญ่ (≥ 6 sq.ft):**

**UI: "Register Remnant"** (Supervisor เป็นคนทำ → ไม่ใช่ช่าง)

**7 Fields:**
1. **สี** (auto filled จาก token)
2. **Estimated area** (sq.ft)
3. **Type** (Dropdown: Remnant / Scrap L / Scrap M / Scrap S)
4. **Source token** (auto filled)
5. **Component** (optional - มาจาก component ไหน)
6. **หมายเหตุ** (ถ้ามี defect)
7. **สร้าง leather_object ใหม่** (System auto-create SKU)

**Process:**
- Supervisor กรอก → System สร้าง `leather_object` ใหม่
- SKU Code: `REM-{COLOR}-{AREA}sqft`
- Status: `available`
- Physical label: Supervisor เขียนมือ (รหัส + ขนาด)

---

#### ⭐ Rules for Using Remnant in Next Jobs (V3 Final)

**ตอนนำ remnant ไปใช้ซ้ำ:**

1. **Dynamic Selection (ไม่ใช่ Reserve ล่วงหน้า)**
   - ⚠️ **Hatthasilpa: ห้าม reserve ล่วงหน้า**
   - ใช้ remnant → เลือกตอนเริ่มงาน component (เหมือน full sheet)
   - ไม่สามารถใช้ได้ถ้าไม่ผ่าน Selection workflow

2. **System Display**
   - ระบบต้องแสดงชื่อ remnant ให้ชัดเจน เช่น:
     - `REM-MINT-12sqft`
     - `REM-MINT-8sqft`
   - แสดงใน dropdown/material selection UI

3. **No Auto-Split**
   - Remnant ไม่สามารถ split อัตโนมัติ
   - ต้องผ่าน CUT Node เท่านั้น (เหมือน full sheet)

4. **Post-CUT Handling**
   - ถ้า CUT เกิด scrap ใหม่ → Finalize Sheet → ต้องย้อนกลับเข้า pool/split ตาม Remnant Size Classification Logic

---

#### ⭐ Human-Friendly UX for Remnant Search (NEW)

**UI สำหรับเลือก Remnant ต้องมี:**

1. **Visual Information:**
   - ขนาด (sqft) - ตัวใหญ่
   - สี - แสดงเป็น color swatch
   - รูปทรง (เช่น ทรงสี่เหลี่ยม, โค้ง, ครึ่งผืน) - icon หรือ thumbnail

2. **Status Display:**
   - Available / Reserved (clearly marked)
   - Reserved for: Token/MO ID

3. **Search/Filter:**
   - Filter by color
   - Filter by size range
   - Filter by status

4. **ไม่ใช่ list text** → ใช้ card-based UI หรือ grid view เพื่อให้ช่างจดจำได้ง่าย

---

### Classic Line

**Scrap Management:**
- ❌ ไม่ track เศษรายชิ้น
- ✅ Track แค่ระดับกล่อง S/M/L ต่อสี:
  - `scrap_S = xx sq.ft`
  - `scrap_M = xx sq.ft`
  - `scrap_L = xx sq.ft`

**เหตุผล**: โรงงานจะพังถ้าต้องแปะบาร์โค้ดเศษทุกชิ้น

#### ⭐ Classic Line: Scrap Conversion Timing (NEW)

**ปัญหาที่ต้องแก้:**
_"ถ้า remnant ใหญ่เหลือ 5–10 sq.ft หลัง Batch หนึ่งเสร็จ จะเก็บอย่างไร?"_

**Solution: "Return-to-Scrap-Pool" Step**

**ตอนปิด MO (MO Complete):**
- Classic line **ไม่ track remnant แบบ SKU-level**
- แต่มี **New Step: "Return-to-Scrap-Pool"**
  - ป้อนค่า "Scrap L/M/S" แบบรวม (aggregated)
  - ไม่สร้าง SKU ใหม่
  - ไม่ต้องเขียน label
  - เพราะ Classic ไม่เน้น remnant reuse (ต่างจาก Hatthasilpa)

**UI Fields:**
- Remaining Scrap Area (total)
- Scrap Classification (S/M/L dropdown)
- Color (auto from MO)

**Result:**
- เพิ่มเข้า scrap pool (aggregated per color/size)
- ไม่ track ว่า remnant ไหนมาจากผืนไหน (pool level)

---

## 🟦 CLASSIC LINE — ปัญหาใหญ่และ Solution

### ❌ สถานะปัจจุบัน

**MO Classic:**
- ไม่ใช้ Node
- ไม่ใช้ Graph
- ไม่รู้ว่าช่างหยิบวัสดุอะไร
- Inventory ไม่เคยลดแบบ real-time
- ช่างคว้าอะไรก็ได้มาตัด → ระบบตามไม่ทัน

**ผลลัพธ์**: Classic Line จะไม่มีทางสัมพันธ์กับ Inventory

---

### ✅ Solution ที่ถูกต้อง (Finalized - Revised Dec 2025)

**"บังคับเบิกวัสดุล่วงหน้า (Material Issue) ก่อนเริ่มงาน"**

นี่คือวิธีที่ ERP ทุกตัวในโลกใช้:
- SAP
- Oracle Netsuite
- Microsoft Dynamics

**⚠️ REVISED: Classic Line = Standard ERP Level (ไม่ใช่ Hermès Level)**

**Rationale:**
- Classic Line volume สูง, workflow ต่าง, ROI ของ granular tracking ไม่คุ้มค่า
- ช่างไม่ค่อยสนใจตัวเลข sq.ft อยู่แล้ว
- โรงงานชินกับรูปแบบ "เบิก 1 ผืน = ทำได้ประมาณ XX ใบ"

---

### Flow ใหม่ของ MO Classic (Mode 2: Simplified)

#### ① ตอนสร้าง MO → ระบบสร้าง Material Requirement (ตาม BOM)

**Example:**

| Material       | per unit | qty | total      |
|----------------|----------|-----|------------|
| Leather Mint   | 1.2 sq.ft| 20  | 24 sq.ft   |
| Lining         | 0.4 sq.ft| 20  | 8 sq.ft    |
| Hardware       | 3 pcs    | 20  | 60 pcs     |

**Status:**
- ✅ ยังไม่ตัด stock
- ✅ ยังไม่ออกของ
- ✅ แค่ "ต้องใช้เท่านี้" (Requirement only)

---

#### ② ก่อนเริ่มงาน → บังคับ Material Issue (Mode 2: เบิกทั้งผืน)

**Warehouse/ช่างต้องทำ:**

_"เลือก SKU ว่าผืนไหนต้องใช้ เพื่อทำ MO นี้"_

**UI Example:**

| Material       | Required | SKU Selection | Area     | รวม   |
|----------------|----------|---------------|----------|-------|
| Leather Mint   | 24 sq.ft | [เลือก SKU]   | 25 sq.ft | 25 ✓ |

**เมื่อเลือก SKU:**
- ระบบแสดง SKU ที่ `status = 'available'`
- User เลือก SKU ที่ต้องการ (เช่น: `HIDE-001`, `HIDE-002`)
- **ระบบไม่สนใจว่าเหลืออีกกี่ sq.ft** → เบิกทั้งผืน

**เมื่อกด Confirm (Material Issue):**

1. **Reserve SKU** → บันทึกใน `leather_reservation`
   - `reserved_for_type = 'mo'`
   - `reserved_for_id = MO_456`
   - SKU เปลี่ยนสถานะเป็น `reserved`

2. **บันทึก Material Issue**
   - บันทึกใน `material_issue` + `material_issue_item`
   - Status: `issued`
   - **ไม่ต้อง split SKU** → เบิกทั้งผืน

**ระหว่างทำงาน:**
- ระบบถือว่า "ผืนนี้ belong to MO นี้"
- ไม่ต้อง track การใช้วัสดุรายละเอียด (เพราะเบิกไปแล้ว)

**นี่คือจุดที่ระบบจับการใช้วัสดุ (แบบ Simplified - เบิกทั้งผืน)**

---

#### ③ ระหว่างทำ Classic MO (ใน PWA)

**Workflow:**
- ✅ แค่สแกนใบงาน
- ✅ Start / Pause / Complete
- ✅ กรอกจำนวนเสร็จแต่ละวัน
- ❌ **ไม่ต้องยุ่งกับวัสดุอีก**

**เหตุผล**: เพราะ "ยอดวัสดุถูกตัดออกไปแล้วตอนเบิก"

---

#### ④ หลังปิด MO (Mode 2: Declare Scrap รวม)

**ตอนปิด MO:**
- มี UI ให้กรอก **"เหลือเศษประมาณกี่ sq.ft → กลายเป็น scrap pool ของสีนี้/ไซส์นี้"**
- ไม่ต้อง split SKU ทุกครั้งตัด
- ไม่รู้ relationship ระหว่างผืนเดิมกับ scrap แบบ 1:1
- แต่รู้ระดับ "MO นี้ใช้ไปประมาณเท่านี้ เหลือเท่านี้"

**Process:**
1. User กรอก "Remaining Scrap Area" (ประมาณการ)
2. ระบบบันทึกเป็น scrap pool (aggregated per color/size)
3. SKU เดิมถูก mark เป็น `consumed`

**Pros:**
- ได้ความแม่นขึ้นกลาง ๆ
- ไม่ต้อง split SKU ทุกครั้งตัด (ลด complexity)
- Stock ไม่หายไปหมด

**Cons:**
- ไม่รู้ relationship ผืนเดิมกับ scrap แบบ 1:1
- แต่สำหรับ Classic Line → นี่พอแล้ว

---

## 📋 Inventory Architecture

### ⭐ Core Principle: Balanced SKU-Level Tracking

**⚠️ REVISED: Balanced Approach (ไม่ใช่ Full SKU Movement ทุกครั้ง)**

**หลักการพื้นฐาน:**

1. **Full hide = 1 SKU** (ทุกผืน = 1 Object เสมอ)
2. **Split สำคัญ ๆ = Child SKU** (เช่น แบ่งเป็น 2 ครึ่ง, แบ่งสำหรับ Hatthasilpa)
3. **Scrap Classic = Pool** (aggregate per color/size - ไม่ต้อง SKU แยกทุกชิ้น)
4. **Scrap Hatthasilpa = ละเอียดกว่า** (track เป็น SKU ได้ถ้าต้องการ)

**ทำไมต้อง Balanced:**

**ปัญหา Full SKU Movement:**
- Production volume สูง → หลายพัน SKU ต่อเดือน
- UI ต้องให้เลือก "ผืนหนัง" จาก dropdown → เลือกยากถ้ามี 500 SKU
- ภาระ manage/search รายการสูง

**Solution:**
- SKU movement เฉพาะจุดที่สำคัญ (ไม่ใช่ทุกครั้งที่ cutter ขยับมีด)
- Traceability ระดับ "มาจากลอตนี้/ผืนนี้" ไม่ใช่ "มาจากขอบด้านขวาบนของผืนที่ 3"
- สำหรับ Classic Line → pool level ก็พอ
- สำหรับ Hatthasilpa → สามารถละเอียดกว่าได้

**ทำไมนี่สำคัญ:**
- ✅ Traceability พอใช้ (ระดับที่เหมาะสม)
- ✅ เทียบเท่า Hermes/LV สำหรับ Hatthasilpa
- ✅ Classic Line ใช้มาตรฐาน ERP ธรรมดา (ไม่หนักเกินจำเป็น)

---

### SKU Lifecycle States

| สถานะ | อธิบาย |
|-------|--------|
| `available` | อยู่ในคลัง ใช้ได้ |
| `reserved` | ถูกจองโดย Token/MO (ห้ามใช้กับงานอื่น) |
| `cutting` | อยู่ระหว่างทำ CUT Node |
| `consumed` | ถูกใช้หมดแล้ว |
| `split` | ถูกแบ่งแล้วสร้าง SKU ใหม่ |
| `scrap` | ถูกแปลงเป็นเศษขนาด S/M/L |

---

### Reservation System (CRITICAL)

**ก่อนทำงาน:**
- เลือกหนัง SKU (เช่น: `HIDE-001`)
- ระบบจะเปลี่ยนสถานะเป็น: `reserved`
- `reserved_for_type`: `token` หรือ `mo`
- `reserved_for_id`: `token_123` หรือ `MO_456`

**ระหว่าง RESERVED:**
- ❌ ห้ามนำไปใช้กับงานอื่น
- ❌ ห้ามตัด
- ❌ ห้ามคืนคลัง
- ❌ ห้ามสูญหายโดยไม่มีเหตุผล
- ✅ สามารถตัดได้แค่กระบวนการของงานนี้เท่านั้น

---

### Table Structure

#### 1. Leather Object (SKU-Level Control) ⭐ NEW

```sql
leather_object
- id_object (PK)
- sku_code (unique) -- e.g., "HIDE-001", "HIDE-001-A", "SCRAP-001-S"
- status ENUM('available', 'reserved', 'cutting', 'consumed', 'split', 'scrap')
- source_object_id (FK) -- ผืนต้นฉบับ (สำหรับ traceability)
- color_code
- area_sqft
- created_at
- updated_at
```

**Purpose**: Track ทุกผืนหนังเป็น SKU แยกกัน (ไม่ใช่รวม sq.ft)

---

#### 2. Leather Usage (Hatthasilpa Dynamic Selection) ⭐ NEW V3

```sql
leather_usage
- id_usage (PK)
- object_id INT NOT NULL (FK → leather_object)
- component_batch_id INT (FK → component_batch หรือ batch_id)
- selected_at DATETIME NOT NULL
- selected_by INT (user_id)
- status ENUM('in_use', 'finalized', 'cancelled') NOT NULL DEFAULT 'in_use'
- finalized_at DATETIME NULL
- finalization_type ENUM('consumed', 'scrap', 'returned') NULL
- INDEX idx_object (object_id),
- INDEX idx_batch (component_batch_id),
- FOREIGN KEY (object_id) REFERENCES leather_object(id_object) ON DELETE CASCADE
```

**Purpose**: บันทึกการเลือกหนัง (Dynamic Selection) สำหรับ Hatthasilpa CUT Node

**Business Rules:**
- 1 SKU สามารถถูกเลือกใช้ได้แค่ 1 component batch (Soft Lock)
- เมื่อ `status = 'in_use'` → ไม่ให้ component batch อื่นเลือก (แต่ไม่ใช่ hard reserve)
- หลัง Finalize → `status = 'finalized'`

**⚠️ IMPORTANT: ต่างจาก `leather_reservation` (Classic Line) ที่ reserve ล่วงหน้า**

---

#### 2.1. Leather Reservation (Classic Line Material Issue) ⭐ NEW

```sql
leather_reservation
- id_reservation (PK)
- object_id (FK → leather_object)
- reserved_for_type ENUM('mo')  -- Note: Hatthasilpa ใช้ leather_usage แทน
- reserved_for_id INT (mo_id)
- reserved_at DATETIME
- reserved_by INT (user_id)
- released_at DATETIME (nullable)
- status ENUM('active', 'released', 'consumed')
```

**Purpose**: จอง SKU สำหรับ Classic MO (Material Issue ล่วงหน้า)

**Business Rules:**
- 1 SKU สามารถ reserved ได้แค่ 1 MO (ไม่ซ้ำ)
- เมื่อ reserved → ห้ามใช้กับงานอื่นจนกว่าจะ release/consume

**⚠️ NOTE: Hatthasilpa ใช้ `leather_usage` แทน (Dynamic Selection)**

---

#### 3. Leather Split (CUT Operation) ⭐ NEW

```sql
leather_split
- id_split (PK)
- source_object_id (FK → leather_object) -- ผืนต้นฉบับ
- token_id INT (nullable) -- สำหรับ Hatthasilpa
- mo_id INT (nullable) -- สำหรับ Classic
- split_type ENUM('cut_half', 'cut_custom', 'generate_scrap')
- created_at DATETIME
```

**Purpose**: บันทึกการแบ่งผืนหนัง (CUT Node)

**Related Tables:**
- `leather_split_output` - SKU ใหม่ที่เกิดจากการ split
  - `split_id` (FK)
  - `output_object_id` (FK → leather_object)
  - `area_sqft`
  - `output_type` ENUM('usable', 'scrap_s', 'scrap_m', 'scrap_l')

---

#### 4. Leather Consumption ⭐ NEW

```sql
leather_consumption
- id_consumption (PK)
- object_id (FK → leather_object)
- consumed_by_type ENUM('token', 'mo')
- consumed_by_id INT
- consumption_type ENUM('normal', 'waste', 'overcut_usable')
- component_code VARCHAR (nullable) -- สำหรับ Hatthasilpa
- quantity_used INT
- waste_reason TEXT (nullable)
- consumed_at DATETIME
```

**Purpose**: บันทึกการบริโภควัสดุ (บนฐาน SKU movement)

**Business Rules:**
- Material Consumption ต้องใช้บนฐานของ "SKU movement"
- ไม่ใช่ลด sq.ft แบบคณิตศาสตร์เฉย ๆ
- แต่เป็น: `HIDE-001 → split → HIDE-001-A + HIDE-001-B → consumed by token/MO`

---

#### 5. Leather Scrap (เศษ S/M/L)

```sql
leather_scrap
- id_scrap (PK)
- object_id (FK → leather_object) -- แต่ละชิ้น scrap = 1 SKU
- color_code
- size ENUM('S', 'M', 'L')
- area_sqft
- source_type ENUM('cut_output', 'mo_return', 'manual')
- source_token_id INT (nullable)
- source_mo_id INT (nullable)
- created_at DATETIME
```

**Purpose**: Track เศษหนังระดับ S/M/L
- Hatthasilpa: รายชิ้น (1 scrap = 1 SKU)
- Classic: รวม (aggregated) แต่ยัง track เป็น SKU

---

#### 6. Component Over-cut Inventory

```sql
component_overcut_inventory
- id (PK)
- mo_id INT (foreign key)
- token_id INT (optional, for Hatthasilpa)
- component_code VARCHAR
- object_id (FK → leather_object) ⭐ NEW -- ผูกกับ SKU จริง
- quantity INT (usable quantity)
- limit INT (maximum quantity available)
- created_at DATETIME
- updated_at DATETIME
```

**Purpose**: Track over-cut usable components (Hatthasilpa only)
- **Enhancement**: ผูกกับ `leather_object` SKU เพื่อ traceability

---

#### 7. Material Issue (Classic Line) ⭐ NEW

```sql
material_issue
- id_issue (PK)
- mo_id INT (FK)
- issued_at DATETIME
- issued_by INT (user_id)
- status ENUM('pending', 'issued', 'completed', 'cancelled')
- issue_details JSON -- material sources selected
```

**Related:**
- `material_issue_item` - SKU ที่ถูก issue
  - `issue_id` (FK)
  - `object_id` (FK → leather_object) -- SKU ที่ถูก issue
  - `quantity` INT
  - `area_sqft` DECIMAL

**Purpose**: บันทึกการเบิกวัสดุสำหรับ Classic MO
- **Enhancement**: Issue เป็น SKU-level (ไม่ใช่แค่ sq.ft)

---

#### 8. Component Queue / Component Output (NEW - V3 Final)

**⚠️ NOTE: Database schema นี้เป็น conceptual design - ต้อง design รายละเอียดใน Phase Implementation**

**Conceptual Schema:**

```sql
-- Component Output (จาก CUT Node)
CREATE TABLE component_output (
    id_output INT PRIMARY KEY AUTO_INCREMENT,
    cut_batch_id INT NOT NULL,  -- FK → cut_batch หรือ batch_id
    component_code VARCHAR(100) NOT NULL,  -- BODY, FLAP, STRAP, etc.
    quantity_produced INT NOT NULL,  -- usable quantity จาก CUT
    status ENUM('ready', 'in_progress', 'completed', 'consumed') NOT NULL DEFAULT 'ready',
    target_node_id INT,  -- FK → routing_node (from Component Mapping)
    target_node_code VARCHAR(100),  -- "Stitch Body", "Stitch Flap", etc.
    created_at DATETIME NOT NULL,
    INDEX idx_batch (cut_batch_id),
    INDEX idx_component (component_code),
    INDEX idx_target_node (target_node_id),
    INDEX idx_status (status)
);

-- Component Queue (สำหรับ Downstream Nodes)
-- Note: อาจใช้ component_output table โดย filter ตาม target_node_id + status='ready'
-- หรือสร้าง separate queue table ตาม implementation decision

-- Component Mapping (Product Config - BOM-based)
-- Note: อาจใช้ existing product_component + graph_component_mapping tables
-- หรือสร้างใหม่ตาม Component Flow requirements
```

**Purpose:**
- บันทึก Component Output จาก CUT Node
- Track Component Queue สำหรับ Downstream Nodes
- Map Component → Target Node (จาก Component Mapping)

**Business Rules:**
- Component Output ไม่ผูกกับ Token
- Downstream Nodes รับงานตาม Component Ready (ไม่ใช่ Token-based)
- Component Mapping มาจาก BOM/Product Config (ไม่ใช่ Graph structure)

---

## 🔄 3 ประเภทการบริโภควัสดุ (SKU-Level)

### 1. ปกติ (ตาม BOM) - Normal Consumption

**Process:**
- SKU ถูก Split (ถ้า CUT) → เกิด SKU ใหม่
- SKU ใหม่ถูก Consume → บันทึกใน `leather_consumption`
- `consumption_type = 'normal'`
- SKU เปลี่ยนสถานะเป็น `consumed`

**Inventory Impact:**
- SKU เดิม: `available` → `split` → (SKU ใหม่)
- SKU ใหม่: `available` → `consumed`

---

### 2. Over-cut Usable (กลายเป็น stock)

**Process:**
- ตัดเกิน requirement
- User เลือก "Keep as usable"
- SKU ใหม่ถูก Consume ส่วนหนึ่ง (ตาม requirement)
- ส่วนเกิน → เก็บเข้า `component_overcut_inventory`
- `consumption_type = 'overcut_usable'`
- มี limit = actual - required

**Inventory Impact:**
- SKU ใหม่ถูก Split อีกครั้ง (usable vs over-cut)
- หรือ SKU ใหม่บางส่วน → `component_overcut_inventory` (status = `available`)

---

### 3. Waste (ตัดทิ้ง)

**Process:**
- ตัดเสีย
- ต้องกรอก defect/waste reason
- SKU ถูก Consume → บันทึกใน `leather_consumption`
- `consumption_type = 'waste'`
- มี `waste_reason`

**Inventory Impact:**
- SKU เปลี่ยนสถานะเป็น `consumed`
- ไม่ได้ใช้ (waste)

---

## 🔗 SKU Movement Flow (Traceability Chain)

### Example: Hatthasilpa CUT Node (V3 Final - Dynamic Selection)

```
HIDE-001 (25 sq.ft, status: available)
  ↓ [Dynamic Select - Component BODY batch (เลือกตอนเริ่มงาน)]
HIDE-001 (status: in_use, leather_usage record created)
  ↓ [CUT: ช่างกรอก actual_cut = 12 usable]
  ↓ [Finalize Sheet: Remaining ~13 sq.ft]
  ├─ Option 1: Register as SCRAP → SCRAP-001-L (13 sq.ft, SKU ใหม่)
  ├─ Option 2: Return to Inventory → HIDE-001 (status: available, area: 13 sq.ft)
  └─ Option 3: Used Up → HIDE-001 (status: consumed)
     ↓ [Consume: BODY component bundle]
     Record in leather_consumption (usable: 12)
     ↓ [Over-cut: ถ้ามี → component_overcut_inventory]
```

**Note**: Hatthasilpa = Dynamic Selection + Full SKU movement (Hermès level)

---

### Example: Classic MO Material Issue (Simplified Mode 2)

```
HIDE-001 (25 sq.ft, status: available)
  ↓ [Material Issue for MO 456 - เบิกทั้งผืน]
HIDE-001 (status: reserved, reserved_for: MO_456)
  ↓ [Work Execution - ไม่ track รายละเอียด]
  ↓ [MO Complete - Declare Scrap รวม]
HIDE-001 (status: consumed, consumed_by: MO_456)
  ↓ [User กรอก: Remaining Scrap = 3 sq.ft]
  Leather Scrap Pool (color: Mint, size: M, area: 3 sq.ft, object_id: NULL, is_aggregated: TRUE)
```

**Key Points:**
- Classic = เบิกทั้งผืน, ไม่ split SKU
- Scrap = Pool (aggregated), ไม่รู้ relationship 1:1
- แต่รู้ระดับ "MO นี้ใช้ไปประมาณเท่านี้ เหลือเท่านี้"

---

## 🎯 Implementation Roadmap

### Phase 1: Hatthasilpa CUT Node Enhancement

1. **UI Changes**
   - แยก input ตาม Component (ไม่ใช่รวม)
   - เพิ่มช่อง "ตัดได้จริง" และ "ตัดเสีย" ต่อ Component
   - เพิ่ม checkbox "Keep as usable over-cut"
   - เพิ่ม field "Waste reason" (ถ้า waste > 0)

2. **Backend Logic**
   - Validate: `actual = usable + waste`
   - Calculate over-cut: `overcut = usable - required` (if > 0)
   - ถ้า user เลือก "Keep as usable":
     - บันทึกเข้า `component_overcut_inventory`
     - Set limit = overcut quantity
   - ถ้า waste > 0:
     - บันทึก waste reason
     - Decrease inventory normally

3. **Material Selection**
   - รองรับเลือก Full Sheet
   - รองรับเลือก Scrap S/M/L
   - Auto-generate scrap S/M/L หลังตัด (Hatthasilpa only)

---

### Phase 2: Classic Line Material Issue

1. **Material Requirement**
   - สร้าง Material Requirement ตาม BOM ตอนสร้าง MO
   - Store ใน `material_requirement` table
   - Status: "pending" (ยังไม่ออกของ)

2. **Material Issue UI**
   - ก่อน Start MO → บังคับให้ Material Issue
   - UI ให้เลือกวัสดุ (Full Sheet / Scrap)
   - Validate: Total >= Required
   - บันทึก Material Issue transaction

3. **Inventory Update**
   - ตัด stock ตอน Issue (ไม่ใช่ตอนตัดจริง)
   - Move to WIP หรือ Reserved status
   - Status: "issued" (ออกของแล้ว)

4. **Workflow Integration**
   - Classic MO workflow ไม่ต้อง track material อีก
   - แค่ Start / Pause / Complete
   - Material ถือว่าใช้หมดแล้วตอน Issue

---

### Phase 3: Over-cut Management

1. **Over-cut Inventory**
   - Table: `component_overcut_inventory`
   - Fields: `component_code`, `quantity`, `limit`, `mo_id`, `created_at`
   - Limit = original over-cut quantity

2. **Over-cut Usage**
   - งานอื่นใช้ over-cut → ลด limit
   - Warehouse สามารถปรับ limit ได้
   - ไม่กระทบ MO เดิม

3. **Over-cut Reporting**
   - Dashboard แสดง over-cut ที่เหลือ
   - งานไหนใช้ over-cut ไปบ้าง
   - Limit tracking

---

## 📊 Database Schema Changes

### ⭐ Core Tables (SKU-Level Tracking)

#### 1. `leather_object` (SKU Master Table)
```sql
CREATE TABLE leather_object (
    id_object INT PRIMARY KEY AUTO_INCREMENT,
    sku_code VARCHAR(100) UNIQUE NOT NULL,  -- e.g., "HIDE-001", "HIDE-001-A", "SCRAP-001-S"
    status ENUM('available', 'reserved', 'cutting', 'consumed', 'split', 'scrap') NOT NULL DEFAULT 'available',
    source_object_id INT NULL,  -- FK → leather_object.id_object (ผืนต้นฉบับ)
    color_code VARCHAR(50),
    area_sqft DECIMAL(10,2),
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    INDEX idx_status (status),
    INDEX idx_sku_code (sku_code),
    FOREIGN KEY (source_object_id) REFERENCES leather_object(id_object) ON DELETE SET NULL
);
```

**Key Fields:**
- `sku_code`: Unique identifier (ทุกผืน = 1 SKU)
- `status`: Lifecycle state
- `source_object_id`: Traceability chain (รู้ว่าผืนไหนมาจากผืนไหน)

---

#### 2. `leather_reservation` (Reservation System)
```sql
CREATE TABLE leather_reservation (
    id_reservation INT PRIMARY KEY AUTO_INCREMENT,
    object_id INT NOT NULL,  -- FK → leather_object.id_object
    reserved_for_type ENUM('token', 'mo') NOT NULL,
    reserved_for_id INT NOT NULL,  -- token_id หรือ mo_id
    reserved_at DATETIME NOT NULL,
    reserved_by INT NOT NULL,  -- user_id
    released_at DATETIME NULL,
    status ENUM('active', 'released', 'consumed') NOT NULL DEFAULT 'active',
    INDEX idx_object (object_id),
    INDEX idx_reserved_for (reserved_for_type, reserved_for_id),
    FOREIGN KEY (object_id) REFERENCES leather_object(id_object) ON DELETE CASCADE
);
```

**Business Rules:**
- 1 SKU สามารถ reserved ได้แค่ 1 งาน (ไม่ซ้ำ)
- เมื่อ reserved → ห้ามใช้กับงานอื่นจนกว่าจะ release/consume

---

#### 3. `leather_split` (CUT Operation)
```sql
CREATE TABLE leather_split (
    id_split INT PRIMARY KEY AUTO_INCREMENT,
    source_object_id INT NOT NULL,  -- FK → leather_object.id_object (ผืนต้นฉบับ)
    token_id INT NULL,  -- สำหรับ Hatthasilpa
    mo_id INT NULL,  -- สำหรับ Classic
    split_type ENUM('cut_half', 'cut_custom', 'generate_scrap') NOT NULL,
    created_at DATETIME NOT NULL,
    INDEX idx_source (source_object_id),
    FOREIGN KEY (source_object_id) REFERENCES leather_object(id_object) ON DELETE CASCADE
);
```

#### 3.1. `leather_split_output` (SKU Outputs)
```sql
CREATE TABLE leather_split_output (
    id_output INT PRIMARY KEY AUTO_INCREMENT,
    split_id INT NOT NULL,  -- FK → leather_split.id_split
    output_object_id INT NOT NULL,  -- FK → leather_object.id_object (SKU ใหม่)
    area_sqft DECIMAL(10,2) NOT NULL,
    output_type ENUM('usable', 'scrap_s', 'scrap_m', 'scrap_l') NOT NULL,
    FOREIGN KEY (split_id) REFERENCES leather_split(id_split) ON DELETE CASCADE,
    FOREIGN KEY (output_object_id) REFERENCES leather_object(id_object) ON DELETE CASCADE
);
```

---

#### 4. `leather_consumption` (Consumption Tracking)
```sql
CREATE TABLE leather_consumption (
    id_consumption INT PRIMARY KEY AUTO_INCREMENT,
    object_id INT NOT NULL,  -- FK → leather_object.id_object
    consumed_by_type ENUM('token', 'mo') NOT NULL,
    consumed_by_id INT NOT NULL,
    consumption_type ENUM('normal', 'waste', 'overcut_usable') NOT NULL DEFAULT 'normal',
    component_code VARCHAR(100) NULL,  -- สำหรับ Hatthasilpa
    quantity_used INT NOT NULL,
    waste_reason TEXT NULL,
    consumed_at DATETIME NOT NULL,
    INDEX idx_object (object_id),
    INDEX idx_consumed_by (consumed_by_type, consumed_by_id),
    FOREIGN KEY (object_id) REFERENCES leather_object(id_object) ON DELETE CASCADE
);
```

**Purpose**: บันทึกการบริโภควัสดุบนฐาน SKU movement (ไม่ใช่แค่ลด sq.ft)

---

#### 5. `material_issue` (Classic Line)
```sql
CREATE TABLE material_issue (
    id_issue INT PRIMARY KEY AUTO_INCREMENT,
    mo_id INT NOT NULL,
    issued_at DATETIME NOT NULL,
    issued_by INT NOT NULL,  -- user_id
    status ENUM('pending', 'issued', 'completed', 'cancelled') NOT NULL DEFAULT 'pending',
    INDEX idx_mo (mo_id)
);
```

#### 5.1. `material_issue_item` (SKU Items)
```sql
CREATE TABLE material_issue_item (
    id_item INT PRIMARY KEY AUTO_INCREMENT,
    issue_id INT NOT NULL,  -- FK → material_issue.id_issue
    object_id INT NOT NULL,  -- FK → leather_object.id_object (SKU ที่ถูก issue)
    quantity INT NOT NULL DEFAULT 1,
    area_sqft DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (issue_id) REFERENCES material_issue(id_issue) ON DELETE CASCADE,
    FOREIGN KEY (object_id) REFERENCES leather_object(id_object) ON DELETE CASCADE
);
```

---

#### 6. `component_overcut_inventory` (Enhanced)
```sql
CREATE TABLE component_overcut_inventory (
    id INT PRIMARY KEY AUTO_INCREMENT,
    mo_id INT NULL,
    token_id INT NULL,
    component_code VARCHAR(100) NOT NULL,
    object_id INT NULL,  -- FK → leather_object.id_object ⭐ NEW
    quantity INT NOT NULL,
    limit INT NOT NULL,  -- maximum quantity available
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    INDEX idx_token (token_id),
    INDEX idx_mo (mo_id),
    FOREIGN KEY (object_id) REFERENCES leather_object(id_object) ON DELETE SET NULL
);
```

**Enhancement**: ผูกกับ `leather_object` SKU เพื่อ traceability

---

#### 7. `leather_scrap` (Enhanced)
```sql
CREATE TABLE leather_scrap (
    id_scrap INT PRIMARY KEY AUTO_INCREMENT,
    object_id INT NOT NULL UNIQUE,  -- FK → leather_object.id_object ⭐ NEW (1 scrap = 1 SKU)
    color_code VARCHAR(50) NOT NULL,
    size ENUM('S', 'M', 'L') NOT NULL,
    area_sqft DECIMAL(10,2) NOT NULL,
    source_type ENUM('cut_output', 'mo_return', 'manual') NOT NULL,
    source_token_id INT NULL,
    source_mo_id INT NULL,
    created_at DATETIME NOT NULL,
    INDEX idx_color_size (color_code, size),
    FOREIGN KEY (object_id) REFERENCES leather_object(id_object) ON DELETE CASCADE
);
```

**Enhancement**: แต่ละชิ้น scrap = 1 SKU (trackable)

---

## 🔐 Business Rules

### Hatthasilpa CUT Node

1. **Component Tracking**
   - ต้องกรอก usable + waste ต่อ Component
   - Validate: `usable + waste = actual_cut`

2. **Over-cut Handling**
   - ถ้า usable > required → ถาม "Keep as usable?"
   - ถ้า YES → บันทึก over-cut + set limit
   - ถ้า NO → ไม่ track (ถือว่าใช้หมด)

3. **Waste Handling**
   - ถ้า waste > 0 → ต้องกรอก reason
   - Inventory ลดตามปกติ

4. **Material Selection**
   - เลือกได้: Full Sheet หรือ Scrap S/M/L
   - Auto-generate scrap หลังตัด

---

### Classic Line

1. **Material Requirement**
   - สร้างตอน MO creation
   - ตาม BOM
   - Status: pending

2. **Material Issue (Mandatory)**
   - ก่อน Start MO → ต้อง Issue ก่อน
   - เลือกวัสดุ (Full Sheet / Scrap)
   - Validate total >= required
   - ตัด stock ทันที

3. **Work Execution**
   - ไม่ต้อง track material อีก
   - แค่ Start / Pause / Complete
   - Material ถือว่าใช้หมดแล้ว

---

## ✅ Acceptance Criteria

### Hatthasilpa CUT Node

- [ ] UI แยก input ตาม Component
- [ ] Support over-cut usable (with checkbox)
- [ ] Support waste (with reason field)
- [ ] Support material selection (Full Sheet / Scrap)
- [ ] Auto-generate scrap S/M/L หลังตัด
- [ ] Track over-cut in `component_overcut_inventory`
- [ ] Limit tracking สำหรับ over-cut

### Classic Line

- [ ] Create Material Requirement จาก BOM
- [ ] Material Issue UI (ก่อน Start MO)
- [ ] Material Issue บังคับ (block Start ถ้ายังไม่ออกของ)
- [ ] ตัด stock ตอน Issue
- [ ] Classic workflow ไม่ต้อง track material

---

## 📝 Notes

### Why Two Different Approaches?

**Hatthasilpa (Premium/Craft)**:
- งานละเอียด → Track ราย Component ได้
- ค่าแรงสูง → ต้องรู้ waste/over-cut ละเอียด
- Batch เล็ก → จัดการได้

**Classic (Mass/Batch)**:
- งานใหญ่ → Track รายชิ้นจะพัง
- ต้อง Issue ล่วงหน้า → จับจุดเดียว
- Batch ใหญ่ → Aggregated tracking พอ

---

## 🚀 Next Steps

1. **Create Task Document** สำหรับแต่ละ Phase
2. **Design Database Schema** สำหรับ tables ใหม่
3. **Design API Endpoints** สำหรับ Material Issue
4. **Design UI/UX** สำหรับ CUT Node Component tracking
5. **Create Migration Scripts** สำหรับ database changes

---

---

## 🎯 สรุปหลักใหญ่: Two-Tier Approach (Finalized Dec 2025)

### ⭐ Core Principle: Different Standards for Different Lines

**Hatthasilpa = Hermès-Level Precision:**
- Full SKU movement (split สำคัญ ๆ = child SKU)
- Component-level tracking (Bundle หรือ Critical Components)
- Graph-based workflow
- Full traceability (1 scrap = 1 SKU)
- Over-cut: Exceptional flow (ไม่ใช่ main flow)

**Classic = Standard ERP Level:**
- Material Issue ก่อนเริ่มงาน (เบิกทั้งผืน)
- ไม่ split SKU ทุกครั้งตัด
- Scrap = Pool (aggregated per color/size)
- ปิด MO แล้ว declare scrap รวม
- ไม่ต้อง track การใช้วัสดุรายละเอียด

---

### หลักการพื้นฐาน (Balanced)

**หนังทุกผืน = 1 Object (SKU) เสมอ**

- Full hide 1 ผืน = 1 SKU
- Split สำคัญ ๆ → Child SKU (Hatthasilpa)
- Scrap Classic → Pool (ไม่ต้อง SKU แยกทุกชิ้น)
- Scrap Hatthasilpa → สามารถละเอียดกว่าได้

### Reservation System (Two-Tier: Hatthasilpa vs Classic)

**⚠️ IMPORTANT (V3 Final): Hatthasilpa และ Classic ใช้วิธีต่างกัน**

**🟧 Hatthasilpa: Dynamic Selection (ไม่ใช่ Reserve ล่วงหน้า)**
- **ห้าม reserve ล่วงหน้า**
- ช่างเลือกหนังตอนเริ่มงาน component → ระบบ record (Soft Lock)
- Sheet ถูก "เลือกใช้" ใน component นี้ (ไม่ให้ component อื่นเลือก)
- บันทึกใน `leather_usage` (not `leather_reservation`)
- Pattern: "Dynamic Selection → Soft Lock → Cut → Finalize"

**🟦 Classic: Material Issue (Reserve ล่วงหน้า)**
- **บังคับ Material Issue ก่อนเริ่มงาน** (Reserve ล่วงหน้า)
- ชิ้นนี้ใช้กับ MO นี้
- บันทึกใน `leather_reservation`:
  - `reserved_for_type = 'mo'`
  - `reserved_for_id = mo_id`
- Pattern: "Reserve → Issue → Work → Consume"

**Default: Soft Lock (ห้ามใช้กับงานอื่น)**

**Exception: Override Selection/Reservation**
- ต้องมีสิทธิ์สูง (Owner/Manager/Supervisor)
- ระบบ log + warning
- Pattern: "Lock ตามหลัก, Allow override พร้อม log"

---

### SKU Movement = Traceability (Balanced - V3 Final)

**Hatthasilpa:**
- Material Consumption = SKU movement (Dynamic Selection)
- Flow: `HIDE-001 → Dynamic Select → Cut → Finalize → Split/Consume/Return`
- ⚠️ **ไม่ใช่ Reserve ล่วงหน้า** → เลือกหนังตอนเริ่มงาน component

**Classic:**
- Material Consumption = เบิกทั้งผืน → Consume (Reserve ล่วงหน้า)
- Flow: `HIDE-001 → Reserve (Material Issue) → Work → Consume → Declare Scrap Pool`

นี่คือหัวใจของ Traceability ที่ **เหมาะสมกับแต่ละ production line**

---

**Last Updated**: 2025-12-10 (Revised based on real-world factory feedback)  
**Status**: Finalized Concept - Ready for Implementation  

**Enhancement History**: 
- Added SKU-Level Tracking & Reservation System (Dec 2025)
- Revised to Two-Tier Approach: Hatthasilpa (Hermès-level) vs Classic (Standard ERP)
- Balanced SKU tracking (ไม่ใช่ full movement ทุกครั้ง)
- Soft Reservation + Audit (ไม่ใช่ hard lock)
- Cut Bundle / Critical Components (ไม่ใช่ทุก component)
- Over-cut as Exceptional Flow (ไม่ใช่ main flow)

**Latest Additions (Dec 2025 - Critical Implementation Details + V3 Final Unified Master Spec):**
1. ✅ Remnant Size Classification Logic (≥ 6 sq.ft = SKU, 1–6 sq.ft = Scrap L/M, < 1 sq.ft = Scrap S)
2. ✅ Physical Labeling Method (เขียนมือสำหรับ remnant ใหญ่)
3. ✅ Remnant Registration Workflow (Supervisor-operated UI)
4. ✅ Rules for Using Remnant in Next Jobs (Dynamic Selection required, No auto-split)
5. ✅ Strict Selection Rules (Hatthasilpa - ห้ามหยิบตามใจ, ต้องผ่าน UI)
6. ✅ Override Reservation Exception Handling (Audit log with reason)
7. ✅ Classic Line Scrap Conversion Timing (Return-to-Scrap-Pool at MO Complete)
8. ✅ Critical Component Concept (BODY/FLAP/STRAP/GUSSET only)
9. ✅ Enhanced CUT UI Logic (Over-cut popup, Waste reason required)
10. ✅ Human-Friendly UX for Remnant Search (Visual selection, not text list)
11. ✅ **3-Layer Architecture (BOM vs Graph vs Node Behavior vs Inventory)** - แยกความเข้าใจระหว่าง 4 เลเยอร์ให้ชัดเจน
12. ✅ **Critical Component Bundle Definition** - ระบุชัดว่า bag completion = minimum ของ Critical Components
13. ✅ **Serial Mapping Scope** - ระบุชัดว่า serial mapping = Critical Components only
14. ✅ **Mandatory Split Rule** - ระบุชัดว่า remnant ≥ 6 sq.ft → MUST split SKU อัตโนมัติ
15. ✅ **Non-critical Visibility Rule** - ระบุชัดว่า non-critical ต้องมีใน CUT UI เสมอ ห้ามซ่อน/ลบ/skip
16. ✅ **⭐ FIRST PRINCIPLE: Graph = Process Engine (ไม่ใช่ Component Engine)** - Reframed เพื่อป้องกัน AI over-design
17. ✅ **CUT Node Batch Workflow (V3 Final)** - Work Queue รวม tokens เป็น Batch Card, CUT Workspace แต่ละ Component มี Start/Finish ของตัวเอง, **Dynamic Material Selection** (ไม่ใช่ Reserve ล่วงหน้า), **Sheet Finalization** mandatory before Close Node, SCRAP Registration workflow
18. ✅ **Component Queue / Component Output Schema (Conceptual Design)** - Database schema สำหรับ Component Output จาก CUT Node และ Component Queue สำหรับ Downstream Nodes (ต้อง design รายละเอียดใน Phase Implementation)

---

## 💡 คำตอบสำหรับ Agent — Design Rationale (Critical for Implementation)

**⚠️ สำคัญมาก: อ่านส่วนนี้ก่อนเริ่ม Implementation เพื่อเข้าใจ "WHY" หลังการตัดสินใจทุกอย่าง**

---

### ⭐ CRITICAL: Graph = Process Engine, Not Component Engine

**⚠️ FIRST PRINCIPLE: Graph ขับเคลื่อน Process ไม่ใช่ Components**

**กฎง่าย ๆ:**

1. **Graph ขับเคลื่อน Process ไม่ใช่ Components**
   - Node = จุดที่ "งาน" วิ่งผ่าน
   - ไม่ได้เป็นตัวแทน "ชิ้นส่วนทีละชิ้น"

2. **ช่างเป็นเจ้าของ How-to ใน Node**
   - ระบบไม่สั่งว่าจะตัด reinforcement ชิ้นไหนก่อน
   - ระบบมีหน้าที่จับเวลา, บันทึกว่าใครทำ, เกิดอะไรขึ้น โดยไม่ก้าวก่ายเทคนิค

3. **Component ใช้แค่เพื่อ:**
   - ทำ BOM / Material Requirement
   - Traceability ในระดับ Critical
   - บอกได้ว่า "ใบนี้สำเร็จ" เมื่อ Critical group ครบ

4. **Graph เล่าแค่:**
   - งานชุดไหนวิ่งสายไหน
   - มีสายไหนทำขนานกันได้
   - เมื่อไรทุกสายพร้อมเข้าสู่ Assembly / QC / Pack

5. **สิ่งที่ไม่ควรทำ:**
   - ไม่ต้องแตกทุก Non-critical Component ออกเป็น Node
   - ไม่ต้องทำ Graph ตามโครงสร้างชิ้นส่วน 1:1
   - ไม่ต้องเอา Graph มาคุมทุกการขยับมือของช่าง

---

### ⭐ Non-critical Components (Resolved — V3 Final)

**สรุปสุดท้าย: Non-critical ไม่ต้องแยกตาม node**

**แต่ต้องอยู่ใน BOM เพื่อ:**
- ให้ระบบรู้ว่าต้องใช้หนังชนิดใด
- ให้ CUT รวมยอดออกมาได้ถูกต้อง
- ให้ Reserve/Log ทำงานได้

**แต่ไม่ต้อง:**
- Track รายชิ้น
- ผูกกับ Node เอง

---

### ⭐ Critical Components (Resolved — V3 Final)

**ใช้เพื่อ:**
- การคำนวณขั้นต่ำของงาน (minimum formula)
- Serial Number binding
- QC mapping
- Material usage logic

**Critical ได้แก่:**
- BODY Front/Back
- FLAP
- STRAP
- GUSSET
- BASE

**แต่ "ไม่จำเป็นต้องสร้าง node แยก"**

**แค่ระบุว่า Critical เพื่อคำนวณ supply chain ให้ถูกต้อง**

---

### ⭐ Classic Line (Resolved — V3 Final)

**Classic ไม่ใช้ CUT Logic แบบ Hatthasilpa**

**เพราะเป็น batch large-volume production**

**แต่ใช้กฎ:**
- เบิกหนังเป็นผืนล่วงหน้า (Material Issue)
- ช่างตัดตามจำนวน batch
- Material consumption ตัดยอดตามจำนวนสินค้า
- Scrap เกิดขึ้น → ลงทะเบียน S/M/L แบบเดียวกับ Hatthasilpa
- **ไม่ต้องใช้ dynamic sheet selection** (ต่างจาก Hatthasilpa)

---

### ⭐ CUT Node Batch Workflow Summary (Implementation Steps)

**Step-by-step สำหรับ Agent Implementation:**

**1. Work Queue (CUT node only)**
- Group tokens by `(product_id, node_id, assignee_id)` → 1 Batch Card
- Card ไม่มี Start/Pause → มีแค่ `[Open CUT Workspace]`

**2. CUT Workspace**
- แสดง components จาก BOM (ทุกตัวที่ต้องตัด)
- แต่ละ component row มี:
  - `required_per_unit`, `required_total`
  - `material_selection_slot` (Leather Sheet / Scrap selector)
  - `status` (not_started, in_progress, done)
  - `[Start]` / `[Finish]` ปุ่มของตัวเอง

**3. Before Start Component**
- บังคับให้เลือกหนัง (ผ่าน leather_sheet selector)
- คำนวณ approx capacity
- ถ้าเพียงพอ → enable `[Start]`
- **⚠️ Start button disabled จนกว่าจะเลือกหนังให้เสร็จก่อน**

**4. On Start Component**
- Set `component_status = 'in_progress'`
- บันทึก `time_start` (สำหรับ productivity)
- UI highlight row → "กำลังตัดอยู่"
- ช่างทำงานบนโต๊ะ → ระบบจับเวลา background

**5. On Finish Component**
- Modal 1: กรอก `actual_cut`
- กรณี `actual > required` → Modal 2: classify over-cut (usable vs waste)
- กรณี `actual < required` → Modal 3: Cut short handling (continue/withdraw/mark used)
- Set `component_status = 'done'` (ถ้า actual >= required)
- เขียนผลลง payload + inventory logic

**6. Sheet Finalization (MANDATORY before Close Node)**
- สำหรับทุก sheet ที่ใช้ → Modal: Finalize Sheet
- Options: Used Up (WASTE) / Register as SCRAP / Return to Inventory
- System auto-detect size classification
- ถ้าช่างไม่เลือก → ปิด Node ไม่ได้

**7. SCRAP Registration (ถ้าเลือก Register as SCRAP)**
- UI Form: Approx width/height, Surface condition, Estimated sq.ft, Size (S/M/L)
- Physical Labeling: เขียนรหัส + ขนาด
- System: สร้าง `leather_object` SKU (≥ 6 sq.ft) หรือเพิ่มเข้า scrap pool

**8. Close CUT Node (Batch)**
- เมื่อ components ที่จำเป็นครบ (`status = 'done'`)
- เมื่อทุก sheet Finalize เรียบร้อยแล้ว
- คำนวณจำนวนใบที่ได้จริงจาก critical components (min formula)
- อัปเดต token ทั้งชุดว่าพร้อมไป node ถัดไป (`state = ready`)

---

### ✅ จุดสำคัญที่ตรงกับแนวคิดหลัก

**1. Node CUT ไม่ใช่ใบต่อใบ**
- Work_queue ใช้ "Card รวม" ต่อ product / node / assignee
- ไม่ใช่ token ละ card แล้วกด start ทีละใบ

**2. Graph ยังเป็น Process Engine เหมือนเดิม**
- Graph แค่บอกว่า: มาถึง Node CUT แล้ว, งาน batch ไหนอยู่ที่ช่างคนไหน
- "ตัดอะไร, ตัดกี่ชิ้น, layout บนหนังยังไง" = อยู่ใน Node Behavior + ฝีมือช่าง

**3. ความจำเป็นในการกรอก "จำนวนที่ตัดได้"**
- เพราะ Node CUT = งาน batch รวม
- จึงต้องมีแบบฟอร์มสรุปหลังจบงาน batch (ไม่ใช่กรอกระหว่างทำ)
- ข้อมูล "จำนวนชิ้นที่ได้ต่อ component" เป็นสิ่งเดียวที่ระบบต้องรู้เพื่อ:
  - คำนวณว่าทำได้กี่ใบ
  - คำนวณ scrap/waste/overcut
  - ผูกกับการใช้วัสดุที่ reserve มา

**4. เลือกหนังเป็น "Dynamic Selection ตอนทำงาน" (ไม่ใช่ Reserve ล่วงหน้า)**
- ⚠️ **Hatthasilpa ห้าม reserve ล่วงหน้า**
- ช่างเลือกหนังตอนเริ่มงาน component → ระบบ record ตามจริง
- **Flow: Start button disabled จนกว่าจะเลือกหนังให้เสร็จก่อน**
- เลือกได้แค่ "ทีละแผ่น / ต่อ component run" เท่านั้น

**5. Sheet Finalization = Mandatory Before Close Node**
- ก่อน Complete node → ระบบบังคับให้ Finalize Sheet
- Options: Used Up (WASTE) / Register as SCRAP / Return to Inventory
- System auto-detect size classification
- ถ้าช่างไม่เลือก → ปิด Node ไม่ได้

---

### 1) ทำไมระบบไม่ Track ทุก Component ของกระเป๋า?

**⚠️ IMPORTANT: แยก 3 คำถามให้ชัดเจน**

มี 3 คำถามที่มักถูกเข้าใจผิดว่าเป็นคำถามเดียวกัน:

1. **BOM / Product Config ต้องมี Non-critical ไหม?**
   - ✅ **คำตอบ: ต้องมีครบทุก component (Critical + Non-critical)**

2. **Node CUT ต้องรู้จัก Non-critical ไหม?**
   - ✅ **คำตอบ: ต้องรู้ว่าต้องตัดอะไร "ทั้งหมด" ที่มีการตัดจริง**

3. **Inventory & Traceability ต้องลงรายละเอียด Non-critical ระดับเดียวกับ BODY/FLAP ไหม?**
   - ✅ **คำตอบ: ไม่จำเป็นต้อง track Non-critical ละเอียดเท่า Critical**

---

#### 🧱 Layer 1: BOM = Single Source of Truth

**กฎสุดแข็ง:**
- **ทุกชิ้นที่อยู่ในกระเป๋า = ต้องอยู่ใน BOM เสมอ**
- **Critical**: BODY / FLAP / STRAP / GUSSET
- **Non-critical**: piping, edge binding, card slot patch, reinforcement, logo tab

**ถ้าไม่อยู่ใน BOM → ไม่มีอะไรไปสั่งให้เบิกหนังมา**

---

#### 🧩 Layer 2: Node CUT = ต้องรู้ทุกอย่างที่ต้องตัด

**หลักการ:** ถ้ามีอะไรต้องตัดจริงบนโต๊ะ → Node CUT ต้องรู้ว่าต้องตัดมัน

**Critical Components (ต้องละเอียด):**
- Component-level tracking
- Usable/Waste per component
- Over-cut tracking
- Waste reason required

**Non-critical Components (ต้อง "มี", แต่ไม่ต้องละเอียดเท่า):**
- แสดงใน UI ให้เห็นลิสต์ของที่ต้องตัด
- รู้ required quantity
- กรอก actual รวม (พอปิด node ได้)
- **ไม่ต้อง:** แยก usable per piece, คิด over-cut per component, Split SKU แยกราย component

**สรุป:** Critical / Non-critical ต่างกันที่ **"ระดับข้อมูลที่กรอก"** ไม่ใช่ **"มี/ไม่มีในระบบ"**

---

#### 📦 Layer 3: Inventory & Traceability = Two-tier

**Critical Components:**
- ละเอียด (ดีเทลระดับ Hermès)
- Track per component
- Over-cut tracking
- Waste reason required
- Serial mapping

**Non-critical Components:**
- Aggregate แต่ไม่ ignore
- Consumption คิดรวม per material
- ไม่ต้อง track per non-critical piece
- ไม่ต้องมี scrap/overcut per non-critical component

**สรุป:** ไม่ต้อง track Non-critical components ด้วย granularity เดียวกับ Critical ใน inventory

---

#### 🔥 ระบบยัง "รู้ครบว่าทำได้กี่ใบ" เพราะ derive ได้:

```
จำนวนใบที่ทำได้ = minimum(
  BODY.usable / BODY.required,
  FLAP.usable / FLAP.required,
  STRAP.usable / STRAP.required,
  GUSSET.usable / GUSSET.required
)
```

**Note:** Non-critical ไม่ได้ใช้ในการคำนวณ "ทำได้กี่ใบ" เพราะไม่ใช่ bottleneck

---

### 2) แล้วถ้าไม่ป้อนจำนวนทุกชิ้น ระบบรู้ได้อย่างไรว่าตัดครบหรือยัง?

**คำตอบ:** เพราะ **"ครบใบ"** นิยามด้วย Critical Components เท่านั้น

**แต่:**
- **Non-critical ต้องปรากฏใน Node CUT UI** (เพื่อให้ช่างรู้ว่าต้องตัดอะไร)
- **Non-critical ต้องกรอก actual** (อย่างน้อยพอปิด node ได้)
- **Non-critical ไม่ได้ใช้ในการคำนวณ "ทำได้กี่ใบ"** (เพราะไม่ใช่ bottleneck)

ดังนั้น:
- ถ้า Critical ครบ → ใบนี้ประกอบได้
- ถ้าขาดชิ้นเดียว → ใบนี้ประกอบไม่ได้
- ชิ้นเล็ก (non-critical) กรอก actual รวม → ไม่ต้องละเอียดเท่า Critical

**นี่คือหลักการเดียวกับ Hermès และโรงงาน craft ระดับโลก**

โรงงาน luxury ไม่มีใครบันทึก ทุก lining piece แบบละเอียดเท่า Critical เพราะมันฆ่าความเร็ว และ ROI ไม่คุ้ม

---

### 3) ทำไมไม่เก็บข้อมูลเป็นราย component ทั้งหมดในระบบแบบละเอียดเท่ากัน?

**คำตอบสั้นที่สุด:**

เพราะการเก็บข้อมูลมากเกินไป **ทำลาย usability, ทำให้ช่างใช้ไม่ได้จริง**, และ **ไม่ได้เพิ่มความแม่นยำของกระบวนการผลิตเลย**

**สิ่งที่ต้องทำ:**
- **BOM**: เก็บครบทุก component (Critical + Non-critical) ✅
- **Node CUT UI**: แสดงทุก component ที่ต้องตัด ✅
- **Non-critical กรอก actual รวม** (พอปิด node ได้) ✅

**สิ่งที่ "ไม่ต้องทำ" แบบละเอียด:**
- ไม่ต้อง track Non-critical components ด้วย granularity เดียวกับ Critical ใน inventory
- ไม่ต้องมี scrap/overcut per non-critical piece
- ไม่ต้อง map serial → non-critical
- ไม่ต้องแยก usable per non-critical piece (กรอก actual รวมพอแล้ว)

**ช่างไม่สามารถ:**
- ตัด 15 ชิ้น แล้วไปกดใส่ 15 ช่องแบบละเอียด
- กรอก lining 8 ชิ้น แบบแยกรายชิ้น
- กรอก pocket piece 2 ชิ้น แบบมี waste reason ทุกชิ้น

**โรงงานจะชะงักทันที**

**แต่ถ้าแยกระดับความละเอียด:**
- Critical: ละเอียด (usable/waste/over-cut) → **ทำงานได้จริง**
- Non-critical: Aggregate (actual รวม) → **ทำงานได้จริง**
- → **ระบบยังนับงานได้แม่น 100%**

---

### 4) ทำไมระบบต้องให้กรอกเฉพาะ "จำนวน usable" เท่านั้น?

**คำตอบ:** เพราะสูตรนี้ง่ายที่สุดสำหรับช่าง และระบบ derive อย่างอื่นเองได้:

```
waste = actual_cut - usable
overcut = usable - required
```

**ช่างกรอกแค่:**
- `usable` (required)
- `waste` (required, ถ้ามี)

**ส่วน `actual_cut = usable + waste`** → derive ได้ทันที

**ไม่ต้องให้ช่างคิด → ไม่ผิดพลาด**

---

### 5) ทำไม Over-cut ต้องเป็น "Exceptional Flow"?

**คำตอบ:** เพราะจากข้อมูลโรงงานทั่วโลก:

- Over-cut ไม่ได้เกิดบ่อย
- ถ้าเกิด ช่างจะตัดเพิ่มขึ้นมา 1–2 ชิ้นเท่านั้น
- **ไม่ใช่เหตุการณ์ปกติ**

ดังนั้นระบบต้องรองรับ แต่ไม่ต้องเป็น main flow

---

### 6) ทำไม Scrap ไม่ควร Track ทุกชิ้นเสมอไป?

**คำตอบง่ายที่สุด:**

เพราะเศษ 0.2–1 sq.ft มีมูลค่าต่ำมาก และโรงงานไม่สามารถติด Sticker/Barcode ได้ทุกชิ้น (ยุ่งมือเกินไป)

**โมเดลที่เหมาะที่สุดคือ:**
- `< 1 sq.ft` → S Pool (aggregate)
- `1–3 sq.ft` → M Pool (aggregate)
- `3–6 sq.ft` → L Pool (aggregate)
- `≥ 6 sq.ft` → ต้องติด label + เป็น SKU แจ้งระบบ

**นี่คือสมดุลระหว่าง accuracy และ usability**

---

### 7) ทำไมต้องใช้ Reservation System?

**คำตอบ:** เพราะ:

- ถ้าไม่ reserve หนัง → ช่างอีกโต๊ะจะหยิบไปก่อน
- เกิด stock mismatch
- เกิด WIP mismatch
- เกิด production delay
- เกิด scrap ไม่สัมพันธ์กับงาน

**Reservation = Soft Lock**

**แต่:**
- ต้องมี override (มี log)
- ไม่ใช่ hard lock

**เพราะในสถานการณ์จริง:**
- ช่างอาจต้องหยิบด่วน
- งานเร่ง
- ชิ้นที่ reserve ผิดสี

**ERP ดีๆ ต้องยืดหยุ่นทั้งการ Lock และ Override**

---

### 8) ทำไม Classic Line ไม่ต้องมี Node Behavior?

**คำตอบ:** เพราะ:

- งาน batch 50–200 ใบไม่สามารถ track ราย component
- ช่างหยิบถูก/ผิด ไม่มีใครยืนยันได้
- Granular tracking → เพิ่มงาน 20 เท่า
- ทำให้ช่างไม่ใช้ระบบ

**แต่ Classic Line มีวิธีที่ดีที่สุดอยู่แล้ว:**

**"บังคับ Material Issue ก่อนเริ่มงาน"**

- → ระบบรู้แน่ชัดว่าใช้ผืนไหน
- → ระบบคำนวณ scrap ตอนปิดงาน
- → ไม่ต้องจุกจิกกลาง workflow

**นี่คือ pattern ของ SAP, Oracle, Dynamics, NetSuite**

---

### ✔ สรุปคำตอบแบบที่ Agent ต้องได้

1. **Graph = Process Engine, ไม่ใช่ Component Engine**
   - Graph ขับเคลื่อน Process ไม่ใช่ Components
   - Node = จุดที่ "งาน" วิ่งผ่าน, ไม่ได้เป็นตัวแทน "ชิ้นส่วนทีละชิ้น"
   - Components อยู่ใน BOM และ Node Behaviors, ไม่ใช่ Graph structure

2. **BOM = Single Source of Truth**
   - ต้องมีครบทุก component (Critical + Non-critical) ✅
   - ถ้าไม่อยู่ใน BOM → ไม่มีอะไรไปสั่งให้เบิกหนังมา

3. **CUT Node = Batch Workflow (ไม่ใช่ Token-by-Token)**
   - Group tokens โดย (product_id, node_id, assignee_id) → 1 Batch Card
   - Card มีปุ่มเดียว: "เข้าสู่หน้าตัด (CUT Workspace)"
   - แต่ละ Component ใน Workspace มี Start/Finish ของตัวเอง

4. **Node CUT Workspace = ต้องรู้ทุกอย่างที่ต้องตัด**
   - Critical / Non-critical ต่างกันที่ **"ระดับข้อมูลที่กรอก"** ไม่ใช่ **"มี/ไม่มีในระบบ"**
   - Critical: ละเอียด (usable/waste/over-cut per component)
   - Non-critical: Aggregate (actual รวม, พอปิด node ได้)

5. **Material Selection = Required Before Start**
   - **Start button disabled จนกว่าจะเลือกหนังให้เสร็จก่อน**
   - ป้องกันปัญหา "กด Start พร้อมกันสอง batch ที่แย่งวัสดุกันใช้"

6. **Inventory & Traceability = Two-tier**
   - Critical → ละเอียด (ดีเทลระดับ Hermès)
   - Non-critical → Aggregate แต่ไม่ ignore (consumption คิดรวม per material)

7. **ระบบยังรู้ครบว่า "ตัดได้กี่ใบ"** เพราะ derive จาก Critical เท่านั้น  
   - Non-critical ไม่ได้ใช้ในการคำนวณ (เพราะไม่ใช่ bottleneck)

8. **Scrap ต้องเป็น 2 โหมด:**
   - Hatthasilpa → track remnant ใหญ่เป็น SKU (≥ 6 sq.ft)
   - Classic → scrap pool (aggregate per color/size)

9. **Material Selection/Reservation จำเป็น** เพราะกันไม่ให้ผืนหนังถูกใช้ผิดงาน  
   - **Hatthasilpa**: Dynamic Selection (ไม่ใช่ Reserve ล่วงหน้า) + Soft lock + override (with audit)
   - **Classic**: Material Issue (Reserve ล่วงหน้า) + Soft lock + override (with audit)

10. **Classic Line ไม่ต้องใช้ Node** เพราะ workflow ต่าง  
    - ใช้ Material Issue ก่อนเริ่มงานแทน

11. **ไม่มีเคสไหนที่ระบบ "ไม่รู้จะสั่งให้ใครตัด / เบิกหนังยังไง"**
    - ถ้าเดินตามโมเดลนี้ (BOM → Material Requirement → Reservation → Node CUT)

12. **Component Flow vs Process Flow:**
    - **Process Flow** = Graph (Start → CUT → Stitch → QC → Assembly → Finish)
    - **Component Flow** = Component Mapping (BOM/Product Config)
    - CUT → Component Output (ไม่ผูก Token) → แต่ละ Component ไหลไป Node ถัดไปตาม Mapping
    - Downstream Nodes รับงานตาม Component Ready (ไม่ใช่ Token-based)
    - Assembly = Token Bundle (Critical Components minimum)
    - Token ใช้ track ระดับ macro (ใบงานแต่ละใบ) ไม่ใช่ component flow
    - Database Schema: Component Queue/Output tables (conceptual design - ต้อง design รายละเอียดใน Phase Implementation)

13. **แนวทางนี้คือจุดสมดุลที่สุดระหว่าง:**
    - ความแม่นยำ  
    - ความเร็ว  
    - ความเป็นจริงในโรงงาน  
    - ความเรียบง่ายของ UI  
    - Traceability ที่ทำงานได้จริง
    - Flexibility (Component เสร็จไม่เท่ากัน → ไปต่อได้เลย)

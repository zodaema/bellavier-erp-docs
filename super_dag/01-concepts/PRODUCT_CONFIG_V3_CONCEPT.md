# Product Configuration V3 - Conceptual Foundation
**Version:** 3.0  
**Date:** 2025-12-25  
**Status:** 🎯 **CORE CONCEPT** - Foundation for Node Behavior Phase  
**Category:** SuperDAG / Product Architecture / Component-Centric Design

> **Conceptual alignment update — V3 crystallization (2025-12-25)**  
> This document reflects the final, crystallized V3 philosophy where Graph is Absolute Source of Truth, Product Config is Intent/Constraints/Invariants ONLY, and Component is the Unit of Work.

---

## Executive Summary

**Product Configuration** คือ Single Source of Truth (SSOT) ที่บรรยาย "ความตั้งใจ" (Intent) ของ Product หนึ่งชิ้นในระดับ Component โดยไม่กำหนด "วิธีทำ" (Instruction) ให้กับ Node

**ทำไมต้องมาก่อน Node Behavior Phase:**
- Node Behavior จะเป็นผู้ตัดสินใจ "ทำอย่างไร" ตาม Product Config ที่กำหนด "ต้องได้อะไร"
- ถ้าไม่มี Product Config ที่ชัดเจน Node Behavior จะไม่มีข้อมูลเพียงพอในการตัดสินใจ
- Product Config เป็น Contract ระหว่าง Product Designer กับ Runtime System

**Core Philosophy:**
> Product Config = "What must be achieved"  
> Node Behavior = "How to achieve it"

**⚠️ CRITICAL ARCHITECTURAL TRUTH:**
> Graph = Law (Absolute Source of Truth)  
> Graph declares Component Slots / Anchors  
> Product = Applicant (binds to Graph)  
> Product satisfies Graph's Component Slots with specifications  
> Product cannot invent components — only Graph declares them

---

## Design Principles

### 1. Single Source of Truth (SSOT)

**Graph is the Absolute Source of Truth:**
- Graph declares all Component Slots / Anchors
- Graph defines all production logic, routing, parallelism, and QC boundaries
- No actor may override Graph logic

**Product Config is SSOT for Intent/Constraints/Invariants:**
- Product Config เป็นแหล่งข้อมูลเดียวที่บอกว่า Component แต่ละ Slot ต้องมีคุณสมบัติอย่างไร (dimensions, thickness, material, lining requirement)
- Product Config ไม่ได้กำหนดว่า Product ประกอบด้วย Components อะไร — Graph เป็นคนกำหนด Component Slots
- Product binds to Graph และ satisfy Component Slots ที่ Graph กำหนดด้วย specifications
- ไม่มีข้อมูล Product Config กระจัดกระจายอยู่ใน Graph หรือ Node Config

### 2. Minimal but Sufficient
เก็บเฉพาะข้อมูลที่จำเป็นสำหรับ Runtime Decision ไม่เก็บข้อมูลที่ Node สามารถคำนวณได้เอง หรือข้อมูลที่อยู่ใน Graph Structure แล้ว

### 3. Intent over Instruction
Product Config บอก "ต้องได้ Component ขนาด X จำนวน Y ชิ้น" ไม่บอก "ต้องใช้ CUT node แล้วไป SKIVE node" (Graph เป็นคนกำหนด routing)

### 4. Component-First, Product-Second
Product เป็น Container ของ Components แต่ Parallel Flow, Work Tracking, และ QC Boundary เกิดขึ้นที่ Component Level ไม่ใช่ Product Level

---

## What Product Config IS

### ข้อมูลที่ระบบ "ต้องรู้" เพื่อตัดสินใจ

**1. Component Slot Specifications**
- Graph declares Component Slots / Anchors (Graph เป็นคนกำหนด)
- Product Config บอกว่าแต่ละ Component Slot ต้องมีคุณสมบัติอย่างไร (specifications)
- แต่ละ Component Slot มีจำนวนเท่าไหร่ต่อ Product
- Component Slot มีลำดับความสำคัญหรือไม่ (optional vs required)

**⚠️ CRITICAL:** Product ไม่ได้กำหนดว่า Product ประกอบด้วย Components อะไร — Graph เป็นคนกำหนด Component Slots ผ่าน Anchor Nodes

**2. Component Specifications**
- ขนาด (dimensions) ของแต่ละ Component
- ความหนาเป้าหมาย (target thickness) สำหรับ Skive/Lining
- วัสดุ (material) ที่ต้องใช้
- คุณสมบัติพิเศษ (special attributes) ถ้ามี

**3. Production Intent**
- Component นี้ต้องผ่านกระบวนการอะไรบ้าง (CUT, SKIVE, QC, etc.)
- แต่ละ Component มี constraint อะไร (เช่น ต้องตัดจาก material sheet ขนาดเท่าไหร่)
- Component มี dependency กับ Component อื่นหรือไม่

**4. Quality Boundaries**
- Component boundary สำหรับ QC และ Rework
- Component ใดที่สามารถ rework ได้ และ rework กลับไปที่ไหน
- Component ใดที่ scrap แล้วต้อง recut

### ขอบเขตความรับผิดชอบ

Product Config รับผิดชอบ:
- ✅ บอกว่าแต่ละ Component Slot (ที่ Graph กำหนด) ต้องมีคุณสมบัติอย่างไร
- ✅ บอกว่า Component Slot มีจำนวนเท่าไหร่ต่อ Product
- ✅ บอกว่า Component Slot มี constraint อะไร
- ✅ บอกว่า Component Slot มี intent อะไร (lining required, target thickness, etc.)

**⚠️ CRITICAL:** Product Config ไม่ได้กำหนดว่า Product ต้องมี Components อะไร — Graph เป็นคนกำหนด Component Slots

Product Config **ไม่รับผิดชอบ**:
- ❌ บอกว่า Component ต้องผ่าน Node อะไรบ้าง (Graph เป็นคนกำหนด)
- ❌ บอกว่า Component ต้องใช้ Machine อะไร (Node Behavior เป็นคนตัดสินใจ)
- ❌ บอกว่า Component ต้องใช้ Operator คนไหน (Assignment System เป็นคนจัดการ)
- ❌ บอกว่า Component ต้องใช้เวลานานเท่าไหร่ (Time Engine เป็นคนคำนวณ)

---

## What Product Config IS NOT

### สิ่งที่ห้ามใส่ใน Product Config

**1. Graph Structure Information**
- Product Config ไม่บอกว่า Component ต้องผ่าน Node อะไร
- Graph Designer เป็นคนกำหนด routing
- Product Config เป็นแค่ "specification" ที่ Graph ต้อง satisfy

**2. Node-Specific Instructions**
- Product Config ไม่บอกว่า CUT node ต้องทำอย่างไร
- Node Behavior เป็นคนตัดสินใจตาม Product Config + Node Config + Runtime Context
- Product Config บอกแค่ "ต้องได้ Component ขนาด X" ไม่บอก "ต้องใช้ blade Y"

**3. Assignment Information**
- Product Config ไม่บอกว่า Component ต้อง assign ให้ Operator คนไหน
- Assignment System เป็นคนจัดการตาม skill, availability, และ workload
- Product Config เป็นแค่ "requirement" ที่ Assignment System ต้อง match

**4. Timing Information**
- Product Config ไม่บอกว่า Component ต้องใช้เวลานานเท่าไหร่
- Time Engine เป็นคนคำนวณจาก historical data, complexity, และ operator skill
- Product Config เป็นแค่ "specification" ที่ Time Engine ใช้ estimate

**5. Machine Configuration**
- Product Config ไม่บอกว่า Component ต้องใช้ Machine อะไร
- Node Behavior เป็นคนตัดสินใจตาม material, size, และ machine availability
- Product Config บอกแค่ "ต้องได้ Component ขนาด X จาก material Y"

---

## What Product Config Must NOT Know (But Graph Must)

### Boundary ที่ต้องปิดให้ชัด

Product Config ต้องไม่รู้เกี่ยวกับโครงสร้างการผลิตภายใน Component เพราะโครงสร้างเหล่านี้เป็นหน้าที่ของ Graph Designer ไม่ใช่ Product Designer

**สิ่งที่ Product Config ต้องไม่รู้:**

**1. Sub-components ภายใน Component**
- Product Config ไม่รู้ว่า Component หนึ่งชิ้นประกอบด้วย sub-components อะไรบ้าง
- Product Config ไม่รู้ว่า Component ต้องประกอบ sub-components อย่างไร
- Graph Designer เป็นคนกำหนดว่า Component ต้องผ่าน Node อะไรบ้างเพื่อประกอบ sub-components

**Example:**
Component "ตัวกระเป๋า" อาจประกอบด้วย:
- Sub-component: ตัวกระเป๋า (outer fabric)
- Sub-component: ฝากระเป๋า (flap)
- Sub-component: พื้นกระเป๋า (bottom)

Product Config แค่บอกว่า Component "ตัวกระเป๋า" ต้องมีคุณสมบัติอย่างไร (ขนาด, วัสดุ, lining requirement)
Graph Designer เป็นคนกำหนดว่า Component ต้องผ่าน Node อะไรบ้างเพื่อประกอบ sub-components เหล่านี้

**2. Internal Assembly Structure**
- Product Config ไม่รู้ว่า Component ต้องประกอบอย่างไร
- Product Config ไม่รู้ว่า Component ต้องผ่านขั้นตอนการประกอบอะไรบ้าง
- Graph Designer เป็นคนกำหนดโครงสร้างการประกอบใน Graph

**Example:**
Component "ตัวกระเป๋า" อาจต้อง:
1. ตัด outer fabric
2. ตัด flap
3. ตัด bottom
4. เย็บ outer fabric + bottom
5. เย็บ flap เข้ากับ outer fabric
6. ติด lining

Product Config แค่บอกว่า Component "ตัวกระเป๋า" ต้องมีคุณสมบัติอย่างไร
Graph Designer เป็นคนกำหนดว่า Component ต้องผ่าน Node อะไรบ้าง (CUT → SEW → LINING → QC)

**3. Lining Steps**
- Product Config ไม่รู้ว่า Component ต้องติด lining อย่างไร
- Product Config ไม่รู้ว่า Component ต้องผ่านขั้นตอนการติด lining อะไรบ้าง
- Product Config แค่บอกว่า Component ต้องมี lining หรือไม่
- Graph Designer เป็นคนกำหนดว่า Component ต้องผ่าน LINING node หรือไม่

**Example:**
Component "ตัวกระเป๋า" มี lining requirement = true
- Product Config แค่บอกว่า Component ต้องมี lining
- Graph Designer เป็นคนกำหนดว่า Component ต้องผ่าน LINING node
- Node Behavior เป็นคนตัดสินใจว่าจะใช้ LINING node หรือไม่ (ถ้า material มี lining อยู่แล้วอาจไม่ต้อง LINING)

**4. Pocket Construction Steps**
- Product Config ไม่รู้ว่า Component ต้องสร้าง pocket อย่างไร
- Product Config ไม่รู้ว่า Component ต้องผ่านขั้นตอนการสร้าง pocket อะไรบ้าง
- Graph Designer เป็นคนกำหนดว่า Component ต้องผ่าน POCKET node หรือไม่

**Example:**
Component "ตัวกระเป๋า" อาจต้องมี pocket
- Product Config ไม่รู้ว่า Component ต้องสร้าง pocket อย่างไร
- Graph Designer เป็นคนกำหนดว่า Component ต้องผ่าน POCKET node
- Node Behavior เป็นคนตัดสินใจว่าจะใช้ POCKET node หรือไม่

**5. Sewing Order**
- Product Config ไม่รู้ว่า Component ต้องเย็บอย่างไร
- Product Config ไม่รู้ว่า Component ต้องเย็บตามลำดับอะไร
- Graph Designer เป็นคนกำหนดลำดับการเย็บใน Graph

**Example:**
Component "ตัวกระเป๋า" อาจต้อง:
1. เย็บ outer fabric + bottom
2. เย็บ flap เข้ากับ outer fabric
3. เย็บ pocket เข้ากับ outer fabric
4. ติด lining

Product Config ไม่รู้ลำดับการเย็บ
Graph Designer เป็นคนกำหนดลำดับใน Graph (SEW_BOTTOM → SEW_FLAP → SEW_POCKET → LINING)

**6. Parallel Graph Branches**
- Product Config ไม่รู้ว่า Component ต้องผ่าน parallel branches อะไรบ้าง
- Product Config ไม่รู้ว่า Component ต้อง split/merge อย่างไร
- Graph Designer เป็นคนกำหนด parallel structure ใน Graph

**Example:**
Component "ตัวกระเป๋า" อาจต้อง:
- Branch 1: ตัด outer fabric → เย็บ outer fabric
- Branch 2: ตัด lining → เย็บ lining
- Merge: รวม outer fabric + lining → ติด lining

Product Config ไม่รู้ parallel structure
Graph Designer เป็นคนกำหนด parallel split/merge ใน Graph

### Separation of Responsibility

**Product Config → Constraints / Intent / Invariants**
- Product Config บอกว่า Component ต้องมีคุณสมบัติอย่างไร
- Product Config บอกว่า Component ต้องมี constraint อะไร
- Product Config บอกว่า Component ต้อง satisfy invariant อะไร

**Graph → Structure / Flow / Parallelism**
- Graph Designer กำหนดโครงสร้างการผลิต
- Graph Designer กำหนด flow ของ Component
- Graph Designer กำหนด parallel structure

**Node Behavior → Execution**
- Node Behavior ตัดสินใจว่าจะทำอย่างไรตาม Product Config + Node Config + Runtime Context
- Node Behavior execute ตาม Graph structure
- Node Behavior enforce constraints จาก Product Config

### Architectural Correctness

**ระบบไม่ incomplete**
- ความซับซ้อนไม่ได้หายไป แต่ถูก delegate ไปที่ Graph
- Graph Designer เป็นคนจัดการความซับซ้อนของการผลิต
- Product Config เป็นแค่ specification ที่ Graph ต้อง satisfy

**ความซับซ้อนถูก delegate อย่างตั้งใจ**
- Product Config ไม่ต้องรู้โครงสร้างการผลิตภายใน Component
- Graph Designer เป็นคนจัดการโครงสร้างการผลิต
- Node Behavior เป็นคน execute ตาม Graph structure

**Graph Model แก้ปัญหา "real-world mess" อยู่แล้ว**
- Graph Designer สามารถกำหนดโครงสร้างการผลิตที่ซับซ้อนได้
- Graph Designer สามารถกำหนด parallel structure ได้
- Graph Designer สามารถกำหนด sub-component flow ได้
- Product Config ไม่ต้องรู้โครงสร้างเหล่านี้

**Key Insight:**
> Product Config = "What must be achieved" (constraints / intent / invariants)  
> Graph = "How to structure the work" (structure / flow / parallelism)  
> Node Behavior = "How to execute" (execution)

### Conceptual Guardrails

**⚠️ Guardrail 1: Responsibility Boundary**
> ถ้าคุณกำลังคิดว่า "Product Config ควรรู้เรื่อง..."  
> - ถ้าเป็นเรื่องโครงสร้างการผลิต → Graph Designer เป็นคนจัดการ  
> - ถ้าเป็นเรื่อง constraint / intent / invariant → Product Config เป็นคนจัดการ  
> - ถ้าเป็นเรื่อง execution → Node Behavior เป็นคนจัดการ

**⚠️ Guardrail 2: Human-First Invariant**
> ถ้า complexity นี้เกิดจาก "มนุษย์ทำงานแบบนี้" → ควรอยู่ใน Graph ไม่ใช่ Product Config  
> ระบบไม่ควร obstruct craftsmen — ERP records, coordinates, และ validates แต่ไม่ choreograph hands

**⚠️ Guardrail 3: Intent vs Instruction**
> Product Config = Intent (What must be achieved)  
> Node Behavior = Executor (How to achieve it)  
> Product Config ไม่ควรบอก "ต้องทำอย่างไร" แต่บอก "ต้องได้อะไร"

**⚠️ Guardrail 4: Reporting ≠ Execution Control**
> Missing reporting detail ≠ Missing system logic  
> Yield reporting, QC history, progress tracking = visibility/analytics  
> Execution control = Graph structure + Node Behavior

**Product Config ไม่ต้องรู้:**
- ❌ Sub-components ภายใน Component
- ❌ Internal assembly structure
- ❌ Lining steps
- ❌ Pocket construction steps
- ❌ Sewing order
- ❌ Parallel graph branches

**Product Config ต้องรู้:**
- ✅ Component specifications (dimensions, thickness, material)
- ✅ Component constraints (material sheet size, etc.)
- ✅ Component intent (lining required, etc.)
- ✅ Component invariants (quality boundaries, etc.)

---

## Component-Centric Model

### ทำไม Parallel Flow ควร Anchor ที่ Component

**Product เป็น Container, Component เป็น Unit of Work**

Product หนึ่งชิ้นอาจประกอบด้วย:
- Component A: ตัวหลัก (1 ชิ้น)
- Component B: ฝาปิด (1 ชิ้น)
- Component C: ฐานรอง (1 ชิ้น)

แต่ใน Production:
- Component A, B, C สามารถทำงานพร้อมกันได้ (parallel)
- Component A อาจเสร็จก่อน Component B (ไม่ต้องรอ)
- Component A อาจ fail และต้อง rework โดยไม่กระทบ Component B

**Component เป็น Boundary สำหรับ:**
- ✅ Parallel Work: Component ต่างกันทำงานพร้อมกันได้
- ✅ Work Tracking: ติดตาม progress ที่ Component level
- ✅ QC Decision: QC แต่ละ Component แยกกัน
- ✅ Rework Boundary: Rework กลับไปที่ Component เดิม ไม่ข้าม Component

### ความสัมพันธ์กับ CUT / SKIVE / QC

**CUT Node:**
- CUT node รับ Product Config และตัด Component ตาม specification
- CUT node ไม่ต้องรู้ว่า Component นี้จะไป Node อะไรต่อ
- CUT node แค่ตัดให้ได้ Component ตาม spec แล้วส่งต่อ

**SKIVE Node:**
- SKIVE node รับ Component และ skive ให้ได้ความหนาตาม target thickness
- SKIVE node ไม่ต้องรู้ว่า Component นี้มาจาก Product อะไร
- SKIVE node แค่ skive ให้ได้ความหนาตาม spec แล้วส่งต่อ

**QC Node:**
- QC node รับ Component และตรวจสอบตาม Component specification
- QC node ไม่ต้องรู้ว่า Component นี้มาจาก Product อะไร
- QC node แค่ตรวจสอบว่า Component ตรงตาม spec หรือไม่

**Key Insight:**
> Node ทำงานกับ Component ไม่ใช่ Product  
> Product Config เป็นแค่ "specification" ที่ Node ใช้ตัดสินใจ  
> Node Behavior executes according to Graph structure + Product Intent  
> Node Behavior enforces constraints and records outcomes — it does NOT instruct humans

---

## CUT Batch Philosophy

### ตัดทีละชิ้น ไม่ตัดครบเป็นใบๆ

**Legacy Model (Token-by-Token):**
- สร้าง token หนึ่ง token ต่อ Product หนึ่งชิ้น
- CUT node ต้องตัดครบทุก Component ก่อนถึงจะ complete token
- Token ไม่สามารถส่งต่อได้ก่อนครบทุก Component

**V3 Model (Component-by-Component):**
- CUT node รับ Product Config และตัด Component ทีละชิ้น
- CUT node สามารถส่ง Component ไป Node ถัดไปได้ทันทีที่ตัดเสร็จ
- ไม่ต้องรอให้ตัดครบทุก Component ก่อน

**Example:**
Product หนึ่งชิ้นประกอบด้วย:
- Component A (ตัวหลัก): 1 ชิ้น
- Component B (ฝาปิด): 1 ชิ้น
- Component C (ฐานรอง): 1 ชิ้น

CUT node:
1. ตัด Component A เสร็จ → ส่ง Component A ไป Node ถัดไปทันที
2. ตัด Component B เสร็จ → ส่ง Component B ไป Node ถัดไปทันที
3. ตัด Component C เสร็จ → ส่ง Component C ไป Node ถัดไปทันที

**ไม่ต้องรอให้ตัดครบทุก Component ก่อน**

### ส่งต่อได้ก่อนครบ

**Partial Component Output:**
- CUT node สามารถส่ง Component ไป Node ถัดไปได้ทันทีที่ตัดเสร็จ
- ไม่ต้องรอให้ตัดครบทุก Component ก่อน
- Work Queue จะเห็น Component ที่ตัดเสร็จแล้วทันที

**Batch Session Tracking:**
- CUT node ยังคงเป็น batch job (ช่างตัดทีละชิ้น)
- แต่ Component ที่ตัดเสร็จแล้วสามารถส่งต่อได้ทันที
- Batch session จะ complete เมื่อตัดครบทุก Component ตาม Product Config

### ไม่ Spawn Token แบบ Legacy

**Legacy Model:**
- สร้าง token หนึ่ง token ต่อ Product หนึ่งชิ้น
- Token เดียวต้องผ่านทุก Node จน complete

**V3 Model:**
- Component เป็น Unit of Work
- Component หนึ่งชิ้น = Token หนึ่ง token (หรือ component token)
- Component token เดินตาม Graph แยกกัน ไม่ต้องรอ Component อื่น

**Key Insight:**
> Graph บอกว่า Product ต้องมี Component Slots อะไร (Graph = Law)  
> Product Config บอกว่าแต่ละ Component Slot ต้องมีคุณสมบัติอย่างไร (Product = Applicant)  
> Component เป็น Unit of Work ที่เดินตาม Graph แยกกัน

---

## Skive / Lining as Product Intent

### ความหนาเป็น Target ไม่ใช่ Step

**Legacy Model:**
- SKIVE เป็น Node แยกต่างหาก
- Product ต้องผ่าน SKIVE node เพื่อให้ได้ความหนาที่ต้องการ

**V3 Model:**
- ความหนาเป้าหมาย (target thickness) เป็น Product Intent
- Product Config บอกว่า Component ต้องมีความหนาเท่าไหร่
- Node Behavior เป็นคนตัดสินใจว่าจะใช้ SKIVE node หรือไม่

**Example:**
Component A มี target thickness = 2.0mm
- ถ้า Material Sheet มีความหนา 2.0mm อยู่แล้ว → ไม่ต้อง SKIVE
- ถ้า Material Sheet มีความหนา 3.0mm → ต้อง SKIVE ให้เหลือ 2.0mm

**Node Behavior เป็นคนตัดสินใจ ไม่ใช่ Product Config**

### Lining เป็น Requirement ไม่ใช่ Step

**Legacy Model:**
- LINING เป็น Node แยกต่างหาก
- Product ต้องผ่าน LINING node เพื่อติด lining

**V3 Model:**
- Lining เป็น Product Requirement (outcome, not step)
- Product Config บอกว่า Component ต้องมี lining หรือไม่ (Intent)
- Graph Designer กำหนด: LINING node มีอยู่ใน Graph หรือไม่ (Structure)
- Node Behavior ตัดสินใจ: จะใช้ LINING node หรือไม่ (based on material + runtime context) (Execution)

**Example:**
Component A มี lining requirement = true
- Product Config บอก: "Component ต้องมี lining" (Intent)
- Graph Designer กำหนด: LINING node มีอยู่ใน Graph หรือไม่ (Structure)
- Node Behavior ตัดสินใจ: ถ้า Material Sheet มี lining อยู่แล้ว → ไม่ต้อง LINING, ถ้าไม่มี → ใช้ LINING (Execution)

**Node Behavior เป็นคนตัดสินใจ ไม่ใช่ Product Config**

---

## Minimal Field Set (Conceptual)

### Field ระดับแนวคิด (ไม่ใช่ Schema)

**Product Level:**
- Product ID / Code: ตัวระบุ Product
- Product Name: ชื่อ Product
- Product Version: เวอร์ชันของ Product Config (สำหรับ versioning)

**Component Level:**
- Component Code: ตัวระบุ Component (unique ภายใน Product)
- Component Name: ชื่อ Component
- Quantity per Product: จำนวน Component ต่อ Product
- Dimensions: ขนาดของ Component (width, length, height)
- Target Thickness: ความหนาเป้าหมาย (สำหรับ Skive)
- Material: วัสดุที่ต้องใช้ (material code หรือ material specification)
- Lining Required: ต้องมี lining หรือไม่
- Optional: Component นี้เป็น optional หรือไม่ (ถ้า optional สามารถ skip ได้)

**Production Intent:**
- Process Requirements: Component นี้ต้องผ่านกระบวนการอะไรบ้าง (CUT, SKIVE, QC, etc.)
- Constraints: Constraint ต่างๆ เช่น ต้องตัดจาก material sheet ขนาดเท่าไหร่
- Dependencies: Component นี้มี dependency กับ Component อื่นหรือไม่

**Quality Boundaries:**
- QC Boundary: Component boundary สำหรับ QC
- Rework Allowed: Component นี้สามารถ rework ได้หรือไม่
- Rework Target: ถ้า rework ต้องกลับไปที่ Component ไหน

### เหตุผลของแต่ละ Field

**Product ID / Code:**
- ใช้ระบุ Product ในระบบ
- ใช้ reference จาก Job Ticket, Graph, และ Token

**Component Code:**
- ใช้ระบุ Component ในระบบ
- ใช้ reference จาก Component Token, Work Session, และ QC Result

**Quantity per Product:**
- ใช้คำนวณ total quantity เมื่อสร้าง Job
- ใช้ validate ว่า Component ครบหรือไม่

**Dimensions:**
- ใช้ตัดสินใจว่า Component ต้องใช้ Material Sheet ขนาดเท่าไหร่
- ใช้ validate ว่า Component ตรงตาม spec หรือไม่

**Target Thickness:**
- ใช้ตัดสินใจว่า Component ต้อง SKIVE หรือไม่
- ใช้ validate ว่า Component ตรงตาม spec หรือไม่

**Material:**
- ใช้ตัดสินใจว่า Component ต้องใช้ Material Sheet อะไร
- ใช้ validate ว่า Component ใช้ material ถูกต้องหรือไม่

**Lining Required:**
- ใช้ตัดสินใจว่า Component ต้อง LINING หรือไม่
- ใช้ validate ว่า Component มี lining หรือไม่

**Optional:**
- ใช้ตัดสินใจว่า Component สามารถ skip ได้หรือไม่
- ใช้ validate ว่า Product complete หรือไม่ (optional component สามารถ skip ได้)

---

## Why This Unlocks Node Behavior Phase

### ถ้าไม่มี Product Config Node Behavior จะพังอย่างไร

**Problem 1: Node Behavior ไม่มีข้อมูลเพียงพอ**
- Node Behavior ไม่รู้ว่า Component ต้องมีคุณสมบัติอย่างไร
- Node Behavior ไม่รู้ว่า Component ต้องผ่านกระบวนการอะไรบ้าง
- Node Behavior ไม่สามารถตัดสินใจได้ว่าต้องทำอะไร

**Problem 2: Node Behavior ต้องไปหาข้อมูลจากที่อื่น**
- Node Behavior ต้องไปหา Product Config จาก Graph
- Node Behavior ต้องไปหา Component Spec จาก Node Config
- Node Behavior ไม่มี Single Source of Truth

**Problem 3: Node Behavior ไม่สามารถ enforce Component Boundary ได้**
- Node Behavior ไม่รู้ว่า Component boundary คืออะไร
- Node Behavior ไม่รู้ว่า QC / Rework ต้อง stay ใน Component boundary
- Node Behavior ไม่สามารถ enforce parallel flow ได้

### ถ้ามี Product Config แล้ว จะได้อะไร

**Benefit 1: Node Behavior มีข้อมูลเพียงพอ**
- Node Behavior มี Product Config เป็น SSOT
- Node Behavior สามารถตัดสินใจได้ว่าต้องทำอะไร
- Node Behavior ไม่ต้องไปหาข้อมูลจากที่อื่น

**Benefit 2: Node Behavior สามารถ enforce Component Boundary ได้**
- Node Behavior รู้ว่า Component boundary คืออะไร
- Node Behavior รู้ว่า QC / Rework ต้อง stay ใน Component boundary
- Node Behavior สามารถ enforce parallel flow ได้

**Benefit 3: Node Behavior สามารถตัดสินใจได้อย่างอิสระ**
- Node Behavior ไม่ต้องทำตาม Instruction จาก Product Config
- Node Behavior สามารถตัดสินใจได้ตาม Product Intent + Node Config + Runtime Context
- Node Behavior มี flexibility ในการตัดสินใจ

**Key Insight:**
> Graph = Law (declares Component Slots, routing, parallelism)  
> Product Config = Intent/Constraints/Invariants (specifications for Graph's Component Slots)  
> Node Behavior = Executor (executes according to Graph structure + Product Intent)  
> Product Config เป็น Foundation ที่ทำให้ Node Behavior สามารถตัดสินใจได้อย่างอิสระ  
> โดยไม่ต้องทำตาม Instruction แต่ทำตาม Intent

---

## Intentional Non-Goals (Design Decisions, Not Omissions)

### สิ่งที่ตั้งใจไม่ทำใน V3 (Intentional Design Decisions)

**⚠️ CRITICAL:** ข้อจำกัดเหล่านี้เป็น **การตัดสินใจเชิงสถาปัตยกรรม** ไม่ใช่ข้อบกพร่องของระบบ

**1. Material Management Integration**
- V3 ไม่รวม Material Requirement, Material Reservation, Material Linking
- Material Management เป็นระบบแยกต่างหาก
- Product Config แค่บอกว่า Component ต้องใช้ Material อะไร (Intent)
- **เหตุผล:** Material Management มี lifecycle และ complexity ของตัวเอง ควรแยกเป็นระบบอิสระ

**2. Cost Calculation**
- V3 ไม่รวม Cost Calculation
- Cost Calculation เป็นระบบแยกต่างหาก
- Product Config แค่บอกว่า Component ต้องใช้ Material อะไร
- **เหตุผล:** Cost calculation ต้องการข้อมูลจากหลายแหล่ง (material cost, labor cost, overhead) ไม่ควรผูกกับ Product Config

**3. Time Estimation**
- V3 ไม่รวม Time Estimation
- Time Estimation เป็นระบบแยกต่างหาก (Time Engine)
- Product Config แค่บอกว่า Component ต้องผ่านกระบวนการอะไรบ้าง
- **เหตุผล:** Time estimation ต้องการ historical data, operator skill, machine availability — ไม่ใช่ Product Config

**4. Assignment Logic**
- V3 ไม่รวม Assignment Logic
- Assignment Logic เป็นระบบแยกต่างหาก
- Product Config แค่บอกว่า Component ต้องผ่านกระบวนการอะไรบ้าง
- **เหตุผล:** Assignment ต้องการ skill matching, workload balancing, availability — ไม่ใช่ Product Config

**5. Machine Configuration**
- V3 ไม่รวม Machine Configuration
- Machine Configuration เป็นระบบแยกต่างหาก
- Product Config แค่บอกว่า Component ต้องได้คุณสมบัติอย่างไร
- **เหตุผล:** Machine selection ต้องการ runtime context (availability, capacity, material compatibility) — Node Behavior เป็นคนตัดสินใจ

**6. Optimization of Human Decision-Making**
- V3 ไม่พยายาม optimize การตัดสินใจของช่าง
- ระบบไม่บอกช่างว่าควรทำอย่างไร
- ระบบแค่ record และ validate — ไม่ choreograph
- **เหตุผล:** งานช่างต้องการ judgment และ flexibility — ระบบไม่ควรบังคับ workflow

**7. Force Pull/Push Behavior**
- V3 ไม่บังคับว่า token ต้อง pull หรือ push
- Work Queue แสดง readiness — ไม่บังคับ sequence
- **เหตุผล:** ช่างต้องมี flexibility ในการเลือกงาน — ระบบไม่ควรบังคับลำดับ

**8. Encode Every Real-World Exception**
- V3 ไม่พยายาม encode ทุก exception ที่เกิดขึ้นจริง
- ระบบมี guardrails และ validation — แต่ไม่ encode ทุกกรณี
- **เหตุผล:** Real-world มี exception มากมาย — ระบบควร flexible และให้ช่างตัดสินใจ

**9. Track QC Decision History in Routing Logic**
- V3 ไม่ใช้ QC decision history ในการ routing
- QC decision history = reporting/analytics only
- Routing logic = Graph structure + Component boundary
- **เหตุผล:** Routing ควร deterministic และ simple — history เป็นข้อมูลสำหรับ analytics ไม่ใช่ routing

**10. Model Incremental Yield as Execution Control**
- V3 ไม่ใช้ incremental yield เป็น execution control
- Yield reporting = visibility/analytics
- Execution control = Graph structure + Node Behavior
- **เหตุผล:** Yield reporting และ execution control เป็นคนละ concern — ไม่ควรผูกกัน

---

## Reporting vs Routing vs Execution (Separation of Concerns)

### ⚠️ CRITICAL: แยกความรับผิดชอบให้ชัดเจน

**Routing Concerns (Graph):**
- Graph กำหนดเส้นทางของ token
- Graph กำหนด parallelism และ merge points
- Graph กำหนด component boundaries
- **Product Config ไม่เกี่ยวข้องกับ routing**

**Execution Concerns (Node Behavior):**
- Node Behavior ตัดสินใจว่าจะทำอย่างไร
- Node Behavior ใช้ Product Config + Node Config + Runtime Context
- Node Behavior execute ตาม Graph structure
- **Product Config = Intent ที่ Node Behavior ใช้ตัดสินใจ**

**Reporting / Visibility Concerns (UI / Analytics):**
- Yield reporting = visibility ว่าผลิตได้เท่าไหร่
- QC decision history = analytics สำหรับ quality improvement
- Component progress tracking = visibility สำหรับ production monitoring
- **Missing reporting detail ≠ Missing system logic**

### Key Insight

> **Product Config = Intent (What must be achieved)**  
> **Graph = Structure (How work flows)**  
> **Node Behavior = Execution (How to achieve it)**  
> **Reporting = Visibility (What happened)**

**⚠️ Guardrail:**
> ถ้า complexity นี้เกิดจาก "มนุษย์ทำงานแบบนี้" → ควรอยู่ใน Graph ไม่ใช่ Product Config  
> ถ้า complexity นี้เกิดจาก "ต้องรู้เพื่อตัดสินใจ" → ควรอยู่ใน Product Config  
> ถ้า complexity นี้เกิดจาก "ต้อง record เพื่อ analytics" → ควรอยู่ใน Reporting Layer

---

## Future Extensions (เผื่อไว้สำหรับอนาคต)

**1. Component Variants**
- Component อาจมี variants หลายแบบ (เช่น ขนาดเล็ก, กลาง, ใหญ่)
- Product Config อาจต้อง support component variants

**2. Component Dependencies**
- Component อาจมี dependency กับ Component อื่น (เช่น Component A ต้องเสร็จก่อน Component B)
- Product Config อาจต้อง support component dependencies

**3. Component Constraints**
- Component อาจมี constraint ต่างๆ (เช่น ต้องตัดจาก material sheet ขนาดเท่าไหร่)
- Product Config อาจต้อง support component constraints

**4. Component Metadata**
- Component อาจมี metadata เพิ่มเติม (เช่น color, finish, etc.)
- Product Config อาจต้อง support component metadata

---

## Summary

**Product Configuration V3** เป็น Foundation ที่ทำให้ Node Behavior Phase สามารถทำงานได้อย่างอิสระ โดย:

1. **Graph เป็น Absolute Source of Truth** ที่บอกว่า Product ต้องมี Component Slots อะไร (Graph = Law)

2. **Product Config เป็น SSOT สำหรับ Intent/Constraints/Invariants** ที่บอกว่าแต่ละ Component Slot (ที่ Graph กำหนด) ต้องมีคุณสมบัติอย่างไร (Product = Applicant)

3. **Component เป็น Unit of Work** ที่เดินตาม Graph แยกกัน ไม่ต้องรอ Component อื่น

4. **Node Behavior เป็น Executor** ตาม Graph structure + Product Intent + Node Config + Runtime Context ไม่ต้องทำตาม Instruction

5. **Product Config เป็น Intent ไม่ใช่ Instruction** บอก "ต้องได้อะไร" ไม่บอก "ต้องทำอย่างไร"

**Next Step:**
- Node Behavior Phase จะใช้ Product Config เป็น Foundation
- Node Behavior จะตัดสินใจ "ทำอย่างไร" ตาม Product Config ที่กำหนด "ต้องได้อะไร"

---

**Document Status:** ✅ **READY FOR NODE BEHAVIOR PHASE**  
**Last Updated:** 2025-12-25  
**Version:** 3.0


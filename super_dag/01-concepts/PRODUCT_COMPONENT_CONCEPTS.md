# Product & Component Architecture Concepts

**Last Updated:** 2026-01-04  
**Status:** ✅ **CONSOLIDATED REFERENCE**  
**Source Files:**
- `PRODUCT_COMPONENT_ARCHITECTURE.md` (2025-12-06, AUTHORITATIVE)
- `PRODUCTS_COMPONENTS_V3_CONCEPT.md` (2025-12-25, Concept Spec)
- `PRODUCT_CONFIG_V3_CONCEPT.md` (2025-12-25, CORE CONCEPT)

**Purpose:** Consolidated source of truth for Product & Component architecture concepts in SuperDAG system. This document combines the definitive architecture guide with V3 concepts for BOM-driven constraints and Product Configuration.

**Audience:** AI Agents, Developers, Architects

---

## Table of Contents

1. [Architecture Overview](#architecture-overview) - From PRODUCT_COMPONENT_ARCHITECTURE.md
2. [V3 BOM-Driven Constraints](#v3-bom-driven-constraints) - From PRODUCTS_COMPONENTS_V3_CONCEPT.md
3. [V3 Product Configuration](#v3-product-configuration) - From PRODUCT_CONFIG_V3_CONCEPT.md
4. [Summary & Current State](#summary--current-state)

---

# Architecture Overview

> **Source:** `PRODUCT_COMPONENT_ARCHITECTURE.md` (Last Updated: 2025-12-06, Status: ✅ AUTHORITATIVE)  
> **Purpose:** Definitive guide for Component Layer Architecture

## 🎯 สรุปแบบ 1 หน้า

```
┌─────────────────────────────────────────────────────────────────┐
│            COMPONENT LAYER ARCHITECTURE (FINAL)                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ⚠️ CRITICAL: Graph = Absolute Source of Truth                 │
│  ├─ Graph declares Component Slots / Anchors                  │
│  ├─ Graph defines all production logic, routing, parallelism   │
│  └─ Product cannot invent components — only Graph declares     │
│                                                                 │
│  🏷️ LAYER 1: component_type_catalog (Generic Types)            │
│  ├─ type_code: BODY, STRAP, FLAP, LINING, HARDWARE             │
│  ├─ ใช้เป็น "ประเภท" หรือ "หมวดหมู่" ของชิ้นส่วน                │
│  └─ ไม่ผูกกับ Product ใดเฉพาะเจาะจง                             │
│                                                                 │
│  📦 LAYER 2: product_component (Product-Specific Specifications)│
│  ├─ component_code: AIMEE_MINI_BODY_2025                       │
│  ├─ component_type_code: BODY (FK → Layer 1)                   │
│  ├─ เป็น "specifications" ของ Component Slot ที่ Graph กำหนด   │
│  └─ ผูก BOM, Physical Specs, Costing                           │
│                                                                 │
│  📋 LAYER 3: product_component_material (BOM)                  │
│  ├─ material_sku, qty_required                                 │
│  └─ ผูกกับ Layer 2                                              │
│                                                                 │
│  🔗 MAPPING: graph_component_mapping                           │
│  ├─ anchor_slot (จาก Graph) → id_product_component (Layer 2)  │
│  ├─ Graph declares anchor_slot (Graph = Law)                   │
│  ├─ Product satisfies anchor_slot with product_component       │
│  └─ ผูกเฉพาะ Product ใบนั้น ไม่ใช่ global                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 📚 คำศัพท์ที่ต้องใช้ให้ตรงกัน

| คำ | หมายถึง | ตัวอย่าง | Table |
|----|---------|---------|-------|
| **Component Type** | ประเภท/หมวดหมู่ของชิ้นส่วน (generic) | BODY, STRAP, FLAP | `component_type_catalog` |
| **Product Component** | ชิ้นส่วนจริงของ Product ใบนั้น | AIMEE_MINI_BODY_2025 | `product_component` |
| **Anchor Slot** | Placeholder ใน Graph สำหรับ component branch | SLOT_BODY, SLOT_STRAP | `routing_node.anchor_slot` |
| **Component Mapping** | การจับคู่ Anchor Slot กับ Product Component | SLOT_BODY → AIMEE_MINI_BODY | `graph_component_mapping` |

**⚠️ CRITICAL ARCHITECTURAL TRUTH:**
> Graph = Law (Absolute Source of Truth)  
> Graph declares Component Slots / Anchors  
> Product = Applicant (binds to Graph)  
> Product satisfies Graph's Component Slots with specifications  
> Product cannot invent components — only Graph declares them

---

# V3 BOM-Driven Constraints

> **Source:** `PRODUCTS_COMPONENTS_V3_CONCEPT.md` (Date: 2025-12-25, Status: Concept Spec - Implementation Ready)  
> **Purpose:** V3 philosophy for BOM-driven production constraints (Role-Based)

## Executive Summary

**V3 Philosophy:** BOM Line เป็น Source of Truth ของ Material Constraints — ไม่ใช่ Slot-Level Config

**Core Change:** Production Constraints ย้ายจาก "config กลางระดับ slot" ไปเป็น "configuration ของแต่ละ BOM line item" ที่ขับด้วย Material Role/Category

**Why V3:**
- V2 + Phase 1: `product_config_component_slot` เป็น "Config กลาง" ทำให้ UX และข้อมูล "ไม่ฉลาด" และใช้จริงไม่ได้
- โลกจริง: Constraints ส่วนใหญ่เป็น "คุณสมบัติ/เงื่อนไขของวัสดุแต่ละรายการใน BOM" ไม่ใช่ของ slot แบบรวมๆ
- V3: Constraints ผูกกับ BOM line item + Material Role → ฉลาดขึ้นจริง

## Principles (กฎเหล็ก)

### P1 — BOM Line เป็น Source of Truth ของ Constraints

**ทุก constraints ที่เกี่ยวกับวัสดุ** (ความหนา, lining, reinforcement, hardware finish, thread size, glue type ฯลฯ) **ต้องผูกกับ "BOM line item" ใน `product_component_material`**

❌ **ห้าม:** ผูก constraints กับ `anchor_slot` โดยตรง  
❌ **ห้าม:** เก็บ constraints เป็น config กลางระดับ slot  
✅ **ต้อง:** Constraints อยู่ที่ BOM line item เท่านั้น

### P2 — Constraints ถูกขับด้วย "Material Role/Category"

**BOM line ต้องมี "Role" ชัดเจน** เพื่อให้ระบบรู้ว่าต้องถาม fields อะไรบ้าง:

- `MAIN_MATERIAL` → thickness, grain_direction, finish_type
- `LINING` → bonding_method, thickness_mm, color
- `HARDWARE` → finish, color, size, brand
- `THREAD` → size, color, material
- `GLUE` → type, application_method

**Role-driven UI:** ระบบ generate form จาก `material_role_field` (data-driven)

---

# V3 Product Configuration

> **Source:** `PRODUCT_CONFIG_V3_CONCEPT.md` (Date: 2025-12-25, Status: 🎯 **CORE CONCEPT**)  
> **Purpose:** Conceptual foundation for Product Configuration V3

## Executive Summary

**Product Configuration** คือ Single Source of Truth (SSOT) ที่บรรยาย "ความตั้งใจ" (Intent) ของ Product หนึ่งชิ้นในระดับ Component โดยไม่กำหนด "วิธีทำ" (Instruction) ให้กับ Node

**Core Philosophy:**
> Product Config = "What must be achieved"  
> Node Behavior = "How to achieve it"

**⚠️ CRITICAL ARCHITECTURAL TRUTH:**
> Graph = Law (Absolute Source of Truth)  
> Graph declares Component Slots / Anchors  
> Product = Applicant (binds to Graph)  
> Product satisfies Graph's Component Slots with specifications  
> Product cannot invent components — only Graph declares them

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

### 2. Minimal but Sufficient

เก็บเฉพาะข้อมูลที่จำเป็นสำหรับ Runtime Decision ไม่เก็บข้อมูลที่ Node สามารถคำนวณได้เอง หรือข้อมูลที่อยู่ใน Graph Structure แล้ว

### 3. Intent over Instruction

Product Config บอก "ต้องได้ Component ขนาด X จำนวน Y ชิ้น" ไม่บอก "ต้องใช้ CUT node แล้วไป SKIVE node" (Graph เป็นคนกำหนด routing)

### 4. Component-First, Product-Second

Product เป็น Container ของ Components แต่ Parallel Flow, Work Tracking, และ QC Boundary เกิดขึ้นที่ Component Level ไม่ใช่ Product Level

---

# Summary & Current State

## Relationship Between Documents

1. **PRODUCT_COMPONENT_ARCHITECTURE.md** (AUTHORITATIVE, 2025-12-06)
   - **Purpose:** Definitive guide for Component Layer Architecture
   - **Scope:** Complete architecture overview (3-layer model, terminology, schema, UI flow)
   - **Status:** ✅ AUTHORITATIVE - This is the definitive reference for architecture

2. **PRODUCTS_COMPONENTS_V3_CONCEPT.md** (Concept Spec, 2025-12-25)
   - **Purpose:** V3 BOM-driven production constraints (Role-Based)
   - **Scope:** Material constraints move from slot-level to BOM line-level with role-driven validation
   - **Status:** Concept Spec (Implementation Ready) - Extends architecture with V3 constraints

3. **PRODUCT_CONFIG_V3_CONCEPT.md** (CORE CONCEPT, 2025-12-25)
   - **Purpose:** Conceptual foundation for Product Configuration V3
   - **Scope:** Product Config as Intent/Constraints/Invariants (not Instructions)
   - **Status:** 🎯 **CORE CONCEPT** - Foundation for Node Behavior Phase

## Current State (2026-01-04)

**Architecture Foundation:**
- ✅ **PRODUCT_COMPONENT_ARCHITECTURE.md** is the AUTHORITATIVE source for architecture
- ✅ V3 concepts (BOM-driven constraints, Product Config) extend but do not replace the architecture
- ✅ All three documents are complementary and should be read together

**V3 Implementation:**
- ✅ V3 BOM-driven constraints (PRODUCTS_COMPONENTS_V3_CONCEPT) - Implementation Ready
- ✅ V3 Product Configuration (PRODUCT_CONFIG_V3_CONCEPT) - CORE CONCEPT, foundation for Node Behavior

**Recommendation:**
- Read **PRODUCT_COMPONENT_ARCHITECTURE.md** first for foundational understanding
- Then read V3 concepts for latest implementation approach
- All three documents are current and valid (no conflicts, all complementary)

---

**Note:** This consolidated document combines three complementary documents. For detailed information, refer to the original source files listed at the top of this document.

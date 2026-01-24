# SuperDAG Concept Documents

**Purpose:** เอกสารแนวคิดและ Vision ของระบบ SuperDAG  
**Location:** `docs/super_dag/01-concepts/`  
**Status:** ✅ **Source of Truth - Concept Documentation**

---

## 📚 Overview

โฟลเดอร์ `01-concepts` เป็น **Source of Truth** สำหรับแนวคิดหลักและ Vision ของระบบ SuperDAG เอกสารในโฟลเดอร์นี้บันทึกแนวคิด หลักการ และ philosophy ที่เป็นพื้นฐานของระบบ เมื่อมีการพัฒนาต่อ ไม่ว่าจะจากมนุษย์หรือ AI ต้องมาอ่านแนวคิดหรือหลักการจากแหล่งนี้เพื่อเข้าใจ "ทำไม" และ "แนวคิดหลัก" ของระบบ

---

## 📁 Document Categories

เอกสารในโฟลเดอร์นี้ถูกจัดเป็น 5 หมวดหมู่ตามหัวเรื่อง:

### 1. Product & Component Architecture (3 files)

**Purpose:** แนวคิดเกี่ยวกับ Product และ Component Architecture

| File | Status | Date | Purpose |
|------|--------|------|---------|
| `PRODUCT_COMPONENT_ARCHITECTURE.md` | ✅ AUTHORITATIVE | 2025-12-06 | Definitive Guide - สถาปัตยกรรม Component Layer (3-layer model, terminology, schema, UI flow) |
| `PRODUCTS_COMPONENTS_V3_CONCEPT.md` | Concept Spec (Implementation Ready) | 2025-12-25 | V3 BOM-driven production constraints (Role-Based) - Material constraints ย้ายจาก slot-level ไป BOM line-level |
| `PRODUCT_CONFIG_V3_CONCEPT.md` | 🎯 **CORE CONCEPT** | 2025-12-25 | V3 Product Configuration foundation - Product Config เป็น Intent/Constraints/Invariants (ไม่ใช่ Instructions) |

**Relationship:**
- `PRODUCT_COMPONENT_ARCHITECTURE.md` เป็น AUTHORITATIVE source สำหรับ architecture overview
- V3 files (`PRODUCTS_COMPONENTS_V3_CONCEPT`, `PRODUCT_CONFIG_V3_CONCEPT`) เป็นแนวคิด V3 ที่ extend architecture
- ทั้ง 3 ไฟล์เป็น complementary (ไม่มี conflict, ทุกไฟล์เป็น current และ valid)

**When to Use:**
- อ่าน `PRODUCT_COMPONENT_ARCHITECTURE.md` ก่อนเพื่อเข้าใจ architecture foundation
- อ่าน V3 concepts สำหรับ latest implementation approach
- อ่านทั้งหมดเพื่อเข้าใจภาพรวมและแนวคิดปัจจุบัน

---

### 2. Graph Architecture (4 files)

**Purpose:** แนวคิดเกี่ยวกับ Graph Architecture, Versioning, และ Module System

| File | Status | Date | Purpose |
|------|--------|------|---------|
| `GRAPH_VERSIONING_AND_PRODUCT_BINDING.md` | 🎯 **CORE CONCEPT** | 2025-12-12 | Graph Versioning Philosophy - Published graphs must be immutable, product bindings reference versions |
| `GRAPH_LINTER_RULES.md` | 📋 DRAFT | N/A | Graph Linter Rules Specification - Validation rules สำหรับ graph structure |
| `SUBGRAPH_MODULE_TEMPLATE.md` | Concept | 2025-01-XX | Subgraph = Module Template - Module Graph concept (reusable templates) |
| `RUNTIME_ENABLED_AUDIT_AND_MIGRATION.md` | Audit Plan | 2025-12-12 | Runtime Enabled Audit & Migration - Migration plan สำหรับ `RUNTIME_ENABLED` feature flag |

**Relationship:**
- `GRAPH_VERSIONING_AND_PRODUCT_BINDING.md` เป็น CORE CONCEPT สำหรับ graph versioning
- `SUBGRAPH_MODULE_TEMPLATE.md` เป็นแนวคิดใหม่สำหรับ module system
- `GRAPH_LINTER_RULES.md` เป็น supporting specification (DRAFT)
- `RUNTIME_ENABLED_AUDIT_AND_MIGRATION.md` เป็น audit/migration plan (supporting)

**When to Use:**
- อ่าน `GRAPH_VERSIONING_AND_PRODUCT_BINDING.md` สำหรับ graph versioning principles
- อ่าน `SUBGRAPH_MODULE_TEMPLATE.md` สำหรับ module template concept
- อ่าน `GRAPH_LINTER_RULES.md` สำหรับ validation rules (DRAFT status)
- อ่าน `RUNTIME_ENABLED_AUDIT_AND_MIGRATION.md` สำหรับ migration planning

---

### 3. QC & Rework (1 file)

**Purpose:** แนวคิดเกี่ยวกับ QC และ Rework Philosophy

| File | Status | Date | Purpose |
|------|--------|------|---------|
| `QC_REWORK_PHILOSOPHY_V2.md` | ✅ FINALIZED | 2025-12-25 | Finalized Rework Philosophy - QC → RRM → Component Node Model (V3 crystallization) |

**Relationship:**
- Single file - FINALIZED status
- Reflects V3 crystallization (2025-12-25)
- Graph is Absolute Source of Truth, Component boundaries are sacred, QC decisions are made by craftsmen

**When to Use:**
- อ่านสำหรับเข้าใจ QC และ Rework philosophy
- อ่านก่อน implement QC/Rework features
- Reference สำหรับ Node Behavior Phase

---

### 4. Catalog & Specification (4 files)

**Purpose:** Specifications สำหรับ Catalog Systems และ Component Specifications

| File | Status | Date | Purpose |
|------|--------|------|---------|
| `COMPONENT_CATALOG_SPEC.md` | 📋 DRAFT | N/A | Component Catalog Specification - Catalog system สำหรับ component types |
| `DEFECT_CATALOG_SPEC.md` | 📋 DRAFT | N/A | Defect Catalog Specification - Catalog system สำหรับ defects |
| `MISSING_COMPONENT_INJECTION_SPEC.md` | 🟢 Ready for Implementation | N/A | Missing Component Injection Specification - Specification สำหรับ missing component injection |
| `SKILL_MATERIAL_TOLERANCE_SPEC.md` | 📋 DRAFT | N/A | Skill & Material Tolerance Rules Specification - Tolerance rules สำหรับ skill และ material |

**Relationship:**
- 4 files เป็น specifications สำหรับ catalog systems และ component specifications
- ส่วนใหญ่เป็น DRAFT status (ยังไม่ finalized)
- `MISSING_COMPONENT_INJECTION_SPEC.md` เป็น Ready for Implementation

**When to Use:**
- อ่านตามต้องการ implement catalog systems
- ระวัง DRAFT status - อาจมีการเปลี่ยนแปลง
- `MISSING_COMPONENT_INJECTION_SPEC.md` เป็น ready for implementation

---

### 5. Edge & Condition (1 file)

**Purpose:** Policy สำหรับ Edge Condition Usage

| File | Status | Date | Purpose |
|------|--------|------|---------|
| `EDGE_CONDITION_USAGE_POLICY.md` | ✅ Finalized | N/A | Edge Condition Usage Policy - When to use `edge_condition` (Router/Option Nodes vs User Decision) |

**Relationship:**
- Single file - Finalized status
- Core principle: Use `edge_condition` for Router/Option Nodes (System Decision), NOT for User Decision

**When to Use:**
- อ่านสำหรับเข้าใจเมื่อไหร่ควรใช้ `edge_condition`
- อ่านก่อน implement routing logic
- Reference สำหรับ Graph Designer

---

## 🎯 How to Use

### สำหรับ Developers

**อ่านก่อน:**
- Starting implementation → อ่าน category ที่เกี่ยวข้อง
- Understanding architecture → อ่าน Product & Component Architecture
- Understanding graph system → อ่าน Graph Architecture
- Writing code → อ้างอิงจาก concept documents

**Workflow:**
1. เริ่มจาก README.md (this file) เพื่อหาเอกสารที่ต้องการ
2. เลือก category ที่เกี่ยวข้อง
3. อ่าน files ตามลำดับความสำคัญ (AUTHORITATIVE → CORE CONCEPT → others)
4. อ้างอิง source file โดยตรง

---

### สำหรับ AI Agents

**Context Loading:**
- ใช้ concept documents เป็น context สำหรับ understanding system philosophy
- อ่าน AUTHORITATIVE และ CORE CONCEPT files ก่อน
- ระวัง DRAFT status files

**Search Strategy:**
- ค้นหาใน category ที่เกี่ยวข้อง
- อ่าน AUTHORITATIVE/CORE CONCEPT files ก่อน
- Check status (AUTHORITATIVE/CORE CONCEPT vs DRAFT)

**Update Strategy:**
- Update content ในไฟล์เดิมโดยตรง (Single Source of Truth)
- ระบุวันที่และ status ใน header
- Maintain consistency กับ existing structure

---

## 📋 Quick Reference

### By Status

**AUTHORITATIVE / CORE CONCEPT (Current & Valid):**
- `PRODUCT_COMPONENT_ARCHITECTURE.md` - Architecture foundation
- `PRODUCT_CONFIG_V3_CONCEPT.md` - V3 Product Config foundation
- `GRAPH_VERSIONING_AND_PRODUCT_BINDING.md` - Graph versioning
- `QC_REWORK_PHILOSOPHY_V2.md` - QC/Rework philosophy
- `EDGE_CONDITION_USAGE_POLICY.md` - Edge condition policy

**Concept Spec / Ready for Implementation:**
- `PRODUCTS_COMPONENTS_V3_CONCEPT.md` - V3 BOM constraints
- `MISSING_COMPONENT_INJECTION_SPEC.md` - Missing component injection

**DRAFT (May Change):**
- `GRAPH_LINTER_RULES.md`
- `COMPONENT_CATALOG_SPEC.md`
- `DEFECT_CATALOG_SPEC.md`
- `SKILL_MATERIAL_TOLERANCE_SPEC.md`

**Supporting Documents:**
- `SUBGRAPH_MODULE_TEMPLATE.md` - Module template concept
- `RUNTIME_ENABLED_AUDIT_AND_MIGRATION.md` - Migration plan

---

## 🔄 Maintenance

**Update Process:**
1. Update content ในไฟล์เดิมโดยตรง (Single Source of Truth)
2. ระบุวันที่และ status ใน header
3. Maintain consistency กับ existing structure
4. Update README.md ถ้าเพิ่ม/ลบไฟล์

**Adding New Content:**
1. สร้างไฟล์ใหม่ใน category ที่เหมาะสม
2. Update README.md เพื่อเพิ่มไฟล์ใหม่
3. ระบุ status และ date ใน header
4. Maintain consistency กับ existing structure

---

## 📚 Related Documents

**Technical Specs:** `../06-specs/` - Implementation specifications  
**Audit Reports:** `../00-audit/` - Audit reports and analysis  
**Implementation Checklists:** `../03-checklists/` - Implementation checklists  
**Developer Guidelines:** `../../developer/03-superdag/` - Developer guidelines

---

## 📝 Notes on Document Relationship

### Product & Component Files

ทั้ง 3 ไฟล์ (`PRODUCT_COMPONENT_ARCHITECTURE.md`, `PRODUCTS_COMPONENTS_V3_CONCEPT.md`, `PRODUCT_CONFIG_V3_CONCEPT.md`) เป็น **complementary** ไม่ใช่ conflicting:

- **PRODUCT_COMPONENT_ARCHITECTURE.md** (AUTHORITATIVE, 2025-12-06): Definitive guide สำหรับ architecture overview
- **PRODUCTS_COMPONENTS_V3_CONCEPT.md** (Concept Spec, 2025-12-25): V3 BOM-driven constraints (extends architecture)
- **PRODUCT_CONFIG_V3_CONCEPT.md** (CORE CONCEPT, 2025-12-25): V3 Product Configuration foundation (extends architecture)

**Current State (2026-01-04):**
- ✅ ทั้ง 3 ไฟล์เป็น current และ valid
- ✅ ไม่มี conflict - ทั้งหมดเป็น complementary
- ✅ อ่านทั้งหมดเพื่อเข้าใจภาพรวมและแนวคิดปัจจุบัน
- ✅ Architecture เป็น foundation, V3 concepts เป็น extensions

---

**Last Updated:** January 4, 2026  
**Structure:** Organized by 5 categories (Product & Component, Graph Architecture, QC & Rework, Catalog & Specification, Edge & Condition)

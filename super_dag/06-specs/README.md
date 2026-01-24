# SuperDAG Technical Specifications

**Purpose:** Source of Truth สำหรับ SuperDAG system - เอกสารบันทึกความจริงของระบบ  
**Location:** `docs/super_dag/06-specs/`  
**Status:** ✅ **Source of Truth - Production-Ready**

---

## 📚 Overview

โฟลเดอร์ `06-specs` เป็น **Source of Truth** ของระบบ SuperDAG และเป็นเอกสารกลางที่บันทึกแนวคิด หลักการ และสเปคของระบบ เมื่อมีการพัฒนาต่อ ไม่ว่าจะจากมนุษย์หรือ AI ต้องมาอ่านแนวคิดหรือหลักการเพื่อพัฒนาต่อยอดจากแหล่งนี้

---

## 📁 Document Structure

เอกสารในโฟลเดอร์นี้แบ่งเป็น 2 หมวดหมู่:

### หมวดหมู่ 1: SuperDAG System Specifications

เอกสารเหล่านี้ถูกจัดระเบียบเป็น 2 ไฟล์หลัก (consolidated from 17 files):

#### 1. REFERENCE_SPECS.md

**Purpose:** Reference specifications สำหรับ SuperDAG system  
**Status:** ✅ Production-Ready  
**Content:** 
- Behavior Execution Spec (v1.0)
- Component Parallel Flow Spec (v2.1)
- SuperDAG Token Lifecycle (v1.0)
- Work Queue Component Filter Decision (v1.0)

**When to Use:**
- ต้องการเข้าใจแนวคิดหลักของ SuperDAG (Token Lifecycle, Component Flow, Behavior Execution)
- ต้องการทราบกฎและหลักการในการ implement
- ต้องการอ้างอิง spec ที่ production-ready

**Key Topics:**
- Token types: batch, piece, component
- State machine: ready → active → waiting → paused → completed/scrapped
- Component tokens and parallelism
- Behavior execution model
- Work Queue integration

---

#### 2. PHASE_1_IMPLEMENTATION.md

**Purpose:** Phase 1 implementation documentation สำหรับ Products & Components V3  
**Status:** 📋 Implementation Documentation  
**Content:** 
- Decisions & Rules (3 documents)
- Implementation Plans (3 documents)
- Audits & Reports (3 documents)
- Context & Summary (4 documents)

**When to Use:**
- กำลัง implement Phase 1 (Product Configuration + Graph Binding)
- ต้องการทราบ principles และ guardrails
- ต้องการเข้าใจ reuse-first approach
- ต้องการดู audit reports และ checklists

**Key Topics:**
- Product Configuration as Intent/Constraints only
- Graph Binding and Component Slot specifications
- Reuse-first implementation approach
- Do-not-create lists and guardrails
- Implementation plans and patches

---

### หมวดหมู่ 2: Material & QC Specifications

#### 1. MATERIAL_ARCHITECTURE_V2.md

**Purpose:** Material Architecture V2 - Bellavier Protocol  
**Status:** ✅ APPROVED - Ready for Implementation  
**Date:** 2025-12-05  

**When to Use:**
- ต้องการเข้าใจ Material Architecture (3-layer model)
- กำลัง implement Material Management features
- ต้องการอ้างอิง Material system specifications

**Key Topics:**
- Layer 1: Routing Component (Graph Designer)
- Layer 2: Product Component (Product Config)
- Layer 3: BOM (product_component_material)
- Material tracking and inventory

---

#### 2. MATERIAL_PRODUCTION_MASTER_SPEC.md

**Purpose:** Material & Production Master Specification  
**Status:** Finalized Concept  
**Date:** December 2025  

**When to Use:**
- ต้องการเข้าใจ Material Management และ Production workflows
- กำลัง implement Material/Production features
- ต้องการอ้างอิง Material Production specifications

**Key Topics:**
- Two Production Lines (Hatthasilpa vs Classic)
- Material tracking (real-time vs batch)
- Production workflows

---

#### 3. MATERIAL_REQUIREMENT_RESERVATION_SPEC.md

**Purpose:** Material Requirement & Reservation System Specification  
**Status:** Draft  
**Date:** 2025-12-05  

**When to Use:**
- กำลัง implement Material Requirement/Reservation system
- ต้องการเข้าใจ Requirement → Reservation → Consumption flow

**Key Topics:**
- Material Requirement Service
- Material Reservation Service
- Material Consumption Service
- Availability calculation

---

#### 4. QC_POLICY_RULES.md

**Purpose:** QC Policy Rules - Single Source of Truth  
**Status:** 📋 **CRITICAL** - Required for Issue 1 implementation  
**Date:** 2025-12-09  

**When to Use:**
- กำลัง implement QC node behavior
- ต้องการทราบ QC business rules และ permissions
- ต้องการอ้างอิง QC policy specifications

**Key Topics:**
- QC Self-Pass rules
- QC permissions and access control
- QC node behavior specifications

---

## 🎯 How to Use

### สำหรับ Developers

**อ่านก่อน:**
- Starting implementation → อ่าน PHASE_1_IMPLEMENTATION.md
- Understanding system concepts → อ่าน REFERENCE_SPECS.md
- Writing code → อ้างอิงจาก consolidated files
- Reviewing pull requests → ตรวจสอบ compliance กับ specs

**Workflow:**
1. เริ่มจาก README.md (this file) เพื่อหาเอกสารที่ต้องการ
2. เปิด consolidated file ที่เกี่ยวข้อง
3. ใช้ Table of Contents เพื่อ navigate ไปยัง section ที่ต้องการ
4. อ้างอิง source file ในแต่ละ section ถ้าต้องการดูรายละเอียด

---

### สำหรับ AI Agents

**Context Loading:**
- ใช้ consolidated files เป็น context สำหรับ implementation
- REFERENCE_SPECS.md = System concepts และ principles
- PHASE_1_IMPLEMENTATION.md = Implementation guidelines และ rules

**Search Strategy:**
- ค้นหาใน consolidated file เดียวตาม category
- ใช้ section headers เพื่อ locate ข้อมูล
- อ้างอิง source file ถ้าต้องการ trace back

**Update Strategy:**
- Update content ใน consolidated files โดยตรง
- ระบุ source file ที่ update ใน comment/header
- Maintain section structure และ clear headers

---

## 📋 Quick Reference

### Reference Specs

| Document | Version | Status | Key Topics |
|----------|---------|--------|------------|
| Behavior Execution Spec | 1.0 | Ready for Implementation | Behavior as Orchestrator, Service Layer Architecture |
| Component Parallel Flow Spec | 2.1 | Production-Ready | Component tokens, Parallel split, Merge semantics |
| SuperDAG Token Lifecycle | 1.0 | Production-Ready | Token types, State machine, Relationships |
| Work Queue Component Filter | 1.0 | Decision Document | Component slot filtering strategy |

### Phase 1 Implementation

| Category | Documents | Purpose |
|----------|-----------|---------|
| Decisions & Rules | 3 | Locked decisions, Do-not-create lists, Executive canon |
| Implementation Plans | 3 | Implementation plans, Canonical prompts |
| Audits & Reports | 3 | Pre-implementation audits, Consistency reports |
| Context & Summary | 4 | System context, Start summary, Checklists |

---

## 📁 Archive

ไฟล์เดิมถูก archive ไว้ที่:
- `archive/completed_phases/06-specs-original/`

ไฟล์เดิมถูก consolidate แล้ว - ใช้ consolidated files สำหรับงานปัจจุบัน

---

## 🔄 Maintenance

**Update Process:**
1. Update content ใน consolidated files โดยตรง
2. ระบุ source file ที่ update (ถ้ามี)
3. Maintain clear section headers และ structure
4. Update "Last Updated" date ใน header

**Adding New Content:**
1. เพิ่ม section ใหม่ใน consolidated file ที่เหมาะสม
2. Update Table of Contents
3. ระบุ source/version ใน section header
4. Maintain consistency กับ existing structure

---

## 📚 Related Documents

**Concept Documents:** `../01-concepts/`  
**Audit Reports:** `../00-audit/`  
**Implementation Checklists:** `../03-checklists/`  
**Developer Guidelines:** `../../developer/03-superdag/`

---

**Last Updated:** January 5, 2026  
**Structure:** 
- SuperDAG System Specs: 2 consolidated files (REFERENCE_SPECS.md + PHASE_1_IMPLEMENTATION.md)
- Material & QC Specs: 4 individual specification files
- Archived: NEGATIVE_WASTE_POLICY.md (moved to archive/completed_phases/)

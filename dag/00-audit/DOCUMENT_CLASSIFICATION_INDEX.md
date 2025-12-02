# Document Classification Index

**Date:** 2025-12-02  
**Purpose:** จัดหมวดหมู่เอกสารและโครงสร้างโฟลเดอร์ของ docs/dag/  
**Scope:** Behavior App, Component Token, Subgraph Module

**⚠️ IMPORTANT:** เอกสารถูกจัดระเบียบใหม่ตามหมวดหมู่ที่ชัดเจน

---

## Folder Structure

```
docs/dag/
├── 00-audit/           📊 Audit Reports (วันเดือนปี_TOPIC_AUDIT_REPORT.md)
├── 01-concepts/        🎯 Concept Documents (TOPIC.md - มาตรฐานกลาง)
├── 02-specs/           📐 Technical Specs (TOPIC_SPEC.md - มาตรฐานกลาง)
├── 03-checklists/      ✅ Implementation Checklists (TOPIC_IMPLEMENTATION.md)
├── 00-overview/        📖 Overview & Introduction
├── 01-roadmap/         🗺️ Implementation Roadmap
├── 02-implementation-status/  📊 Detailed Status (legacy location)
└── 03-tasks/           📋 Task Documentation
```

---

## หมวดที่ 1: 📊 AUDIT REPORTS (สถานะปัจจุบันของระบบ)

เอกสารเหล่านี้ **ตรวจสอบสถานะปัจจุบัน** ของระบบที่มีอยู่แล้ว  
**วัตถุประสงค์:** รายงานว่า "ทำไปแล้วอะไร", "ยังขาดอะไร", "ทำงานหรือไม่"

### 1.1 Component Token Audit

**File:** `docs/dag/00-audit/20251202_COMPONENT_PARALLEL_WORK_AUDIT_REPORT.md`

**สถานะ:** ✅ Audit Report (ตรวจสอบสถานะปัจจุบัน)

**เนื้อหา:**
- ✅ Component Serial Binding (Task 13) - Complete
- ✅ Component Token Creation - Infrastructure exists
- ✅ Parallel Work Infrastructure - Complete
- ✅ Time Tracking Infrastructure - Complete
- ❌ Component Time Tracking Workflow - Missing
- ❌ Work Queue UI for Component Tokens - Missing
- ❌ Component Model (Task 5) - Planned

**วัตถุประสงค์:**
- รายงานสถานะ Component Token ในระบบปัจจุบัน
- ระบุว่าอะไรทำแล้ว, อะไรยังขาด
- ระบุ Blocker สำหรับ production

**Target Audience:** Stakeholders, Project Manager, Developers (เพื่อรู้สถานะ)

---

### 1.2 Subgraph Governance Audit

**File:** `docs/dag/00-audit/20251202_SUBGRAPH_GOVERNANCE_AUDIT_REPORT.md`

**สถานะ:** ✅ Audit Report (ตรวจสอบสถานะปัจจุบัน)

**เนื้อหา:**
- ✅ Database Schema - Complete
- ✅ Version Pinning - Complete
- ✅ Signature Compatibility Check - Complete
- ✅ Recursive Reference Detection - Complete
- ✅ Delete Protection Checks - Implemented
- ❌ Binding Population Logic - Missing (CRITICAL GAP)

**วัตถุประสงค์:**
- รายงานสถานะ Subgraph Governance ในระบบปัจจุบัน
- ระบุว่า Phase 5.8 ทำครบหรือยัง
- ระบุ Critical Gap (binding population)

**Target Audience:** Stakeholders, Developers (เพื่อรู้สถานะ Phase 5.8)

---

### 1.3 Subgraph vs Component Comparison Audit

**File:** `docs/dag/00-audit/20251202_SUBGRAPH_VS_COMPONENT_AUDIT_REPORT.md`

**สถานะ:** 🔄 Hybrid (Audit + Concept Analysis)

**เนื้อหา:**
- ✅ Current Subgraph status (audit)
- ✅ Component Token status (audit)
- ✅ Key differences analysis (concept)
- ✅ Conflict identification (concept)
- ✅ Decision tree (guidance)
- ✅ NEW Subgraph concept (updated concept)

**วัตถุประสงค์:**
- เปรียบเทียบ Subgraph vs Component Token
- ระบุความแตกต่างและ use cases
- ให้คำแนะนำว่าใช้อันไหนเมื่อไหร่
- อัปเดตด้วย NEW Subgraph concept (Module Template)

**Target Audience:** Architects, Developers (เพื่อเข้าใจความแตกต่างและตัดสินใจ)

---

## หมวดที่ 2: 🎯 CONCEPT DOCUMENTS (จุดหมาย แนวคิด Target)

เอกสารเหล่านี้ **อธิบายแนวคิด** และ **จุดหมายที่จะทำ**  
**วัตถุประสงค์:** ให้ AI Agents และ Developers เข้าใจ "Vision" ก่อน implement

### 2.1 Component Parallel Flow - Concept Flow

**File:** `docs/dag/01-concepts/COMPONENT_PARALLEL_FLOW.md`

**สถานะ:** 🎯 Concept Document (แนวคิด Target - มาตรฐานกลาง)

**เนื้อหา:**
- Entity หลัก: Final Token, Component Token, Job Tray
- จุดกำเนิด Final Serial (Job Creation)
- Parallel Split → Component Token creation
- Physical Flow (ถาดงาน)
- Component Work (parallel, separate time)
- Component QC
- Assembly / Merge
- Component Serial = Label Only
- ข้อห้าม (Anti-patterns) 6 ข้อ

**วัตถุประสงค์:**
- อธิบาย Concept Flow แบบ "อ่านง่าย" สำหรับ AI Agents
- ให้เข้าใจ "ภาพรวม" ของ Component Token workflow
- ให้เข้าใจ Physical Reality (ถาดงาน) + Digital mapping

**Target Audience:** AI Agents, New Developers (เพื่อเข้าใจ Vision)

**คำแนะนำการใช้:**
- อ่าน **ก่อน** ลงมือ implement Component Token
- ใช้เป็น "คู่มือแนวคิด" ไม่ใช่ technical spec

---

### 2.2 Subgraph Module Template - Concept

**File:** `docs/dag/01-concepts/SUBGRAPH_MODULE_TEMPLATE.md`

**สถานะ:** 🎯 Concept Document (แนวคิดใหม่ Target - มาตรฐานกลาง)

**เนื้อหา:**
- Graph Classification: Product vs Module
- Subgraph Reference Rules (Product → Module only)
- Component Token + Module Graph integration
- Module Graph as "สูตรทำชิ้นส่วน"
- Subgraph Execution Mode (same_token only)
- Migration Path (OLD → NEW)
- Anti-patterns

**วัตถุประสงค์:**
- อธิบาย **แนวคิดใหม่** ของ Subgraph (Module Template)
- แก้ปัญหา "Product อ้าง Product" → โครงสร้างมั่ว
- ให้เข้าใจว่า Module Graph = Template (ไม่ใช่ Product)

**Target Audience:** Architects, AI Agents (เพื่อเข้าใจแนวคิดใหม่)

**คำแนะนำการใช้:**
- อ่าน **ก่อน** ใช้ Subgraph กับ Component Token
- ใช้เป็น "คู่มือแนวคิดใหม่" ของ Subgraph

---

## หมวดที่ 3: 📐 SPECIFICATION DOCUMENTS (Technical Specs สำหรับ Implementation)

เอกสารเหล่านี้ **ระบุรายละเอียดทางเทคนิค** สำหรับ implement  
**วัตถุประสงค์:** ให้ Developers ใช้เป็น "blueprint" ในการเขียน code

### 3.1 Component Parallel Flow - Implementation Spec

**File:** `docs/dag/02-specs/COMPONENT_PARALLEL_FLOW_SPEC.md`

**สถานะ:** 📐 Technical Specification (Implementation-Ready - มาตรฐานกลาง)

**เนื้อหา:**
- Core Principle: Component Tokens = First-Class Tokens
- Component Tokens Have Work Sessions (TokenWorkSessionService)
- Behavior Execution Support Matrix (which behaviors support component)
- Node-to-Component Mapping (produces_component, consumes_components)
- Parallel Routing (splitToken, parallel_group_id)
- Assembly Node (merge semantics, data contract)
- Work Queue Integration (assignment rules, UI requirements)
- Data Model Requirements (database schema)
- Integration Points (Behavior, Work Queue, Time Engine)
- Implementation Checklist (Priority 1, 2, 3)
- Implementation Gaps Summary
- Anti-Patterns

**วัตถุประสงค์:**
- ให้ Developers ใช้เป็น Technical Spec ในการ implement
- ระบุ Database Schema, API Contracts, Validation Rules
- ระบุ Implementation Checklist (ทำอะไรบ้าง, ลำดับไหน)

**Target Audience:** Developers (เพื่อ implement)

**คำแนะนำการใช้:**
- อ่าน **หลังจาก** อ่าน Concept Flow แล้ว
- ใช้เป็น "blueprint" ในการเขียน code
- Follow Implementation Checklist

---

### 3.2 Behavior App Contract

**File:** `docs/dag/02-specs/BEHAVIOR_APP_SPEC.md`

**สถานะ:** 📐 Technical Specification (API Contract - มาตรฐานกลาง)

**เนื้อหา:**
- Core Concept: Behavior = App
- API Contract (input/output/error codes)
- UI Contract (template-based, executeBehavior)
- Logging Contract (dag_behavior_log, canonical events)
- Domain Rules (behavior-specific vs domain-specific)
- Backend Handler Structure (handleStitch, handleSinglePiece, handleQc, handleCut, handleEdge)
- UI Handler Structure (template-based vs per-behavior)
- Error Codes (current vs target)
- Status Legend (✅ Current, 🚧 Partial, 📋 Target/TODO)

**วัตถุประสงค์:**
- ระบุ Contract ของ Behavior App (API, UI, Logging)
- ให้ Developers เข้าใจว่า Behavior = App (ไม่ใช่ if/else)
- ระบุ Handler patterns และ Family-based execution

**Target Audience:** Developers (เพื่อ implement Behavior handlers)

**คำแนะนำการใช้:**
- อ่านเมื่อต้อง implement Behavior handlers
- ใช้เป็น API Contract reference
- Follow Handler patterns (Family-based execution)

---

## หมวดที่ 4: ✅ IMPLEMENTATION CHECKLISTS (แผนการทำงาน)

เอกสารเหล่านี้ **ระบุขั้นตอนการทำงาน** และ **Priority**  
**วัตถุประสงค์:** ให้ Developers รู้ว่า "ต้องทำอะไรบ้าง" และ "ลำดับไหนก่อน"

### 4.1 Subgraph Module Implementation Checklist

**File:** `docs/dag/03-checklists/SUBGRAPH_MODULE_IMPLEMENTATION.md`

**สถานะ:** ✅ Implementation Checklist (แผนการทำงาน)

**เนื้อหา:**
- Priority 1: Database Schema (graph_type, is_reusable_template)
- Priority 2: Validation Rules (Product-to-Product prevention)
- Priority 3: Graph Designer UI (type selector, filter)
- Priority 4: API Updates (list_module_graphs)
- Priority 5: Current Implementation Alignment
- Priority 6: Documentation Updates
- Validation Checklist
- Estimated Time (10-16 hours)

**วัตถุประสงค์:**
- ให้ Developers รู้ว่าต้องทำอะไรบ้าง
- ระบุ Priority และ Estimated Time
- ระบุไฟล์ที่ต้องแก้

**Target Audience:** Developers (เพื่อทำตาม checklist)

**คำแนะนำการใช้:**
- ใช้เป็น "แผนการทำงาน" สำหรับ implement Module Graph concept
- Follow Priority 1 → 2 → 3 → 4 → 5 → 6

---

## สรุปการจัดหมวดหมู่

### 📊 Audit Reports (สถานะปัจจุบัน)

| ไฟล์ | หัวข้อ | Target Audience |
|------|--------|-----------------|
| `COMPONENT_PARALLEL_WORK_AUDIT.md` | Component Token status | Stakeholders, PM, Devs |
| `FULL_SUBGRAPH_GOVERNANCE_AUDIT.md` | Subgraph Governance status | Stakeholders, Devs |
| `SUBGRAPH_VS_COMPONENT_CONCEPT_AUDIT.md` | Comparison + NEW concept | Architects, Devs |

**วัตถุประสงค์:** รู้สถานะว่า "ทำไปแล้วอะไร, ยังขาดอะไร"

---

### 🎯 Concept Documents (แนวคิด Vision Target)

| ไฟล์ | หัวข้อ | Target Audience |
|------|--------|-----------------|
| `COMPONENT_PARALLEL_FLOW_CONCEPT.md` | Component Token concept flow | AI Agents, New Devs |
| `SUBGRAPH_MODULE_TEMPLATE_CONCEPT.md` | NEW Subgraph concept (Module Template) | Architects, AI Agents |
| `BEHAVIOR_APP_CONTRACT.md` | Behavior = App concept | Devs |

**วัตถุประสงค์:** เข้าใจ "Vision" และ "แนวคิด" ก่อน implement

**อ่านเมื่อไหร่:**
- ก่อนเริ่ม implement feature ใหม่
- เมื่อต้องการเข้าใจ "ทำไม" (not just "ทำอะไร")
- เมื่อต้องการเข้าใจภาพรวม

---

### 📐 Technical Specifications (Blueprint สำหรับ Implementation)

| ไฟล์ | หัวข้อ | Target Audience |
|------|--------|-----------------|
| `SPEC_COMPONENT_PARALLEL_FLOW.md` | Component Token implementation spec | Developers |
| `BEHAVIOR_APP_CONTRACT.md` | Behavior API/UI contract | Developers |

**วัตถุประสงค์:** ใช้เป็น "blueprint" ในการเขียน code

**อ่านเมื่อไหร่:**
- เมื่อต้อง implement Component Token
- เมื่อต้อง implement Behavior handlers
- เมื่อต้องการรายละเอียดทางเทคนิค (schema, API contract)

---

### ✅ Implementation Checklists (แผนการทำงาน)

| ไฟล์ | หัวข้อ | Target Audience |
|------|--------|-----------------|
| `SUBGRAPH_MODULE_IMPLEMENTATION_CHECKLIST.md` | Subgraph Module implementation plan | Developers |

**วัตถุประสงค์:** ให้รู้ว่า "ต้องทำอะไรบ้าง" และ "ลำดับไหน"

**อ่านเมื่อไหร่:**
- เมื่อเริ่ม implement feature
- เมื่อต้องการ estimate เวลา
- เมื่อต้องการ track progress

---

## Workflow: จากเอกสารไปสู่ Implementation

### Step 1: เข้าใจ Vision (Concept Documents)

**อ่านก่อน:**
1. `COMPONENT_PARALLEL_FLOW_CONCEPT.md` (Component Token vision)
2. `SUBGRAPH_MODULE_TEMPLATE_CONCEPT.md` (NEW Subgraph vision)

**เวลา:** 30-60 นาที

**วัตถุประสงค์:** เข้าใจ "ทำไม" และ "ภาพรวม"

---

### Step 2: ตรวจสอบสถานะปัจจุบัน (Audit Reports)

**อ่านต่อ:**
1. `COMPONENT_PARALLEL_WORK_AUDIT.md` (Component status)
2. `FULL_SUBGRAPH_GOVERNANCE_AUDIT.md` (Subgraph status)
3. `SUBGRAPH_VS_COMPONENT_CONCEPT_AUDIT.md` (Comparison)

**เวลา:** 20-30 นาที

**วัตถุประสงค์:** รู้ว่า "ทำไปแล้วอะไร, ยังขาดอะไร"

---

### Step 3: อ่านรายละเอียดทางเทคนิค (Technical Specs)

**อ่านก่อน implement:**
1. `SPEC_COMPONENT_PARALLEL_FLOW.md` (Component implementation spec)
2. `BEHAVIOR_APP_CONTRACT.md` (Behavior API contract)

**เวลา:** 40-60 นาที

**วัตถุประสงค์:** เข้าใจรายละเอียดทางเทคนิค (schema, API, validation)

---

### Step 4: Follow Implementation Checklist

**ใช้ checklist:**
1. `SUBGRAPH_MODULE_IMPLEMENTATION_CHECKLIST.md`
2. Implementation Checklist จาก `SPEC_COMPONENT_PARALLEL_FLOW.md`

**เวลา:** ตาม checklist (10-16 hours)

**วัตถุประสงค์:** Implement ตาม Priority และ track progress

---

## Document Dependency Map

```
Vision / Concept (อ่านก่อน)
   ├─ COMPONENT_PARALLEL_FLOW_CONCEPT.md
   └─ SUBGRAPH_MODULE_TEMPLATE_CONCEPT.md
         ↓
Current Status (อ่านต่อ)
   ├─ COMPONENT_PARALLEL_WORK_AUDIT.md
   ├─ FULL_SUBGRAPH_GOVERNANCE_AUDIT.md
   └─ SUBGRAPH_VS_COMPONENT_CONCEPT_AUDIT.md
         ↓
Technical Details (อ่านก่อน implement)
   ├─ SPEC_COMPONENT_PARALLEL_FLOW.md
   └─ BEHAVIOR_APP_CONTRACT.md
         ↓
Implementation (ทำตาม)
   ├─ SUBGRAPH_MODULE_IMPLEMENTATION_CHECKLIST.md
   └─ Implementation Checklist (in SPEC_COMPONENT_PARALLEL_FLOW.md)
```

---

## Quick Reference: เอกสารไหนตอบคำถามอะไร

### คำถาม: "Component Token คืออะไร? ทำไมต้องมี?"
**อ่าน:** `COMPONENT_PARALLEL_FLOW_CONCEPT.md` (Section 1, 2)

### คำถาม: "Component Token ทำไปแล้วอะไรบ้าง? ยังขาดอะไร?"
**อ่าน:** `COMPONENT_PARALLEL_WORK_AUDIT.md` (Executive Summary, Section 10)

### คำถาม: "Component Token ต้อง implement อย่างไร?"
**อ่าน:** `SPEC_COMPONENT_PARALLEL_FLOW.md` (Section 12: Implementation Checklist)

### คำถาม: "Subgraph กับ Component Token ต่างกันยังไง?"
**อ่าน:** `SUBGRAPH_VS_COMPONENT_CONCEPT_AUDIT.md` (Section 3, 11: Decision Tree)

### คำถาม: "Subgraph คืออะไร? (แนวคิดใหม่)"
**อ่าน:** `SUBGRAPH_MODULE_TEMPLATE_CONCEPT.md` (Section 1, 2)

### คำถาม: "Subgraph Module ต้อง implement อย่างไร?"
**อ่าน:** `SUBGRAPH_MODULE_IMPLEMENTATION_CHECKLIST.md` (Section: Implementation Summary)

### คำถาม: "Behavior App คืออะไร? ต้องเขียน handler อย่างไร?"
**อ่าน:** `BEHAVIOR_APP_CONTRACT.md` (Section 1-7)

---

## Maintenance Guidelines

### เมื่อ implement เสร็จ:

**อัปเดต Audit Reports:**
- ✅ → ❌ (เปลี่ยนสถานะจาก Missing เป็น Complete)
- เพิ่ม implementation date

**อัปเดต Specs:**
- เปลี่ยน "📋 Target/TODO" → "✅ Current"
- อัปเดต version number

**อัปเดต Checklists:**
- ✅ Check off completed items
- เพิ่ม actual time spent

### เมื่อพบ Bug หรือ Gap:

**อัปเดต Audit Reports:**
- เพิ่ม issue ใหม่ใน "Gaps" section
- ระบุ severity (🔴 Critical, 🟡 Medium, 🟢 Low)

**อัปเดต Specs:**
- เพิ่ม validation rule ใหม่ (ถ้าจำเป็น)
- เพิ่ม anti-pattern ใหม่

---

## Summary Table

| Document | Type | Purpose | Read When | Target Audience |
|----------|------|---------|-----------|----------------|
| `00-audit/20251202_COMPONENT_PARALLEL_WORK_AUDIT_REPORT.md` | 📊 Audit | สถานะปัจจุบัน Component | รู้สถานะ | Stakeholders, PM, Devs |
| `00-audit/20251202_SUBGRAPH_GOVERNANCE_AUDIT_REPORT.md` | 📊 Audit | สถานะปัจจุบัน Subgraph | รู้สถานะ Phase 5.8 | Stakeholders, Devs |
| `00-audit/20251202_SUBGRAPH_VS_COMPONENT_AUDIT_REPORT.md` | 🔄 Hybrid | เปรียบเทียบ + NEW concept | เข้าใจความแตกต่าง | Architects, Devs |
| `02-concepts/COMPONENT_PARALLEL_FLOW.md` | 🎯 Concept | Component Token vision | ก่อน implement | AI Agents, New Devs |
| `02-concepts/SUBGRAPH_MODULE_TEMPLATE.md` | 🎯 Concept | NEW Subgraph vision | ก่อน implement | Architects, AI Agents |
| `03-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` | 📐 Spec | Component implementation spec | ขณะ implement | Developers |
| `../developer/03-superdag/03-specs/BEHAVIOR_APP_CONTRACT.md` | 📐 Spec | Behavior API contract | implement Behavior | Developers |
| `07-checklists/SUBGRAPH_MODULE_IMPLEMENTATION.md` | ✅ Checklist | Subgraph Module plan | implement Subgraph | Developers |

---

**Last Updated:** 2025-01-XX  
**Maintained By:** Documentation Team


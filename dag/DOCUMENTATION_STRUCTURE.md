# Documentation Structure - docs/dag/

**Last Updated:** 2025-12-02  
**Purpose:** อธิบายโครงสร้างเอกสารและการใช้งาน

---

## Folder Structure

```
docs/dag/
├── 00-audit/              📊 AUDIT REPORTS (สถานะปัจจุบัน)
│   ├── README.md
│   ├── DOCUMENT_CLASSIFICATION_INDEX.md
│   ├── 20251202_COMPONENT_PARALLEL_WORK_AUDIT_REPORT.md
│   ├── 20251202_SUBGRAPH_GOVERNANCE_AUDIT_REPORT.md
│   └── 20251202_SUBGRAPH_VS_COMPONENT_AUDIT_REPORT.md
│
├── 01-concepts/           🎯 CONCEPT DOCUMENTS (แนวคิด Vision)
│   ├── README.md
│   ├── COMPONENT_PARALLEL_FLOW.md
│   └── SUBGRAPH_MODULE_TEMPLATE.md
│
├── 02-specs/              📐 TECHNICAL SPECS (Blueprint)
│   ├── README.md
│   ├── COMPONENT_PARALLEL_FLOW_SPEC.md
│   └── BEHAVIOR_APP_SPEC.md
│
├── 03-checklists/         ✅ IMPLEMENTATION CHECKLISTS (แผนการทำงาน)
│   ├── README.md
│   └── SUBGRAPH_MODULE_IMPLEMENTATION.md
│
├── 00-overview/           📖 Overview & Introduction
├── 01-roadmap/            🗺️ Implementation Roadmap
├── 02-implementation-status/  📊 Detailed Status (legacy)
├── 03-tasks/              📋 Task Documentation
└── README.md              📚 Main Index
```

---

## Naming Conventions

### 📊 Audit Reports (`00-audit/`)

**Format:** `YYYYMMDD_TOPIC_AUDIT_REPORT.md`

**Rules:**
- ✅ วันที่ในชื่อไฟล์ (วันที่ทำการ Audit)
- ✅ ลงท้ายด้วย `_AUDIT_REPORT.md`
- ✅ สามารถมีหลายไฟล์ (audit ซ้ำได้ตามวันที่)

**Example:**
- `20251202_COMPONENT_PARALLEL_WORK_AUDIT_REPORT.md`
- `20251215_COMPONENT_PARALLEL_WORK_AUDIT_REPORT.md` (audit ครั้งที่ 2)

---

### 🎯 Concept Documents (`01-concepts/`)

**Format:** `TOPIC_NAME.md` (ไม่มีวันที่)

**Rules:**
- ❌ ไม่มีวันที่ในชื่อไฟล์
- ✅ ระบุ Version และ Last Updated ในเนื้อหา
- ✅ ไฟล์เดียว = Single Source of Truth
- ✅ เมื่อแนวคิดเปลี่ยน → แก้ไขไฟล์เดิม (ไม่สร้างใหม่)

**Example:**
- `COMPONENT_PARALLEL_FLOW.md` (Version 1.1, Last Updated: 2025-12-02)
- `SUBGRAPH_MODULE_TEMPLATE.md` (Version 2.0, Last Updated: 2025-12-02)

---

### 📐 Technical Specs (`02-specs/`)

**Format:** `TOPIC_NAME_SPEC.md` (ไม่มีวันที่)

**Rules:**
- ❌ ไม่มีวันที่ในชื่อไฟล์
- ✅ ลงท้ายด้วย `_SPEC.md`
- ✅ ระบุ Version และ Last Updated ในเนื้อหา
- ✅ ไฟล์เดียว = Single Source of Truth
- ✅ เมื่อ requirements เปลี่ยน → แก้ไขไฟล์เดิม

**Example:**
- `COMPONENT_PARALLEL_FLOW_SPEC.md` (Version 1.3, Last Updated: 2025-12-02)
- `BEHAVIOR_APP_SPEC.md` (Version 1.2, Last Updated: 2025-12-01)

---

### ✅ Implementation Checklists (`03-checklists/`)

**Format:** `TOPIC_NAME_IMPLEMENTATION.md` (ไม่มีวันที่)

**Rules:**
- ❌ ไม่มีวันที่ในชื่อไฟล์
- ✅ ลงท้ายด้วย `_IMPLEMENTATION.md`
- ✅ อัปเดตได้เรื่อยๆ (check off items, add notes)
- ✅ สามารถมีหลาย version (เก็บ history)

**Example:**
- `SUBGRAPH_MODULE_IMPLEMENTATION.md`
- `COMPONENT_TOKEN_IMPLEMENTATION.md`

---

## Document Categories

### 📊 Audit Reports (00-audit/)

**Purpose:** ตรวจสอบสถานะปัจจุบัน

**Target Audience:** Stakeholders, PM, Developers

**Update Frequency:** 
- หลัง implement feature ใหม่
- ก่อนเริ่ม implementation (audit ปัจจุบัน)
- Review ประจำเดือน/ไตรมาส

**Content:**
- สถานะปัจจุบัน (✅ Complete, ❌ Missing)
- Infrastructure ที่มีอยู่
- Gaps ที่ยังขาด
- Priority recommendations

---

### 🎯 Concept Documents (02-concepts/)

**Purpose:** แนวคิดและ Vision ของระบบ

**Target Audience:** AI Agents, New Developers, Architects

**Update Frequency:**
- เมื่อแนวคิดเปลี่ยน (แก้ไขไฟล์เดิม)
- เมื่อเพิ่มรายละเอียด (แก้ไขไฟล์เดิม)

**Content:**
- Core Principle
- Entity Relationships
- Flow Summary
- Physical Reality mapping
- Critical Rules
- Anti-Patterns

**⚠️ IMPORTANT:**
- **ไฟล์นี้เป็นมาตรฐานกลาง** (Single Source of Truth)
- **แก้ไขไฟล์เดิม** (ไม่สร้างไฟล์ใหม่)
- **ใช้ Version Control** (Git) เพื่อ track changes

---

### 📐 Technical Specs (03-specs/)

**Purpose:** รายละเอียดทางเทคนิคสำหรับ Implementation

**Target Audience:** Developers

**Update Frequency:**
- เมื่อ technical requirements เปลี่ยน
- เมื่อ schema เปลี่ยน
- เมื่อ API contract เปลี่ยน

**Content:**
- Database Schema
- API Contracts (Input/Output)
- Validation Rules
- Integration Points
- Implementation Checklist
- Implementation Gaps

**⚠️ IMPORTANT:**
- **ไฟล์นี้เป็นมาตรฐานกลาง** (Single Source of Truth)
- **แก้ไขไฟล์เดิม** (ไม่สร้างไฟล์ใหม่)
- **ใช้ Version Control** (Git) เพื่อ track changes

---

### ✅ Implementation Checklists (07-checklists/)

**Purpose:** แผนการทำงานและ Progress Tracking

**Target Audience:** Developers

**Update Frequency:**
- Daily (during implementation)
- Weekly (progress review)

**Content:**
- Priority-based tasks (1-3)
- Estimated time
- Validation checklist
- Current implementation status

**Update Policy:**
- Check off completed items (✅)
- Add notes/issues (📝)
- Update actual time spent

---

## Workflow: From Concept to Implementation

### Step 1: เข้าใจ Concept (30-60 min)

**อ่าน:** `01-concepts/`
- `COMPONENT_PARALLEL_FLOW.md`
- `SUBGRAPH_MODULE_TEMPLATE.md`

**วัตถุประสงค์:** เข้าใจ Vision และ "ทำไม"

---

### Step 2: ตรวจสอบสถานะปัจจุบัน (15-30 min)

**อ่าน:** `00-audit/`
- `20251202_COMPONENT_PARALLEL_WORK_AUDIT_REPORT.md`
- `20251202_SUBGRAPH_GOVERNANCE_AUDIT_REPORT.md`

**วัตถุประสงค์:** รู้ว่า "ทำไปแล้วอะไร, ยังขาดอะไร"

---

### Step 3: อ่านรายละเอียดทางเทคนิค (40-60 min)

**อ่าน:** `02-specs/`
- `COMPONENT_PARALLEL_FLOW_SPEC.md`
- `BEHAVIOR_APP_SPEC.md`

**วัตถุประสงค์:** เข้าใจรายละเอียดทางเทคนิค

---

### Step 4: Follow Checklist (10-30 hours)

**ใช้:** `03-checklists/`
- `SUBGRAPH_MODULE_IMPLEMENTATION.md`
- Implementation Checklist (in Spec, Section 12)

**วัตถุประสงค์:** Implement ตาม Priority และ track progress

---

## Maintenance Rules

### ✅ DO (ควรทำ)

**Audit Reports:**
- ✅ สร้างไฟล์ใหม่ทุกครั้งที่ Audit (พร้อมวันที่)
- ✅ เก็บ history (ไฟล์เก่าไม่ต้องลบ)

**Concept Documents:**
- ✅ แก้ไขไฟล์เดิม (ไม่สร้างใหม่)
- ✅ อัปเดต Version number
- ✅ ใช้ Git เพื่อ track changes

**Technical Specs:**
- ✅ แก้ไขไฟล์เดิม (ไม่สร้างใหม่)
- ✅ อัปเดต Version number
- ✅ Document breaking changes

**Checklists:**
- ✅ อัปเดตได้เรื่อยๆ (check off items)
- ✅ เพิ่ม notes/issues

---

### ❌ DON'T (ไม่ควรทำ)

**Concept Documents:**
- ❌ ห้ามสร้างไฟล์ชื่อคล้ายๆ กัน (เช่น COMPONENT_PARALLEL_FLOW_V2.md)
- ❌ ห้าม archive ไฟล์เดิม (ใช้ Git history แทน)
- ❌ ห้ามสร้าง "final" version (ใช้ version number แทน)

**Technical Specs:**
- ❌ ห้ามสร้างไฟล์ใหม่ทุกครั้งที่แก้ spec
- ❌ ห้ามมีหลาย spec ของ topic เดียวกัน

**Checklists:**
- ❌ ห้าม hard-code วันที่ในชื่อไฟล์

---

## Quick Reference

### Finding Documents:

**ต้องการเข้าใจแนวคิด:**
→ `05-concepts/`

**ต้องการรู้สถานะปัจจุบัน:**
→ `04-audit/` (ดูวันที่ล่าสุด)

**ต้องการรายละเอียดทางเทคนิค:**
→ `06-specs/` (Component/Subgraph)
→ `docs/developer/03-superdag/03-specs/` (Behavior App)

**ต้องการแผนการทำงาน:**
→ `07-checklists/`

---

**Maintained By:** Documentation Team


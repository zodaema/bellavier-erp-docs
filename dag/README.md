# DAG Documentation

**Purpose:** Central documentation hub for SuperDAG system  
**Last Updated:** 2025-12-02

---

## Folder Structure

```
docs/dag/
├── 00-audit/              📊 Audit Reports (สถานะปัจจุบัน)
├── 01-core/               🏗️ Core Architecture
├── 02-concepts/           🎯 Concept Documents (แนวคิด Vision)
├── 03-specs/              📐 Technical Specifications (Blueprint)
├── 04-tasks/              📋 Task Documentation
├── 05-implementation-status/  📊 Detailed Implementation Status
├── 06-overview/           📖 Overview & Introduction
├── 07-checklists/         ✅ Implementation Checklists (แผนการทำงาน)
└── 08-roadmap/            🗺️ Implementation Roadmap
```

---

## Quick Start

### 🆕 New to DAG System?

**Start Here:**
1. `00-overview/DAG_OVERVIEW.md` - ภาพรวมของ SuperDAG
2. `01-concepts/COMPONENT_PARALLEL_FLOW.md` - Component Token concept
3. `01-concepts/SUBGRAPH_MODULE_TEMPLATE.md` - Subgraph Module concept

**Time:** 1-2 hours

---

### 🔨 Ready to Implement?

**Component Token:**
1. Read `02-concepts/COMPONENT_PARALLEL_FLOW.md` (concept)
2. Read `00-audit/20251202_COMPONENT_PARALLEL_WORK_AUDIT_REPORT.md` (status)
3. Read `03-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` (technical spec)
4. Follow Implementation Checklist (in spec, Section 12)

**Subgraph Module:**
1. Read `02-concepts/SUBGRAPH_MODULE_TEMPLATE.md` (concept)
2. Read `00-audit/20251202_SUBGRAPH_GOVERNANCE_AUDIT_REPORT.md` (status)
3. Follow `07-checklists/SUBGRAPH_MODULE_IMPLEMENTATION.md`

---

### 🔍 Looking for Specific Info?

**"Component Token คืออะไร?"**
→ `02-concepts/COMPONENT_PARALLEL_FLOW.md` (Section 1)

**"Component Token ทำไปแล้วอะไรบ้าง?"**
→ `00-audit/20251202_COMPONENT_PARALLEL_WORK_AUDIT_REPORT.md` (Executive Summary)

**"Component Token ต้อง implement อย่างไร?"**
→ `03-specs/COMPONENT_PARALLEL_FLOW_SPEC.md` (Section 12)

**"Subgraph กับ Component ต่างกันยังไง?"**
→ `00-audit/20251202_SUBGRAPH_VS_COMPONENT_AUDIT_REPORT.md` (Section 11: Decision Tree)

**"Subgraph คืออะไร? (แนวคิดใหม่)"**
→ `02-concepts/SUBGRAPH_MODULE_TEMPLATE.md` (Section 1-2)

---

## Document Types

### 📊 Audit Reports (`00-audit/`)

**Purpose:** รายงานสถานะปัจจุบัน

**Naming:** `YYYYMMDD_TOPIC_AUDIT_REPORT.md`

**Read When:** ต้องการรู้สถานะว่า "ทำไปแล้วอะไร, ยังขาดอะไร"

**Target Audience:** Stakeholders, PM, Developers

---

### 🎯 Concept Documents (`02-concepts/`)

**Purpose:** อธิบายแนวคิดและ Vision

**Naming:** `TOPIC_NAME.md` (ไม่มีวันที่)

**Read When:** ก่อนเริ่ม implement (เพื่อเข้าใจ "ทำไม")

**Target Audience:** AI Agents, New Developers, Architects

**Update Policy:** แก้ที่ไฟล์เดิม (ไม่สร้างไฟล์ใหม่)

---

### 📐 Technical Specs (`03-specs/`)

**Purpose:** รายละเอียดทางเทคนิค (Schema, API, Validation)

**Naming:** `TOPIC_NAME_SPEC.md` (ไม่มีวันที่)

**Read When:** ขณะ implement (ใช้เป็น blueprint)

**Target Audience:** Developers

**Update Policy:** แก้ที่ไฟล์เดิม เมื่อ technical requirements เปลี่ยน

**⚠️ Note:** Behavior App Spec อยู่ที่ `docs/developer/03-superdag/03-specs/BEHAVIOR_APP_CONTRACT.md` (ไม่ย้าย)

---

### ✅ Implementation Checklists (`07-checklists/`)

**Purpose:** แผนการทำงานและ Progress Tracking

**Naming:** `TOPIC_NAME_IMPLEMENTATION.md` (ไม่มีวันที่)

**Read When:** เริ่ม implement และ track progress

**Target Audience:** Developers

**Update Policy:** อัปเดตได้เรื่อยๆ (check off items)

---

## Workflow: From Concept to Implementation

```
1. Concept (Vision)
   ├─ 02-concepts/COMPONENT_PARALLEL_FLOW.md
   └─ 02-concepts/SUBGRAPH_MODULE_TEMPLATE.md
         ↓
2. Current Status (Audit)
   ├─ 00-audit/20251202_COMPONENT_PARALLEL_WORK_AUDIT_REPORT.md
   └─ 00-audit/20251202_SUBGRAPH_GOVERNANCE_AUDIT_REPORT.md
         ↓
3. Technical Details (Spec)
   ├─ 03-specs/COMPONENT_PARALLEL_FLOW_SPEC.md
   └─ ../developer/03-superdag/03-specs/BEHAVIOR_APP_CONTRACT.md
         ↓
4. Implementation (Checklist)
   └─ 07-checklists/SUBGRAPH_MODULE_IMPLEMENTATION.md
```

---

## Related Documentation

**SuperDAG Core:**
- `docs/developer/03-superdag/01-core/` - Core architecture
- `docs/developer/03-superdag/02-reference/` - Reference materials
- `docs/developer/03-superdag/03-specs/` - Additional specs

**Implementation Status:**
- `docs/dag/02-implementation-status/` - Detailed implementation status
- `docs/dag/01-roadmap/DAG_IMPLEMENTATION_ROADMAP.md` - Master roadmap

**Tasks:**
- `docs/dag/03-tasks/` - Task-specific documentation
- `docs/super_dag/tasks/` - Legacy task documentation

---

## Maintenance

**Daily Updates:**
- Implementation Checklists (check off completed items)

**Weekly Updates:**
- Audit Reports (if significant progress)

**As Needed:**
- Concept Documents (when vision changes)
- Technical Specs (when requirements change)

---

**Last Updated:** 2025-12-02  
**Maintained By:** Documentation Team

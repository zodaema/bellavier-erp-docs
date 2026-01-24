# Super DAG - Implementation Documentation

**Purpose:** เอกสารสำหรับ implement SuperDAG features  
**Location:** `docs/super_dag/`

---

## 📁 Structure

```
docs/super_dag/
├── 00-audit/          📊 Audit Reports (สถานะปัจจุบัน)
├── 01-concepts/       🎯 Concept Documents (แนวคิด Vision)
├── 06-specs/          📐 Technical Specifications (Blueprint)
├── 03-checklists/     ✅ Implementation Checklists (แผนการทำงาน)
├── plans/             📋 Implementation Plans (how to implement)
├── tasks/             📋 Task Documentation (150+ tasks)
├── archive/           📦 Archived Documents
└── tests/             🧪 Test Documentation
```

---

## 🎯 Workflow for Implementation

```
1. Read Concept (Vision)
   └─ 01-concepts/
         ↓
2. Check Current Status (Audit)
   └─ 00-audit/ (ดูรายงานล่าสุด)
         ↓
3. Read Technical Details (Spec)
   └─ 06-specs/
         ↓
4. Follow Implementation Plan (Checklist)
   └─ 03-checklists/
         ↓
5. Implement & Test
```

---

## 📊 Quick Access

### Component Parallel Flow
1. **Concept:** `01-concepts/COMPONENT_PARALLEL_FLOW.md`
2. **Audit:** `00-audit/20251202_COMPONENT_PARALLEL_WORK_AUDIT_REPORT.md`
3. **Spec:** `06-specs/REFERENCE_SPECS.md` (Component Parallel Flow Spec v2.1)

### Token Lifecycle
1. **Spec:** `06-specs/REFERENCE_SPECS.md` (SuperDAG Token Lifecycle v1.0)

### Behavior Layer
1. **Audit:** `00-audit/20251202_BEHAVIOR_LAYER_AUDIT_REPORT.md`
2. **Developer Guide:** `../developer/03-superdag/03-specs/BEHAVIOR_APP_CONTRACT.md`

### Subgraph Module
1. **Concept:** `01-concepts/SUBGRAPH_MODULE_TEMPLATE.md`
2. **Audit:** `00-audit/20251202_SUBGRAPH_VS_COMPONENT_AUDIT_REPORT.md`
3. **Checklist:** `03-checklists/SUBGRAPH_MODULE_IMPLEMENTATION.md`

---

## 📁 Folder Descriptions

### 📊 00-audit/ - Audit Reports
**Purpose:** รู้ว่า "ทำไปแล้วอะไร, ยังขาดอะไร"  
**Naming:** `YYYYMMDD_TOPIC_AUDIT_REPORT.md`  
**Files:** 3 audit reports (Component, Behavior, Subgraph)

### 🎯 01-concepts/ - Concept Documents
**Purpose:** เข้าใจ "ทำไม" และ "ภาพรวม"  
**Naming:** `TOPIC_NAME.md` (no date, single source of truth)  
**Files:** 2 concepts (Component Flow, Subgraph Module)

### 📐 06-specs/ - Technical Specifications
**Purpose:** Blueprint สำหรับ implement  
**Location:** `docs/super_dag/06-specs/`  
**Files:** 
- SuperDAG System Specs (REFERENCE_SPECS.md, PHASE_1_IMPLEMENTATION.md)
- Material & QC Specs (MATERIAL_ARCHITECTURE_V2.md, MATERIAL_PRODUCTION_MASTER_SPEC.md, MATERIAL_REQUIREMENT_RESERVATION_SPEC.md, QC_POLICY_RULES.md)

### ✅ 03-checklists/ - Implementation Checklists
**Purpose:** Track progress  
**Naming:** `TOPIC_NAME_IMPLEMENTATION.md`  
**Files:** 1 checklist (Subgraph Module)

---

## 📚 Related Documentation

**Developer Guidelines:** `docs/developer/03-superdag/`
- Behavior App Contract (for developers to follow)
- Legacy specs (reference only)

**DAG Documentation:** `docs/dag/`
- Core architecture
- Roadmaps
- 150+ tasks

---

## 🎯 Key Principles

1. **Single Source of Truth:**
   - Concept/Spec = 1 file (แก้ไขไฟล์เดิม)
   - Audit = มีวันที่ (audit ซ้ำได้)

2. **Naming Convention:**
   - Audit: `YYYYMMDD_TOPIC_AUDIT_REPORT.md`
   - Concept: `TOPIC_NAME.md`
   - Spec: `TOPIC_NAME_SPEC.md`
   - Checklist: `TOPIC_NAME_IMPLEMENTATION.md`

3. **Update Policy:**
   - Concept/Spec: แก้ไขไฟล์เดิม
   - Checklist: อัปเดตได้เรื่อยๆ
   - Audit: สร้างใหม่เมื่อต้องการ audit

---

**Last Updated:** December 2, 2025

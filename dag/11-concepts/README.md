# Concept Documents

**Purpose:** เอกสารแนวคิดและ Vision ของระบบ  
**วัตถุประสงค์:** ให้เข้าใจ "ทำไม" และ "ภาพรวม" ก่อน implement

---

## Naming Convention

**Format:** `TOPIC_NAME.md` (ไม่มีวันที่)

**Example:**
- `COMPONENT_PARALLEL_FLOW.md`
- `SUBGRAPH_MODULE_TEMPLATE.md`

**Rules:**
- ไม่ระบุวันที่ในชื่อไฟล์ (เพราะเป็นมาตรฐานกลาง)
- ระบุวันที่ในเนื้อหา (Version, Last Updated)
- ไฟล์นี้เป็น "Single Source of Truth" ของแนวคิด
- เมื่อต้องการแก้แนวคิด → แก้ที่ไฟล์นี้ (ไม่สร้างไฟล์ใหม่)

---

## Current Concept Documents

### Component Parallel Flow

**File:** `COMPONENT_PARALLEL_FLOW.md`

**Version:** 1.1  
**Last Updated:** 2025-12-02

**Content:**
- Entity หลัก: Final Token, Component Token, Job Tray
- จุดกำเนิด Final Serial (Job Creation)
- Parallel Split + Module Graph
- Physical Flow (ถาดงาน)
- Component Work (parallel, separate time)
- Anti-patterns (6 ข้อห้าม)

**Target Audience:** AI Agents, New Developers

### Subgraph Module Template

**File:** `SUBGRAPH_MODULE_TEMPLATE.md`

**Version:** 2.0  
**Last Updated:** 2025-12-02

**Content:**
- Graph Classification: Product vs Module
- Subgraph = Module Template (NEW concept)
- Component Token + Module Graph integration
- Anti-patterns

**Target Audience:** Architects, AI Agents

---

**Maintained By:** Documentation Team

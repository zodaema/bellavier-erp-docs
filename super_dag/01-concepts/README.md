# SuperDAG Concept Documents

**Purpose:** เอกสารแนวคิดและ Vision ของระบบ SuperDAG  
**Location:** `docs/super_dag/01-concepts/`

---

## Naming Convention

`TOPIC_NAME.md` (ไม่มีวันที่)

**Single Source of Truth:** แก้ไขไฟล์เดิม (ไม่สร้างไฟล์ใหม่)

---

## Current Concept Documents

### 1. Component Parallel Flow
**File:** `COMPONENT_PARALLEL_FLOW.md`  
**Purpose:** อธิบายแนวคิด Component Token และ Parallel Work  

**Key Concepts:**
- **Final Token** = กระเป๋า 1 ใบ (final product)
- **Component Token** = ชิ้นส่วนย่อย (BODY, FLAP, STRAP)
- **Parallel Work** = ช่างทำพร้อมกัน, จับเวลาแยกกัน
- **Job Tray** = ถาดงาน (physical container, 1 final = 1 tray)
- **ETA Model** = max(component_times) + assembly_time
- **Final Serial** = เกิดที่ Job Creation (ไม่ใช่ Assembly)

**Core Mechanic:** Component Token = MANDATORY for Hatthasilpa workflow

### 2. Subgraph Module Template
**File:** `SUBGRAPH_MODULE_TEMPLATE.md`  
**Purpose:** แนวคิดใหม่ของ Subgraph (Module Template)  

**Key Concepts:**
- **Product Graph** = กราฟหลักของ product (1 product = 1 graph)
- **Module Graph** = Template ของ component/step (reusable)
- **Reference Rules:**
  - Product → Module ✅ (allowed)
  - Product → Product ❌ (not allowed)
  - Module → Module ✅ (allowed)
- **Component Token** uses Module Graph (not Subgraph fork)

---

## How to Use

**When:** ก่อนเริ่ม implement (เพื่อเข้าใจ "ทำไม")

**Target Audience:** AI Agents, New Developers, Architects

**Read before:**
- Starting implementation
- Designing new features
- Writing technical specs

---

## Update Policy

- **แก้ไขไฟล์เดิม** เมื่อ concept เปลี่ยน
- ไม่สร้างไฟล์ใหม่ (e.g., v2, final, etc.)
- ใช้ Git history เพื่อ track changes
- ระบุวันที่ Concept Date ใน header

---

## Related Documents

**Audit Reports:** `../00-audit/`  
**Technical Specs:** `../02-specs/`  
**Implementation Checklists:** `../03-checklists/`

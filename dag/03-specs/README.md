# Technical Specifications (03-specs/)

**Purpose:** รายละเอียดทางเทคนิคสำหรับ Implementation  
**วัตถุประสงค์:** ให้ Developers ใช้เป็น "Blueprint" ในการเขียน code

**Location:** `docs/dag/03-specs/`

---

## Naming Convention

**Format:** `TOPIC_NAME_SPEC.md` (ไม่มีวันที่)

**Example:**
- `COMPONENT_PARALLEL_FLOW_SPEC.md`

**Rules:**
- ไม่ระบุวันที่ในชื่อไฟล์ (เพราะเป็นมาตรฐานกลาง)
- ลงท้ายด้วย `_SPEC.md` เสมอ
- ไฟล์นี้เป็น "Single Source of Truth" ของ Technical Spec
- เมื่อต้องการแก้ spec → แก้ที่ไฟล์นี้ (ไม่สร้างไฟล์ใหม่)

---

## Current Specifications

### Component Parallel Flow

**File:** `COMPONENT_PARALLEL_FLOW_SPEC.md`

**Version:** 1.3  
**Last Updated:** 2025-12-02

**Content:**
- Database Schema
- API Contracts
- Validation Rules
- Implementation Checklist
- Anti-Patterns

**Target Audience:** Developers

---

## Related Specs (Other Locations)

### Behavior App

**File:** `docs/developer/03-superdag/03-specs/BEHAVIOR_APP_CONTRACT.md`

**Reason:** เป็นของโปรเจค SuperDAG (ไม่ย้าย)

---

**Maintained By:** Development Team

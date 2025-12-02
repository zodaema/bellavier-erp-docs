# Reference Documents

**Purpose:** Reference documentation for specific engines, rules, and technical details  
**Audience:** Developers working on specific features  
**Status:** Active Documentation (updated as needed)

---

## 📚 Overview

เอกสารในโฟลเดอร์นี้เป็น **เอกสารอ้างอิง** สำหรับ engines, rules, และ technical details เฉพาะเจาะจง  
อัพเดทเมื่อมีการเปลี่ยนแปลง rules หรือ technical details แต่ไม่จำเป็นต้องอัพเดทบ่อยเท่า Core Knowledge Documents

---

## 📋 Documents

### Engine References

1. **[condition_engine_overview.md](condition_engine_overview.md)**
   - Condition Engine overview
   - Condition evaluation logic
   - **Last Updated:** Task 19.2 (December 2025)

2. **[condition_field_registry.md](condition_field_registry.md)**
   - Registry ของ fields ที่ใช้ใน conditions
   - **Last Updated:** Task 19.2 (December 2025)

### Validation References

3. **[validation_engine_map.md](validation_engine_map.md)**
   - Validation Engine map
   - **Last Updated:** Task 19.19 (November 2025)

4. **[validation_dependency_graph.md](validation_dependency_graph.md)**
   - Dependency graph ของ Validation
   - **Last Updated:** Task 19.19 (November 2025)

5. **[validation_risk_register.md](validation_risk_register.md)**
   - Risk register สำหรับ validation
   - **Last Updated:** Task 19.19 (November 2025)

6. **[validation/](validation/)** - Validation detailed references
   - `validation_severity_matrix.md` - Severity classification
   - `validation_rule_ordering.md` - Execution order

### Semantic & Intent

7. **[semantic_intent_rules.md](semantic_intent_rules.md)**
   - Semantic Intent rules (QC Routing, Parallel Detection)
   - Intent Conflict Detection
   - **Last Updated:** Task 19.17 (November 2025)

### Risk & Scoring

8. **[autofix_risk_scoring.md](autofix_risk_scoring.md)**
   - Risk scoring สำหรับ AutoFix
   - **Last Updated:** Task 19.10 (December 2025)

### Timezone & Time References

9. **[timezone/](timezone/)** - Timezone references
   - `timezone_reference_map.json` - Timezone reference map

10. **[time/](time/)** - Time references (if any)

### Archived Documents 📦

11. **[validation_leanup_plan.md](../../super_dag/archive/cleanup_plans/validation_leanup_plan.md)** 📦 **ARCHIVED**
    - Cleanup plan for validation layer (superseded by v2)
    - **Location:** `docs/super_dag/archive/cleanup_plans/`

12. **[validation_leanup_plan_v2.md](../../super_dag/archive/cleanup_plans/validation_leanup_plan_v2.md)** 📦 **ARCHIVED**
    - Cleanup plan v2 for validation layer
    - **Location:** `docs/super_dag/archive/cleanup_plans/`

13. **[SuperDAG_Missing_Semantics.md](../../super_dag/archive/gap_analysis/SuperDAG_Missing_Semantics.md)** 📦 **ARCHIVED**
    - Missing semantics analysis
    - **Location:** `docs/super_dag/archive/gap_analysis/`

---

## 🎯 Usage

- **Reference when needed** - ไม่จำเป็นต้องอ่านทั้งหมด
- **Check before implementing** - ตรวจสอบ rules ก่อน implement feature ใหม่
- **Update when rules change** - อัพเดทเมื่อมีการเปลี่ยนแปลง rules

---

**Last Updated:** January 2025


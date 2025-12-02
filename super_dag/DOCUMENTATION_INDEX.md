# SuperDAG Documentation Index

**Last Updated:** January 2025 (Task 20-26 Complete)  
**Purpose:** Index สำหรับเอกสาร SuperDAG ทั้งหมด

> ⚠️ **NOTE:** Core documentation has been moved to `docs/developer/03-superdag/`  
> This index remains for reference to tasks, tests, and archive.

---

## 📁 โครงสร้างเอกสาร

### 📚 Core Documentation (Moved to Developer Docs)

**Location:** `docs/developer/03-superdag/`

- **[01-core/](../developer/03-superdag/01-core/)** - Core Knowledge Documents (ความรู้พื้นฐานสำหรับ Developer)
- **[02-reference/](../developer/03-superdag/02-reference/)** - Reference Documents (เอกสารอ้างอิง)
- **[03-specs/](../developer/03-superdag/03-specs/)** - Specifications (สเปกสำหรับเตรียม Implement)
- **[04-implementation/](../developer/03-superdag/04-implementation/)** - Implementation Guides (คู่มือการพัฒนา)
- **[05-planning/](../developer/03-superdag/05-planning/)** - Planning & Analysis (เอกสารการวางแผน)

**See:** [docs/developer/03-superdag/README.md](../developer/03-superdag/README.md) for complete documentation

### 📝 Task Documentation (Remain Here)

- **[tasks/](tasks/)** - Task Documentation (เอกสารงาน)
- **[task_index.md](task_index.md)** - Task Index (ดัชนีงานทั้งหมด)

### 📦 Archived Documents

- **[archive/](archive/)** - Archived Documents (เอกสารที่เก็บไว้)
  - `audits_reports/` - Completed audit reports and migration plans
  - `cleanup_plans/` - Cleanup and optimization plans
  - `gap_analysis/` - Gap analysis documents
  - `test_documentation/` - Test case documentation

---

## 📚 หมวดที่ 1: Core Knowledge Documents (ต้องอัพเดทให้ทัน)

---

## 📚 หมวดที่ 1: Core Knowledge Documents (ต้องอัพเดทให้ทัน)

เอกสารเหล่านี้เป็น **ความรู้พื้นฐาน** ที่ Dev ต้องอ่านก่อนเริ่มพัฒนา  
**ต้องอัพเดทให้สอดคล้องกับโค้ดจริง** ทุกครั้งที่มีการเปลี่ยนแปลงระบบ

### Architecture & System Design

- **[01-core/SuperDAG_Architecture.md](../developer/03-superdag/01-core/SuperDAG_Architecture.md)** ⭐ **CRITICAL**
  - สถาปัตยกรรมระบบจริง (6 layers)
  - API endpoints, Service classes, Database schema
  - **อัพเดทเมื่อ:** มีการเพิ่ม/แก้ไข Service, API, หรือ Database schema
  - **Last Updated:** Task 20.2.3 (January 2025)

- **[01-core/SuperDAG_Execution_Model.md](../developer/03-superdag/01-core/SuperDAG_Execution_Model.md)** ⭐ **CRITICAL**
  - Token State Machine, Execution Flow
  - Entry Points, State Transitions
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลง Token lifecycle หรือ Execution flow
  - **Last Updated:** Task 20.2.3 (January 2025)

- **[01-core/SuperDAG_Flow_Map.md](../developer/03-superdag/01-core/SuperDAG_Flow_Map.md)** ⭐ **CRITICAL**
  - Token Flow (Linear, Parallel, Conditional)
  - Merge Semantics, Rework Flow
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลง Routing logic หรือ Parallel/Merge behavior
  - **Last Updated:** Task 19.10 (December 2025)

### Core Principles & Blueprint

- **[01-core/core_principles_of_flexible_factory_erp.md](../developer/03-superdag/01-core/core_principles_of_flexible_factory_erp.md)**
  - หลักการออกแบบระบบ (12 หลักการ)
  - Canonical Event Framework
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลงหลักการหรือ Framework
  - **Last Updated:** Task 20.2 (January 2025)

- **[01-core/DAG_Blueprint.md](../developer/03-superdag/01-core/DAG_Blueprint.md)**
  - แผนหลักของ DAG Engine
  - Production Reality Model, Component Model
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลงโมเดลพื้นฐาน
  - **Last Updated:** November 2025

### Behavior & Node Models

- **[01-core/Node_Behavier.md](../developer/03-superdag/01-core/Node_Behavier.md)** ⭐ **CRITICAL**
  - สเปกพฤติกรรม Node (Canonical Spec)
  - Node Mode, Work Center Binding
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลง Node Mode หรือ Behavior definition
  - **Last Updated:** Task 21.1 (November 2025)

- **[01-core/node_behavior_model.md](../developer/03-superdag/01-core/node_behavior_model.md)** ⭐ **CRITICAL**
  - โมเดลพฤติกรรม Node (Aligned with Node_Behavier.md)
  - Execution Context, Canonical Events
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลง Behavior Model หรือ Execution Context
  - **Last Updated:** Task 21.1 (November 2025)

### Engine Models

- **[01-core/time_model.md](../developer/03-superdag/01-core/time_model.md)**
  - โมเดล Time Engine
  - Time tracking, Drift correction
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลง Time Engine logic
  - **Last Updated:** Task 20.2 (January 2025)

- **[02-reference/condition_engine_overview.md](../developer/03-superdag/02-reference/condition_engine_overview.md)**
  - ภาพรวม Condition Engine
  - Condition evaluation logic
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลง Condition evaluation
  - **Last Updated:** Task 19.2 (December 2025)

- **[02-reference/condition_field_registry.md](../developer/03-superdag/02-reference/condition_field_registry.md)**
  - Registry ของ fields ที่ใช้ใน conditions
  - **อัพเดทเมื่อ:** มีการเพิ่ม/แก้ไข condition fields
  - **Last Updated:** Task 19.2 (December 2025)

### Validation & Semantic

- **[02-reference/semantic_intent_rules.md](../developer/03-superdag/02-reference/semantic_intent_rules.md)**
  - กฎ Semantic Intent (QC Routing, Parallel Detection)
  - Intent Conflict Detection
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลง Semantic rules
  - **Last Updated:** Task 19.17 (November 2025)

- **[02-reference/validation_engine_map.md](../developer/03-superdag/02-reference/validation_engine_map.md)**
  - แผนที่ Validation Engine
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลง Validation modules
  - **Last Updated:** Task 19.19 (November 2025)

- **[02-reference/validation_dependency_graph.md](../developer/03-superdag/02-reference/validation_dependency_graph.md)**
  - Dependency graph ของ Validation
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลง Validation dependencies
  - **Last Updated:** Task 19.19 (November 2025)

- **[02-reference/validation/validation_severity_matrix.md](../developer/03-superdag/02-reference/validation/validation_severity_matrix.md)**
  - Severity classification สำหรับ validation rules
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลง severity rules
  - **Last Updated:** Task 19.21 (November 2025)

- **[02-reference/validation/validation_rule_ordering.md](../developer/03-superdag/02-reference/validation/validation_rule_ordering.md)**
  - Execution order ของ validation rules
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลง validation order
  - **Last Updated:** Task 19.21 (November 2025)

### Risk & Scoring

- **[02-reference/autofix_risk_scoring.md](../developer/03-superdag/02-reference/autofix_risk_scoring.md)**
  - Risk scoring สำหรับ AutoFix
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลง risk scoring logic
  - **Last Updated:** Task 19.10 (December 2025)

- **[02-reference/validation_risk_register.md](../developer/03-superdag/02-reference/validation_risk_register.md)**
  - Risk register สำหรับ validation
  - **อัพเดทเมื่อ:** มีการเพิ่ม/แก้ไข risks
  - **Last Updated:** Task 19.19 (November 2025)

### Timezone & Time

- **[02-reference/timezone/timezone_reference_map.json](../developer/03-superdag/02-reference/timezone/timezone_reference_map.json)**
  - Timezone reference map
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลง timezone handling
  - **Last Updated:** Task 20.2 (January 2025)

- **[timezone/timezone_audit_report.md](../archive/audits_reports/timezone_audit_report.md)** 📦 **ARCHIVED**
  - Timezone audit report (Task 20.2.1 - Complete)
  - **Status:** Moved to archive (no longer actively used)
  - **Location:** `archive/audits_reports/timezone_audit_report.md`

- **[time/time_usage_audit.md](../archive/audits_reports/time_usage_audit.md)** 📦 **ARCHIVED**
  - Time usage audit (Task 20.2 - Complete)
  - **Status:** Moved to archive (no longer actively used)
  - **Location:** `archive/audits_reports/time_usage_audit.md`

---

## 📋 หมวดที่ 2: Implementation Specs & Planning (อัพเดทเมื่อจำเป็น)

เอกสารเหล่านี้เป็น **สเปกสำหรับเตรียม Implement** หรือ **แผนการพัฒนา**  
อัพเดทเมื่อมีการเปลี่ยนแปลงแผนหรือสเปก แต่ไม่จำเป็นต้องอัพเดทบ่อยเท่าหมวดที่ 1

### Implementation Guides

- **[04-implementation/DAG_IMPLEMENTATION_GUIDE.md](../developer/03-superdag/04-implementation/DAG_IMPLEMENTATION_GUIDE.md)**
  - คู่มือการพัฒนา DAG Engine
  - Implementation recipes
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลง implementation approach
  - **Last Updated:** December 2025

- **[04-implementation/DAG_EXAMPLES.md](../developer/03-superdag/04-implementation/DAG_EXAMPLES.md)**
  - ตัวอย่าง DAG graphs และ production flows
  - **อัพเดทเมื่อ:** มีการเพิ่มตัวอย่างใหม่
  - **Last Updated:** December 2025

### SPEC Documents (Specifications for Implementation)

เอกสารเหล่านี้ถูกสร้างขึ้นจาก `REALITY_EVENT_IN_HOUSE.md` เพื่อเตรียม implement

- **[03-specs/SPEC_WORK_CENTER_BEHAVIOR.md](../developer/03-superdag/03-specs/SPEC_WORK_CENTER_BEHAVIOR.md)**
  - สเปก Work Center Behavior
  - Data model, Event flows, Roadmap
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลงสเปกหรือ roadmap
  - **Status:** Planning document

- **[03-specs/SPEC_TOKEN_ENGINE.md](../developer/03-superdag/03-specs/SPEC_TOKEN_ENGINE.md)**
  - สเปก Token Engine
  - Token model, State machine, Roadmap
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลงสเปกหรือ roadmap
  - **Status:** Planning document

- **[03-specs/SPEC_TIME_ENGINE.md](../developer/03-superdag/03-specs/SPEC_TIME_ENGINE.md)**
  - สเปก Time Engine
  - Time tracking model, Scenarios, Roadmap
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลงสเปกหรือ roadmap
  - **Status:** Planning document

- **[03-specs/SPEC_COMPONENT_SERIAL_BINDING.md](../developer/03-superdag/03-specs/SPEC_COMPONENT_SERIAL_BINDING.md)**
  - สเปก Component Serial Binding
  - Binding model, Event flows, Roadmap
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลงสเปกหรือ roadmap
  - **Status:** Planning document

- **[03-specs/SPEC_QC_SYSTEM.md](../developer/03-superdag/03-specs/SPEC_QC_SYSTEM.md)**
  - สเปก QC System
  - QC nodes, Defect codes, Roadmap
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลงสเปกหรือ roadmap
  - **Status:** Planning document

- **[03-specs/SPEC_PWA_CLASSIC_FLOW.md](../developer/03-superdag/03-specs/SPEC_PWA_CLASSIC_FLOW.md)**
  - สเปก PWA Classic Flow
  - Scan contracts, Error recovery, Roadmap
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลงสเปกหรือ roadmap
  - **Status:** Planning document

- **[03-specs/SPEC_LEATHER_STOCK_REALITY.md](../developer/03-superdag/03-specs/SPEC_LEATHER_STOCK_REALITY.md)**
  - สเปก Leather Stock Reality
  - Leather Steward, Reconciliation logic, Roadmap
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลงสเปกหรือ roadmap
  - **Status:** Planning document

- **[03-specs/SPEC_IMPLEMENTATION_ROADMAP.md](../developer/03-superdag/03-specs/SPEC_IMPLEMENTATION_ROADMAP.md)**
  - แผนการพัฒนารวม (Master Roadmap)
  - Phase 1-4, Task ordering
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลง roadmap
  - **Status:** Planning document

### Reality & Input Documents

- **[05-planning/REALITY_EVENT_IN_HOUSE.md](../developer/03-superdag/05-planning/REALITY_EVENT_IN_HOUSE.md)**
  - เหตุการณ์จริงในโรงงาน (50+ scenarios)
  - Input สำหรับสร้าง SPEC documents
  - **อัพเดทเมื่อ:** มีการเพิ่มเหตุการณ์ใหม่หรือเปลี่ยนแปลงความต้องการ
  - **Status:** Source of truth for requirements

- **[05-planning/PROMPT_GENERATE_SPECS.md](../developer/03-superdag/05-planning/PROMPT_GENERATE_SPECS.md)**
  - คำสั่งสำหรับสร้าง SPEC files
  - Template และ guidelines
  - **อัพเดทเมื่อ:** มีการเปลี่ยนแปลง template
  - **Status:** Meta document

### Task Management

- **[task_index.md](task_index.md)**
  - ดัชนีงานทั้งหมด (Task 1-26, 271+ tasks)
  - Status tracking
  - **อัพเดทเมื่อ:** มีการเพิ่ม/แก้ไข tasks
  - **Status:** Task tracking document
  - **Location:** `docs/super_dag/task_index.md` (returned to original location)

### Archived Documents 📦

#### Missing & Gaps (Archived)

- **[SuperDAG_Missing_Semantics.md](../archive/gap_analysis/SuperDAG_Missing_Semantics.md)** 📦 **ARCHIVED**
  - Semantic ที่ยังขาด
  - **Status:** Moved to archive (gap analysis document)
  - **Location:** `archive/gap_analysis/SuperDAG_Missing_Semantics.md`

#### Cleanup & Optimization Plans (Archived)

- **[validation_leanup_plan.md](../archive/cleanup_plans/validation_leanup_plan.md)** 📦 **ARCHIVED**
  - แผน cleanup validation layer (superseded by v2)
  - **Status:** Moved to archive
  - **Location:** `archive/cleanup_plans/validation_leanup_plan.md`

- **[validation_leanup_plan_v2.md](../archive/cleanup_plans/validation_leanup_plan_v2.md)** 📦 **ARCHIVED**
  - แผน cleanup validation layer (v2)
  - **Status:** Moved to archive
  - **Location:** `archive/cleanup_plans/validation_leanup_plan_v2.md`

#### Test Documentation (Archived)

- **[tests/autofix_test_cases.md](../archive/test_documentation/autofix_test_cases.md)** 📦 **ARCHIVED**
  - Test cases สำหรับ AutoFix
  - **Status:** Moved to archive (test cases should be in PHPUnit test files)
  - **Location:** `archive/test_documentation/autofix_test_cases.md`

- **[tests/autofix_v2_test_cases.md](../archive/test_documentation/autofix_v2_test_cases.md)** 📦 **ARCHIVED**
  - Test cases สำหรับ AutoFix v2
  - **Status:** Moved to archive
  - **Location:** `archive/test_documentation/autofix_v2_test_cases.md`

- **[tests/qc_routing_test_cases.md](../archive/test_documentation/qc_routing_test_cases.md)** 📦 **ARCHIVED**
  - Test cases สำหรับ QC routing
  - **Status:** Moved to archive
  - **Location:** `archive/test_documentation/qc_routing_test_cases.md`

- **[tests/semantic_routing_test_cases.md](../archive/test_documentation/semantic_routing_test_cases.md)** 📦 **ARCHIVED**
  - Test cases สำหรับ semantic routing
  - **Status:** Moved to archive
  - **Location:** `archive/test_documentation/semantic_routing_test_cases.md`

- **[tests/time_model_test_cases.md](../archive/test_documentation/time_model_test_cases.md)** 📦 **ARCHIVED**
  - Test cases สำหรับ time model
  - **Status:** Moved to archive
  - **Location:** `archive/test_documentation/time_model_test_cases.md`

- **[tests/validation_regression_suite.md](../archive/test_documentation/validation_regression_suite.md)** 📦 **ARCHIVED**
  - Regression test suite สำหรับ validation
  - **Status:** Moved to archive
  - **Location:** `archive/test_documentation/validation_regression_suite.md`

- **[tests/qc_routing_regression_map.md](../archive/test_documentation/qc_routing_regression_map.md)** 📦 **ARCHIVED**
  - QC routing regression map
  - **Status:** Moved to archive
  - **Location:** `archive/test_documentation/qc_routing_regression_map.md`

---

## 🎯 การใช้งานเอกสาร

### สำหรับ Dev ที่เริ่มพัฒนาใหม่

1. **อ่าน Core Knowledge Documents ก่อน:**
   - ไปที่ `docs/developer/03-superdag/01-core/` - Core Knowledge Documents
   - `SuperDAG_Architecture.md` - เข้าใจโครงสร้างระบบ
   - `SuperDAG_Execution_Model.md` - เข้าใจการทำงาน
   - `core_principles_of_flexible_factory_erp.md` - เข้าใจหลักการ
   - `Node_Behavier.md` + `node_behavior_model.md` - เข้าใจ Behavior Model

2. **อ่าน Implementation Specs เมื่อต้องการ implement feature ใหม่:**
   - ไปที่ `docs/developer/03-superdag/03-specs/` - Specifications
   - `SPEC_*.md` - อ่านสเปกที่เกี่ยวข้อง
   - `docs/developer/03-superdag/05-planning/REALITY_EVENT_IN_HOUSE.md` - เข้าใจเหตุการณ์จริง

3. **อ้างอิง Task Index:**
   - `docs/super_dag/task_index.md` - ดูงานที่ทำไปแล้วและสถานะ (returned to original location)

### สำหรับการอัพเดทเอกสาร

**Core Knowledge Documents (หมวดที่ 1):**
- ต้องอัพเดททุกครั้งที่มีการเปลี่ยนแปลงโค้ดที่เกี่ยวข้อง
- ตรวจสอบความสอดคล้องกับโค้ดจริง
- อัพเดท "Last Updated" date

**Implementation Specs (หมวดที่ 2):**
- อัพเดทเมื่อมีการเปลี่ยนแปลงสเปกหรือ roadmap
- ไม่จำเป็นต้องอัพเดทบ่อยเท่าหมวดที่ 1

---

## ✅ สถานะการอัพเดทเอกสาร (หลัง Task 20-26)

**📋 ดูรายละเอียดการเปลี่ยนแปลงทั้งหมดใน:** [TASK_20_26_CHANGES_SUMMARY.md](TASK_20_26_CHANGES_SUMMARY.md)

### ✅ เอกสารที่อัพเดทแล้ว (January 2025)

1. **SuperDAG_Architecture.md** ✅ **UPDATED**
   - ✅ เพิ่ม: TimeHelper, NodeBehaviorEngine, TokenEventService, TimeEventReader
   - ✅ เพิ่ม: LocalRepairEngine, TimelineReconstructionEngine, RepairOrchestrator
   - ✅ เพิ่ม: MO Services (MOCreateAssistService, MOLoadSimulationService, MOLoadEtaService, etc.)
   - ✅ เพิ่ม: Product Services (ClassicProductionStatsService, ProductMetadataResolver)
   - ✅ เพิ่ม: Database tables (token_repair_log, mo_eta_cache, mo_eta_health_log, production_output_daily)
   - ✅ เพิ่ม: GraphTimezone.js (UI Integration Layer)

2. **SuperDAG_Execution_Model.md** ✅ **UPDATED**
   - ✅ เพิ่ม: Canonical Events integration (Task 21.2+)
   - ✅ เพิ่ม: TimeHelper usage in all time operations
   - ✅ เพิ่ม: Self-Healing flow (Task 22.1-22.3)
   - ✅ เพิ่ม: MO lifecycle hooks (Task 23.5)
   - ✅ อัพเดท: Execution examples with canonical events

3. **SuperDAG_Flow_Map.md** ✅ **UPDATED**
   - ✅ เพิ่ม: Canonical events in token spawn flow
   - ✅ เพิ่ม: TimeEventReader sync in finish flow
   - ✅ เพิ่ม: MO lifecycle hooks
   - ✅ อัพเดท: Summary with Task 20-26 enhancements

4. **time_model.md** ✅ **UPDATED**
   - ✅ เพิ่ม: TimeHelper usage in all formulas
   - ✅ เพิ่ม: GraphTimezone.js (frontend layer)
   - ✅ เพิ่ม: TimeEventReader integration
   - ✅ อัพเดท: All examples to use TimeHelper
   - ✅ อัพเดท: Task 20-26 integration status

5. **Node_Behavier.md** ✅ **UPDATED**
   - ✅ เพิ่ม: Implementation status (Task 21.2+)
   - ✅ เพิ่ม: NodeBehaviorEngine, TokenEventService, TimeEventReader integration

6. **node_behavior_model.md** ✅ **UPDATED**
   - ✅ อัพเดท: Version 2.0 (Task 21.1-21.8 Completed)
   - ✅ เพิ่ม: Implementation status and key classes

### 📝 เอกสารที่อาจต้องตรวจสอบเพิ่มเติม

- **DAG_Blueprint.md** - เนื้อหายังใช้ได้ แต่ไม่มี "Last Updated" date
- **core_principles_of_flexible_factory_erp.md** - เนื้อหายังใช้ได้ แต่ไม่มี "Last Updated" date
- **condition_engine_overview.md** - ตรวจสอบว่าต้องอัพเดทหรือไม่
- **semantic_intent_rules.md** - ตรวจสอบว่าต้องอัพเดทหรือไม่

---

## 📝 สรุป

- **หมวดที่ 1 (Core Knowledge):** 20+ ไฟล์ - ต้องอัพเดทให้ทันกับโค้ด
- **หมวดที่ 2 (Implementation Specs):** 15+ ไฟล์ - อัพเดทเมื่อจำเป็น

**Priority:** อัพเดทหมวดที่ 1 ก่อน เพราะเป็นความรู้พื้นฐานที่ Dev ใช้ทุกวัน


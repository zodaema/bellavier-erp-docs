# SuperDAG Documentation

**Purpose:** Complete documentation for SuperDAG system  
**Last Updated:** January 2025  
**Status:** Active Documentation

---

## 📁 Documentation Structure

เอกสาร SuperDAG ถูกจัดระเบียบตามบริบท:

### 📚 [01-core/](01-core/) - Core Knowledge Documents
**ความรู้พื้นฐานสำหรับ Developer** - ต้องอ่านก่อนเริ่มพัฒนา

- `SuperDAG_Architecture.md` - System architecture (6 layers)
- `SuperDAG_Execution_Model.md` - Token state machine & execution flow
- `SuperDAG_Flow_Map.md` - Token flow (linear, parallel, conditional)
- `Node_Behavier.md` + `node_behavior_model.md` - Node behavior specification
- `time_model.md` - Time engine model
- `core_principles_of_flexible_factory_erp.md` - Core design principles
- `DAG_Blueprint.md` - DAG Engine blueprint

**See:** [01-core/README.md](01-core/README.md) for details

---

### 📖 [02-reference/](02-reference/) - Reference Documents
**เอกสารอ้างอิง** - สำหรับ engines, rules, และ technical details

- Condition Engine references
- Validation Engine references
- Semantic Intent rules
- Risk & Scoring references
- Timezone & Time references

**See:** [02-reference/README.md](02-reference/README.md) for details

---

### 📋 [03-specs/](03-specs/) - Specifications
**สเปกสำหรับเตรียม Implement** - สร้างขึ้นจาก REALITY_EVENT_IN_HOUSE.md

- `SPEC_WORK_CENTER_BEHAVIOR.md`
- `SPEC_TOKEN_ENGINE.md`
- `SPEC_TIME_ENGINE.md`
- `SPEC_COMPONENT_SERIAL_BINDING.md`
- `SPEC_QC_SYSTEM.md`
- `SPEC_PWA_CLASSIC_FLOW.md`
- `SPEC_LEATHER_STOCK_REALITY.md`
- `SPEC_IMPLEMENTATION_ROADMAP.md`

**See:** [03-specs/README.md](03-specs/README.md) for details

---

### 🛠️ [04-implementation/](04-implementation/) - Implementation Guides
**คู่มือการพัฒนา** - Implementation guides และ examples

- `DAG_IMPLEMENTATION_GUIDE.md` - Implementation recipes
- `DAG_EXAMPLES.md` - Example DAG graphs and flows

**See:** [04-implementation/README.md](04-implementation/README.md) for details

---

### 📊 [05-planning/](05-planning/) - Planning & Analysis
**เอกสารการวางแผน** - Task tracking, analysis, และ requirements

- `task_index.md` - Task index (Task 1-26, 271+ tasks)
- `REALITY_EVENT_IN_HOUSE.md` - Real-world factory events (source of truth)
- `PROMPT_GENERATE_SPECS.md` - Instructions for generating SPEC files
- `TASK_20_26_CHANGES_SUMMARY.md` - Summary of changes after Task 20-26

**See:** [05-planning/README.md](05-planning/README.md) for details

---

## 🎯 Quick Navigation

### For Developers (Start Here)
1. Read [01-core/README.md](01-core/README.md) - Core Knowledge Documents
2. Read [04-implementation/README.md](04-implementation/README.md) - Implementation Guides
3. Reference [02-reference/README.md](02-reference/README.md) - When needed

### For Planning
1. Read [05-planning/README.md](05-planning/README.md) - Planning documents
2. Check [05-planning/task_index.md](05-planning/task_index.md) - Task status
3. Review [03-specs/README.md](03-specs/README.md) - Specifications

---

## 📝 Related Documentation

### Task & Test Documentation
- **Task Documentation:** `docs/super_dag/tasks/` - Task specifications และ results (269+ files)
- **Test Documentation:** `docs/super_dag/tests/` - Test cases และ regression suites
- **Archive:** `docs/super_dag/archive/` - Archived documents (audits, reports)

### Complete Index
- **[docs/super_dag/DOCUMENTATION_INDEX.md](../../super_dag/DOCUMENTATION_INDEX.md)** - Complete documentation index (includes tasks, tests, archive)

---

## 📝 Maintenance

- **Core Knowledge Documents** - Must update when code changes
- **Reference Documents** - Update when rules/technical details change
- **Specifications** - Update when specs change
- **Implementation Guides** - Update when approach changes
- **Planning Documents** - Update as planning evolves

---

**Last Updated:** January 2025


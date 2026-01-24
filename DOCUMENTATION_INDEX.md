# 📚 Bellavier ERP - Documentation Index

**Last Updated:** December 6, 2025 (21:00 ICT)  
**Purpose:** Quick navigation to all key documents  
**Status:** Consolidated and cleaned

---

## 🎯 **Start Here**

**New to the project?** Read these in order:

1. **`README.md`** - Project overview and quick start
2. **`STATUS.md`** - Current state and next steps (v2.19.0)
3. **`docs/super_dag/SYSTEM_CURRENT_STATE.md`** ⭐ **NEW** - Complete system architecture
4. **`docs/super_dag/tasks/MASTER_IMPLEMENTATION_ROADMAP.md`** - Task 27 roadmap (ALL COMPLETE)

---

## 📋 **Master Documents**

### **System Design:**
- **`docs/DUAL_PRODUCTION_MASTER_BLUEPRINT.md`** ⭐ Master Design (16 sections)
  - Core philosophy and architecture
  - Token lifecycle, Work Item System, Assignment Logic
  - Operator & Manager workflows
  - Implementation approach

- **`docs/IMPLEMENTATION_STATUS_MAP.md`** - Gap analysis & roadmap
  - What's implemented (60%)
  - What's missing (40%)
  - Phase-by-phase plan

- **`docs/MO_VS_ATELIER_JOBS_CLARIFICATION.md`** - System separation
  - MO = OEM only
  - Atelier Jobs = Atelier only
  - Hybrid = Both linked via id_mo

### **Implementation Plans:**
- **`docs/PRODUCTION_CONTROL_CENTER_IMPLEMENTATION_PLAN.md`** - Unified dashboard
  - 3 modes: Plan, Run, Inspect
  - File templates ready
  - 5-day implementation plan

- **`docs/ROADMAP_LUXURY_WORLD_CLASS.md`** ⭐ **CANONICAL (2026–2027)** — Roadmap เป้าหมาย “Luxury world‑class”
  - Product Workspace governance (canonical editor)
  - DAG/SuperDAG runtime excellence + simulation
  - Materials execution + QC evidence + Trace portal
  - Security/Operations hardening (audit‑ready)

> Historical (archived): `docs/archive/completed_phases/ROADMAP_V4.md` (Nov 2025, 6‑week plan)

---

## 📖 **Reference Documents**

### **Technical Reference:**
- **`docs/DATABASE_SCHEMA_REFERENCE.md`** - Complete schema documentation
  - All tables with descriptions
  - Relationships and indexes
  - Query patterns

- **`docs/SERVICE_API_REFERENCE.md`** - Service layer documentation
  - All services and methods
  - Usage examples
  - Integration points

- **`docs/API_REFERENCE.md`** - REST API documentation
  - All endpoints
  - Parameters and responses
  - Error handling

- **`docs/API_DEFECT_CATALOG.md`** - Defect Catalog API (Task 27.14)
  - CRUD for defect types
  - Filter by component type
  - Rework suggestions

### **Component & Material Architecture (NEW - Dec 2025):**
- **`docs/super_dag/SYSTEM_CURRENT_STATE.md`** ⭐ - Complete current system state
- **`docs/super_dag/01-concepts/PRODUCT_COMPONENT_ARCHITECTURE.md`** - 3-Layer component model
- **`docs/super_dag/01-concepts/DEFECT_CATALOG_SPEC.md`** - Defect system spec
- **`docs/super_dag/01-concepts/QC_REWORK_PHILOSOPHY_V2.md`** - QC Rework V2 spec
- **`docs/super_dag/01-concepts/GRAPH_LINTER_RULES.md`** - Graph validation rules
- **`docs/super_dag/01-concepts/MISSING_COMPONENT_INJECTION_SPEC.md`** - MCI spec
- **`docs/06-specs/PUBLISHED_IMMUTABLE_CONTRACT.md`** ⭐ - **Published = Immutable** contract (Product Revision hardening)

### **Architecture:**
- **`docs/SYSTEM_ARCHITECTURE.md`** - Overall architecture
- **`docs/BELLAVIER_DAG_RUNTIME_FLOW.md`** - DAG runtime flow
- **`docs/DAG_vs_LINEAR_EVENT_LOGGING.md`** - Event logging comparison
- **`docs/DUAL_PRODUCTION_MASTER_PLAN.md`** - Dual production execution plan

---

## 👥 **User Guides**

### **For Operators:**
- **`docs/OPERATOR_QUICK_GUIDE_TH.md`** - Operator manual (Thai)
- **`docs/WORK_QUEUE_OPERATOR_JOURNEY.md`** - Operator workflow

### **For Managers:**
- **`docs/MANAGER_QUICK_GUIDE_TH.md`** - Manager manual (Thai)
- **`docs/JOB_TICKET_QUICK_GUIDE.md`** - Job ticket guide

### **For Admins:**
- **`docs/PERMISSION_MANAGEMENT_GUIDE.md`** - Permission system
- **`docs/MIGRATION_WIZARD_GUIDE.md`** - Database migrations
- **`docs/PLATFORM_ADMIN_FULL_ACCESS.md`** - Platform admin guide

---

## 🛠️ **Development Guides**

### **For Developers:**
- **`docs/AI_QUICK_START.md`** - Quick start for AI agents
- **`docs/GLOBAL_HELPERS.md`** - Helper functions
- **`docs/TROUBLESHOOTING_GUIDE.md`** - Common issues

### **For Database:**
- **`docs/MIGRATION_NAMING_STANDARD.md`** - Migration standards
- **`database/MIGRATION_GUIDE.md`** - Migration guide

---

## 📊 **Quality & Best Practices**

### **Production Readiness:**
- **`docs/PRODUCTION_HARDENING.md`** - Production checklist
- **`docs/RISK_PLAYBOOK.md`** - Risk scenarios & solutions
- **`docs/developer/06-architecture/01-system-overview.md`** - Strategic architecture overview
- **`docs/developer/08-guides/10-linear-deprecation.md`** - Linear deprecation timeline & removal safety
- **`docs/audit/STANDARDIZATION_AUDIT_2026_01_07.md`** - รายการไฟล์ API/JS ที่ควรยกระดับมาตรฐาน (RBAC/CSRF/Enterprise)

### **Testing:**
- **`tests/README.md`** - Testing guide
- **`docs/manual_test_checklist.md`** - Manual testing checklist

---

## 📦 **Archive**

Completed work and historical documents:

- **`archive/NODE_PRE_ASSIGNMENT_COMPLETE_NOV5.md`** - Nov 5 completion
- **`archive/TESTING_COMPLETE_NOV5.md`** - Browser testing results
- **`archive/DAG_PRODUCTION_PILOT_COMPLETE_NOV4.md`** - Nov 4 pilot results
- **`archive/TENANT_USER_MANAGEMENT_COMPLETE_NOV4.md`** - User management
- **`docs/archive/2025-q4/`** - Q4 2025 archive

---

## 🔄 **Changelogs**

- **`docs/CHANGELOG_NOV2025.md`** - November 2025 (current)
- **`docs/CHANGELOG_OCT2025.md`** - October 2025
- **`CHANGELOG.md`** - Full history

---

## 🎯 **Quick Links by Task**

### **I want to...**

**...understand the system:**
→ README.md → STATUS.md → DUAL_PRODUCTION_MASTER_BLUEPRINT.md

**...implement a feature:**
→ docs/ROADMAP_LUXURY_WORLD_CLASS.md → IMPLEMENTATION_STATUS_MAP.md → Specific implementation plan

**...understand database:**
→ DATABASE_SCHEMA_REFERENCE.md → MIGRATION_GUIDE.md

**...use an API:**
→ SERVICE_API_REFERENCE.md → API_REFERENCE.md

**...fix a bug:**
→ TROUBLESHOOTING_GUIDE.md → RISK_PLAYBOOK.md

**...train a user:**
→ OPERATOR_QUICK_GUIDE_TH.md (operator) or MANAGER_QUICK_GUIDE_TH.md (manager)

**...deploy to production:**
→ PRODUCTION_HARDENING.md → DEPLOYMENT_GUIDE.md

---

## 📌 **Document Maintenance**

### **Rules:**
- ✅ Keep master documents updated (STATUS.md, ROADMAP_V4.md)
- ✅ Archive completed work (archive/ folder)
- ✅ Delete superseded documents
- ✅ Update CHANGELOG monthly
- ✅ Review documentation quarterly

### **Recent Cleanup (Nov 5):**
- Deleted 7 superseded documents
- Created 4 master documents
- Consolidated planning docs
- Updated all references

---

**Status:** Documentation clean and organized ✅  
**Next:** Maintain as implementation progresses

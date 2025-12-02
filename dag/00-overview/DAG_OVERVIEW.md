# DAG System Overview

**Last Updated:** December 2025  
**Purpose:** Quick introduction to DAG system for new developers  
**Reading Time:** 5-7 minutes

---

## 🎯 What is DAG?

**DAG (Directed Acyclic Graph)** is Bellavier ERP's workflow engine for production routing. It replaces the legacy Linear task-based system with a graph-based approach that supports:

- **Complex routing:** Split, join, conditional branching, wait conditions
- **Multi-part workflows:** Component assembly, serial genealogy
- **Production types:** Hatthasilpa (atelier) and Classic (OEM) modes
- **Token-based execution:** Each work unit flows through the graph as a "token"

---

## 🏗️ Core Concepts

### **Three-Layer Architecture**

```
┌─────────────────────────────────────────────┐
│  Layer 1: Graph Template (Design)         │
│  - routing_graph, routing_node, routing_edge│
│  - Designed in Graph Designer UI           │
└─────────────────────────────────────────────┘
                    │
                    │ instantiate (start_job)
                    ▼
┌─────────────────────────────────────────────┐
│  Layer 2: Graph Instance (Execution)      │
│  - job_graph_instance, node_instance       │
│  - One per job_ticket                      │
└─────────────────────────────────────────────┘
                    │
                    │ spawn tokens
                    ▼
┌─────────────────────────────────────────────┐
│  Layer 3: Token Flow (Work Tracking)      │
│  - flow_token, token_event                 │
│  - Tokens move through nodes, record events│
└─────────────────────────────────────────────┘
```

### **Key Terms**

| Term | Definition |
|------|------------|
| **Graph** | Workflow template (routing_graph) - designed once, used many times |
| **Instance** | Active execution of a graph for a specific job (job_graph_instance) |
| **Token** | Work unit flowing through the graph (flow_token) - can be 1 piece or 1 batch |
| **Node** | Work station or decision point (routing_node) - operation, qc, split, join, wait, decision, etc. |
| **Edge** | Path between nodes (routing_edge) - can have conditions |
| **Event** | State change record (token_event) - spawn, enter, start, complete, etc. |

---

## 🔄 Production Types

### **Hatthasilpa (Atelier)**
- **Mode:** Piece-based production with serial tracking
- **UI:** Work Queue (Kanban/List view)
- **Features:** Manager assignment, operator availability, serial enforcement
- **API:** `hatthasilpa_jobs_api.php`, `dag_token_api.php`

### **Classic (OEM)**
- **Mode:** Batch-based production
- **UI:** PWA Scan Station
- **Features:** Dual-mode execution (Linear + DAG), auto-routing
- **API:** `pwa_scan_v2_api.php`

---

## 📊 Current Status

### **✅ Completed Phases**

| Phase | Scope | Status |
|-------|-------|--------|
| **0** | Job Ticket Pages Restructuring | ✅ Complete |
| **1** | Advanced Token Routing | ✅ Complete (1.1-1.7) |
| **1.5** | Wait Node Logic | ✅ Complete (95% - Production Ready) |
| **1.6** | Decision Node Logic | ✅ Complete |
| **1.7** | Subgraph Node Logic | ✅ Complete (Same Token Mode) |
| **2A** | PWA Integration (Classic) | ✅ Complete |
| **2B** | Work Queue Integration (Hatthasilpa) | ✅ Complete (2B.1-2B.5) |
| **2B.5** | Node-Type Aware Work Queue UX | ✅ Complete |
| **5.2** | Graph Versioning | ✅ Complete |
| **5.8** | Subgraph Governance & Versioning | ✅ Complete |

### **🚧 In Progress**

| Phase | Scope | Status |
|-------|-------|--------|
| **7.X** | Graph Draft Layer | 🚧 In Progress (Migration + API + Frontend done; tests pending) |

### **🟡 Planned**

| Phase | Scope | Status |
|-------|-------|--------|
| **2B.6** | Mobile-Optimized Work Queue UX | 🟡 Not Started |
| **3** | Dashboard & Visualization | 🟡 Not Started |
| **4** | Serial Genealogy & Component Model | 🟡 In Design |
| **6** | Production Hardening | 🟡 Not Started |
| **7** | Migration Tools | 🟡 Not Started |

**Source of Truth:** See [DAG_IMPLEMENTATION_ROADMAP.md](../01-roadmap/DAG_IMPLEMENTATION_ROADMAP.md) for complete Phase Status Table.

---

## 📚 Documentation Structure

### **Recommended Reading Order**

1. **Start Here:** This file (`DAG_OVERVIEW.md`) - Understand the big picture
2. **Roadmap:** [DAG_IMPLEMENTATION_ROADMAP.md](../01-roadmap/DAG_IMPLEMENTATION_ROADMAP.md) - See what's done and what's planned
3. **Tasks:** [TASK_INDEX.md](../03-tasks/TASK_INDEX.md) - Find specific implementation tasks
4. **Core Flow:** [BELLAVIER_DAG_RUNTIME_FLOW.md](../01-core/BELLAVIER_DAG_RUNTIME_FLOW.md) - Understand token lifecycle
5. **Implementation Status:** [IMPLEMENTATION_STATUS_SUMMARY.md](../02-implementation-status/IMPLEMENTATION_STATUS_SUMMARY.md) - Quick status check

### **Documentation Folders**

- **`00-overview/`** - High-level overview (this file)
- **`01-roadmap/`** - Implementation roadmap and phase specs
- **`01-core/`** - Core runtime flow and permissions
- **`02-implementation-status/`** - Status summaries, audits, completion reports
- **`03-tasks/`** - Task-based documentation (DAG-1, DAG-2, etc.)
- **`03-comparison/`** - DAG vs Linear comparison
- **`agent-tasks/`** - Legacy task documentation (being migrated to 03-tasks/)

---

## 🔗 Key Files & Services

### **Backend Services**

| Service | Purpose | Location |
|---------|---------|----------|
| `DAGRoutingService` | Token routing logic | `source/BGERP/Service/DAGRoutingService.php` |
| `TokenLifecycleService` | Token spawn, status management | `source/BGERP/Service/TokenLifecycleService.php` |
| `AssignmentEngine` | Operator assignment (PIN/MANAGER/PLAN/AUTO) | `source/BGERP/Service/AssignmentEngine.php` |
| `HatthasilpaAssignmentService` | Manager assignment lookup | `source/BGERP/Service/HatthasilpaAssignmentService.php` |
| `DAGValidationService` | Graph validation | `source/BGERP/Service/DAGValidationService.php` |

### **API Endpoints**

| API | Purpose | Location |
|-----|---------|----------|
| `dag_token_api.php` | Token operations (start, pause, complete, etc.) | `source/dag_token_api.php` |
| `hatthasilpa_jobs_api.php` | Hatthasilpa job management | `source/hatthasilpa_jobs_api.php` |
| `dag_routing_api.php` | Graph design and save | `source/dag_routing_api.php` |
| `dag_approval_api.php` | Wait node approval | `source/dag_approval_api.php` |

### **Database Tables**

| Table | Purpose |
|-------|---------|
| `routing_graph` | Graph templates |
| `routing_node` | Nodes in graph |
| `routing_edge` | Edges between nodes |
| `job_graph_instance` | Active graph instances |
| `flow_token` | Tokens flowing through graph |
| `token_event` | Token state change events |
| `token_assignment` | Operator assignments |
| `manager_assignment` | Manager-defined assignment plans |

---

## 🚀 Quick Start for Developers

### **1. Understanding a Feature**

1. Check [TASK_INDEX.md](../03-tasks/TASK_INDEX.md) for task-based docs
2. Read the specific task file (e.g., `TASK_DAG_2_MANAGER_ASSIGNMENT.md`)
3. Check implementation status in roadmap

### **2. Implementing a New Feature**

1. Read [DAG_IMPLEMENTATION_ROADMAP.md](../01-roadmap/DAG_IMPLEMENTATION_ROADMAP.md) for phase specs
2. Check existing services and APIs for patterns
3. Write tests following existing test patterns
4. Run audits after implementation (see [AUDIT_WORKFLOW.md](../02-implementation-status/AUDIT_WORKFLOW.md))

### **3. Debugging Issues**

1. Check [BELLAVIER_DAG_RUNTIME_FLOW.md](../01-core/BELLAVIER_DAG_RUNTIME_FLOW.md) for expected behavior
2. Review audit files in `02-implementation-status/`
3. Check test files for expected behavior

---

## ⚠️ Important Notes

### **Linear vs DAG**

- **Linear system** (atelier_job_task, atelier_wip_log) is **TEMPORARY** and will be **REMOVED in Q3 2026**
- **DAG system** is the **permanent** production system
- Currently: Dual-mode coexistence (DAG primary, Linear fallback)
- Timeline: Q1 2026 → DAG adoption, Q2 2026 → Linear deprecation, Q3 2026 → Linear removal

### **Production Type Naming**

- Use `'hatthasilpa'` (NOT `'atelier'`)
- Use `'classic'` (NOT `'oem'`)
- See roadmap for migration details

### **Audit Requirements**

After every implementation phase, **MUST run 3 audits:**
1. NodeType Policy & UI Audit
2. Flow Status & Transition Audit
3. Hatthasilpa Assignment Integration Audit

See [AUDIT_WORKFLOW.md](../02-implementation-status/AUDIT_WORKFLOW.md) for details.

---

## 📞 Getting Help

- **Documentation:** Check `docs/dag/` folder structure
- **Code Examples:** See existing services and tests
- **Status Questions:** Check [IMPLEMENTATION_STATUS_SUMMARY.md](../02-implementation-status/IMPLEMENTATION_STATUS_SUMMARY.md)
- **Task Details:** See [TASK_INDEX.md](../03-tasks/TASK_INDEX.md)

---

**Next Steps:**
- Read [DAG_IMPLEMENTATION_ROADMAP.md](../01-roadmap/DAG_IMPLEMENTATION_ROADMAP.md) for detailed phase status
- Check [TASK_INDEX.md](../03-tasks/TASK_INDEX.md) for task-based documentation


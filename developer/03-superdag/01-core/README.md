# Core Knowledge Documents

**Purpose:** Essential knowledge documents for SuperDAG development  
**Audience:** Developers, AI Agents  
**Status:** Active Documentation (must be kept up-to-date)

---

## 📚 Overview

เอกสารในโฟลเดอร์นี้เป็น **ความรู้พื้นฐาน** ที่ Developer ต้องอ่านก่อนเริ่มพัฒนา SuperDAG features  
**ต้องอัพเดทให้สอดคล้องกับโค้ดจริง** ทุกครั้งที่มีการเปลี่ยนแปลงระบบ

---

## 📋 Documents

### Architecture & System Design ⭐ **CRITICAL**

1. **[SuperDAG_Architecture.md](SuperDAG_Architecture.md)**
   - System architecture (6 layers)
   - API endpoints, Service classes, Database schema
   - **Last Updated:** Task 20-26 (January 2025)

2. **[SuperDAG_Execution_Model.md](SuperDAG_Execution_Model.md)**
   - Token State Machine, Execution Flow
   - Entry Points, State Transitions
   - **Last Updated:** Task 20-26 (January 2025)

3. **[SuperDAG_Flow_Map.md](SuperDAG_Flow_Map.md)**
   - Token Flow (Linear, Parallel, Conditional)
   - Merge Semantics, Rework Flow
   - **Last Updated:** Task 20-26 (January 2025)

### Core Principles & Blueprint

4. **[core_principles_of_flexible_factory_erp.md](core_principles_of_flexible_factory_erp.md)**
   - Core design principles (12 principles)
   - Canonical Event Framework
   - **Last Updated:** Task 20.2 (January 2025)

5. **[DAG_Blueprint.md](DAG_Blueprint.md)**
   - DAG Engine blueprint
   - Production Reality Model, Component Model
   - **Last Updated:** November 2025

### Behavior & Node Models ⭐ **CRITICAL**

6. **[Node_Behavier.md](Node_Behavier.md)**
   - Node behavior specification (Canonical Spec)
   - Node Mode, Work Center Binding
   - **Last Updated:** Task 21.1-21.8 (November 2025)

7. **[node_behavior_model.md](node_behavior_model.md)**
   - Node behavior model (Aligned with Node_Behavier.md)
   - Execution Context, Canonical Events
   - **Last Updated:** Task 21.1-21.8 (November 2025)

### Engine Models

8. **[time_model.md](time_model.md)**
   - Time Engine model
   - Time tracking, Drift correction, Timezone normalization
   - **Last Updated:** Task 20-26 (January 2025)

---

## 🎯 Quick Start for Developers

**Read these documents IN ORDER:**

1. Start with `core_principles_of_flexible_factory_erp.md` (philosophy)
2. Then `DAG_Blueprint.md` (foundation)
3. Then `SuperDAG_Architecture.md` (system overview)
4. Then `SuperDAG_Execution_Model.md` (execution flow)
5. Then `SuperDAG_Flow_Map.md` (token flow)
6. Then `Node_Behavier.md` + `node_behavior_model.md` (behavior model)
7. Finally `time_model.md` (time engine)

---

## ⚠️ Maintenance Rules

- **Must update** when code changes
- **Must sync** with actual implementation
- **Must verify** accuracy before marking complete
- **Never delete** - these are canonical references

---

**Last Updated:** January 2025


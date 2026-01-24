# SuperDAG Technical Specifications

**Purpose:** รายละเอียดทางเทคนิคสำหรับ Implementation  
**Location:** `docs/super_dag/02-specs/`

---

## ⚠️ Canonical Law (Must Read First)

**Source of Truth:** `docs/super_dag/01-canonical/HATTHASILPA_CANONICAL_PRODUCTION_SPEC.md`

**Rule:** ทุก spec ในโฟลเดอร์นี้ต้อง **derive จาก Canonical** และต้องไม่ขัดกับเอกสาร Canonical เด็ดขาด

## Naming Convention

`TOPIC_NAME_SPEC.md` หรือ `TOPIC_NAME.md` (ไม่มีวันที่)

**Single Source of Truth:** แก้ไขไฟล์เดิม (ไม่สร้างไฟล์ใหม่)

---

## Current Technical Specs

### 1. SuperDAG Token Lifecycle
**File:** `SUPERDAG_TOKEN_LIFECYCLE.md` (v1.0)  
**Purpose:** Token lifecycle model (abstract framework)  
**Status:** ✅ Production-Ready  

**Key Topics:**
- Token types: batch, piece, component (+ future)
- State machine: ready → active → waiting → paused → completed/scrapped
- Token relationships: parent-child, parallel group, replacement
- Spawn patterns: job creation, parallel split, replacement
- Merge patterns: component merge, batch join
- Canonical events
- Multi-level component support

### 2. Component Parallel Flow Spec
**File:** `COMPONENT_PARALLEL_FLOW_SPEC.md` (v2.1)  
**Purpose:** Component Flow implementation (concrete rules)  
**Status:** ✅ Production-Ready (3-5 year lifespan)  

**Key Sections:**
- Section 0: Terminology
- Section 1: Core Principle
- Section 2: Current Database Schema
- Section 3: Behavior Execution
- Section 4: Parallel Split Mechanism
- Section 5: Merge Node Semantics
- Section 6: Work Queue Integration
- Section 7: Serial Number Strategy
- Section 8: Implementation Gap Summary
- Section 11: Routing Node Truth Table
- Section 12: Component Split Graph Requirements
- Section 13: Failure Modes & Recovery

### 3. Behavior Execution Spec
**File:** `BEHAVIOR_EXECUTION_SPEC.md` (v1.0)  
**Purpose:** Behavior Layer integration with SuperDAG (target blueprint)  
**Status:** ✅ Ready for Implementation  

**Key Topics:**
- Core Principle: Behavior as Orchestrator (NOT owner)
- Service Layer Architecture (ownership model)
- Token status transitions (call TokenLifecycleService)
- Component token awareness
- Split/merge delegation
- UI data contract
- Failure mode recovery
- Anti-patterns (4 critical rules)

---

## How to Use

**When:** ขณะ implement (ใช้เป็น blueprint)

**Target Audience:** Developers

**Read before:**
- Starting implementation
- Writing code
- Reviewing pull requests

---

## Related Documents

**Concept Documents:** `../01-concepts/`  
**Audit Reports:** `../00-audit/`  
**Implementation Checklists:** `../03-checklists/`  
**Developer Guidelines:** `../../developer/03-superdag/`


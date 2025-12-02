# SuperDAG Technical Specifications

**Purpose:** รายละเอียดทางเทคนิคสำหรับ Implementation  
**Audience:** Developers implementing new features  
**Location:** `docs/developer/03-superdag/03-specs/`

---

## Naming Convention

`TOPIC_NAME_SPEC.md` หรือ `TOPIC_NAME.md` (ไม่มีวันที่)

**Single Source of Truth:** แก้ไขไฟล์เดิม (ไม่สร้างไฟล์ใหม่)

---

## 🏗️ Core Architecture Specs

### 1. SuperDAG Token Lifecycle
**File:** `SUPERDAG_TOKEN_LIFECYCLE.md`  
**Purpose:** Token lifecycle model (abstract framework)  
**Status:** ✅ Production-Ready  
**Key Topics:**
- Token types: batch, piece, component (+ future: tray, work_order, sub_component)
- State machine: ready → active → waiting → paused → completed/scrapped
- Token relationships: parent-child, parallel group, replacement, batch spawn
- Spawn patterns: job creation, parallel split, replacement
- Merge patterns: component merge, batch join
- Canonical events: TOKEN_*, NODE_*, OVERRIDE_*, COMP_*, INVENTORY_*
- Multi-level component support
- Token archival & retention

### 2. Component Parallel Flow Spec
**File:** `COMPONENT_PARALLEL_FLOW_SPEC.md` (v2.1)  
**Purpose:** Component Flow implementation (concrete rules)  
**Status:** ✅ Production-Ready (3-5 year lifespan)  
**Key Topics:**
- **Section 0:** Terminology (Final Token, Component Token, Batch Token)
- **Section 1:** Core Principle (Component = Core Mechanic)
- **Section 2:** Current Database Schema (100% verified)
- **Section 3:** Behavior Execution for Components
- **Section 4:** Parallel Split Mechanism (Native Parallel Split)
- **Section 5:** Merge Node Semantics
- **Section 6:** Work Queue Integration (by role)
- **Section 7:** Serial Number Strategy
- **Section 8:** Implementation Gap Summary
- **Section 9:** Migration Path
- **Section 10:** Anti-Patterns
- **Section 11:** Routing Node Truth Table (NEW)
- **Section 12:** Component Split Graph Requirements (NEW)
- **Section 13:** Failure Modes & Recovery (7 scenarios) (NEW)

### 3. Behavior App Contract
**File:** `BEHAVIOR_APP_CONTRACT.md` (v1.2)  
**Purpose:** Behavior execution contracts  
**Status:** ✅ Current  
**Key Topics:**
- API Contract (Request/Response, Error codes)
- UI Contract (Frontend entry, Event lifecycle)
- Logging Contract (Behavior action log, Canonical events)
- Domain Rules Contract (Behavior-specific rules)
- Behavior Grouping by UI Template
- Behavior Family Handlers

---

## 📋 Legacy Specs (Keep for Reference)

### Time Engine
**File:** `SPEC_TIME_ENGINE.md`  
**Status:** Reference (older spec)

### Token Engine
**File:** `SPEC_TOKEN_ENGINE.md`  
**Status:** Reference (replaced by SUPERDAG_TOKEN_LIFECYCLE.md)

### Work Center Behavior
**File:** `SPEC_WORK_CENTER_BEHAVIOR.md`  
**Status:** Reference (partially replaced by BEHAVIOR_APP_CONTRACT.md)

### Component Serial Binding
**File:** `SPEC_COMPONENT_SERIAL_BINDING.md`  
**Status:** Task 13 implementation spec

### QC System
**File:** `SPEC_QC_SYSTEM.md`  
**Status:** Reference

### PWA Classic Flow
**File:** `SPEC_PWA_CLASSIC_FLOW.md`  
**Status:** Reference

### Leather Stock Reality
**File:** `SPEC_LEATHER_STOCK_REALITY.md`  
**Status:** Reference

### Implementation Roadmap
**File:** `SPEC_IMPLEMENTATION_ROADMAP.md`  
**Status:** Reference (may be outdated)

---

## 🎯 Usage

**When:** ขณะ implement (ใช้เป็น blueprint)

**Target Audience:** Developers

**Update Policy:** แก้ไขไฟล์เดิม เมื่อ technical requirements เปลี่ยน

**Read before:**
- Starting implementation
- Writing code
- Reviewing pull requests

---

## 📚 Related Documents

**Concept Documents:** `../02-concepts/`  
**Audit Reports:** `../00-audit/`  
**Implementation Plans:** `../04-implementation/`  
**Core Knowledge:** `../01-core/`

---

**Last Updated:** December 2, 2025

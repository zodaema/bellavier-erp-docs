# Component Parallel Work Audit

**Date:** 2025-01-XX  
**Purpose:** Audit status of Component Serial system for parallel work on bag parts  
**Scope:** Component tokens, parallel work, separate time tracking

**⚠️ CRITICAL VISION:** Component Token = **CORE MECHANIC** ของ Hatthasilpa Workflow  
**ไม่ใช่ optional enhancement แต่เป็น mandatory architecture**

---


## Executive Summary

**Current Status:** 🟡 **PARTIALLY IMPLEMENTED** (Infrastructure exists, but workflow/documentation missing)

- ✅ **Component Serial Binding (Task 13):** Stage 1 (Capture & Expose) - Complete
- ✅ **Component Token Creation:** Can create component tokens via `splitToken()`
- ✅ **Parallel Work Infrastructure:** Parallel split/merge nodes exist
- ✅ **Component Time Tracking (Theoretical):** Component tokens CAN use `TokenWorkSessionService` (no restrictions)
- ❌ **Component Time Tracking Workflow:** Missing workflow/documentation for component token work sessions
- ❌ **Component Model (Task 5):** Still PLANNED (not implemented)

**🔥 Critical Gap:** Component Token workflow is **MANDATORY** for Hatthasilpa but not yet fully documented/implemented

---

## 0. Why Component Tokens Are Mandatory for Hatthasilpa

### Scope & Boundary

- ใช้กับ: **Hatthasilpa Line เท่านั้น**
- Client หลัก: **Work Queue / Job Ticket**
- ไม่ครอบคลุม: PWA Classic, Classic Line, OEM-style daily reporting

**⚠️ CRITICAL:** Component Token = **CORE MECHANIC** ของ Hatthasilpa Workflow, ไม่ใช่ optional module

### 0.0 Key Concepts (From Concept Flow)

**⚠️ CRITICAL RULES:**
1. **Final Serial = Created at Job Creation** (NOT at Assembly)
2. **Job Tray = Physical Container** (1 Final Token = 1 Tray)
3. **Component Serial = Label Only** (NOT relationship mechanism)
4. **Component Token MUST have parent_token_id** (no orphan components)
5. **Assembly = Re-activate Final Token** (not create new)
6. **Component Token = Native Parallel Split** (NOT Subgraph `fork` mode)

**See Also:**
- `docs/developer/03-superdag/03-specs/COMPONENT_PARALLEL_FLOW_CONCEPT.md` - Detailed concept flow
- `docs/dag/SUBGRAPH_VS_COMPONENT_CONCEPT_AUDIT.md` - Subgraph vs Component comparison

### 0.1 Hatthasilpa = Parallel Craftsmanship Model

**Vision:**
- Bag มีหลายชิ้นส่วน (BODY, FLAP, STRAP, LINING, etc.)
- แต่ละชิ้นส่วนทำโดยช่างคนละคน **พร้อมกัน (parallel)**
- แต่ละช่างจับเวลาแยกกัน
- Assembly = รวมชิ้นส่วนที่เสร็จแล้ว

**Why Component Tokens Are Required:**

1. **✅ Required for Parallel Craft Workflow**
   - Worker A ทำ BODY (2 hours)
   - Worker B ทำ FLAP (1.5 hours)
   - Worker C ทำ STRAP (1 hour)
   - **ต้องทำงานพร้อมกัน** → ต้องมี component tokens แยกกัน

2. **✅ Required for Component-Level Time Tracking**
   - แต่ละช่างจับเวลาแยกกัน
   - Component token = work session แยกกัน
   - Time tracking per component = จำเป็นสำหรับ craftsmanship analytics

3. **✅ Required for ETA Model**
   - ETA ของทั้งใบ = `max(component_times) + assembly_time`
   - Bottleneck = component ที่ใช้เวลานานที่สุด
   - ต้อง track component time แยกกันเพื่อคำนวณ ETA

4. **✅ Required for Assembly Merge**
   - Assembly node = join component tokens
   - Final serial = output ของ component merge
   - ต้องรอให้ทุก component เสร็จก่อน assembly

5. **✅ Required for Craftsmanship Traceability**
   - Storytelling ของกระเป๋า = เวลาของแต่ละช่างในแต่ละชิ้น
   - ต้องรู้ว่าใครทำชิ้นไหน ใช้เวลาเท่าไหร่
   - Component token = signature ของแต่ละช่าง

6. **✅ Required for Multi-Craftsman Signature**
   - แต่ละ component = signature ของช่างคนนั้น
   - QC ของแต่ละ component = คนละ node, คนละ behavior
   - ต้อง track component-level QC แยกกัน

7. **✅ Required for Bottleneck Analytics**
   - ชิ้นไหนเสร็จช้า = bottleneck ของใบ
   - ต้องวิเคราะห์ component time เพื่อหา bottleneck
   - Component token = data source สำหรับ analytics

### 0.2 Component Token = First-Class Token

**Architecture Principle:**
- Component Token = **First-Class Token** (ไม่ใช่ sub-token)
- Component Token มี work session ของตัวเอง
- Component Token มี time tracking ของตัวเอง
- Component Token มี behavior execution ของตัวเอง
- Component Token = **Core Mechanic** ไม่ใช่ optional feature

**Current Gap:**
- Infrastructure exists (can create component tokens)
- But workflow/documentation missing
- But UI/work queue support missing
- But time aggregation logic missing

**This is NOT optional - it's MANDATORY for Hatthasilpa workflow**

---

## 1. Component Serial Binding (Task 13) - ✅ COMPLETE

### 1.1 API & Services

**✅ Implemented:**
- `hatthasilpa_component_api.php`:
  - `bind_component_serial` - Bind component serial to final product serial
  - `get_component_serials` - List component serials for job
  - `get_component_panel` - UI panel data
- `ComponentSerialService` - Generate component serials
- `ComponentBindingService` - Bind/unbind component serials to tokens
- `ComponentCompletenessService` - Validate component completeness

**Status:** Stage 1 (Capture & Expose) - ✅ Complete  
**Enforcement:** ❌ Not yet enforced (soft binding only)

### 1.2 Data Model

**✅ Table: `job_component_serial`**
- Links component serials to final product serials
- Tracks `id_component_token` and `id_final_token`
- Supports `component_code` (BODY, FLAP, STRAP, etc.)

**✅ Table: `component_serial`**
- Stores component serial numbers
- Status: `available`, `used`, `scrapped`

**✅ Table: `component_serial_binding`**
- Links component serials to tokens
- Tracks binding at node/work center level

---

## 2. Component Token (Parallel Work) - ✅ INFRASTRUCTURE EXISTS

### 2.1 Token Creation

**✅ `TokenLifecycleService::splitToken()`**
- Can create component tokens: `token_type = 'component'`
- Sets `parallel_group_id` and `parallel_branch_key` for parallel work
- Creates child tokens with `parent_token_id` reference

**Code Reference:**
```php
// source/BGERP/Service/TokenLifecycleService.php:814-860
$childId = $this->createToken([
    'instance_id' => $parentToken['id_instance'],
    'token_type' => 'component',  // ✅ Component token
    'serial_number' => $config['serial'],
    'parent_token_id' => $parentTokenId,
    'current_node_id' => $config['node_id'],
    'qty' => $config['qty'] ?? 1,
    'status' => 'active',
    'parallel_group_id' => $parallelGroupId,  // ✅ Parallel group
    'parallel_branch_key' => $branchKey       // ✅ Branch identifier
]);
```

### 2.2 Parallel Work Infrastructure

**✅ Parallel Split/Merge Nodes:**
- `routing_node.is_parallel_split` - Flag for parallel split nodes
- `routing_node.is_merge_node` - Flag for merge nodes
- `routing_node.parallel_merge_policy` - Merge semantics (ALL, ANY, AT_LEAST, TIMEOUT_FAIL)

**✅ ParallelMachineCoordinator:**
- Coordinates parallel execution
- Tracks parallel groups
- Handles merge readiness checks

**✅ Flow Token Fields:**
- `flow_token.parallel_group_id` - Groups parallel tokens
- `flow_token.parallel_branch_key` - Identifies branch (e.g., "1", "2", "3")

---

## 3. Component Time Tracking - 🟡 INFRASTRUCTURE EXISTS, WORKFLOW MISSING

### 3.1 Current Time Tracking Infrastructure

**✅ TokenWorkSessionService:**
- Manages work sessions per token
- Supports start/pause/resume/complete
- Tracks work time per token
- **Works with ANY token type** (including component tokens)
- **No restrictions on token_type**

**✅ WorkSessionTimeEngine:**
- Calculates work time from `token_work_session`
- Handles live tail seconds (real-time calculation)
- Single source of truth for time calculation
- **Works with ANY token type**

### 3.2 Component Token Time Tracking Status

**✅ Infrastructure:**
- Component tokens **CAN** have work sessions (via `TokenWorkSessionService`)
- Component tokens **CAN** track time independently
- Time is tracked per token (component tokens = separate time tracking)

**❌ Missing Workflow/Documentation:**
- No explicit workflow for starting work on component token separately
- No documentation on component token work sessions
- No UI/work queue support for component tokens
- No aggregation logic for component times at assembly

**🔥 Critical Gap:**
- Infrastructure exists but **workflow is missing**
- Component token time tracking = **MANDATORY** for Hatthasilpa
- But no explicit workflow/documentation = **BLOCKER** for production use

### 3.3 Component Time Tracking = Mandatory for Hatthasilpa

**Why Component Time Tracking is Required:**

1. **Parallel Work:** Workers A, B, C ทำงานพร้อมกัน → ต้อง track time แยกกัน
2. **ETA Calculation:** ETA = `max(component_times) + assembly_time` → ต้องมี component times
3. **Bottleneck Analysis:** ชิ้นไหนเสร็จช้า = bottleneck → ต้องวิเคราะห์ component times
4. **Craftsmanship Traceability:** Storytelling = เวลาของแต่ละช่าง → ต้อง track component times
5. **Multi-Craftsman Signature:** แต่ละ component = signature ของช่าง → ต้อง track component times

**Current Status:**
- ✅ Infrastructure: Can track component time (TokenWorkSessionService works)
- ❌ Workflow: Missing explicit workflow for component token time tracking
- ❌ Documentation: Missing documentation on component token work sessions
- ❌ UI: Missing work queue support for component tokens
- ❌ Aggregation: Missing logic to aggregate component times at assembly

---

## 4. Component Model (Task 5) - 📋 PLANNED (NOT IMPLEMENTED)

### 4.1 Missing Schema

**❌ Not Yet Implemented:**
- `product_component` table - Component master data
- `flow_token.component_code` - Component code (BODY, FLAP, STRAP)
- `flow_token.id_component` - Foreign key to product_component
- `flow_token.root_serial` - Root serial (final product serial)
- `flow_token.root_token_id` - Root token (final product token)
- `routing_node.produces_component` - Which component this node produces
- `routing_node.consumes_components` - Which components this node consumes
- `bom_line.component_code` - Link BOM to components

**Status:** 🟡 **PLANNED** (Task 5 - Component Model & Serial Genealogy)

---

## 5. Parallel Work Scenario Analysis

### 5.1 Scenario: Parallel Component Work (Hatthasilpa Core Workflow)

**Use Case (MANDATORY for Hatthasilpa):**
- Bag has 3 components: BODY, FLAP, STRAP
- Work on components in parallel:
  - Worker A: BODY (2 hours) - Component Token #1
  - Worker B: FLAP (1.5 hours) - Component Token #2
  - Worker C: STRAP (1 hour) - Component Token #3
- Assembly: Combine all components (0.5 hours) - Final Token
- Total: 2 hours (parallel) + 0.5 hours (assembly) = 2.5 hours

**This is NOT optional - this is THE Hatthasilpa workflow**

**Current System Capability:**

1. **✅ Token Creation:**
   - Can create 3 component tokens via `splitToken()`
   - Each token has `token_type = 'component'`
   - Each token has `parallel_group_id` and `parallel_branch_key`
   - **Infrastructure exists**

2. **✅ Parallel Execution:**
   - ParallelMachineCoordinator can coordinate parallel work
   - Merge node can wait for all components to complete
   - **Infrastructure exists**

3. **✅ Time Tracking (Infrastructure):**
   - Each component token CAN have its own work session
   - `TokenWorkSessionService::startSession()` works with component tokens
   - Time is tracked per token independently
   - **Infrastructure exists**

4. **❌ Missing (BLOCKER for Production):**
   - No explicit workflow for starting work on component tokens
   - No UI/work queue support for component tokens
   - No aggregation of component times at assembly
   - No documentation on component token time tracking
   - **Workflow/documentation missing = BLOCKER**

### 5.2 Why This Scenario is Mandatory

**Hatthasilpa = Parallel Craftsmanship:**
- ไม่ใช่ "nice-to-have" แต่เป็น "must-have"
- Component Token = Core Mechanic ของ Hatthasilpa
- Parallel work = DNA ของ Hatthasilpa workflow
- Component time tracking = จำเป็นสำหรับ ETA, bottleneck analysis, traceability

**Current Gap:**
- Infrastructure exists (can do it)
- But workflow/documentation missing (can't use it in production)
- **This is a BLOCKER, not an enhancement**

---

## 6. Integration Points

### 6.1 Behavior Execution Service

**Current:**
- `BehaviorExecutionService` handles behavior execution
- Works with any token (not restricted by token_type)
- Can start/pause/resume/complete sessions on component tokens

**Gap:**
- No explicit support for component-specific behaviors
- No component time aggregation logic

### 6.2 Work Queue

**Current:**
- Work Queue shows tokens assigned to workers
- Can show component tokens in queue

**Gap:**
- No explicit UI for component token work
- No visualization of parallel component work
- No component time display

•	BehaviorExecutionService:
•	“Component token ต้องถูก execute ผ่าน Behavior เช่นเดียวกับ piece token แต่ใช้ id_token ของ component”
•	Work Queue:
•	“Work Queue เป็นหน้าจอหลักในการทำงานกับ component token (ไม่ใช่ PWA)”

### 6.3 Assembly Node

**Current:**
- Merge nodes can wait for parallel tokens
- Component completeness validation exists (`ComponentCompletenessService`)

**Gap:**
- No time aggregation at assembly
- No component time summary
- No Final Token re-activation logic (should re-activate, not create new)

**⚠️ CRITICAL (From Concept Flow):**
- **Final Serial = Created at Job Creation** (NOT at Assembly)
- **Assembly = Re-activate Final Token** (final serial already exists)
- **Component Serial = Label Only** (relationship = parent_token_id)

---

## 7. Recommendations

### 7.1 Immediate (BLOCKER - Must Fix for Production)

**🔥 Component Token Workflow (MANDATORY):**
- Document workflow for component token work sessions
- Create explicit workflow: How to start work on component tokens
- Document: Component token time tracking is MANDATORY for Hatthasilpa
- **This is NOT optional - it's a BLOCKER**

**🔥 Component Token Work Queue (MANDATORY):**
- Add UI support for component tokens in Work Queue
- Show component tokens separately or grouped by parallel_group_id
- Display component time independently
- **This is NOT optional - it's a BLOCKER**

**🔥 Component Time Aggregation (MANDATORY):**
- Add logic to aggregate component times at assembly
- Show component time summary in assembly node
- Track total component time vs assembly time
- ETA = `max(component_times) + assembly_time`
- **This is NOT optional - it's a BLOCKER**

### 7.2 Short Term (Required for Full Functionality)

**📋 Behavior Execution for Component Tokens:**
- Behavior Execution Service must accept `id_component_token`
- Component tokens must have their own behavior execution
- Component-level QC = separate behavior execution
- **Required for component-level workflows**

**📋 Component Token Assignment:**
- Component tokens must be assignable to workers
- Workers see only their component tokens in work queue
- Component token assignment = separate from final token assignment
- **Required for parallel work**

### 7.3 Long Term (Task 5 Implementation)

**📋 Component Model:**
- Implement `product_component` table
- Add `component_code` to `flow_token`
- Add `produces_component` / `consumes_components` to `routing_node`
- Link BOM to components

**📋 Component Genealogy:**
- Track `root_serial` and `root_token_id` in component tokens
- Enable genealogy queries (component → final product)
- Support component replacement tracking

---

## 8. API Audit

### 8.1 Component Serial API

**✅ `hatthasilpa_component_api.php`:**
- `bind_component_serial` - ✅ Working
- `get_component_serials` - ✅ Working
- `get_component_panel` - ✅ Working

**Status:** ✅ Complete (Stage 1)

### 8.2 Token API

**✅ `dag_token_api.php`:**
- Works with any token (including component tokens)
- No restrictions on `token_type`

**Gap:**
- No explicit component token endpoints
- No component time aggregation endpoints

### 8.3 Work Session API

**✅ `TokenWorkSessionService`:**
- Works with any token (including component tokens)
- No restrictions on `token_type`

**Gap:**
- No component-specific time tracking documentation
- No component time aggregation methods

---

## 9. Database Schema Audit

### 9.1 Existing Tables

**✅ `flow_token`:**
- `token_type` enum('batch', 'piece', 'component') - ✅ Supports component
- `parallel_group_id` - ✅ Supports parallel work
- `parallel_branch_key` - ✅ Supports branch identification
- `parent_token_id` - ✅ Supports component → final product relationship

**✅ `token_work_session`:**
- `id_token` - ✅ Works with component tokens
- No restrictions on `token_type`

**✅ `job_component_serial`:**
- Links component serials to final product serials
- Tracks `id_component_token` and `id_final_token`

### 9.2 Missing Tables

**❌ `product_component`:**
- Component master data (not yet implemented)

**❌ Component time aggregation tables:**
- No tables for aggregating component times

---

## 10. Summary & Next Steps

### 10.1 What Works Now (Infrastructure)

1. **✅ Component Token Creation:**
   - Can create component tokens via `splitToken()`
   - Parallel work infrastructure exists
   - **Infrastructure: ✅ Complete**

2. **✅ Component Serial Binding:**
   - API exists and working
   - Can bind component serials to final products
   - **Infrastructure: ✅ Complete**

3. **✅ Time Tracking (Infrastructure):**
   - Component tokens CAN have work sessions
   - Time is tracked per token independently
   - `TokenWorkSessionService` works with component tokens
   - **Infrastructure: ✅ Complete**

### 10.2 What's Missing (BLOCKERS for Production)

1. **🔥 Component Time Tracking Workflow (BLOCKER):**
   - No explicit workflow for component token time tracking
   - No documentation on component token work sessions
   - **This is MANDATORY, not optional**

2. **🔥 Component Time Aggregation (BLOCKER):**
   - No logic to aggregate component times at assembly
   - No component time summary
   - ETA calculation missing component times
   - **This is MANDATORY, not optional**

3. **🔥 Work Queue UI for Component Tokens (BLOCKER):**
   - No UI support for component tokens
   - Workers can't see component tokens in work queue
   - **This is MANDATORY, not optional**

4. **📋 Component Model (Task 5):**
   - Still PLANNED (not implemented)
   - Missing schema for component master data
   - **This is required for full functionality**

### 10.3 Critical Next Steps (Priority Order)

**🔥 Priority 1: BLOCKERS (Must Fix for Production)**

1. **Document Component Token Time Tracking Workflow:**
   - Document that component tokens can use `TokenWorkSessionService`
   - Create workflow for parallel component work
   - Add examples of component time tracking
   - **Status: MANDATORY, not optional**

2. **Implement Work Queue UI for Component Tokens:**
   - Add UI support for component tokens
   - Show component tokens in parallel groups
   - Display component time independently
   - **Status: MANDATORY, not optional**

3. **Implement Component Time Aggregation:**
   - Add logic to aggregate component times at assembly
   - Show component time summary
   - Track total component time vs assembly time
   - ETA = `max(component_times) + assembly_time`
   - **Status: MANDATORY, not optional**

**📋 Priority 2: Required for Full Functionality**

4. **Behavior Execution for Component Tokens:**
   - Behavior Execution Service must accept `id_component_token`
   - Component tokens must have their own behavior execution
   - **Status: Required for component-level workflows**

5. **Component Token Assignment:**
   - Component tokens must be assignable to workers
   - Workers see only their component tokens in work queue
   - **Status: Required for parallel work**

**📋 Priority 3: Long Term**

6. **Implement Component Model (Task 5):**
   - Create `product_component` table
   - Add component fields to `flow_token`
   - Link BOM to components
   - **Status: Required for full component model**

---

## 11. References

- **Component Serial Binding Spec:** `docs/developer/03-superdag/03-specs/SPEC_COMPONENT_SERIAL_BINDING.md`
- **Component Model Task:** `docs/dag/03-tasks/TASK_DAG_5_COMPONENT_MODEL.md`
- **Component Binding Task 13:** `docs/dag/tasks/task13.md`
- **Component API Task 13.1:** `docs/dag/task13_1_component_binding_manual_tests.md`
- **Component API Task 13.2:** `docs/dag/task13_2_component_read_api.md`
- **Time Engine Spec:** `docs/developer/03-superdag/03-specs/SPEC_TIME_ENGINE.md`
- **Parallel Work:** `docs/developer/03-superdag/01-core/SuperDAG_Architecture.md` (Parallel Flow section)

---

---

## 12. Key Concepts from Concept Flow

**⚠️ CRITICAL RULES (Must Follow):**

1. **Final Serial = Created at Job Creation**
   - Final serial exists from Job Creation (not generated at Assembly)
   - Assembly = Re-activate Final Token (not create new)

2. **Job Tray = Physical Container**
   - 1 Final Token = 1 Job Tray
   - All components of a Final Token → Must be in the same tray
   - Digital relationship (`parent_token_id`) = Physical relationship (tray)

3. **Component Serial = Label Only**
   - Component serial = Just a label (human-readable ID)
   - Real relationship = `parent_token_id` / `parallel_group_id`
   - DO NOT use serial pattern matching for relationships

4. **Component Token MUST have parent_token_id**
   - No orphan components allowed
   - Every component token must reference Final Token

5. **Assembly Worker UI**
   - Show Final Token (not component tokens)
   - Show "Components: Complete" status
   - Worker picks up Tray (all components in one tray)

6. **Component Token = Native Parallel Split (NOT Subgraph)**
   - Use `is_parallel_split=1` flag (not `node_type='subgraph'`)
   - Use `is_merge_node=1` flag (not subgraph exit)
   - Component Token ≠ Subgraph `fork` mode (different concepts)

**See Also:**
- `docs/developer/03-superdag/03-specs/COMPONENT_PARALLEL_FLOW_CONCEPT.md` - Detailed concept flow
- `docs/dag/SUBGRAPH_VS_COMPONENT_CONCEPT_AUDIT.md` - Subgraph vs Component comparison

---

**Last Updated:** 2025-01-XX  
**Version:** 1.1 (Aligned with Concept Flow)  
**Status:** 🟡 PARTIALLY IMPLEMENTED  
**Next:** Document component token time tracking workflow


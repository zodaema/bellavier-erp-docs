# Subgraph vs Component Token - Concept Audit

**Date:** 2025-01-XX  
**Purpose:** Audit Subgraph concept and identify conflicts with Component Token Architecture  
**Scope:** Hatthasilpa Line (Component Token workflow)

**⚠️ CRITICAL FINDING:** Current Subgraph `fork` mode concept conflicts with Component Token architecture

---

## Executive Summary

**Current Subgraph Status:**
- ✅ `same_token` mode - Complete and working
- ⏳ `fork` mode - Not implemented (stub only)
- ✅ Subgraph governance - Complete (versioning, delete protection)

**Key Finding:**
**Subgraph `fork` mode ≠ Component Parallel Split**

These are **different concepts** that solve **different problems**:
- Subgraph fork = Reusable workflow module with parallel branches
- Component parallel split = Product-specific parallel component work

**Recommendation:**
- ✅ Keep Subgraph `same_token` mode (works for sequential reusable modules)
- ❌ **DO NOT implement** Subgraph `fork` mode for Component Token
- ✅ Use native Parallel Split (`is_parallel_split` flag) for Component Token

---

## 1. Current Subgraph Concept

### 1.1 Subgraph = Reusable Workflow Module

**Purpose:** Workflow reuse across multiple products

**Example:**
```
MAIN GRAPH (Product A):
   CUT → SEW_BODY → SUBGRAPH(HARDWARE_FLOW) → ASSEMBLY

MAIN GRAPH (Product B):
   CUT → SEW_STRAP → SUBGRAPH(HARDWARE_FLOW) → ASSEMBLY

HARDWARE_FLOW (subgraph):
   START → PREP_HARDWARE → ATTACH_HARDWARE → END
```

**Use Case:**
- Hardware assembly module (reusable across products)
- Leather drying process (reusable)
- QC batch workflow (reusable)
- Printing pattern workflow (reusable)

**Characteristics:**
- ✅ Reusable across multiple products
- ✅ Version-controlled (immutable snapshots)
- ✅ Modular definition
- ✅ Governance (delete protection, dependency tracking)

### 1.2 Subgraph Execution Modes

**1.2.1 `same_token` Mode** (✅ COMPLETE)

**Behavior:**
- Token continues inside subgraph without spawning new tokens
- Simple, clean genealogy
- Nested status complexity

**Flow:**
```
Token enters subgraph node
  ↓
Create subgraph instance (parent_instance_id = current instance)
  ↓
Set token current_node_id = subgraph.entry_node_id
  ↓
Execute subgraph nodes normally
  ↓
When token reaches subgraph.exit_node_id:
  → Set token current_node_id = parent next node
  → Complete subgraph instance
```

**Status:** ✅ **IMPLEMENTED** and working

**1.2.2 `fork` Mode** (⏳ PENDING)

**Original Concept (from Roadmap):**
- Enter subgraph → spawn child tokens → rejoin
- Supports parallel work
- More complex genealogy

**Flow (Original Concept):**
```
Token enters subgraph node
  ↓
Create subgraph instance
  ↓
Spawn child tokens at subgraph.entry_node_id
  ↓
Execute child tokens through subgraph
  ↓
When all children reach subgraph.exit_node_id:
  → Join children back to parent token
  → Set parent token current_node_id = parent next node
  → Complete subgraph instance
```

**Status:** ⏳ **NOT IMPLEMENTED** (stub only)

---

## 2. Component Token Architecture

### 2.1 Component Token = Product-Specific Parallel Work

**Purpose:** Parallel component work for a single product

**Example:**
```
MAIN GRAPH (Bag Product):
   CUT → PARALLEL_SPLIT → [BODY, FLAP, STRAP] → ASSEMBLY

BODY Branch:
   STITCH_BODY → QC_BODY

FLAP Branch:
   STITCH_FLAP → QC_FLAP

STRAP Branch:
   STITCH_STRAP → QC_STRAP
```

**Use Case:**
- Bag components: BODY, FLAP, STRAP, LINING
- Each component = separate worker, separate time tracking
- Assembly = merge all components into final product

**Characteristics:**
- ✅ Product-specific (not reusable across products)
- ✅ Parallel work (multiple workers, separate time tracking)
- ✅ Component-level QC
- ✅ Assembly merge (re-activate Final Token)
- ✅ ETA = max(component_times) + assembly_time

### 2.2 Component Token Mechanism

**1. Parallel Split:**
- `is_parallel_split = 1` flag on node
- Creates Component Tokens (token_type = 'component')
- Each component = separate token with `parent_token_id`

**2. Component Work:**
- Workers work on component tokens independently
- Time tracked per component token
- Behavior execution per component token

**3. Assembly Merge:**
- `is_merge_node = 1` flag on node
- Waits for all components
- Re-activates Final Token (parent token)
- Aggregates component times

---

## 3. Key Differences: Subgraph vs Component

### 3.1 Purpose

| Aspect | Subgraph | Component Token |
|--------|----------|-----------------|
| **Purpose** | Reusable workflow module | Product-specific parallel work |
| **Reusability** | ✅ Reusable across products | ❌ Product-specific |
| **Governance** | ✅ Version-controlled | ❌ Not version-controlled |
| **Scope** | Module (e.g., hardware assembly) | Component (e.g., BODY, FLAP, STRAP) |

### 3.2 Token Behavior

| Aspect | Subgraph `same_token` | Subgraph `fork` (concept) | Component Token |
|--------|----------------------|--------------------------|-----------------|
| **Token Spawning** | ❌ No spawning | ✅ Spawn children | ✅ Spawn component tokens |
| **Token Type** | Same token | Child tokens | Component tokens (`token_type='component'`) |
| **Parent Relationship** | N/A | `parent_token_id` | `parent_token_id` |
| **Merge Behavior** | Exit subgraph | Join children | Re-activate parent |
| **Time Tracking** | Same token | Children | Per component |

### 3.3 Use Cases

**Subgraph `same_token`:**
- Sequential reusable module
- Example: Hardware assembly (sequential steps)
- Example: Leather drying process (sequential steps)

**Subgraph `fork` (original concept):**
- Parallel reusable module
- Example: QC batch workflow (parallel QC of multiple items)
- **⚠️ NOT suitable for Component Token**

**Component Token:**
- Parallel product-specific work
- Example: Bag components (BODY, FLAP, STRAP)
- **⚠️ NOT reusable across products**

---

## 4. Critical Conflict: Subgraph `fork` vs Component Token

### 4.1 Why Subgraph `fork` is NOT Suitable for Component Token

**Conflict #1: Reusability vs Product-Specific**
- Subgraph = Reusable module (same module, multiple products)
- Component = Product-specific (different components, different products)
- **Cannot use same subgraph for different product components**

**Conflict #2: Governance vs Flexibility**
- Subgraph = Version-controlled (immutable snapshots)
- Component = Product-specific (changes with product design)
- **Component structure should not be version-controlled like subgraph**

**Conflict #3: Entry/Exit vs Split/Merge**
- Subgraph = Entry node + Exit node (single entry, single exit)
- Component = Split node + Merge node (multiple branches, multiple components)
- **Component branches are not "entry/exit" pattern**

**Conflict #4: Subgraph Node vs Parallel Split Node**
- Subgraph = Special node type (`node_type='subgraph'`)
- Component = Standard node with flag (`is_parallel_split=1`)
- **Component uses native parallel split, not subgraph node**

### 4.2 Example: Bag Product

**❌ WRONG: Using Subgraph `fork` for Components**
```
MAIN GRAPH:
   CUT → SUBGRAPH(BAG_COMPONENTS_FORK) → ASSEMBLY

BAG_COMPONENTS_FORK (subgraph):
   ENTRY → FORK → [BODY, FLAP, STRAP] → JOIN → EXIT
```

**Problems:**
- ❌ Subgraph is product-specific (not reusable)
- ❌ Version-controlled subgraph for product components (too rigid)
- ❌ Different products have different components (not reusable)
- ❌ Component structure changes with product design (not modular)

**✅ CORRECT: Using Native Parallel Split for Components**
```
MAIN GRAPH:
   CUT → PARALLEL_SPLIT (is_parallel_split=1) → [BODY, FLAP, STRAP] → MERGE (is_merge_node=1) → ASSEMBLY

BODY Branch:
   STITCH_BODY → QC_BODY

FLAP Branch:
   STITCH_FLAP → QC_FLAP

STRAP Branch:
   STITCH_STRAP → QC_STRAP
```

**Benefits:**
- ✅ Product-specific (graph = product routing)
- ✅ Flexible (changes with product design)
- ✅ Component-level QC (separate nodes per component)
- ✅ Native parallel split/merge (no subgraph overhead)

---

## 5. Subgraph `fork` Mode: Valid Use Cases

### 5.1 When Subgraph `fork` is Appropriate

**Use Case: Reusable Parallel Module**

Example: QC Batch Workflow (reusable)
```
MAIN GRAPH:
   CUT → SEW → SUBGRAPH(QC_BATCH_PARALLEL) → PACK

QC_BATCH_PARALLEL (subgraph):
   ENTRY → SPLIT → [QC_1, QC_2, QC_3] → JOIN → EXIT
```

**Why This Works:**
- ✅ Reusable module (same QC workflow, multiple products)
- ✅ Version-controlled (QC process is standardized)
- ✅ Modular (QC process is independent of product)
- ✅ Same module, different products (reusability)

**Use Case: Parallel Approval Workflow**
```
MAIN GRAPH:
   CREATE_QUOTE → SUBGRAPH(PARALLEL_APPROVAL) → SEND_QUOTE

PARALLEL_APPROVAL (subgraph):
   ENTRY → SPLIT → [MANAGER_APPROVE, FINANCE_APPROVE] → JOIN → EXIT
```

**Why This Works:**
- ✅ Reusable module (same approval workflow, multiple processes)
- ✅ Version-controlled (approval process is standardized)
- ✅ Modular (approval process is independent of product)

### 5.2 When Subgraph `fork` is NOT Appropriate

**❌ Product-Specific Parallel Work (e.g., Component Token)**
- Use native parallel split instead
- Component structure is product-specific, not reusable

**❌ Parallel Work with Component-Level Data**
- Use native parallel split with `produces_component`
- Subgraph cannot store component metadata

**❌ Parallel Work with Physical Tray Mapping**
- Use native parallel split with `parent_token_id`
- Subgraph fork does not map to physical tray

---

## 6. Recommendation: Two Different Mechanisms

### 6.1 Native Parallel Split (for Component Token)

**Mechanism:**
- Node with `is_parallel_split = 1` flag
- Creates Component Tokens (`token_type = 'component'`)
- Each component has `parent_token_id` (Final Token)
- Node with `is_merge_node = 1` flag (merge)
- Re-activates Final Token (parent token)

**Use For:**
- ✅ Product-specific parallel component work
- ✅ Bag components (BODY, FLAP, STRAP)
- ✅ Component-level time tracking
- ✅ Component-level QC
- ✅ Physical tray mapping

**Status:** ✅ **COMPLETE** (infrastructure exists)

### 6.2 Subgraph `fork` Mode (for Reusable Parallel Module)

**Mechanism:**
- Node with `node_type = 'subgraph'` and `mode = 'fork'`
- Spawns child tokens inside subgraph
- Child tokens execute subgraph nodes
- Join children at exit node
- Return to parent token

**Use For:**
- ✅ Reusable parallel modules (e.g., QC batch, parallel approval)
- ✅ Version-controlled parallel workflows
- ✅ Modular parallel processes

**Status:** ⏳ **NOT IMPLEMENTED** (stub only)

---

## 7. Critical Rules: Subgraph vs Component

### 7.1 ❌ DO NOT Use Subgraph `fork` for Component Token

**Reasons:**
1. Component Token = Product-specific (not reusable)
2. Component Token = Physical tray mapping (subgraph cannot handle)
3. Component Token = Native parallel split (no subgraph overhead)
4. Component Token = Component metadata (`produces_component`, `component_code`)

**Use Native Parallel Split Instead:**
- `is_parallel_split = 1` flag
- `produces_component` on target nodes
- `is_merge_node = 1` flag
- `consumes_components` on merge node

### 7.2 ✅ Use Subgraph `fork` for Reusable Parallel Module

**Valid Use Cases:**
- QC batch workflow (reusable)
- Parallel approval workflow (reusable)
- Parallel inspection workflow (reusable)

**Characteristics:**
- ✅ Reusable across products
- ✅ Version-controlled
- ✅ Modular
- ✅ Independent of product design

### 7.3 ✅ Use Subgraph `same_token` for Sequential Reusable Module

**Valid Use Cases:**
- Hardware assembly module (sequential)
- Leather drying process (sequential)
- Printing pattern workflow (sequential)

**Status:** ✅ **COMPLETE** and working

---

## 8. Implementation Status

### 8.1 Native Parallel Split (Component Token)

**Status:** ✅ **INFRASTRUCTURE COMPLETE**

**Existing:**
- ✅ `is_parallel_split` flag on `routing_node`
- ✅ `is_merge_node` flag on `routing_node`
- ✅ `TokenLifecycleService::splitToken()` (creates component tokens)
- ✅ `parallel_group_id`, `parallel_branch_key`, `parent_token_id`
- ✅ `ParallelMachineCoordinator` (merge coordination)

**Missing (from Concept Flow):**
- ❌ `produces_component` on `routing_node` (Task 5)
- ❌ `consumes_components` on `routing_node` (Task 5)
- ❌ `component_code` on `flow_token` (Task 5)
- ❌ Component time aggregation at merge
- ❌ Work Queue UI for component tokens

### 8.2 Subgraph `same_token` Mode

**Status:** ✅ **COMPLETE**

**Existing:**
- ✅ `node_type = 'subgraph'` with `mode = 'same_token'`
- ✅ `subgraph_ref` JSON field on `routing_node`
- ✅ `DAGRoutingService::handleSubgraphNode()` (implemented)
- ✅ Subgraph instance creation
- ✅ Version pinning (mandatory)
- ✅ Subgraph governance (delete protection, dependency tracking)

### 8.3 Subgraph `fork` Mode

**Status:** ⏳ **NOT IMPLEMENTED** (stub only)

**Roadmap Says:**
- Fork mode: spawn child tokens → execute in subgraph → join at exit
- **NOT IMPLEMENTED**

**Recommendation:**
- ✅ Implement for **reusable parallel modules only**
- ❌ **DO NOT use for Component Token** (use native parallel split)

---

## 9. Concept Alignment: Subgraph + Component Token

### 9.1 Coexistence Strategy

**Both mechanisms can coexist:**

**Scenario: Bag Product with Reusable QC Module**
```
MAIN GRAPH:
   CUT → PARALLEL_SPLIT → [BODY, FLAP, STRAP] → MERGE → SUBGRAPH(QC_BATCH) → ASSEMBLY

BODY Branch (native parallel split):
   STITCH_BODY → QC_BODY

FLAP Branch (native parallel split):
   STITCH_FLAP → QC_FLAP

STRAP Branch (native parallel split):
   STITCH_STRAP → QC_STRAP

QC_BATCH (subgraph, reusable):
   ENTRY → SPLIT → [QC_1, QC_2, QC_3] → JOIN → EXIT
```

**Why This Works:**
- ✅ Native parallel split for component-specific work (BODY, FLAP, STRAP)
- ✅ Subgraph for reusable parallel module (QC_BATCH)
- ✅ Each mechanism serves different purpose

### 9.2 Design Principles

**1. Component-Specific Work = Native Parallel Split**
- Use `is_parallel_split` + `is_merge_node`
- No subgraph node
- Product-specific graph definition

**2. Reusable Parallel Module = Subgraph `fork`**
- Use `node_type='subgraph'` + `mode='fork'`
- Version-controlled module
- Reusable across products

**3. Reusable Sequential Module = Subgraph `same_token`**
- Use `node_type='subgraph'` + `mode='same_token'`
- Version-controlled module
- Reusable across products

---

## 10. Critical Gaps & Recommendations

### 10.1 🔴 CRITICAL: Concept Clarity

**Gap:** Roadmap does not distinguish between:
- Subgraph `fork` (reusable parallel module)
- Native parallel split (component-specific work)

**Impact:**
- Confusion about when to use which mechanism
- Risk of using subgraph for component token (wrong approach)

**Recommendation:**
- ✅ Update roadmap to clarify use cases
- ✅ Add "Subgraph vs Component" decision tree
- ✅ Document when to use each mechanism

### 10.2 🔴 CRITICAL: Missing Implementation for Component Token

**Gap:** Component Token missing fields
- ❌ `produces_component` on `routing_node`
- ❌ `consumes_components` on `routing_node`
- ❌ `component_code` on `flow_token`

**Impact:**
- Cannot map nodes to components
- Cannot validate component completeness at merge

**Recommendation:**
- ✅ Implement Task 5 (Component Model) before using component tokens
- ✅ Add `produces_component` / `consumes_components` to `routing_node`
- ✅ Add `component_code` to `flow_token`

### 10.3 🟡 MEDIUM: Subgraph `fork` Mode Not Implemented

**Gap:** Subgraph `fork` mode is stub only

**Impact:**
- Cannot use subgraph for reusable parallel modules
- Limited to sequential subgraphs only

**Recommendation:**
- ✅ Implement Subgraph `fork` mode for **reusable parallel modules only**
- ❌ **DO NOT use for Component Token** (use native parallel split)
- ✅ Document valid use cases (QC batch, parallel approval)

---

## 11. Decision Tree: Which Mechanism to Use?

```
Do you need parallel work?
├─ YES
│   ├─ Is it product-specific?
│   │   ├─ YES → Use Native Parallel Split (is_parallel_split)
│   │   │   Examples: Bag components, product-specific branches
│   │   └─ NO → Use Subgraph fork mode (node_type='subgraph', mode='fork')
│   │       Examples: QC batch, parallel approval
│   └─ NO
└─ NO
    ├─ Is it reusable across products?
    │   ├─ YES → Use Subgraph same_token mode (node_type='subgraph', mode='same_token')
    │   │   Examples: Hardware assembly, leather drying
    │   └─ NO → Use standard sequential nodes
    │       Examples: Product-specific sequential steps
    └─ NO → Use standard sequential nodes
```

---

## 12. Summary & Action Items

### 12.1 Key Findings

1. ✅ Subgraph `same_token` mode = Reusable sequential module (COMPLETE)
2. ⏳ Subgraph `fork` mode = Reusable parallel module (NOT IMPLEMENTED)
3. ✅ Native Parallel Split = Product-specific parallel work (INFRASTRUCTURE COMPLETE)
4. ❌ **DO NOT use Subgraph `fork` for Component Token** (wrong approach)

### 12.2 Critical Rules

1. ✅ **Component Token = Native Parallel Split** (not subgraph)
2. ❌ **Subgraph fork ≠ Component parallel split** (different concepts)
3. ✅ **Both can coexist** (serve different purposes)

### 12.3 Action Items

**URGENT (Before Component Token Production):**
1. ✅ Implement Task 5: Add `produces_component`, `consumes_components` to `routing_node`
2. ✅ Implement Task 5: Add `component_code` to `flow_token`
3. ✅ Document decision tree: When to use Subgraph vs Native Parallel Split
4. ✅ Update Component Parallel Flow Spec to clarify: "Use Native Parallel Split, NOT Subgraph"

**MEDIUM (Subgraph fork for Other Use Cases):**
1. ⏳ Implement Subgraph `fork` mode for reusable parallel modules
2. ⏳ Document valid use cases (QC batch, parallel approval)
3. ⏳ Add validation: Subgraph fork cannot use `produces_component`

---

---

## 13. NEW Subgraph Concept: Module Graph Template

**⚠️ CRITICAL UPDATE (2025-01-XX):**

Subgraph concept ถูกปรับใหม่เป็น **"Module Graph Template"**

### 13.1 OLD Concept (ผิด)
- Subgraph = เลือก Graph อื่น (Product Graph) มาใส่ใน Graph ใหม่
- ปัญหา: เหมือนเอกราฟของกระเป๋าอีกแบบมาปนกัน → โครงสร้างมั่ว

### 13.2 NEW Concept (ถูกต้อง)
- Subgraph = Module Graph (Template)
- Module Graph = "สูตรทำชิ้นส่วน" หรือ "ขั้นตอนย่อย"
- Product Graph อ้างได้เฉพาะ Module Graph เท่านั้น
- ห้ามอ้าง Product Graph อื่น

### 13.3 Graph Classification

**Product Graph:**
- `graph_type = 'product'`
- กราฟหลักของกระเป๋า 1 แบบ
- CAN reference Module Graph
- CANNOT reference Product Graph

**Module Graph:**
- `graph_type = 'module'`
- Template ของ Component/Step ย่อย
- Reusable across products
- Version-controlled

### 13.4 Component Token + Module Graph

**Workflow:**
```
Product Graph:
   CUT → PARALLEL_SPLIT → [BODY_BRANCH, FLAP_BRANCH, STRAP_BRANCH] → MERGE → ASSEMBLY

BODY_BRANCH:
   → SUBGRAPH(BODY_MODULE)

Component Token (BODY):
   → Enters BODY_MODULE (same token)
   → Executes: STITCH_BODY → EDGE_BODY → QC_BODY
   → Exits BODY_MODULE (same token)
   → Moves to MERGE
```

**Benefits:**
- ✅ Module Graph = Reusable Template
- ✅ Component Token เดินผ่าน module (same token)
- ✅ No new Final Token created in module
- ✅ Module = "สูตรทำชิ้นส่วน" (ใช้ซ้ำได้)

**See:** `docs/dag/SUBGRAPH_MODULE_TEMPLATE_CONCEPT.md` for detailed new concept

---

**Last Updated:** 2025-01-XX  
**Version:** 1.1 (Updated with Module Graph Concept)  
**Status:** Critical Concept Audit Complete  
**Next:** Implement Module Graph classification and validation



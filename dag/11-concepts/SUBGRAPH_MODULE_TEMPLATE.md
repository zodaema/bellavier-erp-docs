# Subgraph = Module Template (NEW CONCEPT)

**Date:** 2025-01-XX  
**Purpose:** Define new Subgraph concept as Module Template (not Product Graph)  
**Version:** 2.0 (Conceptual Redesign)

**⚠️ CRITICAL CHANGE:** Subgraph = Module Template สำหรับ Component/Step ย่อย (ไม่ใช่ Product Graph)

---

## Executive Summary

**OLD CONCEPT (ผิด):**
- Subgraph = เลือก Graph อื่น (Product Graph) มาใส่ใน Graph ใหม่
- ปัญหา: เหมือนเอากราฟของกระเป๋าอีกแบบมาปนกัน → โครงสร้างมั่ว

**NEW CONCEPT (ถูกต้อง):**
- Subgraph = Module Template สำหรับ Component/Step ย่อย
- Product Graph อ้างได้เฉพาะ Module Graph เท่านั้น
- ห้ามอ้าง Product Graph อื่น

---

## 1. Graph Classification (NEW)

### 1.1 Product Graph

**Definition:** กราฟหลักของกระเป๋า 1 แบบ

**Characteristics:**
- แทนการผลิตกระเป๋า 1 แบบ (เช่น Diagonal Bag, Tote Bag)
- มี Final Token (กระเป๋าสำเร็จรูป)
- มี Component Tokens (ชิ้นส่วนของกระเป๋า)
- สามารถอ้างอิง Module Graph (via Subgraph node)

**Example:**
```
Product Graph: "Diagonal Bag Production"
   CUT → PARALLEL_SPLIT → [BODY, FLAP, STRAP] → MERGE → ASSEMBLY → PACK
```

**Database:**
```sql
routing_graph:
  - graph_type = 'product' (NEW)
  - is_module = 0
  - is_reusable_template = 0
```

### 1.2 Module Graph (Subgraph Template)

**Definition:** กราฟย่อย (Template) ที่ใช้เป็น "สูตรทำชิ้นส่วน" หรือ "ขั้นตอนย่อย"

**Characteristics:**
- แทนการทำ Component ชิ้นส่วนหนึ่ง (เช่น STRAP Module, BODY Module)
- แทนการทำ Step ย่อย (เช่น Hardware Assembly Module, QC Batch Module)
- **Reusable Template** (ใช้ซ้ำได้)
- **Version-controlled** (มี version management)
- **ไม่มี Final Token** (ไม่ใช่ product)

**Example:**
```
Module Graph: "STRAP_MODULE" (Template)
   ENTRY → STITCH_STRAP → EDGE_STRAP → QC_STRAP → EXIT

Module Graph: "HARDWARE_ASSEMBLY_MODULE" (Template)
   ENTRY → PREP_HARDWARE → ATTACH_HARDWARE → QC_HARDWARE → EXIT
```

**Database:**
```sql
routing_graph:
  - graph_type = 'module' (NEW)
  - is_module = 1 (NEW)
  - is_reusable_template = 1 (NEW)
```

---

## 2. Subgraph Reference Rules (NEW)

### 2.1 Product Graph CAN Reference Module Graph

**Rule:** Product Graph สามารถอ้างอิง Module Graph ผ่าน Subgraph node

**Example:**
```
Product Graph: "Diagonal Bag"
   CUT → SUBGRAPH(STRAP_MODULE) → SUBGRAPH(BODY_MODULE) → ASSEMBLY

STRAP_MODULE:
   ENTRY → STITCH_STRAP → EDGE_STRAP → QC_STRAP → EXIT

BODY_MODULE:
   ENTRY → STITCH_BODY → EDGE_BODY → QC_BODY → EXIT
```

**✅ VALID** - Product Graph references Module Graph

### 2.2 Product Graph CANNOT Reference Product Graph

**Rule:** Product Graph **ห้ามอ้างอิง** Product Graph อื่น

**Example:**
```
❌ WRONG:
Product Graph: "Diagonal Bag V2"
   CUT → SUBGRAPH(DIAGONAL_BAG_V1) → ASSEMBLY

DIAGONAL_BAG_V1 (Product Graph):
   CUT → SEW → EDGE → QC → ASSEMBLY
```

**Problems:**
- ❌ เหมือนเอากราฟของกระเป๋าอีกแบบมาปนกัน
- ❌ โครงสร้างมั่ว (product inside product)
- ❌ ไม่ชัดว่า Final Token ของใคร

**✅ CORRECT:**
- Create new Product Graph (copy/modify structure)
- OR use Module Graph (if steps are reusable)

### 2.3 Module Graph CAN Reference Module Graph

**Rule:** Module Graph สามารถอ้างอิง Module Graph อื่น (nested modules)

**Example:**
```
Module Graph: "ADVANCED_ASSEMBLY_MODULE"
   ENTRY → SUBGRAPH(HARDWARE_MODULE) → SUBGRAPH(STRAP_ATTACH_MODULE) → EXIT

HARDWARE_MODULE:
   ENTRY → PREP_HARDWARE → ATTACH_HARDWARE → EXIT

STRAP_ATTACH_MODULE:
   ENTRY → STITCH_STRAP → ATTACH_STRAP → EXIT
```

**✅ VALID** - Module can reference another module

**Validation:**
- ✅ Check circular reference (A → B → A)
- ✅ Check recursion depth (max 5 levels)

---

## 3. Component Token + Module Graph Integration

### 3.1 Component Token เดินใน Module Graph

**Concept:** Component Token จะเดินใน Module Graph ที่ตรงกับ `component_code`

**Example:**
```
Product Graph: "Diagonal Bag"
   CUT → PARALLEL_SPLIT → [BODY, FLAP, STRAP] → MERGE → ASSEMBLY

BODY Branch:
   → SUBGRAPH(BODY_MODULE)

FLAP Branch:
   → SUBGRAPH(FLAP_MODULE)

STRAP Branch:
   → SUBGRAPH(STRAP_MODULE)

BODY_MODULE (Module Graph):
   ENTRY → STITCH_BODY → EDGE_BODY → QC_BODY → EXIT

FLAP_MODULE (Module Graph):
   ENTRY → STITCH_FLAP → QC_FLAP → EXIT

STRAP_MODULE (Module Graph):
   ENTRY → STITCH_STRAP → EDGE_STRAP → QC_STRAP → EXIT
```

**Flow:**
1. Parallel Split สร้าง Component Tokens (BODY, FLAP, STRAP)
2. BODY Token → เดินเข้า BODY_MODULE (subgraph)
3. FLAP Token → เดินเข้า FLAP_MODULE (subgraph)
4. STRAP Token → เดินเข้า STRAP_MODULE (subgraph)
5. Component Tokens เสร็จ → ออกจาก module → มา Merge
6. Merge → Re-activate Final Token

### 3.2 Module Graph = "สูตรทำชิ้นส่วน"

**Concept:** Module Graph ใช้เป็น Template ของ Component (ไม่ใช่ "อีกใบหนึ่ง")

**Example:**
```
STRAP_MODULE = "สูตรทำสายกระเป๋า"
   ENTRY → STITCH_STRAP → EDGE_STRAP → QC_STRAP → EXIT

BODY_MODULE = "สูตรทำตัวกระเป๋า"
   ENTRY → STITCH_BODY → EDGE_BODY → QC_BODY → EXIT
```

**Benefits:**
- ✅ Module Graph = Reusable Template
- ✅ Different products can use same module (e.g., STRAP module for all bags)
- ✅ Version-controlled (module version = process version)
- ✅ Modular (change module = change process for all products)

**Physical Reality:**
- Component Token เดินใน Module Graph
- แต่ Component Token ยังผูกกับ Final Token (parent_token_id)
- ยังอยู่ในถาด F001 ของใบเดิม

---

## 4. Subgraph Execution Mode (Simplified)

### 4.1 `same_token` Mode Only (for Module Graph)

**Rule:** Module Graph ใช้ `same_token` mode เท่านั้น

**Behavior:**
- Component Token เข้า Module Graph
- Component Token เดินผ่าน Module nodes ตามปกติ
- Component Token ออกจาก Module Graph
- Component Token กลับมา Product Graph

**Flow:**
```
Component Token (STRAP) enters STRAP_MODULE:
  ↓
Create subgraph instance (module instance)
  ↓
Set component token current_node_id = STRAP_MODULE.entry_node_id
  ↓
Execute: STITCH_STRAP → EDGE_STRAP → QC_STRAP
  ↓
Component token reaches STRAP_MODULE.exit_node_id
  ↓
Set component token current_node_id = next node in Product Graph
  ↓
Component token exits module
```

**Database:**
```sql
job_graph_instance:
  - id_instance (Module instance)
  - id_graph = STRAP_MODULE
  - graph_version = "1.0"
  - parent_instance_id = Product Graph instance
  - parent_token_id = Component Token (STRAP)
```

**⚠️ CRITICAL:**
- Module Graph ใช้ `same_token` mode เท่านั้น
- ไม่มี `fork` mode สำหรับ Module Graph
- Component Token เดินผ่าน module แล้วกลับมา product graph

### 4.2 ❌ NO `fork` Mode for Module Graph

**Rule:** Module Graph **ไม่ใช้** `fork` mode

**Reasons:**
- Module Graph = Template สำหรับ Component Token
- Component Token เดินเข้า–ออก module (same token)
- ไม่ต้อง spawn child tokens inside module
- `fork` mode = เหลือไว้สำหรับ future use cases อื่น (ถ้ามี)

**❌ Anti-pattern:**
```
Module Graph with fork mode:
   ENTRY → SPLIT → [TASK_1, TASK_2] → JOIN → EXIT
```

**✅ Correct:**
- Use Native Parallel Split in Product Graph (if need parallel)
- Module Graph = Sequential template only

---

## 5. Parallel Component Flow with Module Graph

### 5.1 Complete Example: Diagonal Bag with Module Templates

**Product Graph: "Diagonal Bag Production"**
```
CUT → PARALLEL_SPLIT → [BODY_BRANCH, FLAP_BRANCH, STRAP_BRANCH] → MERGE → ASSEMBLY → PACK

BODY_BRANCH:
   → SUBGRAPH(BODY_MODULE)

FLAP_BRANCH:
   → SUBGRAPH(FLAP_MODULE)

STRAP_BRANCH:
   → SUBGRAPH(STRAP_MODULE)
```

**Module Graphs:**
```
BODY_MODULE (graph_type='module'):
   ENTRY → STITCH_BODY → EDGE_BODY → QC_BODY → EXIT

FLAP_MODULE (graph_type='module'):
   ENTRY → STITCH_FLAP → QC_FLAP → EXIT

STRAP_MODULE (graph_type='module'):
   ENTRY → STITCH_STRAP → EDGE_STRAP → QC_STRAP → EXIT
```

### 5.2 Token Flow

**Step 1: Job Creation**
- Create Final Token F001 (serial = MA01-HAT-DIAG-20251201-00001-A7F3-X)
- Create Job Tray #1 (id_final_token = F001)

**Step 2: CUT Node**
- Final Token F001 at CUT node
- Worker cuts materials
- Final Token F001 completes CUT → moves to PARALLEL_SPLIT

**Step 3: Parallel Split**
- Final Token F001 reaches PARALLEL_SPLIT (is_parallel_split=1)
- Create Component Tokens:
  - Component Token #1 (BODY, parent_token_id=F001)
  - Component Token #2 (FLAP, parent_token_id=F001)
  - Component Token #3 (STRAP, parent_token_id=F001)
- Final Token F001: status='waiting' (waits for components)

**Step 4: Component Tokens Enter Module Graphs**

**BODY Token → BODY_MODULE:**
```
Component Token #1 (BODY) enters SUBGRAPH(BODY_MODULE):
  → Create module instance (parent_instance_id = Product instance)
  → Component Token moves to BODY_MODULE.ENTRY
  → Execute: STITCH_BODY → EDGE_BODY → QC_BODY
  → Component Token reaches BODY_MODULE.EXIT
  → Component Token exits module → moves to MERGE
```

**FLAP Token → FLAP_MODULE:**
```
Component Token #2 (FLAP) enters SUBGRAPH(FLAP_MODULE):
  → Create module instance
  → Execute: STITCH_FLAP → QC_FLAP
  → Component Token exits module → moves to MERGE
```

**STRAP Token → STRAP_MODULE:**
```
Component Token #3 (STRAP) enters SUBGRAPH(STRAP_MODULE):
  → Create module instance
  → Execute: STITCH_STRAP → EDGE_STRAP → QC_STRAP
  → Component Token exits module → moves to MERGE
```

**Step 5: Merge (Assembly)**
- All component tokens arrive at MERGE node
- Re-activate Final Token F001
- Aggregate component times
- Component Tokens: status='merged'

**Step 6: Assembly**
- Final Token F001 at ASSEMBLY node
- Worker assembles using Tray F001 (all components in one tray)
- Final Token F001 completes ASSEMBLY → moves to PACK

---

## 2. Graph Type Classification

### 2.1 Database Schema (NEW)

```sql
ALTER TABLE routing_graph
    ADD COLUMN graph_type ENUM('product', 'module') NOT NULL DEFAULT 'product' 
        COMMENT 'product=Product Graph, module=Module Template',
    ADD COLUMN is_reusable_template TINYINT(1) NOT NULL DEFAULT 0 
        COMMENT 'Flag: This graph is a reusable template',
    ADD KEY idx_graph_type (graph_type);
```

### 2.2 Graph Type Rules

**Product Graph:**
- `graph_type = 'product'`
- `is_reusable_template = 0`
- CAN reference Module Graph (via Subgraph node)
- CANNOT reference Product Graph (ห้ามอ้าง product อื่น)

**Module Graph:**
- `graph_type = 'module'`
- `is_reusable_template = 1`
- CAN reference Module Graph (nested modules)
- CANNOT reference Product Graph (ห้ามอ้าง product)

### 2.3 Validation Rules

**1. Subgraph Reference Validation:**
```php
// In DAGValidationService::validateSubgraphNodes()
$node = fetchNode($nodeId);
$subgraphRef = json_decode($node['subgraph_ref'], true);
$subgraphId = $subgraphRef['graph_id'];
$subgraph = fetchGraph($subgraphId);

// Check: Product Graph cannot reference Product Graph
$parentGraph = fetchGraph($parentGraphId);
if ($parentGraph['graph_type'] === 'product' && $subgraph['graph_type'] === 'product') {
    throw new Exception('Product Graph cannot reference another Product Graph');
}

// Rule: Can only reference Module Graph
if ($subgraph['graph_type'] !== 'module') {
    throw new Exception('Subgraph must be a Module Graph');
}
```

**2. Module Graph Validation:**
```php
// Module Graph must have ENTRY and EXIT nodes
$entryNode = findNodeByType($subgraphId, 'start');
$exitNode = findNodeByType($subgraphId, 'end');

if (!$entryNode || !$exitNode) {
    throw new Exception('Module Graph must have ENTRY (start) and EXIT (end) nodes');
}
```

---

## 3. Component Token + Module Graph Mapping

### 3.1 Mapping Rule: Component → Module

**Rule:** Component Token เดินใน Module Graph ที่ตรงกับ `component_code`

**Mapping Strategy:**

**Option 1: Explicit Mapping (Recommended)**
```sql
-- In Product Graph
routing_node (PARALLEL_SPLIT):
  - Outgoing Edge 1 → SUBGRAPH(BODY_MODULE) (produces_component='BODY')
  - Outgoing Edge 2 → SUBGRAPH(FLAP_MODULE) (produces_component='FLAP')
  - Outgoing Edge 3 → SUBGRAPH(STRAP_MODULE) (produces_component='STRAP')
```

**Option 2: Convention-Based Mapping**
```php
// Module Graph naming convention: {COMPONENT_CODE}_MODULE
$moduleGraph = findModuleGraph("{$componentCode}_MODULE");

// Example:
// Component STRAP → STRAP_MODULE
// Component BODY → BODY_MODULE
```

**Recommended:** Option 1 (Explicit Mapping) - More flexible and clear

### 3.2 Implementation Logic

**When Component Token Reaches Subgraph Node:**
```php
// In DAGRoutingService::handleSubgraphNode()
$token = fetchToken($tokenId);
$node = fetchNode($nodeId);

// Check if token is component token
if ($token['token_type'] === 'component') {
    $componentCode = $token['component_code'];
    
    // Validate: Module Graph produces this component
    $moduleGraph = fetchGraph($node['subgraph_ref']['graph_id']);
    $moduleProducesComponent = $moduleGraph['produces_component'] ?? null;
    
    if ($moduleProducesComponent !== $componentCode) {
        throw new Exception("Module '{$moduleGraph['name']}' does not produce component '{$componentCode}'");
    }
}

// Enter module
enterSubgraph($tokenId, $node['subgraph_ref']);
```

---

## 4. Module Graph as "Component Process Template"

### 4.1 Module Graph = Reusable Process

**Concept:** Module Graph ใช้เป็น "สูตรทำชิ้นส่วน" ที่ใช้ซ้ำได้

**Example: STRAP_MODULE**
```
STRAP_MODULE (version 1.0):
   ENTRY → STITCH_STRAP → EDGE_STRAP → QC_STRAP → EXIT

Used by:
  - Diagonal Bag → STRAP component
  - Tote Bag → STRAP component
  - Crossbody Bag → STRAP component
```

**Benefits:**
- ✅ Reusable across multiple products
- ✅ Version-controlled (process improvement)
- ✅ Consistent process (same module = same quality)

### 4.2 Module Graph Versioning

**Concept:** Module Graph มี version เหมือน Product Graph

**Example:**
```
STRAP_MODULE version 1.0:
   ENTRY → STITCH_STRAP → EDGE_STRAP → QC_STRAP → EXIT

STRAP_MODULE version 2.0 (improved process):
   ENTRY → STITCH_STRAP → SKIVE_STRAP → EDGE_STRAP → QC_STRAP → EXIT
```

**Impact:**
- Products using STRAP_MODULE v1.0 → Continue using v1.0 (version pinned)
- New products → Use STRAP_MODULE v2.0 (new process)
- Existing instances → Not affected by new version

---

## 5. Subgraph Behavior (Current Implementation)

### 5.1 Current Implementation Status

**✅ Same Token Mode - COMPLETE:**
- Token enters subgraph node
- Token moves to subgraph.entry_node_id
- Token executes subgraph nodes
- Token reaches subgraph.exit_node_id
- Token exits subgraph → moves to next node in parent graph

**Code Reference:** `source/BGERP/Service/DAGRoutingService.php` - `handleSubgraphNode()` method

**Status:** ✅ **WORKING** (ให้ถือว่าเป็น implementation ถูกต้อง)

### 5.2 Subgraph Does NOT Create Final Token

**⚠️ CRITICAL RULE:** Subgraph (Module Graph) **ไม่สร้าง Final Token**

**Correct Behavior:**
- Component Token enters Module Graph
- Component Token executes module nodes (same token)
- Component Token exits Module Graph (same token)
- **No new Final Token created**

**Database:**
```sql
-- Component Token before entering module
flow_token:
  - id_token = 101
  - token_type = 'component'
  - parent_token_id = 100 (Final Token)
  - serial_number = NULL (or component serial if needed)

-- Component Token after exiting module
flow_token:
  - id_token = 101 (SAME TOKEN)
  - token_type = 'component' (SAME TYPE)
  - parent_token_id = 100 (SAME PARENT)
  - serial_number = NULL (or component serial)
```

**Anti-pattern:**
```php
// ❌ WRONG - Creating new token in module
function handleSubgraphNode($tokenId, $nodeId) {
    $newTokenId = createToken(...); // ❌ NO!
}

// ✅ CORRECT - Same token continues
function handleSubgraphNode($tokenId, $nodeId) {
    moveToken($tokenId, $entryNodeId); // ✅ YES!
}
```

### 5.3 Subgraph is NOT Product

**⚠️ CRITICAL RULE:** Module Graph (Subgraph) **ไม่ใช่ Product เอง**

**Correct Understanding:**
- Module Graph = Process template
- Module Graph = Component/step ย่อย
- Module Graph ≠ Product
- Module Graph ≠ Final product

**Example:**
```
❌ WRONG: Module Graph as Product
STRAP_MODULE = "กระเป๋าสายแบบหนึ่ง"

✅ CORRECT: Module Graph as Template
STRAP_MODULE = "สูตรทำสายกระเป๋า" (ใช้ได้กับหลายแบบ)
```

---

## 6. Migration Path: OLD → NEW Concept

### 6.1 Current State (OLD Concept)

**Current Subgraph Usage:**
- ⚠️ May reference Product Graph (wrong)
- ⚠️ May not distinguish Product vs Module
- ⚠️ No `graph_type` classification

**Current Implementation:**
- ✅ `same_token` mode works correctly
- ⏳ `fork` mode not implemented (stub only)

### 6.2 Required Changes (NEW Concept)

**1. Add Graph Type Classification:**
```sql
-- Migration required
ALTER TABLE routing_graph
    ADD COLUMN graph_type ENUM('product', 'module') NOT NULL DEFAULT 'product',
    ADD COLUMN is_reusable_template TINYINT(1) NOT NULL DEFAULT 0,
    ADD KEY idx_graph_type (graph_type);
```

**2. Add Validation Rules:**
```php
// In DAGValidationService::validateSubgraphNodes()
// Rule 1: Product cannot reference Product
// Rule 2: Can only reference Module Graph
// Rule 3: Module Graph must have ENTRY/EXIT
```

**3. Update Existing Graphs:**
```sql
-- Mark existing module-like graphs as 'module'
UPDATE routing_graph 
SET graph_type = 'module', is_reusable_template = 1
WHERE name LIKE '%MODULE%' OR name LIKE '%TEMPLATE%';

-- Verify no product-to-product references
SELECT * FROM graph_subgraph_binding gsb
INNER JOIN routing_graph parent ON parent.id_graph = gsb.parent_graph_id
INNER JOIN routing_graph sub ON sub.id_graph = gsb.subgraph_id
WHERE parent.graph_type = 'product' AND sub.graph_type = 'product';
```

---

## 7. Validation Rules Summary

### 7.1 Graph Type Validation

| Parent Graph Type | Can Reference | Cannot Reference |
|------------------|---------------|------------------|
| Product | ✅ Module Graph | ❌ Product Graph |
| Module | ✅ Module Graph | ❌ Product Graph |

### 7.2 Module Graph Requirements

**Required:**
- ✅ Must have ENTRY node (start node)
- ✅ Must have EXIT node (end node)
- ✅ Must use `same_token` mode (no fork)
- ✅ Must be marked as `graph_type='module'`
- ✅ Must be version-controlled

**Optional:**
- May have parallel branches inside (using is_parallel_split)
- May reference other Module Graphs (nested modules)

### 7.3 Component Token + Module Validation

**Required:**
- ✅ Component Token must have `parent_token_id`
- ✅ Module Graph must produce component matching `component_code`
- ✅ Component Token enters module as same token
- ✅ Component Token exits module as same token
- ✅ No new Final Token created in module

---

## 8. Implementation Checklist

### 8.1 Database Schema

- [ ] Add `graph_type` to `routing_graph`
- [ ] Add `is_reusable_template` to `routing_graph`
- [ ] Add `produces_component` to `routing_graph` (module graph level)
- [ ] Add validation index: `idx_graph_type`

### 8.2 Validation Rules

- [ ] Validate: Product cannot reference Product
- [ ] Validate: Subgraph must be Module Graph
- [ ] Validate: Module must have ENTRY/EXIT
- [ ] Validate: Module produces matching component (if component token)

### 8.3 Graph Designer UI

- [ ] Show graph type indicator (Product / Module)
- [ ] Filter: Subgraph selector shows Module Graphs only
- [ ] Validate: Prevent Product-to-Product reference
- [ ] UI: Mark Module Graphs with icon/badge

### 8.4 Documentation

- [ ] Update Subgraph documentation (new concept)
- [ ] Add examples: Component + Module Graph
- [ ] Document migration path (OLD → NEW)
- [ ] Update validation rules

---

## 9. Anti-Patterns (ข้อห้าม)

### 9.1 ❌ DO NOT Reference Product Graph from Product Graph

**Rule:** Product Graph ห้ามอ้างอิง Product Graph อื่น

**Example:**
```
❌ WRONG:
Product Graph: "Diagonal Bag V2"
   CUT → SUBGRAPH(DIAGONAL_BAG_V1) → ASSEMBLY
```

**Why Wrong:**
- เหมือนเอากราฟของกระเป๋าอีกแบบมาปนกัน
- โครงสร้างมั่ว (product inside product)
- ไม่ชัดว่า Final Token ของใคร

### 9.2 ❌ DO NOT Use `fork` Mode for Module Graph

**Rule:** Module Graph ใช้ `same_token` mode เท่านั้น (ไม่ใช้ fork)

**Reason:**
- Module = Template สำหรับ Component Token
- Component Token เดินผ่าน module (same token)
- ไม่ต้อง spawn child tokens inside module

### 9.3 ❌ DO NOT Create Final Token in Module Graph

**Rule:** Module Graph ไม่สร้าง Final Token

**Correct Behavior:**
- Component Token enters module (same token)
- Component Token executes module nodes (same token)
- Component Token exits module (same token)
- **No new token created**

### 9.4 ❌ DO NOT Treat Module Graph as Product

**Rule:** Module Graph ≠ Product

**Correct Understanding:**
- Module Graph = Process template
- Module Graph = Component/step ย่อย
- Module Graph ≠ Complete product

---

## 10. Summary: NEW Subgraph Concept

### 10.1 Key Concepts

1. **Graph Classification:**
   - Product Graph = กราฟหลักของกระเป๋า 1 แบบ
   - Module Graph = Template ของ Component/Step ย่อย

2. **Reference Rules:**
   - Product → Module ✅
   - Product → Product ❌
   - Module → Module ✅
   - Module → Product ❌

3. **Execution Mode:**
   - Module Graph = `same_token` mode only
   - No `fork` mode for Module Graph

4. **Component Integration:**
   - Component Token เดินใน Module Graph
   - Module Graph = "สูตรทำชิ้นส่วน"
   - Component Token ยังผูกกับ Final Token (parent_token_id)

5. **Physical Reality:**
   - Component Token อยู่ในถาด F001 (ไม่เปลี่ยน)
   - Module Graph = Digital process template
   - Physical tray = Digital parent_token_id

### 10.2 Critical Rules

- ✅ Module Graph = Template (not Product)
- ✅ Component Token = Same token throughout module
- ✅ No Final Token created in module
- ✅ Product cannot reference Product
- ✅ Module uses `same_token` mode only
- ❌ No fork mode for Module Graph
- ❌ No Product Graph reference from Subgraph
- ❌ No new token created in module

---

**Last Updated:** 2025-01-XX  
**Version:** 2.0 (Conceptual Redesign)  
**Status:** Active Concept Document  
**Maintained By:** Development Team

**See Also:**
- `COMPONENT_PARALLEL_FLOW_CONCEPT.md` - Component Token concept flow
- `SUBGRAPH_VS_COMPONENT_CONCEPT_AUDIT.md` - Subgraph vs Component comparison


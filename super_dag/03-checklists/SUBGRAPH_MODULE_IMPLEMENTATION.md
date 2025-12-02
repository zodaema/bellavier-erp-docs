# Subgraph Module Template - Implementation Checklist

**Date:** 2025-01-XX  
**Purpose:** Implementation checklist for new Subgraph = Module Template concept  
**Version:** 1.0

**⚠️ CRITICAL:** This checklist implements the NEW Subgraph concept (Module Template)

---

## Executive Summary

**Concept Change:**
- OLD: Subgraph = อ้าง Graph อื่น (Product Graph) มาใส่ → โครงสร้างมั่ว
- NEW: Subgraph = Module Graph (Template) สำหรับ Component/Step ย่อย → โครงสร้างชัด

**Impact:**
- Product Graph อ้างได้เฉพาะ Module Graph (ห้ามอ้าง Product)
- Module Graph = Reusable Template (ใช้ซ้ำได้หลาย Product)
- Component Token เดินใน Module Graph (same token)

---

## Priority 1: Database Schema (BLOCKER)

### 1.1 Add Graph Type Classification

**Migration Required:**
```sql
-- Add to routing_graph table
ALTER TABLE routing_graph
    ADD COLUMN graph_type ENUM('product', 'module') NOT NULL DEFAULT 'product' 
        COMMENT 'product=Product Graph, module=Module Template',
    ADD COLUMN is_reusable_template TINYINT(1) NOT NULL DEFAULT 0 
        COMMENT 'Flag: This graph is a reusable template (module)',
    ADD KEY idx_graph_type (graph_type);
```

**Status:** ❌ **NOT IMPLEMENTED**

**File to Create:** `database/tenant_migrations/2025_12_graph_type_classification.php`

### 1.2 Add Module-Level Component Metadata

**Migration Required:**
```sql
-- Add to routing_graph table (for Module Graph)
ALTER TABLE routing_graph
    ADD COLUMN produces_component VARCHAR(64) NULL 
        COMMENT 'Component code this module produces (for Module Graph only)',
    ADD COLUMN consumes_components JSON NULL 
        COMMENT 'Component codes this module consumes (for Module Graph only)',
    ADD KEY idx_produces_component (produces_component);
```

**Status:** ❌ **NOT IMPLEMENTED**

**File to Create:** `database/tenant_migrations/2025_12_module_component_metadata.php`

---

## Priority 2: Validation Rules (BLOCKER)

### 2.1 Validate: Product Cannot Reference Product

**Rule:** Product Graph ห้ามอ้างอิง Product Graph อื่น

**Implementation:**
```php
// In DAGValidationService::validateSubgraphNodes()
$parentGraph = $this->fetchGraph($parentGraphId);
$subgraph = $this->fetchGraph($subgraphId);

// Check: Product cannot reference Product
if ($parentGraph['graph_type'] === 'product' && $subgraph['graph_type'] === 'product') {
    $errors[] = [
        'node' => $node['node_code'],
        'rule' => 'subgraph_product_reference',
        'message' => 'Product Graph cannot reference another Product Graph. Use Module Graph instead.',
        'severity' => 'error'
    ];
}
```

**Status:** ❌ **NOT IMPLEMENTED**

**File to Update:** `source/BGERP/Service/DAGValidationService.php`

### 2.2 Validate: Subgraph Must Be Module Graph

**Rule:** Subgraph node สามารถอ้างได้เฉพาะ Module Graph เท่านั้น

**Implementation:**
```php
// In DAGValidationService::validateSubgraphNodes()
$subgraph = $this->fetchGraph($subgraphId);

// Check: Subgraph must be Module Graph
if ($subgraph['graph_type'] !== 'module') {
    $errors[] = [
        'node' => $node['node_code'],
        'rule' => 'subgraph_not_module',
        'message' => "Subgraph '{$subgraph['name']}' is not a Module Graph (graph_type must be 'module')",
        'severity' => 'error'
    ];
}
```

**Status:** ❌ **NOT IMPLEMENTED**

**File to Update:** `source/BGERP/Service/DAGValidationService.php`

### 2.3 Validate: Module Graph Must Have ENTRY/EXIT

**Rule:** Module Graph ต้องมี ENTRY (start) และ EXIT (end) nodes

**Implementation:**
```php
// In DAGValidationService::validateModuleGraph()
$entryNode = $this->findNodeByType($moduleGraphId, 'start');
$exitNode = $this->findNodeByType($moduleGraphId, 'end');

if (!$entryNode) {
    $errors[] = "Module Graph must have ENTRY node (node_type='start')";
}

if (!$exitNode) {
    $errors[] = "Module Graph must have EXIT node (node_type='end')";
}
```

**Status:** 🚧 **PARTIAL** (validation exists, but not enforced for Module Graph type)

**File to Update:** `source/BGERP/Service/DAGValidationService.php`

---

## Priority 3: Graph Designer UI (BLOCKER)

### 3.1 Graph Type Selector

**UI Required:**
- Graph creation wizard shows "Product Graph" or "Module Graph" option
- Graph type cannot be changed after creation (immutable)

**Implementation:**
```javascript
// In graph_designer.js
function showCreateGraphDialog() {
    Swal.fire({
        title: 'Create New Graph',
        html: `
            <div class="form-group">
                <label>Graph Type</label>
                <select id="graph_type" class="form-select">
                    <option value="product">Product Graph (กราฟหลักของสินค้า)</option>
                    <option value="module">Module Graph (Template ของ Component/Step)</option>
                </select>
            </div>
            <div class="form-group">
                <label>Graph Name</label>
                <input type="text" id="graph_name" class="form-control">
            </div>
        `,
        // ...
    });
}
```

**Status:** ❌ **NOT IMPLEMENTED**

**File to Update:** `assets/javascripts/dag/graph_designer.js`

### 3.2 Subgraph Selector Filter

**UI Required:**
- Subgraph selector shows **Module Graphs only** (filter out Product Graphs)
- Show graph type badge (Product / Module)

**Implementation:**
```javascript
// In graph_designer.js - showSubgraphSelector()
function showSubgraphSelector(nodeId) {
    // Fetch Module Graphs only
    $.post('source/dag_routing_api.php', {
        action: 'list_module_graphs'  // NEW action
    }, function(resp) {
        if (resp.ok) {
            // Show Module Graphs in selector
            renderModuleGraphList(resp.data);
        }
    });
}
```

**Status:** ❌ **NOT IMPLEMENTED**

**File to Update:** `assets/javascripts/dag/graph_designer.js`

### 3.3 Graph Type Badge/Indicator

**UI Required:**
- Graph list shows graph type badge (🏭 Product / 📦 Module)
- Graph canvas shows graph type indicator

**Status:** ❌ **NOT IMPLEMENTED**

**File to Update:** `assets/javascripts/dag/graph_designer.js`

---

## Priority 4: API Updates (REQUIRED)

### 4.1 Create `list_module_graphs` Action

**API Required:**
```php
// In dag_routing_api.php
case 'list_module_graphs':
    $stmt = $db->prepare("
        SELECT id_graph, code, name, graph_type, version, status
        FROM routing_graph
        WHERE graph_type = 'module'
        AND deleted_at IS NULL
        ORDER BY name ASC
    ");
    $stmt->execute();
    $moduleGraphs = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    
    json_success(['data' => $moduleGraphs]);
    return;
```

**Status:** ❌ **NOT IMPLEMENTED**

**File to Update:** `source/dag_routing_api.php`

### 4.2 Update `graph_save` to Set Graph Type

**API Required:**
```php
// In dag_routing_api.php - graph_save action
$graphType = $_POST['graph_type'] ?? 'product';

// Validate graph_type
if (!in_array($graphType, ['product', 'module'], true)) {
    json_error('Invalid graph_type', 400);
}

// Insert/Update with graph_type
$stmt = $db->prepare("
    INSERT INTO routing_graph (code, name, graph_type, is_reusable_template, ...)
    VALUES (?, ?, ?, ?, ...)
    ON DUPLICATE KEY UPDATE graph_type = ?, ...
");
```

**Status:** ❌ **NOT IMPLEMENTED**

**File to Update:** `source/dag_routing_api.php`

### 4.3 Update Subgraph Validation

**API Required:**
```php
// In DAGValidationService::validateSubgraphNodes()
// Add: Product cannot reference Product
// Add: Subgraph must be Module Graph
```

**Status:** ❌ **NOT IMPLEMENTED**

**File to Update:** `source/BGERP/Service/DAGValidationService.php`

---

## Priority 5: Current Implementation Alignment

### 5.1 Current Subgraph Implementation

**Status:** ✅ **KEEP AS-IS** (ให้ถือว่าเป็น implementation ถูกต้อง)

**Current Behavior:**
- Token enters subgraph node
- Token moves to subgraph.entry_node_id (same token)
- Token executes subgraph nodes
- Token exits subgraph.exit_node_id (same token)
- Token moves to next node in parent graph

**✅ This is CORRECT for Module Graph concept**

**No Changes Required:**
- ✅ `DAGRoutingService::handleSubgraphNode()` - Works correctly
- ✅ `same_token` mode - Correct implementation
- ✅ No Final Token created in subgraph - Correct

### 5.2 Remove `fork` Mode (Future)

**Rule:** Module Graph **ไม่ใช้** `fork` mode

**Current State:**
- ⏳ `fork` mode not implemented (stub only)

**Action:**
- ✅ Keep stub as-is (ไม่ต้อง implement fork mode for Module Graph)
- 📋 Remove stub in future (if needed)
- 📋 Document: fork mode ไม่ใช้สำหรับ Module Graph

**Status:** ✅ **NO ACTION REQUIRED** (stub can stay)

---

## Priority 6: Documentation Updates

### 6.1 Update Roadmap

**File:** `docs/dag/01-roadmap/DAG_IMPLEMENTATION_ROADMAP.md`

**Updates Required:**
- Update Phase 1.7: Subgraph = Module Template (not Product reference)
- Update examples: Show Module Graph usage
- Remove Product-to-Product reference examples

**Status:** ❌ **NOT UPDATED**

### 6.2 Update Subgraph Governance Audit

**File:** `docs/dag/02-implementation-status/FULL_SUBGRAPH_GOVERNANCE_AUDIT.md`

**Updates Required:**
- Add: Graph type classification requirement
- Add: Product-to-Product reference prevention
- Update validation rules

**Status:** ❌ **NOT UPDATED**

---

## Implementation Summary

### Phase 1: Database Schema (1-2 hours)

- [ ] Create migration: `2025_12_graph_type_classification.php`
  - Add `graph_type` to `routing_graph`
  - Add `is_reusable_template` to `routing_graph`

- [ ] Create migration: `2025_12_module_component_metadata.php`
  - Add `produces_component` to `routing_graph`
  - Add `consumes_components` to `routing_graph`

- [ ] Run migrations on all tenants

### Phase 2: Validation Rules (2-3 hours)

- [ ] Update `DAGValidationService::validateSubgraphNodes()`
  - Add: Product cannot reference Product
  - Add: Subgraph must be Module Graph

- [ ] Create `DAGValidationService::validateModuleGraph()`
  - Validate: Module must have ENTRY/EXIT
  - Validate: Module produces matching component

- [ ] Write tests for validation rules

### Phase 3: API Updates (2-3 hours)

- [ ] Create `list_module_graphs` action in `dag_routing_api.php`
- [ ] Update `graph_save` action to accept `graph_type`
- [ ] Update `graph_create` action to set `graph_type`
- [ ] Test API endpoints

### Phase 4: Graph Designer UI (3-4 hours)

- [ ] Add graph type selector in create dialog
- [ ] Filter subgraph selector to Module Graphs only
- [ ] Show graph type badge/indicator
- [ ] Update graph list to show graph type
- [ ] Test UI workflow

### Phase 5: Documentation (1-2 hours)

- [ ] Update roadmap with new concept
- [ ] Update audit documents
- [ ] Create user guide for Module Graph
- [ ] Update examples

### Phase 6: Data Migration (1-2 hours)

- [ ] Identify existing graphs that should be Module type
- [ ] Update graph_type for existing graphs
- [ ] Verify no Product-to-Product references exist
- [ ] Test existing subgraph references still work

**Total Estimated Time:** 10-16 hours

---

## Validation Checklist

**After Implementation:**

- [ ] All Product Graphs have `graph_type='product'`
- [ ] All Module Graphs have `graph_type='module'`
- [ ] No Product-to-Product references exist
- [ ] All Subgraph nodes reference Module Graphs only
- [ ] Module Graphs have ENTRY/EXIT nodes
- [ ] Existing subgraph instances still work
- [ ] Graph Designer UI shows graph type
- [ ] Subgraph selector filters Module Graphs only
- [ ] Tests pass (validation, API, integration)

---

## Current Implementation Status

**✅ What Works (Keep As-Is):**
- `same_token` mode implementation (correct)
- Subgraph instance creation
- Token enter/exit subgraph
- Version pinning
- Subgraph governance (versioning, delete protection)

**❌ What's Missing (Need to Implement):**
- Graph type classification (`graph_type` column)
- Product-to-Product reference prevention
- Module Graph validation
- Graph Designer UI updates
- API updates (`list_module_graphs`, graph type handling)

**⚠️ What to Change (Conceptual Alignment):**
- Documentation: Subgraph = Module Template (not Product reference)
- Examples: Show Module Graph usage
- Validation: Prevent Product-to-Product reference

---

**Last Updated:** 2025-01-XX  
**Status:** Implementation Checklist Ready  
**Next:** Implement Priority 1 (Database Schema)


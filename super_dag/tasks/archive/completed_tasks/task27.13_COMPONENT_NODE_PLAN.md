# 27.13 Component Node Type (Anchor Model) - Implementation Plan

> **Feature:** Component Anchor Nodes for Parallel Flow  
> **Priority:** 🔴 CRITICAL (Required for QC Rework + MCI)  
> **Estimated Duration:** 4 Days (~31 hours)  
> **Dependencies:** 27.12 Component Catalog  
> **Spec:** `01-concepts/QC_REWORK_PHILOSOPHY_V2.md`  
> **Policy Reference:** `docs/developer/01-policy/DEVELOPER_POLICY.md`

---

## 📐 Enterprise Compliance Notes

**Per DEVELOPER_POLICY.md v1.6, all APIs MUST include:**
- ✅ `TenantApiBootstrap::init()` → `$db->getTenantDb()` pattern
- ✅ `TenantApiOutput::startOutputBuffer()` at start
- ✅ `RateLimiter::check($member, 120, 60, 'endpoint')` - void, no return check
- ✅ `must_allow_code($member, 'permission.code')` for permission
- ✅ `RequestValidator::make()` for input validation
- ✅ Maintenance mode check (`storage/maintenance.flag`)
- ✅ Execution time tracking (`$__t0 = microtime(true)`)
- ✅ `X-AI-Trace` header with `execution_ms`
- ✅ `json_success()` / `json_error()` only (never echo json_encode)
- ✅ i18n: `translate('key', 'English default')` for user-facing text
- ✅ PSR-4 autoload: `use BGERP\...` (no require_once for BGERP classes)
- ✅ After adding new service class: `composer dump-autoload -o`

**Per SYSTEM_WIRING_GUIDE.md:**
- Service location: `BGERP\Service\ComponentMappingService` (domain service, not DAG-specific)
- DAG traversal: `BGERP\Dag\DAGRoutingService` (DAG-specific)
- Permission code format: `component.node.view`, `component.node.manage`

---

## 🔧 Implementation Notes (READ BEFORE CODING!)

### ⚠️ 1. ENUM Migration: EXTEND, don't REPLACE

```php
// ❌ WRONG - Will lose existing values!
ALTER TABLE routing_node MODIFY node_type ENUM('start','operation','split','join','decision','end','component','router');

// ✅ CORRECT - Read current ENUM, then append new values
// Step 1: SHOW COLUMNS FROM routing_node LIKE 'node_type';
// Step 2: Parse existing ENUM values
// Step 3: If 'component' not in list, append it
// Step 4: If 'router' not in list, append it
```

**Spec says:** "ต้องมีค่าเพิ่ม 2 ตัว: `component`, `router`"
**Don't:** Hard-code ลิสต์ ENUM ใหม่ทั้งชุด

---

### ⚠️ 2. Index Migration: CHECK before CREATE

```php
// ✅ CORRECT - Check if index exists first
if (!migration_index_exists($db, 'routing_node', 'idx_anchor_slot')) {
    $db->query("ALTER TABLE routing_node ADD INDEX idx_anchor_slot (anchor_slot)");
}

// Or handle duplicate key error gracefully
try {
    $db->query("ALTER TABLE routing_node ADD INDEX idx_anchor_slot (anchor_slot)");
} catch (\mysqli_sql_exception $e) {
    if (strpos($e->getMessage(), 'Duplicate key name') === false) {
        throw $e; // Re-throw if not duplicate
    }
    // Duplicate index is OK - already exists
}
```

---

### ⚠️ 3. Column Names: VERIFY against actual schema

**Before implementing `DAGRoutingService` methods, verify:**

```php
// Check actual column names in routing_node / routing_edge
// Spec uses: id_node, source_node_id, target_node_id
// Reality might be: id_routing_node, from_node_id, to_node_id

// Run this to check:
DESCRIBE routing_node;
DESCRIBE routing_edge;
```

**Logic is correct** (BFS upstream/downstream + visited set), just match column names.

---

### ⚠️ 4. Duplicate Key Handling in setMapping()

```php
// In ComponentMappingService::setMapping()

try {
    $stmt = $db->prepare(
        "INSERT INTO graph_component_mapping (id_graph, anchor_slot, component_code) VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE component_code = VALUES(component_code)"
    );
    // ...
} catch (\mysqli_sql_exception $e) {
    if ($e->getCode() === 1062) { // Duplicate entry
        throw new \InvalidArgumentException(
            translate('component.mapping.duplicate', 'This slot is already mapped in this graph')
        );
    }
    throw $e;
}
```

---

### ⚠️ 5. RequestValidator: REQUIRED in API

```php
// In component_mapping_api.php - ALL handlers MUST use

case 'set_mapping':
    must_allow_code($member, 'component.node.manage');
    
    // ✅ MUST validate input!
    $validation = RequestValidator::make($_POST, [
        'graph_id' => 'required|integer|min:1',
        'anchor_slot' => 'required|string|max:50|regex:/^[A-Z][A-Z0-9_]*$/',
        'component_code' => 'required|string|max:50'
    ]);
    
    if (!$validation['valid']) {
        json_error($validation['errors'][0]['message'] ?? 'validation_failed', 400, [
            'app_code' => 'CM_400_VALIDATION',
            'errors' => $validation['errors']
        ]);
    }
    
    // Then use $validation['data']
    $service->setMapping(...);
    break;
```

---

### ⚠️ 6. Graph-level vs Product-level Mapping

**Clarification:**
- Mapping table is `graph_component_mapping` with `(id_graph, anchor_slot, component_code)`
- This is **graph-level config**, not product-level
- UI shows "Product" → but actually resolves to "which graph does product use"
- Product doesn't have its own mapping - graph does

**Flow:**
1. User selects Product
2. System looks up Product's assigned Graph
3. Mapping UI shows/edits slots for that Graph
4. Mappings saved to `graph_component_mapping` (not product table)

---

### ⚠️ 7. Additional Test Cases to Add

```php
// Add these test cases during implementation:

public function testComponentNodeWithoutAnchorSlotFailsValidation(): void
{
    // Component node missing anchor_slot → graph validation error
}

public function testDuplicateAnchorSlotInSameGraphFails(): void
{
    // Two component nodes with same anchor_slot in one graph → error
}

public function testComponentNodeNotAfterSplitFails(): void
{
    // Component node without parent split → warning (if mustBeAfterSplit enforced)
}
```

---

### 📌 8. mustBeAfterSplit Policy

**Current decision: STRICT (เข้มไว้ก่อน)**

```javascript
validation: {
    canHaveWorkCenter: false,
    canHaveBehavior: false,
    mustBeAfterSplit: true  // ← Enforce parallel component pattern
}
```

**Why strict now:**
- Component branches = parallel flow = must follow split
- Prevents confusion about "what is a component anchor"
- Aligns with Hatthasilpa parallel manufacturing model

**Future relaxation:**
- If needed for simple/linear component (no split), can relax later
- Add flag like `allowLinearComponent: true` in config
- For now: keep strict to prevent misuse

---

## ⚠️ Legacy Deprecation: Rework Node

**IMPORTANT:** The **Rework Node** in Graph Designer is now **LEGACY** and must be removed.

**Why?**
- QC Rework Philosophy V2 uses **Behavior-based rework selection**
- Operator/QC chooses rework target at runtime via UI
- Graph no longer needs explicit rework edges/nodes
- See: `QC_REWORK_PHILOSOPHY_V2.md`

**Action Required:**
- Remove `type: 'rework'` from node palette
- Remove `.node-rework` CSS styling
- Replace with `type: 'component'` (Component Anchor)

---

## 📊 Architecture: Anchor Model

```
┌─────────────────────────────────────────────────────────────────┐
│              ANCHOR MODEL ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Layer 1: GRAPH TEMPLATE (Graph Designer)                       │
│  ├─ node_type = 'component'                                     │
│  ├─ anchor_slot = 'SLOT_A', 'SLOT_B' (placeholder)             │
│  └─ NO catalog selection in Graph Designer!                    │
│                                                                 │
│  Layer 2: PRODUCT CONFIG (Mapping Layer)                        │
│  ├─ graph_component_mapping table                               │
│  └─ slot_mapping: SLOT_A → STRAP_LONG (from catalog)           │
│                                                                 │
│  Layer 3: RUNTIME (Token)                                       │
│  └─ token.metadata.component_code = resolved                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 Implementation Overview

```
┌─────────────────────────────────────────────────────────────────┐
│              COMPONENT NODE: ANCHOR MODEL                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 1: Database Layer                                          │
│  ├─ 27.13.1 Migration: Extend node_type ENUM                   │
│  ├─ 27.13.2 Migration: Add anchor_slot column                  │
│  └─ 27.13.3 Migration: graph_component_mapping table           │
│                                                                 │
│  Day 2: Service Layer                                           │
│  ├─ 27.13.4 Service: findComponentAnchor()                     │
│  ├─ 27.13.5 Service: getNodesInComponent()                     │
│  └─ 27.13.6 Service: resolveComponentCode()                    │
│                                                                 │
│  Day 3: Graph Designer UI                                       │
│  ├─ 27.13.7 Palette: Component Node item                       │
│  ├─ 27.13.8 UI: Anchor slot input (generic)                    │
│  └─ 27.13.9 Styling: Visual for component nodes                │
│                                                                 │
│  Day 4: API + Config + Tests                                    │
│  ├─ 27.13.10 API: Component Mapping endpoints                  │
│  ├─ 27.13.11 Product Config UI: Slot → Code mapping            │
│  ├─ 27.13.11b Material Linking (Component → Material)          │
│  ├─ 27.13.11c Operation Context (Node → Component → Material)  │
│  ├─ 27.13.12 Validation: Component node rules                  │
│  └─ 27.13.13 Tests: Unit + Integration                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 Task Details

---

### 27.13.1 Migration: Extend node_type ENUM

**Duration:** 2 hours

**File:** `database/tenant_migrations/2025_12_component_node_type.php`

```php
<?php
/**
 * Migration: Add 'component' and 'router' to node_type ENUM
 */

return function (mysqli $db): void {
    // Check current ENUM values
    $result = $db->query("SHOW COLUMNS FROM routing_node LIKE 'node_type'");
    $row = $result->fetch_assoc();
    $currentType = $row['Type'] ?? '';
    
    // Skip if already has 'component'
    if (strpos($currentType, 'component') !== false) {
        error_log("[Migration] node_type already has 'component', skipping");
        return;
    }
    
    // Extend ENUM
    $sql = "ALTER TABLE routing_node 
            MODIFY COLUMN node_type 
            ENUM('start','operation','split','join','decision','end','component','router') 
            NOT NULL 
            COMMENT 'Node types: component=anchor for parallel branch, router=conditional routing'";
    
    if (!$db->query($sql)) {
        throw new \RuntimeException("Failed to modify node_type: " . $db->error);
    }
    
    error_log("[Migration] Extended node_type ENUM with 'component' and 'router'");
};
```

**Deliverables:**
- [ ] ENUM includes 'component' and 'router'
- [ ] Existing data preserved
- [ ] Migration is idempotent

---

### 27.13.2 Migration: Add anchor_slot column

**Duration:** 1 hour

**File:** Same as 27.13.1 or separate

```php
// Add anchor_slot column
$sql = "ALTER TABLE routing_node 
        ADD COLUMN anchor_slot VARCHAR(50) NULL 
        COMMENT 'Anchor slot for component nodes (e.g., SLOT_A, SLOT_B)'
        AFTER node_type";

if (!$db->query($sql)) {
    // Check if column exists
    if (strpos($db->error, 'Duplicate column') === false) {
        throw new \RuntimeException("Failed to add anchor_slot: " . $db->error);
    }
}

// Add index
$db->query("ALTER TABLE routing_node ADD INDEX idx_anchor_slot (anchor_slot)");

error_log("[Migration] Added anchor_slot column to routing_node");
```

**Deliverables:**
- [ ] `anchor_slot` column exists
- [ ] Index created
- [ ] NULL allowed (only used for component nodes)

---

### 27.13.3 Migration: graph_component_mapping table

**Duration:** 2 hours

**File:** `database/tenant_migrations/2025_12_graph_component_mapping.php`

```sql
CREATE TABLE graph_component_mapping (
    id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- References
    graph_id INT NOT NULL 
        COMMENT 'FK to routing_graph',
    anchor_slot VARCHAR(50) NOT NULL 
        COMMENT 'Slot name from routing_node.anchor_slot',
    component_code VARCHAR(50) NOT NULL 
        COMMENT 'FK to component_catalog',
    
    -- Audit
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT NULL,
    
    -- Constraints
    UNIQUE KEY uk_graph_slot (graph_id, anchor_slot),
    INDEX idx_graph (graph_id),
    INDEX idx_component (component_code),
    
    FOREIGN KEY (graph_id) 
        REFERENCES routing_graph(id_graph) 
        ON DELETE CASCADE,
    FOREIGN KEY (component_code) 
        REFERENCES component_catalog(component_code) 
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 
  COMMENT='Maps graph anchor slots to component codes';
```

**Deliverables:**
- [ ] Table created
- [ ] FK to routing_graph works
- [ ] FK to component_catalog works
- [ ] Unique constraint on (graph_id, anchor_slot)

---

### 27.13.4 Service: findComponentAnchor()

**Duration:** 3 hours

**File:** `source/BGERP/Service/DAGRoutingService.php` (extend)

```php
/**
 * Find the nearest component anchor node upstream from given node
 * 
 * @param int $nodeId Current node ID
 * @return array|null Component anchor node or null if not in component branch
 */
public function findComponentAnchor(int $nodeId): ?array
{
    // BFS backwards to find component node
    $visited = [];
    $queue = [$nodeId];
    
    while (!empty($queue)) {
        $currentId = array_shift($queue);
        
        if (isset($visited[$currentId])) {
            continue;
        }
        $visited[$currentId] = true;
        
        // Get node
        $node = $this->getNode($currentId);
        if (!$node) {
            continue;
        }
        
        // Found component anchor!
        if ($node['node_type'] === 'component') {
            return $node;
        }
        
        // Add upstream nodes to queue
        $upstreamEdges = $this->getIncomingEdges($currentId);
        foreach ($upstreamEdges as $edge) {
            $queue[] = $edge['source_node_id'];
        }
    }
    
    return null; // Not in a component branch
}
```

**Deliverables:**
- [ ] BFS algorithm implemented
- [ ] Handles cycles (visited check)
- [ ] Returns null for non-component branches
- [ ] Unit tested

---

### 27.13.5 Service: getNodesInComponent()

**Duration:** 3 hours

**File:** `source/BGERP/Service/DAGRoutingService.php` (extend)

```php
/**
 * Get all operation nodes within a component branch
 * Used for QC rework target selection
 * 
 * @param array $anchorNode Component anchor node
 * @return array List of operation nodes
 */
public function getNodesInComponent(array $anchorNode): array
{
    if ($anchorNode['node_type'] !== 'component') {
        return [];
    }
    
    $nodes = [];
    $visited = [];
    $queue = [$anchorNode['id_node']];
    
    while (!empty($queue)) {
        $currentId = array_shift($queue);
        
        if (isset($visited[$currentId])) {
            continue;
        }
        $visited[$currentId] = true;
        
        $node = $this->getNode($currentId);
        if (!$node) {
            continue;
        }
        
        // Stop at merge nodes (end of component branch)
        if ($node['is_merge_node'] ?? false) {
            continue;
        }
        
        // Collect operation nodes
        if ($node['node_type'] === 'operation') {
            $nodes[] = $node;
        }
        
        // Continue to downstream nodes
        $outgoingEdges = $this->getOutgoingEdges($currentId);
        foreach ($outgoingEdges as $edge) {
            $queue[] = $edge['target_node_id'];
        }
    }
    
    return $nodes;
}
```

**Deliverables:**
- [ ] DFS/BFS downstream traversal
- [ ] Stops at merge nodes
- [ ] Returns only operation nodes
- [ ] Excludes QC, split, merge, etc.

---

### 27.13.6 Service: resolveComponentCode()

**Duration:** 2 hours

**File:** `source/BGERP/Service/ComponentMappingService.php` (NEW)

**Note:** Per `SYSTEM_WIRING_GUIDE.md`, this is a **domain service** (not DAG-specific),
so it belongs in `BGERP\Service`, not `BGERP\Dag`.

```php
<?php
declare(strict_types=1);

namespace BGERP\Service;

/**
 * ComponentMappingService
 * 
 * Maps graph anchor_slots to component_codes.
 * Separates graph structure (slots) from product configuration (codes).
 * 
 * @see docs/super_dag/01-concepts/COMPONENT_CATALOG_SPEC.md
 */
class ComponentMappingService
{
    private \mysqli $db;
    
    public function __construct(\mysqli $db)
    {
        $this->db = $db;
    }
    
    /**
     * Resolve anchor_slot to component_code for a graph
     * 
     * @param int $graphId
     * @param string $anchorSlot
     * @return string|null Component code or null if not mapped
     */
    public function resolveComponentCode(int $graphId, string $anchorSlot): ?string
    {
        $stmt = $this->db->prepare("
            SELECT component_code 
            FROM graph_component_mapping 
            WHERE graph_id = ? AND anchor_slot = ?
        ");
        $stmt->bind_param('is', $graphId, $anchorSlot);
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();
        $stmt->close();
        
        return $row['component_code'] ?? null;
    }
    
    /**
     * Get all mappings for a graph
     */
    public function getMappingsForGraph(int $graphId): array;
    
    /**
     * Set mapping (upsert)
     */
    public function setMapping(int $graphId, string $anchorSlot, string $componentCode): bool;
    
    /**
     * Remove mapping
     */
    public function removeMapping(int $graphId, string $anchorSlot): bool;
    
    /**
     * Get all anchor slots in a graph (from routing_node)
     */
    public function getAnchorSlotsInGraph(int $graphId): array;
    
    /**
     * Validate all slots are mapped
     */
    public function validateMappingsComplete(int $graphId): array;
}
```

**Deliverables:**
- [ ] Service file created
- [ ] resolveComponentCode works
- [ ] Upsert mapping works
- [ ] Validation method for publish

---

### 27.13.7-9 Graph Designer UI

**Duration:** 8 hours total

**Files:**
- `assets/javascripts/dag/graph_designer.js` (extend)
- `views/dag_designer.php` (extend)

**⚠️ IMPORTANT: Replace Rework Node with Component Node**

The **Rework Node** is now **LEGACY** and should be removed from the palette.
- QC Rework V2 uses Behavior-based rework selection (not graph edges)
- Component Node takes its place in the toolbar

```javascript
// REMOVE from palette (LEGACY):
// { type: 'rework', ... }

// REPLACE with Component Node:
{
    type: 'component',
    label: t('dag.node.component', 'Component Anchor'),
    icon: '🏷️',
    color: '#6366f1', // Indigo
    description: t('dag.node.component_desc', 'Marks start of a component branch'),
    properties: {
        anchor_slot: {
            type: 'text',
            label: t('dag.property.anchor_slot', 'Anchor Slot'),
            placeholder: 'SLOT_A',
            required: true,
            pattern: '^[A-Z][A-Z0-9_]*$',
            help: t('dag.property.anchor_slot_help', 'Use UPPER_SNAKE_CASE (e.g., SLOT_A, BODY_1)')
        }
    },
    validation: {
        canHaveWorkCenter: false,
        canHaveBehavior: false,
        mustBeAfterSplit: true
    }
}
```

**Palette Changes:**

| Before (Legacy) | After (V2) |
|-----------------|------------|
| ~~Rework Node~~ | **Component Anchor** |

**i18n Keys to Register (English base):**
- `dag.node.component` = "Component Anchor"
- `dag.node.component_desc` = "Marks start of a component branch"
- `dag.property.anchor_slot` = "Anchor Slot"
- `dag.property.anchor_slot_help` = "Use UPPER_SNAKE_CASE (e.g., SLOT_A, BODY_1)"
- `dag.validation.anchor_slot_required` = "Anchor slot is required"
- `dag.validation.anchor_slot_format` = "Anchor slot must be UPPER_SNAKE_CASE"

**Visual Styling:**

```css
/* Component Node */
.node-component {
    background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
    border: 2px solid #4f46e5;
    border-radius: 8px;
    box-shadow: 0 4px 6px rgba(99, 102, 241, 0.3);
}

.node-component .node-icon {
    font-size: 1.5rem;
}

.node-component .anchor-slot-badge {
    background: rgba(255, 255, 255, 0.2);
    padding: 2px 8px;
    border-radius: 4px;
    font-family: monospace;
    font-size: 0.8rem;
}

/* REMOVE: .node-rework styling (LEGACY) */
```

**Deliverables:**
- [ ] **Remove Rework Node from palette** (LEGACY)
- [ ] Component Node in palette (replaces Rework)
- [ ] Drag-and-drop works
- [ ] anchor_slot input field
- [ ] Validation (UPPER_SNAKE_CASE)
- [ ] Visual styling distinct from operation nodes
- [ ] Cannot add work_center or behavior

---

### 27.13.10 API: Component Mapping Endpoints

**Duration:** 3 hours

**File:** `source/component_mapping_api.php`

**Template (Per DEVELOPER_POLICY v1.6):**

```php
<?php
/**
 * Component Mapping API
 * 
 * Maps anchor_slots to component_codes for graphs.
 * 
 * @package Bellavier Group ERP
 * @version 1.0
 * @lifecycle runtime
 * @tenant_scope true
 * @permission component.node.view, component.node.manage
 * @date 2025-12
 */

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/global_function.php';
require_once __DIR__ . '/model/member_class.php';
require_once __DIR__ . '/permission.php';

use BGERP\Service\ComponentMappingService;
use BGERP\Helper\RateLimiter;
use BGERP\Bootstrap\TenantApiBootstrap;
use BGERP\Http\TenantApiOutput;

TenantApiOutput::startOutputBuffer();

header('Content-Type: application/json; charset=utf-8');
$cid = $_SERVER['HTTP_X_CORRELATION_ID'] ?? bin2hex(random_bytes(8));
header('X-Correlation-Id: ' . $cid);
$__t0 = microtime(true);

// Auth
$objMemberDetail = new memberDetail();
$member = $objMemberDetail->thisLogin();
if (!$member) {
    json_error(translate('common.error.unauthorized', 'Unauthorized'), 401, ['app_code' => 'CM_401_UNAUTH']);
}
$memberId = (int)($member['id_member'] ?? 0);

// Maintenance
if (file_exists(__DIR__ . '/../storage/maintenance.flag')) {
    json_error(translate('common.error.service_unavailable', 'Service unavailable'), 503, ['app_code' => 'CM_503_MAINT']);
}

// Rate limit
RateLimiter::check($member, 120, 60, 'component_mapping');

// Bootstrap
[$org, $db] = TenantApiBootstrap::init();
$tenantDb = $db->getTenantDb();

$service = new ComponentMappingService($tenantDb);
$action = $_REQUEST['action'] ?? '';

$aiTrace = [
    'module' => 'component_mapping',
    'action' => $action,
    'tenant' => $member['id_org'] ?? 0,
    'user_id' => $memberId,
    'timestamp' => gmdate('c'),
    'request_id' => $cid
];

try {
    switch ($action) {
        case 'list_mappings':
            handleListMappings($service);
            break;
        case 'set_mapping':
            must_allow_code($member, 'component.node.manage');
            handleSetMapping($service, $memberId);
            break;
        case 'remove_mapping':
            must_allow_code($member, 'component.node.manage');
            handleRemoveMapping($service);
            break;
        case 'validate':
            handleValidate($service);
            break;
        default:
            json_error(translate('common.error.invalid_action', 'Invalid action'), 400, ['app_code' => 'CM_400_INVALID']);
    }
    
    $aiTrace['execution_ms'] = (int)((microtime(true) - $__t0) * 1000);
    header('X-AI-Trace: ' . json_encode($aiTrace, JSON_UNESCAPED_UNICODE));
    
} catch (Throwable $e) {
    $aiTrace['error'] = $e->getMessage();
    $aiTrace['execution_ms'] = (int)((microtime(true) - $__t0) * 1000);
    header('X-AI-Trace: ' . json_encode($aiTrace, JSON_UNESCAPED_UNICODE));
    
    error_log("[CM][$cid][User:$memberId][$action] Error: " . $e->getMessage());
    json_error(translate('common.error.server', 'An error occurred'), 500, ['app_code' => 'CM_500_ERROR']);
}

// Handler functions...
```

**Endpoints:**
- `list_mappings` - Get all mappings for a graph
- `set_mapping` - Set/update slot → code mapping
- `remove_mapping` - Remove mapping
- `validate` - Check if all slots are mapped

**Deliverables:**
- [ ] API file created with all Enterprise features
- [ ] Permissions registered: `component.node.view`, `component.node.manage`
- [ ] All handlers use `must_allow_code()`
- [ ] X-AI-Trace header included

---

### 27.13.11 Product Config UI: Slot → Code → Material mapping (In Products Modal)

**Duration:** 6 hours (extended for material integration)

**⚠️ DESIGN DECISION:** 
Component Mapping config จะอยู่ใน **Products Modal** ร่วมกับ Production Flow config
ไม่ต้องสร้างหน้าแยกใหม่ - ใช้ UI ที่มีอยู่แล้ว

**📦 Material Integration (Future-Ready Design):**
ต้องคิดเผื่อการเชื่อมโยงกับ Materials System ที่มีอยู่แล้ว

**Files to Modify (NOT create new):**
- `views/products.php` - Add Component Mapping tab/section
- `assets/javascripts/products/products.js` - Add mapping functions
- `source/product_api.php` - Add mapping endpoints
- `source/component_catalog_api.php` - Add material linking actions

**Location in UI:**

```
┌─────────────────────────────────────────────────────────────────┐
│              PRODUCT MODAL                                       │
├─────────────────────────────────────────────────────────────────┤
│  [Details] [BOM] [Production Flow] [Component Mapping]          │
│                     ↑                    ↑                      │
│              existing tab         NEW TAB (add here)            │
└─────────────────────────────────────────────────────────────────┘
```

**Component Mapping Tab Design (with Material Integration):**

```
┌─────────────────────────────────────────────────────────────────┐
│  📦 Component Mapping                                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Graph: Standard Tote Bag Flow v2.1                             │
│                                                                 │
│  ┌─ Anchor Slots ───────────────────────────────────────────┐  │
│  │                                                           │  │
│  │  SLOT_A  →  [ BODY_MAIN_PANEL     ▼ ]  ✅                │  │
│  │              Materials: [Leather-Goat-Black ▼] 0.8 sqft  │  │
│  │                        [+ Add Material]                   │  │
│  │                                                           │  │
│  │  SLOT_B  →  [ STRAP_LONG          ▼ ]  ✅                │  │
│  │              Materials: [Leather-Cow-Brown ▼] 0.5 sqft   │  │
│  │                        [Canvas-Lining ▼] 0.3 sqft        │  │
│  │                                                           │  │
│  │  SLOT_C  →  [ Select component... ▼ ]  ⚠️                │  │
│  │                                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ⚠️ All slots must be mapped before creating jobs               │
│                                                                 │
│  [Save Mappings]                                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔗 Operation Node → Component → Material Chain

### Concept: Behavior ต้องรู้ Context

เมื่อ Token อยู่ที่ **Operation Node** (เช่น CUT, STITCH, EDGE):
1. Behavior ต้องรู้ว่าทำงานกับ **Component** อะไร
2. จาก Component → ดึง **Material** ที่ต้องใช้
3. แสดง Material specs ใน **UI** ให้ช่าง

```
Token at CUT Node
       ↓
┌─────────────────────────────────────────────────────────────────┐
│  Behavior: CUT_LEATHER                                          │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Component: BODY_MAIN_PANEL                                  ││
│  │ Material:  Leather-Goat-Black (Lot: LT-2025-001)           ││
│  │ Qty:       0.8 sqft                                         ││
│  │ Specs:     Thickness 1.2mm, Grade A                         ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  [Start Cut] [Select Leather Sheet]                            │
└─────────────────────────────────────────────────────────────────┘
```

### Resolution Chain: Token → Component → Material

```php
// In BehaviorExecutionService or WorkQueueController

public function getOperationContext(int $tokenId): array
{
    // 1. Get token's current node
    $token = $this->tokenService->getToken($tokenId);
    $nodeId = $token['current_node_id'];
    
    // 2. Find component anchor (parent branch)
    $componentCode = $this->graphService->getComponentForNode($nodeId);
    
    // 3. Get component details + materials
    $component = $this->catalogService->getComponentByCode($componentCode);
    $materials = $this->catalogService->getMaterialsForComponent($componentCode);
    
    // 4. Get lot/sheet availability (for CUT nodes)
    $availableSheets = [];
    if ($this->nodeService->isCutNode($nodeId)) {
        foreach ($materials as $mat) {
            $availableSheets[$mat['material_sku']] = 
                $this->sheetService->getAvailableSheets($mat['material_sku']);
        }
    }
    
    return [
        'token' => $token,
        'component' => $component,
        'materials' => $materials,
        'available_sheets' => $availableSheets
    ];
}
```

### Graph Service: Node → Component Resolution

```php
// In DAGRoutingService or GraphService

/**
 * Find component code for a node by tracing back to component anchor
 * 
 * @param int $nodeId Current node ID
 * @return string|null Component code from nearest component anchor
 */
public function getComponentForNode(int $nodeId): ?string
{
    // Strategy: Trace edges backward until we find a component node
    // Component node has node_type = 'component' and anchor_slot
    
    $visited = [];
    $queue = [$nodeId];
    
    while (!empty($queue)) {
        $currentId = array_shift($queue);
        
        if (in_array($currentId, $visited)) continue;
        $visited[] = $currentId;
        
        $node = $this->getNodeById($currentId);
        
        // Found component anchor!
        if ($node['node_type'] === 'component' && !empty($node['anchor_slot'])) {
            // Resolve anchor_slot → component_code via graph_component_mapping
            return $this->resolveAnchorToComponent($node['anchor_slot']);
        }
        
        // Add predecessor nodes to queue
        $predecessors = $this->getPredecessorNodes($currentId);
        foreach ($predecessors as $pred) {
            $queue[] = $pred['id_node'];
        }
    }
    
    return null; // Not found (shouldn't happen in well-formed graph)
}
```

### Use Cases by Operation Type

| Node Type | Component Context Usage |
|-----------|------------------------|
| **CUT** | Show material specs, available sheets, area needed |
| **STITCH** | Show thread type from material, needle size |
| **EDGE** | Show edge paint color from material config |
| **GLUE** | Show glue type, drying time |
| **QC** | Show component-specific defect types |
| **ASSEMBLY** | Show all components being assembled |

### UI Integration in Work Queue

```javascript
// In work_queue.js - when loading operation details

async function loadOperationContext(tokenId) {
    const response = await fetch(`/source/dag_token_api.php?action=get_context&token_id=${tokenId}`);
    const data = await response.json();
    
    if (data.ok && data.component) {
        // Show component badge
        $('#component-badge').text(data.component.display_name_th || data.component.component_code);
        
        // Show materials
        const materialsHtml = data.materials.map(m => `
            <div class="material-item">
                <span class="material-sku">${m.material_sku}</span>
                <span class="material-qty">${m.qty_per_component} ${m.uom_code || 'pcs'}</span>
                ${m.is_primary ? '<span class="badge bg-primary">Primary</span>' : ''}
            </div>
        `).join('');
        $('#materials-list').html(materialsHtml);
        
        // For CUT nodes: Show available sheets
        if (data.available_sheets) {
            showLeatherSheetSelector(data.available_sheets);
        }
    }
}
```

---

## 📦 Material Integration (Future-Ready)

### Existing Materials Infrastructure (Audit Summary)

**✅ Tables Ready:**
| Table | Purpose | Status |
|-------|---------|--------|
| `material` | Master data (sku, name, category, uom) | Ready |
| `material_lot` | Lot tracking | Ready |
| `stock_item` | Legacy inventory with costs | Ready |
| `component_type` | Component types (BODY, STRAP) | Ready |
| `component_master` | Component definitions | Ready |
| `component_bom_map` | BOM → Component | Ready |

**✅ Services Ready:**
- `materials.php` API - Full CRUD + Lot + Assets
- `MaterialResolver` - Token → Material resolution
- `ComponentAllocationService` - Serial → Sheet allocation

### ❌ Missing: Component → Material Direct Link

**New Table: `component_material_map`**

```sql
CREATE TABLE component_material_map (
    id_map INT AUTO_INCREMENT PRIMARY KEY,
    component_code VARCHAR(50) NOT NULL COMMENT 'FK to component_catalog',
    material_sku VARCHAR(100) NOT NULL COMMENT 'FK to material.sku',
    qty_per_component DECIMAL(18,6) DEFAULT 1.000000 COMMENT 'Material qty per component',
    is_primary TINYINT(1) DEFAULT 1 COMMENT 'Primary material flag',
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uniq_component_material (component_code, material_sku),
    KEY idx_component (component_code),
    KEY idx_material (material_sku)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Benefits:**
- 1 Component → Multiple Materials (เช่น BODY ใช้ leather + lining)
- Track qty_per_component (area/qty สำหรับ cost calculation)
- Bi-directional query: "Material X ใช้ใน Component ไหนบ้าง"

### API Extensions for Material Linking

```php
// In component_catalog_api.php - Add these actions:

case 'get_materials':
    // Get materials linked to a component
    must_allow_code($member, 'component.catalog.view');
    $componentCode = $_GET['component_code'] ?? '';
    $materials = $service->getMaterialsForComponent($componentCode);
    TenantApiOutput::success(['materials' => $materials]);
    break;

case 'link_material':
    // Link material to component
    must_allow_code($member, 'component.catalog.manage');
    $componentCode = $_POST['component_code'] ?? '';
    $materialSku = $_POST['material_sku'] ?? '';
    $qty = (float)($_POST['qty'] ?? 1);
    $isPrimary = (int)($_POST['is_primary'] ?? 1);
    
    $result = $service->linkMaterial($componentCode, $materialSku, $qty, $isPrimary);
    TenantApiOutput::success(['linked' => $result]);
    break;

case 'unlink_material':
    // Unlink material from component
    must_allow_code($member, 'component.catalog.manage');
    $componentCode = $_POST['component_code'] ?? '';
    $materialSku = $_POST['material_sku'] ?? '';
    
    $service->unlinkMaterial($componentCode, $materialSku);
    TenantApiOutput::success(['unlinked' => true]);
    break;
```

**Integration with Production Flow Tab:**
- When user selects graph in "Production Flow" tab → Component Mapping tab updates
- Shows anchor_slots from selected graph
- Dropdown pulls from `component_catalog` API

**i18n Keys (English base):**
```javascript
// JS (in Products modal)
t('product.tab.component_mapping', 'Component Mapping')
t('component_mapping.slot', 'Anchor Slot')
t('component_mapping.component', 'Component')
t('component_mapping.status.mapped', 'Mapped')
t('component_mapping.status.not_mapped', 'Not mapped')
t('component_mapping.action.save', 'Save Mappings')
t('component_mapping.msg.saved', 'Mappings saved successfully')
t('component_mapping.error.incomplete', 'All slots must be mapped before creating jobs')
```

**Deliverables:**
- [ ] New tab "Component Mapping" in Product Modal
- [ ] Tab linked to Production Flow (graph selection)
- [ ] List anchor slots from graph
- [ ] Dropdown from component_catalog (via API)
- [ ] Save to graph_component_mapping
- [ ] Show mapping status (complete/incomplete)
- [ ] Block job creation if incomplete
- [ ] All text uses `t()` for i18n

---

### 27.13.11b Material Linking Integration (Optional Sub-task)

**Duration:** 4 hours (can be done in parallel or Phase 2)

**Files:**
- `database/tenant_migrations/2025_12_component_material_map.php` (NEW)
- `source/BGERP/Service/ComponentCatalogService.php` (extend)
- `source/component_catalog_api.php` (add actions)
- `assets/javascripts/component_catalog/component_catalog.js` (extend)

**Database Migration:**

```php
<?php
/**
 * Migration: 2025_12_component_material_map
 * Creates component_material_map table for component → material linking
 */
require_once __DIR__ . '/../tools/migration_helpers.php';

return function (mysqli $db): void {
    $sql = <<<'SQL'
CREATE TABLE IF NOT EXISTS `component_material_map` (
    `id_map` INT AUTO_INCREMENT PRIMARY KEY,
    `component_code` VARCHAR(50) NOT NULL COMMENT 'FK to component_catalog.component_code',
    `material_sku` VARCHAR(100) NOT NULL COMMENT 'FK to material.sku',
    `qty_per_component` DECIMAL(18,6) DEFAULT 1.000000 COMMENT 'Material qty per component unit',
    `is_primary` TINYINT(1) DEFAULT 1 COMMENT '1=Primary material, 0=Secondary',
    `notes` TEXT,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY `uniq_component_material` (`component_code`, `material_sku`),
    KEY `idx_component` (`component_code`),
    KEY `idx_material` (`material_sku`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    COMMENT='Maps components to their required materials'
SQL;
    $db->query($sql);
};
```

**Service Methods:**

```php
// In ComponentCatalogService.php

/**
 * Get materials linked to a component
 */
public function getMaterialsForComponent(string $componentCode): array
{
    return $this->dbHelper->fetchAll(
        "SELECT cmm.*, m.name AS material_name, m.category
         FROM component_material_map cmm
         LEFT JOIN material m ON m.sku = cmm.material_sku
         WHERE cmm.component_code = ?
         ORDER BY cmm.is_primary DESC, cmm.created_at ASC",
        [$componentCode],
        's'
    );
}

/**
 * Link material to component
 */
public function linkMaterial(string $componentCode, string $materialSku, float $qty = 1.0, bool $isPrimary = true): bool
{
    // Validate component exists
    if (!$this->getComponentByCode($componentCode)) {
        throw new \InvalidArgumentException('Invalid component code');
    }
    
    // Validate material exists
    $material = $this->dbHelper->fetchOne(
        "SELECT sku FROM material WHERE sku = ? AND is_active = 1",
        [$materialSku],
        's'
    );
    if (!$material) {
        throw new \InvalidArgumentException('Invalid or inactive material SKU');
    }
    
    $stmt = $this->db->prepare(
        "INSERT INTO component_material_map 
         (component_code, material_sku, qty_per_component, is_primary)
         VALUES (?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE qty_per_component = VALUES(qty_per_component), is_primary = VALUES(is_primary)"
    );
    $isPrimaryInt = $isPrimary ? 1 : 0;
    $stmt->bind_param('ssdi', $componentCode, $materialSku, $qty, $isPrimaryInt);
    $result = $stmt->execute();
    $stmt->close();
    
    return $result;
}

/**
 * Unlink material from component
 */
public function unlinkMaterial(string $componentCode, string $materialSku): bool
{
    $stmt = $this->db->prepare(
        "DELETE FROM component_material_map WHERE component_code = ? AND material_sku = ?"
    );
    $stmt->bind_param('ss', $componentCode, $materialSku);
    $result = $stmt->execute();
    $stmt->close();
    
    return $result;
}
```

**i18n Keys for Material Linking:**
```javascript
t('component.materials', 'Materials')
t('component.add_material', 'Add Material')
t('component.material_qty', 'Qty per Component')
t('component.primary_material', 'Primary Material')
t('component.link_material.success', 'Material linked successfully')
t('component.unlink_material.confirm', 'Remove this material from component?')
```

**Deliverables (Material Integration):**
- [ ] `component_material_map` table migration
- [ ] Service methods: getMaterialsForComponent, linkMaterial, unlinkMaterial
- [ ] API actions: get_materials, link_material, unlink_material
- [ ] UI: Material dropdown in Component modal or Product modal
- [ ] Validation: material must exist and be active
- [ ] i18n for all UI text

---

### 27.13.11c Operation Context Integration

**Duration:** 4 hours

**Purpose:** Operation Nodes (CUT, STITCH, etc.) ต้องรู้ว่าทำงานกับ Component อะไร และใช้ Material อะไร

**Files:**
- `source/BGERP/Dag/DAGRoutingService.php` (extend)
- `source/BGERP/Dag/BehaviorExecutionService.php` (extend)  
- `source/dag_token_api.php` (extend get_context action)
- `assets/javascripts/dag/work_queue.js` (extend)

**Core Method: Node → Component Resolution**

```php
// In DAGRoutingService.php

/**
 * Get component code for a node by tracing back to component anchor
 */
public function getComponentForNode(int $nodeId): ?string
{
    $visited = [];
    $queue = [$nodeId];
    
    while (!empty($queue)) {
        $currentId = array_shift($queue);
        if (in_array($currentId, $visited)) continue;
        $visited[] = $currentId;
        
        $node = $this->getNodeById($currentId);
        
        // Found component anchor!
        if ($node['node_type'] === 'component' && !empty($node['anchor_slot'])) {
            return $this->resolveAnchorToComponent(
                $node['id_graph'], 
                $node['anchor_slot']
            );
        }
        
        // Add predecessors to queue
        $predecessors = $this->getPredecessorNodes($currentId);
        foreach ($predecessors as $pred) {
            $queue[] = $pred['id_node'];
        }
    }
    
    return null;
}
```

**Full Context for Operations:**

```php
// In BehaviorExecutionService or TokenContextService

/**
 * Get full operation context for a token at an operation node
 */
public function getOperationContext(int $tokenId): array
{
    $token = $this->tokenService->getToken($tokenId);
    $nodeId = (int)$token['current_node_id'];
    $node = $this->routingService->getNodeById($nodeId);
    
    // Get component from node's branch
    $componentCode = $this->routingService->getComponentForNode($nodeId);
    $component = null;
    $materials = [];
    
    if ($componentCode) {
        $component = $this->catalogService->getComponentByCode($componentCode);
        $materials = $this->catalogService->getMaterialsForComponent($componentCode);
    }
    
    // For CUT nodes: get available leather sheets
    $availableSheets = [];
    $behaviorCode = $node['behavior_code'] ?? '';
    if (strpos($behaviorCode, 'CUT') !== false) {
        foreach ($materials as $mat) {
            if ($mat['is_primary']) {
                $availableSheets = $this->sheetService->getAvailableSheets(
                    $mat['material_sku']
                );
                break;
            }
        }
    }
    
    return [
        'token' => $token,
        'node' => $node,
        'component' => $component,
        'component_code' => $componentCode,
        'materials' => $materials,
        'available_sheets' => $availableSheets
    ];
}
```

**Work Queue UI Enhancement:**

```javascript
// When loading operation in work queue
async function showOperationDetails(tokenId) {
    const resp = await $.getJSON('/source/dag_token_api.php', {
        action: 'get_context',
        token_id: tokenId
    });
    
    if (!resp.ok) return;
    
    // Show component badge
    if (resp.component) {
        $('#operation-component').html(`
            <div class="component-badge">
                <i class="fe fe-package"></i>
                ${resp.component.display_name_th || resp.component_code}
            </div>
        `);
    }
    
    // Show materials list
    if (resp.materials?.length > 0) {
        const html = resp.materials.map(m => `
            <div class="material-row ${m.is_primary ? 'primary' : ''}">
                <span class="sku">${m.material_sku}</span>
                <span class="qty">${m.qty_per_component}</span>
                ${m.is_primary ? '<span class="badge bg-primary">Primary</span>' : ''}
            </div>
        `).join('');
        $('#operation-materials').html(html);
    }
    
    // For CUT: Show sheet selector
    if (resp.available_sheets?.length > 0) {
        showLeatherSheetModal(resp.available_sheets);
    }
}
```

**Use Cases by Operation Type:**

| Behavior | Component Context Usage |
|----------|------------------------|
| `CUT_LEATHER` | Material specs, available sheets, area needed |
| `STITCH` | Thread type, needle size from material config |
| `EDGE_PAINT` | Edge paint color from material |
| `GLUE` | Glue type, drying time |
| `QC_SINGLE` | Component-specific defect types |
| `ASSEMBLY` | All components being assembled |

**i18n Keys:**
```javascript
t('operation.component', 'Component')
t('operation.materials', 'Materials Required')
t('operation.primary_material', 'Primary')
t('operation.select_sheet', 'Select Leather Sheet')
t('operation.no_sheets', 'No sheets available')
```

**Deliverables:**
- [ ] `getComponentForNode()` - Trace back to component anchor
- [ ] `resolveAnchorToComponent()` - Map anchor_slot → component_code
- [ ] `getOperationContext()` - Full context for Work Queue UI
- [ ] Extend `get_context` API action with component/material data
- [ ] Work Queue UI shows component + materials
- [ ] CUT nodes trigger leather sheet selector

---

### 27.13.12-13 Validation + Tests

**Duration:** 6 hours

**Validation Rules:**

```php
// In GraphValidationEngine
private function validateComponentNodes(array $nodes): array
{
    $errors = [];
    
    foreach ($nodes as $node) {
        if ($node['node_type'] === 'component') {
            // Must have anchor_slot
            if (empty($node['anchor_slot'])) {
                $errors[] = [
                    'code' => 'C1_ANCHOR_SLOT_REQUIRED',
                    'severity' => 'error',
                    'message' => "Component node '{$node['node_code']}' must have anchor_slot"
                ];
            }
            
            // Cannot have work_center
            if (!empty($node['id_work_center'])) {
                $errors[] = [
                    'code' => 'COMPONENT_NO_WORK_CENTER',
                    'severity' => 'error',
                    'message' => "Component node '{$node['node_code']}' cannot have work center"
                ];
            }
        }
    }
    
    return $errors;
}
```

**Test Cases:**

```php
class ComponentNodeTest extends TestCase
{
    public function testFindComponentAnchorFindsUpstream(): void;
    public function testFindComponentAnchorReturnsNullIfNone(): void;
    public function testGetNodesInComponentReturnsOperations(): void;
    public function testGetNodesInComponentExcludesQC(): void;
    public function testGetNodesInComponentStopsAtMerge(): void;
    public function testResolveComponentCodeReturnsMapping(): void;
    public function testResolveComponentCodeReturnsNullIfNotMapped(): void;
    public function testValidateMappingsCompleteReturnsErrors(): void;
}
```

**Deliverables:**
- [ ] Component node validation rules
- [ ] 10+ unit tests
- [ ] Integration tests for mapping
- [ ] All tests passing

---

## ✅ Definition of Done

**Database:**
- [ ] `node_type` ENUM includes 'component', 'router'
- [ ] `anchor_slot` column in routing_node
- [ ] `graph_component_mapping` table with FKs

**Service Layer:**
- [ ] `findComponentAnchor()` works correctly (BFS upstream)
- [ ] `getNodesInComponent()` returns operation nodes only
- [ ] `resolveComponentCode()` resolves slot → code
- [ ] ComponentMappingService in `BGERP\Service\` namespace
- [ ] `composer dump-autoload -o` executed after adding service

**API Layer:**
- [ ] `component_mapping_api.php` follows DEVELOPER_POLICY v1.6
- [ ] Uses `TenantApiBootstrap::init()` → `$db->getTenantDb()`
- [ ] Uses `TenantApiOutput::startOutputBuffer()`
- [ ] Uses `must_allow_code($member, 'component.node.manage')`
- [ ] Uses `RateLimiter::check()` without if condition
- [ ] X-AI-Trace header with `execution_ms`
- [ ] Permissions: `component.node.view`, `component.node.manage`

**UI Layer:**
- [ ] **Remove Rework Node from palette** (LEGACY)
- [ ] Component Node replaces Rework in palette
- [ ] anchor_slot input (not catalog dropdown!)
- [ ] All UI text uses `translate()` / `t()`
- [ ] Component Mapping tab in Product Modal (not separate page)

**Operation Context (Node → Component → Material):**
- [ ] `getComponentForNode()` - Trace node back to component anchor
- [ ] `getOperationContext()` - Full context for token at operation
- [ ] Work Queue UI shows component + materials
- [ ] CUT nodes show available leather sheets

**Testing:**
- [ ] Validation rules implemented
- [ ] 15+ tests passing
- [ ] All i18n keys have English defaults

---

## 🔗 Dependencies

**Requires:**
- 27.12 Component Catalog (for component_code validation in mapping)

**Blocks:**
- 27.15 QC Rework V2 (needs findComponentAnchor, getNodesInComponent)
- 27.16 Graph Linter (needs anchor_slot validation)
- 27.17 MCI (uses component context)

---

## 📚 Related Documents

- [QC_REWORK_PHILOSOPHY_V2.md](../01-concepts/QC_REWORK_PHILOSOPHY_V2.md)
- [COMPONENT_CATALOG_SPEC.md](../01-concepts/COMPONENT_CATALOG_SPEC.md)
- [MATERIAL_REQUIREMENT_RESERVATION_SPEC.md](../specs/MATERIAL_REQUIREMENT_RESERVATION_SPEC.md) - 📦 Material Req/Res System
- [MASTER_IMPLEMENTATION_ROADMAP.md](./MASTER_IMPLEMENTATION_ROADMAP.md)
- [DEVELOPER_POLICY.md](../../developer/01-policy/DEVELOPER_POLICY.md) - API Standards v1.6
- [SYSTEM_WIRING_GUIDE.md](../../developer/SYSTEM_WIRING_GUIDE.md) - Service Namespaces
- [01-api-development.md](../../developer/08-guides/01-api-development.md) - API Development Guide

---

## 📋 Quick Reference: API Compliance Checklist

```php
// ✅ MUST HAVE in every API file:

// 1. Bootstrap
[$org, $db] = TenantApiBootstrap::init();
$tenantDb = $db->getTenantDb();

// 2. Output Buffer
TenantApiOutput::startOutputBuffer();

// 3. Rate Limit (void - no if check)
RateLimiter::check($member, 120, 60, 'endpoint_name');

// 4. Permission (throws if denied)
must_allow_code($member, 'permission.code');

// 5. AI Trace
$aiTrace['execution_ms'] = (int)((microtime(true) - $__t0) * 1000);
header('X-AI-Trace: ' . json_encode($aiTrace, JSON_UNESCAPED_UNICODE));

// 6. i18n
translate('key', 'English default')  // PHP
t('key', 'English default')          // JS
```


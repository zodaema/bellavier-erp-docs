# 🚀 Phase 8: Product Integration - Quick Reference Guide

**For Developers & AI Assistants**

**Last Updated:** 2025-11-19 (Phase 8.3 Complete - Version Management)

---

## 📋 Quick Links

- **Full Plan:** [PHASE8_PRODUCT_INTEGRATION_PLAN.md](./PHASE8_PRODUCT_INTEGRATION_PLAN.md)
- **Database Schema:** [PHASE8_DATABASE_SCHEMA.md](./PHASE8_DATABASE_SCHEMA.md)
- **Enhancements:** [PHASE8_ENHANCEMENTS.md](./PHASE8_ENHANCEMENTS.md) (Feature Flags, Caching, Stability, Source Tracking, Graph Diff)
- **API Endpoints:** See API specifications below

---

## 🎯 Phase Status

- ✅ **Phase 8.1:** Foundation (Database, Helper, Basic APIs) - Complete
- ✅ **Phase 8.2:** MO/Job Ticket Integration - Complete
- ✅ **Phase 8.3:** Version Management & Preview - Complete (NEW!)
- 📋 **Phase 8.4:** Statistics & Audit - Planned

---

## 🗄️ Database Schema Quick Reference

### Table: `product_graph_binding`

**Purpose:** Links products to routing graphs with version management

**Key Columns:**
- `id_binding` (PK)
- `id_product` (FK → product)
- `id_graph` (FK → routing_graph)
- `graph_version_pin` (NULL = use latest)
- `default_mode` (hatthasilpa/classic/hybrid)
- `is_active` (1/0)
- `effective_from` / `effective_until`

**Indexes:**
- `idx_product` - Fast product lookups
- `idx_graph` - Fast graph lookups
- `idx_active` - Filter active bindings
- `uniq_product_graph_active` - Prevent duplicates

### Table: `product_graph_binding_audit`

**Purpose:** Audit trail for binding changes

**Key Columns:**
- `id_audit` (PK)
- `id_binding` (FK)
- `action` (created/updated/activated/deactivated/deleted)
- `old_values` / `new_values` (JSON)
- `changed_by` / `changed_at`

---

## 🔌 API Quick Reference

### Base URL
```
/source/products.php
```

### 1. Get Product Detail (with binding)
```
GET /source/products.php?action=detail&id_product={id}
```

### 2. Bind Graph to Product
```
POST /source/products.php
action=bind_graph
id_product={id}
id_graph={id}
graph_version_pin={version|null}
default_mode={hatthasilpa|classic|hybrid}
is_active={1|0}
```

### 3. List Available Graphs
```
GET /source/products.php?action=list_graphs&mode={mode}&status=published
```

### 4. Preview Graph
```
GET /source/products.php?action=graph_preview&id_graph={id}&version={version}
```

### 5. Toggle Binding
```
POST /source/products.php
action=toggle_binding
id_binding={id}
is_active={1|0}
```

### 6. Get Usage Stats
```
GET /source/products.php?action=usage_stats&id_product={id}
```

### 7. Get Binding History
```
GET /source/products.php?action=binding_history&id_product={id}
```

### 8. Compare Graph Versions (Phase 8.3 - NEW!)
```
GET /source/dag_routing_api.php?action=compare_versions&id_graph={id}&v1={version1}&v2={version2}
```

**Response:**
```json
{
  "ok": true,
  "graph": {
    "id_graph": 7,
    "code": "HATTHA_KEYCASE_V2",
    "name": "Hatthasilpa Keycase V2"
  },
  "versions": {
    "v1": "2.3",
    "v2": "2.5"
  },
  "comparison": {
    "nodes": {
      "added": [
        {
          "node_code": "NEW_STEP",
          "node_name": "New Step Name",
          "node_type": "operation"
        }
      ],
      "removed": [
        {
          "node_code": "OLD_STEP",
          "node_name": "Old Step Name",
          "node_type": "operation"
        }
      ],
      "modified": [
        {
          "node_code": "MODIFIED_STEP",
          "node_name": "Modified Step",
          "changes": {
            "estimated_minutes": {
              "old": 30,
              "new": 45
            },
            "position_x": {
              "old": 100,
              "new": 150
            }
          }
        }
      ]
    },
    "edges": {
      "added": [
        {
          "from_node": "START",
          "to_node": "NEW_STEP",
          "edge_type": "normal"
        }
      ],
      "removed": [
        {
          "from_node": "OLD_STEP",
          "to_node": "END",
          "edge_type": "normal"
        }
      ]
    }
  },
  "summary": {
    "nodes_added": 1,
    "nodes_removed": 1,
    "nodes_modified": 1,
    "edges_added": 1,
    "edges_removed": 1,
    "total_changes": 5
  }
}
```

### 9. Update Version Pin (Phase 8.3 - NEW!)
```
POST /source/products.php
action=update_version_pin
id_binding=42
graph_version_pin=2.5
```

**Parameters:**
- `id_binding` (required) - Binding ID
- `graph_version_pin` (optional) - Version to pin (empty string or null for auto)

**Response:**
```json
{
  "ok": true,
  "message": "Graph version updated successfully",
  "binding": {
    "id_binding": 42,
    "graph_version_pin": "2.5",
    "graph_code": "HATTHA_KEYCASE_V2",
    "updated_at": "2025-11-19 10:30:00"
  }
}
```

**Permission Required:** `product.graph.pin_version` (for pinning specific version)

---

## 🔧 Helper Functions Quick Reference

### Get Active Binding
```php
use BGERP\Helper\ProductGraphBindingHelper;

$binding = ProductGraphBindingHelper::getActiveBinding($productId, $mode);
// Returns: ['id_binding' => 42, 'id_graph' => 7, 'graph_version_pin' => '2.3', ...]
// Or: null if no active binding
```

### Validate Binding
```php
$validation = ProductGraphBindingHelper::validateBinding($productId, $graphId, $version);
// Returns: ['valid' => true/false, 'errors' => [...]]
```

### Save Binding
```php
$result = ProductGraphBindingHelper::saveBinding([
    'id_product' => 15,
    'id_graph' => 7,
    'graph_version_pin' => '2.3',
    'default_mode' => 'hatthasilpa',
    'is_active' => true
], $userId);
// Returns: ['ok' => true, 'id_binding' => 42]
```

### Get Graph Version
```php
$version = ProductGraphBindingHelper::getGraphVersion($graphId, $pinVersion);
// If $pinVersion provided: returns $pinVersion
// If NULL: returns latest published version
```

### List All Bindings for Product
```php
// Get all bindings (active and inactive) for a product
$bindings = ProductGraphBindingHelper::listBindings($productId);
// Returns: [
//   [
//     'id_binding' => 42,
//     'default_mode' => 'hatthasilpa',
//     'id_graph' => 7,
//     'graph_code' => 'HATTHA_KEYCASE_V2',
//     'graph_version_pin' => '2.3',
//     'is_active' => 1,
//     'effective_from' => '2025-11-01 00:00:00'
//   ],
//   [
//     'id_binding' => 43,
//     'default_mode' => 'classic',
//     'id_graph' => 8,
//     'graph_code' => 'CLASSIC_KEYCASE_V1',
//     'graph_version_pin' => null,
//     'is_active' => 0,
//     'effective_from' => '2025-10-15 00:00:00'
//   ]
// ]

// Get bindings filtered by mode
$hatthasilpaBindings = ProductGraphBindingHelper::listBindings($productId, 'hatthasilpa');

// Get only active bindings
$activeBindings = ProductGraphBindingHelper::listBindings($productId, null, true);
```

---

## 🎨 Frontend Quick Reference

### Load Binding
```javascript
// In product_graph_binding.js
loadProductGraphBinding(productId)
  .then(data => {
    // data.graph_binding contains binding info
    // data.graph_preview contains node list
  });
```

### Save Binding
```javascript
saveGraphBinding(productId, {
  id_graph: 7,
  graph_version_pin: '2.3',
  default_mode: 'hatthasilpa',
  is_active: true
})
  .then(result => {
    if (result.ok) {
      // Success
    }
  });
```

### Display Badge with Mode Indicator
```javascript
// In products.js (list view)
function renderFlowBadge(binding) {
  if (!binding || !binding.is_active) {
    return '<span class="badge bg-secondary">No Flow</span>';
  }
  
  const version = binding.graph_version_pin || 'auto';
  
  // Mode indicator mapping
  const modeLabel = {
    hatthasilpa: 'H',
    classic: 'C',
    hybrid: 'HY'
  }[binding.default_mode] || '';
  
  // Badge color based on mode
  const badgeClass = {
    hatthasilpa: 'bg-primary',    // Blue for Hatthasilpa
    classic: 'bg-info',            // Cyan for Classic
    hybrid: 'bg-warning'           // Yellow for Hybrid
  }[binding.default_mode] || 'bg-success';
  
  return `<span class="badge ${badgeClass}" title="${binding.default_mode}">
    ${modeLabel ? modeLabel + '-' : ''}${binding.graph_code} (v${version})
  </span>`;
}

// Example output:
// Hatthasilpa: <span class="badge bg-primary">H-HATTHA_KEYCASE_V2 (v2.3)</span>
// Classic: <span class="badge bg-info">C-CLASSIC_KEYCASE_V1 (v1.1)</span>
// Hybrid: <span class="badge bg-warning">HY-HYBRID_CASE_V1 (auto)</span>
// No binding: <span class="badge bg-secondary">No Flow</span>
```

---

## 🔗 Integration Quick Reference

### MO Creation
```php
// In source/mo.php
$productId = $_POST['id_product'] ?? null;
$graphBinding = null;

if ($productId) {
    $graphBinding = ProductGraphBindingHelper::getActiveBinding($productId, $mode);
    if ($graphBinding) {
        $graphId = $graphBinding['id_graph'];
        $graphVersion = $graphBinding['graph_version_pin'] ?? 'latest';
        // Pre-fill form
    }
}

// Allow override (with permission)
if (hasPermission('mo.override.graph')) {
    $graphId = $_POST['id_graph'] ?? $graphId;
}
```

### Job Ticket Creation
```php
// In source/atelier_job_ticket.php
$moId = $_POST['id_mo'] ?? null;
if ($moId) {
    $mo = getMO($moId);
    // MO already has id_graph from product binding
    $graphId = $mo['id_graph'];
}
```

### Trace API Enhancement
```php
// In source/trace_api.php
$productId = $serialData['id_product'];
$binding = ProductGraphBindingHelper::getActiveBinding($productId);

$response['production_flow'] = [
    'id_graph' => $binding['id_graph'],
    'graph_code' => $binding['graph_code'],
    'graph_version' => $binding['graph_version_pin'] ?? 'latest'
];
```

---

## 🔗 Backward Trace Integration

### Complete Flow Chain

When a product is bound to a graph, the binding propagates through the entire production chain:

```
Product (with binding)
    ↓ (inherits)
Manufacturing Order (MO)
    ↓ (inherits)
Job Ticket
    ↓ (produces)
Serial Number
    ↓ (traced via)
Trace API → Product → Graph → Full Production Flow
```

### Integration Points

**1. MO Creation:**
- Product binding → MO automatically gets `id_graph` and `graph_version`
- MO stores: `id_graph`, `graph_version`, `production_mode` (from product binding)

**2. Job Ticket Creation:**
- Inherits from MO: `id_graph`, `graph_version`
- Job Ticket links back to: MO → Product → Graph Binding

**3. Serial Generation:**
- Serial pattern can include graph code: `{SKU}-{MODE}-{GRAPH_CODE}-{SEQ}`
- Example: `RB-KC-ALMOND-HAT-HATTHA_KEYCASE_V2-000123`
- Serial metadata stores: `id_product`, `id_graph`, `graph_version`

**4. Trace API:**
- Query by serial → Get product → Get active binding → Get graph → Get full flow
- Response includes:
  ```json
  {
    "product": { "id_product": 15, "sku": "RB-KC-ALMOND" },
    "production_flow": {
      "id_graph": 7,
      "graph_code": "HATTHA_KEYCASE_V2",
      "graph_version": "2.3",
      "default_mode": "hatthasilpa"
    },
    "timeline": [...]
  }
  ```

**5. Audit Trail:**
- Every binding change is logged in `product_graph_binding_audit`
- Links to: Product, Graph, User, Timestamp, Reason
- Enables full traceability: Who changed what binding when and why

---

## 📝 Audit Helper Quick Reference

### Log Binding Changes

```php
use BGERP\Helper\AuditHelper;

// Log binding creation
AuditHelper::log('product_graph_binding', [
    'action' => 'bind_graph',
    'id_product' => $productId,
    'id_graph' => $graphId,
    'graph_version_pin' => $version,
    'default_mode' => $mode,
    'source' => 'manual', // or 'migration', 'api', 'system'
    'user' => $member['id_member'],
    'reason' => 'Initial product setup'
]);

// Log binding update
AuditHelper::log('product_graph_binding', [
    'action' => 'updated',
    'id_binding' => $bindingId,
    'old_values' => [
        'graph_version_pin' => '2.3',
        'is_active' => 1
    ],
    'new_values' => [
        'graph_version_pin' => '2.5',
        'is_active' => 1
    ],
    'user' => $member['id_member'],
    'reason' => 'Updated to latest stable version'
]);

// Log binding deactivation
AuditHelper::log('product_graph_binding', [
    'action' => 'deactivated',
    'id_binding' => $bindingId,
    'user' => $member['id_member'],
    'reason' => 'Switching to new graph version'
]);
```

### Query Audit History

```php
// Get audit history for a product
$history = AuditHelper::getHistory('product_graph_binding', [
    'id_product' => $productId
], [
    'limit' => 50,
    'order_by' => 'changed_at DESC'
]);

// Get audit history for a graph
$history = AuditHelper::getHistory('product_graph_binding', [
    'id_graph' => $graphId
], [
    'limit' => 100,
    'order_by' => 'changed_at DESC'
]);

// Get audit history filtered by action
$history = AuditHelper::getHistory('product_graph_binding', [
    'id_product' => $productId,
    'action' => 'created'
]);
```

---

## 🔒 Permission Quick Reference

| Permission | Code | Used In |
|------------|------|---------|
| View binding | `product.graph.view` | List graphs, view binding |
| Manage binding | `product.graph.manage` | Create/update/delete binding |
| Pin version | `product.graph.pin_version` | Pin specific version |
| Override graph | `mo.override.graph` | Override in MO creation |

**Check Permission:**
```php
must_allow_product($member, 'graph.manage');
```

---

## 📁 File Structure Quick Reference

```
source/
├── products.php (extend)
├── BGERP/
│   └── Service/
│       └── ProductGraphBindingService.php (new)
│   └── Helper/
│       └── ProductGraphBindingHelper.php (new)

assets/javascripts/products/
├── products.js (extend)
└── product_graph_binding.js (new)

views/
└── products.php (extend - add tab)

database/tenant_migrations/
├── 2025_11_product_graph_binding.php (new)
└── 2025_11_product_graph_binding_backfill.php (new)
```

---

## 🧪 Testing Quick Reference

### Unit Test Example
```php
public function testGetActiveBinding() {
    $binding = ProductGraphBindingHelper::getActiveBinding(15, 'hatthasilpa');
    $this->assertNotNull($binding);
    $this->assertEquals(7, $binding['id_graph']);
}
```

### Integration Test Example
```php
public function testMOUsesProductGraph() {
    $mo = createMO(['id_product' => 15]);
    $this->assertEquals(7, $mo['id_graph']); // From product binding
}
```

---

## ⚠️ Error Response Reference

### Standard Error Response Format

All API endpoints follow consistent error response format:

```json
{
  "ok": false,
  "error": "error_code",
  "app_code": "MODULE_HTTP_ERRORCODE",
  "message": "Human-readable error message",
  "meta": {
    "field": "field_name",
    "details": "Additional context"
  }
}
```

### Error Scenarios & Responses

| Scenario | HTTP Code | Error Code | App Code | Example Response |
|----------|-----------|------------|----------|------------------|
| Product not found | 404 | `product_not_found` | `PRODUCT_404_NOT_FOUND` | `{ "ok": false, "error": "product_not_found", "app_code": "PRODUCT_404_NOT_FOUND", "message": "Product with ID 15 not found" }` |
| Graph not found | 404 | `graph_not_found` | `GRAPH_404_NOT_FOUND` | `{ "ok": false, "error": "graph_not_found", "app_code": "GRAPH_404_NOT_FOUND", "message": "Graph with ID 7 not found" }` |
| Graph unpublished | 400 | `graph_unpublished` | `GRAPH_400_UNPUBLISHED` | `{ "ok": false, "error": "graph_unpublished", "app_code": "GRAPH_400_UNPUBLISHED", "message": "Graph is not published. Only published graphs can be bound to products." }` |
| Version not found | 400 | `version_not_found` | `GRAPH_VER_400_NOT_FOUND` | `{ "ok": false, "error": "version_not_found", "app_code": "GRAPH_VER_400_NOT_FOUND", "message": "Version 2.3 not found for graph 7" }` |
| Duplicate binding | 409 | `binding_conflict` | `BIND_409_CONFLICT` | `{ "ok": false, "error": "binding_conflict", "app_code": "BIND_409_CONFLICT", "message": "Active binding already exists for this product and mode" }` |
| Invalid mode | 400 | `invalid_mode` | `PRODUCT_400_INVALID_MODE` | `{ "ok": false, "error": "invalid_mode", "app_code": "PRODUCT_400_INVALID_MODE", "message": "Invalid production mode. Must be hatthasilpa, classic, or hybrid." }` |
| Permission denied | 403 | `permission_denied` | `PERM_403_DENIED` | `{ "ok": false, "error": "permission_denied", "app_code": "PERM_403_DENIED", "message": "You do not have permission to manage product graph bindings" }` |
| Feature disabled | 503 | `feature_disabled` | `PRODUCT_503_FEATURE_DISABLED` | `{ "ok": false, "error": "feature_disabled", "app_code": "PRODUCT_503_FEATURE_DISABLED", "message": "Product-Graph Binding feature is currently disabled" }` |
| Validation failed | 400 | `validation_failed` | `PRODUCT_400_VALIDATION` | `{ "ok": false, "error": "validation_failed", "app_code": "PRODUCT_400_VALIDATION", "errors": [{ "field": "id_graph", "message": "Graph ID is required" }] }` |
| Binding not found | 404 | `binding_not_found` | `BIND_404_NOT_FOUND` | `{ "ok": false, "error": "binding_not_found", "app_code": "BIND_404_NOT_FOUND", "message": "Binding with ID 42 not found" }` |
| Version comparison failed | 400 | `version_comparison_failed` | `GRAPH_VER_400_COMPARE` | `{ "ok": false, "error": "version_comparison_failed", "app_code": "GRAPH_VER_400_COMPARE", "message": "Cannot compare versions: v1 or v2 not found" }` |

### Error Handling Best Practices

```php
// In API endpoints
try {
    // Validate input
    if (empty($productId)) {
        json_error('product_not_found', 404, [
            'app_code' => 'PRODUCT_404_NOT_FOUND',
            'message' => 'Product ID is required'
        ]);
        return;
    }
    
    // Check feature flag
    if (!defined('PRODUCT_GRAPH_BINDING_ENABLED') || !PRODUCT_GRAPH_BINDING_ENABLED) {
        json_error('feature_disabled', 503, [
            'app_code' => 'PRODUCT_503_FEATURE_DISABLED'
        ]);
        return;
    }
    
    // Check permission
    if (!hasPermission('product.graph.manage')) {
        json_error('permission_denied', 403, [
            'app_code' => 'PERM_403_DENIED',
            'message' => 'You do not have permission to manage product graph bindings'
        ]);
        return;
    }
    
    // Business logic...
    
} catch (\Throwable $e) {
    error_log("Product Graph Binding Error: " . $e->getMessage());
    json_error('internal_error', 500, [
        'app_code' => 'PRODUCT_500_INTERNAL',
        'message' => 'An internal error occurred'
    ]);
    return;
}
```

### Frontend Error Handling

```javascript
// In product_graph_binding.js
$.post('source/products.php', payload, function(resp) {
    if (resp.ok) {
        // Success
        notifySuccess('Binding saved successfully');
    } else {
        // Handle specific error codes
        switch(resp.app_code) {
            case 'PRODUCT_404_NOT_FOUND':
                notifyError('Product not found');
                break;
            case 'GRAPH_400_UNPUBLISHED':
                notifyError('Graph must be published before binding');
                break;
            case 'BIND_409_CONFLICT':
                notifyError('Active binding already exists. Please deactivate existing binding first.');
                break;
            case 'PERM_403_DENIED':
                notifyError('You do not have permission to perform this action');
                break;
            case 'PRODUCT_503_FEATURE_DISABLED':
                notifyError('This feature is currently disabled');
                break;
            default:
                notifyError(resp.message || resp.error || 'An error occurred');
        }
    }
}, 'json').fail(function(jqXHR) {
    // Network error
    notifyError('Network error. Please check your connection.');
});
```

---

## ⚠️ Common Pitfalls

1. **Don't auto-update existing MOs/Job Tickets** - Only apply to NEW ones
2. **Always check graph is published** - Can't bind unpublished graphs
3. **Tenant isolation** - Always filter by `id_org`
4. **Version validation** - Check version exists before pinning
5. **Multiple bindings** - Only one active per product+mode
6. **Feature Flag Check** - Always check `PRODUCT_GRAPH_BINDING_ENABLED` before API operations
7. **Cache Invalidation** - Clear cache when graphs are published/updated
8. **Source Tracking** - Always set `source` field (manual/migration/api/system)

---

## 🚀 Phase Checklist

### Phase 8.1: Foundation
- [ ] Migration files created
- [ ] Tables created
- [ ] Permissions added
- [ ] Basic API implemented
- [ ] UI tab added

### Phase 8.2: Integration
- [ ] MO auto-selects graph
- [ ] Job Ticket inherits graph
- [ ] Override permission works

### Phase 8.3: Version Management
- [ ] Version pinning works
- [ ] Graph preview displays
- [ ] Version comparison available

### Phase 8.4: Statistics
- [ ] Usage stats display
- [ ] Audit trail complete
- [ ] Metrics tracked

---

**Last Updated:** 2025-11-12


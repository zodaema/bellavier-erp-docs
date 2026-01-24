# Task 27.19: Product Readiness System

> **Created:** 2025-12-06  
> **Status:** ✅ CTO APPROVED  
> **Priority:** 🔴 CRITICAL (Core system dependency)

---

## 🎯 CTO Decisions (2025-12-06)

| # | Decision | Detail |
|---|----------|--------|
| 1 | Components Validation | มี ≥1 Component + ทุก Component มี ≥1 Material |
| 2 | Badge | แสดง ✅ หลังชื่อเฉพาะ Product ที่ Ready, ไม่พร้อมไม่แสดงอะไร |
| 3 | Dropdown | Not Ready แสดง disabled + "(รอตั้งค่า)" |
| 4 | History | ไม่ track readiness history แต่ log config changes แยก |

---

## 🎯 หลักการสำคัญ (CTO)

> "Product เป็น Core ของทุกอย่างในระบบ ถ้า Config ไม่ครบ จะทำให้ระบบอื่นๆ ล้มเป็นโดมิโน่"

**กฎ:**
- Product ต้อง Config ครบ 100% จึงจะได้ **Badge ติ๊กถูก** ✅
- Product ที่ไม่ ready จะ **ไม่แสดง** ใน dropdown ของหน้าสร้าง Job/MO

---

## 📊 Audit: สิ่งที่มีอยู่แล้ว

| Service | Purpose | Location |
|---------|---------|----------|
| `ProductDependencyScanner` | Scan dependencies ก่อน delete | `source/BGERP/Product/` |
| `ProductMetadataResolver` | Resolve production line, routing | `source/BGERP/Product/` |
| `ProductionRulesService` | Validate qty, schedule, binding | `source/BGERP/Service/` |
| `ProductGraphBindingHelper` | Validate graph binding | `source/BGERP/Helper/` |

---

## 📊 Audit: สิ่งที่ยังไม่มี

| รายการ | ผลกระทบ |
|--------|---------|
| **Product Readiness Check** | ไม่รู้ว่า product config ครบหรือยัง |
| **Product Readiness Badge** | User ไม่เห็นว่า product พร้อมใช้งานหรือไม่ |
| **Block Job/MO Creation** | สร้าง job ได้แม้ product ไม่ ready → ระบบพัง |
| **Readiness Score / Checklist** | ไม่รู้ว่าขาดอะไร |

---

## 🔗 Dependency Map: Product → Systems

```
┌──────────────────────────────────────────────────────────────────┐
│                    PRODUCT READINESS MATRIX                       │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  PRODUCT CONFIG                 DOWNSTREAM SYSTEMS               │
│  ─────────────────────          ────────────────────────         │
│                                                                  │
│  ☐ Graph Binding               → Job Creation                   │
│     └─ id_graph                   └─ TokenLifecycleService      │
│     └─ production_line            └─ GraphInstanceService       │
│                                   └─ Serial Number Generation    │
│                                                                  │
│  ☐ Component Mapping           → Token Routing                  │
│     └─ anchor_slot → PC           └─ Component branches          │
│                                   └─ QC Rework V2 (component)    │
│                                   └─ MCI (Missing Component)     │
│                                                                  │
│  ☐ Product Components          → BOM & Material                  │
│     └─ component_type_code        └─ Material Requirement        │
│     └─ component_code             └─ Inventory Reservation       │
│                                   └─ Cost Calculation            │
│                                                                  │
│  ☐ Component Materials (BOM)   → Inventory                      │
│     └─ material_sku               └─ Stock Deduction             │
│     └─ qty_required               └─ Material Tracking           │
│                                   └─ Purchase Planning           │
│                                                                  │
│  ☐ Production Line             → Workflow                       │
│     └─ hatthasilpa | classic      └─ ProductionRulesService      │
│                                   └─ Permission checks           │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🚨 Impact Matrix: ถ้าไม่ Config จะเกิดอะไร

| Missing Config | System Impact | Error |
|----------------|---------------|-------|
| **No Graph Binding** | Job creation fails | "No START node found" |
| **No Component Mapping** | Token stuck at component node | "No mapping for anchor_slot" |
| **No Product Components** | BOM calculation fails | "No components for product" |
| **No BOM Materials** | Material reservation fails | "No materials to reserve" |
| **Wrong Production Line** | Wrong workflow applied | Permission denied |

---

## ✅ Product Readiness Checklist (Pass/Fail — 100% Required)

### Hatthasilpa Production

| # | Check | Field/Table | Query |
|---|-------|-------------|-------|
| 1 | Production Line = hatthasilpa | `product.production_line` | `= 'hatthasilpa'` |
| 2 | Graph Binding exists | `product_graph_binding` | `WHERE id_product = ?` |
| 3 | Graph is published | `routing_graph.status` | `= 'published'` |
| 4 | Graph has START node | `routing_node.node_type` | `= 'start'` |
| 5 | Product Components ≥ 1 | `product_component` | `COUNT(*) >= 1` |
| 6 | Every Component has ≥ 1 Material | `product_component_material` | All components have materials |
| 7 | Component Mapping complete | `graph_component_mapping` | All anchor_slots mapped |

**Ready = ผ่านทั้ง 7 ข้อ**  
**Not Ready = ขาดข้อใดข้อหนึ่ง**

### Classic Production

| # | Check | Field/Table | Query |
|---|-------|-------------|-------|
| 1 | Production Line = classic | `product.production_line` | `= 'classic'` |
| 2 | (Optional) Graph Binding | `product_graph_binding` | For DAG mode |

**Ready = ข้อ 1 ผ่าน** (Classic มี requirements น้อยกว่า)

---

## 🛠️ Proposed: ProductReadinessService

### Location

`source/BGERP/Service/ProductReadinessService.php`

### Methods

```php
<?php
namespace BGERP\Service;

class ProductReadinessService
{
    /**
     * Get complete readiness status for a product
     * 
     * @param int $productId
     * @return array [
     *   'is_ready' => bool,
     *   'score' => int (0-100),
     *   'checklist' => [...],
     *   'blocking_issues' => [...],
     *   'warnings' => [...]
     * ]
     */
    public function getReadinessStatus(int $productId): array;
    
    /**
     * Check if product is ready for job creation
     * 
     * @param int $productId
     * @param string $productionType 'hatthasilpa' | 'classic'
     * @return array ['ready' => bool, 'errors' => [...]]
     */
    public function canCreateJob(int $productId, string $productionType): array;
    
    /**
     * Get list of ready products for job/MO creation
     * 
     * @param string $productionType
     * @return array List of product IDs that are ready
     */
    public function getReadyProducts(string $productionType): array;
    
    /**
     * Get readiness badge HTML for product list
     * 
     * @param int $productId
     * @return string HTML badge
     */
    public function getReadinessBadge(int $productId): string;
}
```

---

## 📊 Readiness Logic (Pass/Fail)

```php
// ✅ CTO Decision: No scoring, just Pass/Fail

public function isReady(int $productId, string $productionType): array
{
    $checks = [];
    
    if ($productionType === 'hatthasilpa') {
        $checks = [
            'production_line' => $this->checkProductionLine($productId, 'hatthasilpa'),
            'graph_binding' => $this->hasGraphBinding($productId),
            'graph_published' => $this->isGraphPublished($productId),
            'graph_has_start' => $this->graphHasStartNode($productId),
            'has_components' => $this->hasComponents($productId),
            'components_have_materials' => $this->allComponentsHaveMaterials($productId),
            'mapping_complete' => $this->isMappingComplete($productId),
        ];
    } else {
        // Classic: simpler requirements
        $checks = [
            'production_line' => $this->checkProductionLine($productId, 'classic'),
        ];
    }
    
    $failed = array_filter($checks, fn($v) => !$v);
    
    return [
        'ready' => empty($failed),
        'checks' => $checks,
        'failed' => array_keys($failed)
    ];
}
```

---

## 🖥️ UI: Product List with Badge

**✅ CTO Decision:** แสดง ✅ เฉพาะ Product ที่ Ready, ไม่พร้อมไม่แสดงอะไร

```
┌──────────────────────────────────────────────────────────────────┐
│  PRODUCT LIST                                                     │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  SKU          Name                     Line        Status        │
│  ─────────────────────────────────────────────────────────────   │
│  AM-2025     Aimee Mini Greentea ✅    Hatthasilpa  Active        │
│  AM-2025B   Aimee Mini Blue ✅         Hatthasilpa  Active        │
│  TC-001     Tote Classic              Classic      Active        │  ← ไม่มี badge
│  TC-002     Tote Bucket               Classic      Draft         │  ← ไม่มี badge
│                                                                  │
│  ✅ = พร้อมใช้งาน (Ready for production)                          │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🖥️ UI: Job/MO Creation - Product Dropdown

**✅ CTO Decision:** Not Ready แสดง disabled + "(รอตั้งค่า)"

```
┌──────────────────────────────────────────────────────────────────┐
│  CREATE HATTHASILPA JOB                                          │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  เลือกสินค้า:                                                     │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ ▼ เลือกสินค้า...                                           │  │
│  ├────────────────────────────────────────────────────────────┤  │
│  │   AM-2025 - Aimee Mini Greentea ✅                         │  │  ← เลือกได้
│  │   AM-2025B - Aimee Mini Blue ✅                            │  │  ← เลือกได้
│  │   ──────────────────────────────────────────────────────   │  │
│  │   TC-001 - Tote Classic (รอตั้งค่า)        [disabled]     │  │  ← เลือกไม่ได้
│  │   TC-002 - Tote Bucket (รอตั้งค่า)         [disabled]     │  │  ← เลือกไม่ได้
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**HTML:**
```html
<option value="101">AM-2025 - Aimee Mini Greentea ✅</option>
<option value="102">AM-2025B - Aimee Mini Blue ✅</option>
<option disabled value="103">TC-001 - Tote Classic (รอตั้งค่า)</option>
<option disabled value="104">TC-002 - Tote Bucket (รอตั้งค่า)</option>
```

---

## 🔧 Integration Points

### 1. Block Job Creation

**File:** `source/hatthasilpa_jobs_api.php`

```php
// BEFORE creating job
$readinessService = new ProductReadinessService($db);
$readiness = $readinessService->canCreateJob($productId, 'hatthasilpa');

if (!$readiness['ready']) {
    json_error(
        translate('job.error.product_not_ready', 'Product is not ready for production'),
        400,
        [
            'app_code' => 'JOB_400_PRODUCT_NOT_READY',
            'errors' => $readiness['errors'],
            'readiness' => $readiness
        ]
    );
}
```

### 2. Block MO Creation

**File:** `source/mo.php`

```php
// BEFORE creating MO
$readinessService = new ProductReadinessService($db);
$readiness = $readinessService->canCreateJob($productId, 'classic');

if (!$readiness['ready']) {
    json_error(
        translate('mo.error.product_not_ready', 'Product is not ready for production'),
        400,
        ['app_code' => 'MO_400_PRODUCT_NOT_READY', 'errors' => $readiness['errors']]
    );
}
```

### 3. Product List Badge

**File:** `source/products.php` (list action)

```php
// Add readiness info to each product
foreach ($products as &$product) {
    $readiness = $readinessService->getReadinessStatus($product['id_product']);
    $product['is_ready'] = $readiness['is_ready'];
    $product['readiness_score'] = $readiness['score'];
    $product['readiness_badge'] = $readinessService->getReadinessBadge($product['id_product']);
}
```

### 4. Product Dropdown Filter

**File:** `source/product_api.php` (new action)

```php
case 'get_ready_products':
    $productionType = $_GET['production_type'] ?? 'hatthasilpa';
    $readinessService = new ProductReadinessService($tenantDb);
    $products = $readinessService->getReadyProducts($productionType);
    json_success(['products' => $products]);
    break;
```

---

## 📋 Implementation Steps

| # | Task | Time |
|---|------|------|
| 1 | Migration: Create `product_config_log` table | 15 min |
| 2 | Create `ProductReadinessService` | 1 hour |
| 3 | Add logging to Product config actions | 45 min |
| 4 | Add readiness checks to Job creation | 30 min |
| 5 | Add readiness checks to MO creation | 30 min |
| 6 | Add ✅ badge to Product list UI | 20 min |
| 7 | Update Product dropdown (disabled + รอตั้งค่า) | 30 min |
| 8 | Testing | 30 min |
| **Total** | | **~4.5 hours** |

---

## 🔄 Relationship with Task 27.13.12

Task 27.13.12 (Component Mapping Refactor) is a **prerequisite** for this task:

- **27.13.12** fixes the mapping structure (`id_product_component`)
- **27.19** adds readiness validation that uses the fixed mapping

**Order:** 27.13.12 → 27.19

---

## 📝 Product Config Change Log

**✅ CTO Decision:** ไม่ track readiness history แต่ต้อง log ว่าใครตั้งค่าอะไร

### New Table: `product_config_log`

```sql
CREATE TABLE product_config_log (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_product INT NOT NULL,
    
    -- What changed
    config_type ENUM(
        'graph_binding',
        'component_mapping',
        'product_component',
        'component_material',
        'production_line'
    ) NOT NULL,
    
    action ENUM('create', 'update', 'delete') NOT NULL,
    
    -- Details
    old_value JSON NULL COMMENT 'Previous value (for update/delete)',
    new_value JSON NULL COMMENT 'New value (for create/update)',
    
    -- Who & When
    changed_by INT NOT NULL COMMENT 'FK to account.id_member',
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Context
    ip_address VARCHAR(45) NULL,
    user_agent VARCHAR(255) NULL,
    
    INDEX idx_product (id_product),
    INDEX idx_changed_at (changed_at),
    INDEX idx_config_type (config_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Audit log for product configuration changes';
```

### Log Entry Examples

```json
// Graph Binding created
{
    "id_product": 101,
    "config_type": "graph_binding",
    "action": "create",
    "new_value": {"id_graph": 1952, "id_binding": 55},
    "changed_by": 5
}

// Component Material added
{
    "id_product": 101,
    "config_type": "component_material",
    "action": "create",
    "new_value": {"id_product_component": 10, "material_sku": "LTH-001", "qty": 0.5},
    "changed_by": 5
}
```

---

*Created: 2025-12-06*  
*Author: AI Agent*  
*Pending: CTO Review*


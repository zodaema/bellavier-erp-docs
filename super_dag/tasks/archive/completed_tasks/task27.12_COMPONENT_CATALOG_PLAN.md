# 27.12 Component Catalog - Implementation Plan

> **Feature:** Standardized Component Dictionary for Enterprise  
> **Priority:** 🔴 CRITICAL (Foundation for everything)  
> **Estimated Duration:** 3-4 Days (~26 hours)  
> **Dependencies:** None (First task)  
> **Spec:** `01-concepts/COMPONENT_CATALOG_SPEC.md`

---

## 📊 Implementation Overview

```
┌─────────────────────────────────────────────────────────────────┐
│              COMPONENT CATALOG: FOUNDATION LAYER                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Day 1: Database Layer                                          │
│  ├─ 27.12.1 Migration: component_catalog table                 │
│  └─ 27.12.2 Migration: product_component_mapping table         │
│                                                                 │
│  Day 2: Service Layer                                           │
│  ├─ 27.12.3 ComponentCatalogService (CRUD + validation)        │
│  └─ 27.12.4 API Endpoints (CRUD)                               │
│                                                                 │
│  Day 3: Data + API                                              │
│  ├─ 27.12.5 API: get_components_for_product                    │
│  └─ 27.12.6 Seed: Common components (20+)                      │
│                                                                 │
│  Day 4: UI + Tests                                              │
│  ├─ 27.12.7 Admin UI: Catalog management page                  │
│  └─ 27.12.8 Tests: Unit + Integration                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 Task Details

---

### 27.12.1 Database Migration: component_catalog

**Duration:** 2 hours

**File:** `database/tenant_migrations/2025_12_component_catalog.php`

**Schema:**

```sql
CREATE TABLE component_catalog (
    id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Identity
    component_code VARCHAR(50) NOT NULL UNIQUE 
        COMMENT 'Unique code e.g. STRAP_LONG, BODY_MAIN_PANEL',
    
    -- Display (i18n)
    display_name_th VARCHAR(100) NOT NULL 
        COMMENT 'Thai display name',
    display_name_en VARCHAR(100) NOT NULL 
        COMMENT 'English display name',
    
    -- Classification
    component_group VARCHAR(30) NOT NULL 
        COMMENT 'Group: BODY, STRAP, FLAP, POCKET, LINING, HARDWARE, TRIM',
    component_category VARCHAR(30) NULL 
        COMMENT 'Category: STRUCTURAL, DECORATIVE, FUNCTIONAL',
    
    -- Metadata
    description TEXT NULL,
    icon_code VARCHAR(50) NULL 
        COMMENT 'Icon identifier for UI',
    display_order INT DEFAULT 0 
        COMMENT 'Sort order within group',
    
    -- Status
    is_active TINYINT(1) DEFAULT 1,
    
    -- Audit
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT NULL,
    updated_by INT NULL,
    
    -- Indexes
    INDEX idx_group (component_group),
    INDEX idx_category (component_category),
    INDEX idx_active (is_active),
    INDEX idx_display_order (component_group, display_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 
  COMMENT='Standardized component dictionary';
```

**Validation Rules (enforce in service, not schema):**

```
┌─────────────────────────────────────────────────────────────────┐
│              COMPONENT_CODE PATTERN                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Pattern: ^[A-Z][A-Z0-9_]*$                                     │
│  Max Length: 50 characters                                      │
│                                                                 │
│  ✅ VALID: STRAP_LONG, BODY_MAIN_PANEL, HARDWARE_ZIPPER         │
│  ❌ INVALID: strap_long (lowercase), Body Main (spaces)        │
│                                                                 │
│  Enforce in: ComponentCatalogService::validate()               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Standard Groups (Single Source of Truth):**

```php
// In ComponentCatalogService
public const VALID_GROUPS = [
    'BODY', 'STRAP', 'FLAP', 'POCKET', 
    'LINING', 'HARDWARE', 'TRIM'
];

public const VALID_CATEGORIES = [
    'STRUCTURAL', 'FUNCTIONAL', 'DECORATIVE'
];
```

**Deliverables:**
- [ ] Migration file created
- [ ] Migration runs successfully
- [ ] Table exists in tenant DB

---

### 27.12.2 Database Migration: product_component_mapping

**Duration:** 2 hours

**File:** `database/tenant_migrations/2025_12_product_component_mapping.php`

**Schema:**

```sql
CREATE TABLE product_component_mapping (
    id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Product Reference
    product_id INT NOT NULL 
        COMMENT 'FK to product/pattern table',
    
    -- Component Reference
    component_code VARCHAR(50) NOT NULL 
        COMMENT 'FK to component_catalog',
    
    -- Configuration
    is_required TINYINT(1) DEFAULT 1 
        COMMENT '1=must have, 0=optional',
    default_qty INT DEFAULT 1 
        COMMENT 'Default quantity per product',
    display_order INT DEFAULT 0 
        COMMENT 'Assembly order',
    
    -- Audit
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Constraints
    UNIQUE KEY uk_product_component (product_id, component_code),
    INDEX idx_product (product_id),
    INDEX idx_component (component_code),
    
    FOREIGN KEY (component_code) 
        REFERENCES component_catalog(component_code) 
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 
  COMMENT='Maps products to their required components';
```

**Deliverables:**
- [ ] Migration file created
- [ ] FK constraint works
- [ ] Can insert sample mappings

---

### 27.12.3 Service: ComponentCatalogService

**Duration:** 4 hours

**File:** `source/BGERP/Service/ComponentCatalogService.php`

**Methods:**

```php
<?php
declare(strict_types=1);

namespace BGERP\Service;

class ComponentCatalogService
{
    private \mysqli $db;
    
    public function __construct(\mysqli $db)
    {
        $this->db = $db;
    }
    
    // ==================== CATALOG CRUD ====================
    
    /**
     * Get all active components grouped by component_group
     * @return array ['BODY' => [...], 'STRAP' => [...], ...]
     */
    public function getAllGrouped(): array;
    
    /**
     * Get single component by code
     * @param string $code
     * @return array|null
     */
    public function getByCode(string $code): ?array;
    
    /**
     * Create new component
     * @param array $data
     * @return int Component ID
     * @throws \InvalidArgumentException
     */
    public function create(array $data): int;
    
    /**
     * Update existing component
     * @param string $code
     * @param array $data
     * @return bool
     */
    public function update(string $code, array $data): bool;
    
    /**
     * Soft-delete (deactivate) component
     * @param string $code
     * @return bool
     */
    public function deactivate(string $code): bool;
    
    // ==================== VALIDATION ====================
    
    /**
     * Check if component code exists and is active
     * @param string $code
     * @return bool
     */
    public function isValidCode(string $code): bool;
    
    /**
     * Validate component data before create/update
     * @param array $data
     * @param bool $isUpdate
     * @return array ['valid' => bool, 'errors' => [...]]
     * 
     * Checks:
     * - component_code: required, pattern ^[A-Z][A-Z0-9_]*$, max 50
     * - display_name_th: required, not empty
     * - display_name_en: required, not empty
     * - component_group: required, in VALID_GROUPS
     * - component_category: optional, if set must be in VALID_CATEGORIES
     */
    public function validate(array $data, bool $isUpdate = false): array;
    
    // ==================== PRODUCT MAPPING ====================
    
    /**
     * Get components for a specific product
     * @param int $productId
     * @return array Empty array if no mappings (never throws)
     * 
     * Note: JOIN with component_catalog to include display names:
     *       SELECT m.*, c.display_name_th, c.display_name_en, c.component_group
     *       FROM product_component_mapping m
     *       JOIN component_catalog c ON c.component_code = m.component_code
     *       WHERE m.product_id = ? AND c.is_active = 1
     *       ORDER BY m.display_order
     */
    public function getComponentsForProduct(int $productId): array;
    
    /**
     * Get required components for a product
     * @param int $productId
     * @return array
     */
    public function getRequiredComponentsForProduct(int $productId): array;
    
    /**
     * Map component to product
     * @param int $productId
     * @param string $componentCode
     * @param array $options ['is_required', 'default_qty', 'display_order']
     * @return int Mapping ID
     * @throws \InvalidArgumentException If component already mapped (duplicate)
     * 
     * Note: Catch UNIQUE constraint violation and convert to readable error:
     *       "Component 'STRAP_LONG' is already mapped to this product"
     */
    public function mapToProduct(int $productId, string $componentCode, array $options = []): int;
    
    /**
     * Remove component mapping from product
     * @param int $productId
     * @param string $componentCode
     * @return bool
     */
    public function unmapFromProduct(int $productId, string $componentCode): bool;
    
    // ==================== HELPERS ====================
    
    /**
     * Get all component groups
     * @return array ['BODY', 'STRAP', 'FLAP', ...]
     */
    public function getGroups(): array;
    
    /**
     * Search components by name/code
     * @param string $query
     * @param int $limit
     * @return array
     */
    public function search(string $query, int $limit = 20): array;
}
```

**Deliverables:**
- [ ] Service file created
- [ ] All methods implemented
- [ ] Prepared statements used
- [ ] Error handling complete

---

### 27.12.4 API: CRUD Endpoints

**Duration:** 4 hours

**File:** `source/component_catalog_api.php`

**Endpoints:**

| Action | Method | Description |
|--------|--------|-------------|
| `list` | GET | Get all components (grouped) |
| `get` | GET | Get single component by code |
| `create` | POST | Create new component |
| `update` | POST | Update existing component |
| `delete` | POST | Deactivate component |
| `search` | GET | Search components |
| `groups` | GET | Get all groups |

**API Structure:**

```php
<?php
session_start();
require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/global_function.php';
require_once __DIR__ . '/model/member_class.php';
require_once __DIR__ . '/permission.php';
require_once __DIR__ . '/BGERP/Service/ComponentCatalogService.php';

header('Content-Type: application/json');

// Authentication
$objMemberDetail = new memberDetail();
$member = $objMemberDetail->thisLogin();
if (!$member) { 
    json_error(translate('common.error.unauthorized', 'Unauthorized'), 401); 
}

// Tenant DB
$tenantDb = tenant_db();

// Service
$catalogService = new \BGERP\Service\ComponentCatalogService($tenantDb);

// Action routing
$action = $_REQUEST['action'] ?? '';

switch ($action) {
    case 'list':
        // Rate limit
        RateLimiter::check($member, 120, 60, 'component_catalog_list');
        
        $grouped = $catalogService->getAllGrouped();
        json_success(['catalog' => $grouped]);
        break;
        
    case 'get':
        $code = trim($_GET['code'] ?? '');
        if (empty($code)) {
            json_error(translate('common.error.missing_param', 'Missing code'), 400);
        }
        
        $component = $catalogService->getByCode($code);
        if (!$component) {
            json_error(translate('common.error.not_found', 'Component not found'), 404);
        }
        
        json_success(['component' => $component]);
        break;
        
    case 'create':
        must_allow('component.catalog.manage');
        
        // Validate
        $validation = $catalogService->validate($_POST, false);
        if (!$validation['valid']) {
            json_error(implode(', ', $validation['errors']), 400);
        }
        
        // Idempotency
        $idempotencyKey = $_SERVER['HTTP_X_IDEMPOTENCY_KEY'] ?? null;
        if ($idempotencyKey) {
            $cached = Idempotency::check($idempotencyKey, 'component_create');
            if ($cached) {
                json_success($cached, 200);
                return;
            }
        }
        
        $id = $catalogService->create($_POST);
        
        $response = ['id' => $id, 'message' => translate('common.success.created', 'Created')];
        
        if ($idempotencyKey) {
            Idempotency::store($idempotencyKey, $response, 201);
        }
        
        json_success($response, 201);
        break;
        
    case 'update':
        must_allow('component.catalog.manage');
        
        $code = trim($_POST['code'] ?? '');
        if (empty($code)) {
            json_error(translate('common.error.missing_param', 'Missing code'), 400);
        }
        
        $validation = $catalogService->validate($_POST, true);
        if (!$validation['valid']) {
            json_error(implode(', ', $validation['errors']), 400);
        }
        
        $success = $catalogService->update($code, $_POST);
        
        json_success(['message' => translate('common.success.updated', 'Updated')]);
        break;
        
    case 'delete':
        must_allow('component.catalog.manage');
        
        $code = trim($_POST['code'] ?? '');
        if (empty($code)) {
            json_error(translate('common.error.missing_param', 'Missing code'), 400);
        }
        
        // Soft-delete (deactivate) - component still exists but is_active = 0
        $success = $catalogService->deactivate($code);
        
        // Use "Deactivated" to make soft-delete behavior clear
        json_success(['message' => translate('component.success.deactivated', 'Deactivated')]);
        break;
        
    case 'search':
        $query = trim($_GET['q'] ?? '');
        $limit = min((int)($_GET['limit'] ?? 20), 50);
        $includeInactive = (bool)($_GET['include_inactive'] ?? false);
        
        // Default: search active only
        // Pass include_inactive=1 to search all
        $results = $catalogService->search($query, $limit, $includeInactive);
        json_success(['results' => $results]);
        break;
        
    case 'groups':
        $groups = $catalogService->getGroups();
        json_success(['groups' => $groups]);
        break;
        
    default:
        json_error(translate('common.error.invalid_action', 'Invalid action'), 400);
}
```

**Deliverables:**
- [ ] API file created
- [ ] All actions implemented
- [ ] Rate limiting applied
- [ ] Idempotency for create
- [ ] Permission checks

**Permission Note:**
```
Permission: component.catalog.manage

Required for: create, update, delete, map_to_product, unmap_from_product

TODO: Add to permission map in platform_permission table
      (separate task, not part of this implementation)
```

**Enterprise API Compliance (Per DEVELOPER_POLICY.md):**
```php
// ⚠️ REQUIRED for update action - ETag/If-Match pattern:
case 'update':
    // Check If-Match header for optimistic locking
    $ifMatch = $_SERVER['HTTP_IF_MATCH'] ?? null;
    $currentEtag = md5($component['updated_at']);
    
    if ($ifMatch && $ifMatch !== $currentEtag) {
        json_error(
            translate('common.error.conflict', 'Record has been modified'),
            409,
            ['app_code' => 'ETAG_MISMATCH']
        );
    }
    
    // ... update logic ...
    
    // Return new ETag in response
    header('ETag: ' . md5($newUpdatedAt));
```

---

### 27.12.5 API: get_components_for_product

**Duration:** 2 hours

**Add to:** `source/component_catalog_api.php`

**Endpoints:**

```php
case 'product_components':
    $productId = (int)($_GET['product_id'] ?? 0);
    if ($productId <= 0) {
        json_error(translate('common.error.missing_param', 'Missing product_id'), 400);
    }
    
    $components = $catalogService->getComponentsForProduct($productId);
    json_success(['components' => $components]);
    break;

case 'product_required_components':
    $productId = (int)($_GET['product_id'] ?? 0);
    if ($productId <= 0) {
        json_error(translate('common.error.missing_param', 'Missing product_id'), 400);
    }
    
    $components = $catalogService->getRequiredComponentsForProduct($productId);
    json_success(['components' => $components]);
    break;

case 'map_to_product':
    must_allow('component.catalog.manage');
    
    $productId = (int)($_POST['product_id'] ?? 0);
    $componentCode = trim($_POST['component_code'] ?? '');
    
    if ($productId <= 0 || empty($componentCode)) {
        json_error(translate('common.error.missing_param', 'Missing product_id or component_code'), 400);
    }
    
    $options = [
        'is_required' => (bool)($_POST['is_required'] ?? true),
        'default_qty' => (int)($_POST['default_qty'] ?? 1),
        'display_order' => (int)($_POST['display_order'] ?? 0)
    ];
    
    $id = $catalogService->mapToProduct($productId, $componentCode, $options);
    json_success(['id' => $id, 'message' => translate('common.success.mapped', 'Mapped')]);
    break;

case 'unmap_from_product':
    must_allow('component.catalog.manage');
    
    $productId = (int)($_POST['product_id'] ?? 0);
    $componentCode = trim($_POST['component_code'] ?? '');
    
    if ($productId <= 0 || empty($componentCode)) {
        json_error(translate('common.error.missing_param', 'Missing product_id or component_code'), 400);
    }
    
    $success = $catalogService->unmapFromProduct($productId, $componentCode);
    json_success(['message' => translate('common.success.unmapped', 'Unmapped')]);
    break;
```

**Deliverables:**
- [ ] Product mapping endpoints added
- [ ] Validation complete
- [ ] Works with MCI fallback logic

---

### 27.12.6 Seed: Common Components

**Duration:** 2 hours

**File:** `database/tenant_migrations/2025_12_seed_component_catalog.php`

**Seed Data:**

```php
<?php
/**
 * Migration: Seed Component Catalog
 * Seeds 20+ common components for leather goods manufacturing
 */

return function (mysqli $db): void {
    
    $components = [
        // BODY Group
        ['BODY_MAIN_PANEL', 'แผ่นตัวกระเป๋าหลัก', 'Main Body Panel', 'BODY', 'STRUCTURAL', 10],
        ['BODY_BACK_PANEL', 'แผ่นหลังกระเป๋า', 'Back Body Panel', 'BODY', 'STRUCTURAL', 20],
        ['GUSSET_SIDE', 'ข้างกระเป๋า', 'Side Gusset', 'BODY', 'STRUCTURAL', 30],
        ['GUSSET_BOTTOM', 'ก้นกระเป๋า', 'Bottom Gusset', 'BODY', 'STRUCTURAL', 40],
        
        // STRAP Group
        ['STRAP_LONG', 'สายสะพายยาว', 'Long Shoulder Strap', 'STRAP', 'FUNCTIONAL', 10],
        ['STRAP_SHORT', 'สายคล้องสั้น', 'Short Handle Strap', 'STRAP', 'FUNCTIONAL', 20],
        ['STRAP_HANDLE', 'หูหิ้ว', 'Top Handle', 'STRAP', 'FUNCTIONAL', 30],
        ['STRAP_WRIST', 'สายคล้องข้อมือ', 'Wrist Strap', 'STRAP', 'FUNCTIONAL', 40],
        
        // FLAP Group
        ['FLAP_MAIN', 'ฝาปิดหลัก', 'Main Flap', 'FLAP', 'STRUCTURAL', 10],
        ['FLAP_POCKET', 'ฝากระเป๋าหน้า', 'Pocket Flap', 'FLAP', 'STRUCTURAL', 20],
        
        // POCKET Group
        ['POCKET_FRONT', 'กระเป๋าหน้า', 'Front Pocket', 'POCKET', 'FUNCTIONAL', 10],
        ['POCKET_BACK', 'กระเป๋าหลัง', 'Back Pocket', 'POCKET', 'FUNCTIONAL', 20],
        ['POCKET_INTERNAL', 'กระเป๋าใน', 'Internal Pocket', 'POCKET', 'FUNCTIONAL', 30],
        ['POCKET_ZIPPER', 'กระเป๋าซิป', 'Zipper Pocket', 'POCKET', 'FUNCTIONAL', 40],
        
        // LINING Group
        ['LINING_MAIN', 'ซับในหลัก', 'Main Lining', 'LINING', 'STRUCTURAL', 10],
        ['LINING_POCKET', 'ซับในกระเป๋า', 'Pocket Lining', 'LINING', 'STRUCTURAL', 20],
        
        // HARDWARE Group
        ['HARDWARE_ZIPPER', 'ซิป', 'Zipper', 'HARDWARE', 'FUNCTIONAL', 10],
        ['HARDWARE_BUCKLE', 'หัวเข็มขัด', 'Buckle', 'HARDWARE', 'DECORATIVE', 20],
        ['HARDWARE_CLASP', 'ตะขอล็อค', 'Clasp', 'HARDWARE', 'FUNCTIONAL', 30],
        ['HARDWARE_RING', 'ห่วงโลหะ', 'Metal Ring', 'HARDWARE', 'FUNCTIONAL', 40],
        
        // TRIM Group
        ['TRIM_PIPING', 'เส้นไปป์ปิ้ง', 'Piping Trim', 'TRIM', 'DECORATIVE', 10],
        ['TRIM_EDGE_TAPE', 'เทปขอบ', 'Edge Tape', 'TRIM', 'DECORATIVE', 20],
        ['TRIM_BINDING', 'ขอบผ้า', 'Binding', 'TRIM', 'DECORATIVE', 30],
    ];
    
    $stmt = $db->prepare("
        INSERT IGNORE INTO component_catalog 
        (component_code, display_name_th, display_name_en, component_group, component_category, display_order)
        VALUES (?, ?, ?, ?, ?, ?)
    ");
    
    foreach ($components as $c) {
        $stmt->bind_param('sssssi', $c[0], $c[1], $c[2], $c[3], $c[4], $c[5]);
        $stmt->execute();
    }
    
    $stmt->close();
    
    error_log("[Migration] Seeded " . count($components) . " components to catalog");
};
```

**Deliverables:**
- [ ] 23+ components seeded
- [ ] All groups represented
- [ ] Thai + English names
- [ ] Categories assigned

---

### 27.12.7 Admin UI: Catalog Management

**Duration:** 6 hours

**Files:**
- `page/component_catalog.php` - Page definition
- `views/component_catalog.php` - HTML template
- `assets/javascripts/component/catalog.js` - JavaScript

**Features:**

```
┌─────────────────────────────────────────────────────────────────┐
│              COMPONENT CATALOG MANAGEMENT UI                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [+ Add Component]                              [🔍 Search...]  │
│                                                                 │
│  ┌─ Filter by Group ─────────────────────────────────────────┐ │
│  │ [All] [BODY] [STRAP] [FLAP] [POCKET] [LINING] [HARDWARE]  │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌─ Components Table ────────────────────────────────────────┐ │
│  │ Code          │ Name (TH)      │ Name (EN)    │ Group     │ │
│  ├───────────────┼────────────────┼──────────────┼───────────┤ │
│  │ STRAP_LONG    │ สายสะพายยาว    │ Long Strap   │ STRAP     │ │
│  │ BODY_MAIN     │ ตัวกระเป๋าหลัก   │ Main Body    │ BODY      │ │
│  │ ...           │ ...            │ ...          │ ...       │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  [Edit] [Delete]                                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Deliverables:**
- [ ] DataTable with server-side processing
- [ ] Filter by group
- [ ] Search functionality
- [ ] Create/Edit modal
- [ ] Delete confirmation
- [ ] i18n compliant (no hardcoded Thai in JS)

**Implementation Notes:**

```javascript
// Group dropdown should use API, not hardcode
async function loadGroupOptions() {
    const response = await fetch('/source/component_catalog_api.php?action=groups');
    const data = await response.json();
    if (data.ok) {
        populateGroupDropdown(data.groups);
    }
}

// Reuse this component in:
// - Product Config UI (product_component_mapping)
// - Graph Designer (anchor_slot mapping)
```

---

### 27.12.8 Tests: Unit + Integration

**Duration:** 4 hours

**Files:**
- `tests/Unit/ComponentCatalogServiceTest.php`
- `tests/Integration/ComponentCatalogApiTest.php`

**Test Cases:**

```php
// Unit Tests
class ComponentCatalogServiceTest extends TestCase
{
    // CRUD
    public function testCreateComponent(): void;
    public function testCreateDuplicateCodeFails(): void;
    public function testUpdateComponent(): void;
    public function testDeactivateComponent(): void;
    
    // Validation
    public function testIsValidCodeReturnsTrue(): void;
    public function testIsValidCodeReturnsFalseForInactive(): void;
    public function testValidateRejectsLowercaseCode(): void;
    public function testValidateRejectsInvalidGroup(): void;
    public function testValidateRejectsEmptyDisplayName(): void;
    
    // Query
    public function testGetAllGroupedReturnsCorrectStructure(): void;
    public function testGetAllGroupedExcludesInactive(): void;
    public function testSearchFindsByCode(): void;
    public function testSearchFindsByName(): void;
    public function testSearchDefaultExcludesInactive(): void;
    
    // Mapping
    public function testMapToProduct(): void;
    public function testMapToProductDuplicateReturnsReadableError(): void; // NEW
    public function testGetComponentsForProduct(): void;
    public function testGetComponentsForProductReturnsEmptyArrayWhenNoMapping(): void; // NEW
    public function testGetComponentsForProductJoinsDisplayNames(): void; // NEW
    public function testUnmapFromProduct(): void;
}

// Integration Tests
class ComponentCatalogApiTest extends TestCase
{
    public function testListReturnsGroupedComponents(): void;
    public function testGetReturnsComponent(): void;
    public function testGet404ForInvalidCode(): void;
    public function testCreateRequiresPermission(): void;
    public function testCreateValidatesInput(): void;
    public function testCreateSucceeds(): void;
    public function testUpdateSucceeds(): void;
    public function testDeleteDeactivatesNotHardDelete(): void; // Clarified
    public function testSearchReturnsResults(): void;
    public function testSearchDefaultActiveOnly(): void; // NEW
    public function testProductMappingWorks(): void;
    public function testProductMappingDuplicateReturnsError(): void; // NEW
}
```

**Deliverables:**
- [ ] 18+ unit tests (including new validation/mapping tests)
- [ ] 12+ integration tests
- [ ] All tests passing
- [ ] 80%+ coverage

---

## ✅ Definition of Done

- [ ] `component_catalog` table exists with indexes
- [ ] `product_component_mapping` table exists with FK
- [ ] `ComponentCatalogService` with all methods
- [ ] Validation: component_code pattern, group validation
- [ ] API with CRUD + search + product mapping
- [ ] Search defaults to active-only
- [ ] Duplicate mapping returns readable error
- [ ] 23+ components seeded (all groups)
- [ ] Admin UI functional (uses API for group list)
- [ ] Permission `component.catalog.manage` registered
- [ ] 30+ tests passing
- [ ] Documentation updated

---

## 🔗 Dependencies

**This task blocks:**
- 27.13 Component Node Type (needs catalog for validation)
- 27.14 Defect Catalog (needs allowed_components)
- 27.17 MCI (needs catalog for component validation)

---

## 📚 Related Documents

- [COMPONENT_CATALOG_SPEC.md](../01-concepts/COMPONENT_CATALOG_SPEC.md)
- [MASTER_IMPLEMENTATION_ROADMAP.md](./MASTER_IMPLEMENTATION_ROADMAP.md)
- [QC_REWORK_PHILOSOPHY_V2.md](../01-concepts/QC_REWORK_PHILOSOPHY_V2.md)


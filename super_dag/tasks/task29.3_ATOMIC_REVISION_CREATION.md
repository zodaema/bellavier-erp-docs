# Task 29.3: Atomic Revision Creation Flow

**Status:** ✅ **COMPLETE**  
**Priority:** 🔴 **CRITICAL**  
**Phase:** 0 (Foundation)  
**Estimate:** 1 day  
**Depends On:** Task 29.1 (Data Model), Task 29.2 (Invariants)

---

## Goal

สร้าง revision ใหม่แบบไม่เกิด inconsistent state (All-or-Nothing)

---

## Problem Statement

ถ้า revision creation ไม่เป็น atomic:
- อาจมี partial revision ค้างอยู่
- Snapshot อาจไม่ตรงกับ components
- Lineage อาจขาดตอน
- ระบบอาจ reference revision ที่ยังไม่สมบูรณ์

---

## Scope

### 1. Atomic Operation Definition

**Create Revision = Single Transaction:**

```
BEGIN TRANSACTION
    1. Load current product state
    2. Validate invariants
    3. Load components + constraints
    4. Get explicit graph version ID
    5. Build snapshot JSON
    6. Build components JSON
    7. Generate next version number
    8. Insert into product_revision (status='draft')
    9. Log creation event
COMMIT

IF ANY STEP FAILS:
    ROLLBACK
    THROW ERROR
```

### 2. Steps in Detail

#### Step 1: Load Current Product State
- Load from `product` table
- Capture all fields for snapshot

#### Step 2: Validate Invariants
- Use `ProductRevisionInvariantsValidator`
- If invalid → ABORT immediately (before transaction)

#### Step 3: Load Components + Constraints
- Load from `product_component_material`
- Include all constraint JSON
- Include computed quantities

#### Step 4: Get Explicit Graph Version ID
- **Critical:** Must be explicit version, not "active"
- If product has graph binding → get current active graph version
- Store as `graph_version_id` (frozen reference)

#### Step 5: Build Snapshot JSON
```json
{
    "product": { ... },
    "snapshot_at": "2026-01-15T10:30:00Z"
}
```

#### Step 6: Build Components JSON
```json
{
    "components": [ ... ],
    "snapshot_at": "2026-01-15T10:30:00Z"
}
```

#### Step 7: Generate Next Version Number
- Pattern: "1.0", "2.0", "3.0"
- Based on `MAX(version) + 1` for this product

#### Step 8: Insert Revision
- All fields populated
- Status = 'draft'
- `derived_from_revision_id` = parent revision (if applicable)

#### Step 9: Log Creation
- Audit trail
- Creator, timestamp, reason

---

## Agent Must Think About

### 1. Transaction Boundary

**Entire operation inside single transaction:**

```php
$this->db->begin_transaction();
try {
    // All steps here
    $this->db->commit();
} catch (\Throwable $e) {
    $this->db->rollback();
    throw $e;
}
```

### 2. What Data is Cloned vs Referenced

| Data | Cloned (Copy) | Referenced (FK) |
|------|---------------|-----------------|
| Product metadata | ✅ (snapshot_json) | - |
| Components | ✅ (components_json) | - |
| Constraints | ✅ (in components_json) | - |
| Graph version | - | ✅ (graph_version_id FK) |
| Creator | - | ✅ (created_by FK) |

### 3. Snapshot Timing

**Snapshot NOW, not later:**
- Snapshot is created at revision creation time
- Not lazily computed
- Guarantees point-in-time accuracy

### 4. Derived From Logic

| Scenario | derived_from_revision_id |
|----------|--------------------------|
| First revision (v1.0) | `NULL` |
| Creating from active revision | Active revision ID |
| Creating from specific revision | That revision ID |

---

## Deliverables

### 1. ProductRevisionService Class

```php
namespace BGERP\Service;

class ProductRevisionService {
    
    private \mysqli $db;
    private ProductRevisionInvariantsValidator $invariantsValidator;
    
    public function __construct(\mysqli $db) {
        $this->db = $db;
        $this->invariantsValidator = new ProductRevisionInvariantsValidator($db);
    }
    
    /**
     * Create new revision from current product state
     * 
     * @param int $productId Product ID
     * @param int $userId Creator user ID
     * @param string $reasonCode Revision reason (ENUM)
     * @param string|null $notes Human-readable notes
     * @param int|null $derivedFromId Parent revision ID (null for v1.0)
     * @return array Created revision data
     * @throws InvariantViolationException
     * @throws RevisionCreationException
     */
    public function createRevision(
        int $productId,
        int $userId,
        string $reasonCode,
        ?string $notes = null,
        ?int $derivedFromId = null
    ): array {
        
        // Step 1: Load product (pre-transaction validation)
        $product = $this->loadProduct($productId);
        if (!$product) {
            throw new RevisionCreationException("Product not found: {$productId}");
        }
        
        // Step 2: Validate invariants (pre-transaction)
        $snapshotData = $this->buildProductSnapshot($product);
        $invariantsCheck = $this->invariantsValidator->validate($productId, $snapshotData['product']);
        
        if (!$invariantsCheck['valid']) {
            throw new InvariantViolationException(
                'Revision invariants violated',
                $invariantsCheck['violations']
            );
        }
        
        // Begin atomic operation
        $this->db->begin_transaction();
        
        try {
            // Step 3: Load components
            $components = $this->loadComponents($productId);
            
            // Step 4: Get explicit graph version
            $graphVersionId = $this->getActiveGraphVersionId($productId);
            
            // Step 5-6: Build JSON snapshots
            $snapshotJson = json_encode($snapshotData, JSON_UNESCAPED_UNICODE);
            $componentsJson = json_encode([
                'components' => $components,
                'snapshot_at' => $this->now()
            ], JSON_UNESCAPED_UNICODE);
            
            // Step 7: Generate version number
            $version = $this->generateNextVersion($productId);
            
            // Step 8: Insert revision
            $stmt = $this->db->prepare("
                INSERT INTO product_revision (
                    id_product,
                    version,
                    derived_from_revision_id,
                    revision_reason,
                    revision_notes,
                    status,
                    allow_new_jobs,
                    graph_version_id,
                    snapshot_json,
                    components_json,
                    created_at,
                    created_by,
                    row_version
                ) VALUES (?, ?, ?, ?, ?, 'draft', 1, ?, ?, ?, NOW(), ?, 1)
            ");
            
            $stmt->bind_param(
                'isissiisi',
                $productId,
                $version,
                $derivedFromId,
                $reasonCode,
                $notes,
                $graphVersionId,
                $snapshotJson,
                $componentsJson,
                $userId
            );
            
            if (!$stmt->execute()) {
                throw new RevisionCreationException("Failed to insert revision: " . $stmt->error);
            }
            
            $revisionId = $this->db->insert_id;
            
            // Step 9: Log creation
            $this->logRevisionCreation($revisionId, $userId, $reasonCode);
            
            $this->db->commit();
            
            return $this->loadRevision($revisionId);
            
        } catch (\Throwable $e) {
            $this->db->rollback();
            throw new RevisionCreationException(
                "Revision creation failed: " . $e->getMessage(),
                0,
                $e
            );
        }
    }
    
    private function generateNextVersion(int $productId): string {
        $stmt = $this->db->prepare("
            SELECT MAX(CAST(SUBSTRING_INDEX(version, '.', 1) AS UNSIGNED)) as max_major
            FROM product_revision 
            WHERE id_product = ?
        ");
        $stmt->bind_param('i', $productId);
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();
        
        $nextMajor = ($row['max_major'] ?? 0) + 1;
        return $nextMajor . '.0';
    }
    
    private function buildProductSnapshot(array $product): array {
        return [
            'product' => [
                'id_product' => $product['id_product'],
                'sku' => $product['sku'] ?? null,
                'name' => $product['name'] ?? null,
                'uom_base' => $product['uom_base'] ?? null,
                'material_category' => $product['material_category'] ?? null,
                'inventory_accounting_method' => $product['inventory_accounting_method'] ?? null,
                'traceability_level' => $product['traceability_level'] ?? null,
            ],
            'snapshot_at' => $this->now()
        ];
    }
    
    private function loadComponents(int $productId): array {
        $stmt = $this->db->prepare("
            SELECT 
                pcm.*,
                m.name as material_name,
                m.sku as material_sku
            FROM product_component_material pcm
            LEFT JOIN material m ON m.id_material = pcm.id_material
            WHERE pcm.id_product = ?
            ORDER BY pcm.sequence
        ");
        $stmt->bind_param('i', $productId);
        $stmt->execute();
        $result = $stmt->get_result();
        return $result->fetch_all(MYSQLI_ASSOC);
    }
    
    private function getActiveGraphVersionId(int $productId): ?int {
        // Get graph binding for product, then get active version
        $stmt = $this->db->prepare("
            SELECT pgb.id_graph, rgv.id_version
            FROM product_graph_binding pgb
            JOIN routing_graph_version rgv ON rgv.id_graph = pgb.id_graph 
                AND rgv.status = 'published' 
                AND rgv.allow_new_jobs = 1
            WHERE pgb.id_product = ?
            ORDER BY rgv.published_at DESC
            LIMIT 1
        ");
        $stmt->bind_param('i', $productId);
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();
        
        return $row['id_version'] ?? null;
    }
    
    private function now(): string {
        return date('Y-m-d\TH:i:s\Z');
    }
    
    // ... other methods
}
```

### 2. Rollback Behavior

On any failure:
- Transaction rolls back
- No partial revision exists
- Original data unchanged
- Clear error message returned

### 3. Exception Classes

```php
namespace BGERP\Exception;

class InvariantViolationException extends \Exception {
    private array $violations;
    
    public function __construct(string $message, array $violations) {
        parent::__construct($message);
        $this->violations = $violations;
    }
    
    public function getViolations(): array {
        return $this->violations;
    }
}

class RevisionCreationException extends \Exception {}
```

---

## Acceptance Criteria

- [ ] Revision creation is atomic (all-or-nothing)
- [ ] No partial revision can exist
- [ ] Invariants validated before transaction
- [ ] Graph version explicitly captured (not "active" reference)
- [ ] Snapshot captured at creation time
- [ ] Version number generated correctly
- [ ] Lineage tracked via `derived_from_revision_id`
- [ ] Rollback works correctly on failure
- [ ] Audit log created

---

## Test Cases

### 1. Successful Creation

```php
$revision = $service->createRevision(
    productId: 123,
    userId: 1,
    reasonCode: 'OPTIMIZATION',
    notes: 'Improved material usage',
    derivedFromId: null  // First version
);

// Assert: revision exists with status='draft'
// Assert: version = '1.0'
// Assert: snapshot_json contains product data
```

### 2. Creation with Lineage

```php
$v1 = $service->createRevision(123, 1, 'INITIAL');
$service->publishRevision($v1['id_revision'], 1);

$v2 = $service->createRevision(
    productId: 123,
    userId: 1,
    reasonCode: 'FIX_ERROR',
    derivedFromId: $v1['id_revision']
);

// Assert: v2.derived_from_revision_id = v1.id_revision
// Assert: v2.version = '2.0'
```

### 3. Rollback on Failure

```php
// Mock: component loading fails
// Assert: no revision created
// Assert: transaction rolled back
// Assert: exception thrown with clear message
```

### 4. Invariant Violation Abort

```php
// Setup: product.uom_base = 'PCS'
// Attempt: create revision with uom_base = 'KG'
// Assert: InvariantViolationException thrown
// Assert: no revision created
```

---

## Reference Files

- `source/dag/Graph/Service/GraphVersionService.php` - `publish()` method
- `source/service/DatabaseTransaction.php` - Transaction pattern
- `docs/super_dag/06-specs/OPERATIONAL_SAFETY_CHANGE_GOVERNANCE.md` - SPEC

---

**Next Task:** 29.4 (Revision Lineage & Intent Enforcement)

---

## Results

- `docs/super_dag/tasks/results/task29.3.results.md`

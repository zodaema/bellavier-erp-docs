# Task 29.2: Define Revision Invariants Validation

**Status:** ✅ **COMPLETE**  
**Priority:** 🔴 **CRITICAL**  
**Phase:** 0 (Foundation)  
**Estimate:** 0.5 day  
**Depends On:** Task 29.1 (Data Model)

---

## Goal

ป้องกัน revision กลายเป็น "product ใหม่เงียบๆ" โดยบังคับให้ invariant fields เหมือนกันทุก revision

---

## Problem Statement

ถ้าไม่มี invariants validation:
- Revision v2 อาจเปลี่ยน `uom_base` จาก `PCS` เป็น `KG`
- ทำให้ inventory calculations ผิดพลาด
- ทำให้ historical data ไม่สามารถเปรียบเทียบได้

**SAP Rule:** Fields like Base UoM, Material Type require a **new Material Master**, not a Change Number.

---

## Scope

### 1. Formalize List of Invariant Fields

| Field | Location | Reason | SAP Equivalent |
|-------|----------|--------|----------------|
| `sku` | Product | External reference | Material Number |
| `uom_base` | Product | Inventory consistency | Base Unit of Measure |
| `material_category` | Product | Accounting logic | Material Type |
| `inventory_accounting_method` | Product | Costing consistency | Valuation Class |
| `traceability_level` | Product | Lot/Serial tracking | Serialization Profile |

### 2. Define Validation Rules

**Rule:** When creating/updating a revision, validate that invariant fields match the product's original values.

```
FOR EACH revision:
    revision.snapshot.sku == product.sku
    revision.snapshot.uom_base == product.uom_base
    revision.snapshot.material_category == product.material_category
    revision.snapshot.inventory_accounting_method == product.inventory_accounting_method
    revision.snapshot.traceability_level == product.traceability_level
```

### 3. Error Semantics

**When invariant violated:**
- Return structured error
- Error code: `PRD_400_INVARIANT_VIOLATION`
- Clear message: "Cannot change {field} between revisions. Create a new product instead."
- List all violations (not just first)

---

## Agent Must Think About

### 1. Where Validation Should Live

**Recommended: Service Layer**

```php
// ProductRevisionService.php
public function validateInvariants(int $productId, array $snapshotData): array {
    $product = $this->loadProduct($productId);
    
    $invariants = [
        'sku',
        'uom_base', 
        'material_category',
        'inventory_accounting_method',
        'traceability_level'
    ];
    
    $violations = [];
    
    foreach ($invariants as $field) {
        $productValue = $product[$field] ?? null;
        $snapshotValue = $snapshotData[$field] ?? null;
        
        if ($productValue !== $snapshotValue) {
            $violations[] = [
                'field' => $field,
                'product_value' => $productValue,
                'snapshot_value' => $snapshotValue,
                'message' => "Cannot change {$field} between revisions. Create a new product instead."
            ];
        }
    }
    
    return [
        'valid' => empty($violations),
        'violations' => $violations
    ];
}
```

### 2. When to Validate

| Operation | Validate Invariants? |
|-----------|---------------------|
| Create revision | ✅ Yes |
| Publish revision | ✅ Yes (double-check) |
| Update draft revision | ✅ Yes |
| Retire revision | ❌ No |

### 3. Edge Cases

1. **First Revision (v1.0):**
   - No previous revision to compare
   - Compare directly against product table
   - Always valid if product fields match

2. **Product Fields Change:**
   - ❌ Should NOT be allowed if product has revisions
   - Need separate validation for product update

3. **Null Values:**
   - `null === null` is valid
   - `null !== 'value'` is violation

---

## Deliverables

### 1. Invariants Validator Class

```php
namespace BGERP\Service;

class ProductRevisionInvariantsValidator {
    
    private const INVARIANT_FIELDS = [
        'sku',
        'uom_base',
        'material_category',
        'inventory_accounting_method',
        'traceability_level'
    ];
    
    public function __construct(private \mysqli $db) {}
    
    /**
     * Validate that snapshot data matches product invariants
     */
    public function validate(int $productId, array $snapshotData): array {
        $product = $this->loadProduct($productId);
        
        if (!$product) {
            return [
                'valid' => false,
                'violations' => [['field' => 'id_product', 'message' => 'Product not found']]
            ];
        }
        
        $violations = [];
        
        foreach (self::INVARIANT_FIELDS as $field) {
            $productValue = $product[$field] ?? null;
            $snapshotValue = $snapshotData[$field] ?? null;
            
            if ($productValue !== $snapshotValue) {
                $violations[] = [
                    'field' => $field,
                    'product_value' => $productValue,
                    'snapshot_value' => $snapshotValue,
                    'message' => sprintf(
                        'Cannot change %s between revisions (product: %s, snapshot: %s). Create a new product instead.',
                        $field,
                        $productValue ?? 'null',
                        $snapshotValue ?? 'null'
                    )
                ];
            }
        }
        
        return [
            'valid' => empty($violations),
            'violations' => $violations
        ];
    }
    
    /**
     * Check if product can have its invariant fields changed
     */
    public function canChangeProductInvariants(int $productId): bool {
        // Can only change invariants if no revisions exist
        $count = $this->countRevisions($productId);
        return $count === 0;
    }
    
    private function loadProduct(int $productId): ?array {
        $stmt = $this->db->prepare("SELECT * FROM product WHERE id_product = ?");
        $stmt->bind_param('i', $productId);
        $stmt->execute();
        $result = $stmt->get_result();
        return $result->fetch_assoc();
    }
    
    private function countRevisions(int $productId): int {
        $stmt = $this->db->prepare("SELECT COUNT(*) as cnt FROM product_revision WHERE id_product = ?");
        $stmt->bind_param('i', $productId);
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();
        return (int)$row['cnt'];
    }
}
```

### 2. Integration Point

```php
// In ProductRevisionService::createRevision()
public function createRevision(...) {
    // Step 1: Validate invariants BEFORE creating
    $invariantsCheck = $this->invariantsValidator->validate($productId, $snapshotData);
    
    if (!$invariantsCheck['valid']) {
        throw new InvariantViolationException(
            'Revision invariants violated',
            $invariantsCheck['violations']
        );
    }
    
    // Step 2: Proceed with creation
    // ...
}
```

### 3. API Error Response

```json
{
    "ok": false,
    "error": "Revision invariants violated",
    "app_code": "PRD_400_INVARIANT_VIOLATION",
    "violations": [
        {
            "field": "uom_base",
            "product_value": "PCS",
            "snapshot_value": "KG",
            "message": "Cannot change uom_base between revisions. Create a new product instead."
        }
    ]
}
```

---

## Acceptance Criteria

- [ ] Invariant fields list formalized
- [ ] Validator class implemented
- [ ] Validation runs on revision create/update
- [ ] Clear error messages with all violations
- [ ] Product invariant changes blocked if revisions exist
- [ ] Edge cases handled (first revision, null values)

---

## Test Cases

### 1. Valid Revision (Invariants Match)

```php
// Product: sku=P001, uom_base=PCS
// Snapshot: sku=P001, uom_base=PCS
// Result: valid=true
```

### 2. Invalid Revision (UoM Changed)

```php
// Product: sku=P001, uom_base=PCS
// Snapshot: sku=P001, uom_base=KG
// Result: valid=false, violation on uom_base
```

### 3. Multiple Violations

```php
// Product: sku=P001, uom_base=PCS, material_category=FG
// Snapshot: sku=P002, uom_base=KG, material_category=RM
// Result: valid=false, 3 violations
```

### 4. First Revision (v1.0)

```php
// No previous revision
// Snapshot must match product
// Result: follows same rule
```

### 5. Product Update Blocked

```php
// Product has 2 revisions
// Attempt to change product.uom_base
// Result: blocked with clear error
```

---

## Reference Files

- `docs/super_dag/06-specs/OPERATIONAL_SAFETY_CHANGE_GOVERNANCE.md` - Section 10 (Invariants)
- `source/service/ValidationService.php` - Validation pattern
- `source/dag/Graph/Service/GraphVersionService.php` - Template

---

**Next Task:** 29.3 (Atomic Revision Creation Flow)

---

## Results

- `docs/super_dag/tasks/results/task29.2.results.md`

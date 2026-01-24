# Negative Waste Factor Policy - FINAL

**Date:** January 4, 2026  
**Status:** ✅ **LOCKED - Enterprise Policy**  
**Decision:** REJECT negative waste values  
**Impact:** Enterprise-grade data integrity + BOM costing accuracy

---

## Policy Statement

**waste_factor_percent: 0 ≤ value ≤ 200**

- **Negative values = INVALID** (rejected at validation layer)
- **Values > 200% = INVALID** (rejected at validation layer)
- **Error code:** `V3_VALIDATION_WASTE_INVALID`

---

## Rationale (Enterprise-Grade)

1. **Semantic Clarity:** "Waste" means "extra material needed" - cannot be negative
2. **Data Integrity:** Prevents accidental data entry errors
3. **BOM Costing:** Negative waste would reduce material cost, which is counter-intuitive
4. **Audit Trail:** Clear rejection = clear audit trail
5. **User Experience:** Clear error messages prevent confusion

---

## Implementation

### Validation Layer

**Location:** `BGERP\Service\BomQuantityCalculator::validateConstraintsCompleteness()`

```php
// Validate waste_factor_percent: must be >= 0 (REJECT negative values)
if (isset($constraints['waste_factor_percent'])) {
    $waste = (float)$constraints['waste_factor_percent'];
    if ($waste < 0) {
        $invalidFields['waste_factor_percent'] = 'Waste factor cannot be negative (must be >= 0)';
    }
    if ($waste > 200) {
        $invalidFields['waste_factor_percent'] = 'Waste factor cannot exceed 200% (must be <= 200)';
    }
}

return [
    'valid' => $isValid,
    'missing_fields' => $missingFields,
    'invalid_fields' => $invalidFields  // NEW: Invalid field values
];
```

### Response Format

```json
{
  "ok": false,
  "error": "Validation failed",
  "app_code": "V3_VALIDATION_WASTE_INVALID",
  "invalid_fields": {
    "waste_factor_percent": "Waste factor cannot be negative (must be >= 0)"
  }
}
```

---

## Test Coverage

**Test:** `BomQuantityCalculatorTest::testNegativeWasteFactorValidation()`

```php
public function testNegativeWasteFactorValidation(): void
{
    $constraints = [
        'waste_factor_percent' => -10  // INVALID
    ];
    
    $validation = BomQuantityCalculator::validateConstraintsCompleteness('AREA', $constraints);
    
    $this->assertFalse($validation['valid']);
    $this->assertArrayHasKey('invalid_fields', $validation);
    $this->assertArrayHasKey('waste_factor_percent', $validation['invalid_fields']);
}
```

---

## UI Validation

- **Client-side:** Disable Save button if `waste_factor_percent < 0`
- **Highlight:** Red border on waste_factor_percent input
- **Message:** "Waste factor must be between 0% and 200%"
- **Server-side:** Reject with HTTP 400 + error code

---

## If Business Needs Material Savings Later

- **Option:** Add `material_savings_percent` field (0-100%)
- **Option:** Use override mode with audit log (requires reason)
- **NEVER:** Allow negative waste as "backdoor" for savings

---

## Migration Notes

- **Existing data:** If any records have negative waste, need data migration
- **Validation:** Add check in `MaterialRoleValidationService` if needed
- **API:** Update error responses to include `invalid_fields`

---

## Status

✅ **Policy Locked** - January 4, 2026  
✅ **Implementation Complete** - January 4, 2026  
✅ **Tests Updated** - January 4, 2026  
✅ **Documentation Updated** - January 4, 2026

---

**Decision Maker:** System Architecture Team  
**Implementation Date:** January 4, 2026  
**Review Date:** Not scheduled (Enterprise standard)

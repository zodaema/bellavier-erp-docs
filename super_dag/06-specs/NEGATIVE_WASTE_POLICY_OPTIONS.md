# Negative Waste Factor Policy - Decision Options

**Date:** January 4, 2026  
**Status:** 📋 **DECISION REQUIRED**  
**Impact:** Enterprise-grade data integrity + BOM costing accuracy

---

## Problem Statement

Currently, `BomQuantityCalculator::compute()` accepts negative `waste_factor_percent` values without validation. Negative waste reduces computed quantity (e.g., -10% waste = 90% of base quantity).

**Questions:**
1. Should negative waste be **rejected** (strict validation)?
2. Should negative waste be **allowed** (with warnings/logging)?
3. What is the business meaning of "negative waste"?

---

## Option 1: REJECT Negative Waste (Recommended for Enterprise)

### Policy
- **waste_factor_percent: 0 ≤ value ≤ 200** (0% to 200% waste)
- Negative values = **INVALID** (rejected at validation layer)
- Error code: `V3_VALIDATION_WASTE_NEGATIVE`

### Rationale
1. **Semantic Clarity:** "Waste" means "extra material needed" - cannot be negative
2. **Data Integrity:** Prevents accidental data entry errors
3. **BOM Costing:** Negative waste would reduce material cost, which is counter-intuitive
4. **Audit Trail:** Clear rejection = clear audit trail

### Implementation
```php
// In validateConstraintsCompleteness() or MaterialRoleValidationService
if (isset($constraints['waste_factor_percent'])) {
    $waste = (float)$constraints['waste_factor_percent'];
    if ($waste < 0) {
        return [
            'valid' => false,
            'errors' => ['waste_factor_percent' => 'Waste factor cannot be negative'],
            'app_code' => 'V3_VALIDATION_WASTE_NEGATIVE'
        ];
    }
    if ($waste > 200) {
        return [
            'valid' => false,
            'errors' => ['waste_factor_percent' => 'Waste factor cannot exceed 200%'],
            'app_code' => 'V3_VALIDATION_WASTE_EXCESSIVE'
        ];
    }
}
```

### Test Changes Required
- Test 19: Change from "compute with negative waste" → "reject negative waste"
- Add test: `testNegativeWasteRejected()`
- Remove test: `testNegativeWasteFactorValidation()` (or rename to rejection test)

### Impact
- ✅ **Data Integrity:** HIGH (prevents invalid data)
- ✅ **User Experience:** Clear error messages
- ✅ **Maintenance:** Simple, explicit policy
- ⚠️ **Backward Compatibility:** If existing data has negative waste, need migration

---

## Option 2: ALLOW Negative Waste (with Logging/Warning)

### Policy
- **waste_factor_percent: -100 < value ≤ 200** (allows negative, but not -100% or less)
- Negative values = **ALLOWED** but **LOGGED** as unusual
- Warning flag in API response: `waste_factor_warning: "Negative waste reduces quantity"`

### Rationale
1. **Flexibility:** Some edge cases might need "material savings" concept
2. **User Control:** Let users decide (with warnings)
3. **Edge Cases:** May be needed for optimization scenarios

### Implementation
```php
// In compute() methods
$wasteFactor = isset($constraints['waste_factor_percent']) ? (float)$constraints['waste_factor_percent'] : 0.0;

if ($wasteFactor < 0) {
    error_log(sprintf(
        '[BOM] Negative waste factor detected: material_id=%d, waste=%.2f%%, qty_reduction=%.2f%%',
        $materialId ?? 0,
        $wasteFactor,
        abs($wasteFactor)
    ));
}

// Computation continues (no rejection)
$qty *= (1 + $wasteFactor / 100);
```

### Test Changes Required
- Test 19: Keep as-is (test that negative waste computes correctly)
- Add test: `testNegativeWasteWarningLogged()`
- Document: Negative waste is "allowed but unusual"

### Impact
- ⚠️ **Data Integrity:** MEDIUM (allows potentially incorrect data)
- ⚠️ **User Experience:** Confusing (what does negative waste mean?)
- ⚠️ **Maintenance:** Complex (need logging, warnings, documentation)
- ✅ **Backward Compatibility:** No breaking changes

---

## Option 3: HYBRID - Separate "Savings Factor" Field

### Policy
- **waste_factor_percent: 0 ≤ value ≤ 200** (waste = extra material)
- **NEW FIELD:** `material_savings_percent: 0 ≤ value ≤ 100` (savings = less material needed)
- Negative waste = **REJECTED** (use savings field instead)

### Rationale
1. **Semantic Separation:** Waste and Savings are different concepts
2. **Clear Business Logic:** Waste = extra, Savings = reduction
3. **Data Integrity:** Clear, explicit fields

### Implementation
```php
// Validation
if (isset($constraints['waste_factor_percent']) && $constraints['waste_factor_percent'] < 0) {
    return [
        'valid' => false,
        'errors' => [
            'waste_factor_percent' => 'Use material_savings_percent for material reduction'
        ],
        'app_code' => 'V3_VALIDATION_USE_SAVINGS_FIELD'
    ];
}

// Computation
$waste = max(0, (float)($constraints['waste_factor_percent'] ?? 0));
$savings = max(0, min(100, (float)($constraints['material_savings_percent'] ?? 0)));
$qty *= (1 + $waste / 100) * (1 - $savings / 100);
```

### Test Changes Required
- Test 19: Reject negative waste, test savings field separately
- Add tests: `testMaterialSavingsField()`, `testWasteAndSavingsCombined()`
- **Schema Change:** Add `material_savings_percent` to `material_role_field` table (if needed)

### Impact
- ✅ **Data Integrity:** HIGH (clear semantics)
- ⚠️ **Complexity:** HIGH (new field, new logic)
- ⚠️ **Migration:** Requires schema change + data migration
- ✅ **Future-Proof:** Supports both concepts explicitly

---

## Recommendation: **Option 1 (REJECT Negative Waste)**

### Reasons
1. **Enterprise-Grade:** Clear policy = clear audit trail
2. **Semantic Correctness:** "Waste" cannot be negative in production context
3. **Simplicity:** No new fields, no complex logic
4. **User Experience:** Clear error messages prevent confusion
5. **Data Integrity:** Prevents accidental data corruption

### If Business Needs Negative Values Later
- Add `material_savings_percent` field (Option 3) in future phase
- Do NOT allow negative waste as "backdoor" for savings

---

## Decision Checklist

- [ ] Choose option (1, 2, or 3)
- [ ] Update `BomQuantityCalculator::validateConstraintsCompleteness()` or `MaterialRoleValidationService`
- [ ] Update Test 19 to match chosen policy
- [ ] Update API error codes
- [ ] Update documentation (PHASE_1_IMPLEMENTATION.md)
- [ ] Check existing data for negative waste values (if Option 1)
- [ ] Migration plan (if Option 1 + existing data)

---

**Decision Maker:** [To be filled]  
**Decision Date:** [To be filled]  
**Implementation Date:** [To be filled]

# Task 27.10.4: Validate Edge Condition Structure

## Overview

**Status:** Pending  
**Priority:** HIGH  
**Estimated Time:** 1-2 hours  
**Dependencies:** Task 27.10.1, Task 27.10.2, Task 27.10.3  
**Blocks:** None (improvement, not blocking)

---

## Problem Statement

### Current Gap

**GraphValidationEngine only checks if condition exists:**
```php
// Line 744 - Only checks existence
if (!$isDefault && (empty($edgeCondition) || !is_array($edgeCondition))) {
    // Error: CONDITIONAL_EDGE_MISSING_CONDITION
}
```

**Does NOT validate:**
- ❌ Required `type` field
- ❌ `property` for token_property type (not `field`)
- ❌ Valid `operator` values
- ❌ `value` is present

### Impact

| Stage | Wrong Format Condition |
|-------|------------------------|
| **Validator** | ✅ Passes (only checks existence) |
| **Runtime** | ❌ **FAILS!** ConditionEvaluator returns false |

**Example of wrong format that passes validation:**
```json
{
  "field": "qc_result.status",    // ❌ Wrong key
  "operator": "in",
  "value": ["fail_minor"]
  // ❌ Missing "type"
}
```

**Correct format:**
```json
{
  "type": "token_property",       // ✅ Required
  "property": "qc_result.status", // ✅ Correct key
  "operator": "in",
  "value": ["fail_minor"]
}
```

---

## Objective

Add structural validation for `edge_condition` in GraphValidationEngine to catch format errors at design time, not runtime.

---

## Requirements

### R1: Validate Condition Type Field

**File:** `source/BGERP/Dag/GraphValidationEngine.php`
**Method:** `validateConditionalRouting()`

```php
private function validateConditionalRouting(array $nodes, array $edges, array $nodeMap, array $edgeMap): array
{
    // ... existing code ...
    
    if ($edgeType === 'conditional') {
        $edgeCondition = JsonNormalizer::normalizeJsonField($edge, 'edge_condition', null);
        $isDefault = $edge['is_default'] ?? false;
        
        // Existing check: condition must exist
        if (!$isDefault && (empty($edgeCondition) || !is_array($edgeCondition))) {
            $errors[] = [
                'code' => 'CONDITIONAL_EDGE_MISSING_CONDITION',
                // ...
            ];
            continue;
        }
        
        // NEW: Validate condition structure
        if (!$isDefault && is_array($edgeCondition)) {
            $structureErrors = $this->validateConditionStructure($edgeCondition, $edgeCode);
            foreach ($structureErrors as $err) {
                $warnings[] = $err; // Warning not error (don't block save)
            }
        }
    }
}
```

### R2: Create validateConditionStructure() Method

```php
/**
 * Task 27.10.4: Validate edge condition structure
 * 
 * @param array $condition Condition data
 * @param string $edgeCode Edge identifier for error messages
 * @return array Array of warning objects
 */
private function validateConditionStructure(array $condition, string $edgeCode): array
{
    $warnings = [];
    
    $type = $condition['type'] ?? null;
    $validTypes = ['token_property', 'job_property', 'node_property', 'qty_threshold', 'expression', 'default'];
    
    // Check 1: 'type' field is required
    if ($type === null) {
        $warnings[] = [
            'code' => 'CONDITION_MISSING_TYPE',
            'rule' => 'CONDITIONAL_ROUTING',
            'message' => sprintf('Edge "%s" condition missing "type" field. Expected: %s', 
                $edgeCode, implode(' | ', $validTypes)),
            'severity' => 'warning',
            'category' => 'routing',
            'edge' => $edgeCode,
            'suggestion' => 'Add "type": "token_property" for QC conditions.'
        ];
        return $warnings; // Can't validate further without type
    }
    
    // Check 2: 'type' is valid
    if (!in_array($type, $validTypes, true)) {
        $warnings[] = [
            'code' => 'CONDITION_INVALID_TYPE',
            'rule' => 'CONDITIONAL_ROUTING',
            'message' => sprintf('Edge "%s" has invalid condition type "%s".', $edgeCode, $type),
            'severity' => 'warning',
            'category' => 'routing',
            'edge' => $edgeCode,
            'suggestion' => sprintf('Valid types: %s', implode(', ', $validTypes))
        ];
        return $warnings;
    }
    
    // Check 3: Type-specific validation
    if ($type === 'token_property' || $type === 'job_property' || $type === 'node_property') {
        // Must have 'property' (not 'field')
        if (isset($condition['field']) && !isset($condition['property'])) {
            $warnings[] = [
                'code' => 'CONDITION_WRONG_KEY',
                'rule' => 'CONDITIONAL_ROUTING',
                'message' => sprintf('Edge "%s" uses "field" instead of "property".', $edgeCode),
                'severity' => 'warning',
                'category' => 'routing',
                'edge' => $edgeCode,
                'suggestion' => 'Change "field" to "property" in condition.'
            ];
        }
        
        if (!isset($condition['property']) && !isset($condition['field'])) {
            $warnings[] = [
                'code' => 'CONDITION_MISSING_PROPERTY',
                'rule' => 'CONDITIONAL_ROUTING',
                'message' => sprintf('Edge "%s" condition missing "property" field.', $edgeCode),
                'severity' => 'warning',
                'category' => 'routing',
                'edge' => $edgeCode,
                'suggestion' => 'Add "property": "qc_result.status" for QC conditions.'
            ];
        }
        
        // Must have 'operator'
        if (!isset($condition['operator'])) {
            $warnings[] = [
                'code' => 'CONDITION_MISSING_OPERATOR',
                'rule' => 'CONDITIONAL_ROUTING',
                'message' => sprintf('Edge "%s" condition missing "operator" field.', $edgeCode),
                'severity' => 'warning',
                'category' => 'routing',
                'edge' => $edgeCode,
                'suggestion' => 'Add "operator": "==" or "in" for comparison.'
            ];
        }
    }
    
    return $warnings;
}
```

---

## Test Case

**Seed graph (QC_FINAL → ASSEMBLY) intentionally uses wrong format:**
```json
{
  "field": "qc_result.status",    // Wrong key
  "operator": "in",
  "value": ["fail_minor", "fail_major"]
  // Missing "type"
}
```

**After this fix, validation should show:**
- ⚠️ Warning: `CONDITION_MISSING_TYPE` - Edge "Rework" missing "type" field
- ⚠️ Warning: `CONDITION_WRONG_KEY` - Edge "Rework" uses "field" instead of "property"

---

## Acceptance Criteria

1. `validateConditionStructure()` method added to GraphValidationEngine
2. Warns on missing `type` field
3. Warns on `field` instead of `property`
4. Warns on missing `operator` for property-based conditions
5. Does NOT error (only warns) - allow save for backward compatibility
6. Seed graph test case triggers expected warnings

---

## Files to Modify

| File | Changes |
|------|---------|
| `source/BGERP/Dag/GraphValidationEngine.php` | Add `validateConditionStructure()` method |

---

## Results Template

```markdown
## Task 27.10.4 Results

**Completed:** [DATE]
**Time Spent:** [X hours]

### Changes Made
1. Added validateConditionStructure() method
2. Integrated with validateConditionalRouting()

### Test Results
- [ ] Seed graph shows CONDITION_MISSING_TYPE warning
- [ ] Seed graph shows CONDITION_WRONG_KEY warning
- [ ] Correct conditions pass without warnings
- [ ] Validation doesn't block save (warnings only)

### Notes
...
```


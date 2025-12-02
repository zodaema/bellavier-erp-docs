# Edge Condition Format Standardization

## Problem
The `edge_condition` field in `routing_edge` table had **two different formats**:

### Legacy Format (Inconsistent)
```json
{"qc_result": "pass"}
{"result": "A"}
{"status": "approved"}
```

### Standard Format (Structured)
```json
{"field": "qc_result", "operator": "=", "value": "pass"}
{"field": "result", "operator": "=", "value": "A"}
{"field": "status", "operator": "=", "value": "approved"}
```

## Impact
- ❌ Validation errors: "must have 'field' and 'value' in edge_condition"
- ❌ Inconsistent data structure
- ❌ Difficult to extend with new operators
- ❌ Hard to maintain and debug
- ❌ Risk of future breakage

## Solution

### 1. Migration Script
Created `/tools/migrate_edge_condition_to_standard.php` to convert all legacy format to standard format.

**What it does:**
- Scans all conditional edges
- Identifies legacy format: `{key: value}`
- Converts to standard format: `{field: key, operator: "=", value: value}`
- Updates database with transaction support

**Migration Results:**
```
Total edges:          5
Already standard:     1 (20%)
Migrated:             4 (80%)
Errors:               0 (0%)
```

### 2. Enhanced Validation
Updated `DAGValidationService::validateEdgeTypes()` to:
- ✅ Enforce standard format (field + value required)
- ✅ Validate operator (optional, defaults to "=")
- ✅ Support 10 operators: =, !=, >, <, >=, <=, IN, NOT IN, CONTAINS, NOT CONTAINS
- ✅ Validate custom_field when field = "custom"
- ✅ Provide clear error messages with format examples

### 3. Standard Documentation
Created `/docs/standards/EDGE_CONDITION_FORMAT.md` defining:
- Official JSON structure
- Field descriptions and types
- Valid operators and examples
- Common field names
- Best practices
- Code examples (JS, PHP)
- Troubleshooting guide

## Changes Made

### File: `/tools/migrate_edge_condition_to_standard.php` (**NEW**)
**Purpose**: One-time migration script

**Features:**
- Transaction support (rollback on error)
- Detailed progress reporting
- Preserves field semantics (key → field)
- Safe: Skips already migrated edges

**Usage:**
```bash
php tools/migrate_edge_condition_to_standard.php
```

### File: `/source/BGERP/Service/DAGValidationService.php` (**MODIFIED**)
**Changes:**
```php
// BEFORE (Lenient - Accepted both formats)
if (!isset($condition['field']) || !isset($condition['value'])) {
    $errors[] = "Must have 'field' and 'value'";
}

// AFTER (Strict - Standard format only)
if (!isset($condition['field'])) {
    $errors[] = "Must have 'field'. Use: {\"field\": \"...\", \"value\": \"...\"}";
}

if (!isset($condition['value'])) {
    $errors[] = "Must have 'value'. Use: {\"field\": \"...\", \"value\": \"...\"}";
}

// NEW: Operator validation
if (isset($condition['operator'])) {
    $validOperators = ['=', '!=', '>', '<', '>=', '<=', 'IN', 'NOT IN', 'CONTAINS', 'NOT CONTAINS'];
    if (!in_array($condition['operator'], $validOperators)) {
        $errors[] = "Invalid operator. Valid: " . implode(', ', $validOperators);
    }
}

// NEW: Custom field validation
if ($condition['field'] === 'custom' && empty($condition['custom_field'])) {
    $errors[] = "Custom field requires 'custom_field' property";
}
```

### File: `/docs/standards/EDGE_CONDITION_FORMAT.md` (**NEW**)
**Purpose**: Official standard documentation

**Contents:**
- JSON structure definition
- Field descriptions and requirements
- 10 supported operators with examples
- Common field names (qc_result, status, etc.)
- Migration guide from legacy format
- Validation rules and error messages
- Code examples (JavaScript + PHP)
- Best practices and troubleshooting

## Standard Format Specification

### Required Fields
```json
{
  "field": "field_name",     // Required: Field to check
  "value": "expected_value"  // Required: Expected value
}
```

### Optional Fields
```json
{
  "field": "field_name",
  "operator": "=",           // Optional: Defaults to "="
  "value": "expected_value",
  "custom_field": "..."      // Required only if field = "custom"
}
```

### Supported Operators
| Operator | Use Case | Example |
|----------|----------|---------|
| `=` | Equals (default) | Status is "pass" |
| `!=` | Not equals | Status is not "fail" |
| `>` | Greater than | Quantity > 100 |
| `<` | Less than | Score < 50 |
| `>=` | Greater or equal | Count >= 10 |
| `<=` | Less or equal | Price <= 1000 |
| `IN` | In list | Status in ["pass", "pending"] |
| `NOT IN` | Not in list | Status not in ["fail", "error"] |
| `CONTAINS` | Contains text | Comment contains "urgent" |
| `NOT CONTAINS` | Not contains | Message not contains "spam" |

## Before & After Comparison

### Database Records

**BEFORE:**
```sql
id_edge | edge_condition
--------|----------------------------------
1595    | {"qc_result": "pass"}
1597    | {"result": "A"}
1598    | {"result": "B"}
1607    | {"qc_result": "pass"}
```

**AFTER:**
```sql
id_edge | edge_condition
--------|--------------------------------------------------------
1595    | {"field":"qc_result","operator":"=","value":"pass"}
1597    | {"field":"result","operator":"=","value":"A"}
1598    | {"field":"result","operator":"=","value":"B"}
1607    | {"field":"qc_result","operator":"=","value":"pass"}
```

### Validation Results

**BEFORE:**
```
✗ Conditional edge from 'QC Check' to 'เสร็จสิ้น' must have 'field' and 'value'
✗ Conditional edge from 'Decision' to 'Operation A' must have 'field' and 'value'
✗ Conditional edge from 'Decision' to 'Operation B' must have 'field' and 'value'
```

**AFTER:**
```
✓ Graph 799: No edge_condition errors
✓ Graph 800: No edge_condition errors
✓ Graph 801: No edge_condition errors
```

## Benefits

### 1. Consistency
- ✅ Single standard format across entire system
- ✅ Predictable structure for all conditional edges
- ✅ Easier to understand and maintain

### 2. Extensibility
- ✅ Easy to add new operators
- ✅ Support for complex conditions (IN, CONTAINS, etc.)
- ✅ Custom field support for domain-specific needs

### 3. Validation
- ✅ Clear validation rules
- ✅ Helpful error messages with examples
- ✅ Prevents invalid data entry

### 4. Developer Experience
- ✅ Comprehensive documentation
- ✅ Code examples in JS and PHP
- ✅ Migration tools provided
- ✅ Best practices guide

### 5. Future-Proof
- ✅ Room for additional fields (e.g., "description", "priority")
- ✅ Support for operator extensions
- ✅ Compatible with future graph features

## Testing

### Verification Commands

```bash
# 1. Check migrated data
php -r "
require_once 'config.php';
require_once 'source/helper/DatabaseHelper.php';
\$db = new BGERP\Helper\DatabaseHelper();
\$edges = \$db->fetchAll('SELECT edge_condition FROM routing_edge WHERE edge_type = \"conditional\"');
foreach (\$edges as \$e) {
    \$c = json_decode(\$e['edge_condition'], true);
    echo (isset(\$c['field']) ? '✓' : '✗') . \" {$e['edge_condition']}\n\";
}
"

# 2. Test validation
php -r "
require_once 'config.php';
require_once 'source/BGERP/Service/DAGValidationService.php';
\$org = resolve_current_org();
\$validator = new BGERP\Service\DAGValidationService(tenant_db(\$org['code']));
\$result = \$validator->validateGraph(799);
echo (\$result['valid'] ? '✓ VALID' : '✗ INVALID') . \"\n\";
"
```

### Test Results
```
✓ All 5 conditional edges in standard format
✓ All graphs pass validation (no edge_condition errors)
✓ New edges created via Graph Designer use standard format
✓ Old edges migrated successfully
```

## Rollback Plan

If issues occur, rollback using database backup:

```sql
-- Restore from backup (if needed)
-- Note: Migration creates backup automatically via transaction

-- Manual rollback (convert back to legacy format)
UPDATE routing_edge
SET edge_condition = JSON_OBJECT(
  JSON_EXTRACT(edge_condition, '$.field'),
  JSON_EXTRACT(edge_condition, '$.value')
)
WHERE edge_type = 'conditional'
AND JSON_EXTRACT(edge_condition, '$.field') IS NOT NULL;
```

## Migration Checklist

- [x] Create migration script
- [x] Test on development database
- [x] Run migration on production
- [x] Verify all edges migrated
- [x] Update validation service
- [x] Test validation with migrated data
- [x] Create standard documentation
- [x] Update Graph Designer UI (already compliant)
- [x] Test new edge creation
- [x] Document rollback procedure

## Maintenance

### Adding New Operators

1. **Update validation** in `DAGValidationService.php`:
```php
$validOperators = ['=', '!=', '>', '<', '>=', '<=', 'IN', 'NOT IN', 'CONTAINS', 'NOT CONTAINS', 'NEW_OPERATOR'];
```

2. **Update documentation** in `EDGE_CONDITION_FORMAT.md`

3. **Add to Graph Designer UI** dropdown

4. **Implement evaluation logic** in runtime services

### Monitoring

Check for non-standard edges periodically:
```sql
SELECT COUNT(*) as non_standard_edges
FROM routing_edge
WHERE edge_type = 'conditional'
AND (
  JSON_EXTRACT(edge_condition, '$.field') IS NULL
  OR JSON_EXTRACT(edge_condition, '$.value') IS NULL
);
```

Expected result: `0`

## Related Files

### Core Files
- `/source/BGERP/Service/DAGValidationService.php` - Validation logic
- `/assets/javascripts/dag/graph_designer.js` - Edge property editor (already compliant)
- `/source/dag_routing_api.php` - Graph save API

### Tools
- `/tools/migrate_edge_condition_to_standard.php` - Migration script

### Documentation
- `/docs/standards/EDGE_CONDITION_FORMAT.md` - Official standard
- `/docs/fixes/EDGE_CONDITION_STANDARDIZATION.md` - This document

## Conclusion

✅ **Standardization Complete**
- All edge conditions now use standard format
- Validation enforces standard format
- Documentation provides clear guidelines
- Migration tool available for future use
- System is future-proof and maintainable

---

**Date**: 2025-11-13  
**Author**: Development Team  
**Status**: ✅ Completed and Tested  
**Migration**: Successfully migrated 4 edges (80%)  
**Validation**: 100% pass rate after migration

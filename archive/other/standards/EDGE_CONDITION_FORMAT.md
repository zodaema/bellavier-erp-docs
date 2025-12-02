# Edge Condition Format Standard

## Overview
This document defines the **official standard format** for `edge_condition` in the routing graph system.

## Standard Format

### JSON Structure
```json
{
  "field": "field_name",
  "operator": "=",
  "value": "expected_value",
  "custom_field": "custom_field_name"
}
```

### Field Descriptions

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `field` | **Yes** | string | Field name to check (e.g., "qc_result", "status", "custom") |
| `operator` | No | string | Comparison operator (default: "=") |
| `value` | **Yes** | string/number/boolean | Expected value to compare against |
| `custom_field` | Conditional | string | Custom field name (required only if `field = "custom"`) |

### Valid Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `=` | Equals (default) | `{"field": "status", "value": "pass"}` |
| `!=` | Not equals | `{"field": "status", "operator": "!=", "value": "fail"}` |
| `>` | Greater than | `{"field": "count", "operator": ">", "value": 10}` |
| `<` | Less than | `{"field": "count", "operator": "<", "value": 5}` |
| `>=` | Greater than or equal | `{"field": "score", "operator": ">=", "value": 80}` |
| `<=` | Less than or equal | `{"field": "score", "operator": "<=", "value": 100}` |
| `IN` | In list | `{"field": "status", "operator": "IN", "value": ["pass", "pending"]}` |
| `NOT IN` | Not in list | `{"field": "status", "operator": "NOT IN", "value": ["fail", "error"]}` |
| `CONTAINS` | Contains substring | `{"field": "comment", "operator": "CONTAINS", "value": "urgent"}` |
| `NOT CONTAINS` | Does not contain | `{"field": "comment", "operator": "NOT CONTAINS", "value": "spam"}` |

## Examples

### 1. Basic QC Check (Pass/Fail)
```json
{
  "field": "qc_result",
  "operator": "=",
  "value": "pass"
}
```

### 2. Decision Branch (Multiple Paths)
**Path A:**
```json
{
  "field": "decision_result",
  "operator": "=",
  "value": "A"
}
```

**Path B:**
```json
{
  "field": "decision_result",
  "operator": "=",
  "value": "B"
}
```

### 3. Quantity Check
```json
{
  "field": "quantity",
  "operator": ">=",
  "value": 100
}
```

### 4. Status Not In List
```json
{
  "field": "status",
  "operator": "NOT IN",
  "value": ["cancelled", "rejected"]
}
```

### 5. Custom Field
```json
{
  "field": "custom",
  "custom_field": "fabric_type",
  "operator": "=",
  "value": "leather"
}
```

## Common Field Names

### Standard Fields (Built-in)
| Field | Type | Description | Used In |
|-------|------|-------------|---------|
| `qc_result` | string | QC check result | QC/Decision nodes |
| `qc_status` | string | QC status | QC/Decision nodes |
| `status` | string | General status | Any decision node |
| `result` | string | General result | Any decision node |
| `decision_result` | string | Decision outcome | Decision nodes |
| `quantity` | number | Item quantity | Quantity checks |
| `count` | number | Count value | Counting operations |
| `score` | number | Score value | Scoring operations |

### Custom Fields
When using `field = "custom"`, you must specify `custom_field`:
```json
{
  "field": "custom",
  "custom_field": "your_field_name",
  "operator": "=",
  "value": "your_value"
}
```

## Migration from Legacy Format

### Legacy Format (Deprecated)
```json
{
  "qc_result": "pass"
}
```

### Standard Format (Current)
```json
{
  "field": "qc_result",
  "operator": "=",
  "value": "pass"
}
```

### Migration Tool
Use the migration script to convert legacy format to standard:
```bash
php tools/migrate_edge_condition_to_standard.php
```

## Validation Rules

### Required Fields
1. `field` must be present
2. `value` must be present

### Optional Fields
1. `operator` defaults to "=" if not specified
2. `custom_field` required only when `field = "custom"`

### Validation Errors
```
✗ "Conditional edge must have 'field' in edge_condition"
✗ "Conditional edge must have 'value' in edge_condition"
✗ "Conditional edge has invalid operator 'INVALID'"
✗ "Conditional edge uses custom field but 'custom_field' name is missing"
```

## Database Schema

### Table: `routing_edge`
| Column | Type | Description |
|--------|------|-------------|
| `edge_condition` | JSON | Stores condition as JSON string |

### Example SQL
```sql
-- Insert conditional edge
INSERT INTO routing_edge (
  from_node_id, 
  to_node_id, 
  edge_type, 
  edge_condition
) VALUES (
  123, 
  456, 
  'conditional',
  '{"field":"qc_result","operator":"=","value":"pass"}'
);

-- Query conditional edges
SELECT 
  e.*,
  n_from.node_name as from_name,
  n_to.node_name as to_name
FROM routing_edge e
JOIN routing_node n_from ON e.from_node_id = n_from.id_node
JOIN routing_node n_to ON e.to_node_id = n_to.id_node
WHERE e.edge_type = 'conditional'
AND JSON_EXTRACT(e.edge_condition, '$.field') = 'qc_result';
```

## Graph Designer UI

### Conditional Edge Properties Form
When editing a conditional edge in Graph Designer:

1. **Edge Type**: Select "Conditional"
2. **Condition Field**: Dropdown with standard fields + "Custom"
3. **Operator**: Dropdown with valid operators (default: "=")
4. **Value**: Text input for expected value
5. **Custom Field Name**: (Only visible if Field = "Custom")

### UI Validation
- Field and Value are required
- Operator defaults to "=" if not selected
- Custom Field Name required if Field = "Custom"

## Code Examples

### JavaScript (Graph Designer)
```javascript
// Create edge condition
const edgeCondition = {
  field: $('#prop-condition-field').val(),
  operator: $('#prop-condition-operator').val() || '=',
  value: $('#prop-condition-value').val()
};

if (edgeCondition.field === 'custom') {
  edgeCondition.custom_field = $('#prop-custom-field-name').val();
}

edge.data('edgeCondition', edgeCondition);
```

### PHP (Validation)
```php
// Validate edge condition
$condition = json_decode($edge['edge_condition'], true);

if (!isset($condition['field'])) {
    $errors[] = "Missing 'field' in edge_condition";
}

if (!isset($condition['value'])) {
    $errors[] = "Missing 'value' in edge_condition";
}

if (isset($condition['operator'])) {
    $validOperators = ['=', '!=', '>', '<', '>=', '<=', 'IN', 'NOT IN'];
    if (!in_array($condition['operator'], $validOperators)) {
        $errors[] = "Invalid operator: " . $condition['operator'];
    }
}
```

### PHP (Runtime Evaluation)
```php
// Evaluate condition at runtime
function evaluateCondition($condition, $context) {
    $field = $condition['field'];
    $operator = $condition['operator'] ?? '=';
    $expectedValue = $condition['value'];
    
    // Get actual value from context
    if ($field === 'custom') {
        $actualValue = $context[$condition['custom_field']] ?? null;
    } else {
        $actualValue = $context[$field] ?? null;
    }
    
    // Compare based on operator
    switch ($operator) {
        case '=':
            return $actualValue == $expectedValue;
        case '!=':
            return $actualValue != $expectedValue;
        case '>':
            return $actualValue > $expectedValue;
        case '<':
            return $actualValue < $expectedValue;
        case '>=':
            return $actualValue >= $expectedValue;
        case '<=':
            return $actualValue <= $expectedValue;
        case 'IN':
            return in_array($actualValue, (array)$expectedValue);
        case 'NOT IN':
            return !in_array($actualValue, (array)$expectedValue);
        case 'CONTAINS':
            return strpos($actualValue, $expectedValue) !== false;
        case 'NOT CONTAINS':
            return strpos($actualValue, $expectedValue) === false;
        default:
            return false;
    }
}
```

## Best Practices

### 1. Use Descriptive Field Names
✅ Good:
```json
{"field": "qc_visual_inspection", "value": "pass"}
```

❌ Bad:
```json
{"field": "x", "value": "1"}
```

### 2. Default Operator
For simple equality checks, omit operator:
```json
{"field": "status", "value": "approved"}
```

### 3. Consistent Value Types
Use consistent types for values:
```json
{"field": "quantity", "operator": ">=", "value": 100}  // number
{"field": "status", "value": "pass"}                   // string
{"field": "is_urgent", "value": true}                  // boolean
```

### 4. Document Custom Fields
If using custom fields, document them:
```json
{
  "field": "custom",
  "custom_field": "leather_grade",  // Values: A, B, C
  "value": "A"
}
```

## Troubleshooting

### Error: "must have 'field' in edge_condition"
**Cause**: Using legacy format or missing field
**Solution**: Use standard format with `field` property

### Error: "must have 'value' in edge_condition"
**Cause**: Missing value property
**Solution**: Add `value` property

### Error: "has invalid operator"
**Cause**: Using unsupported operator
**Solution**: Use one of the valid operators listed above

### Error: "uses custom field but 'custom_field' name is missing"
**Cause**: `field = "custom"` but no `custom_field` specified
**Solution**: Add `custom_field` property

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-13 | Initial standard format definition |
| 1.1 | 2025-11-13 | Added legacy format migration |
| 1.2 | 2025-11-13 | Enhanced validation with operator support |

## Related Documentation
- [Graph Validation Service](../architecture/GRAPH_VALIDATION.md)
- [Graph Designer Usage](../GRAPH_DESIGNER_USAGE.md)
- [Migration Guide](../fixes/EDGE_CONDITION_MIGRATION.md)

---

**Date**: 2025-11-13  
**Author**: Development Team  
**Status**: ✅ Official Standard  
**Version**: 1.2

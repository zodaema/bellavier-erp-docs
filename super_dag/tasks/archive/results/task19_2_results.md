# Task 19.2 Results – Multi-Condition Rules & AND/OR Grouping

**Date:** 2025-12-18  
**Status:** ✅ Completed  
**Objective:** Extend conditional edge editor to support multiple condition blocks, grouping, logical operators (AND/OR), and structured evaluation.

---

## 1. Overview of Implementation

### 1.1 Core Components

**Files Modified:**
- `assets/javascripts/dag/modules/conditional_edge_editor.js` - Extended with multi-group support
- `assets/javascripts/dag/modules/GraphSaver.js` - Updated to serialize multi-group structures
- `assets/javascripts/dag/graph_designer.js` - Added event handlers for multi-group UI

**New Features:**
1. **Multi-Group UI** - Users can add multiple groups (OR logic) with multiple conditions per group (AND logic)
2. **Legacy Compatibility** - Automatic conversion from legacy single condition → multi-group format
3. **QC Templates** - Two preset templates for common QC routing scenarios
4. **Comprehensive Validation** - Hard errors (block save) and soft warnings (allow with confirmation)
5. **QC Coverage Validation** - Ensures all QC statuses are covered across outgoing edges

### 1.2 Architecture

```
ConditionalEdgeEditor
├── parseConditionToGroups()      # Legacy → Multi-group conversion
├── normalizeConditionForUI()     # Normalize condition for display
├── renderEditor()                # Multi-group UI rendering
├── serializeConditionGroups()    # UI → Unified JSON model
├── validateConditionGroups()      # Comprehensive validation
├── detectConflictingConditions() # Conflict detection
├── validateQCCoverage()          # QC coverage check
├── getQCTemplates()             # Template definitions
└── applyQCTemplate()            # Template application

GraphSaver
└── serializeEdgeCondition()      # Supports both single & multi-group

graph_designer.js
├── initializeMultiGroupEditor()  # Multi-group event handlers
├── initializeSingleConditionEditor() # Legacy handlers
├── initializeCommonHandlers()   # Shared handlers
└── performEdgeSave()             # Save with validation
```

---

## 2. Legacy → UI Mapping Table

### 2.1 Input Formats Supported

| Legacy Format | UI Structure | Internal JSON Format |
|--------------|--------------|---------------------|
| **No condition / null / undefined** | Default Route checkbox checked | `{ type: "expression", expression: "true" }` |
| **Single leaf condition**<br>`{ type: "token_property", property: "qc_result.status", operator: "==", value: "pass" }` | 1 group, 1 condition | `{ type: "and", conditions: [{ ... }] }` |
| **Legacy AND**<br>`{ type: "and", conditions: [...] }` | 1 group with multiple conditions | `{ type: "and", conditions: [...] }` |
| **Legacy OR**<br>`{ type: "or", conditions: [...] }` | Multiple groups, each with 1 condition | `{ type: "or", groups: [{ type: "and", conditions: [...] }] }` |
| **New Multi-Group**<br>`{ type: "or", groups: [...] }` | Multiple groups with multiple conditions | `{ type: "or", groups: [{ type: "and", conditions: [...] }] }` |
| **Expression (Default)**<br>`{ type: "expression", expression: "true" }` | Default Route checkbox checked, no groups | `{ type: "expression", expression: "true" }` |

### 2.2 Conversion Logic

**parseConditionToGroups()** handles all conversions:
- Detects format type (single, AND, OR, multi-group, expression)
- Normalizes to UI structure: `{ groups: [...], isDefault: boolean }`
- Each group: `{ conditions: [{ field, operator, value, conditionType }] }`
- Preserves all condition data during conversion

**Example Conversions:**

```javascript
// Legacy single condition
Input:  { type: "token_property", property: "qc_result.status", operator: "==", value: "pass" }
Output: { groups: [{ conditions: [{ field: "qc_result.status", operator: "==", value: "pass" }] }] }

// Legacy OR
Input:  { type: "or", conditions: [
           { type: "token_property", property: "qc_result.status", operator: "==", value: "pass" },
           { type: "token_property", property: "qc_result.status", operator: "==", value: "fail_minor" }
         ]}
Output: { groups: [
           { conditions: [{ field: "qc_result.status", operator: "==", value: "pass" }] },
           { conditions: [{ field: "qc_result.status", operator: "==", value: "fail_minor" }] }
         ]}
```

---

## 3. Validation Rules (Error vs Warning)

### 3.1 Hard Errors (Block Save)

| Error | Condition | Message |
|-------|-----------|---------|
| **No Groups** | No groups exist and not Default Route | "At least one condition group is required" |
| **Empty Group** | A group has 0 conditions | "Group {N} has no conditions" |
| **Missing Field** | Condition missing field selection | "Group {N}: Field is required" |
| **Missing Operator** | Condition missing operator selection | "Group {N}: Operator is required" |
| **Missing Value** | Condition missing value input | "Group {N}: Value is required" |
| **QC Coverage** | QC node missing coverage for required statuses | "QC statuses not covered: {statuses}" |

**Implementation:**
- `validateConditionGroups()` returns `{ valid: boolean, errors: string[], warnings: string[] }`
- Errors block save with `notifyError()`
- QC coverage check requires `checkQC: true` option with `cy` and `sourceNode`

### 3.2 Soft Warnings (Allow Save with Confirmation)

| Warning | Condition | Message |
|---------|-----------|---------|
| **Conflicting Equals** | Same field with `==` operator but different values in same group | "Group {N}: Conflicting conditions on {field} ({values})" |
| **Conflicting Range** | Numeric field with impossible range (e.g., `qty >= 2 AND qty < 1`) | "Group {N}: Conflicting numeric range on {field} (min: {min}, max: {max})" |

**Implementation:**
- `detectConflictingConditions()` analyzes conditions within each group
- Uses `getMinValue()` and `getMaxValue()` for range conflict detection
- Warnings shown via SweetAlert2 with "Proceed Anyway" option
- User can cancel or proceed with save

**Example Warnings:**

```javascript
// Conflicting equals
Group 1:
  QC Status == pass
  QC Status == fail_major
→ Warning: "Group 1: Conflicting conditions on qc_result.status (pass, fail_major)"

// Conflicting range
Group 1:
  token.qty >= 2
  token.qty < 1
→ Warning: "Group 1: Conflicting numeric range on token.qty (min: 2.0001, max: 0.9999)"
```

---

## 4. Assumptions & Limitations

### 4.1 Assumptions

1. **Backend Compatibility**
   - Backend `ConditionEvaluator` (Task 19.0) already supports unified condition model
   - No backend changes required for multi-group format
   - Backend evaluates `{ type: "or", groups: [...] }` structure correctly

2. **QC Property Standardization**
   - QC conditions use `property: "qc_result.status"` (not `qc_status` or other variants)
   - Required QC statuses: `['pass', 'fail_minor', 'fail_major']`
   - Coverage validation searches for `type == "token_property"` AND `property == "qc_result.status"`

3. **UI Behavior**
   - Single group with single condition → serializes as `{ type: "and", conditions: [...] }` (backward compatible)
   - Multiple groups → serializes as `{ type: "or", groups: [...] }`
   - Default route always serializes as `{ type: "expression", expression: "true" }`

4. **Edge Data Storage**
   - Conditions stored in `edge.data('edgeCondition')` as object (not string)
   - GraphSaver serializes to JSON string before API call
   - Legacy edges automatically converted on load

### 4.2 Limitations

1. **No Nested OR Inside Groups**
   - Groups only support AND logic (all conditions must match)
   - OR logic only exists between groups
   - Cannot create: `(A AND B) OR (C AND D)` inside a single group

2. **No Drag & Drop Between Groups**
   - Conditions cannot be dragged between groups
   - Must manually delete and recreate in target group
   - Future enhancement: Add drag & drop support

3. **QC Templates Are Presets Only**
   - Templates replace all existing groups (no merge)
   - User must manually edit after applying template
   - Cannot save custom templates

4. **Validation Scope**
   - QC coverage validation only checks current graph (not cross-graph)
   - Conflict detection is basic (doesn't handle complex logical contradictions)
   - No validation for impossible conditions across different fields

5. **Performance**
   - Large graphs with many conditional edges may have slower validation
   - QC coverage check iterates all outgoing edges (O(n) where n = edges)
   - No caching of validation results

---

## 5. Test Cases

### 5.1 Single Group

**Test:** Single group with one condition
```
Group 1:
  QC Status == pass
```

**Expected:**
- Serializes as: `{ type: "and", conditions: [{ type: "token_property", property: "qc_result.status", operator: "==", value: "pass" }] }`
- Validation: ✅ Valid
- Save: ✅ Success

---

### 5.2 Multi-Group OR Logic

**Test:** Multiple groups (OR between groups)
```
Group 1:
  QC Status == pass

Group 2:
  QC Status == fail_minor
```

**Expected:**
- Serializes as:
```json
{
  "type": "or",
  "groups": [
    {
      "type": "and",
      "conditions": [
        { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "pass" }
      ]
    },
    {
      "type": "and",
      "conditions": [
        { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "fail_minor" }
      ]
    }
  ]
}
```
- Validation: ✅ Valid
- Save: ✅ Success

---

### 5.3 AND Within Group

**Test:** Single group with multiple conditions (AND logic)
```
Group 1:
  QC Status == fail_minor
  Token.qty >= 1
```

**Expected:**
- Serializes as:
```json
{
  "type": "and",
  "conditions": [
    { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "fail_minor" },
    { "type": "token_property", "property": "token.qty", "operator": ">=", "value": 1 }
  ]
}
```
- Validation: ✅ Valid
- Save: ✅ Success

---

### 5.4 Default-Only Edge

**Test:** Default route with no groups
```
☑ Default Route (Else)
```

**Expected:**
- Serializes as: `{ type: "expression", expression: "true" }`
- Validation: ✅ Valid (no groups required for default)
- Save: ✅ Success

---

### 5.5 QC Full Coverage

**Test:** QC node with 3 outgoing edges covering all statuses
```
Edge 1: QC Status == pass
Edge 2: QC Status == fail_minor
Edge 3: QC Status == fail_major
```

**Expected:**
- Validation: ✅ Valid (all statuses covered)
- Save: ✅ Success

---

### 5.6 QC Partial Coverage (Error)

**Test:** QC node with 2 outgoing edges missing one status
```
Edge 1: QC Status == pass
Edge 2: QC Status == fail_minor
(Missing: fail_major)
```

**Expected:**
- Validation: ❌ Error: "QC statuses not covered: fail_major"
- Save: ❌ Blocked

---

### 5.7 Empty Group (Error)

**Test:** Group with no conditions
```
Group 1: (empty)
```

**Expected:**
- Validation: ❌ Error: "Group 1 has no conditions"
- Save: ❌ Blocked

---

### 5.8 Conflicting Conditions (Warning)

**Test:** Same field with conflicting values in same group
```
Group 1:
  QC Status == pass
  QC Status == fail_major
```

**Expected:**
- Validation: ⚠️ Warning: "Group 1: Conflicting conditions on qc_result.status (pass, fail_major)"
- Save: ⚠️ Shows SweetAlert2 with "Proceed Anyway" option
- User can proceed or cancel

---

### 5.9 Conflicting Range (Warning)

**Test:** Numeric field with impossible range
```
Group 1:
  token.qty >= 2
  token.qty < 1
```

**Expected:**
- Validation: ⚠️ Warning: "Group 1: Conflicting numeric range on token.qty (min: 2.0001, max: 0.9999)"
- Save: ⚠️ Shows SweetAlert2 with "Proceed Anyway" option

---

### 5.10 Legacy Format Loading

**Test:** Load edge with legacy single condition format
```
Existing: { type: "token_property", property: "qc_result.status", operator: "==", value: "pass" }
```

**Expected:**
- UI displays: 1 group with 1 condition
- Field: "qc_result.status" selected
- Operator: "==" selected
- Value: "pass" selected
- Can edit and save (converts to new format)

---

### 5.11 Legacy OR Format Loading

**Test:** Load edge with legacy OR format
```
Existing: {
  type: "or",
  conditions: [
    { type: "token_property", property: "qc_result.status", operator: "==", value: "pass" },
    { type: "token_property", property: "qc_result.status", operator: "==", value: "fail_minor" }
  ]
}
```

**Expected:**
- UI displays: 2 groups, each with 1 condition
- Group 1: QC Status == pass
- Group 2: QC Status == fail_minor
- OR separator between groups
- Can edit and save (converts to new format)

---

### 5.12 QC Template A Application

**Test:** Apply Template A (Basic QC Split)
```
Before: (empty)
Action: Click "Template A: Basic QC Split"
```

**Expected:**
- UI shows: 2 groups
- Group 1: QC Status == pass
- Group 2: QC Status IN [fail_minor, fail_major]
- Can edit after application
- Save: ✅ Success

---

### 5.13 QC Template B Application

**Test:** Apply Template B (Severity + Quantity)
```
Before: (empty)
Action: Click "Template B: Severity + Quantity"
```

**Expected:**
- UI shows: 2 groups
- Group 1: QC Status == fail_minor AND Token.qty >= 1
- Group 2: QC Status == fail_major
- Can edit after application
- Save: ✅ Success

---

## 6. Implementation Notes

### 6.1 Key Functions

**parseConditionToGroups(existingCondition)**
- Handles all legacy format conversions
- Returns: `{ groups: [...], isDefault: boolean }`
- Supports: single, AND, OR, multi-group, expression formats

**serializeConditionGroups(editorContainer, isDefault)**
- Collects all groups and conditions from DOM
- Returns unified condition model
- Single group → `{ type: "and", conditions: [...] }`
- Multiple groups → `{ type: "or", groups: [...] }`
- Default → `{ type: "expression", expression: "true" }`

**validateConditionGroups(editorContainer, isDefault, options)**
- Comprehensive validation with error/warning separation
- QC coverage check (optional, requires cy and sourceNode)
- Returns: `{ valid: boolean, errors: string[], warnings: string[] }`

### 6.2 UI Components

**Condition Groups:**
- Each group wrapped in `.condition-group` with `data-group` attribute
- OR separator between groups (badge)
- Group header shows "Group N" and "All of these must match (AND)"
- Add Condition / Remove Group buttons per group

**Condition Rows:**
- Each condition in `.condition-row` with `data-group` and `data-condition` attributes
- Field dropdown, Operator dropdown, Value input
- Remove Condition button (hidden if only one condition)

**Event Handlers:**
- `initializeMultiGroupEditor()` - Handles all multi-group interactions
- `initializeSingleConditionEditor()` - Legacy single condition handlers
- `initializeCommonHandlers()` - Shared handlers (presets, templates, JSON toggle)

### 6.3 Backward Compatibility

- Legacy edges automatically converted on load
- Single condition format still supported (Task 19.1 compatibility)
- GraphSaver handles both formats seamlessly
- No breaking changes to existing graphs

---

## 7. Acceptance Criteria Status

| Criteria | Status | Notes |
|----------|--------|-------|
| Multi-group / multi-condition editor works | ✅ | Full support for groups and conditions |
| No free text except comments | ✅ | All inputs are dropdowns or validated inputs |
| QC conditions remain mandatory and preserved | ✅ | QC coverage validation enforced |
| OR between groups + AND within groups | ✅ | Logic correctly implemented |
| Default Edge compiled as always-true | ✅ | Serializes as `{ type: "expression", expression: "true" }` |
| Legacy edges load & display in new editor | ✅ | All legacy formats supported |
| No backend logic changed | ✅ | Only frontend changes |
| Graph cannot save invalid conditions | ✅ | Hard errors block save |
| User experience clean and simple | ✅ | iOS automation-like UX |

---

## 8. Future Enhancements

1. **Drag & Drop Between Groups** - Allow moving conditions between groups
2. **Custom Templates** - Save user-defined templates
3. **Advanced Conflict Detection** - Detect more complex logical contradictions
4. **Condition Suggestions** - AI-powered suggestions based on graph context
5. **Bulk Operations** - Apply same condition to multiple edges
6. **Condition Testing** - Test conditions against sample data before save

---

## 9. Conclusion

Task 19.2 successfully extends the conditional edge editor with multi-group support while maintaining full backward compatibility. The implementation provides:

- ✅ Clean, intuitive UI for complex routing rules
- ✅ Comprehensive validation (errors + warnings)
- ✅ QC-aware templates and coverage validation
- ✅ Seamless legacy format conversion
- ✅ No backend changes required

The system is production-ready and ready for user testing.

---

**End of Task 19.2 Results**


# Task 19.2 – Multi-Condition Rules & AND/OR Grouping (Bellavier SuperDAG)

**Objective:**  
Extend the new condition editor (Task 19.1) to support **multiple condition blocks**, **grouping**, **logical operators (AND/OR)**, and **structured evaluation**, keeping the UI simple while enabling expressive routing rules suitable for complex QC decisions, job rules, or future machine allocation logic.

This task focuses **only on UX & serialization logic**.  
Backend evaluation stays the same (uses the unified `ConditionEvaluator` from Task 19.0).

---

# 1. Scope

This task upgrades the following areas:

- ConditionalEdgeEditor – add condition groups and logical operators
- GraphSaver – serialize multi-condition structures to unified condition model
- graph_designer.js – support adding/removing groups
- Validation – detect empty groups, invalid logic, impossible conditions
- QC UX enhancements – templates for grouped rules

This task **does not** modify:
- DAGRoutingService
- ConditionEvaluator
- Machine/Parallel logic
- Backend schema

---

# 2. Deliverables

### 1. Multi-Condition UI
Users can add:
- multiple conditions inside a group (AND logic within the group)
- multiple groups (OR logic between groups)

### 2. UI Components
- “Add Condition”
- “Add Group”
- “Delete Condition”
- “Delete Group”
- Group wrapper UI box
- Logical labels: “ALL must be true (AND)”, “ANY group can match (OR)”

### 3. Unified Structure in JSON
GraphSaver converts UI → JSON model:

```json
{
  "type": "or",
  "groups": [
    {
      "type": "and",
      "conditions": [
        { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "fail_minor" },
        { "type": "token_property", "property": "token.qty", "operator": ">=", "value": 1 }
      ]
    },
    {
      "type": "and",
      "conditions": [
        { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "fail_major" }
      ]
    }
  ]
}
```

### 4. GraphSaver.js Enhancements
- `serializeConditionGroups()` (new)
- Auto-convert single-group → simple format
- Auto-convert simple conditions → single-group model
- Ensure backward compatibility

### 5. Validation Rules
- No empty groups
- No group with 0 conditions
- No condition missing field/operator/value
- No impossible groups (e.g., same property, conflicting ranges)
- QC check remains the same (full coverage must still be satisfied after grouping)

### 6. New File (Optional)
`conditional_group_editor.js`

Or integrate directly into `conditional_edge_editor.js`.

---

# 3. UI Rules

## Group Behavior

### AND inside group
- Every condition in a group must be true.
- Group UI label: **“All of these must match (AND)”**

### OR between groups
- If any group matches → follow edge.
- Group separator label: **“OR”**

## 3.4 Expression Type Rules
- `type: "expression"` is internal-only.
- Only used for Default Route as `{ expression: "true" }`.
- UI does not allow editing or adding custom expressions.
- Unticking Default Route removes the expression automatically.

---

## 3.1 Default Route Rules

If multi-groups exist:
- Default (Else) route must be explicit.
- Default becomes:
```json
{ "type": "expression", "expression": "true" }
```

Backend must NOT use fallback based on order.

---

## 3.2 QC Node Templates

When the edge originates from QC:

Provide preset templates:

### Template A — Basic QC split:
```
Group 1:
  QC Status == pass

Group 2:
  QC Status in [fail_minor, fail_major]
```

### Template B — QC severity + quantity:
```
Group 1:
  QC Status == fail_minor
  Token.qty >= 1

Group 2:
  QC Status == fail_major
```

User can edit freely but QC Status cannot be removed.

## 3.3 QC Property Name Standardization
QC conditions must use:
`token_property.property = "qc_result.status"`
If backend uses a different property name, record the assumption in task19_2_results.md.
Coverage validation searches for conditions where:
- `type == "token_property"`
- `property == "qc_result.status"`
- operator is `==` or `in`

---

# 4. GraphSaver Serialization Rules

`serializeEdgeCondition()` must:

1. Convert UI structure → unified JSON.
2. Flatten single-group → AND-only format:
   ```
   { type: "and", conditions: [...] }
   ```
3. Localize simple QC-only rule:
   ```
   { type: "token_property"... }
   ```
4. Always treat multiple groups as OR.
5. Always ensure explicit conditions (never infer anything).

## 4.1 Legacy → New UI Mapping (Explicit)

Legacy JSON → UI structure:

- **No condition / null / undefined**
  - Meaning: Default Route
  - UI: Mark as “Default Route”
  - Internal JSON: `{ "type": "expression", "expression": "true" }`

- **Single leaf condition**
  ```json
  { "type": "token_property", ... }
  ```
  - UI: 1 group, 1 condition
  - Internal:
    ```json
    { "type": "or", "groups":[ { "type":"and", "conditions":[ leaf ] } ] }
    ```

- **Legacy AND**
  ```json
  { "type":"and", "conditions":[ ... ] }
  ```
  - UI: 1 group with multiple conditions

- **Legacy OR**
  ```json
  { "type":"or", "conditions":[ ... ] }
  ```
  - UI: multiple groups, each containing exactly 1 condition

## 4.2 Structure Restrictions
- Top-level of multi-group model must always be:
  ```json
  { "type":"or", "groups":[ ... ] }
  ```
- Groups must be:
  ```json
  { "type":"and", "conditions":[ ...leaf conditions... ] }
  ```
- No nested OR inside groups.
- For single-group case, GraphSaver can serialize to:
  ```json
  { "type":"and", "conditions":[ ... ] }
  ```
  for backward compatibility.

---

# 5. Graph Designer Integration

- Add “Add Group” button under edge editor.
- Render groups in stacked card layout.
- Each group contains independent condition lists.
- Drag/drop between groups is NOT required.
- Group deletion must include confirmation:  
  > “Delete this rule group? This cannot be undone.”

---

# 6. Frontend Validation

Before saving:

- At least 1 group must exist, unless “Default Route”.
- Each group must have ≥ 1 condition.
- QC graph: Each QC status must be covered by at least 1 group across all outgoing edges.
- Warn if group contains conflicting rules:
  e.g.,  
  qty >= 2 AND qty < 1  
  OR  
  QC Status == pass AND QC Status == fail_major

## 6.1 Error vs Warning Rules

### Hard Errors (Block Save)
- No groups (except when Default Route).
- A group has 0 conditions.
- A condition missing property/operator/value.
- QC graph: some QC status not covered by any outgoing edge.

### Soft Warnings (Allow Save)
- Group appears logically contradictory (e.g., `qty >= 2` AND `qty < 1`).
- Rule like `QC Status == pass` AND `QC Status == fail_major`.
System shows:
“⚠ This group may never match. Proceed anyway?”

---

# 7. Implementation Guardrails (DO NOT BREAK)

- Do NOT modify backend evaluator logic.
- Do NOT add new backend fields.
- Do NOT add new node types.
- Do NOT attempt to auto-merge groups into backend logic.
- Do NOT change edge JSON schema except adding supported `and/or` groups.
- Do NOT create new routing concepts (priority, weight, cost).

If anything is uncertain → write in `task19_2_results.md`, do NOT guess.

---

# 8. Acceptance Criteria

✔ Multi-group / multi-condition editor works  
✔ No free text except comments  
✔ QC conditions remain mandatory and preserved  
✔ OR between groups + AND within groups  
✔ Default Edge compiled as always-true  
✔ Legacy edges load & display in new editor  
✔ No backend logic changed  
✔ Graph cannot save invalid conditions  
✔ User experience clean and simple like iOS automation

---

# 9. Node Default Route Constraints
- A node may contain only one Default Route edge.
- When conditional edges exist, system recommends having exactly one Default Route.
- Missing Default Route triggers a soft warning (not an error).

# 10. Implementation Notes (Required for task19_2_results.md)
task19_2_results.md must include:
1. Overview of implementation
2. Legacy→UI mapping table
3. Validation rules (Error vs Warning)
4. Assumptions & limitations
5. Test cases:
   - Single group
   - Multi-group OR logic
   - Default-only edge
   - QC full/partial coverage

---

# End of Task 19.2 Specification

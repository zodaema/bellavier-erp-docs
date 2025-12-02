# Task 19.6 – Conditional Edge Editor UX Rewrite (Bellavier Premium Edition)

**Objective:**  
Redesign the Conditional Edge Editor into a clean, intuitive, Apple‑grade UI that removes confusion, prevents misconfiguration, and ensures that even non‑technical users can create powerful conditional flows without understanding JSON or internal routing logic.

This task focuses strictly on **UX improvements**, **layout cleanup**, and **context‑aware automatic behavior**.  
No backend logic changes. No schema changes. No new routing concepts.

This is the final UX task before entering Task 20 (ETA Engine).

**Note:** Cursor/AI Agent MUST NOT attempt to simplify the UI. Every sub‑section of this task MUST be implemented exactly as specified. If the editor previously contained conflicting logic or unused legacy UI, those parts MUST be removed. When in doubt, preserve clarity, not compatibility.

---

# 1. Scope

Task 19.6 includes:

- Full UI redesign of the conditional edge editor
- Auto-context behavior (auto show/hide fields)
- Unified operator selection UI
- Dynamic form layout (“iOS settings section” style)
- Default route (Else) UI redesign
- Template-based presets (QC-aware, Job-aware)
- Advanced JSON toggle (collapsible section)
- Removal of confusing or redundant UI elements

Task 19.6 does **NOT**:

- Touch routing logic
- Change ConditionEvaluator
- Modify backend APIs
- Add or remove node types
- Affect parallel/merge logic

---

# 2. Deliverables

## 2.1 New Conditional Edge Editor Layout

**File:** `assets/javascripts/dag/modules/conditional_edge_editor.js`  
(UPDATE)

Implement the following layout structure:

### A. Header Section
```
Edge Conditions
-------------------------------------
```
- Header must remain pinned when user scrolls.
- Add small caption: “Routing rules for this edge. Evaluated top‑to‑bottom.”

### B. Default vs Conditional Mode (Auto)
- If the edge has **no conditions** → UI shows:
  - A toggle: “Use Conditional Routing”
  - Explanation: “If disabled, this edge becomes the ELSE route.”
- If enabled → show full condition builder.

### C. Condition Group Layout (OR)
Each group is a card:

```
Group 1 (Any group can match)
┌─────────────────────────────────┐
│ Field     [Dropdown]            │
│ Operator  [Dropdown]            │
│ Value     [Dropdown/Input]      │
│ + Add Condition                 │
└─────────────────────────────────┘
        [Delete Group]
-------------------------------------
        OR
-------------------------------------
Group 2 ...
```

Rules:
- AND inside each group.
- OR between groups.
- “OR” automatically appears between groups.
- Each group card MUST auto‑number (Group 1, Group 2, ...)
- Group card background color: subtle neutral (#FAFAFA) to separate from main panel
- Keep padding consistent: 16px top/bottom, 20px left/right

### D. Add Group Button
```
+ Add Rule Group
```
Under all groups.

### E. Context-Awareness
Field dropdown must auto-filter:
- If source node is QC → show QC fields first (qc_result.*)
- If job context unavailable → hide job.* fields
- If node metadata present → show node.metadata.* keys
- Behaviors cannot be compared (block invalid fields)

### F. Operator Picker
Select the operator based on field type:
- enum/string → is, is not, in list, not in list
- number → ==, !=, >, >=, <, <=
- boolean → is true, is false

### G. Value Picker
- enum → dropdown
- boolean → toggle
- number → numeric input
- string → free text ONLY IF the registry marks the field as “string” AND has no predefined enum list

### H. Default Route (Else)
Show clearly:
```
Else Route
This edge will be taken when no other conditions match.
```
No JSON required.

### I. Advanced JSON View
Collapsed by default:
```
▼ Advanced View (Developers Only)
   { ... JSON ... }
```
- Read-only unless user has developer permissions
- Use monospace block with syntax highlighting

---

## 2.2 New CSS Styling (Optional)

**File:** `assets/styles/dag/conditional_edge_editor.css`  
(NEW)

- Rounded cards for groups
- Soft separators (“iOS Settings” style)
- Light animation for showing/hiding groups
- Minimalist input styling consistent with Bellavier UI

---

## 2.3 Graph Designer Integration

**File:** `assets/javascripts/dag/graph_designer.js`  
(UPDATE)

- Replace old editor loading logic with new one
- Remove legacy modal sections
- Ensure only the new editor is used
- On opening edge properties, scroll user directly to the active group

---

## 2.4 Default Templates

Integrated into `ConditionalEdgeEditor.js`:

### If source node = QC
Show preset buttons:

```
Templates:
[ Pass → Next | Fail → Rework ]
[ Severity & Qty Routing ]
```
- Templates MUST insert conditions using the exact registry field names.
- Templates MUST clear all existing conditions before applying.
- Templates MUST show a confirmation dialog: “Apply template? Existing rules will be replaced.”

### If source node = Non-QC
Offer simple presets:
```
Templates:
[ Priority-based Routing ]
[ Order Channel Routing ]
[ Behavior-based Routing ]
```

Templates auto-generate groups and conditions.

---

## 2.5 Validation Enhancements

Add UI-only validation:

- Highlight incomplete groups
- Display small warnings (non-blocking)
- Disable “Save” on fatal errors:
  - empty field
  - missing operator
  - value invalid for operator
- Visual highlight for ambiguous ranges (warning)

Additional validation rules:
- Empty group is a fatal error.
- Group with only a field but no operator/value = fatal error.
- Conflicting operators within same group (e.g., == and != for same field) = soft warning.
- Duplicate groups = soft warning.
- More than 8 groups = soft warning (“Complex rule: consider simplifying”).

---

## 2.6 Documentation

**File:** `docs/super_dag/tasks/task19_6_results.md`  
(NEW)

Contains:

- Before/After screenshots
- Description of new UX
- Any removed/retired UI behavior
- No logic changes summary
- Future enhancements section

---

# 3. Implementation Guardrails

To prevent accidental logic changes:

### ❌ MUST NOT:
- Modify ConditionEvaluator
- Modify DAGRoutingService
- Modify TokenLifecycleService
- Add new DB columns
- Change JSON schema
- Create new routing concepts
- Alter parallel/merge/machine logic

### ✔ MUST:
- Only touch JS/CSS/view-level files
- Only modify Node/Edge Properties Panel
- Only improve UX, not logic

### ✔ If unsure:
- Leave old behavior untouched
- Document uncertainty in `task19_6_results.md`

**Testing requirement:** Add temporary console logging for group/condition creation and deletion during development. Remove all logs before shipping.

---

# 4. Acceptance Criteria

✔ New edge editor UI fully replaces old UI  
✔ Field/operator/value controls match registry types  
✔ Groups and conditions render beautifully  
✔ Default route displayed cleanly  
✔ QC and Non-QC templates work  
✔ Advanced JSON view collapsible  
✔ No backend logic modified  
✔ Documentation complete  

---

# End of Task 19.6 Specification
# Task 31: CUT Node UX/UI Redesign (Option A — Select Task First)

**Status:** 🔄 **IN PROGRESS**  
**Date:** January 2026  
**Master Prompt:** MASTER PROMPT — CUT NODE UX/UI (OPTION A)

---

## 🎯 Objective

Redesign CUT node UX/UI to enforce explicit task selection:
1. User must choose **Component + Material Role + Material SKU** before cutting
2. Prevent any possibility of cutting/saving wrong material
3. Align with Product Structure (BOM with material roles)
4. Preserve traceability, WIP accuracy, downstream correctness
5. Remove ambiguity in current "CUT components" UI

---

## 🚫 Hard Constraints (DO NOT VIOLATE)

- ❌ No generic "Cut component" input
- ❌ No quantity input before task selection
- ❌ No saving yield without (component_code + role_code + material_sku)
- ❌ No global leather sheet selector (must be per selected material)
- ❌ Do NOT auto-assign material silently
- ❌ Do NOT allow user to type quantity in wrong context

---

## ✅ UX Flow Design

### PHASE 1: Task Selection Screen (MANDATORY)

**User must complete all 3 steps before proceeding:**

#### Step 1: Select Component
- List components from Product Structure
- Show progress badges (Need / Done / Ready)
- User selects exactly ONE component
- **State:** `selectedComponent = { component_code, display_name, required_qty, done_qty, available_qty }`

#### Step 2: Select Material Role (within selected component)
- Load roles from BOM for selected component
- Show:
  - Role name (from `material_role_catalog`)
  - `is_primary` badge (if true)
  - Priority order
  - Material count per role
- User selects exactly ONE role
- **State:** `selectedRole = { role_code, role_name_en, role_name_th, is_primary, priority }`

#### Step 3: Select Material (Suggested First)
- System suggests materials automatically:
  - Primary material first
  - Based on BOM priority
- Show material SKU + description
- User must explicitly confirm material
- **State:** `selectedMaterial = { material_sku, material_name, material_category, qty_per_unit, uom_code }`

**👉 Only after all 3 steps complete → enable "Start Cutting" button**

---

### PHASE 2: Cutting Session Screen

**When "Start Cutting" is pressed:**

#### Header (VERY PROMINENT)
```
CUTTING:
Component: BODY
Role: MAIN_MATERIAL
Material: RB-LTH-001 (Goat Leather Black)
```

#### Mandatory Leather Sheet / Lot Selection
- Must select leather sheet / lot
- Must be compatible with selected `material_sku`
- Cannot Save without this
- **State:** `selectedSheet = { id_sheet, sheet_code, used_area, area_remaining }`

#### Quantity Input
- Single numeric input: **Cut Quantity (this session)**
- Optional waste/defect input (if supported)
- **State:** `cutQuantity = number`

#### Timer Behavior (STRICT)
- Timer starts on entering this screen
- Timer pauses ONLY when user presses Save
- Save = end of cutting session
- **State:** `sessionStartedAt = timestamp`, `sessionFinishedAt = timestamp`

---

### PHASE 3: Post-Save State

**After successful Save:**
- Return user to Task Selection Screen
- Update progress indicators
- Show Release button only when Available > 0
- Release action is explicit and separate

---

## 🔐 Data & Validation Rules (MANDATORY)

### Backend Save Payload MUST contain:

```json
{
  "component_code": "BODY",
  "role_code": "MAIN_MATERIAL",
  "material_sku": "RB-LTH-001",
  "material_sheet_id": 123,
  "quantity": 5,
  "token_id": 456,
  "started_at": "2026-01-11 10:00:00",
  "finished_at": "2026-01-11 10:15:00"
}
```

**If ANY of these are missing → reject with 400 error**

### Validation Rules

1. Selected leather sheet must match `material_sku`
2. Quantity must be > 0
3. Role must belong to selected component (from BOM)
4. Material must belong to role (from BOM)
5. Timer must be running (started_at must be set)

---

## 🧠 State Machine

### Task Selection State

```
INITIAL
  ↓
[Select Component] → selectedComponent set
  ↓
[Select Role] → selectedRole set
  ↓
[Select Material] → selectedMaterial set
  ↓
[All 3 Complete] → "Start Cutting" enabled
  ↓
[Click "Start Cutting"] → TRANSITION TO CUTTING SESSION
```

### Cutting Session State

```
ENTER SESSION
  ↓
[Timer Starts] → sessionStartedAt = now()
  ↓
[Select Leather Sheet] → selectedSheet set
  ↓
[Enter Quantity] → cutQuantity set
  ↓
[Click Save] → VALIDATE ALL FIELDS
  ↓
[If Valid] → sessionFinishedAt = now(), SAVE TO BACKEND
  ↓
[If Invalid] → Show error, stay in session
  ↓
[After Save Success] → TRANSITION TO POST-SAVE
```

### Post-Save State

```
SAVE SUCCESS
  ↓
[Return to Task Selection] → Reset all selections
  ↓
[Update Progress] → Refresh component list
  ↓
[Show Release Button] → If available_qty > 0
  ↓
[Click Release] → Release action (separate flow)
```

---

## 📦 Implementation Plan

### 1. Update API: `get_cut_batch_detail`

**Return structure:**
```json
{
  "rows": [
    {
      "component_code": "BODY",
      "display_name_en": "Body",
      "required_qty": 10,
      "cut_done_qty": 5,
      "available_to_release_qty": 3,
      "roles": [
        {
          "role_code": "MAIN_MATERIAL",
          "role_name_en": "Main Material",
          "is_primary": true,
          "priority": 1,
          "materials": [
            {
              "material_sku": "RB-LTH-001",
              "material_name": "Goat Leather Black",
              "material_category": "leather",
              "qty_per_unit": 0.8,
              "uom_code": "sqft",
              "is_primary": true,
              "priority": 1
            }
          ]
        }
      ]
    }
  ]
}
```

### 2. Update UI Templates

**PHASE 1 Template:**
- Step 1: Component cards
- Step 2: Role cards (filtered by selected component)
- Step 3: Material cards (filtered by selected role)
- "Start Cutting" button (disabled until all 3 complete)

**PHASE 2 Template:**
- Prominent header (Component + Role + Material)
- Leather sheet selection (mandatory)
- Quantity input
- Timer display
- Save button

**PHASE 3 Template:**
- Return to Phase 1
- Summary table with Release buttons

### 3. Update Backend Validation

**`BehaviorExecutionService::handleCutBatchYieldSave`:**
- Validate `component_code` exists
- Validate `role_code` belongs to component
- Validate `material_sku` belongs to role
- Validate `material_sheet_id` matches `material_sku`
- Validate `quantity > 0`
- Validate `started_at` and `finished_at` are set

---

## 🎨 UI Layout Breakdown

### PHASE 1: Task Selection

```
┌─────────────────────────────────────────┐
│  CUT TASK SELECTION                     │
├─────────────────────────────────────────┤
│                                         │
│  STEP 1: Select Component               │
│  ┌──────┐  ┌──────┐  ┌──────┐         │
│  │ BODY │  │ FLAP │  │STRAP │         │
│  │ 5/10 │  │ 3/10 │  │ 0/10 │         │
│  └──────┘  └──────┘  └──────┘         │
│                                         │
│  STEP 2: Select Role (if component)    │
│  ┌──────────────┐  ┌──────────────┐   │
│  │ MAIN_MATERIAL│  │   LINING     │   │
│  │   [Primary]  │  │              │   │
│  └──────────────┘  └──────────────┘   │
│                                         │
│  STEP 3: Select Material (if role)     │
│  ┌──────────────────────────────────┐ │
│  │ RB-LTH-001 (Goat Leather Black)  │ │
│  │ [Primary] [Suggested]            │ │
│  └──────────────────────────────────┘ │
│                                         │
│  [Start Cutting] (disabled until ready)│
└─────────────────────────────────────────┘
```

### PHASE 2: Cutting Session

```
┌─────────────────────────────────────────┐
│  ⚠️ CUTTING SESSION                     │
├─────────────────────────────────────────┤
│                                         │
│  Component: BODY                        │
│  Role: MAIN_MATERIAL                    │
│  Material: RB-LTH-001 (Goat Leather)    │
│                                         │
│  ────────────────────────────────────  │
│                                         │
│  ⏱️ Timer: 00:15:32                     │
│                                         │
│  Leather Sheet: [Select Sheet] *       │
│  ┌──────────────────────────────────┐ │
│  │ MAT-SAFF-20251120-001            │ │
│  │ Remaining: 12.25 sq.ft            │ │
│  └──────────────────────────────────┘ │
│                                         │
│  Used Area: [____] sq.ft *              │
│                                         │
│  Cut Quantity: [____] pieces *          │
│                                         │
│  [Save] [Cancel]                        │
└─────────────────────────────────────────┘
```

---

## 🔄 How This Prevents Wrong Cutting

1. **Explicit Selection Chain:** Component → Role → Material (cannot skip)
2. **No Quantity Before Task:** Quantity input only appears in Cutting Session
3. **Material-Specific Sheet Selection:** Sheet selector filtered by `material_sku`
4. **Backend Validation:** All 3 fields (component_code, role_code, material_sku) required
5. **Visual Confirmation:** Header shows exactly what is being cut
6. **Timer Tracking:** Session-based, prevents confusion about what was cut when

---

## 📋 Mapping to Product Structure

- **Component:** From `product_component.component_code`
- **Role:** From `product_component_material.role_code` (MAIN_MATERIAL, LINING, etc.)
- **Material:** From `product_component_material.material_sku`
- **BOM Relationship:** `product_component` → `product_component_material` (with role_code)

---

## ✅ Acceptance Criteria

- [ ] User cannot enter quantity without selecting Component + Role + Material
- [ ] "Start Cutting" button disabled until all 3 steps complete
- [ ] Cutting Session shows Component + Role + Material prominently
- [ ] Leather sheet selection filtered by material_sku
- [ ] Timer starts on entering Cutting Session
- [ ] Save requires all fields: component_code, role_code, material_sku, sheet_id, quantity
- [ ] Backend rejects if any required field missing
- [ ] Post-save returns to Task Selection
- [ ] Release button only shown when available_qty > 0

# User Guide - DAG Routing Graph Designer

**Version:** 2.0.0  
**Date:** November 11, 2025  
**Status:** ✅ Complete  
**Audience:** Graph Designers, Production Planners

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Creating Graphs](#creating-graphs)
3. [Node Types](#node-types)
4. [Edge Types](#edge-types)
5. [Validation & Publishing](#validation--publishing)
6. [Simulation](#simulation)
7. [Quick Fixes](#quick-fixes)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)

---

## Getting Started

### Accessing the Designer

1. Navigate to **Operations → Graph Designer**
2. Select a graph from the list (or create new)
3. Canvas will load with selected graph

### Interface Overview

```
┌─────────────────────────────────────────────────────────┐
│ [Toolbar] [Save] [Validate] [Simulate] [Publish]      │
├─────────────────────────────────────────────────────────┤
│ [Palette] │ [Canvas]                    │ [Properties] │
│           │                             │              │
│ START     │  ┌─────┐                    │ Node Props   │
│ Operation │  │ OP1 │                    │              │
│ Split     │  └──┬──┘                    │ Edge Props   │
│ Join      │     │                        │              │
│ QC        │  ┌──▼──┐                    │ Lint Panel   │
│ Decision  │  │ OP2 │                    │              │
│ End       │  └─────┘                    │ Validation   │
└─────────────────────────────────────────────────────────┘
```

---

## Creating Graphs

### Step 1: Create New Graph

1. Click **"New Graph"** button
2. Fill in:
   - **Code:** Unique identifier (e.g., `PROD_BAG_001`)
   - **Name:** Display name (e.g., `Bag Production Flow`)
   - **Description:** Optional description
   - **Production Type:** `hatthasilpa` or `oem`
3. Click **"Create"**

### Step 2: Add Nodes

1. **From Palette:**
   - Click node type (e.g., "Operation")
   - Click on canvas to place node
   - Double-click node to edit properties

2. **Node Properties:**
   - **Code:** Unique code (e.g., `CUT`, `SEW`)
   - **Name:** Display name (e.g., `Cut Material`)
   - **Type:** Node type (start, operation, end, etc.)
   - **Team Category:** Team category (cutting, sewing, etc.)
   - **WIP Limit:** Maximum work-in-progress
   - **Estimated Minutes:** Estimated processing time

### Step 3: Connect Nodes

1. **Create Edge:**
   - Click **"Connect"** button (or press `C`)
   - Click source node
   - Click target node
   - Edge created

2. **Edit Edge:**
   - Click edge to select
   - Edit properties in right panel:
     - **Label:** Edge label (e.g., "Pass", "Fail")
     - **Type:** normal, conditional, rework
     - **Condition:** JSON condition (for conditional/rework)
     - **Priority:** Edge priority (0-100)

---

## Node Types

### 1. **START Node**

**Purpose:** Entry point of workflow

**Properties:**
- Code (required)
- Name (required)
- Position (x, y)

**Rules:**
- ✅ Must have exactly 1 START node per graph
- ✅ Must have outgoing edges
- ❌ Cannot have incoming edges

---

### 2. **END Node**

**Purpose:** Exit point of workflow

**Properties:**
- Code (required)
- Name (required)
- Position (x, y)

**Rules:**
- ✅ Must have at least 1 END node per graph
- ✅ Must have incoming edges
- ❌ Cannot have outgoing edges

---

### 3. **Operation Node**

**Purpose:** Work task (e.g., cutting, sewing)

**Properties:**
- Code (required)
- Name (required)
- **Team Category** (required): cutting, sewing, edging, etc.
- **Work Center** (optional): Specific work center
- **WIP Limit** (optional): Maximum concurrent work
- **Estimated Minutes** (optional): Processing time estimate
- **Assignment Policy** (optional): auto, team_hint, team_lock
- **Preferred Team** (optional): Preferred team ID
- **Allowed Teams** (optional): Allowed team IDs
- **Forbidden Teams** (optional): Forbidden team IDs

**Rules:**
- ✅ Must have team_category or work_center
- ✅ Can have multiple incoming/outgoing edges

---

### 4. **Decision Node**

**Purpose:** Conditional branching (if/then)

**Properties:**
- Code (required)
- Name (required)
- **Form Schema JSON** (optional): Decision form schema

**Rules:**
- ✅ Must have ≥2 outgoing edges
- ✅ All outgoing edges must be `conditional` or `rework`
- ✅ Must have 1 default edge (`is_default=true`)
- ❌ Cannot have `normal` outgoing edges

**Example:**
```
DECISION → [conditional: pass] → OP1
         → [conditional: fail] → OP2 (default)
```

---

### 5. **QC Node**

**Purpose:** Quality control check

**Properties:**
- Code (required)
- Name (required)
- **Form Schema JSON** (optional): QC form schema

**Rules:**
- ✅ Should have ≥2 outgoing edges (pass/fail)
- ✅ Fail edge should be `rework` type (not `conditional`)
- ✅ Pass edge can be `conditional` or `normal`

**Example:**
```
QC → [conditional: pass] → END
   → [rework: fail] → REWORK_SINK
```

---

### 6. **Split Node**

**Purpose:** Parallel work fork (split into multiple branches)

**Properties:**
- Code (required)
- Name (required)
- **Split Policy** (optional): `ALL`, `CONDITIONAL`, `RATIO`
- **Split Ratio JSON** (optional): Ratio distribution (for RATIO policy)

**Rules:**
- ✅ Must have ≥2 outgoing edges
- ✅ All outgoing edges should be `normal`
- ✅ If `split_policy=RATIO`, must set `split_ratio_json`

**Split Policies:**
- **ALL:** All tokens go to all branches (parallel)
- **CONDITIONAL:** Tokens go based on conditions
- **RATIO:** Tokens distributed by ratio (e.g., 60% branch1, 40% branch2)

**Example:**
```
SPLIT → [normal] → OP1
      → [normal] → OP2
```

---

### 7. **Join Node**

**Purpose:** Merge parallel branches

**Properties:**
- Code (required)
- Name (required)
- **Join Type** (optional): `AND`, `OR`, `N_OF_M`
- **Join Quorum** (optional): Required tokens for N_OF_M (e.g., 2 of 3)

**Rules:**
- ✅ Must have ≥2 incoming edges
- ✅ If `join_type=N_OF_M`, must set `join_quorum`

**Join Types:**
- **AND:** Wait for all tokens (all branches must complete)
- **OR:** Wait for any token (first branch completes)
- **N_OF_M:** Wait for quorum (e.g., 2 of 3 branches)

**Example:**
```
OP1 → [normal] → JOIN (AND) → OP3
OP2 → [normal] ┘
```

---

### 8. **Wait Node**

**Purpose:** Wait for event/time/SLA

**Properties:**
- Code (required)
- Name (required)
- **SLA Minutes** (optional): Service level agreement
- **Wait Window Minutes** (optional): Wait timeout

**Rules:**
- ✅ Can have multiple incoming/outgoing edges

---

### 9. **Subgraph Node**

**Purpose:** Call another graph (nested workflow)

**Properties:**
- Code (required)
- Name (required)
- **Subgraph Ref ID** (required): Reference to another graph
- **Subgraph Ref Version** (required): Version (must be published)
- **IO Contract JSON** (optional): Input/output mapping

**Rules:**
- ✅ Must reference published graph version
- ✅ Cannot create circular references (A→B→A)

---

### 10. **Rework Sink Node**

**Purpose:** Rework destination (not in main DAG)

**Properties:**
- Code (required)
- Name (required)

**Rules:**
- ✅ Should only receive `rework` edges
- ✅ Not counted in cycle detection

---

## Edge Types

### 1. **Normal Edge**

**Purpose:** Standard flow

**Properties:**
- **Label** (optional): Edge label
- **Priority** (optional): 0-100 (higher = preferred)

**Use Case:**
- Sequential flow (OP1 → OP2)
- Split branches (SPLIT → OP1, SPLIT → OP2)

---

### 2. **Conditional Edge**

**Purpose:** Conditional branching

**Properties:**
- **Label** (required): Edge label (e.g., "Pass", "Fail")
- **Condition** (required): JSON condition (e.g., `{"qc":"pass"}`)
- **Is Default** (optional): `true` if default path
- **Priority** (optional): 0-100

**Use Case:**
- Decision node branches
- QC pass/fail paths

**Example:**
```json
{
  "edge_label": "Pass",
  "edge_condition": {"qc": "pass"},
  "is_default": true
}
```

---

### 3. **Rework Edge**

**Purpose:** Rework flow (not counted in cycles)

**Properties:**
- **Label** (required): Edge label (e.g., "Fail - Rework")
- **Condition** (required): JSON condition (e.g., `{"qc":"fail"}`)
- **Priority** (optional): 0-100

**Use Case:**
- QC fail → Rework sink
- Allows loops without cycle errors

**Example:**
```json
{
  "edge_label": "Fail - Rework",
  "edge_condition": {"qc": "fail"},
  "edge_type": "rework"
}
```

---

### 4. **Event Edge**

**Purpose:** Event notification (not counted in cycles)

**Properties:**
- **Label** (optional): Event name
- **Condition** (optional): Event condition

**Use Case:**
- External events
- Notifications

---

## Validation & Publishing

### Validate Graph

1. Click **"Validate"** button
2. Review results:
   - **Errors** (red): Must fix before publish
   - **Warnings** (yellow): Can publish but recommended to fix
   - **Lint** (blue): Suggestions for improvement

3. **Quick Fixes:**
   - Click **"Quick Fix"** button on errors/warnings/lint
   - System applies fix automatically
   - Graph reloads and re-validates

### Publish Graph

1. **Prerequisites:**
   - Graph must pass validation (no errors)
   - All required fields filled
   - No cycles (except rework edges)

2. **Publish:**
   - Click **"Publish"** button
   - Confirm publish
   - Graph version created
   - Graph becomes immutable

3. **After Publish:**
   - Graph version frozen
   - Can create new version for changes
   - Published version used in production

---

## Simulation

### Run Simulation

1. Click **"Simulate"** button
2. Enter parameters:
   - **Target Quantity:** Number of pieces to simulate
   - **Assumptions** (optional): Override defaults
3. Click **"Run Simulation"**

### Simulation Results

- **Critical Path:** Longest path through graph
- **Bottlenecks:** Slow nodes
- **Parallelism:** Parallel work opportunities
- **Estimated Time:** Total processing time

---

## Quick Fixes

### Available Quick Fixes

1. **Add Default Edge:**
   - Marks conditional edge as default
   - Fixes: "Decision node should have default edge"

2. **Convert to Rework Edge:**
   - Converts QC fail edge to rework type
   - Fixes: "QC fail edge should be rework"

3. **Set Join Quorum:**
   - Sets join_quorum for N_OF_M join
   - Fixes: "Join quorum missing"

4. **Set Split Ratio:**
   - Sets split_ratio_json for RATIO split
   - Fixes: "Split ratio missing"

5. **Fix Split Ratio Sum:**
   - Normalizes ratios to sum to 1.0
   - Fixes: "Split ratios don't sum to 1.0"

### Using Quick Fixes

1. Run validation
2. Find error/warning/lint with **"Quick Fix"** button
3. Click **"Quick Fix"**
4. System applies fix automatically
5. Graph reloads and re-validates

---

## Troubleshooting

### Common Issues

#### 1. **"Graph must have exactly 1 start node"**

**Problem:** Multiple START nodes or no START node

**Error:** `Graph must have exactly 1 start node (found 2: เริ่มต้น, ตรวจสอบคุณภาพ)`

**Cause:** โหนด "ตรวจสอบคุณภาพ (QC)" ถูกตั้ง `node_type = start` โดยไม่ตั้งใจ

**Solution:**
- Check all nodes: Only 1 should be `node_type=start`
- Open Properties ของโหนด "ตรวจสอบคุณภาพ"
- Change `node_type` from `start` to `qc` or `operation`
- Save changes
- Delete duplicate START nodes if needed
- Add START node if missing

---

#### 2. **"Graph contains cycle"**

**Problem:** Circular dependency detected

**Error:** `Graph contains cycles (not allowed in DAG). Cycle detected: SEW → EDG → QC → SEW`

**Cause:** มีเส้นเชื่อมที่ย้อนกลับไปยังโหนดก่อนหน้า ทำให้เกิดวงวน

**Solution:**
- **อย่าเชื่อม QC → SEW/EDG แบบ edge ปกติ** เพราะจะย้อนกลับกราฟเสมอ
- Use `rework` edges for QC fail paths (not `normal`/`conditional`)
- Remove backward edges

**Example Fix:**
```
❌ Wrong: QC → [normal] → SEW (creates cycle)
✅ Correct: QC → [rework] → REWORK_SINK
```

**Step-by-Step:**
1. Delete edges QC → SEW และ QC → EDG ที่เป็น `edge_type = normal/conditional`
2. Add edge QC → REWORK_SINK (หรือ node ปลายทางเหตุการณ์) โดยตั้ง `edge_type = rework`
3. Set `edge_label = "ไม่ผ่าน - กลับไปแก้ไข"`
4. Runtime จะ spawn token ใหม่ที่ SEW/EDG ตาม policy

---

#### 3. **Decision Node Validation Errors**

**Problem:** Decision node validation errors

**Common Errors:**
1. **"Decision node 'ตรวจสอบคุณภาพ' must have at least 2 outgoing edges (found: 1)"**
   - Decision node ต้องมี outgoing edges อย่างน้อย 2 เส้น

2. **"Decision node 'ตรวจสอบคุณภาพ' should have conditional or rework edges only (found 'normal' edge to 'เสร็จสิ้น')"**
   - Decision node ต้องมีเฉพาะ conditional หรือ rework edges เท่านั้น (ไม่ใช่ 'normal' edge)

3. **"Decision node 'QC' (ตรวจสอบคุณภาพ) must have at least one conditional edge"**
   - Decision node ต้องมี conditional edge อย่างน้อย 1 เส้น

4. **"Decision node should have default edge"**
   - Decision node without default path

**Solution:**

**Step 1: Add Outgoing Edge**
- Click Decision node on canvas
- Click **"Connect"** button (or press `C`)
- Drag from Decision node to target node
- Repeat to add at least 2 edges

**Step 2: Change Edge Type**
- Click edge that is `normal` type
- In Properties panel, find **"Edge Type"**
- Change from `normal` to `conditional` or `rework`

**Step 3: Set Edge Condition**
- If `conditional`: Set edge condition (e.g., `"pass"`, `"fail"`, `quality_check == "pass"`)
- If `rework`: Set edge label (e.g., `"ไม่ผ่าน - กลับไปแก้ไข"`)

**Step 4: Set Default Edge**
- Click **"Quick Fix"** button (recommended)
- Or manually mark one conditional edge as `is_default=true`

**Example Structure:**
```
Decision Node
├── [conditional: option1] → Target 1
├── [conditional: option2] → Target 2
└── [conditional: default] → Target 3 (is_default=true)
```

---

#### 4. **"QC fail edge should be rework"**

**Problem:** QC fail edge uses `normal`/`conditional` instead of `rework`

**Solution:**
- Click **"Quick Fix"** button (recommended)
- Or manually change edge type to `rework`

**Why:** QC fail edges should be `rework` type to enable spawn_new_token policy

---

#### 5. **"Join quorum missing"**

**Problem:** N_OF_M join without `join_quorum`

**Solution:**
- Click **"Quick Fix"** button (recommended)
- Or manually set `join_quorum` in node properties (e.g., 2 of 3)

---

#### 6. **"Split ratio missing"**

**Problem:** RATIO split without `split_ratio_json`

**Solution:**
- Click **"Quick Fix"** button (recommended)
- Or manually set `split_ratio_json` in node properties (e.g., `{"branch1": 0.6, "branch2": 0.4}`)

---

## Best Practices

### 1. **Naming Conventions**

- **Graph Code:** `PROD_{PRODUCT}_{VERSION}` (e.g., `PROD_BAG_001`)
- **Node Code:** Uppercase, short (e.g., `CUT`, `SEW`, `QC`)
- **Node Name:** Descriptive (e.g., `Cut Material`, `Sew Body`)

### 2. **Graph Structure**

- ✅ Keep graphs simple (≤20 nodes)
- ✅ Use subgraphs for complex workflows
- ✅ Document complex logic in descriptions

### 3. **Validation**

- ✅ Validate frequently (before major changes)
- ✅ Fix errors immediately
- ✅ Review warnings before publish

### 4. **Versioning**

- ✅ Publish only when ready
- ✅ Use descriptive version names
- ✅ Document changes in version notes

### 5. **Performance**

- ✅ Set realistic WIP limits
- ✅ Use split/join for parallel work
- ✅ Avoid deep nesting (≤5 levels)

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `C` | Connect mode (create edge) |
| `Delete` | Delete selected node/edge |
| `Ctrl+Z` | Undo |
| `Ctrl+Y` | Redo |
| `Ctrl+S` | Save |
| `Ctrl+V` | Validate |
| `+` | Zoom in |
| `-` | Zoom out |
| `F` | Fit to screen |

---

## Related Documentation

- `FULL_DAG_DESIGNER_ROADMAP.md` - Technical roadmap
- `FEATURE_FLAGS.md` - Feature flags documentation
- `CURRENT_STATUS.md` - Current status

---

**Last Updated:** November 11, 2025  
**Questions?** Contact Development Team


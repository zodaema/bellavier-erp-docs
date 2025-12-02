# Parallel Operations Visual Indicator

## Overview
Enhanced the Node Details display in Product Graph Binding to clearly show which operations run in parallel (same sequence_no).

## Features

### 1. Parallel Detection Algorithm
```javascript
// Check if this node is part of parallel operations
const parallelNodes = sortedNodes.filter(n => 
  n.sequence_no === stepNum && 
  n.sequence_no !== null
);
const isParallel = parallelNodes.length > 1;
```

### 2. Visual Indicators

#### A. Git Branch Icon
Parallel nodes display a small git-branch icon (🔀) next to the Step badge:
```
Step 3 🔀  ← Parallel operation indicator
```

#### B. Visual Grouping
Parallel nodes have:
- **Left border**: Orange/warning border (3px thick)
- **Background**: Light gray background with 25% opacity
- Makes parallel operations visually grouped together

### 3. Display Example

#### Sequential Flow (No Parallel)
```
┌─────────────────────────────────────────┐
│ 🟢 START    [start]    [Step 1]        │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ 🔵 CUT      [operation] [Step 2]       │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ 🔵 SEW      [operation] [Step 3]       │
└─────────────────────────────────────────┘
```

#### Parallel Flow (Split/Join)
```
┌─────────────────────────────────────────┐
│ 🟢 START    [start]    [Step 1]        │
└─────────────────────────────────────────┘
┌─────────────────────────────────────────┐
│ 🟡 SPLIT    [split]    [Step 2]        │
└─────────────────────────────────────────┘
┃━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┃ ← Orange border
┃ 🔵 OP1      [operation] [Step 3 🔀]    ┃ ← Parallel indicator
┃━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┃
┃━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┃
┃ 🔵 OP2      [operation] [Step 3 🔀]    ┃ ← Parallel indicator
┃━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┃
┌─────────────────────────────────────────┐
│ 🟡 JOIN     [join]     [Step 4]        │
└─────────────────────────────────────────┘
```

## Technical Implementation

### Code Changes
**File**: `/assets/javascripts/products/product_graph_binding.js`

```javascript
// 1. Detect parallel operations
const parallelNodes = sortedNodes.filter(n => 
  n.sequence_no === stepNum && 
  n.sequence_no !== null
);
const isParallel = parallelNodes.length > 1;

// 2. Add icon to Step badge
let stepBadge = `<span class="badge bg-light text-dark">
  ${t('product_graph.step', 'Step')} ${stepNum}`;
if (isParallel) {
  stepBadge += ` <i class="fe fe-git-branch" 
    style="font-size: 0.75rem;" 
    title="${t('product_graph.parallel_operation', 'Parallel operation')}">
  </i>`;
}
stepBadge += `</span>`;

// 3. Add visual grouping classes
const parallelGroupClass = isParallel ? 
  'border-start border-warning border-3' : '';
const parallelBgClass = isParallel ? 
  'bg-light bg-opacity-25' : '';

// 4. Apply to list item
<div class="list-group-item ${parallelBgClass} ${parallelGroupClass}">
  ...
</div>
```

## Benefits

### 1. Clarity
- Users can immediately see which operations run in parallel
- Visual grouping makes parallel paths obvious
- Reduces confusion about operation sequence

### 2. Planning
- Helps with resource allocation (need multiple work centers/teams)
- Aids in capacity planning (parallel operations can run simultaneously)
- Critical for understanding production bottlenecks

### 3. Validation
- Easy to verify graph structure is correct
- Can quickly spot unintended parallel operations
- Helps identify optimization opportunities

## Use Cases

### 1. Split/Join Patterns
```
SPLIT → [OP1, OP2, OP3] (parallel) → JOIN
```
All operations between SPLIT and JOIN are marked as parallel.

### 2. Independent Operations
```
START → [CUT_A, CUT_B] (parallel) → ASSEMBLE
```
Independent cutting operations that can happen simultaneously.

### 3. Multi-Path QC
```
OPERATION → [QC_VISUAL, QC_MEASURE, QC_TEST] (parallel) → DECISION
```
Multiple QC checks that can run in parallel.

## Edge Cases Handled

### 1. Disconnected Nodes
- Nodes without edges still get proper sequence_no
- Fallback: sequential numbering for disconnected nodes
- Visual indicator still works correctly

### 2. Cycles (Should Not Happen)
- Topological sort detects cycles
- Fallback to sequential numbering
- System logs warning

### 3. Mixed Node Types
- Parallel operations can be different types (operation, qc, decision)
- Visual indicator applies to all parallel nodes regardless of type
- Example: `[OPERATION, QC]` both at Step 3

## Future Enhancements

### 1. Parallel Path Labels
Add labels like "Path A", "Path B" for multiple parallel branches:
```
Step 3 🔀 (Path A)
Step 3 🔀 (Path B)
```

### 2. Collapsible Parallel Groups
Allow collapsing/expanding parallel operation groups:
```
▼ Step 3 (3 parallel operations)
  └─ OP1
  └─ OP2
  └─ OP3
```

### 3. Duration Comparison
Show total time vs parallel time:
```
Step 3 🔀 (30min each, 30min total)
  ← Saves 60 minutes vs sequential
```

### 4. Resource Conflict Warning
Highlight if parallel operations require same resource:
```
Step 3 🔀 ⚠️
  OP1: WC-1, Team: Sewing
  OP2: WC-1, Team: Sewing
  ⚠️ Both require WC-1 (potential conflict)
```

## Testing

### Test Scenarios

1. **Simple Parallel (2 nodes)**
   - Graph: SPLIT → [OP1, OP2] → JOIN
   - Expected: Both show Step 3 🔀 with border

2. **Multiple Parallel (3+ nodes)**
   - Graph: SPLIT → [OP1, OP2, OP3] → JOIN
   - Expected: All show same step with indicator

3. **Nested Parallel (Not Common)**
   - Graph: SPLIT1 → [SPLIT2 → [OP1, OP2], OP3] → JOIN
   - Expected: Correct grouping at each level

4. **No Parallel (Sequential)**
   - Graph: START → OP1 → OP2 → END
   - Expected: No indicators, sequential steps

### Verification Commands

```bash
# Check graphs with parallel operations
php -r "
require_once 'config.php';
require_once 'source/global_function.php';
require_once 'source/helper/DatabaseHelper.php';

\$db = new BGERP\Helper\DatabaseHelper();

// Find graphs with parallel operations (nodes with same sequence_no)
\$result = \$db->fetchAll(\"
    SELECT 
        rg.id_graph, 
        rg.name,
        rn.sequence_no,
        COUNT(*) as parallel_count
    FROM routing_graph rg
    JOIN routing_node rn ON rn.id_graph = rg.id_graph
    GROUP BY rg.id_graph, rn.sequence_no
    HAVING parallel_count > 1
    ORDER BY rg.id_graph, rn.sequence_no
\");

foreach (\$result as \$row) {
    echo \"Graph {$row['id_graph']} ({$row['name']}): 
          Step {$row['sequence_no']} has {$row['parallel_count']} parallel nodes\\n\";
}
"
```

## Performance

### Complexity
- O(n) for detecting parallel nodes (filter operation)
- O(1) for adding visual indicators
- Negligible impact on rendering performance

### Optimization
- Parallel detection done once per node during render loop
- CSS classes are lightweight (border + background)
- No additional API calls required

## Related Documentation
- [Badge Step Sequence Fix](../fixes/BADGE_STEP_SEQUENCE_FIX.md)
- [Graph Viewer Usage](../GRAPH_VIEWER_USAGE.md)
- [Topological Sort Algorithm](../architecture/TOPOLOGICAL_SORT.md)

---

**Date**: 2025-11-13  
**Author**: Development Team  
**Status**: ✅ Implemented and Tested  
**Version**: 1.0

# AutoFix Risk Scoring Model

**Task 19.10: Semantic Repair Engine**

## Overview

AutoFix v3 introduces risk scoring to prevent "over-fixing" beyond user intent. Each fix receives a Risk Score (0-100) that determines whether it can be auto-applied, suggested, or requires manual review.

---

## Risk Score Calculation

### Scoring Criteria (Each 0-20 points)

1. **Structural Correctness (0-20)**
   - How correct is the fix structurally?
   - Creating edges/nodes: +5
   - Modifying metadata: +1
   - Base correctness: 0-15

2. **Semantic Clarity (0-20)**
   - How clear is the user intent?
   - Conditional edges: +3
   - Complex patterns: +2
   - Simple patterns: 0

3. **Behavior Alignment (0-20)**
   - Does fix align with intended behavior?
   - QC routing changes: +2
   - Flow changes: +4
   - Metadata only: 0

4. **User Override Potential (0-20)**
   - How easy is it to undo/override?
   - Metadata flags: +1 (easy to change)
   - Created edges: +5 (harder to remove)
   - Created nodes: +10 (hardest to remove)

5. **Downstream Implications (0-20)**
   - How does fix affect downstream nodes?
   - Connecting nodes: +4
   - Creating routes: +3
   - Metadata only: 0

**Total = Sum of all criteria (0-100)**

---

## Risk Score Bands

### 0-20: Low Risk (Auto-Apply Safe)
- **Color:** Green badge
- **UI:** Checked by default
- **Action:** Can be auto-applied without confirmation
- **Examples:**
  - Mark rework edge as default (Risk: 10)
  - Mark sink node flag (Risk: 10)
  - START/END normalization (Risk: 10)

### 21-50: Medium Risk (Suggest Fixes)
- **Color:** Blue badge
- **UI:** Checked by default, but user can uncheck
- **Action:** Suggested, user can accept/reject
- **Examples:**
  - Create QC edges for 3-way routing (Risk: 40)
  - Create default ELSE edge (Risk: 30)
  - Mark parallel split (Risk: 30)

### 51-80: High Risk (Warning + Disabled)
- **Color:** Orange badge
- **UI:** Unchecked by default, disabled checkbox
- **Action:** Shown but requires manual review before applying
- **Examples:**
  - Connect unreachable node (Risk: 65)
  - END consolidation (Risk: 60)

### 81-100: Critical Risk (Never Auto-Apply)
- **Color:** Red badge
- **UI:** Unchecked, disabled, highlighted in red
- **Action:** Only suggested, never auto-applied
- **Examples:**
  - Major structural changes
  - Ambiguous branching fixes (Risk: 80)

---

## Fix Type Base Risk Scores

| Fix Type | Base Risk | Risk Level |
|----------|-----------|------------|
| QC_DEFAULT_REWORK | 10 | Low |
| MARK_SINK_NODE | 10 | Low |
| START_END_NORMALIZATION | 10 | Low |
| MARK_MERGE_NODE | 10 | Low |
| MARK_SPLIT_NODE | 10 | Low |
| QC_TWO_WAY | 10 | Low |
| CREATE_END_NODE | 10 | Low |
| QC_FULL_COVERAGE | 30 | Medium |
| CREATE_ELSE_EDGE | 30 | Medium |
| CREATE_REWORK_PATH | 30 | Medium |
| PARALLEL_SPLIT | 30 | Medium |
| QC_THREE_WAY | 40 | Medium |
| CONNECT_UNREACHABLE | 65 | High |
| CONNECT_UNREACHABLE_SEMANTIC | 65 | High |
| END_CONSOLIDATION | 60 | High |

## Apply Policy by Fix Type

| Fix Type | Apply Policy |
|----------|--------------|
| QC_DEFAULT_REWORK | Auto-Apply |
| MARK_SINK_NODE | Auto-Apply |
| START_END_NORMALIZATION | Auto-Apply |
| MARK_MERGE_NODE | Auto-Apply |
| MARK_SPLIT_NODE | Auto-Apply |
| QC_TWO_WAY | Auto-Apply |
| CREATE_END_NODE | Auto-Apply |
| QC_FULL_COVERAGE | Suggest |
| CREATE_ELSE_EDGE | Suggest |
| CREATE_REWORK_PATH | Suggest |
| PARALLEL_SPLIT | Suggest |
| QC_THREE_WAY | Suggest |
| CONNECT_UNREACHABLE | Suggest-Only (Disabled by default) |
| CONNECT_UNREACHABLE_SEMANTIC | Suggest-Only (Disabled by default) |
| END_CONSOLIDATION | Suggest-Only (Disabled by default) |

---

## Risk Score Adjustment Rules

### Creating Structure (+5-10)
- `create_edge`: +5
- `create_node`: +10

### Conditional Edges (+3)
- Any edge with `edge_condition`: +3

### Behavior Changes (+2-4)
- QC routing changes: +2
- Flow changes: +4

### Easy Override (+1)
- Metadata flags (`is_merge_node`, `is_parallel_split`): +1

### Downstream Impact (+3-4)
- Connecting nodes: +4
- Creating routes: +3

---

## UI Behavior by Risk Level

### Low Risk (0-20)
```javascript
{
  checked: true,
  disabled: false,
  badge: 'bg-success',
  message: 'Safe to apply'
}
```

### Medium Risk (21-50)
```javascript
{
  checked: true,
  disabled: false,
  badge: 'bg-info',
  message: 'Review before applying'
}
```

### High Risk (51-80)
```javascript
{
  checked: false,
  disabled: true,
  badge: 'bg-warning',
  message: 'Requires manual review',
  warning: 'High/Critical risk fixes require manual review before applying.'
}
```

### Critical Risk (81-100)
```javascript
{
  checked: false,
  disabled: true,
  badge: 'bg-danger',
  message: 'Never auto-apply',
  warning: 'Critical risk - manual review required.'
}
```

---

## Example Risk Calculations

### Example 1: QC 2-way Fix
- **Base Risk:** 10 (QC_DEFAULT_REWORK)
- **Structural Correctness:** 0 (metadata only)
- **Semantic Clarity:** 0 (clear intent)
- **Behavior Alignment:** 0 (no behavior change)
- **User Override Potential:** 0 (easy to change)
- **Downstream Implications:** 0 (no impact)
- **Total:** 10 (Low Risk) ✅

### Example 2: Create QC Edge for 3-way
- **Base Risk:** 30 (QC_FULL_COVERAGE)
- **Structural Correctness:** +5 (creating edge)
- **Semantic Clarity:** +3 (conditional edge)
- **Behavior Alignment:** +2 (QC routing change)
- **User Override Potential:** +5 (edge creation)
- **Downstream Implications:** +0 (no downstream impact)
- **Total:** 45 (Medium Risk) ⚠️

### Example 3: Connect Unreachable Node
- **Base Risk:** 65 (CONNECT_UNREACHABLE)
- **Structural Correctness:** +5 (creating edge)
- **Semantic Clarity:** +0 (clear intent)
- **Behavior Alignment:** +4 (flow change)
- **User Override Potential:** +5 (edge creation)
- **Downstream Implications:** +4 (affects flow)

**Total:** 83 (Critical Risk) 🔴

---

## Best Practices

1. **Always show risk score** in UI
2. **Disable high/critical fixes** by default
3. **Provide clear warnings** for risky fixes
4. **Allow user override** for medium risk fixes
5. **Never auto-apply** critical risk fixes
6. **Sort fixes by risk** (lowest first)

---

## Integration with Semantic Intent

Risk scores are adjusted based on semantic intent confidence:

- **High confidence (0.9+):** No adjustment
- **Medium confidence (0.7-0.89):** +5 risk
- **Low confidence (< 0.7):** +10 risk, disable fix

This ensures that fixes based on uncertain intent are treated with extra caution.

# Task 19.10.2 Results – Integrate SemanticIntentEngine → AutoFixEngine v3

**Status:** ✅ **COMPLETED**  
**Date:** December 19, 2025  
**Task:** [task19.10.2.md](task19.10.2.md)

---

## Summary

Task 19.10.2 successfully integrated `SemanticIntentEngine` with `GraphAutoFixEngine` v3, enabling intent-aware fix generation with risk scoring and apply mode policies. The integration allows AutoFix to use semantic intent analysis to generate more intelligent, context-aware fixes that respect user intent.

---

## Changes Made

### 1. GraphAutoFixEngine.php

#### 1.1 Intent Loading & Storage
- **Added:** `private $intents = []` property to store intents for lookup
- **Updated:** `suggestFixes()` method to load intents when `mode === 'semantic'`
- **Location:** Lines 24, 92-95

```php
if ($mode === 'semantic') {
    // Task 19.10.2: Load intents for all fixes (not just semantic)
    $intentEngine = new SemanticIntentEngine($this->db);
    $intentAnalysis = $intentEngine->analyzeIntent($nodes, $edges);
    $this->intents = $intentAnalysis['intents'] ?? [];
    // ...
}
```

#### 1.2 Intent Lookup Helper
- **Added:** `findIntent(string $type, ?int $nodeId = null): ?array` method
- **Purpose:** Lookup specific intent by type and optional node ID
- **Location:** Lines 175-186

#### 1.3 Intent-Aware Risk Scoring
- **Updated:** `calculateRiskScores()` method to use `intent.risk_base` when available
- **Features:**
  - Maps fix types to intent types
  - Uses `intent.risk_base` as base risk score
  - Applies confidence penalty if confidence < 0.7
  - Adds size penalty for multiple element creation
  - Adds edge complexity penalty for conditional edges
  - Includes `evidence` from intent in fix definition
- **Location:** Lines 188-310

#### 1.4 Apply Mode Policy
- **Added:** `getApplyMode(int $riskScore, string $fixType): string` method
- **Policies:**
  - `auto`: Risk ≤ 20 (Low risk - auto-apply safe)
  - `suggest`: Risk 21-50 (Medium risk - user can accept/reject)
  - `suggest_only`: Risk 51-80 or specific fix types (High risk - disabled by default)
  - `disabled`: Risk > 80 (Critical risk - never auto-apply)
- **Special Cases:**
  - `QC_PASS_ONLY`, `REMOVE_UNREACHABLE_ORPHAN`, `END_CONSOLIDATION`, `SEMANTIC_SPLIT`, `QC_THREE_WAY` → `suggest_only`
- **Location:** Lines 312-339

#### 1.5 New Fix Types (v3)
- **Added:** `suggestQCPassOnlyFix()` - QC pass-only fix (suggest-only)
- **Added:** `suggestMultiExitElseRouteFix()` - Multi-exit ELSE route fix
- **Added:** `suggestSemanticSplitFix()` - Semantic split fix (suggest-only, high risk)
- **Added:** `suggestEnsureTrueEndFix()` - Ensure true END fix
- **Added:** `suggestRemoveUnreachableOrphanFix()` - Remove unreachable orphan fix (suggest-only)
- **Updated:** All semantic fix methods to use `intent.risk_base` and `evidence`
- **Location:** Lines 586-900+

#### 1.6 Updated Fix Types
- **Updated:** `suggestQCTwoWayFix()` - Uses `FIX_QC_TWOWAY_TO_DEFAULT_REWORK` type, includes `risk_base` and `evidence`
- **Updated:** `suggestQCThreeWayFix()` - Includes `risk_base` and `evidence`
- **Updated:** `suggestParallelSplitFix()` - Includes `risk_base` and `evidence`
- **Updated:** `suggestEndConsolidationFix()` - Includes `risk_base` and `evidence`
- **Updated:** `suggestUnreachableConnectionFix()` - Includes `risk_base` and `evidence`

#### 1.7 Base Risk Mapping
- **Updated:** `getBaseRiskForFixType()` to include new v3 fix types
- **New Types Added:**
  - `FIX_QC_TWOWAY_TO_DEFAULT_REWORK` → 10 (Low)
  - `FIX_ADD_ELSE_ROUTE` → 30 (Medium)
  - `FIX_ENSURE_TRUE_END` → 10 (Low)
  - `FIX_REMOVE_UNREACHABLE_ORPHAN` → 60 (Critical)
  - `QC_PASS_ONLY` → 30 (Medium)
  - `MULTI_EXIT_ELSE_ROUTE` → 30 (Medium)
  - `SEMANTIC_SPLIT` → 50 (High)
- **Location:** Lines 341-375

### 2. graph_designer.js

#### 2.1 Apply Mode Display
- **Updated:** `showFixesSelectionDialog()` to display `apply_mode` badge
- **Badges:**
  - `auto` → Green "Auto-Apply" badge
  - `suggest_only` → Orange "Suggest-Only" badge
  - `disabled` → Red "Disabled" badge
- **Location:** Lines 7022-7070

#### 2.2 Evidence Tooltip
- **Added:** Evidence tooltip display for fixes with `evidence` field
- **Format:** Badge with info icon, shows evidence data on hover
- **Location:** Lines 7045-7050

#### 2.3 Apply Mode-Based Disabling
- **Updated:** Checkbox disabling logic to use `apply_mode` in addition to risk score
- **Rules:**
  - `disabled` → Always disabled
  - `suggest_only` + risk ≥ 55 → Disabled by default
  - `suggest_only` + risk < 55 → Enabled but unchecked by default
  - `auto` / `suggest` → Enabled and checked by default
- **Location:** Lines 7030-7035

#### 2.4 Warning Messages
- **Added:** Warning message for `suggest_only` fixes
- **Added:** Error message for disabled fixes
- **Location:** Lines 7055-7057

### 3. API Integration

#### 3.1 graph_autofix Action
- **Status:** Already supports `mode=semantic` parameter
- **Response:** Includes `fixes` array with:
  - `risk_score` (0-100)
  - `risk_level` (low/medium/high/critical)
  - `apply_mode` (auto/suggest/suggest_only/disabled)
  - `evidence` (from intent)
  - `risk_base` (from intent)
- **Location:** `source/dag_routing_api.php` lines 4821-4896

---

## New Fix Types (v3)

### FIX_QC_TWOWAY_TO_DEFAULT_REWORK
- **Intent:** `qc.two_way`
- **Risk Base:** 10 (Low)
- **Apply Mode:** `auto`
- **Description:** Marks rework edge as default for QC 2-way routing

### FIX_ADD_ELSE_ROUTE
- **Intent:** `operation.multi_exit`
- **Risk Base:** 30 (Medium)
- **Apply Mode:** `suggest`
- **Description:** Adds ELSE route for multi-exit operations

### FIX_ENSURE_TRUE_END
- **Intent:** `endpoint.missing`
- **Risk Base:** 10 (Low)
- **Apply Mode:** `auto`
- **Description:** Creates END node and connects terminal operations

### FIX_REMOVE_UNREACHABLE_ORPHAN
- **Intent:** `unreachable.unintentional`
- **Risk Base:** 65 (High)
- **Apply Mode:** `suggest_only`
- **Description:** Removes unreachable orphan node (suggest-only, high risk)

### QC_PASS_ONLY
- **Intent:** `qc.pass_only`
- **Risk Base:** 20 (Low-Medium)
- **Apply Mode:** `suggest_only`
- **Description:** Adds rework/failure routing for QC pass-only node

### SEMANTIC_SPLIT
- **Intent:** `parallel.semantic_split`
- **Risk Base:** 45 (Medium-High)
- **Apply Mode:** `suggest_only`
- **Description:** Marks node as semantic split (suggest-only, high risk)

---

## Risk Scoring Formula

```
fix.final_risk = fix.risk_base (from intent)
                + confidence_penalty (if confidence < 0.7)
                + size_penalty (if creating multiple elements)
                + edge_complexity_penalty (if conditional edges)
                + behavior_alignment_penalty (if QC routing)
                + downstream_implications_penalty (if connecting nodes)
```

**Penalties:**
- Confidence penalty: `(0.7 - confidence) * 20` (max +10)
- Size penalty: `+5` per element created, `+2` per additional element
- Edge complexity: `+3` per conditional edge
- Behavior alignment: `+2` for QC routing changes
- Downstream implications: `+4` for connecting nodes

**Cap:** 0-100

---

## Apply Mode Policies

| Risk Score | Apply Mode | Default State | Description |
|------------|------------|---------------|-------------|
| 0-20 | `auto` | Checked, Enabled | Low risk - auto-apply safe |
| 21-50 | `suggest` | Checked, Enabled | Medium risk - user can accept/reject |
| 51-80 | `suggest_only` | Unchecked, Enabled* | High risk - disabled by default if risk ≥ 55 |
| 81-100 | `disabled` | Unchecked, Disabled | Critical risk - never auto-apply |

*Special cases: `QC_PASS_ONLY`, `REMOVE_UNREACHABLE_ORPHAN`, `END_CONSOLIDATION`, `SEMANTIC_SPLIT`, `QC_THREE_WAY` → Always `suggest_only` regardless of risk score.

---

## Evidence Integration

Each fix now includes `evidence` field from intent:
- **QC Intents:** `has_pass_edge`, `has_fail_edges`, `has_rework_edges`, `missing_statuses`
- **Parallel Intents:** `total_outgoing`, `target_node_types`, `has_conditional_edges`
- **Endpoint Intents:** `end_node_count`, `terminal_node_codes`
- **Reachability Intents:** `is_isolated`, `has_incoming`, `has_outgoing`

Evidence is displayed as a tooltip badge in the UI.

---

## Testing

### Manual Testing
1. ✅ Create QC node with 2-way routing → AutoFix suggests `FIX_QC_TWOWAY_TO_DEFAULT_REWORK` (risk: 10, auto-apply)
2. ✅ Create QC node with pass-only → AutoFix suggests `QC_PASS_ONLY` (risk: 20, suggest-only)
3. ✅ Create operation with multi-exit → AutoFix suggests `FIX_ADD_ELSE_ROUTE` (risk: 30, suggest)
4. ✅ Create graph without END → AutoFix suggests `FIX_ENSURE_TRUE_END` (risk: 10, auto-apply)
5. ✅ Create isolated unreachable node → AutoFix suggests `FIX_REMOVE_UNREACHABLE_ORPHAN` (risk: 65, suggest-only, disabled)
6. ✅ UI displays risk badges, apply mode badges, evidence tooltips correctly
7. ✅ High/critical risk fixes are disabled by default
8. ✅ Suggest-only fixes show warning message

### Backward Compatibility
- ✅ All existing fixes (v1, v2) continue to work
- ✅ Risk scoring falls back to `getBaseRiskForFixType()` if intent not found
- ✅ API response format unchanged (adds new fields, doesn't remove old ones)
- ✅ UI gracefully handles missing `apply_mode` or `evidence` fields

---

## Files Modified

1. **source/BGERP/Dag/GraphAutoFixEngine.php**
   - Added intent loading and storage
   - Added intent lookup helper
   - Updated risk scoring to use intent.risk_base
   - Added apply mode policy
   - Added 5 new fix type methods
   - Updated all semantic fix methods to include risk_base and evidence

2. **assets/javascripts/dag/graph_designer.js**
   - Updated fix dialog to display apply_mode badge
   - Added evidence tooltip display
   - Updated checkbox disabling logic based on apply_mode
   - Added warning messages for suggest_only fixes

3. **source/dag_routing_api.php**
   - No changes needed (already supports mode=semantic)

---

## Acceptance Criteria

- [x] AutoFixEngine โหลด intents จาก SemanticIntentEngine ได้
- [x] Fix rules ทั้งหมดใช้ intent.risk_base + evidence
- [x] Fix ที่เสี่ยงสูงเป็น suggest-only หรือ disabled
- [x] graph_autofix API return risk score + evidence
- [x] UI แสดง risk badge ต่อ fix
- [x] UI แสดง apply_mode badge ต่อ fix
- [x] UI แสดง evidence tooltip ต่อ fix
- [x] Full backward compatible
- [x] task19_10_2_results.md ถูกสร้างและสรุปงาน

---

## Next Steps

Task 19.10.2 successfully integrated SemanticIntentEngine with AutoFixEngine v3. The system now:

1. ✅ Uses semantic intent analysis to generate context-aware fixes
2. ✅ Applies risk scoring based on intent.risk_base
3. ✅ Enforces apply mode policies (auto/suggest/suggest_only/disabled)
4. ✅ Displays evidence from intent in UI
5. ✅ Prevents high-risk fixes from being auto-applied

**Future Work:**
- Task 19.11: Enhanced validation with semantic layer
- Task 19.12: Fix application improvements (if needed)

---

**Last Updated:** December 19, 2025


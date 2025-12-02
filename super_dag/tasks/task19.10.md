

# Task 19.10 — AutoFix v3 (Semantic Repair Engine)

**Status:** SPECIFICATION  
**Objective:** Introduce semantic-level inference, risk scoring, and safe graph repair that respects user intent, replacing the structural-only approach from AutoFix v2.  
**Scope:** No DB schema changes. No core routing logic changes. Backend + GraphDesigner updates only.

---

# 1. Background

AutoFix v2 handles *structural* repairs (missing END nodes, default routes, dangling nodes, simple QC coverage).  
However, several issues remain unsolved:

1. The system cannot infer **user intent**.
2. Some v2 fixes are technically correct but **semantically wrong** (over-fixing).
3. Multiple fixes may conflict—no **risk scoring** exists.
4. Complex patterns (QC + Parallel + SLA + Join) cannot be auto-repaired safely.
5. Validator and AutoFix are not integrated into a single pipeline.

AutoFix v3 addresses these issues.

---

# 2. Goals

### 2.1 Provide “Semantic Repair” Instead of Blind Structural Repair
AutoFix should:
- Understand graph patterns (QC → Next / QC → Rework / Multi-exit / Parallel / Join).
- Detect intent from context (adjacent nodes, behavior type, edge types).
- Avoid generating unwanted edges or transformations.

### 2.2 Introduce Risk Scoring
Each fix receives a *Risk Score (0–100)*:
- **0–20 Low** → Safe, always suggested.
- **21–50 Medium** → Needs user confirmation.
- **51–80 High** → Shown but highlighted in orange.
- **81–100 Critical** → Disabled unless user forces manual mode.

Risk scores prevent AutoFix from “over-fixing” beyond user intent.

### 2.3 Semantic Graph Analysis
New inference engine determines:
- Whether QC node intends 2-way (Pass/Fail → Rework) or 3-way routing.
- Whether multiple outgoing edges represent:
  - Parallel Split
  - Multi-exit logic (not parallel)
  - QC branching
  - Rework/Scrap exits
- Whether an unreachable subgraph is intentional (multi-flow process).

### 2.4 Unified Validator + AutoFix Pipeline
AutoFix v3 integrates directly with Validator:

```
validate → infer intent → generate fixes → rank → apply safely → revalidate
```

---

# 3. AutoFix v3 Architecture

### 3.1 New Class: `SemanticIntentEngine.php`
Purpose:
- Analyze patterns around nodes, edges, and behaviors.
- Compute intent tags:
  - `qc.two_way`
  - `qc.three_way`
  - `operation.multi_exit`
  - `parallel.true_split`
  - `parallel.semantic_split`
  - `endpoint.true_end`
  - `endpoint.multi_end`
  - `unreachable.intentional_subflow`
  - `unreachable.unintentional`

### 3.2 Update: `GraphAutoFixEngine.php` (v3)
New responsibilities:
- Load semantic tags.
- Generate contextual fixes per tag.
- Assign risk score per fix.
- Merge overlapping fixes into one suggestion group.

### 3.3 Update: `GraphValidationEngine.php`
New “semantic layer” of validation:
- Evaluate intent mismatch (e.g., QC with 1 fail path but user expects 2).
- Check if structural issues violate intended behavior.
- Mark errors as:
  - Structural Error
  - Semantic Error
  - Semantic Warning

---

# 4. Fix Types (v3)

### 4.1 QC Fixes
#### Case A — QC 2-way (Pass + Rework)  
**Intent:** user doesn’t need minor/major split  
**Fix:**  
- Insert default condition → Rework  
**Risk:** 10 (Safe)

#### Case B — QC 3-way  
**Fix:**  
- Insert missing edges for minor/major  
- Suggest assigning correct destinations  
**Risk:** 40 (Medium)

#### Case C — QC with fallback paths
**Fix:**  
- Normalize fallback → ELSE route  
**Risk:** 20 (Safe)

---

### 4.2 Parallel & Multi-exit Fixes
#### Case A — Multi-exit operation (not parallel)  
Example:
```
OP1 → QC
OP1 → Rework
OP1 → Scrap
```
**Fix:** none (just semantics)  
**Risk:** 5

#### Case B — True parallel (two operations downstream)
**Fix:** mark as parallel_split  
**Risk:** 30

#### Case C — Ambiguous branching  
**Fix:** disabled; only suggest  
**Risk:** 80 (Critical)

---

### 4.3 End Node Fixes
#### Case A — Multiple END nodes (unintentional)
**Fix:** consolidate  
**Risk:** 60 (High)

#### Case B — Multiple END nodes (intentional parallel termination)
**Fix:** none  
**Risk:** 5

#### Case C — Missing END
**Fix:** create END  
**Risk:** 10 (Safe)

---

### 4.4 Reachability Fixes
#### Case A — unreachable due to missing edge  
**Fix:** link nearest semantic successor  
**Risk:** 50 (Medium)

#### Case B — unreachable intentional subgraph  
**Fix:** none  
**Risk:** 0

---

# 5. Risk Scoring Model (v3)

### 5.1 Scoring Criteria (each 0–20)
- Structural correctness: 0–20  
- Semantic clarity: 0–20  
- Behavior alignment: 0–20  
- User override potential: 0–20  
- Downstream implications: 0–20  

Sum = 0–100

### 5.2 Score Bands
- 0–20: Auto-apply safe  
- 21–50: Suggest fixes  
- 51–80: Warning + disabled by default  
- 81–100: Critical → never auto-apply

---

# 6. Integration with Graph Designer

### 6.1 AutoFix Panel v3
New UI panel:
- Shows fix suggestions grouped by category
- Shows risk score badge
- Checkbox for “Require confirmation for Medium risk”
- Hard disabled for High/Critical

### 6.2 Fix Preview
Hover to preview graph changes:
- Highlight new edges in green
- Highlight removed edges in red (v3 generally avoids removing edges)
- Show semantic tag tooltips

---

# 7. Acceptance Criteria

### 7.1 Functional
- AutoFix v3 must never create/modify edges that conflict with user intent.
- v3 must rank fixes by risk.
- v3 must integrate with the existing validator pipeline.

### 7.2 UX
- Fix suggestions must show risk level.
- User must be able to accept/reject Medium-risk fixes.
- High and Critical fixes must be suggested only (never auto-applied).

### 7.3 Regression Safety
- Must pass all T19.8, T19.9 tests.
- New tests for:
  - Multiexit vs parallel inference
  - QC 2-way vs 3-way inference
  - Multi-END detection
  - Intentional multigraph

---

# 8. Deliverables

- `SemanticIntentEngine.php` (NEW)
- `GraphAutoFixEngine.php` (Updated)
- `GraphValidationEngine.php` (Updated)
- `conditional_edge_editor.js` (Minor update)
- `graph_designer.js` (UI for AutoFix v3)
- Documentation:
  - `task19_10_results.md`
  - `semantic_intent_rules.md`
  - `autofix_risk_scoring.md`

---

# 9. Out of Scope (v3)
- No auto-creation of nodes (except END)
- No rewriting of conditional expressions
- No removal of edges
- No ETA or Time Model changes (Task 20)

---

# END OF SPEC
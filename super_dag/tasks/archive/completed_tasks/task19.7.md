

# Task 19.7 — GraphValidator Hardening & Unified Validation Framework

## Overview
Task 19.7 focuses on fixing all known issues in the SuperDAG validation flow, consolidating scattered validation code, and introducing a unified, deterministic, predictable validation engine for both frontend (graph_designer.js) and backend (GraphValidator.php).

This task resolves:
- QC routing false warnings
- Incorrect “missing work center” errors
- Missing/duplicated START/END checks
- Parallel split/merge structural validation gaps
- Invalid conditional routing rules
- Machine binding contradictions
- Behavior constraints inconsistencies

---

## Goals

### 1. Replace legacy scatter‑validation with a single source of truth
Currently validation lives in:
- graph_designer.js (partial)
- GraphValidator.php
- dag_routing_api.php
- ConditionEvaluator.php
- ParallelMachineCoordinator.php (indirect)
- QC routing validator inside DAGRoutingService

These will be merged into a unified validation engine.

### 2. Fix QC routing validator (priority)
- QC nodes must NOT require 3 edges.
- QC nodes must validate only edges that originate from QC node.
- Missing QC status edges should be a *warning*, unless:
  - No ELSE/default edge exists.
- QC auto-rework logic must be recognized.

### 3. Structural DAG Checks
- Only 1 START allowed
- Only 1 END allowed
- No dead-end nodes unless explicitly marked as SINK/TERMINAL
- Parallel splits: ≥2 outgoing edges
- Merge nodes: ≥2 incoming edges
- No dangling edges
- No self-loop edges

### 4. Node Configuration Checks
- Operation nodes must have Work Center
- QC nodes must have QC Policy
- Machine-bound nodes must have Machine Binding type
- Execution Mode must match Behavior capabilities
- Parallel flags auto-inferred → remove redundant error alerts

### 5. Simplify user experience
Validation messages must:
- Be friendly
- Indicate EXACT node + problem
- Provide actionable suggestion

Format:
```
[ERROR] Node "QC1" → Missing QC route for fail_major.  
Suggestion: Add conditional edge or declare ELSE route.
```

---

## Deliverables

### 1. New file: `source/BGERP/Dag/GraphValidationEngine.php`
A unified validator replacing all scattered logic.

Includes 10 modules:
1. Node existence validator  
2. Start/End validator  
3. Edge integrity validator  
4. Parallel structure validator  
5. Merge structure validator  
6. QC routing validator  
7. Conditional routing validator  
8. Behavior–WorkCenter compatibility validator  
9. Machine binding validator  
10. Token-level runtime-check constraints (light mode)

### 2. Update: `GraphValidator.php`
- Become a thin wrapper calling `GraphValidationEngine`

### 3. Update: `graph_designer.js`
- Remove all legacy validation
- Call backend validator via `/validate_graph` before save
- Inline UI warnings for:
  - missing QC routes
  - unused ELSE routes
  - unreachable nodes

### 4. API Update: `dag_routing_api.php`
- Add new route: `validate_graph()`
- Replace saveGraph → validateGraph → saveGraph

### 5. Documentation
File created:  
`docs/super_dag/tasks/task19_7_results.md`

Contents:
- problem analysis  
- new validation architecture  
- validator rule list  
- before/after examples  
- expected UX behavior  
- future work (Task 19.8)

---

## Acceptance Criteria

| Requirement | Status |
|------------|--------|
| Unified validation engine | MUST |
| QC routing warnings fixed | MUST |
| START/END uniqueness | MUST |
| Parallel/merge consistency | MUST |
| UX-friendly error messages | MUST |
| Frontend only shows actionable errors | MUST |
| No breaking of legacy graphs | MUST |
| 100% backward compatible | MUST |
| No routing logic changed | MUST |
| No DAG execution logic changed | MUST |

---

## Next Task
**Task 19.8 – AutoFix Engine**  
Automatically repair simple validation issues (missing end, dangling edges, missing default edge, etc.)

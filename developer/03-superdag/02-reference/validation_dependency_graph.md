# Validation Dependency Graph

**Task 19.19: Validation Engine Lean-Up Precheck Report**

Diagram / table แสดง dependency ระหว่าง modules, classes, และ API actions

---

## Dependency Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Frontend (JS)                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ graph_designer.js                                     │  │
│  │  - validateGraphBeforeSave()                         │  │
│  │  - showValidationErrorDialog()                        │  │
│  │  - applyFixes()                                       │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ conditional_edge_editor.js                          │  │
│  │  - serializeCondition()                              │  │
│  │  - validateCondition()                               │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ GraphSaver.js                                        │  │
│  │  - serializeEdgeCondition()                         │  │
│  │  - serializeGraph()                                 │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                        │
                        │ HTTP API calls
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              API Layer (dag_routing_api.php)               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ graph_validate                                       │  │
│  │  → GraphValidationEngine::validate()                 │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ graph_autofix                                         │  │
│  │  → GraphValidationEngine::validate()                 │  │
│  │  → GraphAutoFixEngine::suggestFixes()                 │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ graph_apply_fixes                                     │  │
│  │  → GraphAutoFixEngine::suggestFixes()                 │  │
│  │  → ApplyFixEngine::apply()                            │  │
│  │  → GraphValidationEngine::validate()                  │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ graph_save / graph_save_draft / graph_publish        │  │
│  │  → GraphValidationEngine::validate()                 │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                        │
                        │ Direct instantiation
                        ▼
┌─────────────────────────────────────────────────────────────┐
│         Core Validation Engine (PHP Classes)                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ GraphValidationEngine                                 │  │
│  │  ├─→ SemanticIntentEngine::analyzeIntent()          │  │
│  │  ├─→ ReachabilityAnalyzer::analyze()                 │  │
│  │  └─→ ConditionEvaluator::evaluate() (indirect)        │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ SemanticIntentEngine                                  │  │
│  │  └─→ (no dependencies, pure analysis)                │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ ReachabilityAnalyzer                                  │  │
│  │  └─→ (no dependencies, pure analysis)                │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ ConditionEvaluator                                    │  │
│  │  └─→ (static method, no dependencies)                │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ GraphAutoFixEngine                                    │  │
│  │  ├─→ SemanticIntentEngine::analyzeIntent()           │  │
│  │  └─→ GraphValidationEngine::validate() (indirect)    │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ ApplyFixEngine                                        │  │
│  │  └─→ (no dependencies, pure graph manipulation)      │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ QCMetadataNormalizer                                  │  │
│  │  └─→ BGERP\Helper\JsonNormalizer                     │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Detailed Dependency Table

### GraphValidationEngine

| Dependency | Type | Usage | Notes |
|------------|------|-------|-------|
| `SemanticIntentEngine` | Class | `analyzeIntent()` | Used in `validateSemanticLayer()` |
| `ReachabilityAnalyzer` | Class | `analyze()` | Used in `validateReachabilityRules()` |
| `ConditionEvaluator` | Static | `evaluate()` | Indirect (used by edge validation) |
| `BGERP\Helper\JsonNormalizer` | Helper | JSON normalization | Used for JSON field normalization |
| `BGERP\Helper\TempIdHelper` | Helper | Temp ID handling | Used for temp ID management |

**Internal Dependencies:**
- `buildNodeMap()` - Used by all validation modules
- `buildEdgeMap()` - Used by all validation modules
- `formatErrorsDetail()` - Formats errors for output
- `formatWarningsDetail()` - Formats warnings for output
- `findIntent()` - Finds intent by type/node ID

---

### SemanticIntentEngine

| Dependency | Type | Usage | Notes |
|------------|------|-------|-------|
| None | - | - | Pure analysis, no external dependencies |

**Internal Dependencies:**
- `analyzeQCRoutingIntent()` - Analyzes QC routing patterns
- `analyzeParallelIntent()` - Analyzes parallel patterns
- `analyzeEndpointIntent()` - Analyzes endpoint patterns
- `analyzeReachabilityIntent()` - Analyzes reachability patterns
- `detectIntentConflicts()` - Detects intent conflicts
- `buildNodeMap()` - Builds node lookup map
- `extractQCStatusesFromCondition()` - Extracts QC statuses from condition
- `isReworkSinkEdge()` - Checks if edge is rework sink
- `checkParallelBranchesToEnds()` - Checks parallel branches to ENDs
- `buildReachabilityMap()` - Builds reachability map
- `findConnectedSubgraph()` - Finds connected subgraph

---

### ConditionEvaluator

| Dependency | Type | Usage | Notes |
|------------|------|-------|-------|
| None | - | - | Static method, pure function |

**Internal Dependencies:**
- None (pure function)

---

### ReachabilityAnalyzer

| Dependency | Type | Usage | Notes |
|------------|------|-------|-------|
| None | - | - | Pure analysis, no external dependencies |

**Internal Dependencies:**
- `buildNodeMap()` - Builds node lookup map
- `buildEdgeMap()` - Builds edge lookup map
- `findStartNode()` - Finds START node
- `buildReachabilityMap()` - Builds reachability map (BFS)
- `findUnreachableNodes()` - Finds unreachable nodes
- `findDeadEndNodes()` - Finds dead-end nodes
- `detectCycles()` - Detects cycles (DFS)
- `detectCycleDFS()` - DFS helper for cycle detection
- `findTerminalNodes()` - Finds terminal nodes (END nodes)

---

### GraphAutoFixEngine

| Dependency | Type | Usage | Notes |
|------------|------|-------|-------|
| `SemanticIntentEngine` | Class | `analyzeIntent()` | Used in `suggestFixes()` (semantic mode) |
| `GraphValidationEngine` | Class | `validate()` | Indirect (uses validation results) |

**Internal Dependencies:**
- `generateSemanticFixes()` - Generates semantic fixes (v3)
- `generateStructuralFixes()` - Generates structural fixes (v2)
- `calculateRiskScores()` - Calculates risk scores
- `getApplyMode()` - Determines apply mode
- `getBaseRiskForFixType()` - Gets base risk for fix type
- `getRiskLevel()` - Gets risk level string
- `suggestQCTwoWayFix()` - Suggests QC 2-way fix
- `suggestQCThreeWayFix()` - Suggests QC 3-way fix
- `suggestParallelSplitFix()` - Suggests parallel split fix
- `suggestEndConsolidationFix()` - Suggests END consolidation fix
- `suggestUnreachableConnectionFix()` - Suggests unreachable connection fix
- `suggestQCDefaultRework()` - Suggests QC default rework
- `suggestMarkSinkNodes()` - Suggests mark sink nodes
- `suggestDefaultElseRoute()` - Suggests default else route
- `suggestStartEndNormalization()` - Suggests START/END normalization
- `buildNodeMap()` - Builds node lookup map
- `buildEdgeMap()` - Builds edge lookup map
- `findIntent()` - Finds intent by type/node ID
- `isQCPassCondition()` - Checks if condition is QC pass
- `isReworkSinkEdge()` - Checks if edge is rework sink
- `generatePreview()` - Generates preview of patched graph

---

### ApplyFixEngine

| Dependency | Type | Usage | Notes |
|------------|------|-------|-------|
| None | - | - | Pure graph manipulation, no external dependencies |

**Internal Dependencies:**
- `applySingleOperation()` - Applies single operation
- `applyUpdateNodeProperty()` - Updates node property
- `applyMarkAsSink()` - Marks node as sink
- `applyCreateEndNode()` - Creates END node
- `applyRemoveNode()` - Removes node
- `applySetNodeMetadata()` - Sets node metadata
- `applySetNodeStartEndFlag()` - Sets START/END flag
- `applySetNodeSplitMergeFlag()` - Sets split/merge flag
- `applySetEdgeAsElse()` - Sets edge as else/default
- `applyCreateEdge()` - Creates edge
- `applyRemoveEdge()` - Removes edge
- `applyUpdateEdgeCondition()` - Updates edge condition
- `validateOperation()` - Validates operation before applying
- `validateGraphState()` - Validates graph state after applying
- `buildNodeMap()` - Builds node lookup map
- `buildEdgeMap()` - Builds edge lookup map
- `deepClone()` - Deep clones array

---

### QCMetadataNormalizer

| Dependency | Type | Usage | Notes |
|------------|------|-------|-------|
| `BGERP\Helper\JsonNormalizer` | Helper | `normalizeJsonField()` | Used for JSON field normalization |

**Internal Dependencies:**
- `normalizeFromFormData()` - Normalizes from form data
- `writeToTokenMetadata()` - Writes to token metadata
- `getFromTokenMetadata()` - Gets from token metadata
- `validate()` - Validates QC result format

---

## API Action Dependencies

### graph_validate

```
graph_validate (API)
    ↓
GraphValidationEngine::validate()
    ├─→ SemanticIntentEngine::analyzeIntent()
    ├─→ ReachabilityAnalyzer::analyze()
    └─→ ConditionEvaluator::evaluate() (indirect)
    ↓
Return validation result
```

**Dependencies:**
- `GraphValidationEngine` (direct)
- `SemanticIntentEngine` (via GraphValidationEngine)
- `ReachabilityAnalyzer` (via GraphValidationEngine)
- `ConditionEvaluator` (indirect, via edge validation)

---

### graph_autofix

```
graph_autofix (API)
    ↓
GraphValidationEngine::validate()
    ├─→ SemanticIntentEngine::analyzeIntent()
    ├─→ ReachabilityAnalyzer::analyze()
    └─→ ConditionEvaluator::evaluate() (indirect)
    ↓
GraphAutoFixEngine::suggestFixes()
    ├─→ SemanticIntentEngine::analyzeIntent() (if semantic mode)
    └─→ calculateRiskScores()
    ↓
Return fix suggestions
```

**Dependencies:**
- `GraphValidationEngine` (direct)
- `GraphAutoFixEngine` (direct)
- `SemanticIntentEngine` (via both engines)
- `ReachabilityAnalyzer` (via GraphValidationEngine)
- `ConditionEvaluator` (indirect)

---

### graph_apply_fixes

```
graph_apply_fixes (API)
    ↓
GraphAutoFixEngine::suggestFixes()
    ├─→ SemanticIntentEngine::analyzeIntent() (if semantic mode)
    └─→ calculateRiskScores()
    ↓
ApplyFixEngine::apply()
    └─→ applySingleOperation() (for each operation)
    ↓
GraphValidationEngine::validate() (re-validate)
    ├─→ SemanticIntentEngine::analyzeIntent()
    ├─→ ReachabilityAnalyzer::analyze()
    └─→ ConditionEvaluator::evaluate() (indirect)
    ↓
Return updated graph state
```

**Dependencies:**
- `GraphAutoFixEngine` (direct)
- `ApplyFixEngine` (direct)
- `GraphValidationEngine` (direct, for re-validation)
- `SemanticIntentEngine` (via GraphAutoFixEngine and GraphValidationEngine)
- `ReachabilityAnalyzer` (via GraphValidationEngine)
- `ConditionEvaluator` (indirect)

---

### graph_save / graph_save_draft / graph_publish

```
graph_save / graph_save_draft / graph_publish (API)
    ↓
GraphValidationEngine::validate()
    ├─→ SemanticIntentEngine::analyzeIntent()
    ├─→ ReachabilityAnalyzer::analyze()
    └─→ ConditionEvaluator::evaluate() (indirect)
    ↓
If valid, save/publish graph
```

**Dependencies:**
- `GraphValidationEngine` (direct)
- `SemanticIntentEngine` (via GraphValidationEngine)
- `ReachabilityAnalyzer` (via GraphValidationEngine)
- `ConditionEvaluator` (indirect)

---

## Frontend Dependencies

### graph_designer.js

| Dependency | Type | Usage | Notes |
|------------|------|-------|-------|
| `graph_validate` API | HTTP | `validateGraphBeforeSave()` | Calls API for validation |
| `graph_autofix` API | HTTP | `applyFixes()` | Calls API for autofix suggestions |
| `graph_apply_fixes` API | HTTP | `applyFixes()` | Calls API to apply fixes |
| `ConditionEvaluator` logic | Indirect | Condition validation | Uses backend validation only (engine-driven). Client-side checks are limited to basic UI/UX (e.g. required fields, simple guards). |

**Internal Dependencies:**
- `validateGraphBeforeSave()` - Validates graph before save
- `showValidationErrorDialog()` - Shows validation error dialog
- `buildErrorListHtml()` - Builds error list HTML
- `applyFixes()` - Applies autofix

---

### conditional_edge_editor.js

| Dependency | Type | Usage | Notes |
|------------|------|-------|-------|
| `ConditionEvaluator` logic | Indirect | Condition validation | Performs basic UX-level checks only; backend ConditionEvaluator remains the single source of truth for routing decisions. |

**Internal Dependencies:**
- `serializeCondition()` - Serializes condition to JSON
- `serializeConditionGroups()` - Serializes condition groups
- `validateCondition()` - Validates condition (client-side)

---

### GraphSaver.js

| Dependency | Type | Usage | Notes |
|------------|------|-------|-------|
| None | - | - | Pure serialization |

**Internal Dependencies:**
- `serializeEdgeCondition()` - Serializes edge condition
- `serializeGraph()` - Serializes entire graph

---

## Circular Dependencies

**None detected.** All dependencies are unidirectional:
- Frontend → API → Backend
- GraphValidationEngine → SemanticIntentEngine (one-way)
- GraphAutoFixEngine → GraphValidationEngine (one-way, indirect)
- ApplyFixEngine → GraphValidationEngine (one-way, for re-validation only)

---

## Duplicate Logic

### 1. Condition Evaluation

**Location:**
- Backend: `ConditionEvaluator::evaluate()` (single source of truth)
- Frontend: `conditional_edge_editor.js::validateCondition()` (client-side validation)

**Risk:** Low–Medium

- Backend ConditionEvaluator is the single source of truth for routing; frontend should only perform shallow UX checks (e.g. non-empty fields, basic type sanity).
- UX risk: if frontend blocking rules diverge too much from backend behavior, users may see confusing differences between “cannot save” (frontend) vs. “validation failed” (backend).
- Solution: Keep frontend checks shallow and, in the future, consider driving complex UI hints from backend-provided metadata instead of duplicating logic.

### 2. Node/Edge Map Building

**Location:**
- `GraphValidationEngine::buildNodeMap()` / `buildEdgeMap()`
- `SemanticIntentEngine::buildNodeMap()`
- `ReachabilityAnalyzer::buildNodeMap()` / `buildEdgeMap()`
- `GraphAutoFixEngine::buildNodeMap()` / `buildEdgeMap()`
- `ApplyFixEngine::buildNodeMap()` / `buildEdgeMap()`

**Risk:** Low
- Same logic duplicated in multiple classes
- Solution: Extract to shared helper class

### 3. QC Status Extraction

**Location:**
- `GraphValidationEngine::extractQCStatusesFromCondition()`
- `SemanticIntentEngine::extractQCStatusesFromCondition()`

**Risk:** Medium
- Same logic duplicated in two classes
- Solution: Extract to shared helper method or `ConditionEvaluator`

---

## Legacy Dependencies

### validateGraphStructure()

**Location:** `dag_routing_api.php` (function, not class)

**Status:** Deprecated, kept for backward compatibility

**Dependencies:**
- `DAGValidationService` (legacy service)
- Direct SQL queries (not using prepared statements in some places)

**Replacement:** `GraphValidationEngine::validate()`

**Risk:** High (if still used)
- Solution: Remove after confirming no usage

---

## Summary

**Total Modules:** 7 core classes
**Total API Actions:** 4 (graph_validate, graph_autofix, graph_apply_fixes, graph_save/draft/publish)
**Total Frontend Modules:** 3 (graph_designer.js, conditional_edge_editor.js, GraphSaver.js)

**Dependency Patterns:**
- Unidirectional (no circular dependencies)
- Layered architecture (Frontend → API → Backend)
- Pure analysis classes (no database dependencies)

**Duplicate Logic:**
- Condition evaluation (backend + frontend)
- Node/Edge map building (multiple classes)
- QC status extraction (2 classes)

**Legacy Code:**
- `validateGraphStructure()` function (deprecated)

---

**Last Updated:** November 24, 2025  
**Task:** 19.19 - Validation Engine Lean-Up Precheck Report


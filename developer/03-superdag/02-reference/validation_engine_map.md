# Validation Engine Map

**Task 19.19: Validation Engine Lean-Up Precheck Report**

แผนที่ high-level ของ SuperDAG Validation Engine และแต่ละ module ทำหน้าที่อะไร

---

## Overview

SuperDAG Validation Engine เป็นระบบ validation แบบ unified ที่รวม validation logic ทั้งหมดไว้ในที่เดียว แทนที่ validation ที่กระจัดกระจายในหลายไฟล์

**Architecture:**
- **Backend:** PHP classes ใน `source/BGERP/Dag/`
- **Frontend:** JavaScript modules ใน `assets/javascripts/dag/`
- **API:** `source/dag_routing_api.php` (actions: `graph_validate`, `graph_autofix`, `graph_apply_fixes`)

---

## Core Modules

### 1. GraphValidationEngine.php

**Purpose:** Single source of truth สำหรับ graph validation ทั้งหมด

**Key Methods:**
- `validate(array $nodes, array $edges, array $options): array` - Main entry point
- `validateNodeExistence()` - ตรวจสอบ node existence และ uniqueness
- `validateStartEnd()` - ตรวจสอบ START/END nodes
- `validateEdgeIntegrity()` - ตรวจสอบ edge connectivity
- `validateParallelStructure()` - ตรวจสอบ parallel split structure
- `validateMergeStructure()` - ตรวจสอบ merge node structure
- `validateQCRouting()` - ตรวจสอบ QC routing structure (light check)
- `validateConditionalRouting()` - ตรวจสอบ conditional edge structure
- `validateBehaviorWorkCenter()` - ตรวจสอบ behavior-work center compatibility
- `validateMachineBinding()` - ตรวจสอบ machine binding
- `validateNodeConfiguration()` - ตรวจสอบ node configuration
- `validateSemanticLayer()` - Semantic validation layer (v3)
- `validateQCRoutingSemantic()` - QC routing semantic validation
- `validateParallelSemantic()` - Parallel structure semantic validation
- `validateEndpointSemantic()` - Endpoint semantic validation
- `validateReachabilityRules()` - Reachability validation (uses ReachabilityAnalyzer)
- `validateTimeSLABasic()` - Basic time/SLA validation

**Dependencies:**
- `SemanticIntentEngine` - สำหรับ semantic intent analysis
- `ReachabilityAnalyzer` - สำหรับ reachability analysis
- `ConditionEvaluator` - สำหรับ condition evaluation (indirect)

**Input:**
- `$nodes`: Array of node data
- `$edges`: Array of edge data
- `$options`: ['graphId', 'isOldGraph', 'mode' => 'publish'|'save'|'draft']

**Output:**
```php
[
    'valid' => bool,
    'errors' => array,
    'warnings' => array,
    'summary' => array,
    'score' => int,
    'intents' => array, // Task 19.11
    'errors_detail' => array, // Task 19.11
    'warnings_detail' => array // Task 19.11
]
```

**Validation Modules (11 modules):**
1. Node Existence Validator
2. Start/End Validator
3. Edge Integrity Validator
4. Parallel Structure Validator
5. Merge Structure Validator
6. QC Routing Validator (structural)
7. Conditional Routing Validator
8. Behavior-WorkCenter Compatibility Validator
9. Machine Binding Validator
10. Node Configuration Validator
11. Semantic Validation Layer (v3)

---

### 2. SemanticIntentEngine.php

**Purpose:** วิเคราะห์ graph patterns เพื่อ infer user intent

**Key Methods:**
- `analyzeIntent(array $nodes, array $edges, array $options): array` - Main entry point
- `analyzeQCRoutingIntent()` - วิเคราะห์ QC routing intent (two_way, three_way, pass_only)
- `analyzeParallelIntent()` - วิเคราะห์ parallel intent (true_split, semantic_split, merge)
- `analyzeEndpointIntent()` - วิเคราะห์ endpoint intent (missing, true_end, multi_end, unintentional_multi)
- `analyzeReachabilityIntent()` - วิเคราะห์ reachability intent (intentional_subflow, unintentional)
- `detectIntentConflicts()` - ตรวจจับ intent conflicts (Task 19.17)

**Dependencies:**
- None (pure analysis, no database queries)

**Input:**
- `$nodes`: Array of node data
- `$edges`: Array of edge data
- `$options`: Optional configuration

**Output:**
```php
[
    'intents' => [
        [
            'type' => string, // e.g., 'qc.two_way', 'parallel.true_split'
            'node_id' => int|string,
            'confidence' => float, // 0.0 - 1.0
            'evidence' => array,
            'risk_base' => int // 0-100
        ],
        ...
    ],
    'patterns' => array,
    'conflicts' => array // Task 19.17
]
```

**Intent Types:**
- QC: `qc.two_way`, `qc.three_way`, `qc.pass_only`
- Parallel: `parallel.true_split`, `parallel.semantic_split`, `parallel.merge`
- Operation: `operation.multi_exit`, `operation.linear_only`
- Endpoint: `endpoint.missing`, `endpoint.true_end`, `endpoint.multi_end`, `endpoint.unintentional_multi`
- Reachability: `unreachable.intentional_subflow`, `unreachable.unintentional`
- Sink: `sink.expected`

---

### 3. ConditionEvaluator.php

**Purpose:** Evaluate conditions on edges (single source of truth for condition evaluation)

**Key Methods:**
- `evaluate(array $condition, array $context): bool` - Static method, evaluate condition

**Dependencies:**
- None (pure function)

**Input:**
- `$condition`: Condition object (token_property, job_property, node_property, default, expression)
- `$context`: Context data (token, job, node metadata)

**Output:**
- `bool`: True if condition matches, false otherwise

**Condition Types:**
- `token_property`: Token property conditions (e.g., `qc_result.status == 'pass'`)
- `job_property`: Job property conditions
- `node_property`: Node property conditions
- `default`: Default/else route (always returns true)
- `expression`: Complex expression (legacy support)

---

### 4. QCMetadataNormalizer.php

**Purpose:** Standardize QC result format in token metadata

**Key Methods:**
- `normalizeFromFormData(array $formData, int $operatorId): array` - Normalize from form data
- `writeToTokenMetadata(\mysqli $db, int $tokenId, array $qcResult): bool` - Write to token metadata
- `getFromTokenMetadata(array $token): ?array` - Get from token metadata
- `validate(array $qcResult): array` - Validate QC result format

**Dependencies:**
- `BGERP\Helper\JsonNormalizer` - สำหรับ JSON normalization

**Valid QC Statuses:**
- `pass`
- `fail_minor`
- `fail_major`

---

### 5. ReachabilityAnalyzer.php

**Purpose:** วิเคราะห์ reachability, dead-ends, และ cycles

**Key Methods:**
- `analyze(array $nodes, array $edges, array $intents = []): array` - Main entry point
- `buildReachabilityMap()` - สร้าง reachability map จาก START node
- `findUnreachableNodes()` - หา unreachable nodes
- `findDeadEndNodes()` - หา dead-end nodes
- `detectCycles()` - ตรวจจับ cycles
- `findTerminalNodes()` - หา terminal nodes (END nodes)

**Dependencies:**
- None (pure analysis)

**Input:**
- `$nodes`: Array of node data
- `$edges`: Array of edge data
- `$intents`: Optional semantic intents (for intentional subflow detection)

**Output:**
```php
[
    'reachable' => array, // Node IDs reachable from START
    'unreachable' => array, // Unreachable nodes
    'dead_ends' => array, // Dead-end nodes
    'cycles' => array, // Detected cycles
    'terminal_nodes' => array // Terminal nodes (END nodes)
]
```

---

### 6. GraphAutoFixEngine.php

**Purpose:** Generate autofix suggestions based on validation results

**Key Methods:**
- `suggestFixes(array $nodes, array $edges, array $validationResult, array $options): array` - Main entry point
- `generateSemanticFixes()` - Generate semantic fixes (v3)
- `generateStructuralFixes()` - Generate structural fixes (v2)
- `calculateRiskScores()` - Calculate risk scores for fixes
- `getApplyMode()` - Determine apply mode (auto, suggest, suggest_only, disabled)
- `suggestQCTwoWayFix()` - Suggest QC 2-way fix
- `suggestQCThreeWayFix()` - Suggest QC 3-way fix
- `suggestParallelSplitFix()` - Suggest parallel split fix
- `suggestEndConsolidationFix()` - Suggest END consolidation fix
- `suggestUnreachableConnectionFix()` - Suggest unreachable connection fix
- `suggestQCDefaultRework()` - Suggest QC default rework
- `suggestMarkSinkNodes()` - Suggest mark sink nodes
- `suggestDefaultElseRoute()` - Suggest default else route

**Dependencies:**
- `SemanticIntentEngine` - สำหรับ semantic intent analysis
- `GraphValidationEngine` - สำหรับ validation results

**Input:**
- `$nodes`: Array of node data
- `$edges`: Array of edge data
- `$validationResult`: Validation result from GraphValidationEngine
- `$options`: ['mode' => 'metadata'|'structural'|'semantic']

**Output:**
```php
[
    'fixes' => [
        [
            'id' => string,
            'type' => string,
            'severity' => string,
            'target_node_id' => int|string,
            'target_edge_id' => int|string,
            'title' => string,
            'description' => string,
            'operations' => array,
            'risk_score' => int, // 0-100
            'risk_level' => string, // Low, Medium, High, Critical
            'apply_mode' => string, // auto, suggest, suggest_only, disabled
            'evidence' => array
        ],
        ...
    ],
    'patched_nodes' => array,
    'patched_edges' => array
]
```

**Fix Modes:**
- `metadata` (v1): Metadata-only fixes (low risk)
- `structural` (v2): Structural fixes (medium risk)
- `semantic` (v3): Semantic fixes (high risk, intent-aware)

---

### 7. ApplyFixEngine.php

**Purpose:** Execute autofix operations on graph state

**Key Methods:**
- `apply(array $nodes, array $edges, array $operations, array $options): array` - Main entry point
- `applySingleOperation()` - Apply single operation
- `applyUpdateNodeProperty()` - Update node property
- `applyMarkAsSink()` - Mark node as sink
- `applyCreateEndNode()` - Create END node
- `applyRemoveNode()` - Remove node
- `applySetNodeMetadata()` - Set node metadata
- `applySetNodeStartEndFlag()` - Set START/END flag
- `applySetNodeSplitMergeFlag()` - Set split/merge flag
- `applySetEdgeAsElse()` - Set edge as else/default
- `applyCreateEdge()` - Create edge
- `applyRemoveEdge()` - Remove edge
- `applyUpdateEdgeCondition()` - Update edge condition

**Dependencies:**
- None (pure graph manipulation)

**Input:**
- `$nodes`: Array of node data
- `$edges`: Array of edge data
- `$operations`: Array of operation definitions
- `$options`: ['validate' => bool, 'strict' => bool]

**Output:**
```php
[
    'nodes' => array, // Modified nodes
    'edges' => array, // Modified edges
    'applied_count' => int,
    'errors' => array
]
```

**Operation Types:**
- `UPDATE_NODE_PROPERTY`
- `MARK_AS_SINK`
- `CREATE_END_NODE`
- `REMOVE_NODE`
- `SET_NODE_METADATA`
- `SET_NODE_START_END_FLAG`
- `SET_NODE_SPLIT_MERGE_FLAG`
- `SET_EDGE_AS_ELSE`
- `CREATE_EDGE`
- `REMOVE_EDGE`
- `UPDATE_EDGE_CONDITION`

**Features:**
- Atomic operations (rollback on failure)
- Validation before/after
- Strict mode (throw on error) vs. lenient mode (collect errors)

---

## API Integration

### dag_routing_api.php

**Actions:**
- `graph_validate` - Validate graph structure
- `graph_autofix` - Generate autofix suggestions
- `graph_apply_fixes` - Apply autofix operations

**Flow:**
1. `graph_validate` → `GraphValidationEngine::validate()`
2. `graph_autofix` → `GraphValidationEngine::validate()` → `GraphAutoFixEngine::suggestFixes()`
3. `graph_apply_fixes` → `GraphAutoFixEngine::suggestFixes()` → `ApplyFixEngine::apply()` → `GraphValidationEngine::validate()`

**Other Actions (using validation):**
- `graph_save` - Uses `GraphValidationEngine` (publish mode)
- `graph_save_draft` - Uses `GraphValidationEngine` (draft mode, warnings only)
- `graph_publish` - Uses `GraphValidationEngine` (publish mode)

---

## Frontend Integration

### graph_designer.js

**Key Functions:**
- `validateGraphBeforeSave(cy)` - Validate graph before save (calls `graph_validate` API)
- `showValidationErrorDialog()` - Show validation error dialog
- `buildErrorListHtml()` - Build error list HTML
- `applyFixes()` - Apply autofix (calls `graph_apply_fixes` API)

**Flow:**
1. User clicks Save/Publish
2. `validateGraphBeforeSave()` calls `graph_validate` API
3. If errors, show error dialog with autofix button
4. If autofix clicked, call `graph_autofix` API
5. User selects fixes, calls `graph_apply_fixes` API
6. Update graph state and re-validate

### conditional_edge_editor.js

**Key Functions:**
- `serializeCondition()` - Serialize condition to JSON
- `serializeConditionGroups()` - Serialize condition groups
- `validateCondition()` - Validate condition (client-side)

**Integration:**
- Uses `ConditionEvaluator` logic (backend) for validation
- Serializes conditions in format compatible with `ConditionEvaluator`

### GraphSaver.js

**Key Functions:**
- `serializeEdgeCondition()` - Serialize edge condition
- `serializeGraph()` - Serialize entire graph

**Integration:**
- Serializes graph data for API calls
- Ensures compatibility with backend validation

---

## Validation Categories

### 1. Structural Validation
- Node existence and uniqueness
- START/END node requirements
- Edge integrity
- Parallel structure
- Merge structure

### 2. Semantic Validation
- QC routing semantic
- Parallel semantic
- Endpoint semantic
- Reachability semantic
- Intent conflict detection

### 3. QC-Specific Validation
- QC routing structure
- QC routing semantic
- QC status coverage
- QC condition validation

### 4. Reachability Validation
- Unreachable nodes
- Dead-end nodes
- Cycle detection
- Terminal nodes

### 5. Configuration Validation
- Behavior-work center compatibility
- Machine binding
- Node configuration
- Time/SLA basic validation

---

## Data Flow

```
User Action (Save/Publish)
    ↓
Frontend: validateGraphBeforeSave()
    ↓
API: graph_validate
    ↓
GraphValidationEngine::validate()
    ├─→ SemanticIntentEngine::analyzeIntent()
    ├─→ ReachabilityAnalyzer::analyze()
    └─→ ConditionEvaluator::evaluate() (indirect)
    ↓
Return validation result
    ↓
Frontend: Show errors/warnings
    ↓
If autofix requested:
    ↓
API: graph_autofix
    ↓
GraphAutoFixEngine::suggestFixes()
    ├─→ SemanticIntentEngine::analyzeIntent()
    └─→ Calculate risk scores
    ↓
Return fix suggestions
    ↓
User selects fixes
    ↓
API: graph_apply_fixes
    ↓
ApplyFixEngine::apply()
    ↓
GraphValidationEngine::validate() (re-validate)
    ↓
Return updated graph state
```

---

## Test Coverage

**Test Suite (Task 19.18):**
- `ValidateGraphTest.php` - Main validation test harness
- `SemanticSnapshotTest.php` - Semantic intent snapshot testing
- `AutoFixPipelineTest.php` - Autofix pipeline testing

**Test Fixtures:**
- 14+ graph fixtures covering all validation categories
- QC Routing (4), Parallel/Multi-Exit (4), Reachability (3), Endpoint (2), Semantic (2)

**Coverage:**
- Structural validation: ✅
- Semantic validation: ✅
- QC routing: ✅
- Reachability: ✅
- Autofix pipeline: ✅

---

## Legacy Code

### Deprecated Functions

1. **validateGraphStructure()** (in `dag_routing_api.php`)
   - Status: Still exists but not used by new code
   - Replacement: `GraphValidationEngine::validate()`
   - Note: Kept for backward compatibility only

2. **validateReachabilitySemantic()** (in `GraphValidationEngine.php`)
   - Status: `@deprecated` (Task 19.15)
   - Replacement: `validateReachabilityRules()` (uses `ReachabilityAnalyzer`)

3. **Legacy node types** (`split`, `join`, `wait`, `decision`)
   - Status: Deprecated (Task 19.13)
   - Replacement: `is_parallel_split`, `is_merge_node` flags, conditional edges

### Legacy Support

- Old graphs (created before 2025-11-15) have relaxed validation
- Legacy node types still validated but cannot be created/updated
- `validateGraphStructure()` kept for backward compatibility

---

## Summary

**Core Modules:** 7
- GraphValidationEngine (main validator)
- SemanticIntentEngine (intent analysis)
- ConditionEvaluator (condition evaluation)
- QCMetadataNormalizer (QC metadata)
- ReachabilityAnalyzer (reachability analysis)
- GraphAutoFixEngine (autofix suggestions)
- ApplyFixEngine (fix execution)

**Validation Modules:** 11 (in GraphValidationEngine)
**Intent Types:** 13+ (in SemanticIntentEngine)
**Fix Types:** 20+ (in GraphAutoFixEngine)
**Operation Types:** 11 (in ApplyFixEngine)

**Test Coverage:** 14+ fixtures, 3 test harnesses

**Status:** Production-ready, comprehensive validation layer

---

**Last Updated:** November 24, 2025  
**Task:** 19.19 - Validation Engine Lean-Up Precheck Report


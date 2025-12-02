# SuperDAG Validation Engine Lean-Up Plan v2.0

**Document Version:** 2.0  
**Date:** 2025-11-24  
**Status:** Production-Ready Specification  
**Task:** 19.19 → 19.20+ (Lean-Up Phase Implementation)

---

## 1. Overview

This document defines the complete, executable Lean-Up Plan for the SuperDAG Validation Engine. It is structured as a deterministic specification that can be executed by an AI agent without ambiguity.

**Scope:**
- Phase 1: Quick Wins (Low Risk / High Clarity) - 1-2 days
- Phase 2: Structural Refactor (Medium Risk) - 3-5 days
- Phase 3: Deep Clean & ETA Preparation (High Risk) - 5-7 days

**Total Estimated Time:** 9-14 days

**Principle:** Quality > Speed. Data integrity and security are non-negotiable.

---

## 2. System Architecture Summary

### 2.1 Current State (Post Task 19.18)

**Core Engines:**
- `GraphValidationEngine` - Single source of truth for validation (11 modules)
- `SemanticIntentEngine` - Intent analysis (no database dependencies)
- `ReachabilityAnalyzer` - Reachability/dead-end/cycle detection
- `ConditionEvaluator` - Condition evaluation (static methods)
- `GraphAutoFixEngine` - Autofix suggestions (v1/v2/v3 modes)
- `ApplyFixEngine` - Atomic fix application with rollback
- `QCMetadataNormalizer` - QC metadata standardization

**API Actions:**
- `graph_validate` - Validation only
- `graph_autofix` - Generate fix suggestions
- `graph_apply_fixes` - Apply fixes and re-validate
- `graph_save` / `graph_save_draft` / `graph_publish` - Save with validation

**Frontend:**
- `graph_designer.js` - Engine-driven validation (no client-side validation logic)
- `conditional_edge_editor.js` - Condition serialization (UX checks only)
- `GraphSaver.js` - Graph serialization

**Test Infrastructure:**
- `ValidateGraphTest.php` - 14+ fixtures
- `SemanticSnapshotTest.php` - Intent snapshot comparison
- `AutoFixPipelineTest.php` - Complete autofix flow testing

### 2.2 Key System Constraints

1. **Default Routes:** Use `{"type": "default"}` condition (Task 19.16)
2. **QC 2-Way Routing:** Valid (warning-only, not error) (Task 19.16)
3. **Legacy Node Types:** `split`, `join`, `wait`, `decision` - Deprecated (Task 19.13)
4. **Validation Mode:** Backend-only (frontend removed in Task 19.14)
5. **Intent Conflicts:** Detected and reported (Task 19.17)

---

## 3. Validation Execution Order (Strict Specification)

### 3.1 GraphValidationEngine::validate() Execution Sequence

**File:** `source/BGERP/Dag/GraphValidationEngine.php`  
**Method:** `public function validate(array $nodes, array $edges, array $options = []): array`

**Execution Order (MUST NOT CHANGE):**

```
1. Build node/edge maps
   → buildNodeMap($nodes)
   → buildEdgeMap($edges, $nodeMap)

2. Module 1: Node Existence Validator
   → validateNodeExistence($nodes, $nodeMap)
   → Returns: ['errors' => [], 'warnings' => [], 'rules_validated' => int]

3. Module 2: Start/End Validator
   → validateStartEnd($nodes, $nodeMap)
   → Returns: ['errors' => [], 'warnings' => [], 'rules_validated' => int]

4. Module 3: Edge Integrity Validator
   → validateEdgeIntegrity($nodes, $edges, $nodeMap, $edgeMap)
   → Returns: ['errors' => [], 'warnings' => [], 'rules_validated' => int]

5. Module 4: Parallel Structure Validator
   → validateParallelStructure($nodes, $edges, $nodeMap, $edgeMap)
   → Returns: ['errors' => [], 'warnings' => [], 'rules_validated' => int]

6. Module 5: Merge Structure Validator
   → validateMergeStructure($nodes, $edges, $nodeMap, $edgeMap)
   → Returns: ['errors' => [], 'warnings' => [], 'rules_validated' => int]

7. Module 6: QC Routing Validator (Structural)
   → validateQCRouting($nodes, $edges, $nodeMap, $edgeMap)
   → Returns: ['errors' => [], 'warnings' => [], 'rules_validated' => int]

8. Module 7: Conditional Routing Validator
   → validateConditionalRouting($nodes, $edges, $nodeMap, $edgeMap)
   → Returns: ['errors' => [], 'warnings' => [], 'rules_validated' => int]

9. Module 8: Behavior-WorkCenter Compatibility Validator
   → validateBehaviorWorkCenter($nodes, $nodeMap)
   → Returns: ['errors' => [], 'warnings' => [], 'rules_validated' => int]

10. Module 9: Machine Binding Validator
    → validateMachineBinding($nodes, $nodeMap)
    → Returns: ['errors' => [], 'warnings' => [], 'rules_validated' => int]

11. Module 10: Node Configuration Validator
    → validateNodeConfiguration($nodes, $nodeMap)
    → Returns: ['errors' => [], 'warnings' => [], 'rules_validated' => int]

12. Module 11: Semantic Validation Layer
    → validateSemanticLayer($nodes, $edges, $nodeMap, $edgeMap, $options)
    → Calls: SemanticIntentEngine::analyzeIntent()
    → Calls: SemanticIntentEngine::detectIntentConflicts()
    → Calls: ReachabilityAnalyzer::analyze()
    → Returns: ['errors' => [], 'warnings' => [], 'rules_validated' => int]

13. Compute validation score
    → score = max(0, 100 - (errorCount * 20 + warningCount * 5))

14. Format output
    → formatErrorsDetail($errors)
    → formatWarningsDetail($warnings)
    → Return: ['valid' => bool, 'errors' => [], 'warnings' => [], 'summary' => [], 'score' => int, 'intents' => [], 'errors_detail' => [], 'warnings_detail' => []]
```

**Critical Rule:** Module execution order MUST NOT change. Structural validators (1-10) MUST run before semantic validators (11).

### 3.2 Semantic Layer Execution Order

**File:** `source/BGERP/Dag/GraphValidationEngine.php`  
**Method:** `private function validateSemanticLayer(...)`

**Execution Order:**

```
1. Analyze semantic intents
   → SemanticIntentEngine::analyzeIntent($nodes, $edges, $options)
   → Store intents in $this->intents

2. QC Routing Semantic Validation
   → validateQCRoutingSemantic($nodes, $edges, $nodeMap, $edgeMap)
   → Uses: $this->intents (from step 1)

3. Parallel Semantic Validation
   → validateParallelSemantic($nodes, $edges, $nodeMap, $edgeMap)
   → Uses: $this->intents (from step 1)

4. Endpoint Semantic Validation
   → validateEndpointSemantic($nodes, $edges, $nodeMap, $edgeMap)
   → Uses: $this->intents (from step 1)

5. Reachability Rules Validation
   → validateReachabilityRules($nodes, $edges, $nodeMap, $edgeMap)
   → Calls: ReachabilityAnalyzer::analyze($nodes, $edges, $this->intents)

6. Detect Intent Conflicts
   → SemanticIntentEngine::detectIntentConflicts($nodes, $edges, $this->intents)
   → Merge conflicts into errors/warnings

7. Time/SLA Basic Validation
   → validateTimeSLABasic($nodes, $nodeMap)
   → Validates: expected_minutes, sla_minutes format
```

**Critical Rule:** Intent analysis MUST run before semantic validators that use intents.

---

## 4. Cross-File Dependency Graph

### 4.1 Backend Dependency Graph

```
dag_routing_api.php
├── graph_validate
│   └── GraphValidationEngine::validate()
│       ├── SemanticIntentEngine::analyzeIntent()
│       ├── SemanticIntentEngine::detectIntentConflicts()
│       ├── ReachabilityAnalyzer::analyze()
│       └── ConditionEvaluator::evaluate() (indirect, via edge validation)
│
├── graph_autofix
│   ├── GraphValidationEngine::validate()
│   └── GraphAutoFixEngine::suggestFixes()
│       ├── SemanticIntentEngine::analyzeIntent() (if mode='semantic')
│       └── GraphValidationEngine::validate() (indirect, uses validation results)
│
├── graph_apply_fixes
│   ├── GraphAutoFixEngine::suggestFixes()
│   ├── ApplyFixEngine::apply()
│   └── GraphValidationEngine::validate() (re-validate after fixes)
│
└── graph_save / graph_save_draft / graph_publish
    └── GraphValidationEngine::validate()
```

### 4.2 Frontend Dependency Graph

```
graph_designer.js
├── validateGraphBeforeSave()
│   └── HTTP POST → dag_routing_api.php?action=graph_validate
│
├── applyFixes()
│   ├── HTTP POST → dag_routing_api.php?action=graph_autofix
│   └── HTTP POST → dag_routing_api.php?action=graph_apply_fixes
│
└── showValidationErrorDialog()
    └── Renders errors from graph_validate API response

conditional_edge_editor.js
├── serializeCondition()
│   └── Output: JSON condition (must match ConditionEvaluator input format)
│
└── validateCondition() (UX checks only)
    └── Basic field validation (non-empty, type checks)
    └── NOT condition evaluation (backend ConditionEvaluator is source of truth)

GraphSaver.js
├── serializeEdgeCondition()
│   └── Output: JSON condition (must match ConditionEvaluator input format)
│
└── serializeGraph()
    └── Output: JSON graph (nodes + edges)
```

### 4.3 Dependency Rules

**Rule 1:** Frontend MUST NOT duplicate backend validation logic.  
**Rule 2:** Frontend condition serialization MUST match `ConditionEvaluator` input format.  
**Rule 3:** `SemanticIntentEngine` and `ReachabilityAnalyzer` have NO database dependencies.  
**Rule 4:** `ConditionEvaluator` is static-only (no instance state).  
**Rule 5:** `ApplyFixEngine` has NO dependencies on other validation engines.

---

## 5. Engine Responsibilities Matrix

| Engine | Responsibility | Input | Output | Dependencies |
|--------|----------------|-------|--------|--------------|
| `GraphValidationEngine` | Orchestrate all validation modules | `$nodes`, `$edges`, `$options` | Validation result with errors/warnings | `SemanticIntentEngine`, `ReachabilityAnalyzer`, `ConditionEvaluator` (indirect) |
| `SemanticIntentEngine` | Analyze graph patterns to infer user intent | `$nodes`, `$edges`, `$options` | Intent array with type, confidence, evidence | None (pure analysis) |
| `ReachabilityAnalyzer` | Analyze reachability, dead-ends, cycles | `$nodes`, `$edges`, `$intents` (optional) | Reachability analysis result | None (pure analysis) |
| `ConditionEvaluator` | Evaluate conditions on edges | `$condition`, `$context` | Boolean (true/false) | None (static methods) |
| `GraphAutoFixEngine` | Generate autofix suggestions | `$nodes`, `$edges`, `$validationResult`, `$options` | Fix suggestions array with risk scores | `SemanticIntentEngine` (if mode='semantic') |
| `ApplyFixEngine` | Apply fixes to graph state | `$nodes`, `$edges`, `$operations`, `$options` | Modified graph state | None (pure graph manipulation) |
| `QCMetadataNormalizer` | Normalize QC result format | `$formData`, `$operatorId` | Standardized QC result | `BGERP\Helper\JsonNormalizer` |

### 5.1 Responsibility Boundaries

**GraphValidationEngine:**
- MUST orchestrate all validation modules
- MUST NOT perform intent analysis (delegate to SemanticIntentEngine)
- MUST NOT perform reachability analysis (delegate to ReachabilityAnalyzer)
- MUST NOT evaluate conditions (delegate to ConditionEvaluator)

**SemanticIntentEngine:**
- MUST analyze graph patterns
- MUST NOT modify graph state
- MUST NOT query database
- MUST NOT perform validation (only intent inference)

**ReachabilityAnalyzer:**
- MUST analyze reachability, dead-ends, cycles
- MUST NOT modify graph state
- MUST NOT query database
- MUST NOT perform validation (only analysis)

**ConditionEvaluator:**
- MUST evaluate conditions
- MUST NOT modify graph state
- MUST NOT query database
- MUST be deterministic (same input → same output)

**GraphAutoFixEngine:**
- MUST generate fix suggestions
- MUST NOT apply fixes (delegate to ApplyFixEngine)
- MUST NOT modify graph state
- MUST calculate risk scores

**ApplyFixEngine:**
- MUST apply fixes atomically
- MUST rollback on failure
- MUST NOT generate fixes (delegate to GraphAutoFixEngine)
- MUST NOT perform validation (delegate to GraphValidationEngine)

---

## 6. Graph State Canonical Format

### 6.1 Node Format

**File:** All validation engines use this format

```php
[
    'id_node' => int|null,           // Database ID (null for temp nodes)
    'temp_id' => string,             // Temporary ID (required for temp nodes)
    'node_code' => string,           // Unique code (required)
    'node_type' => string,           // 'start', 'end', 'operation', 'qc', 'rework_sink', etc.
    'node_name' => string,           // Display name
    'behavior_code' => string|null,   // 'CUT', 'QC', etc.
    'is_parallel_split' => bool,    // Parallel split flag
    'is_merge_node' => bool,          // Merge node flag
    'work_center_code' => string|null,
    'team_category' => string|null,
    'expected_minutes' => int|null,
    'sla_minutes' => int|null,
    // ... other fields
]
```

**Critical Fields:**
- `node_code`: MUST be unique within graph
- `node_type`: MUST be one of: 'start', 'end', 'operation', 'qc', 'rework_sink'
- `temp_id`: MUST be present for temp nodes (format: 'temp_' . uniqid())

### 6.2 Edge Format

**File:** All validation engines use this format

```php
[
    'id_edge' => int|null,           // Database ID (null for temp edges)
    'temp_id' => string,             // Temporary ID (required for temp edges)
    'from_node_id' => int|string,    // Source node ID or temp_id
    'from_node_code' => string|null, // Source node code (for lookup)
    'to_node_id' => int|string,      // Target node ID or temp_id
    'to_node_code' => string|null,   // Target node code (for lookup)
    'edge_type' => string,            // 'normal', 'conditional', 'rework'
    'edge_condition' => array|null,  // Condition object (see ConditionEvaluator format)
    'is_default' => bool,             // Default/else route flag
    'edge_code' => string|null,
    'edge_name' => string|null,
    // ... other fields
]
```

**Critical Fields:**
- `edge_type`: MUST be one of: 'normal', 'conditional', 'rework'
- `edge_condition`: MUST be null for 'normal' edges, MUST be array for 'conditional' edges
- `is_default`: MUST be true for default/else routes

### 6.3 Condition Format (ConditionEvaluator Input)

**File:** `source/BGERP/Dag/ConditionEvaluator.php`

```php
// Default route
[
    'type' => 'default'
]

// Token property condition
[
    'type' => 'token_property',
    'property' => string,        // e.g., 'qc_result.status', 'token.priority'
    'operator' => string,         // '==', '!=', '>', '<', '>=', '<=', 'IN'
    'value' => mixed             // Value to compare
]

// Job property condition
[
    'type' => 'job_property',
    'property' => string,
    'operator' => string,
    'value' => mixed
]

// Node property condition
[
    'type' => 'node_property',
    'property' => string,
    'operator' => string,
    'value' => mixed
]

// Expression condition (legacy)
[
    'type' => 'expression',
    'expression' => string        // PHP expression string
]

// Condition groups (AND/OR)
[
    'type' => 'group',
    'operator' => 'AND'|'OR',
    'groups' => [
        [
            'operator' => 'AND',
            'conditions' => [/* condition objects */]
        ],
        // ... more groups
    ]
]
```

**Critical Rules:**
- Default route: `{"type": "default"}` (Task 19.16)
- QC status conditions: `{"type": "token_property", "property": "qc_result.status", "operator": "==", "value": "pass|fail_minor|fail_major"}`

---

## 7. API Contracts

### 7.1 Validator Interface Contract

**File:** `source/BGERP/Dag/Validators/BaseValidator.php` (to be created in Phase 2)

```php
namespace BGERP\Dag\Validators;

interface ValidatorInterface
{
    /**
     * Validate graph state
     * 
     * @param array $nodes Canonical node array
     * @param array $edges Canonical edge array
     * @param array $nodeMap Node lookup map (from GraphHelper::buildNodeMap())
     * @param array $edgeMap Edge lookup map (from GraphHelper::buildEdgeMap())
     * @param array $options Validation options ['graphId', 'isOldGraph', 'mode']
     * @return array ['errors' => [], 'warnings' => [], 'rules_validated' => int]
     */
    public function validate(array $nodes, array $edges, array $nodeMap, array $edgeMap, array $options = []): array;
}
```

**Implementation Requirements:**
- All validators MUST implement `ValidatorInterface`
- All validators MUST return same format: `['errors' => [], 'warnings' => [], 'rules_validated' => int]`
- All validators MUST use canonical node/edge format (Section 6)
- All validators MUST use `GraphHelper::buildNodeMap()` and `GraphHelper::buildEdgeMap()`

### 7.2 ConditionEvaluator Contract

**File:** `source/BGERP/Dag/ConditionEvaluator.php`

**Method Signature:**
```php
public static function evaluate(array $condition, array $context): bool
```

**Input Contract:**
- `$condition`: Condition object (see Section 6.3)
- `$context`: Context array with keys: `token` (array), `job` (array|null), `node` (array|null)

**Output Contract:**
- Returns: `bool` (true if condition matches, false otherwise)
- MUST be deterministic (same input → same output)
- MUST handle all condition types: 'default', 'token_property', 'job_property', 'node_property', 'expression', 'group'

**Error Handling:**
- Invalid condition type → returns `false`
- Missing required fields → returns `false`
- Expression evaluation errors → returns `false` (log error)

### 7.3 GraphAutoFixEngine Contract

**File:** `source/BGERP/Dag/GraphAutoFixEngine.php`

**Method Signature:**
```php
public function suggestFixes(array $nodes, array $edges, array $validationResult, array $options = []): array
```

**Input Contract:**
- `$nodes`: Canonical node array
- `$edges`: Canonical edge array
- `$validationResult`: Output from `GraphValidationEngine::validate()`
- `$options`: `['mode' => 'metadata'|'structural'|'semantic']`

**Output Contract:**
```php
[
    'fixes' => [
        [
            'id' => string,                    // Unique fix ID
            'type' => string,                  // Fix type constant
            'severity' => string,              // 'error', 'warning', 'info'
            'target_node_id' => int|string,    // Node ID or temp_id
            'target_edge_id' => int|string,   // Edge ID or temp_id (if applicable)
            'title' => string,                 // Human-readable title
            'description' => string,           // Human-readable description
            'operations' => array,            // Array of operation objects
            'risk_score' => int,              // 0-100
            'risk_level' => string,           // 'Low', 'Medium', 'High', 'Critical'
            'apply_mode' => string,           // 'auto', 'suggest', 'suggest_only', 'disabled'
            'evidence' => array               // Evidence for fix suggestion
        ],
        // ... more fixes
    ],
    'patched_nodes' => array,                 // Preview of patched nodes
    'patched_edges' => array                  // Preview of patched edges
]
```

**Fix Modes:**
- `metadata` (v1): Metadata-only fixes (low risk)
- `structural` (v2): Structural fixes (medium risk)
- `semantic` (v3): Semantic fixes (high risk, intent-aware)

### 7.4 ApplyFixEngine Contract

**File:** `source/BGERP/Dag/ApplyFixEngine.php`

**Method Signature:**
```php
public function apply(array $nodes, array $edges, array $operations, array $options = []): array
```

**Input Contract:**
- `$nodes`: Canonical node array
- `$edges`: Canonical edge array
- `$operations`: Array of operation objects (from fix suggestions)
- `$options`: `['validate' => bool, 'strict' => bool]`

**Output Contract:**
```php
[
    'nodes' => array,              // Modified nodes (canonical format)
    'edges' => array,              // Modified edges (canonical format)
    'applied_count' => int,        // Number of operations applied
    'errors' => array             // Array of errors (if any)
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

**Atomicity:**
- MUST rollback all changes if any operation fails (when `strict=true`)
- MUST validate final graph state (when `validate=true`)

---

## 8. Safe-to-Remove Code List

### 8.1 Legacy Functions (Safe to Remove)

**File:** `source/dag_routing_api.php`

**Function:** `validateGraphStructure()`
- **Location:** Line ~645
- **Grep Pattern:** `function validateGraphStructure`
- **Status:** Deprecated, not used by new code
- **Removal Steps:**
  1. Search for usage: `grep -r "validateGraphStructure" source/`
  2. If no usage found, remove function
  3. Run regression tests: `php tests/super_dag/ValidateGraphTest.php`
  4. Verify: All tests pass

**File:** `source/BGERP/Dag/GraphValidationEngine.php`

**Method:** `validateReachabilitySemantic()`
- **Location:** Line ~1370
- **Grep Pattern:** `validateReachabilitySemantic`
- **Status:** Deprecated, replaced by `validateReachabilityRules()`
- **Removal Steps:**
  1. Search for usage: `grep -r "validateReachabilitySemantic" source/`
  2. If no usage found, remove method
  3. Run regression tests: `php tests/super_dag/ValidateGraphTest.php`
  4. Verify: All tests pass

### 8.2 Legacy Node Type Validation (Safe to Remove)

**File:** `source/dag_routing_api.php`

**Legacy Node Types:** `split`, `join`, `wait`, `decision`
- **Location:** Lines ~1262-1320 (approximate)
- **Grep Pattern:** `node_type.*split|node_type.*join|node_type.*wait|node_type.*decision`
- **Status:** Deprecated (Task 19.13), cannot be created/updated
- **Removal Steps:**
  1. Keep backward compatibility checks for old graphs
  2. Remove validation logic for new graph creation
  3. Run regression tests: `php tests/super_dag/ValidateGraphTest.php`
  4. Verify: Old graphs still load, new graphs reject legacy types

### 8.3 Deprecated Comments (Safe to Remove)

**File:** `source/BGERP/Dag/GraphValidationEngine.php`

**Comment:** `// This module is now soft-deprecated as a HARD validator.`
- **Location:** Line ~569
- **Status:** Outdated comment
- **Removal Steps:**
  1. Remove comment
  2. Update method documentation if needed

### 8.4 Verification Commands

**Before Removal:**
```bash
# Search for function usage
grep -r "validateGraphStructure" source/

# Search for method usage
grep -r "validateReachabilitySemantic" source/

# Search for legacy node types
grep -r "node_type.*split\|node_type.*join\|node_type.*wait\|node_type.*decision" source/

# Run regression tests
php tests/super_dag/ValidateGraphTest.php
php tests/super_dag/SemanticSnapshotTest.php
php tests/super_dag/AutoFixPipelineTest.php
```

**After Removal:**
- All tests MUST pass
- No references to removed code in codebase
- Documentation updated (if applicable)

---

## 9. Phase 1: Quick Wins (Low Risk / High Clarity)

**Goal:** Extract duplicate logic, remove legacy code, organize error codes

**Impact Level:** Low  
**Required Regression Coverage:** Existing test suite (Task 19.18)  
**Estimated Time:** 1-2 days

### 9.1 Extract Shared Helper Methods

**Task ID:** P1-T1

**Objective:** Create `GraphHelper` class and extract duplicate `buildNodeMap()` / `buildEdgeMap()` / `extractQCStatusesFromCondition()` methods.

**Files to Create:**
- `source/BGERP/Dag/GraphHelper.php`

**Files to Modify:**
- `source/BGERP/Dag/GraphValidationEngine.php`
- `source/BGERP/Dag/SemanticIntentEngine.php`
- `source/BGERP/Dag/ReachabilityAnalyzer.php`
- `source/BGERP/Dag/GraphAutoFixEngine.php`
- `source/BGERP/Dag/ApplyFixEngine.php`

**Implementation Steps:**

1. **Create GraphHelper.php:**
   ```php
   namespace BGERP\Dag;
   
   class GraphHelper
   {
       /**
        * Build node lookup map
        * 
        * @param array $nodes Canonical node array
        * @return array Map: node_id => node, node_code => node, temp_id => node
        */
       public static function buildNodeMap(array $nodes): array
       {
           $map = [];
           foreach ($nodes as $node) {
               $id = $node['id_node'] ?? null;
               $tempId = $node['temp_id'] ?? null;
               $code = $node['node_code'] ?? null;
               
               if ($id !== null) {
                   $map[$id] = $node;
               }
               if ($tempId !== null) {
                   $map[$tempId] = $node;
               }
               if ($code !== null) {
                   $map[$code] = $node;
               }
           }
           return $map;
       }
       
       /**
        * Build edge lookup map
        * 
        * @param array $edges Canonical edge array
        * @param array $nodeMap Node lookup map
        * @return array Map: edge_id => edge, from_node_id => [edges], to_node_id => [edges]
        */
       public static function buildEdgeMap(array $edges, array $nodeMap): array
       {
           $map = [];
           $fromMap = [];
           $toMap = [];
           
           foreach ($edges as $edge) {
               $id = $edge['id_edge'] ?? null;
               $tempId = $edge['temp_id'] ?? null;
               $fromId = $edge['from_node_id'] ?? null;
               $toId = $edge['to_node_id'] ?? null;
               
               if ($id !== null) {
                   $map[$id] = $edge;
               }
               if ($tempId !== null) {
                   $map[$tempId] = $edge;
               }
               if ($fromId !== null) {
                   $fromMap[$fromId][] = $edge;
               }
               if ($toId !== null) {
                   $toMap[$toId][] = $edge;
               }
           }
           
           return [
               'by_id' => $map,
               'by_from' => $fromMap,
               'by_to' => $toMap
           ];
       }
       
       /**
        * Extract QC statuses from condition
        * 
        * @param array $condition Condition object
        * @param array &$statusSet Reference to status set (modified in place)
        * @return void
        */
       public static function extractQCStatusesFromCondition(array $condition, array &$statusSet): void
       {
           $type = $condition['type'] ?? '';
           
           // Skip default routes (Task 19.16)
           if ($type === 'default') {
               return;
           }
           
           if ($type === 'token_property') {
               $property = $condition['property'] ?? '';
               if ($property === 'qc_result.status') {
                   $value = $condition['value'] ?? null;
                   if (in_array($value, ['pass', 'fail_minor', 'fail_major'], true)) {
                       $statusSet[$value] = true;
                   }
               }
           }
           
           // Handle condition groups
           if ($type === 'group' && isset($condition['groups'])) {
               foreach ($condition['groups'] as $group) {
                   if (isset($group['conditions'])) {
                       foreach ($group['conditions'] as $subCondition) {
                           self::extractQCStatusesFromCondition($subCondition, $statusSet);
                       }
                   }
               }
           }
       }
   }
   ```

2. **Update GraphValidationEngine.php:**
   - Replace `$this->buildNodeMap($nodes)` with `GraphHelper::buildNodeMap($nodes)`
   - Replace `$this->buildEdgeMap($edges, $nodeMap)` with `GraphHelper::buildEdgeMap($edges, $nodeMap)`
   - Replace `$this->extractQCStatusesFromCondition(...)` with `GraphHelper::extractQCStatusesFromCondition(...)`
   - Remove private methods: `buildNodeMap()`, `buildEdgeMap()`, `extractQCStatusesFromCondition()`

3. **Update SemanticIntentEngine.php:**
   - Replace `$this->buildNodeMap($nodes)` with `GraphHelper::buildNodeMap($nodes)`
   - Replace `$this->extractQCStatusesFromCondition(...)` with `GraphHelper::extractQCStatusesFromCondition(...)`
   - Remove private methods: `buildNodeMap()`, `extractQCStatusesFromCondition()`

4. **Update ReachabilityAnalyzer.php:**
   - Replace `$this->buildNodeMap($nodes)` with `GraphHelper::buildNodeMap($nodes)`
   - Replace `$this->buildEdgeMap($edges, $nodeMap)` with `GraphHelper::buildEdgeMap($edges, $nodeMap)`
   - Remove private methods: `buildNodeMap()`, `buildEdgeMap()`

5. **Update GraphAutoFixEngine.php:**
   - Replace `$this->buildNodeMap($nodes)` with `GraphHelper::buildNodeMap($nodes)`
   - Replace `$this->buildEdgeMap($edges, $nodeMap)` with `GraphHelper::buildEdgeMap($edges, $nodeMap)`
   - Remove private methods: `buildNodeMap()`, `buildEdgeMap()`

6. **Update ApplyFixEngine.php:**
   - Replace `$this->buildNodeMap($nodes)` with `GraphHelper::buildNodeMap($nodes)`
   - Replace `$this->buildEdgeMap($edges, $nodeMap)` with `GraphHelper::buildEdgeMap($edges, $nodeMap)`
   - Remove private methods: `buildNodeMap()`, `buildEdgeMap()`

**Acceptance Criteria:**
- [ ] `GraphHelper.php` created with all three methods
- [ ] All 5 classes updated to use `GraphHelper`
- [ ] All duplicate methods removed
- [ ] All tests pass: `php tests/super_dag/ValidateGraphTest.php`
- [ ] No behavior change (validation results identical)

**Test Commands:**
```bash
php tests/super_dag/ValidateGraphTest.php
php tests/super_dag/SemanticSnapshotTest.php
php tests/super_dag/AutoFixPipelineTest.php
```

---

### 9.2 Remove Legacy Code

**Task ID:** P1-T2

**Objective:** Remove deprecated `validateGraphStructure()` function and `validateReachabilitySemantic()` method.

**Files to Modify:**
- `source/dag_routing_api.php`
- `source/BGERP/Dag/GraphValidationEngine.php`

**Implementation Steps:**

1. **Verify No Usage:**
   ```bash
   grep -r "validateGraphStructure" source/
   grep -r "validateReachabilitySemantic" source/
   ```

2. **Remove validateGraphStructure():**
   - File: `source/dag_routing_api.php`
   - Location: Line ~645
   - Action: Delete entire function definition
   - Verify: No references remain

3. **Remove validateReachabilitySemantic():**
   - File: `source/BGERP/Dag/GraphValidationEngine.php`
   - Location: Line ~1370
   - Action: Delete entire method definition
   - Verify: No references remain

4. **Remove Legacy Node Type Validation:**
   - File: `source/dag_routing_api.php`
   - Location: Lines ~1262-1320 (approximate)
   - Action: Remove validation logic for `split`, `join`, `wait`, `decision` node types
   - Keep: Backward compatibility checks for old graphs (if needed)
   - Verify: Old graphs still load, new graphs reject legacy types

**Acceptance Criteria:**
- [ ] `validateGraphStructure()` function removed
- [ ] `validateReachabilitySemantic()` method removed
- [ ] Legacy node type validation removed (for new graphs)
- [ ] All tests pass: `php tests/super_dag/ValidateGraphTest.php`
- [ ] Old graphs still load correctly (backward compatibility)

**Test Commands:**
```bash
php tests/super_dag/ValidateGraphTest.php
# Manually test old graph loading in UI
```

---

### 9.3 Organize Error Codes / Message Mapping

**Task ID:** P1-T3

**Objective:** Create `ValidationErrorCodes` and `ValidationMessageMapper` classes for centralized error code management.

**Files to Create:**
- `source/BGERP/Dag/ValidationErrorCodes.php`
- `source/BGERP/Dag/ValidationMessageMapper.php`

**Files to Modify:**
- `source/dag_routing_api.php`

**Implementation Steps:**

1. **Create ValidationErrorCodes.php:**
   ```php
   namespace BGERP\Dag;
   
   class ValidationErrorCodes
   {
       // Node Existence
       const NODE_DUPLICATE_CODE = 'NODE_DUPLICATE_CODE';
       const NODE_MISSING_CODE = 'NODE_MISSING_CODE';
       
       // Start/End
       const GRAPH_MISSING_START = 'GRAPH_MISSING_START';
       const GRAPH_MULTIPLE_START = 'GRAPH_MULTIPLE_START';
       const GRAPH_MISSING_END = 'GRAPH_MISSING_END';
       
       // Edge Integrity
       const EDGE_INVALID_FROM = 'EDGE_INVALID_FROM';
       const EDGE_INVALID_TO = 'EDGE_INVALID_TO';
       
       // Parallel Structure
       const PARALLEL_SPLIT_INSUFFICIENT_EDGES = 'PARALLEL_SPLIT_INSUFFICIENT_EDGES';
       
       // Merge Structure
       const MERGE_NODE_INSUFFICIENT_EDGES = 'MERGE_NODE_INSUFFICIENT_EDGES';
       
       // QC Routing
       const QC_NO_OUTGOING_EDGES = 'QC_NO_OUTGOING_EDGES';
       const QC_MISSING_FAILURE_PATH = 'QC_MISSING_FAILURE_PATH';
       
       // Reachability
       const UNREACHABLE_NODE = 'UNREACHABLE_NODE';
       const DEAD_END_NODE = 'DEAD_END_NODE';
       
       // Semantic
       const INTENT_CONFLICT_ENDPOINT_WITH_OUTGOING = 'INTENT_CONFLICT_ENDPOINT_WITH_OUTGOING';
       const INTENT_CONFLICT_PARALLEL_CONDITIONAL = 'INTENT_CONFLICT_PARALLEL_CONDITIONAL';
       const INTENT_CONFLICT_MULTIPLE_ROUTING_STYLES = 'INTENT_CONFLICT_MULTIPLE_ROUTING_STYLES';
       const INTENT_CONFLICT_LINEAR_MULTIPLE_EXITS = 'INTENT_CONFLICT_LINEAR_MULTIPLE_EXITS';
       const INTENT_CONFLICT_QC_NON_QC_CONDITION = 'INTENT_CONFLICT_QC_NON_QC_CONDITION';
       
       // ... (add all error codes from GraphValidationEngine)
   }
   ```

2. **Create ValidationMessageMapper.php:**
   ```php
   namespace BGERP\Dag;
   
   class ValidationMessageMapper
   {
       /**
        * Map error code to app code for API response
        * 
        * @param string $errorCode Validation error code
        * @return string App code for API response
        */
       public static function mapToAppCode(string $errorCode): string
       {
           $map = [
               ValidationErrorCodes::GRAPH_MISSING_START => 'DAG_ROUTING_400_MISSING_START',
               ValidationErrorCodes::GRAPH_MULTIPLE_START => 'DAG_ROUTING_400_MULTIPLE_START',
               ValidationErrorCodes::GRAPH_MISSING_END => 'DAG_ROUTING_400_MISSING_END',
               ValidationErrorCodes::UNREACHABLE_NODE => 'DAG_ROUTING_400_UNREACHABLE_NODE',
               ValidationErrorCodes::DEAD_END_NODE => 'DAG_ROUTING_400_DEAD_END_NODE',
               // ... (add all mappings)
           ];
           
           return $map[$errorCode] ?? 'DAG_ROUTING_400_VALIDATION_ERROR';
       }
       
       /**
        * Get human-readable message for error code
        * 
        * @param string $errorCode Validation error code
         * @param array $context Context data for message interpolation
         * @return string Human-readable message
         */
       public static function getMessage(string $errorCode, array $context = []): string
       {
           // Use translate() function for i18n
           $messages = [
               ValidationErrorCodes::GRAPH_MISSING_START => translate('dag.validation.missing_start', 'Graph must have exactly 1 Start node.'),
               // ... (add all messages)
           ];
           
           $message = $messages[$errorCode] ?? 'Validation error';
           
           // Interpolate context variables
           foreach ($context as $key => $value) {
               $message = str_replace('{' . $key . '}', (string)$value, $message);
           }
           
           return $message;
       }
   }
   ```

3. **Update dag_routing_api.php:**
   - Replace hardcoded error code strings with `ValidationErrorCodes::CONSTANT`
   - Replace app code mapping with `ValidationMessageMapper::mapToAppCode()`
   - Use `ValidationMessageMapper::getMessage()` for error messages

**Acceptance Criteria:**
- [ ] `ValidationErrorCodes.php` created with all error code constants
- [ ] `ValidationMessageMapper.php` created with mapping functions
- [ ] `dag_routing_api.php` updated to use new classes
- [ ] All tests pass: `php tests/super_dag/ValidateGraphTest.php`
- [ ] Error codes unchanged (backward compatible)

**Test Commands:**
```bash
php tests/super_dag/ValidateGraphTest.php
# Verify error codes in API responses match expected values
```

---

### 9.4 Document Validation Rules

**Task ID:** P1-T4

**Objective:** Create `validation_rules_reference.md` documenting all validation rules.

**Files to Create:**
- `docs/super_dag/validation_rules_reference.md`

**Implementation Steps:**

1. **Create validation_rules_reference.md:**
   - Document all 11 validation modules
   - Document QC routing rules (2-way, 3-way, pass-only)
   - Document parallel/merge rules
   - Document reachability rules
   - Document semantic validation rules
   - Link to test cases (Task 19.18 fixtures)

**Acceptance Criteria:**
- [ ] Documentation file created
- [ ] All validation modules documented
- [ ] All validation rules documented
- [ ] Test cases linked
- [ ] Examples provided

---

## 10. Phase 2: Structural Refactor (Medium Risk)

**Goal:** Refactor GraphValidationEngine structure, consolidate QC routing logic, make ConditionEvaluator single source of truth

**Impact Level:** Medium  
**Required Regression Coverage:** Existing test suite + additional edge cases  
**Estimated Time:** 3-5 days

### 10.1 Refactor GraphValidationEngine Structure

**Task ID:** P2-T1

**Objective:** Extract validation modules into separate validator classes implementing `ValidatorInterface`.

**Files to Create:**
- `source/BGERP/Dag/Validators/BaseValidator.php` (abstract base class)
- `source/BGERP/Dag/Validators/NodeExistenceValidator.php`
- `source/BGERP/Dag/Validators/StartEndValidator.php`
- `source/BGERP/Dag/Validators/EdgeIntegrityValidator.php`
- `source/BGERP/Dag/Validators/ParallelStructureValidator.php`
- `source/BGERP/Dag/Validators/MergeStructureValidator.php`
- `source/BGERP/Dag/Validators/QCRoutingValidator.php` (structural only)
- `source/BGERP/Dag/Validators/ConditionalRoutingValidator.php`
- `source/BGERP/Dag/Validators/BehaviorWorkCenterValidator.php`
- `source/BGERP/Dag/Validators/MachineBindingValidator.php`
- `source/BGERP/Dag/Validators/NodeConfigurationValidator.php`
- `source/BGERP/Dag/Validators/SemanticValidator.php`
- `source/BGERP/Dag/Validators/ReachabilityValidator.php`

**Files to Modify:**
- `source/BGERP/Dag/GraphValidationEngine.php`

**Implementation Steps:**

1. **Create BaseValidator.php:**
   ```php
   namespace BGERP\Dag\Validators;
   
   use BGERP\Dag\GraphHelper;
   
   abstract class BaseValidator implements ValidatorInterface
   {
       protected function buildNodeMap(array $nodes): array
       {
           return GraphHelper::buildNodeMap($nodes);
       }
       
       protected function buildEdgeMap(array $edges, array $nodeMap): array
       {
           return GraphHelper::buildEdgeMap($edges, $nodeMap);
       }
   }
   ```

2. **Create Individual Validators:**
   - Extract each `validate*()` method from `GraphValidationEngine` into separate validator class
   - Each validator extends `BaseValidator`
   - Each validator implements `ValidatorInterface`
   - Each validator uses `GraphHelper` for map building

3. **Refactor GraphValidationEngine:**
   - Keep `validate()` as orchestrator
   - Instantiate validators in execution order (Section 3.1)
   - Call `$validator->validate()` for each module
   - Merge results from all validators

**Acceptance Criteria:**
- [ ] All 12 validator classes created
- [ ] All validators implement `ValidatorInterface`
- [ ] `GraphValidationEngine` refactored to use validators
- [ ] Execution order unchanged (Section 3.1)
- [ ] All tests pass: `php tests/super_dag/ValidateGraphTest.php`
- [ ] No behavior change (validation results identical)

**Test Commands:**
```bash
php tests/super_dag/ValidateGraphTest.php
php tests/super_dag/SemanticSnapshotTest.php
php tests/super_dag/AutoFixPipelineTest.php
```

---

### 10.2 Consolidate QC Routing Logic

**Task ID:** P2-T2

**Objective:** Consolidate QC routing logic from `GraphValidationEngine` and `SemanticIntentEngine` into `QCRoutingValidator`.

**Files to Modify:**
- `source/BGERP/Dag/Validators/QCRoutingValidator.php` (created in P2-T1)
- `source/BGERP/Dag/GraphValidationEngine.php`
- `source/BGERP/Dag/SemanticIntentEngine.php`

**Implementation Steps:**

1. **Update QCRoutingValidator:**
   - Merge `validateQCRouting()` (structural) and `validateQCRoutingSemantic()` (semantic) logic
   - Use `SemanticIntentEngine` for intent analysis
   - Use `GraphHelper::extractQCStatusesFromCondition()` for status extraction
   - Support QC 2-way routing (warning-only, not error) (Task 19.16)

2. **Update GraphValidationEngine:**
   - Remove `validateQCRouting()` and `validateQCRoutingSemantic()` methods
   - Use `QCRoutingValidator` instead

3. **Update SemanticIntentEngine:**
   - Keep `analyzeQCRoutingIntent()` for intent analysis
   - Remove duplicate `extractQCStatusesFromCondition()` (already in GraphHelper)

**Acceptance Criteria:**
- [ ] QC routing logic consolidated in `QCRoutingValidator`
- [ ] `GraphValidationEngine` uses `QCRoutingValidator`
- [ ] QC 2-way routing supported (warning-only)
- [ ] All QC tests pass: `php tests/super_dag/ValidateGraphTest.php --category QC`
- [ ] No behavior change (validation results identical)

**Test Commands:**
```bash
php tests/super_dag/ValidateGraphTest.php --category QC
php tests/super_dag/SemanticSnapshotTest.php
```

---

### 10.3 Make ConditionEvaluator Single Source of Truth

**Task ID:** P2-T3

**Objective:** Ensure frontend condition serialization matches `ConditionEvaluator` input format exactly.

**Files to Modify:**
- `source/BGERP/Dag/ConditionEvaluator.php` (add validation methods)
- `assets/javascripts/dag/modules/conditional_edge_editor.js`
- `assets/javascripts/dag/modules/GraphSaver.js`

**Implementation Steps:**

1. **Add Validation Methods to ConditionEvaluator:**
   ```php
   /**
    * Validate condition format
    * 
    * @param array $condition Condition object
    * @return array ['valid' => bool, 'errors' => []]
    */
   public static function validateFormat(array $condition): array
   {
       $errors = [];
       
       if (empty($condition) || !is_array($condition)) {
           return ['valid' => false, 'errors' => ['Condition must be an array']];
       }
       
       $type = $condition['type'] ?? '';
       
       if (empty($type)) {
           $errors[] = 'Condition type is required';
       }
       
       // Validate type-specific fields
       switch ($type) {
           case 'default':
               // No additional fields required
               break;
               
           case 'token_property':
           case 'job_property':
           case 'node_property':
               if (empty($condition['property'])) {
                   $errors[] = "Property is required for {$type} condition";
               }
               if (!isset($condition['operator'])) {
                   $errors[] = "Operator is required for {$type} condition";
               }
               if (!isset($condition['value'])) {
                   $errors[] = "Value is required for {$type} condition";
               }
               break;
               
           case 'expression':
               if (empty($condition['expression'])) {
                   $errors[] = 'Expression is required for expression condition';
               }
               break;
               
           case 'group':
               if (empty($condition['groups']) || !is_array($condition['groups'])) {
                   $errors[] = 'Groups array is required for group condition';
               }
               break;
               
           default:
               $errors[] = "Unknown condition type: {$type}";
       }
       
       return [
           'valid' => empty($errors),
           'errors' => $errors
       ];
   }
   
   /**
    * Serialize condition to canonical format
    * 
    * @param array $condition Condition object
    * @return string JSON string
    */
   public static function serializeCondition(array $condition): string
   {
       return json_encode($condition, JSON_UNESCAPED_UNICODE);
   }
   ```
   
2. **Update conditional_edge_editor.js:**
   - Ensure `serializeCondition()` outputs format matching `ConditionEvaluator::validateFormat()` requirements
   - Default route: `{"type": "default"}` (Task 19.16)
   - Token property: `{"type": "token_property", "property": "...", "operator": "...", "value": ...}`
   - Remove any client-side condition evaluation logic (keep only UX checks)
   
3. **Update GraphSaver.js:**
   - Ensure `serializeEdgeCondition()` outputs format matching `ConditionEvaluator::validateFormat()` requirements
   - Use same format as `conditional_edge_editor.js`
   
4. **Add API Endpoint for Condition Validation:**
   - File: `source/dag_routing_api.php`
   - Action: `condition_validate`
   - Calls: `ConditionEvaluator::validateFormat()`
   - Returns: `['valid' => bool, 'errors' => []]`

**Acceptance Criteria:**
- [ ] `ConditionEvaluator::validateFormat()` method added
- [ ] `ConditionEvaluator::serializeCondition()` method added
- [ ] Frontend condition serialization matches backend format exactly
- [ ] All conditional routing tests pass: `php tests/super_dag/ValidateGraphTest.php --test TC-QC-01 --test TC-QC-02 --test TC-PL-04`
- [ ] No behavior change (condition evaluation results identical)

**Test Commands:**
```bash
php tests/super_dag/ValidateGraphTest.php --test TC-QC-01
php tests/super_dag/ValidateGraphTest.php --test TC-QC-02
php tests/super_dag/ValidateGraphTest.php --test TC-PL-04
```

---

### 10.4 Refactor GraphAutoFixEngine Structure

**Task ID:** P2-T4

**Objective:** Extract fix generation logic into separate generator classes.

**Files to Create:**
- `source/BGERP/Dag/FixGenerators/BaseFixGenerator.php` (abstract base class)
- `source/BGERP/Dag/FixGenerators/MetadataFixGenerator.php` (v1)
- `source/BGERP/Dag/FixGenerators/StructuralFixGenerator.php` (v2)
- `source/BGERP/Dag/FixGenerators/SemanticFixGenerator.php` (v3)

**Files to Modify:**
- `source/BGERP/Dag/GraphAutoFixEngine.php`

**Implementation Steps:**

1. **Create BaseFixGenerator.php:**
   ```php
   namespace BGERP\Dag\FixGenerators;
   
   use BGERP\Dag\GraphHelper;
   
   abstract class BaseFixGenerator
   {
       protected function buildNodeMap(array $nodes): array
       {
           return GraphHelper::buildNodeMap($nodes);
       }
       
       protected function buildEdgeMap(array $edges, array $nodeMap): array
       {
           return GraphHelper::buildEdgeMap($edges, $nodeMap);
       }
       
       /**
        * Generate fixes
        * 
        * @param array $nodes Canonical node array
        * @param array $edges Canonical edge array
        * @param array $validationResult Validation result from GraphValidationEngine
        * @param array $options Generator options
        * @return array Fix suggestions array
        */
       abstract public function generate(array $nodes, array $edges, array $validationResult, array $options = []): array;
   }
   ```

2. **Create MetadataFixGenerator.php:**
   - Extract metadata-only fixes (v1) from `GraphAutoFixEngine`
   - Methods: `suggestQCDefaultRework()`, `suggestMarkSinkNodes()`, `suggestDefaultElseRoute()`, `suggestStartEndNormalization()`

3. **Create StructuralFixGenerator.php:**
   - Extract structural fixes (v2) from `GraphAutoFixEngine`
   - Methods: `suggestQCDefaultRework()`, `suggestMarkSinkNodes()`, `suggestDefaultElseRoute()` (from generateStructuralFixes)

4. **Create SemanticFixGenerator.php:**
   - Extract semantic fixes (v3) from `GraphAutoFixEngine`
   - Methods: `suggestQCTwoWayFix()`, `suggestQCThreeWayFix()`, `suggestParallelSplitFix()`, `suggestEndConsolidationFix()`, `suggestUnreachableConnectionFix()`
   - Uses: `SemanticIntentEngine` for intent analysis

5. **Refactor GraphAutoFixEngine:**
   - Keep `suggestFixes()` as orchestrator
   - Instantiate generators based on mode: 'metadata', 'structural', 'semantic'
   - Call `$generator->generate()` for each mode
   - Merge results and calculate risk scores

**Acceptance Criteria:**
- [ ] All 4 generator classes created
- [ ] All generators extend `BaseFixGenerator`
- [ ] `GraphAutoFixEngine` refactored to use generators
- [ ] Fix modes unchanged: 'metadata', 'structural', 'semantic'
- [ ] All autofix tests pass: `php tests/super_dag/AutoFixPipelineTest.php`
- [ ] No behavior change (fix suggestions identical)

**Test Commands:**
```bash
php tests/super_dag/AutoFixPipelineTest.php
php tests/super_dag/ValidateGraphTest.php
```

---

## 11. Phase 3: Deep Clean & ETA Preparation (High Risk)

**Goal:** Normalize time/SLA validation, prepare interface for Phase 20 (ETA / Simulation)

**Impact Level:** High  
**Required Regression Coverage:** Existing test suite + time/SLA test cases  
**Estimated Time:** 5-7 days

### 11.1 Normalize Time/SLA Validation

**Task ID:** P3-T1

**Objective:** Create `TimeValidator` class and integrate with `time_model.md` (Task 19.5).

**Files to Create:**
- `source/BGERP/Dag/Validators/TimeValidator.php`

**Files to Modify:**
- `source/BGERP/Dag/GraphValidationEngine.php`
- `source/BGERP/Dag/Validators/BaseValidator.php` (if needed)

**Implementation Steps:**

1. **Create TimeValidator.php:**
   ```php
   namespace BGERP\Dag\Validators;
   
   use BGERP\Dag\BaseValidator;
   
   class TimeValidator extends BaseValidator implements ValidatorInterface
   {
       /**
        * Validate time/SLA fields
        * 
        * Rules (from time_model.md):
        * - expected_minutes: INT NULL (minutes, >= 0)
        * - sla_minutes: INT NULL (minutes, >= 0, optional)
        * - sla_minutes MUST be >= expected_minutes (if both present)
        * - Timestamp format: ISO8601 or MySQL DATETIME
        * - Duration format: milliseconds (BIGINT)
        * 
        * @param array $nodes Canonical node array
        * @param array $edges Canonical edge array
        * @param array $nodeMap Node lookup map
        * @param array $edgeMap Edge lookup map
        * @param array $options Validation options
        * @return array ['errors' => [], 'warnings' => [], 'rules_validated' => int]
        */
       public function validate(array $nodes, array $edges, array $nodeMap, array $edgeMap, array $options = []): array
       {
           $errors = [];
           $warnings = [];
           $rulesValidated = 0;
           
           foreach ($nodes as $node) {
               $nodeCode = $node['node_code'] ?? 'UNKNOWN';
               
               // Validate expected_minutes
               $expectedMinutes = $node['expected_minutes'] ?? null;
               if ($expectedMinutes !== null) {
                   $rulesValidated++;
                   if (!is_int($expectedMinutes) || $expectedMinutes < 0) {
                       $errors[] = [
                           'code' => 'TIME_INVALID_EXPECTED_MINUTES',
                           'message' => "Node '{$nodeCode}' has invalid expected_minutes: must be non-negative integer",
                           'node_id' => $node['id_node'] ?? null,
                           'node_code' => $nodeCode
                       ];
                   }
               }
               
               // Validate sla_minutes
               $slaMinutes = $node['sla_minutes'] ?? null;
               if ($slaMinutes !== null) {
                   $rulesValidated++;
                   if (!is_int($slaMinutes) || $slaMinutes < 0) {
                       $errors[] = [
                           'code' => 'TIME_INVALID_SLA_MINUTES',
                           'message' => "Node '{$nodeCode}' has invalid sla_minutes: must be non-negative integer",
                           'node_id' => $node['id_node'] ?? null,
                           'node_code' => $nodeCode
                       ];
                   }
                   
                   // Validate SLA >= Expected (if both present)
                   if ($expectedMinutes !== null && $slaMinutes < $expectedMinutes) {
                       $warnings[] = [
                           'code' => 'TIME_SLA_LESS_THAN_EXPECTED',
                           'message' => "Node '{$nodeCode}' has sla_minutes ({$slaMinutes}) less than expected_minutes ({$expectedMinutes})",
                           'node_id' => $node['id_node'] ?? null,
                           'node_code' => $nodeCode
                       ];
                   }
               }
           }
           
           return [
               'errors' => $errors,
               'warnings' => $warnings,
               'rules_validated' => $rulesValidated
           ];
       }
   }
   ```

2. **Update GraphValidationEngine:**
   - Remove `validateTimeSLABasic()` method
   - Add `TimeValidator` to validator list (after Module 11, before score calculation)
   - Use `TimeValidator` instead of `validateTimeSLABasic()`

3. **Update time_model.md Reference:**
   - Ensure `TimeValidator` follows all rules from `time_model.md`
   - Document any deviations or extensions

**Acceptance Criteria:**
- [ ] `TimeValidator.php` created with all validation rules
- [ ] `GraphValidationEngine` uses `TimeValidator`
- [ ] Time/SLA validation rules match `time_model.md`
- [ ] All existing tests pass: `php tests/super_dag/ValidateGraphTest.php`
- [ ] Time/SLA test cases added (3-5 cases)
- [ ] Backward compatible (existing graphs unaffected)

**Test Commands:**
```bash
php tests/super_dag/ValidateGraphTest.php
# Add time/SLA test fixtures
```

---

### 11.2 Prepare Interface for ETA Engine

**Task ID:** P3-T2

**Objective:** Create `ETAEngineInterface` for Phase 20 integration.

**Files to Create:**
- `source/BGERP/Dag/ETAEngineInterface.php`
- `docs/super_dag/eta_engine_integration.md`

**Implementation Steps:**

1. **Create ETAEngineInterface.php:**
   ```php
   namespace BGERP\Dag;
   
   /**
    * ETA Engine Interface
    * 
    * Defines contract for ETA calculation and predictive routing (Phase 20)
    * 
    * @package BGERP\Dag
    * @version 1.0
    * @since 2025-11-24
    */
   interface ETAEngineInterface
   {
       /**
        * Calculate ETA for token at current node
        * 
        * @param array $token Token data (canonical format)
        * @param array $node Node data (canonical format)
        * @param array $graph Graph data (nodes + edges)
        * @param array $options Calculation options
        * @return array ['eta_minutes' => int, 'sla_deadline' => string|null, 'confidence' => float]
        */
       public function calculateETA(array $token, array $node, array $graph, array $options = []): array;
       
       /**
        * Calculate ETA for entire path (from current node to end)
        * 
        * @param array $token Token data
        * @param array $currentNode Current node data
        * @param array $graph Graph data
        * @param array $options Calculation options
        * @return array ['path_eta_minutes' => int, 'path_sla_deadline' => string|null, 'nodes' => []]
        */
       public function calculatePathETA(array $token, array $currentNode, array $graph, array $options = []): array;
       
       /**
        * Predict optimal routing based on ETA
        * 
        * @param array $token Token data
        * @param array $node Node data (with multiple outgoing edges)
        * @param array $graph Graph data
        * @param array $options Prediction options
        * @return array ['recommended_edge_id' => int|string, 'reason' => string, 'eta_comparison' => []]
        */
       public function predictOptimalRouting(array $token, array $node, array $graph, array $options = []): array;
   }
   ```

2. **Create eta_engine_integration.md:**
   - Document interface methods
   - Document input/output formats
   - Document integration points with validation engine
   - Document time model usage

**Acceptance Criteria:**
- [ ] `ETAEngineInterface.php` created with all methods
- [ ] `eta_engine_integration.md` created with complete documentation
- [ ] Interface ready for Phase 20 implementation
- [ ] No breaking changes to existing code

**Test Commands:**
```bash
# Interface tests (mock implementation)
php -l source/BGERP/Dag/ETAEngineInterface.php
```

---

### 11.3 Deep Clean: Remove All Legacy Validation

**Task ID:** P3-T3

**Objective:** Remove all legacy validation code after Phase 1 and Phase 2 completion.

**Files to Modify:**
- `source/dag_routing_api.php`
- `source/BGERP/Dag/GraphValidationEngine.php`
- `source/BGERP/Service/DAGValidationService.php` (check if still used)

**Implementation Steps:**

1. **Verify No Usage:**
   ```bash
   # Search for legacy validation usage
   grep -r "validateGraphStructure" source/
   grep -r "DAGValidationService" source/
   grep -r "validateReachabilitySemantic" source/
   ```

2. **Remove Legacy Code:**
   - Remove any remaining references to `validateGraphStructure()`
   - Remove any remaining references to `validateReachabilitySemantic()`
   - Remove backward compatibility checks for old graphs (if safe)
   - Clean up deprecated comments

3. **Update DAGValidationService:**
   - Check if `DAGValidationService` is still used
   - If not used, mark as deprecated or remove
   - If used, document usage and migration path

**Acceptance Criteria:**
- [ ] All legacy validation code removed
- [ ] No references to deprecated functions/methods
- [ ] All tests pass: `php tests/super_dag/ValidateGraphTest.php`
- [ ] Backward compatibility maintained (if required)
- [ ] Code cleaner and more maintainable

**Test Commands:**
```bash
php tests/super_dag/ValidateGraphTest.php
php tests/super_dag/SemanticSnapshotTest.php
php tests/super_dag/AutoFixPipelineTest.php
```

---

### 11.4 Performance Optimization

**Task ID:** P3-T4

**Objective:** Optimize validation performance if needed.

**Files to Modify:**
- `source/BGERP/Dag/GraphValidationEngine.php`
- `source/BGERP/Dag/ReachabilityAnalyzer.php`
- `source/BGERP/Dag/SemanticIntentEngine.php`

**Files to Create:**
- `tests/super_dag/PerformanceTest.php`

**Implementation Steps:**

1. **Add Performance Tests:**
   ```php
   // tests/super_dag/PerformanceTest.php
   class PerformanceTest
   {
       public function testValidationPerformance(): void
       {
           // Test with large graph (100+ nodes, 200+ edges)
           // Measure validation time
           // Assert: < 1000ms for large graph
       }
   }
   ```

2. **Optimize if Needed:**
   - Cache validation results (if graph unchanged)
   - Optimize node/edge map building (already in GraphHelper)
   - Optimize reachability analysis (BFS/DFS optimization)
   - Optimize intent analysis (cache patterns)

3. **Measure Performance:**
   - Baseline: Current performance
   - Target: < 1000ms for large graphs (100+ nodes)
   - Monitor: Validation time per module

**Acceptance Criteria:**
- [ ] Performance tests created
- [ ] Validation performance measured
- [ ] Optimizations applied (if needed)
- [ ] All tests pass: `php tests/super_dag/ValidateGraphTest.php`
- [ ] No behavior change

**Test Commands:**
```bash
php tests/super_dag/PerformanceTest.php
php tests/super_dag/ValidateGraphTest.php
```

---

## 12. Time/SLA Validation Lookup Table

### 12.1 Validation Rules

| Field | Type | Required | Validation Rule | Severity | Error Code |
|-------|------|----------|----------------|----------|------------|
| `expected_minutes` | INT NULL | No | Must be >= 0 if present | Error | `TIME_INVALID_EXPECTED_MINUTES` |
| `sla_minutes` | INT NULL | No | Must be >= 0 if present | Error | `TIME_INVALID_SLA_MINUTES` |
| `sla_minutes` vs `expected_minutes` | - | - | `sla_minutes >= expected_minutes` (if both present) | Warning | `TIME_SLA_LESS_THAN_EXPECTED` |
| `start_at` | DATETIME NULL | No | Must be valid DATETIME if present | Error | `TIME_INVALID_START_AT` |
| `completed_at` | DATETIME NULL | No | Must be valid DATETIME if present | Error | `TIME_INVALID_COMPLETED_AT` |
| `actual_duration_ms` | BIGINT NULL | No | Must be >= 0 if present | Error | `TIME_INVALID_DURATION_MS` |

### 12.2 Severity Rules

- **Error:** Blocks graph save/publish
- **Warning:** Allows graph save/publish but shows warning

### 12.3 Time Model Reference

**File:** `docs/super_dag/time_model.md`

**Key Rules:**
- Time units: Minutes for `expected_minutes` and `sla_minutes`, Milliseconds for `actual_duration_ms`
- Format: ISO8601 for timestamps, MySQL DATETIME for database storage
- Null handling: NULL values are valid (no time constraint)

---

## 13. ETA Engine Integration Requirements

### 13.1 Interface Contract

**File:** `source/BGERP/Dag/ETAEngineInterface.php`

**Methods:**
1. `calculateETA(array $token, array $node, array $graph, array $options = []): array`
2. `calculatePathETA(array $token, array $currentNode, array $graph, array $options = []): array`
3. `predictOptimalRouting(array $token, array $node, array $graph, array $options = []): array`

### 13.2 Input Format

**Token Format:**
```php
[
    'id_token' => int,
    'qty' => int,
    'start_at' => string|null,        // ISO8601 or DATETIME
    'completed_at' => string|null,    // ISO8601 or DATETIME
    'actual_duration_ms' => int|null,
    'metadata' => array
]
```

**Node Format:**
```php
[
    'id_node' => int,
    'node_code' => string,
    'expected_minutes' => int|null,
    'sla_minutes' => int|null,
    // ... other fields
]
```

**Graph Format:**
```php
[
    'nodes' => array,  // Canonical node array
    'edges' => array   // Canonical edge array
]
```

### 13.3 Output Format

**ETA Calculation:**
```php
[
    'eta_minutes' => int,              // Estimated time to complete (minutes)
    'sla_deadline' => string|null,     // ISO8601 deadline (if SLA present)
    'confidence' => float,              // 0.0 - 1.0
    'calculation_method' => string,   // 'expected', 'historical', 'predictive'
    'factors' => array                 // Factors affecting ETA
]
```

**Path ETA:**
```php
[
    'path_eta_minutes' => int,
    'path_sla_deadline' => string|null,
    'nodes' => [
        [
            'node_id' => int,
            'node_code' => string,
            'eta_minutes' => int,
            'sla_deadline' => string|null
        ],
        // ... more nodes
    ]
]
```

**Optimal Routing:**
```php
[
    'recommended_edge_id' => int|string,
    'reason' => string,
    'eta_comparison' => [
        [
            'edge_id' => int|string,
            'eta_minutes' => int,
            'sla_deadline' => string|null
        ],
        // ... more edges
    ]
]
```

### 13.4 Integration Points

1. **Validation Engine:**
   - `TimeValidator` validates time/SLA fields
   - ETA Engine uses validated time data

2. **Routing Engine:**
   - ETA Engine provides routing recommendations
   - Routing Engine uses ETA for decision making

3. **Token Execution:**
   - ETA Engine calculates ETA during token movement
   - Token execution tracks actual time vs. ETA

---

## 14. Test Coverage Requirements for Refactor

### 14.1 Phase 1 Test Requirements

**Required Test Coverage:**
- All existing test fixtures (14+ fixtures)
- GraphHelper extraction tests
- Legacy code removal tests
- Error code organization tests

**Test Commands:**
```bash
php tests/super_dag/ValidateGraphTest.php
php tests/super_dag/SemanticSnapshotTest.php
php tests/super_dag/AutoFixPipelineTest.php
```

**Success Criteria:**
- All tests pass
- No behavior change
- Code coverage maintained

### 14.2 Phase 2 Test Requirements

**Required Test Coverage:**
- All existing test fixtures
- Validator interface tests
- QC routing consolidation tests
- Condition serialization tests
- Fix generator tests

**Test Commands:**
```bash
php tests/super_dag/ValidateGraphTest.php
php tests/super_dag/SemanticSnapshotTest.php
php tests/super_dag/AutoFixPipelineTest.php
# Add edge case tests for each validator
```

**Success Criteria:**
- All tests pass
- No behavior change
- Code more maintainable

### 14.3 Phase 3 Test Requirements

**Required Test Coverage:**
- All existing test fixtures
- Time/SLA validation tests (3-5 new fixtures)
- ETA interface tests (mock implementation)
- Performance tests
- Legacy removal tests

**Test Commands:**
```bash
php tests/super_dag/ValidateGraphTest.php
php tests/super_dag/SemanticSnapshotTest.php
php tests/super_dag/AutoFixPipelineTest.php
php tests/super_dag/PerformanceTest.php
```

**Success Criteria:**
- All tests pass
- Time/SLA validation works correctly
- ETA interface ready
- Performance acceptable

### 14.4 Test Fixture Mapping

| Test Fixture | Validation Module | Phase |
|--------------|-------------------|-------|
| TC-QC-01 | QC Routing | All |
| TC-QC-02 | QC Routing | All |
| TC-QC-03 | QC Routing Semantic | All |
| TC-QC-04 | QC Routing | All |
| TC-PL-01 | Parallel Structure | All |
| TC-PL-02 | Merge Structure | All |
| TC-PL-03 | Parallel Semantic | All |
| TC-PL-04 | Conditional Routing | All |
| TC-RC-01 | Reachability | All |
| TC-RC-02 | Reachability | All |
| TC-RC-03 | Reachability | All |
| TC-END-01 | Endpoint Semantic | All |
| TC-END-02 | Endpoint Semantic | All |
| TC-SM-01 | Semantic Intent | All |
| TC-SM-02 | Semantic Intent | All |

---

## 15. Final Gate Checklist (Must Be Passed Before Phase 20)

### 15.1 Code Quality Gates

- [ ] All Phase 1 tasks completed
- [ ] All Phase 2 tasks completed
- [ ] All Phase 3 tasks completed
- [ ] All tests pass: `php tests/super_dag/ValidateGraphTest.php`
- [ ] All tests pass: `php tests/super_dag/SemanticSnapshotTest.php`
- [ ] All tests pass: `php tests/super_dag/AutoFixPipelineTest.php`
- [ ] Performance tests pass: `php tests/super_dag/PerformanceTest.php`
- [ ] No linter errors: `php -l source/BGERP/Dag/*.php`
- [ ] No deprecated code remaining (verified by grep)

### 15.2 Documentation Gates

- [ ] `validation_rules_reference.md` created and complete
- [ ] `eta_engine_integration.md` created and complete
- [ ] All validator classes documented
- [ ] All API contracts documented
- [ ] Time/SLA validation rules documented

### 15.3 Architecture Gates

- [ ] `GraphHelper` class created and used by all engines
- [ ] All validators implement `ValidatorInterface`
- [ ] `ConditionEvaluator` is single source of truth
- [ ] `TimeValidator` integrated and working
- [ ] `ETAEngineInterface` defined and documented
- [ ] No circular dependencies
- [ ] No duplicate logic

### 15.4 Test Coverage Gates

- [ ] Test coverage >= 90% for high-risk modules
- [ ] All validation modules have test fixtures
- [ ] Time/SLA test cases added (3-5 cases)
- [ ] Performance tests added
- [ ] Edge case tests added

### 15.5 Backward Compatibility Gates

- [ ] Old graphs still load correctly
- [ ] Legacy node types handled (backward compatibility)
- [ ] API responses unchanged (error codes, format)
- [ ] Frontend compatibility maintained

### 15.6 Verification Commands

```bash
# Code quality
php -l source/BGERP/Dag/*.php
grep -r "validateGraphStructure" source/
grep -r "validateReachabilitySemantic" source/

# Tests
php tests/super_dag/ValidateGraphTest.php
php tests/super_dag/SemanticSnapshotTest.php
php tests/super_dag/AutoFixPipelineTest.php
php tests/super_dag/PerformanceTest.php

# Documentation
ls docs/super_dag/validation_rules_reference.md
ls docs/super_dag/eta_engine_integration.md
```

**Gate Status:** ❌ NOT PASSED (Lean-Up Phase not yet started)

---

## 16. Risk Assessment Table

| Phase | Task | Risk Level | Mitigation | Test Coverage |
|-------|------|------------|------------|---------------|
| Phase 1 | P1-T1: Extract Helpers | Low | Simple extraction, no logic change | All fixtures |
| Phase 1 | P1-T2: Remove Legacy | Low | Deprecated code, not used | All fixtures |
| Phase 1 | P1-T3: Organize Error Codes | Low | Organizational change only | All fixtures |
| Phase 1 | P1-T4: Document Rules | None | Documentation only | N/A |
| Phase 2 | P2-T1: Refactor Validators | Medium | Structural change, logic unchanged | All fixtures + edge cases |
| Phase 2 | P2-T2: Consolidate QC | Medium | Logic consolidation | QC fixtures + edge cases |
| Phase 2 | P2-T3: ConditionEvaluator | Medium | Frontend-backend sync | Conditional fixtures |
| Phase 2 | P2-T4: Refactor AutoFix | Medium | Structural change | Autofix fixtures |
| Phase 3 | P3-T1: Time/SLA Validation | High | New validation rules | All fixtures + time/SLA cases |
| Phase 3 | P3-T2: ETA Interface | High | Interface design | Mock tests |
| Phase 3 | P3-T3: Deep Clean | High | Code removal | All fixtures |
| Phase 3 | P3-T4: Performance | Medium | Optimization | Performance tests |

### 16.1 Risk Mitigation Strategies

**High-Risk Tasks:**
1. **Time/SLA Validation:**
   - Test thoroughly with time/SLA test cases
   - Ensure backward compatibility
   - Document time model clearly

2. **ETA Interface:**
   - Design interface carefully
   - Document all methods
   - Create mock implementation for testing

3. **Deep Clean:**
   - Verify no usage before removal
   - Test backward compatibility
   - Remove incrementally

**Medium-Risk Tasks:**
1. **Structural Refactoring:**
   - Incremental changes
   - Test after each change
   - Ensure no behavior change

2. **Frontend-Backend Sync:**
   - Test condition serialization format
   - Ensure frontend matches backend
   - Add integration tests

---

## 17. Appendix

### 17.1 File Path Reference

**Backend Files:**
- `source/BGERP/Dag/GraphValidationEngine.php`
- `source/BGERP/Dag/SemanticIntentEngine.php`
- `source/BGERP/Dag/ReachabilityAnalyzer.php`
- `source/BGERP/Dag/ConditionEvaluator.php`
- `source/BGERP/Dag/GraphAutoFixEngine.php`
- `source/BGERP/Dag/ApplyFixEngine.php`
- `source/BGERP/Dag/QCMetadataNormalizer.php`
- `source/dag_routing_api.php`

**Frontend Files:**
- `assets/javascripts/dag/graph_designer.js`
- `assets/javascripts/dag/modules/conditional_edge_editor.js`
- `assets/javascripts/dag/modules/GraphSaver.js`

**Test Files:**
- `tests/super_dag/ValidateGraphTest.php`
- `tests/super_dag/SemanticSnapshotTest.php`
- `tests/super_dag/AutoFixPipelineTest.php`
- `tests/super_dag/fixtures/*.json`

**Documentation Files:**
- `docs/super_dag/validation_engine_map.md`
- `docs/super_dag/validation_dependency_graph.md`
- `docs/super_dag/validation_risk_register.md`
- `docs/super_dag/time_model.md`

### 17.2 Method Signature Reference

**GraphValidationEngine:**
```php
public function validate(array $nodes, array $edges, array $options = []): array
```

**SemanticIntentEngine:**
```php
public function analyzeIntent(array $nodes, array $edges, array $options = []): array
public function detectIntentConflicts(array $nodes, array $edges, array $intents): array
```

**ReachabilityAnalyzer:**
```php
public function analyze(array $nodes, array $edges, array $intents = []): array
```

**ConditionEvaluator:**
```php
public static function evaluate(array $condition, array $context): bool
public static function validateFormat(array $condition): array
public static function serializeCondition(array $condition): string
```

**GraphAutoFixEngine:**
```php
public function suggestFixes(array $nodes, array $edges, array $validationResult, array $options = []): array
```

**ApplyFixEngine:**
```php
public function apply(array $nodes, array $edges, array $operations, array $options = []): array
```

### 17.3 Error Code Reference

**Node Existence:**
- `NODE_DUPLICATE_CODE`
- `NODE_MISSING_CODE`

**Start/End:**
- `GRAPH_MISSING_START`
- `GRAPH_MULTIPLE_START`
- `GRAPH_MISSING_END`

**Edge Integrity:**
- `EDGE_INVALID_FROM`
- `EDGE_INVALID_TO`

**Parallel/Merge:**
- `PARALLEL_SPLIT_INSUFFICIENT_EDGES`
- `MERGE_NODE_INSUFFICIENT_EDGES`

**QC Routing:**
- `QC_NO_OUTGOING_EDGES`
- `QC_MISSING_FAILURE_PATH`

**Reachability:**
- `UNREACHABLE_NODE`
- `DEAD_END_NODE`

**Semantic:**
- `INTENT_CONFLICT_ENDPOINT_WITH_OUTGOING`
- `INTENT_CONFLICT_PARALLEL_CONDITIONAL`
- `INTENT_CONFLICT_MULTIPLE_ROUTING_STYLES`
- `INTENT_CONFLICT_LINEAR_MULTIPLE_EXITS`
- `INTENT_CONFLICT_QC_NON_QC_CONDITION`

**Time/SLA:**
- `TIME_INVALID_EXPECTED_MINUTES`
- `TIME_INVALID_SLA_MINUTES`
- `TIME_SLA_LESS_THAN_EXPECTED`

---

**Document Version:** 2.0  
**Last Updated:** November 24, 2025  
**Status:** Production-Ready Specification  
**Next Step:** Begin Phase 1 implementation

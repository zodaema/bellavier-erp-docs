# Task 27.10.3: Validation Consolidation and Cleanup

## Overview

**Status:** Pending  
**Priority:** HIGH  
**Estimated Time:** 2-3 hours  
**Dependencies:** Task 27.10.1, Task 27.10.2  
**Blocks:** None (can proceed to Task 27.11 after 27.10.1 and 27.10.2)

---

## Objective

Clean up redundant validation code and consolidate to single source of truth.

---

## Background

After completing 27.10.1 and 27.10.2, the system will have:
- GraphValidationEngine as primary validator
- DAGValidationService with deprecated methods
- Some redundant inline validation in dag_routing_api.php

This task removes redundancy and documents the new architecture.

---

## Requirements

### R1: Remove Redundant Inline Validation from dag_routing_api.php

Already partially done in previous work, but verify these are removed:

| Location | Check | Status |
|----------|-------|--------|
| Lines 4145-4191 (removed) | QC/Decision default edge check | Verify removed |
| Lines 4193-4239 (removed) | QC rework edge check | Verify removed |

Search for any remaining inline validation:
```bash
grep -n "QC.*default\|rework.*edge\|validateGraphStructure" source/dag_routing_api.php
```

### R2: Document GraphValidationEngine as Single Source of Truth

**File:** `docs/super_dag/00-audit/GRAPH_DESIGNER_RULES.md`

Add section:

```markdown
## Validation Architecture (Updated Dec 2025)

### Single Source of Truth: GraphValidationEngine

As of December 2025, ALL graph validation MUST go through:
- File: `source/BGERP/Dag/GraphValidationEngine.php`
- Method: `validate($nodes, $edges, $options)`

### Deprecated Services

The following are DEPRECATED and will be removed:
- `DAGValidationService::validateGraph()` - Use GraphValidationEngine
- `DAGValidationService::canPublishGraph()` - Use GraphValidationEngine with mode='publish'
- Inline validation in dag_routing_api.php - REMOVED

### Validation Modes

| Mode | Usage |
|------|-------|
| `draft` (default) | UI validation, warnings allowed |
| `publish` | Strict validation, no warnings about mandatory fields |

### Edge Pattern Recognition

GraphValidationEngine recognizes BOTH patterns for rework edges:
1. Legacy: `edge_type='rework'`
2. Modern: `edge_type='conditional'` + `edge_condition` with fail status
```

### R3: Update DAGValidationService to Forward to GraphValidationEngine

Instead of maintaining two validation implementations, update DAGValidationService to delegate to GraphValidationEngine:

**File:** `source/BGERP/Service/DAGValidationService.php`

```php
/**
 * @deprecated Use GraphValidationEngine directly
 */
public function validateGraph(int $graphId): array
{
    trigger_error('validateGraph() is deprecated. Use GraphValidationEngine instead.', E_USER_DEPRECATED);
    
    // Forward to GraphValidationEngine
    $engine = new \BGERP\Dag\GraphValidationEngine($this->db);
    
    $nodes = $this->fetchAllNodes($graphId);
    $edges = $this->fetchAllEdges($graphId);
    
    $result = $engine->validate($nodes, $edges);
    
    // Convert to legacy format for backward compatibility
    return [
        'valid' => $result['valid'],
        'errors' => $result['errors'] ?? [],
        'warnings' => $result['warnings'] ?? []
    ];
}
```

### R4: Standardize Error Codes

Create mapping for error codes across the system:

**File:** `source/BGERP/Dag/ValidationErrorCodes.php` (NEW)

```php
<?php
namespace BGERP\Dag;

/**
 * Standardized validation error codes for graph validation
 */
class ValidationErrorCodes
{
    // Structural errors
    public const START_NODE_MISSING = 'GRAPH_001_START_MISSING';
    public const START_NODE_MULTIPLE = 'GRAPH_002_START_MULTIPLE';
    public const END_NODE_MISSING = 'GRAPH_003_END_MISSING';
    public const CYCLE_DETECTED = 'GRAPH_004_CYCLE_DETECTED';
    public const ORPHAN_NODE = 'GRAPH_005_ORPHAN_NODE';
    
    // Semantic errors
    public const PARALLEL_SPLIT_NO_MERGE = 'SEM_001_PARALLEL_NO_MERGE';
    public const QC_MISSING_FAILURE_PATH = 'SEM_002_QC_NO_FAIL_PATH';
    public const QC_MISSING_DEFAULT_EDGE = 'SEM_003_QC_NO_DEFAULT';
    
    // Publish errors
    public const TEMP_NODE_ID = 'PUB_001_TEMP_ID';
    public const MISSING_WORK_CENTER = 'PUB_002_NO_WORK_CENTER';
    
    // Warnings
    public const REWORK_CYCLE_WARNING = 'WARN_001_REWORK_CYCLE';
    public const QC_PASS_ONLY = 'WARN_002_QC_PASS_ONLY';
    
    /**
     * Get human-readable message for error code
     */
    public static function getMessage(string $code): string
    {
        $messages = [
            self::START_NODE_MISSING => 'Graph must have exactly 1 START node',
            self::START_NODE_MULTIPLE => 'Graph has multiple START nodes',
            self::END_NODE_MISSING => 'Graph must have at least 1 END node',
            self::CYCLE_DETECTED => 'Graph contains a cycle',
            self::ORPHAN_NODE => 'Node is not connected to the graph',
            self::PARALLEL_SPLIT_NO_MERGE => 'Parallel split has no merge node downstream',
            self::QC_MISSING_FAILURE_PATH => 'QC node missing failure/rework path',
            self::QC_MISSING_DEFAULT_EDGE => 'QC node should have a default edge',
            self::TEMP_NODE_ID => 'Node has temporary ID - save before publishing',
            self::MISSING_WORK_CENTER => 'Operation node missing work center',
            self::REWORK_CYCLE_WARNING => 'Graph contains intentional rework cycle',
            self::QC_PASS_ONLY => 'QC node only has pass path (no fail handling)',
        ];
        
        return $messages[$code] ?? 'Unknown validation error';
    }
}
```

### R5: Write Integration Tests

**File:** `tests/Integration/GraphValidationEngineTest.php`

```php
<?php
namespace BellavierGroup\Tests\Integration;

use PHPUnit\Framework\TestCase;
use BGERP\Dag\GraphValidationEngine;

class GraphValidationEngineTest extends TestCase
{
    private $engine;
    
    protected function setUp(): void
    {
        $this->engine = new GraphValidationEngine(/* mock db */);
    }
    
    public function testValidateRecognizesModernReworkPattern()
    {
        $nodes = [
            ['id_node' => 1, 'node_code' => 'START', 'node_type' => 'start'],
            ['id_node' => 2, 'node_code' => 'QC', 'node_type' => 'qc'],
            ['id_node' => 3, 'node_code' => 'END', 'node_type' => 'end'],
        ];
        
        $edges = [
            ['from_node_id' => 1, 'to_node_id' => 2, 'edge_type' => 'normal'],
            ['from_node_id' => 2, 'to_node_id' => 3, 'edge_type' => 'normal', 'is_default' => 1],
            ['from_node_id' => 2, 'to_node_id' => 2, 'edge_type' => 'conditional', 
             'edge_condition' => '{"status":"fail"}'], // Modern rework
        ];
        
        $result = $this->engine->validate($nodes, $edges);
        
        // Should NOT have CYCLE_DETECTED error (rework is intentional)
        $hasCycleError = false;
        foreach ($result['errors'] as $error) {
            if (($error['code'] ?? '') === 'CYCLE_DETECTED') {
                $hasCycleError = true;
            }
        }
        
        $this->assertFalse($hasCycleError, 'Should not detect cycle for modern rework pattern');
    }
    
    public function testValidateRecognizesLegacyReworkPattern()
    {
        $nodes = [
            ['id_node' => 1, 'node_code' => 'START', 'node_type' => 'start'],
            ['id_node' => 2, 'node_code' => 'QC', 'node_type' => 'qc'],
            ['id_node' => 3, 'node_code' => 'END', 'node_type' => 'end'],
        ];
        
        $edges = [
            ['from_node_id' => 1, 'to_node_id' => 2, 'edge_type' => 'normal'],
            ['from_node_id' => 2, 'to_node_id' => 3, 'edge_type' => 'normal', 'is_default' => 1],
            ['from_node_id' => 2, 'to_node_id' => 2, 'edge_type' => 'rework'], // Legacy rework
        ];
        
        $result = $this->engine->validate($nodes, $edges);
        
        $hasCycleError = false;
        foreach ($result['errors'] as $error) {
            if (($error['code'] ?? '') === 'CYCLE_DETECTED') {
                $hasCycleError = true;
            }
        }
        
        $this->assertFalse($hasCycleError, 'Should not detect cycle for legacy rework pattern');
    }
}
```

---

## Files to Modify/Create

| File | Action |
|------|--------|
| `source/dag_routing_api.php` | Verify redundant validation removed |
| `source/BGERP/Service/DAGValidationService.php` | Forward to GraphValidationEngine |
| `source/BGERP/Dag/ValidationErrorCodes.php` | NEW - Standardized error codes |
| `docs/super_dag/00-audit/GRAPH_DESIGNER_RULES.md` | Document new architecture |
| `tests/Integration/GraphValidationEngineTest.php` | NEW - Integration tests |

---

## Acceptance Criteria

1. No redundant inline validation in dag_routing_api.php
2. DAGValidationService forwards to GraphValidationEngine
3. ValidationErrorCodes class created with standard codes
4. Documentation updated
5. Integration tests pass
6. All existing functionality preserved

---

## Testing

### Regression Test
```bash
# Run all existing tests
vendor/bin/phpunit

# All tests should pass
```

### Integration Test
```bash
# Run new integration tests
vendor/bin/phpunit tests/Integration/GraphValidationEngineTest.php
```

### Manual Verification
1. Open Graph Designer
2. Create various graph configurations
3. Validate -> Consistent results
4. Publish -> Same validation as UI

---

## Results Template

```markdown
## Task 27.10.3 Results

**Completed:** [DATE]
**Time Spent:** [X hours]

### Changes Made
1. ...

### Tests Passed
- [ ] Regression tests
- [ ] Integration tests
- [ ] Manual verification

### Documentation Updated
- [ ] GRAPH_DESIGNER_RULES.md
- [ ] Audit report

### Notes
...
```


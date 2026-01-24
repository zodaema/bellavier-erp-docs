# Task 27.10.2: Unify Validation Engine for Publish Action

## Overview

**Status:** Pending  
**Priority:** CRITICAL  
**Estimated Time:** 1-2 hours  
**Dependencies:** Task 27.10.1  
**Blocks:** Task 27.11

---

## Problem Statement

### Current Situation

| Action | Engine Used | Method |
|--------|-------------|--------|
| `graph_validate` (UI) | `GraphValidationEngine` | `validate()` |
| `graph_publish` (API) | `DAGValidationService` | `canPublishGraph()` |

### Impact

- User validates graph in UI with GraphValidationEngine -> PASSES
- User clicks Publish -> Uses DAGValidationService -> MAY FAIL
- **User confusion:** "Why does validation pass but publish fail?"

### Current Code (dag_routing_api.php line ~4669)

```php
// Validate before publish
$canPublish = $validationService->canPublishGraph($graphId);

if (!$canPublish['can_publish']) {
    json_error(translate('common.error.validation_failed', 'Validation failed'), 400, [
        'app_code' => 'DAG_ROUTING_400_CANNOT_PUBLISH',
        'errors' => $canPublish['reasons']
    ]);
}
```

---

## Objective

Use `GraphValidationEngine` as the SINGLE SOURCE OF TRUTH for ALL validation:
1. UI Validate action
2. Publish action
3. Any future validation needs

---

## Requirements

### R1: Replace DAGValidationService.canPublishGraph() with GraphValidationEngine

**File:** `source/dag_routing_api.php`  
**Action:** `graph_publish` (line ~4660-4676)

**Before:**
```php
// Validate before publish
$canPublish = $validationService->canPublishGraph($graphId);

if (!$canPublish['can_publish']) {
    json_error(translate('common.error.validation_failed', 'Validation failed'), 400, [
        'app_code' => 'DAG_ROUTING_400_CANNOT_PUBLISH',
        'errors' => $canPublish['reasons']
    ]);
}
```

**After:**
```php
// Task 27.10.2: Use GraphValidationEngine as SINGLE SOURCE OF TRUTH
// This ensures publish validation matches UI validation exactly
$validationEngine = new GraphValidationEngine($tenantDb);

// Load graph data for validation
$graphData = loadGraphWithVersion($db, $graphId);
if (!$graphData) {
    json_error(translate('dag_routing.error.not_found', 'Graph not found'), 404, ['app_code' => 'DAG_ROUTING_404_GRAPH']);
}

$nodes = $graphData['nodes'] ?? [];
$edges = $graphData['edges'] ?? [];

// Validate with publish mode (strict)
$validationResult = $validationEngine->validate($nodes, $edges, [
    'mode' => 'publish',
    'strict' => true
]);

if (!$validationResult['valid']) {
    $errorMessages = array_map(function($err) {
        return is_array($err) ? ($err['message'] ?? json_encode($err)) : $err;
    }, $validationResult['errors'] ?? []);
    
    json_error(translate('common.error.validation_failed', 'Validation failed'), 400, [
        'app_code' => 'DAG_ROUTING_400_CANNOT_PUBLISH',
        'errors' => $errorMessages,
        'validation_details' => $validationResult
    ]);
}
```

### R2: Add Publish-Specific Checks to GraphValidationEngine

**File:** `source/BGERP/Dag/GraphValidationEngine.php`

Add additional checks that are only required for publishing:

```php
// In validate() method, check for mode
$mode = $options['mode'] ?? 'draft';
$isPublishMode = ($mode === 'publish');

if ($isPublishMode) {
    // Additional publish-only checks
    $publishErrors = $this->validateForPublish($nodes, $edges);
    $errors = array_merge($errors, $publishErrors);
}
```

```php
/**
 * Additional validation for publish mode
 */
private function validateForPublish(array $nodes, array $edges): array
{
    $errors = [];
    
    // Check 1: No temp IDs (node_code starting with 'temp_' or negative IDs)
    foreach ($nodes as $node) {
        $nodeCode = $node['node_code'] ?? '';
        $nodeId = $node['id_node'] ?? 0;
        
        if (str_starts_with($nodeCode, 'temp_') || $nodeId < 0) {
            $errors[] = [
                'code' => 'PUBLISH_TEMP_NODE',
                'message' => sprintf('Node "%s" has temporary ID. Save before publishing.', $nodeCode),
                'severity' => 'error'
            ];
        }
    }
    
    // Check 2: All operation nodes have work_center_code
    foreach ($nodes as $node) {
        if (($node['node_type'] ?? '') === 'operation') {
            if (empty($node['work_center_code'])) {
                $errors[] = [
                    'code' => 'PUBLISH_MISSING_WORK_CENTER',
                    'message' => sprintf('Operation node "%s" missing work center.', $node['node_code'] ?? 'Unknown'),
                    'severity' => 'error'
                ];
            }
        }
    }
    
    return $errors;
}
```

### R3: Deprecate DAGValidationService.canPublishGraph()

**File:** `source/BGERP/Service/DAGValidationService.php`

Add deprecation notice:

```php
/**
 * @deprecated Use GraphValidationEngine::validate() with mode='publish' instead
 * This method will be removed in a future version.
 */
public function canPublishGraph(int $graphId): array
{
    trigger_error(
        'canPublishGraph() is deprecated. Use GraphValidationEngine::validate() with mode=publish instead.',
        E_USER_DEPRECATED
    );
    
    // ... existing code for backward compatibility ...
}
```

---

## Files to Modify

| File | Changes |
|------|---------|
| `source/dag_routing_api.php` | Update `graph_publish` to use GraphValidationEngine |
| `source/BGERP/Dag/GraphValidationEngine.php` | Add `validateForPublish()` method |
| `source/BGERP/Service/DAGValidationService.php` | Add deprecation notice to `canPublishGraph()` |

---

## Acceptance Criteria

1. `graph_publish` action uses `GraphValidationEngine`
2. Validation results are consistent between UI validate and publish
3. Publish-specific checks (temp IDs, work center) are enforced
4. `canPublishGraph()` is marked deprecated
5. No breaking changes for existing workflows

---

## Testing

### Manual Test 1: Publish After Validate
1. Open Graph Designer
2. Create or load a valid graph
3. Click Validate -> Should pass
4. Click Publish -> Should also pass (same engine)

### Manual Test 2: Publish Validation Failure
1. Open Graph Designer
2. Create graph with validation error (e.g., missing end node)
3. Click Publish
4. Expected: Same error message as UI validate

### Manual Test 3: Publish-Only Checks
1. Create graph with temp node IDs
2. Try to publish without saving
3. Expected: Error about temp IDs

---

## Results Template

```markdown
## Task 27.10.2 Results

**Completed:** [DATE]
**Time Spent:** [X hours]

### Changes Made
1. ...

### Tests Passed
- [ ] Publish after validate
- [ ] Publish validation failure
- [ ] Publish-only checks

### Notes
...
```


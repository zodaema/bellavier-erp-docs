# Task 28.x - P0 Resolver Logic Fixes
**Date:** 2025-12-13  
**Status:** ✅ **COMPLETED**  
**Priority:** P0 (Critical Logic Conflicts)

---

## Executive Summary

Fixed critical logic conflicts in `GraphSaveModeResolver` that would have caused:
1. Publish to never work (blocked before routing)
2. Partial payload incorrectly routed to draft
3. Incorrect publish semantics (required no draft instead of requiring draft)

---

## 🚨 Critical Fixes Applied

### ✅ P0 Fix 1: Publish Blocked Before Routing

**Problem:**
- Global block condition (line 74-80) blocked ALL saves to published graphs
- This blocked `publish` before it could reach the switch case
- Result: Publish would never work

**Original Code:**
```php
// BEFORE switch case - blocks everything including publish
if (!$hasActiveDraft && in_array($graphStatus, ['published', 'retired'])) {
    throw new \RuntimeException("Cannot save...");
}

switch ($requestedType) {
    case 'publish': // Never reached!
        ...
}
```

**Solution:**
- Moved block conditions **INSIDE switch case per save_type**
- `publish` is allowed even when `graphStatus=published` (creates new version)
- Only `draft`, `autosave`, `node_update` are blocked on published/retired graphs

**Fixed Code:**
```php
switch ($requestedType) {
    case 'autosave':
        // Block autosave to published/retired (inside case)
        if (!$hasActiveDraft && in_array($graphStatus, ['published', 'retired'])) {
            throw new \RuntimeException("Cannot autosave...");
        }
        ...
    
    case 'draft':
        // Block draft save to published/retired (inside case)
        if (!$hasActiveDraft && in_array($graphStatus, ['published', 'retired'])) {
            throw new \RuntimeException("Cannot create draft...");
        }
        ...
    
    case 'publish':
        // Publish is ALLOWED even when graphStatus=published (creates new version)
        // BUT: Must have active draft to publish
        if (!$hasActiveDraft) {
            throw new \RuntimeException("Cannot publish without active draft...");
        }
        ...
}
```

---

### ✅ P0 Fix 2: Publish Semantics Corrected

**Problem:**
- Resolver required "no active draft" for publish
- Actual workflow: Publish should **require active draft** (publish draft → published version)
- Logic was backwards

**Original Code:**
```php
case 'publish':
    if ($hasActiveDraft) {
        throw new \RuntimeException("Cannot publish while active draft exists...");
    }
```

**Solution:**
- **Require active draft** for publish
- Publish loads from active draft automatically
- Creates new published version from draft

**Fixed Code:**
```php
case 'publish':
    // P0 FIX: Publish semantics - publish active draft to create published version
    // Publish is allowed even when graphStatus=published (creates new published version)
    // BUT: Must have active draft to publish (cannot publish empty/live graph)
    if (!$hasActiveDraft) {
        throw new \RuntimeException(
            "Cannot publish without active draft. " .
            "Create and save a draft version first, then publish it."
        );
    }
    return [
        'mode' => 'publish',
        'service_class' => \BGERP\Dag\Graph\Service\GraphVersionService::class,
        'service_method' => 'publish' // Publishes active draft
    ];
```

---

### ✅ P0 Fix 3: Partial Payload Detection

**Problem:**
- Legacy detection: `if (hasNodes OR hasEdges) → draft`
- Partial payload (only nodes OR only edges) would be routed to draft
- Result: Incomplete draft overwrites existing draft

**Original Code:**
```php
if (!$payloadHasNodes && !$payloadHasEdges) {
    $requestedType = 'autosave';
} else {
    $requestedType = 'draft'; // ❌ Wrong if only nodes OR only edges
}
```

**Solution:**
- Require **both nodes AND edges** for draft/publish
- Reject partial payload with clear error message
- Suggest correct save_type

**Fixed Code:**
```php
if (!$payloadHasNodes && !$payloadHasEdges) {
    $requestedType = 'autosave'; // No payload → autosave
} elseif ($payloadHasNodes && $payloadHasEdges) {
    $requestedType = 'draft'; // Full payload → draft
} else {
    // Partial payload → reject
    throw new \InvalidArgumentException(
        "Partial payload detected. Draft/publish requires full payload (both nodes and edges). " .
        "Use save_type=autosave for position updates or save_type=node_update for node config changes."
    );
}
```

---

### ✅ P1 Fix 4: Service Class as FQCN

**Problem:**
- Service class names were strings: `'GraphDraftService'`
- Dynamic instantiation (`new $class`) would fail with namespaces
- Silent failures in edge cases

**Solution:**
- Use `::class` for fully-qualified class names
- Ensures correct namespace resolution

**Fixed Code:**
```php
'service_class' => \BGERP\Dag\Graph\Service\GraphDraftService::class,
'service_class' => \BGERP\Dag\Graph\Service\GraphSaveEngine::class,
'service_class' => \BGERP\Dag\Graph\Service\GraphVersionService::class,
```

---

### ✅ P1 Fix 5: Node Update Not Routed to Draft

**Problem:**
- `node_update` was routed to `saveDraft()` with potentially partial payload
- Would overwrite draft with incomplete data
- Not yet implemented anyway

**Solution:**
- Return clear error instead of routing
- Prevents partial payload from corrupting draft

**Fixed Code:**
```php
case 'node_update':
    // P1 FIX: Node update not yet implemented - return clear error
    // Routing partial payload to saveDraft would overwrite draft with incomplete data
    throw new \RuntimeException(
        "save_type=node_update is not yet implemented. " .
        "Use save_type=draft with full payload (nodes + edges) for now, " .
        "or save_type=autosave for position-only updates."
    );
```

---

## 📋 Save Semantics (Final)

### Draft Save
- **Requires:** Full payload (both nodes AND edges)
- **Allowed on:** Any graph (except published/retired without active draft)
- **If-Match:** Not required
- **Validation:** Non-blocking (warnings only)

### Autosave
- **Requires:** Position updates (nodes optional, edges optional)
- **Allowed on:** Any graph EXCEPT published/retired without active draft
- **If-Match:** Not required
- **With active draft:** Merges positions with existing draft
- **Without active draft:** Updates positions in main tables

### Publish
- **Requires:** Active draft (loads from draft automatically)
- **Allowed on:** Any graph (including published - creates new version)
- **If-Match:** Required
- **Validation:** Strict (blocks on errors)
- **Result:** Creates new published version, discards draft, creates new draft

### Node Update
- **Status:** Not yet implemented
- **Error:** Returns clear message suggesting alternatives

---

## 🧪 Test Cases

### Must Pass ✅

1. ✅ Publish with active draft → Creates published version
2. ✅ Publish on published graph → Creates new version (allowed)
3. ✅ Partial payload → Rejected with clear error
4. ✅ Draft save on published → Blocked (must create draft first)
5. ✅ Autosave on published → Blocked (must create draft first)

### Must Fail ✅

1. ✅ Publish without active draft → Blocked (403)
2. ✅ Partial payload (only nodes) → Rejected (400)
3. ✅ Draft save on published without draft → Blocked (403)

---

## Related Documents

- `P0_SAVE_SEMANTICS_REFACTOR_COMPLETE.md` - Original refactor
- `AUDIT_FOLLOW_UP_RISKS.md` - Original audit findings


# DAG Validation & Routing — Pseudocode Specification

_Last updated: {{DATE}}_

This file provides **pseudocode-only** definitions of the main validation and routing flows.
It is meant to guide implementation and refactors without being tied to a specific language.

---

## 1. High-Level Flow

```text
Graph Designer UI
    ↓
dag_routing_api.php
    - validateGraphStructure()         # STRUCTURE ONLY
    - call DAGValidationService        # BUSINESS RULES ONLY
    ↓
DAGValidationService
    - validate() → errors + warnings
```

---

## 2. API Layer — validateGraphStructure(nodes, edges, graphMeta)

**File:** `dag_routing_api.php`

```pseudo
function validateGraphStructure(nodes, edges, graphMeta): Result {
    errors = []
    warnings = []

    # 1. Basic node checks
    ensureNonEmpty(nodes)
    ensureNodeIdsUnique(nodes)
    ensureNodeTypesValid(nodes)

    # 2. Start/End
    ensureExactlyOneStart(nodes)
    ensureAtLeastOneEnd(nodes)

    # 3. Edge validity
    ensureEdgeReferencesExist(edges, nodes)

    # 4. Structural constraints
    ensureNoCycles(nodes, edges)
    ensureNoSelfLoops(edges)
    ensureSplitRules(nodes, edges)
    ensureJoinRules(nodes, edges)

    # 5. RETURN — API MUST NOT apply business rules
    return { errors, warnings, nodes, edges }
}
```

Notes:
- **Do not** check team_category / work_center here.
- **Do not** inspect assignment rules here.
- This is purely about **graph correctness**, not production policy.

---

## 3. Service Layer — DAGValidationService::validate(graphId)

**File:** `DAGValidationService.php`

```pseudo
function validate(graphId): Result {
    errors   = []
    warnings = []

    nodes = loadNodes(graphId)
    edges = loadEdges(graphId)
    graphMeta = loadGraphMeta(graphId)

    # 1. Operation node workforce
    validateOperationNodes(nodes, graphMeta, errors, warnings)

    # 2. Assignment rules
    validateAssignmentPolicies(nodes, edges, errors, warnings)

    # 3. Concurrency constraints
    validateConcurrency(nodes, edges, errors, warnings)

    # 4. Legacy compatibility
    validateLegacyConstraints(graphMeta, nodes, edges, errors, warnings)

    return { errors, warnings }
}
```

---

## 4. validateOperationNodes (Business Rule)

```pseudo
function validateOperationNodes(nodes, graphMeta, errors, warnings): void {
    isOldGraph = isLegacyGraph(graphMeta.created_at)

    for each node in nodes:
        if node.type != 'operation':
            continue

        hasTeam = notEmpty(node.team_category)
        hasWC   = node.id_work_center > 0

        if not hasTeam and not hasWC:
            msg = "Operation node \"" + node.code + "\" must have team_category or work_center assigned."

            if isOldGraph:
                msg = msg + " (old graph: recommended to update)"
                warnings.append({
                    code: 'W_OP_MISSING_TEAM',
                    message: msg,
                    node_id: node.id,
                })
            else:
                errors.append({
                    code: 'W_OP_MISSING_TEAM',
                    message: msg,
                    node_id: node.id,
                })
```

Notes:
- This function is the **single source of truth** for the workforce requirement.
- API must **not** duplicate this logic.

---

## 5. isLegacyGraph(created_at)

```pseudo
function isLegacyGraph(created_at): bool {
    CUTOFF = '2025-11-01T00:00:00Z'   # Example; real value in config
    return created_at < CUTOFF
}
```

---

## 6. Routing Engine — High-Level (DAGRoutingService)

**File:** `DAGRoutingService.php`

```pseudo
function routeToken(tokenId): void {
    token = loadToken(tokenId)
    node  = getCurrentNode(token)

    # if no outgoing edges → complete instance
    edges = getOutgoingEdges(node)
    if edges.count == 0:
        completeInstance(token.instanceId)
        return

    if edges.count == 1:
        target = edges[0].to
        routeToNode(token, target)
        return

    # multiple edges → conditional / decision routing
    target = resolveConditionalEdge(node, token, edges)
    routeToNode(token, target)
}
```

---

### 6.1 routeToNode(token, node)

```pseudo
function routeToNode(token, targetNode): void {
    # 1. Move token
    moveToken(token, targetNode)

    # 2. Check node type
    if targetNode.type == 'split':
        handleSplitNode(token, targetNode)
        return

    if targetNode.type == 'join':
        handleJoinNode(token, targetNode)
        return

    # 3. Standard operation / qc / etc.
    # Apply concurrency & WIP limits, then assignment
    if targetNode.type == 'operation':
        enforceConcurrencyLimit(targetNode)
        enforceWipLimit(targetNode)
        resolveAssignmentForToken(token, targetNode)
```

---

## 7. Assignment & Concurrency Pseudocode

```pseudo
function resolveAssignmentForToken(token, node): void {
    # 1. Determine candidate team
    team = findPreferredTeam(node)

    # 2. If no team, allow manual assignment later
    if team is null:
        logAssignmentPlaceholder(token, node)
        return

    # 3. Pick operator based on load, availability
    operator = selectOperatorFromTeam(team)

    # 4. Insert into token_assignment
    insertTokenAssignment(token.id, node.id, operator.id, status='assigned')

    # 5. Log in assignment_log
    logAssignment(token.id, node.id, operator)
}
```

```pseudo
function enforceConcurrencyLimit(node): void {
    limit = node.concurrency_limit
    if limit <= 0:
        return

    activeSessions = getActiveWorkSessions(node.id)
    if activeSessions >= limit:
        queueToken(node)
}
```

Notes:
- `getActiveWorkSessions` must count **status = 'active'**.
- `status='assigned'` means not started yet.

---

## 8. Error & Warning Model

```pseudo
struct ValidationItem {
    code: string
    message: string
    node_id: int | null
    extra: map
}

struct ValidationResult {
    errors:   list<ValidationItem>
    warnings: list<ValidationItem>
}
```

Helpers:

```pseudo
function addError(list, code, message, nodeId=null, extra={}): void
function addWarning(list, code, message, nodeId=null, extra={}): void
```

---

## 9. Notes for AI Agent

- Do not add new business rules to `dag_routing_api.php`.
- All workforce-related rules must live in `DAGValidationService`.
- When refactoring, keep function responsibilities consistent with this pseudocode.

---

End of file.
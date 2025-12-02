# Condition Engine Overview

**Date:** 2025-12-18  
**Purpose:** Complete overview of the unified condition engine for SuperDAG routing  
**Task:** 19.4 - Condition Engine Standardization for Non-QC Routing

> **⚠️ IMPORTANT:** This document describes the unified condition engine that powers all conditional routing decisions in SuperDAG. All conditional routing (QC and non-QC) must use this engine.

---

## Table of Contents

1. [Introduction](#introduction)
2. [Architecture](#architecture)
3. [Condition Types](#condition-types)
4. [Field Registry](#field-registry)
5. [Evaluation Flow](#evaluation-flow)
6. [Usage Examples](#usage-examples)
7. [Integration Points](#integration-points)

---

## Introduction

The Condition Engine is a unified evaluation system for all conditional routing decisions in SuperDAG. It provides:

- **Single Source of Truth:** All routing conditions use the same model
- **Type Safety:** Field types and operators are validated
- **Extensibility:** New fields can be added via field registry
- **Consistency:** Same evaluation logic for QC and non-QC routing

**Key Components:**
- `ConditionEvaluator` (PHP) - Backend evaluation engine
- `ConditionalEdgeEditor` (JS) - Frontend UI editor
- Field Registry - Single source of truth for all fields

---

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────┐
│ Frontend (ConditionalEdgeEditor.js)                    │
│ - Field dropdown (from registry)                       │
│ - Operator selection (based on field type)             │
│ - Value input (select/number/text)                     │
│ - Serialization to unified model                       │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Unified Condition Model (JSON)                         │
│ {                                                       │
│   type: "token_property" | "job_property" | ...        │
│   property: "qc_result.status" | "job.priority" | ...  │
│   operator: "==" | ">" | "IN" | ...                    │
│   value: "pass" | 10 | ["high", "urgent"] | ...        │
│ }                                                       │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Backend (ConditionEvaluator.php)                       │
│ - evaluate(condition, context) → boolean                 │
│ - Type-specific evaluators                              │
│ - Property path resolution                              │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│ Routing Service (DAGRoutingService.php)                │
│ - selectNextNode() uses ConditionEvaluator             │
│ - Context building (token, job, node)                  │
│ - Edge evaluation and selection                         │
└─────────────────────────────────────────────────────────┘
```

### Data Flow

1. **User Input (UI):**
   - User selects field from dropdown (registry-based)
   - UI auto-selects valid operators for field type
   - User enters value (select/number/text based on field type)

2. **Serialization (Frontend):**
   - `ConditionalEdgeEditor.serializeConditionGroups()` converts UI to unified model
   - Property paths use registry format (e.g., `job.priority`, `qc_result.status`)

3. **Storage (Database):**
   - Condition stored in `routing_edge.edge_condition` (JSON)
   - Multi-group format: `{ type: "or", groups: [...] }`

4. **Evaluation (Backend):**
   - `DAGRoutingService::selectNextNode()` loads edges
   - For each conditional edge, calls `ConditionEvaluator::evaluate()`
   - Context built from token, job, node data
   - First matching edge wins

---

## Condition Types

### 1. Token Property

**Type:** `token_property`

**Purpose:** Evaluate conditions based on token data

**Property Paths:**
- `token.qty` - Token quantity
- `token.priority` - Token priority
- `token.rework_count` - Rework count
- `token.status` - Token status
- `token.serial_number` - Serial number
- `token.metadata.X` - Custom metadata fields
- `qc_result.status` - QC result status (stored in token metadata)
- `qc_result.defect_type` - QC defect type
- `qc_result.severity` - QC severity

**Example:**
```json
{
  "type": "token_property",
  "property": "qc_result.status",
  "operator": "==",
  "value": "pass"
}
```

**Evaluator:** `ConditionEvaluator::evaluateTokenProperty()`

---

### 2. Job Property

**Type:** `job_property`

**Purpose:** Evaluate conditions based on job/order data

**Property Paths:**
- `job.priority` - Job priority
- `job.type` - Job type
- `job.target_qty` - Target quantity
- `job.process_mode` - Process mode (piece/batch)
- `job.order_channel` - Order channel
- `job.customer_tier` - Customer tier

**Example:**
```json
{
  "type": "job_property",
  "property": "job.priority",
  "operator": "==",
  "value": "high"
}
```

**Evaluator:** `ConditionEvaluator::evaluateJobProperty()`

**Context:** Job data loaded from `job_ticket` or `mo` table via `DAGRoutingService::fetchJobTicket()`

---

### 3. Node Property

**Type:** `node_property`

**Purpose:** Evaluate conditions based on routing node data

**Property Paths:**
- `node.node_type` - Node type
- `node.behavior_code` - Behavior code
- `node.category` - Node category
- `node.work_center_code` - Work center code
- `node.metadata.X` - Custom metadata fields

**Example:**
```json
{
  "type": "node_property",
  "property": "node.behavior_code",
  "operator": "==",
  "value": "CUT"
}
```

**Evaluator:** `ConditionEvaluator::evaluateNodeProperty()`

**Context:** Node data loaded from `routing_node` table via `DAGRoutingService::fetchNode()`

---

### 4. Expression

**Type:** `expression`

**Purpose:** Default/always-true conditions

**Format:**
```json
{
  "type": "expression",
  "expression": "true"
}
```

**Usage:** Default route edges (else case)

**Evaluator:** `ConditionEvaluator::evaluateExpression()`

**Note:** Expression type is primarily for default routes. Complex expressions are not fully supported yet.

---

## Field Registry

**Location:** `docs/super_dag/condition_field_registry.md`

**Purpose:** Single source of truth for all condition fields

**Contents:**
- Field definitions (Label, Key, Type, Enum Values, Operators)
- Property path mappings
- Usage guidelines

**Rule:** UI and serializer MUST NOT invent new property names. They must use the registry.

**Fields Covered:**
- Token fields (qty, priority, rework_count, status, serial_number, metadata.*, qc_result.*)
- Job fields (priority, type, target_qty, process_mode, order_channel, customer_tier)
- Node fields (node_type, behavior_code, category, work_center_code, metadata.*)

---

## Evaluation Flow

### Step-by-Step Process

1. **Edge Selection:**
   - `DAGRoutingService::selectNextNode()` gets outgoing edges
   - Filters conditional edges (`edge_type = 'conditional'`)

2. **Context Building:**
   - Extracts token data
   - Lazy-loads job data (if `job_property` condition exists)
   - Lazy-loads node data (if `node_property` condition exists)

3. **Condition Evaluation:**
   - For each conditional edge:
     - Normalizes `edge_condition` JSON
     - Calls `ConditionEvaluator::evaluate(condition, context)`
     - Returns boolean result

4. **Edge Matching:**
   - Collects all matching edges
   - If 0 matches → Error: unroutable
   - If 1 match → Route to that edge
   - If 2+ matches → Error: ambiguous (or first match wins, implementation-dependent)

5. **Routing:**
   - Routes token to target node of matching edge
   - Logs routing event

### Multi-Group Evaluation (Task 19.2)

**Format:**
```json
{
  "type": "or",
  "groups": [
    {
      "type": "and",
      "conditions": [
        { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "pass" }
      ]
    },
    {
      "type": "and",
      "conditions": [
        { "type": "token_property", "property": "qc_result.status", "operator": "IN", "value": ["fail_minor", "fail_major"] }
      ]
    }
  ]
}
```

**Evaluation:**
- OR between groups: First group with all conditions matching wins
- AND within groups: All conditions in group must match

**Implementation:**
- `ConditionEvaluator::evaluate()` handles multi-group format
- Recursively evaluates groups and conditions

---

## Usage Examples

### Example 1: QC Pass Routing

**Condition:**
```json
{
  "type": "token_property",
  "property": "qc_result.status",
  "operator": "==",
  "value": "pass"
}
```

**Context:**
```php
[
  'token' => [
    'id' => 1,
    'metadata' => [
      'qc_result' => [
        'status' => 'pass'
      ]
    ]
  ]
]
```

**Result:** `true` (condition matches)

---

### Example 2: Priority-Based Routing

**Condition:**
```json
{
  "type": "job_property",
  "property": "job.priority",
  "operator": "IN",
  "value": ["high", "urgent"]
}
```

**Context:**
```php
[
  'token' => ['id' => 1],
  'job' => [
    'priority' => 'high'
  ]
]
```

**Result:** `true` (condition matches)

---

### Example 3: Multi-Group Condition

**Condition:**
```json
{
  "type": "or",
  "groups": [
    {
      "type": "and",
      "conditions": [
        { "type": "token_property", "property": "qc_result.status", "operator": "==", "value": "fail_minor" },
        { "type": "token_property", "property": "token.qty", "operator": ">=", "value": 5 }
      ]
    }
  ]
}
```

**Context:**
```php
[
  'token' => [
    'id' => 1,
    'qty' => 10,
    'metadata' => [
      'qc_result' => [
        'status' => 'fail_minor'
      ]
    ]
  ]
]
```

**Result:** `true` (both conditions in group match)

---

## Integration Points

### Frontend Integration

**File:** `assets/javascripts/dag/modules/conditional_edge_editor.js`

**Key Methods:**
- `getAvailableFields()` - Returns fields from registry
- `getOperatorsForField(field)` - Returns valid operators for field type
- `getValueInputType(field)` - Returns input type (select/number/text)
- `serializeConditionGroups()` - Converts UI to unified model

**Usage:**
- Integrated into `graph_designer.js` edge properties panel
- Renders multi-group editor (Task 19.2)
- Validates conditions before save

---

### Backend Integration

**File:** `source/BGERP/Dag/ConditionEvaluator.php`

**Key Method:**
- `evaluate(array $condition, array $context): bool` - Evaluates condition

**File:** `source/BGERP/Service/DAGRoutingService.php`

**Key Method:**
- `selectNextNode(array $edges, array $token, ?int $operatorId): array` - Uses ConditionEvaluator

**Usage:**
- All conditional routing uses `ConditionEvaluator`
- Context built from token, job, node data
- Lazy-loading of job/node data when needed

---

### Database Integration

**Table:** `routing_edge`

**Field:** `edge_condition` (JSON)

**Format:**
- Single condition: `{ type: "token_property", property: "...", operator: "...", value: ... }`
- Multi-group: `{ type: "or", groups: [{ type: "and", conditions: [...] }] }`
- Default: `{ type: "expression", expression: "true" }`

---

## Standardization Status

### ✅ Completed (Task 19.0-19.4)

- Unified condition model
- ConditionEvaluator class
- Field registry
- UI editor with registry-based fields
- Multi-group support
- QC and non-QC routing

### ⚠️ Legacy Exceptions

**Decision Nodes:**
- Use `condition_rule` field (separate from `edge_condition`)
- Evaluation order based on `priority` field
- Documented in `task19_4_results.md`

**Rework Edges:**
- Use `edge_type = 'rework'` (explicit edge type)
- Can also use conditional edges with `qc_result.status` conditions

---

## Future Enhancements

### Planned (Task 20+)

- Time-based conditions (ETA, SLA)
- Machine availability conditions
- Historical data conditions
- Complex expression parser
- Performance optimization

### Not Planned

- Weights/costs for routing
- Multi-objective optimization
- Machine allocation via conditions (separate system)

---

**End of Condition Engine Overview**


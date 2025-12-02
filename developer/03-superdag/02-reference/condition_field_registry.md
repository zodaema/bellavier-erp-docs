# Condition Field Registry

**Date:** 2025-12-18  
**Purpose:** Single source of truth for all condition fields used in conditional routing  
**Task:** 19.4 - Condition Engine Standardization for Non-QC Routing

> **⚠️ IMPORTANT:** The UI and serializer MUST NOT invent new property names. They must use this registry as the single source of truth.

---

## Table of Contents

1. [Token Fields](#token-fields)
2. [QC Result Fields](#qc-result-fields)
3. [Job / Order Fields](#job--order-fields)
4. [Node Fields](#node-fields)
5. [Field Usage Guidelines](#field-usage-guidelines)
6. [Property Path Mapping](#property-path-mapping)

---

## Token Fields

Fields available from the token object (`flow_token` table).

### Token Quantity

- **Label:** Token Quantity
- **Key (internal):** `token.qty`
- **Type:** number
- **Condition Type:** `token_property`
- **Operators:** `==`, `!=`, `>`, `>=`, `<`, `<=`
- **Description:** Current quantity of the token

### Token Priority

- **Label:** Token Priority
- **Key (internal):** `token.priority`
- **Type:** enum
- **Enum Values:** `low`, `normal`, `high`, `urgent`
- **Condition Type:** `token_property`
- **Operators:** `==`, `!=`, `IN`, `NOT_IN`
- **Description:** Priority level of the token

### Token Rework Count

- **Label:** Token Rework Count
- **Key (internal):** `token.rework_count`
- **Type:** number
- **Condition Type:** `token_property`
- **Operators:** `==`, `!=`, `>`, `>=`, `<`, `<=`
- **Description:** Number of times token has been reworked

### Token Status

- **Label:** Token Status
- **Key (internal):** `token.status`
- **Type:** enum
- **Enum Values:** `ready`, `active`, `waiting`, `paused`, `completed`, `scrapped`, `cancelled`, `merged`, `consumed`, `stuck`
- **Condition Type:** `token_property`
- **Operators:** `==`, `!=`, `IN`, `NOT_IN`
- **Description:** Current status of the token

### Token Serial Number

- **Label:** Token Serial Number
- **Key (internal):** `token.serial_number`
- **Type:** string
- **Condition Type:** `token_property`
- **Operators:** `==`, `!=`, `CONTAINS`, `STARTS_WITH`
- **Description:** Serial number of the token

### Token Metadata: X

- **Label:** Token Metadata: {X}
- **Key Pattern (internal):** `token.metadata.X`
- **Type:** dynamic (string/number/boolean)
- **Condition Type:** `token_property`
- **Operators:** Depends on type (enum → `==`, `!=`, `IN`, `NOT_IN`; number → `==`, `!=`, `>`, `>=`, `<`, `<=`; string → `==`, `!=`, `CONTAINS`)
- **Description:** Dynamic metadata fields stored in token metadata JSON
- **Note:** Access via `token.metadata.X` where X is the metadata key

---

## QC Result Fields

Fields available from QC result stored in token metadata (`token.metadata.qc_result`).

### QC Status

- **Label:** QC Result → Status
- **Key (internal):** `qc_result.status`
- **Type:** enum
- **Enum Values:** `pass`, `fail_minor`, `fail_major`
- **Condition Type:** `token_property` (accessed via `qc_result.status` in property path)
- **Operators:** `==`, `!=`, `IN`, `NOT_IN`
- **Description:** QC result status (pass, fail_minor, fail_major)
- **Usage:** Primary field for QC routing decisions

### QC Defect Type

- **Label:** QC Result → Defect Type
- **Key (internal):** `qc_result.defect_type`
- **Type:** string/enum
- **Condition Type:** `token_property` (accessed via `qc_result.defect_type` in property path)
- **Operators:** `==`, `!=`, `CONTAINS`, `STARTS_WITH`
- **Description:** Type of defect found in QC (e.g., 'stitch', 'color', 'size')

### QC Severity

- **Label:** QC Result → Severity
- **Key (internal):** `qc_result.severity`
- **Type:** enum
- **Enum Values:** `minor`, `major`
- **Condition Type:** `token_property` (accessed via `qc_result.severity` in property path)
- **Operators:** `==`, `!=`, `IN`, `NOT_IN`
- **Description:** Severity level of QC failure

**Note:** QC result fields are stored in `token.metadata.qc_result` and accessed via `qc_result.*` property paths in `ConditionEvaluator`.

---

## Job / Order Fields

Fields available from the job ticket (`job_ticket` or `mo` table).

### Job Priority

- **Label:** Job → Priority
- **Key (internal):** `job.priority`
- **Type:** enum
- **Enum Values:** `low`, `normal`, `high`, `urgent`
- **Condition Type:** `job_property`
- **Operators:** `==`, `!=`, `IN`, `NOT_IN`
- **Description:** Priority level of the job/order
- **Usage:** Route high-priority jobs to faster paths

### Job Type

- **Label:** Job → Type
- **Key (internal):** `job.type`
- **Type:** enum/string
- **Enum Values:** (varies by system, e.g., `standard`, `custom`, `rush`, `oem`)
- **Condition Type:** `job_property`
- **Operators:** `==`, `!=`, `IN`, `NOT_IN`, `CONTAINS`
- **Description:** Type of job/order

### Job Target Quantity

- **Label:** Job → Target Quantity
- **Key (internal):** `job.target_qty`
- **Type:** number
- **Condition Type:** `job_property`
- **Operators:** `==`, `!=`, `>`, `>=`, `<`, `<=`
- **Description:** Target quantity for the job/order
- **Usage:** Route large orders to batch processing, small orders to piece processing

### Job Process Mode

- **Label:** Job → Process Mode
- **Key (internal):** `job.process_mode`
- **Type:** enum
- **Enum Values:** `piece`, `batch`
- **Condition Type:** `job_property`
- **Operators:** `==`, `!=`, `IN`, `NOT_IN`
- **Description:** Processing mode (piece-by-piece or batch)

### Order Channel

- **Label:** Job → Order Channel
- **Key (internal):** `job.order_channel`
- **Type:** enum/string
- **Enum Values:** `online`, `retail`, `oem`, `wholesale`
- **Condition Type:** `job_property`
- **Operators:** `==`, `!=`, `IN`, `NOT_IN`, `CONTAINS`
- **Description:** Sales channel for the order
- **Usage:** Route different channels to different processing paths

### Customer Tier

- **Label:** Job → Customer Tier
- **Key (internal):** `job.customer_tier`
- **Type:** enum
- **Enum Values:** `normal`, `vip`, `premium`
- **Condition Type:** `job_property`
- **Operators:** `==`, `!=`, `IN`, `NOT_IN`
- **Description:** Customer tier classification
- **Usage:** Route VIP customers to priority processing paths

**Note:** Job fields are loaded from `job_ticket` or `mo` table via `DAGRoutingService::fetchJobTicket()` and passed to `ConditionEvaluator` in the context.

---

## Node Fields

Fields available from the routing node (`routing_node` table).

### Node Type

- **Label:** Node → Node Type
- **Key (internal):** `node.node_type`
- **Type:** enum
- **Enum Values:** `start`, `end`, `operation`, `qc`, `decision`, `subgraph`, `split`, `join`, `wait`
- **Condition Type:** `node_property`
- **Operators:** `==`, `!=`, `IN`, `NOT_IN`
- **Description:** Type of the routing node

### Node Behavior Code

- **Label:** Node → Behavior Code
- **Key (internal):** `node.behavior_code`
- **Type:** enum
- **Enum Values:** (matches behavior registry: `CUT`, `STITCH`, `EDGE`, `QC_SINGLE`, `QC_FINAL`, `HARDWARE_ASSEMBLY`, `QC_REPAIR`, `EMBOSS`)
- **Condition Type:** `node_property`
- **Operators:** `==`, `!=`, `IN`, `NOT_IN`
- **Description:** Behavior code assigned to the node
- **Usage:** Route based on node behavior (e.g., route to CUT nodes only)

### Node Category

- **Label:** Node → Category
- **Key (internal):** `node.category`
- **Type:** enum/string
- **Enum Values:** (varies by system, e.g., `production`, `quality`, `packaging`, `shipping`)
- **Condition Type:** `node_property`
- **Operators:** `==`, `!=`, `IN`, `NOT_IN`, `CONTAINS`
- **Description:** Category classification of the node

### Node Work Center Code

- **Label:** Node → Work Center Code
- **Key (internal):** `node.work_center_code`
- **Type:** string
- **Condition Type:** `node_property`
- **Operators:** `==`, `!=`, `CONTAINS`, `STARTS_WITH`
- **Description:** Work center code assigned to the node

### Node Metadata: X

- **Label:** Node Metadata: {X}
- **Key Pattern (internal):** `node.metadata.X`
- **Type:** dynamic (string/number/boolean)
- **Condition Type:** `node_property`
- **Operators:** Depends on type
- **Description:** Dynamic metadata fields stored in node metadata JSON
- **Note:** Access via `node.metadata.X` where X is the metadata key

**Note:** Node fields are loaded from `routing_node` table via `DAGRoutingService::fetchNode()` and passed to `ConditionEvaluator` in the context.

---

## Field Usage Guidelines

### 1. Field Selection in UI

**Rule:** The UI (`ConditionalEdgeEditor.js`) MUST only show fields from this registry.

**Implementation:**
- `getAvailableFields()` method must return fields matching this registry
- Field dropdown must be generated from registry
- No free-text field input allowed

### 2. Property Path Serialization

**Rule:** When serializing conditions, use the exact property path from this registry.

**Example:**
```json
{
  "type": "job_property",
  "property": "job.priority",
  "operator": "==",
  "value": "high"
}
```

**Not:**
```json
{
  "type": "job_property",
  "property": "priority",  // ❌ Missing "job." prefix
  "operator": "==",
  "value": "high"
}
```

### 3. Condition Type Mapping

**Rule:** Each field has a `conditionType` that determines which evaluator method to use.

**Mapping:**
- `token_property` → `ConditionEvaluator::evaluateTokenProperty()`
- `job_property` → `ConditionEvaluator::evaluateJobProperty()`
- `node_property` → `ConditionEvaluator::evaluateNodeProperty()`

### 4. Operator Selection

**Rule:** Operators must match the field type.

**Type → Operator Mapping:**
- **enum:** `==`, `!=`, `IN`, `NOT_IN`
- **number:** `==`, `!=`, `>`, `>=`, `<`, `<=`
- **string:** `==`, `!=`, `CONTAINS`, `STARTS_WITH`
- **boolean:** `==`, `!=` (with values `true`, `false`)

### 5. Value Input Type

**Rule:** Value input type must match field type.

**Type → Input Mapping:**
- **enum:** Dropdown select (use `enumValues`)
- **number:** Number input
- **string:** Text input
- **boolean:** Checkbox or dropdown (`true`/`false`)

---

## Property Path Mapping

### Internal Property Paths

When evaluating conditions, `ConditionEvaluator` uses the following property paths:

**Token Properties:**
- `token.qty` → `$token['qty']`
- `token.priority` → `$token['priority']`
- `token.rework_count` → `$token['rework_count']`
- `token.status` → `$token['status']`
- `token.serial_number` → `$token['serial_number']`
- `token.metadata.X` → `$token['metadata'][X]`
- `qc_result.status` → `$token['metadata']['qc_result']['status']`
- `qc_result.defect_type` → `$token['metadata']['qc_result']['defect_type']`
- `qc_result.severity` → `$token['metadata']['qc_result']['severity']`

**Job Properties:**
- `job.priority` → `$job['priority']`
- `job.type` → `$job['type']`
- `job.target_qty` → `$job['target_qty']`
- `job.process_mode` → `$job['process_mode']`
- `job.order_channel` → `$job['order_channel']`
- `job.customer_tier` → `$job['customer_tier']`

**Node Properties:**
- `node.node_type` → `$node['node_type']`
- `node.behavior_code` → `$node['behavior_code']`
- `node.category` → `$node['category']`
- `node.work_center_code` → `$node['work_center_code']`
- `node.metadata.X` → `$node['metadata'][X]`

### Property Path Format

**Format:** `{source}.{field}` or `{source}.{field}.{subfield}`

**Examples:**
- `token.qty` - Direct token field
- `job.priority` - Direct job field
- `node.behavior_code` - Direct node field
- `qc_result.status` - QC result in token metadata
- `token.metadata.custom_field` - Custom metadata field

**Note:** Property paths are case-sensitive and must match exactly.

---

## Adding New Fields

### Process

1. **Define Field:**
   - Add entry to appropriate section (Token/QC/Job/Node)
   - Specify: Label, Key, Type, Enum Values (if enum), Condition Type, Operators, Description

2. **Update UI:**
   - Add field to `ConditionalEdgeEditor.getAvailableFields()`
   - Ensure operators and value input type match field type

3. **Update Backend:**
   - Ensure `ConditionEvaluator` can access the field
   - Add property path mapping if needed

4. **Update Documentation:**
   - Add field to this registry
   - Update test cases if applicable

### Validation

- Field must have unique key
- Field must have valid condition type
- Field must have valid operators for its type
- Property path must be resolvable in `ConditionEvaluator`

---

**End of Condition Field Registry**


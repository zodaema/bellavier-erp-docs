# Node Type Policy Matrix - Single Source of Truth

**Created:** November 15, 2025  
**Purpose:** Definitive specification for node type behavior, actions, and visibility  
**Status:** 📋 **CRITICAL** - Required for Phase 2B.5 implementation  
**Audience:** AI Agents, Developers, QA

---

## ⚠️ IMPORTANT

**This document is the authoritative source for node type behavior.**

If any code, UI, or API conflicts with this specification, **THIS DOCUMENT is correct.**

---

## 📋 Node Type Policy Matrix

| node_type | Visible in Work Queue? | Visible in PWA? | Allowed Actions | Status Transitions | Notes |
|-----------|------------------------|-----------------|-----------------|-------------------|-------|
| `start` | ❌ **NO** | ❌ **NO** | `[]` (none) | `auto-enter` | Auto-enters tokens, no operator interaction |
| `operation` | ✅ **YES** | ✅ **YES** | `start`, `pause`, `resume`, `complete` | `ready` → `active` → `complete` → `routed` | Normal work station |
| `qc` | ✅ **YES** | ✅ **YES** | `pass`, `fail` | `ready` → `qc_pass` / `qc_fail` → `routed` | QC-specific actions only |
| `split` | ❌ **NO** | ❌ **NO** | `[]` (none) | `system-controlled` | Auto-spawns child tokens |
| `join` | ❌ **NO** | ❌ **NO** | `[]` (none) | `waiting` → `active` (when ready) | System-controlled, tokens wait automatically |
| `end` | ❌ **NO** | ❌ **NO** | `[]` (none) | `auto-complete` | Final sink, tokens auto-complete |
| `decision` | ⚠️ **CONDITIONAL** | ⚠️ **CONDITIONAL** | `[]` (none) | `auto-route` (based on condition) | May show if needs operator input (form) |
| `system` | ❌ **NO** | ❌ **NO** | `[]` (none) | `system-controlled` | Hidden system nodes |
| `wait` | ⚠️ **CONDITIONAL** | ⚠️ **CONDITIONAL** | `[]` (none) | `waiting` → `active` (after timeout) | May show if needs operator notification |

---

## 🔍 Detailed Specifications

### **1. START Node**

**Purpose:** Entry point for tokens into the graph

**Behavior:**
- Tokens automatically enter at START node
- No operator interaction required
- Tokens immediately move to next node (auto-routing)

**Visibility:**
- ❌ **NOT visible** in Work Queue
- ❌ **NOT visible** in PWA Scan
- ✅ **Visible** in Graph Designer (for configuration)

**Actions:**
- None (system-controlled)

**Status Transitions:**
```
spawned → auto-enter → routed to next node
```

**Implementation:**
```php
// In handleGetWorkQueue() - Filter out START nodes
WHERE rn.node_type != 'start'

// In renderKanbanColumn() - Skip START nodes
if (node.node_type === 'start') {
    return null; // Don't render
}
```

---

### **2. OPERATION Node**

**Purpose:** Normal work station where operators perform tasks

**Behavior:**
- Operators can start, pause, resume, and complete work
- Supports work sessions and time tracking
- Can be assigned to operators

**Visibility:**
- ✅ **Visible** in Work Queue (as column)
- ✅ **Visible** in PWA Scan (when token scanned)

**Actions:**
- `start` - Begin work session
- `pause` - Pause work session
- `resume` - Resume paused session
- `complete` - Complete work and route to next node

**Status Transitions:**
```
ready → [start] → active → [complete] → completed → routed
active → [pause] → paused → [resume] → active
```

**Implementation:**
```javascript
// In renderKanbanTokenCard() - Show operation actions
if (nodeType === 'operation') {
    if (token.status === 'ready') {
        actionButtons = '<button class="btn-start">Start</button>';
    } else if (token.status === 'active') {
        actionButtons = '<button class="btn-pause">Pause</button> <button class="btn-complete">Complete</button>';
    } else if (token.status === 'paused') {
        actionButtons = '<button class="btn-resume">Resume</button> <button class="btn-complete">Complete</button>';
    }
}
```

---

### **3. QC Node**

**Purpose:** Quality control check point

**Behavior:**
- Operators perform QC inspection
- Only Pass/Fail actions allowed
- No Start/Pause/Complete actions
- Auto-routes based on QC result

**Visibility:**
- ✅ **Visible** in Work Queue (as column)
- ✅ **Visible** in PWA Scan (when token scanned)

**Actions:**
- `pass` - QC passed, route to pass edge
- `fail` - QC failed, route to rework edge

**Status Transitions:**
```
ready → [pass] → qc_pass → routed (pass edge)
ready → [fail] → qc_fail → routed (rework edge)
```

**Implementation:**
```javascript
// In renderKanbanTokenCard() - Show QC actions
if (nodeType === 'qc') {
    if (token.status === 'ready' || token.status === 'active') {
        actionButtons = `
            <button class="btn-qc-pass">Pass</button>
            <button class="btn-qc-fail">Fail</button>
        `;
    }
    // NO Start/Pause/Complete buttons
}
```

**API Endpoints:**
```php
// In dag_token_api.php
case 'qc_pass':
    handleQCPass($db, $operatorId);
    break;
    
case 'qc_fail':
    handleQCFail($db, $operatorId);
    break;
```

---

### **4. SPLIT Node**

**Purpose:** Parallel work fork (spawns multiple child tokens)

**Behavior:**
- Automatically spawns child tokens when parent token arrives
- No operator interaction required
- Child tokens inherit parent serial + component suffix

**Visibility:**
- ❌ **NOT visible** in Work Queue
- ❌ **NOT visible** in PWA Scan
- ✅ **Visible** in Graph Designer (for configuration)

**Actions:**
- None (system-controlled)

**Status Transitions:**
```
parent_token arrives → auto-split → child_tokens spawned → parent routed
```

**Implementation:**
```php
// In handleGetWorkQueue() - Filter out SPLIT nodes
WHERE rn.node_type != 'split'

// In DAGRoutingService::handleSplitNode()
// Automatically spawns children, no operator action needed
```

---

### **5. JOIN Node**

**Purpose:** Combine multiple tokens into one (assembly point)

**Behavior:**
- Tokens wait at JOIN node until all required inputs arrive
- System evaluates join condition automatically
- No operator interaction required
- Tokens may show "waiting" status with join info

**Visibility:**
- ❌ **NOT visible** as operable column in Work Queue
- ⚠️ **Visible** as "waiting" status indicator (informational only)
- ❌ **NOT visible** in PWA Scan (no actions)

**Actions:**
- None (system-controlled)

**Status Transitions:**
```
token arrives → waiting → [all inputs ready] → active → routed
```

**Implementation:**
```php
// In handleGetWorkQueue() - Filter out JOIN nodes from operable columns
WHERE rn.node_type IN ('operation', 'qc')

// But JOIN tokens may appear with status='waiting' for informational display
// Show join_info (arrived_count, required_count, components)
```

**Display Rules:**
- Show JOIN tokens in "Waiting" section (informational)
- Display join status (e.g., "2/3 components ready")
- NO action buttons
- NO Start/Pause/Complete buttons

---

### **6. END Node**

**Purpose:** Final sink for completed tokens

**Behavior:**
- Tokens automatically complete when reaching END node
- No operator interaction required
- Marks token as completed

**Visibility:**
- ❌ **NOT visible** in Work Queue
- ❌ **NOT visible** in PWA Scan
- ✅ **Visible** in Graph Designer (for configuration)

**Actions:**
- None (system-controlled)

**Status Transitions:**
```
token arrives → auto-complete → completed
```

**Implementation:**
```php
// In handleGetWorkQueue() - Filter out END nodes
WHERE rn.node_type != 'end'

// In DAGRoutingService::handleEndNode()
// Automatically completes token, no operator action needed
```

---

### **7. DECISION Node**

**Purpose:** Conditional branching based on conditions

**Behavior:**
- Evaluates conditions automatically
- Routes token based on condition result
- May require operator input if form_schema_json is present

**Visibility:**
- ⚠️ **CONDITIONAL** - Visible only if form_schema_json exists (needs operator input)
- ⚠️ **CONDITIONAL** - Otherwise hidden (auto-routing)

**Actions:**
- `submit_form` (if form_schema_json exists)
- None (if auto-routing)

**Status Transitions:**
```
ready → [evaluate condition] → routed (conditional edge)
OR
ready → [operator submits form] → routed (conditional edge)
```

**Implementation:**
```php
// In handleGetWorkQueue() - Show DECISION nodes only if form required
WHERE (rn.node_type != 'decision' OR rn.form_schema_json IS NOT NULL)
```

---

### **8. SYSTEM Node**

**Purpose:** Hidden system nodes (internal use only)

**Behavior:**
- System-controlled nodes
- Not visible to operators
- Used for internal routing logic

**Visibility:**
- ❌ **NOT visible** in Work Queue
- ❌ **NOT visible** in PWA Scan
- ✅ **Visible** in Graph Designer (for advanced configuration)

**Actions:**
- None (system-controlled)

**Status Transitions:**
```
system-controlled (varies by implementation)
```

**Implementation:**
```php
// In handleGetWorkQueue() - Always filter out SYSTEM nodes
WHERE rn.node_type != 'system'
```

---

### **9. WAIT Node**

**Purpose:** Time-based waiting (delay node)

**Behavior:**
- Tokens wait for specified duration
- May notify operators when wait completes
- Auto-routes after timeout

**Visibility:**
- ⚠️ **CONDITIONAL** - Visible if needs operator notification
- ❌ **NOT visible** if pure time-based (no notification)

**Actions:**
- `notify_complete` (if operator notification required)
- None (if pure time-based)

**Status Transitions:**
```
ready → waiting → [timeout] → active → routed
```

**Implementation:**
```php
// In handleGetWorkQueue() - Show WAIT nodes only if notification required
WHERE (rn.node_type != 'wait' OR rn.notify_on_complete = 1)
```

---

## 🔒 Validation Rules

### **Rule 1: Action Validation**

**Before executing any action, validate:**
```php
function validateAction($tokenId, $action, $operatorId) {
    $token = getToken($tokenId);
    $node = getNode($token['current_node_id']);
    
    // Get allowed actions for this node type
    $allowedActions = NODE_TYPE_POLICY[$node['node_type']]['allowed_actions'];
    
    if (!in_array($action, $allowedActions)) {
        json_error("Action '{$action}' not allowed for node type '{$node['node_type']}'", 400);
    }
    
    return true;
}
```

### **Rule 2: Status Transition Validation**

**Before changing token status, validate:**
```php
function validateStatusTransition($tokenId, $newStatus) {
    $token = getToken($tokenId);
    $node = getNode($token['current_node_id']);
    
    $allowedTransitions = NODE_TYPE_POLICY[$node['node_type']]['status_transitions'];
    
    if (!in_array($newStatus, $allowedTransitions)) {
        json_error("Status transition to '{$newStatus}' not allowed for node type '{$node['node_type']}'", 400);
    }
    
    return true;
}
```

### **Rule 3: Visibility Validation**

**Before displaying in UI, validate:**
```php
function shouldShowInWorkQueue($nodeType) {
    return NODE_TYPE_POLICY[$nodeType]['visible_in_work_queue'] === true;
}

function shouldShowInPWA($nodeType) {
    return NODE_TYPE_POLICY[$nodeType]['visible_in_pwa'] === true;
}
```

---

## 📋 Implementation Checklist

### **API (`dag_token_api.php`):**
- [ ] Filter out non-operable nodes in `handleGetWorkQueue()`
- [ ] Add `node_type` to response (already exists, verify)
- [ ] Add validation in `handleStartToken()` - reject if node_type not 'operation'
- [ ] Add validation in `handleCompleteToken()` - reject if node_type not 'operation'
- [ ] Add `qc_pass` endpoint
- [ ] Add `qc_fail` endpoint
- [ ] Validate token is at QC node before processing QC actions

### **Frontend (`work_queue.js`):**
- [ ] Filter nodes before rendering Kanban columns
- [ ] Hide columns for START/END/SPLIT/JOIN/system nodes
- [ ] Add QC Pass/Fail buttons for QC nodes
- [ ] Hide Start/Pause/Complete for QC nodes
- [ ] Add QC action handlers
- [ ] Show join status for JOIN nodes (informational only)

### **PWA Scan (`pwa_scan.js`):**
- [ ] Check `node_type` before showing actions
- [ ] Show Pass/Fail for QC nodes
- [ ] Hide actions for START/END/SPLIT/JOIN nodes
- [ ] Show info message for system nodes

---

## 🎯 Acceptance Criteria

- [ ] START/END/SPLIT/JOIN/system nodes do NOT appear as operable columns in Work Queue
- [ ] QC nodes show Pass/Fail buttons (not Start/Pause/Complete)
- [ ] Operation nodes show Start/Pause/Complete buttons
- [ ] PWA Scan shows appropriate actions based on node_type
- [ ] No invalid actions for system nodes
- [ ] API rejects invalid actions with clear error messages
- [ ] Frontend validates node_type before rendering actions
- [ ] All node types follow this policy matrix exactly

---

## 📝 Related Documents

- `DAG_IMPLEMENTATION_ROADMAP.md` - Phase 2B.5 specification
- `VALIDATION_RULES.md` - Detailed validation rules
- `WORK_QUEUE_OPERATOR_JOURNEY.md` - Work Queue UX design

---

**Document Status:** ✅ **COMPLETE** - Ready for Implementation  
**Last Updated:** November 15, 2025


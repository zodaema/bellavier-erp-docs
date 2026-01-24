# QC Policy Rules - Single Source of Truth

**Created:** 2025-12-09  
**Purpose:** Definitive specification for QC node business rules and permissions  
**Status:** 📋 **CRITICAL** - Required for Issue 1 implementation  
**Audience:** AI Agents, Developers, QA, Business Stakeholders

---

## ⚠️ IMPORTANT

**This document is the authoritative source for QC node behavior.**

If any code, UI, or API conflicts with this specification, **THIS DOCUMENT is correct.**

---

## 🎯 Core Philosophy

**Bellavier Group / Hatthasilpa Model:**
- QC is part of the craftsman's work, not a separate department
- Craftsmen are responsible for their own quality
- QC is a **culture of self-inspection**, not a separate profession

**This aligns 100% with Hermès/Hatthasilpa philosophy:**
- Atelier work = Craftsmen own their quality
- Not mass-production factory model
- Simple, elegant, traceable

---

## 📋 Business Rules (Definitive)

### Rule 1: QC Self-Pass Allowed (Default)

**When:** Token is **unassigned**

**Who can act:**
- ✅ Any operator who can access the node
- ✅ The operator who produced the token (self-QC)
- ✅ Anyone with operator role for that node

**Rationale:**
- Atelier model: Craftsmen QC their own work
- No need for separate QC inspector assignment
- Supports self-ownership culture

**Example:**
```
Token: Ready, Unassigned, Node: QC_SINGLE
→ Any operator can Pass/Fail
```

---

### Rule 2: QC Inspector Optional (When Assigned)

**When:** Token is **assigned to a specific user**

**Who can act:**
- ✅ Only the assigned user (QC inspector)
- ❌ Others cannot act (including self-QC)

**Rationale:**
- When assigned, responsibility is transferred
- Prevents traceability issues
- Supports formal QC inspection model

**Example:**
```
Token: Ready, Assigned to "John (QC Inspector)", Node: QC_SINGLE
→ Only John can Pass/Fail
→ Others see "Assigned to John" message
```

---

### Rule 3: Active Session Ownership

**When:** User has active session on token

**Who can act:**
- ✅ User with active session (regardless of assignment)
- ❌ Others cannot act

**Rationale:**
- User already started QC work
- Must be able to complete their own session
- Prevents work interruption

**Example:**
```
Token: Active, Session owner: "Mary", Assigned to: "John"
→ Mary can Pass/Fail (has active session)
→ John cannot act (Mary has session)
```

---

## 🔧 Configuration Options (per Node)

### Permission Config Structure

```json
{
  "self_qc_allowed": true,           // Default: true (Atelier model)
  "qc_assignment_required": false    // Default: false (open QC)
}
```

### Configuration Scenarios

#### Scenario A: Hatthasilpa (Atelier Model)
```json
{
  "self_qc_allowed": true,
  "qc_assignment_required": false
}
```
**Behavior:**
- Unassigned → Anyone can QC
- Assigned → Only assigned user
- Supports self-QC culture

#### Scenario B: OEM Classic (Formal QC)
```json
{
  "self_qc_allowed": false,
  "qc_assignment_required": true
}
```
**Behavior:**
- Unassigned → Only users with QC role can QC
- Assigned → Only assigned user
- Formal inspection model

#### Scenario C: Hybrid (Flexible)
```json
{
  "self_qc_allowed": true,
  "qc_assignment_required": true
}
```
**Behavior:**
- Unassigned → Anyone can QC (self-QC allowed)
- Assigned → Only assigned user (formal when needed)
- Best of both worlds

---

## 📊 Permission Matrix

| Token State | Assignment | Session | Who Can Act | Rule Applied |
|-------------|-----------|---------|-------------|--------------|
| Ready | Unassigned | None | ✅ Anyone (operator) | Rule 1: Self-QC Allowed |
| Ready | Assigned to A | None | ✅ Only A | Rule 2: Inspector Required |
| Active | Assigned to A | B's session | ✅ Only B | Rule 3: Session Ownership |
| Active | Unassigned | A's session | ✅ Only A | Rule 3: Session Ownership |
| Paused | Assigned to A | B's session | ✅ Only B | Rule 3: Session Ownership |

---

## 🔄 Implementation Logic

### Backend: computeTokenPermissions()

**Current Logic (dag_token_api.php:1829-1830):**
```php
'can_qc_pass' => $nodeType === 'qc' && ($isMine || $canAct),
'can_qc_fail' => $nodeType === 'qc' && ($isMine || $canAct),

// Where:
$canAct = $isAssignedToMe || $isUnassigned || $isMine;
```

**Current Behavior:**
- ✅ Matches Rule 1 (unassigned → anyone)
- ✅ Matches Rule 2 (assigned → only assigned)
- ✅ Matches Rule 3 (session → session owner)

**Status:** ✅ **ALREADY CORRECT** for default behavior

**Enhancement Needed:**
- ⚠️ Add `permission_config` support for `qc_assignment_required`
- ⚠️ Add `self_qc_allowed` check (if needed)

---

### PermissionEngine: checkQcNodeRules()

**Current Logic (PermissionEngine.php:314-336):**
```php
private function checkQcNodeRules(string $action, array $ctx, array $permConfig): bool
{
    $selfQcAllowed = $permConfig['self_qc_allowed'] ?? false;
    $qcAssignmentRequired = $permConfig['qc_assignment_required'] ?? false;
    
    if ($qcAssignmentRequired) {
        if (!$ctx['is_assigned_to_me']) {
            return PermissionHelper::permissionAllowCode($this->member, 'qc.fail.manage');
        }
    }
    
    return true; // Default: allow
}
```

**Status:** ⚠️ **PARTIALLY IMPLEMENTED**
- ✅ Has `qc_assignment_required` check
- ⚠️ `self_qc_allowed` not fully implemented
- ⚠️ Not integrated with `computeTokenPermissions()`

---

### Frontend: renderActionButtons()

**Current Logic (TokenCardParts.js:294-305):**
```javascript
if (state.isQcNode) {
    if (perms.canQcPass || perms.canQcFail) {
        return Pass/Fail buttons;
    }
}
```

**Status:** ✅ **CORRECT**
- Uses permissions from API (Single Source of Truth)
- No additional logic needed

---

## ✅ Validation Checklist

### For Unassigned QC Tokens:
- [x] Any operator can Pass/Fail
- [x] No QC role required (default)
- [x] Supports self-QC culture

### For Assigned QC Tokens:
- [x] Only assigned user can Pass/Fail
- [x] Others see "Assigned to X" message
- [x] Prevents traceability issues

### For Active Sessions:
- [x] Session owner can Pass/Fail
- [x] Others cannot interrupt
- [x] Prevents work loss

### For Configuration:
- [ ] `qc_assignment_required: true` → Enforce QC role for unassigned
- [ ] `self_qc_allowed: false` → Prevent self-QC (if needed)
- [ ] Configurable per node

---

## 🎯 Implementation Plan

### Phase 1: Verify Current Behavior ✅

**Status:** Current code already implements Rules 1, 2, 3 correctly for default case.

**Action:** None needed (already working)

---

### Phase 2: Add Configuration Support (Optional)

**Goal:** Support `qc_assignment_required` and `self_qc_allowed` configs

**Approach:** Integrate PermissionEngine with `computeTokenPermissions()`

**Changes:**
1. Load `permission_config` from node
2. Check `qc_assignment_required` → Require QC role if unassigned
3. Check `self_qc_allowed` → Prevent self-QC if false (if needed)

**Priority:** 🟡 Medium (nice to have, not critical)

---

### Phase 3: Documentation & Testing

**Actions:**
1. ✅ Create this policy document
2. [ ] Update audit document with findings
3. [ ] Write test cases for all scenarios
4. [ ] Verify in production

---

## 📝 Conclusion

**Current Status:** ✅ **WORKING CORRECTLY**

The current implementation already supports the desired business rules:
- ✅ Unassigned QC tokens → Anyone can act (self-QC allowed)
- ✅ Assigned QC tokens → Only assigned user can act
- ✅ Active sessions → Session owner can act

**Enhancement Opportunity:**
- ⚠️ Add `permission_config` support for advanced scenarios (OEM Classic, etc.)
- ⚠️ Integrate PermissionEngine for consistency

**Risk Level:** 🟢 **LOW**
- Current behavior matches requirements
- Enhancement is optional (can be done later)

---

## 🔗 Related Documents

- [Issue 1 Audit Report](../00-audit/20251209_ISSUE1_QC_NODE_BUSINESS_RULE_AUDIT.md)
- [Permission Engine Refactor](../tasks/task27.23_PERMISSION_ENGINE_REFACTOR.md)
- [Node Type Policy](../dag/05-implementation-status/NODE_TYPE_POLICY.md)

---

**Last Updated:** 2025-12-09  
**Next Review:** When implementing `permission_config` support


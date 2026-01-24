# Issue 5: renderActionButtons Logic Audit

**Date:** 2025-12-09  
**Task:** 27.22.1 - Token Card Logic Issues  
**Status:** 🔍 AUDIT COMPLETE

---

## 📋 Objective

Verify consistency between:
1. `renderActionButtons()` logic in `TokenCardParts.js`
2. `canActOnToken()` logic in `TokenCardState.js`
3. Backend permissions from `computeTokenPermissions()` in `dag_token_api.php`

---

## 🔍 Current Implementation Analysis

### 1. renderActionButtons() Logic (TokenCardParts.js:268)

**Current Flow:**
```javascript
function renderActionButtons(state, options = {}) {
    const perms = state.permissions || {};  // From API
    const canAct = TokenCardState.canActOnToken(state);  // Computed locally
    
    // Operation Node: Use API permissions
    if (state.isOperationNode) {
        if (perms.canPause) { return pause button; }
        if (perms.canResume) { return resume button; }
        if (perms.canStart) { return start button; }
        // Material shortage fallback
        // Help/takeover fallback
    }
}
```

**Issues Found:**
- ✅ Uses `state.permissions` from API (Single Source of Truth)
- ⚠️ Computes `canAct` but **doesn't use it** for button rendering
- ⚠️ Help/takeover buttons use fallback logic instead of permissions

### 2. canActOnToken() Logic (TokenCardState.js:181)

**Current Logic:**
```javascript
function canActOnToken(state) {
    if (state.isAssignedToMe) return true;
    if (state.isMine) return true;
    if (state.helpType !== null) return true;
    if (!state.assignedToName) return true;  // Unassigned token
    return false;  // Assigned to someone else
}
```

**Issues Found:**
- ✅ Matches backend `$canAct` logic conceptually
- ⚠️ Not used in `renderActionButtons()` decision
- ⚠️ May not match backend permissions exactly (backend checks material shortage, node type)

### 3. Backend Permissions (dag_token_api.php:1797)

**Backend Logic:**
```php
function computeTokenPermissions(array $token, int $operatorId, array $materialShortageMap): array
{
    $canAct = $isAssignedToMe || $isUnassigned || $isMine;
    
    return [
        'can_start' => $status === 'ready' 
                       && $canAct 
                       && !$hasShortage 
                       && $nodeType === 'operation',
        'can_pause' => $sessionStatus === 'active' && $isMine,
        'can_resume' => $sessionStatus === 'paused' && $isMine,
        'can_complete' => $sessionStatus === 'active' && $isMine,
    ];
}
```

**Key Rules:**
- `can_start`: Ready + canAct + no shortage + operation node
- `can_pause`: Active session + isMine
- `can_resume`: Paused session + isMine
- `can_complete`: Active session + isMine

---

## 🔄 Consistency Analysis

### ✅ **CONSISTENT:**

1. **Pause/Resume Logic:**
   - Frontend: `perms.canPause` / `perms.canResume`
   - Backend: `sessionStatus === 'active' && $isMine` / `sessionStatus === 'paused' && $isMine`
   - ✅ **MATCH** - Both check session ownership

2. **Start Button Logic:**
   - Frontend: `perms.canStart`
   - Backend: `ready && canAct && !shortage && operation`
   - ✅ **MATCH** - Backend already includes all checks

3. **QC Node Logic:**
   - Frontend: `perms.canQcPass` / `perms.canQcFail`
   - Backend: `nodeType === 'qc' && ($isMine || $canAct)`
   - ✅ **MATCH** - Both check node type and assignment

### ⚠️ **POTENTIAL INCONSISTENCIES:**

1. **canAct Variable Not Used:**
   ```javascript
   const canAct = TokenCardState.canActOnToken(state);  // Computed but unused
   ```
   - **Issue:** Computed but never used in button rendering
   - **Impact:** Low (permissions already include canAct check)
   - **Recommendation:** Remove unused variable or use for validation

2. **Help/Takeover Fallback:**
   ```javascript
   // Assigned to someone else - show help/takeover (fallback to old logic)
   if (state.isReady && !state.isWaiting && state.assignedToName && !state.isAssignedToMe && showHelp) {
       return help/takeover buttons;
   }
   ```
   - **Issue:** Uses fallback logic instead of permissions
   - **Impact:** Medium (may show buttons when permissions say no)
   - **Recommendation:** Check `canAct` before showing help/takeover

3. **Material Shortage Check:**
   ```javascript
   if (state.warnings.hasMaterialShortage && state.isReady) {
       return blocked button;
   }
   ```
   - **Issue:** Duplicate check (backend already includes in `can_start`)
   - **Impact:** Low (defense-in-depth, but redundant)
   - **Recommendation:** Keep as UI-level safety check

---

## 📊 Test Cases Required

### Test Case 1: Start Button
- ✅ Ready token + assigned to me → Show Start
- ✅ Ready token + unassigned → Show Start
- ❌ Ready token + assigned to someone else → No Start
- ❌ Ready token + material shortage → No Start (blocked)
- ❌ Active token → No Start

### Test Case 2: Pause Button
- ✅ Active session + isMine → Show Pause
- ❌ Active session + not mine → No Pause
- ❌ Paused session → No Pause
- ❌ No session → No Pause

### Test Case 3: Resume Button
- ✅ Paused session + isMine → Show Resume
- ❌ Paused session + not mine → No Resume
- ❌ Active session → No Resume
- ❌ No session → No Resume

### Test Case 4: Help/Takeover Buttons
- ✅ Ready + assigned to someone else + canAct → Show Help/Takeover
- ❌ Ready + assigned to someone else + !canAct → No buttons
- ❌ Active token → No Help/Takeover

---

## ✅ Recommendations

### 1. **Remove Unused Variable** (Low Priority)
```javascript
// Remove this line if not used:
const canAct = TokenCardState.canActOnToken(state);
```

### 2. **Add canAct Check to Help/Takeover** (Medium Priority)
```javascript
// Before showing help/takeover, verify canAct
if (state.isReady && !state.isWaiting && state.assignedToName && !state.isAssignedToMe && showHelp && canAct) {
    return help/takeover buttons;
}
```

### 3. **Add Unit Tests** (High Priority)
- Test all permission combinations
- Test edge cases (unassigned, assigned, helping, etc.)
- Verify consistency with backend logic

---

## 📝 Conclusion

**Overall Status:** ✅ **MOSTLY CONSISTENT**

- Permissions from API are used correctly
- Backend logic is comprehensive and includes all checks
- Frontend correctly uses `state.permissions` as Single Source of Truth
- Minor issues: unused `canAct` variable, help/takeover fallback logic

**Action Items:**
1. ✅ Write unit tests for all permission combinations
2. ⚠️ Consider using `canAct` for help/takeover validation
3. ⚠️ Remove unused `canAct` variable or document why it's kept

---

**Next Steps:**
- Write unit tests (see `tests/Unit/TokenCardPartsTest.php`)
- Verify edge cases in production
- Document permission flow


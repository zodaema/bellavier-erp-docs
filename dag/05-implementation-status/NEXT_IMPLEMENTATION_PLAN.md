# Next Implementation Plan - December 2025

**Date:** December 2025  
**Current Phase:** Phase 1.5 Wait Node Logic (Partially Complete)  
**Status:** 🟡 **READY FOR COMPLETION**

---

## 📊 Current Implementation Status

### ✅ **Completed Phases:**

- ✅ **Phase 0:** Job Ticket Pages Restructuring (100% Complete)
- ✅ **Phase 1.1-1.4:** Advanced Token Routing (Split, Join, Conditional, Rework)
- ✅ **Phase 2:** Dual-Mode Execution Integration (100% Complete)
- ✅ **Status Consistency Fix:** Token status ENUM updated (December 2025)
- ✅ **Migration Consolidation:** November & December migrations consolidated

### 🟡 **Partially Complete:**

**Phase 1.5: Wait Node Logic** (70% Complete)
- ✅ Database schema (`wait_rule` column)
- ✅ Core routing logic (`handleWaitNode()`, `evaluateWaitCondition()`)
- ✅ Wait condition evaluation (time, batch, approval)
- ✅ Validation (`validateWaitNodes()`)
- ✅ Work Queue filtering
- ⏳ **Missing:** Background job for periodic evaluation
- ⏳ **Missing:** Approval API endpoint
- ⏳ **Missing:** Testing

---

## 🎯 Next Steps - Phase 1.5 Completion

### **Priority 1: Background Job for Wait Condition Evaluation** 🔴

**Why Critical:**
- Required for time-based waits to work automatically
- Required for batch waits to detect when batch is full
- Without this, wait nodes won't auto-complete

**Estimated Time:** 1-2 hours

**Tasks:**
1. Create `tools/cron/evaluate_wait_conditions.php`
2. Implement periodic evaluation logic
3. Set up cron job (every 2-5 minutes)
4. Test with time-based waits

**Dependencies:** None (can start immediately)

---

### **Priority 2: Approval API Endpoint** 🟡

**Why Important:**
- Required for approval-based waits to work
- Allows supervisors/managers to grant approvals
- Completes the approval workflow

**Estimated Time:** 1-2 hours

**Tasks:**
1. Create `source/dag_approval_api.php`
2. Implement `handleGrantApproval()` function
3. Add permission checks (supervisor/manager/admin)
4. Create `approval_granted` event
5. Auto-complete wait node when approval granted

**Dependencies:** None (can start immediately)

---

### **Priority 3: Testing** 🟡

**Why Important:**
- Verify all wait types work correctly
- Ensure edge cases are handled
- Validate integration with routing system

**Estimated Time:** 2-3 hours

**Tasks:**
1. Unit tests for wait evaluation logic
2. Integration tests for all wait types
3. Edge case testing (multiple tokens, batch completion)
4. Manual testing in Graph Designer

**Dependencies:** Priority 1 & 2 (test after implementation)

---

## 📋 Implementation Checklist

### **Phase 1.5 Wait Node Logic:**

- [x] Database schema (`wait_rule` column) ✅
- [x] Core routing logic (`handleWaitNode()`) ✅
- [x] Wait condition evaluation ✅
- [x] Validation (`validateWaitNodes()`) ✅
- [x] Work Queue filtering ✅
- [ ] Background job for periodic evaluation ⏳
- [ ] Approval API endpoint ⏳
- [ ] Testing ⏳

**Completion:** 70% → Target: 100%

---

## 🚀 Recommended Implementation Order

### **Step 1: Background Job** (1-2 hours)
```bash
# Create file
touch tools/cron/evaluate_wait_conditions.php

# Implement evaluation logic
# Set up cron job
```

**Benefits:**
- Enables time-based waits immediately
- Enables batch waits immediately
- Can test with real scenarios

---

### **Step 2: Approval API** (1-2 hours)
```bash
# Create file
touch source/dag_approval_api.php

# Implement approval grant logic
# Add permission checks
```

**Benefits:**
- Completes approval workflow
- Enables supervisor approvals
- Can test approval flow

---

### **Step 3: Testing** (2-3 hours)
- Unit tests
- Integration tests
- Manual testing

**Benefits:**
- Validates all wait types work
- Ensures production readiness
- Documents expected behavior

---

## 📊 After Phase 1.5 Completion

### **Next Phase: Phase 1.6 Decision Node Logic**

**Priority:** 🟡 **IMPORTANT**  
**Duration:** 0.5-1 week  
**Dependencies:** Phase 1.5 (Wait Node)

**Objective:**
- Implement `decision` node type for conditional branching
- Quantity-based routing (if qty > 10 → bulk line)
- Material-based routing (if material = goat → sewing A)
- Rework-based routing (if rework_count > 1 → scrap)

**Status:** ⏳ **NOT IMPLEMENTED**

---

## 🎯 Success Criteria

**Phase 1.5 Complete When:**
- ✅ Background job evaluates wait conditions periodically
- ✅ Approval API allows granting approvals
- ✅ All wait types tested and working
- ✅ Wait nodes auto-complete when conditions met
- ✅ Wait completion routes tokens correctly

---

## 📝 Notes

- **Current Status:** Phase 1.5 is 70% complete
- **Remaining Work:** Background job + Approval API + Testing
- **Estimated Time:** 4-7 hours total
- **Priority:** Complete Phase 1.5 before moving to Phase 1.6

---

**Last Updated:** December 2025  
**Next Review:** After Phase 1.5 completion


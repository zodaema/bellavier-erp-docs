# Modal-Revision Integration Design

**Date:** 2026-01-06  
**Status:** Design Complete  
**Implementation:** Pending User Approval

---

## 🎯 **Problem Statement**

**Current State:**
- **Old Modals** (Edit Component, Add Material, Configure Constraints) save changes **directly to database**
- **New Workspace** (Product Workspace with tabs) implements **Revision-First Architecture**
- **Conflict:** Old modals bypass revision checks → can cause **breaking changes without creating new revision**

**User Questions:**
1. เมื่อบันทึกค่า Constraints ใน edit (Modal เดิม) → SQL binding error
2. ปุ่มกดดู Constraints ในแท็บ Structure ทำงานแล้ว แต่ยังไม่ปรากฎรายละเอียดใด (✅ Fixed)
3. ต้องคิดต่อว่า ถ้าจะใช้ Modal เดิมในการ Edit Component, Config Constraints จะนำมาเชื่อมต่อกับระบบ Revision, Draft Alert อย่างไร

---

## 📐 **Design Options**

### **Option A: Pre-Save Interception (แนะนำ)**

```
User clicks Save in Modal
       ↓
[ProductWorkspace intercepts]
  ├─ Check: Is this a breaking change?
  │   ├─ YES → Show Revision Dialog
  │   │         ├─ User confirms → Create Revision + Save
  │   │         └─ User cancels → Abort
  │   └─ NO → Save directly
  └─ Update Global Draft Alert
```

**Implementation:**

```javascript
// In product_workspace.js
function interceptModalSave(modalType, data) {
  // Step 1: Check if breaking change
  const isBreaking = await checkBreakingChange(modalType, data);
  
  if (isBreaking && state.usageState === 'IN_PRODUCTION') {
    // Step 2: Show revision dialog
    const result = await Swal.fire({
      title: t('workspace.revision.breaking_change_title', 'Breaking Change Detected'),
      html: `
        <p>${t('workspace.revision.breaking_change_message', 'This change requires a new revision because it affects production.')}</p>
        <ul class="text-start">
          <li>${t('workspace.revision.current_jobs_safe', 'Current jobs will continue using the old revision')}</li>
          <li>${t('workspace.revision.new_jobs_use_new', 'New jobs will use the new revision')}</li>
        </ul>
      `,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonText: t('workspace.revision.create_and_save', 'Create Revision & Save'),
      cancelButtonText: t('common.action.cancel', 'Cancel')
    });
    
    if (!result.isConfirmed) {
      return { ok: false, cancelled: true };
    }
    
    // Step 3: Create revision first
    const revisionResp = await $.post(CONFIG.productApiEndpoint, {
      action: 'create_revision',
      id_product: state.productId,
      reason: `Breaking change: ${modalType}`
    });
    
    if (!revisionResp.ok) {
      toastr.error(t('workspace.revision.create_failed', 'Failed to create revision'));
      return { ok: false, error: revisionResp.error };
    }
    
    // Step 4: Save changes
    const saveResp = await saveModalData(modalType, data);
    
    if (saveResp.ok) {
      // Step 5: Update workspace state
      await loadProduct(state.productId);
      updateGlobalDraftAlert();
      toastr.success(t('workspace.revision.created_and_saved', 'Revision created and changes saved'));
    }
    
    return saveResp;
  } else {
    // Non-breaking change → save directly
    const saveResp = await saveModalData(modalType, data);
    
    if (saveResp.ok) {
      // Mark as draft (server-side)
      state.serverDraft.structure = true; // or .production
      updateGlobalDraftAlert();
    }
    
    return saveResp;
  }
}

// Helper: Check if change is breaking
async function checkBreakingChange(modalType, data) {
  // Call backend API to determine if breaking
  const resp = await $.getJSON(CONFIG.productApiEndpoint, {
    action: 'check_breaking_change',
    modal_type: modalType,
    data: JSON.stringify(data),
    id_product: state.productId
  });
  
  return resp.is_breaking || false;
}

// Helper: Save modal data
async function saveModalData(modalType, data) {
  const actionMap = {
    'edit_component': 'update_component',
    'add_material': 'add_component_material',
    'edit_material': 'update_component_material',
    'config_constraints': 'update_component_material'
  };
  
  return await $.post(CONFIG.productApiEndpoint, {
    action: actionMap[modalType],
    ...data
  });
}
```

**Pros:**
- ✅ Minimal changes to existing modals
- ✅ Centralized revision logic in workspace
- ✅ User gets clear feedback before breaking changes
- ✅ Works with all existing modals

**Cons:**
- ⚠️ Requires backend API `check_breaking_change`
- ⚠️ Slightly more complex flow

---

### **Option B: Modal-Level Integration**

```
User clicks Save in Modal
       ↓
[Modal's save handler]
  ├─ Call ProductWorkspace.checkRevision(data)
  ├─ If breaking → Show dialog
  └─ Save via ProductWorkspace API wrapper
```

**Implementation:**

```javascript
// In product_components.js (existing modal code)
function handleComponentSave() {
  const data = getFormData();
  
  // Check revision via workspace
  if (window.ProductWorkspace && window.ProductWorkspace.checkRevisionRequired) {
    const revisionCheck = await window.ProductWorkspace.checkRevisionRequired('edit_component', data);
    
    if (revisionCheck.required && !revisionCheck.confirmed) {
      // User cancelled
      return;
    }
  }
  
  // Save via workspace wrapper (handles draft state)
  if (window.ProductWorkspace && window.ProductWorkspace.saveWithDraft) {
    const result = await window.ProductWorkspace.saveWithDraft('edit_component', data);
    if (result.ok) {
      closeModal();
      reloadComponentList();
    }
  } else {
    // Fallback: direct save (old behavior)
    const result = await $.post('source/product_api.php', {
      action: 'update_component',
      ...data
    });
    // ...
  }
}
```

**Pros:**
- ✅ Each modal has control over its flow
- ✅ Can customize behavior per modal

**Cons:**
- ❌ Requires modifying **every existing modal**
- ❌ Duplicated logic across modals
- ❌ Higher maintenance cost

---

### **Option C: Backend-Only Enforcement**

```
User clicks Save in Modal
       ↓
[Modal saves directly to API]
       ↓
[Backend API]
  ├─ Check: Is breaking change?
  │   ├─ YES → Return error "revision_required"
  │   └─ NO → Save + Mark as draft
  └─ Return response
       ↓
[Modal handles error]
  └─ If "revision_required" → Show message + reload workspace
```

**Implementation:**

```php
// In source/product_api.php
function handleUpdateComponent($tenantDb, $member) {
    // ... existing validation ...
    
    // Check if breaking change
    $usageState = ProductUsageStateService::getUsageState($tenantDb, $productId);
    $isBreaking = ProductUsageStateService::isBreakingChange($tenantDb, $productId, 'component_update', $data);
    
    if ($isBreaking && $usageState['state'] === 'IN_PRODUCTION' && !$usageState['has_draft_changes']) {
        // Reject: Must create revision first
        json_error(translate('api.product.error.revision_required', 'This change requires a new revision. Please use the Workspace to create a revision first.'), 409, [
            'app_code' => 'PRD_409_REVISION_REQUIRED',
            'requires_revision' => true
        ]);
    }
    
    // Save + mark as draft
    // ... existing save logic ...
    
    // Mark as draft (if not already)
    $stmt = $tenantDb->prepare("UPDATE product SET has_draft_changes = 1 WHERE id_product = ?");
    $stmt->bind_param('i', $productId);
    $stmt->execute();
    
    json_success(['message' => 'Saved as draft']);
}
```

```javascript
// In product_components.js (modal)
function handleComponentSave() {
  const data = getFormData();
  
  $.post('source/product_api.php', {
    action: 'update_component',
    ...data
  }).done(function(resp) {
    if (resp.ok) {
      closeModal();
      reloadComponentList();
    }
  }).fail(function(xhr) {
    const resp = xhr.responseJSON;
    if (resp && resp.app_code === 'PRD_409_REVISION_REQUIRED') {
      Swal.fire({
        title: 'Revision Required',
        text: 'This change requires a new revision. Please use the Product Workspace to create a revision first.',
        icon: 'warning',
        confirmButtonText: 'Open Workspace'
      }).then((result) => {
        if (result.isConfirmed) {
          // Reload workspace or navigate to it
          window.location.reload();
        }
      });
    } else {
      toastr.error(resp.error || 'Save failed');
    }
  });
}
```

**Pros:**
- ✅ Backend enforces rules (cannot bypass)
- ✅ Minimal frontend changes

**Cons:**
- ❌ Poor UX: User finds out **after** clicking save
- ❌ No automatic revision creation
- ❌ User must manually go to workspace

---

## 🏆 **Recommended Approach: Option A (Pre-Save Interception)**

**Why:**
1. **Best UX**: User gets clear feedback **before** save
2. **Centralized**: All revision logic in one place (`product_workspace.js`)
3. **Flexible**: Works with all existing modals without modifying them
4. **Safe**: Backend can still validate (defense in depth)

**Implementation Plan:**

### **Phase 1: Backend API (New Endpoints)**

```php
// source/product_api.php

case 'check_breaking_change':
    handleCheckBreakingChange($tenantDb, $member);
    break;

function handleCheckBreakingChange($tenantDb, $member) {
    $productId = (int)($_GET['id_product'] ?? 0);
    $modalType = $_GET['modal_type'] ?? '';
    $data = json_decode($_GET['data'] ?? '{}', true);
    
    // Determine if breaking
    $isBreaking = ProductUsageStateService::isBreakingChange($tenantDb, $productId, $modalType, $data);
    
    json_success([
        'is_breaking' => $isBreaking,
        'reason' => $isBreaking ? 'Affects production' : null
    ]);
}
```

### **Phase 2: Frontend Wrapper (product_workspace.js)**

```javascript
// Export functions for modals to use
window.ProductWorkspace = window.ProductWorkspace || {};

window.ProductWorkspace.interceptModalSave = async function(modalType, data) {
  return await interceptModalSave(modalType, data);
};

window.ProductWorkspace.checkBreakingChange = async function(modalType, data) {
  return await checkBreakingChange(modalType, data);
};
```

### **Phase 3: Modal Integration (Minimal Changes)**

```javascript
// In product_components.js (example)
// OLD:
$('#btnSaveComponent').on('click', function() {
  const data = getFormData();
  $.post('source/product_api.php', { action: 'update_component', ...data })
    .done(function(resp) { /* ... */ });
});

// NEW:
$('#btnSaveComponent').on('click', async function() {
  const data = getFormData();
  
  // Use workspace wrapper if available
  if (window.ProductWorkspace && window.ProductWorkspace.interceptModalSave) {
    const result = await window.ProductWorkspace.interceptModalSave('edit_component', data);
    if (result.ok) {
      closeModal();
      reloadComponentList();
    }
  } else {
    // Fallback: direct save (old behavior)
    $.post('source/product_api.php', { action: 'update_component', ...data })
      .done(function(resp) { /* ... */ });
  }
});
```

---

## 📋 **Implementation Checklist**

### **Backend (PHP)**
- [ ] Add `check_breaking_change` API endpoint
- [ ] Implement `ProductUsageStateService::isBreakingChange()`
- [ ] Add validation in `update_component`, `update_component_material` to reject breaking changes without revision
- [ ] Add `has_draft_changes` flag update after non-breaking saves

### **Frontend (JavaScript)**
- [ ] Add `interceptModalSave()` in `product_workspace.js`
- [ ] Add `checkBreakingChange()` helper
- [ ] Add `saveModalData()` helper
- [ ] Export `window.ProductWorkspace` API
- [ ] Update `updateGlobalDraftAlert()` to handle modal saves

### **Modal Integration**
- [ ] Update `product_components.js` (Edit Component modal)
- [ ] Update `product_components.js` (Add/Edit Material modal)
- [ ] Update `product_components.js` (Configure Constraints modal)
- [ ] Test all modals with revision checks

### **Testing**
- [ ] Test breaking change detection (e.g., change component name)
- [ ] Test non-breaking change (e.g., update qty)
- [ ] Test revision creation flow from modal
- [ ] Test Global Draft Alert updates
- [ ] Test fallback behavior (when workspace not loaded)

---

## 🚀 **Next Steps**

1. **Get User Approval** on Option A design
2. **Implement Backend API** (`check_breaking_change`)
3. **Implement Frontend Wrapper** (`interceptModalSave`)
4. **Integrate with Modals** (minimal changes)
5. **Test End-to-End** (breaking + non-breaking scenarios)

---

## 📝 **Notes**

- **Backward Compatibility**: Old modals still work if workspace not loaded (fallback to direct save)
- **Defense in Depth**: Backend should still validate even if frontend checks pass
- **User Experience**: Clear dialogs explain why revision is needed
- **Draft State**: Non-breaking changes mark product as "has_draft_changes" for later publishing

---

**End of Design Document**

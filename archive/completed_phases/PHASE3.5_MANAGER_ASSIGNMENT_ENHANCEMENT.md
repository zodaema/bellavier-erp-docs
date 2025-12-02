# Phase 3.5: Manager Assignment Enhancement Plan

**Version:** 1.0  
**Date:** November 7, 2025  
**Duration:** 1-2 days (8-16 hours)  
**Priority:** URGENT (UX blocker + Team integration missing)

---

## 🎯 Goal

Fix Manager Assignment page to integrate with Team System and improve Plans tab UX (currently requires manual ID input - unusable).

---

## 🔍 Current Problems

### **Tokens Tab:**
- ✅ Team dropdown works (Phase 2)
- ✅ Operator dropdown works (Phase 3 API)
- ⚠️ **But no visual hint when no operators found**

### **Plans Tab:**
- ❌ **Requires manual node ID input** (how does manager know ID?)
- ❌ **Requires manual operator ID input** (hard to use)
- ❌ **No team integration** (can't assign team to node)
- ❌ **No operator search/dropdown**
- ❌ **Poor UX - managers won't use it**

### **People Tab:**
- ✅ Fully integrated (Phase 2.5 + Phase 3)

---

## 📦 Deliverables

### 1. Tokens Tab Enhancement (2 hours)
- Add operator meta hint display (when dropdown empty)
- Show "No operators configured" warning

### 2. Plans Tab Redesign (6-12 hours) **PRIORITY**
- Replace manual ID inputs with dropdowns
- Node selector (dropdown with node names)
- Operator/Team selector (unified dropdown)
- Show existing assignments (table)
- Edit/Delete assignments easily
- Bulk assignment wizard

---

## 🗓️ Timeline

### **Quick Fix (8 hours - 1 day):**

#### Hour 1-2: Tokens Tab - Add Operator Hint
**Tasks:**
- [ ] Add hint container below operator dropdown
- [ ] Show meta hint when operators empty
- [ ] Style with alert-warning

**Code:**
```html
<!-- Add below operator dropdown in assign modal -->
<div id="operator-hint" class="alert alert-warning mt-2" style="display: none;">
  <i class="bi bi-exclamation-triangle"></i>
  <span id="operator-hint-text"></span>
</div>
```

```javascript
// In loadOperators() success
if (operators.length === 0 && resp.meta?.hint_detail) {
  $('#operator-hint').show();
  $('#operator-hint-text').text(resp.meta.hint_detail);
} else {
  $('#operator-hint').hide();
}
```

---

#### Hour 3-8: Plans Tab - Complete Redesign

**New UI Structure:**
```
┌─────────────────────────────────────────┐
│ Plans Tab                                │
├─────────────────────────────────────────┤
│ [+ Create New Plan]                      │
│                                          │
│ Existing Plans Table:                    │
│ ┌──────────┬──────────┬──────┬────────┐ │
│ │ Node     │ Assigned │ Type │ Actions│ │
│ ├──────────┼──────────┼──────┼────────┤ │
│ │ เริ่มต้น  │ ทีมเย็บ   │ Team │ Edit   │ │
│ │ ตัดวัสดุ │ นายสมชาย │ User │ Delete │ │
│ └──────────┴──────────┴──────┴────────┘ │
└─────────────────────────────────────────┘
```

**Tasks:**
- [ ] API: `list_plans` - Get all node assignments
- [ ] API: `create_plan` - Create with node name (not ID)
- [ ] API: `update_plan` - Update existing
- [ ] API: `delete_plan` - Remove assignment
- [ ] UI: Plans table (DataTable)
- [ ] UI: Create/Edit modal with dropdowns
- [ ] JS: Load nodes dropdown
- [ ] JS: Load operators/teams dropdown (unified)
- [ ] JS: CRUD operations

**Create/Edit Modal:**
```html
<select id="plan-node" required>
  <option value="">-- Select Node --</option>
  <option value="123">เริ่มต้น (Start)</option>
  <option value="124">ตัดวัสดุ (Cut)</option>
</select>

<select id="plan-assignment-type">
  <option value="team">Assign to Team</option>
  <option value="user">Assign to Operator</option>
</select>

<select id="plan-team" style="display:none">
  <option value="">-- Select Team --</option>
  <option value="5">ทีมเย็บมือ</option>
</select>

<select id="plan-operator" style="display:none">
  <option value="">-- Select Operator --</option>
  <option value="42">นายสมชาย (admin)</option>
</select>
```

---

### **Full Enhancement (16 hours - 2 days):**

Add to quick fix:

#### Hour 9-12: Plans Tab - Bulk Assignment Wizard
**Tasks:**
- [ ] Multi-node selection
- [ ] Assign same team/operator to multiple nodes
- [ ] Preview before save

#### Hour 13-16: Plans Tab - Copy/Templates
**Tasks:**
- [ ] Copy from another graph
- [ ] Save as template
- [ ] Quick apply common patterns

---

## 📋 API Changes Needed

### New Endpoints (`assignment_plan_api.php`):

```php
// 1. List all plans (with names, not IDs)
case 'list_plans':
  // JOIN with routing_node, team, account
  // Return: node_name, assigned_name, type (team/user)
  
// 2. Create plan (accept node name or ID)
case 'create_plan':
  // Accept: node_id OR node_name
  // Accept: team_id OR user_id
  // Validate node exists
  // Validate team/user exists
  
// 3. Get nodes list (for dropdown)
case 'get_nodes':
  // Return all nodes with names
  // Format: [{id: 123, name: 'เริ่มต้น'}]
  
// 4. Get assignment options (for dropdown)
case 'get_assignment_options':
  // Return teams + operators (unified list)
  // Format: [
  //   {type: 'team', id: 5, name: 'ทีมเย็บ'},
  //   {type: 'user', id: 42, name: 'นายสมชาย'}
  // ]
```

---

## 🎨 UI Mockup

### Before (Current - BAD):
```
┌─────────────────────────────────┐
│ Node ID: [____] (manual input)  │
│ User ID: [____] (manual input)  │
│ [Save]                          │
└─────────────────────────────────┘
❌ Manager doesn't know IDs!
```

### After (New - GOOD):
```
┌─────────────────────────────────┐
│ Node: [เริ่มต้น ▼]             │
│ Assign to: [● Team ○ Operator]  │
│ Team: [ทีมเย็บมือ ▼]            │
│ [Save Plan]                     │
└─────────────────────────────────┘
✅ Manager can see names!
```

---

## 📁 Files to Change

### Backend (3 files):
1. `source/assignment_plan_api.php` - Add 4 new endpoints
2. `source/dag_token_api.php` - Add `get_nodes` helper (if not exist)
3. `source/team_api.php` - Reuse existing team list

### Frontend (2 files):
1. `views/manager_assignment.php` - Redesign Plans tab HTML
2. `assets/javascripts/manager/assignment.js` - Add Plans CRUD logic

---

## ✅ Success Criteria

### Quick Fix (Day 1):
- [ ] Tokens tab shows operator hint (when empty)
- [ ] Plans tab has node dropdown (no manual ID)
- [ ] Plans tab has operator/team dropdown (no manual ID)
- [ ] Plans table shows existing assignments
- [ ] Create/Edit/Delete plans work

### Full Enhancement (Day 2):
- [ ] Bulk assignment wizard works
- [ ] Copy plans between graphs works
- [ ] Template save/load works

---

## 🚀 Deployment

**Quick Fix (Recommended - Start Tomorrow):**
- 8 hours = 1 working day
- No breaking changes
- Immediate UX improvement
- Managers can actually use Plans tab

**Full Enhancement (Optional - Week 2):**
- +8 hours = 2 working days total
- Advanced features
- Nice-to-have, not critical

---

## 💡 Recommendation

### **Do Quick Fix First (8 hours):**

**Why:**
1. ✅ Fixes critical UX issue (manual IDs unusable)
2. ✅ Integrates with existing Team System
3. ✅ Managers can pre-assign work efficiently
4. ✅ Low risk (only UI/API changes)

**Then:**
- Deploy → Get feedback (3-5 days)
- If needed → Add bulk/templates (Week 2)

---

**Estimated Effort:** 8-16 hours (1-2 days)  
**Risk:** LOW (UI/API only, no database changes)  
**Business Impact:** HIGH (Makes Plans tab actually usable)  
**User Impact:** CRITICAL (Managers currently avoid Plans tab)

---

## 📊 Priority Comparison

| Feature | Priority | Effort | Impact | Start |
|---------|----------|--------|--------|-------|
| **Manager Assignment Fix** | 🔴 **URGENT** | 1-2 days | HIGH | **NOW** |
| Analytics Dashboard | 🟡 Medium | 3-4 days | HIGH | Week 2 |
| Mobile PWA | 🟢 Low | 2-3 days | Medium | Week 3 |

**Recommendation: Fix Manager Assignment first (tomorrow), then Analytics (next week)**


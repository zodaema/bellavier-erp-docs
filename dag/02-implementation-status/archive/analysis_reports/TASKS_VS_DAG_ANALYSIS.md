# Tasks vs DAG Tokens - Analysis & Recommendations

**Created:** November 15, 2025  
**Purpose:** Analyze whether Tasks system needs improvement before Phase 2B implementation  
**Status:** 🔍 Analysis Complete

---

## 📋 Executive Summary

### **Key Finding:**
**Tasks system (`job_task`) is for LINEAR mode only. DAG mode uses `routing_node` + `flow_token` instead.**

### **Recommendation:**
✅ **NO NEED to fix Tasks system before Phase 2B** - They serve different purposes:
- **Linear Mode:** Uses `job_task` table (sequential tasks)
- **DAG Mode:** Uses `routing_node` + `flow_token` (graph-based tokens)

However, **UI improvements needed** to clearly distinguish between Linear and DAG modes in the job ticket detail view.

---

## 🔍 Current State Analysis

### **1. Tasks System (Linear Mode)**

**Table:** `job_task` (aliased as `hatthasilpa_job_task`)

**Purpose:**
- Sequential task list for Linear production
- Each task has `sequence_no` (1, 2, 3...)
- Tasks linked to `job_ticket` via `id_job_ticket`
- Progress tracked via WIP logs (`wip_log`)

**API Endpoints:**
- `task_list` - Get tasks for a job ticket
- `task_create` - Create new task
- `task_update` - Update task
- `task_delete` - Delete task

**UI Location:**
- `views/hatthasilpa_job_ticket.php` - Tasks table (`#tbl-job-tasks`)
- `assets/javascripts/hatthasilpa/job_ticket.js` - Tasks rendering logic

**Current Status:**
- ✅ API endpoints exist and functional
- ✅ UI table exists
- ⚠️ **Issue:** Tasks table shows for ALL job tickets (including DAG mode)
- ⚠️ **Issue:** No clear indication when job is DAG mode (should hide Tasks, show Tokens instead)

---

### **2. DAG Tokens System (DAG Mode)**

**Tables:** 
- `routing_node` - Process steps (from graph template)
- `flow_token` - Individual work units
- `token_event` - Event audit trail
- `token_work_session` - Active work sessions

**Purpose:**
- Graph-based production flow
- Tokens flow through nodes (not sequential tasks)
- Multiple tokens can be at same node simultaneously
- Supports split/join/conditional routing

**API Endpoints:**
- `dag_token_api.php` - Token operations
- `token_management_api.php` - Token management UI

**UI Location:**
- `views/token_management.php` - Token management UI
- `views/work_queue.php` - Work Queue (Phase 2B target)

**Current Status:**
- ✅ Backend APIs complete
- ✅ Token management UI exists
- ⏳ Work Queue integration (Phase 2B) - Pending

---

## 🔗 Relationship Between Tasks and DAG Tokens

### **Key Insight:**
**Tasks (`job_task`) and DAG Tokens (`flow_token`) are MUTUALLY EXCLUSIVE:**

1. **Linear Mode (`routing_mode='linear'`):**
   - Uses `job_task` table
   - Sequential workflow
   - Progress via WIP logs
   - **Tasks table should be visible**

2. **DAG Mode (`routing_mode='dag'` + `graph_instance_id IS NOT NULL`):**
   - Uses `routing_node` (from graph template)
   - Graph-based workflow
   - Progress via token events
   - **Tasks table should be HIDDEN, Tokens table shown instead**

### **Current Problem:**
The `hatthasilpa_job_ticket.php` view shows Tasks table for ALL job tickets, regardless of routing mode. This causes confusion:
- DAG jobs show empty Tasks table (tasks don't exist)
- Users don't see DAG tokens (which are the actual work units)
- No clear indication that job is DAG mode

---

## 🎯 Recommended Actions

### **Option 1: Quick Fix (Recommended)**
**Hide Tasks table for DAG jobs, show Tokens table instead**

**Changes Needed:**
1. **Backend:** Check `routing_mode` and `graph_instance_id` in `task_list` API
   - If DAG mode → Return empty array or special flag
   
2. **Frontend:** Conditionally render Tasks vs Tokens table
   - If Linear mode → Show Tasks table (current behavior)
   - If DAG mode → Hide Tasks table, show Tokens table (link to token_management.php)

**Files to Modify:**
- `source/hatthasilpa_job_ticket.php` - Add routing mode check
- `assets/javascripts/hatthasilpa/job_ticket.js` - Conditional rendering
- `views/hatthasilpa_job_ticket.php` - Add Tokens section for DAG mode

**Effort:** ~2-3 hours

---

### **Option 2: Full Integration**
**Integrate DAG tokens directly into job ticket detail view**

**Changes Needed:**
1. Add Tokens section in job ticket detail panel
2. Show tokens grouped by node (similar to Phase 2B Work Queue)
3. Allow token actions (Start/Pause/Complete) from job ticket view
4. Show token status, progress, assignments

**Files to Modify:**
- `source/hatthasilpa_job_ticket.php` - Add token list API endpoint
- `assets/javascripts/hatthasilpa/job_ticket.js` - Add token rendering logic
- `views/hatthasilpa_job_ticket.php` - Add Tokens section UI

**Effort:** ~1-2 days (overlaps with Phase 2B)

---

### **Option 3: Do Nothing (Not Recommended)**
**Keep current behavior**

**Issues:**
- Users confused by empty Tasks table for DAG jobs
- No visibility into DAG tokens from job ticket view
- Poor UX for DAG mode jobs

---

## 📊 Impact Analysis

### **If We Fix Tasks System:**

**Pros:**
- ✅ Clear separation between Linear and DAG modes
- ✅ Better UX for DAG jobs
- ✅ Users can see tokens from job ticket view
- ✅ Reduces confusion

**Cons:**
- ⏱️ Delays Phase 2B by 2-3 hours (Option 1) or 1-2 days (Option 2)
- 🔄 May duplicate work if Phase 2B already covers this

---

### **If We Skip Tasks Fix:**

**Pros:**
- ✅ Phase 2B can proceed immediately
- ✅ No delay in implementation

**Cons:**
- ❌ Users confused by empty Tasks table
- ❌ Poor UX for DAG jobs
- ❌ May need to fix later anyway

---

## 🎯 Final Recommendation

### **Recommended Approach: Option 1 (Quick Fix)**

**Rationale:**
1. **Low effort, high impact** - 2-3 hours for significant UX improvement
2. **Doesn't block Phase 2B** - Can be done in parallel or before Phase 2B
3. **Prevents user confusion** - Clear indication of DAG vs Linear mode
4. **Sets foundation** - Makes it easier to add full token integration later

**Implementation Steps:**

1. **Backend:** Add routing mode check in `task_list` API
   ```php
   // In hatthasilpa_job_ticket.php
   case 'task_list':
       // ... existing code ...
       
       // Check if DAG mode
       $ticket = db_fetch_one($tenantDb, 
           "SELECT routing_mode, graph_instance_id FROM job_ticket WHERE id_job_ticket = ?", 
           [$idTicket]
       );
       
       if ($ticket['routing_mode'] === 'dag' && $ticket['graph_instance_id']) {
           // DAG mode - return empty tasks with flag
           json_success([
               'data' => [],
               'is_dag' => true,
               'graph_instance_id' => $ticket['graph_instance_id']
           ]);
           return;
       }
       
       // Linear mode - continue with existing logic
   ```

2. **Frontend:** Conditionally render Tasks vs Tokens
   ```javascript
   // In job_ticket.js
   function loadTasks(ticketId) {
       $.get('source/hatthasilpa_job_ticket.php', {
           action: 'task_list',
           id_job_ticket: ticketId
       }).done(function(response) {
           if (response.is_dag) {
               // Hide Tasks table, show Tokens link
               $('#tbl-job-tasks').closest('.section-divider').next().hide();
               showDAGTokensLink(response.graph_instance_id);
           } else {
               // Show Tasks table (existing behavior)
               renderTasksTable(response.data);
           }
       });
   }
   ```

3. **UI:** Add Tokens section for DAG mode
   ```html
   <!-- In hatthasilpa_job_ticket.php -->
   <?php if ($ticket['routing_mode'] === 'dag' && $ticket['graph_instance_id']): ?>
   <div class="alert alert-info">
       <strong>DAG Mode Job</strong>
       <p>This job uses graph-based routing. View tokens in <a href="?p=token_management&instance_id=<?= $ticket['graph_instance_id'] ?>">Token Management</a></p>
   </div>
   <?php endif; ?>
   ```

---

## 📝 Implementation Checklist

### **Quick Fix (Option 1):**
- [ ] Add routing mode check in `task_list` API
- [ ] Return `is_dag` flag in API response
- [ ] Update JavaScript to handle DAG mode
- [ ] Hide Tasks table for DAG jobs
- [ ] Add Tokens link/alert for DAG jobs
- [ ] Test with Linear job (Tasks visible)
- [ ] Test with DAG job (Tasks hidden, Tokens link shown)

### **Full Integration (Option 2):**
- [ ] All Quick Fix items
- [ ] Add token list API endpoint
- [ ] Create Tokens table component
- [ ] Add token actions (Start/Pause/Complete)
- [ ] Group tokens by node
- [ ] Show token status and progress
- [ ] Test end-to-end flow

---

## 🔄 Relationship to Phase 2B

**Phase 2B: Work Queue Integration** will create a dedicated Work Queue UI for DAG tokens. However, having token visibility in the job ticket detail view is still valuable because:

1. **Job ticket view** = Management perspective (see all tokens for a job)
2. **Work Queue view** = Operator perspective (see tokens at my node)

Both views serve different purposes and should coexist.

---

## ✅ Conclusion

**Recommendation:** Implement **Option 1 (Quick Fix)** before Phase 2B.

**Reasoning:**
- Low effort (2-3 hours)
- High impact (better UX)
- Doesn't block Phase 2B
- Sets foundation for future improvements

**Timeline:**
- Can be done in parallel with Phase 2A testing
- Or as first task before Phase 2B implementation
- Should be completed before Phase 2B goes live

---

**Last Updated:** November 15, 2025  
**Status:** Ready for Implementation  
**Next:** Decide on approach and implement


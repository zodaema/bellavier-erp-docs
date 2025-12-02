# Phase 2A: PWA Integration - Test Plan

**Created:** November 15, 2025  
**Status:** 🧪 Testing Phase  
**Phase:** 2A - PWA Integration (OEM / Classic Production)

---

## 📋 Test Overview

### **Test Scope**
- Phase 2A.1: Routing Mode Detection
- Phase 2A.2: DAG PWA UI (Token-Station View)
- Phase 2A.3: Auto-Routing After Complete
- Phase 2A.4: Backward Compatibility

### **Test Environment**
- **Backend:** `source/pwa_scan_api.php`, `source/dag_token_api.php`
- **Frontend:** `assets/javascripts/pwa_scan/pwa_scan.js`
- **Database:** Tenant database with DAG graph instances

---

## ✅ Test Checklist

### **2A.1: Routing Mode Detection**

#### **Test 1.1: DAG Token Scanning (TOKEN: prefix)**
- [ ] Scan QR code: `TOKEN:TOTE-001-BODY-1`
- [ ] Expected: API returns token data with `routing_mode='dag'`
- [ ] Expected: Response includes `type='dag_token'`
- [ ] Expected: Response includes `current_node`, `job`, `session` data
- [ ] **API Endpoint:** `GET /source/pwa_scan_api.php?action=lookup&code=TOKEN:TOTE-001-BODY-1`

#### **Test 1.2: DAG Token Scanning (DAG: prefix)**
- [ ] Scan QR code: `DAG:TOTE-001-BODY-1`
- [ ] Expected: Same as Test 1.1
- [ ] **API Endpoint:** `GET /source/pwa_scan_api.php?action=lookup&code=DAG:TOTE-001-BODY-1`

#### **Test 1.3: DAG Token Scanning (Token ID)**
- [ ] Scan QR code: `DAG:123` (where 123 is token ID)
- [ ] Expected: API returns token data for token ID 123
- [ ] **API Endpoint:** `GET /source/pwa_scan_api.php?action=lookup&code=DAG:123`

#### **Test 1.4: Linear Job Ticket Scanning**
- [ ] Scan QR code: `JT251016001` (Linear job ticket)
- [ ] Expected: API returns job ticket data with `routing_mode='linear'`
- [ ] Expected: Response includes `tasks` array (not tokens)
- [ ] Expected: No `dag` info in response
- [ ] **API Endpoint:** `GET /source/pwa_scan_api.php?action=lookup&code=JT251016001`

#### **Test 1.5: Mixed Mode Detection**
- [ ] Scan Linear job → Verify Linear UI shown
- [ ] Scan DAG token → Verify DAG token UI shown
- [ ] Scan DAG job ticket → Verify DAG job UI shown

---

### **2A.2: DAG PWA UI (Token-Station View)**

#### **Test 2.1: Token View Display**
- [ ] Scan DAG token (TOKEN: or DAG: prefix)
- [ ] Expected: Single token view displayed (not list)
- [ ] Expected: Shows token serial number
- [ ] Expected: Shows current node name and code
- [ ] Expected: Shows job name and ticket code
- [ ] Expected: Shows token status badge

#### **Test 2.2: Action Buttons (Ready Status)**
- [ ] Scan token with status='ready'
- [ ] Expected: Shows [Start Work] button
- [ ] Expected: No Pause/Complete buttons visible

#### **Test 2.3: Action Buttons (Active Status)**
- [ ] Scan token with active session
- [ ] Expected: Shows [Pause] and [Complete] buttons
- [ ] Expected: Work timer displayed and running
- [ ] Expected: Operator name displayed

#### **Test 2.4: Action Buttons (Waiting Status)**
- [ ] Scan token with status='waiting'
- [ ] Expected: Shows "รออยู่" message
- [ ] Expected: No action buttons (waiting for join condition)

#### **Test 2.5: Action Buttons (Completed Status)**
- [ ] Scan token with status='completed'
- [ ] Expected: Shows "เสร็จสิ้นแล้ว" message
- [ ] Expected: No action buttons

#### **Test 2.6: Work Timer**
- [ ] Start work on token
- [ ] Expected: Timer starts counting up
- [ ] Expected: Format: `HH:MM:SS`
- [ ] Expected: Timer updates every second
- [ ] Expected: Timer pauses when work paused
- [ ] Expected: Timer resumes when work resumed

---

### **2A.3: Auto-Routing After Complete**

#### **Test 3.1: Complete Normal Node**
- [ ] Complete token at normal operation node
- [ ] Expected: Token routed to next node automatically
- [ ] Expected: Success message shows "Token ถูกส่งไปยัง: {next_node}"
- [ ] Expected: Token status updated to new node
- [ ] Expected: Token view reloads with new node info

#### **Test 3.2: Complete Split Node**
- [ ] Complete token at split node
- [ ] Expected: Child tokens spawned automatically
- [ ] Expected: Parent token marked as completed
- [ ] Expected: Child tokens appear at their respective nodes
- [ ] Expected: Success message indicates split occurred

#### **Test 3.3: Complete Join Node**
- [ ] Complete token that arrives at join node
- [ ] Expected: Token enters join buffer
- [ ] Expected: If join condition satisfied → node activated
- [ ] Expected: If join condition NOT satisfied → token status='waiting'
- [ ] Expected: Success message shows join status

#### **Test 3.4: Complete QC Node (Pass)**
- [ ] Complete token at QC node with pass result
- [ ] Expected: Token routes to pass edge (normal flow)
- [ ] Expected: No rework count increment
- [ ] Expected: Success message shows routing to next node

#### **Test 3.5: Complete QC Node (Fail)**
- [ ] Complete token at QC node with fail result
- [ ] Expected: Token routes to rework edge
- [ ] Expected: Rework count incremented
- [ ] Expected: Token returns to previous node
- [ ] Expected: Success message shows rework routing

#### **Test 3.6: Complete End Node**
- [ ] Complete token at end node
- [ ] Expected: Token marked as completed
- [ ] Expected: No further routing
- [ ] Expected: Success message: "Token เสร็จสิ้นสมบูรณ์แล้ว"

#### **Test 3.7: Conditional Routing**
- [ ] Complete token at node with multiple conditional edges
- [ ] Expected: Conditions evaluated correctly
- [ ] Expected: Token routes to matching edge
- [ ] Expected: Success message shows routing result

#### **Test 3.8: WIP Limit Reached**
- [ ] Complete token when next node has WIP limit reached
- [ ] Expected: Token moved to next node but status='waiting'
- [ ] Expected: Success message shows "กำลังรอ: WIP limit reached"
- [ ] Expected: Queue position displayed

---

### **2A.4: Backward Compatibility**

#### **Test 4.1: Linear Mode Still Works**
- [ ] Scan Linear job ticket (JT*)
- [ ] Expected: Shows Linear UI (task dropdowns)
- [ ] Expected: Quick/Detail mode works
- [ ] Expected: WIP logs created (not token events)
- [ ] Expected: No DAG token view shown

#### **Test 4.2: Linear Mode Actions**
- [ ] Start work on Linear task
- [ ] Expected: WIP log created in `atelier_wip_log`
- [ ] Expected: Operator session updated
- [ ] Expected: Task status updated
- [ ] Expected: No token events created

#### **Test 4.3: Mixed Linear/DAG Jobs**
- [ ] Have both Linear and DAG jobs in system
- [ ] Scan Linear job → Verify Linear UI
- [ ] Scan DAG token → Verify DAG token UI
- [ ] Expected: No conflicts or errors

#### **Test 4.4: Mode Detection Accuracy**
- [ ] Verify `routing_mode='linear'` → Linear mode
- [ ] Verify `routing_mode='dag'` + `graph_instance_id IS NULL` → Linear mode (fallback)
- [ ] Verify `routing_mode='dag'` + `graph_instance_id IS NOT NULL` → DAG mode

---

## 🔧 Manual Testing Steps

### **Prerequisites**
1. Create test DAG graph with:
   - Start node
   - Operation nodes
   - Split node
   - Join node
   - QC node
   - End node
2. Create test job ticket with `routing_mode='dag'` and `graph_instance_id`
3. Spawn tokens for testing
4. Create test Linear job ticket for comparison

### **Test Procedure**

#### **Step 1: Test Token Scanning**
```bash
# Test DAG token scan
curl "http://localhost/bellavier-group-erp/source/pwa_scan_api.php?action=lookup&code=TOKEN:TOTE-001-BODY-1"

# Test Linear job scan
curl "http://localhost/bellavier-group-erp/source/pwa_scan_api.php?action=lookup&code=JT251016001"
```

#### **Step 2: Test PWA UI**
1. Open PWA scan page in browser
2. Scan DAG token QR code
3. Verify token view displayed
4. Test Start/Pause/Complete actions
5. Verify timer works

#### **Step 3: Test Auto-Routing**
1. Complete token at different node types
2. Verify routing results
3. Check token status after routing
4. Verify child tokens spawned (for split nodes)

#### **Step 4: Test Backward Compatibility**
1. Scan Linear job ticket
2. Verify Linear UI shown
3. Perform work actions
4. Verify WIP logs created (not token events)

---

## 🐛 Known Issues & Edge Cases

### **Edge Case 1: Token Not Found**
- **Scenario:** Scan invalid token serial
- **Expected:** Error message "Entity not found"
- **Status:** ✅ Handled

### **Edge Case 2: Network Retry**
- **Scenario:** Network lag causes duplicate Complete action
- **Expected:** Idempotency prevents duplicate routing
- **Status:** ⚠️ Needs TokenExecutionService (Phase 2A.3 - Future)

### **Edge Case 3: Concurrent Operators**
- **Scenario:** Two operators complete same token simultaneously
- **Expected:** Row-level lock prevents race condition
- **Status:** ⚠️ Needs TokenExecutionService (Phase 2A.3 - Future)

### **Edge Case 4: Token at End Node**
- **Scenario:** Complete token already at end node
- **Expected:** Token marked as completed, no routing
- **Status:** ✅ Handled

### **Edge Case 5: Invalid Node Type**
- **Scenario:** Token at node with invalid node_type
- **Expected:** Error logged, graceful failure
- **Status:** ✅ Handled

---

## 📊 Test Results Template

### **Test Session: [Date]**

| Test ID | Description | Status | Notes |
|---------|-------------|--------|-------|
| 1.1 | DAG Token Scan (TOKEN:) | ⬜ Pass / ⬜ Fail | |
| 1.2 | DAG Token Scan (DAG:) | ⬜ Pass / ⬜ Fail | |
| 1.3 | DAG Token Scan (ID) | ⬜ Pass / ⬜ Fail | |
| 1.4 | Linear Job Scan | ⬜ Pass / ⬜ Fail | |
| 1.5 | Mixed Mode Detection | ⬜ Pass / ⬜ Fail | |
| 2.1 | Token View Display | ⬜ Pass / ⬜ Fail | |
| 2.2 | Action Buttons (Ready) | ⬜ Pass / ⬜ Fail | |
| 2.3 | Action Buttons (Active) | ⬜ Pass / ⬜ Fail | |
| 2.4 | Action Buttons (Waiting) | ⬜ Pass / ⬜ Fail | |
| 2.5 | Action Buttons (Completed) | ⬜ Pass / ⬜ Fail | |
| 2.6 | Work Timer | ⬜ Pass / ⬜ Fail | |
| 3.1 | Complete Normal Node | ⬜ Pass / ⬜ Fail | |
| 3.2 | Complete Split Node | ⬜ Pass / ⬜ Fail | |
| 3.3 | Complete Join Node | ⬜ Pass / ⬜ Fail | |
| 3.4 | Complete QC Node (Pass) | ⬜ Pass / ⬜ Fail | |
| 3.5 | Complete QC Node (Fail) | ⬜ Pass / ⬜ Fail | |
| 3.6 | Complete End Node | ⬜ Pass / ⬜ Fail | |
| 3.7 | Conditional Routing | ⬜ Pass / ⬜ Fail | |
| 3.8 | WIP Limit Reached | ⬜ Pass / ⬜ Fail | |
| 4.1 | Linear Mode Still Works | ⬜ Pass / ⬜ Fail | |
| 4.2 | Linear Mode Actions | ⬜ Pass / ⬜ Fail | |
| 4.3 | Mixed Linear/DAG Jobs | ⬜ Pass / ⬜ Fail | |
| 4.4 | Mode Detection Accuracy | ⬜ Pass / ⬜ Fail | |

**Overall Status:** ⬜ Pass / ⬜ Fail  
**Issues Found:** [List any issues]  
**Next Steps:** [Actions needed]

---

## 🔍 Debugging Tips

### **Check API Response**
```javascript
// In browser console
fetch('/bellavier-group-erp/source/pwa_scan_api.php?action=lookup&code=TOKEN:TOTE-001-BODY-1')
  .then(r => r.json())
  .then(console.log);
```

### **Check Token Status**
```javascript
// In browser console
fetch('/bellavier-group-erp/source/dag_token_api.php?action=token_status&token_id=123')
  .then(r => r.json())
  .then(console.log);
```

### **Check Database**
```sql
-- Check token status
SELECT * FROM flow_token WHERE id_token = 123;

-- Check routing result
SELECT * FROM token_event WHERE token_id = 123 ORDER BY event_time DESC LIMIT 5;

-- Check work session
SELECT * FROM token_work_session WHERE id_token = 123;
```

### **Common Issues**

1. **Token not found**
   - Check serial number format
   - Verify token exists in database
   - Check tenant database context

2. **Routing not working**
   - Check node has outgoing edges
   - Verify routing service loaded
   - Check transaction committed

3. **UI not updating**
   - Check browser console for errors
   - Verify API response format
   - Check token status reload

---

## 📝 Test Notes

### **Test Environment Setup**
- Database: `bgerp_t_maison_atelier`
- Test User: admin / iydgtv
- Test Graph: [Graph ID]
- Test Tokens: [List token serials]

### **Test Data**
- Token Serial: `TOTE-001-BODY-1`
- Token Serial: `TOTE-001-STRAP-1`
- Job Ticket: `JT251016001` (Linear)
- Job Ticket: `JT251016002` (DAG)

---

**Last Updated:** November 15, 2025  
**Test Status:** Ready for Testing  
**Next:** Execute manual tests and document results


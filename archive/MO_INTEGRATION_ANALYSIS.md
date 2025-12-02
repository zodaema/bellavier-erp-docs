# 🔍 MO Integration Analysis - November 4, 2025

## 📊 Current Situation:

### Database Check:
```sql
SELECT id_job_ticket, ticket_code, id_mo, routing_mode 
FROM hatthasilpa_job_ticket 
ORDER BY id_job_ticket DESC LIMIT 10;

Results:
id_job_ticket | ticket_code                  | id_mo | routing_mode
172          | JT-DAG-TOKEN-251104-200709   | NULL  | dag        ⚠️
169          | JT-DAG-DEMO                  | NULL  | dag        ⚠️
168          | JT-LINEAR-DEMO               | NULL  | linear     ⚠️
167          | JT-DEMO-FRESH                | NULL  | dag        ⚠️
142          | JOB-MO2025100001             | 2     | linear     ✅
141          | JOB-MO2025100002             | 3     | linear     ✅
```

### 🚨 **CRITICAL FINDING:**

**Demo/Test Jobs:**
- id_mo = NULL ❌
- สร้างโดยตรง (ไม่ผ่าน MO)
- ใช้สำหรับทดสอบเท่านั้น!

**Production Jobs:**
- id_mo = 2, 3 ✅
- สร้างจาก MO
- Flow ถูกต้อง!

---

## 🔄 Correct Flow:

### **Production Flow (ที่ถูกต้อง):**
```
Manufacturing Order (MO)
    ↓ (Create Job Ticket)
Hatthasilpa Job Ticket (id_mo = MO.id_mo)
    ↓ (Select routing_mode)
    ├─ linear → hatthasilpa_job_task
    └─ dag → job_graph_instance → Tokens
```

### **Demo Flow (ตอนนี้ใช้):**
```
⚠️ Job Ticket (standalone, id_mo = NULL)
    ↓ (Direct to DAG)
Graph Instance → Tokens

Problem: ข้าม MO!
Use Case: Testing only!
```

---

## 📋 Integration Points:

### 1. **Job Ticket Creation (source/hatthasilpa_job_ticket.php)**

**Code:**
```php
$payload = [
    'id_mo' => (int)($_POST['id_mo'] ?? 0) ?: null,  // ✅ รองรับ MO!
    // ... other fields
];

// Validate MO status
if ($payload['id_mo']) {
    $moData = db_fetch_one($db, "SELECT status FROM mo WHERE id_mo=?", [$payload['id_mo']]);
    // ✅ Check MO status before creating ticket
}

INSERT INTO hatthasilpa_job_ticket (..., id_mo, ...) VALUES (...);
```

**Status:** ✅ Integration exists!

---

### 2. **DAG Token Spawn (source/dag_token_api.php)**

**Code:**
```php
// Get ticket (includes id_mo)
$ticket = db_fetch_one($db, "SELECT * FROM hatthasilpa_job_ticket WHERE id_job_ticket=?", [$ticketId]);

// Create graph instance
INSERT INTO job_graph_instance (id_graph, id_job_ticket, ...) VALUES (...);

// Spawn tokens
$tokenService->spawnTokens($instanceId, $qty, $mode, $serials);
```

**Issue:** ⚠️ ไม่ได้ display MO info ใน UI!
**Status:** Backend ✅ เชื่อมแล้ว, Frontend ❌ ยังไม่แสดง

---

### 3. **Work Queue (source/dag_token_api.php)**

**Query:**
```php
SELECT 
    t.id_token, t.serial_number, t.status,
    jt.ticket_code, jt.job_name,  // ✅ มี job info
    jt.id_mo,                      // ⚠️ Query แต่ไม่ได้ส่งไป UI!
    n.node_name, n.node_code
FROM flow_token t
JOIN job_graph_instance jgi ON ...
JOIN hatthasilpa_job_ticket jt ON ...  // ✅ Join กับ ticket
JOIN routing_node n ON ...
```

**Issue:** ⚠️ Query id_mo แต่ไม่ส่งไป frontend!

---

### 4. **Manager Assignment (source/assignment_api.php)**

**Query:**
```php
SELECT 
    t.id_token, t.serial_number, t.status,
    jt.ticket_code, jt.job_name,  // ✅ มี job info
    // ⚠️ ไม่ได้ query id_mo!
    n.node_name
FROM flow_token t
JOIN ...
```

**Issue:** ❌ ไม่ได้ query MO ด้วยซ้ำ!

---

## 🎯 Root Cause Analysis:

### **Why Demo Jobs Have id_mo = NULL?**

**Demo Script (clean_and_reseed_dag.php):**
```php
INSERT INTO hatthasilpa_job_ticket 
(ticket_code, job_name, target_qty, process_mode, status, routing_mode)
VALUES (?, ?, ?, ?, ?, 'dag')
// ❌ ไม่ได้ส่ง id_mo!
```

**Reason:** 
- Demo scripts สร้าง Job Ticket โดยตรง
- ไม่ผ่าน MO (เพื่อความรวดเร็วในการทดสอบ)

**Impact:**
- ✅ OK for testing
- ❌ NOT OK for production

---

## ✅ What Works (Production Ready):

1. **Database Schema:**
   - ✅ hatthasilpa_job_ticket.id_mo exists (FK to MO)
   - ✅ Can be NULL (for standalone tickets)
   - ✅ Can reference MO (for production)

2. **Job Ticket Creation:**
   - ✅ Accepts id_mo parameter
   - ✅ Validates MO status
   - ✅ Syncs with MO workflow

3. **Backend Flow:**
   - ✅ MO → Job Ticket → Graph → Tokens
   - ✅ All FK relationships exist

---

## ⚠️ What's Missing (UI Display):

1. **Work Queue:**
   - ❌ ไม่แสดง MO code/name
   - ❌ Operator ไม่รู้ว่า token มาจาก MO ไหน

2. **Manager Assignment:**
   - ❌ ไม่แสดง MO info
   - ❌ Manager assign ได้แต่ไม่รู้ source

3. **Token Details:**
   - ❌ ไม่มีข้อมูล MO ใน token view

---

## 🔧 Recommended Fixes:

### Fix 1: Work Queue - Show MO Info
```php
// In dag_token_api.php -> handleGetWorkQueue()
SELECT 
    t.id_token, t.serial_number, t.status,
    jt.ticket_code, jt.job_name, jt.id_mo,  // ✅ Already queried
    mo.mo_code, mo.id_product AS mo_product,  // ⭐ ADD MO info
    n.node_name, n.node_code
FROM flow_token t
JOIN job_graph_instance jgi ON ...
JOIN hatthasilpa_job_ticket jt ON ...
LEFT JOIN mo ON mo.id_mo = jt.id_mo  // ⭐ ADD JOIN
JOIN routing_node n ON ...
```

### Fix 2: Manager Assignment - Show MO Info
```php
// In assignment_api.php -> handleGetUnassignedTokens()
SELECT 
    t.id_token, t.serial_number, t.status,
    jt.ticket_code, jt.job_name, jt.id_mo,  // ⭐ ADD
    mo.mo_code,  // ⭐ ADD
    n.node_name
FROM flow_token t
JOIN ...
LEFT JOIN mo ON mo.id_mo = jt.id_mo  // ⭐ ADD JOIN
```

### Fix 3: UI - Display MO Badge
```javascript
// In manager/assignment.js
<div class="text-muted small">
    <i class="bi bi-briefcase"></i> ${token.ticket_code}
    ${token.mo_code ? '<br><i class="bi bi-box"></i> MO: ' + token.mo_code : ''}
</div>
```

---

## 🎯 Impact Assessment:

### Current State:
- **Backend:** ✅ 80% Ready (FK exists, validation exists)
- **Frontend:** ❌ 20% Ready (no MO display)

### After Fix:
- **Backend:** ✅ 100% Complete
- **Frontend:** ✅ 100% Complete
- **Traceability:** ✅ Full (Token → Job Ticket → MO)

### Time to Fix:
- **Estimated:** 30-45 minutes
- **Risk:** Low (additive change)
- **Value:** High (production visibility)

---

## 📋 Conclusion:

### **ตอบคำถาม:**

**"ได้ใช้งานร่วมกันกับ MO อย่างดีแล้วหรือยัง?"**

**คำตอบ: ใช้ได้ แต่ไม่ดี! (80%)**

**✅ ทำงานร่วมกันได้:**
- Database มี FK (id_mo)
- สร้าง Job Ticket จาก MO ได้
- Validation MO status ทำงาน

**❌ แต่ไม่ดีเท่าที่ควร:**
- UI ไม่แสดง MO info
- Operator/Manager ไม่รู้ว่า token มาจาก MO ไหน
- Demo data ไม่มี id_mo (เพราะสร้างเพื่อทดสอบ)

**🔧 แก้ได้ใน:** 30-45 นาที

---

## 🚀 Recommendation:

**Option 1: Fix Now (30-45 min)**
- เพิ่ม MO column ใน Work Queue
- เพิ่ม MO info ใน Manager Assignment
- แสดง MO badge ใน token cards

**Option 2: Fix Later**
- ระบบใช้งานได้ แต่ไม่มี MO info
- เหมาะสำหรับ demo/testing
- ควร fix ก่อน production deployment

**Preferred:** Option 1 (ควรแก้เลย!)

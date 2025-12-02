# 👷 Operator Journey - Work Queue System

**Created:** November 2, 2025  
**Purpose:** Document real operator workflow with work queue  
**Based On:** User's journey analysis and workshop feedback

---

## 🎯 **Core Principle**

> **"ช่างไม่ต้องเข้าใจ DAG - แค่รู้ว่าชิ้นไหนพร้อมทำ ชิ้นไหนรอ"**

---

## 📋 **Complete Operator Journey (1 Day)**

### **0) เข้าแอป & เตรียมพร้อม**

**08:00 - Login PWA**
```
1. เปิดแอป → Login
2. ระบบ sync งานค้าง
3. เห็น "My Tasks" (งานที่มี token พร้อมทำ)
```

**Screen:**
```
┌─────────────────────────────────────┐
│ My Tasks (Today)                    │
├─────────────────────────────────────┤
│ SEW BODY                            │
│ 5 pieces • 2 ready • 2 paused • 1 done
│ [View Queue →]                      │
├─────────────────────────────────────┤
│ EDGE                                │
│ 3 pieces • 3 ready • 0 in progress  │
│ [View Queue →]                      │
└─────────────────────────────────────┘
```

---

### **1) เลือกงานที่จะทำ**

**08:05 - Open SEW BODY Queue**
```
4. แตะ "SEW BODY" → เห็น Work Queue
5. เห็นรายการชิ้นงาน:
   - Ready (พร้อมทำ)
   - Paused (ค้างไว้)
   - In Progress (กำลังทำ)
   - Completed (เสร็จแล้ว)
```

**Screen:**
```
┌─────────────────────────────────────┐
│ ← My Tasks                          │
├─────────────────────────────────────┤
│ SEW BODY Station                    │
│ Progress: 1/5 completed (20%)       │
├─────────────────────────────────────┤
│ [My Work 3] [Available 2] [All 5]   │
├─────────────────────────────────────┤
│ ⏸ TOTE-002 (Paused - You)           │
│ Work time: 15 min • Paused: 08:45   │
│ [Resume] [Complete]                 │
├─────────────────────────────────────┤
│ ☐ TOTE-001 (Ready)                  │
│ [Start Work]                        │
├─────────────────────────────────────┤
│ ☐ TOTE-005 (Ready)                  │
│ [Start Work]                        │
├─────────────────────────────────────┤
│ ✓ TOTE-003 (Completed - You)        │
│ Duration: 35 min • Done: 07:45      │
└─────────────────────────────────────┘
```

---

### **2) เริ่มทำงานชิ้นใหม่**

**08:10 - Start TOTE-001**
```
6. แตะ "Start Work" ที่ TOTE-001
7. ระบบสร้าง work session
8. Timer เริ่มนับ
```

**Screen:**
```
┌─────────────────────────────────────┐
│ ⚙️ TOTE-001 (In Progress - You)     │
│ Started: 08:10 (0 min ago)          │
│ [Pause] [Complete]                  │
└─────────────────────────────────────┘
```

**Backend:**
```sql
-- Create work session
INSERT INTO token_work_session (
    id_token, operator_user_id, status, started_at
) VALUES (1, 42, 'active', '2025-11-02 08:10:00');

-- Update token
UPDATE flow_token SET status = 'active' WHERE id_token = 1;

-- Create event
INSERT INTO token_event (
    id_token, event_type, operator_user_id, event_time
) VALUES (1, 'start', 42, '2025-11-02 08:10:00');
```

---

### **3) พักครึ่งทาง**

**08:25 - Pause TOTE-001 (ยังไม่เสร็จ)**
```
9. แตะ "Pause"
10. ระบบบันทึกเวลาพัก
11. Token status: active → paused
```

**Screen:**
```
┌─────────────────────────────────────┐
│ ⏸ TOTE-001 (Paused - You)           │
│ Work time: 15 min • Paused: 08:25   │
│ [Resume] [Complete]                 │
└─────────────────────────────────────┘
```

**Backend:**
```sql
-- Update session
UPDATE token_work_session 
SET status = 'paused', 
    paused_at = '2025-11-02 08:25:00'
WHERE id_token = 1 AND status = 'active';

-- Update token
UPDATE flow_token SET status = 'paused' WHERE id_token = 1;

-- Create event
INSERT INTO token_event (
    id_token, event_type, event_time, notes
) VALUES (1, 'pause', '2025-11-02 08:25:00', 'Break');
```

---

### **4) สลับไปทำชิ้นอื่น**

**08:30 - Start TOTE-005 (ทำต่อชิ้นอื่น)**
```
12. เลือก TOTE-005 → Start
13. TOTE-001 ยัง paused อยู่
14. ทำงาน TOTE-005...
```

**08:45 - Complete TOTE-005**
```
15. แตะ "Complete"
16. ระบบคำนวณเวลา: 08:30-08:45 = 15 min
17. Token routes → SEW_STRAP
```

**Backend:**
```sql
-- Complete session
UPDATE token_work_session 
SET status = 'completed',
    completed_at = '2025-11-02 08:45:00'
WHERE id_token = 5;

-- Route token to next node
UPDATE flow_token 
SET current_node_id = 11,  -- SEW_STRAP
    status = 'active'
WHERE id_token = 5;
```

---

### **5) กลับมาทำชิ้นเดิมต่อ**

**10:00 - Resume TOTE-001**
```
18. กลับมา SEW BODY queue
19. เห็น TOTE-001 paused (work time: 15 min)
20. แตะ "Resume"
21. ทำต่อจากที่ค้างไว้
```

**10:20 - Complete TOTE-001**
```
22. แตะ "Complete"
23. ระบบคำนวณเวลา:
    - Work: 08:10-08:25 (15 min) + 10:00-10:20 (20 min)
    - Pause: 08:25-10:00 (excluded)
    - Total work: 35 min
24. Token routes → SEW_STRAP
```

**Backend:**
```sql
-- Calculate work time
SELECT 
    TIMESTAMPDIFF(MINUTE, started_at, completed_at) as total_minutes,
    total_pause_minutes,
    (TIMESTAMPDIFF(MINUTE, started_at, completed_at) - total_pause_minutes) as work_minutes
FROM token_work_session
WHERE id_token = 1;

-- Result: 130 min total - 95 min pause = 35 min work
```

---

### **6) งานต้อง QC**

**12:00 - QC Task**
```
25. เสร็จ SEW_BODY → เข้า QC station
26. QC Inspector scans TOTE-001
27. ตรวจสอบ...
28. Pass → Route to ASSEMBLY
    Fail → Route to REWORK_SEW
```

---

### **7) งานประกอบ (Assembly)**

**14:00 - Assembly Task with Component Check**
```
29. เปิด ASSEMBLY queue
30. เห็น:
    🔒 TOTE-001 (Blocked)
        Waiting for: STRAP-001
        
    ✅ TOTE-003 (Ready - All components available!)
        Components:
        - BODY-003 ✓
        - STRAP-003 ✓
        
31. เลือก TOTE-003 → Start
32. System shows component list (auto-check)
33. Assemble...
34. Complete → ระบบผูก genealogy
```

**Backend:**
```sql
-- Check if all required tokens arrived at join node
SELECT 
    rn.node_name,
    COUNT(DISTINCT t.id_token) as arrived_count,
    (
        SELECT COUNT(*) 
        FROM routing_edge 
        WHERE to_node_id = 15  -- ASSEMBLY node
    ) as required_count
FROM flow_token t
JOIN routing_node rn ON rn.id_node = t.current_node_id
WHERE t.serial_number LIKE 'TOTE-003%'  -- All components of TOTE-003
  AND t.current_node_id = 15
  AND t.status = 'active';

-- If arrived_count = required_count → Ready
-- Else → Blocked
```

---

### **8) โหมดออฟไลน์**

**15:00 - Network Lost**
```
35. แถบแสดง: "⚠️ Offline - จะซิงค์เมื่อมีเน็ต"
36. ช่างทำงานต่อได้ตามปกติ
37. กด Start/Pause/Complete → เก็บใน Local Queue
```

**15:30 - Network Restored**
```
38. ระบบซิงค์อัตโนมัติ
39. ใช้ idempotency_key กันซ้ำ
40. แสดง "✓ Synced 3 events"
```

---

### **9) ปิดกะ**

**17:00 - End Shift**
```
41. เปิด "My Summary"
42. เห็น:
    - วันนี้ทำ: 8 pieces
    - Total work time: 280 min (4.6 hours)
    - Avg per piece: 35 min
    - Fastest: TOTE-005 (15 min)
    - Slowest: TOTE-007 (75 min - complex design)
43. Logout
```

---

## 🎨 **UI States Reference**

### **Token Status Visual Guide:**

| Status | Icon | Color | Meaning | Actions |
|--------|------|-------|---------|---------|
| **Ready** | ☐ | Gray | Not started, ready to begin | [Start] |
| **Active** | ⚙️ | Blue | Currently working | [Pause] [Complete] |
| **Paused** | ⏸ | Yellow | Work interrupted, can resume | [Resume] [Complete] |
| **Completed** | ✓ | Green | Finished, routed to next node | (none) |
| **Blocked** | 🔒 | Red | Waiting for components | (none) |

### **Micro-Copy (UI Text):**

```javascript
const messages = {
    ready: "พร้อมเริ่ม — dependency ครบแล้ว",
    blocked: "ยังเริ่มไม่ได้ — รอ: STEP-2, STEP-3",
    paused: "พักไว้ — กลับมาทำต่อได้เสมอ",
    active: "กำลังทำ — จับเวลาอยู่",
    completed: "เสร็จแล้ว — ใช้เวลา {duration} นาที",
    offline: "ออฟไลน์แล้ว • กดได้ตามปกติ ระบบจะซิงค์ให้เอง",
    syncing: "กำลังซิงค์... {count} events",
    synced: "✓ ซิงค์เสร็จแล้ว"
};
```

---

## 📊 **Real Example: 1 Day Timeline**

### **ช่าง A - SEW BODY Station (Atelier Line)**

```
Time    | Token   | Action      | Status        | Notes
--------|---------|-------------|---------------|------------------
08:00   | Login   | -           | -             | See 5 pieces in queue
08:10   | TOTE-001| Start       | Active        | Timer starts
08:25   | TOTE-001| Pause       | Paused (15m)  | Go get thread
08:30   | TOTE-005| Start       | Active        | Work on different piece
08:45   | TOTE-005| Complete    | ✓ (15m)       | Routes to SEW_STRAP
09:00   | TOTE-004| Start       | Active        |
09:40   | TOTE-004| Complete    | ✓ (40m)       | Routes to SEW_STRAP
10:00   | TOTE-001| Resume      | Active (15m)  | Continue from pause
10:20   | TOTE-001| Complete    | ✓ (35m total) | Work: 15+20, Pause excluded
12:00   | Lunch   | -           | -             | All auto-paused
13:00   | TOTE-002| Resume      | Active        | From yesterday
14:15   | TOTE-002| Complete    | ✓ (75m)       | Complex stitching
14:20   | TOTE-006| Start       | Active        |
15:00   | Network | Offline     | -             | Internet down
15:15   | TOTE-006| Complete    | ✓ (55m)       | Saved to queue
15:30   | Network | Online      | -             | Auto-sync ✓
15:35   | TOTE-007| Start       | Active        |
17:00   | End     | -           | -             | Summary: 5 pieces, 240 min
```

**Summary:**
- Pieces completed: 5 (TOTE-001, 002, 004, 005, 006)
- Total work time: 240 minutes (4 hours)
- Average: 48 min/piece
- Fastest: TOTE-005 (15 min)
- Slowest: TOTE-002 (75 min - complex)

**Customer Value:**
```
Customer scans TOTE-002 serial:
✓ "Handcrafted by Artisan Somporn"
✓ "SEW BODY: 75 minutes of dedicated work"
✓ "Completed: Nov 2, 2025 at 14:15"
→ Justifies luxury price!
```

---

## 🎯 **Why This Works**

### **For Atelier Line (Handcraft):**

**Problem:**
- Batch completion → lost per-piece time
- Customer scans serial → sees average time (not real)
- Loses craftsmanship story value

**Solution:**
- Work queue → each piece tracked individually
- Pause/resume → accurate work time per piece
- Customer sees real time spent

**Example:**
```
TOTE-002: 75 min (complex hand-stitching)
TOTE-005: 15 min (simple design)

Without work queue:
Both show: 45 min average ❌

With work queue:
TOTE-002: 75 min ✓ (shows difficulty)
TOTE-005: 15 min ✓ (shows speed)
```

---

### **For Batch OEM Line:**

**Problem:**
- Same as Atelier, but less critical

**Solution:**
- Same work queue UI
- But can use "lot serial" (1 token for 50 pieces)
- Or individual serials (if traceability needed)

**Flexibility:**
```
Standard product:
LOT-2025-A123 (1 token, 50 pcs)
→ Complete once → all 50 done

Premium product:
WALLET-001 to WALLET-050 (50 tokens)
→ Each tracked individually
```

---

## 💡 **Operator Benefits**

1. **Visual Work Queue** ✅
   - เห็นชิ้นงานทั้งหมด
   - รู้ว่าเหลืออะไร
   - เลือกทำก่อนหลังได้

2. **Pause/Resume** ✅
   - ไม่ต้องทำให้เสร็จทีเดียว
   - พักได้ กลับมาทำต่อได้
   - ไม่สับสน

3. **Flexible Switching** ✅
   - สลับไปทำชิ้นอื่นก่อนได้
   - แต่ละชิ้นติดตามแยก
   - Progress ชัดเจน

4. **Accurate Time** ✅
   - ระบบจับเวลาแม่นยำ
   - ไม่นับเวลาพัก
   - Per-piece duration

5. **Multi-Operator** ✅
   - ช่าง A ทำ TOTE-001, 002
   - ช่าง B ทำ TOTE-003, 004
   - ไม่ชนกัน

---

## 🎓 **Training Material (1 page)**

### **Work Queue คืออะไร?**

```
Work Queue = รายการงานที่ต้องทำ

เหมือนกับ To-Do List แต่:
- แต่ละชิ้นมี Serial Number
- กดเริ่ม → จับเวลา
- พัก → เวลาหยุด
- ทำต่อ → เวลาเริ่ม
- เสร็จ → บันทึกเวลาที่ใช้

ทำไมต้องมี?
→ เพื่อบันทึกว่าแต่ละชิ้นใช้เวลาเท่าไร
→ ลูกค้าสแกนเห็น "ใช้เวลาทำ 35 นาที"
→ เพิ่มมูลค่าสินค้า Handcraft
```

### **วิธีใช้ (3 ขั้นตอน):**

```
1. เปิด Task → เห็นรายการชิ้นงาน
2. เลือกชิ้น → กด Start
3. เสร็จ → กด Complete
   (พักได้ → กด Pause)
```

### **ข้อควรทราบ:**

```
✅ ทำ:
- เลือกชิ้นที่ Ready
- Pause ถ้าต้องพัก
- Resume เมื่อกลับมา
- Complete เมื่อเสร็จ

❌ ไม่ควร:
- ทิ้งงาน Paused ทิ้งไว้นาน (>1 วัน)
- Start หลายชิ้นพร้อมกัน (ระบบบังคับให้ pause ชิ้นเก่า)
- Complete โดยไม่ตรวจสอบคุณภาพ
```

---

## 🔧 **Technical Notes**

### **Performance Optimization:**

```sql
-- Index for fast queue loading
CREATE INDEX idx_token_queue 
ON flow_token (current_node_id, status, id_instance);

CREATE INDEX idx_session_active 
ON token_work_session (id_token, status);

-- Query optimization
SELECT t.*, s.started_at, s.paused_at
FROM flow_token t
LEFT JOIN token_work_session s ON s.id_token = t.id_token AND s.status IN ('active','paused')
WHERE t.current_node_id = ? 
  AND t.id_instance = ?
  AND t.status IN ('active','paused','ready')
ORDER BY 
    CASE WHEN s.operator_user_id = ? THEN 0 ELSE 1 END,  -- My work first
    t.serial_number;
```

### **Real-Time Updates:**

```javascript
// Poll queue every 30 seconds (when active)
setInterval(() => {
    if (document.visibilityState === 'visible' && pwaState.currentNode) {
        refreshWorkQueue(pwaState.currentNode);
    }
}, 30000);

// Or use WebSocket for instant updates (future)
socket.on('token_completed', (data) => {
    if (data.node_id === pwaState.currentNode) {
        updateQueueDisplay(data);
    }
});
```

---

## 📈 **Success Metrics**

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Time accuracy | 95%+ | Compare work_minutes vs actual |
| Operator satisfaction | 4/5+ | Survey after 1 month |
| Pause/resume usage | 30%+ sessions | Count sessions with pause |
| Multi-piece flexibility | 50%+ operators | Operators working on >1 piece/day |
| Customer engagement | 20%+ scan serials | Serial scan analytics |

---

**Last Updated:** November 2, 2025  
**Status:** Approved design, ready for implementation  
**Next:** Migration 0009 + Work Queue APIs


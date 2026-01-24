# Task 21.6 – Canonical Timeline Debugger (Dev-Only Tool)

**Status:** PLANNING  
**Date:** 2025-01-XX  
**Category:** SuperDAG / Time Engine / Dev Tools  
**Depends on:**  
- Task 21.1–21.5 (Node Behavior Engine + Canonical Events + TimeEventReader)  
- `time_model.md` (Canonical Time Model)  
- `SuperDAG_Execution_Model.md`  
- `task21_3_results.md`, `task21_5_results.md`  

---

## 1. Objective

สร้าง Debug Tool แบบ Dev-Only เพื่อให้สามารถ:

1. แสดง canonical events (`token_event`) ของ token/node ได้ครบถ้วน  
2. แสดง timeline ที่ถูกสร้างจาก `TimeEventReader`  
3. เปรียบเทียบ canonical timeline กับ legacy time fields ใน `flow_token`  
4. ช่วยตรวจสอบความถูกต้องของ canonical-time pipeline (Task 21.1–21.5)

> เป้าหมายของ Task 21.6 = “สร้างกล้องวงจรปิดของ Token Lifecycle”  
> ใช้เพื่อดูว่าเวลาที่คำนวณจาก canonical events มาตรงกับพฤติกรรมจริงหรือไม่

---

## 2. Scope

### 2.1 In-Scope

1. **สร้างหน้า Dev-Only Debug View**
   - URL เช่น: `/dev/debug/token-timeline.php`
   - Input parameters:
     - `token_id` (必須)
     - optional: `node_id`, `job_ticket_id`
   - Layout:
     1. Token Info (flow_token)
     2. Raw Events (`token_event`)
     3. Parsed Canonical Timeline (จาก TimeEventReader)
     4. Summary Comparison (canonical vs legacy)

2. **Backend Helper Script**
   - ไฟล์ PHP เพื่อ:
     - Query token_event
     - เรียก TimeEventReader
     - ดึงข้อมูล flow_token
     - Render HTML แบบเรียบง่าย (dev only)

3. **Highlight inconsistencies**
   - หาก canonical duration ไม่เท่ากับ legacy → highlight สีแดง
   - หาก canonical start/complete missing → highlight สีเหลือง
   - หาก event sequence ผิด (เช่น pause โดยไม่มี start) → แสดงเป็น Warning Panel

4. **Dev-only Protection**
   - ไฟล์ต้องมี guard เช่น:
     ```php
     if (!isDevEnvironment()) {
         http_response_code(403);
         exit('Forbidden');
     }
     ```
   - ใช้ logic เดียวกับ dev tools ปัจจุบันของระบบ

### 2.2 Out-of-Scope
- ไม่มีการแก้ไข business logic  
- ไม่เขียนข้อมูลลงฐาน  
- ไม่ทำ UI สวยงามระดับ production  
- ไม่ integrate กับ PWA (desktop dev-only page เท่านั้น)

---

## 3. Design

### 3.1 Debug Page Structure

```
+---------------------------------------------------+
| Token Timeline Debugger (Dev Only)                |
+---------------------------------------------------+
| Section 1: Token Info (flow_token)                |
| - token_id:                                       |
| - job_ticket_id:                                  |
| - current_node_id:                                |
| - start_at (legacy)                               |
| - completed_at (legacy)                           |
| - actual_duration_ms (legacy)                     |
+---------------------------------------------------+
| Section 2: Canonical Events                       |
| - event_type                                      |
| - canonical_type                                  |
| - event_time                                      |
| - payload                                         |
+---------------------------------------------------+
| Section 3: Canonical Timeline                     |
| - start_time                                      |
| - complete_time                                   |
| - duration_ms                                     |
| - sessions (list)                                 |
+---------------------------------------------------+
| Section 4: Comparison                              |
| - canonical vs legacy timeline                    |
| - color-coded differences                         |
+---------------------------------------------------+
```

### 3.2 Backend Structure

สร้างไฟล์ใหม่:

```
public/dev/debug/token-timeline.php
```

ภายใน:

```php
require_once __DIR__ . '/../../../source/bootstrap.php';

if (!isDevEnvironment()) {
    http_response_code(403);
    exit('Forbidden');
}

$tokenId = $_GET['token_id'] ?? null;

$db = getPdo();

$token = TokenRepository::find($tokenId);
$events = TokenEventService::fetchEvents($tokenId);
$timeline = (new TimeEventReader($db))->getTimelineForToken($tokenId);

renderDebugPage($token, $events, $timeline);
```

### 3.3 Helper Functions

- `renderTokenInfo()`  
- `renderEventTable()`  
- `renderTimeline()`  
- `renderComparisonTable()`  

ทั้งหมดเป็น HTML แบบง่าย (ไม่ต้องใช้ framework)

---

## 4. Testing

### 4.1 Dev Manual Test
1. เปิด feature flag `NODE_BEHAVIOR_EXPERIMENTAL`  
2. เลือก token_id ที่เพิ่งทำงานจริง  
3. เปิดหน้า `/dev/debug/token-timeline.php?token_id=123`  
4. ตรวจสอบ:
   - canonical events ถูกสร้างครบ?
   - timeline จาก TimeEventReader สอดคล้องหรือไม่?
   - legacy fields ถูก sync หรือไม่?
   - สี warning แสดงถูกต้องหรือไม่?

### 4.2 Special Cases
- มี pause/resume หลายรอบ  
- ไม่มี NODE_START แต่มี NODE_COMPLETE  
- short session < 500 ms  
- events ไม่เรียงตามเวลา (ทดสอบ sorting)  

---

## 5. Limitations
- Dev-only tool ไม่ใช่ UI production  
- ไม่รองรับ multi-tenant UI (ใช้ scope ที่ bootstrap กำหนด)  
- ยังไม่ทำ grouping ตามงาน Hatthasilpa vs Classic  
- ไม่ทำ component-level timeline (future task)

---

## 6. Done Criteria
- มีหน้า dev-only สำหรับดู timeline canonical vs legacy  
- TimeEventReader ทำงานถูกใน dev ตาม event จริง  
- Developer สามารถใช้ debug timeline เพื่อตรวจสอบ behavior  
- ไม่มีการเขียนข้อมูลลงฐาน  
- มีเอกสาร `task21_6_results.md` พร้อมภาพประกอบ / ตัวอย่าง output

# Task 1 – Time Engine v2 (Core Engine + Work Queue Integration) - สรุปผลการทำงาน

**วันที่:** 2025-12-XX  
**สถานะ:** ✅ COMPLETED  
**Phase:** Phase 1 – Core Engine (Backend)

---

## 📋 วัตถุประสงค์

สร้าง Time Engine v2 เป็น **Single Source of Truth** สำหรับคำนวณเวลาทำงานของ `token_work_session` และให้ Work Queue ใช้เป็นที่แรก เพื่อเตรียมพื้นสำหรับ Phase 2 (drift-corrected JS timer) และ Phase 3 (auto-guard)

---

## ✅ สิ่งที่ทำเสร็จแล้ว

### 1. Backend – สร้าง WorkSessionTimeEngine Service

**ไฟล์:** `source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php`

**คุณสมบัติ:**
- ใช้ `DatabaseHelper` (PSR-4) แทน `mysqli` โดยตรง
- Method หลัก: `calculateTimer(array $sessionRow, ?DateTimeImmutable $now = null): array`
- รองรับ status: `active`, `paused`, `completed`, `none`, `unknown`
- คืนค่า Timer DTO ที่เป็นมาตรฐาน

**Timer DTO Structure:**
```php
[
    'work_seconds'      => int,   // เวลารวม ณ ตอนนี้
    'base_work_seconds' => int,   // work_seconds จาก DB snapshot
    'live_tail_seconds' => int,   // ส่วนเพิ่มตั้งแต่ resumed_at/started_at
    'status'            => string,// active|paused|completed|none|unknown
    'started_at'        => string,// ISO8601 format
    'resumed_at'        => string,// ISO8601 format
    'last_server_sync'  => string // ISO8601 format (สำหรับ Phase 2)
]
```

**Logic:**
- `active`: `work_seconds = base + (now - resumed_at/started_at)`
- `paused`/`completed`: `work_seconds = base` (no live tail)
- `none`: `work_seconds = 0`
- `unknown`: `work_seconds = base` (no live tail)

---

### 2. Backend – แก้ไข Work Queue API

**ไฟล์:** `source/dag_token_api.php` (function `handleGetWorkQueue()`)

**การเปลี่ยนแปลง:**
1. ลบ SQL CASE `work_seconds_display` ออกจาก SELECT
   ```sql
   -- เดิม (ลบออกแล้ว)
   CASE 
       WHEN s.status = 'active' THEN 
           COALESCE(s.work_seconds, 0) + TIMESTAMPDIFF(SECOND, COALESCE(s.resumed_at, s.started_at), NOW())
       WHEN s.status IN ('paused', 'completed') THEN 
           COALESCE(s.work_seconds, 0)
       ELSE 0
   END as work_seconds_display
   ```

2. เพิ่มการใช้ `WorkSessionTimeEngine` หลัง fetch tokens:
   ```php
   $dbHelper = new DatabaseHelper($tenantDb);
   $timeEngine = new WorkSessionTimeEngine($dbHelper);
   $now = new \DateTimeImmutable('now');
   
   foreach ($tokens as &$token) {
       if (!empty($token['id_session'])) {
           $sessionRow = [
               'status' => $token['session_status'] ?? null,
               'work_seconds' => $token['work_seconds'] ?? null,
               'started_at' => $token['started_at'] ?? null,
               'resumed_at' => $token['resumed_at'] ?? null,
           ];
           $timer = $timeEngine->calculateTimer($sessionRow, $now);
       } else {
           $timer = [/* empty timer */];
       }
       $token['timer'] = $timer;
   }
   ```

3. ส่ง `timer` DTO ใน response แทน `work_seconds_display`:
   ```php
   $tokenData = [
       // ... fields อื่นๆ ...
       'timer' => $token['timer'] ?? null,
       'session' => [/* ... */] // ไม่มี work_seconds_display แล้ว
   ];
   ```

---

### 3. Frontend – อัปเดต Work Queue UI

**ไฟล์:** `assets/javascripts/pwa_scan/work_queue.js`

**การเปลี่ยนแปลง:**

1. **เพิ่มฟังก์ชัน `formatWorkSeconds()`:**
   ```javascript
   function formatWorkSeconds(workSeconds) {
       const seconds = Math.max(0, Math.floor(workSeconds || 0));
       const hours = Math.floor(seconds / 3600);
       const mins = Math.floor((seconds % 3600) / 60);
       const secs = seconds % 60;
       
       return hours > 0 
           ? `${hours}:${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
           : `${mins}:${secs.toString().padStart(2, '0')}`;
   }
   ```

2. **เปลี่ยนจาก `token.session.work_seconds` เป็น `token.timer.work_seconds`:**
   ```javascript
   // เดิม
   const workSeconds = token.session.work_seconds || 0;
   
   // ใหม่
   const timer = token.timer || null;
   const workSeconds = timer ? timer.work_seconds : 0;
   ```

3. **เพิ่ม data attributes สำหรับ Phase 2 (drift-corrected timer):**
   ```html
   <span class="work-timer-active" 
         data-started="${session.started_at}"
         data-pause-min="${totalPauseMinutes}"
         data-work-seconds-base="${timer.base_work_seconds || 0}"
         data-last-server-sync="${timer.last_server_sync || ''}"
         data-status="${timer.status || 'active'}">
       ${formatWorkSeconds(timer.work_seconds || 0)}
   </span>
   ```

4. **อัปเดต 3 จุด:**
   - Kanban view (`renderKanbanToken()`)
   - List view (`renderListView()`)
   - Mobile cards (`renderMobileJobCard()`)

---

### 4. Unit Tests

**ไฟล์:** `tests/Unit/WorkSessionTimeEngineTest.php`

**ผลการทดสอบ:**
- ✅ 10 tests, 44 assertions — **ผ่านทั้งหมด**

**Test Cases:**
1. ✅ Active session without resume → `work_seconds = base + (now - started_at)`
2. ✅ Active session with resume → `work_seconds = base + (now - resumed_at)`
3. ✅ Paused session → `work_seconds = base` (no live tail)
4. ✅ Completed session → `work_seconds = base` (no live tail)
5. ✅ No session → `status = 'none'`, `work_seconds = 0`
6. ✅ Unknown status → `status = 'unknown'`, `work_seconds = base`
7. ✅ Future datetime handling → `live_tail >= 0` (never negative)
8. ✅ Missing work_seconds → defaults to 0
9. ✅ ISO8601 format conversion → `started_at`, `resumed_at` in ISO8601
10. ✅ Consistency with same now → identical results

---

## 📊 ผลลัพธ์

### เป้าหมายที่บรรลุ

1. ✅ **เลิกกระจาย logic เวลาไว้ใน SQL**  
   - Logic เวลาอยู่ใน Service กลางแล้ว (ไม่กระจายใน SQL/endpoint หลายจุด)

2. ✅ **มี Service กลางที่ตอบคำถามง่าย ๆ**  
   - `WorkSessionTimeEngine::calculateTimer()` ตอบคำถาม "token/session นี้ใช้เวลาไปแล้วกี่วินาที และ state คืออะไร?"

3. ✅ **Work Queue เป็น consumer แรกของ Time Engine v2**  
   - `handleGetWorkQueue()` ใช้ `WorkSessionTimeEngine` แล้ว

4. ✅ **เตรียมพื้นสำหรับ Phase 2 และ Phase 3**  
   - Timer DTO มี `last_server_sync` สำหรับ Phase 2 (drift-corrected timer)
   - Service structure พร้อมสำหรับ Phase 3 (auto-guard)

### คุณภาพ

- ✅ **Syntax check:** ผ่าน
- ✅ **Unit tests:** 10 tests, 44 assertions — ผ่านทั้งหมด
- ✅ **Code standards:** ใช้ `DatabaseHelper` (PSR-4)
- ✅ **Documentation:** มี comments และ docblocks ครบ

---

## 📁 ไฟล์ที่สร้าง/แก้ไข

### ไฟล์ใหม่

1. **`source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php`** (180 บรรทัด)
   - Core service สำหรับคำนวณเวลา session/token
   - ใช้ `DatabaseHelper` (PSR-4)

2. **`tests/Unit/WorkSessionTimeEngineTest.php`** (275 บรรทัด)
   - Unit tests ครอบคลุม 10 test cases

### ไฟล์ที่แก้ไข

1. **`source/dag_token_api.php`**
   - เพิ่ม `use BGERP\Service\TimeEngine\WorkSessionTimeEngine;`
   - ลบ SQL CASE `work_seconds_display`
   - เพิ่มการใช้ `WorkSessionTimeEngine` หลัง fetch tokens
   - ส่ง `timer` DTO ใน response

2. **`assets/javascripts/pwa_scan/work_queue.js`**
   - เพิ่ม `formatWorkSeconds()` function
   - อัปเดต 3 จุดให้ใช้ `token.timer` แทน `token.session.work_seconds`
   - เพิ่ม data attributes สำหรับ Phase 2

---

## ⚠️ ข้อจำกัด (ตาม Non-goals)

- ❌ ยัง **ไม่** ทำ cron auto-pause/auto-close (Phase 3)
- ❌ ยัง **ไม่** เปลี่ยน People Monitor (Phase 4)
- ⚠️ Frontend ยังใช้ `setInterval` แบบเดิม (Phase 2 จะ refactor)

---

## 🚀 ขั้นตอนต่อไป

### Task 2: JS Timer Refactor (Drift-corrected)
- ใช้ `last_server_sync` จาก Timer DTO เพื่อแก้ drift
- เปลี่ยนจาก `+1` ทุกวินาที เป็นคำนวณจาก `base + drift`
- เพิ่มกลไก re-sync กับ server ทุก X วินาที

### Task 3: Session Auto-Guard + Cron
- Cron/worker ที่ปิด session แปลก ๆ (ลืมกด pause, ปิดแท็บ ฯลฯ)
- Rule ชัดเจน เช่น inactive > 2 ชม. → auto-pause

### Task 4: People Monitor Integration
- ใช้ Time Engine + realtime timer ต่อคน
- แสดง workload breakdown, current work, timer

---

## 📝 สรุป

**Task 1 เสร็จสมบูรณ์ตาม spec:**

- ✅ สร้าง Time Engine v2 Service (`WorkSessionTimeEngine`)
- ✅ Work Queue ใช้ Time Engine แล้ว (แทน SQL CASE)
- ✅ Frontend รองรับ Timer DTO พร้อม data attributes สำหรับ Phase 2
- ✅ Tests ผ่านทั้งหมด (10 tests, 44 assertions)
- ✅ ใช้ `DatabaseHelper` (PSR-4) ตามมาตรฐาน

**พร้อมสำหรับ Task 2 (JS Timer Refactor) ต่อไป!**

---

## 📚 อ้างอิง

- **Task Spec:** `docs/time-engine/tasks/task1.md`
- **Implementation Guide:** `docs/time-engine/time-engine-bellavier-erp-implementation.md`
- **Service:** `source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php`
- **Tests:** `tests/Unit/WorkSessionTimeEngineTest.php`


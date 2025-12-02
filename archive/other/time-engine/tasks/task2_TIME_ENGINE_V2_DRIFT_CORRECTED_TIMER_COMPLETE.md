# Task 2 – Time Engine v2 (Phase 2) – Drift-Corrected JS Timer for Work Queue - สรุปผลการทำงาน

**วันที่:** 2025-12-XX  
**สถานะ:** ✅ COMPLETED  
**Phase:** Phase 2 – Frontend Timer (Drift-corrected)

---

## 📋 วัตถุประสงค์

เปลี่ยนกลไกนับเวลาใน Work Queue UI ให้ใช้ค่าเวลาแบบอ้างอิงจาก Server (Timer DTO จาก Time Engine v2) แทนการใช้ `setInterval +1` แบบเดิม เพื่อแก้ปัญหา:
- Timer เพี้ยนเมื่อแท็บอยู่เบื้องหลัง (background)
- Timer เพี้ยนเมื่อสลับหน้า
- Timer เพี้ยนเมื่อ CPU/Browser lag
- Timer ไม่แม่นยำเมื่อแท็บเปิดค้างนานหรือ sleep

---

## ✅ สิ่งที่ทำเสร็จแล้ว

### 1. Frontend – สร้าง Work Queue Timer Engine

**ไฟล์:** `assets/javascripts/pwa_scan/work_queue_timer.js`

**คุณสมบัติ:**
- ใช้ `window.BGTimeEngine` namespace สำหรับ global access
- Registry system สำหรับ track timer elements อัตโนมัติ
- Drift-corrected calculation จาก `last_server_sync` + client clock
- Auto-cleanup เมื่อ element ถูกลบจาก DOM
- รองรับทั้ง direct text และ nested `.timer-display` span

**API Methods:**
```javascript
BGTimeEngine.registerTimerElement(spanEl)      // ลงทะเบียน timer element
BGTimeEngine.unregisterTimerElement(spanEl)   // ยกเลิกการลงทะเบียน
BGTimeEngine.updateTimerFromPayload(spanEl, timerDto)  // อัปเดตจาก server response
BGTimeEngine.cleanup()                         // Cleanup ทั้งหมด
```

**Logic:**
- `active`: `displaySeconds = syncSeconds + (now - lastSync)`
- `paused`/`completed`: `displaySeconds = syncSeconds` (no drift)
- Update ทุก 1 วินาทีด้วย global ticker (shared across all timers)

---

### 2. Frontend – ปรับ HTML Data Attributes

**ไฟล์:** `assets/javascripts/pwa_scan/work_queue.js`

**การเปลี่ยนแปลงใน 3 จุด:**

#### 2.1 renderListView (List View)
- เพิ่ม `data-work-seconds-sync="${timer.work_seconds || 0}"`
- เพิ่ม `data-token-id="${token.id_token}"` (สำหรับหา element หลัง render)
- คงไว้ attributes เดิม: `data-work-seconds-base`, `data-last-server-sync`, `data-status`

#### 2.2 renderKanbanTokenCard (Kanban View)
- เพิ่ม `data-work-seconds-sync="${timer.work_seconds || 0}"`
- เพิ่ม `data-token-id="${token.id_token}"`
- คงไว้ attributes เดิม

#### 2.3 renderListTokenCard (List View - Mobile)
- เพิ่ม `data-work-seconds-sync="${timer.work_seconds || 0}"`
- เพิ่ม `data-token-id="${token.id_token}"`
- คงไว้ attributes เดิม

**เหตุผล:**
- `data-work-seconds-sync` = snapshot จาก server ณ เวลา `last_server_sync`
- `data-token-id` = ใช้สำหรับหา element หลัง render เพื่อ register timer

---

### 3. Frontend – ผูก Register Timer หลัง Render Token

**การเปลี่ยนแปลง:**

#### 3.1 เพิ่ม Helper Function
```javascript
function registerTimerElements($container) {
    // Find all .work-timer-active elements
    // Register only active timers with BGTimeEngine
}
```

#### 3.2 เรียกใช้ใน 3 จุด:
1. `renderListView()` - หลัง `$container.html(html)`
2. `renderMobileJobCards()` - หลัง `$container.html(html)`
3. `renderKanbanColumn()` - หลัง append token cards

**ผลลัพธ์:**
- Timer elements ถูก register อัตโนมัติหลัง render
- เฉพาะ `status === 'active'` เท่านั้นที่ถูก register (paused/completed ไม่ต้อง)

---

### 4. Frontend – แก้ไข updateAllTimers()

**การเปลี่ยนแปลง:**

#### 4.1 ลบ setInterval เดิม
```javascript
// เดิม (ลบออกแล้ว)
setInterval(updateAllTimers, 1000);

// ใหม่
// TASK2: Timers are now handled by BGTimeEngine (drift-corrected)
// No need for setInterval here - BGTimeEngine manages its own ticker
```

#### 4.2 Deprecate updateAllTimers()
```javascript
function updateAllTimers() {
    // TASK2: BGTimeEngine handles all timer updates automatically
    // This function is kept for backward compatibility but does nothing
    return;
}
```

**เหตุผล:**
- BGTimeEngine มี global ticker ของตัวเอง (1 ticker สำหรับทุก timers)
- ไม่ต้องมี setInterval หลายตัว (ลด memory leak)

---

### 5. Frontend – เพิ่ม Helper สำหรับ State Changes

**เพิ่ม Function:**
```javascript
function updateTimerFromResponse(tokenId, timerDto) {
    // Find timer element by token-id
    // Update data attributes from server response
    // Re-register if status changed to active
}
```

**สถานะ:**
- Function พร้อมใช้งานแล้ว
- ยังไม่ได้เรียกใช้ (เพราะ API responses ไม่ได้ส่ง timer DTO กลับมา)
- `loadWorkQueue()` จะ refresh ทั้งหน้าและ register timers อัตโนมัติ

**อนาคต:**
- ถ้า API ส่ง timer DTO กลับมาใน response → สามารถเรียกใช้ได้ทันที

---

### 6. Page Definition – เพิ่ม Timer Engine Script

**ไฟล์:** `page/work_queue.php`

**การเปลี่ยนแปลง:**
```php
// เดิม
$page_detail['jquery'][3] = domain::getDomain().'/assets/javascripts/pwa_scan/work_queue.js?v='.time();

// ใหม่
$page_detail['jquery'][3] = domain::getDomain().'/assets/javascripts/pwa_scan/work_queue_timer.js?v='.time();
$page_detail['jquery'][4] = domain::getDomain().'/assets/javascripts/pwa_scan/work_queue.js?v='.time();
```

**เหตุผล:**
- `work_queue_timer.js` ต้องโหลดก่อน `work_queue.js` (เพื่อให้ `window.BGTimeEngine` พร้อมใช้งาน)

---

## 📊 ผลลัพธ์

### เป้าหมายที่บรรลุ

1. ✅ **Drift-Corrected Timer**
   - Timer คำนวณจาก server snapshot + client clock
   - ไม่เพี้ยนเมื่อแท็บ background/sleep
   - แม่นยำแม้แท็บเปิดค้างนาน

2. ✅ **Single Source of Truth**
   - Logic เวลาอยู่ที่ `BGTimeEngine` (frontend)
   - ใช้ Timer DTO จาก `WorkSessionTimeEngine` (backend)
   - ไม่มี logic เวลาซ้ำซ้อน

3. ✅ **Backward Compatibility**
   - ไม่เปลี่ยนโครงสร้าง HTML/DOM
   - เพิ่มแค่ data attributes
   - ยังรองรับ `.timer-display` span (nested)

4. ✅ **Performance**
   - 1 global ticker แทน setInterval หลายตัว
   - Auto-cleanup เมื่อ element ถูกลบ
   - Registry system ใช้ Set (O(1) lookup)

### คุณภาพ

- **Code Organization:** แยก concerns ชัดเจน (timer engine vs view logic)
- **Error Handling:** มี fallback เมื่อ BGTimeEngine ไม่โหลด
- **Maintainability:** Helper functions ชัดเจน, มี comments
- **Testing Ready:** Logic แยกออกมา test ได้ง่าย

---

## 📁 ไฟล์ที่สร้าง/แก้ไข

### ไฟล์ใหม่

1. **`assets/javascripts/pwa_scan/work_queue_timer.js`** (196 บรรทัด)
   - Timer Engine ฝั่ง Frontend
   - Registry system
   - Drift-corrected calculation

### ไฟล์ที่แก้ไข

1. **`assets/javascripts/pwa_scan/work_queue.js`**
   - เพิ่ม `data-work-seconds-sync` ใน 3 render functions
   - เพิ่ม `registerTimerElements()` helper
   - เพิ่ม `updateTimerFromResponse()` helper
   - แก้ไข `updateAllTimers()` (deprecate)
   - ลบ `setInterval(updateAllTimers, 1000)`

2. **`page/work_queue.php`**
   - เพิ่ม `work_queue_timer.js` script (โหลดก่อน work_queue.js)

---

## ⚠️ ข้อจำกัด (ตาม Non-goals)

1. **ยังไม่ refactor JS timer แบบเต็มระบบ**
   - ยังใช้ `formatWorkSeconds()` เดิม (ไม่แยกออกมา)
   - ยังไม่มีการ optimize rendering (debounce/throttle)

2. **ยังไม่มีการ handle edge cases บางอย่าง**
   - Timezone differences (ใช้ client timezone)
   - Clock skew > 1 นาที (ยังไม่ validate)

3. **ยังไม่มีการ integration กับหน้าอื่น**
   - People Monitor (Phase 4)
   - Trace Overview (Phase 4)

---

## 🚀 ขั้นตอนต่อไป

### Task 3: Session Auto-Guard + Cron
- สร้าง cron job สำหรับ auto-pause abandoned sessions
- ใช้ Timer Engine v2 ในการคำนวณ session duration
- เพิ่ม configuration สำหรับ threshold

### Task 4: Multi-surface Integration
- People Monitor → ใช้ BGTimeEngine
- Trace Overview → ใช้ BGTimeEngine
- Serial/Token Detail → ใช้ BGTimeEngine

### Task 5: Advanced Analytics & Costing
- ใช้ Timer Engine v2 ในการคำนวณต้นทุนแรงงาน
- Productivity & Bottleneck Analysis
- SLA & Lead Time

---

## 📝 สรุป

Task 2 สำเร็จแล้ว โดยเปลี่ยน Work Queue UI ให้ใช้ **drift-corrected timer** จาก BGTimeEngine แทนการใช้ `setInterval +1` แบบเดิม

**ผลลัพธ์หลัก:**
- Timer แม่นยำแม้แท็บ background/sleep
- Single source of truth (BGTimeEngine)
- Performance ดีขึ้น (1 ticker แทนหลาย setInterval)
- Backward compatible (ไม่เปลี่ยน DOM structure)

**Technical Highlights:**
- Registry system สำหรับ track timers
- Auto-cleanup เมื่อ element ถูกลบ
- Drift-corrected calculation จาก server snapshot
- Helper functions สำหรับ state changes (พร้อมใช้งาน)

**Next Steps:**
- Task 3: Auto-Guard (ป้องกัน abandoned sessions)
- Task 4: Multi-surface Integration (People Monitor, Trace Overview)
- Task 5: Advanced Analytics (Costing, Productivity)

---

## 📚 อ้างอิง

- **Task Spec:** `docs/time-engine/tasks/task2.md`
- **Implementation Guide:** `docs/time-engine/time-engine-bellavier-erp-implementation.md` (Phase 2)
- **Task 1 (Backend):** `docs/time-engine/tasks/task1_TIME_ENGINE_V2_CORE_ENGINE_COMPLETE.md`
- **WorkSessionTimeEngine:** `source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php`
- **Work Queue API:** `source/dag_token_api.php` (handleGetWorkQueue)

---

**วันที่เสร็จ:** 2025-12-XX  
**ผู้พัฒนา:** AI Agent (Auto)  
**สถานะ:** ✅ COMPLETED


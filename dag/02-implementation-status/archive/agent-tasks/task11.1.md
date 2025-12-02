# Task 11.1 – Work Queue UI Smoothing (Loading State & Flicker Fix)

**Type:** Frontend Patch / UX Smoothing  
**Files:**  
- `assets/javascripts/pwa_scan/work_queue.js`  
**Do NOT touch:**  
- PHP layout / HTML structure ของหน้า Work Queue  
- CSS / SCSS (ห้ามแก้ class / style หลัก)  
- Backend API logic ใน `source/dag_token_api.php` (ถือว่า Task 11 ปรับไว้แล้วถูกต้อง)

---

## 🎯 Objective

1. แก้ปัญหา **loading spinner “กำลังโหลด…” ค้างอยู่** ข้าง ๆ column ใน Kanban / List view
2. ลดอาการ **จอกระพริบ / แถวหาย–กลับมาใหม่** เมื่อกดปุ่ม:
   - เริ่มงาน (Start)
   - หยุด (Pause)
   - ทำต่อ (Resume)
   - จบงาน (Complete)
   - QC pass/fail
3. ทำให้ Work Queue **ลื่นตาแบบเวอร์ชันก่อน refactor** โดย:
   - ไม่แสดง placeholder loading ใหญ่ ๆ ทุกครั้งหลัง action เล็ก ๆ
   - พยายามรักษา scroll position และ layout เดิม

---

## 🧱 Current Behavior Overview (from existing JS)

- `loadWorkQueue()`:
  - ใส่ loading HTML เข้าไปใน:
    - `#work-queue-container`
    - `#hattha-mobile-cards`
  - call API `source/dag_token_api.php?action=get_work_queue`
  - success → `renderWorkQueue(resp.nodes)`, `updateSummary`
- `renderWorkQueue(nodes)`:
  - อัปเดต node filter
  - สร้าง viewModel
  - ถ้า empty → ใส่ empty state
  - ถ้าไม่ empty:
    - ดู `getEffectiveViewMode()` → เรียก `renderKanbanView` หรือ `renderListView`
    - mobile → `renderMobileJobCards`
- `renderKanbanView(nodes, $container)`:
  - ปัจจุบัน **ไม่ได้ clear container ก่อน** แต่ `append` column ต่อท้าย
  - ทำให้ spinner / ของเก่าอยู่ค้าง
- ปุ่ม action ต่าง ๆ (`startToken`, `pauseToken`, `resumeToken`, `completeToken`, `handleQCAction`, ฯลฯ):
  - หลัง action เสร็จ มักเรียก `loadWorkQueue()` อีกครั้ง
  - เพราะ `loadWorkQueue()` แสดง spinner เต็มจอ → token list หายไปแล้วกลับมาใหม่ → เกิด “กระพริบ”

---

## 🔧 Scope of Changes

### 1) แก้ Loading State ให้ถูกต้อง (ไม่ค้าง)

**Goal:** เมื่อโหลด work queue เสร็จ  
- spinner/ข้อความ “กำลังโหลด…” ต้องหายไปทั้งหมด
- container มีเฉพาะ column หรือ list ที่ render ใหม่

**Required changes:**

1. ปรับ `renderKanbanView(nodes, $container)`:

   - ปัจจุบัน:

     ```js
     function renderKanbanView(nodes, $container) {
         nodes.forEach(node => {
             const $kanbanColumn = renderKanbanColumn(node);
             $container.append($kanbanColumn);
         });
     }
     ```

   - ให้เปลี่ยนเป็น (แนวทาง):

     ```js
     function renderKanbanView(nodes, $container) {
         // Clear any loading/previous content
         $container.empty();

         if (!nodes || !nodes.length) {
             return;
         }

         nodes.forEach(node => {
             const $kanbanColumn = renderKanbanColumn(node);
             if ($kanbanColumn) {
                 $container.append($kanbanColumn);
             }
         });
     }
     ```

   - ต้องเช็ค `null` จาก `renderKanbanColumn()` เพราะมัน return `null` สำหรับ non-operable node type (start/end/split/join/…).

2. ตรวจสอบ `renderListView()` และ `renderMobileJobCards()`:
   - `renderListView()` ใช้ `$container.html(html)` อยู่แล้ว → OK
   - `renderMobileJobCards()` ใช้ `$container.empty()` แล้วค่อยเติม → OK
   - ไม่ต้องเปลี่ยน layout, แค่ยืนยันว่าไม่มีส่วนไหน `append` ซ้อนทับโดยไม่ clear

3. ใน `renderWorkQueue(nodes)`:
   - ตอน empty state ใช้ `$kanbanContainer.html(emptyHtml)` / `$mobileContainer.html(emptyHtml)` → OK
   - ไม่ต้องแสดง spinnerในฟังก์ชันนี้ (spinner คุมโดย `loadWorkQueue`)

---

### 2) แยก “Full Loading” กับ “Silent Refresh” (ลดการกระพริบ)

**Goal:**  
- Initial load / กดปุ่ม Refresh → แสดง spinner ได้ (เพื่อให้ user รู้ว่าโหลดใหม่)
- หลัง action เช่น Start/Pause/Resume/Complete/QC → ให้ refresh แบบ “เงียบ” (ไม่มี placeholder ใหญ่, ไม่รีเซ็ต DOM แบบ hard) เพื่อลดอาการกระพริบ

**Implementation plan:**

1. เปลี่ยน `loadWorkQueue()` ให้รับ *optional options*:

   ```js
   function loadWorkQueue(options) {
       const settings = Object.assign({
           showLoading: true,   // default: true
           preserveScroll: true // optional: ใช้ภายหลังได้
       }, options || {});

	2.	ใช้ showLoading คุม spinner:

if (settings.showLoading) {
    const loadingHtml = `...`; // ของเดิม
    $kanbanContainer.html(loadingHtml);
    if ($mobileContainer.length) {
        $mobileContainer.html(loadingHtml);
    }
}


	3.	อัปเดต caller ของ loadWorkQueue():
	•	Initial load ($(document).ready) → ใช้ค่า default (หรือส่ง {showLoading: true})
	•	ปุ่ม Refresh: $('#btn-refresh-queue') → เรียก loadWorkQueue({showLoading: true});
	•	Auto refresh timer (startAutoRefresh() ถ้ามีในไฟล์) → ให้ออกแบบเป็น “silent refresh”:
	•	loadWorkQueue({showLoading: false});
	•	หลัง action token (start/pause/resume/complete/QC/help/takeover) → ให้ใช้ silent refresh:
	•	loadWorkQueue({showLoading: false});
NOTE: ต้องค้นในไฟล์ว่า loadWorkQueue() ถูกเรียกจากที่ไหนบ้าง แล้วเปลี่ยนให้ตรงตามนี้
	4.	ห้ามโชว์ spinner ขนาดใหญ่ เวลา action สำเร็จ:
	•	ตอนนี้ทุก action เรียก loadWorkQueue() → เดิมจะแสดง spinner แล้ว reload ทั้งแถว → ทำให้ตากระพริบ
	•	หลัง patch แล้ว action จะ reload ข้อมูล “เงียบ ๆ” แถวอาจ refresh แต่ไม่โดนแทนที่ด้วย placeholder

⸻

3) รักษา Scroll Position (ถ้าเป็นไปได้แบบง่าย)

ไม่จำเป็นต้อง complex แต่ถ้าทำได้:
	1.	ใน loadWorkQueue(options):
	•	ถ้า settings.preserveScroll เป็น true:
	•	เก็บ const scrollTop = $kanbanContainer.scrollTop();
	•	หลังจาก renderWorkQueue เสร็จ:
	•	set กลับ scrollTop เดิม

ตัวอย่าง:

function loadWorkQueue(options) {
    const settings = Object.assign({
        showLoading: true,
        preserveScroll: true
    }, options || {});

    const $kanbanContainer = $('#work-queue-container');
    const $mobileContainer = $('#hattha-mobile-cards');
    const prevScrollTop = settings.preserveScroll ? $kanbanContainer.scrollTop() : 0;

    // ... call AJAX ...

    success: function(resp) {
        if (resp.ok) {
            renderWorkQueue(resp.nodes || []);
            updateSummary(resp.total_tokens);

            if (settings.preserveScroll) {
                $kanbanContainer.scrollTop(prevScrollTop);
            }
        } else {
            // error handling ตามเดิม
        }
    }
}

	•	สำหรับ mobile container จะใช้ behavior ของ browser / จอเล็ก (ไม่ต้องบังคับ scroll ก็ได้)

⸻

4) ตรวจสอบการแสดงสถานะ (ไม่กระตุกระหว่างเปลี่ยน status)

ไม่ต้องเปลี่ยน design, แต่อย่างน้อย:
	1.	หลังจาก action เสร็จ:
	•	ปุ่มของ token นั้นไม่ควรค้างใน state เก่า
	•	หลัง silent refresh ควรแสดง:
	•	ready → active/paused
	•	active → paused/complete
	2.	ไม่ต้องทำ “optimistic UI” ซับซ้อน (เช่น เปลี่ยน state ก่อน API ตอบ)
แค่ uncoupled spinner ก็ลดอาการกระพริบได้เยอะแล้ว

⸻

✅ Acceptance Criteria
	1.	Loading State
	•	หลังโหลด Work Queue สำเร็จ:
	•	ไม่มี element “กำลังโหลด…” เหลือใน #work-queue-container หรือ #hattha-mobile-cards
	•	เมื่อ switch Kanban/List → แสดงเฉพาะ column/list ที่ถูกต้อง ไม่มี spinner ซ้อน
	2.	Smooth Actions (NO Flicker)
	•	กด “เริ่ม / หยุด / ทำต่อ / เสร็จ / QC pass/fail / Help / Take over”:
	•	การ์ดไม่หายไปทั้งแถวแล้วกลับมาแบบวูบ ๆ
	•	ไม่มีการขึ้น spinner ใหญ่เต็มช่องทุกครั้ง (ใช้ silent refresh)
	•	หลัง action → status ของการ์ดเปลี่ยนถูกต้อง (ready → active/paused, ฯลฯ)
	3.	Scroll
	•	ถ้า operator scroll ดูรายการอยู่:
	•	กด action ใด ๆ → scroll position ไม่ถูกรีเซ็ตไปบนสุด (หรืออย่างน้อยไม่ขยับแบบชัดเจน) ใน desktop
	4.	No Layout/CSS Changes
	•	Layout / spacing / สี / typography ของ Work Queue เหมือนเดิมทุกประการ
	•	Kanban column และ card structure ไม่ถูกเปลี่ยน (เฉพาะ logic ภายใน JS เท่านั้นที่เปลี่ยน)
	5.	Regression
	•	Work Queue ยังโหลดได้ในทั้ง:
	•	Desktop (Kanban + List)
	•	Mobile (job cards)
	•	Filter เช่น Hide Scrapped Tokens, assigned_to_me ยังใช้งานได้ตามเดิม

⸻

📝 Notes for Agent
	•	โฟกัสเฉพาะไฟล์ assets/javascripts/pwa_scan/work_queue.js
	•	ห้ามเปลี่ยน HTML structure หรือ class names เพราะผูกกับ CSS และ template เดิม
	•	ให้คอมเมนต์สั้น ๆ ระบุว่าเป็นส่วนของ Task 11.1 (เช่น // TASK11.1: ...) ตรงจุดที่แก้ไข เพื่อช่วยเวลา code review
	•	หลัง patch แนะนำให้ทดสอบ manual:
	1.	เปิด Work Queue, Kanban view
	2.	กดเริ่มงาน 1 ชิ้น → สังเกตว่าการ์ดเปลี่ยนสถานะ โดยไม่กระพริบทั้ง list
	3.	กดหยุด/ทำต่อ/เสร็จ → ตรวจสอบลักษณะเดียวกัน
	4.	ลองกดปุ่ม Refresh → spinner ต้องแสดงตามปกติ, แล้วหาย

---

ถ้าคุณอยากให้เพิ่ม section “Agent command (EN)” แบบสั้น ๆ เอาไว้ใส่ใน Cursor system prompt ผมเขียนต่อให้ได้เลยครับ ✨
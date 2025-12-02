TASK 2.2 – TIME ENGINE V2: Fix Realtime Timers (Work Queue & Friends)

รหัสงาน: TIME_ENGINE_V2_TASK2_2_FIX_REALTIME_TIMERS
เป้าหมาย: ทำให้เวลาในหน้า Work Queue วิ่งแบบ realtime ถูกต้อง หลัง Start / Pause / Resume โดยไม่ต้อง refresh หน้า และไม่กระโดดเป็นหลักนาที

⸻

1. Context & Symptoms

ตอนนี้ Time Engine v2 ถูก implement แล้ว (Task 1 + Task 2 + 2.1) และใช้งานบนหน้า:
	•	assets/javascripts/pwa_scan/work_queue.js
	•	API: source/dag_token_api.php (ฝั่ง server ส่ง timer DTO มา)
	•	PHP Time Engine: source/model/WorkSessionTimeEngine.php (หรือไฟล์ที่เกี่ยวข้องกับ timer DTO)

อาการปัจจุบันที่ผู้ใช้เจอในหน้า Work Queue:
	1.	กด Start แล้วเวลาไม่วิ่งแบบ realtime
	•	ต้อง refresh หน้าใหม่ → เวลาถึงจะเปลี่ยน
	2.	กด Pause → Resume แล้วเวลา “กระโดด”
	•	เช่น เวลาแสดง 10:10 (10 นาที 10 วิ)
	•	กด Pause แล้วตัวเลขค้างที่ 10:51
	•	กด Resume แล้ว “เดินต่อได้ปกติ” (แต่รู้สึกว่าคำนวณผิดหรือโดด)
	3.	หลังจากปรับมาใช้ BGTimeEngine แล้ว:
	•	Resume ดูเหมือนทำงาน แต่ Start รอบแรกไม่ trigger timer อย่างถูกต้อง
	•	บ่งชี้ว่ามีปัญหาที่:
	•	การ register timer DOM กับ BGTimeEngine
	•	หรือการตีความ data attributes (data-started, data-work-seconds-base, ฯลฯ)
	•	หรือการ reload work queue หลัง action

⸻

2. Scope งาน Task 2.2

2.2.1 ไฟล์หลักที่เกี่ยวข้อง

Frontend JS:
	•	assets/javascripts/pwa_scan/work_queue.js
	•	assets/javascripts/time/BGTimeEngine.js (หรือชื่อไฟล์ time-engine ที่ใช้จริงในโปรเจกต์ – ให้ค้นหา “BGTimeEngine”)

Backend PHP:
	•	source/dag_token_api.php (เฉพาะส่วนที่ส่ง timer DTO)
	•	source/model/WorkSessionTimeEngine.php (หรือไฟล์ที่ generate timer DTO ให้ frontend)

เอกสาร:
	•	docs/time_engine/TIME_ENGINE_V2.md (หรือไฟล์อธิบาย Time Engine v2)
	•	docs/developer/02-quick-start/GLOBAL_HELPERS.md (มี section ที่พูดถึง Time Engine / WorkSessionTimeEngine ถ้ามี)
	•	docs/developer/02-quick-start/AI_QUICK_START.md (กฎสำหรับ AI; ต้องปฏิบัติตาม)

⸻

3. Safety Rails (ข้อจำกัดสำคัญ)
	1.	ห้ามเปลี่ยน Business Logic / กติกาการนับเวลาฝั่ง PHP
	•	ห้ามเปลี่ยนกติกาการคำนวณเวลาทำงานจริง (total_work_seconds, pause_minutes ฯลฯ)
	•	หากจำเป็นต้องแตะ WorkSessionTimeEngine ให้แก้เฉพาะ bug ในการ “นำเสนอ DTO” เท่านั้น
(เช่น แก้ค่า field ผิด mapping, or off-by-one, หรือแปลง timestamp ผิด)
	•	ห้ามเปลี่ยนโครงสร้าง DB
	2.	Source of Truth คือ Server + Time Engine DTO
	•	Frontend ห้าม “คิดเวลาเอง” ด้วย setInterval + logic ใหม่
	•	Frontend มีหน้าที่:
	•	render timer DOM element พร้อม data-* ครบ
	•	ส่ง DOM timers ให้ BGTimeEngine เท่านั้น
	3.	ไม่ทำ Refactor ครั้งใหญ่
	•	ห้ามจัดโครงสร้าง work_queue.js ใหม่ทั้งไฟล์
	•	ห้าม rename ฟังก์ชัน public ที่ถูกใช้จากไฟล์อื่น
	•	จำกัดการเปลี่ยนแปลงให้ “minimal diff ที่แก้ bug” + เพิ่ม helper เท่าที่จำเป็น
	4.	Backward Compatibility
	•	หน้าอื่นที่ใช้ BGTimeEngine (ถ้ามี เช่น เวอร์ชันก่อนหน้า) ต้องไม่พัง
	•	Timer ที่ pause อยู่แล้วต้องแสดงเวลาเดิมถูกต้อง

⸻

4. เป้าหมายเชิงพฤติกรรม (Behavioral Goals)

เมื่อแก้เสร็จ ต้องได้พฤติกรรมแบบนี้:
	1.	Start Token
	•	กด Start → UI reload queue แบบ silent (ไม่กระตุกมาก)
	•	Timer ของ token นั้นเริ่มนับแบบ realtime ภายใน 1 วินาที โดยไม่ต้อง refresh หน้า
	2.	Pause Token
	•	กด Pause → Timer หยุดนิ่งทันที
	•	ไม่ควรมี tick ต่อไป (ไม่มี ghost interval)
	3.	Resume Token
	•	กด Resume → Timer เริ่ม “วิ่งต่อจากค่าเดิม” เนียนๆ
	•	ไม่มีการโดด “ทีเดียวเป็นหลักนาที” เพราะ drift หรือคำนวณ base ผิด
	4.	หลาย Timer พร้อมกัน
	•	หาก operator มีงาน active มากกว่า 1 ชิ้น (ถ้า allowed)
	•	Timers ทุกตัวที่ active ต้องวิ่งพร้อมกันอย่างถูกต้อง
	•	ไม่กิน CPU เกินไป (ใช้ engine กลาง ไม่ใช่ setInterval ทีละ element)

⸻

5. สิ่งที่ต้องทำ (Step-by-Step)

Step 1 – อ่าน Time Engine V2 Contract
	1.	เปิดไฟล์ Time Engine docs:
	•	docs/time_engine/TIME_ENGINE_V2.md (หรือไฟล์ที่อธิบาย Time Engine จริงในโปรเจกต์)
	2.	สรุป “สัญญา” (contract) ระหว่าง Backend → Frontend → BGTimeEngine:
	•	timer DTO มี field อะไรบ้าง เช่น:
	•	timer.status
	•	timer.work_seconds
	•	timer.base_work_seconds
	•	timer.last_server_sync
	•	DOM timer element ที่ BGTimeEngine คาดหวังต้องมี data-* อะไรบ้าง เช่น:
	•	data-started
	•	data-pause-min
	•	data-work-seconds-base
	•	data-work-seconds-sync
	•	data-last-server-sync
	•	data-status

ให้เขียนสรุปสั้นๆ ใน comment (เฉพาะใน JS / PHP) หรือใน docs ถ้าจำเป็น เพื่อกันลืม

⸻

Step 2 – ตรวจ work_queue.js ว่าทำตาม contract หรือไม่
	1.	หาโค้ดที่ render timer:
	•	ฟังก์ชัน:
	•	renderListTokenCard(token, groupType)
	•	renderKanbanTokenCard(token, groupType)
	•	renderTokenCard(token, groupType) (legacy)
	•	ยืนยันว่า:
	•	ทุก active timer element มี class work-timer-active
	•	data-* ครบ และ mapping เข้ากับ DTO ตาม contract
	2.	ตรวจฟังก์ชัน:
	•	registerTimerElements($container):
	•	ต้องค้นหา .work-timer-active ภายใน scope ที่ส่งเข้ามา
	•	ส่ง element list ไปที่ window.BGTimeEngine.registerTimerElements(...)
	3.	ตรวจ event handlers ที่เกี่ยวกับ state:
	•	.btn-start-token
	•	.btn-pause-token
	•	.btn-resume-token
	•	.btn-complete-token
	•	.btn-qc-pass
	•	.btn-qc-fail
ยืนยันว่า:
	•	ใน resp.ok === true → เรียก loadWorkQueue({ showLoading: false, preserveScroll: true });
	•	ไม่มี setInterval / manual DOM update timer ที่ไปซ้อนกับ BGTimeEngine แล้ว

⸻

Step 3 – ตรวจ BGTimeEngine ตัวจริง
	1.	ค้นหาไฟล์ JS ของ BGTimeEngine:
	•	ใช้ global search หาคำว่า BGTimeEngine ในโปรเจกต์
	•	เปิดไฟล์ เช่น assets/javascripts/time/BGTimeEngine.js (ชื่ออาจต่างเล็กน้อย)
	2.	ตรวจฟังก์ชันหลัก:
	•	registerTimerElements(domElementsOrArray)
	•	ตัว loop ที่ใช้ requestAnimationFrame หรือ setInterval เพื่อ update timers
	3.	เช็คจุดสำคัญ:
	•	เวลาเริ่มนับ now เทียบกับ:
	•	data-started
	•	data-work-seconds-base
	•	data-pause-min
	•	ตอน Resume:
	•	เอาค่า base เดิม + delta ใหม่ไปรวมกันถูกต้องหรือไม่
	•	Drift หรือ double-interval:
	•	registerTimerElements บางทีอาจเพิ่ม element เดิมซ้ำๆ → ทำให้ logic คำนวณ base ผิด
	•	ต้อง ensure ว่ามีการ de-duplicate timers

ถ้าเจอ logic ที่ “คิดเวลาจากเวลาปัจจุบันลบ started_at แล้วค่อยบวก base” ให้เช็กว่าใช้ data field ถูกตัว

⸻

Step 4 – หาสาเหตุที่เกี่ยวกับอาการของผู้ใช้

โฟกัส 2 อาการหลัก:
	1.	Start แล้วไม่วิ่งจนกว่าจะ refresh
	•	เป็นไปได้ว่า:
	•	ไม่ได้เรียก registerTimerElements หลังจาก loadWorkQueue รอบแรก
	•	BGTimeEngine ยังไม่ได้ initial เลยในหน้า work_queue
	•	หรือ timer element ยังไม่มี class work-timer-active ตอน render
	2.	Pause → Resume แล้วเวลากระโดด
	•	เป็นไปได้ว่า:
	•	BGTimeEngine คิดว่า “base_work_seconds” = เวลา pause แล้ว แต่หลัง resume ตั้ง base ใหม่ผิด
	•	แต่ server ส่ง timer.work_seconds ที่รวม pause แล้ว → ทำให้ base ถูกบวกสองรอบ
	•	หรือ data-pause-min ถูกแปลงหน่วยผิด (minute vs second)

ให้เพิ่ม log เล็กๆ (ชั่วคราว) ใน BGTimeEngine เช่น:

console.debug('[BGTimeEngine] registerTimer', {
  tokenId,
  started,
  base: workSecondsBase,
  sync: workSecondsSync,
  status,
});

และใน work_queue.js ใน success ของ start/pause/resume เพื่อดูค่าที่ส่งมาจาก server แล้ว mapping ลง DOM

⸻

Step 5 – แก้ไขอย่างระมัดระวัง

เป้าหมายหลักของการแก้:
	1.	BGTimeEngine.registerTimerElements:
	•	ไม่ควรสร้าง timer object ซ้ำซ้อนสำหรับ element เดิม
	•	ถ้ามีการ re-render DOM แล้วเรียก registerTimerElements ใหม่ → engine ต้อง:
	•	ถอด timer เก่าที่ใช้ element เดิมทิ้ง (หรือ update reference)
	•	หรือใช้ key ตาม data-token-id เพื่อ override state เดิม
	2.	คำนวณเวลา:
	•	ถ้า status = active:
	•	แสดงเวลาปัจจุบัน = base_work_seconds + (now - last_server_sync) (ในหน่วยวินาที)
	•	ถ้า status = paused:
	•	แสดงเวลาคงที่ = work_seconds จาก server เท่านั้น
	•	ไม่ต้องใช้ tick
	•	Resume:
	•	server จะ update DTO ใหม่ → frontend reload → BGTimeEngine เพิ่ม timer ใหม่จากค่า DTO ล่าสุด (ไม่ควร reuse stateเก่า)
	3.	ปรับเฉพาะ:
	•	BGTimeEngine.js (ถ้ามี bug)
	•	work_queue.js (ถ้าลืมเรียก register หรือ map data ผิด)

หลีกเลี่ยงการแก้ไข WorkSessionTimeEngine.php เว้นแต่เจอ bug mapping DTO ชัดเจน และต้องระบุใน comment ว่าแก้อะไร

⸻

6. Acceptance Criteria

ถือว่า Task 2.2 เสร็จเมื่อ:
	1.	Manual Test – Work Queue
	•	Start token → เวลาเริ่มวิ่งภายใน 1 วินาที โดยไม่ต้อง refresh
	•	Pause token → เวลาใน DOM หยุดเด้งทันที
	•	Resume token → เวลาเดินต่อแบบ smooth ไม่มีการกระโดดเป็นหลักนาที
	•	ทำซ้ำกับ token อื่น 2–3 ตัว → timers ทั้งหมดทำงานถูกต้อง
	2.	No Legacy Timer
	•	ไม่มีการใช้ setInterval / setTimeout เพื่ออัพเดต timer ด้วยตัวเองใน work_queue.js
	•	Timer ทำงานผ่าน BGTimeEngine เท่านั้น
	3.	No Console Errors
	•	ไม่มี error เกี่ยวกับ BGTimeEngine, undefined function, data attribute missing
	•	ถ้ามี log debug ให้เก็บในระดับ console.debug และถ้าไม่จำเป็นควรลบทิ้งก่อนจบงาน
	4.	ไม่มีผลข้างเคียงกับหน้าอื่น
	•	ถ้ามีการใช้ BGTimeEngine บนหน้าอื่นอยู่แล้ว หน้านั้นต้องไม่พัง
	•	ถ้าจำเป็นให้ทดสอบหน้าอื่นที่ใช้ BGTimeEngine อย่างน้อย 1 หน้า (ถ้ามี)
	5.	Documentation / Comment
	•	เพิ่ม comment สั้นๆ ใน BGTimeEngine.js อธิบาย contract data-* ที่ใช้
	•	ถ้าเปลี่ยน behavior สำคัญ ให้เพิ่ม note ใน docs/time_engine/TIME_ENGINE_V2.md หรือไฟล์ที่เกี่ยวข้อง

⸻

7. สรุปคำสั่งให้ Agent ทำ

ให้ Agent ทำงานตามลำดับนี้:

	1.	อ่าน:
	•	docs/time_engine/TIME_ENGINE_V2.md (ถ้ามี)
	•	docs/developer/02-quick-start/AI_QUICK_START.md
	•	docs/developer/02-quick-start/GLOBAL_HELPERS.md
	2.	เปิดไฟล์:
	•	assets/javascripts/pwa_scan/work_queue.js
	•	assets/javascripts/time/BGTimeEngine.js (หรือไฟล์จริงของ BGTimeEngine)
	•	source/dag_token_api.php
	•	source/model/WorkSessionTimeEngine.php (อ่านเฉพาะส่วน DTO)
	3.	วิเคราะห์สาเหตุอาการ:
	•	Start แล้วไม่วิ่งจน refresh
	•	Pause → Resume แล้วเวลาโดด
	4.	แก้โค้ดโดย:
	•	ปรับ work_queue.js ให้ map data + registerTimerElements ถูกต้อง
	•	ปรับ BGTimeEngine.js ให้ compute เวลา / handle register ซ้ำ ได้อย่างถูกต้อง
	•	ห้ามเปลี่ยน business logic การคิดเวลาจริง (เพียงแค่แก้ presentational logic / wiring)
	5.	รัน manual test:
	•	จำลอง flow Start → Pause → Resume จาก UI logic (หรือเขียน comment ว่าเวลาทดสอบจริงควรทำอะไรบ้าง)
	6.	สรุปใน commit message / comment:
	•	อธิบายสั้นๆ ว่า bug เกิดจากอะไร และแก้ยังไง

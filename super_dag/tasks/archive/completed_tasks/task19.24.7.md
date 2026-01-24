# Task 19.24.7 – JS History Slimming (Reduce Redundant `saveState()` Calls)

> **Goal:** ทำให้ Undo/Redo "คิดเหมือนผู้ใช้" มากขึ้นขั้นแรก โดยลดการเรียก `saveState()` ที่ซ้ำซ้อนหรือไม่จำเป็น โดย **ไม่เปลี่ยน behavior เชิงฟีเจอร์** และต้องไม่ทำให้กราฟพัง หรือ history ขาดตอน

---

## 1. Context & Scope

ไฟล์ที่เกี่ยวข้องใน Task นี้:

- `assets/javascripts/dag/graph_designer.js`
- `assets/javascripts/dag/modules/conditional_edge_editor.js`
- เอกสารอ้างอิง: `docs/super_dag/tasks/task19.24.6_state_map.md`

สิ่งที่เรารู้จาก **state_map**:

- มีหลายจุดที่เรียก `saveState()` ถี่เกินไป หรือถูกเรียกทั้งก่อนและหลัง action ตัวเดียวกัน
- บางจุดเป็นการเรียก `saveState()` จาก UI layer โดยที่ยังไม่ได้มีการเปลี่ยน graph จริง (เช่น แค่เปิด/ปิด panel)
- ผลลัพธ์คือ history ยาวเกินจำเป็น และ Undo 1 ครั้ง กระโดดกลับหลาย step ที่ผู้ใช้ไม่เข้าใจ

Task 19.24.7 จะ **ไม่แก้โครงสร้าง history ทั้งระบบ** (ยังไม่แตะเรื่อง grouping) แต่จะ:

- ลด redundant calls ที่ชัดเจน
- ย้ายบางจุดไปอยู่ timing ที่เหมาะสมขึ้น (หลัง commit การเปลี่ยนจริง)

---

## 2. Non-goals (สิ่งที่ยังไม่ทำใน Task นี้)

เพื่อไม่ให้หลุด scope:

- ❌ ยัง **ไม่** ทำ history grouping (เช่น add node + edit properties = 1 step) – จะทำใน Task 19.24.8
- ❌ ยัง **ไม่** แก้ชื่อฟังก์ชัน / เปลี่ยน signature ของ `saveState()` หรือ `restoreState()`
- ❌ ยัง **ไม่** เปลี่ยนรูปแบบของ state object ที่เก็บใน history
- ❌ ยัง **ไม่** ย้าย HistoryManager ออกไปไฟล์แยก (เป็นของ Task 19.24.9)

Task นี้คือ **ลดจำนวนการเรียก saveState() ให้ตรงกับ “การเปลี่ยนกราฟจริง” มากที่สุด** เท่าที่จะทำได้โดยไม่เปลี่ยน behavior อื่น

---

## 3. Guiding Principles

1. **หนึ่ง action ที่มีความหมายต่อผู้ใช้ = มากที่สุด 1 saveState()**
   - เช่น การลาก node แล้วย้ายตำแหน่งหลาย pixel → saveState แค่ตอน drag-end ไม่ใช่ทุก mousemove
   - การแก้ property ของ node ผ่าน panel → ให้มี save แค่ตอน "apply/confirm" ไม่ใช่ทุก keypress

2. **UI ที่ไม่เปลี่ยน graph ห้ามเรียก saveState()**
   - เปิด/ปิด side panel
   - เลือก tab ใน properties panel
   - เปิด modal แล้วกดยกเลิก

3. **ยึด state_map เป็น source of truth**
   - จุดไหนที่ state_map บอกว่า "saveState เรียกซ้ำซ้อน" ให้ลด
   - ถ้าไม่แน่ใจว่าจุดไหนควรลบ/คงไว้ ให้เพิ่ม comment แทนการเดา

4. **อย่าทำให้ behavior แย่ลง**
   - ถ้าเดิมทีมี Undo ได้ละเอียดอยู่แล้ว อย่าลบจนหายไปโดยไม่ตั้งใจ
   - ถ้าจุดไหนเสี่ยง ให้ใส่ TODO + comment ชัดเจน

---

## 4. Detailed Steps (สำหรับ AI Agent / Implementor)

### Step 4.1 – อ่านและทำสรุปจาก `state_map`

1. เปิด `docs/super_dag/tasks/task19.24.6_state_map.md`
2. สร้างสรุปสั้น ๆ (ในหัวหรือใน comment) ว่า:
   - ฟังก์ชัน / event handler ไหนใน `graph_designer.js` เรียก `saveState()`
   - ฟังก์ชัน / event handler ไหนใน `conditional_edge_editor.js` เรียก `saveState()`
   - จุดไหนที่ state_map ระบุว่า **redundant** หรือ **UI-only**

> **ข้อสำคัญ:** ห้ามเดาสุ่ม ต้องอิงจาก state_map + โค้ดจริงเท่านั้น

---

### Step 4.2 – จัดกลุ่มประเภทการเรียก `saveState()`

ใน `graph_designer.js` และ `conditional_edge_editor.js` ให้จัดกลุ่มการเรียก `saveState()` ตามประเภท:

1. **Graph Mutation จริง (ควรมี saveState)**
   - เพิ่ม/ลบ node
   - เพิ่ม/ลบ edge
   - เปลี่ยน property ของ node/edge แล้ว commit

2. **Graph Mutation จาก Interaction ต่อเนื่อง**
   - Drag node
   - Resize หรือ move group (ถ้ามี)

3. **UI-only / Config-only** (มักจะไม่ควรมี saveState)
   - เปิด/ปิด panel
   - เปลี่ยน tab
   - เปิด dialog แล้วกดยกเลิก

4. **Redundant double-save**
   - ฟังก์ชัน A เรียก `saveState()` แล้วฟังก์ชัน B ที่เรียก A ก็เรียก `saveState()` อีก
   - การเรียก `saveState()` ทั้งก่อนและหลัง mutation เดียวกัน

จากนั้น **เขียน comment สั้น ๆ** ใกล้แต่ละกลุ่มที่จะเปลี่ยน เช่น:

```js
// Task 19.24.7: This saveState() is redundant (UI-only), will be removed.
// Task 19.24.7: This saveState() is candidate for moving to commit-time.
```

---

### Step 4.3 – ลบ / ย้าย saveState() ที่เป็น UI-only หรือ redundant

1. **ลบ saveState() ที่เกิดจาก UI-only events**
   - เช่น การเปิด/ปิด panel, toggle advanced view, etc.
   - ถ้าไม่แน่ใจว่า UI นั้นมีผลกับ graph state จริงหรือไม่ → ตรวจโค้ดก่อนลบ

2. **ลบการเรียกซ้ำซ้อนใน function call chain**
   - ถ้า `onNodePropertyChanged()` เรียก `saveState()` แล้ว `onPropertyPanelSubmit()` ก็เรียกด้วย → ต้องเหลือแค่ 1 แห่ง
   - เลือกจุดที่ใกล้ "จบ action" มากที่สุด (เช่น submit/confirm)

3. **สำหรับ drag/move** (หากมีการเรียก `saveState()` ใน `mousemove`/`drag`):
   - ย้ายไปเรียกเฉพาะตอน drag-end (เช่น `mouseup`, `dragend`)
   - ถ้าตอนนี้ยังไม่มีการเรียกเลย ให้แค่ note ไว้ (อย่าเพิ่ม behavior ใหม่ใน Task นี้ ถ้า logic ยังไม่พร้อม)

> ถ้าเจอกรณีเสี่ยง ให้คอมเมนต์แทนการลบทิ้ง เช่น:
>
> ```js
> // Task 19.24.7 NOTE: This saveState() might be redundant, but kept for now for safety.
> // To be revisited in Task 19.24.8 (history grouping).
> ```

---

### Step 4.4 – ปรับให้ `conditional_edge_editor.js` เรียก saveState เฉพาะตอน commit

ใน `conditional_edge_editor.js`:

1. ตรวจให้แน่ใจว่า **แก้ condition เฉย ๆ (พิมพ์ข้อความ/เปลี่ยน dropdown) แต่ยังไม่กด "Save" หรือ "Apply"** → ไม่ควรเรียก `saveState()`
2. ให้ `saveState()` ถูกเรียกจากจุดที่ "graph ถูก update จริง" เท่านั้น เช่น:
   - ตอน user กดปุ่ม "Save" หรือ "Apply" ของ edge condition
   - หลังจาก edge condition ถูก serialize และส่งกลับไปให้ graph core

ถ้ามีการเรียก `saveState()` ใน onChange/onInput → ให้พิจารณาย้ายไปจุด commit

---

### Step 4.5 – Manual Sanity Check (คิดแบบผู้ใช้)

หลังจากแก้โค้ดแล้ว ให้ทดสอบแบบ manual (ไม่ใช่แค่ unit test):

1. สร้างกราฟง่าย ๆ:
   - START → OP1 → QC → FINISH
2. ทดสอบ:
   - เพิ่ม node ใหม่ → Undo → node ต้องหายไปทีเดียว
   - แก้ชื่อ node 1 ครั้ง → Undo → ชื่อกลับค่าเดิมใน 1 ครั้ง ไม่ใช่ 2–3 ครั้ง
   - เปิด/ปิด panel หลายครั้ง → Undo → ไม่ควรเปลี่ยน graph เลย

ถ้าพบว่า Undo/Redo ทำงาน "แย่ลง" (เช่น ย้อนกลับไม่ครบ หรือกระโดดแปลก ๆ) ต้อง:

- ถอยการแก้จุดนั้น
- หรือเพิ่ม comment แจ้งไว้ให้ชัดว่า **ต้องรอ Task 19.24.8 แก้แบบโครงสร้าง**

---

## 5. Acceptance Criteria

Task 19.24.7 จะถือว่าสำเร็จเมื่อ:

1. ✅ จำนวนจุดที่เรียก `saveState()` ใน `graph_designer.js` และ `conditional_edge_editor.js` ลดลงจากเดิมอย่างชัดเจน (โดยเฉพาะ UI-only)
2. ✅ ไม่มี `saveState()` ที่ถูกเรียกจาก event ที่ไม่เปลี่ยน graph state จริง (เช่น แค่เปิด/ปิด panel)
3. ✅ Undo 1 ครั้ง ไม่ควรกระโดดผ่าน state ที่ผู้ใช้ "ไม่เห็นว่าเป็นการเปลี่ยนกราฟ" (เช่น เปิด/ปิด panel เฉย ๆ)
4. ✅ Unit tests และ SuperDAG validation tests ทั้งชุด **ต้องผ่านทั้งหมด**
5. ✅ Manual test บน Graph Designer จริง ยังสามารถ:
   - เพิ่ม/ลบ node
   - แก้ conditions บน conditional edge
   - ใช้ Undo/Redo แล้วได้ผลลัพธ์เหมือนเดิมหรือดีกว่าเดิม (ไม่แย่ลง)
6. ✅ มีการเพิ่ม/อัปเดตเอกสารสั้น ๆ ใน `task19.24.7_results.md` (หรือใน task index) เพื่อบันทึกว่า saveState ถูก slim แล้ว

---

## 6. Notes สำหรับ Task ถัดไป

หลังจบ 19.24.7:

- 19.24.8 จะต่อยอดจากจุดนี้ โดยเน้น **history grouping** (1 action = 1 logical history step)
- 19.24.9 จะเน้นการ **แยก HistoryManager ออกมาเป็น module** ทำให้โค้ด JS สะอาดและ maintain ได้ง่ายขึ้น

Task นี้คือก้าวแรกในการทำให้ Undo/Redo ของ SuperDAG **"ฉลาดในแบบที่ผู้ใช้รู้สึกได้"** แต่ยังคงความปลอดภัยสูงสุดในเชิง behavior

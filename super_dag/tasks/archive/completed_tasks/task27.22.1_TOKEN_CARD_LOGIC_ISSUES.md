# Task 27.22.1: Token Card Logic Issues (Backlog)

> **Status:** 📋 BACKLOG - จะย้อนกลับมาทำภายหลัง  
> **Created:** 2025-12-08  
> **Discovered During:** Task 27.22 Token Card Component Refactor  
> **Priority:** Medium (ไม่ block production แต่ควรแก้ไข)

---

## 🔍 Issues ที่พบระหว่าง Review

### Issue 1: QC Node Business Rule ยังไม่ชัดเจน

**ปัญหา:**
```javascript
// TokenCardParts.js - renderActionButtons()
if (state.isQcNode) {
    if ((state.isReady || state.isInProgress) && canAct) {
        // Pass/Fail buttons
    }
}
```

**คำถาม:**
- QC token ที่ไม่ได้ assign → ทุกคน Pass/Fail ได้?
- หรือ QC ควร assign ให้เฉพาะ QC inspector เท่านั้น?

**ผลกระทบ:**
- ถ้าทุกคนทำ QC ได้ → อาจมีคนที่ไม่ใช่ QC inspector กด Pass/Fail
- ถ้าเฉพาะ QC inspector → token ที่ไม่ assign จะไม่มีปุ่ม

**แนวทางแก้ไข (เมื่อย้อนกลับมา):**
1. ถามผู้ใช้ว่า Business Rule คืออะไร
2. อาจต้องเพิ่ม `isQcInspector` field ใน state
3. แก้ logic ใน `renderActionButtons()` ให้ตรงกับ rule

---

### Issue 2: Material Warning แสดงเฉพาะ Ready Tokens

**ปัญหา:**
```javascript
// TokenCardParts.js - renderMaterialWarning()
if (!state.warnings.hasMaterialShortage || !state.isReady) return '';
```

**คำถาม:**
- ถ้า token กำลัง in_progress แต่มี material shortage (case partial reserve) → ต้องแสดง warning ไหม?

**ผลกระทบ:**
- อาจมี case ที่ in_progress token ขาด material แต่ไม่มี warning แสดง

**แนวทางแก้ไข (เมื่อย้อนกลับมา):**
1. ตรวจสอบว่า partial reserve เป็นไปได้หรือไม่
2. ถ้าเป็นไปได้ → แสดง warning สำหรับทุก status
3. แต่อาจใช้ style ต่างกัน (ready = red, in_progress = yellow)

---

### Issue 3: Timer Data Attributes Contract ยังไม่มี Document

**ปัญหา:**
```javascript
// TokenCardParts.js - renderTimer()
<span class="work-timer work-timer-active" 
      data-token-id="${state.id}"
      data-started="${session.started_at}"
      data-pause-min="${time.totalPauseMinutes}"
      data-work-seconds-base="${time.baseWorkSeconds}"
      data-work-seconds-sync="${time.workSeconds}"
      data-last-server-sync="${time.lastServerSync || ''}"
      data-status="active">
```

**คำถาม:**
- BGTimeEngine ใช้ data attributes เหล่านี้ทั้งหมดหรือไม่?
- มี attribute ไหนที่ BGTimeEngine ต้องการแต่ยังไม่มี?

**ผลกระทบ:**
- Timer อาจ drift หรือ sync ไม่ถูกต้อง

**แนวทางแก้ไข (เมื่อย้อนกลับมา):**
1. ตรวจสอบ `BGTimeEngine.js` ว่าใช้ attributes อะไรบ้าง
2. สร้าง Data Attributes Contract document
3. ปรับ `renderTimer()` ให้ match กับ contract

---

### Issue 4: data-job-id Field Name อาจไม่ตรง

**ปัญหา:**
```javascript
// TokenCardLayouts.js
data-job-id="${token.job_ticket_id || ''}"
```

**คำถาม:**
- Token data ใช้ `job_ticket_id` หรือ `id_job_ticket` หรือ `job_id`?

**ผลกระทบ:**
- `data-job-id` อาจเป็นค่าว่างเสมอ

**แนวทางแก้ไข (เมื่อย้อนกลับมา):**
1. ตรวจสอบ API response ว่า field name คืออะไร
2. ปรับ code ให้ match

---

### Issue 5: renderActionButtons Logic Consistency

**ปัญหา (แก้ไขไปแล้ว แต่ควร verify):**
```javascript
// TokenCardParts.js
if (state.isInProgress && canAct) {  // ← Pause เช็ค canAct
if (state.isPaused && canAct) {      // ← Resume เช็ค canAct
if (state.isReady && !state.isWaiting) {  // ← Start ไม่เช็ค canAct
```

**คำถาม:**
- Logic ถูกต้องหรือไม่หลังจากแก้ `canActOnToken()`?
- Start ไม่เช็ค canAct เพราะ token ที่ ready + no assignment → ทุกคน start ได้?

**แนวทางแก้ไข (เมื่อย้อนกลับมา):**
1. Verify ว่า logic ทำงานถูกต้องในทุก case
2. เขียน unit test สำหรับ `canActOnToken()` และ `renderActionButtons()`

---

## 📁 Files ที่เกี่ยวข้อง

- `assets/javascripts/pwa_scan/token_card/TokenCardState.js`
- `assets/javascripts/pwa_scan/token_card/TokenCardParts.js`
- `assets/javascripts/pwa_scan/token_card/TokenCardLayouts.js`
- `assets/javascripts/pwa_scan/token_card/TokenCardComponent.js`
- `assets/javascripts/pwa_scan/work_queue.js`
- `assets/javascripts/dag/BGTimeEngine.js` (ต้องตรวจสอบ)

---

## ✅ Issues ที่แก้ไขแล้ว (ระหว่าง Review)

| Issue | Status | Description |
|-------|--------|-------------|
| `openWorkModal` ไม่ export | ✅ Fixed | เพิ่ม `window.openWorkModal` |
| `canActOnToken()` logic ผิด | ✅ Fixed | เพิ่ม condition `!state.assignedToName` |
| Duplicate code ใน layouts | ✅ Fixed | สร้าง `encodeTokenData()` helper |

---

## 📋 Action Items (เมื่อย้อนกลับมา)

1. [ ] ตัดสินใจ QC Business Rule
2. [ ] ตรวจสอบ Material Warning requirement
3. [ ] สร้าง Timer Data Attributes Contract
4. [ ] ตรวจสอบ job_id field name ใน API
5. [ ] เขียน unit tests สำหรับ TokenCardState & TokenCardParts
6. [ ] Verify logic ทำงานถูกต้องในทุก case

---

## 🔗 Related Tasks

- Task 27.22: Token Card Component Refactor (Parent)
- Task 27.20: Work Modal Behavior
- Task 27.21: Material Integration



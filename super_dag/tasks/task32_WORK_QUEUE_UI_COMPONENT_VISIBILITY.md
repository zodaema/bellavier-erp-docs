# Task 32: Work Queue UI — Component Visibility + “Natural Flow” UX

**Status:** 📋 **TODO**  
**Priority:** 🔴 **CRITICAL**  
**Category:** Work Queue UI / Operator UX / Component Parallel Flow  
**Date:** January 2026  
**Depends On:** Task 30.1–30.3 (backend deterministic + split/merge runtime)

---

## Executive Summary

**Goal:** ทำให้หน้า Work Queue รองรับ “Component Parallel Flow” แบบปลอดภัยต่อผู้ใช้จริง โดย
- default **ไม่แสดง component tokens** (กันสับสน)
- มีทางเปิดดู/ทำงานกับ component tokens แบบ **ตั้งใจ** (explicit)
- UI แสดงบริบทที่ “มนุษย์เข้าใจง่าย”: งานนี้คือ **FINAL** หรือ **COMPONENT** อะไร, ผูกกับอะไร, และกำลังรอใคร

**Key Constraint (SSOT):**
- API already supports visibility policy via `include_component_tokens=1` (Task 30.1)
- Component identity SSOT = `flow_token.component_code` (Task 30.3)

**Reference (Current Code):**
- Page: `page/work_queue.php`
- View: `views/work_queue.php`
- JS: `assets/javascripts/pwa_scan/work_queue.js`
- API: `source/dag_token_api.php` (`get_work_queue`)

---

## Scope

### Included
- เพิ่ม UI control “แสดงงาน Component” (toggle) โดย default ปิด
- ส่งพารามิเตอร์ `include_component_tokens=1` ไปที่ `get_work_queue` เมื่อ user เปิด toggle
- แสดง label/badge บน token card:
  - `token_type` (piece/component/batch)
  - `component_code` (เมื่อ token_type=component)
  - `parent_token_id` (แสดงแบบ human-friendly: “belongs to FINAL: <serial>” ถ้ามีข้อมูลพอ)
- ปรับการกรอง/การจัดกลุ่มให้ไม่ทำให้ operator สับสน

### Excluded (Not now)
- ทำหน้า UI แยกใหม่ทั้งหมด
- เปลี่ยน permission model ครั้งใหญ่ใน backend

---

## UX Policy (สำคัญมาก — ต้องเขียนก่อนลงมือ)

### Default Behavior (Safety First)
- Toggle “Show Component Tasks” = **OFF**
- Work Queue แสดงเฉพาะ FINAL tokens (และ token_type อื่นที่เป็นงานหลักของ user ตาม flow ปัจจุบัน)

### Explicit Opt-in
- ถ้า user เปิด toggle:
  - Work Queue จะ include component tokens
  - UI ต้องใส่ visual cues ชัดเจนว่าเป็น “Component Task”

### What user must always understand
- **ฉันกำลังทำงานกับชิ้นไหน** (FINAL vs COMPONENT)
- **ถ้าเป็น COMPONENT**: เป็น component อะไร (`component_code`) และผูกกับ final ตัวไหน
- **ถ้าเป็น FINAL ที่กำลังรอ merge**: อธิบายว่า “รอ component อะไรอยู่” (phase ถัดไป—ต้องพึ่ง `ComponentFlowService::getSiblingStatus`)

---

## Implementation Plan (Step-by-step)

### Step 1 — UI Controls (View layer)
**File:** `views/work_queue.php`
- เพิ่ม checkbox toggle ในแถว filter (ใกล้ `#hideScrappedTokens`)
  - id แนะนำ: `#showComponentTokens`
  - copy ต้องผ่าน i18n:
    - `work_queue.filter.show_components` → default English: `Show component tasks`

**Expected UX:**
- Desktop: อยู่ใน filter bar
- Mobile: อยู่ใน filter bar เหมือนกัน (แต่ระวังพื้นที่)

### Step 2 — Wire toggle to API request
**File:** `assets/javascripts/pwa_scan/work_queue.js`
- ใน `loadWorkQueue()` เพิ่ม `include_component_tokens` ใน payload:
  - `include_component_tokens: $('#showComponentTokens').is(':checked') ? 1 : 0`
- bind event:
  - `$('#showComponentTokens').on('change', () => loadWorkQueue({ showLoading:false }));`

### Step 3 — Rendering: make component tokens visually distinct
**File:** `assets/javascripts/pwa_scan/work_queue.js` (renderer / TokenCard)
- เมื่อ token มี `token_type === 'component'`:
  - เพิ่ม badge เช่น `COMPONENT • BODY`
  - ลดโอกาสกดผิด:
    - สี/ขอบต่างจาก FINAL
    - แสดง hint: “Part of FINAL-xxx”

> หมายเหตุ: ตอนนี้ API ส่ง `token_type/component_code/parent_token_id` แล้ว แต่ UI ยังไม่ได้ใช้

### Step 4 — Grouping strategy (ขั้นต่ำ)
**Default (toggle OFF):**
- เหมือนเดิม (group by node)

**When toggle ON:**
ตัวเลือก A (ง่ายสุด):
- ยัง group by node เหมือนเดิม แต่ component tokens มี badge ชัด ๆ

ตัวเลือก B (อ่านง่ายขึ้น):
- group by node → ภายใน node แยก section:
  - FINAL tasks
  - COMPONENT tasks

**Recommendation:** เริ่มด้วย **A** เพื่อไม่เสี่ยง refactor เยอะ แล้วค่อย evolve เป็น B เมื่อข้อมูล sibling status พร้อม

### Step 5 — Copy & i18n
เพิ่ม key ใน lang:
- `work_queue.filter.show_components` = `Show component tasks`
- `work_queue.badge.component` = `Component`
- `work_queue.badge.final` = `Final`
- `work_queue.component.belongs_to` = `Belongs to final`

---

## Acceptance Criteria

- [ ] ค่า default: UI ไม่แสดง component tokens
- [ ] เปิด toggle แล้ว: UI ส่ง `include_component_tokens=1` และเห็น component tokens
- [ ] component tokens มี visual distinction ชัดเจน + แสดง `component_code`
- [ ] ไม่มีการใช้ `alert()/confirm()` และยังใช้ SweetAlert2/toast ตามมาตรฐาน
- [ ] Smoke test manual: operator ใช้งานแล้วไม่สับสนว่า token ไหนเป็น final/component

---

## User Simulation (มุมมองผู้ใช้จริง — อ่านง่าย)

### Persona A: ช่างเย็บ “BODY” (ทำงาน component ก่อน assembly)
1) เปิดหน้า Work Queue  
2) เห็นคิวงาน “STITCH BODY” เป็นงานหลักของตัวเอง  
3) ตอนแรก **ไม่ต้องเห็นงาน component label อะไรให้รก** (เพราะคิวนี้ของสถานี BODY อยู่แล้ว)
4) แต่ถ้าผู้จัดการบอกว่า “วันนี้ต้องเร่ง BODY ของ FINAL-0007”  
   - ช่างเปิด toggle “Show component tasks”  
   - เห็น card ที่ติด badge `COMPONENT • BODY` และมีข้อความ “Belongs to FINAL-0007”  
   - กดเข้า modal แล้วทำงานต่อ (Start/Complete) เหมือนเดิม

**ผลลัพธ์ที่คนใช้รู้สึก:** “ฉันรู้ว่ากำลังทำ BODY ของชิ้นไหน และไม่สับสนกับ FINAL”

### Persona B: ช่างประกอบ (ASSEMBLY) — ต้องเห็นเฉพาะ FINAL ที่พร้อมจริง
1) เปิด Work Queue ที่สถานี ASSEMBLY  
2) default toggle OFF → เห็นเฉพาะ FINAL tokens ที่ถึง node assembly แล้ว (`ready`)  
3) FINAL ที่ “ยังรอ component” จะไม่โผล่มาหลอกให้เริ่มงาน

**ผลลัพธ์ที่คนใช้รู้สึก:** “งานที่โผล่มาคือทำได้เลย ไม่เสียเวลาไล่ถามว่า component ครบไหม”

### Persona C: หัวหน้าไลน์ — ต้อง diagnose แบบเร็ว
1) เปิด Work Queue แล้วเปิด toggle “Show component tasks”  
2) เห็นว่า FINAL-0007 อยู่สถานะ waiting (อยู่ split หลังแตกงาน)  
3) เห็น component tokens บางตัวค้างอยู่ที่ node ก่อน merge  
4) ใช้ข้อมูลนี้ไปสั่งงาน/ย้ายคนช่วย/เร่งสถานีคอขวด

**ผลลัพธ์ที่คนใช้รู้สึก:** “ฉันเห็นภาพรวมว่า ‘ติดที่ component ไหน’ ได้เร็ว”

---

## Notes / Risks

- ถ้าเปิด component tokens ให้ทุกคนเห็นโดย default → เสี่ยงสับสนสูงมาก (จึงต้อง default OFF)
- ในอนาคตเมื่อ `ComponentFlowService::getSiblingStatus()` ทำจริง:
  - UI สามารถแสดง “Missing components: BODY, FLAP” บน FINAL card ได้ (จะยิ่งเข้าใจง่าย)

---

**Next Step (Implementation):** หลังคุณ approve แผนนี้ → เริ่มแก้ `views/work_queue.php` + `assets/javascripts/pwa_scan/work_queue.js` ตาม Step 1–3 ก่อน


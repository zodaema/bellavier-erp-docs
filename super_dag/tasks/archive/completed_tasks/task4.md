

# Task 4 — Behavior-Aware UX Layer (Pre‑Execution Phase)

**Status:** IN PROGRESS  
**Owner:** Super DAG Core  
**Purpose:** เปลี่ยน UX จาก generic → behavior-aware โดยไม่แตะ execution logic

---

# 🎯 Objective

Task 4 มีหน้าที่ “ยกระดับ UI ให้ฉลาดขึ้นตาม Work Center Behavior”  
โดยที่ **ยังไม่แตะ Token Engine, Time Engine, DAG Execution Logic**

UI ตอนกดทำงานของช่างใน Work Queue / PWA / Job Ticket ต้อง “รู้ว่า Node นี้มี behavior อะไร” และแสดง UI ที่เหมาะสม

นี่เป็น Phase เตรียมตัวก่อนเข้าสู่ Execution Engine (Task 5–10)

---

# 🧠 Scope

## What’s Included
- Behavior-aware UI templates
- Dynamic UI loading by `behavior_code`
- Work Queue / PWA / Job Ticket / Token Popup integration
- JS template registry
- Non-breaking backend (read-only)

## What’s NOT included
- No token state updates  
- No execution rules  
- No batch→single logic  
- No time engine changes  
- No splitting/merging  
- No QC logic  
- No component serial binding execution  

---

# 📐 Behavior Templates To Implement

Behavior Template คือ UI ส่วนที่เพิ่มเข้ามา “เฉพาะ behavior นั้น”  
เพื่อเตรียม execution logic ใน Task 5+

## ✔ CUT (Batch)
Fields:
- จำนวนที่ผลิตได้ (input: integer)
- จำนวนที่เสีย (input: integer)
- สาเหตุการผลิตไม่ครบ (textarea)
- เลือกหนังล็อตที่ใช้ (optional)

UI Type:
- Form overlay panel

---

## ✔ STITCH (Hatthasilpa Single)
Fields:
- เวลาเริ่มงาน (read)
- ปุ่ม Start / Pause / Resume (Time UI)
- สาเหตุ pause (dropdown)
- หมายเหตุ (textarea)

UI Type:
- Sidebar panel merged with time-control UI

---

## ✔ EDGE (Edge Paint)
Fields:
- รอบที่ทา (1 / 2 / 3)
- สถานะแห้ง (wet/dry toggle)
- สีที่ใช้ (read)
- การแก้ไขจุดบกพร่อง (textarea)

UI Type:
- Step-based mini-layer UI

---

## ✔ HARDWARE_ASSEMBLY
Fields:
- Serial ของ hardware ที่ต้อง bind
- ตรวจล็อต hardware
- ปัญหา hardware mismatch (checkbox)

UI Type:
- Horizontal component strip

---

## ✔ QC_SINGLE / QC_FINAL
Fields:
- defect code dropdown (dynamic later)
- สาเหตุ defect
- ปุ่มส่งกลับไป node ก่อนหน้า
- ปุ่ม mark-pass

UI Type:
- QC mini-console panel

---

# 🗂 Files to Modify

## JS (main)
- `assets/javascripts/pwa_scan/pwa_scan.js`
- `assets/javascripts/pwa_scan/work_queue.js`
- `assets/javascripts/hatthasilpa/job_ticket.js`

## JS (new)
- **`assets/javascripts/dag/behavior_ui_templates.js`**
  - Registry ของ behavior → UI template HTML
  - Registry ของ behavior → JS Handlers

## PHP
- ไม่มีการแก้ logic  
- เพียงตรวจสอบว่า behavior metadata ส่งมาจาก Task 3 แล้ว

## Views
- Minor: inject template containers into Work Queue / PWA / Job Ticket

---

# 🧩 Implementation Plan

## Step 1 — Create Template Registry
สร้างไฟล์ใหม่:
`assets/javascripts/dag/behavior_ui_templates.js`

Expose global:
```
window.BGBehaviorUI = {
    templates: {},
    handlers: {},
    registerTemplate(behavior, html),
    registerHandler(behavior, handlerObject)
}
```

## Step 2 — Register UI per behavior_code
Example:
```
BGBehaviorUI.registerTemplate("CUT", `
   <div class="behavior-cut-form">
      <label>จำนวนที่ผลิตได้</label><input type="number" />
      <label>จำนวนที่เสีย</label><input type="number" />
      <label>หมายเหตุ</label><textarea></textarea>
   </div>
`);
```

## Step 3 — Inject UI into Work Queue Token Popup
- รับ behavior_code จาก dag_token_api
- โหลด template จาก BGBehaviorUI
- แสดงที่ container ใหม่: `#behavior-panel`

## Step 4 — Apply Same Logic to:
- PWA Scan screen
- Job Ticket
- Token Detail view

## Step 5 — Test Coverage
Manual tests:
- เปิดทุก token ทุก behavior → UI ต้องเปลี่ยน
- Behavior ที่ไม่มี template → fallback เป็น default UI
- Template ไม่มี JS → ไม่พัง
- Mobile PWA → responsive

---

# 🛡 Safety Rails

- ❌ ห้ามแตะ execution engine  
- ❌ ห้ามสร้าง state ใหม่  
- ❌ ห้าม normalise ช้อมูล behavior  
- ❌ ห้ามเขียน logic แทนช่าง  
- ✔ เฉพาะ UI layer  
- ✔ behavior metadata read-only  
- ✔ JS-only changes  

---

# 📦 Deliverables

1. `behavior_ui_templates.js` (ใหม่)
2. UI integration ใน Work Queue / PWA / Job Ticket
3. fallback safe UI
4. `task4_results.md` (ผลลัพธ์หลังทำ)
5. Update `task_index.md`

---

# ✔ Definition of Done

- Behavior UI template ทำงานในทุกจุดที่เกี่ยวข้อง
- UI ไม่ error ถ้า behavior ไม่มี template
- Token popup มี behavior panel
- Work Queue card → แสดง icon behavior
- PWA Scan → แสดง UI เฉพาะ behavior
- Job Ticket → แสดง UI เฉพาะ behavior
- เอกสารผลลัพธ์ถูกสร้าง
คุณคือ Senior Systems Engineer + Auditor
หน้าที่ของคุณคือ “อ่าน – วิเคราะห์ – ชี้ต้นตอ – เสนอทางแก้ขั้นต่ำ”
ห้าม patch โค้ดก่อนเข้าใจระบบ
ห้ามแก้แบบเพิ่ม guard ซ้อน
ห้ามเพิ่ม timeout / window / lock เพิ่มอีก

====================================================
PHASE 0 — CONTEXT (ต้องเข้าใจก่อนทำอะไร)
====================================================

ระบบนี้คือ DAG Graph Designer ที่มี:
- Published versions (immutable snapshots)
- Draft (mutable)
- UI มี GraphVersionController + GraphSidebar + GraphLoader
- Backend มี hard guarantee แล้ว:
  - graph_save ห้าม publish
  - publish ต้องผ่าน graph_publish เท่านั้น

**ปัญหาปัจจุบัน (FACT ไม่ใช่สมมติ):**
1. เข้า page ครั้งแรก → Draft เปิดได้ (หลัง boot-fix)
2. เมื่อ user สลับไป Published (v3.0)
3. เมื่อ user พยายามสลับกลับ Draft (v4.0)
   → selector “เด้งกลับ” ไป Published เสมอ
4. Backend log ยืนยันว่า draft ถูกโหลดจริง
5. แต่ UI state ถูก override หลังจากนั้น

**สำคัญ:**  
- API ไม่ผิด
- Data ไม่ผิด
- Draft load สำเร็จ
- Bug อยู่ที่ UI state orchestration

====================================================
PHASE 1 — READ FIRST (ห้ามข้าม)
====================================================

ให้คุณอ่านไฟล์ audit นี้ให้เข้าใจเชิงสถาปัตยกรรมก่อน:
docs/super_dag/security/SECURITY_HARD_GUARANTEE_PATCH.md

เป้าหมายของ audit:
- แยก write path (draft / publish)
- สร้าง source of truth ที่ backend
- ลด accidental publish

❗ Audit นี้ “ไม่ใช่” สาเหตุของ selector เด้ง
แต่ต้องใช้เป็น constraint:  
> **ห้ามเสนอ solution ที่ทำให้ draft/published เขียนปนกัน**

====================================================
PHASE 2 — DIAGNOSIS (ห้าม patch)
====================================================

ให้คุณตอบคำถามต่อไปนี้เป็นข้อ ๆ พร้อมหลักฐานจาก log/flow:

1. Source of truth ของ “current version” ตอนนี้คืออะไร?
   - GraphVersionController?
   - graph_designer global state?
   - GraphSidebar selection?
   - lastLoadIntent?
   - currentIdentity?

2. ใครคือผู้เรียก `selectGraph()` หลังจาก user action?
   - user event?
   - sidebar_autoselect?
   - initGraphSidebar?
   - async callback?

3. ทำไม log ถึงแสดงลำดับนี้:
   - handleGraphLoaded → Showing draft mode
   - แล้ว selector state ถูก revert กลับ published

4. ปัญหานี้คือ:
   - race condition?
   - state overwrite?
   - multiple authorities?
   - missing single source of truth?

ตอบเป็น sequence diagram (ข้อความ) ได้

====================================================
PHASE 3 — ROOT CAUSE (บังคับเลือก 1)
====================================================

คุณต้องเลือก “ต้นตอหลัก” เพียงข้อเดียว:
A) Draft lock window สั้นเกิน (ถ้าเลือก ต้องอธิบายว่าทำไม 15s ยังไม่พอ)
B) selector state ถูกควบคุมจากหลาย controller
C) published-first design flaw (ยังเหลืออยู่)
D) ไม่มี canonical version state
E) อื่น ๆ (ต้องอธิบายว่าทำไมข้ออื่นไม่ใช่)

❗ ห้ามตอบหลายข้อ
❗ ห้ามพูดกลาง ๆ

====================================================
PHASE 4 — FIX STRATEGY (NO CODE YET)
====================================================

เสนอแนวทางแก้ **เพียง 1 แนวทาง** ที่:
- ไม่เพิ่ม guard ซ้อน
- ไม่เพิ่ม timeout
- ไม่เพิ่ม flag ชั่วคราว
- ไม่พึ่ง heuristic (เช่น recentUserDraftPick)

แนวทางต้องตอบให้ได้:
- ใครเป็น owner ของ version state
- ใคร “ห้าม” เขียน state
- event ไหนต้องถูก ignore แบบถาวร

ถ้าคำตอบคือ “ต้อง refactor”:
- ระบุชัดว่า refactor อะไร
- scope แค่ไหน
- file ใดเป็น canonical

====================================================
PHASE 5 — MINIMAL PATCH PLAN
====================================================

ถ้า (และเฉพาะถ้า) fix strategy ผ่าน:
- เสนอ patch ขั้นต่ำ (≤ 2 จุด)
- ไม่แก้หลายไฟล์
- ไม่แตะ backend

Patch plan ต้องบอก:
1. File
2. Function
3. Logic ที่ “ถูกลบออก” (สำคัญกว่าที่เพิ่ม)
4. Expected log หลังแก้ (published request ต้องไม่ถูกยิงอีก)

====================================================
PHASE 6 — SAFETY CHECK
====================================================

ตอบให้ชัด:
- หลัง fix นี้ มีโอกาสไหมที่:
  - draft save ไปเขียน published?
  - publish ถูก trigger โดย UI bug?
  - job runtime อ่าน graph ผิด version?

ถ้ามี → fix strategy ถือว่า FAIL

====================================================
OUTPUT FORMAT (บังคับ)
====================================================

- Diagnosis (bullet)
- Root cause (เลือก 1)
- Fix strategy (1 paragraph)
- Minimal patch plan (numbered)
- Safety confirmation (yes/no + reason)

ห้ามเขียน code ก่อนผ่าน Phase 2–4
ห้าม patch แบบทดลอง
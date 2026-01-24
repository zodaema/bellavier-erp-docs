# Task 19.24.6 — Undo/Redo Hardening (SuperDAG Graph Designer)

## Objective

ทำให้ระบบ **Undo / Redo** ของ SuperDAG Graph Designer:
- เชื่อถือได้
- ไม่ทำ state เพี้ยน
- ทำงานร่วมกับ validate / autofix / apply-fix ได้อย่างถูกต้อง

โดย **ไม่เปลี่ยน UX** (ตำแหน่งปุ่ม / shortcut ยังเหมือนเดิม)

---

## Scope

### 1) Map ปัจจุบันของ Undo/Redo

ให้ AI Agent ทำ:

1. ค้นหาใน `graph_designer.js` และ modules ที่เกี่ยวข้อง:
   - ฟังก์ชันในกลุ่ม:
     - `undo`, `redo`
     - `pushHistory`, `saveHistory`, `applyHistoryState`
     - `historyStack`, `historyIndex`, `undoStack`, `redoStack`
   - จุดที่เรียก `pushHistory(...)`:
     - ตอนสร้าง node / edge
     - ตอนลบ node / edge
     - ตอนแก้ properties ของ node / edge
     - ตอนใช้ autofix / apply fixes
     - ตอนแก้ condition ใน `conditional_edge_editor`

2. สร้างเอกสาร `docs/super_dag/tasks/task19.24.6_state_map.md`:
   - อธิบาย:
     - แหล่งกำเนิด state (canvas, side panel, conditional editor)
     - จุดที่เขียนเข้า history
     - จุดที่ **ไม่** เขียนเข้า history (gaps)
     - ลักษณะ state object แต่ละ entry

### 2) ปิดรูรั่ว basic ก่อน

ให้ AI Agent:

1. ตรวจสอบว่า **ทุก action ที่เปลี่ยน graph จริง ๆ** ต้องเรียก `pushHistory()`:
   - เพิ่ม node
   - ลบ node
   - เพิ่ม edge
   - ลบ edge
   - แก้ properties สำคัญ (work_center, behavior, execution_mode, parallel flags, merge flags)
   - แก้ condition ของ conditional edge (หลังจากกด Save ใน editor)

2. ถ้าพบ action ที่เปลี่ยน state แต่ไม่เรียก `pushHistory()`:
   - ให้เพิ่มการเรียก `pushHistory()` ในจุดนั้น
   - หรือถ้ามี helper เช่น `applyGraphChange()` อยู่แล้ว ให้หักเข้าทาง helper กลาง

3. ตรวจสอบว่า:
   - หลัง `graph_autofix` + `graph_apply_fixes` (ที่รับ state จาก backend)  
     → ต้องมีการ push history entry หนึ่งครั้ง **หลัง** apply graph ใหม่สำเร็จ

### 3) กัน Undo/Redo ชนกับ Validation & Autofix

1. ตรวจสอบ flow:
   - ถ้า user:
     - แก้กราฟ → validate → autofix → apply fixes → undo → redo
   - ต้องไม่เกิด:
     - JS error
     - graph state mismatch (เช่น nodes บน canvas ไม่ตรงกับ data ที่ save)
     - history stack หายหรือค้าง

2. เพิ่ม guard logic ง่าย ๆ:
   - ระหว่างกำลังรัน:
     - `graph_validate`
     - `graph_autofix`
     - `graph_apply_fixes`
   - ให้ disable ปุ่ม Undo/Redo ชั่วคราว
   - หรือไม่ให้กดซ้ำได้จนกว่า promise จะ resolve

3. ถ้าพบว่ามีการ update state แบบ **replace ทั้ง graph** (เช่นหลัง apply fixes):
   - ให้ `pushHistory()` จาก state ใหม่ (snapshot)  
     → เพื่อตัด history branch เก่าแบบชัดเจน

### 4) Acceptance Criteria

เมื่อจบ Task 19.24.6:

- A. Functional
  - Undo/Redo:
    - เพิ่ม node → Undo → node หาย → Redo → node กลับมา
    - เพิ่ม edge → Undo → edge หาย → Redo → edge กลับมา
    - แก้ condition ของ edge → Undo → condition กลับค่าเดิม → Redo → กลับค่าที่แก้ล่าสุด
  - หลังใช้ autofix:
    - กด Undo → กลับไป graph ก่อน autofix
    - กด Redo → กลับไปกราฟหลัง autofix

- B. Stability
  - ระหว่าง validate/autofix/apply_fixes:
    - กด Undo/Redo แล้วไม่เกิด error
    - UI ไม่ค้าง

- C. Tests & Manual Checks
  - `ValidateGraphTest`, `SemanticSnapshotTest`, `AutoFixPipelineTest` ยังผ่านทั้งหมด
  - Manual test:
    - 5 scenario หลักของ Undo/Redo ตามที่ระบุข้างบน
    - บันทึกผลใน `docs/super_dag/tests/undo_redo_manual_tests.md`

---

## Notes

- ห้ามเปลี่ยนรูปแบบ graph payload เพื่อให้ history engine ไม่ต้องตาม schema ใหม่
- ถ้าเจอ logic history บางส่วนที่ซับซ้อนเกินในรอบนี้:
  - ให้ใส่ comment:  
    `// TODO(SuperDAG-History): candidate for Phase 2 refactor`
  - โฟกัสแค่ปิดรูรั่วที่เห็นชัดก่อน
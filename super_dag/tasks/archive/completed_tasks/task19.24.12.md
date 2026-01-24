

# Task 19.24.12 — Remove Legacy Snapshot Logic (Graph History)

> Goal: ลบ logic เก่าที่รองรับ snapshot format `{ cyJson: { ... } }` ออกจาก Graph History Engine ทั้งหมด และบังคับให้ระบบใช้ snapshot format แบบใหม่เพียงแบบเดียวเท่านั้น

---
## 1. Scope

โฟกัสเฉพาะฝั่ง SuperDAG Graph Designer (JS):

**ไฟล์หลัก:**
- `assets/javascripts/dag/modules/GraphHistoryManager.js`
- `assets/javascripts/dag/graph_designer.js`

**ไม่แตะต้องไฟล์:**
- PHP (SuperDAG backend, validation, autofix, ฯลฯ)
- Condition editor (`conditional_edge_editor.js`)
- Test harness PHP ทั้งหมด (ValidateGraphTest, AutoFixPipelineTest, SemanticSnapshotTest) — แต่อาจต้องอัปเดต fixture JS/inline comments ถ้าจำเป็น

---
## 2. Canonical Snapshot Format (เป้าหมายสุดท้าย)

ให้ถือว่า **รูปแบบ snapshot เดียวที่อนุญาตหลังจบ Task นี้** คือ:

```js
// canonical snapshot
{
  nodes: [ /* plain JS objects for nodes */ ],
  edges: [ /* plain JS objects for edges */ ],
  meta:  { /* optional, small, non-Cytoscape metadata */ }
}
```

### 2.1 สิ่งที่ **ต้องไม่เหลืออยู่** หลังจบงาน

- ฟิลด์ระดับบน (`top-level`) ต่อไปนี้ **ต้องไม่ถูกใช้/เช็คอีกต่อไป**:
  - `snapshot.cyJson`
  - `snapshot.cy` (หรือ object ที่อ้างถึง instance ของ Cytoscape โดยตรง)
  - format เก่าที่เป็น:
    ```js
    {
      cyJson: { elements: { nodes: [...], edges: [...] }, ... }
    }
    ```
- Logic ใด ๆ ที่มีลักษณะเช่น:
  - `if (snapshot.cyJson) { ... } else { ... }`
  - `const cyJson = snapshot.cyJson || snapshot;`
  - การ clone / deep-copy `cyJson` โดยตรง

---
## 3. งานที่ต้องทำ (Step-by-step)

### 3.1 GraphHistoryManager.js — ลบ Legacy Snapshot Format

1. เปิดไฟล์ `assets/javascripts/dag/modules/GraphHistoryManager.js` แล้ว:
   - หา logic ที่รองรับ snapshot format แบบ legacy เช่น:
     - เช็ค `snapshot.cyJson`
     - แปลง `cyJson` → internal snapshot
   - ลบ branch/logic เหล่านี้ทั้งหมด

2. ยืนยันว่า public API ของ `GraphHistoryManager` ทำงานกับ snapshot canonical format เท่านั้น:
   - `push(snapshot)`
   - `undo()`
   - `redo()`
   - `markBaseline()` / `isModified()`
   - `clear()`

3. ภายใน `push()` / internal helpers:
   - สมมติว่า argument `snapshot` **ต้องมี**อย่างน้อย:
     - `Array.isArray(snapshot.nodes)`
     - `Array.isArray(snapshot.edges)`
   - ถ้าไม่ตรง spec ให้ **reject/ignore snapshot** และ log warning (เช่น `console.warn('[History] Invalid snapshot format, ignoring')`) แต่ห้ามพัง runtime.

4. ถ้ามี helper ใดที่ยังรองรับรูปแบบเก่า เช่น `_normalizeSnapshot`:
   - ปรับให้รองรับเฉพาะ canonical format
   - หรือถ้าไม่ได้ใช้แล้ว ให้ลบทิ้ง

### 3.2 graph_designer.js — unify build/restore snapshot

1. เปิด `assets/javascripts/dag/graph_designer.js` แล้วตรวจค้นคำว่า:
   - `cyJson`
   - `snapshot.cyJson`
   - `elements: {`

2. ใน `buildGraphSnapshot()`:
   - ยืนยันว่า **return เฉพาะ canonical format** ตามข้อ 2:
     ```js
     return {
       nodes: ..., // from cy.elements('node') mapped → plain objects
       edges: ..., // from cy.elements('edge') mapped → plain objects
       meta:  ...
     };
     ```
   - ห้ามสร้าง object ระดับบนชื่อ `cyJson` หรือ wrap ใน `{ cyJson: ... }` อีกต่อไป

3. ใน `restoreGraphSnapshot(snapshot)` หรือฟังก์ชันที่มีหน้าที่ restore state ใส่ Cytoscape:
   - ลบ branch ที่รองรับ legacy format เช่น:
     ```js
     const cyJson = snapshot.cyJson ? snapshot.cyJson : snapshot;
     // หรือรูปแบบคล้ายกัน
     ```
   - ให้โค้ด assume ว่า snapshot มีโครงสร้าง canonical เท่านั้น และทำ mapping ใส่ `cy` จาก `snapshot.nodes`/`snapshot.edges`

4. ถ้าเคยมีจุดที่รองรับ snapshot จาก `localStorage` หรือ source เก่า:
   - เพิ่ม guard ง่าย ๆ ว่า ถ้า snapshot ที่อ่านได้ **ไม่ตรง spec** (ไม่มี `nodes`/`edges` เป็น array):
     - แสดง warning ใน console
     - ล้าง history / ข้าม snapshot นั้นไป

### 3.3 ตรวจสอบไฟล์อื่นที่อาจอ้างถึง cyJson

- ในโฟลเดอร์ `assets/javascripts/dag/` ให้ search keyword:
  - `cyJson`
  - `snapshot.cy`
  - รูปแบบที่ดูเป็น legacy เช่น `elements: { nodes:`
- ถ้ามี:
  - วิเคราะห์ก่อนว่ามันยังถูกเรียกใช้หรือไม่
  - ถ้าใช้กับ history/snapshot เดียวกัน → ปรับให้ใช้ snapshot canonical format
  - ถ้าเป็น dead code จริง ๆ → จะไปลบทิ้งใน Task 19.24.13 (อย่าลบใน Task นี้ถ้ามั่นใจไม่พอ)

---
## 4. Safety & Backward Compatibility

1. **อย่าพยายาม migrate localStorage snapshots เก่า**
   - ถ้าเจอ format ที่ไม่ตรง spec ให้ถือว่า snapshot นั้นใช้ไม่ได้ และ reset history แทน
   - เป้าหมายของ Task นี้คือลบ legacy logic ใน code, ไม่ใช่รองรับ snapshot เก่าถาวร

2. **ไม่แก้ไข PHP / Backend**
   - ห้ามไปแก้ไข `dag_routing_api.php` หรือ GraphValidationEngine ใน Task นี้
   - ถ้าเห็น comment เกี่ยวกับ snapshot ใน PHP ให้ข้ามไปก่อน

3. **ห้ามเปลี่ยนพฤติกรรม Undo/Redo**
   - การเปลี่ยนรูปแบบ snapshot ต้องคง semantics เดิม:
     - หนึ่ง user action = หนึ่ง history step (ตามที่เราทำใน Task 19.24.8–19.24.11)
   - ทดสอบ manual ว่า:
     - เพิ่ม/ลบ node + Undo/Redo ยังทำงาน step-by-step จริง
     - Drag node ยาว ๆ → Undo ถอยกลับทีละ drag-group หนึ่งครั้ง

---
## 5. Acceptance Criteria

Task 19.24.12 จะถือว่า **สำเร็จ** เมื่อ:

1. **Code-level**
   - ไม่เหลือการอ้างถึง `cyJson` หรือ `snapshot.cyJson` ในโค้ด JS ทั้งหมดใต้ `assets/javascripts/dag/`
   - ไม่มี branch รูปแบบ `if (snapshot.cyJson) { ... }`
   - `GraphHistoryManager` ทำงานกับ snapshot canonical format เท่านั้น

2. **Behavior-level**
   - Undo/Redo ยังทำงานเหมือนหลังจบ Task 19.24.11
   - เปิด/ปิด Graph Designer แล้วไม่มี error ใน console
   - ถ้า inject snapshot format เก่าเข้าไปใน history → ระบบไม่พัง แต่จะ ignore/reset history ด้วย warning

3. **Test-level**
   - รันชุดทดสอบเดิมแล้วผ่านทั้งหมด (อย่างน้อย):
     - `php tests/super_dag/ValidateGraphTest.php`
     - `php tests/super_dag/AutoFixPipelineTest.php`
     - `php tests/super_dag/SemanticSnapshotTest.php`
   - ไม่มี error ใหม่ที่เกี่ยวกับ history หรือ snapshot

---
## 6. Note ถึง AI Agent

- โฟกัสเฉพาะ JS ฝั่ง frontend ที่เกี่ยวกับ Graph History + Snapshot เท่านั้น
- ห้ามสร้าง feature ใหม่, ห้ามเปลี่ยนโครงสร้าง UI
- ถ้าไม่แน่ใจว่า block ไหนเป็น legacy หรือยังใช้อยู่ ให้ **เขียน TODO comment** แทนการลบทิ้ง
- อย่าลืมอัปเดต comment ให้สอดคล้องกับพฤติกรรมใหม่ (เช่น ไม่พูดถึง cyJson อีกต่อไป)
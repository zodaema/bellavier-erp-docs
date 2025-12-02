# Task 18.2 — Node UX Logic Simplification & Progressive Disclosure (Patch v2)

**Status:** NEW  
**Category:** Super DAG – Graph Designer UX (Phase 7.1)  
**Depends on:**  
- Task 17 (Parallel/Merge semantics)  
- Task 17.2 (Parallel validation & legacy cleanup)  
- Task 18 (Machine cycle support)  
- Task 18.1 (Parallel × Machine combined logic)

> ⚠️ IMPORTANT: This task is a **hard UX refactor** of the node properties panel. 
> The goal is to **HIDE** irrelevant options (not just disable them) based on graph topology and work center. 
> If the UI still shows blue info boxes all the time, the task is considered **NOT DONE**.

---

# 🎯 Objective

ลดความซับซ้อนของ UX ใน Graph Designer โดยใช้ **Topology-Aware Logic** และ **Progressive Disclosure** ที่ "ทำงานจริง" ดังนี้:

1. ซ่อน (ไม่ใช่แค่ disable) ตัวเลือก Parallel / Merge ตามจำนวนเส้นทางเข้า-ออก (edges) ของ node โดยอัตโนมัติ  
2. Auto-reset flags (`is_parallel_split`, `is_merge_node`) ให้สอดคล้องกับ topology ทุกครั้งที่มีการแก้เส้นทาง  
3. เปลี่ยน Node Type ให้เป็น label (read-only) อยู่ในส่วนหัวของ panel แทน select box  
4. ทำให้ Node Code เป็น auto-generated + read-only สำหรับผู้ใช้ทั่วไป (แก้ได้เฉพาะ dev/admin ถ้าระบบรองรับ role)  
5. ซ่อน Machine Settings สำหรับ work center ที่ไม่ใช้เครื่อง และซ่อนไว้ใต้ปุ่ม "Advanced" สำหรับผู้ใช้ทั่วไป

ผลลัพธ์ที่ต้องการ: ผู้ใช้ทั่วไปจะเห็นเฉพาะ **สิ่งที่จำเป็นต่อการวาดกราฟ** ไม่ต้องเข้าใจ parallel theory หรือ machine theory ก็สามารถออกแบบ flow ได้อย่างถูกต้อง

---

# 🧩 Scope

## In Scope

- Frontend (Graph Designer):
  - `assets/javascripts/dag/graph_designer.js`
  - `assets/javascripts/dag/modules/GraphSaver.js`
- UI Logic:
  - Parallel / Merge controls (ซ่อน/แสดงแบบ dynamic)
  - Node Type rendering (label-only)
  - Node Code behavior (readonly for normal users)
  - Machine Settings panel (Advanced-only)

## Out of Scope

- Backend logic ของ Parallel / Merge / Machine (ทำแล้วใน Task 17–18.1)
- การเปลี่ยนแปลง schema ใน DB (ใช้ของเดิม)
- การปรับ routing runtime (ใช้ logic ปัจจุบัน)

---

# 📦 Deliverables

## 1. Topology-Aware Parallel / Merge UI Logic (จริง ๆ ไม่ใช่แค่ข้อความเตือน)

**Files:**
- `assets/javascripts/dag/graph_designer.js`
- `assets/javascripts/dag/modules/GraphSaver.js`

### 1.1 Helper Functions สำหรับนับ edges

เพิ่ม helper ที่อ่านจากโครงสร้างกราฟจริง ๆ (เช่น Cytoscape หรือ library ที่ใช้อยู่):

```js
function getOutgoingEdgesCount(nodeId) { /* return integer */ }
function getIncomingEdgesCount(nodeId) { /* return integer */ }
```

ใช้ helper สองตัวนี้ทุกครั้งที่:
- เลือก node
- เพิ่ม/ลบ edge
- โหลดกราฟจาก server

### 1.2 ฟังก์ชันกลาง: updateParallelMergeUIForSelectedNode

สร้างฟังก์ชันใน `graph_designer.js` (หรือ module ที่เหมาะสม):

```js
function updateParallelMergeUIForSelectedNode(selectedNode) {
  const nodeId = selectedNode.id();
  const outgoingCount = getOutgoingEdgesCount(nodeId);
  const incomingCount = getIncomingEdgesCount(nodeId);

  // 1) Parallel Start section visibility
  if (outgoingCount <= 1) {
    hideParallelStartSection();
    selectedNode.data('isParallelSplit', false);
  } else {
    showParallelStartSection();
  }

  // 2) Merge section visibility
  if (incomingCount <= 1) {
    hideMergeSection();
    selectedNode.data('isMergeNode', false);
    resetMergePolicyFields(selectedNode);
  } else {
    showMergeSection();
  }
}
```

> ❗ `hideParallelStartSection()` และ `hideMergeSection()` ต้อง **ซ่อนทั้ง panel/section** (เช่น `display: none`) ไม่ใช่เพียงแค่แสดงกล่องข้อความเตือนสีฟ้า

ฟังก์ชันนี้ต้องถูกเรียกเมื่อ:
- ผู้ใช้คลิกเลือก node
- มีการเพิ่ม/ลบ edge ที่เชื่อมกับ node นั้น
- หลังจากโหลดกราฟเวอร์ชันจาก backend (apply ให้ทุก node หรือ node ที่ถูกเลือกอยู่)

### 1.3 Auto-reset flags เมื่อ topology เปลี่ยน

ใน logic ที่ handle การลบ edge:

```js
function onEdgeRemoved(edge) {
  const sourceId = edge.data('source');
  const targetId = edge.data('target');

  const sourceNode = cy.getElementById(sourceId);
  const targetNode = cy.getElementById(targetId);

  if (getOutgoingEdgesCount(sourceId) <= 1) {
    sourceNode.data('isParallelSplit', false);
  }

  if (getIncomingEdgesCount(targetId) <= 1) {
    targetNode.data('isMergeNode', false);
    resetMergePolicyFields(targetNode);
  }

  updateParallelMergeUIForSelectedNode(currentlySelectedNode);
}
```

`GraphSaver` ต้องอ่านค่าที่ถูก reset แล้วส่งไป backend เพื่อไม่ให้เกิด garbage state ใน DB

> 🔑 จุดสำคัญ: ถ้า node มี outgoing == 1 แต่ UI ยังแสดง section Parallel Execution อยู่ = **ถือว่าทำ Task 18.2 ผิด**

---

## 2. Node Type เป็น Read-Only Label ในส่วนหัว

**Files:**
- `assets/javascripts/dag/graph_designer.js`

### 2.1 Layout ใหม่ของ Node Type

ใน panel คุณสมบัติ:

- ย้าย Node Type ให้ไปอยู่บริเวณหัว panel เช่นใต้ชื่อ node:

```text
ชื่อโหนด: [ input ]
ประเภท: [ OPERATION ]  (badge/label เท่านั้น)
```

- ใช้ `<span>` หรือ `<div>` พร้อม style badge เช่น "OPERATION", "QC", "MERGE", "START", "FINISH" ฯลฯ
- **ไม่ต้องมี `<select>` หรือ `<input>` ให้แก้ไขได้**

### 2.2 กติกา Node Type

- Type ถูกกำหนดจาก logic เดิม (สร้างจาก toolbar / behavior / flags) เท่านั้น
- START / FINISH → lock เสมอ
- QC / OPERATION / MERGE → มาจาก behavior, execution_mode, flags

> ผู้ใช้ธรรมดา **ห้ามเปลี่ยน type ผ่าน UI** ทุกกรณี

---

## 3. Node Code — Auto-Generated & Readonly (Normal Users)

**Files:**
- `assets/javascripts/dag/graph_designer.js`
- `assets/javascripts/dag/modules/GraphSaver.js`

### 3.1 พฤติกรรมที่ต้องได้

- ฟิลด์รหัสโหนด (Node Code) แสดงผลแบบ readonly เช่น:

```text
รหัสโหนด (Auto-generated) [ SEW_BODY ]
Auto-generated unique code. Cannot be edited.
```

- ไม่มีทางให้ผู้ใช้ทั่วไปแก้ไขค่า code จาก UI ได้ (input disabled หรือ render เป็น `<span>`) 
- Node ใหม่ต้องได้รับ code อัตโนมัติจาก backend หรือ generator ที่มีอยู่แล้ว

### 3.2 GraphSaver

- เมื่อ save กราฟ ต้องแน่ใจว่า:
  - ทุก node มี `node_code` ไม่ว่าง
  - ถ้าไม่มี code (เช่น node ใหม่ที่ frontend เพิ่งสร้าง) ให้ขอสร้างจาก backend หรือใช้ temporary pattern ที่ backend จะ normalize ภายหลัง

---

## 4. Machine Settings — Advanced Panel with Work Center Awareness

**Files:**
- `assets/javascripts/dag/graph_designer.js`

### 4.1 แปลงเป็น Accordion "Machine Settings (Advanced)"

- ส่วน Machine Settings ทั้งหมดต้องอยู่ภายใต้ accordion แบบนี้:

```text
[▶] Machine Settings (Advanced)
    Machine Binding Mode
    Concurrency Limit
    ... (fields อื่น ๆ ที่เกี่ยวข้อง)
```

- ค่า default:
  - accordion ปิดอยู่ (collapsed) เมื่อเปิด panel node
  - ผู้ใช้ทั่วไปไม่จำเป็นต้องกดเปิดเลยก็ได้

### 4.2 ซ่อน Machine Settings สำหรับ Work Center ที่ไม่มีเครื่อง

- ข้อมูล Work Center ต้องมี flag เช่น `has_machine` (อาจ preload จาก server หรือส่งมาพร้อม list)
- เมื่อเลือก Work Center:

```js
if (!workCenter.has_machine) {
  hideMachineSettingsAccordion();
  setMachineBindingModeNone(selectedNode);
} else {
  showMachineSettingsAccordion();
  applyDefaultMachineSettingsFromWorkCenter(selectedNode, workCenter);
}
```

- สำหรับ work center ที่มีเครื่อง:
  - ตั้งค่า default binding mode และ concurrency limit จาก config ของ work center

> เป้าหมาย: ผู้ใช้ทั่วไปไม่ต้องสนใจ machine settings เลย แต่ระบบยังเก็บค่าที่มีเหตุผลไว้ใน background

### 4.3 Tooltip / Helper Text

เพิ่มคำอธิบายใต้แต่ละ field (เมื่อ accordion เปิด) เช่น:

- Machine Binding Mode: 
  > วิธีที่ token ถูกจับคู่กับเครื่องจักร ส่วนใหญ่สามารถปล่อยเป็นค่า Auto ได้

- Concurrency Limit:
  > จำนวนงานสูงสุดที่ node นี้สามารถทำพร้อมกันได้ ถ้าไม่แน่ใจให้ใช้ค่าที่ระบบตั้งให้

---

## 5. GraphSaver Integration & Validation

**Files:**
- `assets/javascripts/dag/modules/GraphSaver.js`

### 5.1 Sync Auto Logic → Data Model

- เมื่อ UI auto-reset flags (`isParallelSplit`, `isMergeNode`) จากข้อ 1.3 → GraphSaver ต้องอ่านค่าล่าสุดจาก node data เสมอ
- Validation (`validateGraphStructure()` จาก Task 17.2) ต้องสอดคล้องกับ rule ใหม่:
  - ไม่ error ถ้า node มี outgoing == 1 และไม่มี parallel flag (เพราะมันไม่ใช่ parallel case)  
  - ไม่ error ถ้า node มี incoming == 1 และไม่มี merge flag

### 5.2 Backward Compatibility

- เมื่อโหลดกราฟเก่าจาก backend:
  - ถ้า node มี `isParallelSplit = 1` แต่ตอนนี้ outgoing == 1 → ให้ auto-reset เป็น false และซ่อน parallel section  
  - ถ้า node มี `isMergeNode = 1` แต่ incoming == 1 → auto-reset เป็น false และซ่อน merge section

> สามารถ log warning แบบ dev-only ได้ แต่ห้ามให้ผู้ใช้ต้องกดอะไรเพิ่ม

---

# 🧪 Test Cases (ต้องผ่านจริงใน UI)

### TC1 — Node with Single Outgoing Edge

- วาด node ที่มี outgoing edge เดียว
- Expected:
  - **ไม่มี** section Parallel Execution ปรากฏใน panel เลย  
  - `isParallelSplit` ถูก set เป็น `false` ใน node data  
  - Save graph → ไม่มี error จาก validation

### TC2 — Node with Two Outgoing Edges

- วาด node ที่มี outgoing ≥ 2
- Expected:
  - Section Parallel Execution ปรากฏขึ้น (หลังจากเลือก node)  
  - ผู้ใช้สามารถติ๊ก/ไม่ติ๊ก parallel ตาม logic จาก Task 17.2

### TC3 — Node with Multiple Incoming Edges

- วาด node ที่มี incoming ≥ 2
- Expected:
  - Section Merge + Merge Policy ปรากฏขึ้น  
  - ถ้าติ๊กเป็น merge node → สามารถตั้ง merge policy ได้

### TC4 — Change Topology After Flag Set

- Node A เดิมเป็น parallel split (outgoing 3 เส้น + ติ๊ก parallel)
- ลบ edge ออกจนเหลือ 1 เส้น
- Expected:
  - `isParallelSplit` ถูก reset เป็น false  
  - Section Parallel Execution หายไปจาก panel  
  - Save graph แล้วข้อมูลใน DB สอดคล้องกับ state ใหม่

### TC5 — Node Type Immovable

- พยายามหาวิธีเปลี่ยนประเภท node จาก panel
- Expected:
  - เปลี่ยนไม่ได้ (เพราะเป็น label เท่านั้น)  
  - GraphSaver ยังส่งค่า node type เดิมให้ backend ตามที่ engine กำหนด

### TC6 — Machine Settings Hidden for Non-machine Work Center

- เลือก Work Center ที่ `has_machine = false`
- Expected:
  - Accordion Machine Settings ไม่แสดงเลย หรือแสดงแบบ disabled พร้อมข้อความสั้น ๆ เช่น "This work center does not use machines."  
  - Save graph → ค่า machine binding mode ถูก set เป็น `None`

### TC7 — Machine Settings as Advanced (for machine work centers)

- เลือก Work Center ที่มีเครื่อง
- Expected:
  - Accordion Machine Settings แสดงเป็นแบบปิด (collapsed) โดย default  
  - เปิดดูได้เฉพาะเมื่อผู้ใช้กด และเห็น tooltip อธิบาย  
  - ค่า default ถูกตั้งจาก config ของ work center

---

# 📝 Summary

Task 18.2 (Patch v2) เปลี่ยน Graph Designer จาก UI แบบ "โชว์ทุกอย่างตลอดเวลา" ไปเป็น UI แบบ **ฉลาดและรู้บริบทของตัวเอง**:

- รู้จักจำนวนเส้นทางเข้า-ออก และซ่อน parallel/merge UI ที่ใช้ไม่ได้จริง  
- ไม่บังคับให้ผู้ใช้เข้าใจทฤษฎี parallel/merge/machine ก่อนถึงจะวาดกราฟได้  
- Node Type และ Node Code ถูกป้องกันจากการแก้ไขผิด ๆ  
- Machine Settings ถูกซ่อนเป็น advanced panel และผูกกับ Work Center โดยอัตโนมัติ

เกณฑ์จบงาน: เมื่อผู้ใช้ทั่วไปเปิดดู node ที่มี edge เดียว (ทั้งเข้าและออก) แล้ว **ไม่เห็น UI ที่เกี่ยวกับ Parallel/Merge/Machine เลย** ยกเว้นข้อความอธิบายสั้น ๆ ที่ไม่สร้างความสับสน
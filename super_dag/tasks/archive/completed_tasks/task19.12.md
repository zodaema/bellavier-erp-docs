

# Task 19.12 — ApplyFixEngine (AutoFix v3 Execution Layer)

**Category:** SuperDAG / Validation & AutoFix Pipeline
**Depends on:**
- Task 19.10.1 — Semantic Intent Engine
- Task 19.10.2 — AutoFixEngine v3 (intent-aware suggestions)
- Task 19.11 — Validator v3 (semantic-aware)

**Goal:**
สร้าง ApplyFixEngine ที่สามารถ apply ชุด AutoFix operations แบบ atomic → ปลอดภัย → reversible → deterministic. 
ระบบต้องสามารถ:
1. Apply เฉพาะ fixes ที่ผู้ใช้เลือก (manual selection)
2. Apply fixes แบบ batch (Fix All Safe Issues)
3. Validate graph ใหม่หลัง apply
4. ส่งกลับ graph ที่แก้แล้วให้ UI ใช้ update state
5. ป้องกัน edge case เช่น orphan edges, duplicate edges, invalid node refs

---
## 1. Overview
AutoFixEngine v3 แนะนำวิธีแก้ปัญหา แต่ *ไม่ได้แก้กราฟจริง*. 
Task 19.12 จะสร้าง **ApplyFixEngine.php** เพื่อ execute fixes ลงบน graph state ใน memory ก่อนค่อย serialize กลับให้ UI.

ApplyFixEngine ต้อง:
- รองรับ operations ทั้งหมดที่ AutoFixEngine v3 ออกแบบไว้
- Fail-safe: หาก operation ใดล้มเหลว งานทั้งหมดไม่ควร apply (atomic transaction)
- Return graph state ใหม่ที่แก้ไขแล้วแบบครบสมบูรณ์

---
## 2. File to Implement

```
source/BGERP/SuperDAG/ApplyFixEngine.php
```

หากไฟล์นี้มีอยู่แล้ว ให้ **rewrite เฉพาะ method ตามสเปกนี้** (อย่า refactor โครงสร้างอื่น).

---
## 3. Operations ที่ต้องรองรับ

### 3.1 Node Operations
- `update_node_property`
- `mark_as_sink`
- `create_end_node`
- `remove_node` (เฉพาะ unreachable + suggest_only case)
- `set_node_metadata`

### 3.2 Edge Operations
- `set_edge_as_else`
- `create_edge`
- `remove_edge`
- `update_edge_condition`
- `mark_edge_as_default_route`

### 3.3 Multi-step Operations
- Operation chains เช่น:
  - convert QC two-way → pass + else(rework)
  - create END → connect terminal node → update sequencing metadata

ทุก operations ต้องเป็น pure array-based transformation:
```
$nodes = [...];
$edges = [...];
list($nodes, $edges) = $applyFixEngine->apply($nodes, $edges, $operations);
```

---
## 4. Atomicity Rules
ApplyFixEngine ต้อง implement atomic‐apply:
1. Clone state ก่อนเริ่ม apply
2. หาก operation ใด throw exception → rollback ทั้งหมด
3. ส่ง error object กลับไปที่ API

ตัวอย่าง:
```php
$backupNodes = $nodes;
$backupEdges = $edges;
try {
    foreach ($operations as $op) {
        $this->applySingleOperation(...);
    }
} catch (\Exception $e) {
    $nodes = $backupNodes;
    $edges = $backupEdges;
    throw $e;
}
```

---
## 5. Integration in API (dag_routing_api.php)
เพิ่ม action ใหม่:
```
?action=graph_apply_fixes
```

Flow:
1. รับ graph (nodes/edges) + selected fix items จาก UI
2. โหลด ApplyFixEngine
3. ใช้ AutoFixEngine v3 เพื่อ lookup operations ของ fix ที่เลือก
4. Apply แบบ atomic
5. Revalidate ด้วย Validator v3
6. Return graph ใหม่ + validation ใหม่

Response format:
```json
{
  "ok": true,
  "graph": { "nodes": [...], "edges": [...] },
  "validation": {...}
}
```

Error case:
```json
{
  "ok": false,
  "error": "Apply Fix failed: duplicate edge detected",
  "rollback": true
}
```

---
## 6. UI Integration (graph_designer.js)
เพิ่ม flow:
1. User เปิด AutoFix Panel
2. เลือก fixes (checkboxes)
3. Click “Apply Selected Fixes”
4. JS ส่ง list ของ fix_ids ไป API
5. รับ graph ใหม่
6. Replace state ใน Cytoscape ด้วย state ใหม่
7. Run validation อีกครั้ง

Special UX:
- Disable “Apply Selected” หากไม่มี fix ใดถูกเลือก
- Show diff preview (optional, future task)

---
## 7. Safety & Constraints
- ไม่สร้าง node ใหม่ยกเว้น create_end_node
- remove_node ทำได้เฉพาะ unreachable.unintentional ที่ risk ≤ 60
- ต้อง respect apply_mode (disabled/suggest_only/auto)
- ถ้า user เลือก fix ที่ apply_mode=disabled → API ต้อง reject

---
## 8. Acceptance Criteria
- [ ] ApplyFixEngine.php สร้างตามสเปก
- [ ] Apply ทั้ง graph ได้แบบ atomic
- [ ] รองรับ operations ทั้งหมดครบ
- [ ] API graph_apply_fixes ใช้งานได้จริง
- [ ] UI สามารถ apply fix ได้ครบ workflow
- [ ] Validate หลัง apply แล้ว error น้อยลงหรือหายไป
- [ ] ไม่มี regression กับกราฟเก่า

---
## 9. Output Documents
- `task19_12_results.md`

หลัง implement เสร็จ ให้ AI Agent สร้างไฟล์นี้เพื่อสรุปผล.
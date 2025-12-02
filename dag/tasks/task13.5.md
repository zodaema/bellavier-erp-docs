# Task 13.5 — Component Serial Binding (Phase 3.1)

**Status:** TODO  
**Series:** Component System  
**Depends on:**  
- Task 13.3 — Component Type + Master + BOM Map (Read-Only)  
- Task 13.4 — Serial Generation System  
- Super_DAG Task 1–14 (Behavior + Token + Routing Base)

---

# 🎯 GOAL

ทำให้ระบบสามารถ “ผูก Component Serial → Token” ได้จริงในระดับ Node/Behavior  
โดยมีความปลอดภัย, ยืดหยุ่น, backward compatible 100% และไม่รบกวน DAG core logic

Component Binding นี้เป็น *soft binding* (update DB) ยังไม่ enforce completeness  
→ การ enforce จะอยู่ใน Task 13.6

---

# 🚧 SCOPE ของ Task 13.5

### **1. สร้าง Database Layer สำหรับ Binding**
ไฟล์ migration ใหม่:  
`database/tenant_migrations/2025_12_component_serial_binding.php`

รวม 2 ตาราง:

---

### **Table: component_serial_binding**
บันทึกว่า serial ตัวไหนถูกผูกกับ token ใด

| field | type | note |
|-------|------|------|
| id_binding | PK | auto |
| serial_id | FK → component_serial.id | required |
| serial_code | varchar(64) | cached สำหรับ query |
| token_id | FK → dag_token.id | required |
| node_id | FK → dag_graph_node.id | required |
| work_center_id | FK | required |
| bound_by | user_id | required |
| bound_at | datetime | now() |
| status | enum(active, unbound) | default active |
| unbound_at | datetime | nullable |

Unique constraint: `(serial_id, token_id, status='active')`

---

### **Table: component_serial_usage_log**
เก็บประวัติ usage ทุกครั้งที่ bind / unbind

| field | type |
|-------|------|
| id_log | PK |
| serial_id | FK |
| token_id | FK |
| node_id | FK |
| work_center_id | FK |
| action | enum(bind, unbind) |
| actor_id | FK |
| event_at | datetime |

---

## 2. สร้าง ComponentBindingService

ตำแหน่งไฟล์:  
`source/BGERP/Component/ComponentBindingService.php`

### Methods:

### **bindSerialToToken($serialCode, $tokenId, $nodeId, $workCenterId, $userId)**
- ตรวจสอบ serial availability (`status=available`)
- ตรวจสอบไม่ถูก bind อยู่แล้ว
- Insert binding
- Update serial status → `used`
- Insert usage log
- Return binding record

### **unbindSerial($serialCode, $tokenId, $userId)**
- ตรวจสอบ binding active อยู่
- Mark binding = unbound
- Update serial status → `available`
- Insert usage log

### **getBindingsForToken($tokenId)**
- ใช้ใน UI token detail
- Return รายการ serial ที่ผูกอยู่

### **validateSerialCode($serialCode)**
- ตรวจสอบ format + database existence

### **Notes**
- ถ้าพบ error ต้อง return ในรูปแบบ standardized JSON (TenantApiOutput)

---

# 3. API Endpoint: component_binding.php

ไฟล์ใหม่:  

`source/component_binding.php`

### Actions:

#### `bind`
Input:
```json
{
  "serial_code": "BODY-20251201-0001",
  "token_id": 3002,
  "node_id": 45,
  "work_center_id": 12
}
```

Response:
```json
{
  "ok": true,
  "binding": { ... },
  "serial_status": "used"
}
```

---

#### `unbind`
Input:
```json
{
  "serial_code": "BODY-20251201-0001",
  "token_id": 3002
}
```

Response:
```json
{
  "ok": true,
  "unbound": true
}
```

---

#### `list_by_token`
Query:
`?token_id=3002`

Response:
```json
{
  "ok": true,
  "bindings": [
    {"serial_code": "...", "component_type": "...", "node_id": ...}
  ]
}
```

---

# 4. Behavior Integration

### Modify: `BehaviorExecutionService.php`

เพิ่ม logic เฉพาะ behavior เหล่านี้:

### **CUT Behavior**
- ถ้า user เลือก “generate component serial and bind immediately”
- หลัง generate → auto-bind serials → record usage

### **EDGE Behavior**
- Panel ควรมีช่องสำหรับ scanning serials (optional UI)
- ทำให้ EDGE สามารถ bind serial ที่ใช้ในการคุม batch เช่น edge paint bottle (optional)

### **HARDWARE_ASSEMBLY**
- UI: scan hardware serials
- Require at least 1 binding ก่อน complete (ไม่ enforce ใน Task 13.5)

### **QC Behavior**
- QC can view bindings แต่ยังไม่ enforce completeness จนถึง Task 13.6

---

# 5. JavaScript UI Integration

ส่วนนี้ยังไม่ enforce, ยังไม่ block behavior

### New File:
`assets/javascripts/component/binding.js`

Features:

- Scan serial (via input หรือ scanner)
- Validate serial via API
- Show active bindings
- Bind/unbind buttons
- Event dispatch: `BG:ComponentBindingUpdated`

### Modify:

- `behavior_ui_templates.js`
  - เพิ่ม binding panel สำหรับ CUT / STITCH / HARDWARE / EDGE

- `behavior_execution.js`
  - เรียก bind/unbind API ผ่าน AJAX

---

# 6. Permissions

Migration ใหม่ (จอง role สำหรับ binding):

### Add:
- `component.binding.bind`  
- `component.binding.unbind`  
- `component.binding.view`

Auto-assign ให้ TENANT_ADMIN

---

# 7. Non-Goals (ทำใน Task 13.6)

❌ ไม่ enforce completeness  
❌ ไม่ block routing  
❌ ไม่ทำ component requirements per node  
❌ ไม่ตรวจ cross-node serial correctness  
❌ ไม่ตรวจ master vs type conflict  
❌ ไม่รวม stock allocation logic  
❌ ไม่ integrate PWA yet

---

# 8. Acceptance Criteria

- DB tables created และ idempotent
- ComponentBindingService พร้อมใช้งาน (no errors)
- API component_binding.php ส่ง JSON ที่ standardized
- BehaviorExecutionService พร้อมรับ binding แต่ไม่ enforce
- UI แสดง binding panel (optional)
- Debuggable via work_queue และ job_ticket

---

# 9. Required Files

- `database/tenant_migrations/2025_12_component_serial_binding.php`
- `source/BGERP/Component/ComponentBindingService.php`
- `source/component_binding.php`
- Modify `source/BGERP/Dag/BehaviorExecutionService.php`
- Modify `assets/javascripts/dag/behavior_ui_templates.js`
- New `assets/javascripts/component/binding.js`
- `docs/dag/tasks/task13.5_results.md`
- Update `docs/super_dag/task_index.md`

---

# 10. Instructions for AI Agent (Important)

เมื่อสั่งให้ implement:

```
Please implement task13.5 exactly according to task13.5.md.  
Follow all file paths, naming conventions, and rules from Super_DAG standards.  
Do not enforce completeness yet.  
Do not change DAG core logic.  
All code must be backward compatible.  
```

---

# END OF TASK 13.5  
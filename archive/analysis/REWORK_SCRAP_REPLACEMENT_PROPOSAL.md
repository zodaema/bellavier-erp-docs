# 🔄 Rework Scrap & Replacement Token - แนวคิดการจัดการ

**Created:** November 2, 2025  
**Status:** Proposal (Draft)  
**Purpose:** กำหนดแนวคิดการจัดการกรณีที่ token ถูก scrap (rework limit ถึง)

---

## 📌 สรุปแบบง่ายๆ (Quick Reference)

### 🎯 ภาพใหญ่: ทำไมต้องคิดเรื่องนี้เยอะ?

**ระบบเป็น DAG (ไม่มี loop)** → Pattern แบบ `QC → Rework → QC → Rework → ...` วาดเป็นเส้นวนกลับไม่ได้ (จะชน rule "no cycle")

**วิธีแก้:**
> "ห้ามวน node เดิม แต่ให้สร้าง token ใหม่ไปเริ่มจาก node ที่อยากย้อนกลับไปแทน"

**Proposal นี้กำลังนิยามให้ชัดว่า:**
- **"rework ปกติ"** = สร้าง token ไปย้อนกลับไปซ่อม
- **"ซ่อมไม่ไหวจริงๆ"** = scrap + จะสร้างตัวใหม่แบบไหน / ที่ node ไหน

---

### ✅ คำตอบ 3 คำถามสำคัญ:

#### 1) QC ไม่ผ่าน → ต่อไปที่ไหน? Rework node ต้องโยงกลับ node เดิมไหม?

**Flow ที่ถูกต้อง:**
1. ที่ QC node มี 2 edge อย่างน้อย:
   - ผ่าน → ไป node ต่อไป (ประกอบ / แพ็ค / END)
   - ไม่ผ่าน → ไป node ประเภท "Rework Sink"

2. ที่ Rework node ไม่จำเป็นต้องลากเส้นกลับไปยัง OP เดิม
   - Runtime จะใช้ policy ตัดสินใจเองว่า token ใหม่ต้องเกิดที่ node ไหน
   - จากสาเหตุอะไร (reason)

**คำตอบ:**
- ✅ ใช่ – QC fail ควรโยงมาที่ "Rework Sink"
- ✅ ไม่จำเป็นต้องวาดเส้นย้อนกลับไป node เดิม เพราะ engine จะสร้าง token ใหม่ให้เองที่ node เป้าหมาย
- ✅ กราฟยังเป็น DAG สวยๆ ไม่มี cycle

---

#### 2) Token ที่สร้างขึ้นมา "ซ่อม" หรือ "ทำใหม่ทั้งใบ?"

**แยกคำให้ชัด:**

**Rework Token (แบบใน `on_fail`):**
- คือชิ้นเดิมที่ QC ไม่ผ่าน
- สร้าง "token ใหม่" เพื่อย้อนกลับไปทำขั้นตอนบางช่วง เช่น เย็บซ่อม, ทำขอบใหม่
- ไม่ใช่เริ่มจาก START
- = "เอาชิ้นเดิมนี่แหละ ย้อนกลับไปทำขั้นตอนที่ X ใหม่อีกที"

**Replacement Token / Scrap Replacement (ส่วน `on_scrap`):**
- ใช้ตอนชิ้นเดิม "พังเกินเยียวยา"
- ชิ้นเดิมถูก mark ว่า scrapped
- แล้วอาจจะสร้างชิ้นใหม่ขึ้นมาจาก START หรือ CUT

**คำตอบ:**
- ✳️ "Rework ปกติ = ซ่อมชิ้นเดิม ย้อนกลับไปทำบาง node ซ้ำไปเรื่อยๆ จนกว่าจะถึง rework limit หรือ QC ผ่าน"
- ✳️ "Replacement = ทำใหม่ เริ่มจาก START หรือ CUT"

---

#### 3) ถ้าซ่อมไม่ได้ ต้องตัดหนังใหม่ → ใช้ Proposal นี้ยังไง?

**สถานการณ์:**
- Rework ไปแล้วหลายรอบ (rework_count >= MAX_REWORK_LIMIT)
- หรือ QC/ช่างติ๊ก reason ว่า material_defect, cannot_repair

**Flow:**
1. Token เดิมถูก mark ว่า scrapped
2. เกิด event `token_event(type='scrap', ...)`
3. จากนั้นดู policy `on_scrap`

**Policy Modes (อ่านแบบภาษาคน):**

| Mode | Behavior |
|------|----------|
| **`manual`** | แจ้งหัวหน้า → หัวหน้าจะกดสร้าง token ใหม่เอง (จะให้เริ่มจาก START หรือ CUT ก็แล้วแต่ UI ให้เลือก) |
| **`auto_spawn_from_start`** | Scrap ปุ๊บ → ระบบสร้าง token ใหม่ที่ START ให้เลย (= ทำงานใหม่ทั้งใบ) |
| **`auto_spawn_from_cut`** | Scrap ปุ๊บ → token ใหม่ไปเริ่มที่ node CUT (= ตัดหนังใหม่ แต่ยังใช้ routing ต่อจากจุดนั้น) |
| **`none`** | Scrap แล้วจบเลย ไม่มีตัวแทน (ใช้กับเคสที่นับเป็น material loss ไม่ทำซ้ำ) |

**คำตอบ:**
- ✅ ถ้าซ่อมไม่ได้จริงๆ → ให้ QC หรือช่าง mark เหตุผลว่า "ซ่อมไม่ได้ / material defect"
- ✅ Runtime จะ mark token เดิมเป็น scrapped
- ✅ แล้วทำต่อ "ตาม on_scrap.mode" (จะให้ auto สร้างชิ้นใหม่จาก START/CUT หรือปล่อยให้หัวหน้ากดสร้างใหม่เองก็ได้)

---

### 📝 สรุป Logic ที่ควรจำ (เวอร์ชันสั้นสุด)

**เอาไว้แปะในหัว AI Agent ได้เลย:**

1. **QC fail แต่ยังซ่อมได้:**
   - ใช้ `on_fail` → spawn rework token
   - Rework token = ชิ้นเดิม ย้อนกลับไปบาง node
   - วาดกราฟแบบ DAG ไม่ต้องมี loop

2. **QC fail และ "ซ่อมไม่ไหวแล้ว":**
   - Mark scrap (status = scrapped)
   - ใช้ `on_scrap.mode` ตัดสินใจเรื่อง "replacement token"
   - Replacement token = ชิ้นใหม่ เริ่มจาก START หรือ CUT ตาม policy

3. **Rework Limit = จุดที่บังคับเข้าสู่ "scrap flow":**
   - rework_count >= MAX_REWORK_LIMIT → ไม่ให้ rework อีก
   - ไปใช้ `on_scrap` เสมอ

**กฎทอง:**
> **QC Fail → Rework (ซ่อม)**  
> **Scrap → Replacement (ทำใหม่)**

---

## 📋 Overview

### ปัญหา
เมื่อ token ถูก rework หลายครั้งจนถึง `MAX_REWORK_LIMIT` → token จะถูก scrap (ทิ้ง)  
**คำถาม:** ต้องสร้าง token ใหม่เพื่อทำใหม่หรือไม่? และควรสร้างจาก node ไหน?

### วัตถุประสงค์
- กำหนด policy สำหรับการจัดการ scrap tokens
- รองรับทั้ง manual และ automatic replacement
- ใช้โครงสร้าง policy เดียวกับ rework system

---

## 🎯 Scenarios

### Scenario 1: Rework สำเร็จ (Normal Flow)
```
[QC ไม่ผ่าน] → [Rework Sink] → spawn new token → [เย็บ] (ซ่อม)
   ↓
[QC ผ่าน] → [แพ็ค] → [END] ✅
```

### Scenario 2: Rework ไม่สำเร็จ (Rework Limit ถึง)
```
[QC ไม่ผ่าน] → [Rework] → [QC ไม่ผ่านอีก] → ... (rework_count = MAX)
   ↓
[Token ถูก scrap] → Alert supervisor
   ↓
❓ ต้องทำอะไรต่อ?
```

### Scenario 3: Material Defect (ไม่สามารถซ่อมได้)
```
[QC ไม่ผ่าน] → [Rework] → [พบ Material Defect]
   ↓
[Token ถูก scrap ทันที] (ไม่ต้องรอ limit)
   ↓
❓ ต้องตัดหนังใหม่หรือไม่?
```

---

## 💡 Proposed Solution: Scrap Replacement Policy

### Policy Structure (ขยายจาก Rework Policy)

```json
{
  "on_fail": "spawn_new_token",
  "target_nodes": ["SEW", "EDG"],
  "strategy": "by_reason",
  "reason_mapping": {
    "QC_FAIL_STITCH": "SEW",
    "QC_FAIL_EDGE": "EDG"
  },
  
  // ✨ NEW: Scrap Replacement Policy
  "on_scrap": {
    "mode": "manual" | "auto_spawn_from_start" | "auto_spawn_from_cut" | "none",
    "require_approval": true | false,  // สำหรับ auto mode
    "notification": {
      "roles": ["supervisor", "manager"],
      "message_template": "Token {serial} scrapped after {count} rework attempts"
    }
  }
}
```

### Policy Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **`manual`** | Supervisor สร้าง token ใหม่เอง | Default (ปลอดภัย) |
| **`auto_spawn_from_start`** | Auto spawn token ใหม่ที่ START | เมื่อต้องการทำใหม่ทั้งหมด |
| **`auto_spawn_from_cut`** | Auto spawn token ใหม่ที่ CUT | เมื่อต้องการตัดหนังใหม่ |
| **`none`** | ไม่สร้าง token ใหม่ | เมื่อ scrap = material loss (ไม่ต้องทำใหม่) |

---

## 🔄 Runtime Flow

### Flow 1: Rework Limit ถึง (Auto Spawn)

```
1. Token rework_count >= MAX_REWORK_LIMIT
   ↓
2. SET token.status = 'scrapped'
   CREATE token_event(type='scrap', metadata={...})
   ↓
3. Check on_scrap.mode:
   
   IF mode = 'auto_spawn_from_start':
     → Spawn new token at START node
     → Link: new_token.parent_scrapped_token_id = old_token.id
     → Log: "Replacement token spawned from START"
   
   IF mode = 'auto_spawn_from_cut':
     → Spawn new token at CUT node
     → Link: new_token.parent_scrapped_token_id = old_token.id
     → Log: "Replacement token spawned from CUT"
   
   IF mode = 'manual':
     → Send notification to supervisor
     → Wait for manual token creation
   
   IF mode = 'none':
     → Just log scrap (no replacement)
   ↓
4. Send notification (if configured)
```

### Flow 2: Material Defect (Immediate Scrap)

```
1. Operator marks: "Material Defect - Cannot Rework"
   ↓
2. SET token.status = 'scrapped'
   CREATE token_event(type='scrap', metadata={
     'reason': 'material_defect',
     'immediate': true
   })
   ↓
3. Check on_scrap.mode:
   → Same as Flow 1
   ↓
4. If auto_spawn: Create replacement token immediately
```

---

## 📊 Policy Examples

### Example 1: Manual Mode (Default - ปลอดภัย)
```json
{
  "on_fail": "spawn_new_token",
  "target_nodes": ["SEW"],
  "on_scrap": {
    "mode": "manual",
    "notification": {
      "roles": ["supervisor"],
      "message_template": "Token {serial} scrapped. Please create replacement token."
    }
  }
}
```

**Behavior:**
- Token scrap → Alert supervisor
- Supervisor สร้าง token ใหม่เอง (ผ่าน UI)
- ไม่ auto spawn

---

### Example 2: Auto Spawn from START (ทำใหม่ทั้งหมด)
```json
{
  "on_fail": "spawn_new_token",
  "target_nodes": ["SEW"],
  "on_scrap": {
    "mode": "auto_spawn_from_start",
    "require_approval": false,
    "notification": {
      "roles": ["supervisor"],
      "message_template": "Token {serial} scrapped. Replacement token created at START."
    }
  }
}
```

**Behavior:**
- Token scrap → Auto spawn token ใหม่ที่ START
- Token ใหม่เริ่มจากต้น (ตัดหนังใหม่)
- Alert supervisor (informational)

---

### Example 3: Auto Spawn from CUT (ตัดหนังใหม่)
```json
{
  "on_fail": "spawn_new_token",
  "target_nodes": ["SEW"],
  "on_scrap": {
    "mode": "auto_spawn_from_cut",
    "require_approval": true,
    "notification": {
      "roles": ["supervisor", "manager"],
      "message_template": "Token {serial} scrapped. Replacement token created at CUT. Approval required."
    }
  }
}
```

**Behavior:**
- Token scrap → Auto spawn token ใหม่ที่ CUT
- Token ใหม่เริ่มจาก CUT (ตัดหนังใหม่)
- Require supervisor approval before token starts
- Alert supervisor + manager

---

### Example 4: No Replacement (Material Loss)
```json
{
  "on_fail": "spawn_new_token",
  "target_nodes": ["SEW"],
  "on_scrap": {
    "mode": "none",
    "notification": {
      "roles": ["supervisor"],
      "message_template": "Token {serial} scrapped. No replacement (material loss)."
    }
  }
}
```

**Behavior:**
- Token scrap → ไม่สร้าง token ใหม่
- Log material loss
- Alert supervisor (informational)

---

## 🗄️ Database Schema Changes

### 1. Add Field to `flow_token` Table

```sql
ALTER TABLE flow_token
ADD COLUMN parent_scrapped_token_id INT NULL COMMENT 'Reference to scrapped token (if this is a replacement)',
ADD COLUMN scrap_replacement_mode VARCHAR(50) NULL COMMENT 'How this token was created: manual, auto_start, auto_cut',
ADD INDEX idx_parent_scrapped (parent_scrapped_token_id);

-- Foreign key (optional, for referential integrity)
ALTER TABLE flow_token
ADD CONSTRAINT fk_parent_scrapped
FOREIGN KEY (parent_scrapped_token_id) REFERENCES flow_token(id_token)
ON DELETE SET NULL;
```

### 2. Add Field to `token_event` Metadata

```json
{
  "event_type": "scrap",
  "metadata": {
    "reason": "max_rework_exceeded",
    "rework_count": 3,
    "limit": 3,
    "replacement_mode": "auto_spawn_from_start",
    "replacement_token_id": 123  // If auto spawned
  }
}
```

---

## 🎨 UI/UX Considerations

### 1. Designer UI (Policy Configuration)

**QC Node Properties Panel:**
```
┌─────────────────────────────────────┐
│ QC Node: QC1                       │
├─────────────────────────────────────┤
│ ... (existing fields) ...          │
│                                     │
│ ✨ Scrap Replacement Policy:       │
│ ┌─────────────────────────────────┐ │
│ │ Mode: [Manual ▼]                │ │
│ │                                  │ │
│ │ ☑ Require Approval               │ │
│ │                                  │ │
│ │ Notification Roles:              │ │
│ │ ☑ Supervisor                     │ │
│ │ ☐ Manager                        │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### 2. Supervisor Dashboard (Manual Token Creation)

**Scrap Alert Card:**
```
┌─────────────────────────────────────┐
│ ⚠️ Token Scrapped                   │
├─────────────────────────────────────┤
│ Serial: TOTE-001-05                 │
│ Reason: Max rework exceeded (3/3)  │
│ Scrapped At: 2025-11-02 14:30      │
│                                     │
│ [Create Replacement Token]         │
│   └─ Target: [START ▼]             │
│   └─ [Create]                      │
└─────────────────────────────────────┘
```

### 3. Token History View

**Token Details:**
```
Token: TOTE-001-05
Status: Scrapped
├─ Created: 2025-11-02 10:00
├─ Rework Count: 3
├─ Scrapped: 2025-11-02 14:30
└─ Replacement: TOTE-001-05-REPLACE (Created at START)
```

---

## 🔧 Implementation Phases

### Phase 1: Manual Mode Only (Simple)

**Scope:**
- เพิ่ม `on_scrap.mode = "manual"` ใน policy
- เพิ่ม notification เมื่อ scrap
- เพิ่ม UI สำหรับ supervisor สร้าง token ใหม่

**Effort:** 2-3 hours  
**Risk:** Low (ไม่ auto spawn)

---

### Phase 2: Auto Spawn (Full Feature)

**Scope:**
- เพิ่ม `auto_spawn_from_start` และ `auto_spawn_from_cut` modes
- เพิ่ม runtime logic สำหรับ auto spawn
- เพิ่ม approval flow (if require_approval = true)

**Effort:** 4-6 hours  
**Risk:** Medium (ต้อง test auto spawn logic)

---

### Phase 3: Advanced Features (Future)

**Scope:**
- Scrap reason mapping (material_defect → auto_spawn_from_cut)
- Conditional replacement (by reason)
- Replacement token tracking & analytics

**Effort:** 6-8 hours  
**Risk:** Low (optional features)

---

## ✅ Validation Rules

### Policy Validation

1. **on_scrap.mode** must be one of: `manual`, `auto_spawn_from_start`, `auto_spawn_from_cut`, `none`
2. **require_approval** only applies to auto modes
3. **notification.roles** must be valid role codes
4. **START node** must exist in graph (if using `auto_spawn_from_start`)
5. **CUT node** must exist in graph (if using `auto_spawn_from_cut`)

### Runtime Validation

1. Check `rework_count >= MAX_REWORK_LIMIT` before scrap
2. Verify target node (START/CUT) exists before auto spawn
3. Ensure replacement token serial is unique
4. Link parent_scrapped_token_id correctly

---

## 📝 Documentation Updates Needed

### 1. QC_VS_DECISION_NODES.md
- เพิ่ม section "Scrap Replacement Policy"
- อธิบาย policy modes
- ตัวอย่างการใช้งาน

### 2. BELLAVIER_DAG_RUNTIME_FLOW.md
- เพิ่ม "Phase 7.5: Scrap & Replacement"
- อธิบาย runtime flow
- Token lifecycle diagram

### 3. USER_GUIDE.md
- เพิ่ม "Scrap Replacement Configuration"
- UI screenshots
- Best practices

---

## 🎯 Recommendations

### สำหรับ Production:

1. **เริ่มด้วย Phase 1 (Manual Mode)**
   - ปลอดภัยที่สุด
   - Supervisor มี control เต็มที่
   - ไม่ต้องกังวล auto spawn bugs

2. **เพิ่ม Phase 2 ทีหลัง (ถ้าจำเป็น)**
   - เมื่อเห็น pattern การใช้งานจริง
   - เมื่อ supervisor ขอ auto spawn
   - เมื่อมั่นใจว่า logic ถูกต้อง

3. **Default Policy:**
   ```json
   {
     "on_scrap": {
       "mode": "manual",
       "notification": {
         "roles": ["supervisor"]
       }
     }
   }
   ```

---

## ❓ Open Questions

1. **Should replacement tokens have different serial numbers?**
   - Option A: `TOTE-001-05-REPLACE`
   - Option B: `TOTE-001-06` (next sequential)
   - Option C: `TOTE-001-05-V2`

2. **Should replacement tokens count toward job ticket qty?**
   - Yes: Job ticket qty = original + replacements
   - No: Job ticket qty = original only (replacements are extra)

3. **Should we track material cost for replacements?**
   - Yes: Track material loss
   - No: Just track token count

4. **Approval flow: Who can approve?**
   - Supervisor only?
   - Manager only?
   - Both?

---

## 📊 Summary

### Key Points:

✅ **ใช้โครงสร้าง policy เดียวกับ rework** (ไม่ต้องสร้างใหม่)  
✅ **Phase 1 (Manual) = ปลอดภัย + ง่าย** (2-3 hours)  
✅ **Phase 2 (Auto) = เพิ่มความซับซ้อนเล็กน้อย** (4-6 hours)  
✅ **Default = Manual mode** (supervisor control)  
✅ **Flexible = รองรับหลาย scenarios**

### Next Steps:

1. Review proposal
2. Decide on Phase 1 vs Phase 2
3. Answer open questions
4. Update documentation
5. Implement (if approved)

---

**Status:** Ready for Review  
**Feedback Welcome:** Please review and provide feedback before implementation


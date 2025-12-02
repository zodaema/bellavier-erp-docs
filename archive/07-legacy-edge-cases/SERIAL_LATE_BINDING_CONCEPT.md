# 🎯 Serial Tracking - Late Binding Concept

**Created:** November 2, 2025  
**Status:** 📋 Architecture Decision  
**Priority:** 🔴 Critical - Fundamental to Serial System Design

---

## 🎯 **Core Concept**

### **Serial = Digital Container (NOT Physical Label)**

**Traditional Thinking (❌ Wrong):**
```
Serial = รหัสติดบนสินค้า
- ติดตั้งแต่แรก
- Component ผูกติดกับ serial ตั้งแต่ต้น
- Inflexible
```

**Correct Thinking (✅ Right):**
```
Serial = Digital Twin / Container
- สร้างตอนเริ่ม job (จอง slot)
- Component ผลิตแยก (pool)
- ช่าง assign component → serial ทีหลัง (Late Binding)
- Flexible, scalable
```

---

## 🏭 **Late Binding in Production**

### **Complete Workflow:**

#### **Step 0: Job Creation**
```
Job: Luxury Tote Bag (5 pcs)
Target Qty: 5

System Auto-Generates:
  ┌─ Final Product Serials ─────┐
  │ TOTE-2025-A7F3C9 [available] │
  │ TOTE-2025-B2E1D5 [available] │
  │ TOTE-2025-C9F2A8 [available] │
  │ TOTE-2025-D1A4B7 [available] │
  │ TOTE-2025-E5F8C3 [available] │
  └──────────────────────────────┘
  
Status: "Containers" ready, waiting for components
```

#### **Phase 1: Component Production (NO Final Serial)**

```
Task 1: CUT (ตัดผ้าทำ body)
  
  Input: ผ้า roll 1 ม้วน
  Output: 10 body pieces (เผื่อ defect + future jobs)
  
  System Generates Component Serials:
    BODY-2025-001 ✅
    BODY-2025-002 ✅
    BODY-2025-003 ✅
    ...
    BODY-2025-010 ✅
  
  WIP Log:
    - event_type: progress
    - qty: 10
    - serial_number: NULL  ← ยังไม่รู้ว่าไปกับกระเป๋าไหน
  
  Component Pool:
    ┌─ Available Bodies ─┐
    │ BODY-2025-001 🧵   │
    │ BODY-2025-002 🧵   │
    │ ...                │
    │ BODY-2025-010 🧵   │
    └────────────────────┘

─────────────────────────────────────

Task 2: SEW STRAP (เย็บสาย)
  
  Output: 20 straps (2/bag × 5 + buffer)
  
  System Generates:
    STRAP-2025-001 ✅
    STRAP-2025-002 ✅
    ...
    STRAP-2025-020 ✅
  
  WIP Log:
    - qty: 20
    - serial_number: NULL  ← batch production
  
  Component Pool:
    ┌─ Available Straps ─┐
    │ STRAP-2025-001 🔗  │
    │ STRAP-2025-002 🔗  │
    │ ...                │
    │ STRAP-2025-020 🔗  │
    └────────────────────┘
```

#### **Phase 2: Assembly (LATE BINDING!)**

```
Task 3: ASSEMBLY

Operator Picks Components:
  - BODY-2025-001 (จาก pool ที่ตัดไว้)
  - STRAP-2025-003 (จาก pool ที่เย็บไว้)
  - STRAP-2025-004
  - HW-2025-001 (hardware)
  - LINING-2025-001 (lining)

Assembles into → TOTE-2025-A7F3C9 ✨

System Records:

1. WIP Log:
   - event_type: assembly
   - qty: 1
   - serial_number: TOTE-2025-A7F3C9  ← NOW assigned!
   - components: [BODY-2025-001, STRAP-2025-003, ...]

2. Serial Status Update:
   TOTE-2025-A7F3C9: available → in_use

3. Component Status Update:
   BODY-2025-001: available → used
   STRAP-2025-003: available → used
   STRAP-2025-004: available → used
   HW-2025-001: available → used
   LINING-2025-001: available → used

4. Genealogy Record:
   ┌─ TOTE-2025-A7F3C9 ─────────┐
   │ ├─ BODY-2025-001           │
   │ ├─ STRAP-2025-003          │
   │ ├─ STRAP-2025-004          │
   │ ├─ HW-2025-001             │
   │ └─ LINING-2025-001         │
   └────────────────────────────┘
```

#### **Phase 3: Finishing (WITH Serial)**

```
Task 4: QC
  
  Scan QR: TOTE-2025-A7F3C9
  
  System Shows:
    Product: TOTE-2025-A7F3C9
    Components:
      • BODY-2025-001 (ตัดเมื่อ: 2025-11-01 10:00)
      • STRAP-2025-003 (เย็บเมื่อ: 2025-11-01 11:30)
      • STRAP-2025-004
      • HW-2025-001 (Supplier: XXX)
      • LINING-2025-001
    
    Full Traceability! ✅
  
  WIP Log:
    - serial_number: TOTE-2025-A7F3C9  ← Track with final serial
```

---

## 📊 **Serial Types & Timing**

| Serial Type | When Generated | When Assigned | Track Level |
|-------------|----------------|---------------|-------------|
| **Final Product** | Job creation | Assembly step | Product |
| **Component** | Component task complete | Assembly step | Component |

### **Example:**

```
Final Product Serials (Generated at Job Creation):
  TOTE-2025-A7F3C9 → Created: Nov 1, 09:00
  TOTE-2025-B2E1D5 → Created: Nov 1, 09:00

Component Serials (Generated at Task Completion):
  BODY-2025-001 → Created: Nov 1, 10:00 (CUT task complete)
  STRAP-2025-003 → Created: Nov 1, 11:30 (SEW task complete)

Binding (At Assembly):
  TOTE-2025-A7F3C9 ← [BODY-2025-001, STRAP-2025-003, ...]
    → Linked: Nov 1, 14:00
```

---

## 🎯 **Process Mode Clarification**

### **Piece Mode:**
```
Meaning: Final product tracked individually (มี serial)

Component Production:
  - CUT 10 bodies → batch (serial=NULL)
  - SEW 20 straps → batch (serial=NULL)

Assembly:
  - Pick components → Assign to TOTE-2025-A7F3C9
  - Serial binding happens HERE! ✨

Finishing:
  - QC individual piece (with serial)
  - Pack individual piece (with serial)
```

### **Batch Mode:**
```
Meaning: Process in batch, but final product has serial

Component Production:
  - Same as piece mode (batch)

Assembly:
  - May still be batch
  - But each final product gets serial

QC:
  - Individual inspection (with serial)
```

**Key Difference:**
- **Piece Mode:** Track ทุก step หลัง assembly
- **Batch Mode:** Track batch ส่วนใหญ่, final product มี serial

---

## 🗄️ **Database Architecture**

### **Table 1: serial_generation_log (Final Product Pool)**

```sql
CREATE TABLE serial_generation_log (
  id INT PRIMARY KEY AUTO_INCREMENT,
  serial_number VARCHAR(100) UNIQUE NOT NULL,
  id_job_ticket INT NOT NULL,  -- NEW: Link to job
  prefix VARCHAR(50) NOT NULL,
  serial_type ENUM('final_product', 'component') DEFAULT 'final_product',
  status ENUM('available', 'in_use', 'completed', 'cancelled') DEFAULT 'available',
  generated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  generated_by INT NULL,
  used_at DATETIME NULL,  -- When assigned to WIP log
  completed_at DATETIME NULL,  -- When job completed
  
  INDEX idx_ticket (id_job_ticket),
  INDEX idx_status (status),
  INDEX idx_type_status (serial_type, status)
);
```

### **Table 2: serial_component_pool (Component Pool) - OPTIONAL**

```sql
CREATE TABLE serial_component_pool (
  id INT PRIMARY KEY AUTO_INCREMENT,
  serial_number VARCHAR(100) UNIQUE NOT NULL,
  component_type VARCHAR(50) NOT NULL,  -- BODY, STRAP, HW, LINING
  id_job_task INT NULL,  -- Which task produced it
  id_job_ticket INT NULL,  -- Original job (may produce for multiple jobs)
  status ENUM('available', 'used', 'defect', 'returned') DEFAULT 'available',
  produced_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  produced_by INT NULL,
  used_in_serial VARCHAR(100) NULL,  -- Final product serial
  used_at DATETIME NULL,
  
  INDEX idx_type (component_type),
  INDEX idx_status (status),
  INDEX idx_used_in (used_in_serial),
  FOREIGN KEY (used_in_serial) REFERENCES serial_generation_log(serial_number)
);
```

### **Table 3: serial_genealogy (Assembly Record) - OPTIONAL**

```sql
CREATE TABLE serial_genealogy (
  id INT PRIMARY KEY AUTO_INCREMENT,
  parent_serial VARCHAR(100) NOT NULL,  -- TOTE-2025-A7F3C9
  child_serial VARCHAR(100) NOT NULL,  -- BODY-2025-001
  child_type VARCHAR(50) NOT NULL,  -- component_type
  quantity INT DEFAULT 1,  -- How many? (e.g., 2 straps)
  assigned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  assigned_by INT NULL,
  id_wip_log INT NULL,  -- Which assembly log
  
  INDEX idx_parent (parent_serial),
  INDEX idx_child (child_serial),
  UNIQUE KEY uniq_parent_child (parent_serial, child_serial)
);
```

---

## 🛠️ **Implementation Phases**

### **Phase 2.5A: Final Serial Pool (2-3 hours) - RECOMMENDED FIRST**

**Scope:**
1. ✅ Migration 0008: Enhance serial_generation_log
   - Add: id_job_ticket, status, used_at, completed_at
   
2. ✅ Auto-Generate Hook:
   - Job create → Generate serials = target_qty
   - Both piece & batch mode
   
3. ✅ Serial Pool UI:
   - View serials for ticket
   - Filter by status
   - Re-print QR codes
   - Export CSV
   
4. ✅ Status Auto-Update:
   - WIP log with serial → status: in_use
   - Job complete → status: completed

**What You Get:**
- Final product serials ready
- No more "serial หาย" problem
- Re-print anytime
- Track usage

**What's Missing:**
- Component serial tracking
- Genealogy (what went into what)

---

### **Phase 2.5B: Component Serial + Genealogy (4-6 hours) - OPTIONAL**

**Scope:**
1. ✅ Create serial_component_pool table
2. ✅ Create serial_genealogy table
3. ✅ Auto-generate component serials (per task)
4. ✅ Assembly UI (link components → product)
5. ✅ Genealogy viewer (tree structure)

**What You Get:**
- Full component traceability
- Know which parts went into which product
- Supplier accountability
- Defect tracking to source

**Trade-off:**
- Takes longer (4-6 hours)
- Partial DAG implementation (may need refactor for full DAG)

---

### **Phase 4: Full DAG System (Q1 2026) - COMPREHENSIVE**

**Scope:**
- Everything in Phase 2.5B +
- Parallel production workflow
- Graph designer
- Token-based tracking
- Auto component collection
- Visual bottleneck detection

**What You Get:**
- Future-proof architecture
- No refactoring needed
- Comprehensive system

**Trade-off:**
- Must wait until Q1 2026

---

## 💡 **Decision Tree**

```
Does pilot need component traceability NOW?
  │
  ├─ YES, URGENT → Phase 2.5A + 2.5B (Full, 6-9 hours total)
  │                 Get: Component tracking immediately
  │                 Cost: Partial refactor when DAG arrives
  │
  ├─ YES, but can wait → Phase 2.5A only (2-3 hours)
  │                       Then collect feedback
  │                       Then decide: 2.5B or wait DAG
  │
  └─ NO / UNCERTAIN → Phase 2.5A only (2-3 hours)
                      Final serial sufficient for pilot
                      Component tracking in DAG later
```

---

## 📋 **Validation Changes Needed**

### **Current (Wrong):**
```php
// In ValidationService.php
if ($processMode === 'piece') {
    // Piece mode ต้องมี serial!  ← ❌ Wrong assumption
    if (empty($data['serial_number'])) {
        $errors['serial_number'] = 'Serial required for piece mode';
    }
}
```

### **Correct (Late Binding):**
```php
// Serial is OPTIONAL in ALL steps!
// Operator decides when to assign serial (usually at assembly)

if (!empty($data['serial_number'])) {
    // Validate format, uniqueness, etc.
    // But don't REQUIRE serial
}
```

---

## 🎯 **Component Serial Generation**

### **When to Generate:**

```
Task Type → Generate Component Serial?

CUT (output: bodies) → YES
  - Generate: BODY-2025-001, BODY-2025-002, ...
  - Store in: serial_component_pool
  - WIP Log: serial=NULL (batch tracking)

SEW (output: straps) → YES
  - Generate: STRAP-2025-001, STRAP-2025-002, ...
  
ASSEMBLY (combine components) → NO
  - Use existing final & component serials
  - Create genealogy links
  - WIP Log: serial=TOTE-2025-A7F3C9 (late binding!)

QC (inspect final product) → NO
  - Use final product serial
  - WIP Log: serial=TOTE-2025-A7F3C9
```

---

## 🔗 **Genealogy Linking**

### **Assembly Event Structure:**

```json
{
  "event_type": "assembly",
  "qty": 1,
  "serial_number": "TOTE-2025-A7F3C9",
  "components": [
    {
      "type": "BODY",
      "serial": "BODY-2025-001",
      "qty": 1
    },
    {
      "type": "STRAP",
      "serial": "STRAP-2025-003",
      "qty": 2
    },
    {
      "type": "HW",
      "serial": "HW-2025-001",
      "qty": 1
    },
    {
      "type": "LINING",
      "serial": "LINING-2025-001",
      "qty": 1
    }
  ]
}
```

System creates `serial_genealogy` records:
```
parent: TOTE-2025-A7F3C9 ← child: BODY-2025-001 (qty: 1)
parent: TOTE-2025-A7F3C9 ← child: STRAP-2025-003 (qty: 1)
parent: TOTE-2025-A7F3C9 ← child: STRAP-2025-004 (qty: 1)
parent: TOTE-2025-A7F3C9 ← child: HW-2025-001 (qty: 1)
parent: TOTE-2025-A7F3C9 ← child: LINING-2025-001 (qty: 1)
```

---

## 🎯 **Benefits of Late Binding**

### **1. Flexibility**
```
Component Pool:
  BODY-2025-001
  BODY-2025-002
  BODY-2025-003  ← เลือกอันไหนก็ได้!

Operator picks best quality → TOTE-2025-A7F3C9
```

### **2. Buffer Management**
```
Job 1: 5 bags → Cut 10 bodies (buffer)
  - Use 5 bodies → Job 1
  - Remaining 5 → Available for Job 2! ✅
```

### **3. Defect Handling**
```
BODY-2025-005: QC fail → Mark as 'defect'
  - Don't use in assembly
  - Pick BODY-2025-006 instead
  - Full audit trail
```

### **4. Supplier Accountability**
```
Customer complaint: กระเป๋ารุ่น TOTE-2025-A7F3C9 มีปัญหา

Trace back:
  TOTE-2025-A7F3C9 ← BODY-2025-001
  BODY-2025-001 → Produced: Nov 1, 10:00
                → Operator: John
                → Material: Lot-ABC-123
                → Supplier: XYZ Company

Action: Contact supplier, check other bodies from same lot
```

---

## 🚀 **Implementation Options**

### **Option A: Full Component Tracking (4-6 hours)**

**Implement NOW:**
- ✅ Final serial pool (auto-generate on job create)
- ✅ Component serial pool (auto-generate on task complete)
- ✅ Genealogy tracking (link at assembly)
- ✅ Serial Pool UI (2 levels: final + component)
- ✅ Genealogy viewer (tree structure)

**Pros:**
- Complete traceability immediately
- Supplier accountability
- Defect tracking to source
- Ready for luxury goods compliance

**Cons:**
- 4-6 hours development time
- Partial DAG (may need refactor for full DAG system)
- More complex UI

---

### **Option B: Final Serial Only (2-3 hours)**

**Implement NOW:**
- ✅ Final serial pool (auto-generate on job create)
- ✅ Serial Pool UI (view, re-print, export)
- ✅ Status tracking
- ❌ NO component serial
- ❌ NO genealogy

**Pros:**
- Fast implementation
- Solves "serial หาย" problem
- Simple, focused

**Cons:**
- No component traceability
- Can't track defects to source
- Limited supplier accountability

**Later:**
- Add component tracking when needed (in DAG)

---

### **Option C: Wait for DAG (Q1 2026)**

**Implement LATER:**
- Full DAG system with comprehensive component tracking

**Pros:**
- Most comprehensive
- Future-proof
- No refactoring

**Cons:**
- Must wait months
- Pilot runs without component tracking

---

## 🎯 **Recommendation**

### **For Luxury Goods (High-Value Products):**
→ **Option A** (Full Component Tracking)
- Traceability is critical for brand protection
- Customer complaints must be traceable to source
- Supplier accountability essential
- Worth the 4-6 hour investment

### **For Standard Products:**
→ **Option B** (Final Serial Only)
- Final product serial sufficient
- Component tracking nice-to-have, not critical
- Save time, add later if needed

### **If Budget/Time Constrained:**
→ **Option B first**, then evaluate:
- Collect pilot feedback
- If component tracking needed → Add in DAG
- If not needed → Final serial is enough

---

## 📝 **Next Steps**

1. **Review this document** with stakeholders
2. **Decide:** Option A, B, or C
3. **Implement** chosen option
4. **Document** decision in ROADMAP_V3.md
5. **Update** STATUS.md with progress

---

**Last Updated:** November 2, 2025  
**Decision Pending:** Waiting for stakeholder input  
**Estimated Impact:** High (fundamental to serial system design)


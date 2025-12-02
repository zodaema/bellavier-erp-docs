# 🏭 Dual Production Model - Complete Design
**Date:** November 4, 2025  
**Critical Issue:** System forgot original business model!  
**Status:** 🚨 URGENT - Need to align with reality

---

## 🎯 THE FORGOTTEN CONTEXT:

### **Original Business Model (From BELLAVIER_OPERATION_SYSTEM_DESIGN.md):**

#### **1. Atelier Line (Luxury - Handcrafted)**
```
Characteristics:
• Low volume: 10-50 pieces per job
• Handcrafted by artisans
• High traceability per piece
• FLEXIBLE scheduling (no strict MO)
• Priority: Craft quality + timing history
• Example: Charlotte Aimée limited edition handbag

Customer Value:
✅ Scan serial → See who made it
✅ See time spent per step
✅ Timeline: "Artisan John, 08:00-08:25 (25 min)"

Production Type:
• May NOT have MO (direct order from customer)
• May NOT have strict schedule
• Focus: Quality > Speed
```

#### **2. Batch OEM Line (Mass Production)**
```
Characteristics:
• High volume: 100-1000+ pieces per job
• Standardized process
• Efficiency focus
• STRICT MO + schedule required
• Priority: Cost control + yield
• Example: Rebello car key case wholesale

Customer Value:
✅ Scan serial → See batch info
✅ General tracking (date, batch)
❌ Per-piece timing NOT required

Production Type:
• ALWAYS has MO (customer order)
• STRICT schedule (committed delivery)
• Focus: Speed + Cost
```

---

## 🚨 Current System Problems:

### **Problem 1: No Production Type Field!**
```sql
Current Fields:
• process_mode: 'piece' / 'batch'  ← About HOW to produce
• routing_mode: 'linear' / 'dag'   ← About WHICH workflow engine

Missing:
• production_type: 'hatthasilpa' / 'oem'  ← About BUSINESS MODEL!
```

**Impact:**
- ❌ Cannot distinguish Atelier vs OEM
- ❌ Cannot apply different rules
- ❌ Cannot enforce MO for OEM only

---

### **Problem 2: MO Always Optional**
```php
// Current
id_mo = NULL  // OK for both Atelier and OEM ❌

// Should be
id_mo = NULL  // OK for Atelier only ✅
id_mo REQUIRED for OEM ✅
```

**Impact:**
- ❌ OEM jobs can skip MO (wrong!)
- ❌ No enforcement of business rules

---

### **Problem 3: Workflow Confusion**
```
Current Flow (ทั้ง 2 แบบใช้ flow เดียวกัน):
Graph Designer → Job Ticket → Tokens

Atelier Should Be:
Direct Job → Tokens (flexible, no MO required)

OEM Should Be:
MO (strict) → Graph → Tokens (enforced schedule)
```

---

## 💡 Proposed Solution:

### **Add Production Type Field:**

```sql
-- Migration
ALTER TABLE hatthasilpa_job_ticket 
  ADD COLUMN production_type ENUM('hatthasilpa','oem') NOT NULL DEFAULT 'hatthasilpa'
  COMMENT 'Business line: hatthasilpa (luxury) or oem (mass production)';

ALTER TABLE mo
  ADD COLUMN production_type ENUM('hatthasilpa','oem') NOT NULL DEFAULT 'oem'
  COMMENT 'Business line identifier';
```

---

## 🔄 Revised Dual Flow:

### **Flow 1: Atelier (Luxury - Flexible)**

```
┌────────────────────────────────────────────┐
│ Option A: Direct Job (no MO)               │
├────────────────────────────────────────────┤
│ Manager creates Job directly:              │
│                                            │
│ Input:                                     │
│ • Job Name: "Charlotte Aimée - Batch 3"   │
│ • Production Type: "Atelier" ⭐            │
│ • Qty: 20 pieces                           │
│ • Process Mode: piece                      │
│ • Routing Graph: "Premium Bag V2"         │
│ • Due: "Around Dec 10" (flexible)         │
│ • id_mo: NULL (OK!) ✅                    │
│                                            │
│ [Create Job] → Auto-spawn tokens          │
│                                            │
│ Validation:                                │
│ ✅ production_type = 'hatthasilpa'            │
│ ✅ id_mo can be NULL                      │
│ ✅ Schedule optional                      │
│ ✅ Focus on quality                       │
└────────────────────────────────────────────┘
         │
         ▼
    [Tokens spawned]
         │
         ▼
    [Auto-assign OR manual]
         │
         ▼
    [Operators work]
```

**OR**

```
┌────────────────────────────────────────────┐
│ Option B: With MO (customer order)         │
├────────────────────────────────────────────┤
│ Manager creates MO first:                  │
│                                            │
│ MO Input:                                  │
│ • Production Type: "Atelier" ⭐            │
│ • Customer: "VIP Client ABC"              │
│ • Product: Premium Handbag                │
│ • Qty: 5 pieces (small batch)             │
│ • Due: "Flexible" or "Dec 15"             │
│ • Graph: "Luxury Handbag Process"         │
│                                            │
│ [Create MO] → [Start Production]          │
│   ↓                                        │
│ Auto: Create Job + Spawn Tokens           │
│                                            │
│ Validation:                                │
│ ⚠️ Schedule recommended but not strict   │
│ ✅ Can adjust mid-production              │
└────────────────────────────────────────────┘
```

---

### **Flow 2: OEM (Mass - Strict)**

```
┌────────────────────────────────────────────┐
│ MUST Use MO (No exceptions!)               │
├────────────────────────────────────────────┤
│ Manager creates MO:                        │
│                                            │
│ MO Input:                                  │
│ • Production Type: "OEM" ⭐ REQUIRED       │
│ • Customer: "ABC Trading Co."             │
│ • Product: TOTE Bag Standard              │
│ • Qty: 500 pieces                          │
│ • Due: Nov 30 (STRICT!) ⚠️                │
│ • Graph: "TOTE Production V1" REQUIRED    │
│ • Schedule: Nov 10-25 REQUIRED ⚠️         │
│                                            │
│ [Create MO]                                │
│   ↓                                        │
│ Validation:                                │
│ ✅ production_type = 'oem'                │
│ ✅ id_routing_graph NOT NULL ⚠️          │
│ ✅ scheduled_start/end NOT NULL ⚠️        │
│ ✅ Due date enforced                      │
│   ↓                                        │
│ Status: 'planned'                          │
└────────────────┬───────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────┐
│ Step 2: Schedule & Validate                │
│ [Confirm Schedule] → is_scheduled = 1      │
└────────────────┬───────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────┐
│ Step 3: Start Production (Strict!)         │
│                                            │
│ Button enabled only if:                    │
│ ✅ is_scheduled = 1                       │
│ ✅ scheduled_start <= today               │
│ ✅ Graph selected                         │
│                                            │
│ [Start Production]                         │
│   ↓                                        │
│ Auto:                                      │
│ 1. Create graph_instance (id_mo, id_graph)│
│ 2. Spawn tokens (MO.qty)                  │
│ 3. Auto-assign to operators               │
│ 4. Lock schedule (no changes!)            │
│ 5. Update MO status = 'in_progress'       │
└────────────────┬───────────────────────────┘
                 │
                 ▼
          [Operators work]
                 │
                 ▼
   [Complete on/before due date] ⚠️
```

---

## 🏗️ Database Schema Changes:

### **Migration: Add Production Type**

```php
<?php
/**
 * Migration: Add production_type to support Atelier vs OEM
 */
require_once __DIR__ . '/../tools/migration_helpers.php';

return function (mysqli $db): void {
    // Add to Job Ticket
    $db->query("
        ALTER TABLE hatthasilpa_job_ticket 
        ADD COLUMN production_type ENUM('hatthasilpa','oem') NOT NULL DEFAULT 'hatthasilpa'
        COMMENT 'Business line: hatthasilpa (luxury) or oem (mass production)'
        AFTER routing_mode
    ");
    
    // Add to MO
    $db->query("
        ALTER TABLE mo 
        ADD COLUMN production_type ENUM('hatthasilpa','oem') NOT NULL DEFAULT 'oem'
        COMMENT 'Business line identifier'
        AFTER status
    ");
    
    // Add routing graph to MO
    migration_add_column_if_missing($db, 'mo', 'id_routing_graph',
        "`id_routing_graph` INT(11) DEFAULT NULL COMMENT 'FK to routing_graph'"
    );
    
    migration_add_column_if_missing($db, 'mo', 'graph_instance_id',
        "`graph_instance_id` INT(11) DEFAULT NULL COMMENT 'FK to job_graph_instance'"
    );
};
```

---

## 🎯 Business Rules by Type:

### **Atelier Rules:**
```php
if ($productionType === 'hatthasilpa') {
    // Flexible!
    $moRequired = false;          // ✅ Can create job directly
    $scheduleRequired = false;    // ✅ Flexible timeline
    $graphRequired = true;        // ✅ Still need process
    $autoAssign = true;           // ✅ Auto-distribute
    
    // Validation
    // ⚠️ Recommend schedule but allow override
    // ✅ Can adjust mid-production
    // ✅ Quality > Speed
}
```

### **OEM Rules:**
```php
if ($productionType === 'oem') {
    // Strict!
    $moRequired = true;           // ⚠️ MUST have MO
    $scheduleRequired = true;     // ⚠️ MUST schedule
    $graphRequired = true;        // ⚠️ MUST select graph
    $autoAssign = true;           // ✅ Auto-distribute
    
    // Validation
    // ⚠️ Cannot start before scheduled_start
    // ⚠️ Cannot change schedule after start
    // ⚠️ MUST complete before due_date
}
```

---

## 📋 UI Flow by Production Type:

### **Atelier UI Flow:**

**Page: Hatthasilpa Jobs (New Page!)**

```html
<h1>🎨 Atelier Production</h1>
<p>Luxury handcrafted line - Flexible workflow</p>

<form id="formAtelierJob">
  <input name="job_name" placeholder="Charlotte Aimée Batch 3">
  <input name="qty" type="number" placeholder="20" max="100">
  <select name="id_routing_graph">
    <option>Premium Bag V2</option>
  </select>
  <input name="due_date" type="date" placeholder="Flexible">
  
  <!-- Optional MO -->
  <select name="id_mo">
    <option value="">-- No MO (Direct Job) --</option>
    <option value="1">MO-ATELIER-001</option>
  </select>
  
  <button>[Create & Start]</button>
</form>

<!-- 1 STEP! Create → Auto-spawn → Work! -->
```

**Features:**
- ✅ No strict validation
- ✅ Can start immediately
- ✅ MO optional
- ✅ Schedule flexible

---

### **OEM UI Flow:**

**Page: Manufacturing Orders (OEM)**

```html
<h1>🏭 OEM Production</h1>
<p>Mass production - Strict schedule & validation</p>

<form id="formOEM_MO">
  <input name="mo_code" placeholder="MO-2025-001" required>
  <input name="customer_name" placeholder="ABC Trading" required>
  <select name="id_product" required>
    <option>TOTE Bag Standard</option>
  </select>
  <input name="qty" type="number" placeholder="500" required>
  <input name="due_date" type="date" required>
  
  <!-- REQUIRED -->
  <select name="id_routing_graph" required>
    <option value="">-- Select Process --</option>
    <option>TOTE Production V1</option>
  </select>
  
  <!-- REQUIRED -->
  <input name="scheduled_start" type="date" required>
  <input name="scheduled_end" type="date" required>
  
  <button>[Create MO]</button>
</form>

<!-- MO List -->
<table>
  <tr>
    <td>MO-2025-001</td>
    <td>TOTE Bag (500)</td>
    <td>Nov 10-25</td>
    <td>
      <!-- Disabled until scheduled -->
      <button class="btn-start" 
              disabled={!is_scheduled || !graph}>
        Start Production
      </button>
    </td>
  </tr>
</table>

<!-- 3 STEPS: Create → Schedule → Start -->
```

**Features:**
- ⚠️ Strict validation
- ⚠️ Must schedule before start
- ⚠️ MO required
- ⚠️ Cannot bypass

---

## 🎨 Complete Architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                    BELLAVIER GROUP ERP                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  🎨 Atelier Line            🏭 OEM Line                     │
│  (Luxury)                   (Mass Production)               │
│                                                             │
├──────────────────────────┬──────────────────────────────────┤
│                          │                                  │
│  Hatthasilpa Job             │  MO (Required)                   │
│  (Direct)                │  (Strict Schedule)               │
│  • Flexible              │  • Committed                     │
│  • MO optional           │  • MO required                   │
│  • Quick start           │  • Validation heavy              │
│                          │                                  │
│         ↓                │         ↓                        │
│   Select Graph           │   Select Graph (in MO)           │
│   (Luxury processes)     │   (Standard processes)           │
│                          │                                  │
│         ↓                │         ↓                        │
│   Spawn Tokens           │   Schedule → Start → Spawn       │
│   (Immediate)            │   (Validated)                    │
│                          │                                  │
└──────────┬───────────────┴─────────────┬────────────────────┘
           │                             │
           └──────────────┬──────────────┘
                          │
                          ▼
           ┌──────────────────────────────┐
           │    DAG Graph Execution        │
           │    (Unified Engine)           │
           └──────────────┬───────────────┘
                          │
                          ▼
           ┌──────────────────────────────┐
           │      Work Queue              │
           │   (Shows production_type)    │
           │   🎨 Atelier or 🏭 OEM       │
           └──────────────────────────────┘
```

---

## 📋 Implementation Plan:

### **Phase 1: Database (1 hour)**
```sql
1. Add production_type to hatthasilpa_job_ticket
2. Add production_type to mo
3. Add id_routing_graph to mo
4. Add graph_instance_id to mo
5. Migrate existing data:
   - Jobs with id_mo = NULL → 'hatthasilpa'
   - Jobs with id_mo NOT NULL → 'oem'
```

### **Phase 2: Business Rules (2 hours)**
```php
// In mo.php / hatthasilpa_job_ticket.php

function validateJobCreation($data, $productionType) {
    if ($productionType === 'oem') {
        // Strict validation
        if (!$data['id_mo']) {
            throw new Exception('MO required for OEM production');
        }
        if (!$data['id_routing_graph']) {
            throw new Exception('Routing graph required for OEM');
        }
        if (!$data['scheduled_start'] || !$data['scheduled_end']) {
            throw new Exception('Schedule required for OEM');
        }
    } else if ($productionType === 'hatthasilpa') {
        // Flexible validation
        if (!$data['id_routing_graph']) {
            throw new Exception('Routing graph required');
        }
        // MO & schedule optional
    }
}
```

### **Phase 3: UI Separation (3-4 hours)**

**Option A: Separate Pages (Recommended)**
```
Manufacturing Orders (OEM)
  - Strict MO workflow
  - Full validation
  - Customer orders

Hatthasilpa Jobs
  - Direct job creation
  - Flexible workflow
  - Limited editions
```

**Option B: Single Page with Mode Toggle**
```
Production Planning
  [OEM Mode] [Atelier Mode]
  
  // Different forms based on mode
```

### **Phase 4: Work Queue Display (1 hour)**
```javascript
// Show production type badge
{
    production_type === 'oem' ? 
    '🏭 OEM: ' + mo_code :
    '🎨 Hatthasilpa: ' + job_name
}
```

### **Phase 5: Testing (1-2 hours)**
- Test Atelier flow (no MO)
- Test OEM flow (with MO)
- Test validation rules
- Test Work Queue display

**Total: 8-10 hours**

---

## 🎯 Key Decisions Needed:

### **Decision 1: How to determine production_type?**

**Option A: At Job/MO creation (Manual)** ⭐ Recommended
```
Manager selects:
• Production Type: [Atelier] [OEM]
```

**Option B: Auto-detect from Product**
```
Product table:
• product_line ENUM('hatthasilpa','oem')

Auto-fill when product selected
```

**Option C: Auto-detect from MO existence**
```
if (has MO) → OEM
else → Atelier
```

**Recommendation:** Option A (explicit is better!)

---

### **Decision 2: Page Structure**

**Option A: Separate Pages** ⭐ Recommended
```
Sidebar:
├─ Manufacturing Orders (OEM)
├─ Hatthasilpa Jobs
└─ Work Queue (unified)
```

**Benefits:**
- Clear separation
- Different UX per type
- No confusion

**Option B: Unified Page with Tabs**
```
Production Planning
[OEM] [Atelier]
```

**Benefits:**
- Single page
- Easy switching

**Recommendation:** Option A (clearer!)

---

### **Decision 3: Graph Assignment**

**Hatthasilpa:**
- Graph selection at job creation
- Can use experimental graphs
- Can change mid-production (if needed)

**OEM:**
- Graph selection at MO creation
- Must use published graphs only
- Cannot change after start (locked!)

---

## 🔄 Revised Complete Flow:

### **Atelier (Luxury):**
```
Page: Hatthasilpa Jobs

[Create New Job]
  ↓
Input:
• Job Name ✅
• Qty (10-50) ✅
• Graph ✅
• Due (flexible) ⚠️ Optional
• MO ⚠️ Optional
  ↓
[Create & Start] (1 Click!)
  ↓
Auto:
• Spawn tokens
• Assign to artisans
• Send notifications
  ↓
Operators work
  ↓
Complete (flexible timeline)

SIMPLE! FAST!
```

### **OEM (Mass Production):**
```
Page: Manufacturing Orders

[Create New MO]
  ↓
Input:
• Customer ⚠️ Required
• Product ⚠️ Required
• Qty (100-1000) ⚠️ Required
• Due Date ⚠️ Required
• Graph ⚠️ Required
• Schedule ⚠️ Required
  ↓
[Create MO]
  ↓
Status: 'planned'
  ↓
[Schedule] (validate resources)
  ↓
Status: 'scheduled'
  ↓
[Start Production] (on scheduled_start date)
  ↓
Auto:
• Create graph instance
• Spawn tokens
• Auto-assign
• Lock schedule
  ↓
Operators work
  ↓
Complete on/before due date ⚠️

STRUCTURED! COMMITTED!
```

---

## 💡 Comparison:

| Aspect | Atelier | OEM |
|--------|---------|-----|
| Volume | 10-50 | 100-1000+ |
| MO | Optional | Required |
| Schedule | Flexible | Strict |
| Graph | Any published | Published only |
| Due Date | Flexible | Committed |
| Start | Immediate | Scheduled |
| Mid-change | Allow | Lock |
| Focus | Quality | Efficiency |
| Example | Limited handbag | Wholesale TOTE |

---

## 🚀 Implementation Recommendation:

### **Priority 1: Add production_type (URGENT!)**
- Migration (30 min)
- Update existing data (30 min)
- **Total: 1 hour**

### **Priority 2: Separate UI (HIGH)**
- Hatthasilpa Jobs page (3 hours)
- OEM MO enhancement (2 hours)
- **Total: 5 hours**

### **Priority 3: Business Rules (HIGH)**
- Validation by type (2 hours)
- Testing (2 hours)
- **Total: 4 hours**

**Grand Total: 10 hours**

---

## 🎯 What Was Forgotten:

### **Original Vision:**
```
✅ Hatthasilpa: Flexible, artisan-focused
✅ OEM: Structured, customer-committed
```

### **Current System:**
```
❌ One size fits all
❌ No production_type distinction
❌ Same rules for both
❌ MO optional for everyone
```

### **Impact:**
```
⚠️ Cannot enforce OEM commitments
⚠️ Atelier workflow too complex
⚠️ Business model lost
⚠️ User confusion
```

---

## 🎊 After Fix:

### **Benefits:**
1. ✅ Clear business model
2. ✅ Hatthasilpa: Simple & flexible
3. ✅ OEM: Structured & committed
4. ✅ No confusion
5. ✅ Proper validation
6. ✅ Customer satisfaction

---

**🎯 ต้องการให้แก้ไขตอนนี้เลยไหมครับ?**

**เวลา:** 10 ชั่วโมง  
**ความเสี่ยง:** ต่ำ (additive change)  
**คุณค่า:** CRITICAL (align with business model!)

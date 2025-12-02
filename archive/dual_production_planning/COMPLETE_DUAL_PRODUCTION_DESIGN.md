# 🏭🎨 Complete Dual Production Design - Final Architecture
**Date:** November 5, 2025 00:00 ICT  
**Purpose:** ตอบคำถามสำคัญ 3 ข้อ และออกแบบ flow สมบูรณ์  
**Status:** 🎯 FINAL DESIGN - Ready for approval

---

## 🎯 คำถามสำคัญทั้ง 3 ข้อ:

### **Q1: Product 1 ตัว มีทั้ง Atelier และ Batch pattern ได้ไหม?**

**คำตอบ: ได้! และควรทำ!** ✅

**เหตุผล:**
- สินค้าเดียวกันอาจผลิตได้ทั้ง 2 แบบ:
  - **Hatthasilpa:** Limited edition (10 ชิ้น, handcrafted, premium price)
  - **OEM:** Wholesale batch (1000 ชิ้น, standard, economy price)
- ตัวอย่าง: TOTE Bag
  - Charlotte Aimée Collection = Atelier (limited, premium)
  - Rebello Retail Stock = OEM (bulk, standard)

**Database Design:**

```sql
-- Product table enhancement
ALTER TABLE product 
  ADD COLUMN production_lines SET('hatthasilpa','oem') NOT NULL DEFAULT 'oem'
  COMMENT 'Which production lines can produce this product: atelier, oem, or both';

Examples:
  • Premium Handbag: production_lines = 'hatthasilpa' (luxury only)
  • TOTE Bag: production_lines = 'atelier,oem' (both!)
  • Standard Wallet: production_lines = 'oem' (mass only)
```

**How It Works:**

```php
// When creating MO/Job:
$product = getProduct($idProduct);

// Check if product supports selected type
if ($requestedType === 'hatthasilpa' && !in_array('hatthasilpa', $product['production_lines'])) {
    throw new Exception('This product cannot be produced in Atelier line');
}

// UI: Disable option if product doesn't support it
<select name="production_type">
  <option value="hatthasilpa" ${product.supports_atelier ? '' : 'disabled'}>
    🎨 Atelier
  </option>
  <option value="oem" ${product.supports_oem ? '' : 'disabled'}>
    🏭 OEM
  </option>
</select>
```

**Pattern Handling:**

```
Product: TOTE Bag (supports both)
  ↓
  ├─ Atelier Pattern:
  │  • Premium leather
  │  • Hand-stitched details
  │  • Custom lining
  │  • Luxury hardware
  │  • Graph: "Premium TOTE Process" (8 nodes, artisan-focused)
  │
  └─ OEM Pattern:
     • Standard leather
     • Machine-stitched
     • Standard lining
     • Economy hardware
     • Graph: "Standard TOTE Process" (5 nodes, efficiency-focused)
```

**Implementation:**
- Pattern table มีอยู่แล้ว!
- เพิ่ม: `production_line` ENUM('hatthasilpa','oem') to pattern table
- Link: product → multiple patterns (1 per production_line)

---

### **Q2: MO ควรให้เลือก type ไหม? หรือแยกหน้า?**

**คำตอบ: แยกหน้าดีกว่า!** ⭐ **Recommended**

**Option A: แยกหน้า (Recommended)** ✅

```
Sidebar:
├─ 🏭 Manufacturing Orders (OEM)
│  • สำหรับ customer orders
│  • Volume: 100+ pieces
│  • Strict MO + schedule
│  • Permission: mo.create, mo.manage
│
└─ 🎨 Hatthasilpa Jobs
   • สำหรับ limited editions
   • Volume: 10-50 pieces
   • Flexible, no strict MO
   • Permission: hatthasilpa.job.create, hatthasilpa.job.manage
```

**Benefits:**
- ✅ ชัดเจนมาก - ไม่งง
- ✅ UX แยกตาม workflow
- ✅ Permission แยกได้
- ✅ Form fields ต่างกัน (OEM มี schedule, Hatthasilpa ไม่มี)

**Drawbacks:**
- ⚠️ 2 pages to maintain (but different enough!)

---

**Option B: Single Page with Tabs** (Alternative)

```
Page: Production Planning
[🎨 Atelier] [🏭 OEM]

// Form changes based on selected tab
```

**Benefits:**
- ✅ Single page

**Drawbacks:**
- ⚠️ Complex conditional UI
- ⚠️ Easy to confuse
- ⚠️ Less clear separation

---

**Recommendation:** **Option A - แยกหน้า** ⭐

**เพราะ:**
- Workflows ต่างกันมาก (1 step vs 3 steps)
- Form fields ต่างกัน (Atelier simple, OEM complex)
- Users ต่างกัน (Artisan manager vs Production planner)
- Permission control ง่ายกว่า

---

### **Q3: Flow หลัง MO/Job เป็นยังไง? Job Ticket ยังใช้ไหม?**

**คำตอบ: แยกตาม routing_mode!**

```
┌─────────────────────────────────────────────────────┐
│ Decision Tree: What Happens After Create?          │
└─────────────────────────────────────────────────────┘
           │
           ▼
    [Check routing_mode]
           │
     ┌─────┴─────┐
     │           │
     ▼           ▼
  LINEAR       DAG
     │           │
     │           └──────────────────────────┐
     │                                      │
     ▼                                      ▼
┌──────────────────┐           ┌──────────────────────┐
│ Job Ticket       │           │ Graph Instance       │
│ (Legacy)         │           │ (New)                │
├──────────────────┤           ├──────────────────────┤
│ • Create tasks   │           │ • Link to graph      │
│ • Manual steps   │           │ • Auto: Create nodes │
│ • Sequential     │           │ • Auto: Spawn tokens │
│ • Old UI         │           │ • Auto: Assign       │
└────────┬─────────┘           └─────────┬────────────┘
         │                               │
         ▼                               ▼
   [Job Ticket Page]              [Work Queue]
   (Old desktop UI)               (Modern mobile UI)
```

**CRITICAL DECISION: Job Ticket Role in DAG Mode**

**Recommendation: DEPRECATE Job Ticket for DAG!** ⭐

**Why:**
```
Job Ticket = Linear concept
  • Manual task creation
  • Sequential workflow
  • Desktop-centric

DAG = Graph concept
  • Auto node instances
  • Parallel workflow
  • Mobile-first

Mixing both = CONFUSION!
```

---

## 🔄 **FINAL COMPLETE FLOW DESIGN:**

### **Flow 1: 🎨 Atelier (Luxury - Flexible)**

```
┌────────────────────────────────────────────────────┐
│ Step 1: Create Hatthasilpa Job                         │
│ Page: Hatthasilpa Jobs                                 │
├────────────────────────────────────────────────────┤
│                                                    │
│ Form:                                              │
│ • Job Name: "Charlotte Aimée Batch 3" *           │
│ • Product: [Dropdown - Atelier products only]     │
│ • Quantity: 20 pieces (max 100) *                 │
│ • Routing Graph: "Premium Bag V2" *               │
│ • Due Date: (optional, flexible)                   │
│ • Link to MO: (optional)                          │
│                                                    │
│ [Create & Start Production] ← 1 Click!            │
│                                                    │
│ Validation:                                        │
│ ✅ Product supports atelier                       │
│ ✅ Qty <= 100                                     │
│ ✅ Graph selected                                 │
│ ⚠️ MO optional                                    │
│ ⚠️ Schedule optional                              │
└────────────────┬───────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────┐
│ Auto-Actions (Backend)                             │
├────────────────────────────────────────────────────┤
│ 1. INSERT INTO hatthasilpa_job_ticket                 │
│    (job_name, target_qty, production_type='hatthasilpa',│
│     routing_mode='dag', id_routing_graph, id_mo)  │
│                                                    │
│ 2. INSERT INTO job_graph_instance                 │
│    (id_job_ticket, id_graph, status='active')     │
│                                                    │
│ 3. CREATE node_instance (for each node in graph)  │
│                                                    │
│ 4. SPAWN TOKENS (qty = 20)                        │
│    - Generate serials: TOTE-2025-001 to -020     │
│    - Place at START node                          │
│                                                    │
│ 5. AUTO-ASSIGN (optional)                         │
│    - Load balancing to artisans                   │
│    - OR queue for manual assignment               │
│                                                    │
│ 6. CREATE notifications                           │
│                                                    │
│ 7. UPDATE job status = 'in_progress'              │
└────────────────┬───────────────────────────────────┘
                 │
                 ▼
           [Work Queue]
           Operators work!
```

**Total Manager Steps: 1** ✅

---

### **Flow 2: 🏭 OEM (Mass - Strict)**

```
┌────────────────────────────────────────────────────┐
│ Step 1: Create MO                                  │
│ Page: Manufacturing Orders                         │
├────────────────────────────────────────────────────┤
│                                                    │
│ Form:                                              │
│ • MO Code: Auto-generate *                        │
│ • Customer Name: "ABC Trading Co." *              │
│ • Product: [Dropdown - OEM products only]         │
│ • Quantity: 500 pieces *                          │
│ • Due Date: Nov 30, 2025 *                        │
│ • Routing Graph: "TOTE Production V1" *           │
│ • Scheduled Start: Nov 10 *                       │
│ • Scheduled End: Nov 25 *                         │
│                                                    │
│ [Create MO]                                       │
│                                                    │
│ Validation:                                        │
│ ✅ Product supports oem                           │
│ ✅ Customer required                              │
│ ✅ Qty >= 100 (typical)                           │
│ ✅ Graph required                                 │
│ ✅ Schedule required                              │
│ ✅ Due date >= scheduled_end                      │
│                                                    │
│ Result: MO status = 'planned'                     │
└────────────────┬───────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────┐
│ Step 2: Schedule Review & Confirm                  │
│ Page: Manufacturing Orders (same page)             │
├────────────────────────────────────────────────────┤
│                                                    │
│ Manager reviews:                                   │
│ ✅ Material availability                          │
│ ✅ Operator capacity                              │
│ ✅ Work center availability                       │
│ ✅ Timeline feasible                              │
│                                                    │
│ [Confirm Schedule]                                │
│                                                    │
│ Backend:                                           │
│ UPDATE mo SET is_scheduled = 1                    │
│                                                    │
│ Result: MO status = 'scheduled'                   │
│         Button "Start Production" enabled         │
└────────────────┬───────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────┐
│ Step 3: Start Production (on scheduled_start date) │
│ Page: Manufacturing Orders                         │
├────────────────────────────────────────────────────┤
│                                                    │
│ [Start Production] button                         │
│   - Enabled only if:                              │
│     ✅ is_scheduled = 1                           │
│     ✅ today >= scheduled_start_date              │
│     ✅ id_routing_graph NOT NULL                  │
│                                                    │
│ Click: [Start Production]                         │
└────────────────┬───────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────────────────┐
│ Auto-Actions (Backend)                             │
├────────────────────────────────────────────────────┤
│ 1. INSERT INTO job_graph_instance                 │
│    (id_mo, id_graph, status='active')             │
│    ⚠️ NO Job Ticket created!                     │
│                                                    │
│ 2. CREATE node_instance (for each node)           │
│                                                    │
│ 3. SPAWN TOKENS (qty = 500)                       │
│    - Generate serials: TOTE-2025-001 to -500     │
│    - Place at START node                          │
│                                                    │
│ 4. AUTO-ASSIGN                                    │
│    - Load balancing algorithm                     │
│    - Distribute 500 tokens to operators           │
│                                                    │
│ 5. CREATE notifications                           │
│                                                    │
│ 6. UPDATE mo                                       │
│    SET graph_instance_id = X,                     │
│        status = 'in_progress',                    │
│        started_at = NOW()                         │
│                                                    │
│ 7. LOCK schedule (cannot change!)                 │
└────────────────┬───────────────────────────────────┘
                 │
                 ▼
           [Work Queue]
           Operators work!
```

**Total Manager Steps: 3** ✅

---

## 🏗️ **Database Schema - Complete:**

### **Migration: 2025_11_dual_production_complete.php**

```php
<?php
require_once __DIR__ . '/../tools/migration_helpers.php';

return function (mysqli $db): void {
    
    // ============================================
    // 1. Product Enhancement
    // ============================================
    
    // Add production_lines to product
    $db->query("
        ALTER TABLE product 
        ADD COLUMN production_lines SET('hatthasilpa','oem') NOT NULL DEFAULT 'oem'
        COMMENT 'Which production lines support this product: atelier, oem, or both'
        AFTER id_category
    ");
    
    // Migrate existing products (example - adjust based on real data)
    $db->query("
        UPDATE product 
        SET production_lines = CASE
            WHEN id_category IN (23) THEN 'atelier,oem'  -- Bags (both)
            WHEN id_category IN (24) THEN 'oem'          -- Accessories (OEM only)
            ELSE 'hatthasilpa'                                -- Default: Atelier
        END
    ");
    
    // ============================================
    // 2. Pattern Enhancement
    // ============================================
    
    migration_add_column_if_missing($db, 'pattern', 'production_line',
        "`production_line` ENUM('hatthasilpa','oem') NOT NULL DEFAULT 'hatthasilpa' 
         COMMENT 'Which production line this pattern is for'"
    );
    
    // Link pattern to routing graph
    migration_add_column_if_missing($db, 'pattern', 'id_routing_graph',
        "`id_routing_graph` INT(11) DEFAULT NULL 
         COMMENT 'FK to routing_graph - recommended production process'"
    );
    
    // ============================================
    // 3. MO Enhancement
    // ============================================
    
    migration_add_column_if_missing($db, 'mo', 'production_type',
        "`production_type` ENUM('hatthasilpa','oem') NOT NULL DEFAULT 'oem'
         COMMENT 'Production line type'"
    );
    
    migration_add_column_if_missing($db, 'mo', 'id_routing_graph',
        "`id_routing_graph` INT(11) DEFAULT NULL 
         COMMENT 'FK to routing_graph - selected production process'"
    );
    
    migration_add_column_if_missing($db, 'mo', 'graph_instance_id',
        "`graph_instance_id` INT(11) DEFAULT NULL 
         COMMENT 'FK to job_graph_instance - active execution'"
    );
    
    // ============================================
    // 4. Job Ticket Enhancement
    // ============================================
    
    migration_add_column_if_missing($db, 'hatthasilpa_job_ticket', 'production_type',
        "`production_type` ENUM('hatthasilpa','oem') NOT NULL DEFAULT 'hatthasilpa'
         COMMENT 'Production line type'"
    );
    
    migration_add_column_if_missing($db, 'hatthasilpa_job_ticket', 'id_routing_graph',
        "`id_routing_graph` INT(11) DEFAULT NULL 
         COMMENT 'FK to routing_graph - for quick reference'"
    );
    
    // ============================================
    // 5. Graph Instance Enhancement
    // ============================================
    
    // Link directly to MO (bypass Job Ticket for DAG!)
    migration_add_column_if_missing($db, 'job_graph_instance', 'id_mo',
        "`id_mo` INT(11) DEFAULT NULL 
         COMMENT 'FK to mo - direct link for OEM production'"
    );
    
    // ============================================
    // 6. Migrate Existing Data
    // ============================================
    
    // Set production_type for existing job tickets
    $db->query("
        UPDATE hatthasilpa_job_ticket 
        SET production_type = CASE 
            WHEN id_mo IS NULL THEN 'hatthasilpa'
            WHEN target_qty < 100 THEN 'hatthasilpa'
            ELSE 'oem'
        END
    ");
    
    // Set id_routing_graph for existing job tickets from graph_instance
    $db->query("
        UPDATE hatthasilpa_job_ticket jt
        JOIN job_graph_instance jgi ON jt.graph_instance_id = jgi.id_instance
        SET jt.id_routing_graph = jgi.id_graph
        WHERE jt.routing_mode = 'dag'
    ");
};
```

---

## 🔄 **COMPLETE FLOW ARCHITECTURE:**

### **Scenario 1: Hatthasilpa Job (No MO)**

```
Page: 🎨 Hatthasilpa Jobs

[Create Job Form]
  ↓
Product: TOTE Bag
  ↓ (Check product.production_lines)
  ✅ Supports 'hatthasilpa'
  ↓
Auto-load: Atelier patterns for TOTE Bag
  • Premium TOTE Pattern (luxury leather, hand-stitched)
  • Recommended Graph: "Premium TOTE Process" (8 nodes)
  ↓
Input:
  • Job Name: "Charlotte Aimée Limited"
  • Qty: 20
  • Graph: "Premium TOTE Process" (from pattern)
  • Due: (optional)
  ↓
[Create & Start] ← 1 Click!
  ↓
Backend:
  1. INSERT hatthasilpa_job_ticket
     (production_type='hatthasilpa', routing_mode='dag', 
      id_mo=NULL, id_routing_graph=X)
     
  2. INSERT job_graph_instance
     (id_job_ticket=Y, id_graph=X, id_mo=NULL)
     
  3. CREATE node_instances
  
  4. SPAWN 20 tokens
  
  5. Auto-assign to artisans
  ↓
[Work Queue]
  Display:
  🎨 Atelier
  Job: Charlotte Aimée Limited
  Token: TOTE-2025-001
  Station: Cutting
  [Start Work]
```

---

### **Scenario 2: Atelier with MO (VIP Customer Order)**

```
Page: 🎨 Hatthasilpa Jobs

[Create Job Form]
  ↓
Product: Premium Handbag
  ↓
Input:
  • Job Name: "VIP Client ABC - Custom Order"
  • Qty: 5
  • Graph: "Luxury Handbag Process"
  • Due: Dec 15
  • Link to MO: [Optional dropdown]
    └─ "MO-ATELIER-001 (VIP Client ABC, 5 pcs)" ← Select!
  ↓
[Create & Start]
  ↓
Backend:
  1. INSERT hatthasilpa_job_ticket
     (production_type='hatthasilpa', id_mo=123)
     
  2. INSERT job_graph_instance
     (id_job_ticket=Y, id_mo=123, id_graph=X)
     
  3. SPAWN 5 tokens
  
  4. UPDATE mo status (if linked)
  ↓
[Work Queue]
  Display:
  🎨 Atelier
  MO: MO-ATELIER-001 (VIP Client ABC)
  Job: Custom Order
  Token: HANDBAG-2025-001
```

---

### **Scenario 3: OEM Production (Customer Order)**

```
Page: 🏭 Manufacturing Orders

[Create MO Form]
  ↓
Product: TOTE Bag
  ↓ (Check product.production_lines)
  ✅ Supports 'oem'
  ↓
Auto-load: OEM patterns for TOTE Bag
  • Standard TOTE Pattern (standard leather, machine-stitched)
  • Recommended Graph: "Standard TOTE Process" (5 nodes)
  ↓
Input:
  • MO Code: Auto "MO-2025-001"
  • Customer: "ABC Trading Co." *
  • Product: TOTE Bag *
  • Qty: 500 *
  • Due: Nov 30 *
  • Graph: "Standard TOTE Process" (from pattern) *
  • Schedule Start: Nov 10 *
  • Schedule End: Nov 25 *
  ↓
[Create MO]
  ↓
Backend:
  INSERT INTO mo
  (mo_code, id_product, qty, due_date,
   production_type='oem', id_routing_graph=X,
   scheduled_start_date, scheduled_end_date,
   status='planned')
  ↓
MO List shows:
  MO-2025-001 | TOTE Bag | 500 | Nov 10-25 | Planned
  [Schedule] button enabled
  ↓
Manager clicks [Schedule] (after resource check)
  ↓
Backend:
  UPDATE mo SET is_scheduled = 1, status = 'scheduled'
  ↓
MO List shows:
  MO-2025-001 | TOTE Bag | 500 | Nov 10-25 | Scheduled
  [Start Production] button enabled (if today >= Nov 10)
  ↓
On Nov 10, Manager clicks [Start Production]
  ↓
Backend:
  1. INSERT job_graph_instance
     (id_mo=Z, id_graph=X, status='active')
     ⚠️ NO hatthasilpa_job_ticket! (Direct MO → Instance!)
     
  2. CREATE node_instances
  
  3. SPAWN 500 tokens
  
  4. Auto-assign to operators
  
  5. UPDATE mo
     SET graph_instance_id=Y,
         status='in_progress',
         started_at=NOW()
  
  6. LOCK schedule (cannot change)
  ↓
[Work Queue]
  Display:
  🏭 OEM
  MO: MO-2025-001 (ABC Trading)
  Product: TOTE Bag (500 pcs)
  Due: Nov 30 ⚠️
  Token: TOTE-2025-001
  Station: Cutting
  [Start Work]
```

**Total Manager Steps: 3** ✅

---

## 📊 **Data Model - Complete:**

```
product (master data)
  ├─ id_product
  ├─ sku, name
  ├─ id_category
  └─ production_lines SET('hatthasilpa','oem')  ⭐ NEW!
      │
      └─ Determines which workflows available
      
pattern (production methods)
  ├─ id_pattern
  ├─ id_product (FK)
  ├─ pattern_code
  ├─ production_line ENUM('hatthasilpa','oem')  ⭐ NEW!
  └─ id_routing_graph (recommended)  ⭐ NEW!
      │
      └─ 1 product can have multiple patterns!

┌─────────────────────────────────────────────────┐
│ Atelier Flow                                    │
└─────────────────────────────────────────────────┘
hatthasilpa_job_ticket  ⭐ For Atelier (optional MO)
  ├─ production_type = 'hatthasilpa'
  ├─ id_mo (nullable)
  ├─ id_routing_graph
  └─ routing_mode = 'dag'
      │
      └─> job_graph_instance
          (id_job_ticket, id_graph, id_mo)

┌─────────────────────────────────────────────────┐
│ OEM Flow                                        │
└─────────────────────────────────────────────────┘
mo  ⭐ For OEM (required!)
  ├─ production_type = 'oem'
  ├─ id_routing_graph  ⭐ NEW!
  └─ graph_instance_id  ⭐ NEW!
      │
      └─> job_graph_instance
          (id_mo, id_graph)
          ⚠️ NO Job Ticket! Direct!
          
┌─────────────────────────────────────────────────┐
│ Unified Execution (Both use same engine!)      │
└─────────────────────────────────────────────────┘
job_graph_instance  ⭐ Supports BOTH!
  ├─ id_instance
  ├─ id_graph (FK to routing_graph)
  ├─ id_job_ticket (nullable - for Atelier)  ⭐
  ├─ id_mo (nullable - for OEM)  ⭐ NEW!
  └─ status
      │
      └─> flow_token
          (id_instance, serial, current_node)
          │
          └─> Work Queue (unified for both!)
```

---

## 🎯 **ตอบคำถามทั้ง 3 ข้อ:**

### **Q1: Product 1 ตัว มีทั้ง Atelier และ Batch pattern ได้ไหม?**

**ตอบ: ได้! ออกแบบแบบนี้:**

```sql
-- Product level
product.production_lines = 'atelier,oem'  -- Both!

-- Pattern level (แยก pattern ตาม production line)
pattern 1:
  • id_product = TOTE Bag
  • production_line = 'hatthasilpa'
  • pattern_code = 'TOTE-PREMIUM'
  • id_routing_graph = "Premium TOTE Process" (8 nodes)

pattern 2:
  • id_product = TOTE Bag  -- Same product!
  • production_line = 'oem'
  • pattern_code = 'TOTE-STANDARD'
  • id_routing_graph = "Standard TOTE Process" (5 nodes)
```

**UI Flow:**
```
Select Product: TOTE Bag
  ↓
System checks: production_lines = 'atelier,oem'
  ↓
Show options:
  • [🎨 Atelier] (Premium pattern, 8 nodes)
  • [🏭 OEM] (Standard pattern, 5 nodes)
  ↓
User selects → Auto-load appropriate pattern + graph!
```

---

### **Q2: MO ควรให้เลือก type ไหม? หรือแยกหน้า?**

**ตอบ: แยกหน้า!** ⭐

```
Sidebar Menu:
  Manufacturing:
    ├─ Orders (dropdown)
    │  ├─ 🏭 Manufacturing Orders (OEM)  ← OEM only!
    │  └─ 🎨 Hatthasilpa Jobs                ← Atelier only!
    ├─ Work Queue
    ├─ Manager Assignment
    └─ Scan Station (PWA)
```

**เพราะ:**
- ✅ Workflows ต่างกันมาก
- ✅ Forms ต่างกัน
- ✅ Users ต่างกัน
- ✅ Permissions แยกได้

---

### **Q3: Flow หลัง MO/Job เป็นยังไง? Job Ticket ยังใช้ไหม?**

**ตอบ: แยกตาม routing_mode + production_type!**

```
┌─────────────────────────────────────────────────┐
│ Complete Decision Tree                          │
└─────────────────────────────────────────────────┘

IF routing_mode = 'linear':
  ├─ Use Job Ticket (old system)
  ├─ Create tasks manually
  └─ Work on Job Ticket page (desktop)
  
ELSE IF routing_mode = 'dag':
  │
  ├─ IF production_type = 'hatthasilpa':
  │  │
  │  ├─ Create hatthasilpa_job_ticket (optional id_mo)
  │  ├─ Create graph_instance (from job_ticket)
  │  ├─ Spawn tokens
  │  ├─ Auto-assign
  │  └─ Work on Work Queue (mobile) ✅
  │
  └─ ELSE IF production_type = 'oem':
     │
     ├─ MO directly → graph_instance (NO Job Ticket!) ⭐
     ├─ Spawn tokens
     ├─ Auto-assign
     └─ Work on Work Queue (mobile) ✅
```

**Job Ticket Role:**

| Mode | Production Type | Job Ticket? | Flow |
|------|----------------|-------------|------|
| Linear | Any | ✅ YES (required) | MO → Job Ticket → Tasks → Work |
| DAG | Atelier | ⚠️ OPTIONAL (wrapper) | Job Ticket → Graph → Tokens → Work Queue |
| DAG | OEM | ❌ NO (bypass!) | MO → Graph → Tokens → Work Queue |

**ถ้างง: ใช้แผนภูมินี้!**

```
START
  │
  ▼
Production Type?
  ├─ 🎨 Atelier
  │  │
  │  └─ Page: Hatthasilpa Jobs
  │     ├─ Create job_ticket (id_mo optional)
  │     ├─ Auto: graph_instance
  │     ├─ Auto: tokens
  │     └─ Go to: Work Queue ✅
  │
  └─ 🏭 OEM
     │
     └─ Page: Manufacturing Orders
        ├─ Create MO (id_routing_graph required)
        ├─ Schedule MO
        ├─ Start Production
        │  └─ Auto: graph_instance (NO Job Ticket!)
        │     └─ Auto: tokens
        └─ Go to: Work Queue ✅

Work Queue = UNIFIED for BOTH! ✅
```

---

## 🎨 **UI Flow Maps:**

### **Atelier Manager Journey:**

```
1. Open: Hatthasilpa Jobs page
   ↓
2. Click: [New Job]
   ↓
3. Select Product: TOTE Bag
   ↓ (Auto-detect: supports atelier ✅)
4. Form auto-fills:
   • Pattern: Premium TOTE
   • Graph: Premium TOTE Process (8 nodes)
   ↓
5. Manager fills:
   • Job Name: "Charlotte Aimée Batch 3"
   • Qty: 20
   • Due: (leave empty - flexible)
   ↓
6. Click: [Create & Start]
   ↓
7. Confirmation:
   "Start production for 20 pieces?
    Graph: Premium TOTE Process
    Auto-assign to artisans: YES"
   [Confirm]
   ↓
8. Success!
   "20 tokens spawned and assigned
    View in Work Queue or Graph View"
   ↓
9. Navigate to: Graph Visualization
   (See 20 tokens at START node)

DONE! 1 MINUTE!
```

---

### **OEM Manager Journey:**

```
1. Open: Manufacturing Orders page
   ↓
2. Click: [New MO]
   ↓
3. Select Product: TOTE Bag
   ↓ (Auto-detect: supports oem ✅)
4. Form auto-fills:
   • Pattern: Standard TOTE
   • Graph: Standard TOTE Process (5 nodes)
   ↓
5. Manager fills:
   • Customer: "ABC Trading Co." *
   • Qty: 500 *
   • Due: Nov 30 *
   • Schedule: Nov 10 - Nov 25 *
   ↓
6. Click: [Create MO]
   ↓
7. MO created → Status: 'planned'
   List shows:
   MO-2025-001 | ABC Trading | 500 | Nov 10-25 | Planned
   [Schedule] button enabled
   ↓
8. Manager reviews resources
   ↓
9. Click: [Schedule]
   ↓
10. Confirmation:
    "Confirm schedule Nov 10-25?
     This commits to customer delivery!"
    [Confirm]
    ↓
11. Status → 'scheduled'
    [Start Production] button enabled (on Nov 10)
    ↓
12. On Nov 10, Click: [Start Production]
    ↓
13. Confirmation:
    "Start production for MO-2025-001?
     - 500 pieces TOTE Bag
     - Graph: Standard TOTE Process
     - Due: Nov 30 (⚠️ Committed!)
     - Tokens will auto-assign"
    [Confirm]
    ↓
14. Success!
    "500 tokens spawned and distributed
     MO status: In Progress
     View in Graph View or Work Queue"
    ↓
15. Navigate to: Graph Visualization
    (See 500 tokens distributed across nodes)

DONE! 3 STEPS! (Create, Schedule, Start)
```

---

### **Operator Journey (UNIFIED!):**

```
Both Atelier and OEM operators use SAME Work Queue!

Open: Work Queue (mobile PWA)
  ↓
See tokens grouped by station:
  
┌─────────────────────────────────────┐
│ 🚀 Cutting Station (25 tokens)     │
├─────────────────────────────────────┤
│                                     │
│ 🟢 MY WORK (2)                      │
│ ┌───────────────────────────────┐   │
│ │ 🎨 Atelier                    │   │
│ │ Job: Charlotte Aimée Batch 3  │   │
│ │ Token: TOTE-2025-005          │   │
│ │ ⏸️ Paused (12 min)            │   │
│ │ [Resume] [Complete]           │   │
│ └───────────────────────────────┘   │
│                                     │
│ ┌───────────────────────────────┐   │
│ │ 🏭 OEM                        │   │
│ │ MO: MO-2025-001 (ABC Trading) │   │
│ │ TOTE Bag (500 pcs)            │   │
│ │ Due: Nov 30 ⚠️                │   │
│ │ Token: TOTE-2025-042          │   │
│ │ 🟢 Active (8 min)             │   │
│ │ [Pause] [Complete]            │   │
│ └───────────────────────────────┘   │
│                                     │
│ ⚪ AVAILABLE (23)                   │
│ [Show all...]                       │
└─────────────────────────────────────┘

Operator: ไม่งง! เห็นชัดว่า Atelier หรือ OEM
Action: เหมือนกันทั้ง 2 type (Start, Pause, Complete)
```

---

## 🎯 **Key Design Decisions - Final:**

### **Decision 1: Product-Pattern Relationship**
```
1 Product → N Patterns (1 per production_line)

Example: TOTE Bag
  ├─ Atelier Pattern (Premium leather, luxury process)
  └─ OEM Pattern (Standard leather, efficiency process)
```

### **Decision 2: Page Structure**
```
Separate Pages! ⭐

Reasons:
  • Different users (Artisan manager vs Production planner)
  • Different workflows (1 step vs 3 steps)
  • Different validations (flexible vs strict)
  • Clear separation = No confusion
```

### **Decision 3: Job Ticket Role**
```
Linear Mode:
  ✅ Job Ticket required (old system)

DAG + Hatthasilpa:
  ⚠️ Job Ticket optional (wrapper for job info)

DAG + OEM:
  ❌ NO Job Ticket (MO → Graph Instance directly!)

Why: Reduce redundancy, clear flow
```

### **Decision 4: Auto-Assignment**
```
Both Atelier and OEM:
  • Auto-assign by default (load balancing)
  • Manager can override (Manager Assignment page)
  • Operators see assigned tokens in Work Queue

Fair distribution + manual control = Best!
```

---

## 📋 **Revised Implementation Checklist:**

### **Phase 1: Database (1.5 hours)**
- [ ] Add `production_lines` SET to `product`
- [ ] Add `production_line` ENUM to `pattern`
- [ ] Add `id_routing_graph` to `pattern`
- [ ] Add `production_type`, `id_routing_graph`, `graph_instance_id` to `mo`
- [ ] Add `production_type`, `id_routing_graph` to `hatthasilpa_job_ticket`
- [ ] Add `id_mo` to `job_graph_instance`
- [ ] Migrate existing data
- [ ] Test migration

### **Phase 2: Product Master Enhancement (1 hour)**
- [ ] Modify `views/products.php` - Add production_lines field
- [ ] Modify `source/products.php` - Save production_lines
- [ ] Update product list UI - Show production_lines badges

### **Phase 3: Hatthasilpa Jobs Page (3 hours)**
- [ ] Create `page/atelier_jobs.php`
- [ ] Create `views/atelier_jobs.php`
- [ ] Create `assets/javascripts/hatthasilpa/jobs.js`
- [ ] Create `source/atelier_jobs_api.php`
- [ ] Implement create_and_start endpoint
- [ ] Product dropdown (atelier products only)
- [ ] Graph dropdown (from pattern recommendation)
- [ ] Auto-spawn and auto-assign logic
- [ ] Add to sidebar menu

### **Phase 4: OEM MO Enhancement (2.5 hours)**
- [ ] Modify `views/mo.php` - Add graph dropdown, schedule fields
- [ ] Modify `source/mo.php` - Add start_production endpoint
- [ ] Modify `assets/javascripts/mo.js` - Add button logic
- [ ] Product dropdown filter (oem products only)
- [ ] Schedule validation
- [ ] Start production button with validation
- [ ] Auto-spawn logic (bypass Job Ticket!)

### **Phase 5: Business Rules (2 hours)**
- [ ] Create `source/service/ProductionValidationService.php`
- [ ] Implement validateAtelier() - Flexible rules
- [ ] Implement validateOEM() - Strict rules
- [ ] Implement canStartProduction()
- [ ] Write unit tests

### **Phase 6: Work Queue Enhancement (1 hour)**
- [ ] Modify `dag_token_api.php` - Add MO join, production_type
- [ ] Modify `assignment_api.php` - Add MO join, production_type
- [ ] Modify `work_queue.js` - Display type badge + MO info
- [ ] Modify `manager/assignment.js` - Display MO info
- [ ] Add CSS for type badges

### **Phase 7: Testing (2 hours)**
- [ ] Test: Atelier job (no MO, auto-spawn)
- [ ] Test: Atelier job (with MO, linked)
- [ ] Test: OEM MO (strict validation)
- [ ] Test: OEM start production (auto-spawn)
- [ ] Test: Product supports both (pattern selection)
- [ ] Test: Work Queue shows correct type
- [ ] Test: Validation messages
- [ ] E2E: Complete workflows for both types

### **Phase 8: Documentation (1 hour)**
- [ ] Update `docs/USER_MANUAL.md`
- [ ] Create `docs/ATELIER_vs_OEM_MANAGER_GUIDE.md`
- [ ] Update `docs/OPERATOR_QUICK_GUIDE_TH.md`
- [ ] Update `docs/MANAGER_QUICK_GUIDE_TH.md`

**Total: 14 hours** (revised from 10 - more thorough!)

---

## 🚀 **Final Architecture Summary:**

```
┌──────────────────────────────────────────────────────┐
│               PRODUCT MASTER                         │
│  (Defines which production lines supported)          │
├──────────────────────────────────────────────────────┤
│ TOTE Bag:                                            │
│ • production_lines = 'atelier,oem' (BOTH!)          │
│ • Pattern 1: Premium (Hatthasilpa)                      │
│ • Pattern 2: Standard (OEM)                         │
└────────────┬─────────────────────────────────────────┘
             │
    ┌────────┴────────┐
    │                 │
    ▼                 ▼
┌─────────┐     ┌─────────┐
│ Atelier │     │   OEM   │
│  Jobs   │     │   MO    │
└────┬────┘     └────┬────┘
     │               │
     │ (routing_mode = 'dag')
     │               │
     ├───────┬───────┤
             │
             ▼
    ┌────────────────┐
    │ Graph Instance │
    │ (id_mo OR      │
    │  id_job_ticket)│
    └────────┬───────┘
             │
             ▼
      ┌──────────┐
      │  Tokens  │
      └─────┬────┘
            │
            ▼
      ┌──────────┐
      │   Work   │
      │  Queue   │
      │ (UNIFIED)│
      └──────────┘
```

---

## 💡 **Comparison Table:**

| Aspect | Atelier 🎨 | OEM 🏭 |
|--------|-----------|--------|
| **Entry Point** | Hatthasilpa Jobs page | Manufacturing Orders page |
| **Product Filter** | production_lines INCLUDES 'hatthasilpa' | production_lines INCLUDES 'oem' |
| **Volume** | 10-50 (max 100) | 100-1000+ |
| **MO** | Optional | Required |
| **Schedule** | Optional (flexible) | Required (strict) |
| **Graph** | Auto from pattern | Auto from pattern |
| **Job Ticket** | Created (optional wrapper) | NOT created (bypass!) |
| **Graph Instance** | From job_ticket | From MO directly |
| **Tokens** | Auto-spawned | Auto-spawned |
| **Assignment** | Auto or manual | Auto or manual |
| **Work Queue** | ✅ Same UI! | ✅ Same UI! |
| **Display** | 🎨 Badge + Job name | 🏭 Badge + MO code |
| **Manager Steps** | **1** (Create & Start) | **3** (Create → Schedule → Start) |
| **Validation** | Flexible | Strict |
| **Mid-Change** | Allowed | Locked after start |

---

## 🎊 **Final Recommendation:**

### **ทำตามนี้:**

1. **Product Level:**
   - เพิ่ม `production_lines` SET('hatthasilpa','oem')
   - 1 product → multiple patterns (1 per line)

2. **Page Structure:**
   - **แยกหน้า!** (Hatthasilpa Jobs vs OEM MO)
   - Sidebar: 2 menus แยกชัดเจน

3. **Job Ticket:**
   - Linear: ใช้ Job Ticket (old system)
   - DAG + Hatthasilpa: ใช้ Job Ticket (optional wrapper)
   - **DAG + OEM: ไม่ใช้ Job Ticket!** (MO → Graph ตรง!)

4. **Work Queue:**
   - **Unified!** (ทั้ง 2 type ใช้หน้าเดียวกัน)
   - แสดง badge แยก (🎨 / 🏭)
   - Show MO for OEM, Job for Atelier

---

## 📊 **Implementation Priority:**

**Must Do:**
1. ✅ Database (Phase 1)
2. ✅ Atelier Page (Phase 3)
3. ✅ OEM MO (Phase 4)
4. ✅ Work Queue display (Phase 6)

**Should Do:**
5. ✅ Product master (Phase 2)
6. ✅ Business rules (Phase 5)

**Nice to Have:**
7. ⚠️ Testing (Phase 7)
8. ⚠️ Documentation (Phase 8)

---

**Timeline: 14 hours (revised)**  
**Risk: Low**  
**Value: CRITICAL**  
**Status: Ready for implementation!** ✅

---

**พร้อม implement เมื่อได้รับอนุมัติครับ! 🚀**

# 🏗️ Advanced Dual Production Architecture - ถอดรหัสจากแนวคิดเชิงลึก
**Date:** November 5, 2025 00:15 ICT  
**Status:** 🎯 FINAL ARCHITECTURE - Incorporates advanced concepts  
**Revision:** v2.0 (ปรับจากแผนเดิมตามแนวคิดใหม่)

---

## 📊 Root Causes Analysis (ที่ถูกชี้ให้เห็น):

### **1. Products/Patterns อิสระจากชนิดงาน** ✅ ถูกต้อง!
```
ปัญหา:
• Pattern มีหลาย version + รูปได้
• แต่ ไม่ได้บอกว่า version นี้ใช้กับ Atelier หรือ OEM
• routing_graph_designer ออกแบบ 1:1 กับ pattern
• ถ้าต้องแยก type → ต้อง duplicate graph!

Impact:
❌ ไม่สามารถแยก routing ตาม production type
❌ ต้อง clone graph ซ้ำซ้อน
❌ บริหารยาก
```

### **2. MO ไม่รู้ "โหมดการผลิต"** ✅ ถูกต้อง!
```
ปัญหา:
• MO สั่งผลิตได้
• แต่ไม่รู้ว่า Atelier หรือ Batch
• ไม่สามารถบังคับ business rules ตาม type

Impact:
❌ Atelier และ OEM ใช้ validation เดียวกัน (ผิด!)
❌ ไม่สามารถ enforce strict schedule สำหรับ OEM
```

### **3. Job Ticket ผูกกับ flow เชิงเส้น (linear batch)** ✅ ถูกต้อง!
```
ปัญหา:
• Job Ticket = Linear concept
• ไม่เหมาะกับ Atelier (flexible, one-off)
• ไม่เหมาะกับ DAG (parallel)

Impact:
❌ Atelier ต้องผ่าน Ticket (complex!)
❌ DAG ยังไม่มีตัวแทนชัดเจน
```

### **4. DAG ยังลอย** ✅ ถูกต้อง!
```
ปัญหา:
• manager_assignment, work_queue, graph_designer มีแล้ว
• แต่ยังไม่ plug เข้ากับ MO / production type
• ไม่มีแนวทางแยก Atelier vs OEM ใน DAG level

Impact:
❌ DAG ใช้ได้แต่ไม่ผูกกับ business flow
❌ จะเกิด duplication เมื่อต้องแยก type
```

### **5. routing_graph_designer ออกแบบต่อ Pattern อย่างเดียว** ✅ ถูกต้อง!
```
ปัญหา:
• 1 pattern → 1 graph
• ถ้าต้องมี 2 routing (Atelier vs OEM) → ต้อง clone!

Impact:
❌ Duplicate graphs
❌ บริหารยาก
❌ แตกสาย
```

---

## 💡 **Advanced Solutions (จากแนวคิดที่ให้มา):**

### **A) Production Type Everywhere (แกนกลาง)** ⭐

**แนวคิด:** production_type เป็น **Primary Dimension** ของทั้งระบบ!

**ติดตั้งทุกจุด:**
```sql
-- 1. Pattern Version
ALTER TABLE pattern_version 
  ADD COLUMN supported_types SET('hatthasilpa','oem','hybrid') 
  NOT NULL DEFAULT 'atelier,oem';

-- 2. Routing Set (NEW concept!)
CREATE TABLE routing_set (
  id_routing_set INT AUTO_INCREMENT PRIMARY KEY,
  id_pattern INT NOT NULL,
  set_name VARCHAR(200),
  description TEXT,
  is_active TINYINT(1) DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  KEY idx_pattern (id_pattern)
) COMMENT 'Collection of DAG templates per pattern';

-- 3. DAG Template (Enhanced routing_graph!)
ALTER TABLE routing_graph
  ADD COLUMN production_type ENUM('hatthasilpa','oem','hybrid') NOT NULL DEFAULT 'hatthasilpa',
  ADD COLUMN id_routing_set INT DEFAULT NULL COMMENT 'FK to routing_set';

-- 4. MO
ALTER TABLE mo 
  ADD COLUMN production_type ENUM('hatthasilpa','oem','hybrid') NOT NULL DEFAULT 'oem';

-- 5. Job (Enhanced hatthasilpa_job_ticket!)
ALTER TABLE hatthasilpa_job_ticket 
  ADD COLUMN production_type ENUM('hatthasilpa','oem','hybrid') NOT NULL DEFAULT 'hatthasilpa';
```

**Concept:**
```
Pattern (Master Spec)
  ↓
RoutingSet (Template Collection per Pattern)
  ↓
  ├─ DAG Template (Hatthasilpa) - Flexible, artisan-focused
  ├─ DAG Template (OEM) - Efficient, batch-focused
  └─ DAG Template (Hybrid) - OEM base + Atelier finish
```

---

### **B) Binding Layer (ชั้นผูก)** ⭐

**แนวคิด:** Auto-suggest routing ตาม product + type!

```
User สร้าง MO:
  1. เลือก Product: TOTE Bag
  2. เลือก Production Type: OEM
     ↓
  System auto-suggests:
  3. Routing Set: "TOTE Production Set"
  4. Template Options:
     • Standard TOTE (OEM, 5 nodes) ← Suggested!
     • Premium TOTE (Atelier, 8 nodes) [disabled - wrong type]
     • Hybrid TOTE (7 nodes) [available]
     ↓
  5. Manager selects: "Standard TOTE (OEM)"
     ↓
  6. [Create MO] → Auto-bind to template
```

**Backend:**
```php
function autoSuggestRouting($productId, $productionType) {
    // Get pattern for product
    $pattern = db_fetch_one($db, "
        SELECT id_pattern FROM pattern 
        WHERE id_product = ? 
        AND production_line = ? OR production_line = 'both'
        LIMIT 1
    ", [$productId, $productionType]);
    
    // Get routing set for pattern
    $routingSet = db_fetch_one($db, "
        SELECT id_routing_set FROM routing_set
        WHERE id_pattern = ?
        AND is_active = 1
    ", [$pattern['id_pattern']]);
    
    // Get templates in set matching type
    $templates = db_fetch_all($db, "
        SELECT id_graph, graph_name, node_count, description
        FROM routing_graph
        WHERE id_routing_set = ?
        AND production_type IN (?, 'hybrid')
        AND status = 'published'
        ORDER BY 
          CASE WHEN production_type = ? THEN 1 ELSE 2 END,
          graph_name
    ", [$routingSet['id_routing_set'], $productionType, $productionType]);
    
    return [
        'routing_set' => $routingSet,
        'templates' => $templates,
        'suggested' => $templates[0] ?? null
    ];
}
```

---

### **C) DAG Template Set (ไม่ต้อง duplicate!)** ⭐

**แนวคิด:** Template Set + Node Library + Parameters!

**Architecture:**
```
Pattern: TOTE Bag
  ↓
RoutingSet: "TOTE Production Set"
  ↓
  ├─ Template: "Premium TOTE Process" (Hatthasilpa)
  │  • Node Library: Cut, Stitch, QC, Artisan Sign-off, Pack
  │  • Parameters:
  │    - scan_mode: 'piece'
  │    - qc_required: true (every piece!)
  │    - artisan_signature: true
  │    - timing_tracking: 'detailed'
  │  • Total: 8 nodes
  │
  ├─ Template: "Standard TOTE Process" (OEM)
  │  • Node Library: Cut, Stitch, Batch QC, Pack
  │  • Parameters:
  │    - scan_mode: 'batch'
  │    - qc_required: true (sampling only)
  │    - artisan_signature: false
  │    - timing_tracking: 'summary'
  │  • Total: 5 nodes
  │
  └─ Template: "Hybrid TOTE" (OEM base + Atelier finish)
     • Nodes: Standard process + Final artisan touch
     • Parameters: Mixed
     • Total: 7 nodes
```

**Node Parameters (Reduce Duplication!):**
```json
// Node: Quality Check
{
  "node_code": "QC",
  "node_name": "Quality Check",
  "node_type": "operation",
  "parameters": {
    "hatthasilpa": {
      "qc_mode": "per_piece",
      "inspection_points": 15,
      "photo_required": true,
      "artisan_check": true
    },
    "oem": {
      "qc_mode": "sampling",
      "inspection_points": 8,
      "photo_required": false,
      "batch_check": true
    }
  }
}
```

**Benefit:** Same node, different behavior per type!

---

### **D) Centralized Business Rules** ⭐

**แนวคิด:** Single source of truth!

**File: source/service/ProductionRulesService.php**

```php
<?php
namespace BGERP\Service;

class ProductionRulesService
{
    private static $rules = [
        'hatthasilpa' => [
            'allow_no_mo' => true,
            'require_due_date' => false,
            'require_schedule' => false,
            'enforce_linear' => false,
            'min_qty' => 1,
            'max_qty' => 100,
            'require_artisan_tracking' => true,
            'require_per_piece_timing' => true,
            'allow_mid_change' => true,
            'focus' => 'quality'
        ],
        'oem' => [
            'allow_no_mo' => false,
            'require_due_date' => true,
            'require_schedule' => true,
            'enforce_linear' => false,  // Can use DAG!
            'min_qty' => 100,
            'max_qty' => 10000,
            'require_artisan_tracking' => false,
            'require_per_piece_timing' => false,
            'allow_mid_change' => false,  // Lock after start!
            'focus' => 'efficiency'
        ],
        'hybrid' => [
            'allow_no_mo' => false,
            'require_due_date' => true,
            'require_schedule' => true,
            'enforce_linear' => false,
            'min_qty' => 50,
            'max_qty' => 500,
            'require_artisan_tracking' => true,  // Final steps only
            'require_per_piece_timing' => false,
            'allow_mid_change' => false,
            'focus' => 'balanced'
        ]
    ];
    
    public static function getRules(string $type): array
    {
        return self::$rules[$type] ?? self::$rules['oem'];
    }
    
    public static function validate(array $data, string $type): array
    {
        $rules = self::getRules($type);
        $errors = [];
        
        // MO requirement
        if (!$rules['allow_no_mo'] && empty($data['id_mo'])) {
            $errors[] = ucfirst($type) . ' production requires Manufacturing Order';
        }
        
        // Quantity validation
        if (!empty($data['qty'])) {
            if ($data['qty'] < $rules['min_qty']) {
                $errors[] = ucfirst($type) . " production typically requires minimum {$rules['min_qty']} pieces";
            }
            if ($data['qty'] > $rules['max_qty']) {
                $errors[] = ucfirst($type) . " production limited to maximum {$rules['max_qty']} pieces";
            }
        }
        
        // Schedule validation
        if ($rules['require_schedule']) {
            if (empty($data['scheduled_start_date']) || empty($data['scheduled_end_date'])) {
                $errors[] = ucfirst($type) . ' production requires production schedule';
            }
        }
        
        // Due date validation
        if ($rules['require_due_date'] && empty($data['due_date'])) {
            $errors[] = ucfirst($type) . ' production requires due date (customer commitment)';
        }
        
        return [
            'valid' => empty($errors),
            'errors' => $errors,
            'rules' => $rules
        ];
    }
    
    public static function canModifyAfterStart(string $type): bool
    {
        $rules = self::getRules($type);
        return $rules['allow_mid_change'];
    }
    
    public static function getWorkflowSteps(string $type): array
    {
        $rules = self::getRules($type);
        
        $steps = [];
        
        if (!$rules['allow_no_mo']) {
            $steps[] = ['step' => 1, 'name' => 'Create MO', 'required' => true];
        } else {
            $steps[] = ['step' => 1, 'name' => 'Create Job', 'required' => true];
        }
        
        if ($rules['require_schedule']) {
            $steps[] = ['step' => 2, 'name' => 'Schedule', 'required' => true];
            $steps[] = ['step' => 3, 'name' => 'Start Production', 'required' => true];
        } else {
            $steps[] = ['step' => 2, 'name' => 'Start Production', 'required' => true];
        }
        
        return $steps;
    }
}
```

**Usage Everywhere:**
```php
// In MO creation
$validation = ProductionRulesService::validate($_POST, $productionType);
if (!$validation['valid']) {
    json_error(implode(', ', $validation['errors']), 400);
}

// In mid-production change
if (!ProductionRulesService::canModifyAfterStart($mo['production_type'])) {
    json_error('Cannot modify OEM schedule after production started', 400);
}
```

---

### **E) Routing Set Architecture (Template Collection)** ⭐ KEY CONCEPT!

**New Concept: RoutingSet**

```
Pattern (Product Spec)
  ↓ (1:1)
RoutingSet (Template Collection)
  ↓ (1:N)
  ├─ DAG Template (Hatthasilpa)
  ├─ DAG Template (OEM)
  └─ DAG Template (Hybrid)
```

**Database Schema:**

```sql
-- RoutingSet: Collection of templates for a pattern
CREATE TABLE routing_set (
  id_routing_set INT AUTO_INCREMENT PRIMARY KEY,
  id_pattern INT NOT NULL COMMENT 'FK to pattern',
  set_name VARCHAR(200) NOT NULL,
  description TEXT,
  is_active TINYINT(1) DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  KEY idx_pattern (id_pattern),
  UNIQUE KEY uniq_pattern_set (id_pattern, set_name)
) ENGINE=InnoDB;

-- Enhanced routing_graph (becomes Template)
ALTER TABLE routing_graph
  ADD COLUMN id_routing_set INT DEFAULT NULL COMMENT 'FK to routing_set',
  ADD COLUMN production_type ENUM('hatthasilpa','oem','hybrid') NOT NULL DEFAULT 'hatthasilpa',
  ADD COLUMN template_code VARCHAR(50) DEFAULT NULL,
  ADD COLUMN is_default_for_type TINYINT(1) DEFAULT 0 COMMENT 'Default template for this type';

-- Pattern links to RoutingSet
ALTER TABLE pattern
  ADD COLUMN id_routing_set INT DEFAULT NULL COMMENT 'FK to routing_set - recommended templates';

-- Node parameters (for type-specific behavior)
ALTER TABLE routing_node
  ADD COLUMN node_params JSON DEFAULT NULL COMMENT 'Type-specific parameters';

-- Examples of node_params:
{
  "hatthasilpa": {
    "scan_mode": "piece",
    "qc_required": true,
    "qc_mode": "per_piece",
    "artisan_signature": true,
    "timing_detail": "per_piece"
  },
  "oem": {
    "scan_mode": "batch",
    "qc_required": true,
    "qc_mode": "sampling",
    "batch_tracking": true,
    "timing_detail": "summary"
  }
}
```

**Example Data:**
```sql
-- Pattern
INSERT INTO pattern (id_pattern, id_product, pattern_code) 
VALUES (1, 5, 'TOTE-BAG');

-- Routing Set
INSERT INTO routing_set (id_routing_set, id_pattern, set_name)
VALUES (1, 1, 'TOTE Bag Production Templates');

-- Templates in the set
INSERT INTO routing_graph 
(id_routing_set, production_type, graph_name, template_code, is_default_for_type)
VALUES
  (1, 'hatthasilpa', 'Premium TOTE Process', 'TOTE-PREMIUM', 1),
  (1, 'oem', 'Standard TOTE Process', 'TOTE-STANDARD', 1),
  (1, 'hybrid', 'Hybrid TOTE Process', 'TOTE-HYBRID', 0);
```

---

### **F) Node Library + Parametrization** ⭐ ลดการ duplicate!

**แนวคิด:** Node เดียว, พารามิเตอร์ต่างกัน!

**Example: Cutting Node**

```json
{
  "id_node": 1,
  "node_code": "CUT",
  "node_name": "Cutting",
  "node_type": "operation",
  "base_config": {
    "work_center_id": 10,
    "estimated_minutes_per_piece": 15
  },
  "node_params": {
    "hatthasilpa": {
      "scan_mode": "piece",
      "require_artisan_id": true,
      "allow_pause": true,
      "quality_photos": 2,
      "measurement_check": true
    },
    "oem": {
      "scan_mode": "batch",
      "require_artisan_id": false,
      "batch_size": 50,
      "sampling_rate": 0.05,
      "measurement_check": false
    }
  }
}
```

**Runtime Behavior:**
```php
// When operator works on node
$nodeConfig = getNodeConfig($nodeId, $productionType);

if ($nodeConfig['scan_mode'] === 'piece') {
    // Hatthasilpa: Scan each piece
    requireSerialScan();
} else {
    // OEM: Batch tracking
    requireBatchScan();
}
```

**Benefit:** 
- ✅ Same node definition
- ✅ Different behavior per type
- ✅ No duplication!

---

## 🔄 **Revised Complete Architecture:**

```
┌──────────────────────────────────────────────────────────┐
│ Layer 1: Product Master (supports multiple types)        │
├──────────────────────────────────────────────────────────┤
│ product                                                  │
│  ├─ sku, name                                            │
│  └─ production_lines SET('hatthasilpa','oem')  ⭐           │
│      │                                                   │
│      └─ pattern (1:N)                                    │
│          ├─ pattern_code                                 │
│          ├─ production_line ENUM  ⭐                     │
│          └─ id_routing_set  ⭐ NEW!                      │
│              │                                           │
│              └─ routing_set  ⭐ NEW!                     │
│                  ├─ set_name                             │
│                  └─ Templates (1:N)                      │
│                      ├─ DAG Template (Hatthasilpa)           │
│                      ├─ DAG Template (OEM)               │
│                      └─ DAG Template (Hybrid)            │
└──────────────────────────────────────────────────────────┘
                          │
          ┌───────────────┴───────────────┐
          │                               │
          ▼                               ▼
┌─────────────────────┐     ┌─────────────────────┐
│ Atelier Flow        │     │ OEM Flow            │
├─────────────────────┤     ├─────────────────────┤
│ hatthasilpa_job_ticket  │     │ mo                  │
│  ├─ production_type │     │  ├─ production_type │
│  ├─ id_mo (nullable)│     │  ├─ id_routing_graph│
│  └─ id_routing_graph│     │  └─ (schedule)      │
└──────────┬──────────┘     └──────────┬──────────┘
           │                           │
           └─────────┬─────────────────┘
                     │
                     ▼
         ┌─────────────────────┐
         │ job_graph_instance  │
         │  ├─ id_job_ticket   │ ← Atelier
         │  ├─ id_mo           │ ← OEM
         │  ├─ id_graph        │
         │  └─ production_type │ ⭐ NEW!
         └──────────┬──────────┘
                    │
                    ▼
            ┌───────────────┐
            │  flow_token   │
            │  (unified!)   │
            └───────┬───────┘
                    │
                    ▼
            ┌───────────────┐
            │  Work Queue   │
            │  (shows type) │
            └───────────────┘
```

---

## 📋 **Revised Implementation Plan (Enhanced!):**

### **Phase 1: Database Schema (2 hours)** - Expanded!
```
1.1 Product Enhancement:
  ✅ ALTER TABLE product ADD production_lines SET

1.2 Pattern Enhancement:
  ✅ ALTER TABLE pattern ADD production_line ENUM
  ✅ ALTER TABLE pattern ADD id_routing_set INT

1.3 NEW: RoutingSet Table
  ✅ CREATE TABLE routing_set (collection of templates)

1.4 Routing Graph Enhancement:
  ✅ ALTER TABLE routing_graph ADD production_type ENUM
  ✅ ALTER TABLE routing_graph ADD id_routing_set INT
  ✅ ALTER TABLE routing_graph ADD template_code VARCHAR
  ✅ ALTER TABLE routing_graph ADD is_default_for_type TINYINT

1.5 Node Parameters:
  ✅ ALTER TABLE routing_node ADD node_params JSON

1.6 MO Enhancement:
  ✅ ALTER TABLE mo ADD production_type ENUM
  ✅ ALTER TABLE mo ADD id_routing_graph INT
  ✅ ALTER TABLE mo ADD graph_instance_id INT

1.7 Job Ticket Enhancement:
  ✅ ALTER TABLE hatthasilpa_job_ticket ADD production_type ENUM
  ✅ ALTER TABLE hatthasilpa_job_ticket ADD id_routing_graph INT

1.8 Graph Instance Enhancement:
  ✅ ALTER TABLE job_graph_instance ADD id_mo INT
  ✅ ALTER TABLE job_graph_instance ADD production_type ENUM

1.9 Migrate Existing Data
1.10 Create Indexes
```

### **Phase 2: Centralized Rules Service (2 hours)** - NEW!
```
2.1 Create ProductionRulesService
  ✅ Define rules per type (atelier, oem, hybrid)
  ✅ Validation methods
  ✅ Workflow step generator
  ✅ Permission helper

2.2 Create RoutingSetService
  ✅ Auto-suggest templates by product + type
  ✅ Get default template
  ✅ List templates in set

2.3 Unit Tests
  ✅ Test rules for all types
  ✅ Test auto-suggestion
```

### **Phase 3: Product & Pattern Enhancement (1.5 hours)**
```
3.1 Product Form:
  ✅ Add production_lines checkboxes
  ✅ Validation (must select at least one)

3.2 Pattern Form:
  ✅ Add production_line radio
  ✅ Add routing_set dropdown
  ✅ Link to templates

3.3 Product List:
  ✅ Show production_lines badges
```

### **Phase 4: RoutingSet & Template Management (2 hours)** - NEW!
```
4.1 Create Routing Set Management Page
  ✅ List sets per pattern
  ✅ Create/Edit set
  ✅ Link templates to set

4.2 Enhanced Graph Designer:
  ✅ Add production_type selector
  ✅ Add template_code field
  ✅ Link to routing_set
  ✅ Node parameters editor (JSON)

4.3 Template Preview Matrix:
  ✅ Pattern Version (rows) × Templates (columns)
  ✅ Visual coverage matrix
```

### **Phase 5: Hatthasilpa Jobs Page (3 hours)**
```
5.1 Create atelier_jobs.php
5.2 Product dropdown (atelier products only)
5.3 Auto-suggest template from routing_set
5.4 1-click "Create & Start"
5.5 Auto-spawn tokens
5.6 Auto-assign logic
```

### **Phase 6: OEM MO Enhancement (2.5 hours)**
```
6.1 Add production_type selector
6.2 Add routing template dropdown (auto-suggest!)
6.3 Add schedule fields
6.4 "Start Production" button
6.5 Auto-spawn logic (bypass Job Ticket!)
6.6 Strict validation
```

### **Phase 7: Work Queue Enhancement (1.5 hours)**
```
7.1 Query production_type from graph_instance
7.2 Join MO table (for OEM)
7.3 Display type badge (🎨 / 🏭)
7.4 Show MO info (OEM) or Job info (Hatthasilpa)
7.5 Apply node_params at runtime
```

### **Phase 8: Migration & Deprecation (1.5 hours)** - NEW!
```
8.1 Migrate existing Job Tickets:
  ✅ Set production_type based on id_mo
  ✅ Link to routing_graph

8.2 Create "Convert to Job (DAG)" button
  ✅ For linear tickets not yet started
  ✅ Auto-convert to DAG job

8.3 Deprecation notice on Job Ticket page:
  "Job Ticket is for Linear mode only.
   For DAG mode, use Hatthasilpa Jobs or MO."
```

### **Phase 9: Testing (2 hours)**
```
9.1 Test auto-suggestion
9.2 Test Atelier flow (with/without MO)
9.3 Test OEM flow (strict validation)
9.4 Test node parameters
9.5 Test Work Queue display
9.6 Test rules service
9.7 E2E workflows
```

### **Phase 10: Documentation (1 hour)**
```
10.1 Update user guides
10.2 Create routing set guide
10.3 Update manager guides
10.4 Deprecation notice
```

**Total: 19 hours** (revised - more comprehensive!)

---

## 🎯 **Key Improvements from Advanced Concept:**

### **แผนเดิม vs แผนใหม่:**

| Aspect | แผนเดิม (Simple) | แผนใหม่ (Advanced) |
|--------|-----------------|-------------------|
| **Pattern → Graph** | 1:1 (must clone) | 1:N via RoutingSet ✅ |
| **Templates** | Separate graphs | Templates in Set ✅ |
| **Node Duplication** | Clone nodes | Shared + Parameters ✅ |
| **Rules** | Scattered | Centralized Service ✅ |
| **Auto-Suggestion** | Manual select | Auto by product+type ✅ |
| **Job Ticket** | Keep or remove? | Deprecate with plan ✅ |
| **Binding** | Implicit | Explicit Binding Layer ✅ |

---

## 🏗️ **Complete Example:**

### **Setup: TOTE Bag Product**

```sql
-- 1. Product
INSERT INTO product (sku, name, production_lines)
VALUES ('TOTE-001', 'TOTE Bag', 'atelier,oem');

-- 2. Pattern
INSERT INTO pattern (id_product, pattern_code, production_line)
VALUES 
  (5, 'TOTE-PREMIUM', 'hatthasilpa'),
  (5, 'TOTE-STANDARD', 'oem');

-- 3. Routing Set (1 per product, typically)
INSERT INTO routing_set (id_pattern, set_name)
VALUES (1, 'TOTE Bag Production Templates');

-- 4. Link pattern to routing_set
UPDATE pattern SET id_routing_set = 1 WHERE id_pattern = 1;

-- 5. Templates in set
INSERT INTO routing_graph 
(id_routing_set, production_type, graph_name, template_code, is_default_for_type)
VALUES
  (1, 'hatthasilpa', 'Premium TOTE Process', 'TOTE-PREMIUM', 1),
  (1, 'oem', 'Standard TOTE Process', 'TOTE-STANDARD', 1);

-- 6. Nodes (shared library + params)
INSERT INTO routing_node (id_graph, node_code, node_name, node_params)
VALUES
  -- Atelier template nodes
  (1, 'CUT', 'Cutting', '{"hatthasilpa": {"scan_mode": "piece", "artisan_id": true}}'),
  (1, 'STITCH', 'Stitching', '{"hatthasilpa": {"qc_per_piece": true}}'),
  ...
  -- OEM template nodes
  (2, 'CUT', 'Cutting', '{"oem": {"scan_mode": "batch", "batch_size": 50}}'),
  (2, 'STITCH', 'Stitching', '{"oem": {"qc_sampling": 0.05}}'),
  ...
```

---

### **Manager Flow (Using New System):**

**Scenario: Create OEM Order**

```
1. Page: Manufacturing Orders
   ↓
2. Click: [New MO]
   ↓
3. Form:
   • Customer: "ABC Trading"
   • Product: [Select "TOTE Bag"]
     ↓ (System checks: production_lines = 'atelier,oem')
   • Production Type: [🎨 Atelier] [🏭 OEM] ← Show both!
     ↓ User selects: [🏭 OEM]
     ↓
   System auto-suggests:
   • Routing Set: "TOTE Bag Production Templates" (from pattern.id_routing_set)
   • Template: "Standard TOTE Process" (OEM default) ← Auto-selected!
   • Alternative: "Hybrid TOTE Process" (also available)
     ↓
   Manager reviews:
   • Qty: 500 (validated: >= 100 for OEM ✅)
   • Due: Nov 30 *
   • Schedule: Nov 10-25 *
     ↓
4. [Create MO]
   ↓
5. Validation (ProductionRulesService):
   ✅ OEM requires MO
   ✅ OEM requires schedule
   ✅ Qty >= min (100)
   ✅ Template matches type
   ↓
6. MO created → Status: 'planned'
   ↓
7. [Schedule] → Status: 'scheduled'
   ↓
8. [Start Production]
   ↓
9. Auto-actions:
   • Create graph_instance (id_mo, id_graph, production_type='oem')
   • Apply OEM node_params to nodes
   • Spawn 500 tokens
   • Auto-assign
   ↓
10. Work Queue shows:
    🏭 OEM | MO-2025-001 | TOTE Bag | Token: TOTE-2025-001
```

**Total: 3 steps, but MUCH smarter!**

---

## 📊 **Benefits of Advanced Architecture:**

### **1. No Duplication:**
```
Before: 2 graphs (Atelier + OEM) = duplicate nodes
After:  1 RoutingSet → 2 Templates → Shared nodes + Different params
```

### **2. Scalable:**
```
Add new type (e.g., "B2B Custom"):
  ✅ Add to production_type ENUM
  ✅ Define rules in ProductionRulesService
  ✅ Create template in existing RoutingSet
  ✅ Done! No system rewrite!
```

### **3. Maintainable:**
```
Change business rule (e.g., OEM min qty 50 → 80):
  ✅ Update ProductionRulesService (1 line)
  ✅ All validations updated automatically
```

### **4. Clear:**
```
Manager sees:
  ✅ Product supports: [🎨] [🏭]
  ✅ Pattern: Premium (Hatthasilpa) / Standard (OEM)
  ✅ Template auto-suggested
  ✅ No confusion!
```

---

## 🎯 **Checklists (ลงมือทำได้ทันที):**

### **Schema & Index (3 hours)** - Revised!
- [ ] เพิ่ม production_lines SET to product
- [ ] เพิ่ม production_line ENUM to pattern
- [ ] **CREATE TABLE routing_set** ⭐ NEW!
- [ ] เพิ่ม id_routing_set to pattern
- [ ] เพิ่ม production_type, id_routing_set to routing_graph
- [ ] เพิ่ม node_params JSON to routing_node
- [ ] เพิ่ม production_type to mo, hatthasilpa_job_ticket, job_graph_instance
- [ ] เพิ่ม id_mo to job_graph_instance
- [ ] สร้าง indexes
- [ ] Migrate data

### **Rules & Services (2.5 hours)** - Enhanced!
- [ ] Create ProductionRulesService ⭐
- [ ] Create RoutingSetService ⭐
- [ ] Create NodeParameterService ⭐
- [ ] Refactor validations to use RulesService
- [ ] Unit tests

### **UX (2.5 hours)**
- [ ] MO Form: production_type selector + auto-suggestion
- [ ] Hatthasilpa Jobs Form: product filter + template suggestion
- [ ] Badges everywhere (🎨 / 🏭)
- [ ] Work Queue: type badges + MO info
- [ ] Product/Pattern pages: show production_lines

### **DAG Templates (3 hours)** - NEW Phase!
- [ ] RoutingSet management page
- [ ] Enhanced Graph Designer (production_type field)
- [ ] Node parameter editor (JSON)
- [ ] Template preview matrix
- [ ] Create sample templates (Atelier + OEM for TOTE)

### **Migration & Deprecation (1.5 hours)**
- [ ] Migrate existing data
- [ ] "Convert to DAG" button on linear tickets
- [ ] Deprecation notice
- [ ] Migration report

### **Testing (2 hours)**
- [ ] Test all flows
- [ ] Test rules service
- [ ] Test auto-suggestion
- [ ] Test node parameters
- [ ] E2E

### **Documentation (1 hour)**
- [ ] Architecture guide
- [ ] RoutingSet concept doc
- [ ] User guides
- [ ] Migration guide

**Total: 17.5 hours** (more accurate!)

---

## 🎊 **Summary:**

### **Advanced Concepts Applied:**

1. ✅ **Production Type Everywhere** - Primary dimension
2. ✅ **RoutingSet** - Template collection per pattern
3. ✅ **Node Parameters** - Shared nodes, different behavior
4. ✅ **Binding Layer** - Auto-suggestion based on product + type
5. ✅ **Centralized Rules** - ProductionRulesService
6. ✅ **Deprecation Plan** - Migrate from Job Ticket to Job (DAG)

### **Key Benefits:**

```
✅ No duplication (shared nodes + params)
✅ Scalable (add types easily)
✅ Maintainable (centralized rules)
✅ Clear UX (auto-suggestion)
✅ Future-proof (template-based)
```

---

**Timeline: 17.5 hours (more comprehensive!)**  
**Risk: Low (well-architected)**  
**Value: CRITICAL + SCALABLE**

---

**พร้อม implement ตามแนวคิดขั้นสูงนี้เลยไหมครับ? 🚀**

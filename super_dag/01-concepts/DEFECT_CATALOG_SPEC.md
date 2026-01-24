# Defect Catalog Specification

> **Last Updated:** 2024-12-04  
> **Status:** 📋 DRAFT  
> **Priority:** 🔴 HIGH  
> **Depends On:** COMPONENT_CATALOG_SPEC.md, QC_REWORK_PHILOSOPHY_V2.md  
> **Version:** v1

---

## 🎯 Purpose

**"QC กด FAIL แบบมีมาตรฐาน — ไม่พิมพ์เองเรื่อยเปื่อย"**

```
┌─────────────────────────────────────────────────────────────────┐
│              DEFECT CATALOG: WHY IT MATTERS                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ❌ WITHOUT CATALOG:                                            │
│     "ขอบสายไม่เรียบ"                                            │
│     "ขอบสายไม่เรียบค่ะ"                                         │
│     "ขอบสายไม่เรียบเว่อร์"                                       │
│     "ขอบสายไม่เรียบ / ย้วย"                                     │
│     → Data วิเคราะห์ไม่ได้!                                     │
│                                                                 │
│  ✅ WITH CATALOG:                                               │
│     ทุกคน: "EDGE_ROUGH" (เลือกจาก list)                         │
│     → Analytics, Training, RRM ทำงานได้ทันที                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📊 Database Schema

### Table: `defect_catalog`

```sql
CREATE TABLE defect_catalog (
    id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Identity
    defect_code VARCHAR(50) NOT NULL UNIQUE,     -- e.g., 'EDGE_ROUGH'
    
    -- Display
    display_name_th VARCHAR(100) NOT NULL,       -- e.g., 'ขอบไม่เรียบ'
    display_name_en VARCHAR(100) NOT NULL,       -- e.g., 'Rough Edge'
    description_th TEXT NULL,                    -- รายละเอียดภาษาไทย
    description_en TEXT NULL,                    -- รายละเอียดภาษาอังกฤษ
    
    -- Classification
    defect_category VARCHAR(30) NOT NULL,        -- e.g., 'EDGE', 'STITCH', 'GLUE', 'SURFACE'
    severity ENUM('low', 'medium', 'high', 'critical') DEFAULT 'medium',
    
    -- Component Mapping
    allowed_component_groups JSON NULL,          -- e.g., ["STRAP", "BODY"]
    allowed_component_codes JSON NULL,           -- e.g., ["STRAP_LONG", "STRAP_SHORT"]
    
    -- Rework Hints
    default_rework_behavior_pattern VARCHAR(50) NULL,  -- e.g., 'EDGE_%'
    suggested_rework_message_th VARCHAR(255) NULL,
    suggested_rework_message_en VARCHAR(255) NULL,
    
    -- Root Cause (for RRM)
    typical_root_causes JSON NULL,               -- e.g., ["skill_gap", "material_defect", "tool_issue"]
    
    -- Status
    is_active TINYINT(1) DEFAULT 1,
    display_order INT DEFAULT 0,
    
    -- Audit
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Indexes
    INDEX idx_category (defect_category),
    INDEX idx_severity (severity),
    INDEX idx_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## 📋 Standard Defect Categories

| Category | Description | Examples |
|----------|-------------|----------|
| `EDGE` | ปัญหาขอบ/ริม | EDGE_ROUGH, EDGE_UNEVEN, EDGE_PEELING |
| `STITCH` | ปัญหารอยเย็บ | STITCH_LOOSE, STITCH_UNEVEN, STITCH_SKIP |
| `GLUE` | ปัญหากาว | GLUE_PEELING, GLUE_VISIBLE, GLUE_WEAK |
| `SURFACE` | ปัญหาผิวหนัง | SCRATCH_VISIBLE, STAIN, COLOR_UNEVEN |
| `SHAPE` | ปัญหารูปทรง | SHAPE_DISTORTED, ALIGNMENT_OFF |
| `HARDWARE` | ปัญหาอุปกรณ์ | HARDWARE_LOOSE, HARDWARE_SCRATCH |
| `ASSEMBLY` | ปัญหาการประกอบ | ASSEMBLY_MISALIGN, ASSEMBLY_GAP |

---

## 📋 Seed Data (Initial Catalog)

```sql
INSERT INTO defect_catalog (
    defect_code, display_name_th, display_name_en, 
    defect_category, severity,
    allowed_component_groups, default_rework_behavior_pattern,
    typical_root_causes
) VALUES

-- EDGE Category
('EDGE_ROUGH', 'ขอบไม่เรียบ', 'Rough Edge', 
 'EDGE', 'medium',
 '["STRAP", "BODY", "FLAP"]', 'EDGE_%',
 '["skill_gap", "tool_worn", "technique_error"]'),

('EDGE_UNEVEN', 'ขอบไม่เสมอ', 'Uneven Edge', 
 'EDGE', 'medium',
 '["STRAP", "BODY", "FLAP"]', 'EDGE_%',
 '["cutting_error", "material_warp"]'),

('EDGE_PEELING', 'ขอบลอก', 'Peeling Edge', 
 'EDGE', 'high',
 '["STRAP", "BODY"]', 'EDGE_%',
 '["coating_issue", "adhesive_weak", "humidity"]'),

-- STITCH Category
('STITCH_LOOSE', 'รอยเย็บหลวม', 'Loose Stitch', 
 'STITCH', 'high',
 '["BODY", "STRAP", "FLAP", "POCKET"]', 'STITCH_%',
 '["tension_wrong", "skill_gap", "machine_issue"]'),

('STITCH_UNEVEN', 'รอยเย็บไม่สม่ำเสมอ', 'Uneven Stitch', 
 'STITCH', 'medium',
 '["BODY", "STRAP", "FLAP", "POCKET"]', 'STITCH_%',
 '["speed_inconsistent", "skill_gap"]'),

('STITCH_SKIP', 'รอยเย็บข้าม', 'Skipped Stitch', 
 'STITCH', 'high',
 '["BODY", "STRAP", "FLAP", "POCKET"]', 'STITCH_%',
 '["needle_worn", "thread_issue", "machine_timing"]'),

-- GLUE Category
('GLUE_PEELING', 'กาวลอก', 'Peeling Glue', 
 'GLUE', 'high',
 '["BODY", "STRAP", "FLAP"]', 'GLUE_%',
 '["adhesive_expired", "surface_dirty", "drying_time_short"]'),

('GLUE_VISIBLE', 'เห็นกาว', 'Visible Glue', 
 'GLUE', 'medium',
 '["BODY", "STRAP", "FLAP"]', 'GLUE_%',
 '["excess_application", "technique_error"]'),

('GLUE_WEAK', 'กาวไม่แน่น', 'Weak Glue Bond', 
 'GLUE', 'high',
 '["BODY", "STRAP", "FLAP"]', 'GLUE_%',
 '["adhesive_expired", "pressure_insufficient", "curing_incomplete"]'),

-- SURFACE Category
('SCRATCH_VISIBLE', 'มีรอยขีดข่วน', 'Visible Scratch', 
 'SURFACE', 'medium',
 '["BODY", "FLAP"]', 'QC_DECIDE',
 '["handling_rough", "tool_contact", "storage_issue"]'),

('STAIN_VISIBLE', 'มีคราบ/รอยเปื้อน', 'Visible Stain', 
 'SURFACE', 'medium',
 '["BODY", "STRAP", "FLAP", "LINING"]', 'QC_DECIDE',
 '["handling_dirty", "material_defect", "process_contamination"]'),

('COLOR_UNEVEN', 'สีไม่สม่ำเสมอ', 'Uneven Color', 
 'SURFACE', 'high',
 '["BODY", "STRAP", "FLAP"]', 'QC_DECIDE',
 '["material_batch_variation", "coating_issue"]'),

-- SHAPE Category
('SHAPE_DISTORTED', 'รูปทรงบิดเบี้ยว', 'Distorted Shape', 
 'SHAPE', 'high',
 '["BODY", "FLAP"]', 'CUT_%',
 '["cutting_error", "material_warp", "assembly_force"]'),

('ALIGNMENT_OFF', 'ไม่ตรงแนว', 'Alignment Off', 
 'SHAPE', 'medium',
 '["BODY", "STRAP", "POCKET"]', 'STITCH_%',
 '["positioning_error", "template_issue"]'),

-- ASSEMBLY Category
('ASSEMBLY_MISALIGN', 'ประกอบไม่ตรง', 'Assembly Misalignment', 
 'ASSEMBLY', 'high',
 '["BODY"]', 'ASSEMBLY_%',
 '["positioning_error", "rushing", "skill_gap"]'),

('ASSEMBLY_GAP', 'มีช่องว่างผิดปกติ', 'Assembly Gap', 
 'ASSEMBLY', 'medium',
 '["BODY"]', 'ASSEMBLY_%',
 '["measurement_error", "material_shrink"]');
```

---

## 🎨 QC Behavior UI Integration

### Defect Selection Flow

```
┌─────────────────────────────────────────────────────────────────┐
│              QC FAIL - SELECT DEFECT                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Component: STRAP_LONG (สายสะพายยาว)                            │
│                                                                 │
│  Defect Type: (เลือกจาก list)                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ▼ เลือก Defect                                          │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │ 📁 EDGE (ปัญหาขอบ)                                       │   │
│  │    ├─ EDGE_ROUGH (ขอบไม่เรียบ)                          │   │
│  │    ├─ EDGE_UNEVEN (ขอบไม่เสมอ)                          │   │
│  │    └─ EDGE_PEELING (ขอบลอก) ⚠️ HIGH                     │   │
│  │ 📁 STITCH (ปัญหารอยเย็บ)                                 │   │
│  │    ├─ STITCH_LOOSE (รอยเย็บหลวม) ⚠️ HIGH                │   │
│  │    ├─ STITCH_UNEVEN (รอยเย็บไม่สม่ำเสมอ)                │   │
│  │    └─ STITCH_SKIP (รอยเย็บข้าม) ⚠️ HIGH                 │   │
│  │ 📁 GLUE (ปัญหากาว)                                       │   │
│  │    └─ ...                                               │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ⚠️ แสดงเฉพาะ defect ที่ allowed กับ component นี้             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Rework Target Suggestion

```
┌─────────────────────────────────────────────────────────────────┐
│              REWORK TARGET (SUGGESTED ORDER)                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Component: STRAP_LONG                                          │
│  Defect: EDGE_ROUGH (ขอบไม่เรียบ)                               │
│  Severity: ⚠️ MEDIUM                                            │
│                                                                 │
│  Suggested Rework Targets: (เรียงตามความเหมาะสม)                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ⭐ 1. EDGE_STRAP (ขัดขอบสาย)     ← แนะนำ (match pattern) │   │
│  │    2. GLUE_STRAP (ติดกาวสาย)                             │   │
│  │    3. CUT_STRAP (ตัดสาย)         ← ถ้าต้องตัดใหม่        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  💡 "ปัญหาขอบ → แนะนำให้กลับไปขัดขอบ"                          │
│                                                                 │
│  Mode: ○ ซ่อมชิ้นเดิม  ○ ตัดใหม่ทั้งชิ้น                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔧 API Integration

> **Note:** โค้ดด้านล่างเป็น pseudo-code สำหรับแสดง concept  
> Implementation จริงต้องปรับตาม service layer ที่มีอยู่

### Get Defects for Component

```php
// dag_routing_api.php
case 'get_defects_for_component':
    $componentCode = $_REQUEST['component_code'] ?? '';
    $componentGroup = $_REQUEST['component_group'] ?? '';
    
    // ⚠️ Note: ถ้า componentCode/componentGroup ว่าง
    // JSON_CONTAINS จะไม่ match → ควร return all defects หรือ error
    // QC UI ควรรู้ component เสมอ (จาก Component Node)
    
    $stmt = $tenantDb->prepare("
        SELECT 
            defect_code,
            display_name_th,
            display_name_en,
            defect_category,
            severity,
            default_rework_behavior_pattern,
            suggested_rework_message_th
        FROM defect_catalog
        WHERE is_active = 1
        AND (
            JSON_CONTAINS(allowed_component_codes, ?, '$')
            OR JSON_CONTAINS(allowed_component_groups, ?, '$')
        )
        ORDER BY defect_category, display_order
    ");
    $codeJson = json_encode($componentCode);
    $groupJson = json_encode($componentGroup);
    $stmt->bind_param('ss', $codeJson, $groupJson);
    $stmt->execute();
    
    // Group by category
    $result = $stmt->get_result();
    $defects = [];
    while ($row = $result->fetch_assoc()) {
        $cat = $row['defect_category'];
        if (!isset($defects[$cat])) {
            $defects[$cat] = [];
        }
        $defects[$cat][] = $row;
    }
    
    json_success(['defects' => $defects]);
    break;
```

### Suggest Rework Targets

**Required Inputs:**
- `defect_code` - รหัส defect ที่เลือก
- `component_code` - component ที่กำลัง QC
- `qc_node_id` - node ID ของ QC ปัจจุบัน
- `token_id` - token ที่กำลังทำงาน (ใช้หา graph context)

```php
case 'suggest_rework_targets':
    $defectCode = $_REQUEST['defect_code'] ?? '';
    $componentCode = $_REQUEST['component_code'] ?? '';
    $qcNodeId = (int)($_REQUEST['qc_node_id'] ?? 0);
    $tokenId = (int)($_REQUEST['token_id'] ?? 0);  // ✅ Fixed: เพิ่ม token_id
    
    // Get defect info
    $defect = $this->getDefect($defectCode);
    $pattern = $defect['default_rework_behavior_pattern'] ?? null;
    
    // Get all rework targets for component (ใช้ algorithm จาก QC_REWORK_V2)
    $targets = $this->getReworkTargetsForQC($qcNodeId, $tokenId);
    
    // Sort by pattern match - ให้ node ที่ match pattern ขึ้นก่อน
    if ($pattern && $pattern !== 'QC_DECIDE') {
        usort($targets, function($a, $b) use ($pattern) {
            $aMatch = fnmatch($pattern, $a['behavior_code'] ?? '');
            $bMatch = fnmatch($pattern, $b['behavior_code'] ?? '');
            if ($aMatch && !$bMatch) return -1;
            if (!$aMatch && $bMatch) return 1;
            return 0;
        });
    }
    
    json_success([
        'targets' => $targets,
        'suggested_first' => $targets[0] ?? null,
        'defect_severity' => $defect['severity'],
        'suggestion_message' => $defect['suggested_rework_message_th']
    ]);
    break;
```

---

## 📈 Benefits

| Benefit | Description |
|---------|-------------|
| **Standardization** | Defect ทุกอันมี code เดียวกันทั้งองค์กร |
| **Analytics** | วิเคราะห์ defect rate by type, component, worker |
| **Training** | รู้ว่า defect ไหนเกิดบ่อย → สอนช่างเฉพาะเรื่อง |
| **RRM** | Link defect → typical root causes → preventive action |
| **Smart Suggestion** | แนะนำ rework node ที่เหมาะสมอัตโนมัติ |

---

## 🔄 Integration with RRM

```
┌─────────────────────────────────────────────────────────────────┐
│              DEFECT CATALOG → RRM FLOW                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. QC เลือก Defect: STITCH_LOOSE                               │
│                 │                                               │
│                 ▼                                               │
│  2. Catalog บอก typical_root_causes:                            │
│     ["tension_wrong", "skill_gap", "machine_issue"]             │
│                 │                                               │
│                 ▼                                               │
│  3. RRM ถามเพิ่ม: "สาเหตุน่าจะเป็น?"                            │
│     ○ เทนชั่นผิด                                                │
│     ○ ช่างยังไม่ชำนาญ                                           │
│     ○ เครื่องมีปัญหา                                            │
│                 │                                               │
│                 ▼                                               │
│  4. บันทึก root cause → ใช้ทำ preventive action                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Implementation Phases

### Phase 1: Basic Catalog (Week 1)
- [ ] สร้าง `defect_catalog` table
- [ ] Seed initial data (15-20 common defects)
- [ ] API `get_defects_for_component`

### Phase 2: QC UI Integration (Week 2)
- [ ] Defect dropdown ใน QC Behavior UI
- [ ] Filter defects by component
- [ ] Show severity badge

### Phase 3: Smart Suggestion (Week 3)
- [ ] Suggest rework targets by pattern
- [ ] Show suggestion message
- [ ] Log defect_code in qc_fail event

### Phase 4: RRM Integration (Week 4)
- [ ] Root cause selection UI
- [ ] Link to typical_root_causes
- [ ] Analytics dashboard

---

## 🔮 Future Extensions (v2+)

> **Status:** Optional enhancements for Hermès-level quality tracking  
> **Priority:** Low (ทำหลังจาก Phase 1-4 เสร็จ)

### 1. Defect Scope

บาง defect กระทบขอบเขตต่างกัน:

| Scope | Description | Example |
|-------|-------------|---------|
| `component` | แค่ชิ้นส่วนเดียว | SCRATCH_VISIBLE จุดเล็ก |
| `product` | ทั้งใบ (ต้อง scrap ทั้งใบ) | ASSEMBLY_MISALIGN หนัก |
| `batch` | ทั้ง batch วัสดุ | COLOR_UNEVEN (หนังทั้งแผ่น) |

```sql
-- Schema extension
ALTER TABLE defect_catalog ADD COLUMN 
    defect_scope ENUM('component', 'product', 'batch') DEFAULT 'component';
```

### 2. Customer Visibility Flags

Hermès treats defect ไม่เท่ากัน ขึ้นกับว่าลูกค้าเห็นหรือไม่:

```sql
ALTER TABLE defect_catalog ADD COLUMN 
    customer_visible TINYINT(1) DEFAULT 1 COMMENT 'ลูกค้าเห็นได้ (front-facing)';

ALTER TABLE defect_catalog ADD COLUMN 
    customer_critical TINYINT(1) DEFAULT 0 COMMENT 'กระทบ brand image มาก';
```

**Use cases:**
- Priority ของ rework (customer_critical ก่อน)
- Scrap policy (customer_visible + critical = scrap ทันที)
- Training priority (defect ที่ customer เห็นบ่อย = สอนก่อน)

### 3. Default QC Policy per Defect

แทนที่จะ hard-code policy ในหลายที่:

```sql
ALTER TABLE defect_catalog ADD COLUMN 
    default_qc_policy JSON NULL 
    COMMENT '{"allow_rework": true, "max_rework": 2, "allow_scrap": true}';
```

**Benefit:** QC Policy Engine อ่าน config จาก catalog → ไม่ต้องไป hard-code ในโค้ด

### 4. Defect Synonyms (Search-friendly)

รองรับคำค้นหาหลายรูปแบบ:

```sql
ALTER TABLE defect_catalog ADD COLUMN 
    synonyms JSON NULL 
    COMMENT '["ขอบไม่เรียบ", "edge rough", "ขอบหยาบ"]';
```

**Use case:** QC พิมพ์ "ขอบหยาบ" → ระบบ map ไปหา `EDGE_ROUGH` ให้อัตโนมัติ

---

## Related Documents

- [COMPONENT_CATALOG_SPEC.md](./COMPONENT_CATALOG_SPEC.md) - Component standards
- [QC_REWORK_PHILOSOPHY_V2.md](./QC_REWORK_PHILOSOPHY_V2.md) - QC V2 concept
- [GRAPH_LINTER_RULES.md](./GRAPH_LINTER_RULES.md) - Validation rules

---

> **"Defect Catalog = ภาษากลางของปัญหา"**




# Skill & Material Tolerance Rules Specification

> **Last Updated:** 2024-12-04  
> **Status:** 📋 DRAFT  
> **Priority:** 🟡 MEDIUM (Advanced Feature)  
> **Depends On:** COMPONENT_CATALOG_SPEC.md, DEFECT_CATALOG_SPEC.md  
> **Version:** v1 (Future Phase)  
> **Phase:** 🔮 Hatthasilpa Elite Mode (หลัง ERP Core เสร็จ)

---

## 📌 Scope

```
┌─────────────────────────────────────────────────────────────────┐
│                         DOCUMENT SCOPE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ✅ IN SCOPE:                                                   │
│     • Hatthasilpa Line ที่ใช้ DAG / Work Queue                  │
│     • Advanced manufacturing tracking                           │
│     • Skill-based worker assignment                             │
│     • Material tolerance QC                                     │
│                                                                 │
│  ❌ OUT OF SCOPE:                                               │
│     • Classic Line (PWA สแกนเฉย ๆ)                              │
│     • Simple linear workflows                                   │
│     • Non-manufacturing processes                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

> ⚠️ **หมายเหตุ:** อย่านำ Skill/Material system ไปใช้กับ Classic PWA

---

## ⚠️ Implementation Timeline

```
┌─────────────────────────────────────────────────────────────────┐
│              THIS IS A FUTURE PHASE FEATURE                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  📅 Timeline:                                                   │
│     ERP Core → Component Node → QC V2 → ✅ ก่อน                 │
│     People DB + Skill Model → Material Tolerance → 🔮 หลัง      │
│                                                                 │
│  🎯 Purpose of this doc:                                        │
│     • วางโครงสร้างไว้ล่วงหน้า                                   │
│     • ให้ AI Agent รุ่นหลังเข้าใจ vision                         │
│     • กัน scope creep ไม่ให้หลุดไปทำตอนนี้                      │
│                                                                 │
│  ❌ DO NOT implement until:                                     │
│     1. ERP Core complete                                        │
│     2. People DB / Worker system ready                          │
│     3. Explicit request from product owner                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Purpose

**"จาก 'แค่ QC ผ่าน/ไม่ผ่าน' ไปสู่ 'วิทยาศาสตร์ของฝีมือและวัสดุ'"**

```
┌─────────────────────────────────────────────────────────────────┐
│        SKILL & MATERIAL: THE NEXT LEVEL                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  CURRENT STATE (Basic):                                         │
│     • Track token, component, behavior                          │
│     • QC pass/fail                                              │
│     • Rework path                                               │
│                                                                 │
│  NEXT LEVEL (Advanced):                                         │
│     • Skill Model → ช่างมี skill level ต่างกัน                  │
│     • Material Tolerance → วัสดุมี spec + tolerance             │
│     • Smart Matching → งานยากให้ช่างเก่ง                        │
│     • Root Cause → รู้ว่าปัญหาเกิดจากคน/วัสดุ/กระบวนการ          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📊 Part 1: Skill Model

### Database Schema

```sql
-- Skill Categories
CREATE TABLE skill_category (
    id INT AUTO_INCREMENT PRIMARY KEY,
    skill_code VARCHAR(30) NOT NULL UNIQUE,  -- e.g., 'STITCH', 'EDGE', 'GLUE'
    display_name_th VARCHAR(100) NOT NULL,
    display_name_en VARCHAR(100) NOT NULL,
    max_level INT DEFAULT 5,
    description TEXT NULL,
    is_active TINYINT(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Worker Skill Levels
CREATE TABLE worker_skill (
    id INT AUTO_INCREMENT PRIMARY KEY,
    worker_id INT NOT NULL,               -- FK to People DB (see note below)
    skill_code VARCHAR(30) NOT NULL,      -- FK to skill_category
    skill_level INT NOT NULL DEFAULT 1,   -- 1-5
    certified_at DATETIME NULL,           -- When skill was certified
    certified_by INT NULL,                -- Who certified
    notes TEXT NULL,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uk_worker_skill (worker_id, skill_code),
    INDEX idx_skill_level (skill_code, skill_level)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ⚠️ NOTE: worker_id Reference
-- ในระบบ Bellavier ERP จริง worker_id จะผูกกับ:
-- - People DB (ถ้าแยก microservice)
-- - หรือ bgerp.account (id_member) ถ้าใช้ระบบเดิม
-- - หรือ worker table ใหม่ (ถ้าสร้างแยก)
-- ให้ implementation จริง map ตาม source ขององค์กร

-- Node Skill Requirements
CREATE TABLE node_skill_requirement (
    id INT AUTO_INCREMENT PRIMARY KEY,
    node_id INT NOT NULL,                 -- FK to routing_node
    skill_code VARCHAR(30) NOT NULL,
    min_level INT NOT NULL DEFAULT 1,     -- Minimum required level
    preferred_level INT NULL,             -- Preferred level (for better quality)
    
    UNIQUE KEY uk_node_skill (node_id, skill_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### Skill Levels Definition

| Level | Name | Description |
|-------|------|-------------|
| **1** | เริ่มต้น (Beginner) | เรียนรู้พื้นฐาน ต้องมีคนดูแล |
| **2** | พื้นฐาน (Basic) | ทำงานง่ายได้ ยังต้องตรวจบ่อย |
| **3** | ปานกลาง (Intermediate) | ทำงานทั่วไปได้ดี |
| **4** | ชำนาญ (Advanced) | ทำงานยากได้ คุณภาพสม่ำเสมอ |
| **5** | ผู้เชี่ยวชาญ (Master) | ทำทุกอย่างได้ สอนคนอื่นได้ |

### Seed Data

```sql
-- Skill Categories
INSERT INTO skill_category (skill_code, display_name_th, display_name_en, max_level) VALUES
('CUTTING', 'การตัด', 'Cutting', 5),
('STITCHING', 'การเย็บ', 'Stitching', 5),
('EDGE_WORK', 'งานขอบ', 'Edge Work', 5),
('GLUING', 'การทากาว', 'Gluing', 5),
('ASSEMBLY', 'การประกอบ', 'Assembly', 5),
('QC_INSPECTION', 'การตรวจสอบ', 'QC Inspection', 5);

-- Example Worker Skills
INSERT INTO worker_skill (worker_id, skill_code, skill_level, certified_at) VALUES
(1, 'STITCHING', 5, '2024-01-15'),  -- Master stitcher
(1, 'EDGE_WORK', 4, '2024-01-15'),
(1, 'GLUING', 3, '2024-01-15'),
(2, 'STITCHING', 2, '2024-06-01'),  -- Beginner stitcher
(2, 'EDGE_WORK', 1, '2024-06-01');
```

### Multi-Skill per Node Example

บาง node ต้องการหลาย skill:

| node_id | Node | skill_code | min_level | preferred_level | Notes |
|---------|------|------------|-----------|-----------------|-------|
| 101 | STITCH_BODY | STITCHING | 4 | 5 | เย็บงานหลัก |
| 101 | STITCH_BODY | EDGE_WORK | 3 | 4 | เย็บแล้วเก็บขอบด้วย |
| 102 | EDGE_STRAP | EDGE_WORK | 4 | 5 | งานขอบหลัก |
| 102 | EDGE_STRAP | GLUING | 2 | 3 | อาจต้องทากาวก่อนขัด |

→ Worker ต้องมีทั้ง 2 skills ถึง min_level จึงจะ qualified

---

### Skill Matching Flow

```
┌─────────────────────────────────────────────────────────────────┐
│              SKILL MATCHING FLOW                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Token arrives at node: STITCH_BODY                          │
│                 │                                               │
│                 ▼                                               │
│  2. Node requires: STITCHING level ≥ 4                          │
│                 │                                               │
│                 ▼                                               │
│  3. Available workers:                                          │
│     • W001: STITCHING = 5 ✅ (เกินพอ)                           │
│     • W002: STITCHING = 2 ⚠️ (ไม่พอ)                            │
│     • W003: STITCHING = 4 ✅ (พอดี)                             │
│                 │                                               │
│                 ▼                                               │
│  4. Assignment Options:                                         │
│     a) Auto-assign to W001 or W003                              │
│     b) Show warning if assign to W002                           │
│     c) Block W002 from this task                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### API: Check Skill Match

```php
case 'check_skill_match':
    $nodeId = (int)($_REQUEST['node_id'] ?? 0);
    $workerId = (int)($_REQUEST['worker_id'] ?? 0);
    
    // Get node requirements
    $requirements = $this->getNodeSkillRequirements($nodeId);
    
    // Get worker skills
    $workerSkills = $this->getWorkerSkills($workerId);
    
    $result = [
        'is_qualified' => true,
        'warnings' => [],
        'gaps' => []
    ];
    
    foreach ($requirements as $req) {
        $skill = $req['skill_code'];
        $minLevel = $req['min_level'];
        $workerLevel = $workerSkills[$skill] ?? 0;
        
        if ($workerLevel < $minLevel) {
            $result['is_qualified'] = false;
            $result['gaps'][] = [
                'skill' => $skill,
                'required' => $minLevel,
                'actual' => $workerLevel,
                'gap' => $minLevel - $workerLevel
            ];
        } elseif ($workerLevel < $req['preferred_level']) {
            $result['warnings'][] = [
                'skill' => $skill,
                'preferred' => $req['preferred_level'],
                'actual' => $workerLevel,
                'message' => "Skill {$skill} level {$workerLevel} below preferred {$req['preferred_level']}"
            ];
        }
    }
    
    json_success($result);
    break;
```

### API Hook Points (Where to use check_skill_match)

| Use Case | When to Call | Behavior |
|----------|--------------|----------|
| **Primary: Assignment Screen** | หัวหน้างานกด assign งานให้ช่าง | แสดง warning ถ้า skill ไม่พอ |
| **Secondary: Work Queue** | ช่างกดรับงานจาก queue | แสดง suggestion / filter งานที่ qualified |
| **Optional: startWork Guard** | ก่อน BehaviorExecutionService.startWork() | Block ถ้า skill ไม่พอ (strict mode) |

> **Note:** ใน Phase แรก แนะนำใช้เป็น **suggestion/warning** เท่านั้น  
> ไม่ใช่ hard block — เพื่อให้หน้างานยังคล่องตัว

---

## 📊 Part 2: Material Tolerance

### Database Schema

```sql
-- Material Specifications
CREATE TABLE material_spec (
    id INT AUTO_INCREMENT PRIMARY KEY,
    material_code VARCHAR(50) NOT NULL UNIQUE,   -- e.g., 'GOAT_NAPPA_001'
    material_name_th VARCHAR(100) NOT NULL,
    material_name_en VARCHAR(100) NOT NULL,
    material_type VARCHAR(30) NOT NULL,          -- 'leather', 'fabric', 'hardware'
    supplier_code VARCHAR(50) NULL,
    
    -- Standard Specifications
    specs JSON NOT NULL,  -- {"thickness_mm": 1.6, "weight_gsm": 450, ...}
    
    is_active TINYINT(1) DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Component Material Requirements
CREATE TABLE component_material_spec (
    id INT AUTO_INCREMENT PRIMARY KEY,
    component_code VARCHAR(50) NOT NULL,         -- FK to component_catalog
    material_code VARCHAR(50) NOT NULL,          -- FK to material_spec
    
    -- Tolerance Rules
    tolerance_rules JSON NOT NULL,
    -- e.g., {
    --   "thickness_mm": {"min": 1.5, "max": 1.7, "target": 1.6},
    --   "weight_gsm": {"min": 420, "max": 480, "target": 450}
    -- }
    
    notes TEXT NULL,
    
    UNIQUE KEY uk_component_material (component_code, material_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Material Measurements (QC Data)
CREATE TABLE qc_material_measurement (
    id INT AUTO_INCREMENT PRIMARY KEY,
    token_id INT NOT NULL,
    component_code VARCHAR(50) NOT NULL,
    material_code VARCHAR(50) NOT NULL,
    
    -- Actual Measurements
    measurements JSON NOT NULL,
    -- e.g., {"thickness_mm": 1.55, "weight_gsm": 445}
    
    -- Tolerance Check Results
    tolerance_check JSON NOT NULL,
    -- e.g., {"thickness_mm": "pass", "weight_gsm": "pass", "overall": "pass"}
    
    measured_by INT NOT NULL,
    measured_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    notes TEXT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 📋 Measurement Strategy (Policy Decision)

> **เลือก 1 แนวทางก่อน implement:**

| Strategy | Description | Pros | Cons |
|----------|-------------|------|------|
| **Per Piece** | วัดทุกชิ้น ทุก token | ข้อมูลละเอียดสุด | หนัก, ใช้เวลา |
| **Per Batch** | วัด first piece ของ batch แล้วใช้ร่วมกัน | เร็ว, ปฏิบัติได้จริง | อาจพลาด variation ใน batch |
| **Critical Only** | วัดเฉพาะ component สำคัญ (BODY, FLAP) | สมดุลดี | ไม่ครบทุกชิ้น |

**แนะนำ Phase 1:** ใช้ **Per Batch + Critical Only**
- วัดเฉพาะ critical component
- วัดเฉพาะ first piece ของ batch
- ให้ token_id ชี้ไปที่ "representative token" ของ batch นั้น

**Uniqueness Policy:**
- ถ้าต้องการ 1 ครั้งต่อ token+component → เพิ่ม `UNIQUE KEY uk_token_component (token_id, component_code)`
- ถ้าต้องการรองรับหลาย measurement (ก่อน/หลัง rework) → เพิ่ม `measurement_phase` field

### Tolerance Check Flow

```
┌─────────────────────────────────────────────────────────────────┐
│              MATERIAL TOLERANCE CHECK                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Component: STRAP_LONG                                          │
│  Material: GOAT_NAPPA_001                                       │
│                                                                 │
│  Tolerance Rules:                                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Property      │ Min   │ Target │ Max   │ Unit          │   │
│  ├───────────────┼───────┼────────┼───────┼───────────────┤   │
│  │ thickness_mm  │ 1.50  │ 1.60   │ 1.70  │ mm            │   │
│  │ weight_gsm    │ 420   │ 450    │ 480   │ g/m²          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  QC Measurement Input:                                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ thickness_mm: [1.55] mm    ✅ PASS (1.50-1.70)          │   │
│  │ weight_gsm:   [445 ] g/m²  ✅ PASS (420-480)            │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Overall: ✅ PASS                                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Example: Out of Tolerance

```
┌─────────────────────────────────────────────────────────────────┐
│              OUT OF TOLERANCE CASE                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  QC Measurement Input:                                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ thickness_mm: [1.45] mm    ❌ FAIL (below 1.50)         │   │
│  │ weight_gsm:   [445 ] g/m²  ✅ PASS                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Overall: ❌ FAIL - Material out of tolerance                   │
│                                                                 │
│  ⚠️ This indicates a MATERIAL DEFECT, not workmanship issue    │
│                                                                 │
│  Actions:                                                       │
│  ○ Scrap piece (material unusable)                              │
│  ○ Use anyway (with approval)                                   │
│  ○ Notify supplier (batch issue)                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📊 Part 3: Integration with QC & RRM

### Enhanced QC Flow

```
┌─────────────────────────────────────────────────────────────────┐
│              ENHANCED QC FLOW (SKILL + MATERIAL)                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Token at QC Node                                            │
│                 │                                               │
│                 ▼                                               │
│  2. QC Inspector checks:                                        │
│     a) Visual inspection (defect catalog)                       │
│     b) Material measurements (tolerance check)                  │
│                 │                                               │
│                 ▼                                               │
│  3. If FAIL, system determines root cause:                      │
│                                                                 │
│     ┌─────────────────────────────────────────────────────┐    │
│     │ ROOT CAUSE ANALYSIS                                  │    │
│     ├─────────────────────────────────────────────────────┤    │
│     │                                                      │    │
│     │ Defect: EDGE_ROUGH                                   │    │
│     │ Material: ✅ Within tolerance                        │    │
│     │ Worker: W002 (skill EDGE=2, required=4)              │    │
│     │                                                      │    │
│     │ → Likely cause: SKILL GAP                            │    │
│     │ → Action: Training needed for W002                   │    │
│     │                                                      │    │
│     └─────────────────────────────────────────────────────┘    │
│                                                                 │
│     OR                                                          │
│                                                                 │
│     ┌─────────────────────────────────────────────────────┐    │
│     │ ROOT CAUSE ANALYSIS                                  │    │
│     ├─────────────────────────────────────────────────────┤    │
│     │                                                      │    │
│     │ Defect: EDGE_PEELING                                 │    │
│     │ Material: ❌ Thickness 1.45mm (below 1.50)           │    │
│     │ Worker: W001 (skill EDGE=5, master)                  │    │
│     │                                                      │    │
│     │ → Likely cause: MATERIAL DEFECT                      │    │
│     │ → Action: Notify supplier, check batch               │    │
│     │                                                      │    │
│     └─────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### RRM with Skill & Material Data

> **⚠️ Scope of Automation (Phase 1)**
>
> RRM ใช้ข้อมูล skill/material ในเชิง **analysis & suggestion เท่านั้น**
> - ✅ แสดง likely root cause ให้ QC เห็น
> - ✅ แนะนำ action (training, notify supplier)
> - ✅ เก็บข้อมูลสำหรับ analytics dashboard
> - ❌ ไม่ auto-block การทำงาน
> - ❌ ไม่ auto-scrap batch โดยไม่ถามคน
> - ❌ ไม่เปลี่ยน routing อัตโนมัติ
>
> **เหตุผล:** หน้างานต้องคล่องตัว คนต้องเป็นผู้ตัดสินใจสุดท้าย

```php
class EnhancedRRM
{
    public function analyzeDefect(array $qcEvent): array
    {
        $tokenId = $qcEvent['token_id'];
        $defectCode = $qcEvent['defect_code'];
        $workerId = $qcEvent['operator_id'];
        $nodeId = $qcEvent['node_id'];
        
        // Get context
        $defect = $this->getDefect($defectCode);
        $materialCheck = $this->getMaterialMeasurement($tokenId);
        $skillMatch = $this->checkSkillMatch($nodeId, $workerId);
        
        // Determine likely root cause
        $analysis = [
            'defect' => $defect,
            'material_status' => $materialCheck['overall'],
            'skill_status' => $skillMatch['is_qualified'],
            'likely_causes' => []
        ];
        
        // Material out of tolerance?
        if ($materialCheck['overall'] === 'fail') {
            $analysis['likely_causes'][] = [
                'type' => 'MATERIAL_DEFECT',
                'confidence' => 0.85,
                'evidence' => $materialCheck['failures'],
                'actions' => ['notify_supplier', 'check_batch']
            ];
        }
        
        // Skill gap?
        if (!$skillMatch['is_qualified']) {
            $analysis['likely_causes'][] = [
                'type' => 'SKILL_GAP',
                'confidence' => 0.75,
                'evidence' => $skillMatch['gaps'],
                'actions' => ['training', 'reassign']
            ];
        }
        
        // Process issue? (good skill, good material, still failed)
        if ($materialCheck['overall'] === 'pass' && $skillMatch['is_qualified']) {
            $analysis['likely_causes'][] = [
                'type' => 'PROCESS_ISSUE',
                'confidence' => 0.60,
                'evidence' => ['environment', 'tooling', 'procedure'],
                'actions' => ['review_process', 'check_equipment']
            ];
        }
        
        return $analysis;
    }
}
```

---

## 📈 Benefits

| Benefit | Description |
|---------|-------------|
| **Smart Assignment** | งานยากให้ช่างที่มี skill สูง |
| **Root Cause Visibility** | รู้ว่าปัญหาเกิดจากคน/วัสดุ/กระบวนการ |
| **Training Focus** | รู้ว่าช่างคนไหนต้องฝึกอะไร |
| **Supplier Quality** | ตรวจสอบคุณภาพวัสดุเป็นระบบ |
| **Continuous Improvement** | Data-driven quality improvement |

---

## 🚀 Implementation Phases

### Phase 1: Skill Model (Week 1-2)
- [ ] skill_category, worker_skill tables
- [ ] Skill level CRUD
- [ ] Node skill requirements

### Phase 2: Skill Matching (Week 3-4)
- [ ] Check skill match API
- [ ] Assignment warnings
- [ ] Dashboard: skill gaps

### Phase 3: Material Tolerance (Week 5-6)
- [ ] material_spec, component_material_spec tables
- [ ] QC measurement input
- [ ] Tolerance check logic

### Phase 4: RRM Integration (Week 7-8)
- [ ] Enhanced root cause analysis
- [ ] Combine skill + material + defect
- [ ] Recommendations engine

---

## Related Documents

- [COMPONENT_CATALOG_SPEC.md](./COMPONENT_CATALOG_SPEC.md) - Component standards
- [DEFECT_CATALOG_SPEC.md](./DEFECT_CATALOG_SPEC.md) - Defect standards
- [QC_REWORK_PHILOSOPHY_V2.md](./QC_REWORK_PHILOSOPHY_V2.md) - QC V2 concept
- [GRAPH_LINTER_RULES.md](./GRAPH_LINTER_RULES.md) - Rules B2/B3/B4 use skill/material data

### Integration with Graph Linter

Graph Linter จะมี rules ระดับ Best Practice ที่เชื่อมกับ spec นี้:

| Rule | Description |
|------|-------------|
| **B2** | Work center compatibility - ใช้ข้อมูล node_skill_requirement |
| **B3** | Material compatibility - ใช้ข้อมูล component_material_spec |
| **B4** | Skill not assigned - เตือนถ้า node มี skill requirement แต่ไม่มี assignment |

> Rules เหล่านี้ active เมื่อ Skill/Material system ถูก implement แล้วเท่านั้น

---

> **"จาก QC ผ่าน/ไม่ผ่าน → วิทยาศาสตร์ของฝีมือและวัสดุ"**




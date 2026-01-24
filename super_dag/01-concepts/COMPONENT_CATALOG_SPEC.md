# Component Catalog Specification

> **Last Updated:** 2025-12-04  
> **Status:** 📋 DRAFT  
> **Priority:** 🔴 HIGH (Foundation for all other standards)  
> **Depends On:** QC_REWORK_PHILOSOPHY_V2.md  
> **Version:** v2 (Anchor Model)

---

## 🎯 Purpose

**"ทำให้ component_code เป็นภาษากลางขององค์กร — ไม่มั่ว, ไม่ซ้ำ, ไม่พิมพ์ตามอารมณ์"**

```
┌─────────────────────────────────────────────────────────────────┐
│              COMPONENT CATALOG: WHY IT MATTERS                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ❌ WITHOUT CATALOG:                                            │
│     ช่าง A: "STRAP"                                             │
│     ช่าง B: "LONG_STRAP"                                        │
│     ช่าง C: "สายสะพาย"                                          │
│     → Query รวม performance ไม่ได้!                             │
│                                                                 │
│  ✅ WITH CATALOG:                                               │
│     ทุกคน: "STRAP_LONG" (จาก dropdown)                          │
│     → Report, Analytics, RRM ทำงานได้ทันที                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## ⚖️ Design vs Config Boundary

### Graph Designer ใช้ Catalog ในฐานะ "Read-Only Dictionary"

Graph Designer ใช้ `component_catalog` เพื่อ:

| ✅ ทำ | ❌ ไม่ทำ |
|-------|---------|
| แสดงรายชื่อ component ให้เลือก (dropdown) | กำหนด defect rules / policy |
| ป้องกันการตั้งชื่อมั่ว / ซ้ำ | กำหนด material specs |
| Validate ว่า code มีจริงในระบบ | กำหนด skill requirements |
| ใช้เป็น domain label ใน graph | กำหนด cost / pricing |

### ทำไม component_code ถือเป็น "โครงสร้าง" ไม่ใช่ "config"?

```
┌─────────────────────────────────────────────────────────────────┐
│              COMPONENT = PART OF STRUCTURE                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  สำหรับ Bellavier / Hermès-style atelier:                       │
│                                                                 │
│  "มี component อะไรบ้างใน flow นี้"                             │
│  = ส่วนหนึ่งของโครงสร้างการผลิต                                 │
│  (BODY, STRAP, FLAP define ว่างานใบนี้ประกอบจากอะไร)            │
│                                                                 │
│  "รายละเอียดของ component นั้น"                                 │
│  = config / policy layer                                        │
│  (material, defect rules, cost, skill requirements)             │
│                                                                 │
│  Graph Designer รู้จัก "ตัวตน" ของ component (code)              │
│  แต่ไม่รู้ policy ลึก ๆ                                          │
│  → ยังอยู่ในโซน "routing + domain label"                        │
│  → ไม่ใช่ config editor เต็มตัว                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Design Decision (v2 - Anchor Model)

เวอร์ชันนี้เลือกให้ **Graph ใช้ Anchor Slot** เพราะ:

1. **Graph Designer = โครงสร้างล้วน** - ไม่ผูกกับ catalog โดยตรง
2. **Template reusable** - กราฟเดียว reuse ได้หลาย product/tenant
3. **Separation of Concerns** - โครงสร้าง (Graph) แยกจาก Config (Mapping)
4. **Progressive Enhancement** - ใช้ mapping layer หรือ MCI inject ก็ได้

```
┌─────────────────────────────────────────────────────────────────┐
│              V2: ANCHOR MODEL (CURRENT)                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Layer 1: GRAPH TEMPLATE (Graph Designer สร้าง)                 │
│  ├─ node_type = 'component'                                     │
│  ├─ anchor_slot = 'SLOT_A', 'SLOT_B', etc.                     │
│  └─ label = 'Component 1' (generic, not catalog-bound)         │
│                                                                 │
│  Layer 2: CONFIGURATION (Product Config / Instance)            │
│  ├─ graph_component_mapping table                               │
│  └─ slot_mapping = {                                            │
│        "SLOT_A": "STRAP_LONG",    ← Map จาก Catalog             │
│        "SLOT_B": "BODY_MAIN_PANEL"                              │
│      }                                                          │
│                                                                 │
│  Layer 3: RUNTIME (Token Lifecycle)                             │
│  └─ token.component_code = resolved from mapping                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

> **หมายเหตุ:** Graph Designer ไม่รู้จัก component_code โดยตรง - ใช้แค่ anchor_slot เป็น placeholder

---

## 📊 Database Schema

### Table: `component_catalog`

```sql
CREATE TABLE component_catalog (
    id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Identity
    component_code VARCHAR(50) NOT NULL UNIQUE,  -- e.g., 'STRAP_LONG'
    
    -- Display
    display_name_th VARCHAR(100) NOT NULL,       -- e.g., 'สายสะพายยาว'
    display_name_en VARCHAR(100) NOT NULL,       -- e.g., 'Long Strap'
    
    -- Classification
    component_group VARCHAR(30) NOT NULL,        -- e.g., 'STRAP', 'BODY', 'FLAP'
    component_category VARCHAR(30) NULL,         -- e.g., 'STRUCTURAL', 'DECORATIVE'
    
    -- Metadata
    description TEXT NULL,
    icon_code VARCHAR(50) NULL,                  -- For UI display
    display_order INT DEFAULT 0,
    
    -- Status
    is_active TINYINT(1) DEFAULT 1,
    
    -- Audit
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT NULL,
    
    -- Indexes
    INDEX idx_group (component_group),
    INDEX idx_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## 📋 Standard Component Groups

| Group | Description | Examples |
|-------|-------------|----------|
| `BODY` | ตัวกระเป๋าหลัก | BODY_MAIN_PANEL, BODY_BACK_PANEL, GUSSET_SIDE |
| `STRAP` | สายสะพาย/สายคล้อง | STRAP_LONG, STRAP_SHORT, STRAP_HANDLE |
| `FLAP` | ฝาปิด | FLAP_MAIN, FLAP_POCKET |
| `POCKET` | กระเป๋าเล็ก/ช่องใส่ของ | POCKET_FRONT, POCKET_INTERNAL |
| `LINING` | ซับใน | LINING_MAIN, LINING_POCKET |
| `HARDWARE` | อุปกรณ์โลหะ | HARDWARE_ZIPPER, HARDWARE_BUCKLE |
| `TRIM` | ขอบ/ตกแต่ง | TRIM_PIPING, TRIM_EDGE |

---

## 📋 Seed Data (Initial Catalog)

```sql
INSERT INTO component_catalog (component_code, display_name_th, display_name_en, component_group, display_order) VALUES

-- BODY Group
('BODY_MAIN_PANEL', 'แผ่นตัวกระเป๋าหลัก', 'Main Body Panel', 'BODY', 10),
('BODY_BACK_PANEL', 'แผ่นหลังกระเป๋า', 'Back Body Panel', 'BODY', 20),
('GUSSET_SIDE', 'ข้างกระเป๋า', 'Side Gusset', 'BODY', 30),
('GUSSET_BOTTOM', 'ก้นกระเป๋า', 'Bottom Gusset', 'BODY', 40),

-- STRAP Group
('STRAP_LONG', 'สายสะพายยาว', 'Long Shoulder Strap', 'STRAP', 10),
('STRAP_SHORT', 'สายคล้องสั้น', 'Short Handle Strap', 'STRAP', 20),
('STRAP_HANDLE', 'หูหิ้ว', 'Top Handle', 'STRAP', 30),
('STRAP_WRIST', 'สายคล้องข้อมือ', 'Wrist Strap', 'STRAP', 40),

-- FLAP Group
('FLAP_MAIN', 'ฝาปิดหลัก', 'Main Flap', 'FLAP', 10),
('FLAP_POCKET', 'ฝากระเป๋าหน้า', 'Pocket Flap', 'FLAP', 20),

-- POCKET Group
('POCKET_FRONT', 'กระเป๋าหน้า', 'Front Pocket', 'POCKET', 10),
('POCKET_BACK', 'กระเป๋าหลัง', 'Back Pocket', 'POCKET', 20),
('POCKET_INTERNAL', 'กระเป๋าใน', 'Internal Pocket', 'POCKET', 30),
('POCKET_ZIPPER', 'กระเป๋าซิป', 'Zipper Pocket', 'POCKET', 40),

-- LINING Group
('LINING_MAIN', 'ซับในหลัก', 'Main Lining', 'LINING', 10),
('LINING_POCKET', 'ซับในกระเป๋า', 'Pocket Lining', 'LINING', 20),

-- TRIM Group
('TRIM_PIPING', 'เส้นไปป์ปิ้ง', 'Piping Trim', 'TRIM', 10),
('TRIM_EDGE_TAPE', 'เทปขอบ', 'Edge Tape', 'TRIM', 20);
```

---

## 🎨 Graph Designer Integration

### Component Node Creation UI

```
┌─────────────────────────────────────────────────────────────────┐
│              ADD COMPONENT NODE                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Node Type: [Component]                                         │
│                                                                 │
│  Component Code: (required)                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ▼ เลือกจาก Catalog                                       │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │ 📁 BODY                                                  │   │
│  │    ├─ BODY_MAIN_PANEL (แผ่นตัวกระเป๋าหลัก)               │   │
│  │    ├─ BODY_BACK_PANEL (แผ่นหลังกระเป๋า)                  │   │
│  │    ├─ GUSSET_SIDE (ข้างกระเป๋า)                          │   │
│  │    └─ GUSSET_BOTTOM (ก้นกระเป๋า)                         │   │
│  │ 📁 STRAP                                                 │   │
│  │    ├─ STRAP_LONG (สายสะพายยาว)                           │   │
│  │    ├─ STRAP_SHORT (สายคล้องสั้น)                         │   │
│  │    └─ STRAP_HANDLE (หูหิ้ว)                              │   │
│  │ 📁 FLAP                                                  │   │
│  │    ├─ FLAP_MAIN (ฝาปิดหลัก)                              │   │
│  │    └─ FLAP_POCKET (ฝากระเป๋าหน้า)                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ❌ ห้ามพิมพ์เอง - ต้องเลือกจาก Catalog เท่านั้น               │
│                                                                 │
│  [Cancel]                              [Create Component Node]  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### API: Get Component Catalog

```php
// dag_routing_api.php
case 'get_component_catalog':
    $stmt = $tenantDb->prepare("
        SELECT 
            component_code,
            display_name_th,
            display_name_en,
            component_group,
            icon_code
        FROM component_catalog
        WHERE is_active = 1
        ORDER BY component_group, display_order
    ");
    $stmt->execute();
    $result = $stmt->get_result();
    
    $catalog = [];
    while ($row = $result->fetch_assoc()) {
        $group = $row['component_group'];
        if (!isset($catalog[$group])) {
            $catalog[$group] = [];
        }
        $catalog[$group][] = $row;
    }
    
    json_success(['catalog' => $catalog]);
    break;
```

---

## 🔒 Validation Rules

### Rule 1: Component Node must use catalog code

```php
// GraphValidationEngine.php
private function validateComponentNode(array $node): array
{
    $errors = [];
    
    if ($node['node_type'] === 'component') {
        $componentCode = $node['component_code'] ?? null;
        
        if (empty($componentCode)) {
            $errors[] = [
                'code' => 'COMPONENT_CODE_REQUIRED',
                'message' => "Component node '{$node['node_code']}' must have component_code"
            ];
        } else {
            // Check if code exists in catalog
            if (!$this->isValidCatalogCode($componentCode)) {
                $errors[] = [
                    'code' => 'COMPONENT_CODE_INVALID',
                    'message' => "Component code '{$componentCode}' not found in catalog"
                ];
            }
        }
    }
    
    return $errors;
}
```

### Rule 2: No duplicate component codes in same graph

```php
private function validateUniqueComponentCodes(array $nodes): array
{
    $errors = [];
    $componentCodes = [];
    
    foreach ($nodes as $node) {
        if ($node['node_type'] === 'component') {
            $code = $node['component_code'];
            if (isset($componentCodes[$code])) {
                $errors[] = [
                    'code' => 'DUPLICATE_COMPONENT_CODE',
                    'message' => "Component code '{$code}' used multiple times in graph"
                ];
            }
            $componentCodes[$code] = true;
        }
    }
    
    return $errors;
}
```

---

## 📈 Benefits

| Benefit | Description |
|---------|-------------|
| **Consistency** | ทุกกราฟใช้ชื่อ component เดียวกัน |
| **Analytics** | Query รวม defect rate ของ STRAP_LONG ทั้งองค์กรได้ |
| **Training** | สอนช่างใหม่ด้วย "ภาษาเดียวกัน" |
| **RRM** | Root Rework Mapping รู้ว่า defect นี้เกี่ยวกับ component ไหน |
| **Traceability** | ติดตามชิ้นส่วนแต่ละชิ้นได้ชัดเจน |

---

## 🚀 Implementation Phases

### Phase 1: Basic Catalog (Week 1)
- [ ] สร้าง `component_catalog` table
- [ ] Seed initial data
- [ ] API `get_component_catalog`

### Phase 2: Graph Designer Integration (Week 2)
- [ ] Component Node UI ใช้ dropdown จาก catalog
- [ ] Validation: ต้องเลือกจาก catalog เท่านั้น
- [ ] ห้ามพิมพ์ component_code เอง

### Phase 3: Migration (Week 3)
- [ ] Migrate existing component nodes to use catalog codes
- [ ] Add validation warnings for non-catalog codes

---

## 📊 Database Schema (v2 - Anchor Model)

### Table: `routing_node` Changes

```sql
-- Add anchor_slot column (NOT component_code)
ALTER TABLE routing_node ADD COLUMN anchor_slot VARCHAR(50) NULL 
  COMMENT 'Anchor slot for component nodes (e.g., SLOT_A, SLOT_B)';

ALTER TABLE routing_node ADD INDEX idx_anchor_slot (anchor_slot);
```

### Table: `graph_component_mapping` (NEW)

```sql
-- Mapping layer: connects graph anchor slots to catalog components
CREATE TABLE graph_component_mapping (
    id INT AUTO_INCREMENT PRIMARY KEY,
    graph_id INT NOT NULL,               -- FK to routing_graph
    anchor_slot VARCHAR(50) NOT NULL,    -- e.g., 'SLOT_A', 'SLOT_B'
    component_code VARCHAR(50) NOT NULL, -- FK to component_catalog
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY uk_graph_slot (graph_id, anchor_slot),
    FOREIGN KEY (graph_id) REFERENCES routing_graph(id_graph) ON DELETE CASCADE,
    FOREIGN KEY (component_code) REFERENCES component_catalog(component_code)
);
```

### Resolution Flow

```
┌─────────────────────────────────────────────────────────────────┐
│              COMPONENT CODE RESOLUTION                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Step 1: Token spawns at Component Node                         │
│  ────────────────────────────────────────────────               │
│  routing_node.anchor_slot = 'SLOT_A'                            │
│                                                                 │
│  Step 2: Lookup graph_component_mapping                         │
│  ────────────────────────────────────────────────               │
│  SELECT component_code                                          │
│  FROM graph_component_mapping                                   │
│  WHERE graph_id = ? AND anchor_slot = 'SLOT_A'                 │
│  → Returns 'STRAP_LONG'                                         │
│                                                                 │
│  Step 3: Set on Token                                           │
│  ────────────────────────────────────────────────               │
│  token.component_code = 'STRAP_LONG' (stored in metadata)       │
│                                                                 │
│  Step 4: Services use resolved code                             │
│  ────────────────────────────────────────────────               │
│  ComponentFlowService, MCI, RRM → all use component_code        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📝 Legacy Note (v1 - Direct Binding)

> **Status:** ⚠️ DEPRECATED - Do not use for new implementations

**v1 Approach (Not Recommended):**
- ❌ `routing_node.component_code` directly
- ❌ Graph Designer selects from catalog
- ❌ Tight coupling between graph and catalog

**Why v1 was deprecated:**
- Graph cannot be reused across products/tenants
- Graph Designer becomes a "config editor" (violates neutrality principle)
- No separation between structure and configuration

---

## Related Documents

- [QC_REWORK_PHILOSOPHY_V2.md](./QC_REWORK_PHILOSOPHY_V2.md) - Component Node concept
- [DEFECT_CATALOG_SPEC.md](./DEFECT_CATALOG_SPEC.md) - Defect standards (next)
- [GRAPH_LINTER_RULES.md](./GRAPH_LINTER_RULES.md) - Validation rules
- [MISSING_COMPONENT_INJECTION_SPEC.md](./MISSING_COMPONENT_INJECTION_SPEC.md) - **Escape Hatch** เมื่อกราฟลืมวาด component

---

## 🚨 Escape Hatch: Missing Component Injection

```
┌─────────────────────────────────────────────────────────────────┐
│              WHEN GRAPH ≠ REALITY                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Component Catalog เป็น "source of truth" สำหรับ:              │
│  • Graph Designer (เลือก component_code จาก catalog)            │
│  • MCI (validate ว่า component ที่ช่างแจ้งมีในระบบจริง)          │
│                                                                 │
│  ถ้า Designer ลืมวาด component ในกราฟ:                          │
│  • ช่างสามารถใช้ MCI inject component ได้                       │
│  • MCI validate ว่า component_code อยู่ใน catalog               │
│  • ไม่ต้องแก้ graph ระหว่าง production                          │
│                                                                 │
│  See: MISSING_COMPONENT_INJECTION_SPEC.md                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

> **"Component Catalog = ภาษากลางของชิ้นส่วน"**




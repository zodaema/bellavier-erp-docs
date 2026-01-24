# Material Requirement & Reservation System Specification

**Version:** 1.0  
**Status:** Draft  
**Created:** 2025-12-05  
**Related Tasks:** 27.13 (Component Node), 27.12 (Component Catalog)

---

## 📊 Executive Summary

ระบบ Material Management แบ่งเป็น 3 ชั้น:

| Layer | Service | Purpose | When |
|-------|---------|---------|------|
| **1. Requirement** | `MaterialRequirementService` | คำนวณความต้องการ | Draft Job / Preview |
| **2. Reservation** | `MaterialReservationService` | จองของกัน overbooking | Confirm Job |
| **3. Consumption** | `MaterialConsumptionService` | ตัด stock จริง | เบิกของ / CUT จริง |

---

## 🎯 Core Principle

```
❌ พิมพ์ตัวเลขในหน้า Job → ตัด stock ทันที (WRONG!)

✅ พิมพ์ตัวเลขในหน้า Job → คำนวณ requirement → แสดง preview
✅ Confirm Job → สร้าง reservation → กัน quota
✅ เบิกของ/CUT จริง → consumption → ลด stock
```

---

## 📐 Data Model

### Inventory Availability Formula

```
available_to_promise = on_hand_qty − SUM(reserved_qty_active)
```

### Tables

#### 1. `material_inventory` (extend existing)

```sql
-- Already exists, may need these columns:
ALTER TABLE material_inventory ADD COLUMN IF NOT EXISTS
    on_hand_qty DECIMAL(18,6) NOT NULL DEFAULT 0,
    reserved_qty DECIMAL(18,6) NOT NULL DEFAULT 0 COMMENT 'Calculated from material_reservation',
    committed_qty DECIMAL(18,6) NOT NULL DEFAULT 0 COMMENT 'Actually issued/consumed';
```

#### 2. `material_reservation` (NEW)

```sql
CREATE TABLE material_reservation (
    id_reservation INT AUTO_INCREMENT PRIMARY KEY,
    job_id INT NOT NULL COMMENT 'FK to job_ticket or hatthasilpa_job_ticket',
    job_type ENUM('job_ticket', 'hatthasilpa', 'mo') NOT NULL DEFAULT 'hatthasilpa',
    material_sku VARCHAR(100) NOT NULL,
    component_code VARCHAR(50) NULL COMMENT 'Optional: which component needs this',
    qty_reserved DECIMAL(18,6) NOT NULL,
    qty_issued DECIMAL(18,6) NOT NULL DEFAULT 0 COMMENT 'How much already consumed',
    status ENUM('active', 'partial', 'fulfilled', 'released', 'cancelled') NOT NULL DEFAULT 'active',
    reserved_by INT NOT NULL COMMENT 'FK to account.id_member',
    reserved_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    released_at DATETIME NULL,
    notes TEXT,
    
    KEY idx_job (job_id, job_type),
    KEY idx_material (material_sku),
    KEY idx_status (status),
    KEY idx_material_status (material_sku, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    COMMENT='Material reservations for jobs - blocks availability';
```

#### 3. `material_issue` (NEW - or extend existing consumption table)

```sql
CREATE TABLE material_issue (
    id_issue INT AUTO_INCREMENT PRIMARY KEY,
    reservation_id INT NULL COMMENT 'FK to material_reservation (if from reservation)',
    job_id INT NOT NULL,
    job_type ENUM('job_ticket', 'hatthasilpa', 'mo') NOT NULL DEFAULT 'hatthasilpa',
    material_sku VARCHAR(100) NOT NULL,
    lot_id INT NULL COMMENT 'FK to material_lot if lot-tracked',
    sheet_id INT NULL COMMENT 'FK to leather_sheet if leather',
    component_code VARCHAR(50) NULL,
    token_id INT NULL COMMENT 'FK to flow_token if issued during operation',
    qty_issued DECIMAL(18,6) NOT NULL,
    issued_by INT NOT NULL,
    issued_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    issue_type ENUM('warehouse', 'cut_station', 'workstation') NOT NULL DEFAULT 'warehouse',
    notes TEXT,
    
    KEY idx_job (job_id, job_type),
    KEY idx_reservation (reservation_id),
    KEY idx_material (material_sku),
    KEY idx_token (token_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    COMMENT='Actual material consumption records';
```

---

## 🔧 Service Layer

### 1. MaterialRequirementService

**Purpose:** คำนวณความต้องการวัสดุ (ไม่แตะ stock)

**Location:** `source/BGERP/Service/MaterialRequirementService.php`

```php
namespace BGERP\Service;

class MaterialRequirementService
{
    private \mysqli $db;
    private ComponentCatalogService $catalogService;
    
    /**
     * Calculate material requirements for a job
     * 
     * @param int $productId Product being produced
     * @param int $qty Job quantity
     * @param float $scrapAllowance Scrap allowance percentage (default 10%)
     * @return array Requirements with availability status
     */
    public function calculateRequirements(int $productId, int $qty, float $scrapAllowance = 0.10): array
    {
        $requirements = [];
        
        // 1. Get components for product (via graph + mapping)
        $components = $this->getComponentsForProduct($productId);
        
        // 2. For each component, get materials
        foreach ($components as $component) {
            $materials = $this->catalogService->getMaterialsForComponent($component['component_code']);
            
            foreach ($materials as $mat) {
                $baseQty = $mat['qty_per_component'] * $qty;
                $withScrap = $baseQty * (1 + $scrapAllowance);
                
                $sku = $mat['material_sku'];
                if (!isset($requirements[$sku])) {
                    $requirements[$sku] = [
                        'material_sku' => $sku,
                        'material_name' => $mat['material_name'] ?? $sku,
                        'total_qty' => 0,
                        'total_with_scrap' => 0,
                        'components' => [],
                        'on_hand' => 0,
                        'reserved' => 0,
                        'available' => 0,
                        'status' => 'unknown'
                    ];
                }
                
                $requirements[$sku]['total_qty'] += $baseQty;
                $requirements[$sku]['total_with_scrap'] += $withScrap;
                $requirements[$sku]['components'][] = [
                    'component_code' => $component['component_code'],
                    'qty_per' => $mat['qty_per_component'],
                    'subtotal' => $baseQty
                ];
            }
        }
        
        // 3. Check inventory availability
        foreach ($requirements as $sku => &$req) {
            $inventory = $this->getInventoryStatus($sku);
            $req['on_hand'] = $inventory['on_hand_qty'];
            $req['reserved'] = $inventory['reserved_qty'];
            $req['available'] = $inventory['on_hand_qty'] - $inventory['reserved_qty'];
            
            // Determine status
            if ($req['available'] >= $req['total_with_scrap']) {
                $req['status'] = 'sufficient';
            } elseif ($req['available'] >= $req['total_qty']) {
                $req['status'] = 'tight'; // พอแต่ไม่มี margin สำหรับ scrap
            } elseif ($req['available'] > 0) {
                $req['status'] = 'partial'; // มีบ้าง แต่ไม่พอ
            } else {
                $req['status'] = 'insufficient';
            }
        }
        
        return array_values($requirements);
    }
    
    /**
     * Check if job can be confirmed (all materials available)
     */
    public function canConfirmJob(int $productId, int $qty): array
    {
        $requirements = $this->calculateRequirements($productId, $qty);
        
        $canConfirm = true;
        $issues = [];
        
        foreach ($requirements as $req) {
            if ($req['status'] === 'insufficient') {
                $canConfirm = false;
                $issues[] = [
                    'material_sku' => $req['material_sku'],
                    'needed' => $req['total_with_scrap'],
                    'available' => $req['available'],
                    'shortage' => $req['total_with_scrap'] - $req['available']
                ];
            }
        }
        
        return [
            'can_confirm' => $canConfirm,
            'requirements' => $requirements,
            'issues' => $issues
        ];
    }
}
```

---

### 2. MaterialReservationService

**Purpose:** จองวัสดุเมื่อ Confirm Job (ยังไม่ตัด stock)

**Location:** `source/BGERP/Service/MaterialReservationService.php`

```php
namespace BGERP\Service;

class MaterialReservationService
{
    private \mysqli $db;
    private MaterialRequirementService $requirementService;
    
    /**
     * Create reservations for a job
     * Called when job is CONFIRMED (not draft)
     * 
     * @throws \Exception If insufficient materials
     */
    public function reserveForJob(int $jobId, string $jobType, int $productId, int $qty, int $userId): array
    {
        // 1. Calculate requirements
        $check = $this->requirementService->canConfirmJob($productId, $qty);
        
        if (!$check['can_confirm']) {
            throw new \Exception(
                'Insufficient materials: ' . 
                implode(', ', array_column($check['issues'], 'material_sku'))
            );
        }
        
        // 2. Create reservations
        $this->db->begin_transaction();
        
        try {
            $reservations = [];
            
            foreach ($check['requirements'] as $req) {
                $stmt = $this->db->prepare(
                    "INSERT INTO material_reservation 
                     (job_id, job_type, material_sku, qty_reserved, reserved_by)
                     VALUES (?, ?, ?, ?, ?)"
                );
                $stmt->bind_param('issdi', 
                    $jobId, $jobType, $req['material_sku'], 
                    $req['total_with_scrap'], $userId
                );
                $stmt->execute();
                
                $reservations[] = [
                    'id' => $stmt->insert_id,
                    'material_sku' => $req['material_sku'],
                    'qty_reserved' => $req['total_with_scrap']
                ];
                $stmt->close();
            }
            
            $this->db->commit();
            return $reservations;
            
        } catch (\Exception $e) {
            $this->db->rollback();
            throw $e;
        }
    }
    
    /**
     * Release reservations when job is cancelled
     */
    public function releaseForJob(int $jobId, string $jobType): void
    {
        $stmt = $this->db->prepare(
            "UPDATE material_reservation 
             SET status = 'released', released_at = NOW()
             WHERE job_id = ? AND job_type = ? AND status IN ('active', 'partial')"
        );
        $stmt->bind_param('is', $jobId, $jobType);
        $stmt->execute();
        $stmt->close();
    }
    
    /**
     * Get available quantity for a material
     */
    public function getAvailableToPromise(string $materialSku): float
    {
        $row = $this->dbHelper->fetchOne(
            "SELECT 
                COALESCE(i.on_hand_qty, 0) AS on_hand,
                COALESCE(SUM(r.qty_reserved - r.qty_issued), 0) AS reserved
             FROM material m
             LEFT JOIN material_inventory i ON i.material_sku = m.sku
             LEFT JOIN material_reservation r ON r.material_sku = m.sku 
                AND r.status IN ('active', 'partial')
             WHERE m.sku = ?
             GROUP BY m.sku",
            [$materialSku],
            's'
        );
        
        return ($row['on_hand'] ?? 0) - ($row['reserved'] ?? 0);
    }
}
```

---

### 3. MaterialConsumptionService

**Purpose:** บันทึกการใช้จริง / ตัด stock

**Location:** `source/BGERP/Service/MaterialConsumptionService.php`

```php
namespace BGERP\Service;

class MaterialConsumptionService
{
    private \mysqli $db;
    
    /**
     * Issue material from warehouse to job
     * For: Hardware, consumables (not leather sheets)
     */
    public function issueFromWarehouse(
        int $jobId,
        string $jobType,
        string $materialSku,
        float $qty,
        ?int $lotId,
        int $userId,
        ?string $notes = null
    ): int {
        $this->db->begin_transaction();
        
        try {
            // 1. Create issue record
            $stmt = $this->db->prepare(
                "INSERT INTO material_issue 
                 (job_id, job_type, material_sku, lot_id, qty_issued, 
                  issued_by, issue_type, notes)
                 VALUES (?, ?, ?, ?, ?, ?, 'warehouse', ?)"
            );
            $stmt->bind_param('issidis', 
                $jobId, $jobType, $materialSku, $lotId, 
                $qty, $userId, $notes
            );
            $stmt->execute();
            $issueId = $stmt->insert_id;
            $stmt->close();
            
            // 2. Update reservation (if exists)
            $this->updateReservationIssued($jobId, $jobType, $materialSku, $qty);
            
            // 3. Decrease inventory
            $this->decreaseInventory($materialSku, $qty, $lotId);
            
            $this->db->commit();
            return $issueId;
            
        } catch (\Exception $e) {
            $this->db->rollback();
            throw $e;
        }
    }
    
    /**
     * Issue leather sheet during CUT operation
     * For: Leather specifically, linked to token
     */
    public function issueLeatherSheet(
        int $tokenId,
        int $sheetId,
        float $areaUsed,
        int $userId,
        ?string $componentCode = null
    ): int {
        // Get job info from token
        $token = $this->getTokenWithJob($tokenId);
        
        $this->db->begin_transaction();
        
        try {
            // 1. Get sheet info
            $sheet = $this->getSheet($sheetId);
            
            // 2. Create issue record
            $stmt = $this->db->prepare(
                "INSERT INTO material_issue 
                 (job_id, job_type, material_sku, sheet_id, component_code,
                  token_id, qty_issued, issued_by, issue_type)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'cut_station')"
            );
            $stmt->bind_param('issisidi', 
                $token['job_id'], $token['job_type'], $sheet['material_sku'],
                $sheetId, $componentCode, $tokenId, $areaUsed, $userId
            );
            $stmt->execute();
            $issueId = $stmt->insert_id;
            $stmt->close();
            
            // 3. Update sheet remaining area
            $this->updateSheetArea($sheetId, $areaUsed);
            
            // 4. Update reservation
            $this->updateReservationIssued(
                $token['job_id'], $token['job_type'], 
                $sheet['material_sku'], $areaUsed
            );
            
            // 5. Link sheet to token (leather_sheet_usage_log)
            $this->logSheetUsage($sheetId, $tokenId, $areaUsed, $userId);
            
            $this->db->commit();
            return $issueId;
            
        } catch (\Exception $e) {
            $this->db->rollback();
            throw $e;
        }
    }
    
    /**
     * Update reservation's issued quantity
     */
    private function updateReservationIssued(
        int $jobId, 
        string $jobType, 
        string $materialSku, 
        float $qty
    ): void {
        $stmt = $this->db->prepare(
            "UPDATE material_reservation 
             SET qty_issued = qty_issued + ?,
                 status = CASE 
                    WHEN qty_issued + ? >= qty_reserved THEN 'fulfilled'
                    ELSE 'partial'
                 END
             WHERE job_id = ? AND job_type = ? AND material_sku = ?
               AND status IN ('active', 'partial')"
        );
        $stmt->bind_param('ddiss', $qty, $qty, $jobId, $jobType, $materialSku);
        $stmt->execute();
        $stmt->close();
    }
}
```

---

## 🖥️ UI Integration

### Job Creation Page

```
┌─────────────────────────────────────────────────────────────────┐
│  CREATE JOB                                                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Product: [Classic Tote Bag ▼]                                  │
│  Quantity: [10] ← พิมพ์เลข → คำนวณ requirement ทันที             │
│                                                                 │
│  ─────────────────────────────────────────────────────────────  │
│  📦 Material Requirements (Preview)                              │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Material            Need    Avail   Status                  ││
│  │ ─────────────────────────────────────────────────────────── ││
│  │ Leather-Goat-Black  14.3    32.0    ✅ Sufficient           ││
│  │ Canvas-Lining        3.3    50.0    ✅ Sufficient           ││
│  │ Zipper-Gold-20cm    10.0     8.0    ❌ Insufficient (-2)    ││
│  │ D-Ring-Brass        20.0    25.0    ⚠️ Tight (5 left)       ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  ⚠️ Cannot confirm: Zipper-Gold-20cm is insufficient           │
│                                                                 │
│  [Save Draft]  [Confirm Job] ← Disabled if insufficient        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Status Colors

| Status | Color | Meaning |
|--------|-------|---------|
| `sufficient` | ✅ Green | Available >= Need + Scrap |
| `tight` | ⚠️ Yellow | Available >= Need but < Need + Scrap |
| `partial` | 🟠 Orange | Some available but not enough |
| `insufficient` | ❌ Red | Available <= 0 or < minimum |

---

## 🔄 Lifecycle Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        JOB LIFECYCLE                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [Draft]                                                        │
│     │                                                           │
│     │ MaterialRequirementService.calculateRequirements()        │
│     │ → Show preview (NO stock change)                          │
│     ▼                                                           │
│  [Confirm] ─────────────────────────────────────────────────────│
│     │                                                           │
│     │ MaterialReservationService.reserveForJob()                │
│     │ → Create reservations                                     │
│     │ → Block available_to_promise                              │
│     ▼                                                           │
│  [In Progress] ─────────────────────────────────────────────────│
│     │                                                           │
│     │ MaterialConsumptionService.issueFromWarehouse()           │
│     │ MaterialConsumptionService.issueLeatherSheet()            │
│     │ → Create issue records                                    │
│     │ → Decrease on_hand                                        │
│     │ → Update reservation (partial → fulfilled)                │
│     ▼                                                           │
│  [Complete] ────────────────────────────────────────────────────│
│     │                                                           │
│     │ Any remaining reservation → auto-release                  │
│     ▼                                                           │
│  [Done]                                                         │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                        CANCEL FLOW                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [Any State] ──→ [Cancel]                                       │
│     │                                                           │
│     │ MaterialReservationService.releaseForJob()                │
│     │ → Release all active reservations                         │
│     │ → Restore available_to_promise                            │
│     ▼                                                           │
│  [Cancelled]                                                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🚨 Policy Configuration

### Strict Mode (Recommended for Leather)

```php
// config/material_policy.php

return [
    'leather' => [
        'allow_negative_available' => false,
        'require_reservation' => true,
        'require_lot_tracking' => true,
        'scrap_allowance' => 0.10, // 10%
        'min_safety_stock' => 5.0, // sqft
        'warn_if_last_sheet' => true
    ],
    'hardware' => [
        'allow_negative_available' => false,
        'require_reservation' => true,
        'require_lot_tracking' => false,
        'scrap_allowance' => 0.05, // 5%
        'min_safety_stock' => 10, // pieces
        'warn_if_below_reorder' => true
    ],
    'consumable' => [
        'allow_negative_available' => true, // Can go negative, warning only
        'require_reservation' => false,
        'require_lot_tracking' => false,
        'scrap_allowance' => 0.20, // 20% for thread/glue
        'track_per_job' => false // Track as overhead cost
    ]
];
```

---

## 📝 Implementation Tasks

### New Task: 27.18 Material Requirement & Reservation

**Duration:** 16 hours

| Sub-task | Hours | Description |
|----------|-------|-------------|
| 27.18.1 | 2 | Database: `material_reservation`, `material_issue` tables |
| 27.18.2 | 4 | Service: `MaterialRequirementService` |
| 27.18.3 | 4 | Service: `MaterialReservationService` |
| 27.18.4 | 4 | Service: `MaterialConsumptionService` (extend existing) |
| 27.18.5 | 2 | API: Requirement endpoints |
| 27.18.6 | 2 | UI: Job creation preview |
| 27.18.7 | 2 | Integration with CUT behavior |
| 27.18.8 | 2 | Tests |

---

## 🔗 Related Documents

- `task27.13_COMPONENT_NODE_PLAN.md` - Component → Material mapping
- `COMPONENT_CATALOG_SPEC.md` - Component catalog structure
- `ComponentAllocationService.php` - Existing sheet allocation (to integrate)
- `materials.php` - Existing materials API

---

## ✅ Definition of Done

- [ ] `material_reservation` table created
- [ ] `material_issue` table created
- [ ] `MaterialRequirementService` calculates requirements correctly
- [ ] `MaterialReservationService` creates/releases reservations
- [ ] `MaterialConsumptionService` issues and decreases stock
- [ ] Job creation UI shows requirement preview
- [ ] Confirm Job blocked if insufficient materials
- [ ] Cancel Job releases reservations
- [ ] CUT behavior issues leather via service
- [ ] Tests cover: confirm, cancel, issue, overbooking prevention


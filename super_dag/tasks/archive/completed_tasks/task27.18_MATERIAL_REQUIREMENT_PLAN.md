# Task 27.18 - Material Requirement & Reservation

> **Purpose:** Calculate material requirements from BOM and manage stock reservations  
> **Priority:** 🟠 HIGH - Inventory Integration  
> **Estimated Time:** 45-55 hours (~6-7 days)  
> **Dependencies:** Task 27.13.11b Material Architecture V2 ✅  
> **Status:** 📋 PLANNING

---

## 📋 Executive Summary

```
┌─────────────────────────────────────────────────────────────────┐
│           MATERIAL REQUIREMENT & RESERVATION SYSTEM             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  INPUT (What we have):                                          │
│  ├─ product_component (physical specs per product)              │
│  ├─ product_component_material (BOM - qty per component)        │
│  ├─ material / stock_item (inventory)                           │
│  ├─ material_lot / stock_item_lot (lot tracking)                │
│  └─ Job Ticket with target_qty                                  │
│                                                                 │
│  OUTPUT (What we need):                                         │
│  ├─ Total material requirements for job                         │
│  ├─ Stock availability check                                    │
│  ├─ Reservations (soft lock on inventory)                       │
│  ├─ Allocations (hard link token → material)                    │
│  └─ Shortage warnings                                           │
│                                                                 │
│  FLOW:                                                          │
│  Job Created → Calculate Requirements → Check Stock             │
│       → Reserve Materials → Token Started → Allocate            │
│       → Token Completed → Consume/Release                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Objectives

### 1. Material Requirement Calculation
- Calculate total material needed based on `product_component_material` BOM
- Support job target quantity multiplier
- Handle component quantity variations
- Consider yield/waste factors

### 2. Stock Availability Check
- Check if sufficient stock exists before job creation
- Support multiple material sources (lots, locations)
- Provide shortage warnings with details
- Consider reserved quantities

### 3. Material Reservation
- Soft-lock materials when job is created
- Prevent over-commitment of inventory
- Support partial reservations
- Allow manual override with approval

### 4. Material Allocation
- Hard-link materials to specific tokens
- Track which token uses which material lot
- Support FIFO/FEFO allocation strategies
- Enable full traceability

### 5. Consumption & Release
- Consume materials when token completes
- Release reservations on job cancellation
- Handle rework scenarios (re-reserve)
- Track actual vs planned usage

---

## 🗃️ Database Design

### New Tables

```sql
-- ═══════════════════════════════════════════════════════════════
-- 1. material_requirement - Calculated requirements per job
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE material_requirement (
    id_requirement INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Job Reference
    id_job_ticket INT NOT NULL COMMENT 'FK to job_ticket',
    id_instance INT NULL COMMENT 'FK to job_graph_instance (if spawned)',
    
    -- Material Reference
    material_sku VARCHAR(100) NOT NULL COMMENT 'FK to material.sku',
    
    -- Source (which component needs this)
    id_product_component INT NULL COMMENT 'FK to product_component (Layer 2)',
    component_type_code VARCHAR(50) NULL COMMENT 'Component type (Layer 1)',
    
    -- Quantities
    qty_per_unit DECIMAL(10,4) NOT NULL COMMENT 'Qty required per product unit',
    qty_total_required DECIMAL(10,4) NOT NULL COMMENT 'Total = qty_per_unit × target_qty',
    qty_reserved DECIMAL(10,4) DEFAULT 0 COMMENT 'Currently reserved',
    qty_allocated DECIMAL(10,4) DEFAULT 0 COMMENT 'Allocated to tokens',
    qty_consumed DECIMAL(10,4) DEFAULT 0 COMMENT 'Actually consumed',
    
    -- UOM
    uom_code VARCHAR(20) NOT NULL COMMENT 'Unit of measure',
    
    -- Status
    status ENUM('pending', 'reserved', 'partial', 'allocated', 'consumed', 'shortage', 'cancelled')
        DEFAULT 'pending' COMMENT 'Requirement status',
    
    -- Shortage Info
    shortage_qty DECIMAL(10,4) NULL COMMENT 'Shortage amount if insufficient',
    shortage_notified_at DATETIME NULL COMMENT 'When shortage was notified',
    
    -- Metadata
    calculated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_job (id_job_ticket),
    INDEX idx_instance (id_instance),
    INDEX idx_material (material_sku),
    INDEX idx_status (status),
    INDEX idx_component (id_product_component)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Material requirements calculated from BOM - Task 27.18';

-- ═══════════════════════════════════════════════════════════════
-- 2. material_reservation - Soft-lock on inventory
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE material_reservation (
    id_reservation INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Requirement Reference
    id_requirement INT NOT NULL COMMENT 'FK to material_requirement',
    
    -- Material Source
    material_sku VARCHAR(100) NOT NULL COMMENT 'FK to material.sku',
    id_lot INT NULL COMMENT 'FK to material_lot (if lot-specific)',
    id_warehouse INT NULL COMMENT 'FK to warehouse',
    id_location INT NULL COMMENT 'FK to warehouse_location',
    
    -- Quantity
    qty_reserved DECIMAL(10,4) NOT NULL COMMENT 'Reserved quantity',
    uom_code VARCHAR(20) NOT NULL,
    
    -- Status
    status ENUM('active', 'allocated', 'released', 'expired', 'cancelled')
        DEFAULT 'active' COMMENT 'Reservation status',
    
    -- Timing
    reserved_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NULL COMMENT 'Auto-release after this time',
    released_at DATETIME NULL,
    
    -- Audit
    reserved_by INT NOT NULL COMMENT 'User who created reservation',
    released_by INT NULL COMMENT 'User who released reservation',
    release_reason VARCHAR(100) NULL,
    
    INDEX idx_requirement (id_requirement),
    INDEX idx_material (material_sku),
    INDEX idx_lot (id_lot),
    INDEX idx_status (status),
    INDEX idx_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Material reservations (soft-lock) - Task 27.18';

-- ═══════════════════════════════════════════════════════════════
-- 3. material_allocation - Hard-link token → material
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE material_allocation (
    id_allocation INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Token Reference
    id_token INT NOT NULL COMMENT 'FK to flow_token',
    id_requirement INT NOT NULL COMMENT 'FK to material_requirement',
    
    -- Material Source
    material_sku VARCHAR(100) NOT NULL COMMENT 'FK to material.sku',
    id_lot INT NULL COMMENT 'FK to material_lot',
    id_sheet INT NULL COMMENT 'FK to leather_sheet (for leather)',
    
    -- Quantity
    qty_allocated DECIMAL(10,4) NOT NULL COMMENT 'Quantity allocated',
    qty_consumed DECIMAL(10,4) DEFAULT 0 COMMENT 'Quantity actually used',
    uom_code VARCHAR(20) NOT NULL,
    
    -- Status
    status ENUM('allocated', 'in_use', 'consumed', 'returned', 'wasted')
        DEFAULT 'allocated' COMMENT 'Allocation status',
    
    -- Waste Tracking
    waste_qty DECIMAL(10,4) DEFAULT 0 COMMENT 'Waste amount',
    waste_reason VARCHAR(100) NULL,
    
    -- Timing
    allocated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    consumed_at DATETIME NULL,
    
    -- Audit
    allocated_by INT NOT NULL,
    consumed_by INT NULL,
    
    INDEX idx_token (id_token),
    INDEX idx_requirement (id_requirement),
    INDEX idx_material (material_sku),
    INDEX idx_lot (id_lot),
    INDEX idx_sheet (id_sheet),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Token-to-material allocation (hard-link) - Task 27.18';

-- ═══════════════════════════════════════════════════════════════
-- 4. material_requirement_log - Audit trail
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE material_requirement_log (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    
    id_job_ticket INT NOT NULL,
    id_requirement INT NULL,
    id_reservation INT NULL,
    id_allocation INT NULL,
    
    event_type ENUM(
        'requirement_calculated',
        'stock_checked',
        'shortage_detected',
        'reservation_created',
        'reservation_released',
        'reservation_expired',
        'allocation_created',
        'material_consumed',
        'material_returned',
        'waste_recorded'
    ) NOT NULL,
    
    material_sku VARCHAR(100) NULL,
    qty DECIMAL(10,4) NULL,
    details JSON NULL COMMENT 'Additional event details',
    
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_by INT NULL,
    
    INDEX idx_job (id_job_ticket),
    INDEX idx_event (event_type),
    INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Material requirement audit log - Task 27.18';
```

### Views for Reporting

```sql
-- Available stock considering reservations
CREATE VIEW v_material_available AS
SELECT 
    m.sku,
    m.name_th,
    m.name_en,
    COALESCE(ml.total_qty, 0) AS total_qty,
    COALESCE(mr.reserved_qty, 0) AS reserved_qty,
    COALESCE(ml.total_qty, 0) - COALESCE(mr.reserved_qty, 0) AS available_qty,
    m.default_uom_code AS uom_code
FROM material m
LEFT JOIN (
    SELECT id_material, SUM(quantity) AS total_qty
    FROM material_lot 
    WHERE status = 'available'
    GROUP BY id_material
) ml ON ml.id_material = m.id_material
LEFT JOIN (
    SELECT material_sku, SUM(qty_reserved) AS reserved_qty
    FROM material_reservation 
    WHERE status = 'active'
    GROUP BY material_sku
) mr ON mr.material_sku = m.sku;

-- Job material status summary
CREATE VIEW v_job_material_status AS
SELECT 
    mr.id_job_ticket,
    jt.job_code,
    COUNT(DISTINCT mr.material_sku) AS total_materials,
    SUM(CASE WHEN mr.status = 'consumed' THEN 1 ELSE 0 END) AS consumed_count,
    SUM(CASE WHEN mr.status = 'shortage' THEN 1 ELSE 0 END) AS shortage_count,
    SUM(CASE WHEN mr.status IN ('reserved', 'allocated') THEN 1 ELSE 0 END) AS ready_count,
    CASE 
        WHEN SUM(CASE WHEN mr.status = 'shortage' THEN 1 ELSE 0 END) > 0 THEN 'shortage'
        WHEN SUM(CASE WHEN mr.status IN ('pending') THEN 1 ELSE 0 END) > 0 THEN 'pending'
        WHEN SUM(CASE WHEN mr.status IN ('reserved', 'allocated') THEN 1 ELSE 0 END) = COUNT(*) THEN 'ready'
        ELSE 'partial'
    END AS overall_status
FROM material_requirement mr
JOIN job_ticket jt ON jt.id_job_ticket = mr.id_job_ticket
GROUP BY mr.id_job_ticket, jt.job_code;
```

---

## 🔧 Service Architecture

### 1. MaterialRequirementService

```php
namespace BGERP\Service;

class MaterialRequirementService
{
    // ═══════════════════════════════════════════════════════════
    // CALCULATION
    // ═══════════════════════════════════════════════════════════
    
    /**
     * Calculate material requirements for a job
     * Uses product_component_material BOM
     */
    public function calculateRequirements(int $jobTicketId): array
    {
        // 1. Get job details (product_id, target_qty)
        // 2. Get product components (Layer 2)
        // 3. For each component, get materials (Layer 3)
        // 4. Multiply by target_qty
        // 5. Insert into material_requirement table
        // 6. Return summary
    }
    
    /**
     * Get requirements for a job
     */
    public function getRequirements(int $jobTicketId): array;
    
    /**
     * Recalculate requirements (if target_qty changed)
     */
    public function recalculateRequirements(int $jobTicketId): array;
    
    // ═══════════════════════════════════════════════════════════
    // AVAILABILITY
    // ═══════════════════════════════════════════════════════════
    
    /**
     * Check stock availability for requirements
     */
    public function checkAvailability(int $jobTicketId): array
    {
        // Returns: [
        //   'all_available' => bool,
        //   'shortages' => [...],
        //   'materials' => [sku => ['required' => x, 'available' => y, 'shortage' => z]]
        // ]
    }
    
    /**
     * Get available stock for a material (considering reservations)
     */
    public function getAvailableStock(string $materialSku): array;
    
    // ═══════════════════════════════════════════════════════════
    // SHORTAGE
    // ═══════════════════════════════════════════════════════════
    
    /**
     * Get jobs with material shortages
     */
    public function getJobsWithShortages(): array;
    
    /**
     * Notify about shortage
     */
    public function notifyShortage(int $requirementId): bool;
}
```

### 2. MaterialReservationService

```php
namespace BGERP\Service;

class MaterialReservationService
{
    // ═══════════════════════════════════════════════════════════
    // RESERVATION
    // ═══════════════════════════════════════════════════════════
    
    /**
     * Reserve materials for job (soft-lock)
     * Called when job status changes to 'confirmed' or 'in_progress'
     */
    public function reserveMaterials(int $jobTicketId, int $userId): array
    {
        // 1. Get requirements
        // 2. For each requirement, find available stock
        // 3. Create reservation records (FIFO/FEFO)
        // 4. Update requirement status
        // 5. Log event
        // 6. Return result
    }
    
    /**
     * Release reservations for job
     * Called when job is cancelled or completed
     */
    public function releaseReservations(int $jobTicketId, int $userId, string $reason): array;
    
    /**
     * Release expired reservations (cron job)
     */
    public function releaseExpiredReservations(): int;
    
    /**
     * Get reservations for a job
     */
    public function getReservations(int $jobTicketId): array;
    
    /**
     * Transfer reservation to another job
     */
    public function transferReservation(int $reservationId, int $toJobTicketId, int $userId): bool;
    
    // ═══════════════════════════════════════════════════════════
    // ALLOCATION STRATEGY
    // ═══════════════════════════════════════════════════════════
    
    /**
     * Find best lots to reserve (FIFO/FEFO/LIFO)
     */
    private function findLotsToReserve(
        string $materialSku, 
        float $qtyNeeded, 
        string $strategy = 'FIFO'
    ): array;
}
```

### 3. MaterialAllocationService

```php
namespace BGERP\Service;

class MaterialAllocationService
{
    // ═══════════════════════════════════════════════════════════
    // ALLOCATION
    // ═══════════════════════════════════════════════════════════
    
    /**
     * Allocate materials to token (hard-link)
     * Called when token enters CUT or material-consuming node
     */
    public function allocateToToken(int $tokenId, int $userId): array
    {
        // 1. Get token's job and component
        // 2. Find matching requirements
        // 3. Convert reservations to allocations
        // 4. Update allocation status
        // 5. Log event
    }
    
    /**
     * Get allocations for a token
     */
    public function getTokenAllocations(int $tokenId): array;
    
    /**
     * Record material consumption
     * Called when token completes operation
     */
    public function consumeMaterial(
        int $allocationId, 
        float $qtyConsumed, 
        int $userId,
        ?float $wasteQty = null,
        ?string $wasteReason = null
    ): bool;
    
    /**
     * Return unused material
     * Called when token is scrapped or job cancelled
     */
    public function returnMaterial(int $allocationId, float $qtyReturned, int $userId): bool;
    
    // ═══════════════════════════════════════════════════════════
    // LEATHER SPECIFIC
    // ═══════════════════════════════════════════════════════════
    
    /**
     * Allocate leather sheet to token
     * Special handling for leather area tracking
     */
    public function allocateLeatherSheet(
        int $tokenId, 
        int $sheetId, 
        float $areaSqft, 
        int $userId
    ): array;
}
```

---

## 🌐 API Endpoints

### material_requirement_api.php

| Action | Method | Description |
|--------|--------|-------------|
| `calculate` | POST | Calculate requirements for job |
| `get_requirements` | GET | Get requirements for job |
| `check_availability` | GET | Check stock availability |
| `reserve_materials` | POST | Create reservations |
| `release_reservations` | POST | Release reservations |
| `get_reservations` | GET | Get reservations for job |
| `allocate_to_token` | POST | Allocate to token |
| `consume_material` | POST | Record consumption |
| `return_material` | POST | Return unused material |
| `get_shortages` | GET | Get jobs with shortages |
| `get_job_material_status` | GET | Get material status for job |

### API Response Examples

```json
// GET ?action=get_requirements&job_ticket_id=123
{
  "ok": true,
  "data": {
    "job_ticket_id": 123,
    "product_id": 45,
    "product_name": "Tote Bag Classic",
    "target_qty": 10,
    "requirements": [
      {
        "id_requirement": 1,
        "material_sku": "LEA-VEG-TAN-001",
        "material_name": "Vegetable Tanned Leather",
        "component_type_code": "BODY",
        "qty_per_unit": 1.5,
        "qty_total_required": 15.0,
        "qty_reserved": 15.0,
        "qty_allocated": 5.0,
        "qty_consumed": 5.0,
        "uom_code": "SQFT",
        "status": "allocated"
      }
    ],
    "summary": {
      "total_materials": 5,
      "ready": 4,
      "shortage": 1,
      "overall_status": "partial"
    }
  }
}

// POST action=check_availability
{
  "ok": true,
  "data": {
    "all_available": false,
    "shortages": [
      {
        "material_sku": "HRD-ZIPPER-001",
        "material_name": "Premium Zipper",
        "required": 10,
        "available": 7,
        "shortage": 3,
        "uom_code": "PCS"
      }
    ]
  }
}
```

---

## 🔗 Integration Points

### 1. Job Ticket Creation
```php
// In job_ticket creation flow
if ($jobCreated) {
    // Calculate requirements
    $reqService = new MaterialRequirementService($db);
    $requirements = $reqService->calculateRequirements($jobTicketId);
    
    // Check availability and warn if shortage
    $availability = $reqService->checkAvailability($jobTicketId);
    if (!$availability['all_available']) {
        // Log warning, notify, but don't block
        $reqService->notifyShortage($jobTicketId);
    }
}
```

### 2. Job Status Change (Confirmed/In Progress)
```php
// When job status changes to confirmed or in_progress
if ($newStatus === 'confirmed' || $newStatus === 'in_progress') {
    $resService = new MaterialReservationService($db);
    $resService->reserveMaterials($jobTicketId, $userId);
}
```

### 3. Token Enters CUT Node
```php
// In BehaviorExecutionService::handleCUT()
$allocService = new MaterialAllocationService($db);
$allocService->allocateToToken($tokenId, $userId);
```

### 4. Token Completes Operation
```php
// In BehaviorExecutionService::handleComplete()
$allocService = new MaterialAllocationService($db);
foreach ($token['allocations'] as $alloc) {
    $allocService->consumeMaterial(
        $alloc['id_allocation'],
        $alloc['qty_allocated'],
        $userId
    );
}
```

### 5. Job Cancelled
```php
// In job cancellation flow
$resService = new MaterialReservationService($db);
$resService->releaseReservations($jobTicketId, $userId, 'job_cancelled');
```

---

## 🖥️ UI Components

### 1. Job Ticket - Material Tab

```
┌─────────────────────────────────────────────────────────────────┐
│  Job: JT-2025-001234 | Tote Bag Classic × 10                    │
├─────────────────────────────────────────────────────────────────┤
│  [ Details ] [ Tasks ] [ Materials ] [ Timeline ]               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  📦 Material Requirements          [Calculate] [Reserve All]    │
│  ───────────────────────────────────────────────────────────    │
│                                                                 │
│  Material               │ Component │ Required │ Reserved │ Status │
│  ─────────────────────────────────────────────────────────────────│
│  🟢 Veg-Tan Leather     │ BODY      │ 15 SQFT │ 15 SQFT │ Ready  │
│  🟢 Cotton Lining       │ LINING    │ 8 SQFT  │ 8 SQFT  │ Ready  │
│  🟡 Premium Thread      │ -         │ 200 M   │ 150 M   │ Partial│
│  🔴 Metal Clasp         │ HARDWARE  │ 10 PCS  │ 0 PCS   │ Shortage│
│                                                                 │
│  ⚠️ 1 shortage detected - ETA from supplier: Dec 15, 2025       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Material Shortage Dashboard

```
┌─────────────────────────────────────────────────────────────────┐
│  🔴 Material Shortages                        Updated: 15:30    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Material               │ Total Shortage │ Jobs Affected │ Action │
│  ─────────────────────────────────────────────────────────────────│
│  Metal Clasp (HRD-001)  │ 25 PCS        │ 5 jobs       │ [Order] │
│  Premium Zipper (ZIP-02)│ 12 PCS        │ 3 jobs       │ [Order] │
│  Edge Paint Black       │ 500 ML        │ 8 jobs       │ [Order] │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3. Token Material Allocation Card

```
┌─────────────────────────────────────────────────────────────────┐
│  Token: BEL-2025-ABC123-BODY                    Status: Active  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  📋 Allocated Materials:                                        │
│  ───────────────────────────────────────────────────────────    │
│  • Veg-Tan Leather (Lot: VTL-2025-001) - 1.5 SQFT              │
│  • Sheet: SHT-001-A23 (Area used: 1.5 / 12.5 SQFT)             │
│                                                                 │
│  [ View Details ] [ Record Waste ]                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 Implementation Tasks

### Phase 1: Database & Core Services (16-20h)

| Task | Description | Est. |
|------|-------------|------|
| 27.18.1 | Migration: Create 4 new tables + views | 3h |
| 27.18.2 | `MaterialRequirementService` - calculation logic | 5h |
| 27.18.3 | `MaterialReservationService` - reservation logic | 5h |
| 27.18.4 | `MaterialAllocationService` - allocation logic | 5h |
| 27.18.5 | Unit tests for services | 3h |

### Phase 2: API & Integration (12-15h)

| Task | Description | Est. |
|------|-------------|------|
| 27.18.6 | `material_requirement_api.php` - 11 endpoints | 5h |
| 27.18.7 | Integration with Job Ticket creation | 3h |
| 27.18.8 | Integration with Job status changes | 2h |
| 27.18.9 | Integration with Token lifecycle | 3h |
| 27.18.10 | Integration tests | 3h |

### Phase 3: UI Components (10-12h)

| Task | Description | Est. |
|------|-------------|------|
| 27.18.11 | Job Ticket - Material Tab UI | 4h |
| 27.18.12 | Material Shortage Dashboard | 3h |
| 27.18.13 | Token Material Allocation card | 2h |
| 27.18.14 | Shortage notification system | 2h |
| 27.18.15 | UI testing & polish | 2h |

### Phase 4: Advanced Features (7-10h)

| Task | Description | Est. |
|------|-------------|------|
| 27.18.16 | FIFO/FEFO allocation strategy | 3h |
| 27.18.17 | Leather sheet area tracking | 3h |
| 27.18.18 | Reservation expiry cron job | 2h |
| 27.18.19 | Actual vs planned usage report | 2h |

---

## ⚠️ Safety Guards

### 1. Idempotency
```php
// Prevent double reservation
IdempotencyService::guard($idempotencyKey, 'reserve_materials', 300);
```

### 2. Validation
```php
// Check before reserve
if ($availability['all_available'] === false && !$forceReserve) {
    throw new InsufficientStockException($availability['shortages']);
}
```

### 3. Transaction Safety
```php
$transaction = new DatabaseTransaction($db);
$transaction->execute(function($db) use ($requirements, $userId) {
    // All-or-nothing reservation
    foreach ($requirements as $req) {
        $this->createReservation($req, $userId);
    }
});
```

### 4. Feature Flag
```php
define('MATERIAL_REQUIREMENT_ENABLED', true);
define('AUTO_RESERVE_ON_JOB_CREATE', false); // Manual trigger first
```

---

## 📊 Success Metrics

| Metric | Target |
|--------|--------|
| Calculation time | < 500ms per job |
| Reservation time | < 1s per job |
| Stock accuracy | 99%+ match with physical |
| Shortage prediction | 95%+ accurate |
| Full traceability | 100% token → material link |

---

## 🔮 Future Enhancements

1. **Auto-purchase suggestion** - When shortage detected, suggest PO
2. **Material substitution** - Allow alternative materials
3. **Yield optimization** - Suggest best cutting layout for leather
4. **Cost tracking** - Track actual material cost per job
5. **Supplier integration** - Real-time stock from supplier

---

## ✅ Definition of Done

- [ ] All 4 tables created and migrated
- [ ] MaterialRequirementService calculates from BOM
- [ ] MaterialReservationService reserves with FIFO
- [ ] MaterialAllocationService links token → material
- [ ] 11 API endpoints working
- [ ] Job Ticket shows Material tab
- [ ] Shortage dashboard working
- [ ] Integration tests passing
- [ ] Full audit trail in logs
- [ ] Documentation updated

---

> **"Know your materials before you cut - measure twice, cut once"**


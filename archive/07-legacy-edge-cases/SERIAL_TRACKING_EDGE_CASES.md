# 🛡️ Serial Tracking - Edge Cases & Guardrails

**Created:** November 1, 2025  
**Status:** 📋 Comprehensive Analysis  
**Purpose:** Identify and plan for edge cases before production deployment

---

## 🎯 **Overview**

**ที่ implement แล้ว:**
- ✅ Basic serial tracking (database, UI, validation)
- ✅ Format validation (alphanumeric + dash/dot/underscore)
- ✅ Duplicate prevention (within same task)

**ที่ยังไม่ได้คิด (อันตราย!):**
- ⚠️ Serial collision across jobs
- ⚠️ Serial reuse after scrap
- ⚠️ Concurrent operations
- ⚠️ Bulk operations
- ⚠️ Print failures
- ⚠️ Date/time edge cases
- ⚠️ Multi-tenant conflicts
- ⚠️ Data archival & cleanup

**Edge Cases Found:** 15+  
**Critical:** 8  
**Priority:** Fix before pilot deployment

---

## 🔴 **Critical Edge Cases (ต้องแก้ก่อน Pilot)**

### **Edge Case 1: Serial Collision Across Jobs**

**Scenario:**
```
Job 1 (JT001): ทำ TOTE-001 (เสร็จแล้ว)
Job 2 (JT002): ใช้ TOTE-001 อีกรอบ (job ใหม่)

ปัญหา:
- Serial ซ้ำกัน (across jobs)
- ข้อมูลปนกัน (ไม่รู้ว่า log ไหนของ job ไหน)
- Query ผิด (get wrong data)
```

**Current Validation (ไม่เพียงพอ!):**
```php
// ValidationService->validateWIPLog()
// เช็คแค่ SAME TASK only!

$stmt = $db->prepare("
    SELECT COUNT(*) as cnt 
    FROM atelier_wip_log 
    WHERE id_job_task = ?        // ❌ แค่ task เดียว!
    AND serial_number = ? 
    AND deleted_at IS NULL
");
```

**Solution: Add Job-Level Validation**
```php
// เช็คว่า serial ซ้ำ across ALL active jobs หรือไม่

public static function validateSerialUnique($serialNumber, $currentJobId, $db) {
    // Check if serial exists in OTHER active jobs
    $stmt = $db->prepare("
        SELECT j.ticket_code, w.event_time
        FROM atelier_wip_log w
        JOIN atelier_job_ticket j ON j.id_job_ticket = w.id_job_ticket
        WHERE w.serial_number = ?
          AND w.deleted_at IS NULL
          AND w.id_job_ticket != ?
          AND j.status NOT IN ('completed', 'cancelled')
        LIMIT 1
    ");
    
    $stmt->bind_param('si', $serialNumber, $currentJobId);
    $stmt->execute();
    $result = $stmt->get_result()->fetch_assoc();
    
    if ($result) {
        return [
            'valid' => false,
            'error' => "Serial '{$serialNumber}' already used in job {$result['ticket_code']}"
        ];
    }
    
    return ['valid' => true];
}
```

**Impact:** 🔴 **CRITICAL** - ป้องกัน data corruption

---

### **Edge Case 2: Serial Reuse After Job Complete**

**Scenario:**
```
Job 1: TOTE-001 (completed yesterday)
Job 2: ใช้ TOTE-001 ใหม่ (วันนี้)

คำถาม:
- ใช้ได้ไหม? (job เก่าเสร็จแล้ว)
- Work history จะปนกันไหม?
- Customer scan → เห็น history ไหนรึเปล่า?
```

**Options:**

**Option A: Allow Reuse (ง่าย แต่สับสน)**
```
✅ Pros: ไม่ต้องคิด serial ใหม่
❌ Cons: 
   - History ปนกัน (TOTE-001 มี 2 jobs)
   - ลูกค้า scan → เห็น job ไหน?
   - Traceability ไม่ชัด
```

**Option B: Block Reuse (แนะนำ)**
```
✅ Pros:
   - 1 Serial = 1 Product (ชัดเจน)
   - History ไม่ปน
   - Traceability accurate

❌ Cons:
   - ต้องคิด serial ใหม่เสมอ
   - ถ้า auto-generate → ไม่มีปัญหา!
```

**Recommended: Block Reuse**
```php
public static function validateSerialNotCompleted($serialNumber, $db) {
    // Check if serial already completed
    $stmt = $db->prepare("
        SELECT j.ticket_code, w.event_time
        FROM atelier_wip_log w
        JOIN atelier_job_ticket j ON j.id_job_ticket = w.id_job_ticket
        WHERE w.serial_number = ?
          AND w.deleted_at IS NULL
          AND j.status = 'completed'
        LIMIT 1
    ");
    
    $stmt->bind_param('s', $serialNumber);
    $stmt->execute();
    $result = $stmt->get_result()->fetch_assoc();
    
    if ($result) {
        return [
            'valid' => false,
            'error' => "Serial '{$serialNumber}' already completed in job {$result['ticket_code']} (cannot reuse)"
        ];
    }
    
    return ['valid' => true];
}
```

**Impact:** 🔴 **CRITICAL** - ป้องกัน confusion

---

### **Edge Case 3: Concurrent Serial Entry**

**Scenario:**
```
Time: 14:00:00 - ช่าง A เริ่มพิมพ์ TOTE-001
Time: 14:00:05 - ช่าง B เริ่มพิมพ์ TOTE-001 (คนละเครื่อง)
Time: 14:00:10 - ช่าง A กด Save → ✅ Success
Time: 14:00:12 - ช่าง B กด Save → ❓ ซ้ำหรือเปล่า?

ปัญหา:
- Race condition (2 คนใช้ serial เดียวกันพร้อมกัน)
- ถ้าเช็คไม่ดี → duplicate ผ่านไปได้!
```

**Solution: Row Locking (Already Implemented!)**
```php
// ValidationService->validateWIPLog() uses $db parameter
// ใน DatabaseTransaction:

public function lockForUpdate($table, $where, $params) {
    $sql = "SELECT * FROM {$table} WHERE {$where} FOR UPDATE";
    // FOR UPDATE = lock row until transaction complete
}

// Usage in validation:
$transaction = new DatabaseTransaction($db);
$transaction->execute(function($db) use ($serial) {
    // 1. Lock existing serial (ถ้ามี)
    $existing = $db->query("
        SELECT serial_number 
        FROM atelier_wip_log 
        WHERE serial_number = '{$serial}'
        FOR UPDATE
    ");
    
    // 2. If exists → Error
    if ($existing && $existing->num_rows > 0) {
        throw new Exception('Serial already exists');
    }
    
    // 3. Insert new log
    // ...
});
```

**Status:** ✅ **HANDLED** (DatabaseTransaction ป้องกันแล้ว)

---

### **Edge Case 4: Serial Migration Between Jobs**

**Scenario:**
```
Job 1: TOTE-001 (50% complete) → Job cancelled!
Job 2: ต้องการใช้ TOTE-001 ต่อ (ทำงานต่อจากที่ค้างไว้)

คำถาม:
- ย้าย serial ได้ไหม?
- Work history จะตามไปด้วยไหม?
- ต้องทำอย่างไร?
```

**Solution: Serial Transfer Function**

**Database:**
```sql
CREATE TABLE serial_transfer_log (
    id INT PRIMARY KEY AUTO_INCREMENT,
    serial_number VARCHAR(100),
    from_job_ticket INT,
    to_job_ticket INT,
    reason VARCHAR(100),            -- 'job_cancelled', 'job_split', 'wip_reuse'
    transferred_by INT,
    transferred_at DATETIME,
    notes TEXT,
    
    INDEX idx_serial (serial_number),
    FOREIGN KEY (from_job_ticket) REFERENCES atelier_job_ticket(id_job_ticket),
    FOREIGN KEY (to_job_ticket) REFERENCES atelier_job_ticket(id_job_ticket)
);
```

**API:**
```php
case 'transfer_serial':
    $serial = $_POST['serial_number'];
    $fromJob = (int)$_POST['from_job'];
    $toJob = (int)$_POST['to_job'];
    $reason = $_POST['reason'];
    
    // Validate both jobs exist
    // Validate from_job not completed
    // Validate serial exists in from_job
    
    // Transfer all logs
    $stmt = $db->prepare("
        UPDATE atelier_wip_log 
        SET id_job_ticket = ?
        WHERE serial_number = ?
          AND id_job_ticket = ?
          AND deleted_at IS NULL
    ");
    $stmt->bind_param('isi', $toJob, $serial, $fromJob);
    $stmt->execute();
    
    // Log transfer
    $stmt2 = $db->prepare("
        INSERT INTO serial_transfer_log 
        (serial_number, from_job_ticket, to_job_ticket, reason, transferred_by)
        VALUES (?, ?, ?, ?, ?)
    ");
    $stmt2->bind_param('siisi', $serial, $fromJob, $toJob, $reason, $userId);
    $stmt2->execute();
    
    json_success(['transferred' => 1]);
```

**Impact:** 🟡 **IMPORTANT** - สำหรับ WIP reuse

---

### **Edge Case 5: Bulk Serial Delete**

**Scenario:**
```
Job cancelled → ต้องลบ serial ทั้งหมด (100 serials)

ปัญหา:
- Delete ทีละตัว? (ช้า!)
- ถ้า error ตัวที่ 50? (rollback?)
- Session rebuild ทุกตัว? (ช้ามาก!)
```

**Solution: Bulk Soft-Delete with Single Session Rebuild**

```php
case 'bulk_delete_serials':
    $jobId = (int)$_POST['id_job_ticket'];
    $serials = $_POST['serials']; // Array
    
    if (empty($serials) || count($serials) > 100) {
        json_error('Invalid serials count (max 100)', 400);
    }
    
    $transaction = new DatabaseTransaction($db);
    
    try {
        $transaction->execute(function($db) use ($serials, $userId) {
            // Bulk soft-delete
            $placeholders = implode(',', array_fill(0, count($serials), '?'));
            $types = str_repeat('s', count($serials)) . 'i';
            $params = array_merge($serials, [$userId]);
            
            $stmt = $db->prepare("
                UPDATE atelier_wip_log 
                SET deleted_at = NOW(), deleted_by = ?
                WHERE serial_number IN ({$placeholders})
                  AND deleted_at IS NULL
            ");
            $stmt->bind_param($types, ...$params);
            $stmt->execute();
            
            return $stmt->affected_rows;
        });
        
        // Rebuild sessions ONCE (for all affected tasks)
        $affectedTasks = getAffectedTasks($db, $serials);
        foreach ($affectedTasks as $taskId) {
            $sessionService->rebuildSessionsFromLogs($taskId);
        }
        
        json_success(['deleted' => count($serials)]);
        
    } catch (Exception $e) {
        json_error($e->getMessage(), 500);
    }
```

**Impact:** 🟡 **IMPORTANT** - Performance optimization

---

### **Edge Case 6: QR Print Queue Failure**

**Scenario:**
```
Generate 100 serials → Print QR stickers
Printer jam ที่ sticker ที่ 50!

ปัญหา:
- Serials 51-100 ไม่มี sticker
- ทำงานไม่ได้ (ไม่มี QR scan)
- Reprint ทั้งหมดหรือแค่ 51-100?
```

**Solution: Print Queue Tracking**

**Database:**
```sql
CREATE TABLE serial_print_queue (
    id INT PRIMARY KEY AUTO_INCREMENT,
    job_ticket_id INT,
    serial_number VARCHAR(100),
    print_status ENUM('pending', 'printed', 'failed'),
    print_batch_id VARCHAR(50),     -- Group prints together
    printed_at DATETIME NULL,
    printer_id VARCHAR(50),
    error_message TEXT NULL,
    retry_count INT DEFAULT 0,
    
    INDEX idx_batch (print_batch_id),
    INDEX idx_status (print_status)
);

-- Queue all serials when job created
INSERT INTO serial_print_queue 
(job_ticket_id, serial_number, print_status, print_batch_id)
SELECT 10, serial_number, 'pending', 'BATCH-2025-11-01-001'
FROM (
    SELECT CONCAT('TOTE-', LPAD(seq, 3, '0')) as serial_number
    FROM (SELECT @row := @row + 1 as seq FROM 
          (SELECT 1 UNION SELECT 2 UNION ...) t1,
          (SELECT @row := 0) t2
          LIMIT 100) numbers
) serials;

-- After print success/failure
UPDATE serial_print_queue 
SET print_status = 'printed',
    printed_at = NOW(),
    printer_id = 'PRINTER-01'
WHERE print_batch_id = 'BATCH-2025-11-01-001'
  AND serial_number BETWEEN 'TOTE-001' AND 'TOTE-050';

-- Reprint only failed ones
SELECT serial_number 
FROM serial_print_queue 
WHERE print_batch_id = 'BATCH-2025-11-01-001'
  AND print_status = 'failed'
ORDER BY serial_number;
```

**UI: Print Status Monitor**
```
┌────────────────────────────────┐
│  Print Queue: BATCH-001        │
│                                │
│  ✅ Printed: 50/100 (50%)      │
│  ⏳ Pending: 0                 │
│  ❌ Failed: 50                 │
│                                │
│  Failed Serials:               │
│  TOTE-051 to TOTE-100          │
│                                │
│  [Retry Failed] [Download PDF] │
└────────────────────────────────┘
```

**Impact:** 🔴 **CRITICAL** - ป้องกัน production halt

---

### **Edge Case 7: Date/Year Rollover**

**Scenario:**
```
Dec 31, 2025, 23:59:00 - Generate: TOTE-2025-999
Dec 31, 2025, 23:59:30 - Generate: TOTE-2025-1000
Jan 1, 2026, 00:00:10 - Generate: TOTE-2026-001

ปัญหา:
- ปีเปลี่ยน → format เปลี่ยน
- Sequence reset หรือเปล่า?
- ถ้า collision?
```

**Solution: Smart Serial Generation**

```php
function generateSerial($sku, $db, $format = '{SKU}-{YEAR}-{SEQ}') {
    $year = date('Y');
    $prefix = str_replace(
        ['{SKU}', '{YEAR}'],
        [$sku, $year],
        $format
    );
    
    // Find last serial in CURRENT YEAR
    $stmt = $db->prepare("
        SELECT serial_number 
        FROM atelier_wip_log 
        WHERE serial_number LIKE ?
          AND YEAR(event_time) = ?
        ORDER BY serial_number DESC 
        LIMIT 1
    ");
    
    $pattern = $prefix . '%';
    $stmt->bind_param('si', $pattern, $year);
    $stmt->execute();
    $result = $stmt->get_result()->fetch_assoc();
    
    if ($result) {
        // Extract sequence
        $lastSerial = $result['serial_number'];
        $seq = (int)str_replace($prefix, '', $lastSerial);
        $nextSeq = $seq + 1;
    } else {
        // First serial of the year
        $nextSeq = 1;
    }
    
    // Format with padding
    $seqStr = str_pad($nextSeq, 3, '0', STR_PAD_LEFT);
    
    return $prefix . $seqStr;
}

// ตัวอย่าง:
// 2025: TOTE-2025-001, TOTE-2025-002, ...
// 2026: TOTE-2026-001 (reset sequence)
```

**Impact:** 🟡 **IMPORTANT** - Long-term system stability

---

### **Edge Case 8: Multi-Tenant Serial Collision**

**Scenario:**
```
Tenant A: ใช้ TOTE-001
Tenant B: ใช้ TOTE-001

ปัญหา:
- Serial ซ้ำกัน (across tenants)
- ถ้า merge data? (ปนกัน)
- Customer scan → ได้ข้อมูลผิด tenant?
```

**Current Status:**
```
✅ SAFE - Tenant isolation ทำงานอยู่แล้ว!

Database separation:
- Tenant A: bgerp_t_maison_atelier
- Tenant B: bgerp_t_bellavier_factory

Serial TOTE-001 in Tenant A ≠ TOTE-001 in Tenant B
→ ไม่มีปัญหา!
```

**But... for customer-facing portal:**
```
ถ้าลูกค้า scan TOTE-001:
- ต้องรู้ว่าเป็น tenant ไหน
- ต้องเพิ่ม tenant prefix!

Solution: ใช้ format {TENANT}-{SKU}-{SEQ}
- Tenant A: MA-TOTE-001 (Maison Atelier)
- Tenant B: BF-TOTE-001 (Bellavier Factory)
```

**Impact:** 🟡 **IMPORTANT** - สำหรับ customer portal (future)

---

## 🟡 **Important Edge Cases (ควรแก้)**

### **Edge Case 9: Serial Format Migration**

**Scenario:**
```
เดือน 1: ใช้ format "TOTE-001" (3 digits)
เดือน 6: production เพิ่ม → ทำ 1000+ ชิ้น
         TOTE-999 → TOTE-1000 (4 digits!)

ปัญหา:
- Format ไม่ consistent
- Sort order ผิด (TOTE-1000 < TOTE-999 ถ้า sort string)
```

**Solution: Fixed-Length Sequence**

```php
// ใช้ 4-5 digits เสมอ (support up to 9,999 or 99,999)
function generateSerial($sku) {
    // ...
    $seqStr = str_pad($nextSeq, 4, '0', STR_PAD_LEFT);
    // TOTE-0001, TOTE-0002, ..., TOTE-1000, TOTE-9999
}
```

**Impact:** 🟡 **IMPORTANT** - Scalability

---

### **Edge Case 10: Serial Search Performance**

**Scenario:**
```
มี serial 100,000+ serials
ลูกค้า search: "TOTE-001"

ปัญหา:
- Query ช้า (no index on serial_number ที่ right side)
- LIKE '%TOTE-001%' → full table scan!
```

**Current Status:**
```
✅ SAFE - มี index แล้ว!

Migration 0005:
- idx_serial (serial_number)           → fast exact match
- idx_task_serial (task, serial, ...)  → fast task queries

Query:
WHERE serial_number = 'TOTE-001'  → ✅ Use index (fast)
WHERE serial_number LIKE 'TOTE%'  → ✅ Use index (fast)
WHERE serial_number LIKE '%001'   → ❌ Full scan (slow!)
```

**Optimization: Full-Text Search (if needed)**
```sql
-- For customer portal (search by partial serial)
ALTER TABLE atelier_wip_log 
ADD FULLTEXT INDEX ft_serial (serial_number);

-- Query:
SELECT * FROM atelier_wip_log 
WHERE MATCH(serial_number) AGAINST('TOTE' IN BOOLEAN MODE);
```

**Impact:** 🟢 **NICE TO HAVE** - สำหรับ customer portal

---

### **Edge Case 11: Serial Archival & Cleanup**

**Scenario:**
```
3 years later: มี serial 1,000,000+ serials
Database ใหญ่มาก (100+ GB)

คำถาม:
- Serial เก่าเก็บไว้นานแค่ไหน?
- Archive หรือ delete?
- ลูกค้า scan serial เก่า (2 ปีที่แล้ว) จะเห็นไหม?
```

**Solution: Time-Based Archival**

**Archive Strategy:**
```sql
-- Table: atelier_wip_log_archive
CREATE TABLE atelier_wip_log_archive LIKE atelier_wip_log;

-- Archive old logs (> 2 years, completed jobs)
INSERT INTO atelier_wip_log_archive
SELECT * FROM atelier_wip_log w
JOIN atelier_job_ticket j ON j.id_job_ticket = w.id_job_ticket
WHERE j.status = 'completed'
  AND j.completed_at < NOW() - INTERVAL 2 YEAR;

-- Delete from main table
DELETE FROM atelier_wip_log 
WHERE id_wip_log IN (
    SELECT id_wip_log FROM atelier_wip_log_archive
);

-- Customer query: Search BOTH tables
SELECT * FROM atelier_wip_log WHERE serial_number = ?
UNION ALL
SELECT * FROM atelier_wip_log_archive WHERE serial_number = ?;
```

**Retention Policy:**
- Active jobs: Keep forever
- Completed < 2 years: Keep in main table
- Completed > 2 years: Archive (slower query OK)
- Legal requirement: 5-7 years (Thailand law)

**Impact:** 🟢 **FUTURE** - สำหรับ long-term (3+ years)

---

### **Edge Case 12: Barcode Format Compatibility**

**Scenario:**
```
Existing system: ใช้ Code 128 barcode
New system: ใช้ QR code

ปัญหา:
- Scanner เก่าอ่าน QR ไม่ได้
- ต้องซื้อ scanner ใหม่ (ค่าใช้จ่าย!)
- Hybrid period (ใช้ทั้ง 2)?
```

**Solution: Dual Format Support**

**Sticker Design:**
```
┌─────────────────────────┐
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓       │ ← QR Code
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓       │
│                         │
│  ║│║│║│║│║│║│║│║│║│║  │ ← Code 128 Barcode
│                         │
│  TOTE-2025-001          │
└─────────────────────────┘

Payload (same for both):
- QR: {type, ticket, task, serial}
- Barcode: TOTE-2025-001 (text only)

Scanner support:
- Old scanner → Read barcode → Manual lookup
- New scanner → Read QR → Auto-populate
```

**Impact:** 🟡 **IMPORTANT** - Backward compatibility

---

### **Edge Case 13: Serial Overflow**

**Scenario:**
```
Format: TOTE-2025-999 (3 digits)
Production: ทำ 1,000 ชิ้น

ปัญหา:
- ชิ้นที่ 1,000 → TOTE-2025-1000 (4 digits!)
- Format inconsistent
- Sort order broken
```

**Solution: Detect and Warn Early**

```php
function generateSerial($sku, $db) {
    $maxSeq = 9999; // 4 digits max
    $nextSeq = getCurrentSequence($sku, $db) + 1;
    
    if ($nextSeq > $maxSeq) {
        // Overflow! Need new format
        throw new Exception(
            "Serial sequence overflow for SKU '{$sku}'. " .
            "Please use new SKU variant or contact admin."
        );
    }
    
    // Warn at 90%
    if ($nextSeq > $maxSeq * 0.9) {
        error_log("WARNING: Serial sequence for {$sku} at 90% ({$nextSeq}/{$maxSeq})");
        // Send notification to admin
    }
    
    return $sku . '-' . date('Y') . '-' . str_pad($nextSeq, 4, '0', STR_PAD_LEFT);
}
```

**Impact:** 🟡 **IMPORTANT** - Prevent future overflow

---

### **Edge Case 14: Duplicate Serial in Same Batch**

**Scenario:**
```
Generate 100 serials พร้อมกัน
เกิด bug → TOTE-001 ถูก generate 2 ครั้ง!

ปัญหา:
- 2 stickers มี serial เดียวกัน
- ทำงานปนกัน
- Data corruption
```

**Solution: Unique Constraint + Transaction**

```sql
-- ใน migration: เพิ่ม unique constraint
ALTER TABLE atelier_wip_log 
ADD CONSTRAINT unique_active_serial 
UNIQUE (serial_number, deleted_at);
-- deleted_at = NULL → ต้อง unique
-- deleted_at != NULL → can duplicate (soft-deleted)

-- NOTE: MySQL partial unique index limitation!
-- Workaround: Use trigger instead

DELIMITER $$
CREATE TRIGGER check_serial_unique BEFORE INSERT ON atelier_wip_log
FOR EACH ROW
BEGIN
    IF NEW.serial_number IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM atelier_wip_log 
            WHERE serial_number = NEW.serial_number 
              AND deleted_at IS NULL
        ) THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Serial number already exists';
        END IF;
    END IF;
END$$
DELIMITER ;
```

**Impact:** 🔴 **CRITICAL** - Data integrity

---

### **Edge Case 15: Rapid Serial Creation (Performance)**

**Scenario:**
```
10 operators สร้าง serial พร้อมกัน (concurrent)
Generate TOTE-001 to TOTE-100 ใน 10 วินาที

ปัญหา:
- Race condition (หา sequence ล่าสุด)
- Duplicate sequence
- Lock timeout
```

**Solution: Database Sequence Generator**

```sql
-- Use separate table for sequence tracking
CREATE TABLE serial_sequence (
    sku VARCHAR(100) PRIMARY KEY,
    year INT,
    last_sequence INT DEFAULT 0,
    updated_at DATETIME,
    UNIQUE KEY unique_sku_year (sku, year)
);

-- Atomic increment
function getNextSequence($sku, $year, $db) {
    $stmt = $db->prepare("
        INSERT INTO serial_sequence (sku, year, last_sequence)
        VALUES (?, ?, 1)
        ON DUPLICATE KEY UPDATE 
            last_sequence = last_sequence + 1,
            updated_at = NOW()
    ");
    $stmt->bind_param('si', $sku, $year);
    $stmt->execute();
    
    // Get incremented value
    $stmt2 = $db->prepare("
        SELECT last_sequence 
        FROM serial_sequence 
        WHERE sku = ? AND year = ?
    ");
    $stmt2->bind_param('si', $sku, $year);
    $stmt2->execute();
    $result = $stmt2->get_result()->fetch_assoc();
    
    return $result['last_sequence'];
}
```

**Impact:** 🟡 **IMPORTANT** - Concurrent performance

---

## 🟢 **Nice-to-Have Edge Cases**

### **Edge Case 16: Serial Search by Partial Match**

**Scenario:**
```
ลูกค้าจำได้แค่: "TOTE... อะไรสักอย่าง"
Search: "TOTE" → ต้องการ list ทั้งหมด
```

**Solution: Prefix Search with Pagination**

```sql
SELECT serial_number, ticket_code, job_name
FROM atelier_wip_log w
JOIN atelier_job_ticket j ON j.id_job_ticket = w.id_job_ticket
WHERE w.serial_number LIKE 'TOTE%'
  AND w.deleted_at IS NULL
GROUP BY w.serial_number
ORDER BY w.event_time DESC
LIMIT 50;
```

---

### **Edge Case 17: Serial Export/Import**

**Scenario:**
```
Export data to Excel/PDF
Import serials from external system

ปัญหา:
- Format conversion
- Encoding (UTF-8)
- Validation
```

**Solution: CSV Import/Export**

```php
// Export
case 'export_serials':
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="serials.csv"');
    
    echo "\xEF\xBB\xBF"; // UTF-8 BOM
    echo "Serial,Job,Task,Operator,Time,Notes\n";
    
    $logs = db_fetch_all($db, "SELECT ... WHERE serial_number IS NOT NULL");
    foreach ($logs as $log) {
        echo implode(',', [
            $log['serial_number'],
            $log['ticket_code'],
            $log['task_name'],
            $log['operator_name'],
            $log['event_time'],
            '"' . str_replace('"', '""', $log['notes']) . '"'
        ]) . "\n";
    }
```

---

## 📋 **Edge Case Priority Matrix**

| Edge Case | Priority | Impact | Effort | Status |
|-----------|----------|--------|--------|--------|
| 1. Serial collision across jobs | 🔴 CRITICAL | Data corruption | 1h | ❌ Not handled |
| 2. Serial reuse after complete | 🔴 CRITICAL | Confusion | 1h | ❌ Not handled |
| 3. Concurrent entry | 🔴 CRITICAL | Duplicates | 0h | ✅ Handled (Transaction) |
| 4. Serial migration | 🟡 IMPORTANT | WIP reuse | 2h | ❌ Not planned |
| 5. Bulk delete | 🟡 IMPORTANT | Performance | 1h | ❌ Not optimized |
| 6. Print queue failure | 🔴 CRITICAL | Production halt | 2h | ❌ Not handled |
| 7. Date rollover | 🟡 IMPORTANT | Long-term | 1h | ❌ Not handled |
| 8. Multi-tenant collision | 🟡 IMPORTANT | Customer portal | 1h | ✅ Safe (isolated DBs) |
| 9. Serial format migration | 🟡 IMPORTANT | Scalability | 1h | ❌ Not planned |
| 10. Search performance | 🟢 NICE | UX | 0h | ✅ OK (indexes) |
| 11. Archival | 🟢 FUTURE | Storage | 2h | ⏸️ Not needed yet |
| 12. Barcode compat | 🟡 IMPORTANT | Hardware | 1h | ❌ Not supported |
| 13. Serial overflow | 🟡 IMPORTANT | Future-proof | 30min | ❌ Not checked |
| 14. Duplicate in batch | 🔴 CRITICAL | Data integrity | 1h | ⚠️ Partial (app-level) |
| 15. Rapid creation | 🟡 IMPORTANT | Concurrency | 2h | ⚠️ Partial (locks) |

**Summary:**
- 🔴 Critical: 4 cases (3 not handled!)
- 🟡 Important: 8 cases (6 not handled!)
- 🟢 Nice-to-have: 3 cases

**Recommendation: Fix critical cases before pilot!**

---

## 🔧 **Immediate Action Items**

### **Before Pilot Deployment (Must Fix!):**

**1. Add Cross-Job Validation (1 hour)**
```php
// In ValidationService->validateWIPLog()
// Add: validateSerialUnique($serial, $jobId, $db)
```

**2. Block Serial Reuse (1 hour)**
```php
// In ValidationService->validateWIPLog()
// Add: validateSerialNotCompleted($serial, $db)
```

**3. Add Database Trigger (1 hour)**
```sql
-- Prevent duplicate serials at DB level
CREATE TRIGGER check_serial_unique BEFORE INSERT ...
```

**4. Implement Print Queue (2 hours)**
```sql
-- Create serial_print_queue table
-- Add print status tracking
-- Add reprint function
```

**Total:** 5 hours  
**Priority:** 🔴 **CRITICAL** - Must do before pilot

---

### **After Pilot Feedback (Good to Have):**

**5. Serial Migration Function (2 hours)**
- Move serials between jobs
- Preserve work history
- Log transfers

**6. Bulk Operations (1 hour)**
- Bulk delete optimization
- Bulk transfer
- Bulk reprint

**7. Date Rollover Handling (1 hour)**
- Year-based sequence reset
- Format consistency check
- Overflow detection

**8. Barcode Compatibility (1 hour)**
- Dual format support (QR + Code 128)
- Old scanner compatibility
- Hybrid period support

**Total:** 5 hours  
**Priority:** 🟡 **IMPORTANT** - Enhance UX & reliability

---

## 📊 **Comprehensive Solution Summary**

### **What We Have Now (Nov 1):**
```
✅ Basic serial tracking (60%)
✅ Validation (format only)
✅ UI (manual entry)

❌ No cross-job validation
❌ No reuse policy
❌ No print queue
❌ No error recovery
```

### **What We Need to Add:**

**Tier 1 (Critical - Before Pilot):**
- [ ] Cross-job serial validation (1h)
- [ ] Reuse blocking (1h)
- [ ] Database trigger (1h)
- [ ] Print queue system (2h)

**Tier 2 (Important - After Pilot):**
- [ ] Serial migration (2h)
- [ ] Bulk operations (1h)
- [ ] Date rollover (1h)
- [ ] Barcode compat (1h)

**Tier 3 (Future):**
- [ ] Archival strategy (2h)
- [ ] Full-text search (1h)
- [ ] Analytics dashboard (3h)

**Total Effort:**
- Tier 1: 5 hours 🔴
- Tier 2: 5 hours 🟡  
- Tier 3: 6 hours 🟢

---

## ✅ **Recommended Action**

### **ทำทันที (ก่อน Pilot):**

**Fix 4 Critical Edge Cases:**
1. ✅ Cross-job validation (ป้องกัน serial ซ้ำ across jobs)
2. ✅ Reuse blocking (ป้องกัน confusion)
3. ✅ Database trigger (data integrity)
4. ✅ Print queue (ป้องกัน production halt)

**Timeline:** 5 hours  
**Risk if skip:** 🔴 High (data corruption, production issues)

---

### **ทำหลัง Pilot (based on feedback):**

**Enhance based on real usage:**
- Serial migration (ถ้ามี WIP reuse จริง)
- Bulk operations (ถ้ามี volume สูง)
- Date rollover (ถ้า production scale)
- Barcode compat (ถ้ามี old hardware)

**Timeline:** 5 hours  
**Risk if skip:** 🟡 Medium (UX issues, inefficiency)

---

## 🎯 **Final Recommendation**

**ผมแนะนำให้:**

1. **อ่านเอกสารนี้ทั้งหมด** (30 นาที)
2. **Review กับ stakeholders** (ผู้บริหาร, production manager)
3. **ตัดสินใจ:**
   - ทำ Tier 1 ก่อน pilot? (5 ชม. - แนะนำ!)
   - หรือ deploy simple version → fix ทีหลัง?
4. **Plan timeline:**
   - ถ้าทำ Tier 1: Nov 2-3 (2 วัน)
   - Pilot: Nov 12 (Week 2)

---

**Updated:** November 1, 2025  
**Total Edge Cases Identified:** 17  
**Critical (Must Fix):** 4  
**Important (Should Fix):** 8  
**Nice-to-Have:** 5

---

**Built with ❤️ for Bellavier Group**  
**Quality First - Production Ready**


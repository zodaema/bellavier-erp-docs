# 🔐 Serial Tracking - Security Requirements

**Created:** November 1, 2025  
**Status:** 📋 Critical Security Analysis  
**Priority:** 🔴 Must implement before production

---

## 🎯 **Security Principles**

### **1. Serial Must Be Unpredictable (คาดเดาไม่ได้)**

**❌ Insecure (Predictable):**
```
TOTE-001
TOTE-002
TOTE-003
...

Risks:
- Competitor รู้ production volume (001-999 = 999 ชิ้น)
- ทำปลอมได้ง่าย (สร้าง TOTE-1000, TOTE-1001)
- Business intelligence leak
```

**✅ Secure (Unpredictable):**
```
TOTE-2025-A7F3C9
TOTE-2025-B2E1D5
TOTE-2025-C9F2A8

Benefits:
- ไม่สามารถเดา serial ถัดไป
- ทำปลอมยาก (ต้องมี database)
- ปกป้อง business data
```

---

### **2. Use QR Code (Not Barcode)**

**Reasons:**
```
✅ Scan ผ่านมือถือได้ (ไม่ต้องซื้อ scanner)
✅ ข้อมูลมากกว่า (4KB vs 80 bytes)
✅ Error correction 30% (ทนทาน)
✅ Support JSON payload:
   {
     "serial": "TOTE-2025-A7F3C9",
     "hash": "verification_hash",
     "timestamp": 1730476800
   }
```

---

### **3. Verification Hash (Anti-Tampering)**

**Concept:**
```
QR Payload = {serial, hash}
Hash = HMAC-SHA256(serial + secret_key)

Validation:
1. Scan QR → get serial + hash
2. Calculate: expected_hash = HMAC(serial + secret)
3. Compare: hash == expected_hash?
   ✅ Match → Authentic
   ❌ Not match → Fake/Tampered
```

**Implementation:**
```php
class SerialSecurity {
    
    private const SECRET_KEY = 'bellavier_group_secret_2025'; // ในระบบจริง ใช้ env variable!
    
    /**
     * Generate QR payload with verification hash
     */
    public static function generateQRPayload($serial, $ticket, $task) {
        $data = [
            'type' => 'work_piece',
            'serial' => $serial,
            'ticket' => $ticket,
            'task' => $task,
            'timestamp' => time()
        ];
        
        // Generate verification hash
        $dataString = json_encode($data, JSON_UNESCAPED_UNICODE);
        $hash = hash_hmac('sha256', $dataString, self::SECRET_KEY);
        
        // Add hash to payload
        $data['hash'] = substr($hash, 0, 16); // First 16 chars
        
        return json_encode($data, JSON_UNESCAPED_UNICODE);
    }
    
    /**
     * Verify QR payload authenticity
     */
    public static function verifyQRPayload($payload) {
        $data = json_decode($payload, true);
        
        if (!$data || !isset($data['hash'])) {
            return ['valid' => false, 'reason' => 'invalid_payload'];
        }
        
        // Extract hash
        $providedHash = $data['hash'];
        unset($data['hash']);
        
        // Calculate expected hash
        $dataString = json_encode($data, JSON_UNESCAPED_UNICODE);
        $expectedHash = hash_hmac('sha256', $dataString, self::SECRET_KEY);
        $expectedHash = substr($expectedHash, 0, 16);
        
        // Compare
        if (!hash_equals($providedHash, $expectedHash)) {
            return ['valid' => false, 'reason' => 'hash_mismatch_tampered'];
        }
        
        // Check timestamp (not too old)
        $age = time() - ($data['timestamp'] ?? 0);
        if ($age > 86400 * 365) { // > 1 year
            return ['valid' => false, 'reason' => 'qr_expired'];
        }
        
        return [
            'valid' => true,
            'data' => $data
        ];
    }
}
```

---

### **4. Component Serial Format**

**Recommended Format:**
```
{TYPE}-{YEAR}-{HASH-6}

Examples:
- BODY-2025-A7F3C9      (ตัวกระเป๋า)
- STRAP-2025-B2E1D5     (สาย)
- HW-2025-C9F2A8        (โลหะ)
- LINING-2025-D1A4B7    (ซับใน)

Final Product:
- HANDBAG-2025-9X4K2L   (สินค้าสำเร็จ)
```

**Type Prefixes:**
| Prefix | Component | Example |
|--------|-----------|---------|
| BODY | Body/ตัวกระเป๋า | BODY-2025-A7F3C9 |
| STRAP | Strap/สาย | STRAP-2025-B2E1D5 |
| HW | Hardware/โลหะ | HW-2025-C9F2A8 |
| LINING | Lining/ซับใน | LINING-2025-D1A4B7 |
| ZIPPER | Zipper/ซิป | ZIPPER-2025-E5F8C3 |
| BUTTON | Button/กระดุม | BUTTON-2025-F6A9D2 |
| **Final Products** | | |
| TOTE | Tote bag | TOTE-2025-9X4K2L |
| WALLET | Wallet | WALLET-2025-8Y3J1K |
| HANDBAG | Handbag | HANDBAG-2025-7Z2H0M |

---

## 🛡️ **Security Layers**

### **Layer 1: Format Validation**
```php
function validateSerialFormat($serial) {
    // Must match: {PREFIX}-{YEAR}-{HASH-6}
    if (!preg_match('/^[A-Z]+-\d{4}-[A-F0-9]{6}$/', $serial)) {
        return false;
    }
    
    // Extract year
    $parts = explode('-', $serial);
    $year = (int)$parts[1];
    
    // Year must be reasonable (2025-2030)
    if ($year < 2025 || $year > 2030) {
        return false;
    }
    
    return true;
}
```

### **Layer 2: Database Existence**
```php
function validateSerialExists($serial, $db) {
    $stmt = $db->prepare("
        SELECT serial_number 
        FROM atelier_wip_log 
        WHERE serial_number = ?
          AND deleted_at IS NULL
        LIMIT 1
    ");
    $stmt->bind_param('s', $serial);
    $stmt->execute();
    $result = $stmt->get_result()->fetch_assoc();
    
    return $result !== null;
}
```

### **Layer 3: Event History Validation**
```php
function validateSerialHistory($serial, $db) {
    $stmt = $db->prepare("
        SELECT 
            COUNT(*) as event_count,
            COUNT(DISTINCT event_type) as event_types,
            MIN(event_time) as first_event,
            MAX(event_time) as last_event,
            TIMESTAMPDIFF(MINUTE, MIN(event_time), MAX(event_time)) as duration
        FROM atelier_wip_log
        WHERE serial_number = ?
          AND deleted_at IS NULL
    ");
    
    $stmt->bind_param('s', $serial);
    $stmt->execute();
    $result = $stmt->get_result()->fetch_assoc();
    
    // Validate reasonable patterns
    $checks = [
        'has_events' => $result['event_count'] >= 2,
        'has_variety' => $result['event_types'] >= 2, // start + complete at minimum
        'reasonable_duration' => $result['duration'] >= 30 && $result['duration'] <= 43200, // 30min - 30 days
    ];
    
    return [
        'valid' => !in_array(false, $checks, true),
        'checks' => $checks,
        'data' => $result
    ];
}
```

### **Layer 4: QR Hash Verification**
```php
// ใช้ SerialSecurity::verifyQRPayload() (ด้านบน)
```

---

## 📊 **Serial Format Comparison**

| Format | Example | Security | Usability | Recommend |
|--------|---------|----------|-----------|-----------|
| Sequential | TOTE-001 | ❌ Low (predictable) | ✅ Good (simple) | ❌ No |
| UUID | TOTE-a7f3c9e1-... | ✅ High | ❌ Poor (too long) | ❌ No |
| Short Hash | TOTE-A7F3C9 | ✅ High | ⚠️ OK (no context) | ⚠️ Maybe |
| **Hybrid** | **TOTE-2025-A7F3C9** | ✅ **High** | ✅ **Good** | ✅ **YES!** |

**Winner: Hybrid Format** `{SKU}-{YEAR}-{HASH-6}`

---

## 🔧 **Implementation Changes Needed**

### **Update ValidationService:**

```php
// source/service/ValidationService.php

public static function validateWIPLog($data, $task, $ticket, $db = null): array
{
    $errors = [];
    
    // ... existing validation ...
    
    // Serial validation (enhanced)
    if (!empty($data['serial_number'])) {
        $serial = trim($data['serial_number']);
        
        // 1. Format validation (existing)
        if (!self::validateSerialFormat($serial)) {
            $errors['serial_number'] = 'Invalid serial format (use: SKU-YEAR-HASH)';
        }
        
        // 2. Cross-job uniqueness (NEW!)
        if ($db) {
            $uniqueCheck = self::validateSerialUniqueGlobal($serial, $ticket['id_job_ticket'], $db);
            if (!$uniqueCheck['valid']) {
                $errors['serial_number'] = $uniqueCheck['error'];
            }
        }
        
        // 3. Not already completed (NEW!)
        if ($db) {
            $completedCheck = self::validateSerialNotCompleted($serial, $db);
            if (!$completedCheck['valid']) {
                $errors['serial_number'] = $completedCheck['error'];
            }
        }
    }
    
    return [
        'valid' => empty($errors),
        'errors' => array_values($errors)
    ];
}

/**
 * Validate serial format (secure format)
 */
private static function validateSerialFormat($serial) {
    // Format: SKU-YEAR-HASH (e.g., TOTE-2025-A7F3C9)
    if (!preg_match('/^[A-Z0-9]+-\d{4}-[A-F0-9]{6}$/', $serial)) {
        return false;
    }
    
    // Extract year
    $parts = explode('-', $serial);
    $year = (int)$parts[1];
    
    // Year must be reasonable
    if ($year < 2025 || $year > 2035) {
        return false;
    }
    
    return true;
}

/**
 * Check serial unique across ALL jobs (not just task)
 */
private static function validateSerialUniqueGlobal($serial, $currentJobId, $db) {
    $stmt = $db->prepare("
        SELECT j.ticket_code, j.status, w.event_time
        FROM atelier_wip_log w
        JOIN atelier_job_ticket j ON j.id_job_ticket = w.id_job_ticket
        WHERE w.serial_number = ?
          AND w.deleted_at IS NULL
          AND w.id_job_ticket != ?
        LIMIT 1
    ");
    
    $stmt->bind_param('si', $serial, $currentJobId);
    $stmt->execute();
    $result = $stmt->get_result()->fetch_assoc();
    
    if ($result) {
        return [
            'valid' => false,
            'error' => "Serial '{$serial}' already used in job {$result['ticket_code']} ({$result['status']})"
        ];
    }
    
    return ['valid' => true];
}

/**
 * Check serial not in completed job
 */
private static function validateSerialNotCompleted($serial, $db) {
    $stmt = $db->prepare("
        SELECT j.ticket_code, j.completed_at
        FROM atelier_wip_log w
        JOIN atelier_job_ticket j ON j.id_job_ticket = w.id_job_ticket
        WHERE w.serial_number = ?
          AND w.deleted_at IS NULL
          AND j.status = 'completed'
        LIMIT 1
    ");
    
    $stmt->bind_param('s', $serial);
    $stmt->execute();
    $result = $stmt->get_result()->fetch_assoc();
    
    if ($result) {
        return [
            'valid' => false,
            'error' => "Serial '{$serial}' already completed in job {$result['ticket_code']} (cannot reuse)"
        ];
    }
    
    return ['valid' => true];
}
```

---

## 🔒 **Customer-Facing API Security**

### **Public API for Serial Verification:**

```php
<?php
// source/public_serial_verify.php (customer portal)

session_start();
require_once __DIR__ . '/../config.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: https://bellaviergroup.com'); // Restrict origin!

$serial = $_GET['serial'] ?? '';

if (empty($serial)) {
    json_error('Missing serial number', 400);
}

// Rate limiting (prevent brute force scanning)
$ip = $_SERVER['REMOTE_ADDR'];
$cacheKey = "serial_verify_{$ip}";
$attempts = apcu_fetch($cacheKey) ?? 0;

if ($attempts > 10) { // Max 10 requests per minute
    json_error('Too many requests. Please wait.', 429);
}

apcu_store($cacheKey, $attempts + 1, 60); // Expire in 60 seconds

// Get tenant from serial prefix (if multi-tenant)
$tenantCode = extractTenantFromSerial($serial);
$db = tenant_db($tenantCode);

// Verify serial
$stmt = $db->prepare("
    SELECT 
        w.serial_number,
        j.job_name as product_name,
        j.sku,
        DATE(MIN(w.event_time)) as crafted_date,
        GROUP_CONCAT(DISTINCT w.operator_name ORDER BY w.event_time SEPARATOR ', ') as artisans,
        'authentic' as status
    FROM atelier_wip_log w
    JOIN atelier_job_ticket j ON j.id_job_ticket = w.id_job_ticket
    WHERE w.serial_number = ?
      AND w.deleted_at IS NULL
      AND j.status = 'completed'
    GROUP BY w.serial_number
");

$stmt->bind_param('s', $serial);
$stmt->execute();
$result = $stmt->get_result()->fetch_assoc();

if (!$result) {
    // Log suspicious attempt
    error_log("Serial verification failed: {$serial} from IP: {$ip}");
    
    json_error('Serial not found. This may be a counterfeit product.', 404);
}

// Return limited data (don't expose everything!)
json_success([
    'authentic' => true,
    'product' => $result['product_name'],
    'sku' => $result['sku'],
    'crafted_date' => $result['crafted_date'],
    'artisans' => $result['artisans'], // "คุณแดง, คุณน้ำ"
    'warranty' => '2 years',
    'certificate_url' => "https://bellavier.com/certificate/{$serial}"
]);

function extractTenantFromSerial($serial) {
    // If format: {TENANT}-{SKU}-{YEAR}-{HASH}
    // Example: MA-TOTE-2025-A7F3C9
    // Extract: MA = maison_atelier
    
    $parts = explode('-', $serial);
    if (count($parts) >= 4) {
        $tenantMap = [
            'MA' => 'maison_atelier',
            'BF' => 'bellavier_factory',
            // ... other tenants
        ];
        
        return $tenantMap[$parts[0]] ?? 'default';
    }
    
    // Single tenant system
    return 'maison_atelier';
}
```

---

## 🎯 **Multi-Tenant Serial Format**

### **Problem:**
```
Tenant A: TOTE-2025-A7F3C9
Tenant B: TOTE-2025-A7F3C9  ← ซ้ำกัน!

Customer scan → ไม่รู้ว่าเป็น tenant ไหน
```

### **Solution: Add Tenant Prefix**

**Format:**
```
{TENANT}-{SKU}-{YEAR}-{HASH}

Examples:
MA-TOTE-2025-A7F3C9        (Maison Atelier)
BF-WALLET-2025-B2E1D5      (Bellavier Factory)
LC-HANDBAG-2025-C9F2A8     (Luxury Collection)

Benefits:
✅ Global uniqueness (across all tenants)
✅ Clear ownership
✅ Routing ถูกต้อง (customer portal)
```

---

## 🔐 **Security Checklist**

### **Before Production Deployment:**

**Serial Generation:**
- [ ] ใช้ cryptographic random (random_bytes)
- [ ] Hash with SHA256
- [ ] Validate uniqueness in database
- [ ] Log generation for audit

**Serial Validation:**
- [ ] Format validation (regex)
- [ ] Cross-job uniqueness check
- [ ] Completed job blocking
- [ ] Event history validation

**QR Code:**
- [ ] Include verification hash
- [ ] Timestamp for expiry check
- [ ] JSON payload validation
- [ ] Origin verification

**Customer Portal:**
- [ ] Rate limiting (10 req/min)
- [ ] IP logging (audit trail)
- [ ] Limited data exposure (no internal IDs)
- [ ] HTTPS only (SSL/TLS)

**Database:**
- [ ] Prepared statements (100%)
- [ ] Unique constraints
- [ ] Audit logging
- [ ] Soft-delete tracking

---

## 💰 **Cost-Benefit (Security)**

### **Investment in Security:**

| Security Feature | Cost | Benefit |
|------------------|------|---------|
| Cryptographic serial | 0 (dev time) | Prevent counterfeiting |
| QR verification hash | 0 (dev time) | Anti-tampering |
| Rate limiting | 0 (APCu cache) | Prevent abuse |
| Audit logging | Storage (~1 GB/year) | Compliance |
| **Total** | **~5,000 บาท/year** | **Priceless** |

### **Cost of Security Breach:**

**Scenario: Counterfeit Products**
```
Fake products in market: 1,000 units
Bellavier brand damage: Priceless
Legal liability: 1,000,000+ บาท
Customer trust loss: Cannot recover

Prevention cost: 0 บาท (just good design!)
→ ROI: Infinite ✅
```

---

## ✅ **Final Recommendations**

### **1. QR Code Strategy:**

**✅ Use QR Code exclusively (not barcode)**
- PWA ready (camera API)
- Scan ผ่านมือถือ (ไม่ต้องซื้อ scanner)
- Support complex payload
- Error correction 30%

---

### **2. Component Serial:**

**✅ YES - Components ต้องมี Serial เป็นของตัวเอง!**

**When to use:**
- ✅ Luxury products (high-value items)
- ✅ Assembly operations (multi-component)
- ✅ Supplier accountability (track source)
- ⏸️ Not needed for simple linear workflow

**Implementation:**
- Phase 1 (Current): Final product serial only
- Phase 4 (Q1 2026): Component serial + genealogy (DAG)

---

### **3. Secure Serial Format:**

**✅ Use Hybrid: {PREFIX}-{YEAR}-{HASH-6}**

**Examples:**
```
Component Serials:
- BODY-2025-A7F3C9
- STRAP-2025-B2E1D5

Final Product Serials:
- TOTE-2025-9X4K2L
- HANDBAG-2025-7Z2H0M

Multi-Tenant (if needed):
- MA-TOTE-2025-9X4K2L   (Maison Atelier)
- BF-WALLET-2025-8Y3J1K (Bellavier Factory)
```

**Benefits:**
- ✅ Unpredictable (secure)
- ✅ Unique globally
- ✅ Anti-counterfeiting
- ✅ Still readable
- ✅ Sortable by year

---

## 🚀 **Action Items**

### **ทำทันที (Before Pilot):**

1. **Update serial generation to use secure hash** (2 hours)
   - Implement `SecureSerialGenerator` class
   - Use `{SKU}-{YEAR}-{HASH-6}` format
   - Add verification hash to QR payload

2. **Add cross-job validation** (1 hour)
   - Update `ValidationService`
   - Block serial reuse across jobs
   - Block reuse after completion

3. **Implement QR verification** (1 hour)
   - HMAC hash validation
   - Timestamp checking
   - Anti-tampering detection

**Total: 4 hours 🔴**

---

## 📚 **Documentation Updates**

<function_calls>
<invoke name="search_replace">
<parameter name="file_path">/Applications/MAMP/htdocs/bellavier-group-erp/docs/INDEX.md

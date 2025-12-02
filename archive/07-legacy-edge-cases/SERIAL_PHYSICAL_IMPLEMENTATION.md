# 🏷️ Serial Tracking - Physical Implementation Guide

**Created:** November 1, 2025  
**Status:** 📋 Planning & Design  
**Audience:** Production Manager, Operations Team, System Implementers

---

## 🎯 **ปัญหาที่ต้องแก้:**

### **❓ คำถามสำคัญจากการใช้งานจริง:**

1. **จะนำ serial code ติดไปบนชิ้นงานอย่างไร?**
   - Sticker? Tag? เขียนด้วยปากกา?
   - ติดที่ไหนไม่ให้หลุด/เสียหาย?
   - Material อะไรทนทาน กันน้ำ?

2. **ถ้าหลุด/หายระหว่างทาง จะทำอย่างไร?**
   - ออก code ใหม่? (ข้อมูลเดิมจะหายไหม?)
   - ช่างจะรู้ได้อย่างไรว่าชิ้นนี้คือ serial อะไร?
   - ป้องกันการใช้ซ้ำได้ไหม?

3. **ถ้าทำมาเกิน (excess) จะเก็บไว้ใช้ต่อได้ไหม?**
   - ข้อมูลเวลาการทำยังใช้ได้ไหม?
   - ใส่ job ใหม่ได้ไหม?
   - ต้นทุนจะคำนวณอย่างไร?

---

## 🏷️ **Solution A: QR Sticker Strategy (แนะนำ)**

### **1. WIP Stage (ระหว่างผลิต)**

**Label Type: Removable Paper Sticker**

**Specifications:**
```
Material: Water-resistant paper
Size: 7x7 cm (square) or 7x10 cm (rectangular)
Adhesive: Removable (ลอกออกได้ ไม่ทิ้งคราบ)
Print: Black & white (laser printer)
Cost: 1.5-2 บาท/ใบ
```

**Label Content:**
```
┌───────────────────────────┐
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓       │ ← QR Code (5x5 cm)
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓       │    Payload: {type, ticket, task, serial}
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓       │
│                           │
│  TOTE-2025-001            │ ← Serial (font: 14pt bold)
│  Job: JT251022001         │
│  SKU: LUXURY-TOTE         │
│                           │
│  Tasks:                   │ ← Progress checklist
│  ☐ ตัด                   │
│  ☐ เย็บตัว               │
│  ☐ เย็บสาย               │
│  ☐ ประกอบ               │
│  ☐ QC                    │
└───────────────────────────┘
```

**Placement Strategy:**
| Stage | Location | Reason |
|-------|----------|--------|
| ตัด (Cutting) | ด้านหลังชิ้นหนัง | ไม่กีดขวาง marking |
| เย็บ (Sewing) | ด้านในกระเป๋า | ไม่ให้เข็มทิ่ม sticker |
| ประกอบ (Assembly) | ย้ายไป tag card | Temporary sticker → Permanent tag |
| QC | Tag card ห้อย | Professional presentation |

**How to Stick:**
```
1. ทำความสะอาดพื้นผิว (ปัดฝุ่น)
2. ติด sticker ให้แน่น (กดให้ติด 5 วินาที)
3. ตรวจสอบว่า sticker แน่น (ลอกมุมดู)
4. ถ้าหลวม → ติดเทปใส (scotch tape) เสริม
```

---

### **2. Final Product Stage (สินค้าสำเร็จ)**

**Label Type: Premium Tag Card**

**Specifications:**
```
Material: Thick card stock (300 gsm)
Size: 5x8 cm (credit card size)
Print: Full color + gold foil
Attachment: String/ribbon (luxury feel)
Cost: 15-30 บาท/ใบ
```

**Tag Design:**
```
┌─────────────────────────────┐
│  ╔═══════════════════════╗  │
│  ║  BELLAVIER GROUP      ║  │ ← Gold foil
│  ║  Handcrafted with ❤️  ║  │
│  ╚═══════════════════════╝  │
│                             │
│     ▓▓▓▓▓▓▓▓▓▓▓▓▓▓         │ ← QR Code
│     ▓▓▓▓▓▓▓▓▓▓▓▓▓▓         │
│                             │
│  Serial: HB-2025-001        │
│  Artisan: คุณแดง            │
│  Crafted: Nov 1, 2025       │
│                             │
│  Scan for authenticity      │
│  & craftsmanship story      │
└─────────────────────────────┘
```

**Attachment:**
- Luxury ribbon (สีทอง/เงิน)
- Tied to handle or zipper
- Can be removed by customer (keep as certificate)

---

## ❌ **Error Scenario 1: Label Lost/Damaged**

### **Problem:**
```
Time: 14:00 - ช่างติด sticker TOTE-001 แล้วเริ่มงาน
Time: 15:00 - ทำงานไป 1 ชม.
Time: 15:30 - Sticker หลุด! 😱
Time: 16:00 - จะ complete ไม่ได้ (ไม่มี QR scan)
```

### **Solution: Reprint Same Serial**

**PWA UI:**
```
┌────────────────────────────────────┐
│  ⚠️ ไม่สามารถ scan QR ได้?       │
│                                    │
│  เลือกชิ้นงานที่กำลังทำอยู่:      │
│                                    │
│  ○ TOTE-001                        │
│    Task: ตัด (50% complete)       │
│    Started: 14:00 by คุณแดง       │
│    Duration: 2 ชม.                │
│                                    │
│  ○ TOTE-002                        │
│    Task: เย็บ (30% complete)      │
│    Started: 16:00 by คุณน้ำ       │
│    Duration: 1 ชม.                │
│                                    │
│  [ยืนยันและพิมพ์ QR ใหม่]         │
└────────────────────────────────────┘
```

**Backend Logic:**
```php
// API: reprint_serial
case 'reprint_serial':
    $serialNumber = $_POST['serial_number'];
    $reason = $_POST['reason'] ?? 'lost';
    
    // Validate serial exists
    $log = db_fetch_one($db, "
        SELECT * FROM atelier_wip_log 
        WHERE serial_number = ? 
          AND deleted_at IS NULL 
        ORDER BY event_time DESC 
        LIMIT 1
    ", [$serialNumber]);
    
    if (!$log) {
        json_error('Serial not found', 404);
    }
    
    // Check not already completed
    if ($log['event_type'] === 'complete') {
        json_error('Serial already completed', 400);
    }
    
    // Log reprint event
    $stmt = $db->prepare("
        INSERT INTO serial_reprint_log 
        (serial_number, reason, reprinted_by, reprinted_at)
        VALUES (?, ?, ?, NOW())
    ");
    $stmt->bind_param('ssi', $serialNumber, $reason, $userId);
    $stmt->execute();
    
    // Generate QR PDF
    $qrData = json_encode([
        'type' => 'work_piece',
        'ticket' => $log['id_job_ticket'],
        'task' => $log['id_job_task'],
        'serial' => $serialNumber
    ]);
    
    $pdfUrl = generateQRLabel($qrData, $serialNumber);
    
    json_success([
        'pdf_url' => $pdfUrl,
        'serial' => $serialNumber,
        'message' => 'QR label ready to print'
    ]);
```

**Database Table:**
```sql
CREATE TABLE serial_reprint_log (
    id INT PRIMARY KEY AUTO_INCREMENT,
    serial_number VARCHAR(100) NOT NULL,
    reason ENUM('lost', 'damaged', 'illegible', 'other'),
    reprinted_by INT,
    reprinted_at DATETIME,
    notes TEXT,
    INDEX idx_serial (serial_number)
);
```

**Benefits:**
- ✅ Same serial → Work history preserved
- ✅ Track reprint frequency → Quality improvement
- ✅ Quick recovery (< 1 นาที)

---

## ♻️ **Error Scenario 2: Excess Production (ทำมาเกิน)**

### **Problem:**
```
Job: JT251022001, Target: 10 pcs
ทำไป: 12 pcs (เผื่อของเสีย 2 pcs)
QC:
  - Pass: 11 pcs → ส่งมอบ
  - อยู่ระหว่างทำ: 1 pc (TOTE-012, 80% complete)

คำถาม:
1. TOTE-012 ควรทำต่อไหม? (ถ้าไม่มี order)
2. ถ้าเก็บไว้ จะเก็บที่ไหน?
3. ถ้ามี order ใหม่ จะใช้ TOTE-012 ต่อได้ไหม?
4. Work history (เวลา, ช่าง) จะหายไหม?
```

### **Solution: WIP Inventory System**

**Database:**
```sql
CREATE TABLE wip_inventory (
    id INT PRIMARY KEY AUTO_INCREMENT,
    serial_number VARCHAR(100) UNIQUE NOT NULL,
    sku VARCHAR(100) NOT NULL,
    
    -- Progress tracking
    current_task_id INT,            -- ทำมาถึง task ไหนแล้ว
    completed_tasks JSON,           -- [{id: 1, name: 'ตัด', completed_at: '...'}]
    completion_pct DECIMAL(5,2),    -- เสร็จไปกี่ %
    
    -- Work history (preserve data!)
    work_history JSON,              -- Detailed work log
    total_work_minutes INT,         -- รวมเวลาที่ใช้
    artisans JSON,                  -- ช่างที่เคยทำ [{name, task, duration}]
    quality_notes TEXT,             -- หมายเหตุคุณภาพ
    
    -- Inventory management
    status ENUM('ready', 'reserved', 'in_use', 'scrapped'),
    location VARCHAR(100),          -- เก็บที่ rack ไหน
    reserved_for_job INT NULL,      -- จองไว้ให้ job ไหน
    reserved_at DATETIME NULL,
    
    -- Origin
    original_job_ticket INT,        -- มาจาก job ไหน
    created_at DATETIME,
    updated_at DATETIME,
    
    INDEX idx_sku_status (sku, status),
    INDEX idx_location (location),
    FOREIGN KEY (current_task_id) REFERENCES atelier_job_task(id_job_task)
);
```

**Example Data:**
```sql
INSERT INTO wip_inventory VALUES (
    1,
    'TOTE-012',
    'LUXURY-TOTE',
    8,  -- Task 8: ตกแต่ง
    '[
        {"id":1,"name":"ตัด","completed_at":"2025-11-01 14:00:00"},
        {"id":2,"name":"เย็บตัว","completed_at":"2025-11-01 16:00:00"},
        {"id":3,"name":"เย็บสาย","completed_at":"2025-11-01 17:00:00"}
    ]',
    75.0,  -- เสร็จ 75%
    '[
        {"task":"ตัด","operator":"คุณแดง","duration":120,"notes":"คุณภาพดี"},
        {"task":"เย็บตัว","operator":"คุณน้ำ","duration":150,"notes":"เย็บสวย"},
        {"task":"เย็บสาย","operator":"คุณฝน","duration":90,"notes":"แน่น"}
    ]',
    360,  -- รวม 6 ชม.
    '[
        {"name":"คุณแดง","tasks":["ตัด"],"total_minutes":120},
        {"name":"คุณน้ำ","tasks":["เย็บตัว"],"total_minutes":150},
        {"name":"คุณฝน","tasks":["เย็บสาย"],"total_minutes":90}
    ]',
    'งานดี คุณภาพสูง',
    'ready',          -- พร้อมใช้
    'WIP-SHELF-A1',   -- เก็บที่ rack A1
    NULL,             -- ยังไม่ถูกจอง
    NULL,
    10,               -- มาจาก Job 10
    NOW(),
    NOW()
);
```

---

### **PWA Flow: Reuse WIP Inventory**

**When creating new job:**

```javascript
// Step 1: Check WIP inventory
$.get('source/wip_inventory_api.php', {
    action: 'check_available',
    sku: 'LUXURY-TOTE'
}, (resp) => {
    if (resp.ok && resp.data.length > 0) {
        showWIPReuseDialog(resp.data);
    }
});

// Step 2: Show reuse dialog
function showWIPReuseDialog(wipItems) {
    let html = '<h5>พบชิ้นงานค้างที่พร้อมใช้:</h5><ul>';
    
    wipItems.forEach(item => {
        html += `
            <li>
                <input type="checkbox" id="wip-${item.serial_number}" checked>
                <label>
                    <strong>${item.serial_number}</strong> 
                    (${item.completion_pct}% complete)
                    <br>
                    <small>
                        Task ถัดไป: ${item.next_task_name}
                        | เก็บที่: ${item.location}
                        | เวลารวม: ${item.total_work_minutes} นาที
                    </small>
                </label>
            </li>
        `;
    });
    
    html += '</ul>';
    
    Swal.fire({
        title: 'ใช้ชิ้นงานค้างหรือไม่?',
        html: html,
        showCancelButton: true,
        confirmButtonText: 'ใช้ชิ้นงานที่เลือก',
        cancelButtonText: 'ทำใหม่ทั้งหมด'
    }).then((result) => {
        if (result.isConfirmed) {
            // Get selected WIP items
            const selected = getSelectedWIP();
            reserveWIPForJob(selected, newJobId);
        }
    });
}
```

**Step 3: Reserve WIP for new job**

```php
// API: reserve_wip
case 'reserve_wip':
    $serials = $_POST['serials']; // Array
    $jobId = (int)$_POST['job_id'];
    
    foreach ($serials as $serial) {
        // Update WIP inventory
        $stmt = $db->prepare("
            UPDATE wip_inventory 
            SET status = 'reserved',
                reserved_for_job = ?,
                reserved_at = NOW()
            WHERE serial_number = ?
              AND status = 'ready'
        ");
        $stmt->bind_param('is', $jobId, $serial);
        $stmt->execute();
        
        // Update WIP logs (link to new job)
        $stmt2 = $db->prepare("
            UPDATE atelier_wip_log 
            SET id_job_ticket = ?
            WHERE serial_number = ?
              AND deleted_at IS NULL
        ");
        $stmt2->bind_param('is', $jobId, $serial);
        $stmt2->execute();
    }
    
    json_success(['reserved' => count($serials)]);
```

---

**Step 4: Continue work from WIP**

```javascript
// PWA: Operator scans TOTE-012

ระบบเช็ค:
1. TOTE-012 อยู่ใน wip_inventory? → YES
2. Current task? → Task 8 (ตกแต่ง)
3. Completion? → 75%

แสดง:
┌────────────────────────────────┐
│  ชิ้นงาน WIP                   │
│                                │
│  Serial: TOTE-012              │
│  ความคืบหน้า: 75%             │
│                                │
│  งานที่ทำแล้ว:                 │
│  ✅ ตัด (คุณแดง, 2 ชม.)       │
│  ✅ เย็บตัว (คุณน้ำ, 2.5 ชม.) │
│  ✅ เย็บสาย (คุณฝน, 1.5 ชม.)  │
│                                │
│  งานถัดไป: ตกแต่ง             │
│                                │
│  [เริ่มทำต่อ]                  │
└────────────────────────────────┘

ช่างกด "เริ่มทำต่อ":
→ Start task "ตกแต่ง"
→ Work history preserved!
→ เวลารวมสะสมต่อ
```

---

## 🔄 **Label Lifecycle**

### **Full Lifecycle:**

```
1. GENERATE (Job created)
   ↓
   System generates serials: TOTE-001 to TOTE-010
   
2. PRINT (Bulk print)
   ↓
   Print 10 QR stickers (PDF, 1 page)
   Operator cuts and prepares
   
3. ATTACH (Task start)
   ↓
   Stick on work piece (inside/back)
   
4. SCAN (Each task)
   ↓
   Start task → Scan QR
   Complete task → Scan QR
   Transfer to next station (sticker stays on piece)
   
5. TRANSFER (Between tasks)
   ↓
   Piece moved with sticker
   Next operator scans QR (verify correct piece)
   
6. REPLACE (Final product)
   ↓
   Remove temporary sticker
   Attach premium tag card
   
7. CUSTOMER (After sales)
   ↓
   Customer scans QR on tag
   View full craftsmanship history
```

---

## 🎯 **Special Cases**

### **Case 1: Pre-made Components (สำหรับ DAG)**

**Scenario:**
```
ทำ body ล่วงหน้า 50 ชิ้น
ทำ strap ล่วงหน้า 100 เส้น

เก็บใน component inventory พร้อม sticker
เมื่อต้องประกอบ:
→ หยิบ body จาก shelf (scan QR)
→ หยิบ strap จาก shelf (scan QR)
→ ประกอบ
→ สร้าง final serial
```

**Label for Components:**
```
┌─────────────────────┐
│  ▓▓▓▓▓▓▓▓▓▓▓       │ ← QR
│                     │
│  BODY-001           │
│  Type: Component    │
│  For: LUXURY-TOTE   │
│  Grade: A           │
│  Artisan: คุณแดง    │
│                     │
│  Ready for assembly │
└─────────────────────┘
```

**Storage:**
- Shelf: COMPONENT-BODY-A (sorted by grade)
- Box with label: "LUXURY-TOTE Bodies (Grade A)"
- Quick pick for assembly

---

### **Case 2: Rework (ทำใหม่)**

**Scenario:**
```
TOTE-001 ทำเสร็จแล้ว
QC fail! → ต้อง rework

คำถาม:
- ใช้ serial เดิม (TOTE-001) หรือสร้างใหม่?
- Work history เก่ายังเก็บไหม?
```

**Solution: Keep Same Serial (แนะนำ)**

```
QC fail → Rework:
1. Serial ยังคงเป็น TOTE-001
2. เพิ่ม rework event:
   - event_type: 'rework'
   - notes: 'QC fail: เย็บไม่ตรง'
   - rework_count++

3. ส่งกลับไป task ที่มีปัญหา (เช่น "เย็บ")

4. ช่าง scan TOTE-001 อีกครั้ง:
   → แสดง: "Rework (ครั้งที่ 1)"
   → ทำแก้ไข
   → Complete → ส่งต่อ

5. Work history รวม:
   - Original work (คุณแดง, 2 ชม.)
   - Rework (คุณน้ำ, 0.5 ชม.)
   - Total: 2.5 ชม.

✅ ข้อมูลไม่หาย
✅ Trace ได้ว่าเคย rework
✅ Cost accurate (รวมเวลา rework)
```

---

### **Case 3: Component Substitution (เปลี่ยนชิ้นส่วน)**

**Scenario (DAG System):**
```
Assembly task:
- กำหนดใช้: STRAP-001
- แต่ STRAP-001 เสีย/หาย
- ต้องเปลี่ยนเป็น STRAP-002 แทน

คำถาม:
- Genealogy จะถูกต้องไหม?
- ต้องบันทึกอย่างไร?
```

**Solution: Substitution Log**

```sql
CREATE TABLE component_substitution_log (
    id INT PRIMARY KEY AUTO_INCREMENT,
    final_product_serial VARCHAR(100),  -- HANDBAG-001
    original_component VARCHAR(100),    -- STRAP-001 (planned)
    substitute_component VARCHAR(100),  -- STRAP-002 (actual)
    component_type VARCHAR(50),         -- 'strap'
    reason VARCHAR(255),                -- 'original_damaged'
    substituted_by INT,
    substituted_at DATETIME
);

-- Query: Product ใช้ component อะไรจริงๆ?
SELECT 
    fc.component_type,
    COALESCE(sub.substitute_component, fc.original_component) as actual_component
FROM final_product_components fc
LEFT JOIN component_substitution_log sub 
    ON sub.final_product_serial = fc.final_product_serial
    AND sub.component_type = fc.component_type
WHERE fc.final_product_serial = 'HANDBAG-001';
```

---

## 📍 **Physical Storage & Tracking**

### **WIP Shelf Organization:**

**Rack Layout:**
```
┌─────────────────────────────────────┐
│  WIP Inventory Rack                 │
│                                     │
│  [A1] LUXURY-TOTE (Ready)           │
│  ├─ TOTE-012 (80%) 📍              │
│  ├─ TOTE-015 (60%) 📍              │
│  └─ TOTE-018 (90%) 📍              │
│                                     │
│  [A2] WALLET (Ready)                │
│  ├─ WALLET-005 (70%) 📍            │
│  └─ WALLET-009 (50%) 📍            │
│                                     │
│  [B1] COMPONENTS - Body             │
│  ├─ BODY-001 (Grade A) 📍          │
│  ├─ BODY-002 (Grade A) 📍          │
│  └─ BODY-003 (Grade B) 📍          │
│                                     │
│  [B2] COMPONENTS - Strap            │
│  ├─ STRAP-001 (Grade A) 📍         │
│  └─ STRAP-002 (Grade A) 📍         │
└─────────────────────────────────────┘
```

**Shelf Label (QR Code):**
```
┌──────────────────┐
│  ▓▓▓▓▓▓▓▓▓▓     │ ← Rack QR
│                  │
│  WIP Shelf: A1   │
│  SKU: LUXURY-TOTE│
│  Items: 3        │
│                  │
│  Scan to view    │
│  inventory list  │
└──────────────────┘
```

**PWA: Scan Shelf QR**
```
ช่าง scan shelf QR "A1":

แสดง:
┌────────────────────────────────┐
│  📍 WIP Shelf A1               │
│  SKU: LUXURY-TOTE              │
│                                │
│  Available Items (3):          │
│                                │
│  ☐ TOTE-012 (80%)              │
│     Next: ตกแต่ง                │
│     Location: Row 1, Box 2     │
│                                │
│  ☐ TOTE-015 (60%)              │
│     Next: เย็บสาย              │
│     Location: Row 2, Box 1     │
│                                │
│  ☐ TOTE-018 (90%)              │
│     Next: QC                   │
│     Location: Row 1, Box 3     │
│                                │
│  [หยิบชิ้นงาน]                 │
└────────────────────────────────┘

เลือกชิ้นงาน → Scan serial → Continue work
```

---

## 💡 **Best Practices**

### **1. Label Placement:**
- ✅ **DO:** ติดด้านใน (hidden), ตำแหน่งที่ไม่กีดขวางการทำงาน
- ❌ **DON'T:** ติดด้านนอก (ลูกค้าเห็น), บนรอยต่อ (หลุดง่าย)

### **2. Label Maintenance:**
- ✅ **DO:** เช็ค sticker ทุกครั้งก่อนส่งต่อ task
- ✅ **DO:** Reprint ทันทีถ้าหลุด/ชำรุด
- ❌ **DON'T:** ปล่อยให้ sticker ขาด/พับ (อ่านไม่ได้)

### **3. WIP Inventory:**
- ✅ **DO:** เก็บตาม SKU และ %complete
- ✅ **DO:** FIFO (First In First Out) - ใช้ชิ้นเก่าก่อน
- ❌ **DON'T:** เก็บนานเกิน 30 วัน (คุณภาพอาจเปลี่ยน)

### **4. Component Inventory:**
- ✅ **DO:** แยกเก็บตาม type (body, strap, HW)
- ✅ **DO:** Sort by grade (A, B, C)
- ✅ **DO:** Label ชั้นวาง (shelf QR)

---

## 🎓 **Training for Operators**

### **Skills Needed:**

**Basic (Week 1):**
- ✅ Scan QR code (PWA)
- ✅ Stick label on piece (correct placement)
- ✅ Check label before transfer

**Intermediate (Week 2):**
- ✅ Reprint lost label
- ✅ Find serial in active list
- ✅ Use WIP from inventory

**Advanced (Q1 2026 - DAG):**
- ✅ Scan multiple components
- ✅ Assembly validation
- ✅ Component substitution

---

## 📊 **Metrics to Track**

### **Label Quality Metrics:**
| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Reprint rate | < 5% | > 10% |
| Label damage rate | < 2% | > 5% |
| QR scan failure rate | < 1% | > 3% |

**Actions if threshold exceeded:**
- Check sticker material quality
- Review placement guidelines
- Consider waterproof stickers

### **WIP Inventory Metrics:**
| Metric | Target | Notes |
|--------|--------|-------|
| WIP inventory value | < 50,000 บาท | Too much = production planning issue |
| WIP reuse rate | > 80% | Low = waste |
| Avg WIP age | < 7 days | Old = quality concern |

---

## 💰 **Cost-Benefit Analysis**

### **Investment:**
| Item | Qty/Month | Unit Cost | Total/Month |
|------|-----------|-----------|-------------|
| WIP stickers | 1,000 | 2 บาท | 2,000 บาท |
| Final tags | 900 | 20 บาท | 18,000 บาท |
| Reprint (5%) | 50 | 2 บาท | 100 บาท |
| **Total** | | | **20,100 บาท** |

### **Savings:**
| Benefit | Estimated Value/Year |
|---------|---------------------|
| Recall cost reduction | 500,000 บาท (95% precision) |
| Waste reduction (WIP reuse) | 50,000 บาท (80% reuse rate) |
| Quality improvement | 100,000 บาท (faster issue detection) |
| Customer trust | Priceless (brand value) |
| **Total ROI** | **600,000+ บาท/ปี** |

**Payback Period:** < 1 month ✅

---

## 🚀 **Implementation Priority**

### **Phase 1: Current (Nov 1, 2025) ✅ DONE**
- Database schema
- Backend validation
- UI (PWA + Job Ticket)
- **Status:** Manual entry only

### **Phase 2: Pilot Enhancement (1-2 weeks)**
**Priority: HIGH 🔴**
- [ ] Auto-generate serials
- [ ] Bulk QR printing (PDF)
- [ ] Reprint lost labels
- **Timeline:** 2-3 hours
- **Value:** 80% time saved

### **Phase 3: WIP Inventory (2-3 weeks)**
**Priority: MEDIUM 🟡**
- [ ] wip_inventory table
- [ ] Excess production handling
- [ ] WIP reuse workflow
- **Timeline:** 3-4 hours
- **Value:** Reduce waste 50-80%

### **Phase 4: Component Inventory (Q1 2026)**
**Priority: LOW 🟢**
- [ ] component_inventory table
- [ ] Pre-made parts tracking
- [ ] Grade classification
- **Timeline:** 2-3 hours
- **Prerequisite:** DAG system

### **Phase 5: DAG Assembly (Q1 2026)**
**Priority: FUTURE 📋**
- [ ] Multi-component scanning
- [ ] Assembly genealogy
- [ ] Component substitution
- **Timeline:** 6-8 weeks
- **Prerequisite:** Pilot success + Business need

---

## ✅ **Decision Matrix**

| Question | Answer | Action |
|----------|--------|--------|
| Do you have assembly operations? | YES | Implement DAG (Q1 2026) |
| Do you have assembly operations? | NO | Serial Simple enough |
| Do operators have time to print labels? | YES | Implement Phase 2 now |
| Do operators have time to print labels? | NO | Keep manual entry |
| Do you have excess WIP? | YES | Implement Phase 3 soon |
| Do you have excess WIP? | NO | Skip WIP inventory |
| Do you make components in advance? | YES | Implement Phase 4 |
| Do you make components in advance? | NO | Skip component inventory |

---

## 📚 **References**

- `SERIAL_TRACKING_README.md` - Current implementation
- `SERIAL_TRACKING_ROADMAP.md` - Technical roadmap
- `DAG_PLANNING_SUMMARY.md` - DAG architecture overview
- `BELLAVIER_DAG_RUNTIME_FLOW.md` - Token lifecycle (assembly logic)

---

**Updated:** November 1, 2025  
**Version:** 1.0 (Initial Design)  
**Status:** ✅ Complete Planning - Ready for Stakeholder Review

---

**Built with ❤️ for Bellavier Group**  
**Production-Ready Design - From WIP to Final Product**


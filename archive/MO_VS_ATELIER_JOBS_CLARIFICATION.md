# 📋 MO vs Atelier Jobs - Complete Clarification

**Created:** November 5, 2025  
**Purpose:** Clarify the difference between MO and Atelier Jobs systems  
**Status:** Design Decision Document

---

## ❓ **คำถามที่ได้รับ:**

> **ใน MO มีวงเล็บว่า (OEM) แต่ตอนสร้างเลือก production_type ได้ทั้ง atelier/oem/hybrid?**  
> **Atelier Jobs ทำหน้าที่เหมือน MO หรือเปล่า?**

---

## ✅ **คำตอบ: ไม่เหมือนกัน!**

### **MO (Manufacturing Order)** และ **Atelier Jobs** เป็นคนละระบบ สำหรับคนละวิธีการผลิต

---

## 🏭 **MO (Manufacturing Order) - OEM Production**

### หลักการ:
```
MO = Manufacturing Order (ใบสั่งผลิต)
สำหรับ: OEM / Mass Production / High Volume
ลักษณะ: ผลิตจำนวนมาก ตามแผน มี due date เข้มงวด
```

### Workflow:
```
1. Create MO
   - Product: เลือกจาก product ที่มี production_lines รวม 'oem'
   - Qty: จำนวนมาก (50-1000+ pcs)
   - Due Date: บังคับ!
   - Schedule: บังคับ! (start date, end date)
   - Graph: เลือก routing template สำหรับ OEM
   ↓
2. Review & Schedule
   - ตรวจสอบ capacity
   - จัดสรร resources
   - อนุมัติแผน
   ↓
3. Start Production
   - สร้าง graph_instance
   - Spawn tokens (batch)
   - Auto-assign to production line
   ↓
4. Work Queue
   - Operators เห็นงาน
   - ทำตาม flow ที่กำหนด
```

### Use Cases:
- ✅ ผลิต TOTE Bag 500 ชิ้น สำหรับ customer ABC
- ✅ ผลิต Wallet 1000 ชิ้น ส่งมอบวันที่ 30 Nov
- ✅ งาน OEM ที่ต้องการ scheduling และ capacity planning

---

## 🎨 **Atelier Jobs - Luxury Production**

### หลักการ:
```
Atelier Jobs = Luxury / Custom Production
สำหรับ: งานฝีมือ / Custom / High Quality
ลักษณะ: ทำชิ้นต่อชิ้น เน้นคุณภาพ flexible schedule
```

### Workflow:
```
1. Create Job (1-click!)
   - Product: เลือกจาก product ที่มี production_lines รวม 'atelier'
   - Qty: จำนวนน้อย (1-50 pcs)
   - Due Date: optional (flexible)
   - Schedule: ไม่ต้อง! (เริ่มทันที)
   - Graph: auto-select จาก pattern
   ↓
2. Start Immediately
   - สร้าง job_ticket + graph_instance ทันที
   - Spawn tokens (piece by piece)
   - Auto-assign to artisans
   ↓
3. Work Queue
   - Artisans เห็นงาน
   - ทำได้ทันที (no waiting for schedule)
```

### Use Cases:
- ✅ ผลิตกระเป๋าสั่งทำพิเศษ 5 ชิ้น (VIP customer)
- ✅ ทำ prototype ใหม่ 3 ชิ้น
- ✅ งาน custom ที่ต้องการความยืดหยุ่น

---

## 📊 **เปรียบเทียบ MO vs Atelier Jobs**

| คุณสมบัติ | MO (OEM) | Atelier Jobs |
|-----------|----------|--------------|
| **Production Type** | OEM (should be hardcoded) | Atelier (hardcoded) |
| **Target Quantity** | สูง (50-1000+) | ต่ำ (1-50) |
| **Due Date** | ✅ บังคับ | ⚠️ Optional |
| **Schedule** | ✅ บังคับ | ❌ ไม่ต้อง |
| **Start Time** | ตามแผน | ทันที |
| **Batch Size** | > 1 (batch) | 1 (piece) |
| **Flow** | MO → Schedule → Start → Tokens | Job → Tokens (1-click) |
| **Flexibility** | ต่ำ (ตามแผน) | สูง (ปรับได้) |
| **QC** | Sampling (10%) | 100% inspection |
| **UI** | Manufacturing Orders page | Atelier Jobs page |
| **Link to MO** | N/A (MO itself) | ✅ Optional (can link) |

---

## 🔴 **ปัญหาปัจจุบัน:**

### ใน `source/mo.php`:
```php
// Line 135
$production_type = trim($_POST['production_type'] ?? 'oem');

// Line 147-150
if (!in_array($production_type, ['atelier', 'oem', 'hybrid'])) {
    echo json_encode(['ok'=>false,'error'=>'Invalid production type']);
    exit;
}
```

**❌ Problem:** MO สามารถเลือก `production_type` ได้ทั้งหมด!

**ผลกระทบ:**
- สับสน: MO ควรเป็น OEM only แต่เลือก atelier ได้
- Inconsistent: Atelier Jobs hardcode 'atelier' แต่ MO ไม่ hardcode 'oem'
- Logic error: MO ไม่ควรมี atelier mode

---

## ✅ **วิธีแก้:**

### **Option A: Hardcode MO = OEM Only** ⭐ **Recommended**

```php
// source/mo.php
case 'create':
    // Remove production_type from form input
    $production_type = 'oem'; // HARDCODE!
    
    // Validation for OEM only
    $validation = ProductionRulesService::validate([
        'qty' => $qty,
        'due_date' => $due_date,
        'scheduled_start_date' => $scheduled_start_date,
        'id_routing_graph' => $id_routing_graph
    ], 'oem'); // Always OEM
    
    // ... rest of code
```

**Changes Needed:**
1. Remove `production_type` dropdown from MO form
2. Hardcode `production_type = 'oem'` in create action
3. Update menu text: "Manufacturing Orders (OEM)" → always OEM

---

### **Option B: Keep production_type but Validate Strictly**

```php
case 'create':
    $production_type = trim($_POST['production_type'] ?? 'oem');
    
    // ✅ NEW: Validate that MO only accepts OEM
    if ($production_type !== 'oem') {
        echo json_encode([
            'ok' => false,
            'error' => 'MO only supports OEM production. Use Atelier Jobs for atelier production.'
        ]);
        exit;
    }
    
    // ... rest of code
```

---

## 🎯 **Design Decision: แยกชัดเจน!**

### **Production Type Separation:**

```
┌─────────────────────────────────────────────────────────────┐
│                  BELLAVIER ERP PRODUCTION                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  🏭 OEM / Mass Production                                  │
│  ├─ UI: Manufacturing Orders                               │
│  ├─ production_type: 'oem' (hardcoded)                     │
│  ├─ Features: Schedule, Capacity, Batch                    │
│  └─ Flow: MO → Schedule → Start → Tokens                   │
│                                                             │
│  🎨 Atelier / Luxury Production                            │
│  ├─ UI: Atelier Jobs                                       │
│  ├─ production_type: 'atelier' (hardcoded)                 │
│  ├─ Features: Flexible, Quality, 1-click                   │
│  └─ Flow: Job → Tokens (immediate)                         │
│                                                             │
│  🔗 Optional: Link Atelier Job to MO                       │
│  └─ Use Case: VIP order tracked through MO system          │
│     but produced via Atelier workflow                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## ❓ **FAQ:**

### 1. **ถ้าต้องการผลิตแบบ Hybrid จะทำอย่างไร?**

**Answer:**
```
Hybrid = ใช้ทั้ง MO และ Atelier Jobs ร่วมกัน (แยกกัน, ไม่ใช่ระบบเดียว)

Example:
1. สร้าง MO สำหรับ body (OEM, 1000 pcs)
2. สร้าง Atelier Job สำหรับ decoration (Custom, 1000 pcs)
3. Link ทั้งสองเข้าด้วยกัน (via id_mo reference)

ไม่ใช่: สร้าง MO เดียวที่มี production_type='hybrid'
```

### 2. **Atelier Jobs สามารถ link กับ MO ได้หรือไม่?**

**Answer:**
```
✅ ได้! (Optional)

Use Case:
- VIP customer order ต้อง track ผ่าน MO (for accounting/planning)
- แต่ผลิตผ่าน Atelier workflow (for quality/flexibility)

Flow:
1. Create MO (OEM mode) → status='planned'
2. Create Atelier Job → select MO from dropdown
3. Atelier Job links to MO (id_mo field)
4. Production follows Atelier workflow
5. MO tracks overall progress

Benefit: Best of both worlds!
```

### 3. **MO ยังไม่มี Start Production workflow ใช่ไหม?**

**Answer:**
```
✅ ใช่! MO ยังไม่สมบูรณ์

Current State:
- MO create ✅
- MO list ✅
- MO start production ❌ (code มีแต่ไม่ได้ test)

Missing:
- Schedule UI
- Capacity planning
- MO → Graph Instance → Tokens flow (untested)

ตอนนี้ใช้ Atelier Jobs แทน (ที่ใช้งานได้แล้ว)
```

### 4. **ควรแก้ MO ให้เป็น OEM only หรือไม่?**

**Answer:**
```
✅ ควร! (Recommended)

Reasons:
1. Consistency: Atelier Jobs = atelier only, MO = oem only
2. Clarity: ไม่สับสน
3. Simplicity: ลด complexity
4. Validation: ง่ายกว่า

Changes:
1. Remove production_type dropdown from MO form
2. Hardcode production_type = 'oem' in backend
3. Update menu label: "Manufacturing Orders (OEM)"
```

---

## 📌 **สรุป:**

| System | Production Type | Use Case | Status |
|--------|----------------|----------|--------|
| **MO** | OEM (should hardcode) | Mass production, scheduled | ⚠️ Incomplete |
| **Atelier Jobs** | Atelier (hardcoded) | Custom, luxury, flexible | ✅ Complete |

**Recommendation:**
1. ✅ Hardcode MO = OEM only
2. ✅ Keep Atelier Jobs = Atelier only
3. ✅ Hybrid = Use both systems separately

**Next Action:**
- Fix MO to remove production_type selector
- Update MO form UI
- Document OEM workflow

---

**Status:** Design clarified  
**Decision:** Separate systems (MO=OEM, Atelier Jobs=Atelier)


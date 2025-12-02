# Task 24.9 — Work Card Print Engine Refactor (job_ticket_print)

## 1. เป้าหมายหลัก (Goal)

ทำให้หน้า **ใบงาน A4 (Work Card)** ของ Job Ticket:

- อ่านโค้ดง่าย ไม่เป็น spaghetti
- แยกชั้น **Data / Service / View** ให้ชัด
- เลิกใช้เทคนิค hack superglobals / require API ภายใน view
- แต่ **พฤติกรรมที่ผู้ใช้เห็นต้องเหมือนเดิม** (หน้าตา / layout / URL / flow การพิมพ์)

> สรุป: เปลี่ยน “วิธีสร้างข้อมูลและ render” ให้สะอาดขึ้น โดยไม่เปลี่ยนสิ่งที่ user เห็นหรือ flow การใช้งาน

---

## 2. ขอบเขต (Scope)

อยู่ในขอบเขตเฉพาะ **Work Card ของ Job Ticket** เท่านั้น:

- URL: `form/job_ticket_print.php&id={id_job_ticket}`
- File view ปัจจุบัน: `form/job_ticket_print.php`

ไม่ไปยุ่งกับ:

- MO / MO ETA / MO Assist
- Hatthasilpa Jobs API
- Job Ticket list / offcanvas view
- Node Behavior / Canonical Events

---

## 3. ภาพรวมสถาปัตยกรรมใหม่

### 3.1 ชั้น Service

สร้าง service ใหม่สำหรับเตรียมข้อมูลใบงาน:

- ไฟล์: `source/BGERP/JobTicket/JobTicketPrintService.php`
- Namespace: `BGERP\JobTicket`
- Responsibility: 
  - โหลดข้อมูล Job Ticket + Product + MO + Owner + Line Type
  - เตรียมโครงสร้างข้อมูลที่ view ใช้ได้เลย
  - ไม่ render HTML
  - ไม่แตะ superglobals

**เมธอดหลัก**

```php
class JobTicketPrintService
{
    public function __construct(\DatabaseConnection $db /* หรือ wrapper ที่ใช้ในระบบตอนนี้ */);

    /**
     * @param int $ticketId
     * @return array{ ok: bool, error?: string, error_code?: string, data?: array }
     */
    public function getPrintData(int $ticketId): array;
}
```

### 3.2 Form (job_ticket_print.php)

- `form/job_ticket_print.php` ทำหน้าที่เป็น **Controller + View แบบเบา ๆ**:
  - อ่าน `id` จาก `$_GET`
  - เรียก `JobTicketPrintService::getPrintData()`
  - ถ้า error → แสดง error page แบบเรียบง่าย
  - ถ้า ok → render HTML A4 ตาม layout ปัจจุบัน

- ห้าม:
  - แก้ไข / spoof ค่าใน `$_GET`, `$_REQUEST`, `$_POST`
  - `require` `source/job_ticket.php` เพื่อเรียก action ภายในไฟล์เดียวกัน
  - ทำงานที่ควรเป็นของ service (เช่น JOIN หลายตารางเองแบบกระจัดกระจาย)

---

## 4. รายละเอียด Implementation

### 4.1 JobTicketPrintService.php

**สร้างไฟล์ใหม่**

ที่ `source/BGERP/JobTicket/JobTicketPrintService.php`:

- ใช้ style ใกล้เคียงกับ service อื่นใน `BGERP\JobTicket` / `BGERP\MO`
- รองรับการใช้งานแบบ simple (ไม่ต้องผูก DI container ซับซ้อน)

**โครงสร้างข้อมูลที่ return**

`getPrintData()` ควรคืนค่า:

```php
[
  'ok' => true,
  'data' => [
    'ticket' => [
      'id' => int,
      'code' => string,
      'status' => string,
      'line_type' => 'classic'|'hatthasilpa'|'hybrid'|string,
      'created_at' => string|null,
      'due_date' => string|null,
      'qty_target' => int|null,
      'qty_completed' => int|null,
      'job_owner_id' => int|null,
      'job_owner_name' => string|null,
      'mo_code' => string|null,
      'production_type_label' => string,    // label ภาษาไทย/อังกฤษสั้น ๆ
    ],
    'product' => [
      'sku' => string|null,
      'name' => string|null,
      'variant' => string|null,   // สี/ไซซ์ ถ้ามี
    ],
    'work_card' => [
      'work_card_code' => string, // เช่น 'JT-20251129-001'
      'print_date' => string,     // วันที่พิมพ์
      'priority' => string|null,  // future use
    ],
  ]
];
```

**Logic ดึงข้อมูล (ตัวอย่าง)**

- `job_ticket` → ticket main info
- JOIN กับ `mo` เพื่อดึง `mo_code`, `qty`, `id_product`, `due_date`
- JOIN กับ `product` → sku, name
- JOIN กับ `users` หรือ table ที่ใช้เก็บช่าง/ผู้ใช้ → job_owner_name (ถ้ามี)

**Error Handling**

- ถ้าหา ticket ไม่เจอ → `ok = false`, `error_code = 'TICKET_NOT_FOUND'`
- ถ้า query พัง → log error แล้ว return `ok = false`, `error_code = 'DB_ERROR'`

---

### 4.2 Refactor form/job_ticket_print.php

เป้าหมาย: เปลี่ยนจาก “ทุกอย่างอยู่ในไฟล์เดียว + spoof API” → “เรียก Service ตรง ๆ”

**สิ่งที่ต้องลบออก**

- โค้ดที่ `require '../source/job_ticket.php'` หรือไฟล์อื่นเพื่อ call action ภายใน
- โค้ดที่แก้ไข `$_GET`, `$_REQUEST`, `$_POST`, `$_SERVER` เพื่อหลอก API
- โค้ด data-fetching ที่กระจัดกระจายหลายส่วน

**สิ่งที่ต้องทำแทน**

1. ที่ด้านบนสุดของไฟล์:

```php
<?php
require_once __DIR__ . '/../source/bootstrap.php'; // หรือไฟล์รวม config/database ที่ใช้ใน views อื่น

use BGERP\JobTicket\JobTicketPrintService;

// อ่าน id จาก GET
$ticketId = isset($_GET['id']) ? (int) $_GET['id'] : 0;

$service = new JobTicketPrintService($db /* หรือ helper ที่มีอยู่แล้ว */);
$result = $service->getPrintData($ticketId);

if (!$result['ok']) {
    // แสดง error page แบบง่าย ๆ
    http_response_code($result['error_code'] === 'TICKET_NOT_FOUND' ? 404 : 500);
    // render HTML error minimal
    // (อนุญาตให้ทำ inline, ไม่ต้องทำ template แยก)
    exit;
}

$data = $result['data'];
$ticket = $data['ticket'];
$product = $data['product'];
$workCard = $data['work_card'];
$isClassic = ($ticket['line_type'] === 'classic');
?>
```

2. ส่วนที่เหลือของไฟล์:
   - ใช้ `$ticket`, `$product`, `$workCard`, `$isClassic` ใน HTML เหมือนปัจจุบัน
   - **อย่าเปลี่ยน layout / ข้อความ / จำนวน rows** (คงแบบ manual 10 rows ตาม Task 24.8)
   - ตรวจให้แน่ใจว่าการอ้าง attribute ต่าง ๆ มาจาก `$ticket`, `$product`, `$workCard` เท่านั้น

---

### 4.3 QR Code (Phase A — Optional แต่แนะนำ)

> ถ้าในโปรเจกต์มี library สำหรับ QR อยู่แล้ว (เช่น `phpqrcode` หรือ helper อื่น) ให้ใช้  
> ถ้าไม่มี ให้ **เก็บ Implementation เดิมไว้ (JS หรือ placeholder text)**

**Design ที่แนะนำ**

- ใน service: สร้าง `work_card_code` (เช่น ใช้ ticket code / mo code + running)
- ใน view:
  - ถ้ามี QR helper → แสดง `<img src=".../qr.php?data=JT-xxxx">`
  - ถ้าไม่มีก็ fallback เป็นตัวหนังสือเหมือนเดิม

**ห้าม** ดึง QR จาก API ภายนอก (ต้องเป็น offline / self-hosted เท่านั้น)

---

## 5. Non-Goals (สิ่งที่ไม่ทำใน Task นี้)

- ไม่ออกแบบ layout ใหม่ (ใช้ layout ที่ได้จาก Task 24.8)
- ไม่เปลี่ยนจำนวนแถวในตาราง
- ไม่แตะ logic ของ Job Ticket / Hatthasilpa Jobs / Node Behavior
- ไม่เพิ่มฟีเจอร์ “บันทึกข้อมูลจากใบงานกลับเข้า ERP” (ใบงานยังเป็นกระดาษล้วน ๆ)

---

## 6. Acceptance Criteria

1. ✅ `form/job_ticket_print.php` **ไม่** มีการ `require source/job_ticket.php` หรือ spoof `$_GET` เพื่อเรียก action อีกต่อไป
2. ✅ มีไฟล์ `JobTicketPrintService.php` และ `getPrintData()` ใช้งานได้จริง
3. ✅ URL `index.php?p=job_ticket_print&id={id}` ทำงานเหมือนเดิม:
   - ใช้กับ Classic line ได้
   - ใช้กับ Hatthasilpa-origin tickets ได้ (ถ้ามี mapping)
4. ✅ Layout, ข้อความ, จำนวนแถว ในใบงาน **ไม่เปลี่ยนไปจากเวอร์ชั่นหลัง Task 24.8**
5. ✅ มี logging เมื่อเกิด error (เช่น ticket ไม่พบ, DB error) เพื่อใช้ debug
6. ✅ ไม่มี PHP warnings/notices บนหน้า print
7. ✅ ไม่มี side-effect แปลก ๆ กับ global state (เช่น refresh หน้าอื่นแล้วยังติด flag เดิม)

---

## 7. Notes to Future Tasks

- ถ้าอนาคตต้องการ “อ่านค่าจากใบงานเข้า ERP” (เช่น ช่างเขียนเวลาเริ่ม–จบลงกระดาษ แล้ว admin กรอกเข้าไป)  
  ให้ทำเป็น task แยก เช่น **Task 25.x – Work Card Feedback Entry UI**  
- ถ้าจะปรับ layout ให้หรูขึ้น (แบบ Luxury Edition) ให้ทำใน Task อื่น  
  อย่าเปลี่ยน layout ใน refactor task นี้

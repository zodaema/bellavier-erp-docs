คุณพูดถูกครับ รอบเมื่อกี้ผมดันโฟกัสแต่ส่วน Patch จนกลบ เนื้อหา task หลัก ไปเอง อันนี้คือความผิดพลาดของผมจริง ๆ 😓
เดี๋ยวผมเขียน ไฟล์ task25.2.md ฉบับเต็ม ให้ใหม่แบบที่:
	•	เก็บ เนื้อหา Task หลัก (Classic Output Dashboard) ครบเหมือนเดิม
	•	แล้วค่อยมี ส่วน Patch ClassicProductionStatsService ต่อท้าย
	•	ทั้งหมดอยู่ในไฟล์เดียว อ่านง่าย เอาไปสั่ง Cursor ต่อได้เลย

คุณสามารถเอาข้างล่างนี้ไป แทนทั้งไฟล์ /docs/super_dag/tasks/task25.2.md ได้เลยครับ

⸻


Task 25.2 — Product Classic Output Dashboard (Classic Production Overview)

Phase: 25 — Classic Line Stabilization  
Status: READY FOR IMPLEMENTATION  
Owner: System Engineering / Production Planning Module

⸻

🎯 Objective

สร้าง Dashboard สำหรับดูสถิติการผลิตใน Classic Line แบบรวมศูนย์บนหน้า “Product Detail” โดยใช้ข้อมูลจากตาราง `production_output_daily`

Dashboard นี้จะทำหน้าที่เป็น “Production Insight” ช่วยผู้วางแผนมองเห็นว่า:
- สินค้าแต่ละ SKU ถูกผลิตเฉลี่ยวันละกี่ชิ้น  
- วันไหนผลิตได้เท่าไร  
- ความเร็วในการผลิต (Lead time) ดีขึ้นหรือแย่ลงแค่ไหน

**ข้อสำคัญ**

- Classic Line **ไม่ใช้ ETA / Simulation / Node Behavior**
- Dashboard นี้ใช้ข้อมูลจาก **ผลลัพธ์จริง 100%** จาก `production_output_daily`

⸻

✔ Scope ครอบคลุม

1. API สำหรับดึงสถิติ
2. UI สำหรับ Dashboard อยู่ในหน้า Product Detail
3. Charts (line graph) + Summary Cards
4. CSV Export
5. Pagination / Range Filters (ช่วงเวลา 7/14/30/60/90 วัน)

⸻

📌 1. API — `product_stats_api.php?action=classic_dashboard`

**Request**

```http
GET product_stats_api.php?action=classic_dashboard&product_id=123&days=30

Response Structure (ตัวอย่าง)

{
  "ok": true,
  "product_id": 123,
  "days": 30,
  "summary": {
    "total_output": 481,
    "avg_per_day": 16,
    "best_day_qty": 42,
    "best_day_date": "2025-11-22",
    "worst_day_qty": 0,
    "worst_day_date": "2025-11-03"
  },
  "daily": [
    {
      "date": "2025-11-01",
      "qty": 12,
      "avg_lead_time_hours": 4.5
    },
    {
      "date": "2025-11-02",
      "qty": 19,
      "avg_lead_time_hours": 3.1
    }
  ],
  "lead_time_trend": [
    { "date": "2025-11-01", "hours": 4.5 },
    { "date": "2025-11-02", "hours": 3.1 }
  ]
}

⸻

📌 2. Backend Implementation (API)

ไฟล์: product_stats_api.php

ให้เพิ่ม case ใหม่:
	•	action=classic_dashboard

Validation
	•	product_id (int) ต้องมี
	•	days ต้องอยู่ในชุด: [7, 14, 30, 60, 90]
ถ้าไม่อยู่ ให้คืน 400 + error message

Query

SELECT date, qty, avg_lead_time_ms
FROM production_output_daily
WHERE id_product = ?
  AND date >= (CURRENT_DATE - INTERVAL ? DAY)
ORDER BY date ASC;

Compute ฝั่ง PHP
	•	total_output = sum(qty) ทั้งช่วง
	•	avg_per_day = total_output / days (round 2 ตำแหน่ง)
	•	best_day_qty, best_day_date = วันที่ qty สูงสุด
	•	worst_day_qty, worst_day_date = วันที่ qty ต่ำสุด
	•	avg_lead_time_hours ต่อวัน = avg_lead_time_ms / 3,600,000 (round 2 ตำแหน่ง)
	•	lead_time_trend = array ของ {date, hours} ตามตัวอย่าง

⸻

📌 3. UI — Product Detail Page (views/product.php)

ตำแหน่ง
	•	เพิ่ม Section ใต้ “Product Info”

Section Title

Classic Production Overview

Summary Cards ที่ต้องมี
	•	ยอดผลิตสะสม N วันล่าสุด (ตาม range ที่เลือก)
	•	ผลิตเฉลี่ยต่อวัน
	•	วันที่ผลิตสูงสุด (และจำนวน)
	•	วันที่ผลิตต่ำสุด (และจำนวน)

Chart
	•	Line chart: ปริมาณผลิตต่อวัน (qty)
	•	Lead time trend: optional (จะทำเป็น dataset ที่สอง หรือ toggle ทีหลังก็ได้)

Controls
	•	Range buttons:
	•	[7 วัน] [14 วัน] [30 วัน] [60 วัน] [90 วัน]
	•	ปุ่ม:
	•	[Export as CSV]

JS

สร้างไฟล์ใหม่: assets/javascripts/classic_product_dashboard.js

Loading Flow
	1.	เมื่อเปิด product.php (Product Detail) → script จะโหลดขึ้นมา
	2.	Script อ่านค่า product_id จาก hidden input เดิมในหน้า (ถ้ามี) หรือ element ที่มีอยู่แล้ว
	3.	ยิง request ไปยัง product_stats_api.php?action=classic_dashboard
	4.	Update summary cards
	5.	Render chart ด้วย Chart.js
	•	ใช้ config ธรรมดา (line chart)
	•	ไม่มีการ custom style แปลก ๆ (เพื่อแก้ไขง่ายในอนาคต)

⸻

📌 4. CSV Export

เพิ่ม endpoint ใหม่ใน product_stats_api.php:
	•	action=classic_dashboard_csv

Behavior
	•	Response เป็น text/csv + header download
	•	ชื่อไฟล์: classic_output_<product_id>_<days>d.csv

Columns

date,qty,avg_lead_time_hours

Query ใช้ชุดเดียวกับ classic_dashboard แล้ว map มาเป็น rows CSV

⸻

📌 5. Acceptance Criteria

Functional
	•	Dashboard แสดงข้อมูล Classic (production_output_daily) ได้ถูกต้อง
	•	เวลาโหลดในช่วง 30 วัน: ควร ≤ 200ms สำหรับ query + serialize (ไม่ต้องเก็บเป็น hard rule แต่เป็นเป้าหมาย)
	•	Selector ช่วงเวลา (7/14/30/60/90 วัน) ทำงานได้ และ chart/summary refresh ตามจริง
	•	CSV export ดาวน์โหลดได้ พร้อมข้อมูลตรงกับ dashboard

Non-Functional
	•	UI ไม่ block / ไม่ timeout
	•	Summary cards อ่านง่าย ไม่ต้องตีความเยอะ
	•	ไม่มี PHP warning / notice ใน logs จาก endpoint นี้

⸻

📌 6. Future-proofing
	•	Dashboard นี้สามารถใช้ต่อยอดไปสู่ phase “Forecasting” (เช่น ใช้ qty/day + lead time trend คำนวณ capacity ที่แท้จริง)
	•	สามารถเชื่อมกับ “Factory Capacity Planning” ได้ภายหลัง โดยไม่ต้องเปลี่ยน schema หลัก (แค่เพิ่ม field/ตารางเสริม)

⸻

📌 Deliverables
	1.	Updated API file: product_stats_api.php
	•	เพิ่ม action classic_dashboard
	•	เพิ่ม action classic_dashboard_csv
	2.	New JS file: assets/javascripts/classic_product_dashboard.js
	3.	Updated View file: views/product.php
	•	เพิ่ม Classic Production Overview section
	4.	CSV Export logic ครบตาม spec
	5.	Documentation file: docs/super_dag/tasks/results/task25_2_results.md

⸻
⸻

🔧 Appendix A — Patch ClassicProductionStatsService (Task 25.2 – Patch Classic Line Aggregation)

หมายเหตุ: Section นี้คือ เสริม เพื่อให้ Classic Line Aggregation แข็งแรงขึ้น
ให้ Cursor แก้ไฟล์ ClassicProductionStatsService.php ตาม step ด้านล่าง (ไม่เกี่ยวกับ oboe)

Target File

source/BGERP/Service/ClassicProductionStatsService.php

เป้าหมาย Patch
	1.	ปรับลำดับความสำคัญของการหาจำนวนผลิตให้ใช้ operator sessions ก่อน target_qty
	2.	ทำให้ aggregation เป็น idempotent ต่อ ticket (ไม่โดนนับซ้ำ)
	3.	เพิ่ม comment ให้ชัดเจนว่า OEM = Classic line ใน schema ปัจจุบัน

⸻

(1) recordCompleteFromTicket() — ปรับลำดับการเลือก completed quantity

ค้นหาในเมธอด recordCompleteFromTicket() บล็อกที่ใกล้คอมเมนต์:

// Get completed quantity
if ($completedQty === null || $completedQty <= 0) {
    // Fallback: Use target_qty or completed_qty from session
    $completedQty = (int)($ticket['target_qty'] ?? 0);
    
    // Try to get actual completed qty from operator sessions
    if ($completedQty <= 0) {
        $completedQty = $this->getCompletedQtyFromSessions($ticketId);
    }
}

ให้แทนที่ทั้งบล็อกด้วย:

// Get completed quantity
if ($completedQty === null || $completedQty <= 0) {
    // Prefer actual completed qty from operator sessions
    $completedQty = $this->getCompletedQtyFromSessions($ticketId);

    // Fallback: use target_qty from ticket if sessions have no data
    if ($completedQty <= 0) {
        $completedQty = (int)($ticket['target_qty'] ?? 0);
    }
}


⸻

(2) aggregateDailyOutputForDate() — ให้ใช้ sessions ก่อน target_qty

ในเมธอด aggregateDailyOutputForDate() ให้แก้ส่วนที่คำนวณ $qty ภายในลูป:

โค้ดเดิม (ตัวอย่าง):

$qty = (int)($row['target_qty'] ?? 0);
if ($qty <= 0) {
    $qty = $this->getCompletedQtyFromSessions($ticketId);
}

ให้เปลี่ยนเป็น:

// Prefer actual completed qty from operator sessions
$qty = $this->getCompletedQtyFromSessions($ticketId);
if ($qty <= 0) {
    // Fallback to target_qty if sessions have no data
    $qty = (int)($row['target_qty'] ?? 0);
}


⸻

(3) aggregateDailyOutput() — ทำให้ idempotent ต่อ ticket

ในเมธอด:

private function aggregateDailyOutput(
    int $productId,
    string $date,
    int $qty,
    int $leadTimeMs,
    int $totalLeadTimeMs,
    int $ticketId
): void

หลังบรรทัด:

$existing = $this->getDailyOutput($productId, $date);

ให้แทรก:

// If this ticket has already been aggregated for this date, do nothing (idempotent)
if ($existing) {
    $existingTicketIds = json_decode($existing['source_job_ticket_ids'] ?? '[]', true) ?: [];
    if (in_array($ticketId, $existingTicketIds, true)) {
        error_log("[ClassicProductionStatsService] Ticket {$ticketId} already aggregated for {$productId} on {$date}, skipping.");
        return;
    }
}

แล้วให้โครงสร้างท้าย ๆ ของเมธอดหน้าตาประมาณนี้ (ถ้าไม่ตรง ให้ Cursor ปรับให้ตรง):

if ($existing) {
    // Update existing row (additive aggregation)
    $newQty = $existing['qty'] + $qty;
    $newTotalLeadTimeMs = $existing['total_lead_time_ms'] + $totalLeadTimeMs;
    $newAvgLeadTimeMs = (int)($newTotalLeadTimeMs / $newQty);

    // Update ticket IDs JSON array
    $ticketIds = json_decode($existing['source_job_ticket_ids'] ?? '[]', true) ?: [];
    if (!in_array($ticketId, $ticketIds, true)) {
        $ticketIds[] = $ticketId;
    }

    $this->updateDailyOutput(
        $productId,
        $date,
        $newQty,
        $newAvgLeadTimeMs,
        $newTotalLeadTimeMs,
        $ticketIds
    );
} else {
    // Insert new row
    $this->insertDailyOutput(
        $productId,
        $date,
        $qty,
        $leadTimeMs,
        $totalLeadTimeMs,
        [$ticketId]
    );
}


⸻

(4) เพิ่ม comment ว่า OEM = Classic line

ที่ docblock ด้านบนของคลาส (ก่อน class ClassicProductionStatsService):

ตอนนี้มีประมาณนี้:

/**
 * Classic Production Statistics Service
 * 
 * Task 25.1: Product Output Analytics (Classic Line)
 * 
 * Purpose: Collect and aggregate production statistics for Classic Line tickets
 * - Stores daily aggregated production output per product
 * - Calculates lead time metrics
 * - Supports idempotent operations (no double-counting)
 * 
 * @package BGERP\Service
 * @version 1.0
 */

ให้เพิ่มบรรทัด:

 * Note: In the current schema, production_type = 'oem' is used for the Classic line.

ให้กลายเป็น:

/**
 * Classic Production Statistics Service
 * 
 * Task 25.1: Product Output Analytics (Classic Line)
 * 
 * Purpose: Collect and aggregate production statistics for Classic Line tickets
 * - Stores daily aggregated production output per product
 * - Calculates lead time metrics
 * - Supports idempotent operations (no double-counting)
 * 
 * Note: In the current schema, production_type = 'oem' is used for the Classic line.
 * 
 * @package BGERP\Service
 * @version 1.0
 */


⸻

หลังทำเสร็จให้ Cursor รัน:

php -l source/BGERP/Service/ClassicProductionStatsService.php

เพื่อเช็ค syntax อีกครั้ง

⸻

จบ Task 25.2:
	•	ส่วนบน = Spec หลักของ Classic Output Dashboard
	•	ส่วนล่าง = Patch เสริม ClassicProductionStatsService สำหรับ Cursor

---

**Status:** ✅ **COMPLETED** (2025-11-30)  
**Results:** [task25_2_results.md](results/task25_2_results.md)

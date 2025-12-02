# Task 25.1 — Product Output Analytics (Classic Line)
**Phase:** 25 — Production Statistics Layer  
**Status:** NEW  
**Owner:** Core ERP Team  
**Scope:** Classic Line only (no ETA, no token, no node behavior)

---

## 🎯 Objective
ออกแบบระบบสำหรับเก็บสถิติ “ปริมาณงานผลิตจริงต่อวัน” และ “เวลาที่ใช้จริงต่อ Product แต่ละ SKU” จาก Classic Line เพื่อให้:

- วางแผนการผลิตได้แม่นขึ้น  
- คำนวณกำลังการผลิตต่อวัน (Capacity per Day)  
- ใช้เป็นข้อมูลอ้างอิงสำหรับ Planning + MO Scheduling  
- รองรับ Inventory auto-increment  
- ใช้เป็นฐานข้อมูลสำหรับระบบในอนาคต (Demand Forecasting, Cost Calculation)

---

## 🔍 Key Insight
Classic Line **ไม่ต้องใช้ ETA / Token / Node Behavior**  
แต่ยังต้องเก็บ **สถิติเวลาการผลิตจริง** เพื่อคำนวณ work-rate รายวัน

ดังนั้น เราต้องเก็บเพียง:
- เมื่อไหร่ Job Ticket ถูก Start  
- เมื่อไหร่ Job Ticket ถูก Complete  
- ปริมาณผลิตจริง (completed_qty)  
- ช่างคนใดทำ (optional)  

---

## 📦 Deliverables (ใน Task นี้)

### 1. สร้างตารางใหม่ `production_output_daily`

เก็บข้อมูลสรุปการผลิตแบบ aggregated รายวัน (Classic เท่านั้น)

| Field               | Type    | Description                                   |
|---------------------|---------|-----------------------------------------------|
| id                  | bigint  | PK                                           |
| product_id          | bigint  | สินค้าที่ผลิต (FK → product.id_product)     |
| date                | date    | วันที่ผลิต (ตาม time zone โรงงาน)           |
| qty                 | int     | จำนวนผลิตสำเร็จต่อวัน (sum completed_qty)   |
| avg_lead_time_ms    | bigint  | เวลาผลิตเฉลี่ยต่อ 1 unit (weighted average) |
| total_lead_time_ms  | bigint  | เวลาผลิตรวมของวันนั้น (sum lead time ทุก lot) |
| source_job_ticket_ids | json  | job_ticket_id ที่ถูกใช้รวมในแถวนี้          |

ข้อกำหนด schema เพิ่มเติม:
- เก็บเฉพาะ **Classic Line** เท่านั้น (production_type = 'classic')
- Unique constraint: `(product_id, date)` เพื่อกัน duplicated rows
- Index แนะนำ:
  - `idx_prod_date (product_id, date)`
  - `idx_date (date)` สำหรับ dashboard รายวัน

---

### 2. Hook ใน `job_ticket.php`

เพิ่ม logic เมื่อ (เฉพาะ **Classic Line** เท่านั้น):
- เมื่อเกิด **state transition: planned → in_progress** (start action) → เรียก `ClassicProductionStatsService::recordStartFromTicket(ticket_id)`
- เมื่อเกิด **state transition: in_progress → completed** (complete action) → เรียก `ClassicProductionStatsService::recordCompleteFromTicket(ticket_id, completed_qty)`
- เมื่อ **cancel / restore** → เรียก `rollbackWhenCancelled(ticket_id)` หรือ re-aggregate เพื่อกัน double-count

หมายเหตุ:
- Hatthasilpa tickets ไม่ต้องเรียก service นี้ (ใช้ canonical timeline ฝั่ง Hatthasilpa แยกต่างหาก)

---

### 3. Service ใหม่ `ClassicProductionStatsService`

หน้าที่ (proposed interface):
- `recordStartFromTicket(int $ticketId): void`
  - อ่าน job_ticket จาก DB → เก็บ start timestamp (หากยังไม่เคยเก็บ)
  - ทำงานเฉพาะเมื่อ ticket เป็น Classic (production_type = 'classic')
- `recordCompleteFromTicket(int $ticketId, int $completedQty): void`
  - อ่าน start_at / completed_at จาก job_ticket
  - คำนวณ lead_time_ms สำหรับ lot นี้
  - อัปเดต/aggregate เข้า `production_output_daily` ของวัน `date(completed_at)`
  - ต้องเป็น **idempotent** (เรียกซ้ำไม่ควร double count)
- `aggregateDailyOutputForDate(
    int $productId,
    string $date
  ): void`
  - เอาไว้ใช้เวลา re-calc จาก raw job_ticket หากจำเป็น
- `rollbackWhenCancelled(int $ticketId): void`
  - ลบหรือปรับปรุงค่าใน `production_output_daily` เมื่อ ticket ถูก cancel / restore

ข้อกำหนดสำคัญ:
- Service ต้อง **ignore** tickets ที่ไม่ใช่ Classic (Hatthasilpa, Hybrid ฯลฯ)
- การคำนวณ `avg_lead_time_ms` ต้องเป็น **weighted average**: `total_lead_time_ms / qty`

---

### 4. Cron Script (optional)
`tools/recompute_classic_stats.php`  
สำหรับ re-calc ถ้าข้อมูลย้อนหลังมีการแก้ไข

---

### 5. API ใหม่
`source/product_stats_api.php`

Endpoints:
- `/daily-output?product_id=xxx&date=xxxx`
- `/product-capacity?product_id=xxx`
- `/lead-time-history?product_id=xxx`

---

### 6. UI — Product Detail Page
เพิ่มแท็บใหม่:
- **“Classic Line Productivity”**  
- รายการ: Capacity per day, average lead time, trend 30 วัน

## 🧱 Guard Rails / Constraints

เพื่อกัน "สายไฟหลอน" ในอนาคต ให้ถือเป็นกติกา:

1. Classic Only
   - ทุก logic ใน Task 25.1 ทำงานเฉพาะ job tickets ที่ `production_type = 'classic'`
   - ห้ามดึง Hatthasilpa เข้ามาปนในตาราง `production_output_daily`

2. One Source of Truth
   - แหล่งเวลาใช้จาก `job_ticket` เท่านั้น (ไม่ใช้ ETA, ไม่ใช้ canonical events)
   - `start_at` = ตอน ticket เปลี่ยนสถานะเป็น in_progress
   - `completed_at` = ตอน ticket เปลี่ยนสถานะเป็น completed

3. Idempotency & Double Count Safety
   - การ complete ซ้ำ, re-run cron, หรือ restore ต้องไม่ทำให้ qty ใน `production_output_daily` ถูกนับซ้ำ
   - ใช้ unique constraint + defensive update แทน insert ดิบ ๆ

4. Cancel / Restore Behavior
   - เมื่อ cancel ticket → ต้อง rollback ผลที่เคยสะสมไว้ในสถิติ (ถ้ามี)
   - เมื่อ restore หรือ re-open → ให้ re-calc จาก job_ticket ที่เป็นจริงอีกครั้ง (ไม่ใช้ค่าเดิมแบบมืดบอด)

5. Minimal Surface Area
   - Task นี้ไม่แตะ ETA Engine, Health Monitor, หรือ Hatthasilpa timeline เลย
   - ทำงานแยกขาดเหมือน "โลกขนาน" ของ Classic Line เท่านั้น

---

## 📌 Data Flow Summary

```
User Completes Classic Job Ticket
        ↓
job_ticket.php → invoke ClassicProductionStatsService
        ↓
write to production_output_daily
        ↓
Product stats dashboard reads aggregated data
```

---

## 📘 Acceptance Criteria

1. ระบบเก็บสถิติเวลาการผลิตจริงต่อวันได้  
2. 1 product = 1 ค่า average lead time ต่อวัน  
3. UI แสดง trend ย้อนหลังได้  
4. ไม่รบกวน Hatthasilpa Line  
5. ไม่แตะ ETA อีกแล้ว  
6. สถิติถูกต้องแม้มีการ cancel / restore คล้าย MO health logic

---

## 🚀 Ready for Implementation
Task 25.1 เป็นการวางรากฐานสำคัญสำหรับการวางแผนผลิตสินค้า Classic Line ทั้งหมดในอนาคต  
หลังจาก Task นี้เสร็จ → เราจะทำ Task 25.2 (Implementation) ต่อทันที

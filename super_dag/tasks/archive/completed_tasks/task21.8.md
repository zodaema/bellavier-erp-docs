# Task 21.8 – Bulk Integrity Validator + Session Overlap Rule + Unified DB API

**Status:** PLANNING  
**Date:** 2025-01-XX  
**Category:** SuperDAG / Canonical Events / Integrity / Batch Processing  
**Depends on:**  
- Task 21.1–21.7  
- `CanonicalEventIntegrityValidator.php`  
- `TimeEventReader.php`  
- `NodeBehaviorEngine.php`  
- `task21_7_results.md`  

---

## 1. Objective

เสริมสิ่งที่ยังขาดจาก Task 21.7 และต่อยอดให้ระบบสามารถ:

1. **Validate หลาย token แบบ batch**  
2. **เพิ่ม rule ที่ยังตกหล่น: Session Overlap Detection**  
3. **รวม DB API ให้ใช้รูปแบบเดียวกัน (PDO / mysqli) ตามมาตรฐาน DAG layer**  
4. **เพิ่ม CLI สำหรับสแกนทั้งระบบ**  
5. **เพิ่ม Dev Report แบบรวม** (ไม่ใช่แค่ token เดี่ยว)

Task 21.8 จะเป็นการ “ปิดวงกลมด้านความถูกต้องของ canonical events” ให้สมบูรณ์ที่สุดใน phase 21.x

---

## 2. Scope

### 2.1 In-Scope

#### ✔ เพิ่ม Validation Rule: Session Overlap  
ใน Task 21.7 ยังไม่มี rule ตรวจว่า session ซ้อนกันหรือไม่ เช่น:

- START 10:00  
- PAUSE 10:05  
- RESUME 10:03 ← ผิด  
- COMPLETE 10:06  

หรือ

- Session A = 10:00–10:05  
- Session B = 10:04–10:06 (ทับกัน) ← ผิด

ต้องเพิ่ม:

```
Rule 10: No overlapping sessions
```

โดยใช้ข้อมูลจาก `TimeEventReader::getTimelineForToken()`  
เพราะ timeline นั้นสร้าง session array มาพร้อมแล้ว:

```
sessions: [
  { start: ts1, end: ts2 },
  { start: ts3, end: ts4 },
]
```

ซึ่งสามารถ detect ได้ง่าย:

```
if (sessionA.end > sessionB.start) → overlap
```

#### ✔ Unified DB API  
ในตอนนี้:

- `CanonicalEventIntegrityValidator` ใช้ **mysqli**
- `TimeEventReader` ใช้ **PDO**
- `TokenEventService` ใช้ **PDO**

ทำให้เกิด inconsistency  
Task 21.8 ต้อง:

- เปลี่ยน `CanonicalEventIntegrityValidator` ให้ใช้ **PDO** ตาม DAG standard  
- หรืออย่างน้อยให้ทั้งสาม class รับ interface ของ DB ตัวเดียวกันจาก container

เลือกแบบ PDO เพราะ DAG layer ใช้ PDO เป็นมาตรฐาน

#### ✔ Bulk Validator (Batch Processing)

สร้าง class/function ใหม่:

```
php cli.php dag:validate-all --limit=500
php cli.php dag:validate-token-range --from=1000 --to=2000
php cli.php dag:validate-latest --hours=24
```

ความสามารถ:

- Validate tokens ทีละ batch เช่น 100/500/1000  
- เก็บผลเป็น summary  
- แสดงจำนวน token invalid, warning, error types  
- Export JSON รายงานสรุป (dev-only)

#### ✔ Dev Report (Aggregate View)

สร้างหน้า dev-only ใหม่:

```
/dev/debug/timeline-report.php
```

แสดง:

- อัตรา % integrity pass  
- อันดับปัญหาที่พบบ่อยที่สุด  
- List 50 token ที่ผิดร้ายแรง  
- ปัญหาคลาสสิก เช่น missing start, missing complete, pause-before-start ฯลฯ  
- Graph distribution ของ duration mismatch

เป้าหมายของ report คือช่วยให้คุณมองเห็น “ภาพรวมความแม่นยำของ canonical pipeline”

---

## 3. Design

### 3.1 Updated Ruleset (รวมของเดิม + ใหม่)

| Rule | Description | Severity |
|------|-------------|----------|
| 1 | START → PAUSE → RESUME → COMPLETE | error |
| 2 | START ต้องมาก่อน COMPLETE | error |
| 3 | PAUSE → RESUME pairing | error |
| 4 | event_time sorted | error |
| 5 | duration >= 0 | error |
| 6 | legacy sync mismatch > 5% | warning |
| 7 | canonical_type whitelist | error |
| 8 | event_type mismatch | error |
| 9 | timeline completeness (start_time missing) | error |
| **10 (ใหม่)** | **session overlap** | error |

---

### 3.2 Bulk Validator Class

ไฟล์ใหม่:  

`source/BGERP/Dag/BulkIntegrityValidator.php`

โครงสร้าง:

```php
class BulkIntegrityValidator
{
    protected PDO $db;
    protected CanonicalEventIntegrityValidator $validator;

    public function validateRange(int $from, int $to): array { ... }
    public function validateLatestHours(int $hours): array { ... }
    public function validateAll(int $limit = 5000): array { ... }
}
```

ผลลัพธ์จะรวม:

```
{
  total: 500,
  valid: 420,
  invalid: 80,
  errors: [...count by type...],
  warnings: [...],
  tokens: [...]
}
```

---

### 3.3 CLI Commands

```
php cli.php dag:validate-token --token=123
php cli.php dag:validate-all --limit=2000
php cli.php dag:validate-latest --hours=24
php cli.php dag:validate-range --from=100 --to=500
```

CLI จะ:

- เรียก BulkIntegrityValidator  
- dump summary  
- dump JSON ถ้าต้องการ

---

### 3.4 Dev Report Page

ไฟล์ใหม่:

```
public/dev/debug/timeline-report.php
```

ฟีเจอร์:

- แสดง summary card  
- Table ปัญหายอดฮิต  
- Table tokens ที่ผิด  
- ตัวกรอง:  
  - filter by error type  
  - filter by date  
- สีแสดง severity

---

## 4. Testing

### 4.1 Unit Tests
- Session overlap algorithm  
- Bulk validator split by range  
- DB adapter compatibility (PDO)  

### 4.2 Integration Tests
- Validate 100 tokens จาก dev environment  
- เทียบว่าผล bulk = sum ของการ validate ทีละ token  

---

## 5. Done Criteria

- CanonicalEventIntegrityValidator ถูก refactor ให้ใช้ PDO  
- Rule 10 (session overlap) เพิ่มสมบูรณ์  
- BulkIntegrityValidator ทำงาน  
- CLI commands ทำงาน  
- Dev Report Page ทำงาน  
- task21_8_results.md ถูกสร้างและสรุปเนื้อหาทั้งหมด  

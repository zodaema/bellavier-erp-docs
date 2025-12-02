# Task 23.4.1 — ETA Integration Patch & Simulation Refinement  
**Phase 23 — MO ETA Engine (Advanced ETA Model B)**  
**Status: Blueprint + Patch Instructions for AI Agent**  
**Author: ChatGPT (Bellavier Protocol v2.0)**  
**Length: ~450 lines**  

---

# 0. PURPOSE

Task 23.4.1 คือ “Patch รอบใหญ่” เพื่อทำให้ **MOLoadSimulationService** และ **MOLoadEtaService** สมบูรณ์แบบสำหรับ Phase 23 โดยตรงกับ ETA รุ่น Advanced (Model B)

เป้าหมายคือ:  
- ล้าง dependency ที่ไม่จำเป็น  
- แก้ unit ที่อาจหลอน  
- ทำ queue model ให้แข็ง  
- ทำให้ simulation layer + ETA layer “สอดคล้องกัน 100%”  
- ป้องกันสปาเก็ตตี้ก่อนเข้าสู่ Task 23.5–23.7  
- เป็น foundation สำหรับ Phase 24 (MO Timeline UI)

---

# 1. GOALS OF TASK 23.4.1

### 🎯 Objective A — Refine Simulation Layer  
- ตัด dependency ที่ไม่จำเป็น  
- ปรับ hours/ms logic ให้ตรงกับชั่วโมงทำงานจริง (work_hours_per_day)  
- ปรับ output ให้ clean ขึ้นสำหรับ ETA engine  

### 🎯 Objective B — Refine ETA Layer  
- ทำให้คิวต่อ station (work_center) “ไม่หลอก”  
- ปรับ sequencing logic ต่อ node → stage → MO  
- ปรับ delay propagation ให้สอดคล้องกับ canonical durations  

### 🎯 Objective C — Cross-Layer Sync  
- Node count  
- duration_per_token_ms  
- total_workload_ms  
- capacity_per_day_ms  
- p90-based risk logic  

ทั้งหมดต้อง align กันในสอง service:

1. `MOLoadSimulationService.php`
2. `MOLoadEtaService.php`

---

# 2. CHANGES REQUIRED IN MOLoadSimulationService

## 2.1 Remove Unused Dependency  
ลบทั้งหมดที่เกี่ยวกับ:

```
MOCreateAssistService
```

### เป้าหมาย  
- แยก simulation layer ออกจาก assist layer  
- ป้องกันปัญหาหลอนอนาคตหาก AssistService เปลี่ยนโครงสร้าง  
- ลด coupling ไม่จำเป็น  

### สิ่งที่ต้องลบ  
- `use BGERP\MO\MOCreateAssistService;`
- property `$assistService`
- instance creation ใน constructor

---

## 2.2 Fix capacity_per_hour_ms (avoid 24-hr average)

ตอนนี้ใช้:

```
capacity_per_hour_ms = capacity_per_day_ms / 24
```

แต่โรงงานทำงานแค่ **8 ชั่วโมง** → ต้อง derive จาก `work_hours_per_day`

### แผน patch:

```
capacity_per_hour_ms = capacity_per_day_ms / work_hours_per_day
```

### เหตุผล:  
- ETA จะใช้ค่า capacity_per_hour_ms ใน queue model  
- ถ้าใช้ 24 ชม. → ค่า capacity ถูกเฉลี่ยออกมากเกินจริง → ETA ผิด  

---

## 2.3 Confirm Qty Flow → OK (No Patch Required)

Simulation ใช้:

```
duration_per_token_ms * qty
```

ETA ใช้แบบเดียวกัน → ถูกแล้ว  
→ ไม่แพต

---

# 3. CHANGES REQUIRED IN MOLoadEtaService (Queue Model v1.1)

Queue model เป็นหัวใจของ ETA Model B

### ปัจจุบัน  
- ใช้ “workload_ms / capacity”  
- ไม่มี sequencing ที่แท้จริง  
- ไม่มี offset ต่อ node  
- ไม่มี wait time per station  

### ใน Task 23.4.1 จะเพิ่ม:  
1. sequential offset ต่อ node  
2. station queue (based on workload_ms, not per-token)  
3. delay propagation stage-by-stage  
4. earliest start & earliest finish model  

---

## 3.1 Node-Level ETA Fix

เพิ่มฟิลด์ที่ ETA ต้องมี:

```
node_start_at (predicted)
node_complete_at
node_wait_ms
node_execution_ms
node_delay_factor
```

### ภาพรวม logic:

```
node_start_at = max(prev_node_complete_at, station_available_at)
node_execution_ms = duration_per_token_ms * qty
node_complete_at = node_start_at + node_execution_ms
```

### station_available_at  
ใช้ค่าจาก simulation:

```
station_available_at = now + station_workload_ms / capacity_per_hour_ms
```

---

## 3.2 Stage-Level ETA Fix

Stages ต้องสรุปเวลาจาก "max node complete time" ภายใน stage

```
stage_start_at = first_node_start
stage_complete_at = max(all node_complete_at)
stage_delay_ms = stage_complete_at - ideal_stage_time
```

---

# 4. PATCH INTEGRATION SUMMARY

ใน Task 23.4.1 ให้ Agent ทำ:

---

## 🔧 Patch 1 — Remove AssistService (Simulation)

```
- use BGERP\MO\MOCreateAssistService;
- private $assistService;
- $this->assistService = new MOCreateAssistService($db);
```

---

## 🔧 Patch 2 — Fix capacity_per_hour_ms

เปลี่ยน:

```
$capacityPerHourMs = $capacityPerDayMs / 24;
```

เป็น:

```
$capacityPerHourMs =
    $capacityPerDayMs && $workHoursPerDay > 0
        ? (int)($capacityPerDayMs / $workHoursPerDay)
        : null;
```

---

## 🔧 Patch 3 — Add Node-Level ETA Logic (MOLoadEtaService)

เพิ่ม fields:

```
node_wait_ms
node_start_at
node_execution_ms
node_complete_at
node_delay_factor
```

และ logic ส่วน:

```
node_start_at = max(prev_node_complete_at, station_available_at)
station_available_at += node_execution_ms
```

---

## 🔧 Patch 4 — Add Stage-Level ETA Envelope

เพิ่ม:

```
best_case, normal_case, worst_case
stage_start_at
stage_complete_at
stage_risk_factor
```

---

## 🔧 Patch 5 — Add Validation & Error Handling

- ตรวจว่างานไม่มี routing → abort gracefully  
- ตรวจ station headcount = 0 → mark “unserviceable station”  
- ตรวจ p90 variance สูง → flag as delayed node  

---

# 5. UPDATED OUTPUT STRUCTURE FOR ETA API

ETA API (`mo_eta_api.php`) ต้องส่งกลับข้อมูลรูปแบบใหม่:

### Response Example

```
{
  "mo_id": 1234,
  "qty": 50,
  "eta_best": "2025-01-15 14:30:00",
  "eta_normal": "2025-01-15 17:20:00",
  "eta_worst": "2025-01-16 11:00:00",
  "stages": [
    {
      "stage_id": 1,
      "stage_start_at": "...",
      "stage_complete_at": "...",
      "nodes": [
        {
          "node_id": 100,
          "station_id": 8,
          "node_start_at": "...",
          "node_complete_at": "...",
          "wait_ms": 1800000,
          "execution_ms": 2400000,
          "delay_factor": 0.3
        }
      ]
    }
  ]
}
```

---

# 6. PATCH PROMPT FOR AI AGENT  
**(ให้ใส่ใน Cursor หรือ Factory Droid ตามระบบเดิม)**

```
Task: Implement ETA Integration Patch for Task 23.4.1

Files to modify:
- source/BGERP/MO/MOLoadSimulationService.php
- source/BGERP/MO/MOLoadEtaService.php

Requirements:
1. Remove all MOCreateAssistService dependency from MOLoadSimulationService.
2. Fix capacity_per_hour_ms = capacity_per_day_ms / work_hours_per_day.
3. Add Node-Level ETA fields to MOLoadEtaService:
   - node_wait_ms, node_start_at, node_execution_ms, node_complete_at, node_delay_factor
4. Implement sequential queue model:
   node_start_at = max(prev_node_complete, station_available_at)
5. Implement station availability rollover across nodes using total_workload_ms.
6. Add Stage-Level ETA envelope: stage_start_at, stage_complete_at, stage_risk_factor.
7. Ensure all new fields appear in API output.
8. Do not change existing API signature.
9. Keep logic pure (no DB writes).
```

---

# 7. WHAT TO DO AFTER THIS TASK

Task 23.4.2–23.4.4 จะต่อเนื่องจากนี้:

### 23.4.2 — ETA Audit Tool  
- Dev tool สำหรับตรวจ ETA correctness  
- ดู timeline VS simulation VS canonical  

### 23.4.3 — ETA Report Cache  
- ทำ caching level (5–30 mins)  
- ป้องกัน ETA คิดซ้ำบ่อย ๆ  

### 23.4.4 — ETA Stability & Debugging Layer  
- วิเคราะห์ delay patterns  
- เพิ่ม “reason” ของ ETA  

---

# 8. END OF FILE  



# Task 20.2.2 — System‑Wide Timezone & Timestamp Audit Framework

This document defines the audit plan for reviewing all timestamp, timezone, and datetime usages within Bellavier Group ERP, preparing for Phase 20.3 (Standardization & Refactor).

---
## 1. Objective
Ensure that **all timestamps in the system follow a unified and predictable standard**, enabling correct ETA calculations, SLA monitoring, manufacturing logs, claim logs, and multi‑tenant consistency.

### Goals:
- Reduce ambiguity between **server timezone**, **database timezone**, **PHP DateTime timezone**, and **JavaScript timezone**.
- Identify all APIs and modules that require migration to the **Central Timezone Helper Layer**.
- Prepare for global operations (Phase 21) with multi‑tenant timezone support.

---
## 2. Scope of Audit
The audit covers **100% of timestamp-producing or timestamp-consuming components**:

### 2.1 Backend (PHP)
- All API endpoints in the `/source/` directory
- All services in `BGERP/Service/*`
- All models in `BGERP/Model/*`
- All DAG/Token time-based operations (super_dag)
- All log writers (operation logs, QC logs, claim logs, command logs)
- All database writes involving datetime columns

### 2.2 Frontend (JavaScript)
- GraphDesigner timestamp preview
- All timestamp parsing in dashboard and PWA
- All Axios fetch timestamp handling
- Local Time vs Server Time differences

### 2.3 Database
- Columns: timestamp, datetime, date, created_at, updated_at, processed_at, qc_at, start_at, end_at
- Check default values (NOW(), CURRENT_TIMESTAMP)
- Check per-table timezone assumptions

---
## 3. Audit Methodology

### Step 1 — Static Code Scan
Search for all locations containing:
```
DateTime
Carbon
strtotime
NOW()
CURRENT_TIMESTAMP
Asia/Bangkok
new Date()
Date.parse
.toLocaleString
moment
```

### Step 2 — Dynamic API Inspection
Call every endpoint listed in `api_index.md` and record:
- format
- timezone offset
- consistency with server time

### Step 3 — Cross-Consistency Check
Determine:
- which modules assume **local TH time (GMT+7)**
- which modules assume **UTC**
- which modules assume **server time**

### Step 4 — Classify Findings (Critical → Low)
**Critical** — Affects manufacturing order timing, ETA engine, SLA, QC logs
**High** — Affects claim timestamps, customer service logs
**Medium** — Affects dashboard charts
**Low** — Display-only formatting issues

---
## 4. Deliverables
At the end of Task 20.2.2, system should have:

1. **Timestamp Usage Map** (timestamp_usage_map.md)
2. **Timezone Risk Report** (timezone_risk_register.md)
3. **List of APIs requiring refactor** (tz_refactor_targets.md)
4. **Migration Plan** for Phase 20.2.3 and 20.3

---
## 5. Acceptance Criteria
- Must identify at least **95%+** of timestamp usages
- Must categorize each usage into one of the 4 levels (Critical/High/Medium/Low)
- Must locate all timezone inconsistencies
- Must produce a dependency graph showing which modules depend on correct timezone logic
- No modifications to production code — *audit only*

---
## 6. Next Steps
Proceed to **Task 20.2.3 — Implement Central Timezone Helper Layer**, using the audit results of this task.
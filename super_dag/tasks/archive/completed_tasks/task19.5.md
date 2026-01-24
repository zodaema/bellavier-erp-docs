

# Task 19.5 – Time Modeling & SLA Pre-Layer (SuperDAG Time Foundation)

**Objective:**  
Establish the *time data foundation* required for Task 20 (ETA / SLA / Predictive Routing). Task 19.5 introduces **no scheduling logic** and **no ETA calculation**, but ensures that SuperDAG consistently captures and stores time-related information required by the future Time Layer.

This task is designed to be *safe* and strictly *non-invasive*:
- No routing logic changes  
- No machine/parallel behavior changes  
- No conditional engine changes  
- No execution semantics changes  

Task 19.5 focuses only on:
- Data structure  
- Normalization  
- Logging  
- UX input/output format  
- Documentation  

---

# 1. Scope

Task 19.5 covers:

- Standardizing how *Node Expected Time*, *SLA*, and *Actual Duration* are represented.
- Ensuring `flow_token` and `token_event` consistently record time-related values.
- Adding optional SLA configuration to nodes (without affecting routing).
- Normalizing timestamp and duration formats.
- Establishing a unified “Time Model Document” to be used by Task 20.
- Adding 3–5 test cases to verify correctness of the time layer.

Task 19.5 **does not**:

- Implement ETA prediction  
- Implement scheduling  
- Change token state machine  
- Add new routing behaviors  
- Introduce machine queue logic  

---

# 2. Deliverables

## 2.1 Time Model Document (NEW)
**File:** `docs/super_dag/time_model.md`

Must define:

### A. Time Concepts
- `expected_minutes` (existing)  
- `actual_minutes` (computed)  
- `sla_minutes` (new optional UX field)  
- `start_at`  
- `completed_at`  
- `duration_ms` (precise measurement)  
- `wait_window_minutes` (existing)  
- `deadline_at` (derived from SLA)

### B. Formula Definitions
- `actual_duration_ms = completed_at - start_at`
- `actual_minutes = actual_duration_ms / 60000`
- `sla_deadline_at = start_at + sla_minutes*60`

### C. Storage Locations
- `routing_node.expected_minutes`  
- `routing_node.sla_minutes`  
- `flow_token.start_at`  
- `flow_token.completed_at`  
- `flow_token.actual_duration_ms`  
- `token_event.duration_ms`  

### D. Handling Null / Missing Data
- When start_at missing → no SLA evaluation  
- When sla_minutes null → node has no SLA  
- When completed_at missing → no actual_duration_ms

---

## 2.2 Node SLA UX (Optional Input)

**File:** `graph_designer.js` (UPDATE)

Add to Node Property Panel:
- Field: **SLA (minutes)**
- For advanced users only (hidden unless “Show Advanced” is enabled).
- Stored in `routing_node.sla_minutes`.

No routing behavior changes; purely informational.

---

## 2.3 Database Migration (NEW)

**File:**  
`database/tenant_migrations/2025_12_19_time_model_foundation.php`

Add fields only if they do not exist:

### A. routing_node
- `sla_minutes` INT NULL DEFAULT NULL

### B. flow_token
- `start_at` DATETIME NULL  
- `completed_at` DATETIME NULL  
- `actual_duration_ms` BIGINT UNSIGNED NULL

### C. token_event
- `duration_ms` BIGINT UNSIGNED NULL  

No destructive changes.  
No renaming.  
No dropping columns.

---

## 2.4 Backend Updates (Safe Only)

### Update: `TokenLifecycleService.php`
- When token is started → set `start_at`
- When token is completed → set `completed_at` and `actual_duration_ms`
- When generating token_event → include `duration_ms`

### Update: `DAGRoutingService.php`
- DO NOT add scheduling logic.
- Only ensure `start_at` and `completed_at` are always recorded for node transitions.

### Update: `TokenStatusHelper.php` (optional)
- Add helper `calculateActualMinutes()` (non-invasive)

---

## 2.5 Documentation

### 1. `time_model.md`
Explains everything above.

### 2. `task19_5_results.md`
Must include:
- Summary of actual changes  
- Compatibility review  
- Verified that NO routing logic changed  
- Any fields skipped due to safety concerns  

---

## 2.6 Test Cases (3–5 Cases)

Add to `docs/super_dag/tests/time_model_test_cases.md`:

1. **TM-01: Basic Start + Complete Timestamps**
2. **TM-02: SLA_minutes Set, No Completion**
3. **TM-03: SLA_minutes + Actual Duration Calculation**
4. **TM-04: Legacy Token Without Start Timestamp**
5. **TM-05: Event Duration Logging**

All must pass with zero logic changes.

---

# 3. Implementation Guardrails

To ensure Task 19.5 does not accidentally affect routing:

### ❌ MUST NOT:
- Introduce any scheduling / ETA logic  
- Change routing decisions  
- Change order of node execution  
- Modify condition engine  
- Add new node types, behaviors  
- Change parallel / merge logic  
- Change job priority logic  

### ✔ MUST:
- Only log time  
- Only add optional SLA field  
- Only document formulas  
- Keep backward compatibility with all existing tokens  

---

# 4. Acceptance Criteria

✔ SLA input appears only under “Advanced View”  
✔ flow_token timestamps/logging consistent  
✔ token_event.duration_ms recorded  
✔ No routing logic changes  
✔ Database updated non-destructively  
✔ Time Model Document created  
✔ Test cases added  
✔ Summary in task19_5_results.md  

---

# End of Task 19.5 Specification
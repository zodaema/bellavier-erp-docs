# Time Model Test Cases

**Date:** 2025-12-18  
**Task:** 19.5 - Time Modeling & SLA Pre-Layer  
**Purpose:** Test cases for time data foundation (no ETA/SLA calculation logic)

---

## Test Case Categories

1. [Basic Start + Complete Timestamps](#tm-01-basic-start--complete-timestamps)
2. [SLA Minutes Set, No Completion](#tm-02-sla-minutes-set-no-completion)
3. [SLA Minutes + Actual Duration Calculation](#tm-03-sla-minutes--actual-duration-calculation)
4. [Legacy Token Without Start Timestamp](#tm-04-legacy-token-without-start-timestamp)
5. [Event Duration Logging](#tm-05-event-duration-logging)

---

## TM-01: Basic Start + Complete Timestamps

**Objective:** Verify that `start_at` and `completed_at` are correctly recorded when token starts and completes work.

**Preconditions:**
- Graph with operation node (Node A)
- Token spawned and ready

**Steps:**
1. Operator starts work on token (status: 'ready' → 'active')
2. Verify `flow_token.start_at` is set to current timestamp
3. Operator completes work (status: 'active' → 'completed')
4. Verify `flow_token.completed_at` is set to current timestamp
5. Verify `flow_token.actual_duration_ms` is calculated correctly

**Expected Results:**
- ✅ `start_at` is NOT NULL and equals work start time
- ✅ `completed_at` is NOT NULL and equals completion time
- ✅ `actual_duration_ms` = (completed_at - start_at) * 1000 (in milliseconds)
- ✅ `actual_duration_ms` > 0

**SQL Verification:**
```sql
SELECT 
    id_token,
    start_at,
    completed_at,
    actual_duration_ms,
    TIMESTAMPDIFF(MICROSECOND, start_at, completed_at) / 1000 AS calculated_ms
FROM flow_token
WHERE id_token = ?
  AND start_at IS NOT NULL
  AND completed_at IS NOT NULL;
```

**Expected:** `actual_duration_ms` matches `calculated_ms` (within 1 second tolerance)

---

## TM-02: SLA Minutes Set, No Completion

**Objective:** Verify that SLA field is stored correctly even when token hasn't completed yet.

**Preconditions:**
- Graph with operation node (Node A) with `sla_minutes = 45`
- Token spawned and ready

**Steps:**
1. Set `routing_node.sla_minutes = 45` for Node A
2. Operator starts work on token (status: 'ready' → 'active')
3. Verify `flow_token.start_at` is set
4. Token is still active (not completed)
5. Verify `flow_token.completed_at` is NULL
6. Verify `flow_token.actual_duration_ms` is NULL

**Expected Results:**
- ✅ `routing_node.sla_minutes = 45`
- ✅ `flow_token.start_at` is NOT NULL
- ✅ `flow_token.completed_at` is NULL (token still active)
- ✅ `flow_token.actual_duration_ms` is NULL (cannot calculate without completion)

**SQL Verification:**
```sql
SELECT 
    rn.sla_minutes,
    ft.start_at,
    ft.completed_at,
    ft.actual_duration_ms
FROM flow_token ft
JOIN routing_node rn ON rn.id_node = ft.current_node_id
WHERE ft.id_token = ?;
```

**Expected:** SLA is set, start_at is set, but completion fields are NULL

---

## TM-03: SLA Minutes + Actual Duration Calculation

**Objective:** Verify that actual duration is calculated correctly and can be compared to SLA.

**Preconditions:**
- Graph with operation node (Node A) with `sla_minutes = 45`
- Token spawned and ready

**Steps:**
1. Set `routing_node.sla_minutes = 45` for Node A
2. Operator starts work at 10:00:00
3. Operator completes work at 10:30:00 (30 minutes later)
4. Verify `flow_token.actual_duration_ms` is calculated
5. Calculate `actual_minutes = actual_duration_ms / 60000`
6. Compare `actual_minutes` vs `sla_minutes`

**Expected Results:**
- ✅ `start_at = '2025-12-18 10:00:00'`
- ✅ `completed_at = '2025-12-18 10:30:00'`
- ✅ `actual_duration_ms = 1800000` (30 minutes = 1,800,000 ms)
- ✅ `actual_minutes = 30`
- ✅ `actual_minutes < sla_minutes` (30 < 45) → SLA met ✅

**SQL Verification:**
```sql
SELECT 
    rn.sla_minutes,
    ft.start_at,
    ft.completed_at,
    ft.actual_duration_ms,
    ft.actual_duration_ms / 60000.0 AS actual_minutes,
    CASE 
        WHEN ft.actual_duration_ms / 60000.0 <= rn.sla_minutes THEN 'SLA_MET'
        ELSE 'SLA_VIOLATED'
    END AS sla_status
FROM flow_token ft
JOIN routing_node rn ON rn.id_node = ft.current_node_id
WHERE ft.id_token = ?
  AND ft.completed_at IS NOT NULL;
```

**Expected:** `actual_minutes = 30`, `sla_status = 'SLA_MET'`

---

## TM-04: Legacy Token Without Start Timestamp

**Objective:** Verify backward compatibility with tokens created before Task 19.5.

**Preconditions:**
- Legacy token (created before migration) with `start_at = NULL`
- Token is completed

**Steps:**
1. Find legacy token with `start_at IS NULL` and `completed_at IS NOT NULL`
2. Verify `flow_token.actual_duration_ms` is NULL (cannot calculate without start_at)
3. Attempt to complete token (should not fail)
4. Verify no errors occur

**Expected Results:**
- ✅ `start_at` is NULL (legacy token)
- ✅ `completed_at` is NOT NULL (token completed)
- ✅ `actual_duration_ms` is NULL (cannot calculate without start_at)
- ✅ No errors when querying or completing token
- ✅ Token can still be queried and displayed

**SQL Verification:**
```sql
SELECT 
    id_token,
    start_at,
    completed_at,
    actual_duration_ms,
    status
FROM flow_token
WHERE start_at IS NULL
  AND completed_at IS NOT NULL
LIMIT 1;
```

**Expected:** Token exists with NULL start_at and actual_duration_ms, but completed_at is set

---

## TM-05: Event Duration Logging

**Objective:** Verify that `token_event.duration_ms` is recorded for time-bounded events.

**Preconditions:**
- Graph with operation node
- Token spawned and ready

**Steps:**
1. Operator starts work (creates 'start' event)
2. Operator pauses work after 10 minutes (creates 'pause' event)
3. Verify `token_event.duration_ms` is NULL for 'start' event (instant event)
4. Verify `token_event.duration_ms` is set for 'pause' event (time-bounded)
5. Operator resumes work (creates 'resume' event)
6. Operator completes work after 5 more minutes (creates 'complete' event)
7. Verify `token_event.duration_ms` is set for 'complete' event

**Expected Results:**
- ✅ 'start' event: `duration_ms` is NULL (instant event)
- ✅ 'pause' event: `duration_ms` ≈ 600000 (10 minutes = 600,000 ms, within tolerance)
- ✅ 'resume' event: `duration_ms` is NULL (instant event)
- ✅ 'complete' event: `duration_ms` ≈ 300000 (5 minutes = 300,000 ms, within tolerance)

**SQL Verification:**
```sql
SELECT 
    id_event,
    event_type,
    event_time,
    duration_ms,
    duration_ms / 60000.0 AS duration_minutes
FROM token_event
WHERE id_token = ?
ORDER BY event_time ASC;
```

**Expected:** Instant events have NULL duration_ms, time-bounded events have non-NULL duration_ms

---

## Test Execution Notes

### Manual Testing

1. **TM-01:** Use Work Queue UI to start and complete a token
2. **TM-02:** Set SLA in Graph Designer, start token but don't complete
3. **TM-03:** Complete token within SLA time, verify calculation
4. **TM-04:** Query existing tokens from before migration
5. **TM-05:** Use Work Queue UI to pause/resume/complete, check events

### Automated Testing (Future)

- Unit tests for `TokenLifecycleService.completeToken()`
- Unit tests for `TokenWorkSessionService.setTokenStartTime()`
- Integration tests for time calculation formulas
- SQL tests for duration calculation accuracy

### Edge Cases

- **Token paused multiple times:** Verify duration calculation handles pauses correctly
- **Token moved between nodes:** Verify start_at is reset when entering new node
- **Concurrent token starts:** Verify no race conditions in start_at setting
- **Clock skew:** Verify timestamps use server time (NOW()) not client time

---

## Acceptance Criteria

✅ All 5 test cases pass  
✅ No routing logic changes (verified by regression tests)  
✅ Backward compatibility maintained (legacy tokens work)  
✅ Time calculations accurate (within 1 second tolerance)  
✅ No performance degradation (timestamps indexed)

---

**End of Test Cases**


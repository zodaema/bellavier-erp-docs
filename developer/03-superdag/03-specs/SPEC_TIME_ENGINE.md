# Time Engine Spec

**Bellavier Group ERP – DAG System**

This spec defines how time tracking works for Hatthasilpa single-piece work, including start/pause/resume, drift correction, over-limit detection, and error recovery.

---

## Purpose & Scope

- Defines time tracking model for single-piece Hatthasilpa work
- Handles start/pause/resume storage and drift correction
- Detects over-limit sessions using `default_expected_duration` from Work Center Behavior
- Explains server-side truth vs client-side display
- Provides recovery mechanisms for JS pause/closed tab scenarios
- **Out of scope:** Batch time tracking (covered in SPEC_WORK_CENTER_BEHAVIOR.md)

---

## Key Concepts & Definitions

- **Work Session:** Continuous time period when worker is actively working on a token
- **Base Work Seconds:** Accumulated work time stored in DB (snapshot)
- **Live Tail Seconds:** Additional seconds since last resume/start (calculated on-the-fly)
- **Drift:** Difference between client-side timer and server-side truth
- **Over-Limit:** Session duration exceeds threshold (e.g., 150% of `default_expected_duration`)
- **Anchor Time:** `resumed_at` (if exists) or `started_at` (used for live tail calculation)

---

## Data Model

### Table: `token_work_session` (Existing)

Current structure (from Time Engine v2):

| Field | Type | Description |
|-------|------|-------------|
| `id_session` | int PK | Primary key |
| `id_token` | int FK | References `flow_token.id_token` |
| `operator_user_id` | int | Worker user ID |
| `operator_name` | varchar(255) | Worker name (denormalized) |
| `status` | enum | 'active', 'paused', 'completed' |
| `started_at` | datetime | Session start time |
| `paused_at` | datetime | Last pause time |
| `resumed_at` | datetime | Last resume time |
| `work_seconds` | int | Accumulated work seconds (snapshot) |
| `work_minutes` | int | Calculated from work_seconds |
| `pause_count` | int | Number of pause events |
| `total_pause_minutes` | int | Total pause duration |
| `notes` | text | Session notes |
| `created_at` | datetime | Session creation |
| `updated_at` | datetime | Last update |

**Extensions Needed (Future):**

| Field | Type | Description |
|-------|------|-------------|
| `over_limit_flag` | tinyint(1) | Flag: session exceeded expected duration |
| `over_limit_threshold` | int | Threshold in seconds (from behavior) |
| `drift_correction_applied` | tinyint(1) | Flag: drift correction was applied |
| `last_client_sync` | datetime | Last client-side sync timestamp |

---

## Event → Screen → Data Flow

### Scenario: Single Job Running (Normal Flow)

**Step 1: Worker Starts Work**
- Screen: Work Queue → STITCH node
- Worker clicks "Start" → API: `dag_token_api.php?action=token_start&token_id=123`
- System:
  - Creates `token_work_session`:
    - `status = 'active'`
    - `started_at = NOW()`
    - `work_seconds = 0`
  - Updates `flow_token`: `status = 'active'`

**Step 2: Worker Pauses**
- Worker clicks "Pause" → API: `dag_token_api.php?action=token_pause&token_id=123`
- System (Time Engine):
  - Calculates live tail: `(NOW() - started_at)`
  - Updates session:
    - `status = 'paused'`
    - `paused_at = NOW()`
    - `work_seconds = base + live_tail` (snapshot)
    - `pause_count++`

**Step 3: Worker Resumes**
- Worker clicks "Resume" → API: `dag_token_api.php?action=token_resume&token_id=123`
- System:
  - Calculates pause duration: `(NOW() - paused_at)`
  - Updates session:
    - `status = 'active'`
    - `resumed_at = NOW()`
    - `total_pause_minutes += pause_duration`
  - Live tail calculation now uses `resumed_at` as anchor

**Step 4: Worker Completes**
- Worker clicks "Complete" → API: `dag_token_api.php?action=token_complete&token_id=123`
- System:
  - Final time calculation: `work_seconds = base + live_tail`
  - Updates session: `status = 'completed'`, `work_seconds = final_value`
  - Token moves to next node

### Scenario: Worker Forgot to Press Pause (Over-Limit Detection)

**Step 1: Long-Running Session**
- Worker started STITCH at 9:00 AM
- Behavior `default_expected_duration = 3600` (60 minutes)
- Worker forgot to pause → went to help other work
- Current time: 12:30 PM (3.5 hours = 12600 seconds)

**Step 2: Over-Limit Detection**
- System (periodic check or on work_queue load):
  - Queries active sessions
  - For each session:
    - Calculates current work_seconds
    - Compares with `default_expected_duration` from behavior
    - If `work_seconds > (default_expected_duration * 1.5)`:
      - Sets `over_limit_flag = 1`
      - Logs alert (not auto-failure)

**Step 3: Supervisor View**
- Work Queue (Supervisor) → Shows token with "Over Limit" badge
- Supervisor can:
  - View session details
  - Adjust time manually (correction)
  - Add comment: "Forgot to pause, went to help other work"

### Scenario: Offline Tab / JS Pause

**Step 1: Tab Closed During Active Session**
- Worker has active session (status='active', started_at=9:00 AM)
- Worker closes browser tab at 10:30 AM
- Client-side timer stops

**Step 2: Recovery on Tab Reopen**
- Worker reopens Work Queue at 11:00 AM
- System (server-side):
  - Queries session: `status='active'`, `started_at='9:00 AM'`
  - Calculates live tail: `(NOW() - started_at) = 7200 seconds`
  - Returns timer DTO:
    - `work_seconds = base + live_tail`
    - `status = 'active'`
    - `last_server_sync = NOW()`

**Step 3: Client-Side Sync**
- Client receives server timer DTO
- Client adjusts local timer to match server
- Drift correction applied (if client showed different time)

### Scenario: Worker Tries to Start Second Job (Conflict)

**Step 1: Worker Has Active Session**
- Worker has active session on Token A (status='active')
- Worker tries to start Token B

**Step 2: Conflict Detection**
- System checks: `SELECT COUNT(*) FROM token_work_session WHERE operator_user_id = ? AND status = 'active'`
- If count > 0:
  - Returns error: "You have an active session. Please complete or pause current work."
  - Prevents starting second job

**Step 3: Resolution**
- Worker must:
  - Complete Token A, OR
  - Pause Token A
- Then can start Token B

---

## Integration & Dependencies

- **Work Center Behavior:** `default_expected_duration` used for over-limit detection
- **Token Engine:** Time tracking tied to token state (active/paused/completed)
- **Work Queue UI:** Displays live timer and handles start/pause/resume actions
- **Supervisor Dashboard:** Shows over-limit alerts and allows manual correction

---

## Implementation Roadmap (Tasks)

1. **TE-01:** Stabilize core time storage (already done – refer to existing tasks)
   - `WorkSessionTimeEngine::calculateTimer()` is single source of truth
   - `TokenWorkSessionService` handles start/pause/resume
   - Reference: `docs/time-engine/tasks/task1_TIME_ENGINE_V2_CORE_ENGINE_COMPLETE.md`

2. **TE-02:** Implement over-limit detection based on behavior
   - Service: `TimeEngineOverLimitService::checkOverLimit(int $tokenId, int $expectedDuration)`
   - Compares current work_seconds with threshold (1.5x expected)
   - Sets `over_limit_flag` in session
   - Logs alert (not auto-failure)

3. **TE-03:** Add conflict checker (1 worker → 1 active token)
   - Service: `TimeEngineConflictService::checkActiveSession(int $operatorUserId)`
   - Prevents starting second job if active session exists
   - Returns error with current session details

4. **TE-04:** Add recovery UI hints for supervisors
   - Work Queue (Supervisor) → Show over-limit badges
   - Allow manual time adjustment
   - Allow adding correction notes
   - Display session history (start/pause/resume events)

5. **TE-05:** Implement drift correction (Phase 2)
   - Client-side timer syncs with server every 30 seconds
   - If drift > 5 seconds → auto-correct
   - Log drift events for analysis

6. **TE-06:** Add long idle session detection
   - If session active > 8 hours → flag as "needs review"
   - Not auto-failure, but alerts supervisor
   - Prevents accidental time accumulation

**Constraints:**
- Must preserve existing Time Engine v2 structure
- No breaking changes to `token_work_session` table
- Server-side truth is authoritative (client is display only)

---

**Source:** [REALITY_EVENT_IN_HOUSE.md](REALITY_EVENT_IN_HOUSE.md) Section 1.2, [DAG_Blueprint.md](DAG_Blueprint.md) Section 1.2  
**Related:** [SPEC_WORK_CENTER_BEHAVIOR.md](SPEC_WORK_CENTER_BEHAVIOR.md), [SPEC_TOKEN_ENGINE.md](SPEC_TOKEN_ENGINE.md)  
**Last Updated:** December 2025


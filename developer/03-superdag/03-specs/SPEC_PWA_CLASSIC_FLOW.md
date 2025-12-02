# PWA Classic Flow Spec

**Bellavier Group ERP – DAG System**

This spec defines how Classic/PWA scan-based flow works, scan event contracts, error recovery, and integration with Token Engine concepts.

---

## Purpose & Scope

- Describes how Classic line differs from Hatthasilpa (scan-based vs time-based)
- Defines PWA scan contracts: scan_in, scan_out, node transitions
- Specifies error recovery cases (LOST NODE, MISSING SCAN, REVERSE SCAN)
- Integrates with Token Engine concepts (same language, different entry points)
- **Out of scope:** PWA UI design details (only behavior contracts)

---

## Key Concepts & Definitions

- **Classic Line:** OEM, Classic mass production flow (scan-based, station-to-station)
- **PWA Scan:** Progressive Web App scanning workflow for Classic line
- **Scan In:** Event when worker scans token at station entry
- **Scan Out:** Event when worker scans token at station exit
- **Reverse Scan:** Scanning token at wrong station or out of sequence
- **Missing Scan:** Worker forgot to scan at required station
- **Safe-Scan:** Validation that prevents invalid scan sequences

---

## Data Model

### Table: `wip_log` (Existing - Classic Line)

Current structure (from Classic API):

| Field | Type | Description |
|-------|------|-------------|
| `id_wip_log` | int PK | Primary key |
| `id_job_ticket` | int FK | References `job_ticket.id_job_ticket` |
| `id_job_task` | int FK | References `job_task.id_job_task` |
| `event_type` | varchar(50) | 'start' (scan_in), 'complete' (scan_out) |
| `station_code` | varchar(50) | Station code where scan occurred |
| `sequence_no` | int | Task sequence number |
| `operator_id` | int | Operator user ID |
| `operator_name` | varchar(255) | Operator name (denormalized) |
| `scanned_at` | datetime | Scan timestamp |
| `deleted_at` | datetime | Soft delete |

**Extensions Needed (Future):**

| Field | Type | Description |
|-------|------|-------------|
| `id_token` | int FK | References `flow_token.id_token` (if using DAG tokens) |
| `scan_error_type` | enum | 'none', 'reverse', 'missing', 'duplicate' |
| `scan_error_resolved` | tinyint(1) | Flag: error was resolved |
| `scan_error_resolved_by` | int | User who resolved error |

### Scan Event Types

| Event Type | Description | Database Value |
|------------|-------------|----------------|
| scan_in | Token enters station | `event_type='start'` |
| scan_out | Token exits station | `event_type='complete'` |
| scan_error | Invalid scan detected | `event_type='error'` (future) |

---

## Event → Screen → Data Flow

### Scenario: Normal Scan Flow (Station → Station)

**Step 1: Worker Scans Token at Station 1**
- Screen: PWA → Scan barcode/QR code
- Worker scans token serial: "MA01-CLASSIC-20251201-00001"
- API: `classic_api.php?action=ticket_scan&event=in&station_code=STITCH&sequence_no=3`

**Step 2: Scan Validation**
- System validates:
  - Token exists and is at correct node
  - Previous step completed (sequence validation)
  - No duplicate scan_in for this step
- If valid → Creates `wip_log`:
  - `event_type = 'start'`
  - `station_code = 'STITCH'`
  - `sequence_no = 3`
  - `scanned_at = NOW()`

**Step 3: Worker Completes Work**
- Worker performs work (no time tracking)
- Worker scans token again (scan_out)
- API: `classic_api.php?action=ticket_scan&event=out&station_code=STITCH&sequence_no=3`

**Step 4: Scan Out Validation**
- System validates:
  - Must have scan_in first (using 'start' event_type)
  - No duplicate scan_out (using 'complete' event_type)
- If valid → Creates `wip_log`:
  - `event_type = 'complete'`
  - Token moves to next node

### Scenario: Reverse Scan (Wrong Station)

**Step 1: Worker Scans at Wrong Station**
- Token should be at Station 3 (STITCH)
- Worker scans at Station 5 (PACK)
- System detects: Token not at expected node

**Step 2: Error Detection**
- System:
  - Rejects scan
  - Returns error: "Token not at expected station"
  - Logs scan_error: `scan_error_type = 'reverse'`

**Step 3: Error Recovery**
- Supervisor can:
  - Manually correct token position
  - Or allow scan with override (audit log)

### Scenario: Missing Scan (Worker Forgot)

**Step 1: Worker Skips Station**
- Token should be scanned at Station 3 (STITCH)
- Worker forgot to scan → went directly to Station 4 (QC)

**Step 2: Missing Scan Detection**
- System detects: No scan_in for Station 3
- Blocks scan at Station 4: "Previous step must be completed"

**Step 3: Recovery**
- Supervisor can:
  - Add missing scan manually (with audit log)
  - Or allow scan with override (marks as missing_scan_recovered)

### Scenario: Double Scan (Duplicate)

**Step 1: Worker Scans Twice**
- Worker scans token at Station 3 (scan_in)
- Worker scans same token again at Station 3 (duplicate scan_in)

**Step 2: Duplicate Detection**
- System detects: Already scanned in for this step
- Returns error: "Already scanned in for this step"
- Logs scan_error: `scan_error_type = 'duplicate'`

**Step 3: Auto-Fix or Manual**
- System can auto-ignore duplicate (if within 5 seconds)
- Or requires supervisor override

---

## Integration & Dependencies

- **Token Engine:** Classic line uses same token concepts but different entry points (scan events vs time engine)
- **DAG Routing:** Scan events trigger token node transitions (same as Hatthasilpa, but scan-driven)
- **Work Center Behavior:** `supports_scan` flag indicates scan-based nodes
- **Trace API:** Scan events appear in token timeline

---

## Implementation Roadmap (Tasks)

1. **PWA-01:** Document current PWA DB/API
   - Review existing `wip_log` table structure
   - Document `classic_api.php` scan endpoints
   - Document `pwa_scan_api.php` (if separate)
   - Migration file: `database/tenant_migrations/YYYY_MM_pwa_scan_extensions.php`

2. **PWA-02:** Standardize scan event types
   - Define scan event enum: 'scan_in', 'scan_out', 'scan_error'
   - Map to existing `wip_log.event_type` values
   - Add `scan_error_type` field to `wip_log`

3. **PWA-03:** Implement error recovery patterns
   - Service: `PWAScanErrorService::detectError(string $tokenSerial, string $stationCode, int $sequenceNo)`
   - Error types:
     - REVERSE_SCAN: Token at wrong station
     - MISSING_SCAN: Previous step not scanned
     - DUPLICATE_SCAN: Already scanned at this station
   - Recovery: Manual override with audit log

4. **PWA-04:** Integrate with trace reports
   - Extend `trace_api.php` to show scan events
   - Display scan timeline (scan_in → work → scan_out)
   - Show scan errors and recovery actions

5. **PWA-05:** Add safe-scan validation
   - Service: `PWAScanValidationService::validateScan(int $tokenId, string $stationCode, int $sequenceNo)`
   - Checks:
     - Token at correct node
     - Previous step completed
     - No duplicate scans
   - Returns validation result with error details

6. **PWA-06:** Token Engine integration
   - Map scan events to token state transitions:
     - scan_in → Token enters node (status='active')
     - scan_out → Token completes node (status='completed')
   - Use same token model as Hatthasilpa (different entry point)

**Constraints:**
- Must preserve existing `wip_log` structure (additive only)
- Must not break existing Classic line workflows
- Scan events must integrate with Token Engine concepts

---

**Source:** [REALITY_EVENT_IN_HOUSE.md](REALITY_EVENT_IN_HOUSE.md) Section 1.3, [DAG_Blueprint.md](DAG_Blueprint.md) Section 1.3  
**Related:** [SPEC_TOKEN_ENGINE.md](SPEC_TOKEN_ENGINE.md), [SPEC_WORK_CENTER_BEHAVIOR.md](SPEC_WORK_CENTER_BEHAVIOR.md)  
**Last Updated:** December 2025


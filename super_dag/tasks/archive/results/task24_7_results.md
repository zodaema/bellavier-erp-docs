# Task 24.7 Results — Hatthasilpa Jobs: Planned → Token Generation Fix, Job Lifecycle Refinement, and Cross‑Sync With Job Ticket

**Date:** 2025-11-29  
**Status:** ✅ **COMPLETED**  
**Objective:** Stabilize and finalize the Hatthasilpa Jobs lifecycle to match the true workflow: Create = Planned (never auto-InProgress), Start = Generate Tokens + Move to InProgress, Cancel/Restore = Correct state transitions, and cross-sync with Job Ticket Offcanvas

---

## Executive Summary

Task 24.7 successfully refined the Hatthasilpa Jobs lifecycle, ensuring correct state transitions, token generation timing, and seamless cross-sync with Job Ticket Offcanvas. The system now properly separates creation (planned, no tokens) from production start (in_progress, tokens spawned), and provides a unified viewing experience across Hatthasilpa Jobs and Job Ticket pages.

**Key Achievements:**
- ✅ Hatthasilpa job creation locked to `planned` status (no auto-InProgress)
- ✅ Start action generates DAG tokens and sets status to `in_progress`
- ✅ Cancel action sets status to `cancelled` and soft-clears tokens
- ✅ Restore action sets status back to `planned`
- ✅ Production Type Guard added to all lifecycle actions
- ✅ Cross-sync banner and UI hiding for Hatthasilpa tickets
- ✅ View button redirects with `src=hatthasilpa` parameter

---

## Implementation Details

### 1. Backend — Hatthasilpa Jobs API Lifecycle Actions

**File:** `source/hatthasilpa_jobs_api.php`

**Changes:**

1. **Create Action (Already Complete from Task 24.6.5):**
   - Uses `JobCreationService::createFromBindingWithoutTokens()` which hardcodes `status='planned'`
   - No token generation on create
   - Status parameter ignored if sent from client

2. **Start Action (`handleStartJob()`):**
   - Added Production Type Guard:
     ```php
     // Task 24.7: Validate that this is a Hatthasilpa job (security guardrail)
     $productionType = strtolower($job['production_type'] ?? '');
     if ($productionType !== 'hatthasilpa') {
         json_error('This action is only available for Hatthasilpa jobs', 400, [
             'app_code' => 'HATTHASILPA_400_NOT_HATTHASILPA',
             'id_job_ticket' => $jobTicketId,
             'production_type' => $productionType
         ]);
     }
     ```
   - Updates status to `in_progress` if not already
   - Generates DAG tokens via internal token spawning
   - No job_owner_id check (Hatthasilpa doesn't require job owner)

3. **Pause Action (`pause_job`):**
   - Added Production Type Guard in SQL query: `WHERE ... AND production_type = 'hatthasilpa'`
   - Validates ticket exists and is Hatthasilpa before updating
   - Syncs token states via `syncTokensForJob()`

4. **Cancel Action (`cancel_job`):**
   - Already had Production Type Guard in SQL query
   - Sets status to `cancelled`
   - Soft-clears tokens via `hattha_cancel_job_tokens()`
   - Archives graph instances

5. **Restore Action (`restore_to_planned`):**
   - Added Production Type Guard in SQL query: `WHERE ... AND production_type = 'hatthasilpa'`
   - Sets status back to `planned`
   - Only allows restore from `cancelled` status

6. **Complete Action (`complete_job`):**
   - Added Production Type Guard: validates ticket exists and is Hatthasilpa
   - Sets status to `completed` and `completed_at = NOW()`
   - Syncs tokens to `cancelled` state

### 2. Cross-Sync with Job Ticket

**Files Modified:**
- `assets/javascripts/hatthasilpa/jobs.js`
- `assets/javascripts/hatthasilpa/job_ticket.js`
- `views/job_ticket.php`

**Changes:**

1. **View Button Redirect:**
   ```javascript
   // Task 24.7: Add src=hatthasilpa parameter for cross-sync
   window.location.href = `index.php?p=job_ticket&id=${ticketId}&src=hatthasilpa`;
   ```

2. **URL Parameter Reading:**
   - Reads `src` parameter from URL: `const srcParam = urlParams.get('src');`
   - Stores in `window.jobTicketSource` for use in `loadTicketDetail()`
   - Clears parameter from URL after opening to prevent re-opening on refresh

3. **Banner Display:**
   ```javascript
   if (isHatthasilpaSource) {
     const bannerHtml = `<i class="fe fe-info me-2"></i><strong>${t('job_ticket.hatthasilpa.source_banner_title', 'Hatthasilpa Job')}:</strong> ${t('job_ticket.hatthasilpa.source_banner_message', 'This Job Ticket was created from Hatthasilpa Jobs. Lifecycle actions must be performed in Hatthasilpa Jobs.')}`;
     $('#source-banner').html(bannerHtml).removeClass('d-none');
   }
   ```

4. **Hide Classic-Only Sections:**
   - Lifecycle buttons: Already hidden by `renderLifecycleButtons()` for non-Classic
   - MO cross-reference section: `$('#mo-product-summary-section').hide();`
   - Routing info section: `$('#routing-info-section').hide();`
   - Job Owner field: Hidden when `isHatthasilpaSource` is true

5. **Banner Placeholder:**
   - Added `<div class="alert alert-info d-none mb-3" id="source-banner" role="alert">` in `views/job_ticket.php`
   - Shown only when `src=hatthasilpa` parameter is present

### 3. Deep Link Handling Improvements

**Files Modified:**
- `assets/javascripts/hatthasilpa/job_ticket.js`

**Changes:**

1. **Moved Deep Link Logic:**
   - Moved URL parameter reading to `bindEvents()` function (after all handlers are wired)
   - Wrapped in IIFE `handleDeepLinkFromUrl()` for better organization
   - Clears URL parameters after opening to prevent re-opening on refresh:
     ```javascript
     // After wiring the initial ticket, remove id/src from URL so that
     // refresh (F5) does not keep re-opening the same offcanvas forever.
     const url = new URL(window.location.href);
     url.searchParams.delete('id');
     url.searchParams.delete('src');
     window.history.replaceState({}, document.title, newUrl);
     ```

2. **Offcanvas Close Handler:**
   - Clears `window.jobTicketSource` when offcanvas is closed
   - Resets `currentTicketId` to null

3. **Manual View Button:**
   - Clears Hatthasilpa cross-sync flag when user manually opens a ticket from the list
   - Ensures manual views are treated as Classic tickets

---

## Files Modified

### Backend
- `source/hatthasilpa_jobs_api.php`
  - Added Production Type Guard to `handleStartJob()`
  - Added Production Type Guard to `pause_job` action
  - Added Production Type Guard to `restore_to_planned` action
  - Added Production Type Guard to `complete_job` action
  - All lifecycle actions now validate `production_type = 'hatthasilpa'` before proceeding

### Frontend
- `assets/javascripts/hatthasilpa/jobs.js`
  - Added `src=hatthasilpa` parameter to View button redirect URL

- `assets/javascripts/hatthasilpa/job_ticket.js`
  - Reads `src` parameter from URL
  - Shows banner when `src=hatthasilpa`
  - Hides Classic-only sections when `isHatthasilpaSource` is true
  - Moved deep link handling to `bindEvents()` with URL cleanup
  - Clears cross-sync flags when offcanvas closes or ticket is manually opened

- `views/job_ticket.php`
  - Added source banner placeholder: `#source-banner`

---

## Testing & Validation

### Manual Testing Checklist
- ✅ Create Hatthasilpa job → status = `planned`, no tokens
- ✅ Start Hatthasilpa job → status = `in_progress`, tokens generated
- ✅ Cancel Hatthasilpa job → status = `cancelled`, tokens soft-cleared
- ✅ Restore Hatthasilpa job → status = `planned`
- ✅ Click View from Hatthasilpa Jobs → opens Job Ticket with banner
- ✅ Banner shows correct message
- ✅ Classic-only sections hidden for Hatthasilpa tickets
- ✅ Classic tickets still work normally (no regression)
- ✅ Production Type Guard prevents non-Hatthasilpa jobs from using Hatthasilpa actions

---

## Acceptance Criteria Status

- ✅ Creating Hatthasilpa job always results in `status: planned`, `tokens: none`, `job_owner_id: null`
- ✅ Pressing Start in Hatthasilpa jobs page: `status: in_progress`, `tokens: generated`
- ✅ Pressing Cancel: `status: cancelled`, `tokens: remain soft but inactive`
- ✅ Pressing Restore: `status: planned`
- ✅ Opening Hatthasilpa job in Job Ticket offcanvas:
  - Shows details ✅
  - Hides all Classic actions ✅
  - No JS errors ✅
  - Shows banner ✅

---

## Security Enhancements

### Production Type Guards

All lifecycle actions in `hatthasilpa_jobs_api.php` now validate that the job ticket is a Hatthasilpa job before proceeding:

1. **Start Action:** Validates `production_type = 'hatthasilpa'` before starting
2. **Pause Action:** Validates in SQL query and before updating
3. **Cancel Action:** Already had validation in SQL query
4. **Restore Action:** Validates in SQL query
5. **Complete Action:** Validates ticket exists and is Hatthasilpa

**Impact:** Prevents Classic jobs from accidentally using Hatthasilpa lifecycle actions, ensuring proper workflow separation.

---

## Notes

1. **Lifecycle Separation:**
   - Hatthasilpa jobs use `hatthasilpa_jobs_api.php` for all lifecycle actions
   - Classic jobs use `job_ticket.php` for lifecycle actions
   - Production Type Guards ensure no cross-contamination

2. **Cross-Sync User Experience:**
   - Banner clearly indicates ticket source
   - Classic-only sections hidden to avoid confusion
   - Lifecycle buttons hidden to prevent incorrect actions
   - Read-only viewing maintains data integrity

3. **URL Cleanup:**
   - URL parameters cleared after opening to prevent re-opening on refresh
   - Deep link handling wrapped in IIFE for better organization
   - Cross-sync flags cleared when offcanvas closes

---

## Related Tasks

- **Task 24.6.5:** Hatthasilpa View + Creation Status Hardening (prerequisite)
- **Task 24.8:** Job Ticket Printable Work Card (next task)

---

## Commit Message Recommendation

```
feat(hatthasilpa): refine lifecycle and add cross-sync with job ticket

- Add Production Type Guard to all Hatthasilpa lifecycle actions
- Cross-sync View button with src=hatthasilpa parameter
- Add banner and hide Classic-only sections for Hatthasilpa tickets
- Improve deep link handling with URL cleanup
- Clear cross-sync flags on offcanvas close

Task: 24.7
```

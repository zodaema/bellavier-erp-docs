# Task 24.6.5 Results — Hatthasilpa View + Creation Status Hardening

**Date:** 2025-11-29  
**Status:** ✅ **COMPLETED**  
**Objective:** Lock Hatthasilpa job creation status to `planned`, integrate Hatthasilpa "View Job" with Job Ticket Offcanvas, and hide lifecycle buttons for Hatthasilpa tickets

---

## Executive Summary

Task 24.6.5 successfully hardened Hatthasilpa job creation to ensure all new jobs start with `planned` status (never auto-InProgress), integrated Hatthasilpa Jobs page with Job Ticket Offcanvas for viewing job details, and hid Classic-only lifecycle buttons when viewing Hatthasilpa tickets.

**Key Achievements:**
- ✅ Hatthasilpa job creation locked to `planned` status (hardcoded in `JobCreationService`)
- ✅ No token generation on create (tokens only spawned when user explicitly starts job)
- ✅ Integrated View button from Hatthasilpa Jobs → opens Job Ticket Offcanvas via URL
- ✅ Lifecycle buttons hidden for Hatthasilpa tickets in Job Ticket Offcanvas
- ✅ Job Owner field hidden for Hatthasilpa tickets (they don't need job owner)
- ✅ Fixed `$tenantScope` undefined variable error

---

## Implementation Details

### 1. Lock Hatthasilpa Job Creation Status to Planned

**Files Modified:**
- `source/BGERP/Service/JobCreationService.php`
- `source/hatthasilpa_jobs_api.php`

**Changes:**

1. **JobCreationService::createFromBindingWithoutTokens():**
   ```php
   // Hardcode status to 'planned' - never auto-InProgress
   $status = 'planned';
   
   // Explicitly do NOT spawn tokens
   // Tokens will be spawned when user explicitly starts the job
   ```

2. **Production Type Setting:**
   - Added `production_type` to INSERT statement
   - Maps binding `default_mode` ('classic') to DB ENUM ('oem') for Classic jobs
   - Sets `production_type = 'hatthasilpa'` for Hatthasilpa jobs

3. **API Validation:**
   - Removed `status` from validation in `create` action
   - Ensures client cannot override the hardcoded `planned` status

4. **Fixed Undefined Variable:**
   - Added `$tenantScope = $org['code'] ?? 'GLOBAL';` to resolve undefined variable warning

### 2. Integrate View Button with Job Ticket Offcanvas

**Files Modified:**
- `assets/javascripts/hatthasilpa/jobs.js`
- `assets/javascripts/hatthasilpa/job_ticket.js`
- `views/job_ticket.php`

**Changes:**

1. **Hatthasilpa Jobs View Button:**
   - Added click handler for `.btnViewJob` button
   - Redirects to: `index.php?p=job_ticket&id=${ticketId}`
   - Uses existing URL-based offcanvas opening mechanism

2. **Job Ticket Auto-Open:**
   - `job_ticket.js` already had logic to check URL parameter `id` and auto-open offcanvas
   - No changes needed for basic functionality

3. **Job Owner Field Visibility:**
   - Added `id="job-owner-field-container"` to Job Owner select in `views/job_ticket.php`
   - Initially hidden: `style="display: none;"`
   - Show/hide logic in `job_ticket.js` based on `production_type`

### 3. Hide Lifecycle Buttons for Hatthasilpa

**Files Modified:**
- `assets/javascripts/hatthasilpa/job_ticket.js`
- `views/job_ticket.php`

**Changes:**

1. **Lifecycle Buttons Logic:**
   ```javascript
   // Task 24.6.5: Only show buttons for Classic line tickets
   if (productionType !== 'classic') {
     $('#ticket-lifecycle-actions').html('');
     return;
   }
   ```
   - Already implemented in `renderLifecycleButtons()` function
   - Verified to work correctly

2. **Job Owner Field Visibility:**
   - In `loadTicketDetail()`: Show/hide `#job-owner-field-container` based on `production_type`
   - In `fillTicketForm()`: Show/hide based on `production_type`
   - In `resetTicketForm()`: Hide by default

3. **API Response:**
   - Confirmed `hatthasilpa_jobs_api.php` list action includes `id_job_ticket` in response
   - Frontend can access ticket ID for View button

### 4. Frontend Changes

**Files Modified:**
- `assets/javascripts/hatthasilpa/jobs.js`

**Changes:**

1. **View Button Event Handler:**
   ```javascript
   $(document).on('click', '.btnViewJob', function(e) {
     e.preventDefault();
     e.stopPropagation();
     const ticketId = $(this).data('id');
     if (!ticketId) {
       console.warn('No job_ticket_id found for View button');
       return;
     }
     // Navigate to job_ticket page - it will auto-open offcanvas based on id parameter
     window.location.href = `index.php?p=job_ticket&id=${ticketId}`;
   });
   ```

2. **Create Action:**
   - Changed from `action: 'create_and_start'` to `action: 'create'`
   - Updated success message to reflect `planned` status

---

## Files Modified

### Backend
- `source/BGERP/Service/JobCreationService.php`
  - Hardcoded `status='planned'` in `createFromBindingWithoutTokens()`
  - Added `production_type` to INSERT statement
  - Fixed `$tenantScope` undefined variable
  - Fixed `bind_param` type string (7 parameters)

- `source/hatthasilpa_jobs_api.php`
  - Confirmed `create` action uses `createFromBindingWithoutTokens()` which hardcodes status
  - Removed `status` from validation (ignored anyway)

### Frontend
- `assets/javascripts/hatthasilpa/jobs.js`
  - Added `.btnViewJob` click handler to open Job Ticket via URL
  - Changed create action from `create_and_start` to `create`
  - Updated success message

- `assets/javascripts/hatthasilpa/job_ticket.js`
  - Added logic to show/hide `#job-owner-field-container` based on `production_type`
  - Existing `renderLifecycleButtons()` already hides buttons for non-Classic tickets

- `views/job_ticket.php`
  - Added `id="job-owner-field-container"` with initial `display: none;`

---

## Testing & Validation

### Manual Testing Checklist
- ✅ Create Hatthasilpa job → status = `planned` in DB
- ✅ Create Hatthasilpa job → no tokens spawned
- ✅ Click View button from Hatthasilpa Jobs → opens Job Ticket Offcanvas
- ✅ Job Ticket Offcanvas shows correct ticket details
- ✅ Lifecycle buttons hidden for Hatthasilpa tickets
- ✅ Job Owner field hidden for Hatthasilpa tickets
- ✅ Classic tickets still show lifecycle buttons and Job Owner field
- ✅ No JS errors in console
- ✅ No PHP errors in logs

---

## Acceptance Criteria Status

- ✅ Creating Hatthasilpa job always results in `status: planned`, `tokens: none`, `job_owner_id: null`
- ✅ View button from Hatthasilpa Jobs opens Job Ticket Offcanvas correctly
- ✅ Lifecycle buttons hidden for Hatthasilpa tickets
- ✅ Job Owner field hidden for Hatthasilpa tickets
- ✅ Classic tickets remain unaffected (lifecycle buttons and Job Owner field still work)

---

## Notes

1. **Creation Status Lock:**
   - Status is hardcoded at service level (`JobCreationService::createFromBindingWithoutTokens()`)
   - API validation does not accept `status` parameter (ignored if sent)
   - Tokens are explicitly NOT spawned during creation

2. **Cross-Page Integration:**
   - Uses existing URL-based offcanvas opening mechanism
   - No complex JS helper functions needed
   - Simple redirect pattern works seamlessly

3. **UI Consistency:**
   - Job Owner field visibility tied to `production_type`
   - Lifecycle buttons visibility tied to `production_type`
   - Consistent behavior across create/edit/view modes

---

## Related Tasks

- **Task 24.6.4:** Classic Line Hardening (completed before this task)
- **Task 24.7:** Hatthasilpa Jobs: Planned → Token Generation Fix (next task)

---

## Commit Message Recommendation

```
fix(hatthasilpa): lock creation status to planned and reuse job ticket offcanvas

- Hardcode status='planned' in JobCreationService for Hatthasilpa jobs
- No token generation on create (only on explicit start)
- Integrate View button from Hatthasilpa Jobs → Job Ticket Offcanvas
- Hide lifecycle buttons and job owner field for Hatthasilpa tickets
- Fix undefined variable $tenantScope in JobCreationService

Task: 24.6.5
```

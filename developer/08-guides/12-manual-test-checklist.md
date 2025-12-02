# Comprehensive Manual Test Checklist
## Bellavier Group ERP - Production Ready Testing

**Date:** _____________  
**Tester:** _____________  
**Environment:** ⬜ Development | ⬜ Staging | ⬜ Production

---

## 📋 Table of Contents
1. [Core Features](#core-features)
2. [Job Ticket Module](#job-ticket-module)
3. [QC Fail & Rework](#qc-fail--rework)
4. [Inventory Transactions](#inventory-transactions)
5. [Master Data Management](#master-data-management)
6. [Dashboard & Reporting](#dashboard--reporting)
7. [Mobile WIP](#mobile-wip)
8. [Permission & Security](#permission--security)

---

## 1. Core Features

### 1.1 Authentication & Authorization
- [ ] Login with valid credentials
- [ ] Login with invalid credentials (should fail)
- [ ] Logout functionality
- [ ] Session timeout handling
- [ ] Password reset flow (if applicable)

### 1.2 Navigation & UI
- [ ] All menu items load correctly
- [ ] Breadcrumbs display correctly
- [ ] i18n switching (Thai/English) works
- [ ] Responsive design on mobile/tablet
- [ ] Toast notifications display correctly

---

## 2. Job Ticket Module

### 2.1 Create Job Ticket
- [ ] Open Job Ticket page (`?p=atelier_job_ticket`)
- [ ] Click "New Ticket" button
- [ ] Select MO from dropdown
- [ ] Verify MO summary displays (product, qty, routing)
- [ ] Fill in required fields (qty, process mode, assigned user)
- [ ] Click Save
- [ ] Verify success toast appears
- [ ] Verify ticket appears in table

### 2.2 Edit Job Ticket
- [ ] Click edit button on existing ticket
- [ ] Verify modal opens with correct data
- [ ] Modify ticket fields (qty, notes, assigned user)
- [ ] Click Save
- [ ] Verify changes reflect in table
- [ ] Verify success toast appears

### 2.3 Delete Job Ticket
- [ ] Click delete button on ticket
- [ ] Confirm deletion in dialog
- [ ] Verify ticket removed from table
- [ ] Verify success toast appears

### 2.4 QR Code Generation
- [ ] Click QR code button on ticket
- [ ] Verify QR modal opens
- [ ] Verify QR code displays correctly
- [ ] Test QR code scanning (optional - verify format)

### 2.5 WIP Logs
#### Create Log
- [ ] Select a job ticket
- [ ] Click "Add Log" button
- [ ] Select event type (complete, rework, etc.)
- [ ] Select task from dropdown
- [ ] Enter quantity
- [ ] Select operator (or leave empty)
- [ ] Enter notes
- [ ] Click Save
- [ ] Verify log appears in table
- [ ] Verify success toast

#### Edit Log
- [ ] Click edit button on WIP log
- [ ] Verify modal opens with correct data
- [ ] Verify operator pre-selected (if set)
- [ ] Verify notes populated
- [ ] Modify values
- [ ] Click Save
- [ ] Verify changes reflect in table

#### Delete Log
- [ ] Click delete button on log
- [ ] Confirm deletion
- [ ] Verify log removed from table

### 2.6 Operator Field Edge Cases
- [ ] Create log with empty operator → Verify saves as NULL
- [ ] Edit log with empty operator → Verify doesn't auto-select
- [ ] Open operator dropdown → Verify no duplicates
- [ ] Verify users from tenant only (not cross-tenant)
- [ ] Select operator → Verify saves correctly

### 2.7 Notes Field
- [ ] Enter long text in notes → Verify saves correctly
- [ ] Enter special characters → Verify displays correctly
- [ ] Leave notes empty → Verify saves as empty string

### 2.8 MO Status Validation (October 2025)
#### Create Ticket from MO
- [ ] Create Ticket from MO status = `planned` → Should succeed
- [ ] Create Ticket from MO status = `released` → Should succeed
- [ ] Create Ticket from MO status = `in_progress` → Should succeed
- [ ] Create Ticket from MO status = `cancelled` → Should block with error
- [ ] Create Ticket from MO status = `completed` → Should block with error
- [ ] Verify error message displays when blocked

#### Edit Ticket with MO
- [ ] Edit Ticket of MO status = `in_progress` → Should succeed
- [ ] Edit Ticket of MO status = `completed` → Should succeed with warning
- [ ] Edit Ticket of MO status = `cancelled` → Should block with error
- [ ] Verify warning toast displays for completed MO

#### MO Auto Status Update
- [ ] Create first Ticket from MO → Verify MO status becomes `released`
- [ ] Start Task in Ticket → Verify MO status becomes `in_progress`
- [ ] Complete all Tasks → Verify MO status becomes `qc`
- [ ] Add rework Task → Verify MO status becomes `rework`

### 2.9 Permission-based UI (October 2025)
#### MO Page Buttons
- [ ] Login as `admin` → Verify sees all MO buttons
- [ ] Login as `production_operator` → Verify sees only Start/Stop/Complete
- [ ] Login as `planner` → Verify sees only Plan button
- [ ] Login as `viewer` → Verify sees no action buttons
- [ ] Verify buttons appear/disappear based on MO status

#### Job Ticket Permissions
- [ ] Login without `atelier.job.ticket` → Cannot access page
- [ ] Login with `atelier.job.ticket` → Can create/edit tickets
- [ ] Verify permission check works correctly

### 2.10 DataTable UI Improvements (October 2025)
- [ ] Verify pagination style matches other pages
- [ ] Verify Tasks table in offcanvas displays correctly
- [ ] Verify WIP Logs table in offcanvas displays correctly
- [ ] Open multiple tickets → Verify Tasks/Logs switch correctly
- [ ] Verify no CSS conflicts with theme

### 2.11 Number Formatting (October 2025)
- [ ] MO with integer qty (100) → Displays "100" (no decimal)
- [ ] MO with decimal qty (100.5) → Displays "100.5"
- [ ] Verify "{used}/{total} (Remain {remain})" formats correctly
- [ ] Verify all numeric displays are clean

---

## 3. QC Fail & Rework

### 3.1 Report QC Fail
- [ ] Open QC Rework page (`?p=qc_rework`)
- [ ] Click "Report QC Fail" button
- [ ] Fill in required fields:
  - [ ] Job Ticket (or manual entry)
  - [ ] Fail Code (e.g., SCRATCH, DENT)
  - [ ] Severity (Low/Medium/High)
  - [ ] Station Code
  - [ ] Defect Quantity
  - [ ] Root Cause
- [ ] Upload photo attachment (optional)
- [ ] Click Submit
- [ ] Verify success toast
- [ ] Verify event appears in list

### 3.2 View QC Fail Details
- [ ] Click on QC fail event in table
- [ ] Verify offcanvas opens with details
- [ ] Verify attachments display correctly
- [ ] Verify related rework tasks shown
- [ ] Test lightbox for photos

### 3.3 Create Rework Task
- [ ] From QC fail details, click "Create Rework Task"
- [ ] Fill in task details:
  - [ ] Action Type (Rework/Scrap)
  - [ ] Assign To
  - [ ] Due Date
  - [ ] Priority
  - [ ] Target Quantity
- [ ] Click Save
- [ ] Verify task appears in list

### 3.4 Update Rework Task
- [ ] Click on rework task
- [ ] Update status (pending → in_progress → completed)
- [ ] Add notes/updates
- [ ] Update completed quantity
- [ ] Verify changes save correctly

### 3.5 Filters & Search
- [ ] Filter by status (Open/Closed)
- [ ] Filter by severity (Low/Medium/High)
- [ ] Filter by station
- [ ] Date range filter
- [ ] Search by fail code

---

## 4. Inventory Transactions

### 4.1 GRN (Goods Receipt Note)
- [ ] Open GRN page (`?p=grn`)
- [ ] Click "Add GRN" button
- [ ] Select warehouse
- [ ] Select location
- [ ] Select material/SKU
- [ ] Verify UoM updates automatically
- [ ] Enter quantity (2 decimal places)
- [ ] Enter lot code (if applicable)
- [ ] Enter reference number
- [ ] Click Save
- [ ] Verify success toast
- [ ] Verify transaction appears in table
- [ ] Test Edit GRN
- [ ] Test Delete GRN

### 4.2 Issue (Stock Issue/Return)
- [ ] Open Issue page (`?p=issue`)
- [ ] Create new issue transaction
- [ ] Verify all fields work correctly
- [ ] Test Edit & Delete

### 4.3 Adjust (Stock Adjustment)
- [ ] Open Adjust page (`?p=adjust`)
- [ ] Create new adjustment
- [ ] Verify quantity can be negative (for write-offs)
- [ ] Test Edit & Delete

### 4.4 Transfer (Stock Transfer)
- [ ] Open Transfer page (`?p=transfer`)
- [ ] Create transfer (from warehouse/location → to warehouse/location)
- [ ] Verify creates both OUT and IN records
- [ ] Test Delete (should delete both records)

### 4.5 Stock On Hand
- [ ] Open Stock On Hand page (`?p=stock_on_hand`)
- [ ] Verify quantities display correctly (2 decimal places)
- [ ] Test filters (warehouse, location, SKU)
- [ ] Verify data matches ledger

### 4.6 Stock Card
- [ ] Open Stock Card page (`?p=stock_card`)
- [ ] Select SKU
- [ ] Verify transaction history displays
- [ ] Verify quantities formatted correctly
- [ ] Verify references display correctly

---

## 5. Master Data Management

### 5.1 Products
- [ ] Open Products page (`?p=products`)
- [ ] Create new product
- [ ] Upload product image
- [ ] Test edit product
- [ ] Test lightbox for images
- [ ] Test delete product

### 5.2 Materials
- [ ] Open Materials page (`?p=materials`)
- [ ] Create new material
- [ ] Upload asset/image
- [ ] Add lot tracking
- [ ] Test edit & delete
- [ ] Test lightbox for images

### 5.3 UoM (Unit of Measure)
- [ ] Open UoM page (`?p=uom`)
- [ ] Create new UoM
- [ ] Test edit & delete
- [ ] Verify i18n works

### 5.4 Warehouses
- [ ] Open Warehouses page (`?p=warehouses`)
- [ ] Create new warehouse
- [ ] Test edit & delete

### 5.5 Locations
- [ ] Open Locations page (`?p=locations`)
- [ ] Create new location
- [ ] Link to warehouse
- [ ] Test edit & delete

---

## 6. Dashboard & Reporting

### 6.1 Dashboard Main
- [ ] Open Dashboard (`?p=dashboard`)
- [ ] Verify KPI cards load:
  - [ ] Yield (QC Pass)
  - [ ] Average Lead Time
  - [ ] Defect Rate
- [ ] Verify Production Timeline chart
- [ ] Verify Daily Activity feed
- [ ] Verify Job Ticket Snapshot

### 6.2 QC Metrics Widget
- [ ] Verify QC Fail & Rework Metrics widget displays
- [ ] Verify summary cards:
  - [ ] Open QC Fails
  - [ ] Defect Qty (30d)
  - [ ] Active Rework
  - [ ] Avg Turnaround
- [ ] Verify Severity Breakdown chart
- [ ] Verify Top Fail Codes list
- [ ] Verify Defect Rate Trend chart (7 days)

### 6.3 Auto-refresh
- [ ] Wait 5 minutes
- [ ] Verify dashboard auto-refreshes
- [ ] Verify no errors in console

---

## 7. Mobile WIP

### 7.1 Mobile WIP Page
- [ ] Open Mobile WIP page (`?p=atelier_wip_mobile`)
- [ ] Scan QR code (or enter ticket code manually)
- [ ] Verify ticket details load
- [ ] Select event type
- [ ] Verify QC Fail fields show/hide correctly
- [ ] Fill in QC Fail data (if applicable)
- [ ] Upload photos
- [ ] Submit WIP log
- [ ] Verify syncs with web view

### 7.2 Offline Mode (if PWA implemented)
- [ ] Turn off Wi-Fi
- [ ] Create WIP log
- [ ] Verify saved to IndexedDB
- [ ] Turn on Wi-Fi
- [ ] Verify syncs automatically

---

## 8. Permission & Security

### 8.1 Permission Checks
- [ ] Login as different user roles
- [ ] Verify menu items show/hide based on permissions
- [ ] Try accessing pages without permission (should redirect/deny)
- [ ] Verify actions require correct permissions

### 8.2 Data Isolation
- [ ] Switch between tenants (if multi-tenant)
- [ ] Verify data doesn't leak between tenants
- [ ] Verify user sees only their organization's data

---

## 9. Edge Cases & Error Handling

### 9.1 Error Scenarios
- [ ] Submit form with missing required fields
- [ ] Enter invalid data (negative quantities, etc.)
- [ ] Try to delete record that has dependencies
- [ ] Test with network offline (verify error messages)
- [ ] Test with invalid API responses

### 9.2 Data Validation
- [ ] Decimal places: Verify quantities show 2 decimal places
- [ ] Date formats: Verify consistent date display
- [ ] Timezone: Verify times are Bangkok timezone
- [ ] Empty states: Verify "No data" messages display

---

## 10. Performance

### 10.1 Page Load Times
- [ ] Dashboard loads < 3 seconds
- [ ] DataTable pages load < 2 seconds
- [ ] No console errors

### 10.2 Large Datasets
- [ ] Test with 1000+ records in tables
- [ ] Verify pagination works correctly
- [ ] Verify search performance acceptable

---

## 📊 Test Results Summary

**Total Test Cases:** _______  
**Passed:** _______  
**Failed:** _______  
**Skipped:** _______

### Critical Issues Found:
1. _______________________________________
2. _______________________________________
3. _______________________________________

### Minor Issues Found:
1. _______________________________________
2. _______________________________________

### Notes:
_______________________________________
_______________________________________
_______________________________________

---

## ✅ Sign-off

**Test Completed By:** _____________  
**Date:** _____________  
**Status:** ⬜ Ready for Production | ⬜ Needs Fixes | ⬜ Blocked

**Approved By:** _____________  
**Date:** _____________


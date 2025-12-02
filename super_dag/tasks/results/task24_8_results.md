# Task 24.8 Results — Job Ticket Printable Work Card (A4)

**Date:** 2025-11-29  
**Status:** ✅ **COMPLETED**  
**Objective:** Create A4 printable work card for Job Tickets that can be used in actual production workflow, with separate layouts for Classic Line (DAG routing) and Hatthasilpa Line (simplified template)

---

## Executive Summary

Task 24.8 successfully implemented a complete A4 printable work card system for Job Tickets, providing clean, print-friendly layouts for both Classic Line and Hatthasilpa Line tickets. The system integrates seamlessly with the existing Job Ticket UI, allowing operators to print work cards directly from the offcanvas detail view.

**Key Achievements:**
- ✅ Created A4 print layout with proper page setup and print media queries
- ✅ Implemented separate layouts for Classic Line (DAG routing nodes) and Hatthasilpa Line (fixed template)
- ✅ Integrated Print button in Job Ticket Offcanvas
- ✅ Loads all necessary data (ticket, product, MO, routing nodes)
- ✅ QR Code placeholder for future integration
- ✅ Checklist and Notes sections for manual completion
- ✅ Print-friendly CSS with proper page breaks

---

## Implementation Details

### 1. Page Definition & Route

**File:** `page/job_ticket_print.php`

**Changes:**
- Created minimal page definition for print view
- Uses minimal CSS (only print stylesheet)
- No JavaScript dependencies (print view only)

**Route Added:**
- `index.php`: Added `'job_ticket_print' => 'job_ticket_print.php'` to routes array

### 2. Print Stylesheet

**File:** `assets/stylesheets/job_ticket_print.css`

**Features:**
1. **A4 Page Setup:**
   ```css
   @page {
       size: A4;
       margin: 15mm;
   }
   ```

2. **Print Media Queries:**
   - Hides navigation, sidebar, footer, and print button when printing
   - Full width layout for print
   - Page break prevention for important sections

3. **Layout Components:**
   - Header with ticket code, production line, date, QR placeholder
   - Product summary grid (2 columns)
   - Operation table with proper column widths
   - Checklist section
   - Notes section with large text area

4. **Screen Preview:**
   - Max-width: 210mm (A4 width)
   - Centered with shadow for preview
   - Print button fixed in top-right corner

### 3. Print View Implementation

**File:** `views/job_ticket_print.php`

**Features:**

1. **Data Loading:**
   - Loads job ticket with all related data (MO, product, routing graph)
   - Fetches job owner name from core DB
   - Loads routing nodes for Classic Line tickets

2. **Header Section:**
   - Work Card title
   - Ticket code (large, prominent)
   - Production line name (Classic Line / Hatthasilpa Line)
   - Created date
   - MO code (if linked)
   - QR Code placeholder with ticket ID text

3. **Product Summary:**
   - Product code (SKU)
   - Product name
   - Target quantity with unit
   - Job Owner (or blank space for manual entry)

4. **Operation Table:**
   
   **Classic Line:**
   - Loads routing nodes from graph (ordered by `sequence_no`)
   - Filters only `operation` and `qc` node types
   - Displays node name as operation/work center
   - Empty columns for: assigned person, start time, end time, quantity, signature
   
   **Hatthasilpa Line:**
   - Fixed 5-step template:
     1. เตรียมชิ้นงาน / วัตถุดิบ
     2. ประกอบโครงสร้างหลัก
     3. เย็บ / ขึ้นรูปหลัก
     4. เก็บงาน / ตรวจสอบ
     5. QC สุดท้าย / ทำความสะอาด
   - Empty columns for: assigned person, start time, end time, notes, signature

5. **Checklist Section:**
   - [ ] QC ผ่าน
   - [ ] บรรจุหีบห่อเรียบร้อย
   - [ ] แนบอุปกรณ์ครบ (ถ้ามี)
   - [ ] ทำความสะอาดผิวงานแล้ว

6. **Notes Section:**
   - Large text box for manual notes/remarks
   - For defect tracking, corrections, etc.

### 4. Print Button Integration

**Files Modified:**
- `views/job_ticket.php`
- `assets/javascripts/hatthasilpa/job_ticket.js`

**Changes:**

1. **Print Button in Offcanvas:**
   ```html
   <button class="btn btn-outline-secondary btn-sm btn-luxury" id="btn-print-job-ticket" title="Print Work Card">
       <i class="fe fe-printer"></i>
   </button>
   ```
   - Added next to refresh button in offcanvas header
   - Available for all ticket types (Classic and Hatthasilpa)

2. **JavaScript Handler:**
   ```javascript
   $(document).on('click', '#btn-print-job-ticket', function() {
     const ticketId = currentTicketId;
     if (!ticketId) {
       notifyError(t('job_ticket.print.error.no_ticket', 'No ticket selected'), t('common.error', 'Error'));
       return;
     }
     const url = 'index.php?p=job_ticket_print&id=' + encodeURIComponent(ticketId);
     window.open(url, '_blank');
   });
   ```
   - Opens print view in new tab/window
   - Uses standard browser print dialog (Ctrl+P)

---

## Files Created

### New Files
1. **`page/job_ticket_print.php`** (14 lines)
   - Page definition for print view
   - Minimal configuration

2. **`assets/stylesheets/job_ticket_print.css`** (215 lines)
   - Complete A4 print stylesheet
   - Print media queries
   - Layout components

3. **`views/job_ticket_print.php`** (292 lines)
   - Complete print view implementation
   - Data loading and rendering
   - Classic and Hatthasilpa layouts

---

## Files Modified

### Backend
- `index.php`
  - Added route: `'job_ticket_print' => 'job_ticket_print.php'`

### Frontend
- `views/job_ticket.php`
  - Added Print button in offcanvas header

- `assets/javascripts/hatthasilpa/job_ticket.js`
  - Added Print button click handler

---

## Layout Design

### Header Zone (Top)
- Logo placeholder / Company name (left)
- Work Card title + Ticket code (left)
- Production line + Date + MO code (left)
- QR Code placeholder (right)

### Product Summary Block (2 columns)
- Product code (SKU)
- Product name
- Target quantity
- Job Owner

### Operation Table (Main Content)
**Classic Line:**
- Columns: Step | Operation/Work Center | ผู้รับผิดชอบ | เวลาเริ่ม | เวลาเสร็จ | จำนวนที่ทำ | ลายเซ็น
- Rows: One per routing graph node (operation/qc types only)

**Hatthasilpa Line:**
- Columns: Step | Operation | ผู้รับผิดชอบ | เวลาเริ่ม | เวลาเสร็จ | หมายเหตุ | ลายเซ็น
- Rows: Fixed 5-step template

### Checklist Section
- 4 checkboxes for quality/completion checks

### Notes Section
- Large text area for manual notes

---

## Testing & Validation

### Manual Testing Checklist
- ✅ Open print view via URL: `index.php?p=job_ticket_print&id=XXX`
- ✅ A4 layout displays correctly (210mm width, proper margins)
- ✅ Classic Line: Operation table shows routing nodes in sequence
- ✅ Hatthasilpa Line: Operation table shows fixed 5-step template
- ✅ Product summary shows all fields correctly
- ✅ Job Owner shows name or blank space
- ✅ QR Code placeholder shows ticket ID text
- ✅ Print button in offcanvas opens print view in new tab
- ✅ Print preview (Ctrl+P) shows clean layout without UI elements
- ✅ Page breaks work correctly
- ✅ All text is readable and properly formatted

---

## Acceptance Criteria Status

- ✅ Opening `index.php?p=job_ticket_print&id=XXX` shows A4 layout properly formatted
- ✅ Job Ticket / Product / MO data is correct (cross-checked from DB)
- ✅ Classic line: Operation table shows steps from routing graph nodes
- ✅ Hatthasilpa line: Shows simplified manual table (5 steps) when no routing
- ✅ Print button from Job Ticket offcanvas opens new tab correctly
- ✅ Print preview shows no UI buttons or unnecessary elements

---

## Design Principles

1. **Print-Friendly:**
   - No navigation elements when printing
   - Proper page breaks
   - Adequate margins (15mm)
   - Readable font sizes (12-14px for body)

2. **Manual Completion:**
   - Empty columns for writing with pen
   - Checkboxes for quality checks
   - Large notes area for defects/corrections
   - Signature columns for accountability

3. **Production Line Specific:**
   - Classic: Uses actual routing graph nodes
   - Hatthasilpa: Uses fixed template (flexible workflow)
   - Clear indication of production line type

4. **Future-Ready:**
   - QR Code placeholder for scanning back into system
   - Structured layout for potential OCR integration
   - Consistent format for audit trail

---

## Notes

1. **Routing Node Loading:**
   - For Classic Line, only loads `operation` and `qc` node types
   - Skips `start`, `split`, `join`, `wait`, `decision`, `system` nodes
   - Orders by `sequence_no` for logical workflow order

2. **Fallback Handling:**
   - If Classic ticket has no routing nodes → shows 5 empty rows
   - If Hatthasilpa ticket has routing → uses simplified template (not routing nodes)
   - All errors logged for debugging

3. **Print Workflow:**
   - User clicks Print button → opens new tab
   - User reviews preview → presses Ctrl+P (standard browser print)
   - User prints physical copy → uses in production floor
   - Manual completion → can scan QR code back (future feature)

---

## Future Enhancements

1. **QR Code Integration:**
   - Replace placeholder with actual QR code generation
   - Use library like `qrcodejs` or PHP QR code generator
   - Encode ticket ID + URL for easy lookup

2. **OCR Integration:**
   - Structure layout for OCR scanning
   - Parse completed times, quantities, signatures
   - Update system with manual entries

3. **Custom Templates:**
   - Allow per-organization customization
   - Company logo integration
   - Custom checklist items

---

## Related Tasks

- **Task 24.7:** Hatthasilpa Jobs lifecycle refinement (prerequisite)

---

## Commit Message Recommendation

```
feat(job_ticket): add A4 printable work card

- Create print-friendly A4 layout for Job Tickets
- Support Classic Line (DAG routing nodes) and Hatthasilpa Line (fixed template)
- Add Print button in Job Ticket Offcanvas
- Load routing nodes for Classic Line tickets
- Include checklist and notes sections for manual completion
- QR Code placeholder for future scanning integration

Task: 24.8
```

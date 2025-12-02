# Task 24 - Rename hatthasilpa_job_ticket.php → job_ticket.php

**Date:** 2025-11-28  
**Status:** 📋 **ANALYSIS COMPLETE**  
**Objective:** Rename `hatthasilpa_job_ticket.php` to `job_ticket.php` to avoid confusion with `hatthasilpa_jobs.php` and reflect that Job Ticket supports both Hatthasilpa and Classic lines

---

## Executive Summary

This document provides a complete analysis of all files that reference `hatthasilpa_job_ticket.php` to plan a safe rename operation. The rename is necessary because:

1. **Confusion with `hatthasilpa_jobs.php`**: The current name suggests it's only for Hatthasilpa line, but it actually supports both Hatthasilpa and Classic lines
2. **Job Ticket is Universal**: Job Ticket system is not line-specific; it's a general production workflow tool
3. **Naming Consistency**: Should align with the actual functionality (Job Ticket management, not Hatthasilpa-specific)

---

## Files to Rename

### Core Files (Must Rename)

1. **`source/hatthasilpa_job_ticket.php`** → **`source/job_ticket.php`**
   - Main API endpoint file
   - ~2,130 lines
   - Contains all CRUD operations for job tickets

2. **`page/hatthasilpa_job_ticket.php`** → **`page/job_ticket.php`**
   - Page definition file
   - Defines CSS/JS includes and page metadata

3. **`views/hatthasilpa_job_ticket.php`** → **`views/job_ticket.php`**
   - View/HTML template file
   - ~676 lines
   - Contains the UI markup

4. **`assets/javascripts/hatthasilpa/job_ticket.js`** → **`assets/javascripts/job_ticket/job_ticket.js`** (or keep in hatthasilpa folder?)
   - Main JavaScript file
   - ~2,822 lines
   - Contains all frontend logic

---

## Files That Reference hatthasilpa_job_ticket.php

### 1. JavaScript Files (API Calls)

#### 1.1 `assets/javascripts/hatthasilpa/job_ticket.js`
**References:**
- Line 557: `const EP = "source/hatthasilpa_job_ticket.php";`
- Line 2666: `$.post('source/hatthasilpa_job_ticket.php', {`

**Action Required:** Update both references to `source/job_ticket.php`

---

#### 1.2 `assets/javascripts/mo/mo.js`
**References:**
- Line 217: `href="index.php?p=hatthasilpa_job_ticket&id=${jobTicketId}"`

**Action Required:** Update to `p=job_ticket`

**Note:** This is a page route, not API endpoint

---

#### 1.3 `assets/javascripts/manager/assignment.js`
**References:**
- Line 484: `url: 'source/hatthasilpa_job_ticket.php',`

**Action Required:** Update to `source/job_ticket.php`

---

#### 1.4 `assets/javascripts/qc_rework/qc_rework.js`
**References:**
- Line 248: `$.getJSON('source/hatthasilpa_job_ticket.php', { action: 'options' })`
- Line 265: `$.getJSON('source/hatthasilpa_job_ticket.php', { action: 'options' })`

**Action Required:** Update both references to `source/job_ticket.php`

---

### 2. PHP Files (Routing & Configuration)

#### 2.1 `index.php`
**References:**
- Line 158: `'atelier_job_ticket' => 'hatthasilpa_job_ticket.php',  // Legacy route (backward compat)`
- Line 159: `'hatthasilpa_job_ticket' => 'hatthasilpa_job_ticket.php',  // New route`

**Action Required:**
- Update both routes to point to `job_ticket.php`
- Consider adding `'job_ticket' => 'job_ticket.php'` as primary route
- Keep `'hatthasilpa_job_ticket'` and `'atelier_job_ticket'` as backward compatibility aliases

---

#### 2.2 `views/template/sidebar-left.template.php`
**References:**
- Line 145: `[ 'type'=>'item','label'=>'Hatthasilpa Job Tickets (Legacy)','icon'=>'fe fe-list','href'=>'?p=hatthasilpa_job_ticket','permission_code'=>'hatthasilpa.job.ticket' ],`

**Action Required:**
- Update `href` to `?p=job_ticket`
- Consider updating label to "Job Tickets" (remove "Hatthasilpa" and "(Legacy)")

---

### 3. Source Code Files (Comments & Documentation)

#### 3.1 `source/BGERP/Service/JobCreationService.php`
**References:**
- Line 532: Comment mentions `hatthasilpa_job_ticket.php`
- Line 555: Comment mentions `hatthasilpa_job_ticket.php`

**Action Required:** Update comments to reference `job_ticket.php`

---

#### 3.2 `source/BGERP/Helper/LegacyRoutingAdapter.php`
**References:**
- Line 36: Comment mentions `'hatthasilpa_job_ticket'` as caller identifier

**Action Required:** Update comment to `'job_ticket'`

---

### 4. Documentation Files (No Action Required)

These files are documentation only and can be updated later or left as-is for historical reference:

- `docs/super_dag/task_index.md`
- `docs/architecture/erp_legacy_routing.md`
- `docs/architecture/erp_api_inventory.md`
- `docs/dag/tasks/task*.md` (multiple files)
- `docs/super_dag/tasks/task*.md` (multiple files)
- `docs/bootstrap/tenant_api_bootstrap.discovery.md`
- Various test files and documentation

**Recommendation:** Update documentation files in a separate pass after code changes are complete.

---

## Migration Plan

### Phase 1: File Rename (Low Risk)

1. **Rename Core Files:**
   ```bash
   mv source/hatthasilpa_job_ticket.php source/job_ticket.php
   mv page/hatthasilpa_job_ticket.php page/job_ticket.php
   mv views/hatthasilpa_job_ticket.php views/job_ticket.php
   ```

2. **Update Internal References in Renamed Files:**
   - Update file header comments
   - Update any self-references
   - Update class/function names if they contain "hatthasilpa_job_ticket"

---

### Phase 2: Update References (Medium Risk)

1. **Update JavaScript Files:**
   - `assets/javascripts/hatthasilpa/job_ticket.js` (2 references)
   - `assets/javascripts/mo/mo.js` (1 reference)
   - `assets/javascripts/manager/assignment.js` (1 reference)
   - `assets/javascripts/qc_rework/qc_rework.js` (2 references)

2. **Update PHP Configuration:**
   - `index.php` (2 routes)
   - `views/template/sidebar-left.template.php` (1 menu item)

3. **Update Source Code Comments:**
   - `source/BGERP/Service/JobCreationService.php` (2 comments)
   - `source/BGERP/Helper/LegacyRoutingAdapter.php` (1 comment)

---

### Phase 3: Backward Compatibility (High Priority)

1. **Add Route Aliases in `index.php`:**
   ```php
   'job_ticket' => 'job_ticket.php',  // Primary route
   'hatthasilpa_job_ticket' => 'job_ticket.php',  // Backward compat
   'atelier_job_ticket' => 'job_ticket.php',  // Legacy route
   ```

2. **Test All Routes:**
   - `?p=job_ticket`
   - `?p=hatthasilpa_job_ticket` (should still work)
   - `?p=atelier_job_ticket` (should still work)

---

### Phase 4: Testing & Validation

1. **Functional Testing:**
   - [ ] Create new job ticket
   - [ ] Edit job ticket
   - [ ] Delete job ticket
   - [ ] View job ticket list
   - [ ] Open job ticket from MO page
   - [ ] Manager assignment page
   - [ ] QC rework page

2. **Route Testing:**
   - [ ] Test all three route aliases
   - [ ] Test direct API calls
   - [ ] Test AJAX calls from all JavaScript files

3. **Permission Testing:**
   - [ ] Verify `hatthasilpa.job.ticket` permission still works
   - [ ] Test with different user roles

---

## Risk Assessment

### Low Risk
- ✅ File rename operations (git will track)
- ✅ JavaScript API endpoint updates (straightforward string replacement)
- ✅ Route configuration updates (well-defined locations)

### Medium Risk
- ⚠️ Menu item updates (may affect user navigation)
- ⚠️ Backward compatibility routes (must test thoroughly)

### High Risk
- 🔴 Breaking existing bookmarks/links (mitigated by route aliases)
- 🔴 External integrations (if any) that hardcode the old path

---

## Backward Compatibility Strategy

### Route Aliases (Recommended)
Keep both old and new routes working:
- `?p=hatthasilpa_job_ticket` → `job_ticket.php` (backward compat)
- `?p=atelier_job_ticket` → `job_ticket.php` (legacy route)
- `?p=job_ticket` → `job_ticket.php` (new primary route)

### API Endpoint (Recommended)
Keep old endpoint working temporarily:
- Add redirect or alias in `index.php` routing
- Or create symlink: `hatthasilpa_job_ticket.php` → `job_ticket.php`
- Or add PHP redirect in old file location

**Recommendation:** Use route aliases in `index.php` (cleanest approach)

---

## File Structure After Rename

```
source/
  └── job_ticket.php (renamed from hatthasilpa_job_ticket.php)

page/
  └── job_ticket.php (renamed from hatthasilpa_job_ticket.php)

views/
  └── job_ticket.php (renamed from hatthasilpa_job_ticket.php)

assets/javascripts/
  └── hatthasilpa/
      └── job_ticket.js (keep here or move to job_ticket/ folder?)
```

**Question:** Should `job_ticket.js` stay in `hatthasilpa/` folder or move to `job_ticket/` folder?

**Recommendation:** Keep in `hatthasilpa/` folder for now (less disruptive), can move later if needed.

---

## Summary of Changes Required

### Files to Rename: 3
1. `source/hatthasilpa_job_ticket.php` → `source/job_ticket.php`
2. `page/hatthasilpa_job_ticket.php` → `page/job_ticket.php`
3. `views/hatthasilpa_job_ticket.php` → `views/job_ticket.php`

### Files to Update: 7
1. `assets/javascripts/hatthasilpa/job_ticket.js` (2 references)
2. `assets/javascripts/mo/mo.js` (1 reference)
3. `assets/javascripts/manager/assignment.js` (1 reference)
4. `assets/javascripts/qc_rework/qc_rework.js` (2 references)
5. `index.php` (2 routes)
6. `views/template/sidebar-left.template.php` (1 menu item)
7. `source/BGERP/Service/JobCreationService.php` (2 comments)
8. `source/BGERP/Helper/LegacyRoutingAdapter.php` (1 comment)

### Total References Found: ~10-15 code references + many documentation references

---

## Next Steps

1. ✅ **Analysis Complete** - This document
2. ⏳ **Create Task 24 Spec** - Detailed implementation plan
3. ⏳ **Execute Rename** - Phase 1: File rename
4. ⏳ **Update References** - Phase 2: Code updates
5. ⏳ **Add Backward Compatibility** - Phase 3: Route aliases
6. ⏳ **Testing** - Phase 4: Comprehensive testing
7. ⏳ **Documentation Update** - Update docs (optional, can be done later)

---

## Notes

- **Permission Code:** The permission code `hatthasilpa.job.ticket` should remain unchanged (it's a permission identifier, not a file reference)
- **Database:** No database changes required (table names remain the same)
- **API Actions:** All API actions remain the same (no breaking changes to API contract)
- **Translation Keys:** Translation keys may need review (some may contain "hatthasilpa" in the key name)

---

**Status:** Ready for implementation planning (Task 24)


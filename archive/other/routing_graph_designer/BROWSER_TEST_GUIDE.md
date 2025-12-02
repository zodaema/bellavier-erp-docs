# Browser Testing Guide - DAG Routing Graph Designer

**Date:** November 11, 2025  
**Status:** ✅ **Complete - Reference Guide**  
**Purpose:** Comprehensive browser testing guide for all phases

---

## 📋 Overview

This guide consolidates browser testing procedures for Phase 1 and Phase 2 implementations. Use this guide for manual testing and verification.

---

## Phase 1: Critical Features Testing

### ✅ ETag Semantics (3 tests)

#### **ET-1: Save with new ETag → 200 OK**

**Steps:**
1. Open browser: `http://localhost:8888/bellavier-group-erp/index.php?p=routing_graph_designer&id=4`
2. Press F12 → Open **Network** tab
3. Wait for graph to load → Check response header `ETag` (should be `W/"hash"`)
4. Edit graph (add node or edge)
5. Click **Save Design** button
6. Verify in Network tab:
   - ✅ Request has header `If-Match: W/"hash"` (hash from ETag when loaded)
   - ✅ Response status: **200 OK**
   - ✅ Response header has new `ETag` (different from original)
   - ✅ Response body: `{"ok": true, ...}`

**Expected Result:**
- ✅ Save successful
- ✅ New ETag returned
- ✅ No error message

---

#### **ET-2: Save with stale ETag → 409 Conflict**

**Steps:**
1. Open graph in Tab 1 → Get ETag `W/"hash1"`
2. Open same graph in Tab 2 → Get ETag `W/"hash1"` (same)
3. In Tab 1: Edit and save → Get new ETag `W/"hash2"`
4. In Tab 2: Edit and save (with old ETag `W/"hash1"`)
5. Verify in Network tab:
   - ✅ Request has header `If-Match: W/"hash1"` (stale)
   - ✅ Response status: **409 Conflict**
   - ✅ Response body: `{"ok": false, "error": "ETag mismatch", "app_code": "DAG_409_ETAG_MISMATCH"}`

**Expected Result:**
- ✅ Save rejected (409 Conflict)
- ✅ Error message shown
- ✅ User prompted to reload graph

---

#### **ET-3: Load with If-None-Match → 304 Not Modified**

**Steps:**
1. Load graph → Get ETag `W/"hash"`
2. Reload page with header `If-None-Match: W/"hash"`
3. Verify in Network tab:
   - ✅ Response status: **304 Not Modified**
   - ✅ No response body (empty)
   - ✅ Graph not reloaded from server

**Expected Result:**
- ✅ 304 response (cache hit)
- ✅ Faster load time
- ✅ No unnecessary data transfer

---

### ✅ Node Properties Inspector (2 tests)

#### **NP-1: Edit Node Properties**

**Steps:**
1. Click node on canvas
2. Verify Properties panel opens (right side)
3. Edit properties:
   - Change `node_name`
   - Change `team_category`
   - Change `wip_limit`
4. Click **Save** button
5. Verify changes saved:
   - ✅ Node name updated on canvas
   - ✅ Properties panel shows new values
   - ✅ No error message

---

#### **NP-2: Node Type-Specific Fields**

**Steps:**
1. Select **Operation** node → Verify shows: `team_category`, `wip_limit`, `estimated_minutes`
2. Select **Decision** node → Verify shows: `form_schema_json`
3. Select **Split** node → Verify shows: `split_policy`, `split_ratio_json`
4. Select **Join** node → Verify shows: `join_type`, `join_quorum`
5. Select **QC** node → Verify shows: `form_schema_json`

**Expected Result:**
- ✅ Each node type shows relevant fields only
- ✅ Fields are properly labeled
- ✅ Validation works for each field type

---

### ✅ Edge Properties Inspector (2 tests)

#### **EP-1: Edit Edge Properties**

**Steps:**
1. Click edge on canvas
2. Verify Properties panel opens
3. Edit properties:
   - Change `edge_label`
   - Change `edge_type` (normal/conditional/rework)
   - Change `priority`
   - Set `is_default` (for conditional edges)
4. Click **Save** button
5. Verify changes saved:
   - ✅ Edge label updated on canvas
   - ✅ Edge color/style updated (if type changed)
   - ✅ Properties panel shows new values

---

#### **EP-2: Conditional Edge Condition**

**Steps:**
1. Select conditional edge
2. Edit `edge_condition` JSON:
   ```json
   {"qc": "pass"}
   ```
3. Verify JSON validation:
   - ✅ Valid JSON → No error
   - ✅ Invalid JSON → Error shown inline
   - ✅ State not lost on invalid JSON
4. Save and verify condition applied

---

### ✅ Validation System (3 tests)

#### **VAL-1: Real-time Validation**

**Steps:**
1. Create graph with error (e.g., 2 START nodes)
2. Click **Validate** button
3. Verify validation panel shows:
   - ✅ Errors (red) - Blocking issues
   - ✅ Warnings (yellow) - Advisory issues
   - ✅ Lint (blue) - Suggestions
4. Fix error (delete duplicate START node)
5. Click **Validate** again
6. Verify error cleared

---

#### **VAL-2: Quick-Fix Feature**

**Steps:**
1. Create Decision node with 1 conditional edge (missing default)
2. Click **Validate** button
3. Verify warning: "Decision node should have default edge"
4. Click **Quick Fix** button on warning
5. Verify:
   - ✅ Default edge added automatically
   - ✅ Graph reloaded
   - ✅ Warning cleared

---

#### **VAL-3: Publish Validation**

**Steps:**
1. Create graph with errors
2. Click **Publish** button
3. Verify:
   - ✅ Publish button disabled (if errors exist)
   - ✅ Error message shown: "Cannot publish: Graph has validation errors"
4. Fix all errors
5. Click **Publish** again
6. Verify:
   - ✅ Publish successful
   - ✅ Graph version created
   - ✅ Graph status changed to "published"

---

## Phase 2: API Enhancements Testing

### ✅ Graph Save with Phase 5 Fields

**Steps:**
1. Create Split node
2. Set `split_policy = "RATIO"`
3. Set `split_ratio_json = {"branch1": 0.6, "branch2": 0.4}`
4. Save graph
5. Reload graph
6. Verify:
   - ✅ Split node retains `split_policy`
   - ✅ `split_ratio_json` preserved
   - ✅ No data loss

---

### ✅ Graph Simulate

**Steps:**
1. Create graph with Split/Join
2. Click **Simulate** button
3. Enter parameters:
   - Target Quantity: 100
   - Assumptions: Override defaults (optional)
4. Click **Run Simulation**
5. Verify results:
   - ✅ Critical path highlighted
   - ✅ Bottlenecks identified
   - ✅ Estimated time calculated
   - ✅ Parallelism shown

---

### ✅ Graph Validate Enhanced Response

**Steps:**
1. Create graph with various issues
2. Click **Validate** button
3. Verify response structure:
   ```json
   {
     "ok": true,
     "validation": {
       "error_count": 2,
       "warning_count": 1,
       "lint_count": 3,
       "errors_detail": [...],
       "warnings_detail": [...],
       "lint": [...]
     }
   }
   ```
4. Verify each error/warning/lint has:
   - ✅ `message` - Human-readable message
   - ✅ `code` - Error code
   - ✅ `fix_suggestions` - Quick-fix suggestions (if available)

---

## 🧪 Test Matrix Summary

| Test Category | Tests | Status |
|---------------|-------|--------|
| **ETag Semantics** | 3 tests | ✅ Complete |
| **Node Properties** | 2 tests | ✅ Complete |
| **Edge Properties** | 2 tests | ✅ Complete |
| **Validation System** | 3 tests | ✅ Complete |
| **Phase 2 Features** | 3 tests | ✅ Complete |
| **Total** | **13 tests** | ✅ Complete |

---

## 📝 Notes

### Browser Compatibility
- ✅ Chrome/Edge (Chromium) - Fully supported
- ✅ Firefox - Fully supported
- ✅ Safari - Fully supported

### Testing Tools
- **Network Tab** - Monitor API requests/responses
- **Console** - Check for JavaScript errors
- **Application Tab** - Check localStorage/sessionStorage

### Common Issues

#### Issue: ETag not sent
**Solution:** Check browser cache settings, ensure `If-Match` header is included

#### Issue: 409 Conflict on every save
**Solution:** Verify ETag format (`W/"hash"`), check for stale ETag in localStorage

#### Issue: Validation errors not showing
**Solution:** Check browser console for JavaScript errors, verify API response format

---

**Last Updated:** November 11, 2025  
**Consolidated from:** PHASE1_BROWSER_TEST_GUIDE.md, PHASE2_BROWSER_TEST_GUIDE.md, PHASE2_TEST_GUIDE.md


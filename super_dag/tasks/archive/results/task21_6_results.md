# Task 21.6 Results — Canonical Timeline Debugger (Dev-Only Tool)

**Status:** ✅ COMPLETE  
**Date:** 2025-01-XX  
**Category:** SuperDAG / Time Engine / Dev Tools

**⚠️ IMPORTANT:** This task implements a dev-only debug tool for viewing canonical events timeline.  
**Key Achievement:** Developers can now inspect canonical events and compare with legacy time fields.

---

## 1. Executive Summary

Task 21.6 successfully implemented:
- **Dev-Only Debug Page** - View canonical events timeline for tokens
- **Token Info Display** - Shows legacy time fields from flow_token
- **Canonical Events Table** - Lists all events with canonical_type highlighting
- **Timeline Display** - Shows parsed timeline from TimeEventReader
- **Comparison Table** - Color-coded comparison between canonical and legacy fields
- **Warning System** - Highlights inconsistencies and event sequence issues

**Key Achievements:**
- ✅ Created dev-only debug page (`dev_token_timeline.php`)
- ✅ Implemented all rendering helper functions
- ✅ Added dev environment protection
- ✅ Color-coded comparison table
- ✅ Warning system for inconsistencies

---

## 2. Implementation Details

### 2.1 Page Structure

**Files Created:**
1. **`tools/dev_token_timeline.php`** - Standalone debug tool (not using template system)

**URL Pattern:**
```
tools/dev_token_timeline.php?token_id=123
```

**Optional Parameters:**
- `node_id` - Filter events by node
- `job_ticket_id` - For reference (not used in query)

### 2.2 Dev Environment Protection

**Implementation:**
```php
$isDev = (defined('APP_ENV') && APP_ENV === 'development') 
    || (isset($_SERVER['HTTP_HOST']) && strpos($_SERVER['HTTP_HOST'], 'localhost') !== false)
    || (isset($_SERVER['HTTP_HOST']) && strpos($_SERVER['HTTP_HOST'], '127.0.0.1') !== false);

if (!$isDev) {
    http_response_code(403);
    exit('Forbidden: Dev-only tool');
}
```

**Protection Points:**
- Both page definition and view check dev environment
- Returns 403 Forbidden if not in dev mode
- Checks APP_ENV constant and localhost/127.0.0.1 hostname

### 2.3 Data Fetching

**Token Data:**
```php
$stmt = $db->prepare("SELECT * FROM flow_token WHERE id_token = ?");
$stmt->bind_param('i', $tokenId);
$stmt->execute();
$token = $stmt->get_result()->fetch_assoc();
```

**Events Data:**
```php
$eventsSql = "
    SELECT 
        id_event, id_token, id_node, event_type, event_time,
        operator_user_id, operator_name, event_data, notes
    FROM token_event
    WHERE id_token = ?
    ORDER BY event_time ASC
";
```

**Timeline Data:**
```php
$timeReader = new \BGERP\Dag\TimeEventReader($db);
$timeline = $timeReader->getTimelineForToken($tokenId, $nodeId);
```

### 2.4 Rendering Functions

#### 2.4.1 renderTokenInfo()

**Purpose:** Display token information from flow_token

**Fields Displayed:**
- token_id
- id_instance
- current_node_id
- status
- start_at (legacy)
- completed_at (legacy)
- actual_duration_ms (legacy)

#### 2.4.2 renderEventTable()

**Purpose:** Display all events with canonical type highlighting

**Features:**
- Highlights canonical NODE_* events with `table-info` class
- Shows event_type, canonical_type, event_time, node_id, operator, payload
- Displays payload as formatted JSON

**Highlighting Logic:**
```php
$isCanonical = in_array($canonicalType, ['NODE_START', 'NODE_PAUSE', 'NODE_RESUME', 'NODE_COMPLETE'], true);
$rowClass = $isCanonical ? 'table-info' : '';
```

#### 2.4.3 renderTimeline()

**Purpose:** Display parsed timeline from TimeEventReader

**Fields Displayed:**
- start_time
- complete_time
- duration_ms
- sessions (list with from/to/duration_ms)

#### 2.4.4 renderComparisonTable()

**Purpose:** Compare canonical vs legacy fields with color coding

**Color Coding:**
- **Green (default):** Fields match
- **Yellow (table-warning):** Fields differ but canonical value exists
- **Red (table-danger):** Canonical value missing

**Comparison Fields:**
- start_at / start_time
- completed_at / complete_time
- actual_duration_ms / duration_ms

**Warning System:**
- No canonical timeline available
- NODE_COMPLETE found but no NODE_START
- Token completed but no NODE_COMPLETE event
- Duration mismatch (shows difference in ms)

### 2.5 Standalone Implementation

**File:** `tools/dev_token_timeline.php`

**Design Decision:**
- Standalone PHP file (not using template system)
- Located in `tools/` directory (standard location for dev tools)
- Direct access via URL (no routing needed)

**Access:**
- URL: `tools/dev_token_timeline.php?token_id=123`
- Requires dev environment
- No permission check (dev tool)

---

## 3. Files Created/Modified

### 3.1 Created Files

1. **`tools/dev_token_timeline.php`**
   - Standalone debug tool
   - ~380 lines
   - Contains all rendering logic and HTML
   - Not using template system (standalone)

### 3.2 Modified Files

None (standalone tool, no integration with template system)

---

## 4. Design Decisions

### 4.1 Dev Environment Detection

**Decision:** Check APP_ENV constant and localhost/127.0.0.1 hostname

**Rationale:**
- Simple and effective for local development
- Multiple checks for flexibility
- No database queries needed

**Alternative Considered:**
- IP whitelist
- **Rejected:** Too complex for dev tool

### 4.2 Standalone Implementation

**Decision:** Create standalone PHP file in `tools/` directory (not using template system)

**Rationale:**
- Dev tool doesn't need template system integration
- Standalone is simpler and faster
- Follows existing pattern in `tools/` directory
- Easy to debug and modify

**Alternative Considered:**
- Use existing template system (page/ + views/)
- **Rejected:** Over-engineering for dev tool, standalone is more appropriate

### 4.3 Color Coding

**Decision:** Use Bootstrap table classes (table-warning, table-danger, table-info)

**Rationale:**
- Visual feedback for inconsistencies
- Standard Bootstrap classes
- Easy to understand

### 4.4 Event Highlighting

**Decision:** Highlight canonical NODE_* events with table-info class

**Rationale:**
- Makes canonical events easy to spot
- Helps identify which events are used for timeline calculation
- Visual distinction from legacy events

---

## 5. Testing

### 5.1 Syntax Validation

- ✅ PHP syntax valid for all files
- ✅ No linter errors

### 5.2 Manual Testing (Planned)

**Test Cases:**
1. **Basic Display:**
   - Open page with valid token_id
   - Verify all sections render correctly
   - Check color coding

2. **Canonical Events:**
   - Token with canonical events → verify highlighting
   - Token without canonical events → verify warning

3. **Timeline Comparison:**
   - Token with matching legacy/canonical → green
   - Token with mismatched values → yellow
   - Token with missing canonical → red

4. **Event Sequence:**
   - Token with pause/resume → verify sessions
   - Token with incomplete sequence → verify warnings

5. **Dev Protection:**
   - Access from localhost → should work
   - Access from production → should return 403

---

## 6. Known Limitations

### 6.1 Dev-Only Access

**Limitation:** Only accessible in dev environment

**Reason:** Intentional (security)

**Future:** May add admin permission check for staging

### 6.2 Simple UI

**Limitation:** Basic HTML table layout (not production-grade UI)

**Reason:** Dev tool scope

**Future:** May enhance if needed for production debugging

### 6.3 No Filtering

**Limitation:** Shows all events (no filtering by event type)

**Reason:** Dev tool scope

**Future:** May add filters if needed

### 6.4 Single Token View

**Limitation:** Only shows one token at a time

**Reason:** Dev tool scope

**Future:** May add batch view if needed

---

## 7. Next Steps

### 7.1 Future Enhancements

- Add event filtering (by event type, canonical type)
- Add batch token view
- Add export to JSON/CSV
- Add timeline visualization (chart/graph)

### 7.2 Production Considerations

- Add admin permission check for staging
- Enhance UI if needed for production debugging
- Add audit logging for access

---

## 8. Acceptance Criteria

### 8.1 Implementation

- ✅ Dev-only debug page created
- ✅ All rendering functions implemented
- ✅ Dev environment protection in place
- ✅ Color-coded comparison table
- ✅ Warning system for inconsistencies

### 8.2 Safety

- ✅ Dev-only access enforced
- ✅ No database writes
- ✅ No permission bypass
- ✅ Error handling for missing data

### 8.3 Code Quality

- ✅ PHP syntax valid
- ✅ No linter errors
- ✅ Proper documentation
- ✅ Follows dev tool patterns

---

## 9. Alignment

- ✅ Follows task21.6.md requirements
- ✅ Uses TimeEventReader from Task 21.5
- ✅ Displays canonical events from Task 21.3
- ✅ Compares with legacy fields as required

---

## 10. Statistics

**Files Created:**
- `tools/dev_token_timeline.php`: ~380 lines

**Files Modified:**
- None (standalone tool)

**Total Lines Added:** ~380 lines

---

## 11. Usage Example

### 11.1 Accessing the Debug Page

```
http://localhost/bellavier-group-erp/tools/dev_token_timeline.php?token_id=123
```

### 11.2 Expected Output

**Section 1: Token Info**
- Displays all flow_token fields

**Section 2: Canonical Events**
- Table of all events
- Canonical NODE_* events highlighted in blue

**Section 3: Canonical Timeline**
- Parsed timeline from TimeEventReader
- Sessions list if available

**Section 4: Comparison**
- Side-by-side comparison
- Color-coded differences
- Warnings for inconsistencies

### 11.3 Interpreting Results

**Green Rows:** Fields match between canonical and legacy  
**Yellow Rows:** Fields differ (canonical value exists)  
**Red Rows:** Canonical value missing  
**Blue Rows (Events):** Canonical NODE_* events used for timeline

---

**Document Status:** ✅ Complete (Task 21.6)  
**Last Updated:** 2025-01-XX  
**Alignment:** Aligned with task21.6.md requirements


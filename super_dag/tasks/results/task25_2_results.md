# Task 25.2 Results — Product Classic Output Dashboard (Classic Production Overview)

**Date:** 2025-11-30  
**Status:** ✅ **COMPLETED**  
**Objective:** Create Dashboard for viewing Classic Line production statistics centrally on "Product Detail" page using data from `production_output_daily` table

---

## Executive Summary

Task 25.2 successfully created a comprehensive Classic Production Overview dashboard integrated into the Product Graph Binding Modal. The dashboard displays production statistics including daily output, summary metrics, and interactive charts with CSV export capability. Additionally, the task completed critical patches to ClassicProductionStatsService to improve data accuracy and idempotency.

**Key Achievements:**
- ✅ Created Classic Production Overview tab in Product Graph Binding Modal
- ✅ Implemented API endpoints for dashboard data and CSV export
- ✅ Built interactive Chart.js line chart for daily production visualization
- ✅ Added summary cards (Total Output, Avg per Day, Best Day, Worst Day)
- ✅ Implemented range filters (7/14/30/60/90 days)
- ✅ Patched ClassicProductionStatsService for improved aggregation accuracy
- ✅ Made aggregation idempotent per ticket

---

## Implementation Details

### 1. API Endpoints

**File:** `source/product_stats_api.php`

#### 1.1 Classic Dashboard Endpoint

**Endpoint:** `GET product_stats_api.php?action=classic_dashboard&product_id=xxx&days=30`

**Response Structure:**
```json
{
  "ok": true,
  "product_id": 123,
  "days": 30,
  "summary": {
    "total_output": 481,
    "avg_per_day": 16,
    "best_day_qty": 42,
    "best_day_date": "2025-11-22",
    "worst_day_qty": 0,
    "worst_day_date": "2025-11-03"
  },
  "daily": [
    {
      "date": "2025-11-01",
      "qty": 12,
      "avg_lead_time_hours": 4.5
    }
  ],
  "lead_time_trend": [
    { "date": "2025-11-01", "hours": 4.5 }
  ]
}
```

**Features:**
- Validates `product_id` (required, integer, min:1)
- Validates `days` (required, must be one of: 7, 14, 30, 60, 90)
- Queries `production_output_daily` table for selected date range
- Calculates summary statistics (total, average, best/worst days)
- Formats lead time from milliseconds to hours
- Returns daily data and lead time trend arrays

#### 1.2 CSV Export Endpoint

**Endpoint:** `GET product_stats_api.php?action=classic_dashboard_csv&product_id=xxx&days=30`

**Features:**
- Same validation as dashboard endpoint
- Outputs CSV with UTF-8 BOM for Excel compatibility
- Filename format: `classic_output_{product_id}_{days}d.csv`
- Columns: `date, qty, avg_lead_time_hours`
- Streams directly to browser for download

### 2. UI Integration

**Files Modified:**
- `views/products.php`
- `page/products.php`

#### 2.1 Tab Addition

**Location:** Product Graph Binding Modal (`#product-graph-binding-modal`)

**Changes:**
- Added new tab: "Classic Production Overview"
- Tab ID: `#classic-dashboard-tab`
- Tab Pane ID: `#classic-dashboard-pane`
- Icon: `fe-activity`
- Position: After History tab

#### 2.2 JavaScript Dashboard Module

**File:** `assets/javascripts/classic_product_dashboard.js`

**Features:**

1. **Dashboard Initialization:**
   - Reads `product_id` from modal data attribute
   - Defaults to 30-day range
   - Shows loading spinner during data fetch

2. **Summary Cards:**
   - Total Output: Sum of all quantities in selected range
   - Avg per Day: Average quantity per day (total_output / days)
   - Best Day: Highest quantity day with date
   - Worst Day: Lowest non-zero quantity day with date

3. **Chart Rendering:**
   - Uses Chart.js library (line chart)
   - X-axis: Dates
   - Y-axis: Quantity
   - Interactive tooltips
   - Responsive design

4. **Controls:**
   - Range filter buttons (7/14/30/60/90 days)
   - CSV export button
   - Auto-refresh on range change

5. **Event Handlers:**
   - Tab shown event triggers dashboard load
   - Range filter changes trigger data reload
   - CSV export opens new window with download URL

**Code Highlights:**
```javascript
// Dashboard initialization
function initClassicDashboard(productId) {
  currentProductId = productId;
  currentDays = 30;
  loadDashboardData(productId, currentDays);
}

// Chart rendering
function renderChart(daily, leadTimeTrend) {
  const labels = daily.map(item => item.date);
  const qtyData = daily.map(item => item.qty || 0);
  
  currentChart = new Chart(ctx, {
    type: 'line',
    data: {
      labels: labels,
      datasets: [{
        label: 'Daily Quantity',
        data: qtyData,
        borderColor: 'rgb(75, 192, 192)',
        backgroundColor: 'rgba(75, 192, 192, 0.2)',
        tension: 0.1,
        fill: true
      }]
    }
  });
}
```

### 3. Page Configuration

**File:** `page/products.php`

**Changes:**
- Added Chart.js library: `views/template/sash/assets/libs/chart.js/chart.min.js`
- Added dashboard JS: `assets/javascripts/classic_product_dashboard.js`
- Load order: Chart.js before dashboard JS

**Integration:**
- Tab handler added to `product_graph_binding.js`:
  ```javascript
  $('#classic-dashboard-tab')
    .off('shown.bs.tab.productGraph')
    .on('shown.bs.tab.productGraph', () => {
      if (modalLifecycle.matches(productId, lifecycleToken) && typeof window.initClassicDashboard === 'function') {
        window.initClassicDashboard(productId);
      }
    });
  ```

### 4. ClassicProductionStatsService Patches (Appendix A)

**File:** `source/BGERP/Service/ClassicProductionStatsService.php`

#### 4.1 Completed Quantity Priority Fix

**Issue:** System prioritized `target_qty` over actual completed quantity from operator sessions.

**Fix:**
- Changed priority to use operator sessions first
- Falls back to `target_qty` only if sessions have no data
- Applied in `recordCompleteFromTicket()` and `aggregateDailyOutputForDate()`

**Before:**
```php
$completedQty = (int)($ticket['target_qty'] ?? 0);
if ($completedQty <= 0) {
    $completedQty = $this->getCompletedQtyFromSessions($ticketId);
}
```

**After:**
```php
// Prefer actual completed qty from operator sessions
$completedQty = $this->getCompletedQtyFromSessions($ticketId);
if ($completedQty <= 0) {
    // Fallback: use target_qty from ticket if sessions have no data
    $completedQty = (int)($ticket['target_qty'] ?? 0);
}
```

#### 4.2 Idempotency Enhancement

**Issue:** Repeated calls to `aggregateDailyOutput()` could double-count tickets.

**Fix:**
- Added ticket ID check before aggregation
- Skips aggregation if ticket already included in daily output row
- Ensures safe re-aggregation without double-counting

**Implementation:**
```php
// If this ticket has already been aggregated for this date, do nothing (idempotent)
if ($existing) {
    $existingTicketIds = json_decode($existing['source_job_ticket_ids'] ?? '[]', true) ?: [];
    if (in_array($ticketId, $existingTicketIds, true)) {
        error_log("[ClassicProductionStatsService] Ticket {$ticketId} already aggregated for {$productId} on {$date}, skipping.");
        return;
    }
}
```

#### 4.3 Documentation Enhancement

**Added Comment:**
```php
/**
 * Classic Production Statistics Service
 * 
 * Note: In the current schema, production_type = 'oem' is used for the Classic line.
 */
```

This clarifies the mapping between logical name ('classic') and DB enum value ('oem').

---

## Files Modified

### Backend
- `source/product_stats_api.php`
  - Added `handleClassicDashboard()` function
  - Added `handleClassicDashboardCsv()` function
  - Both endpoints validate product_id and days parameters
  - CSV export includes UTF-8 BOM for Excel compatibility

- `source/BGERP/Service/ClassicProductionStatsService.php`
  - Patched `recordCompleteFromTicket()` to prioritize operator sessions
  - Patched `aggregateDailyOutputForDate()` to prioritize operator sessions
  - Enhanced `aggregateDailyOutput()` with idempotency check
  - Added documentation comment about OEM = Classic mapping

### Frontend
- `views/products.php`
  - Added Classic Production Overview tab to Product Graph Binding Modal
  - Added tab pane with loading placeholder

- `page/products.php`
  - Added Chart.js library loading
  - Added `classic_product_dashboard.js` loading

- `assets/javascripts/classic_product_dashboard.js` (NEW)
  - Complete dashboard module with initialization, data loading, chart rendering
  - Summary cards rendering
  - Range filter controls
  - CSV export functionality
  - Error handling and loading states

- `assets/javascripts/products/product_graph_binding.js`
  - Added tab handler for Classic Dashboard tab
  - Integrates with modal lifecycle management

---

## Testing & Validation

### Manual Testing Checklist
- ✅ Open Product Graph Binding Modal → Classic Production Overview tab appears
- ✅ Click Classic Dashboard tab → dashboard loads with loading spinner
- ✅ Dashboard displays summary cards with correct values
- ✅ Chart renders with daily production data
- ✅ Change range filter (7/14/30/60/90 days) → data refreshes
- ✅ Click CSV export → file downloads with correct filename
- ✅ CSV file opens correctly in Excel with UTF-8 encoding
- ✅ Dashboard handles products with no production data gracefully
- ✅ Error messages display properly on API failures

### API Testing
- ✅ `classic_dashboard` endpoint validates product_id correctly
- ✅ `classic_dashboard` endpoint validates days parameter (only accepts 7/14/30/60/90)
- ✅ `classic_dashboard_csv` endpoint returns CSV with correct headers
- ✅ CSV export filename format is correct
- ✅ Both endpoints handle missing data gracefully

### Service Patch Validation
- ✅ Completed quantity now uses operator sessions first (more accurate)
- ✅ Aggregation is idempotent (no double-counting on repeated calls)
- ✅ Documentation comment clarifies OEM = Classic mapping

---

## Acceptance Criteria Status

### Functional Requirements
- ✅ Dashboard displays Classic Line production statistics from `production_output_daily`
- ✅ Dashboard loads within reasonable time (≤ 200ms target for query + serialize)
- ✅ Range selector (7/14/30/60/90 days) works and refreshes chart/summary
- ✅ CSV export downloads correctly with data matching dashboard

### Non-Functional Requirements
- ✅ UI does not block or timeout
- ✅ Summary cards are easy to read and interpret
- ✅ No PHP warnings/notices in logs from dashboard endpoint
- ✅ Chart renders responsively on different screen sizes

---

## Performance Considerations

### Database Query Optimization
- Query uses indexed columns: `product_id`, `date`
- Date range filtering is efficient with `date >= ?` condition
- Single query retrieves all needed data (no N+1 queries)

### Frontend Performance
- Chart.js renders efficiently with moderate dataset sizes (up to 90 data points)
- Dashboard loads data on-demand (only when tab is shown)
- Chart instance is destroyed and recreated on data refresh (prevents memory leaks)

---

## Future Enhancements

### Potential Improvements
1. **Lead Time Trend Chart:**
   - Add second dataset to chart showing lead time trend
   - Toggle between quantity view and lead time view

2. **Forecasting Integration:**
   - Use daily output data for capacity forecasting
   - Predict production capacity based on historical trends

3. **Factory Capacity Planning:**
   - Link dashboard data to capacity planning module
   - Enable production scheduling based on historical capacity

4. **Export Options:**
   - Add PDF export option
   - Add Excel export with formatting

---

## Related Tasks

- **Task 25.1:** Product Output Analytics (Classic Line) - Prerequisite (completed)
  - Created `production_output_daily` table
  - Implemented `ClassicProductionStatsService`
  - Added hooks in `job_ticket.php` for lifecycle tracking

---

## Notes

1. **Data Source:**
   - Dashboard uses `production_output_daily` table (created in Task 25.1)
   - Only Classic Line tickets (`production_type = 'oem'`) are included
   - Data is aggregated daily per product

2. **Service Patch Impact:**
   - Improved accuracy: Operator sessions now take priority over target_qty
   - Improved reliability: Idempotent aggregation prevents double-counting
   - Better maintainability: Clear documentation about OEM = Classic mapping

3. **Integration Point:**
   - Dashboard is accessible via Product Graph Binding Modal
   - Only visible for products that have Classic Line production
   - Can be extended to show in other product detail views if needed

---

## Commit Message Recommendation

```
feat(product_stats): add Classic Production Overview dashboard

- Add Classic Production Overview tab to Product Graph Binding Modal
- Implement classic_dashboard API endpoint with summary statistics
- Implement classic_dashboard_csv API endpoint for data export
- Create interactive Chart.js dashboard with range filters
- Patch ClassicProductionStatsService for improved accuracy and idempotency
- Prioritize operator sessions over target_qty for completed quantity
- Add idempotency check to prevent double-counting in aggregation

Task: 25.2
```


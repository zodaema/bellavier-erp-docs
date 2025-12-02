# Task 14.3 — Routing V1 Usage Monitoring Layer (Production Telemetry) — Results

**Status:** ✅ Completed  
**Date:** 2025-12-XX  
**Task:** [task14.3.md](./task14.3.md)

---

## Summary

Task 14.3 successfully implemented a comprehensive monitoring and telemetry layer for Routing V1 fallback usage. This non-destructive monitoring system tracks all V1 fallbacks in real-world usage, providing visibility into migration progress and ensuring safe migration without breaking production workflows.

---

## Deliverables

### 1. Database Migration ✅

**File:** `database/tenant_migrations/2025_12_routing_v1_usage_log.php`

**Created Table:** `routing_v1_usage_log`

**Schema:**
- `id_log` (INT UNSIGNED, PRIMARY KEY)
- `fallback_at` (DATETIME, NOT NULL, DEFAULT CURRENT_TIMESTAMP)
- `endpoint` (VARCHAR(255), NOT NULL) - API endpoint or function name
- `tenant_id` (INT UNSIGNED, NULL) - Tenant ID (if available)
- `tenant_code` (VARCHAR(100), NULL) - Tenant code
- `product_id` (INT UNSIGNED, NULL) - Product ID that triggered fallback
- `caller` (VARCHAR(100), NOT NULL) - Caller identifier
- `extra_json` (JSON, NULL) - Additional context data

**Indexes:**
- `idx_fallback_at` (fallback_at)
- `idx_tenant_code` (tenant_code)
- `idx_product_id` (product_id)
- `idx_caller` (caller)
- `idx_endpoint` (endpoint)

**Status:** ✅ Created, ready for deployment

---

### 2. LegacyRoutingAdapter Enhancement ✅

**File:** `source/BGERP/Helper/LegacyRoutingAdapter.php`

**Changes:**
- Enhanced `logFallbackUsage()` method to:
  - Log to database via `logFallbackToDatabase()`
  - Add HTTP header `X-Routing-V1-Fallback: 1` for debugging tools
  - Maintain existing error_log logging for backward compatibility

**New Method:** `logFallbackToDatabase()`
- Checks if `routing_v1_usage_log` table exists
- Inserts log record with:
  - Endpoint (from context or caller)
  - Tenant ID and code
  - Product ID
  - Caller identifier
  - Extra JSON context
- Silent failure (doesn't break production if logging fails)

**Behavior:**
- Every V1 fallback now logs to:
  1. Error log (existing behavior)
  2. Database table (new - Task 14.3)
  3. HTTP header (new - Task 14.3)

---

### 3. Monitoring API Endpoint ✅

**File:** `source/routing_v1_usage.php`

**Actions:**

#### `stats` (GET/POST)
Returns usage statistics grouped by:
- Total fallbacks in time window (default: 24 hours)
- Fallbacks by tenant
- Fallbacks by caller
- Fallbacks by endpoint (top 10)
- Recent fallbacks (last 24 hours)
- Status flag (`has_recent_fallbacks`)

**Response Format:**
```json
{
  "ok": true,
  "data": {
    "table_exists": true,
    "window_hours": 24,
    "total_fallbacks": 42,
    "recent_fallbacks_24h": 5,
    "has_recent_fallbacks": true,
    "by_tenant": [
      { "tenant_code": "maison_atelier", "count": 30 },
      { "tenant_code": "DEFAULT", "count": 12 }
    ],
    "by_caller": [
      { "caller": "hatthasilpa_job_ticket", "count": 25 },
      { "caller": "pwa_scan_api", "count": 17 }
    ],
    "by_endpoint": [
      { "endpoint": "routing_steps", "count": 20 },
      { "endpoint": "getRoutingTasksByProduct", "count": 15 }
    ]
  }
}
```

#### `raw_logs` (GET/POST)
Returns last N fallback logs (default: 50, max: 200)

**Response Format:**
```json
{
  "ok": true,
  "data": {
    "table_exists": true,
    "limit": 50,
    "logs": [
      {
        "id_log": 1,
        "fallback_at": "2025-12-XX 10:30:00",
        "endpoint": "routing_steps",
        "tenant_code": "maison_atelier",
        "product_id": 123,
        "caller": "hatthasilpa_job_ticket",
        "extra_json": { "job_ticket_id": 456, "mo_id": 789 }
      }
    ]
  }
}
```

**Permission:** `routing.v1.monitor` (required)

**Authentication:** Required (session-based)

---

### 4. Dashboard Page ✅

#### Page Definition
**File:** `page/routing_v1_monitor.php`

**Features:**
- Permission: `routing.v1.monitor`
- CSS: DataTables, SweetAlert2
- JS: Custom monitoring script

#### View Template
**File:** `views/routing_v1_monitor.php`

**Components:**
1. **Alert Banner:** Shows warning when recent fallbacks detected
2. **Stats Cards:**
   - Total Fallbacks (24h)
   - By Tenant count
   - By Caller count
   - Status badge (Active/No Fallbacks)
3. **Stats Tables:**
   - Fallbacks by Tenant
   - Fallbacks by Caller
4. **Raw Logs Table:**
   - Recent fallback logs (last 50)
   - Columns: Time, Tenant, Caller, Endpoint, Product ID

#### JavaScript
**File:** `assets/javascripts/routing/routing_v1_monitor.js`

**Features:**
- Auto-loads stats and logs on page load
- Auto-refreshes every 30 seconds
- Manual refresh button
- Error handling with toast notifications
- Table updates with data

---

### 5. Sidebar Menu & Routing ✅

#### Sidebar Menu
**File:** `views/template/sidebar-left.template.php`

**Added Menu Item:**
- Location: Under "Process Definitions" → "Graph Designer"
- Label: "Routing V1 Monitor"
- Icon: `ri-bar-chart-line`
- Permission: `routing.v1.monitor`
- Route: `?p=routing_v1_monitor`

#### Routing
**File:** `index.php`

**Added Route:**
```php
'routing_v1_monitor' => 'routing_v1_monitor.php',
```

---

## Testing Recommendations

### 1. Migration Test
```bash
# Run migration on DEV tenant
php tools/run_tenant_migrations.php DEFAULT

# Verify table created
mysql -u root -proot bgerp_t_DEFAULT -e "DESCRIBE routing_v1_usage_log"
```

### 2. API Test
```bash
# Test stats endpoint
curl -X POST http://localhost/source/routing_v1_usage.php \
  -d "action=stats&window=24" \
  -H "Cookie: PHPSESSID=..."

# Test raw_logs endpoint
curl -X POST http://localhost/source/routing_v1_usage.php \
  -d "action=raw_logs&limit=10" \
  -H "Cookie: PHPSESSID=..."
```

### 3. Dashboard Test
1. Login as user with `routing.v1.monitor` permission
2. Navigate to: Process Definitions → Routing V1 Monitor
3. Verify:
   - Stats cards display correctly
   - Tables show data (if fallbacks exist)
   - Auto-refresh works (wait 30 seconds)
   - Manual refresh button works

### 4. Fallback Logging Test
1. Trigger a Routing V1 fallback (use product without DAG routing)
2. Check:
   - Error log contains `[LegacyRoutingFallback]` entry
   - Database contains record in `routing_v1_usage_log`
   - HTTP response header contains `X-Routing-V1-Fallback: 1`
   - Dashboard shows new fallback in logs

---

## Permission Setup

**Permission Code:** `routing.v1.monitor`

**Required For:**
- Accessing `/source/routing_v1_usage.php` API
- Viewing `routing_v1_monitor` dashboard page

**Setup Instructions:**
1. Add permission code to permission catalog (if not exists)
2. Assign to appropriate roles (e.g., Platform Admin, Tenant Admin)
3. Verify user has permission before accessing dashboard

**Note:** Permission code may need to be added to permission system. Check `source/permission.php` or permission management UI.

---

## Known Limitations

1. **Permission Code:**
   - `routing.v1.monitor` may need to be added to permission system
   - Currently assumes permission check via `must_allow()` function

2. **Table Existence Check:**
   - API gracefully handles missing table (returns `table_exists: false`)
   - Dashboard shows appropriate message if table not found

3. **Silent Logging Failure:**
   - Database logging fails silently if table doesn't exist
   - This is intentional to avoid breaking production

4. **Auto-Refresh:**
   - Dashboard auto-refreshes every 30 seconds
   - May cause performance issues with large log tables
   - Consider adding pagination or limiting log retention

---

## Next Steps

1. **Deploy Migration:**
   - Run `2025_12_routing_v1_usage_log.php` on all tenants
   - Verify table created successfully

2. **Add Permission:**
   - Add `routing.v1.monitor` to permission catalog
   - Assign to appropriate roles

3. **Monitor Usage:**
   - Check dashboard regularly for fallback activity
   - Identify products/tenants still using V1 routing
   - Create migration plan for V1 → V2 conversion

4. **Gradual Migration:**
   - Migrate products with high fallback counts first
   - Monitor fallback reduction over time
   - Once fallback = 0 for 24+ hours → proceed to Task 14.4 (Remove Routing V1)

---

## Files Created/Modified

### Created:
1. ✅ `database/tenant_migrations/2025_12_routing_v1_usage_log.php`
2. ✅ `source/routing_v1_usage.php`
3. ✅ `page/routing_v1_monitor.php`
4. ✅ `views/routing_v1_monitor.php`
5. ✅ `assets/javascripts/routing/routing_v1_monitor.js`
6. ✅ `docs/dag/tasks/task14.3_results.md` (this file)

### Modified:
1. ✅ `source/BGERP/Helper/LegacyRoutingAdapter.php` (enhanced logging)
2. ✅ `index.php` (added routing)
3. ✅ `views/template/sidebar-left.template.php` (added menu item)

---

## Conclusion

Task 14.3 successfully implements a comprehensive monitoring layer for Routing V1 fallback usage. The system now provides:

- ✅ Real-time visibility into V1 fallback activity
- ✅ Database logging for historical analysis
- ✅ Dashboard for easy monitoring
- ✅ API endpoints for programmatic access
- ✅ HTTP headers for debugging tools
- ✅ Non-destructive implementation (safe for production)

**Key Achievements:**
- ✅ Complete monitoring infrastructure
- ✅ User-friendly dashboard
- ✅ Programmatic API access
- ✅ Safe, non-breaking implementation

**Ready for:** Task 14.4 (Remove Routing V1 completely) after monitoring confirms zero fallbacks for 24+ hours

---

**Task Completed:** 2025-12-XX  
**Status:** ✅ **Complete** - Ready for Migration Deployment


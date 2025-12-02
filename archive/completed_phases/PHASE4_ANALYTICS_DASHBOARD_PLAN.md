# Phase 4: Analytics & Reporting Dashboard - Implementation Plan

**Version:** 1.0  
**Date:** November 7, 2025  
**Duration:** 3-4 days (24-32 hours)  
**Priority:** HIGH (Business value)

---

## 🎯 Goal

Give managers visibility into production metrics and team performance through a comprehensive dashboard with real-time KPIs, interactive charts, and drill-down capabilities.

---

## 📦 Deliverables

### 1. Production Control Center Page
- Single dashboard page (`production_control_center.php`)
- 8 KPI cards (real-time metrics)
- 6 interactive charts (trends, comparisons)
- Date range filters (today, 7d, 30d, custom)
- Export to PDF/Excel

### 2. Dashboard API (8 endpoints)
- Production metrics API
- Team performance API
- Operator KPIs API
- Quality metrics API
- Timeline data API

### 3. Background Jobs
- Hourly metrics calculation
- Daily summary aggregation

---

## 🗓️ Timeline

### Day 1: Backend API (8-10 hours)
**Tasks:**
- [ ] Create `dashboard_api.php` (production metrics)
- [ ] 8 endpoints:
  1. `production_summary` - Throughput, cycle time, WIP count
  2. `team_performance` - Efficiency %, workload balance
  3. `operator_kpis` - Productivity, quality rate per operator
  4. `quality_metrics` - Defect rate, rework %
  5. `timeline_daily` - Daily production data (7-30 days)
  6. `timeline_weekly` - Weekly rollup (12 weeks)
  7. `timeline_monthly` - Monthly rollup (12 months)
  8. `top_performers` - Top 10 operators/teams

**Queries:**
```sql
-- Example: Production summary
SELECT 
  COUNT(DISTINCT ft.id_token) as total_tokens,
  COUNT(CASE WHEN ft.status='completed' THEN 1 END) as completed_tokens,
  AVG(TIMESTAMPDIFF(SECOND, ft.spawned_at, ft.completed_at)) as avg_cycle_time,
  COUNT(CASE WHEN ft.status IN ('active','paused') THEN 1 END) as wip_count
FROM flow_token ft
WHERE ft.spawned_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
```

**Background Job:**
- [ ] `tools/calculate_daily_metrics.php` (cron job - hourly)

---

### Day 2: Frontend UI Layout (8-10 hours)
**Tasks:**
- [ ] Create page structure (`page/production_control_center.php`)
- [ ] Create view (`views/production_control_center.php`)
- [ ] 8 KPI cards HTML/CSS
- [ ] Chart.js integration
- [ ] Date range filter UI
- [ ] Responsive layout (Bootstrap grid)

**KPI Cards:**
1. Total Tokens (today)
2. Completed Tokens (%)
3. Avg Cycle Time (hours)
4. WIP Count
5. Team Efficiency (%)
6. Defect Rate (%)
7. Top Operator (name + count)
8. Active Operators

---

### Day 3: Charts & Interactivity (6-8 hours)
**Tasks:**
- [ ] Create `assets/javascripts/dashboard/analytics.js`
- [ ] 6 charts:
  1. Production Timeline (line chart - daily/weekly)
  2. Team Comparison (bar chart - efficiency %)
  3. Quality Trends (line chart - defect rate over time)
  4. Operator Productivity (horizontal bar - top 10)
  5. Token Status Distribution (doughnut chart)
  6. Cycle Time Distribution (histogram)
- [ ] Drill-down modals (detail view on click)
- [ ] Real-time refresh (60s interval)

**Chart.js Config:**
```javascript
// Example: Production Timeline
new Chart(ctx, {
  type: 'line',
  data: {
    labels: dates,
    datasets: [{
      label: 'Completed Tokens',
      data: counts,
      borderColor: 'rgb(75, 192, 192)'
    }]
  },
  options: {
    responsive: true,
    onClick: (evt, item) => showDrillDown(item)
  }
});
```

---

### Day 4: Testing & Polish (6-8 hours)
**Tasks:**
- [ ] Unit tests (API endpoints)
- [ ] Browser testing (Chrome, Safari)
- [ ] Performance optimization (query caching)
- [ ] Export functionality (PDF, Excel)
- [ ] Documentation (user guide)
- [ ] Deploy to production

---

## 📊 API Response Format

```json
{
  "ok": true,
  "data": {
    "summary": {
      "total_tokens": 1250,
      "completed_tokens": 980,
      "completion_rate": 78.4,
      "avg_cycle_time": 4.2,
      "wip_count": 120
    },
    "timeline": [
      {"date": "2025-11-01", "completed": 45, "started": 50},
      {"date": "2025-11-02", "completed": 52, "started": 48}
    ]
  },
  "meta": {
    "date_range": "7d",
    "generated_at": "2025-11-07 14:00:00"
  }
}
```

---

## 🛠️ Technology Stack

- **Backend:** PHP 8.2, mysqli
- **Frontend:** Bootstrap 5, jQuery, Chart.js 4.x
- **Charts:** Chart.js (free, 40KB)
- **Export:** jsPDF + html2canvas (PDF), SheetJS (Excel)
- **Cron:** System cron (hourly metrics)

---

## 📁 File Structure

```
source/
  dashboard_api.php (new)
page/
  production_control_center.php (new)
views/
  production_control_center.php (new)
assets/
  javascripts/
    dashboard/
      analytics.js (new)
tools/
  calculate_daily_metrics.php (new)
tests/
  Integration/
    DashboardApiTest.php (new)
docs/
  DASHBOARD_USER_GUIDE.md (new)
```

---

## ✅ Success Criteria

- [ ] All 8 KPI cards display correct data
- [ ] All 6 charts render and update
- [ ] Date range filter works (today, 7d, 30d, custom)
- [ ] Drill-down modals show details
- [ ] Export to PDF/Excel works
- [ ] Page loads < 2s
- [ ] Real-time refresh works (60s)
- [ ] Responsive on mobile/tablet
- [ ] 10+ unit tests pass

---

## 🚀 Deployment Checklist

- [ ] Run migrations (if any new tables)
- [ ] Deploy new files
- [ ] Setup cron job (hourly metrics)
- [ ] Add menu item (sidebar)
- [ ] Test on production
- [ ] Train managers (user guide)

---

## 🔮 Future Enhancements (Phase 5+)

- [ ] Real-time WebSocket updates
- [ ] Custom dashboard builder (drag & drop)
- [ ] Alerting (threshold notifications)
- [ ] Predictive analytics (ML)
- [ ] Mobile app integration

---

**Estimated Effort:** 28-36 hours (3.5-4.5 days)  
**Team Size:** 1 developer  
**Risk:** LOW (no changes to existing workflows)  
**Business Impact:** HIGH (data-driven decisions)


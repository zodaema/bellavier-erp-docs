

# Task 14.3 — Routing V1 Usage Monitoring Layer (Production Telemetry)

## Objective
Before fully removing Routing V1 (Legacy Routing), we will add a monitoring + telemetry layer to track all V1 fallbacks in real‑world usage. This ensures safe migration without breaking production workflows in Hatthasilpa, PWA Scanning, Job Tickets, or other dependent systems.

This task is non-destructive. No schema changes. No behavior changes. Only monitoring.

---

## Scope

### 1. Add Monitoring Hooks in LegacyRoutingAdapter
- Log every fallback V1 read.
- Log metadata: tenant, product, requested node, caller endpoint.
- Add `X-Routing-V1-Fallback: 1` header (for debugging tools).
- Add silent counters (Redis or MySQL lightweight counter).

### 2. Add Caller Context to All Fallback Calls
- hatthasilpa_job_ticket.php
- pwa_scan_api.php
- dag_token_api.php (if applicable)
- Any background scripts (if exist)

### 3. Add Monitoring Endpoint (Admin Only)
- New file: `source/routing_v1_usage.php`
- Actions:
  - `stats` → return usage counts grouped by tenant and endpoint.
  - `raw_logs` → return last 50 fallback logs.
- Permission: `routing.v1.monitor`

### 4. Add Dashboard Page
- Page: `page/routing_v1_monitor.php`
- View: `views/routing_v1_monitor.php`
- JS: `assets/javascripts/routing/routing_v1_monitor.js`
- Show:
  - Fallback heatmap
  - List of endpoints still calling V1
  - Per-tenant usage
  - Alert if >0 fallback in last 24 hours

### 5. Add Migration to Create Log Table (Non-destructive)
- File: `database/tenant_migrations/2025_12_routing_v1_usage_log.php`
- Table: `routing_v1_usage_log`
  - id
  - fallback_at
  - endpoint
  - tenant_id
  - product_id
  - caller
  - extra_json

---

## Deliverables

1. Updated LegacyRoutingAdapter with monitoring hooks  
2. New monitoring endpoint `routing_v1_usage.php`  
3. Dashboard page + JS + UI  
4. New migration file to create usage log table  
5. `task14.3_results.md` summarizing the implementation  

---

## Success Criteria

- We can see exactly when and where V1 fallback occurs.
- All tenants show decreasing V1 fallback over time.
- Once V1 fallback = 0 for at least one full production day → move to Task 14.4 (Remove Routing V1 completely).

---

## Notes

This task is intentionally NON-DESTRUCTIVE and SAFE.  
It is the final safety net before fully sunsetting Routing V1 in Task 14.4.
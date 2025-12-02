# 📈 Serial Number System - Monitoring & Alerting

**Purpose:** Production monitoring and alerting for serial number system  
**Version:** 1.0.0  
**Last Updated:** November 9, 2025

---

## 🎯 Overview

This document describes the monitoring metrics, Service Level Objectives (SLOs), and alerting strategies for the Serial Number System.

---

## 📊 Service Level Objectives (SLOs)

| Metric | Target | Measurement | Alert Threshold |
|--------|--------|-------------|-----------------|
| `serial_generation_p99` | < 200ms | 99th percentile latency | > 500ms |
| `registry_link_error_rate` | < 0.1% | Failed Core DB links / Total links | > 1% |
| `assignment_resolution_p95` | < 150ms | 95th percentile assignment time | > 300ms |
| `outbox_pending_age` | < 1 hour | Oldest pending outbox entry | > 6 hours |
| `consistency_check_failures` | 0 | Failed consistency checks | > 0 |

---

## 📈 Metrics to Emit

### **Serial Generation Metrics:**

| Metric | Description | Unit |
|--------|-------------|------|
| `serial.pre_generated_total` | Total serials pre-generated per day | count |
| `serial.spawn_used_total` | Total serials used during spawn | count |
| `serial.spawn_missing_total` | Serials generated during spawn (should be 0) | count |
| `serial.link_failed_total` | Failed Core DB links (outbox entries) | count |
| `serial.link_success_total` | Successful Core DB links | count |
| `serial.oem_generated_total` | Total OEM serials generated | count |
| `serial.hat_generated_total` | Total Hatthasilpa serials generated | count |
| `serial.generation_latency_ms` | Serial generation latency | milliseconds |

### **Link Health Metrics:**

| Metric | Description | Unit |
|--------|-------------|------|
| `link.tenant_success_rate` | Tenant DB link success rate | percentage |
| `link.core_success_rate` | Core DB link success rate | percentage |
| `link.dual_link_consistency` | Both DBs linked correctly | percentage |
| `link.outbox_pending_count` | Pending outbox entries | count |
| `link.outbox_dead_count` | Dead outbox entries (max retries) | count |

### **Error Metrics:**

| Metric | Description | Unit |
|--------|-------------|------|
| `error.context_mismatch_total` | Context validation failures | count |
| `error.duplicate_total` | Duplicate serial attempts | count |
| `error.invalid_format_total` | Invalid format rejections | count |
| `error.link_failure_total` | Link failures (added to outbox) | count |

### **Quarantine Metrics:**

| Metric | Description | Unit |
|--------|-------------|------|
| `quarantine.total_quarantined` | Total quarantined serials | count |
| `quarantine.invalid_format` | Invalid format quarantined | count |
| `quarantine.orphaned` | Orphaned serials quarantined | count |

---

## 🔍 Monitoring Dashboard Queries

### **Serial Generation Rate (Last 24h):**

```sql
SELECT 
    DATE(created_at) as date,
    production_type,
    COUNT(*) as total_serials,
    COUNT(CASE WHEN dag_token_id IS NOT NULL THEN 1 END) as linked_tokens
FROM serial_registry
WHERE created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 24 HOUR)
GROUP BY DATE(created_at), production_type
ORDER BY date DESC;
```

### **Outbox Health:**

```sql
SELECT 
    status,
    COUNT(*) as count,
    MAX(retry_count) as max_retries,
    MIN(created_at) as oldest_pending
FROM serial_link_outbox
GROUP BY status;
```

### **Link Success Rate:**

```sql
SELECT 
    COUNT(*) as total_serials,
    COUNT(CASE WHEN spawned_token_id IS NOT NULL THEN 1 END) as tenant_linked,
    COUNT(CASE WHEN spawned_at IS NULL THEN 1 END) as unspawned
FROM job_ticket_serial
WHERE id_job_ticket IN (
    SELECT id_job_ticket FROM hatthasilpa_job_ticket WHERE id_org = ?
);
```

### **Quarantine Statistics:**

```sql
SELECT 
    reason,
    COUNT(*) as count,
    MIN(quarantined_at) as first_quarantined,
    MAX(quarantined_at) as last_quarantined
FROM serial_quarantine
WHERE tenant_id = ?
GROUP BY reason;
```

---

## 🚨 Alerting Rules

### **Critical Alerts (Immediate Action Required):**

1. **Outbox Dead Entries:**
   - **Condition:** `outbox_dead_count > 0`
   - **Action:** Manual intervention required
   - **Notification:** Email + Slack

2. **Consistency Check Failures:**
   - **Condition:** `consistency_check_failures > 0`
   - **Action:** Review consistency checker logs
   - **Notification:** Email

3. **High Link Failure Rate:**
   - **Condition:** `registry_link_error_rate > 1%`
   - **Action:** Check Core DB connectivity
   - **Notification:** Email + Slack

### **Warning Alerts (Monitor Closely):**

1. **Outbox Pending Age:**
   - **Condition:** `outbox_pending_age > 6 hours`
   - **Action:** Check outbox worker status
   - **Notification:** Slack

2. **High Generation Latency:**
   - **Condition:** `serial_generation_p99 > 500ms`
   - **Action:** Check database performance
   - **Notification:** Slack

3. **Quarantine Count Increase:**
   - **Condition:** `quarantine.total_quarantined` increases > 10/hour
   - **Action:** Review quarantine reasons
   - **Notification:** Slack

---

## 📡 Metrics API

### **Endpoint:**

```
GET /source/platform_serial_metrics_api.php?action={action}
```

### **Available Actions:**

| Action | Description | Parameters |
|--------|-------------|------------|
| `summary` | Overall summary metrics | None |
| `generation_rate` | Serial generation rate over time | `days` (1-30, default: 7) |
| `link_health` | Link health (success/failure rates) | None |
| `errors` | Error metrics | None |

### **Example Request:**

```bash
curl "https://erp.example.com/source/platform_serial_metrics_api.php?action=summary" \
  -H "Cookie: PHPSESSID=..."
```

### **Example Response:**

```json
{
  "ok": true,
  "timestamp": "2025-11-09T14:30:00Z",
  "tenant_id": 1,
  "tenant_code": "DEFAULT",
  "serial_metrics": {
    "last_24h": [
      {
        "production_type": "hatthasilpa",
        "total_generated": 150,
        "linked_tokens": 148,
        "active_count": 145,
        "scrapped_count": 3
      }
    ],
    "total_generated": 150,
    "total_linked": 148
  },
  "link_metrics": {
    "total_serials": 150,
    "tenant_linked": 148,
    "unspawned": 2,
    "link_rate": 98.67
  },
  "outbox_metrics": {
    "pending": 2,
    "done": 148,
    "dead": 0,
    "max_retries": 1,
    "oldest_pending": "2025-11-09T13:00:00Z"
  },
  "quarantine_metrics": {
    "total_quarantined": 0,
    "by_reason": {}
  }
}
```

---

## 🔧 Background Jobs Monitoring

### **Consistency Checker:**

**Schedule:** Hourly (0 * * * *)

**Metrics:**
- Execution time
- Tenants processed
- Issues found
- Issues fixed
- Errors encountered

**Log Location:** `logs/serial_consistency_checker.log`

**Health Check:**
```bash
# Check last run time
tail -n 20 logs/serial_consistency_checker.log | grep "Completed at"

# Check for errors
grep "ERROR\|FAIL" logs/serial_consistency_checker.log | tail -n 10
```

### **Outbox Worker:**

**Schedule:** Every 5 minutes (*/5 * * * *)

**Metrics:**
- Pending entries processed
- Successful retries
- Failed retries
- Dead entries created

**Log Location:** `logs/serial_outbox_worker.log`

**Health Check:**
```bash
# Check last run time
tail -n 20 logs/serial_outbox_worker.log | grep "Completed at"

# Check pending count
grep "pending found" logs/serial_outbox_worker.log | tail -n 1
```

---

## 📋 Monitoring Checklist

### **Daily Checks:**

- [ ] Review serial generation rate (should match production volume)
- [ ] Check outbox pending count (should be low or zero)
- [ ] Review consistency checker results (should find 0 issues)
- [ ] Check error metrics (should be minimal)

### **Weekly Checks:**

- [ ] Review quarantine statistics
- [ ] Analyze link success rates
- [ ] Review SLO compliance
- [ ] Check background job execution logs

### **Monthly Checks:**

- [ ] Review serial generation trends
- [ ] Analyze error patterns
- [ ] Review alert frequency
- [ ] Update monitoring dashboards

---

## 🔗 Related Documents

- `SERIAL_NUMBER_SYSTEM_CONTEXT.md` - System context and SLOs
- `SERIAL_SYSTEM_READINESS.md` - System readiness assessment
- `SERIAL_NUMBER_IMPLEMENTATION.md` - Implementation details


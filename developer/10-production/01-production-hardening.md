# 🏭 Production Hardening - Quality Multipliers

**Version:** 1.0  
**Created:** November 2, 2025  
**Purpose:** 5 categories that make system "factory-ready" and "scale-ready from day 1"  
**Prerequisite:** Complete [`RISK_PLAYBOOK.md`](RISK_PLAYBOOK.md) first (50 risk scenarios)

---

## 🎯 **Overview: The 5 Multipliers**

**After implementing core features:**
- ✅ Work queue works
- ✅ Risk playbook covered

**Add these 5 multipliers:**
- 🔧 Engineering Hardening (7 practices)
- 💾 Data Integrity & Recovery (4 practices)
- 🎨 UX Error Prevention (5 practices)
- 🚀 Operations & Change Management (4 practices)
- 🔐 Security, Label & Customer Trace (4 practices)

**Result:**
- System is **factory-ready** (survives real-world chaos)
- System is **scale-ready** (handles growth from day 1)

---

## 🔧 **Category 1: Engineering Hardening**

### **1.1 Feature Flags + Kill Switch** ⭐

**Purpose:** Turn off broken feature in 1 click (no deploy)

**Implementation:**
```php
// config.php or database table
$featureFlags = [
    'enable_dag_routing' => true,
    'enable_serial_tracking' => true,
    'enable_offline_queue' => true,
    'enable_work_queue' => true,
    'enable_multi_operator' => true
];

// Per-tenant override
$tenantFlags = getTenantFeatureFlags($orgCode);
$flags = array_merge($featureFlags, $tenantFlags);

// Usage
if (!$flags['enable_work_queue']) {
    // Fallback to old behavior
    return handleLegacyTaskList();
}

// Admin UI: Toggle switch per feature
```

**Benefits:**
- ✅ Instant rollback (no code deploy)
- ✅ A/B testing (enable for 10% users)
- ✅ Gradual rollout (per department)

---

### **1.2 Shadow Mode (Dark Launch)** 🌓

**Purpose:** Run new system in parallel, compare results, gain confidence

**Implementation:**
```php
// Run DAG projection in shadow mode (no user impact)
if (SHADOW_MODE_ENABLED) {
    // Run new logic (don't save to production tables)
    $shadowResult = projectTokenEventsToShadowTable($events);
    
    // Compare with old logic
    $productionResult = calculateTaskProgressOldWay($taskId);
    
    // Log difference
    if ($shadowResult !== $productionResult) {
        logShadowDiff([
            'task_id' => $taskId,
            'production' => $productionResult,
            'shadow' => $shadowResult,
            'diff_pct' => abs($shadowResult - $productionResult) / $productionResult * 100
        ]);
    }
}

// After 1-2 weeks: If diff < 1% → safe to switch
```

**Dashboard:**
```sql
-- Shadow mode accuracy
SELECT 
    DATE(created_at) as date,
    COUNT(*) as comparisons,
    SUM(CASE WHEN diff_pct < 1 THEN 1 ELSE 0 END) as matches,
    ROUND(SUM(CASE WHEN diff_pct < 1 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) as accuracy_pct
FROM shadow_comparison_log
GROUP BY date;

-- Target: accuracy_pct > 99% for 7+ days → ready to switch
```

---

### **1.3 Golden Scenarios (Test Fixtures)** 🏆

**Purpose:** 5 representative jobs that exercise all features

**Fixture Set:**
```php
// tests/fixtures/golden_scenarios.php

return [
    'simple_linear' => [
        'ticket_code' => 'GOLDEN-001',
        'process_mode' => 'batch',
        'routing_mode' => 'linear',
        'tasks' => [
            ['step' => 'CUT', 'qty' => 50],
            ['step' => 'SEW', 'qty' => 50],
            ['step' => 'FINISH', 'qty' => 50]
        ],
        'expected_duration' => 120, // minutes
        'expected_events' => 6 // start+complete per task
    ],
    
    'piece_mode_atelier' => [
        'ticket_code' => 'GOLDEN-002',
        'process_mode' => 'piece',
        'routing_mode' => 'dag',
        'target_qty' => 10,
        'serials' => ['TOTE-001', ..., 'TOTE-010'],
        'expected_per_piece_time' => 45, // minutes
        'expected_pause_resume' => true
    ],
    
    'parallel_assembly' => [
        'ticket_code' => 'GOLDEN-003',
        'routing_mode' => 'dag',
        'graph' => 'parallel_3_branch_join',
        'nodes' => ['CUT', 'SEW_BODY', 'SEW_STRAP', 'SEW_HANDLE', 'ASSEMBLY'],
        'expected_parallel_time_saving' => 0.4 // 40% faster
    ],
    
    'qc_fail_rework' => [
        'ticket_code' => 'GOLDEN-004',
        'routing_mode' => 'dag',
        'inject_qc_fail' => ['TOTE-003', 'TOTE-007'],
        'expected_rework_loops' => 2,
        'expected_final_yield' => 0.8 // 80% (2/10 scrapped)
    ],
    
    'offline_recovery' => [
        'ticket_code' => 'GOLDEN-005',
        'simulate_offline' => true,
        'offline_events' => 15,
        'duplicate_submissions' => 3,
        'expected_unique_events' => 15, // Not 18 (idempotent)
        'expected_sync_time' => 10 // seconds
    ]
];
```

**CI/CD Integration:**
```bash
# Run golden scenarios on every deployment
vendor/bin/phpunit tests/Integration/GoldenScenariosTest.php

# All must pass before deploy to production
```

---

### **1.4 Observability Pack** 📊

**Purpose:** See everything happening in real-time

**Structured Logging:**
```php
// Every event includes rich context
function logEvent($type, $data) {
    error_log(json_encode([
        'timestamp' => microtime(true),
        'type' => $type,
        'operator_id' => $data['operator_id'],
        'device_id' => $data['device_id'],
        'app_version' => $data['app_version'],
        'idempotency_key' => $data['idem_key'],
        'server_time' => date('Y-m-d H:i:s'),
        'client_time' => $data['client_time'],
        'latency_ms' => round((microtime(true) - $data['request_start']) * 1000, 2),
        'duplicate' => $data['is_duplicate'] ?? false,
        'conflict' => $data['had_conflict'] ?? false,
        'client_seq' => $data['client_seq'] // Monotonic counter per operator/day
    ]));
}
```

**Dashboard Queries:**
```sql
-- Real-time metrics (refresh every 30s)
CREATE VIEW v_system_health AS
SELECT 
    'Duplicate Rate' as metric,
    CONCAT(
        ROUND((COUNT(*) - COUNT(DISTINCT idempotency_key)) / COUNT(*) * 100, 3), 
        '%'
    ) as value,
    CASE 
        WHEN (COUNT(*) - COUNT(DISTINCT idempotency_key)) / COUNT(*) < 0.001 THEN 'OK'
        WHEN (COUNT(*) - COUNT(DISTINCT idempotency_key)) / COUNT(*) < 0.005 THEN 'WARNING'
        ELSE 'CRITICAL'
    END as status
FROM wip_log
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 1 HOUR)

UNION ALL

SELECT 
    'Dangling Work',
    CONCAT(COUNT(*), ' tokens'),
    CASE 
        WHEN COUNT(*) < 3 THEN 'OK'
        WHEN COUNT(*) < 10 THEN 'WARNING'
        ELSE 'CRITICAL'
    END
FROM flow_token t
JOIN token_work_session s ON s.id_token = t.id_token
WHERE s.status = 'active'
  AND TIMESTAMPDIFF(HOUR, s.started_at, NOW()) > 2;
```

**Alert Rules:**
```javascript
// Monitor dashboard, trigger alerts
const alerts = {
    duplicate_rate: { threshold: 0.1, action: 'review_idempotency' },
    conflict_rate: { threshold: 0.5, action: 'check_locking' },
    sync_p95: { threshold: 60, action: 'investigate_network' },
    dangling_work: { threshold: 3, action: 'notify_supervisor' },
    qc_leak: { threshold: 0.3, action: 'review_gates' }
};
```

---

### **1.5 Backpressure & Spike Arrest** 🚦

**Purpose:** Prevent thundering herd when network returns

**Implementation:**
```php
// Rate limiting per device
$deviceId = $_SERVER['HTTP_X_DEVICE_ID'];
$key = "rate_limit:device:{$deviceId}";
$requests = $redis->incr($key);

if ($requests === 1) {
    $redis->expire($key, 60); // 1 minute window
}

if ($requests > 30) { // Max 30 requests/minute per device
    http_response_code(429);
    json_error('Too many requests - please wait', 429);
}

// Per user
$userId = $member['id'];
$userKey = "rate_limit:user:{$userId}";
$userRequests = $redis->incr($userKey);

if ($userRequests > 100) { // Max 100/minute per user
    json_error('Rate limit exceeded', 429);
}
```

**Client-side backoff:**
```javascript
// Retry with jitter to prevent thundering herd
async function syncQueue() {
    const jitter = Math.random() * 5000; // 0-5 seconds
    await sleep(jitter);
    
    for (const item of queue) {
        await syncItem(item);
        await sleep(100); // 100ms between items (not all at once)
    }
}
```

---

### **1.6 Config as Code** ⚙️

**Purpose:** Factory policies versioned and deployable

**Config Structure:**
```yaml
# config/factory_policy.yaml
work_centers:
  SEW_BODY:
    auto_pause_threshold_minutes: 30
    qc_required: true
    qc_sample_rate: 1.0  # 100%
    parallel_operators_max: 3
    
  ASSEMBLY:
    qc_required: true
    bom_check_required: true
    component_timeout_hours: 24
    
global:
  session_timeout_hours: 8
  offline_queue_max: 100
  sync_batch_size: 10
  lock_expiry_minutes: 15
```

**Deployment:**
```bash
# Deploy config changes (no code deploy)
php deploy_config.php --env production --config factory_policy.yaml

# Validate before deploy
php validate_config.php factory_policy.yaml
```

---

### **1.7 Materialized Views (Read Performance)** 📈

**Purpose:** Fast queries without locking event log

**Architecture:**
```
Event Log (Immutable, Write-Optimized)
├─ atelier_wip_log
└─ token_event

      ↓ (Projector runs every 5 min)

Materialized Views (Read-Optimized)
├─ v_task_progress (aggregated by task)
├─ v_token_status (current state per token)
├─ v_operator_daily_summary (performance metrics)
└─ v_work_queue_snapshot (fast queue loading)
```

**Projector:**
```php
// Cron job: php projector.php (every 5 minutes)

function projectTokenStatus() {
    // Rebuild materialized view from events
    $db->query("TRUNCATE TABLE v_token_status_snapshot");
    
    $db->query("
        INSERT INTO v_token_status_snapshot
        SELECT 
            t.id_token,
            t.serial_number,
            t.current_node_id,
            MAX(te.event_time) as last_event_time,
            (SELECT event_type FROM token_event 
             WHERE id_token = t.id_token 
             ORDER BY event_time DESC LIMIT 1) as last_event_type,
            s.operator_user_id,
            s.started_at,
            CASE 
                WHEN s.status = 'active' THEN TIMESTAMPDIFF(MINUTE, s.started_at, NOW())
                ELSE 0
            END as elapsed_minutes
        FROM flow_token t
        LEFT JOIN token_event te ON te.id_token = t.id_token
        LEFT JOIN token_work_session s ON s.id_token = t.id_token AND s.status IN ('active','paused')
        WHERE t.status IN ('active','paused','qc_pending')
        GROUP BY t.id_token
    ");
    
    echo "✅ Projected " . $db->affected_rows . " token statuses\n";
}
```

**Benefits:**
- ✅ Work queue loads in < 100ms (not 500ms)
- ✅ No locks on event log
- ✅ Dashboard queries don't impact writes

---

## 💾 **Category 2: Data Integrity & Recovery**

### **2.1 Disaster Playbook (1 Page)** 🚨

**When Database Down / Queue Stuck:**

```
STEP 1: FREEZE WRITES (2 min)
├─ Set feature flag: enable_work_queue = false
├─ Show operators: "ระบบปรับปรุง - กลับมา 15 นาที"
└─ Stop all cron jobs (projectors, reconciliation)

STEP 2: DRAIN QUEUE (5 min)
├─ Let pending sync requests complete
├─ Monitor: Queue size decreasing
└─ Target: 0 pending events

STEP 3: BACKFILL PROJECTOR (5 min)
├─ Run: php projector.php --force --all
├─ Verify: Materialized views match event log
└─ Sanity check: Random sample 10 tokens

STEP 4: SANITY CHECKS (5 min)
├─ Count: Tokens spawned = Serials generated
├─ Count: Completed tokens ≤ Target qty
├─ Verify: No orphan events (id_token = NULL)
└─ Check: Lock owner valid (no deleted users)

STEP 5: REOPEN (2 min)
├─ Set feature flag: enable_work_queue = true
├─ Announce: "ระบบพร้อมใช้งาน"
└─ Monitor: First 10 events successful

TOTAL TIME: ~20 minutes
```

**Practice Drill:**
```bash
# Monthly disaster recovery drill
php disaster_drill.php --scenario db_corruption --tenant default

# Simulate:
# - Database rollback to 1 hour ago
# - Queue has 50 pending events
# - Projector out of sync

# Verify:
# - Can recover to consistent state
# - No data loss
# - Recovery time < 20 minutes
```

---

### **2.2 Point-in-Time Recovery (PITR)** ⏰

**Purpose:** Restore to specific timestamp if corruption detected

**Backup Strategy:**
```bash
# Automated backups
0 */4 * * * mysqldump bgerp_t_default atelier_job_ticket flow_token token_event > backup_$(date +\%Y\%m\%d_\%H\%M).sql

# Retention policy
- Hourly: Keep 24 hours
- Daily: Keep 30 days
- Weekly: Keep 1 year
- Monthly: Keep forever

# PITR enable (MySQL)
binlog_format = ROW
binlog_expire_logs_seconds = 604800 # 7 days
```

**Recovery:**
```bash
# Restore to 10:30 AM today
mysqlbinlog --stop-datetime="2025-11-02 10:30:00" binlog.000123 | mysql bgerp_t_default

# Verify
SELECT COUNT(*) FROM flow_token WHERE created_at <= '2025-11-02 10:30:00';
```

**Monthly Drill:**
```bash
# Practice restore
php test_restore.php --target-time "1 hour ago"

# Verify:
# - Data restored correctly
# - No data loss
# - Recovery time < 15 minutes
```

---

### **2.3 Audit Trail (Human-Readable)** 📝

**Purpose:** "What changed?" page that anyone can understand

**UI:**
```
┌─────────────────────────────────────────────┐
│ What Changed - TOTE-003                     │
├─────────────────────────────────────────────┤
│ Nov 2, 10:20 - Status changed              │
│ From: In Progress → To: Completed           │
│ By: ช่าง A (ID: 42)                         │
│ Why: Normal completion                      │
│ Duration: 35 minutes                        │
├─────────────────────────────────────────────┤
│ Nov 2, 10:00 - Work resumed                │
│ From: Paused → To: In Progress              │
│ By: ช่าง A (ID: 42)                         │
│ Paused for: 95 minutes                      │
├─────────────────────────────────────────────┤
│ Nov 2, 08:25 - Work paused                 │
│ From: In Progress → To: Paused              │
│ By: ช่าง A (ID: 42)                         │
│ Reason: Break                               │
└─────────────────────────────────────────────┘
```

**Implementation:**
```php
function getAuditTrail($tokenId) {
    $events = db_fetch_all($db, "
        SELECT 
            te.event_type,
            te.event_time,
            te.operator_name,
            te.notes,
            te.from_node_id,
            te.to_node_id,
            s.work_minutes
        FROM token_event te
        LEFT JOIN token_work_session s ON s.id_token = te.id_token
        WHERE te.id_token = ?
        ORDER BY te.event_time DESC
    ", [$tokenId]);
    
    $trail = [];
    foreach ($events as $event) {
        $trail[] = formatAuditEntry($event);
    }
    
    return $trail;
}

function formatAuditEntry($event) {
    return [
        'timestamp' => thai_date($event['event_time']),
        'action' => translateEventType($event['event_type']),
        'actor' => $event['operator_name'],
        'details' => formatDetails($event)
    ];
}
```

---

### **2.4 Reconciliation Jobs** 🔍

**Purpose:** Detect data anomalies automatically

**Nightly Checks:**
```php
// Cron: php reconciliation.php (every night at 2 AM)

function reconcile() {
    $issues = [];
    
    // Rule 1: Serial count vs target qty
    $mismatch = db_fetch_all($db, "
        SELECT 
            t.id_job_ticket,
            t.ticket_code,
            t.target_qty,
            COUNT(s.id_serial) as serial_count
        FROM atelier_job_ticket t
        LEFT JOIN job_ticket_serial s ON s.id_job_ticket = t.id_job_ticket
        WHERE t.process_mode = 'piece'
        GROUP BY t.id_job_ticket
        HAVING COUNT(s.id_serial) != t.target_qty
    ");
    
    if (count($mismatch) > 0) {
        $issues[] = [
            'rule' => 'serial_count_mismatch',
            'severity' => 'high',
            'count' => count($mismatch),
            'fix' => 'generate_missing_or_retire_excess',
            'tickets' => array_column($mismatch, 'ticket_code')
        ];
    }
    
    // Rule 2: Orphan events (no valid token)
    $orphans = db_fetch_all($db, "
        SELECT COUNT(*) as count
        FROM token_event te
        WHERE te.id_token IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM flow_token WHERE id_token = te.id_token)
    ");
    
    if ($orphans[0]['count'] > 0) {
        $issues[] = [
            'rule' => 'orphan_events',
            'severity' => 'medium',
            'count' => $orphans[0]['count'],
            'fix' => 'link_to_correct_token_or_archive'
        ];
    }
    
    // Rule 3: QC required but no pass
    $qcPending = db_fetch_all($db, "
        SELECT t.serial_number
        FROM flow_token t
        JOIN node_instance ni ON ni.id_node_instance = t.current_node_id
        JOIN routing_node rn ON rn.id_node = ni.id_node
        WHERE rn.qc_required = true
          AND t.status = 'completed'
          AND NOT EXISTS (
              SELECT 1 FROM token_event 
              WHERE id_token = t.id_token AND event_type = 'qc_pass'
          )
    ");
    
    if (count($qcPending) > 0) {
        $issues[] = [
            'rule' => 'qc_gate_bypassed',
            'severity' => 'critical',
            'count' => count($qcPending),
            'fix' => 'force_qc_or_rollback',
            'serials' => array_column($qcPending, 'serial_number')
        ];
    }
    
    // ... (5 more rules)
    
    // Generate fix list
    if (count($issues) > 0) {
        generateFixList($issues);
        notifySupervisor($issues);
    }
    
    return $issues;
}
```

**Fix List Output:**
```
RECONCILIATION REPORT - 2025-11-02
===================================

CRITICAL (1 issue):
❌ QC Gate Bypassed (3 tokens)
   Serials: TOTE-012, TOTE-015, TOTE-019
   Fix: php fix_qc_bypass.php --serials TOTE-012,TOTE-015,TOTE-019
   
HIGH (1 issue):
⚠️ Serial Count Mismatch (2 tickets)
   Tickets: JT-001 (10 target, 9 serials), JT-002 (5 target, 6 serials)
   Fix: php fix_serial_count.php --tickets JT-001,JT-002

TOTAL: 2 issues detected
```

---

## 🎨 **Category 3: UX Error Prevention**

### **3.1 Sticky Context Bar** 📌

**Purpose:** Always visible reminder of current work

**Implementation:**
```html
<!-- Always at top of screen -->
<div class="sticky-top bg-primary text-white p-2 d-flex justify-content-between align-items-center">
    <div>
        <i class="ri-timer-line"></i>
        <strong>กำลังทำ:</strong> TOTE-003 (SEW BODY)
        <small class="ms-2">เริ่มเมื่อ: 15 นาทีที่แล้ว</small>
    </div>
    <button class="btn btn-sm btn-light" onclick="resumeCurrentWork()">
        <i class="ri-play-line"></i> ทำต่อ
    </button>
</div>
```

**Auto-update:**
```javascript
setInterval(() => {
    const current = pwaState.currentWork;
    if (current) {
        const elapsed = Math.floor((Date.now() - current.started_at) / 60000);
        $('#sticky-timer').text(`${elapsed} นาทีที่แล้ว`);
    }
}, 30000); // Update every 30s
```

---

### **3.2 Smart Defaults** 🎯

**Purpose:** Auto-select next piece to reduce taps

**Logic:**
```javascript
// When opening work queue, auto-select:
// 1. My paused work (priority 1)
// 2. Next serial in sequence (priority 2)
// 3. First available (priority 3)

function getSmartDefault(queue) {
    // Priority 1: Resume paused
    const myPaused = queue.filter(t => 
        t.status === 'paused' && t.operator_id === currentUser.id
    );
    if (myPaused.length > 0) {
        return myPaused[0]; // Resume this
    }
    
    // Priority 2: Next in my sequence
    const myLast = getMyLastCompleted();
    if (myLast) {
        const nextSeq = myLast.sequence_no + 1;
        const next = queue.find(t => t.sequence_no === nextSeq && t.status === 'ready');
        if (next) return next;
    }
    
    // Priority 3: First available
    return queue.find(t => t.status === 'ready');
}

// Pre-select in UI
const defaultToken = getSmartDefault(queue);
if (defaultToken) {
    highlightToken(defaultToken.id);
    scrollIntoView(defaultToken.id);
}
```

---

### **3.3 Resolve Dialog (Standard Template)** 🔄

**Purpose:** Unified conflict resolution UX

**Template:**
```javascript
function showResolveDialog(conflict) {
    Swal.fire({
        title: '⚠️ ข้อมูลไม่ตรงกัน',
        html: `
            <div class="alert alert-warning text-start">
                <strong>สิ่งที่คุณทำ:</strong> ${conflict.your_action}<br>
                <strong>สิ่งที่เกิดขึ้น:</strong> ${conflict.current_state}
            </div>
            <p>ต้องการจะ:</p>
        `,
        showDenyButton: true,
        showCancelButton: true,
        confirmButtonText: '🔄 Retry (รีเฟรชและลองใหม่)',
        denyButtonText: '📝 บันทึกเป็น Note',
        cancelButtonText: '❌ ข้าม (ไม่บันทึก)'
    }).then(result => {
        if (result.isConfirmed) {
            // Refresh and retry
            refreshState().then(() => retryAction());
        } else if (result.isDenied) {
            // Convert to note
            convertToNote(conflict);
        } else {
            // Skip (idempotent - already processed)
            markAsResolved(conflict);
        }
    });
}
```

**Examples:**
```
Conflict 1: Serial already completed
"TOTE-003 ถูก complete โดยช่าง B เมื่อ 10:30"
→ [Retry] [บันทึกเป็น Note] [ข้าม]

Conflict 2: Token locked by another operator
"TOTE-005 กำลังถูกทำโดยช่าง C (ดับเครื่องไป 10 นาที)"
→ [รอต่อ] [Take Over (หัวหน้า)] [เลือก Serial อื่น]
```

---

### **3.4 Thai Microcopy (Ultra-Short)** 🇹🇭

**Purpose:** Clear, concise, no jargon

**Style Guide:**
```javascript
const microcopy = {
    // Status
    ready: "พร้อมเริ่ม",
    blocked: "รอ: {DEPS}",
    active: "กำลังทำ",
    paused: "พักไว้",
    completed: "เสร็จแล้ว",
    
    // Actions
    start: "เริ่มทำ",
    pause: "พักครู่",
    resume: "ทำต่อ",
    complete: "เสร็จสิ้น",
    
    // Feedback
    saving: "บันทึก...",
    saved: "✓ บันทึกแล้ว",
    offline: "ออฟไลน์ • บันทึกไว้แล้ว",
    syncing: "ซิงค์... {COUNT} รายการ",
    synced: "✓ ซิงค์เสร็จ",
    
    // Errors
    error: "ผิดพลาด",
    conflict: "ข้อมูลไม่ตรงกัน",
    retry: "ลองใหม่",
    
    // Guidance
    help_start: "กดเริ่มเมื่อพร้อมทำงาน",
    help_pause: "พักงานชั่วคราว กลับมาทำต่อได้",
    help_complete: "กดเมื่อเสร็จสมบูรณ์",
    help_offline: "ทำงานได้ปกติ ระบบจะซิงค์เมื่อมีเน็ต"
};

// Usage
<button title="${t('help_start')}">
    ${t('start')}
</button>
```

**Prohibited:**
```
❌ "Token ready — All edges satisfied"
❌ "Upstream dependency pending"
❌ "Materialized view sync required"

✅ "พร้อมเริ่ม"
✅ "รอ: STEP-2"
✅ "กำลังอัปเดต..."
```

---

### **3.5 Accessibility (ถุงมือ/มืดสนิท)** ♿

**Purpose:** Usable in factory conditions (gloves, low light, fatigue)

**Design Requirements:**
```css
/* Touch targets */
.btn-action {
    min-width: 44px;
    min-height: 44px;
    margin: 8px; /* Prevent mis-tap */
}

/* Contrast (WCAG AAA) */
.btn-primary {
    background: #0066cc;
    color: #ffffff;
    /* Contrast ratio: 8.2:1 */
}

/* Font size */
body {
    font-size: 16px; /* Min for readability */
}

.token-card {
    font-size: 18px; /* Larger for gloved fingers */
}

/* Haptic feedback (if supported) */
button:active {
    navigator.vibrate && navigator.vibrate(50);
}
```

**Scanner-Friendly:**
```javascript
// Support scanner input (no touch required)
document.addEventListener('scan', (event) => {
    const serial = event.detail.code;
    autoSelectToken(serial);
    // Operator can press physical button to confirm
});
```

---

## 🚀 **Category 4: Operations & Change Management**

### **4.1 Rollout Strategy (Pilot → Ring)** 🎯

**Purpose:** Gradual deployment with safety gates

**Rings:**
```
Ring 0 (Canary - 1 day):
├─ 1 production line
├─ 1 department (5 operators)
└─ Metric gate: Duplicate < 0.1%, Conflict < 0.5%

Ring 1 (Pilot - 1 week):
├─ 1 factory floor
├─ 2 departments (20 operators)
└─ Metric gate: QC leak < 0.3%, Sync p95 < 60s

Ring 2 (Staged - 2 weeks):
├─ Entire factory
├─ All departments (100 operators)
└─ Metric gate: MTTR < 15 min, Uptime > 99%

Ring 3 (Full - 4 weeks):
├─ All factories
├─ All operators (500+)
└─ Continuous monitoring
```

**Gate Enforcement:**
```php
// Before expanding to next ring
function checkMetricGate($ring) {
    $metrics = getCurrentMetrics();
    $gates = getRingGates($ring);
    
    foreach ($gates as $metric => $threshold) {
        if ($metrics[$metric] > $threshold) {
            return [
                'passed' => false,
                'failed_metric' => $metric,
                'value' => $metrics[$metric],
                'threshold' => $threshold,
                'action' => 'fix_before_expand'
            ];
        }
    }
    
    return ['passed' => true];
}
```

---

### **4.2 Supervisor Playbook** 👔

**Purpose:** Quick actions for common issues

**Playbook Cards:**

**Card 1: Dangling In-Progress > 2 Hours**
```
Problem: Token stuck, operator left
Action:
1. Check: Did operator logout? (No)
2. Contact operator (call/message)
3. If no response → Force-pause
   php force_pause.php --token TOTE-003 --reason "Operator unavailable"
4. Reassign to available operator
   php reassign_token.php --token TOTE-003 --operator 15
5. Log in audit trail
```

**Card 2: Duplicate Serials Detected**
```
Problem: Same serial used twice
Action:
1. Identify: Which is correct?
2. Mark duplicate: 
   php mark_duplicate_serial.php --serial TOTE-003-DUP --original TOTE-003
3. Generate replacement:
   php generate_replacement_serial.php --job JT-001
4. Update affected records
```

**Card 3: QC Fail ต่อเนื่อง (>3 ชิ้น)**
```
Problem: Quality issue, possible systemic
Action:
1. Stop-the-line (pause all work on this task)
   php stop_line.php --task SEW_BODY
2. Root cause analysis (5 Why)
3. Fix process/training
4. Resume line after verification
   php resume_line.php --task SEW_BODY --reason "Process corrected"
```

---

### **4.3 Training Cards (A6)** 🎓

**Purpose:** Quick reference on factory floor

**Card Format (A6 size, laminated):**

```
┌─────────────────────────────────────┐
│ การ์ด 1: เริ่มงาน (START)           │
├─────────────────────────────────────┤
│ 1. เปิดแอป → เลือก Task             │
│ 2. เห็นรายการ Serial                │
│ 3. แตะ Serial → กด [เริ่มทำ]        │
│ 4. Timer เริ่มนับ                   │
│                                     │
│ ⚠️ ข้อควรระวัง:                     │
│ • ทำได้ทีละชิ้น (งาน Atelier)      │
│ • ถ้ามีงานค้าง → พักอันเก่าก่อน     │
│                                     │
│ 📹 วิดีโอ:                          │
│ [QR Code]                           │
└─────────────────────────────────────┘
```

**6 Cards:**
1. เริ่มงาน (START)
2. พัก-ทำต่อ (PAUSE/RESUME)
3. เสร็จสิ้น (COMPLETE)
4. ตรวจสอบ (QC)
5. ออฟไลน์ (OFFLINE)
6. แก้ปัญหา (RESOLVE)

---

### **4.4 Post-Incident Review (30 min)** 📋

**Purpose:** Learn from every major issue

**Trigger:** Any incident affecting >10 pieces

**Format:**
```
INCIDENT: Serial ซ้ำ 5 ชิ้น (Nov 2, 2025)
=========================================

What Happened:
- Generator created duplicate serials (TOTE-001 to TOTE-005)
- 5 pieces affected
- Detected by nightly reconciliation

Root Cause:
- Random generator seed not unique
- Collision possible with crypto suffix only

Guardrail That Failed:
- No global uniqueness check before saving serial

Patch Applied:
- Add namespace (brand/sku/year/batch)
- Add global serial registry check
- PR #123 deployed Nov 2, 15:00

Owner: Tech Lead
Due: Verified in production by Nov 3

Lessons:
- Random alone insufficient for global uniqueness
- Need registry check at generation time
- Nightly reconciliation works (detected early)
```

---

## 🔐 **Category 5: Security, Label & Customer Trace**

### **5.1 Signed QR (Tamper-Proof)** 🔐

**Purpose:** Prevent forged QR codes

**Generation:**
```php
function generateSignedQR($payload) {
    $data = json_encode([
        'ticket_code' => $payload['ticket_code'],
        'serial' => $payload['serial'],
        'issued_at' => time(),
        'expires_at' => time() + 86400 // 24 hours
    ]);
    
    $signature = hash_hmac('sha256', $data, SECRET_KEY);
    $qrContent = base64_encode($data) . '.' . $signature;
    
    return generateQRCode($qrContent);
}
```

**Validation:**
```php
function validateSignedQR($qrContent) {
    [$encodedData, $signature] = explode('.', $qrContent);
    
    // Verify signature
    $expectedSig = hash_hmac('sha256', $encodedData, SECRET_KEY);
    if (!hash_equals($expectedSig, $signature)) {
        json_error('Invalid QR signature', 403);
    }
    
    // Decode and check expiry
    $data = json_decode(base64_decode($encodedData), true);
    if ($data['expires_at'] < time()) {
        json_error('QR code expired', 403);
    }
    
    return $data;
}
```

---

### **5.2 Label Readability Spec** 🏷️

**Purpose:** Scannable in factory conditions

**Physical Requirements:**
```
Font Size: ≥ 10pt (readable from 30cm)
Contrast: ≥ 7:1 (WCAG AAA)
Material: Waterproof, tear-resistant
Placement: Not on fold/stitch lines
QR Size: ≥ 2cm × 2cm (scannable at 50cm)
Lighting: Readable in low light (50 lux)
```

**Testing:**
```bash
# Test scan in various conditions
php test_label_readability.php

Conditions:
✅ Normal light (500 lux)
✅ Low light (50 lux)
✅ With gloves
✅ From 50cm distance
✅ Worn/scratched label
✅ Wet surface

Pass rate: > 95%
```

---

### **5.3 Customer Trace Portal (MVP)** 🔍

**Purpose:** Customer sees craftsmanship story

**Public Page:**
```
URL: https://trace.bellavier.com/{SERIAL}

┌─────────────────────────────────────────┐
│ Charlotte Aimée Tote Bag                │
│ Serial: TOTE-2025-A7F3C9                │
├─────────────────────────────────────────┤
│ ✨ Handcrafted in Bangkok Atelier      │
│                                         │
│ 👤 Crafted by: Artisan S.              │
│    (10 years experience)                │
│                                         │
│ ⏱️ Craftsmanship Timeline:              │
│    Cutting: 15 minutes                  │
│    Sewing: 45 minutes                   │
│    Edge work: 30 minutes                │
│    Quality check: Passed ✓              │
│                                         │
│ 📅 Completed: November 2, 2025          │
│                                         │
│ 🏆 Quality Certification                │
│    [View Certificate PDF]               │
└─────────────────────────────────────────┘
```

**Privacy Boundaries:**
```
Customer Sees:
✅ Artisan initial (not full name)
✅ Experience years
✅ Atelier location (city only)
✅ Timeline (approximate)
✅ Quality pass/fail

Customer Does NOT See:
❌ Artisan full name/ID
❌ Exact timestamps (hour:min:sec)
❌ Salary/performance data
❌ Internal notes
❌ Rework/scrap details
```

**Implementation:**
```php
// source/public_trace_api.php (no auth required)
case 'lookup_serial':
    $serial = $_GET['serial'];
    
    // Validate format (prevent enumeration)
    if (!preg_match('/^[A-Z]+-\d{4}-[A-F0-9]{6}$/', $serial)) {
        json_error('Invalid serial format', 400);
    }
    
    // Get public trace data
    $trace = getPublicTrace($serial);
    
    // Anonymize
    $trace['artisan_name'] = substr($trace['artisan_full_name'], 0, 1) . '.';
    $trace['timeline'] = roundTimeline($trace['exact_timeline'], 5); // Round to 5 min
    
    unset($trace['artisan_full_name']);
    unset($trace['exact_timeline']);
    unset($trace['internal_notes']);
    
    json_success($trace);
    break;
```

---

### **5.4 Privacy Controls** 🔒

**Purpose:** GDPR/PDPA compliance

**Data Classification:**
```
Public (Customer Trace):
├─ Serial number
├─ Product SKU
├─ Artisan initial
├─ Timeline (rounded)
└─ QC result (pass/fail)

Internal (Operator Dashboard):
├─ Full operator name
├─ Exact timestamps
├─ Pause reasons
├─ Performance metrics
└─ Error logs

Sensitive (Supervisor Only):
├─ Salary/bonus data
├─ Disciplinary records
├─ Personal information
└─ Audit trails
```

**Access Control:**
```php
// RBAC enforcement
$permissions = [
    'operator' => ['view_own_work', 'submit_events'],
    'supervisor' => ['view_all_work', 'force_actions', 'view_audit'],
    'admin' => ['view_sensitive', 'modify_config']
];

must_allow('atelier.work.view_audit'); // Before showing audit trail
```

---

## 📊 **Quality Metrics (Pass Criteria)**

### **Production Readiness Scorecard:**

| Category | Metric | Target | Current |
|----------|--------|--------|---------|
| **Reliability** | Duplicate rate | < 0.1% | ⏳ TBD |
| **Reliability** | Conflict rate | < 0.5% | ⏳ TBD |
| **Performance** | Sync p95 | < 60s | ⏳ TBD |
| **Quality** | QC leak rate | < 0.3% | ⏳ TBD |
| **Integrity** | Orphan events | 0 | ⏳ TBD |
| **Integrity** | Cycle count | 0 | ⏳ TBD |
| **Recovery** | MTTR | < 15 min | ⏳ TBD |
| **Availability** | Uptime | > 99.5% | ⏳ TBD |

**Go/No-Go Decision:**
```
All metrics meet targets for 7+ days 
+ Golden scenarios pass 100%
+ Supervisor training complete
= READY FOR PRODUCTION
```

---

## 🎯 **Small Things That Massively Help**

### **1. Undo Last 3 Actions** ↩️
```javascript
// Per-operator undo stack (max 3)
const undoStack = [];

function recordAction(action) {
    undoStack.push({
        type: action.type,
        token_id: action.token_id,
        timestamp: Date.now(),
        can_undo: canUndo(action.type)
    });
    
    if (undoStack.length > 3) {
        undoStack.shift(); // Keep only last 3
    }
}

function undo() {
    const last = undoStack.pop();
    if (!last || !last.can_undo) return;
    
    // Create compensating event
    createCompensatingEvent(last);
}

// Undoable actions: pause, resume, note
// Not undoable: complete (too critical)
```

**Benefits:**
- ✅ Reduces supervisor workload by 80%
- ✅ Operators fix own mistakes
- ✅ Audit trail preserved (compensating events)

---

### **2. Auto-Idle Detection** ⏱️
```javascript
// Suggest pause if no activity > 10 minutes
let lastActivity = Date.now();

setInterval(() => {
    const idle = Date.now() - lastActivity;
    
    if (idle > 10 * 60 * 1000 && hasActiveWork()) {
        Swal.fire({
            title: 'ไม่มีกิจกรรม 10 นาที',
            text: 'ต้องการพักงานไหม?',
            icon: 'question',
            showCancelButton: true,
            confirmButtonText: 'พักงาน',
            cancelButtonText: 'ทำต่อ'
        }).then(result => {
            if (result.isConfirmed) {
                pauseCurrentWork('auto_idle');
            }
        });
    }
}, 60000); // Check every minute

// Reset on any activity
document.addEventListener('click', () => lastActivity = Date.now());
```

---

### **3. Monotonic Client Sequence** 🔢
```javascript
// Per operator, per day
const clientSeq = {
    get: () => {
        const key = `client_seq_${operatorId}_${today}`;
        let seq = localStorage.getItem(key) || 0;
        seq = parseInt(seq) + 1;
        localStorage.setItem(key, seq);
        return seq;
    }
};

// Include in every event
payload.client_seq = clientSeq.get();

// Server validates
if ($event['client_seq'] < $lastSeq - 10) {
    // Out of order by >10 (suspicious)
    logAnomaly('client_seq_out_of_order', [
        'operator_id' => $operatorId,
        'expected' => $lastSeq + 1,
        'received' => $event['client_seq']
    ]);
}
```

**Benefits:**
- ✅ Detect out-of-order events
- ✅ Find replay attacks
- ✅ Debug timeline issues

---

### **4. Dark Launch Split View** 🌗
```javascript
// Enable for power users only (feature flag)
if (user.is_power_user || featureFlags.split_view_beta) {
    showSplitViewToggle();
}

// A/B test: 10% users get new UI
if (Math.random() < 0.1) {
    enableFeature('split_view');
}

// Collect feedback
trackFeatureUsage('split_view', {
    user_id,
    satisfaction,
    time_saved
});
```

---

## 📋 **Implementation Checklist**

### **Must-Have (Before Production):**

**Engineering:**
- [ ] Feature flags (per tenant)
- [ ] Kill switch (disable features remotely)
- [ ] Golden scenarios (5 fixtures)
- [ ] Observability (structured logging)
- [ ] Rate limiting (30 req/min per device)

**Data:**
- [ ] Disaster playbook (documented)
- [ ] PITR enabled (binlog retention)
- [ ] Audit trail (human-readable)
- [ ] Reconciliation jobs (nightly)

**UX:**
- [ ] Sticky context bar
- [ ] Smart defaults (auto-select next)
- [ ] Resolve dialog (standard template)
- [ ] Thai microcopy (no jargon)
- [ ] Accessibility (44px buttons, high contrast)

**Operations:**
- [ ] Ring deployment plan
- [ ] Supervisor playbook (3 cards)
- [ ] Training cards (A6, 6 cards)
- [ ] Post-incident review template

**Security:**
- [ ] Signed QR (HMAC)
- [ ] Label readability spec
- [ ] Customer trace portal
- [ ] Privacy boundaries (RBAC)

---

## 🎯 **Quality Gates (Before Each Ring)**

### **Ring 0 → Ring 1:**
```
Metrics (7 days):
✅ Duplicate rate < 0.1%
✅ Conflict rate < 0.5%
✅ Golden scenarios pass 100%
✅ No critical incidents
```

### **Ring 1 → Ring 2:**
```
Metrics (14 days):
✅ QC leak < 0.3%
✅ Sync p95 < 60s
✅ Operator satisfaction > 4/5
✅ Supervisor feedback positive
```

### **Ring 2 → Ring 3:**
```
Metrics (30 days):
✅ MTTR < 15 min
✅ Uptime > 99.5%
✅ All supervisors trained
✅ Disaster drill passed
```

---

## 📈 **Scale-Ready Indicators**

### **System is scale-ready when:**

1. **Load Testing Passed** ✅
   - 100 concurrent operators
   - 1,000 tokens in flight
   - 10,000 events/hour
   - Response time < 200ms (p95)

2. **Chaos Engineering Passed** ✅
   - Random network failures → recovers
   - Random database restarts → no data loss
   - Random device crashes → queue preserved

3. **Metrics Stable** ✅
   - 30 days in production
   - All KPIs within targets
   - No degradation over time

4. **Team Confident** ✅
   - Operators comfortable (4/5 satisfaction)
   - Supervisors can troubleshoot
   - Tech team has playbooks

---

## 🎓 **For Development Team**

### **When to Apply Hardening:**

**Phase 1 (Core Features):**
- ⏸️ Skip hardening (focus on functionality)

**Phase 2 (Alpha Testing):**
- ✅ Add: Feature flags, logging, basic metrics

**Phase 3 (Beta - Pilot):**
- ✅ Add: Shadow mode, golden scenarios, supervisor playbook

**Phase 4 (Production):**
- ✅ Add: Full observability, disaster playbook, customer trace
- ✅ All 5 categories complete

**Don't over-engineer early!**
- Week 1-2: Build core features
- Week 3: Add critical hardening (idempotency, locking)
- Week 4: Add production hardening (this document)

---

## ✅ **Success Criteria**

**System is "factory-ready" when:**
- [ ] All 50 risk scenarios mitigated (RISK_PLAYBOOK)
- [ ] All 5 quality multipliers implemented (this doc)
- [ ] Golden scenarios pass 100%
- [ ] Ring 0 pilot successful (7 days)
- [ ] All KPIs meet targets
- [ ] Team trained and confident

**System is "scale-ready" when:**
- [ ] Load testing passed (100 concurrent)
- [ ] Chaos testing passed (random failures)
- [ ] 30 days stable metrics
- [ ] Ring 3 rollout complete
- [ ] Customer trace portal live
- [ ] Disaster recovery drilled monthly

---

**Created:** November 2, 2025  
**Status:** Active hardening guide  
**Apply After:** Core features complete (Week 3-4)  
**Related:** [`RISK_PLAYBOOK.md`](RISK_PLAYBOOK.md) - 50 risk scenarios


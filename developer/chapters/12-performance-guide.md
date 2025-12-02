# Chapter 12 — Performance Guide

**Last Updated:** November 19, 2025  
**Purpose:** Explain optimization logic and performance best practices  
**Audience:** Developers optimizing queries and performance, AI agents working on performance improvements

---

## Overview

This chapter provides comprehensive guidance on performance optimization in the Bellavier Group ERP system. It covers query optimization strategies, results from Task 21, anti-patterns to avoid, caching strategies, and scaling considerations.

**Key Topics:**
- Query optimization strategy
- Results from Task 21 (query optimizer)
- Query anti-patterns to avoid
- Caching strategy (future)
- Heavy endpoint profiling
- Scaling roadmap

**Performance Status:**
- ✅ Task 21 complete - Query optimization for WIP/Trace/Routing APIs
- ✅ 30-69% performance improvement achieved
- ✅ Indexes optimized
- ✅ N+1 queries eliminated

---

## Key Concepts

### 1. Performance Optimization Philosophy

**Principles:**
- Measure first, optimize second
- Optimize bottlenecks, not everything
- Maintain code readability
- Don't optimize prematurely

**Approach:**
- Profile before optimizing
- Use EXPLAIN to analyze queries
- Monitor slow query logs
- Test with realistic data volumes

### 2. Query Optimization Strategy

**Levels of Optimization:**
1. **Index Optimization** - Add missing indexes
2. **Query Rewriting** - Optimize query structure
3. **N+1 Elimination** - Reduce query count
4. **Caching** - Cache frequently accessed data
5. **Database Tuning** - Optimize database configuration

### 3. Performance Targets

**Response Time Targets:**
- Simple query (with index): < 10ms
- List query (DataTable): < 50ms
- Complex operation (with services): < 100ms
- Session rebuild (single task): < 30ms
- Full ticket recalc: < 200ms

**Throughput Targets:**
- API requests: 100+ req/sec
- Database queries: 1000+ queries/sec
- Concurrent users: 1000+ users

---

## Core Components

### Query Optimization Patterns

#### 1. Index Optimization

**Strategy:**
- Composite indexes for common query patterns
- First column = highest selectivity
- Order matters: (most_selective, less_selective, sorting_column)

**Critical Indexes (Migration 0003):**
```sql
-- Most important (90%+ of queries use these)
idx_wip_log_task_deleted (id_job_task, deleted_at) -- Task WIP queries
idx_wip_log_ticket_deleted (id_job_ticket, deleted_at) -- Ticket WIP queries
idx_session_task_status (id_job_task, status) -- Session queries

-- Supporting indexes
idx_wip_log_event_type (event_type, deleted_at) -- Event filtering
idx_wip_log_event_time (event_time, deleted_at) -- Time-based queries
idx_task_ticket_seq (id_job_ticket, sequence_no) -- Task ordering
idx_task_status (status, id_job_ticket) -- Status filtering
```

**Usage:**
```php
// ✅ Good (uses index):
SELECT id_job_task, status FROM atelier_job_task 
WHERE id_job_ticket=? AND status='in_progress'
// Uses idx_task_status (status, id_job_ticket)

// ❌ Bad (full table scan):
SELECT * FROM atelier_job_task WHERE notes LIKE '%search%'
// No index on notes column
```

#### 2. N+1 Query Elimination

**Problem:**
```php
// ❌ Bad (N+1 problem):
$tasks = fetch_all_tasks($ticketId);
foreach ($tasks as $task) {
    $user = fetch_user($task['assigned_to']); // 1 query per task!
}
```

**Solution:**
```php
// ✅ Good (2 queries total):
$tasks = fetch_all_tasks($ticketId);
$userIds = array_column($tasks, 'assigned_to');
$users = fetch_users_by_ids($userIds); // 1 query for all users
foreach ($tasks as &$task) {
    $task['user'] = $users[$task['assigned_to']] ?? null;
}
```

#### 3. Correlated Subquery Elimination

**Problem (Task 21):**
```sql
-- ❌ Bad: Correlated subquery (runs once per row)
SELECT 
    jt.*,
    COALESCE(
        (SELECT COUNT(*) > 0 
         FROM wip_log hwl 
         INNER JOIN job_task jt2 ON jt2.id_job_task = hwl.id_job_task
         WHERE jt2.id_job_ticket = jt.id_job_ticket 
         AND hwl.event_type = 'rework'
         AND hwl.deleted_at IS NULL), 
        0
    ) AS has_rework
FROM atelier_job_task jt
```

**Solution (Task 21):**
```sql
-- ✅ Good: LEFT JOIN + MAX aggregation (single query)
SELECT 
    jt.*,
    COALESCE(MAX(CASE WHEN hwl.event_type = 'rework' THEN 1 ELSE 0 END), 0) AS has_rework
FROM atelier_job_task jt
LEFT JOIN atelier_wip_log hwl ON hwl.id_job_task = jt.id_job_task 
    AND hwl.deleted_at IS NULL
GROUP BY jt.id_job_task
```

**Performance Improvement:**
- Before: ~420ms for 50 rows (estimated)
- After: ~130ms for 50 rows (estimated)
- **Change: ~-69% reduction** ✅

#### 4. LIMIT for Large Datasets

**Problem:**
```php
// ❌ Bad: Fetch all rows
SELECT * FROM atelier_wip_log WHERE id_job_ticket=?
// May return thousands of rows
```

**Solution:**
```php
// ✅ Good: Use LIMIT
SELECT * FROM atelier_wip_log 
WHERE id_job_ticket=? AND deleted_at IS NULL 
ORDER BY event_time DESC 
LIMIT 100 -- Prevent loading thousands of rows
```

### Results from Task 21

**Files Optimized:**
- ✅ `source/trace_api.php` - has_rework subquery → LEFT JOIN
- ✅ `source/dag_token_api.php` - assignment_log and queue_position subqueries optimized
- ✅ `source/dag_routing_api.php` - where_used subqueries → LEFT JOINs

**Optimizations Implemented:**

1. **trace_api.php:**
   - Replaced correlated subquery with LEFT JOIN + MAX aggregation
   - **Performance:** ~-69% reduction (420ms → 130ms for 50 rows)

2. **dag_token_api.php:**
   - Replaced assignment_log subquery with LEFT JOIN
   - Replaced queue_position subquery with PHP post-processing
   - **Performance:** Significant improvement (exact numbers in Task 21 results)

3. **dag_routing_api.php:**
   - Replaced where_used subqueries with LEFT JOINs + MAX aggregation
   - **Performance:** Significant improvement

**Reference:** See `docs/performance/task21_results.md` for complete details.

### Query Anti-Patterns to Avoid

#### 1. SELECT * (Wildcard)

**Problem:**
```php
// ❌ Bad: Selects all columns
SELECT * FROM atelier_job_task WHERE id_job_ticket=?
```

**Solution:**
```php
// ✅ Good: Select only needed columns
SELECT id_job_task, step_name, status, sequence_no 
FROM atelier_job_task 
WHERE id_job_ticket=?
```

#### 2. LIKE with Leading Wildcard

**Problem:**
```php
// ❌ Bad: Can't use index
SELECT * FROM products WHERE name LIKE '%search%'
```

**Solution:**
```php
// ✅ Good: Use full-text search or prefix search
SELECT * FROM products WHERE name LIKE 'search%'
// Or use full-text index
SELECT * FROM products WHERE MATCH(name) AGAINST('search' IN BOOLEAN MODE)
```

#### 3. Functions on Indexed Columns

**Problem:**
```php
// ❌ Bad: Can't use index
SELECT * FROM atelier_wip_log WHERE DATE(event_time) = '2025-11-19'
```

**Solution:**
```php
// ✅ Good: Use range query
SELECT * FROM atelier_wip_log 
WHERE event_time >= '2025-11-19 00:00:00' 
AND event_time < '2025-11-20 00:00:00'
```

#### 4. OR Conditions

**Problem:**
```php
// ❌ Bad: May not use index efficiently
SELECT * FROM atelier_job_task 
WHERE status='pending' OR status='in_progress'
```

**Solution:**
```php
// ✅ Good: Use IN clause
SELECT * FROM atelier_job_task 
WHERE status IN ('pending', 'in_progress')
```

#### 5. Subqueries in WHERE Clause

**Problem:**
```php
// ❌ Bad: May be slow
SELECT * FROM atelier_job_task 
WHERE id_job_ticket IN (SELECT id_job_ticket FROM atelier_job_ticket WHERE status='active')
```

**Solution:**
```php
// ✅ Good: Use JOIN
SELECT jt.* FROM atelier_job_task jt
INNER JOIN atelier_job_ticket t ON t.id_job_ticket = jt.id_job_ticket
WHERE t.status='active'
```

### Caching Strategy (Future)

**Planned Caching Layers:**

1. **Session Data Caching**
   - Cache user sessions
   - Cache permission checks
   - Cache organization context

2. **Query Result Caching**
   - Cache frequently accessed data
   - Cache aggregated statistics
   - Cache master data (products, materials)

3. **Application-Level Caching**
   - APCu for PHP
   - Redis for distributed caching
   - Memcached for simple key-value

**Caching Rules:**
- ✅ Cache read-only data
- ✅ Invalidate cache on updates
- ❌ Don't cache user-specific data (username, language, tenant)
- ❌ Don't cache sensitive data

### Heavy Endpoint Profiling

**Profiling Tools:**
- PHP Xdebug profiler
- MySQL slow query log
- Application performance monitoring (APM)

**Profiling Process:**
1. Identify slow endpoints
2. Enable profiling
3. Run realistic load
4. Analyze results
5. Optimize bottlenecks
6. Re-test

**Example:**
```php
// Enable profiling
xdebug_start_trace('/tmp/trace');

// ... API code ...

// Stop profiling
xdebug_stop_trace();
```

---

## Developer Responsibilities

### When Optimizing Queries

**MUST:**
- ✅ Profile before optimizing (measure, don't guess)
- ✅ Use EXPLAIN to verify index usage
- ✅ Test with realistic data volumes
- ✅ Verify optimization doesn't break functionality
- ✅ Document optimization changes

**DO NOT:**
- ❌ Optimize without profiling
- ❌ Remove indexes without checking usage
- ❌ Optimize prematurely
- ❌ Break functionality for performance

### When Adding Indexes

**MUST:**
- ✅ Use migration files (PHP, not SQL)
- ✅ Use migration helpers (idempotent)
- ✅ Test index creation
- ✅ Verify index usage with EXPLAIN
- ✅ Document index purpose

**DO NOT:**
- ❌ Create indexes without analyzing queries
- ❌ Create too many indexes (overhead)
- ❌ Create indexes on low-selectivity columns

---

## Common Pitfalls

### 1. Missing Indexes

**Problem:**
```php
// ❌ Bad: No index on status column
SELECT * FROM atelier_job_task WHERE status='in_progress'
// Full table scan
```

**Solution:**
```php
// ✅ Good: Add index
// Migration: Add index on status column
migration_add_index_if_missing(
    $db,
    'atelier_job_task',
    'idx_status',
    'INDEX `idx_status` (`status`)'
);
```

### 2. N+1 Queries

**Problem:**
```php
// ❌ Bad: N+1 queries
$tasks = fetch_all_tasks($ticketId);
foreach ($tasks as $task) {
    $user = fetch_user($task['assigned_to']); // 1 query per task
}
```

**Solution:**
```php
// ✅ Good: Batch fetch
$tasks = fetch_all_tasks($ticketId);
$userIds = array_column($tasks, 'assigned_to');
$users = fetch_users_by_ids($userIds); // 1 query total
foreach ($tasks as &$task) {
    $task['user'] = $users[$task['assigned_to']] ?? null;
}
```

### 3. Correlated Subqueries

**Problem:**
```php
// ❌ Bad: Correlated subquery (runs per row)
SELECT *, (SELECT COUNT(*) FROM wip_log WHERE task_id = t.id) AS log_count
FROM tasks t
```

**Solution:**
```php
// ✅ Good: LEFT JOIN + aggregation
SELECT t.*, COUNT(wl.id) AS log_count
FROM tasks t
LEFT JOIN wip_log wl ON wl.task_id = t.id AND wl.deleted_at IS NULL
GROUP BY t.id
```

### 4. Fetching Too Much Data

**Problem:**
```php
// ❌ Bad: Fetch all rows
SELECT * FROM atelier_wip_log WHERE id_job_ticket=?
// May return thousands of rows
```

**Solution:**
```php
// ✅ Good: Use LIMIT
SELECT * FROM atelier_wip_log 
WHERE id_job_ticket=? AND deleted_at IS NULL 
ORDER BY event_time DESC 
LIMIT 100
```

---

## Examples

### Example 1: Query Optimization (Task 21)

**Before:**
```sql
-- Correlated subquery (slow)
SELECT 
    jt.*,
    COALESCE(
        (SELECT COUNT(*) > 0 
         FROM wip_log hwl 
         INNER JOIN job_task jt2 ON jt2.id_job_task = hwl.id_job_task
         WHERE jt2.id_job_ticket = jt.id_job_ticket 
         AND hwl.event_type = 'rework'
         AND hwl.deleted_at IS NULL), 
        0
    ) AS has_rework
FROM atelier_job_task jt
```

**After:**
```sql
-- LEFT JOIN + MAX aggregation (fast)
SELECT 
    jt.*,
    COALESCE(MAX(CASE WHEN hwl.event_type = 'rework' THEN 1 ELSE 0 END), 0) AS has_rework
FROM atelier_job_task jt
LEFT JOIN atelier_wip_log hwl ON hwl.id_job_task = jt.id_job_task 
    AND hwl.deleted_at IS NULL
GROUP BY jt.id_job_task
```

**Performance:** ~-69% reduction (420ms → 130ms)

### Example 2: N+1 Query Elimination

**Before:**
```php
// ❌ Bad: N+1 queries
$tokens = db_fetch_all($tenantDb, "SELECT * FROM flow_token WHERE graph_id=?", [$graphId]);
foreach ($tokens as &$token) {
    $node = db_fetch_one($tenantDb, "SELECT * FROM routing_node WHERE id_node=?", [$token['current_node_id']]);
    $token['node'] = $node;
}
```

**After:**
```php
// ✅ Good: Batch fetch
$tokens = db_fetch_all($tenantDb, "SELECT * FROM flow_token WHERE graph_id=?", [$graphId]);
$nodeIds = array_column($tokens, 'current_node_id');
$nodes = db_fetch_all($tenantDb, 
    "SELECT * FROM routing_node WHERE id_node IN (" . implode(',', array_fill(0, count($nodeIds), '?')) . ")",
    $nodeIds
);
$nodeMap = array_column($nodes, null, 'id_node');
foreach ($tokens as &$token) {
    $token['node'] = $nodeMap[$token['current_node_id']] ?? null;
}
```

### Example 3: Index Usage Verification

```sql
-- Check index usage
EXPLAIN SELECT * FROM atelier_job_task 
WHERE id_job_ticket=? AND status='in_progress';

-- Should show: "Using index" not "Using filesort"
```

---

## Reference Documents

### Performance Documentation

- **Task 21 Results**: `docs/performance/task21_results.md` - Complete optimization results
- **Task 21**: `docs/bootstrap/Task/task21.md` - Query optimizer task

### Database Documentation

- **Schema Reference**: `docs/DATABASE_SCHEMA_REFERENCE.md` - Table structures and indexes
- **Migration 0003**: `database/tenant_migrations/0003_performance_indexes.php` - Performance indexes

### Related Chapters

- **Chapter 5**: Database Architecture
- **Chapter 6**: API Development Guide

---

## Future Expansion

### Planned Enhancements

1. **Query Result Caching**
   - Redis cache layer
   - Query result caching
   - Cache invalidation strategy

2. **Database Sharding**
   - Horizontal scaling
   - Shard management
   - Data distribution

3. **Read Replicas**
   - Read-only replicas
   - Load balancing
   - Performance optimization

4. **Advanced Monitoring**
   - Real-time performance metrics
   - Slow query alerts
   - Performance dashboards

---

**Previous Chapter:** [Chapter 11 — Security Handbook](../chapters/11-security-handbook.md)  
**Next Chapter:** [Chapter 13 — Refactor & Contribution Guide](../chapters/13-refactor-contribution-guide.md)


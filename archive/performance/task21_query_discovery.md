# Task 21: Query Optimizer Discovery & Profiling

**Status:** 🔍 IN PROGRESS (2025-11-19)  
**Task:** Query Optimizer for WIP / Trace / Routing APIs  
**Goal:** Identify bottlenecks and optimization opportunities in trace_api.php, dag_token_api.php, dag_routing_api.php

---

## Overview

This document records the discovery phase findings for query optimization in the WIP/Trace/Routing APIs. It identifies bottlenecks, N+1 query patterns, missing indexes, and other performance issues.

---

## 1. trace_api.php

### 1.1 handleTraceList() - Main List Query

**Location:** `source/trace_api.php` ~line 1882

**Query Pattern:**
```sql
SELECT SQL_CALC_FOUND_ROWS
    jts.serial_number AS serial,
    p.sku AS product_sku,
    p.name AS product_name,
    jt.ticket_code,
    jt.status,
    jt.production_type,
    rg.code AS graph_code,
    jt.completed_at,
    jgi.id_instance,
    COALESCE(
        (SELECT COUNT(*) > 0 
         FROM wip_log hwl 
         INNER JOIN job_task jt2 ON jt2.id_job_task = hwl.id_job_task
         WHERE jt2.id_job_ticket = jt.id_job_ticket 
         AND hwl.event_type = 'rework'
         AND hwl.deleted_at IS NULL), 
        0
    ) AS has_rework,
    NULL AS efficiency_percent
FROM job_ticket_serial jts
LEFT JOIN job_ticket jt ON jt.id_job_ticket = jts.id_job_ticket
LEFT JOIN job_graph_instance jgi ON jgi.id_job_ticket = jt.id_job_ticket
LEFT JOIN routing_graph rg ON rg.id_graph = jgi.id_graph
LEFT JOIN mo m ON m.id_mo = jt.id_mo
LEFT JOIN product p ON p.id_product = COALESCE(m.id_product, jt.id_product)
WHERE 1=1
GROUP BY jts.serial_number, jt.id_job_ticket, jgi.id_instance, p.id_product, rg.id_graph
ORDER BY {$sortColumn} {$dir}
LIMIT ? OFFSET ?
```

**Bottlenecks Identified:**

1. **Correlated Subquery for `has_rework`:**
   - Runs for EVERY row in result set
   - Pattern: `(SELECT COUNT(*) > 0 FROM wip_log ... WHERE jt2.id_job_ticket = jt.id_job_ticket)`
   - **Impact:** N+1 subquery pattern - if result has 50 rows, this subquery runs 50 times
   - **Optimization:** Use LEFT JOIN with aggregation instead of correlated subquery

2. **Multiple LEFT JOINs without explicit indexes:**
   - `jts.id_job_ticket` → `jt.id_job_ticket` (likely indexed, but verify)
   - `jgi.id_job_ticket` → `jt.id_job_ticket` (check index)
   - `jgi.id_graph` → `rg.id_graph` (check index)
   - `m.id_mo` → `jt.id_mo` (check index)
   - `COALESCE(m.id_product, jt.id_product)` → `p.id_product` (complex - check indexes)

3. **GROUP BY with multiple columns:**
   - `GROUP BY jts.serial_number, jt.id_job_ticket, jgi.id_instance, p.id_product, rg.id_graph`
   - May require temporary table if indexes don't support grouping
   - **Check:** EXPLAIN to see if `using temporary` or `using filesort`

4. **ORDER BY with dynamic column:**
   - Uses variable `{$sortColumn}` which may not match any index
   - **Check:** EXPLAIN to see if `using filesort`

5. **LIKE queries without prefix:**
   - Pattern: `jts.serial_number LIKE ?` with `%{$q}%`
   - Cannot use index for prefix-matching LIKE
   - **Impact:** Full table scan if LIKE is used

**Recommended Indexes:**
```sql
-- For serial_number search (if frequently searched)
CREATE INDEX idx_job_ticket_serial_serial_number ON job_ticket_serial(serial_number);

-- For job_ticket joins
CREATE INDEX idx_job_ticket_id_job_ticket_status ON job_ticket(id_job_ticket, status);
CREATE INDEX idx_job_graph_instance_id_job_ticket ON job_graph_instance(id_job_ticket);

-- For rework subquery optimization
CREATE INDEX idx_wip_log_job_task_rework ON wip_log(id_job_task, event_type, deleted_at);
CREATE INDEX idx_job_task_id_job_ticket ON job_task(id_job_ticket, id_job_task);

-- For sorting (cover common sort columns)
CREATE INDEX idx_job_ticket_completed_at_status ON job_ticket(completed_at, status);
CREATE INDEX idx_product_id_product_name ON product(id_product, name);
```

### 1.2 Serial Registry Enrichment (Cross-DB Query)

**Location:** `source/trace_api.php` ~line 2048-2075

**Query Pattern:**
```php
// After getting $rows from main query
$serials = array_column($rows, 'serial');
$placeholders = implode(',', array_fill(0, count($serials), '?'));
$stmt = $coreDb->prepare("
    SELECT serial_code, dag_token_id, job_ticket_id, status AS registry_status
    FROM serial_registry
    WHERE serial_code IN ($placeholders)
");
```

**Bottlenecks Identified:**

1. **Cross-DB query (Tenant → Core):**
   - Separate database connection required
   - **Impact:** Network latency + separate query execution
   - **Note:** This is necessary for architecture (cannot JOIN across DBs), but can be optimized

2. **IN clause with large arrays:**
   - If `$rows` has 100+ serials, IN clause becomes large
   - **Impact:** MySQL may switch to full table scan if IN list is too large
   - **Optimization:** Batch into chunks (e.g., 50 serials per query)

3. **Missing index on serial_code:**
   - **Check:** Verify `serial_registry.serial_code` has index
   - **If missing:** `CREATE INDEX idx_serial_registry_serial_code ON serial_registry(serial_code);`

**Current Implementation:**
- ✅ Already batches with IN clause (better than N+1)
- ⚠️ Could benefit from chunking if result set is large (>100 rows)

### 1.3 handleTraceBySerial() - Single Serial View

**Location:** `source/trace_api.php` ~line 1754

**Query Pattern:**
```sql
SELECT 
    jts_child.serial_number AS child_serial,
    jt_child.ticket_code AS child_ticket_code,
    ...
FROM inventory_transaction_item iti
INNER JOIN job_graph_instance jgi ON jgi.id_instance = iti.job_instance_id
LEFT JOIN job_ticket_serial jts_child ON jts_child.id_job_ticket = iti.source_doc_id 
    AND iti.source_doc_type = 'job_ticket'
LEFT JOIN job_ticket jt_child ON jt_child.id_job_ticket = jts_child.id_job_ticket
...
WHERE jgi.id_instance = ?
```

**Bottlenecks Identified:**

1. **Multiple LEFT JOINs:**
   - 5+ LEFT JOINs in a single query
   - **Check:** EXPLAIN to see join order and index usage

2. **Filter on source_doc_type in JOIN:**
   - `LEFT JOIN ... ON ... AND iti.source_doc_type = 'job_ticket'`
   - **Impact:** May prevent index usage on `source_doc_id`
   - **Optimization:** Move to WHERE clause if possible, or ensure composite index

**Recommended Indexes:**
```sql
-- For inventory_transaction_item lookups
CREATE INDEX idx_iti_job_instance_id ON inventory_transaction_item(job_instance_id);
CREATE INDEX idx_iti_source_doc ON inventory_transaction_item(source_doc_id, source_doc_type);

-- For job_ticket_serial joins
CREATE INDEX idx_jts_id_job_ticket_serial ON job_ticket_serial(id_job_ticket, serial_number);
```

---

## 2. dag_token_api.php

### 2.1 get_work_queue() - Main Work Queue Query

**Location:** `source/dag_token_api.php` ~line 1731

**Query Pattern:**
```sql
SELECT 
    t.id_token,
    t.serial_number,
    t.status,
    t.current_node_id,
    n.node_name,
    n.node_code,
    n.node_type,
    s.id_session,
    s.operator_user_id,
    s.status as session_status,
    ...
    CASE 
        WHEN t.status = 'waiting' THEN (
            SELECT COUNT(*) 
            FROM flow_token t2 
            WHERE t2.current_node_id = t.current_node_id 
              AND t2.status = 'waiting'
              AND t2.spawned_at < t.spawned_at
        ) + 1
        ELSE NULL
    END as queue_position
FROM flow_token t
JOIN routing_node n ON n.id_node = t.current_node_id
LEFT JOIN token_work_session s ON s.id_token = t.id_token AND s.status IN ('active', 'paused')
LEFT JOIN job_graph_instance gi ON gi.id_instance = t.id_instance
LEFT JOIN job_ticket jt ON jt.id_job_ticket = gi.id_job_ticket
LEFT JOIN mo ON mo.id_mo = COALESCE(jt.id_mo, gi.id_mo)
LEFT JOIN product p ON p.id_product = COALESCE(jt.id_product, mo.id_product)
LEFT JOIN token_assignment ta ON ta.id_token = t.id_token 
    AND ta.status IN ('assigned', 'accepted', 'started', 'paused')
LEFT JOIN bgerp.account acc ON acc.id_member = ta.assigned_to_user_id
LEFT JOIN bgerp.account replaced_acc ON replaced_acc.id_member = ta.replaced_from
LEFT JOIN assignment_log al ON al.token_id = t.id_token 
    AND al.node_id = t.current_node_id
    AND al.created_at = (
        SELECT MAX(al2.created_at) 
        FROM assignment_log al2 
        WHERE al2.token_id = t.id_token 
          AND al2.node_id = t.current_node_id
    )
WHERE 
    (t.status = 'ready' OR (t.status IN ('active', 'paused') AND s.operator_user_id = ?))
    AND t.current_node_id IS NOT NULL
    AND n.node_type IN ('operation', 'qc')
    AND gi.status = 'active'
    AND (jt.status IS NULL OR jt.status = 'in_progress')
    AND (jt.production_type IS NULL OR jt.production_type = 'hatthasilpa')
ORDER BY 
    CASE WHEN s.operator_user_id = ? THEN 0 ELSE 1 END,
    CASE WHEN ta.assigned_to_user_id = ? THEN 0 ELSE 1 END,
    t.spawned_at ASC
```

**Bottlenecks Identified:**

1. **Two Correlated Subqueries:**
   - `queue_position`: Runs for every waiting token
     - `(SELECT COUNT(*) FROM flow_token t2 WHERE ... AND t2.spawned_at < t.spawned_at)`
   - `assignment_log`: Runs for every token to get latest assignment reason
     - `(SELECT MAX(al2.created_at) FROM assignment_log al2 WHERE ...)`
   - **Impact:** 2N subqueries where N = number of tokens
   - **Optimization:** Use window functions (MySQL 8.0+) or pre-fetch with separate query

2. **Cross-DB JOINs (Core DB):**
   - `LEFT JOIN bgerp.account acc ON acc.id_member = ta.assigned_to_user_id`
   - `LEFT JOIN bgerp.account replaced_acc ON replaced_acc.id_member = ta.replaced_from`
   - **Impact:** Cannot use prepared statement JOIN across databases
   - **Current:** Likely uses separate queries or manual JOIN
   - **Note:** Architecture constraint - cannot be JOINed directly

3. **Complex ORDER BY with CASE:**
   - `CASE WHEN s.operator_user_id = ? THEN 0 ELSE 1 END`
   - `CASE WHEN ta.assigned_to_user_id = ? THEN 0 ELSE 1 END`
   - **Impact:** Requires filesort (cannot use index)
   - **Check:** EXPLAIN to confirm `using filesort`

4. **Multiple LEFT JOINs:**
   - 9+ LEFT JOINs in a single query
   - **Impact:** MySQL query optimizer may choose suboptimal join order
   - **Check:** EXPLAIN to see join order

5. **Token Work Session Filter in JOIN:**
   - `LEFT JOIN token_work_session s ON s.id_token = t.id_token AND s.status IN ('active', 'paused')`
   - **Impact:** May prevent index usage
   - **Check:** Ensure index on `token_work_session(id_token, status)`

**Recommended Indexes:**
```sql
-- Primary lookup indexes
CREATE INDEX idx_flow_token_current_node_status ON flow_token(current_node_id, status);
CREATE INDEX idx_flow_token_status_spawned ON flow_token(status, spawned_at);

-- For queue_position calculation
CREATE INDEX idx_flow_token_node_status_spawned ON flow_token(current_node_id, status, spawned_at);

-- For token_work_session lookups
CREATE INDEX idx_token_work_session_token_status ON token_work_session(id_token, status);
CREATE INDEX idx_token_work_session_operator ON token_work_session(operator_user_id, status);

-- For token_assignment lookups
CREATE INDEX idx_token_assignment_token_status ON token_assignment(id_token, status);

-- For assignment_log latest lookup
CREATE INDEX idx_assignment_log_token_node_created ON assignment_log(token_id, node_id, created_at DESC);

-- For job_graph_instance lookups
CREATE INDEX idx_jgi_instance_status ON job_graph_instance(id_instance, status);
```

### 2.2 Post-Query Processing: Join Info & Split Children

**Location:** `source/dag_token_api.php` ~line 1918

**Query Pattern:**
```php
// After main query
$tokenIds = array_column($tokens, 'id_token');
if (!empty($tokenIds)) {
    // Pre-fetch join info
    $joinInfo = db_fetch_all("SELECT ... WHERE token_id IN (...)");
    // Pre-fetch split children
    $splitChildren = db_fetch_all("SELECT ... WHERE parent_token_id IN (...)");
}
```

**Current Implementation:**
- ✅ **Already optimized!** Uses IN clause to batch queries
- ✅ Pre-fetches all related data in 2 queries instead of N+1
- **No optimization needed** - this is the correct pattern

### 2.3 manager_all_tokens() - Manager Token List

**Location:** `source/dag_token_api.php` ~line 3209

**Query Pattern:**
```sql
SELECT 
    t.id_token,
    t.serial_number,
    t.status as token_status,
    ...
FROM flow_token t
JOIN routing_node n ON n.id_node = t.current_node_id
LEFT JOIN job_graph_instance gi ON gi.id_instance = t.id_instance
LEFT JOIN job_ticket jt ON jt.id_job_ticket = gi.id_job_ticket
LEFT JOIN token_assignment ta ON ta.id_token = t.id_token 
    AND ta.status IN ('assigned','accepted','started','paused')
LEFT JOIN bgerp.account acc ON acc.id_member = ta.assigned_to_user_id
LEFT JOIN token_work_session s ON s.id_token = t.id_token 
    AND s.status IN ('active','paused')
WHERE t.status IN ('ready', 'active', 'waiting', 'paused')
    AND n.node_type IN ('operation', 'qc')
    AND (jt.status IS NULL OR jt.status = 'in_progress')
    AND (jt.production_type IS NULL OR jt.production_type = 'hatthasilpa')
ORDER BY 
    n.id_node ASC,
    CASE WHEN ta.assigned_to_user_id IS NULL THEN 0 ELSE 1 END ASC,
    t.spawned_at ASC
```

**Bottlenecks Identified:**

1. **Cross-DB JOIN (Core DB):**
   - `LEFT JOIN bgerp.account acc ON acc.id_member = ta.assigned_to_user_id`
   - **Impact:** Cannot use prepared statement JOIN
   - **Note:** Architecture constraint

2. **Complex ORDER BY:**
   - Multiple columns with CASE expression
   - **Check:** EXPLAIN to see if `using filesort`

3. **No LIMIT clause:**
   - Fetches ALL tokens matching criteria
   - **Impact:** May return thousands of rows
   - **Optimization:** Add pagination support or reasonable LIMIT

**Recommended Indexes:**
```sql
-- Same as get_work_queue (reuse indexes)
-- Additional index for ORDER BY
CREATE INDEX idx_flow_token_node_assigned_spawned ON flow_token(current_node_id, spawned_at);
```

---

## 3. dag_routing_api.php

### 3.1 graph_list() - Main Graph List Query

**Location:** `source/dag_routing_api.php` ~line 1582

**Query Pattern:**
```sql
-- Step 1: Fetch basic graph data
SELECT rg.*
FROM routing_graph rg
WHERE 1=1
-- (with filters: status, search, category, favorite, etc.)
LIMIT ? OFFSET ?

-- Step 2: Fetch user names from core DB (batched - good!)
SELECT id_member, name FROM bgerp.account WHERE id_member IN (...)

-- Step 3: Fetch metadata (node count, edge count, version) per graph
-- 3a: Node count (batched - good!)
SELECT id_graph, COUNT(*) as node_count FROM routing_node WHERE id_graph IN (...) GROUP BY id_graph

-- 3b: Edge count (batched - good!)
SELECT id_graph, COUNT(*) as edge_count FROM routing_edge WHERE id_graph IN (...) GROUP BY id_graph

-- 3c: Last published version (OPTIMIZED with self-join - good!)
SELECT v1.id_graph, v1.published_at, v1.version
FROM routing_graph_version v1
INNER JOIN (
    SELECT id_graph, MAX(published_at) as max_published_at
    FROM routing_graph_version
    WHERE id_graph IN (...)
    GROUP BY id_graph
) v2 ON v1.id_graph = v2.id_graph AND v1.published_at = v2.max_published_at
WHERE v1.id_graph IN (...)
```

**Bottlenecks Identified:**

1. **Multiple separate queries for metadata:**
   - Node count: 1 query
   - Edge count: 1 query  
   - Version: 1 query
   - **Current:** 3 separate queries (batched with IN clause - ✅ good pattern)
   - **Optimization:** Could potentially combine into single query with UNION or subqueries, but current pattern is acceptable

2. **Cross-DB query for user names:**
   - Separate query to Core DB for account names
   - **Current:** Batched with IN clause (✅ good pattern)
   - **Note:** Architecture constraint - cannot be JOINed

3. **No LIMIT on metadata queries:**
   - If graph list returns 100 graphs, metadata queries process 100 IDs
   - **Impact:** May be slow if IN clause is very large
   - **Check:** MySQL has limit on IN clause size (~1000 items)

**Current Implementation:**
- ✅ **Already optimized!** Uses batched queries with IN clause
- ✅ No N+1 patterns found
- ✅ Uses self-join for version lookup (efficient)

**Recommended Indexes:**
```sql
-- For routing_graph lookups
CREATE INDEX idx_routing_graph_status_code ON routing_graph(status, code);
CREATE INDEX idx_routing_graph_category ON routing_graph(category);

-- For metadata queries (already likely indexed)
CREATE INDEX idx_routing_node_id_graph ON routing_node(id_graph);
CREATE INDEX idx_routing_edge_id_graph ON routing_edge(id_graph);
CREATE INDEX idx_routing_graph_version_id_graph_published ON routing_graph_version(id_graph, published_at DESC);

-- For favorite filter
CREATE INDEX idx_routing_graph_favorite_graph_member ON routing_graph_favorite(id_graph, id_member);
```

### 3.2 where_used() - Graph Usage Query

**Location:** `source/dag_routing_api.php` ~line 6468

**Query Pattern:**
```sql
SELECT 
    gsb.parent_graph_id,
    rg.name AS parent_graph_name,
    ...
    -- Correlated subquery 1: Latest subgraph version
    (SELECT MAX(rgv2.version) FROM routing_graph_version rgv2 
     WHERE rgv2.id_graph = ? AND rgv2.published_at IS NOT NULL) AS latest_subgraph_version,
    -- Correlated subquery 2: Current parent version
    (SELECT rgv3.version FROM routing_graph_version rgv3 
     WHERE rgv3.id_graph = gsb.parent_graph_id 
     AND rgv3.published_at IS NOT NULL 
     ORDER BY rgv3.published_at DESC LIMIT 1) AS current_parent_version,
    COUNT(DISTINCT jgi.id_instance) AS active_instance_count,
    COUNT(DISTINCT CASE WHEN jt.status NOT IN ('completed', 'cancelled') THEN jt.id_job_ticket END) AS active_ticket_count
FROM graph_subgraph_binding gsb
INNER JOIN routing_graph rg ON rg.id_graph = gsb.parent_graph_id
INNER JOIN routing_node rn ON rn.id_node = gsb.node_id
LEFT JOIN job_graph_instance jgi ON jgi.id_graph = gsb.subgraph_id 
    AND jgi.graph_version = gsb.subgraph_version
    AND jgi.status IN ('active', 'paused')
LEFT JOIN job_ticket jt ON jt.id_job_ticket = jgi.id_job_ticket
WHERE gsb.subgraph_id = ?
GROUP BY gsb.parent_graph_id, gsb.parent_graph_version, gsb.subgraph_version, gsb.node_id, 
         rg.name, rg.code, rg.status, rn.node_name, rn.node_code, rn.node_type
ORDER BY rg.name, gsb.subgraph_version
```

**Bottlenecks Identified:**

1. **Two Correlated Subqueries:**
   - `latest_subgraph_version`: Runs for every row in result set
     - `(SELECT MAX(rgv2.version) FROM routing_graph_version WHERE rgv2.id_graph = ? ...)`
   - `current_parent_version`: Runs for every row in result set
     - `(SELECT rgv3.version FROM routing_graph_version WHERE rgv3.id_graph = gsb.parent_graph_id ...)`
   - **Impact:** 2N subqueries where N = number of bindings
   - **Optimization:** Use LEFT JOIN with MAX aggregation instead of correlated subqueries

2. **GROUP BY with multiple columns:**
   - `GROUP BY gsb.parent_graph_id, gsb.parent_graph_version, gsb.subgraph_version, gsb.node_id, ...`
   - **Impact:** May require temporary table
   - **Check:** EXPLAIN to see if `using temporary` or `using filesort`

3. **Multiple LEFT JOINs:**
   - 4+ LEFT JOINs in a single query
   - **Check:** EXPLAIN to see join order

**Recommended Indexes:**
```sql
-- For graph_subgraph_binding lookups
CREATE INDEX idx_gsb_subgraph_id ON graph_subgraph_binding(subgraph_id);
CREATE INDEX idx_gsb_parent_graph_id ON graph_subgraph_binding(parent_graph_id);

-- For routing_graph_version subqueries
CREATE INDEX idx_rgv_id_graph_published_version ON routing_graph_version(id_graph, published_at DESC, version);

-- For job_graph_instance joins
CREATE INDEX idx_jgi_graph_version_status ON job_graph_instance(id_graph, graph_version, status);
```

### 3.3 graph_get() - Single Graph Query

**Location:** `source/dag_routing_api.php` ~line 5408

**Query Pattern:**
```sql
-- Nodes
SELECT id_node, node_code, node_name, ...
FROM routing_node
WHERE id_graph = ?
ORDER BY sequence_no ASC, node_code ASC

-- Edges
SELECT e.id_edge, e.from_node_id, e.to_node_id, ...
FROM routing_edge e
LEFT JOIN routing_node fn ON fn.id_node = e.from_node_id
LEFT JOIN routing_node tn ON tn.id_node = e.to_node_id
WHERE e.id_graph = ?
ORDER BY e.priority DESC, e.id_edge ASC
```

**Bottlenecks Identified:**

1. **Two separate queries:**
   - One for nodes, one for edges
   - **Impact:** 2 queries instead of 1
   - **Optimization:** Could combine into single query with UNION, but current pattern is acceptable (simpler)

2. **LEFT JOIN on edges query:**
   - Joins routing_node twice (for from_node_code and to_node_code)
   - **Impact:** Extra JOINs but necessary for node codes
   - **Check:** EXPLAIN to ensure indexes are used

**Current Implementation:**
- ✅ Simple and efficient
- ✅ Uses indexes (id_graph filter)
- ✅ No N+1 patterns
- **No optimization needed** - this is the correct pattern

**Recommended Indexes:**
```sql
-- Already likely indexed, but verify:
CREATE INDEX idx_routing_node_id_graph_seq ON routing_node(id_graph, sequence_no, node_code);
CREATE INDEX idx_routing_edge_id_graph_priority ON routing_edge(id_graph, priority DESC, id_edge);
```

---

## 4. Common Patterns Across APIs

### 4.1 Cross-DB JOINs (Core DB)

**Pattern:**
- `LEFT JOIN bgerp.account ON account.id_member = ...`
- Used in: `dag_token_api.php` (multiple locations)

**Impact:**
- Cannot use prepared statement JOINs across databases
- May require separate queries or manual JOIN logic
- Network latency between DB connections

**Recommendation:**
- ✅ Keep as-is (architecture constraint)
- Consider caching account names if frequently accessed
- Pre-fetch account data in batches when possible

### 4.2 Correlated Subqueries

**Pattern:**
- `(SELECT ... FROM table2 WHERE table2.id = table1.id)`
- Used in: `trace_api.php` (has_rework), `dag_token_api.php` (queue_position, assignment_log)

**Impact:**
- Runs once per row in result set
- N subqueries for N rows
- Can be very slow with large result sets

**Optimization:**
- Replace with LEFT JOIN + aggregation
- Use window functions (MySQL 8.0+)
- Pre-fetch in separate query with IN clause

### 4.3 GROUP BY with Multiple Columns

**Pattern:**
- `GROUP BY col1, col2, col3, col4, col5`
- Used in: `trace_api.php` (handleTraceList)

**Impact:**
- May require temporary table
- May require filesort
- Check EXPLAIN for `using temporary` or `using filesort`

**Optimization:**
- Ensure covering index on GROUP BY columns
- Consider if GROUP BY is necessary (may be for deduplication)

### 4.4 Dynamic ORDER BY

**Pattern:**
- `ORDER BY {$sortColumn} {$dir}`
- Used in: `trace_api.php` (handleTraceList)

**Impact:**
- Index may not match sort column
- Requires filesort if index doesn't match

**Optimization:**
- Create indexes on common sort columns
- Consider limiting sort options to indexed columns

---

## 5. EXPLAIN Analysis (To Be Done)

### 5.1 trace_api.php Queries

**Status:** ⏳ Pending

**Next Steps:**
- Run EXPLAIN on main queries in `trace_api.php`
- Document findings:
  - Type (index scan, full scan, etc.)
  - Possible keys
  - Key used
  - Rows examined
  - Extra (using temporary, using filesort, etc.)

### 5.2 dag_token_api.php Queries

**Status:** ⏳ Pending

**Next Steps:**
- Run EXPLAIN on main queries in `dag_token_api.php`
- Document findings

### 5.3 dag_routing_api.php Queries

**Status:** ⏳ Pending

**Next Steps:**
- Identify main queries in `dag_routing_api.php`
- Run EXPLAIN
- Document findings

---

## 6. N+1 Query Patterns Found

### 6.1 trace_api.php

**Status:** ✅ **No N+1 found in main queries**
- Serial registry enrichment uses IN clause (batched)
- ✅ Good pattern

### 6.2 dag_token_api.php

**Status:** ✅ **No N+1 found in post-query processing**
- Join info and split children use IN clause (batched)
- ✅ Good pattern

**Status:** ⚠️ **Correlated subqueries found (similar to N+1)**
- `queue_position` subquery runs per waiting token
- `assignment_log` subquery runs per token
- Consider optimization

### 6.3 dag_routing_api.php

**Status:** ✅ **No N+1 found in main queries**
- graph_list uses batched queries with IN clause (✅ good pattern)
- where_used has correlated subqueries (⚠️ similar to N+1)

---

## 7. Priority Optimization Targets

### High Priority (Biggest Impact)

1. **trace_api.php - has_rework subquery**
   - Replace correlated subquery with LEFT JOIN
   - **Expected Impact:** 30-50% reduction in query time for list endpoint

2. **dag_token_api.php - queue_position subquery**
   - Replace with window function or pre-fetch
   - **Expected Impact:** 20-40% reduction for work queue endpoint

3. **dag_token_api.php - assignment_log subquery**
   - Replace with LEFT JOIN with MAX aggregation
   - **Expected Impact:** 20-40% reduction for work queue endpoint

4. **dag_routing_api.php - where_used subqueries**
   - Replace 2 correlated subqueries with LEFT JOINs
   - **Expected Impact:** 20-40% reduction for where_used endpoint

### Medium Priority

4. **Index creation**
   - Create recommended indexes from Section 1-3
   - **Expected Impact:** 10-30% improvement across all queries

5. **trace_api.php - ORDER BY optimization**
   - Add indexes on common sort columns
   - **Expected Impact:** 10-20% improvement for sorted results

### Low Priority (Nice to Have)

6. **dag_token_api.php - Cross-DB account lookups**
   - Consider caching if frequently accessed
   - **Expected Impact:** 5-10% improvement (network latency reduction)

---

## 8. Next Steps

1. ✅ Complete discovery document (this file)
2. ✅ Review `dag_routing_api.php` and add findings
3. ⏳ Run EXPLAIN on main queries and document results
4. ⏳ Create indexes (or document SQL for migration)
5. ⏳ Implement query optimizations (Step 2-3 from task21.md)
6. ⏳ Measure before/after performance (Step 4 from task21.md)

**Current Status:** Discovery phase complete. Ready to proceed with EXPLAIN analysis and optimization implementation.

---

## 9. Notes

- **Architecture Constraints:**
  - Cross-DB JOINs (Tenant → Core) cannot be done with prepared statements
  - Must use separate queries or manual JOIN logic
  
- **MySQL Version:**
  - Check MySQL version for window function support (8.0+)
  - If 5.7 or earlier, use subquery or JOIN alternatives

- **Testing:**
  - Ensure all optimizations maintain exact same JSON output
  - Run integration tests after each optimization

---

**Last Updated:** 2025-11-19  
**Next Review:** After EXPLAIN analysis

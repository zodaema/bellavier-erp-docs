-- Legacy Reliance Statistics Queries
-- Purpose: Measure usage of edge_type='rework' and qc_policy adoption
-- Safe: Read-only queries (no data modification)

-- ============================================================================
-- Query 1: Count rework edges by graph
-- ============================================================================
SELECT 
    rg.id_graph,
    rg.code AS graph_code,
    rg.name AS graph_name,
    COUNT(DISTINCT re.id_edge) AS rework_edge_count,
    COUNT(DISTINCT re.from_node_id) AS nodes_with_rework_edge
FROM routing_graph rg
LEFT JOIN routing_edge re ON re.id_graph = rg.id_graph 
    AND re.edge_type = 'rework'
    AND re.deleted_at IS NULL
WHERE rg.deleted_at IS NULL
GROUP BY rg.id_graph, rg.code, rg.name
HAVING rework_edge_count > 0
ORDER BY rework_edge_count DESC;

-- ============================================================================
-- Query 2: QC nodes without qc_policy (rely on legacy rework edge)
-- ============================================================================
SELECT 
    rn.id_node,
    rn.node_code,
    rn.node_name,
    rn.id_graph,
    rg.code AS graph_code,
    rg.name AS graph_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM routing_edge re 
            WHERE re.from_node_id = rn.id_node 
            AND re.edge_type = 'rework'
            AND re.deleted_at IS NULL
        ) THEN 'HAS_REWORK_EDGE'
        ELSE 'NO_REWORK_EDGE'
    END AS rework_edge_status
FROM routing_node rn
JOIN routing_graph rg ON rg.id_graph = rn.id_graph
WHERE rn.node_type = 'qc'
    AND (rn.qc_policy IS NULL OR rn.qc_policy = '' OR rn.qc_policy = '{}')
    AND rn.deleted_at IS NULL
    AND rg.deleted_at IS NULL
ORDER BY rg.code, rn.node_code;

-- ============================================================================
-- Query 3: QC nodes with qc_policy but no routing edges
-- ============================================================================
SELECT 
    rn.id_node,
    rn.node_code,
    rn.node_name,
    rn.id_graph,
    rg.code AS graph_code,
    rg.name AS graph_name,
    COUNT(re.id_edge) AS outgoing_edge_count
FROM routing_node rn
JOIN routing_graph rg ON rg.id_graph = rn.id_graph
LEFT JOIN routing_edge re ON re.from_node_id = rn.id_node 
    AND re.deleted_at IS NULL
WHERE rn.node_type = 'qc'
    AND rn.qc_policy IS NOT NULL
    AND rn.qc_policy != ''
    AND rn.qc_policy != '{}'
    AND rn.deleted_at IS NULL
    AND rg.deleted_at IS NULL
GROUP BY rn.id_node, rn.node_code, rn.node_name, rn.id_graph, rg.code, rg.name
HAVING outgoing_edge_count = 0
ORDER BY rg.code, rn.node_code;

-- ============================================================================
-- Query 4: Summary statistics
-- ============================================================================
SELECT 
    'Total rework edges' AS metric,
    COUNT(*) AS count
FROM routing_edge
WHERE edge_type = 'rework'
    AND deleted_at IS NULL

UNION ALL

SELECT 
    'Graphs with rework edges' AS metric,
    COUNT(DISTINCT id_graph) AS count
FROM routing_edge
WHERE edge_type = 'rework'
    AND deleted_at IS NULL

UNION ALL

SELECT 
    'QC nodes without qc_policy' AS metric,
    COUNT(*) AS count
FROM routing_node
WHERE node_type = 'qc'
    AND (qc_policy IS NULL OR qc_policy = '' OR qc_policy = '{}')
    AND deleted_at IS NULL

UNION ALL

SELECT 
    'QC nodes with qc_policy' AS metric,
    COUNT(*) AS count
FROM routing_node
WHERE node_type = 'qc'
    AND qc_policy IS NOT NULL
    AND qc_policy != ''
    AND qc_policy != '{}'
    AND deleted_at IS NULL

UNION ALL

SELECT 
    'QC nodes with policy but no edges' AS metric,
    COUNT(*) AS count
FROM routing_node rn
WHERE rn.node_type = 'qc'
    AND rn.qc_policy IS NOT NULL
    AND rn.qc_policy != ''
    AND rn.qc_policy != '{}'
    AND rn.deleted_at IS NULL
    AND NOT EXISTS (
        SELECT 1 FROM routing_edge re 
        WHERE re.from_node_id = rn.id_node 
        AND re.deleted_at IS NULL
    );

-- ============================================================================
-- Query 5: Top graphs by rework edge usage
-- ============================================================================
SELECT 
    rg.id_graph,
    rg.code AS graph_code,
    rg.name AS graph_name,
    COUNT(DISTINCT re.id_edge) AS rework_edge_count,
    COUNT(DISTINCT rn.id_node) AS qc_node_count,
    COUNT(DISTINCT CASE 
        WHEN (rn.qc_policy IS NULL OR rn.qc_policy = '' OR rn.qc_policy = '{}') 
        THEN rn.id_node 
    END) AS qc_nodes_without_policy
FROM routing_graph rg
LEFT JOIN routing_edge re ON re.id_graph = rg.id_graph 
    AND re.edge_type = 'rework'
    AND re.deleted_at IS NULL
LEFT JOIN routing_node rn ON rn.id_graph = rg.id_graph 
    AND rn.node_type = 'qc'
    AND rn.deleted_at IS NULL
WHERE rg.deleted_at IS NULL
GROUP BY rg.id_graph, rg.code, rg.name
HAVING rework_edge_count > 0 OR qc_nodes_without_policy > 0
ORDER BY rework_edge_count DESC, qc_nodes_without_policy DESC
LIMIT 20;

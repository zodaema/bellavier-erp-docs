# Migration Integrity Map

**Purpose:** Track migration dependencies, critical flags, and safe-to-edit status

**Last Updated:** 2025-12-XX  
**Task:** 14.1.7 - Pre-Cleanup Migration Consolidation Framework

---

## Migration Status Overview

| Status | Count | Description |
|--------|-------|-------------|
| ✅ Active | ~25 | Safe to run, safe to modify |
| 🔒 Locked | 2 | Do not modify or re-run |
| 📦 Archived | ~50 | Historical reference only |
| 🏗️ Foundation | 2 | Core schema (0001, 0002) |

---

## Active Migrations (Safe to Edit)

### Component System
| File | Status | Safe to Edit | Safe to Move | Dependencies |
|------|--------|--------------|--------------|--------------|
| `active/2025_12_component_system_foundation.php` | ✅ Active | ✅ Yes | ✅ Yes | None |
| `active/2025_12_component_serial_generation.php` | ✅ Active | ✅ Yes | ✅ Yes | component_system_foundation |
| `active/2025_12_component_serial_binding_phase3.php` | ✅ Active | ✅ Yes | ✅ Yes | component_system_foundation |
| `active/2025_12_component_allocation_layer.php` | ✅ Active | ✅ Yes | ✅ Yes | component_system_foundation |
| `active/2025_12_component_serial_permissions.php` | ✅ Active | ✅ Yes | ✅ Yes | component_system_foundation |
| `active/2025_12_component_binding_permissions.php` | ✅ Active | ✅ Yes | ✅ Yes | component_system_foundation |
| `active/2025_12_component_override_ui_permission.php` | ✅ Active | ✅ Yes | ✅ Yes | component_system_foundation |

### DAG Behavior
| File | Status | Safe to Edit | Safe to Move | Dependencies |
|------|--------|--------------|--------------|--------------|
| `active/2025_12_dag_behavior_log.php` | ✅ Active | ✅ Yes | ✅ Yes | routing_graph, routing_node |
| `active/2025_12_dag_supervisor_sessions_permission.php` | ✅ Active | ✅ Yes | ✅ Yes | None |

### Leather GRN & Sheet
| File | Status | Safe to Edit | Safe to Move | Dependencies |
|------|--------|--------------|--------------|--------------|
| `active/2025_12_leather_grn_unified_flow.php` | ✅ Active | ✅ Yes | ✅ Yes | material_lot |
| `active/2025_12_leather_grn_permission.php` | ✅ Active | ✅ Yes | ✅ Yes | None |
| `active/2025_12_leather_sheet_usage.php` | ✅ Active | ✅ Yes | ✅ Yes | leather_sheet |
| `active/2025_12_leather_sheet_usage_permissions.php` | ✅ Active | ✅ Yes | ✅ Yes | None |
| `active/2025_12_leather_cut_bom_log.php` | ✅ Active | ✅ Yes | ✅ Yes | bom_line |
| `active/2025_12_leather_cut_bom_permissions.php` | ✅ Active | ✅ Yes | ✅ Yes | None |

### Performance & Optimization
| File | Status | Safe to Edit | Safe to Move | Dependencies |
|------|--------|--------------|--------------|--------------|
| `active/2025_12_performance_indexes_phase_5_8.php` | ✅ Active | ✅ Yes | ✅ Yes | All tables |

### Work Center Behavior
| File | Status | Safe to Edit | Safe to Move | Dependencies |
|------|--------|--------------|--------------|--------------|
| `active/2025_12_work_center_behavior.php` | ✅ Active | ✅ Yes | ✅ Yes | None |
| `active/2025_12_work_center_behavior_map.php` | ✅ Active | ✅ Yes | ✅ Yes | work_center_behavior, work_center |

### Graph Features
| File | Status | Safe to Edit | Safe to Move | Dependencies |
|------|--------|--------------|--------------|--------------|
| `active/2025_12_graph_draft_layer.php` | ✅ Active | ✅ Yes | ✅ Yes | routing_graph |
| `active/2025_12_graph_draft_layer_patch.php` | ✅ Active | ✅ Yes | ✅ Yes | graph_draft_layer |
| `active/2025_12_subgraph_governance.php` | ✅ Active | ✅ Yes | ✅ Yes | routing_graph |
| `active/2025_12_node_type_enum_update.php` | ✅ Active | ✅ Yes | ✅ Yes | routing_node |

### System Master Data
| File | Status | Safe to Edit | Safe to Move | Dependencies |
|------|--------|--------------|--------------|--------------|
| `active/2025_12_system_master_data_hardening.php` | ✅ Active | ✅ Yes | ✅ Yes | unit_of_measure, work_center, warehouse, warehouse_location |

---

## Locked Migrations (Do Not Edit)

### Legacy Stock
| File | Status | Safe to Edit | Safe to Move | Blocked By | Unlock When |
|------|--------|--------------|--------------|------------|-------------|
| `locked/legacy_stock/2025_12_material_lot_id_material.php` | 🔒 Locked | ❌ No | ✅ Yes (dir only) | Dual-write pattern | Task 14.1.8+ |

**Critical Flags:**
- ⚠️ Contains dual-write pattern (`id_stock_item` + `id_material`)
- ⚠️ Still referenced by `leather_grn.php`, `materials.php`
- ⚠️ Cannot remove `id_stock_item` until dual-write removed

### Master Schema Cleanup
| File | Status | Safe to Edit | Safe to Move | Blocked By | Unlock When |
|------|--------|--------------|--------------|------------|-------------|
| `locked/2025_12_master_schema_v2_cleanup.php` | 🔒 Locked | ❌ No | ✅ Yes (dir only) | Multiple dependencies | Phase 3 |

**Critical Flags:**
- ⚠️ Contains cleanup operations (all commented out)
- ⚠️ Blocked by `stock_item` table (dual-write)
- ⚠️ Blocked by `routing` V1 tables (LegacyRoutingAdapter - now instrumented via Task 14.1.9)
- ⚠️ Blocked by `id_stock_item` columns (dual-write)
- ⚠️ Cannot drop tables/columns until dependencies removed

### Feature Flags (Core DB)
| File | Status | Safe to Edit | Safe to Move | Dependencies |
|------|--------|--------------|--------------|--------------|
| `migrations/0006_routing_v1_feature_flag.php` | ✅ Active | ✅ Yes | ❌ No (core DB) | feature_flag_catalog, feature_flag_tenant |

**Feature Flag Details:**
- **Key:** `FF_ALLOW_ROUTING_V1_FALLBACK`
- **Default:** `1` (enabled)
- **Purpose:** Control V1 routing fallback behavior
- **Status:** Active (Task 14.1.9)
- **Note:** V1 routing tables are in `ARCHIVE+INSTRUMENTED` mode - all fallback usage is logged

---

## Foundation Migrations (Core Schema)

| File | Status | Safe to Edit | Safe to Move | Description |
|------|--------|--------------|--------------|-------------|
| `0001_init_tenant_schema_v2.php` | 🏗️ Foundation | ⚠️ Limited | ❌ No | Core schema (87+ tables) |
| `0002_seed_data.php` | 🏗️ Foundation | ⚠️ Limited | ❌ No | Seed data |

**Rules:**
- ⚠️ **Limited editing** - Only add new tables/columns, do not remove
- ❌ **Do not move** - Must stay in root directory
- ⚠️ **Test thoroughly** - Changes affect all tenants

---

## Archived Migrations

| Directory | Count | Status | Description |
|-----------|-------|--------|-------------|
| `archive/2025_11_consolidated/` | ~15 | 📦 Archived | November 2025 consolidated |
| `archive/2025_11_active_consolidated/` | ~10 | 📦 Archived | November 2025 active features |
| `archive/2025_12_consolidated/` | 3 | 📦 Archived | December 2025 consolidated |
| `archive/consolidated_2025_11/` | ~14 | 📦 Archived | November 2025 legacy consolidated |
| `archive/routing_graph_migrations/` | 3 | 📦 Archived | Routing graph migrations |

**Rules:**
- ✅ **Safe to reference** - Historical data
- ❌ **Do not run** - Already consolidated
- ✅ **Safe to delete** - After verification (not recommended)

---

## Dependency Map

### Legacy Dependencies (Blocking Cleanup)

```
stock_item table
  ├── leather_grn.php (dual-write)
  ├── materials.php (dual-write/fallback)
  └── material_lot.id_stock_item (FK)

id_stock_item columns
  ├── material_lot.id_stock_item (dual-write)
  └── component_bom_map.id_stock_item (if exists)

routing V1 tables
  ├── LegacyRoutingAdapter.php (adapter)
  ├── routing.php (deprecated but kept)
  └── hatthasilpa_job_ticket.php (uses adapter)
```

### Active Dependencies (Safe)

```
material table
  ├── material_lot.id_material (FK)
  ├── bom_item.id_material (FK)
  └── All active migrations

routing_graph (V2)
  ├── routing_node (FK)
  ├── routing_edge (FK)
  └── All DAG migrations

bom_line (ACTIVE, not legacy)
  ├── bom.php (CRUD)
  ├── BOMService.php (service)
  └── All BOM-related migrations
```

---

## Safeguards

### Hard Guardrails

1. **Locked Migration Check:**
   ```php
   // In migration helpers
   if (strpos($filePath, 'locked/') !== false) {
       error_log('[SAFEGUARD] Attempted to run locked migration: ' . $filePath);
       throw new RuntimeException('Locked migration cannot be run');
   }
   ```

2. **Dual-Write Detection:**
   ```php
   if ($this->columnExists('material_lot', 'id_stock_item')) {
       error_log('[SAFEGUARD] id_stock_item still exists — skipping destructive cleanup');
   }
   ```

3. **Legacy Table Check:**
   ```php
   if ($this->tableExists('stock_item')) {
       error_log('[SAFEGUARD] stock_item table still exists — cannot drop');
   }
   ```

### Preventive Comments

All locked migrations have:
```php
// ⚠️ LOCKED MIGRATION — DO NOT MODIFY OR RE-RUN
// This file contains legacy-bound schema. It will be cleaned only after Phase 3.
```

---

## Next Steps

### Phase 1: Dual-Write Removal (Task 14.1.8)
- Remove dual-write from `leather_grn.php`
- Remove dual-write from `materials.php`
- Update `material_lot_id_material.php` (unlock)

### Phase 2: Routing V1 Migration (Task 14.1.9 - Completed)
- ✅ Feature flag `FF_ALLOW_ROUTING_V1_FALLBACK` added (migration `0006_routing_v1_feature_flag.php`)
- ✅ `LegacyRoutingAdapter` enhanced with feature flag and logging
- ✅ All callers updated to use instance-based adapter
- ✅ V1 routing in `ARCHIVE+INSTRUMENTED` mode (all fallback usage logged)
- ⚠️ Routing V1 tables still exist (will be dropped in Phase 3)
- Next: Monitor logs, gradually disable V1 fallback per tenant

### Phase 3: Final Cleanup
- Drop `stock_item` table
- Drop `id_stock_item` columns
- Drop routing V1 tables
- Re-run `master_schema_v2_cleanup.php` with operations enabled

---

**Maintained By:** Task 14.1.7  
**Review Frequency:** After each cleanup phase


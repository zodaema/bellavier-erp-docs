# Roles & Permissions Database Audit

> **Generated:** 2025-12-08  
> **Auditor:** AI Agent  
> **Scope:** database/, source/ 

---

## 📊 Executive Summary

| Source | Roles | Permissions |
|--------|-------|-------------|
| **seed_default_permissions.php** (Reference) | 23 | 93 |
| **0002_seed_data.php** (Actual Migration) | 10 | 94 |
| **Code Usage** (must_allow_code/permission_allow_code) | - | 88 |

### ⚠️ Critical Gap

- **13 Roles** defined in reference but NOT in migration!
- **35 Permissions** used in code but NOT in seed!
- **40 Permissions** in seed but NOT used in code!

---

## 1️⃣ Roles Analysis

### Roles in Migration (0002_seed_data.php) - 10 roles

| ID | Code | Name | Description |
|----|------|------|-------------|
| 1 | `owner` | Owner | Tenant owner with full access |
| 2 | `admin` | Administrator | Tenant administrator role |
| 3 | `viewer` | Viewer | Viewer (read only) |
| 4 | `production_manager` | Production Manager | Production manager |
| 5 | `production_operator` | Production Operator | Production operator |
| 6 | `artisan_operator` | Artisan Operator | Artisan operator |
| 7 | `quality_manager` | Quality Manager | Quality control manager |
| 8 | `qc_lead` | QC Lead | QC lead |
| 9 | `inventory_manager` | Inventory Manager | Inventory manager |
| 10 | `planner` | Planner | Production planner |

### 🔴 Roles in Reference but NOT in Migration (13 roles)

| Role | Description | Impact |
|------|-------------|--------|
| `warehouse_manager` | Warehouse Manager | No GRN/Transfer management |
| `warehouse` | Warehouse Staff | No basic warehouse access |
| `sales_manager` | Sales Manager | No sales module access |
| `sales` | Sales Representative | No SO creation |
| `sales_bv` | Sales (Bellavier Brand) | No brand-scoped access |
| `sales_oem` | Sales (OEM) | No OEM-scoped access |
| `purchaser` | Purchasing Officer | No PR/PO creation |
| `finance` | Finance Manager | No costing access |
| `cost_accountant` | Cost Accountant | No costing access |
| `finance_clerk` | Finance Clerk | No costing view |
| `operations` | Operations Staff | No operations access |
| `auditor` | Internal Auditor | No audit access |
| `auditor_readonly` | External Auditor | No read-only audit access |

---

## 2️⃣ Permissions Analysis

### Permissions in Migration (0002_seed_data.php) - 94 permissions

```
adjust.manage, adjust.view, admin.role.manage, admin.settings.manage, admin.user.manage,
bom.manage, bom.view, brand.scope.bv, brand.scope.oem, costing.post, costing.view,
dag.routing.design.view, dag.routing.runtime.view, dag.routing.view, DAG_SUPERVISOR_SESSIONS,
dashboard.production.view, dashboard.view, delivery.create, grn.manage, grn.receive, grn.view,
hatthasilpa.dashboard.view, hatthasilpa.job.ticket, hatthasilpa.job.wip.scan, hatthasilpa.material.lot,
hatthasilpa.purchase.rfq, hatthasilpa.qc.checklist, hatthasilpa.routing.manage, hatthasilpa.routing.view,
inventory.adjust, inventory.cyclecount, inventory.issue, inventory.receive, inventory.transfer, inventory.view,
issue.manage, issue.view, locations.manage, locations.view, materials.manage, materials.view,
mo.cancel, mo.complete, mo.create, mo.manage, mo.plan, mo.start_stop, mo.update, mo.view,
oem.dashboard.view, oem.job.ticket, org.role.assign, org.settings.manage, org.user.manage,
pattern.manage, pattern.view, product.manage, product.view, product_categories.manage, product_categories.view,
products.manage, products.view, purchase.order, purchase.rfq, purchase.view,
qc.check, qc.fail, qc.fail.manage, qc.fail.view, qc.inspect, qc.rework.manage, qc.rework_scrap,
qc.spec.manage, qc.spec.view, qc.view, receive.manage, receive.view, reports.view,
routing.manage, routing.view, serial.verify, serial.view, session.login, stock_card.view, stock_on_hand.view,
system.log.view, team.manage, team.view, trace.manage, trace.view, transfer.manage, transfer.view,
uom.manage, uom.view, warehouse.location.manage, warehouse.manage, warehouse.view,
warehouses.manage, warehouses.view, work.center.manage, work.center.view, work_centers.manage, work_centers.view,
work.queue.* (20+ permissions), workcenter.manage, workcenter.view
```

### 🔴 Permissions in CODE but NOT in Seed (35 permissions)

These permissions are actively used in code but will FAIL at runtime!

| Permission | Used In | Issue |
|------------|---------|-------|
| `admin.manage` | `admin_org.php` | Not seeded |
| `component.binding.bind` | `component_binding.php` | Not seeded |
| `component.binding.unbind` | `component_binding.php` | Not seeded |
| `component.binding.view` | `component_binding.php` | Not seeded |
| `component.catalog.manage` | `component_catalog_api.php` | Not seeded |
| `component.mapping.manage` | `component_mapping_api.php` | Not seeded |
| `component.mapping.view` | `component_mapping_api.php` | Not seeded |
| `component.serial.generate` | `component_serial.php` | Not seeded |
| `component.serial.view` | `component_serial.php` | Not seeded |
| `dag.routing.manage` | `dag_token_api.php`, `assignment_api.php` | Not seeded |
| `dag.routing.publish` | `dag_routing_api.php` | Not seeded |
| `example.manage` | `api_template.php` | Template only |
| `example.view` | `api_template.php` | Template only |
| `graph.manage` | `products.php` | Not seeded |
| `hatthasilpa.job.assign` | `dag_token_api.php` | Not seeded |
| `hatthasilpa.job.complete` | `dag_token_api.php` | Not seeded |
| `hatthasilpa.job.manage` | `hatthasilpa_jobs_api.php` | Not seeded |
| `hatthasilpa.routing.runtime.view` | `dag_routing_api.php` | Not seeded |
| `hatthasilpa.token.create_replacement` | `dag_token_api.php` | Not seeded |
| `leather.cut.bom.manage` | `leather_cut_bom_api.php` | Not seeded |
| `leather.cut.bom.view` | `leather_cut_bom_api.php` | Not seeded |
| `leather.sheet.use` | `leather_sheet_api.php` | Not seeded |
| `leather.sheet.view` | `leather_sheet_api.php` | Not seeded |
| `leather_grn.manage` | `leather_grn.php` | Not seeded |
| `manager.assignment` | `assignment_plan_api.php` | Not seeded |
| `manager.team` | `team_api.php` | Not seeded |
| `manager.team.members` | `team_api.php` | Not seeded |
| `mo.eta.view` | `mo_eta_api.php` | Uses `mo.view` instead |
| `people.view_detail` | `team_api.php` | Not seeded |
| `routing.v1.monitor` | Unknown | Not seeded |
| `system.manage` | `admin_rbac.php` | Not seeded |
| `trace.manage` | `trace_api.php` | ✅ In migration |
| `trace.view` | `trace_api.php` | ✅ In migration |

### 🟡 Permissions in Seed but NOT Used in Code (40 permissions)

These may be:
- Future features (not implemented yet)
- UI-only checks (pages, not APIs)
- Deprecated

```
atelier.dashboard.view, atelier.material.lot, atelier.qc.checklist, brand.scope.bv, brand.scope.oem,
costing.post, costing.view, dashboard.view, delivery.create, graph.publish, grn.receive,
hatthasilpa.job.wip.scan, inventory.adjust, inventory.cyclecount, inventory.issue, inventory.receive,
inventory.transfer, inventory.view, mo.override.graph, po.approve, po.create, pr.approve, pr.create,
product.graph.diff.view, qc.fail.manage, qc.inspect, qc.rework.manage, qc.rework_scrap,
qc.spec.manage, qc.spec.view, reports.view, sales.price.manage, session.login,
so.approve, so.create, system.log.view, warehouse.label_print, warehouse.location.manage,
workcenter.manage, workcenter.view
```

---

## 3️⃣ Role-Permission Mappings (From Migration)

### Owner (Role ID: 1)
- **BYPASSED** - Owner role bypasses ALL permission checks

### Admin (Role ID: 2) - 53 permissions
```
adjust.manage, adjust.view, admin.role.manage, admin.settings.manage, admin.user.manage,
bom.manage, bom.view, dashboard.view, dashboard.production.view, trace.view, trace.manage,
grn.manage, grn.view, inventory.view, issue.manage, issue.view, locations.manage, locations.view,
materials.manage, materials.view, mo.cancel, mo.complete, mo.create, mo.plan, mo.start_stop,
mo.update, mo.view, org.role.assign, org.settings.manage, org.user.manage,
product_categories.manage, product_categories.view, products.manage, products.view,
qc.fail.view, reports.view, routing.manage, routing.view, session.login,
stock_card.view, stock_on_hand.view, system.log.view, transfer.manage, transfer.view,
uom.manage, uom.view, warehouses.manage, warehouses.view, work_centers.manage, work_centers.view,
workcenter.manage, workcenter.view, DAG_SUPERVISOR_SESSIONS
```

### Production Manager (Role ID: 4) - 35 permissions
```
hatthasilpa.dashboard.view, hatthasilpa.job.ticket, bom.manage, bom.view, dashboard.view,
dashboard.production.view, trace.view, trace.manage, materials.view, mo.cancel, mo.complete,
mo.create, mo.plan, mo.start_stop, mo.update, mo.view, products.view, qc.fail.manage,
qc.fail.view, qc.inspect, qc.rework.manage, qc.spec.view, reports.view, routing.manage,
routing.view, schedule.auto_arrange, schedule.config, schedule.edit, schedule.view,
session.login, stock_card.view, stock_on_hand.view, work_centers.manage, work_centers.view,
workcenter.manage, workcenter.view
```

### Production Operator (Role ID: 5) - 8 permissions
```
hatthasilpa.job.ticket, hatthasilpa.job.wip.scan, hatthasilpa.qc.checklist, dashboard.view,
mo.start_stop, mo.view, qc.inspect, session.login
```

### Artisan Operator (Role ID: 6) - 6 permissions
```
hatthasilpa.job.ticket, hatthasilpa.job.wip.scan, hatthasilpa.qc.checklist, dashboard.view,
mo.view, session.login
```

### Quality Manager (Role ID: 7) - 14 permissions
```
hatthasilpa.job.ticket, hatthasilpa.qc.checklist, dashboard.view, mo.view, products.view,
qc.fail.manage, qc.fail.view, qc.inspect, qc.rework_scrap, qc.rework.manage,
qc.spec.manage, qc.spec.view, reports.view, session.login
```

### QC Lead (Role ID: 8) - 9 permissions
```
hatthasilpa.qc.checklist, dashboard.view, mo.view, products.view, qc.fail.manage,
qc.fail.view, qc.inspect, qc.spec.view, session.login
```

### Inventory Manager (Role ID: 9) - 27 permissions
```
adjust.manage, adjust.view, dashboard.view, grn.manage, grn.receive, grn.view,
inventory.adjust, inventory.cyclecount, inventory.issue, inventory.receive, inventory.transfer,
inventory.view, issue.manage, issue.view, locations.manage, locations.view, materials.view,
products.view, reports.view, session.login, stock_card.view, stock_on_hand.view,
transfer.manage, transfer.view, warehouse.location.manage, warehouses.manage, warehouses.view
```

### Planner (Role ID: 10) - 17 permissions
```
bom.view, dashboard.view, materials.view, mo.create, mo.plan, mo.update, mo.view, products.view,
reports.view, routing.view, schedule.auto_arrange, schedule.edit, schedule.view,
session.login, stock_on_hand.view, work_centers.view, workcenter.view
```

### Viewer (Role ID: 3) - 4 permissions
```
bom.view, dashboard.view, reports.view, session.login
```

---

## 4️⃣ Naming Convention Issues

### ⚠️ Inconsistent Naming

| Current | Should Be |
|---------|-----------|
| `DAG_SUPERVISOR_SESSIONS` | `dag.supervisor.sessions` |
| `work_centers.view` | `work.centers.view` |
| `work_centers.manage` | `work.centers.manage` |
| `product_categories.view` | `product.categories.view` |
| `product_categories.manage` | `product.categories.manage` |
| `stock_on_hand.view` | `stock.on.hand.view` |
| `stock_card.view` | `stock.card.view` |
| `leather_grn.manage` | `leather.grn.manage` |
| `mo.start_stop` | `mo.start.stop` |

### Duplicate Concepts

| Domain 1 | Domain 2 | Should Be |
|----------|----------|-----------|
| `work_centers.*` | `workcenter.*` | `work.center.*` |
| `warehouses.*` | `warehouse.*` | `warehouse.*` |
| `dag.routing.*` | `hatthasilpa.routing.*` | `routing.*` |

---

## 5️⃣ Recommendations

### 🔴 Critical (Fix Immediately)

1. **Add missing permissions to migration:**
   - All 35 permissions used in code but not seeded
   - Priority: `component.*`, `leather.*`, `manager.*`

2. **Add missing roles to migration:**
   - At minimum: `warehouse_manager`, `warehouse`, `purchaser`

### 🟡 High Priority

3. **Standardize naming convention:**
   - Use `module.submodule.action` pattern consistently
   - Rename `DAG_SUPERVISOR_SESSIONS` → `dag.supervisor.sessions`
   - Consolidate `work_centers.*` and `workcenter.*`

4. **Create permission sync script:**
   - Auto-detect permissions from `@permission` docblocks
   - Compare with database
   - Generate migration for missing permissions

### 🟢 Medium Priority

5. **Review unused permissions:**
   - Determine if planned features or deprecated
   - Remove or document accordingly

6. **Create Permission Registry:**
   - Central source of truth
   - Auto-sync to database

---

## 🔗 Related Documents

- [Permission System Audit](./20251208_PERMISSION_SYSTEM_AUDIT.md)
- [Permission Engine Refactor Plan](../tasks/task27.23_PERMISSION_ENGINE_REFACTOR.md)


# Permission Reference

**Last Updated:** December 2025  
**Purpose:** Complete reference of all permission codes in Bellavier Group ERP

---

## Overview

This document lists all permission codes available in the system. Permissions are managed in the Core DB (`bgerp.permission`) and synced to all tenant DBs.

**Permission Naming Convention:**
- Format: `{module}.{action}` or `{module}.{submodule}.{action}`
- Examples: `mo.view`, `schedule.edit`, `DAG_SUPERVISOR_SESSIONS`

---

## Permission Categories

### DAG / Supervisor Tools

#### DAG_SUPERVISOR_SESSIONS
- **Description:** Access to DAG Supervisor Sessions dashboard & override actions
- **Default Roles:** PLATFORM_ADMIN, TENANT_ADMIN
- **Category:** DAG / Supervisor Tools
- **Added:** December 2025 (Task 13.1)
- **Usage:** 
  - View active/stale work sessions
  - Force close stuck sessions
  - Mark sessions as reviewed
- **Note:** This permission is restricted to Admin roles only. Platform admins have access via platform admin check. Tenant admins have access via this permission code.

---

## Manufacturing

### Manufacturing Orders
- `mo.view` - View manufacturing orders
- `mo.create` - Create manufacturing orders
- `mo.plan` - Plan manufacturing orders
- `mo.start_stop` - Start/Stop work orders
- `mo.complete` - Complete manufacturing orders
- `mo.cancel` - Cancel manufacturing orders

### Production Schedule
- `schedule.view` - View production schedule calendar and planning
- `schedule.edit` - Edit schedule dates via drag & drop and manual entry
- `schedule.auto_arrange` - Use automatic scheduling feature
- `schedule.config` - Configure work center capacity and schedule settings

### Work Centers
- `work_centers.view` - View work centers
- `work_centers.manage` - Manage work centers
- `workcenter.view` - View work centers (legacy)
- `workcenter.manage` - Create/Update work centers (legacy)

---

## Products & Materials

### Products
- `products.view` - View products
- `products.manage` - Create/Update products
- `product_categories.view` - View product categories
- `product_categories.manage` - Manage product categories

### Materials
- `materials.view` - View materials (raw materials catalog)
- `materials.manage` - Create/Update/Delete materials

### BOM
- `bom.view` - View bill of materials
- `bom.manage` - Create/Update bill of materials

### Routing
- `routing.view` - View routing
- `routing.manage` - Create/Update routing

---

## Inventory

### Warehouses
- `warehouses.view` - View warehouses
- `warehouses.manage` - Manage warehouses
- `locations.view` - View warehouse locations
- `locations.manage` - Manage warehouse locations

### Stock Operations
- `inventory.view` - View inventory
- `stock_on_hand.view` - View stock on hand summary
- `stock_card.view` - View stock card
- `adjust.view` - View stock adjustments
- `adjust.manage` - Manage stock adjustments
- `transfer.view` - View stock transfers
- `transfer.manage` - Manage stock transfers
- `issue.view` - View material issues
- `issue.manage` - Manage material issues
- `grn.view` - View goods receipts
- `grn.manage` - Manage goods receipts

---

## Quality Control

- `qc.fail.view` - View QC fail events and rework tasks
- `qc.fail.manage` - Create and update QC fail events
- `qc.inspect` - Perform QC inspections
- `qc.rework.manage` - Assign and update QC rework tasks
- `qc.rework_scrap` - Record Rework/Scrap actions
- `qc.spec.view` - View QC specifications
- `qc.spec.manage` - Manage QC specifications

---

## Administration

### User & Access Management
- `org.user.manage` - Manage users within current organization
- `org.role.assign` - Assign roles within current organization
- `org.settings.manage` - Manage organization settings
- `admin.user.manage` - Manage users
- `admin.role.manage` - Manage roles/permissions
- `admin.settings.manage` - Manage system settings

### System
- `system.log.view` - View system logs
- `migration.run` - Run migrations / system updates
- `session.login` - Login to system

---

## Platform (Core DB Only)

- `platform.tenants.manage` - Manage tenant organizations (create/update/delete)
- `platform.accounts.manage` - Manage platform users and roles
- `platform.audit.view` - View platform-wide audit logs
- `platform.billing.manage` - Manage tenant billing/subscription
- `platform.migrations.run` - Run core/tenant migrations

---

## Reports & Dashboards

- `dashboard.view` - Access organization dashboard
- `dashboard.production.view` - View production dashboard
- `reports.view` - Access reports/KPIs

---

## Traceability

- `trace.view` - View product traceability
- `trace.manage` - Manage product traceability

---

## Notes

- **Owner Role:** Bypasses ALL permission checks (see `permission.php`)
- **Platform Admin:** Has access to all platform permissions
- **Tenant Admin:** Has access to most tenant permissions (assigned via role)
- **Permission Sync:** Permissions are synced from Core DB to tenant DBs via `tools/sync_permissions_to_tenants.php`

---

**Last Updated:** December 2025  
**Maintained By:** Development Team


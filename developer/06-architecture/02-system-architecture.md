# 🏗️ Bellavier Group ERP - System Architecture

**Date:** January 2025  
**Version:** 2.0 (SuperDAG Integration + Bootstrap Layers)  
**Last Updated:** January 2025

---

## 📊 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    CLIENT LAYER (Browser)                    │
├─────────────────────────────────────────────────────────────┤
│  • FullCalendar.js (Production Schedule)                    │
│  • Chart.js (Capacity Visualization)                        │
│  • jQuery + AJAX (API Communication)                        │
│  • Bootstrap 5 (UI Framework)                               │
│  • Graph Designer (DAG routing graph editor)                │
│  • GraphTimezone.js (Canonical timezone normalization)      │
└─────────────────────────────────────────────────────────────┘
                            ↓ HTTPS
┌─────────────────────────────────────────────────────────────┐
│                  APPLICATION LAYER (PHP)                     │
├─────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────┐  │
│  │              BOOTSTRAP LAYERS                         │  │
│  │  • TenantApiBootstrap - Tenant-scoped APIs (40+)      │  │
│  │  • CoreApiBootstrap - Platform/core APIs (12)          │  │
│  │  • Auto tenant resolution & DB connection              │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              ROUTING & SESSION                        │  │
│  │  • index.php - Main router                            │  │
│  │  • memberLogin/memberDetail - Authentication          │  │
│  │  • resolve_current_org() - Tenant context             │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              PERMISSION LAYER                         │  │
│  │  • PermissionHelper (PSR-4) - Authorization          │  │
│  │  • is_platform_administrator() - Platform check       │  │
│  │  • is_tenant_administrator() - Tenant check           │  │
│  │  • Hybrid: Tenant-first, fallback to Core            │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              API ENDPOINTS                            │  │
│  │  • Tenant APIs: products, materials, bom, etc. (40+)  │  │
│  │  • Platform APIs: platform_dashboard, health (12)     │  │
│  │  • DAG APIs: dag_routing_api, dag_token_api           │  │
│  │  • MO APIs: mo.php + MO service layer                 │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              SERVICE LAYER                             │  │
│  │  • ScheduleService, BOMService, WorkCenterService      │  │
│  │  • DAGRoutingService, TokenLifecycleService           │  │
│  │  • MO Services: MOCreateAssist, MOLoadEta, etc.       │  │
│  │  • Product Services: ClassicProductionStats, etc.     │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              DAG ENGINE LAYER                         │  │
│  │  • DagExecutionService - Token movement               │  │
│  │  • BehaviorExecutionService - Node behavior           │  │
│  │  • NodeBehaviorEngine - Behavior execution            │  │
│  │  • ParallelMachineCoordinator - Parallel execution     │  │
│  │  • MachineAllocationService - Machine binding          │  │
│  │  • EtaEngine - ETA/SLA calculation                    │  │
│  │  • LocalRepairEngine - Self-healing (L1)              │  │
│  │  • TimelineReconstructionEngine - Self-healing (L2/L3)│  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              HELPER / UTILITY LAYER                    │  │
│  │  • TimeHelper (PHP) - Canonical timezone              │  │
│  │  • DatabaseHelper - DB operations                     │  │
│  │  • PermissionHelper - Permission checks               │  │
│  │  • BootstrapMigrations - Migration execution          │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↓ MySQLi
┌─────────────────────────────────────────────────────────────┐
│                    DATABASE LAYER (MySQL)                    │
├─────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────┐  │
│  │   CORE DATABASE (bgerp) - Shared Platform Data       │  │
│  ├───────────────────────────────────────────────────────┤  │
│  │  • account - Users                                    │  │
│  │  • organization - Tenant registry                     │  │
│  │  • platform_user - Platform administrators            │  │
│  │  • platform_role - Platform roles                     │  │
│  │  • permission - Master permission list                │  │
│  │  • tenant_role_template - Role templates              │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  TENANT DATABASES (bgerp_t_*) - Isolated Org Data    │  │
│  ├───────────────────────────────────────────────────────┤  │
│  │  PER TENANT:                                          │  │
│  │  • permission - Synced from core                      │  │
│  │  • tenant_role - Organization roles                   │  │
│  │  • mo - Manufacturing orders                          │  │
│  │  • mo_eta_cache - MO ETA cache (Task 23)              │  │
│  │  • mo_eta_health_log - ETA health log (Task 23)       │  │
│  │  • atelier_job_ticket - Job tickets (Linear)          │  │
│  │  • routing_graph - DAG routing graphs                 │  │
│  │  • routing_node - DAG nodes                           │  │
│  │  • routing_edge - DAG edges                           │  │
│  │  • flow_token - DAG tokens                            │  │
│  │  • token_event - Canonical events (Task 21)           │  │
│  │  • token_work_session - Work sessions                 │  │
│  │  • token_repair_log - Repair audit trail (Task 22)    │  │
│  │  • work_center - Work centers                          │  │
│  │  • machine - Machines                                 │  │
│  │  • product, bom, routing, stock, etc.                 │  │
│  │  • production_output_daily - Daily stats (Task 25)    │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔐 Permission Architecture

### **Hybrid Model: Tenant-Isolated with Core Fallback**

```
User Request
    ↓
1. Check Platform Role
    ├─ is_platform_administrator()
    │   └─ Query: platform_user + platform_role
    │       ├─ TRUE → Grant ALL access
    │       └─ FALSE → Continue
    ↓
2. Check Tenant Role (NEW - Priority)
    ├─ tenant_permission_allow_code()
    │   └─ Query: tenant_role + tenant_role_permission (Tenant DB)
    │       ├─ TRUE → Grant access
    │       ├─ FALSE → Deny access
    │       └─ NULL (tenant system not active) → Fallback to #3
    ↓
3. Fallback: Core Permission (Legacy)
    └─ permission_allow()
        └─ Query: permission_allow (Core DB)
            ├─ TRUE → Grant access
            └─ FALSE → Deny access
```

---

## 📅 Production Schedule Architecture

### **Data Flow:**

```
User Action (Drag & Drop MO)
    ↓
Frontend (schedule.js)
    ├─ FullCalendar event handler
    ├─ Extract new dates
    └─ AJAX POST to source/atelier_schedule.php
        ↓
API Endpoint (atelier_schedule.php)
    ├─ Authenticate (session check)
    ├─ Authorize (schedule.edit permission)
    └─ Delegate to ScheduleService
        ↓
Service Layer (ScheduleService.php)
    ├─ Validate dates (start < end)
    ├─ Check MO status (not completed)
    ├─ Log change (schedule_change_log)
    └─ UPDATE mo table
        ↓
Database (Tenant DB)
    ├─ mo.scheduled_start_date = new date
    ├─ mo.scheduled_end_date = new date
    └─ mo.is_scheduled = 1
        ↓
Response
    ├─ Success: {"ok":true,"message":"Schedule updated"}
    └─ Error: {"ok":false,"error":"validation failed"}
        ↓
Frontend
    ├─ Show notification
    ├─ Refresh calendar
    └─ Update summary panel
```

---

## 🔄 Capacity Calculation Flow

### **Factory Pattern:**

```
User Loads Calendar
    ↓
Frontend requests capacity_data
    ↓
API: source/atelier_schedule.php?action=capacity_data
    ↓
CapacityCalculatorFactory::create($db, $mode)
    ├─ Read: production_schedule_config.capacity_mode
    ├─ Mode = 'simple' → SimpleCapacityCalculator
    ├─ Mode = 'work_center' → WorkCenterCapacityCalculator
    └─ Mode = 'skill_based' → SkillBasedCalculator (future)
        ↓
Calculator->calculate($start_date, $end_date)
    ├─ For each day in range:
    │   ├─ Count active MO (simple mode)
    │   ├─ OR Calculate work center load (work center mode)
    │   └─ Return: {capacity, used, available, percentage}
    └─ Return array of daily capacity
        ↓
Response: {"ok":true,"capacity":[...]}
    ↓
Frontend renders Chart.js bar chart
```

---

## 🗄️ Database Schema Relationships

### **Core DB (bgerp):**

```
account (users)
    ↓ 1:N
account_org (user↔tenant mapping)
    ↓ N:1
organization (tenants)

account
    ↓ 1:1
platform_user (platform admins)
    ↓ 1:N
platform_user_role
    ↓ N:1
platform_role

permission (master list, 93)
    ↓ 1:N
tenant_role_template_permission
    ↓ N:1
tenant_role_template (7 templates)
```

---

### **Tenant DB (bgerp_t_*):**

```
permission (synced from core, 93)
    ↓ 1:N
tenant_role_permission (assignments)
    ↓ N:1
tenant_role (23 roles)

product
    ↓ 1:N
mo (manufacturing orders)
    ↓ 1:N
atelier_job_ticket
    ↓ N:1
work_center

product
    ↓ 1:1
routing
    ↓ 1:N
routing_step
    ↓ N:1
work_center
```

---

## 🔧 Key Design Patterns

### **1. Factory Pattern** (CapacityCalculator)
```php
interface CapacityCalculatorInterface {
    public function calculate($start, $end);
}

class SimpleCapacityCalculator implements CapacityCalculatorInterface { ... }
class WorkCenterCapacityCalculator implements CapacityCalculatorInterface { ... }

CapacityCalculatorFactory::create($db, $mode);
```

**Benefits:**
- Easy to add new calculation modes
- Swap implementations without changing API
- Testable in isolation

---

### **2. Strategy Pattern** (Permission Checking)
```php
// Try tenant system first
$result = tenant_permission_allow_code();

if ($result === null) {
    // Fallback to legacy system
    $result = permission_allow();
}
```

**Benefits:**
- Gradual migration path
- Backward compatibility
- Zero downtime deployment

---

### **3. Separation of Concerns**
```
Controller (atelier_schedule.php)
    ├─ Handle HTTP request/response
    ├─ Validate input
    └─ Delegate to Service Layer

Service (ScheduleService.php)
    ├─ Business logic
    ├─ Data validation
    └─ Database operations

Model (Database tables)
    └─ Data persistence
```

---

## 🚀 Scalability Considerations

### **Current Capacity:**

| Metric | Current | Phase 2 | Phase 3 |
|--------|---------|---------|---------|
| **Tenants** | 2 | 10 | 50+ |
| **Users/Tenant** | 5-10 | 20-50 | 100+ |
| **MO/Day** | 5-10 | 20-50 | 100+ |
| **Concurrent Users** | 2-3 | 10-15 | 50+ |

**Performance Optimizations:**
- ✅ Indexed queries (id, code, dates)
- ✅ Prepared statements (SQL injection prevention)
- ✅ Minimal JOINs (optimized queries)
- 🔄 Future: Redis cache for permissions
- 🔄 Future: Read replicas for reports

---

## 🔐 Security Architecture

### **Authentication:**
```
1. Session-based (PHP sessions)
2. Remember Me cookie (optional, hashed token)
3. Auto-login on cookie validation
```

### **Authorization:**
```
1. Role-based (account_group / tenant_role)
2. Permission-based (permission codes)
3. Tenant-isolated (each org has own data)
```

### **Data Isolation:**
```
1. Separate databases per tenant (bgerp_t_*)
2. org_code in session determines active tenant
3. resolve_current_org() enforces context
```

---

## 📈 Monitoring & Logging

### **Application Logs:**
```php
error_log() - PHP errors
LogHelper - Application events
schedule_change_log - Schedule audit trail
```

### **Database Monitoring:**
```sql
-- Schedule usage
SELECT COUNT(*) FROM schedule_change_log 
WHERE changed_at >= DATE_SUB(NOW(), INTERVAL 7 DAY);

-- Permission checks (slow query log)
-- Capacity calculations
```

---

## 🔮 Future Architecture

### **Phase 2 Enhancements:**
- Work center capacity mode
- Real-time collaboration (WebSockets)
- Background job queue (for auto-arrange)

### **Phase 3 Scaling:**
- Microservices (if > 100 tenants)
- Elasticsearch (for full-text search)
- Redis cache (for frequently accessed data)
- CDN (for static assets)

---

## 🎯 Technology Stack

| Layer | Technology | Version | Purpose |
|-------|------------|---------|---------|
| **Frontend** | FullCalendar | 6.1.10 | Production calendar |
| **Frontend** | Chart.js | 4.4.0 | Capacity visualization |
| **Frontend** | jQuery | 3.7.1 | AJAX & DOM manipulation |
| **Frontend** | Bootstrap | 5.x | UI framework |
| **Backend** | PHP | 7.4+ | Application logic |
| **Database** | MySQL | 5.7+ | Data persistence |
| **Server** | Apache/Nginx | Any | Web server |

---

## 📝 Architectural Decisions

### **1. Why Tenant-Isolated Permissions?**

**Problem:** Shared core permissions → all tenants get same permissions

**Solution:** Each tenant has own permission table

**Benefits:**
- ✅ Tenant customization (add/remove permissions)
- ✅ Security (tenant A can't see tenant B's config)
- ✅ Compliance (GDPR, SOC 2)

---

### **2. Why Interface-Based CapacityCalculator?**

**Problem:** Different calculation methods needed (simple/work center/skill-based)

**Solution:** Interface + Factory pattern

**Benefits:**
- ✅ Easy to swap implementations
- ✅ Add new modes without changing API
- ✅ Testable in isolation

---

### **3. Why Service Layer?**

**Problem:** Business logic mixed with controller code

**Solution:** Separate service classes

**Benefits:**
- ✅ Reusable business logic
- ✅ Easier to test
- ✅ Cleaner code (SRP principle)

---

## 🎯 Summary

**Architecture Type:** Monolithic (Multi-Tenant) with DAG Execution Engine

**Database Strategy:** Tenant-per-Database (Isolated)

**Permission Model:** Hybrid (Tenant-first, Core fallback)

**Design Patterns:** Factory, Strategy, Separation of Concerns, Service Layer, Bootstrap Layers

**Execution Model:** Dual-Mode (Linear + DAG) → Single-Mode (DAG only by Q3 2026)

**Key Components:**
- ✅ Bootstrap Layers (TenantApiBootstrap, CoreApiBootstrap)
- ✅ DAG Engine (Token-based routing, parallel execution, machine binding)
- ✅ Self-Healing (LocalRepairEngine, TimelineReconstructionEngine)
- ✅ Time Engine (Canonical timezone, ETA/SLA calculation)
- ✅ MO Intelligence (ETA, Load Simulation, Health Monitoring)
- ✅ Product Integration (Classic/Hatthasilpa consolidation)

**Scalability:** Designed for 2-50 tenants, 100+ users/tenant, 1000+ tokens/day

**Status:** ✅ **Production Ready** (100% enterprise-compliant APIs, 104+ tests passing)


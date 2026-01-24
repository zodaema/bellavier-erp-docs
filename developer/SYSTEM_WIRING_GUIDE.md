# 🔌 Bellavier Group ERP - System Wiring Guide

**Version:** 2.0  
**Date:** January 2025  
**Purpose:** Complete canonical reference for all system wiring, dependencies, and integration rules  
**Audience:** Developers, AI agents, system architects  
**Status:** ✅ Complete - All subsystems documented (Updated to reflect Task 25-26 reality)

---

## 📋 Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Master System Map (Critical Bloodlines Overview)](#2-master-system-map-critical-bloodlines-overview)
3. [Product Layer (Entry Point of All Work)](#3-product-layer-entry-point-of-all-work)
4. [Classic Line Wiring (Linear System)](#4-classic-line-wiring-linear-system)
5. [Hatthasilpa Line Wiring (DAG System)](#5-hatthasilpa-line-wiring-dag-system)
6. [MO + ETA System](#6-mo--eta-system)
7. [SuperDAG System (Canonical Events Engine)](#7-superdag-system-canonical-events-engine)
8. [Job Ticket System (Unified Overview)](#8-job-ticket-system-unified-overview)
9. [Component Serial / Traceability Wiring](#9-component-serial--traceability-wiring)
10. [People / Assignment / Operator Wiring](#10-people--assignment--operator-wiring)
11. [PWA Wiring](#11-pwa-wiring)
12. [Analytics Wiring](#12-analytics-wiring)
13. [Security Layer](#13-security-layer)
14. [API Layer Architecture](#14-api-layer-architecture)
15. [Rules for Future Development](#15-rules-for-future-development)
16. [DO NOT TOUCH Zones](#16-do-not-touch-zones)
17. [Appendix: Database Table Map](#17-appendix-database-table-map)

---

## 1. Executive Summary

### High-Level Architecture

**Bellavier Group ERP** is a multi-tenant manufacturing ERP system with **dual production lines**:

- 🎨 **Hatthasilpa** (Luxury, handcrafted, 1-50 pieces)
  - Uses **DAG (Directed Acyclic Graph)** routing
  - Token-based execution (`flow_token`)
  - Canonical event system (`token_event`)
  - Self-healing capabilities
  - Graph binding required

- 🏭 **Classic** (Mass production, 50-1000+ pieces)
  - Uses **Linear** routing only (DAG binding deprecated after Task 25.3)
  - Batch-first workflow
  - PWA scan-based tracking
  - MO-driven production planning
  - **No graph binding** (Hatthasilpa only)

### The "Bloodline" Metaphor

Think of the ERP as a living organism with **critical bloodlines** (wiring paths) that carry data and state:

- **Product → BOM → Routing → MO → Job Tickets → Output** (Main production bloodline)
- **Token → Node → Work Session → Canonical Event** (DAG execution bloodline)
- **Component Serial → Binding → Traceability** (Component genealogy bloodline)
- **People → Assignment → Work Queue → Operator** (Human resource bloodline)
- **MO → ETA → Cache → Health** (Intelligence bloodline)

**Critical Rule:** Never break a bloodline. Always understand dependencies before modifying.

### Bootstrap vs Legacy

**Bootstrap APIs (77+ files):**
- Use `TenantApiBootstrap::init()` or `CoreApiBootstrap::init()`
- Enterprise features: Rate limiting, Request validation, Idempotency
- Standardized error handling
- **Location:** `source/*_api.php` (modern APIs)

**Legacy APIs (8+ files):**
- Direct database access
- Manual authentication
- No enterprise features
- **Location:** `source/*.php` (legacy files)
- **Status:** ⚠️ Need migration

### Current System State

- **Database Tables:** 135 tables (13 core + 122 tenant)
- **API Files:** 85+ files (77+ migrated, 8+ legacy)
- **Services/Engines:** 87 total
  - 50 services (incl. DefectCatalogService, ComponentTypeService, ProductComponentService)
  - 26 DAG engines
  - 6 MO services
  - 4 Component services
  - 1 Product service
- **PSR-4 Classes:** 121 files in BGERP namespace

### System Readiness Matrix (January 2025)

**Status Legend:**
- ✅ **Live** - Actively used in production, core functionality
- ⚠️ **Optional/Partial** - Available but not main driver, experimental
- 🔜 **Planned** - Designed but not yet implemented at scale

| System Component | Status | Notes |
|-----------------|--------|-------|
| **Hatthasilpa DAG Core** | ✅ Live | Token engine, canonical events, self-healing - production ready |
| **Work Queue + Assignment** | ✅ Live | Hatthasilpa only, fully operational |
| **Product v2** (line, draft, classic dashboard) | ✅ Live | Production line separation, draft/publish flow active |
| **Classic Minimal Mode** (job_ticket + output stats) | ✅ Live | Core Classic workflow in use |
| **Component Serial / Traceability** | ✅ Live | Full implementation, actively used |
| **Security / Permissions / Bootstrap** | ✅ Live | Enterprise features operational |
| **Classic Extended Mode** (job_task + wip_log + operator_session) | ⚠️ Optional/Partial | Infrastructure exists, not main driver |
| **MO ETA / Health System** | ⚠️ Optional/Experimental | Engine available, not enforced in daily operations |
| **Node Behavior Engine** (execution profiles) | 🔜 Planned | Architecture ready, full implementation pending |

**Critical Notes:**
- Classic Line uses **Linear mode only** (DAG binding deprecated)
- Work Queue is **Hatthasilpa only** (not for Classic)
- PWA scanners are **Classic only** (not work queue interface)
- MO ETA is calculated but **not used as constraint** in current factory operations

---

## 2. Master System Map (Critical Bloodlines Overview)

### ASCII Subway Map

```
┌──────────────────────────────────────────────────────────────────────────┐
│                      BELLAVIER ERP SYSTEM MAP                            │
└──────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────┐
                    │    PRODUCT      │
                    │ (production_line│
                    │ classic|hatthas)│
                    └────────┬────────┘
                             │
                ┌────────────┴────────────┐
                │                         │
        ┌───────▼───────┐      ┌──────────▼──────────────┐
        │      BOM      │      │  PRODUCT GRAPH BINDING  │
        └───────┬───────┘      └──────────┬──────────────┘
                │                         │
                └──────────┬──────────────┘
                           │
                    ┌──────▼────────┐
                    │ ROUTING GRAPH │
                    └──────┬────────┘
                           │
            ┌──────────────┴─────────────┐
            │                            │
    ┌───────▼──────┐            ┌────────▼─────────┐
     │      MO      │            │   JOB TICKET     │
     │  (Classic)   │            │  (Classic/Hatthas)│
    └───────┬──────┘            └────────┬─────────┘
            │                            │
    ┌───────▼──────┐            ┌────────┴────────────┐
    │   MO ETA     │            │                     │
    └───────┬──────┘            │                     │
            │            ┌───────▼──────┐    ┌────────▼─────────┐
    ┌───────▼──────┐     │ CLASSIC LINE │    │ HATTHASILPA LINE │
    │   MO CACHE   │     │   (Linear)   │    │     (DAG)        │
    └──────────────┘     └───────┬──────┘    └────────┬─────────┘
                                 │                    │
                    ┌────────────┴──────┐   ┌─────────┴──────────┐
                    │                   │   │                    │
            ┌───────▼──────┐    ┌───────▼──────┐     ┌───────────▼──────────┐
            │   JOB TASK   │    │  GRAPH       │     │    TOKEN SPAWN       │
            │   (Linear)   │    │  INSTANCE    │     │  (TokenLifecycle)    │
            └───────┬──────┘    └───────┬──────┘     └───────────┬──────────┘
                    │                   │                        │
            ┌───────▼──────┐    ┌───────┴────────────────────────┴──────────┐
            │   WIP LOG    │    │                                           │
            │  (soft-del)  │    │  ┌─────────────────────────────────────┐  │
            └───────┬──────┘    │  │  TOKEN EVENT (Canonical)            │  │
                    │           │  └─────────────────────────────────────┘  │
            ┌───────▼──────┐    │                                           │
            │ OUTPUT STATS │    │  ┌─────────────────────────────────────┐  │
            │ (production_ │    │  │  NODE INSTANCE → WORK SESSION       │  │
            │  output_daily│    │  └─────────────────────────────────────┘  │
            └──────────────┘    │                                           │
                                │  ┌─────────────────────────────────────┐  │
                                │  │  ASSIGNMENT → OPERATOR              │  │
                                │  └─────────────────────────────────────┘  │
                                │                                           │
                                │  ┌─────────────────────────────────────┐  │
                                │  │  COMPONENT BINDING → TRACEABILITY   │  │
                                │  └─────────────────────────────────────┘  │
                                │                                           │
                                │  ┌─────────────────────────────────────┐  │
                                │  │  REPAIR ENGINE (Self-Healing)       │  │
                                │  └─────────────────────────────────────┘  │
                                │                                           │
                                │  ┌─────────────────────────────────────┐  │
                                │  │  TIME ENGINE → ETA/SLA              │  │
                                │  └─────────────────────────────────────┘  │
                                │                                           │
                                │  ┌─────────────────────────────────────┐  │
                                │  │  ANALYTICS → PRODUCTION OUTPUT      │  │
                                │  └─────────────────────────────────────┘  │
                                └───────────────────────────────────────────┘
```

### Critical Bloodlines (Detailed)

#### Bloodline 1: Product → Production Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│  Product (production_line: classic|hatthasilpa)             │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
┌────────▼──────────┐  ┌─────────▼──────────────────────┐
│ Product Graph     │  │ (if hatthasilpa)               │
│ Binding           │  │ ProductGraphBindingHelper      │
└────────┬──────────┘  └──────────┬─────────────────────┘
         │                        │
         └───────────┬────────────┘
                     │
         ┌───────────▼──────────────────────────┐
         │  Routing Graph                       │
         │  (routing_graph, routing_node,       │
         │   routing_edge)                      │
         └───────────┬──────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
┌────────▼──────────┐  ┌─────────▼──────────────────────┐
│ MO (mo)           │  │ Hatthasilpa Job                │
│ (Classic only)    │  │ (hatthasilpa_jobs_api)         │
└────────┬──────────┘  └──────────┬─────────────────────┘
         │                        │
         └───────────┬────────────┘
                     │
         ┌───────────▼───────────┐
         │  Job Ticket           │
         │  (job_ticket)         │
         └───────────┬───────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
┌────────▼───────────┐  ┌────────▼──────────────────────────┐
│ Classic Path:      │  │ Hatthasilpa Path:                 │
│ job_task           │  │ job_graph_instance                │
│   → wip_log        │  │   → flow_token                    │
│   → production_    │  │   → token_event                   │
│     output_daily   │  │   → completion                    │
└────────────────────┘  └───────────────────────────────────┘
```

**Key Files:**
- `source/BGERP/Product/ProductMetadataResolver.php` - Resolves production line
- `source/BGERP/Helper/ProductGraphBindingHelper.php` - Graph binding lookup
- `source/BGERP/Service/JobCreationService.php` - Job creation from binding
- `source/mo.php` - MO creation (Classic only)
- `source/hatthasilpa_jobs_api.php` - Hatthasilpa job creation

**Key Tables:**
- `product` - Products (production_line column)
- `product_graph_binding` - Product↔Graph bindings
- `routing_graph` - DAG graphs
- `mo` - Manufacturing orders
- `job_ticket` - Job tickets

#### Bloodline 2: Token Execution Pipeline (DAG)

```
┌─────────────────────────────────────────────────────────────┐
│  Token Spawn                                                │
│  (TokenLifecycleService::spawnTokens)                       │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────▼────────────┐
         │  flow_token            │
         │  (status: ready)       │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  Node Enter            │
         │  (DagExecutionService::│
         │   enterNode)           │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  node_instance         │
         │  (status: active)      │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  Work Session Start    │
         │  (BehaviorExecution    │
         │   Service)             │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  token_work_session    │
         │  (status: active)      │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  Canonical Event       │
         │  (TokenEventService::  │
         │   persistEvent)        │
         └───────────┬────────────┘
                     │
         ┌───────────▼───────────┐
         │  token_event          │
         │  (canonical_type:     │
         │   NODE_START)         │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Work Complete        │
         │  (BehaviorExecution   │
         │   Service)            │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  token_event          │
         │  (canonical_type:     │
         │   NODE_COMPLETE)      │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Time Sync            │
         │  (TimeEventReader::   │
         │   syncTimeline)       │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  flow_token           │
         │  (start_at,           │
         │   completed_at,       │
         │   actual_duration_ms) │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Route to Next Node   │
         │  (DAGRoutingService:: │
         │   routeToken)         │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  [Repeat or Complete] │
         └───────────────────────┘
```

**Key Files:**
- `source/BGERP/Service/TokenLifecycleService.php` - Token lifecycle
- `source/BGERP/Dag/DagExecutionService.php` - Token movement
- `source/BGERP/Dag/BehaviorExecutionService.php` - Node behavior
- `source/BGERP/Dag/TokenEventService.php` - Canonical events
- `source/BGERP/Dag/TimeEventReader.php` - Time synchronization

**Key Tables:**
- `flow_token` - Tokens
- `token_event` - Canonical events
- `token_work_session` - Work sessions
- `node_instance` - Node instances

#### Bloodline 3: Component Serial Binding Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│  Component Serial Pool                                      │
│  (component_serial_pool)                                    │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────▼────────────┐
         │  Component Serial      │
         │  Batch                 │
         │  (component_serial_    │
         │   batch)               │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  Component Serial      │
         │  (component_serial)    │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  Component Serial      │
         │  Allocation            │
         │  (component_serial_    │
         │   allocation)          │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  Component Serial      │
         │  Binding               │
         │  (component_serial_    │
         │   binding)             │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  Job Ticket Serial     │
         │  (job_ticket_serial)   │
         └───────────┬────────────┘
                     │
         ┌───────────▼───────────┐
         │  Traceability         │
         │  (trace_access_log,   │
         │   trace_note)         │
         └───────────────────────┘
```

**Key Files:**
- `source/BGERP/Component/ComponentSerialService.php` - Serial management
- `source/BGERP/Component/ComponentBindingService.php` - Binding operations
- `source/hatthasilpa_component_api.php` - Component API
- `source/trace_api.php` - Traceability API

**Key Tables:**
- `component_serial_pool` - Serial pool
- `component_serial_batch` - Serial batches
- `component_serial` - Component serials
- `component_serial_binding` - Serial bindings
- `trace_access_log` - Trace access log

#### Bloodline 4: Assignment & Operator Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│  Assignment Plan                                            │
│  (assignment_plan_job, assignment_plan_node)                │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────▼────────────┐
         │  Assignment Engine     │
         │  (AssignmentEngine::   │
         │   decide)              │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  Assignment Decision   │
         │  Log                   │
         │  (assignment_decision_ │
         │   log)                 │
         └───────────┬────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
┌────────▼──────────┐  ┌─────────▼───────────┐
│  Token Assignment │  │  Node Assignment    │
│  (token_assignment│  │  (node_assignment)  │
└────────┬──────────┘  └─────────┬───────────┘
         │                       │
         └───────────┬───────────┘
                     │
         ┌───────────▼────────────┐
         │  People Operator Cache │
         │  (people_operator_     │
         │   cache)               │
         └───────────┬────────────┘
                     │
         ┌───────────▼─────────────┐
         │  Operator Availability  │
         │  (operator_availability)│
         └───────────┬─────────────┘
                     │
         ┌───────────▼───────────┐
         │  Work Queue           │
         │  (worker_token_api)   │
         │  ⚠️ Hatthasilpa ONLY  │
         └───────────────────────┘
```

**Key Files:**
- `source/BGERP/Service/AssignmentEngine.php` - Assignment logic
- `source/BGERP/Service/AssignmentResolverService.php` - Assignment resolution
- `source/BGERP/Service/NodeAssignmentService.php` - Node assignments
- `source/assignment_api.php` - Assignment API
- `source/worker_token_api.php` - Work queue API

**Key Tables:**
- `assignment_plan_job` - Job assignment plans
- `assignment_plan_node` - Node assignment plans
- `assignment_decision_log` - Decision log
- `token_assignment` - Token assignments
- `node_assignment` - Node assignments
- `people_operator_cache` - Operator cache
- `operator_availability` - Availability data

#### Bloodline 5: MO Intelligence Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│  MO Creation                                                │
│  (mo.php or mo_assist_api.php)                              │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────▼───────────┐
         │  MO Load Simulation   │
         │  (MOLoadSimulation    │
         │   Service::           │
         │   runSimulation)      │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  MO ETA Calculation   │
         │  (MOLoadEtaService::  │
         │   computeETA)         │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  MO ETA Cache         │
         │  (MOEtaCacheService:: │
         │   cacheETA)           │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  mo_eta_cache         │
         │  (cached ETA)         │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  MO ETA Health        │
         │  (MOEtaHealthService::│
         │   validateETAHealth)  │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  mo_eta_health_log    │
         │  (health log)         │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Token Completion     │
         │  Hook                 │
         │  (TokenLifecycle      │
         │   Service::           │
         │   completeToken)      │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  ETA Health Update    │
         │ (MOEtaHealthService:: │
         │   onTokenCompleted)   │
         └───────────────────────┘
```

**Key Files:**
- `source/BGERP/MO/MOCreateAssistService.php` - MO creation assist
- `source/BGERP/MO/MOLoadSimulationService.php` - Load simulation
- `source/BGERP/MO/MOLoadEtaService.php` - ETA calculation
- `source/BGERP/MO/MOEtaCacheService.php` - ETA caching
- `source/BGERP/MO/MOEtaHealthService.php` - ETA health
- `source/BGERP/MO/MOEtaAuditService.php` - ETA audit

**Key Tables:**
- `mo` - Manufacturing orders
- `mo_eta_cache` - ETA cache
- `mo_eta_health_log` - ETA health log

#### Bloodline 6: Self-Healing Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│  Integrity Check                                            │
│  (CanonicalEventIntegrity                                   │
│   Validator::validateToken)                                 │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────▼────────────┐
         │  Problem Detection     │
         │  (LocalRepairEngine::  │
         │   detectProblems)      │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  Local Repair          │
         │  (LocalRepairEngine::  │
         │   repair)              │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  token_repair_log      │
         │  (repair log)          │
         └───────────┬────────────┘
                     │
         ┌───────────▼─────────────┐
         │  Timeline               │
         │  Reconstruction         │
         │  (TimelineReconstruction│
         │   Engine::reconstruct)  │
         └───────────┬─────────────┘
                     │
         ┌───────────▼─────────────┐
         │  Repair Orchestration   │
         │  (RepairOrchestrator::  │
         │   orchestrate)          │
         └─────────────────────────┘
```

**Key Files:**
- `source/BGERP/Dag/CanonicalEventIntegrityValidator.php` - Integrity validation
- `source/BGERP/Dag/LocalRepairEngine.php` - Local repair
- `source/BGERP/Dag/TimelineReconstructionEngine.php` - Timeline reconstruction
- `source/BGERP/Dag/RepairOrchestrator.php` - Repair orchestration

**Key Tables:**
- `token_event` - Canonical events
- `token_repair_log` - Repair log
- `flow_token` - Tokens

---

## 3. Product Layer (Entry Point of All Work)

### Product Core

**Location:** `source/BGERP/Product/ProductMetadataResolver.php`

**Purpose:** Resolve product metadata including production line and routing bindings.

**Key Method:**
```php
ProductMetadataResolver::resolve($productId): array
```

**Returns:**
- `production_line`: `'hatthasilpa'` | `'classic'`
- `routing`: Graph binding data (if Hatthasilpa)
- `dashboard_available`: Boolean

**Key Table:** `product`
- `production_line` VARCHAR(32) - Single value: `'hatthasilpa'` or `'classic'`
- `is_draft` TINYINT - 0 = published, 1 = draft
- `is_active` TINYINT - Active status

### Product Graph Binding

**Location:** `source/BGERP/Helper/ProductGraphBindingHelper.php`

**Purpose:** Link products to routing graphs (Hatthasilpa only).

**Key Method:**
```php
ProductGraphBindingHelper::getActiveBinding($db, $productId, $mode): ?array
```

**Key Table:** `product_graph_binding`
- `id_product` - Product ID
- `id_graph` - Routing graph ID
- `default_mode` - `'hatthasilpa'` | `'classic'` | `'hybrid'`
- `is_active` - Active binding
- `effective_from` / `effective_until` - Validity period
- `priority` - Binding priority

**Rules:**
- ✅ **Hatthasilpa products** MUST have graph binding
- ❌ **Classic products** MUST NOT have graph binding (deprecated after Task 25.3)
- ✅ Only ONE active binding per product per mode
- ✅ Binding determines which graph to use for Hatthasilpa job creation

**⚠️ Deprecation Note (Task 25.3-25.5):**
- Classic DAG binding was deprecated
- Classic now uses Linear mode exclusively
- Hybrid mode is no longer supported

### Duplicate → Draft Flow

**Location:** `source/product_api.php`

**Flow:**
1. User creates product → `is_draft = 0` (published)
2. User clicks "Duplicate" → Creates copy with `is_draft = 1` (draft)
3. User edits draft → Updates draft product
4. User clicks "Publish" → `is_draft = 0` (published)

**Key Logic:**
- Draft products are NOT visible in production
- Draft products CAN be edited freely
- Publishing draft activates the product
- **UI:** Product modal has "Duplicate" button → creates draft
- **UI:** Draft products show "Publish" button, published products show "Unpublish"

### Product State Diagram

**Product Lifecycle States:**

```
┌─────────────────────────────────────────────────────────────┐
│                    PRODUCT STATE FLOW                       │
└─────────────────────────────────────────────────────────────┘

         ┌──────────────┐
         │    DRAFT     │
         │ (is_draft=1) │
         │              │
         │ • Not visible│
         │   in prod    │
         │ • Editable   │
         └──────┬───────┘
                │
                │ publish
                │
         ┌──────▼──────────────┐
         │    PUBLISHED        │
         │ (is_draft=0,        │
         │  is_active=1)       │
         │                     │
         │ • Visible in prod   │
         │ • Can create jobs   │
         └──────┬──────────────┘
                │
                │ unpublish
                │
         ┌──────▼──────────────┐
         │    INACTIVE         │
         │  (is_active=0)      │
         │                     │
         │ • Hidden from UI    │
         │ • Cannot create     │
         │   new jobs          │
         └─────────────────────┘
```

**State Transitions:**
- **DRAFT → PUBLISHED:** User clicks "Publish" → `is_draft = 0`, `is_active = 1`
- **PUBLISHED → INACTIVE:** User clicks "Unpublish" → `is_active = 0`
- **INACTIVE → PUBLISHED:** User clicks "Publish" → `is_active = 1`
- **PUBLISHED → DRAFT:** User clicks "Duplicate" → Creates new product with `is_draft = 1`

**Rules:**
- Only **PUBLISHED** products can be used for job creation
- **DRAFT** products are for editing/preparation only
- **INACTIVE** products are hidden but retain historical data

### Classic Dashboard Integration

**Location:** `assets/javascripts/products/products.js`

**Purpose:** Show Classic production statistics in Product modal.

**Features:**
- Classic Dashboard tab in Product modal (for Classic products only)
- Displays `production_output_daily` statistics
- Shows completed quantity, lead time, output dates
- **Not available for Hatthasilpa products** (they use Graph Dashboard)

### Product Assets vs Pattern Assets

**Product Assets:**
- **Table:** `product_asset`
- **Purpose:** Product images, thumbnails
- **Usage:** Product display, catalog

**Pattern Assets:**
- **Table:** `pattern` + `pattern_version`
- **Purpose:** Design files (PDF, AI, SVG)
- **Usage:** Production reference, versioning

**Separation:**
- Product assets = Marketing/Display
- Pattern assets = Production/Design

---

## 4. Classic Line Wiring (Linear System)

### Classic Production Modes

**⚠️ Important:** Classic Line has two operational modes:

1. **Minimal Classic Mode** (✅ **Live** - Currently in use)
   - Job Ticket → Output Stats
   - Simple planning and completion tracking
   - Uses `production_output_daily` for statistics

2. **Extended Classic Linear Mode** (⚠️ **Optional/Partial** - Infrastructure exists, not main driver)
   - Job Ticket → Job Task → WIP Log → Operator Session
   - Detailed task-level tracking
   - **⚠️ Important:** This mode exists for historical and future integration purposes
   - **It is NOT part of the current manufacturing workflow at Bellavier Factory**
   - Not actively used in current factory operations

### Classic Production Flow (Minimal Mode - Current)

**Entry Point:** `source/classic_api.php` or `source/mo.php`

**Flow:**
```
┌───────────────────────────────────┐
│        MO Creation (mo.php)       │
└────────────────────┬──────────────┘
                     │
         ┌───────────▼────────────┐
         │  MO Status: planned    │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  Job Ticket Creation   │
         │  (job_ticket.php or    │
         │   classic_api.php)     │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  job_ticket            │
         │  (production_type=     │
         │   'classic',           │
         │   routing_mode=        │
         │   'linear' ONLY)       │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  Ticket Completion    │
         │  (JobTicketStatus     │
         │   Service)            │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  Production Output     │
         │  Stats                 │
         │  (ClassicProduction    │
         │   StatsService)        │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  production_output_    │
         │  daily                 │
         │  (daily aggregation)   │
         └────────────────────────┘
```

**⚠️ Deprecation Note (Task 25.3-25.5):**
- Classic DAG mode (`routing_mode='dag'`) was deprecated
- Classic now uses Linear mode exclusively
- Graph binding for Classic products is no longer supported

### Classic Line Tables

**Core Tables (Minimal Mode - Active):**
- `job_ticket` - Job tickets
  - `production_type = 'classic'`
  - `process_mode = 'batch'`
  - `routing_mode = 'linear'` (ONLY - DAG deprecated)
- `production_output_daily` - Daily output statistics
  - Aggregated completion data
  - Used for Classic Dashboard

**Extended Tables (Optional - Not Main Driver):**
- `job_task` - Job tasks
  - `sequence_no` - Task order
  - `status` - Task status
  - ⚠️ Infrastructure exists but not actively used
- `wip_log` - WIP logs (soft-delete)
  - `event_type` - 'start', 'complete', 'hold', 'resume'
  - `deleted_at IS NULL` - Always filter
  - ⚠️ Available for future use, not current workflow
- `task_operator_session` - Operator sessions
  - Used for progress calculation
  - ⚠️ Optional, not required for minimal mode

### Classic Line Rules

**✅ DO:**
- Use `wip_log` for scan events
- Use `task_operator_session` for progress tracking (optional)
- Use `production_output_daily` for statistics
- Filter `wip_log` with `deleted_at IS NULL`

**❌ DON'T:**
- Use DAG tables (`flow_token`, `token_event`) for Classic (deprecated)
- Use `token_work_session` for Classic
- Use assignment system for Classic (Hatthasilpa only)
- Use canonical events for Classic
- Use graph binding for Classic products (deprecated after Task 25.3)
- Use `routing_mode='dag'` for Classic tickets

### Classic Line APIs

**Primary APIs:**
- `source/classic_api.php` - Classic job ticket management
- `source/mo.php` - MO creation (Classic only)
- `source/job_ticket.php` - Job ticket management (supports both)

**PWA Integration:**
- `source/pwa_scan_api.php` - Scan events
- Limited to scan_in/scan_out events
- No DAG token operations

### Classic Line ETA

**Status:** ⚠️ ETA is **optional/experimental** for Classic Line
- MO ETA engine exists and can calculate ETA
- **Not used as constraint** in current factory operations
- Classic uses fixed schedules and manual planning
- No SLA tracking or ETA enforcement for Classic tasks
- ETA is available for informational purposes only

---

## 5. Hatthasilpa Line Wiring (DAG System)

### Hatthasilpa Production Flow

**Entry Point:** `source/hatthasilpa_jobs_api.php`

**UI Integration:**
- `hatthasilpa_jobs_api.php` → Creates Hatthasilpa job tickets
- Click "View" on Hatthasilpa job → Opens Job Ticket Offcanvas with `src=hatthasilpa`
- Job Ticket for Hatthasilpa:
  - Shows overview and progress
  - Links to Work Queue (`worker_token_api.php`)
  - **No lifecycle buttons** (status managed via Work Queue)
  - Used as dashboard/overview, not direct control interface

**Flow:**
```
┌──────────────────────────────────┐
│  Hatthasilpa Job Creation        │
│  (hatthasilpa_jobs_api.php)      │
└────────────────────┬─────────────┘
                     │
         ┌───────────▼───────────┐
         │  Product Graph        │
         │  Binding Lookup       │
         │  (ProductGraphBinding │
         │   Helper)             │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Routing Graph        │
         │  Selection            │
         │  (routing_graph)      │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Job Ticket Creation  │
         │  (JobCreationService::│
         │   createFromBinding)  │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  job_ticket           │
         │  (production_type=    │
         │   'hatthasilpa',      │
         │   routing_mode='dag', │
         │   graph_instance_id   │
         │   required)           │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Graph Instance       │
         │  Creation             │
         │ (GraphInstanceService │
         │   ::createInstance)   │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  job_graph_instance   │
         │  (graph_id,           │
         │   production_type=    │
         │   'hatthasilpa')      │
         └───────────┬───────────┘
                     │
         ┌───────────▼────────────┐
         │  Node Instance         │
         │  Creation              │
         │  (GraphInstanceService │
         │  ::createNodeInstances)│
         └───────────┬────────────┘
                     │
         ┌───────────▼───────────┐
         │  node_instance        │
         │  (one per graph node) │
         └───────────┬───────────┘
                     │
         ┌───────────▼────────────┐
         │  Token Spawn           │
         │  (TokenLifecycleService│
         │   ::spawnTokens)       │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  flow_token            │
         │  (status='ready',      │
         │   spawned_at START)    │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  Token Enter Node      │
         │  (DagExecutionService::│
         │   enterNode)           │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  node_instance         │
         │  (status='active')     │
         └───────────┬────────────┘
                     │
         ┌───────────▼───────────┐
         │  Work Session Start   │
         │  (BehaviorExecution   │
         │   Service)            │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  token_work_session   │
         │  (status='active')    │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Canonical Event      │
         │  (TokenEventService:: │
         │   persistEvent)       │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  token_event          │
         │  (canonical_type=     │
         │   'NODE_START')       │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Work Complete        │
         │  (BehaviorExecution   │
         │   Service)            │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  token_event          │
         │  (canonical_type=     │
         │   'NODE_COMPLETE')    │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Time Sync            │
         │  (TimeEventReader::   │
         │   syncTimeline)       │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  flow_token           │
         │  (start_at,           │
         │   completed_at,       │
         │   actual_duration_ms) │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Route to Next Node   │
         │  (DAGRoutingService:: │
         │   routeToken)         │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  [Repeat until        │
         │   END node]           │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Token Complete       │
         │  (TokenLifecycle      │
         │   Service::           │
         │   completeToken)      │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  flow_token           │
         │  (status='completed') │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Job Complete         │
         │  (JobTicketStatus     │
         │   Service)            │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  job_ticket           │
         │  (status='completed') │
         └───────────────────────┘
```

### Hatthasilpa Line Tables

**Core Tables:**
- `job_ticket` - Job tickets
  - `production_type = 'hatthasilpa'`
  - `routing_mode = 'dag'`
  - `graph_instance_id` - Required
- `job_graph_instance` - Graph instances
  - `id_graph` - Graph ID
  - `production_type = 'hatthasilpa'`
- `routing_graph` - DAG graphs
  - `production_type = 'hatthasilpa'` (or `'hybrid'`)
- `routing_node` - Graph nodes
  - `node_type` - START, OPERATION, QC, END, etc.
  - `node_mode` - From work center behavior
- `routing_edge` - Graph edges
  - `from_node_id` / `to_node_id`
  - `edge_condition` - Conditional routing
- `flow_token` - DAG tokens
  - `status` - ready, active, waiting, paused, completed, scrapped
  - `current_node_id` - Current node
  - `spawned_at_node_id` - START node
- `token_event` - Canonical events
  - `canonical_type` - TOKEN_*, NODE_*, OVERRIDE_*, COMP_*
  - `event_data` - JSON payload
- `token_work_session` - Work sessions
  - `status` - active, paused, completed
  - `started_at` / `completed_at` - Timestamps
- `node_instance` - Node instances
  - `status` - pending, active, completed
  - `started_at` / `completed_at` - Timestamps

### Hatthasilpa Line Rules

**✅ DO:**
- Use `flow_token` for work tracking
- Use `token_event` for canonical events
- Use `token_work_session` for work sessions
- Use `node_instance` for node state
- Use assignment system for operator assignment
- Use graph binding for job creation
- Use canonical events for all state changes

**❌ DON'T:**
- Use `wip_log` for Hatthasilpa (Linear only)
- Use `task_operator_session` for Hatthasilpa (use `token_work_session`)
- Create jobs without graph binding
- Bypass canonical event system
- Manually update token tables

### Hatthasilpa Line APIs

**Primary APIs:**
- `source/hatthasilpa_jobs_api.php` - Job creation
- `source/dag_token_api.php` - Token operations
- `source/dag_routing_api.php` - Graph management
- `source/worker_token_api.php` - Work queue
- `source/token_management_api.php` - Token management

**Key Services:**
- `TokenLifecycleService` - Token lifecycle
- `DagExecutionService` - Token movement
- `BehaviorExecutionService` - Node behavior
- `TokenEventService` - Canonical events
- `NodeBehaviorEngine` - Behavior execution

---

## 6. MO + ETA System

### MO System Overview

**Purpose:** Manufacturing Order management for Classic production line.

**Key Rule:** MO is **Classic only** (hardcoded `production_type = 'classic'`)

**Location:** `source/mo.php`, `source/mo_assist_api.php`

### MO Creation Flow

```
┌──────────────────────────────┐
│  MO Creation                 │
│  (mo.php → create action)    │
└────────────────────┬─────────┘
                     │
         ┌───────────▼───────────┐
         │  Product Selection    │
         │  (id_product)         │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Product Graph        │
         │  Binding Lookup       │
         │  (ProductGraphBinding │
         │   Helper)             │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Routing Graph        │
         │  Auto-Select          │
         │  (if binding exists)  │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  MO Created           │
         │  (mo table)           │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  MO Status:           │
         │  draft → planned      │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Job Ticket Creation  │
         │  (job_ticket.php or   │
         │   classic_api.php)    │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Job Ticket Linked    │
         │  to MO                │
         │  (job_ticket.id_mo)   │
         └───────────────────────┘
```

### MO ETA System

**Purpose:** Calculate Estimated Time of Arrival for MOs.

**⚠️ Status:** Optional/Experimental - Engine available but not enforced in daily operations

**Current Usage:**
- ETA calculation engine is fully implemented
- ETA cache and health monitoring systems are operational
- **Not used as constraint** in current factory planning
- Available for informational/debugging purposes
- Future: May be integrated as planning tool

**Components:**

1. **MOLoadSimulationService** (`source/BGERP/MO/MOLoadSimulationService.php`)
   - Simulates load on work centers
   - Projects node execution times
   - Uses canonical timeline first, then historic data

2. **MOLoadEtaService** (`source/BGERP/MO/MOLoadEtaService.php`)
   - Calculates ETA (best, normal, worst case)
   - Stage-level and node-level ETA
   - Delay propagation
   - Queue modeling

3. **MOEtaCacheService** (`source/BGERP/MO/MOEtaCacheService.php`)
   - Caches ETA results
   - Signature-based invalidation
   - TTL-based expiration

4. **MOEtaHealthService** (`source/BGERP/MO/MOEtaHealthService.php`)
   - Validates ETA health
   - Monitors drift
   - Creates health log entries

5. **MOEtaAuditService** (`source/BGERP/MO/MOEtaAuditService.php`)
   - Cross-validates ETA calculations
   - Compares ETA vs Simulation vs Canonical
   - Debugging tool

### MO ETA Flow

```
┌───────────────────────────┐
│  MO Created/Updated       │
└───────────────────────────┘
                     │
         ┌───────────▼───────────┐
         │  MO ETA Calculation   │
         │  Request              │
         │  (mo_eta_api.php)     │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  MOEtaCacheService::  │
         │  getOrCompute()       │
         └───────────┬───────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
┌────────▼──────────┐  ┌─────────▼──────────┐
│  Cache Hit?       │  │  Cache Miss?       │
│  Return cached    │  │  Compute ETA       │
│  ETA              │  └─────────┬──────────┘
└───────────────────┘            │
                     ┌───────────▼──────────┐
                     │  MOLoadSimulation    │
                     │  Service::           │
                     │  runSimulation()     │
                     └───────────┬──────────┘
                                 │
                     ┌───────────▼──────────┐
                     │  MOLoadEtaService::  │
                     │  computeETA()        │
                     └───────────┬──────────┘
                                 │
                     ┌───────────▼───────────┐
                     │  MOEtaCacheService::  │
                     │  cacheETA()           │
                     └───────────┬───────────┘
                                 │
                     ┌───────────▼───────────┐
                     │  mo_eta_cache         │
                     │  (cached result)      │
                     └───────────┬───────────┘
                                 │
                     ┌───────────▼───────────┐
                     │  MOEtaHealthService:: │
                     │  validateETAHealth()  │
                     └───────────┬───────────┘
                                 │
                     ┌───────────▼───────────┐
                     │  mo_eta_health_log    │
                     │  (health log)         │
                     └───────────────────────┘
```

### MO ETA Tables

- `mo` - Manufacturing orders
  - `id_routing_graph` - Graph ID (optional)
  - `production_type = 'classic'` (hardcoded)
- `mo_eta_cache` - ETA cache
  - `input_signature` - Cache key
  - `ttl_expires_at` - Expiration time
  - `eta_result` - Cached ETA (JSON)
- `mo_eta_health_log` - Health log
  - `health_status` - OK, WARNING, ERROR
  - `metrics` - Health metrics (JSON)

### MO Lifecycle Hooks

**Token Completion Hook:**
- `TokenLifecycleService::completeToken()` calls `MOEtaHealthService::onTokenCompleted()`
- Updates health log when tokens complete
- Non-blocking (best-effort)

**MO Update Hook:**
- `mo.php` → `update` action invalidates ETA cache
- Triggers ETA recalculation on next request

**⚠️ Current Usage Status:**
- ETA engine is fully operational and can calculate ETA
- ETA cache and health monitoring are active
- **Not used as constraint** in current factory planning operations
- Classic Line uses fixed schedules and manual planning
- ETA available for informational/debugging purposes only
- Future: May be integrated as planning tool when needed

---

## 7. SuperDAG System (Canonical Events Engine)

### Canonical Event Framework

**Core Principle:** "Reality Flexible, Logic Strict"

All state changes in the DAG system must go through **canonical events**. The canonical event system is the **single source of truth** for token state.

### Canonical Event Types

**Whitelist (from `TokenEventService`):**

- **TOKEN_***: `TOKEN_CREATE`, `TOKEN_SHORTFALL`, `TOKEN_ADJUST`, `TOKEN_SPLIT`, `TOKEN_MERGE`
- **NODE_***: `NODE_START`, `NODE_PAUSE`, `NODE_RESUME`, `NODE_COMPLETE`, `NODE_CANCEL`
- **OVERRIDE_***: `OVERRIDE_ROUTE`, `OVERRIDE_TIME_FIX`, `OVERRIDE_TOKEN_ADJUST`
- **COMP_***: `COMP_BIND`, `COMP_UNBIND`
- **INVENTORY_***: `INVENTORY_MOVE`

### Canonical Event Flow

```
┌─────────────────────────────────────────────────────────────┐
│  State Change Request                                       │
│  (API)                                                      │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────▼───────────┐
         │  Service Layer        │
         │  (TokenLifecycle      │
         │   Service,            │
         │   BehaviorExecution   │
         │   Service, etc.)      │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Canonical Event      │
         │  Creation             │
         │  (TokenEventService:: │
         │   persistEvent)       │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  token_event          │
         │  (canonical_type,     │
         │   event_data JSON)    │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  State Update         │
         │  (flow_token,         │
         │   node_instance, etc.)│
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Time Sync            │
         │  (TimeEventReader::   │
         │   syncTimeline)       │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  flow_token           │
         │  (start_at,           │
         │   completed_at,       │
         │   actual_duration_ms) │
         └───────────────────────┘
```

### Canonical Event Integrity

**Location:** `source/BGERP/Dag/CanonicalEventIntegrityValidator.php`

**Purpose:** Validate canonical event pipeline integrity.

**Validation Rules:**
1. **Sequence Check:** NODE_START before NODE_COMPLETE
2. **Completeness Check:** All sessions have START and COMPLETE
3. **Session Pairing:** PAUSE/RESUME pairs correctly
4. **Time Order:** Events in chronological order
5. **Duration Check:** Duration matches event times
6. **Legacy Sync:** Legacy fields match canonical events
7. **Type Whitelist:** Only allowed canonical types
8. **Event Type Mismatch:** event_type matches canonical_type
9. **Session Overlap:** No overlapping sessions

### Self-Healing System

**Three-Layer Repair:**

1. **LocalRepairEngine** (`source/BGERP/Dag/LocalRepairEngine.php`)
   - **Level:** L1 (Local token repair)
   - **Scope:** Single token
   - **Actions:** Fix missing events, correct timestamps
   - **Table:** `token_repair_log`

2. **TimelineReconstructionEngine** (`source/BGERP/Dag/TimelineReconstructionEngine.php`)
   - **Level:** L2/L3 (Timeline reconstruction)
   - **Scope:** Multiple tokens, graph instance
   - **Actions:** Reconstruct timeline from events
   - **Uses:** `TimeEventReader` for canonical timeline

3. **RepairOrchestrator** (`source/BGERP/Dag/RepairOrchestrator.php`)
   - **Level:** Orchestration
   - **Scope:** Full repair workflow
   - **Actions:** Coordinates LocalRepair + TimelineReconstruction

### Time Event Reader

**Location:** `source/BGERP/Dag/TimeEventReader.php`

**Purpose:** Read canonical timeline from `token_event` and sync to `flow_token`.

**Key Method:**
```php
TimeEventReader::syncTimeline($tokenId): void
```

**Actions:**
- Reads `token_event` for token
- Calculates `start_at`, `completed_at`, `actual_duration_ms`
- Updates `flow_token` fields
- Handles pause/resume correctly

**Integration:**
- Called by `TokenLifecycleService::completeToken()`
- Called by repair engines
- Called by ETA system

### Canonical Event Rules

**✅ DO:**
- Use `TokenEventService::persistEvent()` for all state changes
- Use canonical event types from whitelist
- Store payload in `event_data` JSON field
- Use `TimeEventReader` to sync timeline
- Validate events with `CanonicalEventIntegrityValidator`

**❌ DON'T:**
- Bypass canonical event system
- Manually update `flow_token` without events
- Create events with non-whitelist types
- Skip event persistence
- Modify `token_event` records directly

---

## 8. Job Ticket System (Unified Overview)

### Job Ticket Types

**Classic Job Tickets:**
- **Table:** `job_ticket`
- **Fields:**
  - `production_type = 'classic'`
  - `process_mode = 'batch'`
  - `routing_mode = 'linear'` (ONLY - DAG deprecated)
  - `graph_instance_id` - NULL (not used)
- **Work Tracking:** Minimal mode (job_ticket → output stats)
- **Progress:** From `production_output_daily` aggregation
- **UI:** Full lifecycle buttons (start, hold, resume, complete, cancel)

**Hatthasilpa Job Tickets:**
- **Table:** `job_ticket`
- **Fields:**
  - `production_type = 'hatthasilpa'`
  - `routing_mode = 'dag'` (required)
  - `graph_instance_id` - Required
- **Work Tracking:** `flow_token` (required)
- **Progress:** From `flow_token` aggregation
- **UI:** Overview/dashboard only, **no lifecycle buttons**
  - Status managed via Work Queue (`worker_token_api.php`)
  - Click "View" on Hatthasilpa job → Opens Job Ticket Offcanvas with `src=hatthasilpa`
  - Used as overview/link to Work Queue, not direct control interface

### Job Ticket Lifecycle

**Status Flow:**
```
┌──────────┐     ┌───────────────┐     ┌──────┐     ┌───────────┐
│ planned  │ ──→ │ in_progress   │ ──→ │  qc  │ ──→ │ completed │
└────┬─────┘     └──────┬────────┘     └──┬───┘     └───────────┘
     │                  │                  │
     │                  │                  │
     │                  │                  │
     │                  ▼                  │
     │            ┌──────────┐             │
     │            │ on_hold  │             │
     │            │ (any     │             │
     │            │  status) │             │
     │            └──────────┘             │
     │                                     │
     │                                     │
     └─────────────────────────────────────┘
                    │
                    ▼
            ┌──────────────┐
            │  cancelled   │
            │  (any status)│
            └──────────────┘
```

**Lifecycle Actions:**
- `start` - planned → in_progress
- `hold` - any → on_hold
- `resume` - on_hold → previous status
- `complete` - in_progress → completed
- `cancel` - any → cancelled

**Location:** `source/BGERP/Service/JobTicketStatusService.php`

### Job Ticket Progress

**Location:** `source/BGERP/JobTicket/JobTicketProgressService.php`

**Purpose:** Calculate job ticket progress.

**Methods:**
- `getProgress($ticketId)` - Get progress percentage
- `getCompletedQty($ticketId)` - Get completed quantity

**Logic:**
- **Classic Linear:** Sum from `production_output_daily` (minimal mode) or `task_operator_session` (extended mode)
- **Hatthasilpa:** Sum from `flow_token` (completed tokens)

### Job Ticket Event Log

**Location:** `source/job_ticket_progress_api.php`

**Purpose:** Track job ticket events.

**Events:**
- Status changes
- Progress updates
- Assignment changes
- QC results

**Table:** `job_ticket_status_history`

---

## 9. Component Serial / Traceability Wiring

### Component Serial System

**Purpose:** Track component serials (hardware, straps, etc.) and bind them to final product serials.

### Component Serial Flow

```
┌──────────────────────────────────────┐
│  Component Serial Pool               │
│  (component_serial_pool)             │
└────────────────────┬─────────────────┘
                     │
         ┌───────────▼───────────┐
         │  Component Serial     │
         │  Batch                │
         │  (component_serial_   │
         │   batch)              │
         └───────────┬───────────┘
                     │
         ┌───────────▼────────────┐
         │  Component Serial      │
         │  Generation            │
         │  (ComponentSerial      │
         │   Service::            │
         │   generateSerial)      │
         └───────────┬────────────┘
                     │
         ┌───────────▼───────────┐
         │  component_serial     │
         │  (serial_number,      │
         │   status='available') │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Component Serial     │
         │  Allocation           │
         │  (ComponentAllocation │
         │   Service::allocate)  │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  component_serial_    │
         │  allocation           │
         │  (allocated to        │
         │   job/token)          │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Component Serial     │
         │  Binding              │
         │  (ComponentBinding    │
         │   Service::bind)      │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  component_serial_    │
         │  binding              │
         │  (bound to            │
         │   final_piece_serial) │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Job Ticket Serial    │
         │  (job_ticket_serial)  │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Traceability         │
         │  (trace_api.php)      │
         └───────────────────────┘
```

### Component Serial Tables

- `component_serial_pool` - Serial pool
- `component_serial_batch` - Serial batches
- `component_serial` - Component serials
  - `serial_number` - Serial number
  - `status` - available, allocated, bound, used
- `component_serial_allocation` - Serial allocation
  - `id_token` - Token ID (if DAG)
  - `id_job_ticket` - Job ticket ID
- `component_serial_binding` - Serial binding
  - `component_serial` - Component serial
  - `final_piece_serial` - Final product serial
  - `id_component_token` - Component token ID
  - `id_final_token` - Final product token ID

### Component Serial Services

**Location:** `source/BGERP/Component/`

- `ComponentSerialService.php` - Serial generation
- `ComponentAllocationService.php` - Serial allocation
- `ComponentBindingService.php` - Serial binding
- `ComponentCompletenessService.php` - Completeness check

### Traceability System

**Location:** `source/trace_api.php`

**Purpose:** Trace product genealogy and component relationships.

**Endpoints:**
- `serial_view` - View serial details
- `serial_components` - Get components for serial
- `serial_trace` - Full trace path

**Tables:**
- `trace_access_log` - Access log
- `trace_export_job` - Export jobs
- `trace_note` - Trace notes
- `trace_reconcile_log` - Reconcile log
- `trace_share_link` - Share links

**Integration:**
- Queries `component_serial_binding` for component relationships
- Queries `job_ticket_serial` for job relationships
- Queries `serial_registry` (core DB) for serial metadata

---

## 10. People / Assignment / Operator Wiring

### Assignment System

**Purpose:** Assign operators to tokens/nodes based on rules.

### Assignment Flow

```
┌────────────────────────────────────────────────────────────┐
│  Assignment Plan Creation                                  │
│  (assignment_plan_api.php)                                 │
└────────────────────┬───────────────────────────────────────┘
                     │
         ┌───────────▼───────────┐
         │  assignment_plan_job  │
         │  (job-level plan)     │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  assignment_plan_node │
         │  (node-level plan)    │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Assignment Engine    │
         │  (AssignmentEngine::  │
         │   decide)             │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Assignment Decision  │
         │  Log                  │
         │  (assignment_decision_│
         │   log)                │
         └───────────┬───────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
┌────────▼──────────┐  ┌─────────▼──────────┐
│  Token Assignment │  │  Node Assignment   │
│  (token_assignment│  │  (node_assignment) │
└────────┬──────────┘  └─────────┬──────────┘
         │                       │
         └───────────┬───────────┘
                     │
         ┌───────────▼────────────┐
         │  Work Queue            │
         │  (worker_token_api.php)│
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  Operator Claims Token │
         │  (worker_token_api.php │
         │   → claim action)      │
         └───────────┬────────────┘
                     │
         ┌───────────▼───────────┐
         │  Token Work Session   │
         │  (token_work_session) │
         └───────────────────────┘
```

### Assignment Tables

- `assignment_plan_job` - Job assignment plans
- `assignment_plan_node` - Node assignment plans
- `assignment_log` - Assignment log
- `assignment_decision_log` - Decision log
  - `assignment_type` - manual, auto_plan, auto_team
  - `assigned_to_user_id` - Assigned operator
  - `assigned_to_team_id` - Assigned team
  - `decision_reason` - Why this operator?
- `assignment_notification` - Notifications
- `token_assignment` - Token assignments
- `node_assignment` - Node assignments

### People Integration

**Purpose:** Sync operator data from external People system.

**Tables:**
- `people_operator_cache` - Operator cache
- `people_availability_cache` - Availability cache
- `people_team_cache` - Team cache
- `people_sync_error_log` - Sync errors
- `people_masking_policy` - Masking policy
- `operator_availability` - Availability data

**Location:** `source/BGERP/Service/PeopleSyncService.php`

### Work Center System

**Purpose:** Define work centers and their behaviors.

**Tables:**
- `work_center` - Work centers
- `work_center_behavior` - Work center behaviors
  - `node_mode` - BATCH_QUANTITY, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE
- `work_center_behavior_map` - Behavior mapping
- `work_center_team_map` - Team mapping

**Location:** `source/BGERP/Dag/WorkCenterBehaviorRepository.php`

### Work Center Behavior Mode Mapping

**Purpose:** Node behavior modes determine how work is executed at each work center.

**Mode Mapping Table:**

| `node_mode` | Meaning | Used By | Description |
|-------------|---------|---------|-------------|
| `HAT_SINGLE` | 1 token / operator | Hatthasilpa | Single-piece work, operator processes one token at a time |
| `BATCH_QUANTITY` | Batch work | Classic | Batch processing, multiple pieces processed together |
| `CLASSIC_SCAN` | Scan-based terminal | Classic (PWA) | Scan in/out workflow, no token tracking |
| `QC_SINGLE` | QC nodes | Hatthasilpa | Quality control nodes, single-piece inspection |

**Usage Rules:**
- **Hatthasilpa nodes:** Use `HAT_SINGLE` or `QC_SINGLE`
- **Classic nodes:** Use `BATCH_QUANTITY` or `CLASSIC_SCAN`
- **Node Behavior Engine** (Task 28+) will use these modes to determine execution profiles
- **Work Queue** respects `node_mode` when displaying tokens to operators
- **PWA scanners** only work with `CLASSIC_SCAN` mode nodes

**⚠️ Critical:**
- Do NOT mix modes across production lines
- Hatthasilpa = `HAT_SINGLE` / `QC_SINGLE` only
- Classic = `BATCH_QUANTITY` / `CLASSIC_SCAN` only

### Assignment Rules

**✅ DO:**
- Use assignment system for **Hatthasilpa DAG only**
- Use `AssignmentEngine` for auto-assignment
- Use `assignment_decision_log` for audit trail
- Use `people_operator_cache` for operator data
- Use Work Queue (`worker_token_api.php`) for Hatthasilpa token operations

**❌ DON'T:**
- Use assignment system for Classic (not supported)
- Use Work Queue for Classic tickets (Hatthasilpa only)
- Bypass assignment engine
- Manually update assignment tables

**⚠️ Critical Separation:**
- **Work Queue = Hatthasilpa only** - Operators claim tokens via `worker_token_api.php`
- **PWA Scanners = Classic only** - Simple scan in/out for job tickets
- These are **separate systems** for **separate production lines**

---

## 11. PWA Wiring

### PWA Scan API

**Location:** `source/pwa_scan_api.php`

**Purpose:** Scan-based workflow for production tracking.

### PWA Scan Flow

**⚠️ Critical:** PWA scanners are **Classic Line only**. Hatthasilpa uses Work Queue, not PWA.

```
┌────────────────────────────────────────────────────────────┐
│  Scan QR Code (PWA)                                        │
│  ⚠️ Classic Line ONLY                                      │
└────────────────────┬───────────────────────────────────────┘
                     │
         ┌───────────▼───────────┐
         │  Lookup               │
         │  (pwa_scan_api.php →  │
         │   lookup action)      │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │  Identify Type        │
         │  (job_ticket,         │
         │   material, component,│
         │   etc.)               │
         └───────────┬───────────┘
                     │
         ┌───────────┴───────────┐───────────────────────┐
         │                       │                       │
┌────────▼─────────┐   ┌─────────▼──────────┐  ┌─────────▼──────────┐
│  Job Ticket      │   │  Material          │  │  Component         │
│  → Get job       │   │  → Get material    │  │  → Get component   │
│    details       │   │    details         │  │    details         │
└────────┬─────────┘   └─────────┬──────────┘  └─────────┬──────────┘
         │                       │                       │
         └───────────┬───────────┴───────────────────────┘
                     │
         ┌───────────▼───────────┐
         │  Scan Event           │
         │  (pwa_scan_api.php →  │
         │   scan action)        │
         └───────────┬───────────┘
                     │
         ┌───────────▼──────────┐
         │  Classic Linear ONLY │
         │  → wip_log           │
         │  (event_type=        │
         │   'start' or         │
         │   'complete')        │
         └──────────────────────┘
```

**⚠️ Deprecation Note:**
- Classic DAG mode via PWA was deprecated (Task 25.3-25.5)
- Hatthasilpa does NOT use PWA scanners (uses Work Queue instead)
- PWA is now **Classic Linear only**

### PWA Work Session Rules

**Classic Linear (Current):**
- Uses `wip_log` for scan events
- No work session required
- Progress from `task_operator_session` (optional)
- Simple scan in/out workflow

**⚠️ Deprecated:**
- Classic DAG mode via PWA (removed after Task 25.3)
- Hatthasilpa does NOT use PWA (uses Work Queue)

### PWA Limitations

**Classic Linear (Current):**
- ✅ Scan in/out events
- ✅ Progress tracking
- ✅ Simple job ticket completion
- ❌ No DAG token operations (not supported)
- ❌ No assignment system (Hatthasilpa only)
- ❌ Not a work queue interface (scanner/terminal only)

**⚠️ Separation:**
- **PWA = Classic only** - Simple scanner for job tickets
- **Work Queue = Hatthasilpa only** - Full token management interface
- These are **completely separate systems** for different production lines

---

## 12. Analytics Wiring

### Production Output Daily

**Location:** `source/BGERP/Service/ClassicProductionStatsService.php`

**Purpose:** Aggregate daily production statistics for Classic line.

**Flow:**
```
┌───────────────────────────────────────────────────────────┐
│  Classic Ticket Completion                                │
│  (JobTicketStatusService)                                 │
└────────────────────┬──────────────────────────────────────┘
                     │
         ┌───────────▼────────────┐
         │  ClassicProduction     │
         │  StatsService::        │
         │  recordCompletion()    │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │  production_output_    │
         │  daily                 │
         │  (daily aggregation)   │
         │                        │
         │  Fields:               │
         │  - product_id          │
         │  - output_date         │
         │  - completed_qty       │
         │  - lead_time_minutes   │
         └────────────────────────┘
```

**Table:** `production_output_daily`
- `id_product` - Product ID
- `output_date` - Date
- `completed_qty` - Completed quantity
- `lead_time_minutes` - Lead time

### Analytics Views

**Materialized Views:**
- `mv_cycle_time_analytics` - Cycle time analytics
- `mv_dashboard_trends` - Dashboard trends
- `mv_node_bottlenecks` - Node bottlenecks
- `mv_team_workload` - Team workload
- `mv_token_flow_summary` - Token flow summary

**Purpose:** Pre-aggregated analytics for dashboards.

**Refresh:** Manual or scheduled (not auto-refresh)

### Analytics Integration

**APIs:**
- `source/dashboard_api.php` - Dashboard data
- `source/product_stats_api.php` - Product statistics
- `source/classic_api.php` - Classic statistics

**Services:**
- `ClassicProductionStatsService` - Classic stats
- `ProductMetadataResolver` - Product metadata

---

## 13. Security Layer

### Permission System

**Location:** `source/BGERP/Security/PermissionHelper.php`

**Purpose:** Hybrid permission model (Tenant-first, Core fallback).

**Flow:**
```
┌─────────────────────────────────────────────────────────────┐
│  Permission Check Request                                   │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────▼───────────┐
         │  Check Platform Role  │
         │  (is_platform_        │
         │   administrator)      │
         └───────────┬───────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
┌────────▼──────────┐  ┌─────────▼──────────┐
│  TRUE             │  │  FALSE             │
│  → Grant ALL      │  │  → Continue        │
│     access        │  └─────────┬──────────┘
└───────────────────┘            │
                     ┌───────────▼───────────┐
                     │  Check Tenant Role    │
                     │  (tenant_permission_  │
                     │   allow_code)         │
                     └───────────┬───────────┘
                                 │
                     ┌───────────┴────────────┐───────────────────────┐
                     │                        │                       │
         ┌───────────▼───────────┐  ┌─────────▼──────────┐  ┌─────────▼─────────┐
         │  TRUE                 │  │  FALSE             │  │  NULL             │
         │  → Grant access       │  │  → Deny access     │  │  → Fallback       │
         └───────────────────────┘  └────────────────────┘  └────────┬──────────┘
                                                                     │
                                                         ┌───────────▼───────────┐
                                                         │  Fallback: Core       │
                                                         │  Permission           │
                                                         │  (permission_allow)   │
                                                         └───────────┬───────────┘
                                                                     │
                                                         ┌───────────┴───────────┐
                                                         │                       │
                                               ┌─────────▼──────────┐  ┌─────────▼──────────┐
                                               │  TRUE              │  │  FALSE             │
                                               │  → Grant access    │  │  → Deny access     │
                                               └────────────────────┘  └────────────────────┘
```

**Tables:**
- Core DB: `platform_role`, `platform_permission`, `platform_user`
- Tenant DB: `tenant_role`, `tenant_role_permission`, `tenant_user_role`
- Core DB: `permission` (legacy fallback)

### Feature Flags

**Location:** `source/BGERP/Service/FeatureFlagService.php`

**Purpose:** Feature flag system for gradual rollout.

**Tables:**
- Core DB: `feature_flag` - Feature flag catalog
- Tenant DB: `tenant_feature_flags` - Tenant-specific flags

**Usage:**
```php
FeatureFlagService::getFlagValue($flagName, $defaultValue)
```

### Bootstrap Authentication

**TenantApiBootstrap:**
- Auto tenant resolution
- Session authentication
- Tenant DB connection

**CoreApiBootstrap:**
- Platform authentication
- Multiple modes: `platform_admin`, `auth_required`, `public`, `cli`
- Optional tenant context

---

## 14. API Layer Architecture

### Bootstrap Layers

**TenantApiBootstrap** (`source/BGERP/Bootstrap/TenantApiBootstrap.php`)

**Usage:**
```php
[$org, $db] = TenantApiBootstrap::init();
```

**Returns:**
- `$org` - Organization array
- `$db` - DatabaseHelper instance

**Features:**
- Auto tenant resolution
- Tenant DB connection
- Timezone setup
- Error handling

**CoreApiBootstrap** (`source/BGERP/Bootstrap/CoreApiBootstrap.php`)

**Usage:**
```php
[$member, $coreDb, $tenantDb, $org, $cid] = CoreApiBootstrap::init([
    'requireAuth' => true,
    'requirePlatformAdmin' => false,
    'requiredPermissions' => [],
    'requireTenant' => false,
    'jsonResponse' => true,
    'cliMode' => false,
]);
```

**Returns:** (varies by mode)
- `$member` - Member array
- `$coreDb` - Core database connection
- `$tenantDb` - Tenant database connection (if required)
- `$org` - Organization array (if required)
- `$cid` - Correlation ID

### API Context Loading

**Standard Flow:**
```
1. Session Start
2. Authentication Check
3. Maintenance Mode Check
4. Correlation ID Setup
5. Rate Limiting
6. Bootstrap Initialization
7. Request Validation
8. Idempotency Check (if create operation)
9. Business Logic
10. Response
```

### Error Handling Rules

**✅ DO:**
- Use `json_error()` for errors
- Use `json_success()` for success
- Include `app_code` in errors
- Log all exceptions
- Use top-level try-catch

**❌ DON'T:**
- Use `echo json_encode()` directly
- Return `{success: true}` (use `{ok: true}`)
- Silent catch (always log)
- Expose sensitive data in errors

### i18n Requirements

**Backend:**
```php
translate('key', 'Default English Text')
```

**Frontend:**
```javascript
t('key', 'Default English Text')
```

**Rule:** All UI text must have English default.

---

## 15. Rules for Future Development

### Naming Conventions

**Files:**
- API files: `*_api.php` (snake_case)
- Service classes: `*Service.php` (PascalCase)
- Helper classes: `*Helper.php` (PascalCase)
- Exception classes: `*Exception.php` (PascalCase)

**Database:**
- Tables: `snake_case`
- Columns: `snake_case`
- Indexes: `idx_column_name` or `idx_composite_name`

**Code:**
- PHP functions: `snake_case()`
- PHP classes: `PascalCase`
- JavaScript functions: `camelCase()`

### Never Bypass Canonical Event System

**❌ FORBIDDEN:**
```php
// Direct update - FORBIDDEN
$db->query("UPDATE flow_token SET status='completed' WHERE id_token=?");

// Bypass event system - FORBIDDEN
$db->query("UPDATE node_instance SET status='completed' WHERE id_instance=?");
```

**✅ REQUIRED:**
```php
// Use canonical events
$tokenEventService = new TokenEventService($db);
$tokenEventService->persistEvent($tokenId, $nodeId, 'NODE_COMPLETE', $payload);

// Use services
$tokenLifecycleService = new TokenLifecycleService($db);
$tokenLifecycleService->completeToken($tokenId);
```

### Never Touch Token Tables Manually

**❌ FORBIDDEN:**
- Direct UPDATE to `flow_token`
- Direct UPDATE to `token_event`
- Direct UPDATE to `node_instance`
- Direct UPDATE to `token_work_session`

**✅ REQUIRED:**
- Use `TokenLifecycleService` for token operations
- Use `TokenEventService` for canonical events
- Use `DagExecutionService` for token movement
- Use `BehaviorExecutionService` for node behavior

### When to Create New Service vs Extend Service

**Create New Service When:**
- New domain (e.g., `ComponentSerialService` for component domain)
- New responsibility (e.g., `MOEtaService` for ETA domain)
- Independent functionality

**Extend Service When:**
- Related functionality (e.g., add method to `TokenLifecycleService`)
- Same domain (e.g., add method to `DagExecutionService`)
- Shared responsibility

### When to Use Helper vs Service

**Use Helper When:**
- Stateless utility functions
- No business logic
- Reusable across modules
- Examples: `TimeHelper`, `DatabaseHelper`, `JsonNormalizer`

**Use Service When:**
- Business logic
- State management
- Database transactions
- Examples: `TokenLifecycleService`, `JobCreationService`, `AssignmentEngine`

### When Classic May NOT Use DAG Tables

**Classic Linear Mode (Current):**
- ❌ May NOT use `flow_token` (deprecated)
- ❌ May NOT use `token_event` (deprecated)
- ❌ May NOT use `node_instance` (deprecated)
- ❌ May NOT use `token_work_session` (deprecated)
- ❌ May NOT use `job_graph_instance` (deprecated)
- ✅ MUST use `wip_log` (for extended mode, optional)
- ✅ MAY use `task_operator_session` (for extended mode, optional)
- ✅ MUST use `production_output_daily` (for minimal mode, active)

**⚠️ Deprecation Note:**
- Classic DAG mode was deprecated after Task 25.3-25.5
- Classic now uses Linear mode exclusively
- All DAG tables are Hatthasilpa only

### When Hatthasilpa Must Use Graph Binding

**Hatthasilpa Job Creation:**
- ✅ MUST have `product_graph_binding`
- ✅ MUST have `routing_graph`
- ✅ MUST create `job_graph_instance`
- ✅ MUST spawn tokens

**Hatthasilpa Rules:**
- No job creation without graph binding
- No job creation without routing graph
- Graph must have START and END nodes
- Graph must be valid (DAGValidationService)

### All New Code MUST Follow Enterprise Standards

**Required Features:**
- ✅ Rate limiting (`RateLimiter::check()`)
- ✅ Request validation (`RequestValidator::make()`)
- ✅ Idempotency (for create operations)
- ✅ ETag/If-Match (for update operations)
- ✅ Maintenance mode check
- ✅ Execution time tracking
- ✅ Correlation ID
- ✅ AI Trace headers
- ✅ Standardized logging
- ✅ Error handling (not silent)

**Template:** `source/api_template.php`

---

## 16. DO NOT TOUCH Zones

### DAG Core Tables

**❌ NEVER modify directly:**
- `flow_token` - Use `TokenLifecycleService`
- `token_event` - Use `TokenEventService`
- `node_instance` - Use `DagExecutionService`
- `token_work_session` - Use `BehaviorExecutionService`
- `routing_graph` - Use `DagRoutingService`
- `routing_node` - Use `DagRoutingService`
- `routing_edge` - Use `DagRoutingService`
- `job_graph_instance` - Use `GraphInstanceService`

**Reason:** These tables are managed by services that enforce business rules and canonical events.

### Canonical Event Tables

**❌ NEVER modify directly:**
- `token_event` - Immutable event log
- `token_repair_log` - Repair audit trail

**Reason:** These are audit trails. Modifying them breaks integrity.

### MO ETA Logic

**❌ NEVER modify directly:**
- `MOLoadEtaService` - ETA calculation engine
- `MOEtaCacheService` - Cache logic
- `MOEtaHealthService` - Health validation
- `mo_eta_cache` - Cache table
- `mo_eta_health_log` - Health log table

**Reason:** ETA system is complex and tightly integrated. Changes break MO planning.

### Platform-Level Tables

**❌ NEVER modify directly:**
- Core DB: `account`, `organization`, `account_org`
- Core DB: `platform_role`, `platform_permission`, `platform_user`
- Core DB: `permission`, `group_permission`
- Core DB: `schema_migrations`

**Reason:** These are platform-level tables shared across all tenants. Modifying them affects all tenants.

### Serial Generation System

**❌ NEVER modify directly:**
- `serial_generation_log` - Generation audit trail
- `serial_quarantine` - Quarantine system
- `serial_link_outbox` - Link outbox
- Serial generation logic in `ComponentSerialService`

**Reason:** Serial generation must be unique and traceable. Modifying breaks traceability.

### Security Models

**❌ NEVER modify directly:**
- `PermissionHelper` - Permission checking logic
- `TenantApiBootstrap` - Authentication flow
- `CoreApiBootstrap` - Platform authentication
- `tenant_role`, `tenant_role_permission` - Role system

**Reason:** Security is critical. Bypassing or modifying breaks access control.

### Repair Engines

**❌ NEVER modify directly:**
- `LocalRepairEngine` - L1 repair logic
- `TimelineReconstructionEngine` - L2/L3 repair logic
- `RepairOrchestrator` - Repair coordination
- `token_repair_log` - Repair audit trail

**Reason:** Repair engines are self-healing mechanisms. Modifying breaks integrity.

---

## 17. Appendix: Database Table Map

### Core Database (`bgerp`) - 13 Tables

#### Account System (3 tables)
- `account` - User accounts (platform-level)
- `account_group` - Legacy role groups
- `account_org` - User↔Organization mapping

#### Organization System (1 table)
- `organization` - Tenant registry

#### Permission System (2 tables)
- `permission` - Master permission list
- `group_permission` - Legacy group permissions

#### Platform Administration (3 tables)
- `platform_user` - Platform administrators
- `platform_role` - Platform roles
- `platform_permission` - Platform permissions

#### Tenant Management (2 tables)
- `tenant_role_template` - Role templates
- `tenant_role_template_permission` - Template permissions

#### System (2 tables)
- `account_invite` - Invitation system
- `organization_domain` - Subdomain support
- `system_logs` - System logging
- `admin_notifications` - Admin notifications
- `schema_migrations` - Migration tracking

---

### Tenant Database (`bgerp_t_{org_code}`) - 122 Tables

#### Core Master Data (11 tables)
- `account` - Tenant user accounts
- `organization` - Organization data
- `permission` - Synced permissions
- `tenant_role` - Organization roles
- `tenant_role_permission` - Role assignments
- `tenant_user_role` - User role assignments
- `product_category` - Product categories
- `unit_of_measure` - Units of measure (legacy)
- `uom` - Units of measure (new)
- `warehouse` - Warehouses
- `warehouse_location` - Warehouse locations

#### Product & BOM (9 tables)
- `product` - Products (`production_line`: classic|hatthasilpa)
- `bom` - Bill of Materials
- `bom_item` - BOM items
- `bom_line` - BOM lines
- `product_asset` - Product assets
- `product_graph_binding` - Product↔Graph binding (Hatthasilpa)
- `product_graph_binding_audit` - Binding audit
- `pattern` - Patterns
- `pattern_version` - Pattern versions

#### Material & Inventory (12 tables)
- `material` - Materials
- `material_lot` - Material lots
- `material_lot_movement` - Lot movements
- `material_asset` - Material assets
- `stock_item` - Stock items
- `stock_item_asset` - Stock item assets
- `stock_item_lot` - Stock item lots
- `stock_ledger` - Stock ledger
- `warehouse_inventory` - Warehouse inventory
- `inventory_transaction` - Inventory transactions
- `inventory_transaction_item` - Transaction items
- `leather_sheet` - Leather sheets

#### Component System (9 tables)
- `component_type` - Component types
- `component_master` - Component master data
- `component_bom_map` - Component↔BOM mapping
- `component_serial_batch` - Serial batches
- `component_serial` - Component serials
- `component_serial_allocation` - Serial allocation
- `component_serial_binding` - Serial binding
- `component_serial_pool` - Serial pool
- `component_serial_usage_log` - Usage log

#### Manufacturing Orders (3 tables)
- `mo` - Manufacturing orders (Classic only)
- `mo_eta_cache` - ETA cache (Task 23)
- `mo_eta_health_log` - ETA health log (Task 23)

#### Job Tickets & Tasks (5 tables)
- `job_ticket` - Job tickets (DAG + Linear)
- `job_task` - Job tasks (Linear)
- `job_ticket_serial` - Ticket serials
- `job_ticket_status_history` - Status history
- `wip_log` - WIP logs (Linear, soft-delete: `deleted_at IS NULL`)

#### DAG Routing System (15 tables)
- `routing_graph` - DAG graphs
- `routing_graph_draft` - Graph drafts
- `routing_graph_version` - Graph versions
- `routing_graph_favorite` - Favorites
- `routing_graph_var` - Graph variables
- `routing_graph_feature_flag` - Feature flags
- `routing_node` - DAG nodes
- `routing_edge` - DAG edges
- `routing` - Legacy routing
- `routing_step` - Legacy routing steps
- `routing_set` - Routing sets
- `routing_audit_log` - Routing audit
- `routing_v1_usage_log` - V1 usage log
- `graph_subgraph_binding` - Subgraph binding
- `job_graph_instance` - Graph instances

#### Token System (10 tables)
- `flow_token` - DAG tokens (DO NOT TOUCH directly)
- `token_event` - Canonical events (DO NOT TOUCH directly)
- `token_work_session` - Work sessions
- `token_assignment` - Token assignments
- `token_spawn_log` - Spawn log
- `token_join_buffer` - Join buffer
- `node_instance` - Node instances (DO NOT TOUCH directly)
- `node_assignment` - Node assignments
- `task_operator_session` - Operator sessions (Linear)
- `dag_behavior_log` - Behavior log
- `token_repair_log` - Repair log (Task 21)

#### Work Centers & Teams (8 tables)
- `work_center` - Work centers
- `work_center_behavior` - Work center behaviors (`node_mode`: BATCH_QUANTITY, HAT_SINGLE, CLASSIC_SCAN, QC_SINGLE)
- `work_center_behavior_map` - Behavior mapping
- `work_center_team_map` - Team mapping
- `team` - Teams
- `team_member` - Team members
- `team_member_history` - Member history
- `team_availability` - Team availability

#### Quality Control (5 tables)
- `qc_inspection` - QC inspections
- `qc_inspection_item` - Inspection items
- `qc_fail_event` - QC fail events
- `qc_rework_task` - Rework tasks
- `qc_rework_log` - Rework log

#### Assignment System (5 tables)
- `assignment_plan_job` - Assignment plans (jobs)
- `assignment_plan_node` - Assignment plans (nodes)
- `assignment_log` - Assignment log
- `assignment_decision_log` - Decision log
- `assignment_notification` - Notifications

#### People Integration (6 tables)
- `people_availability_cache` - Availability cache
- `people_operator_cache` - Operator cache
- `people_team_cache` - Team cache
- `people_sync_error_log` - Sync errors
- `people_masking_policy` - Masking policy
- `operator_availability` - Operator availability

#### Production & Analytics (8 tables)
- `production_output_daily` - Daily output (Task 25, Classic stats)
- `production_schedule_config` - Schedule config
- `schedule_change_log` - Schedule changes
- `cut_batch` - Cut batches
- `leave_request` / `member_leave` - Leave management
- `mv_cycle_time_analytics` - Cycle time analytics (materialized view)
- `mv_dashboard_trends` - Dashboard trends (materialized view)
- `mv_node_bottlenecks` - Node bottlenecks (materialized view)
- `mv_team_workload` - Team workload (materialized view)
- `mv_token_flow_summary` - Token flow summary (materialized view)

#### Serial Number System (5 tables)
- `serial_generation_log` - Generation log (DO NOT TOUCH)
- `serial_link_outbox` - Link outbox
- `serial_quarantine` - Quarantine (DO NOT TOUCH)
- (Serial system integrated with component system)

#### Traceability (5 tables)
- `trace_access_log` - Access log
- `trace_export_job` - Export jobs
- `trace_note` - Trace notes
- `trace_reconcile_log` - Reconcile log
- `trace_share_link` - Share links

#### Leather & BOM (2 tables)
- `leather_cut_bom_log` - Leather cut BOM log
- `leather_sheet_usage_log` - Sheet usage log

#### Purchase & Supplier (3 tables)
- `purchase_rfq` - Purchase RFQ
- `purchase_rfq_item` - RFQ items
- `supplier_score` - Supplier scores

#### Machine System (1 table)
- `machine` - Machines (Task 18)

#### System & Configuration (8 tables)
- `feature_flag` - Feature flags
- `tenant_feature_flags` - Tenant feature flags
- `tenant_schema_migrations` - Migration tracking
- `tenant_migrations` - Migration log
- `legacy_cleanup_tracking` - Cleanup tracking
- `routing_v1_usage_log` - Routing V1 usage

---

### Critical Table Notes

#### Soft-Delete Tables
**Always filter with `deleted_at IS NULL`:**
- `wip_log` - WIP logs (Linear system)

#### Immutable Tables (Audit Trails)
**Never UPDATE or DELETE:**
- `token_event` - Canonical events (immutable)
- `token_repair_log` - Repair audit trail
- `serial_generation_log` - Serial generation audit
- `trace_access_log` - Trace access audit
- `assignment_decision_log` - Assignment decision audit

#### Production Line Tables
**Classic Line:**
- `job_ticket` (`production_type='classic'`)
- `job_task` (Linear mode)
- `wip_log` (Linear mode)
- `mo` (Classic only)

**Hatthasilpa Line:**
- `job_ticket` (`production_type='hatthasilpa'`)
- `job_graph_instance` (required)
- `flow_token` (required)
- `token_event` (required)
- `product_graph_binding` (required)

#### DAG Core Tables (DO NOT TOUCH)
**Use services only:**
- `flow_token` → `TokenLifecycleService`
- `token_event` → `TokenEventService`
- `node_instance` → `DagExecutionService`
- `token_work_session` → `BehaviorExecutionService`
- `routing_graph` → `DagRoutingService`
- `routing_node` → `DagRoutingService`
- `routing_edge` → `DagRoutingService`
- `job_graph_instance` → `GraphInstanceService`

---

## 📚 Additional Resources

### Documentation References
- `docs/developer/03-superdag/` - SuperDAG architecture
- `docs/developer/04-api/` - API reference
- `docs/developer/05-database/` - Database schema
- `docs/developer/06-architecture/` - System architecture
- `docs/developer/08-guides/` - Development guides

### Code References
- `source/BGERP/Service/` - Service layer
- `source/BGERP/Dag/` - DAG engines
- `source/BGERP/Helper/` - Helper utilities
- `source/BGERP/Bootstrap/` - Bootstrap layers
- `source/*_api.php` - API endpoints

### Migration Files
- `database/migrations/0001_core_bootstrap_v2.php` - Core schema
- `database/tenant_migrations/0001_init_tenant_schema_v2.php` - Tenant schema

---

**Document End** ✅

**Last Updated:** January 2025  
**Version:** 1.0  
**Status:** Complete - All subsystems documented
# 🧭 Serial Number System - Production Context Awareness

**Created:** November 9, 2025  
**Purpose:** Define behavioral differences between Hatthasilpa and OEM production models  
**Audience:** AI Agents implementing serial number logic  
**Status:** ✅ **Critical Context - Read Before Implementation**

---

## 🎯 Purpose

This document defines how the Serial Number System must behave differently between **Hatthasilpa (Atelier-based craftsmanship)** and **OEM (Batch-based manufacturing)** to ensure:

- ✅ Logical consistency across both pipelines
- ✅ Correct data linkage and traceability
- ✅ Integrity of serial-to-source relationships
- ✅ Appropriate security isolation (separate salts)

---

## ⚙️ Production Model Overview

### **1. Hatthasilpa (Artisan / Atelier Production)**

**Philosophy:**
> One piece = one story = one serial.

Every object is handcrafted under a chain of artisans, each represented in the trace data.

**Technical Behavior:**

| Key | Description |
|-----|-------------|
| `production_type` | `'hatthasilpa'` |
| **Serial granularity** | **1 serial per physical piece** |
| **Data source** | `atelier_job` + `dag_token` + `work_session` |
| **Routing model** | **DAG (Directed Acyclic Graph)** — each node = specific process (cutting, stitching, finishing) |
| **Assignment logic** | Manual or semi-auto by Manager (based on skill/team) |
| **Traceable entities** | `people_profile`, `skill_category`, `team_assignment`, `session_time` |
| **Visibility** | **Public-Facing trace allowed** (customer can view the artisan profile) |
| **Security salt** | Use `SERIAL_SECRET_SALT_HAT` |
| **Serial code prefix** | `HAT` (from `getProductionTypeCode('hatthasilpa')`) |
| **Registry linkage** | `serial_registry` → `dag_token` → `people_profile` |
| **Lifecycle status** | `created` → `in_progress` → `qc_verified` → `delivered` |

**Example Flow:**
```
atelier_job #15 (Leather Bag)
  → DAG Node 1: Cutting (assigned to Somchai)
  → DAG Node 2: Edge Painting (assigned to Mali)
  → DAG Node 3: Stitching (assigned to Natee)
  → Final Assembly → QC → Pack → Serial Issued
```

---

### **2. OEM (Industrial / Batch Production)**

**Philosophy:**
> Focus on efficiency and batch-level traceability for mass production.

Serials track lots, not individual pieces.

**Technical Behavior:**

| Key | Description |
|-----|-------------|
| `production_type` | `'oem'` |
| **Serial granularity** | **1 serial per batch or MO (Manufacturing Order)** |
| **Data source** | `mo_header` + `job_ticket` |
| **Routing model** | **Job Ticket (Linear flow)** — one job per production batch |
| **Assignment logic** | Automatic via `manager_assignment` or auto-assign |
| **Traceable entities** | `machine_id`, `operator_team`, `mo_id`, `batch_code` |
| **Visibility** | **Internal Only** (not shown to customers) |
| **Security salt** | Use `SERIAL_SECRET_SALT_OEM` |
| **Serial code prefix** | `OEM` |
| **Registry linkage** | `serial_registry` → `job_ticket` → `mo_header` |
| **Lifecycle status** | `created` → `in_progress` → `completed` → `shipped` |

**Example Flow:**
```
MO #2025-0412-A (Key Fob Case Batch 500 pcs)
  → Job Ticket: Cutting (Team A)
  → Job Ticket: Stitching (Team B)
  → Job Ticket: QC
  → Batch Completed
  → Serial issued for the batch as OEM serial
```

---

## 🧩 Serial Behavior Difference Summary

| Feature | Hatthasilpa | OEM |
|---------|------------|-----|
| **Serial level** | Per-piece | Per-batch |
| **System dependency** | DAG + Token + Work Queue | MO + Job Ticket |
| **Assignment style** | Manual (team/operator) | Auto (rule-based) |
| **Traceable data** | Artisan, skill, session | Batch, operator team |
| **Visibility** | Public (trace link shown to customer) | Internal (manager dashboard only) |
| **Secret salt** | `SERIAL_SECRET_SALT_HAT` | `SERIAL_SECRET_SALT_OEM` |
| **Example** | `MA01-HAT-BAG-20251109-00027-A9K2-X` | `MA01-OEM-KFOB-20251109-00001-F73J-D` |

---

## 🔐 Serial Service Logic Extension

### **Modified UnifiedSerialService::generateSerial()**

```php
// Step 0: Determine production context
$isHatthasilpa = ($productionType === 'hatthasilpa');

// Step 1: Choose appropriate salt
$secretSalt = getenv(
    $isHatthasilpa ? 'SERIAL_SECRET_SALT_HAT' : 'SERIAL_SECRET_SALT_OEM'
);

if (!$secretSalt) {
    throw new RuntimeException(
        'Missing SERIAL_SECRET_SALT for production type: ' . $productionType
    );
}

// Step 2: Determine serial scope
$serialScope = $isHatthasilpa ? 'piece' : 'batch';

// Step 3: Sequence scope changes
// - Hatthasilpa: (tenant + sku + ymd + artisan_id optional)
// - OEM: (tenant + sku + ymd) only
```

---

## 🔄 System Integration Map

```
                    UnifiedSerialService
                            |
            ┌───────────────┴───────────────┐
            |                               |
    HATTHASILPA (Atelier)          OEM (Industrial)
            |                               |
    ┌───────┴────────┐              ┌──────┴────────┐
    |                |              |                |
Source: dag_token   Source: job_ticket
Scope: per-piece    Scope: per-batch
Salt: SERIAL_       Salt: SERIAL_
      SECRET_SALT_       SECRET_SALT_
      HAT                OEM
Trace: people_profile   Trace: mo_header
Visibility: public     Visibility: internal
```

---

## 🧪 Validation Rules

### **1. Serial must respect production type scope**

- ✅ `hatthasilpa` → one serial per product piece
- ✅ `oem` → one serial per batch

### **2. Cross-reference integrity**

- ✅ For `hatthasilpa`, every serial must be linked to a valid `dag_token.id_token`
- ✅ For `oem`, every serial must be linked to `mo_id` or `job_ticket_id`

### **3. Security enforcement**

- ✅ Use different salts to avoid pattern collision or cross-verification
- ✅ HAT serials cannot be verified with OEM salt (and vice versa)

### **4. API / Registry extensions**

- ✅ Add field `serial_scope ENUM('piece','batch')`
- ✅ Add field `linked_source ENUM('dag_token','job_ticket')`

---

## 🧾 Database Extension Plan

```sql
-- Core DB (bgerp)
ALTER TABLE serial_registry 
  ADD COLUMN serial_scope ENUM('piece','batch') DEFAULT 'piece' 
    COMMENT 'Serial granularity level',
  ADD COLUMN linked_source ENUM('dag_token','job_ticket') DEFAULT 'job_ticket' 
    COMMENT 'Source system for traceability';

-- Add indexes for queries
ALTER TABLE serial_registry 
  ADD INDEX idx_scope (serial_scope),
  ADD INDEX idx_linked_source (linked_source);
```

---

## ✅ Test Scenarios to Verify Agent Logic

| Scenario | Expected Behavior |
|----------|-------------------|
| **Generate serial for hatthasilpa job** | Creates 1 serial per token (piece-level) |
| **Generate serial for oem MO** | Creates 1 serial per batch |
| **Verify trace link for HAT** | Returns artisan names + DAG node path |
| **Verify trace link for OEM** | Returns MO ID + job_ticket summary |
| **Cross-verify salt usage** | HAT/OEM serials cannot validate each other |
| **Batch/day reset** | Sequence restarts daily per production_type |

---

## 🧩 Summary for Agent Implementation

**Always treat Hatthasilpa and OEM as two different manufacturing philosophies, not just two enum strings.**

### **Hatthasilpa:**
- ✅ Trace craftsmanship
- ✅ Public verification
- ✅ Piece-level serial
- ✅ DAG-based workflow
- ✅ Artisan-centric traceability

### **OEM:**
- ✅ Trace operational flow
- ✅ Internal verification
- ✅ Batch-level serial
- ✅ Job Ticket-based workflow
- ✅ Batch-centric traceability

---

## 🔗 Related Documents

- `docs/SERIAL_NUMBER_IMPLEMENTATION_GUIDE.md` - Complete implementation guide
- `docs/SERIAL_NUMBER_DESIGN_PROPOSAL_v1.0_APPROVED.md` - Baseline design
- `docs/SERIAL_NUMBER_HARDENING_PATCHES.md` - Security patches

---

**Last Updated:** November 9, 2025  
**Status:** ✅ **Critical Context - Required Reading**  
**Priority:** 🔴 **MUST READ** before implementing serial generation logic


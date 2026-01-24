# Material Management Implementation Roadmap

**Based on**: `MATERIAL_PRODUCTION_MASTER_SPEC.md`  
**Created**: 2025-12-10  
**Status**: Planning

---

## 🎯 Overview

Implementation roadmap สำหรับ Material Management ตาม Master Spec ที่ตกผลึกแล้ว

---

## 📋 Phase Breakdown

### Phase 1: Hatthasilpa CUT Node Enhancement

**Goal**: รองรับ Component-level tracking + Over-cut + Waste + SKU-Level Tracking

**Tasks**:

1. **Database Schema** ⭐ SKU-Level Foundation
   - [ ] Create `leather_object` table (SKU master)
   - [ ] Create `leather_reservation` table
   - [ ] Create `leather_split` + `leather_split_output` tables
   - [ ] Create `leather_consumption` table
   - [ ] Create `component_overcut_inventory` table (enhanced with object_id)
   - [ ] Create `leather_scrap` table (enhanced with object_id)
   - [ ] Extend CUT node behavior storage
   - [ ] Migration scripts

2. **SKU Management Service**
   - [ ] Create `LeatherObjectService` (CRUD for SKU)
   - [ ] Create `LeatherReservationService` (Reserve/Release)
   - [ ] Create `LeatherSplitService` (CUT operation → Create new SKUs)
   - [ ] Create `LeatherConsumptionService` (Track consumption)

3. **Backend API**
   - [ ] Update CUT node save endpoint
   - [ ] Add SKU reservation flow (Reserve → Cut → Split → Consume)
   - [ ] Add over-cut calculation logic
   - [ ] Add waste reason handling
   - [ ] Material selection API (list available SKUs)
   - [ ] SKU creation after split
   - [ ] Consumption recording (SKU movement)

4. **Frontend UI**
   - [ ] SKU selection UI (list available SKUs)
   - [ ] Reservation confirmation
   - [ ] Component-level input form
   - [ ] Over-cut checkbox + limit display
   - [ ] Waste reason field
   - [ ] SKU traceability display (source chain)

5. **Testing**
   - [ ] Unit tests สำหรับ SKU reservation/release
   - [ ] Unit tests สำหรับ leather split (create new SKUs)
   - [ ] Unit tests สำหรับ over-cut calculation
   - [ ] Unit tests สำหรับ consumption tracking
   - [ ] Integration tests สำหรับ CUT node save (full flow)
   - [ ] Manual QA (SKU traceability verification)

**Estimated Duration**: 2-3 weeks

---

### Phase 2: Classic Line Material Issue (SKU-Level)

**Goal**: เพิ่ม Material Issue flow สำหรับ Classic MO (ใช้ SKU-Level Tracking)

**Tasks**:

1. **Database Schema**
   - [ ] Create `material_issue` + `material_issue_item` tables
   - [ ] Link to `leather_object` (SKU-level)
   - [ ] Migration script

2. **Backend API**
   - [ ] Auto-create Material Requirement จาก BOM
   - [ ] Material Issue endpoint (SKU selection)
   - [ ] SKU reservation for MO (reserve multiple SKUs)
   - [ ] Validate SKU availability
   - [ ] Block MO Start ถ้ายังไม่ออกของ

3. **Frontend UI**
   - [ ] Material Requirement display (MO creation)
   - [ ] Material Issue modal/form (Mode 2: เบิกทั้งผืน)
   - [ ] SKU selection UI (list available SKUs by color/size, ไม่สนใจ area ที่เหลือ)
   - [ ] MO Complete: Remaining Scrap declaration UI (กรอก scrap รวม)
   - [ ] Validation + confirmation

4. **Workflow Integration**
   - [ ] MO Start validation (check Material Issue completed)
   - [ ] Remove material tracking จาก Classic workflow (หลัง Issue)
   - [ ] MO Complete → Mark SKUs as consumed

5. **Testing**
   - [ ] Unit tests สำหรับ Material Issue (SKU reservation)
   - [ ] Integration tests สำหรับ MO workflow
   - [ ] Manual QA

**Estimated Duration**: 2-3 weeks

---

### Phase 3: Over-cut Management & Reporting

**Goal**: จัดการและรายงาน Over-cut inventory

**Tasks**:

1. **Backend API**
   - [ ] Over-cut usage tracking
   - [ ] Limit adjustment (warehouse)
   - [ ] Over-cut reporting endpoints

2. **Frontend UI**
   - [ ] Over-cut dashboard
   - [ ] Over-cut usage history
   - [ ] Limit adjustment UI (warehouse)

3. **Testing**
   - [ ] Unit tests สำหรับ over-cut management
   - [ ] Integration tests
   - [ ] Manual QA

**Estimated Duration**: 1-2 weeks

---

## 🔄 Dependencies

### Phase 1 → Phase 3
- Phase 3 ต้องมี Phase 1 เสร็จก่อน (over-cut inventory structure)

### Phase 2 → Independent
- Classic Line Material Issue เป็นอิสระจาก Hatthasilpa

---

## 📊 Database Changes Summary

### ⭐ Core Tables (SKU-Level Tracking) - NEW

#### 1. `leather_object` (SKU Master Table) ⭐ CRITICAL
- **Purpose**: Track ทุกผืนหนังเป็น SKU แยกกัน (ไม่ใช่รวม sq.ft)
- **Key fields**: `sku_code` (unique), `status`, `source_object_id` (traceability)
- **Status values**: `available`, `reserved`, `cutting`, `consumed`, `split`, `scrap`

#### 2. `leather_reservation` (Reservation System) ⭐ CRITICAL
- **Purpose**: จอง SKU สำหรับงานเฉพาะ (Token หรือ MO)
- **Key fields**: `object_id`, `reserved_for_type`, `reserved_for_id`, `status`
- **Business Rule**: 1 SKU reserved ได้แค่ 1 งาน

#### 3. `leather_split` + `leather_split_output` (CUT Operation)
- **Purpose**: บันทึกการแบ่งผืนหนัง (CUT Node)
- **Key fields**: `source_object_id`, `token_id`/`mo_id`, `split_type`
- **Output**: SKU ใหม่ที่เกิดจากการ split

#### 4. `leather_consumption` (Consumption Tracking)
- **Purpose**: บันทึกการบริโภควัสดุ (บนฐาน SKU movement)
- **Key fields**: `object_id`, `consumed_by_type`, `consumed_by_id`, `consumption_type`
- **Types**: `normal`, `waste`, `overcut_usable`

---

### Supporting Tables

#### 5. `material_issue` + `material_issue_item` (Classic Line)
- **Purpose**: Track Material Issue transactions
- **Key fields**: `mo_id`, `issued_at`, `issued_by`, `status`
- **Items**: SKU ที่ถูก issue (`object_id`, `quantity`, `area_sqft`)

#### 6. `component_overcut_inventory` (Enhanced)
- **Purpose**: Track over-cut usable components (Hatthasilpa only)
- **Enhancement**: เพิ่ม `object_id` (FK → leather_object) สำหรับ traceability

#### 7. `leather_scrap` (Enhanced)
- **Purpose**: Track เศษหนังระดับ S/M/L
- **Enhancement**: เพิ่ม `object_id` (1 scrap = 1 SKU)

---

### Modified Tables

1. **Node behavior storage** (CUT node)
   - Add component-level fields
   - Add over-cut flag
   - Add waste reason
   - Add SKU selection (object_id)

2. **Material requirement**
   - Add issue status
   - Add issue tracking fields

---

## 🎨 UI/UX Requirements

### Hatthasilpa CUT Node

**Component Table**:
```
┌───────────┬──────────┬───────────┬──────────┬─────────────────┐
│ Component │ Required │ ตัดได้จริง│ ตัดเสีย  │ Over-cut Usable │
├───────────┼──────────┼───────────┼──────────┼─────────────────┤
│ BODY      │    1     │    [2]    │   [0]    │ [✓] Keep usable │
│ FLAP      │    1     │    [1]    │   [0]    │                 │
│ STRAP     │    2     │    [2]    │   [1]    │ Waste reason:   │
│           │          │           │          │ [___________]   │
└───────────┴──────────┴───────────┴──────────┴─────────────────┘
```

**Material Selection**:
- Radio: Full Sheet / Scrap S/M/L
- Dropdown: เลือกผืน/scrap ที่มี
- Display: Available quantity

---

### Classic Line Material Issue (SKU-Level)

**Material Issue Modal**:
```
Material: Leather Mint
Required: 24 sq.ft

┌──────────────────┬──────────────────┬──────────┬────────┐
│ SKU Code         │ Status           │ Area     │ Select │
├──────────────────┼──────────────────┼──────────┼────────┤
│ HIDE-001         │ Available        │ 25 sq.ft │ [✓]    │
│ HIDE-002         │ Available        │ 23 sq.ft │ [ ]    │
│ SCRAP-001-L      │ Available        │ 5 sq.ft  │ [ ]    │
│                  │                  │          │        │
│ Total Selected:  │                  │          │ 25 ✓   │
└──────────────────┴──────────────────┴──────────┴────────┘

[Cancel]  [Confirm Issue - Reserve SKUs]
```

**Key Points:**
- เลือก SKU (ไม่ใช่แค่ sq.ft)
- แต่ละ SKU = 1 object
- Reserve SKUs → status = `reserved` for MO

**Pre-Start Validation**:
- Check: Material Issue completed?
- If NO → Show warning + block Start
- If YES → Allow Start

---

## 🔐 Business Rules Summary

### Hatthasilpa CUT Node (Hermès-Level)

1. **SKU Reservation**: Select SKU → Reserve for token (status: `reserved`, soft lock)
2. **CUT Operation**: Split SKU สำคัญ ๆ → Create child SKUs (via `leather_split`)
3. **Component Tracking**: Bundle-level หรือ Critical Components only (ไม่ใช่ทุก component)
4. **Over-cut**: Exceptional flow (ไม่ถามช่างทุกครั้ง) → หัวหน้า/Planner สร้างเอง
5. **Waste**: Required reason if waste > 0
6. **Material Selection**: Select SKU (Full Sheet หรือ Scrap S/M/L)
7. **Scrap Generation**: Auto-generate scrap SKUs after cut (1 scrap = 1 SKU)
8. **Consumption**: Record in `leather_consumption` (SKU movement)

### Classic Line (Standard ERP)

1. **Material Requirement**: Auto-create from BOM (area-based requirement)
2. **Material Issue**: Mandatory before MO Start (Mode 2: เบิกทั้งผืน)
   - Select SKUs (ไม่สนใจว่าเหลืออีกกี่ sq.ft)
   - Reserve SKUs → status = `reserved` for MO
   - **ไม่ split SKU** → เบิกทั้งผืน
3. **Inventory**: Reserve SKUs on Issue (เบิกทั้งผืน)
4. **Workflow**: No material tracking during execution
5. **MO Complete**: 
   - Mark reserved SKUs as `consumed`
   - User กรอก "Remaining Scrap Area" → Convert to scrap pool (aggregated, `object_id = NULL`)

---

## 📝 Implementation Notes

### Key Design Decisions

1. **Two-Tier Approach** ⭐ CRITICAL
   - **Hatthasilpa = Hermès-Level**: Full SKU movement, Component-level, Graph-based
   - **Classic = Standard ERP**: Simplified flow, Material Issue, Aggregate tracking
   - แตกต่างตาม volume, workflow, ROI ของ granular tracking

2. **Balanced SKU-Level Tracking** ⭐ REVISED
   - Full hide = 1 SKU (ทุกผืน = 1 Object)
   - Split สำคัญ ๆ = Child SKU (ไม่ใช่ทุกครั้งที่ตัด)
   - Scrap Classic = Pool (aggregated - ไม่ต้อง SKU แยกทุกชิ้น)
   - Scrap Hatthasilpa = ละเอียดกว่า (1 scrap = 1 SKU)
   - **SKU movement เฉพาะจุดที่สำคัญ** ไม่ใช่ทุกครั้งที่ cutter ขยับมีด

3. **Reservation System (Soft Lock + Audit)** ⭐ REVISED
   - SKU ต้อง Reserve ก่อนใช้
   - `reserved_for_type`: `token` หรือ `mo`
   - Default: Soft lock (ห้ามใช้กับงานอื่น)
   - Exception: Override Reservation (ต้องมีสิทธิ์สูง, log + warning)
   - Pattern: "Lock ตามหลัก, Allow override พร้อม log"

3. **Two Different Approaches**
   - Hatthasilpa: Component-level (premium, real-time tracking)
   - Classic: MO-level (mass production, issue before start)

4. **Material Consumption (Two-Tier)**
   - **Hatthasilpa**: SKU Movement = `HIDE-001 → Reserve → Split → HIDE-001-A + HIDE-001-B → Consume`
   - **Classic**: เบิกทั้งผืน = `HIDE-001 → Reserve → Work → Consume → Declare Scrap Pool`
   - Traceability chain: `source_object_id` (สำหรับ Hatthasilpa), Pool-level (สำหรับ Classic)

5. **Over-cut Management (Exceptional Flow)** ⭐ REVISED
   - **Default**: ถ้าตัดเกิน → ถือว่า scrap (ไม่ถามช่างทุกครั้ง)
   - **Exceptional**: Over-cut เป็น flow พิเศษ (หัวหน้า/Planner สร้างเอง)
   - Stored as separate inventory (with SKU reference - Hatthasilpa only)
   - Has limit (original over-cut quantity)
   - Can be used by other jobs
   - Limit adjustment by warehouse

6. **Material Issue Timing**
   - Classic: Before Start (mandatory, SKU reservation)
   - Hatthasilpa: Real-time during CUT node (SKU reservation per cut)

7. **Scrap Tracking (Two-Tier)**
   - **Hatthasilpa**: Per-piece detail (1 scrap = 1 SKU, `object_id` NOT NULL)
   - **Classic**: Aggregated S/M/L per color (`object_id` NULL, `is_aggregated = TRUE`)

---

## ✅ Definition of Done

### Phase 1 Complete (Hatthasilpa - Hermès-Level)

- [ ] SKU management system ทำงาน (leather_object CRUD)
- [ ] SKU reservation system ทำงาน (soft lock + override)
- [ ] Override Reservation UI ทำงาน (high-privilege only, log + warning)
- [ ] CUT Node UI แสดง Component Bundle form (ไม่ใช่ทุก component แยก)
- [ ] SKU selection UI ทำงาน (list available SKUs with filter)
- [ ] Over-cut: Exceptional flow UI ทำงาน (ไม่ใช่ checkbox ทุกครั้ง)
- [ ] Waste reason field ทำงาน
- [ ] Leather split สร้าง child SKU ได้ถูกต้อง (split สำคัญ ๆ เท่านั้น)
- [ ] Consumption tracking ทำงาน (SKU movement)
- [ ] Over-cut ถูกบันทึกใน database (พร้อม object_id) - exceptional flow
- [ ] SKU traceability chain ถูกต้อง (source_object_id)
- [ ] Tests ผ่านทั้งหมด

### Phase 2 Complete (Classic - Standard ERP)

- [ ] Material Requirement สร้างอัตโนมัติจาก BOM
- [ ] Material Issue UI ทำงาน (Mode 2: เบิกทั้งผืน, ไม่สนใจ area ที่เหลือ)
- [ ] SKU reservation for MO ทำงาน (soft lock)
- [ ] Material Issue บังคับก่อน Start
- [ ] SKUs ถูก reserve ตอน Issue (status = `reserved`, เบิกทั้งผืน)
- [ ] Classic workflow ไม่ต้อง track material (หลัง Issue)
- [ ] MO Complete: Remaining Scrap declaration UI ทำงาน
- [ ] SKUs ถูก mark consumed ตอน MO Complete
- [ ] Scrap ถูกบันทึกเป็น pool (aggregated, `object_id = NULL`, `is_aggregated = TRUE`)
- [ ] Tests ผ่านทั้งหมด

### Phase 3 Complete

- [ ] Over-cut dashboard แสดงข้อมูล
- [ ] Over-cut usage tracking ทำงาน
- [ ] Limit adjustment ทำงาน
- [ ] Tests ผ่านทั้งหมด

---

**Next Action**: เริ่ม Phase 1 — Database Schema Design

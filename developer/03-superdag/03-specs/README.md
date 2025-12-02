# Specifications

**Purpose:** Implementation specifications for SuperDAG features  
**Audience:** Developers implementing new features  
**Status:** Planning Documents (updated when specs change)

---

## 📚 Overview

เอกสารในโฟลเดอร์นี้เป็น **สเปกสำหรับเตรียม Implement** ที่สร้างขึ้นจาก `REALITY_EVENT_IN_HOUSE.md`  
อัพเดทเมื่อมีการเปลี่ยนแปลงสเปกหรือ roadmap แต่ไม่จำเป็นต้องอัพเดทบ่อยเท่า Core Knowledge Documents

---

## 📋 Documents

### Master Roadmap

1. **[SPEC_IMPLEMENTATION_ROADMAP.md](SPEC_IMPLEMENTATION_ROADMAP.md)**
   - Master implementation roadmap
   - Phase 1-4, Task ordering
   - **Status:** Planning document

### Domain Specifications

2. **[SPEC_WORK_CENTER_BEHAVIOR.md](SPEC_WORK_CENTER_BEHAVIOR.md)**
   - Work Center Behavior specification
   - Data model, Event flows, Roadmap
   - **Status:** Planning document

3. **[SPEC_TOKEN_ENGINE.md](SPEC_TOKEN_ENGINE.md)**
   - Token Engine specification
   - Token model, State machine, Roadmap
   - **Status:** Planning document

4. **[SPEC_TIME_ENGINE.md](SPEC_TIME_ENGINE.md)**
   - Time Engine specification
   - Time tracking model, Scenarios, Roadmap
   - **Status:** Planning document

5. **[SPEC_COMPONENT_SERIAL_BINDING.md](SPEC_COMPONENT_SERIAL_BINDING.md)**
   - Component Serial Binding specification
   - Binding model, Event flows, Roadmap
   - **Status:** Planning document

6. **[SPEC_QC_SYSTEM.md](SPEC_QC_SYSTEM.md)**
   - QC System specification
   - QC nodes, Defect codes, Roadmap
   - **Status:** Planning document

7. **[SPEC_PWA_CLASSIC_FLOW.md](SPEC_PWA_CLASSIC_FLOW.md)**
   - PWA Classic Flow specification
   - Scan contracts, Error recovery, Roadmap
   - **Status:** Planning document

8. **[SPEC_LEATHER_STOCK_REALITY.md](SPEC_LEATHER_STOCK_REALITY.md)**
   - Leather Stock Reality specification
   - Leather Steward, Reconciliation logic, Roadmap
   - **Status:** Planning document

---

## 🎯 Usage

- **Read before implementing** - อ่านสเปกที่เกี่ยวข้องก่อน implement feature ใหม่
- **Reference during implementation** - อ้างอิงสเปกระหว่าง implement
- **Update when specs change** - อัพเดทเมื่อมีการเปลี่ยนแปลงสเปก

---

## 📝 Generation

เอกสารเหล่านี้ถูกสร้างขึ้นจาก:
- `REALITY_EVENT_IN_HOUSE.md` (source of truth)
- `PROMPT_GENERATE_SPECS.md` (generation guidelines)

---

**Last Updated:** January 2025


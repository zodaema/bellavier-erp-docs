# DAG Task 5: Component Model & Serial Genealogy (Phase 4)

**Task ID:** DAG-5  
**Status:** 🟡 **PLANNED**  
**Scope:** Component / Serial  
**Type:** Design & Implementation Task

---

## 1. Context

### Problem

Current system lacks a clear component model for multi-part products (e.g., bags with BODY, FLAP, STRAP components). This causes:
- No clear tracking of which tokens represent which components
- No genealogy linking components to final products
- No way to express component relationships in graph design
- Serial tracking is incomplete for multi-part assemblies

### Impact

- Cannot track component genealogy (which components went into which final product)
- Cannot enforce component matching at join nodes
- Serial genealogy queries are imprecise
- Multi-part product workflows are difficult to manage

---

## 2. Objective

Implement Component Model & Serial Genealogy system that:
- Defines canonical component master data (BODY, FLAP, STRAP, etc.)
- Links tokens to components via `component_code` and `id_component`
- Tracks genealogy: component → final product relationships
- Supports graph design: nodes produce/consume components
- Enables precise genealogy queries

---

## 3. Scope

### High-Level Scope

**Database Schema:**
- `product_component` table - Component master data
- `flow_token.component_code` - Component code (e.g., 'BODY', 'FLAP')
- `flow_token.id_component` - Foreign key to product_component
- `flow_token.root_serial` - Root serial (final product serial)
- `flow_token.root_token_id` - Root token (final product token)
- `routing_node.produces_component` - Which component this node produces
- `routing_node.consumes_components` - Which components this node consumes
- `bom_line.component_code` - Link BOM to components

**Token-Component Binding:**
- Split nodes create component tokens with `component_code`
- Join nodes validate component matching
- Serial registration links components to final products

**Genealogy Rules:**
- Component tokens track `root_serial` and `root_token_id`
- Final product tokens link to all component tokens
- Genealogy queries traverse component → product relationships

### Dependencies

- ✅ Token lifecycle stable (Phase 1 complete)
- ✅ Split/Rework ready (Phase 1.1, 1.4 complete)
- ✅ Serial tracking infrastructure (UnifiedSerialService exists)

---

## 4. Implementation Summary

### Current State

**✅ Already Exists (Can Reuse):**
- `flow_token.token_type` enum includes 'component' (already exists)
- `flow_token.parent_token_id` exists (already exists)
- `serial_registry.serial_type` enum('product', 'component', 'subassembly') - Reserved for Phase 4
- `serial_registry.component_category` VARCHAR(50) - Reserved for Phase 4
- `serial_registry.batch_code` VARCHAR(50) - Reserved for Phase 4
- `DAGRoutingService::handleSplitNode()` - Has component_type logic (line 843-850)
- `TokenLifecycleService::splitToken()` - Creates component tokens (line 552)
- `UnifiedSerialService::registerSerial()` - Can be extended to populate component fields

**❌ Needs to be Added:**
- `flow_token.component_code` - Component code (e.g., 'BODY', 'FLAP')
- `flow_token.id_component` - Foreign key to product_component
- `flow_token.root_serial` - Root serial (final product serial)
- `flow_token.root_token_id` - Root token (final product token)
- `product_component` table - Component master data
- `routing_node.produces_component` - Which component this node produces
- `routing_node.consumes_components` - Which components this node consumes
- `bom_line.component_code` - Link BOM to components

**⚠️ Needs to be Updated:**
- `DAGRoutingService::handleSplitNode()` - Currently uses old serial pattern (`parent-componentType`), needs standardized component serial scheme
- `UnifiedSerialService::registerSerial()` - Currently doesn't populate `serial_type`, `component_category` fields
- `TokenLifecycleService::splitToken()` - Currently stores `component_type` in event metadata only, needs to store in token fields

### Planned Implementation

**Phase 4.0: Component Model & Serialisation (Prerequisite)**

**4.0.1 Component Master Data**
- Create `product_component` table
- Define component codes (BODY, FLAP, STRAP, etc.)
- Link components to products

**4.0.2 Token-Component Binding**
- Add `component_code`, `id_component` to `flow_token`
- Update `splitToken()` to set component fields
- Update `registerSerial()` to populate component fields

**4.0.3 Node Component Configuration**
- Add `produces_component` to `routing_node`
- Add `consumes_components` to `routing_node`
- Update Graph Designer to configure component relationships

**4.0.4 Genealogy Tracking**
- Add `root_serial`, `root_token_id` to `flow_token`
- Update split/join logic to maintain genealogy
- Create genealogy query methods

**4.0.5 Validation**
- Validate component matching at join nodes
- Validate component codes exist in product_component
- Validate genealogy consistency

**4.0.6 Serial Registration**
- Update `UnifiedSerialService::registerSerial()` to populate:
  - `serial_type` ('product', 'component', 'subassembly')
  - `component_category` (from product_component)
  - `batch_code` (if applicable)

**4.0.7 BOM Integration**
- Add `component_code` to `bom_line`
- Link BOM lines to components
- Validate BOM component consistency

**4.0.8 Testing**
- Unit tests for component model
- Integration tests for genealogy
- Validation tests for component matching

---

## 5. Guardrails

### Must Not Regress

- ✅ **Existing serial tracking** - Must not break current serial registration
- ✅ **Token lifecycle** - Must not break split/join/rework logic
- ✅ **Backward compatibility** - Existing tokens without component fields must still work
- ✅ **Graph validation** - Must not break existing graph validation

### Design Principles

- **Component codes are canonical** - Defined in `product_component` table, not hardcoded
- **Genealogy is bidirectional** - Component → Product and Product → Components
- **Serial registration is consistent** - All component serials link to final product serial
- **Validation is strict** - Join nodes must validate component matching

---

## 6. Status

**Status:** 🟡 **PLANNED**

**Current State:**
- ✅ Prerequisites complete (Phase 1: Split/Join/Rework)
- ✅ Serial infrastructure exists (UnifiedSerialService)
- 🟡 Design phase (this document)
- ⏳ Implementation pending

**Planned Timeline:**
- Phase 4.0: Component Model & Serialisation (0.5-1 week)
- Phase 4.1: Genealogy Queries (1 week)
- Phase 4.2: Component Matching at Join Nodes (1 week)

**Dependencies:**
- ✅ Phase 1: Advanced Token Routing (Complete)
- ✅ Token lifecycle stable
- ✅ Split/Rework ready

---

## 7. Related Documentation

- [DAG_IMPLEMENTATION_ROADMAP.md](../01-roadmap/DAG_IMPLEMENTATION_ROADMAP.md) - Phase 4: Serial Genealogy & Component Model
- [BELLAVIER_DAG_RUNTIME_FLOW.md](../01-core/BELLAVIER_DAG_RUNTIME_FLOW.md) - Token lifecycle (for split/join context)

---

## 8. Implementation Checklist (Future)

**Phase 4.0A: Component Master Data**
- [ ] Create `product_component` table migration
- [ ] Seed component data for existing products
- [ ] Add component_code validation

**Phase 4.0B: Token-Component Binding**
- [ ] Add `component_code`, `id_component` columns to `flow_token`
- [ ] Update `splitToken()` to set component fields
- [ ] Update `registerSerial()` to populate component fields

**Phase 4.0C: Node Component Configuration**
- [ ] Add `produces_component` to `routing_node`
- [ ] Add `consumes_components` to `routing_node`
- [ ] Update Graph Designer UI

**Phase 4.0D: Genealogy Tracking**
- [ ] Add `root_serial`, `root_token_id` to `flow_token`
- [ ] Update split/join logic to maintain genealogy
- [ ] Create genealogy query methods

**Phase 4.0E: Validation**
- [ ] Validate component matching at join nodes
- [ ] Validate component codes exist
- [ ] Validate genealogy consistency

**Phase 4.0F: Serial Registration**
- [ ] Update `UnifiedSerialService::registerSerial()`
- [ ] Populate `serial_type`, `component_category`, `batch_code`
- [ ] Test serial registration

**Phase 4.0G: BOM Integration**
- [ ] Add `component_code` to `bom_line`
- [ ] Link BOM lines to components
- [ ] Validate BOM component consistency

**Phase 4.0H: Testing**
- [ ] Unit tests for component model
- [ ] Integration tests for genealogy
- [ ] Validation tests for component matching

---

**Task Status:** 🟡 **PLANNED**  
**Next Steps:** Begin Phase 4.0 implementation when ready


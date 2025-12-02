# GraphViewer vs GraphPreview - Technical Comparison

**Date:** 2025-11-19  
**Context:** Phase 8.3 Integration Analysis

---

## 📊 Overview

ในระบบมี **2 modules** สำหรับแสดง graph visualization:

1. **GraphViewer** (เดิม) - `assets/javascripts/dag/graph_viewer.js`
2. **GraphPreview** (Phase 8.3) - `assets/javascripts/products/graph_preview.js`

---

## 🔍 Detailed Comparison

### 1. Purpose & Philosophy

| Aspect | GraphViewer | GraphPreview |
|--------|-------------|--------------|
| **Purpose** | Reusable component for read-only viewing | Standalone preview with API integration |
| **Design Pattern** | Class-based, factory method | Module pattern, function exports |
| **Philosophy** | "Pass me data, I'll render it" | "Give me ID, I'll fetch & render" |

---

### 2. API & Usage

#### GraphViewer (Class-based)
```javascript
// Create instance
const viewer = GraphViewer.create({
  container: '#my-canvas',
  nodes: [...],  // Required: pass data
  edges: [...],  // Required: pass data
  options: { minZoom: 0.5, maxZoom: 2 }
});

// Methods
viewer.fit(50);           // Fit with padding
viewer.destroy();         // Cleanup
viewer.update(newData);   // Update data
viewer.getInstance();     // Get cytoscape instance
```

#### GraphPreview (Function-based)
```javascript
// Show modal (fetches data automatically)
GraphPreview.showGraphPreviewModal(graphId, graphName, version);

// Or render in existing container
GraphPreview.renderGraphPreview('#container', graphId, version, {
  height: '600px',
  layout: 'preset'
});

// Direct functions
GraphPreview.loadGraphPreview(graphId, version);  // Returns Promise
```

---

### 3. Data Flow

#### GraphViewer
```
User Code → Pass {nodes, edges} → GraphViewer → Cytoscape
```
**Pros:** 
- Pure component, no side effects
- Can render any graph data
- Fast (no API call)

**Cons:**
- Caller must fetch data
- More setup code

#### GraphPreview
```
User Code → Pass graphId → GraphPreview → API Call → Cytoscape
```
**Pros:**
- Self-contained (handles API)
- Less setup code
- Automatic loading states

**Cons:**
- Coupled to API endpoint
- Network dependency

---

### 4. Node Styling

#### GraphViewer (12 node types)
```javascript
const NODE_COLORS = {
  'start': '#28a745',      // Green
  'operation': '#17a2b8',  // Cyan
  'process': '#007bff',    // Blue
  'split': '#ffc107',      // Yellow
  'join': '#fd7e14',       // Orange
  'decision': '#6c757d',   // Gray
  'qc': '#9c27b0',        // Purple
  'wait': '#00bcd4',       // Light Blue
  'handoff': '#607d8b',    // Blue Gray
  'subgraph': '#2196f3',   // Blue
  'rework_sink': '#424242',// Dark Gray
  'end': '#dc3545'         // Red
};
```

#### GraphPreview (4 node types + shapes)
```javascript
// Simpler, but uses shapes
'start': green + round-rectangle
'end': red + round-rectangle  
'operation': blue + ellipse
'decision': orange + diamond (70x70)
```

**GraphViewer** = More types, same shape  
**GraphPreview** = Fewer types, varied shapes

---

### 5. Controls

#### GraphViewer (5 buttons)
```
[Zoom In] [Zoom Out] [Fit] [Center] [Reset]
Icons: ri-zoom-in-line, ri-zoom-out-line, ri-fullscreen-line, 
       ri-focus-3-line, ri-refresh-line
```

#### GraphPreview (2 buttons)
```
[Fit to Screen] [Reset Zoom]
Icons: fe-maximize, fe-refresh-cw
```

---

### 6. Edge Styling

| Feature | GraphViewer | GraphPreview |
|---------|-------------|--------------|
| Normal edges | Gray, solid | Gray, solid |
| Conditional edges | Gray, dashed | Orange, dashed |
| Rework edges | Yellow | ❌ Not supported |
| Edge opacity | 0.8-1.0 based on type | Always 1.0 |
| Line width | 3px | 2px |
| Arrow style | Triangle | Triangle |

---

### 7. Layout & Positioning

Both use **preset layout** (stored node positions from database)

#### GraphViewer
```javascript
layout: { name: 'preset' }
// Then: fit → center → store initial state
```

#### GraphPreview
```javascript
layout: { name: 'preset' }
// Then: fit only (no center)
```

---

### 8. Modal Integration

#### GraphViewer
- ❌ No built-in modal
- ✅ Renders in existing container
- **Usage:** Call `GraphViewer.create()` when modal opens

#### GraphPreview
- ✅ Built-in modal creation
- ✅ Automatic modal lifecycle
- **Usage:** Call `showGraphPreviewModal()` - done!

---

### 9. Node Details

#### GraphViewer
- ❌ No built-in node details panel
- ✅ Can access via `cy.on('tap', 'node', ...)`

#### GraphPreview
- ✅ Built-in node details panel
- ✅ Shows on node click
- ✅ Displays: code, name, type, estimated_minutes, wip_limit

---

### 10. Performance

| Metric | GraphViewer | GraphPreview |
|--------|-------------|--------------|
| File size | 527 lines | 429 lines |
| Initialization | Instant (data ready) | +API latency |
| Memory | Lower (no modal DOM) | Higher (creates modal) |
| Re-render | `viewer.update()` | Destroy + recreate modal |

---

## 🎯 When to Use Which?

### Use GraphViewer When:
1. **You already have the data** (nodes/edges in memory)
2. **Rendering in existing container** (e.g., modal already open)
3. **Need more node types** (qc, wait, handoff, subgraph, rework)
4. **Need more controls** (zoom in/out, center)
5. **Performance critical** (avoid API calls)
6. **Custom integration** (need direct cytoscape instance access)

**Example Use Cases:**
- Graph Designer preview panel
- Real-time graph updates
- Embedding in existing dashboards
- Custom node interaction logic

---

### Use GraphPreview When:
1. **Don't have data yet** (need to fetch from API)
2. **Want quick preview modal** (self-contained)
3. **Need node details panel** (built-in)
4. **Prefer function over class** (simpler API)
5. **Don't need advanced node types** (start/end/operation/decision sufficient)

**Example Use Cases:**
- "Preview Graph" button in Product binding
- Quick graph inspection
- One-off graph viewing
- Version comparison preview

---

## 🔄 Current Usage in Codebase

### GraphViewer Usage
```javascript
// In product_graph_binding.js (line 471-558)
function renderGraphPreview(preview) {
  // ... uses GraphViewer.create()
}

// Called when:
// 1. Graph selected in binding form
// 2. Product binding loaded
// 3. Manual preview button clicked
```

### GraphPreview Usage (Phase 8.3)
```javascript
// In product_graph_binding.js (line 1727-1738)
$('#btn-preview-graph').on('click', function() {
  GraphPreview.showGraphPreviewModal(graphId, graphName, version);
});

// Called when:
// 1. "Preview Graph" button clicked (in binding status)
```

---

## 💡 Recommendation: Use Both!

### Why Keep Both?

1. **Different Use Cases**
   - GraphViewer = **inline preview** (in existing modal)
   - GraphPreview = **popup preview** (new modal)

2. **Complementary Features**
   - GraphViewer = more node types, more controls
   - GraphPreview = self-contained, with API

3. **No Conflict**
   - Both use same Cytoscape.js
   - No DOM conflicts (different containers)
   - Small bundle size impact (~50KB combined)

---

## 🔧 Integration Strategy (Implemented)

### Current Setup (page/products.php)
```php
$page_detail['jquery'][12] = 'cytoscape.min.js';
$page_detail['jquery'][13] = 'dag/graph_viewer.js';     // Existing
$page_detail['jquery'][14] = 'products/products.js';
$page_detail['jquery'][15] = 'products/version_comparison.js';  // Phase 8.3
$page_detail['jquery'][16] = 'products/graph_preview.js';       // Phase 8.3
$page_detail['jquery'][17] = 'products/product_graph_binding.js';
```

### Usage Pattern
```javascript
// Inline preview (existing modal)
function renderGraphPreview(preview) {
  GraphViewer.create({
    container: '#graph-preview-canvas',
    nodes: preview.nodes,
    edges: preview.edges
  });
}

// Popup preview (new modal)
$('#btn-preview-graph').on('click', function() {
  const graphId = $(this).data('graph-id');
  const graphName = $(this).data('graph-name');
  const version = $(this).data('version');
  
  GraphPreview.showGraphPreviewModal(graphId, graphName, version);
});
```

---

## 📝 Future Improvements

### Potential Enhancements

1. **Unify Node Styling**
   - Merge NODE_COLORS to single source
   - Support both color-only and color+shape modes

2. **Share Control Components**
   - Extract controls to shared utility
   - Consistent icons (remix vs feather)

3. **Add Node Details to GraphViewer**
   - Optional details panel
   - Configurable detail template

4. **Optimize Bundle**
   - Share Cytoscape style configs
   - Extract common utilities

5. **TypeScript Definitions**
   - Add type hints for both modules
   - Improve IDE autocomplete

---

## 🎓 Key Learnings

### Architecture Insights

1. **Separation of Concerns**
   - GraphViewer = "Render engine"
   - GraphPreview = "Preview UI"
   - Both valid, different layers

2. **Composition over Inheritance**
   - GraphPreview could use GraphViewer internally
   - Currently independent (acceptable trade-off)

3. **Progressive Enhancement**
   - Start simple (GraphViewer)
   - Add features (GraphPreview)
   - Keep both for flexibility

---

## 📞 Support & Questions

**Q: Should I refactor GraphPreview to use GraphViewer?**  
A: Not necessary. Current separation is clean and intentional.

**Q: Which one is "better"?**  
A: Neither. They solve different problems. Use based on context.

**Q: Can I use both in same page?**  
A: Yes! They don't conflict. See usage pattern above.

**Q: Performance impact of loading both?**  
A: Minimal. ~50KB combined, 1 Cytoscape.js instance shared.

---

**End of Comparison**

*For more details, see source code:*
- `assets/javascripts/dag/graph_viewer.js`
- `assets/javascripts/products/graph_preview.js`

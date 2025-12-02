# 🎨 Graph List Panel Enhancement - แผนการพัฒนา UI/UX

**วันที่วางแผน:** 9 พฤศจิกายน 2025  
**สถานะ:** 📋 Ready to Implement  
**เป้าหมาย:** ยกระดับ Graph List Panel จาก table ธรรมดา → Modern, Scalable, Intuitive UI (แนว Figma/Miro/VSCode Explorer)

---

## 📊 สรุปภาพรวม

### ปัญหาปัจจุบัน
- ❌ DataTable ธรรมดา ไม่เหมาะกับกราฟหลายสิบไฟล์
- ❌ ไม่มี preview, favorite, grouping
- ❌ Search ไม่ intuitive
- ❌ ไม่มี quick actions (duplicate, rename, delete)
- ❌ ไม่แสดง version, last modified, runtime status
- ❌ โค้ดผสมกับ graph_designer.js (ไม่ modular)

### เป้าหมาย
- ✅ Modern UI (List/Card view) แนว Figma/Miro/VSCode Explorer
- ✅ Search/Filter ที่ powerful และ intuitive
- ✅ Favorite ⭐ และ Collapsible Groups
- ✅ Quick Actions (hover → actions menu)
- ✅ Thumbnail preview (optional)
- ✅ Keyboard shortcuts (Ctrl/Cmd+P → Command Palette)
- ✅ Modular architecture (แยก graph_sidebar.js)
- ✅ Scalable (รองรับ 100+ กราฟ)

---

## 🏗️ Architecture Design

### File Structure (ใหม่)

```
assets/javascripts/dag/
├── graph_designer.js          # Cytoscape logic, Graph CRUD (refactored)
├── graph_sidebar.js           # Graph List Panel logic (NEW)
└── graph_command_palette.js  # Command Palette (NEW, optional)

views/
├── routing_graph_designer.php # Main view (updated)
└── dag/
    └── graph_sidebar.php      # Sidebar component template (NEW)

source/
└── dag_routing_api.php        # API (enhanced fields)
```

### Component Separation

| Component | Responsibility | File |
|-----------|---------------|------|
| **Graph Sidebar** | List rendering, search, filter, selection | `graph_sidebar.js` |
| **Graph Designer** | Cytoscape canvas, node/edge editing | `graph_designer.js` |
| **Command Palette** | Quick search/navigation | `graph_command_palette.js` (optional) |

---

## 🎨 UI Design Specification

### Layout Structure

```
┌─────────────────────────────────────┐
│ Graph List Panel (col-md-3)         │
├─────────────────────────────────────┤
│ [🔍 Search] [⚙️ Filter] [⭐ Favorites]│
│ [📋 List] [🖼️ Card] [📚 Library]     │
├─────────────────────────────────────┤
│ 📁 OEM (5)                          │
│   ├─ Graph A v1.2 [Published] ⭐    │
│   ├─ Graph B v2.0 [Draft]          │
│   └─ Graph C v1.0 [Published]      │
│                                     │
│ 📁 Hatthasilpa (3)                 │
│   ├─ Graph D v1.5 [Published] ⭐    │
│   └─ Graph E v1.0 [Draft]          │
│                                     │
│ 📁 Hybrid (2)                       │
│   └─ Graph F v1.0 [Published]      │
└─────────────────────────────────────┘
```

### View Modes

#### 1. List View (Default)
```
┌─────────────────────────────────────┐
│ Graph Name        │ Status │ Actions│
├─────────────────────────────────────┤
│ 📄 Graph A        │ ✅ Pub │ [⋯]   │
│    code: GRAPH_A  │ v1.2   │        │
│    Modified: 2h   │        │        │
├─────────────────────────────────────┤
│ 📄 Graph B        │ ⚪ Draft│ [⋯]   │
│    code: GRAPH_B  │ v2.0   │        │
│    Modified: 1d   │        │        │
└─────────────────────────────────────┘
```

#### 2. Card View (Optional)
```
┌──────────┬──────────┬──────────┐
│ [Thumb]  │ [Thumb]  │ [Thumb]  │
│ Graph A  │ Graph B  │ Graph C  │
│ v1.2 ✅  │ v2.0 ⚪  │ v1.0 ✅  │
│ ⭐       │          │          │
└──────────┴──────────┴──────────┘
```

#### 3. Library View (Future)
- Grid layout with thumbnails
- Filter by category, production mode
- Sort by name, date, version

---

## 📋 Component API Design

### Graph Sidebar API

```javascript
// graph_sidebar.js
class GraphSidebar {
    constructor(options) {
        this.container = options.container; // '#graph-sidebar'
        this.onGraphSelect = options.onGraphSelect; // Callback: (graphId) => {}
        this.onGraphAction = options.onGraphAction; // Callback: (action, graphId) => {}
    }
    
    // Public Methods
    loadGraphs()           // Fetch and render graphs
    refresh()              // Reload list
    selectGraph(graphId)   // Highlight selected graph
    filterGraphs(filters)  // Apply filters
    searchGraphs(query)    // Search by name/code
    toggleFavorite(graphId) // Toggle favorite
    groupBy(criteria)      // Group by category/mode
    setViewMode(mode)      // 'list' | 'card' | 'library'
}
```

### Event System

```javascript
// Events emitted by GraphSidebar
'graph:selected'     // Graph clicked/selected
'graph:doubleclick'  // Graph double-clicked (open)
'graph:action'       // Action triggered (duplicate, delete, etc.)
'graph:favorite'     // Favorite toggled
'graph:filter'       // Filter changed
'graph:search'       // Search query changed
```

---

## 🔌 API Enhancements

### Enhanced `graph_list` Endpoint

**Current:**
```php
GET /source/dag_routing_api.php?action=graph_list&status=draft
Response: {
    ok: true,
    graphs: [
        {
            id_graph: 1,
            name: "Graph A",
            code: "GRAPH_A",
            status: "draft",
            node_count: 5,
            edge_count: 4
        }
    ]
}
```

**Enhanced:**
```php
GET /source/dag_routing_api.php?action=graph_list
Query Params:
    - status: draft|published|archived (optional)
    - search: string (optional, search name/code)
    - category: oem|hatthasilpa|hybrid (optional)
    - favorite: 0|1 (optional)
    - sort: name|date|version (default: date)
    - order: asc|desc (default: desc)
    - limit: int (optional, for pagination)
    - offset: int (optional, for pagination)

Response: {
    ok: true,
    graphs: [
        {
            id_graph: 1,
            name: "Graph A",
            code: "GRAPH_A",
            status: "draft",
            version: "1.2",
            node_count: 5,
            edge_count: 4,
            thumbnail_url: "/storage/dag_thumbs/1-a1b2c3.png", // Optional
            updated_at: "2025-11-09T10:30:00Z",
            updated_by: 1,
            updated_by_name: "John Doe",
            created_at: "2025-11-01T08:00:00Z",
            created_by: 1,
            created_by_name: "Jane Smith",
            is_favorite: true,
            production_mode: "hatthasilpa", // From nodes
            runtime_enabled: true, // From feature flag
            last_used_at: "2025-11-09T09:00:00Z" // From job_graph_instance
        }
    ],
    total: 25,
    filters_applied: {
        status: "draft",
        category: "hatthasilpa"
    }
}
```

### New Endpoints

#### 1. `graph_favorite_toggle`
```php
POST /source/dag_routing_api.php?action=graph_favorite_toggle
Body: { id_graph: 1 }
Response: { ok: true, is_favorite: true }
```

#### 2. `graph_get_thumbnail` (Optional)
```php
GET /source/dag_routing_api.php?action=graph_get_thumbnail&id_graph=1
Response: {
    ok: true,
    thumbnail_url: "/storage/dag_thumbs/1-a1b2c3.png",
    etag: "W/\"a1b2c3\""
}
// Or 304 Not Modified if ETag matches
```

#### 3. `graph_quick_search` (Command Palette)
```php
GET /source/dag_routing_api.php?action=graph_quick_search&q=graph
Response: {
    ok: true,
    results: [
        {
            id_graph: 1,
            name: "Graph A",
            code: "GRAPH_A",
            match_type: "name", // "name" | "code"
            match_score: 0.95
        }
    ]
}
```

---

## 💻 Implementation Plan

### Phase 2.1: Core Refactoring (1-2 วัน)

#### Task 2.1.1: Extract Graph Sidebar Logic
**File:** `assets/javascripts/dag/graph_sidebar.js` (NEW)

```javascript
/**
 * Graph Sidebar Component
 * Handles graph list rendering, search, filter, and selection
 */

(function($) {
    'use strict';
    
    class GraphSidebar {
        constructor(options) {
            this.container = $(options.container || '#graph-sidebar');
            this.onGraphSelect = options.onGraphSelect || function() {};
            this.onGraphAction = options.onGraphAction || function() {};
            
            // State
            this.graphs = [];
            this.filteredGraphs = [];
            this.selectedGraphId = null;
            this.viewMode = 'list'; // 'list' | 'card' | 'library'
            this.filters = {
                status: null,
                category: null,
                favorite: null,
                search: ''
            };
            this.groupBy = null; // 'category' | 'mode' | null
            
            // Initialize
            this.init();
        }
        
        init() {
            this.render();
            this.bindEvents();
            this.loadGraphs();
        }
        
        async loadGraphs() {
            try {
                const response = await $.get('source/dag_routing_api.php', {
                    action: 'graph_list',
                    ...this.filters
                });
                
                if (response.ok && response.graphs) {
                    this.graphs = response.graphs;
                    this.applyFilters();
                    this.render();
                }
            } catch (error) {
                console.error('Failed to load graphs:', error);
            }
        }
        
        applyFilters() {
            let filtered = [...this.graphs];
            
            // Search filter
            if (this.filters.search) {
                const query = this.filters.search.toLowerCase();
                filtered = filtered.filter(g => 
                    g.name.toLowerCase().includes(query) ||
                    g.code.toLowerCase().includes(query)
                );
            }
            
            // Status filter
            if (this.filters.status) {
                filtered = filtered.filter(g => g.status === this.filters.status);
            }
            
            // Category filter
            if (this.filters.category) {
                filtered = filtered.filter(g => g.production_mode === this.filters.category);
            }
            
            // Favorite filter
            if (this.filters.favorite !== null) {
                filtered = filtered.filter(g => g.is_favorite === this.filters.favorite);
            }
            
            this.filteredGraphs = filtered;
        }
        
        render() {
            const html = this.buildHTML();
            this.container.find('.graph-list-content').html(html);
            this.highlightSelected();
        }
        
        buildHTML() {
            if (this.groupBy) {
                return this.buildGroupedHTML();
            }
            
            if (this.viewMode === 'list') {
                return this.buildListHTML();
            } else if (this.viewMode === 'card') {
                return this.buildCardHTML();
            }
            
            return this.buildListHTML();
        }
        
        buildListHTML() {
            if (this.filteredGraphs.length === 0) {
                return '<div class="text-center p-4 text-muted">No graphs found</div>';
            }
            
            return this.filteredGraphs.map(graph => `
                <div class="graph-list-item ${graph.id_graph === this.selectedGraphId ? 'active' : ''}" 
                     data-graph-id="${graph.id_graph}">
                    <div class="graph-item-content">
                        <div class="graph-item-header">
                            <div class="graph-item-title">
                                <span class="graph-icon">📄</span>
                                <strong>${this.escapeHtml(graph.name)}</strong>
                                ${graph.is_favorite ? '<span class="favorite-star">⭐</span>' : ''}
                            </div>
                            <div class="graph-item-actions">
                                <button class="btn btn-sm btn-link graph-action-btn" 
                                        data-action="menu" 
                                        data-graph-id="${graph.id_graph}">
                                    <i class="ri-more-line"></i>
                                </button>
                            </div>
                        </div>
                        <div class="graph-item-meta">
                            <span class="graph-code">${this.escapeHtml(graph.code)}</span>
                            <span class="graph-badges">
                                ${this.renderStatusBadge(graph)}
                                ${this.renderVersionBadge(graph)}
                                ${graph.runtime_enabled ? '<span class="badge bg-info">Runtime</span>' : ''}
                            </span>
                        </div>
                        <div class="graph-item-footer">
                            <small class="text-muted">
                                Modified: ${this.formatDate(graph.updated_at)}
                                ${graph.updated_by_name ? ` by ${this.escapeHtml(graph.updated_by_name)}` : ''}
                            </small>
                        </div>
                    </div>
                </div>
            `).join('');
        }
        
        renderStatusBadge(graph) {
            const statusMap = {
                'draft': { class: 'bg-secondary', text: 'Draft' },
                'published': { class: 'bg-success', text: 'Published' },
                'archived': { class: 'bg-dark', text: 'Archived' }
            };
            const status = statusMap[graph.status] || statusMap.draft;
            return `<span class="badge ${status.class}">${status.text}</span>`;
        }
        
        renderVersionBadge(graph) {
            if (graph.version) {
                return `<span class="badge bg-outline-secondary">v${graph.version}</span>`;
            }
            return '';
        }
        
        buildGroupedHTML() {
            // Group graphs by category or production_mode
            const groups = {};
            
            this.filteredGraphs.forEach(graph => {
                const key = graph[this.groupBy] || 'other';
                if (!groups[key]) {
                    groups[key] = [];
                }
                groups[key].push(graph);
            });
            
            let html = '';
            Object.keys(groups).sort().forEach(key => {
                html += `
                    <div class="graph-group" data-group="${key}">
                        <div class="graph-group-header" data-toggle="collapse" data-target="#group-${key}">
                            <i class="ri-folder-line"></i>
                            <strong>${this.formatGroupName(key)}</strong>
                            <span class="badge bg-secondary">${groups[key].length}</span>
                            <i class="ri-arrow-down-s-line"></i>
                        </div>
                        <div class="graph-group-content collapse show" id="group-${key}">
                            ${groups[key].map(g => this.buildListItemHTML(g)).join('')}
                        </div>
                    </div>
                `;
            });
            
            return html;
        }
        
        buildListItemHTML(graph) {
            return `
                <div class="graph-list-item ${graph.id_graph === this.selectedGraphId ? 'active' : ''}" 
                     data-graph-id="${graph.id_graph}">
                    <!-- Same as buildListHTML but for grouped view -->
                </div>
            `;
        }
        
        bindEvents() {
            // Click to select
            this.container.on('click', '.graph-list-item', (e) => {
                const graphId = $(e.currentTarget).data('graph-id');
                this.selectGraph(graphId);
            });
            
            // Double-click to open
            this.container.on('dblclick', '.graph-list-item', (e) => {
                const graphId = $(e.currentTarget).data('graph-id');
                this.onGraphSelect(graphId);
            });
            
            // Action menu
            this.container.on('click', '.graph-action-btn', (e) => {
                e.stopPropagation();
                const graphId = $(e.currentTarget).data('graph-id');
                this.showActionMenu(graphId, $(e.currentTarget));
            });
            
            // Favorite toggle
            this.container.on('click', '.favorite-star', (e) => {
                e.stopPropagation();
                const graphId = $(e.currentTarget).closest('.graph-list-item').data('graph-id');
                this.toggleFavorite(graphId);
            });
            
            // Search
            this.container.on('input', '.graph-search-input', (e) => {
                this.filters.search = $(e.target).val();
                this.applyFilters();
                this.render();
            });
            
            // Filter dropdowns
            this.container.on('change', '.graph-filter-status', (e) => {
                this.filters.status = $(e.target).val() || null;
                this.applyFilters();
                this.render();
            });
        }
        
        selectGraph(graphId) {
            this.selectedGraphId = graphId;
            this.highlightSelected();
            this.onGraphSelect(graphId);
        }
        
        highlightSelected() {
            this.container.find('.graph-list-item').removeClass('active');
            if (this.selectedGraphId) {
                this.container.find(`[data-graph-id="${this.selectedGraphId}"]`).addClass('active');
            }
        }
        
        async toggleFavorite(graphId) {
            try {
                const response = await $.post('source/dag_routing_api.php', {
                    action: 'graph_favorite_toggle',
                    id_graph: graphId
                });
                
                if (response.ok) {
                    const graph = this.graphs.find(g => g.id_graph === graphId);
                    if (graph) {
                        graph.is_favorite = response.is_favorite;
                        this.applyFilters();
                        this.render();
                    }
                }
            } catch (error) {
                console.error('Failed to toggle favorite:', error);
            }
        }
        
        showActionMenu(graphId, button) {
            // Show context menu with: Duplicate, Rename, Archive, Delete
            const menu = $(`
                <div class="graph-action-menu">
                    <button class="menu-item" data-action="duplicate">
                        <i class="ri-file-copy-line"></i> Duplicate
                    </button>
                    <button class="menu-item" data-action="rename">
                        <i class="ri-edit-line"></i> Rename
                    </button>
                    <button class="menu-item" data-action="archive">
                        <i class="ri-archive-line"></i> Archive
                    </button>
                    <hr>
                    <button class="menu-item text-danger" data-action="delete">
                        <i class="ri-delete-bin-line"></i> Delete
                    </button>
                </div>
            `);
            
            // Position menu
            const offset = button.offset();
            menu.css({
                position: 'absolute',
                top: offset.top + button.outerHeight(),
                left: offset.left
            });
            
            // Show menu
            $('body').append(menu);
            
            // Handle menu actions
            menu.on('click', '.menu-item', (e) => {
                const action = $(e.currentTarget).data('action');
                this.onGraphAction(action, graphId);
                menu.remove();
            });
            
            // Close on outside click
            $(document).one('click', () => menu.remove());
        }
        
        refresh() {
            this.loadGraphs();
        }
        
        // Utility methods
        escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }
        
        formatDate(dateString) {
            if (!dateString) return 'Never';
            const date = new Date(dateString);
            const now = new Date();
            const diffMs = now - date;
            const diffMins = Math.floor(diffMs / 60000);
            const diffHours = Math.floor(diffMs / 3600000);
            const diffDays = Math.floor(diffMs / 86400000);
            
            if (diffMins < 1) return 'Just now';
            if (diffMins < 60) return `${diffMins}m ago`;
            if (diffHours < 24) return `${diffHours}h ago`;
            if (diffDays < 7) return `${diffDays}d ago`;
            return date.toLocaleDateString();
        }
        
        formatGroupName(key) {
            const names = {
                'oem': 'OEM',
                'hatthasilpa': 'Hatthasilpa',
                'hybrid': 'Hybrid',
                'other': 'Other'
            };
            return names[key] || key.charAt(0).toUpperCase() + key.slice(1);
        }
    }
    
    // Export
    window.GraphSidebar = GraphSidebar;
    
})(jQuery);
```

#### Task 2.1.2: Update graph_designer.js
**Refactor:** Remove DataTable logic, use GraphSidebar

```javascript
// graph_designer.js (refactored)

// Remove initDataTable() and loadGraphList()
// Replace with:

let graphSidebar = null;

$(document).ready(function() {
    // Initialize Graph Sidebar
    graphSidebar = new GraphSidebar({
        container: '#graph-sidebar',
        onGraphSelect: (graphId) => {
            loadGraph(graphId);
        },
        onGraphAction: (action, graphId) => {
            handleGraphAction(action, graphId);
        }
    });
    
    initCytoscape();
    initZoomControls();
    bindEvents();
    
    // Keyboard shortcuts
    $(document).on('keydown', function(e) {
        // Ctrl/Cmd+P: Command Palette
        if ((e.ctrlKey || e.metaKey) && e.key === 'p') {
            e.preventDefault();
            showCommandPalette();
        }
        // ... other shortcuts
    });
});

function handleGraphAction(action, graphId) {
    switch (action) {
        case 'duplicate':
            duplicateGraph(graphId);
            break;
        case 'rename':
            renameGraph(graphId);
            break;
        case 'archive':
            archiveGraph(graphId);
            break;
        case 'delete':
            deleteGraph(graphId);
            break;
    }
}

// Remove loadGraphList() calls, replace with:
function refreshGraphList() {
    if (graphSidebar) {
        graphSidebar.refresh();
    }
}
```

#### Task 2.1.3: Update View Template
**File:** `views/routing_graph_designer.php`

```php
<!-- Graph List Panel -->
<div class="col-md-3">
    <div class="card custom-card mb-3" id="graph-sidebar">
        <div class="card-header">
            <div class="d-flex align-items-center justify-content-between">
                <h6 class="card-title mb-0">
                    <?php echo translate('routing.graph_list', 'Graphs'); ?>
                </h6>
                <div class="btn-group btn-group-sm">
                    <button class="btn btn-outline-secondary" data-view-mode="list" title="List View">
                        <i class="ri-list-check"></i>
                    </button>
                    <button class="btn btn-outline-secondary" data-view-mode="card" title="Card View">
                        <i class="ri-grid-line"></i>
                    </button>
                </div>
            </div>
        </div>
        
        <!-- Search & Filters -->
        <div class="card-body p-2 border-bottom">
            <div class="input-group input-group-sm mb-2">
                <span class="input-group-text"><i class="ri-search-line"></i></span>
                <input type="text" class="form-control graph-search-input" 
                       placeholder="<?php echo translate('routing.search_graphs', 'Search graphs...'); ?>">
            </div>
            
            <div class="d-flex gap-1 flex-wrap">
                <select class="form-select form-select-sm graph-filter-status" style="flex: 1;">
                    <option value="">All Status</option>
                    <option value="draft">Draft</option>
                    <option value="published">Published</option>
                    <option value="archived">Archived</option>
                </select>
                
                <select class="form-select form-select-sm graph-filter-category" style="flex: 1;">
                    <option value="">All Categories</option>
                    <option value="oem">OEM</option>
                    <option value="hatthasilpa">Hatthasilpa</option>
                    <option value="hybrid">Hybrid</option>
                </select>
                
                <button class="btn btn-sm btn-outline-secondary graph-filter-favorite" 
                        data-favorite="1" title="Show Favorites">
                    <i class="ri-star-line"></i>
                </button>
            </div>
            
            <div class="mt-2">
                <button class="btn btn-sm btn-link p-0 graph-group-toggle" data-group-by="category">
                    <i class="ri-folder-line"></i> Group by Category
                </button>
            </div>
        </div>
        
        <!-- Graph List Content -->
        <div class="card-body p-0 graph-list-content" style="max-height: 500px; overflow-y: auto;">
            <!-- Rendered by GraphSidebar -->
        </div>
    </div>
    
    <!-- Toolbox Card (unchanged) -->
    <!-- ... -->
</div>
```

---

### Phase 2.2: API Enhancements (0.5 วัน)

#### Task 2.2.1: Enhance `graph_list` Endpoint
**File:** `source/dag_routing_api.php`

```php
case 'graph_list':
    must_allow_code($member, 'hatthasilpa.routing.view');
    set_cache_header(30);
    
    // Request validation
    $validation = RequestValidator::make($_GET, [
        'status' => 'nullable|in:draft,published,archived',
        'search' => 'nullable|string|max:100',
        'category' => 'nullable|in:oem,hatthasilpa,hybrid',
        'favorite' => 'nullable|boolean',
        'sort' => 'nullable|in:name,date,version',
        'order' => 'nullable|in:asc,desc',
        'limit' => 'nullable|integer|min:1|max:100',
        'offset' => 'nullable|integer|min:0'
    ]);
    $data = $validation['data'];
    
    // Build query
    $sql = "
        SELECT 
            rg.*,
            (SELECT COUNT(*) FROM routing_node WHERE id_graph = rg.id_graph) as node_count,
            (SELECT COUNT(*) FROM routing_edge WHERE id_graph = rg.id_graph) as edge_count,
            (SELECT MAX(published_at) FROM routing_graph_version WHERE id_graph = rg.id_graph) as last_published_at,
            (SELECT version FROM routing_graph_version WHERE id_graph = rg.id_graph ORDER BY published_at DESC LIMIT 1) as version,
            (SELECT COUNT(*) > 0 FROM routing_graph_feature_flag WHERE id_graph = rg.id_graph AND flag_key = 'RUNTIME_ENABLED' AND flag_value = 'on') as runtime_enabled,
            (SELECT MAX(created_at) FROM job_graph_instance WHERE id_graph = rg.id_graph) as last_used_at,
            u1.name as updated_by_name,
            u2.name as created_by_name
        FROM routing_graph rg
        LEFT JOIN bgerp.account u1 ON u1.id_member = rg.updated_by
        LEFT JOIN bgerp.account u2 ON u2.id_member = rg.created_by
        WHERE 1=1
    ";
    
    $params = [];
    $types = '';
    
    // Status filter
    if ($data['status']) {
        $sql .= " AND rg.status = ?";
        $params[] = $data['status'];
        $types .= 's';
    }
    
    // Category filter (from nodes)
    if ($data['category']) {
        $sql .= " AND EXISTS (
            SELECT 1 FROM routing_node 
            WHERE id_graph = rg.id_graph 
            AND production_mode = ?
        )";
        $params[] = $data['category'];
        $types .= 's';
    }
    
    // Search filter
    if ($data['search']) {
        $sql .= " AND (rg.name LIKE ? OR rg.code LIKE ?)";
        $searchTerm = '%' . $data['search'] . '%';
        $params[] = $searchTerm;
        $params[] = $searchTerm;
        $types .= 'ss';
    }
    
    // Favorite filter (if favorite table exists)
    // Note: Need to add routing_graph_favorite table first
    
    // Sorting
    $sort = $data['sort'] ?? 'date';
    $order = $data['order'] ?? 'desc';
    $sortMap = [
        'name' => 'rg.name',
        'date' => 'rg.updated_at',
        'version' => 'last_published_at'
    ];
    $sortField = $sortMap[$sort] ?? 'rg.updated_at';
    $sql .= " ORDER BY {$sortField} {$order}";
    
    // Pagination
    if (isset($data['limit'])) {
        $limit = (int)$data['limit'];
        $offset = (int)($data['offset'] ?? 0);
        $sql .= " LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;
        $types .= 'ii';
    }
    
    // Execute query
    if ($types && $params) {
        $graphs = $db->fetchAll($sql, $params, $types);
    } else {
        $graphs = $db->fetchAll($sql);
    }
    
    // Add thumbnail URLs
    foreach ($graphs as &$graph) {
        if ($graph['etag']) {
            $etagHash = substr(md5($graph['etag']), 0, 8);
            $graph['thumbnail_url'] = "/storage/dag_thumbs/{$graph['id_graph']}-{$etagHash}.png";
        }
        // Add favorite status (if table exists)
        $graph['is_favorite'] = false; // TODO: Query from routing_graph_favorite
    }
    
    // Get total count (for pagination)
    $countSql = "SELECT COUNT(*) as total FROM routing_graph rg WHERE 1=1";
    // Apply same filters...
    $total = $db->fetchOne($countSql, $params, $types)['total'] ?? count($graphs);
    
    json_success([
        'graphs' => $graphs,
        'total' => $total,
        'filters_applied' => array_filter([
            'status' => $data['status'] ?? null,
            'category' => $data['category'] ?? null,
            'search' => $data['search'] ?? null
        ])
    ]);
    break;
```

#### Task 2.2.2: Add `graph_favorite_toggle` Endpoint
**File:** `source/dag_routing_api.php`

```php
case 'graph_favorite_toggle':
    must_allow_code($member, 'hatthasilpa.routing.view');
    
    $validation = RequestValidator::make($_POST, [
        'id_graph' => 'required|integer|min:1'
    ]);
    if (!$validation['valid']) {
        json_error('validation_failed', 400);
    }
    
    $graphId = $validation['data']['id_graph'];
    $userId = $member['id_member'];
    
    // Check if favorite exists
    $existing = $db->fetchOne(
        "SELECT id FROM routing_graph_favorite WHERE id_graph = ? AND id_member = ?",
        [$graphId, $userId],
        'ii'
    );
    
    if ($existing) {
        // Remove favorite
        $db->execute(
            "DELETE FROM routing_graph_favorite WHERE id_graph = ? AND id_member = ?",
            [$graphId, $userId],
            'ii'
        );
        json_success(['is_favorite' => false]);
    } else {
        // Add favorite
        $db->execute(
            "INSERT INTO routing_graph_favorite (id_graph, id_member, created_at) VALUES (?, ?, NOW())",
            [$graphId, $userId],
            'ii'
        );
        json_success(['is_favorite' => true]);
    }
    break;
```

#### Task 2.2.3: Add `routing_graph_favorite` Table (Migration)
**File:** `database/tenant_migrations/2025_11_graph_list_enhancement.php` (NEW)

```php
<?php
/**
 * Migration: 2025_11_graph_list_enhancement
 * 
 * Description: Graph List Panel Enhancement - Database Schema
 * 
 * Adds:
 * - routing_graph_favorite table (user favorites)
 * - Enhanced graph_list API fields (version, updated_by_name, etc.)
 * 
 * @package Bellavier Group ERP
 * @version 1.0.0
 * @date 2025-11-09
 */

require_once __DIR__ . '/../tools/migration_helpers.php';

return function (mysqli $db): void {
    echo "=== Graph List Panel Enhancement - Migration ===\n\n";
    
    // Create routing_graph_favorite table
    echo "[1/1] Creating routing_graph_favorite table...\n";
    
    $sql = <<<'SQL'
(
    id INT PRIMARY KEY AUTO_INCREMENT,
    id_graph INT NOT NULL COMMENT 'FK → routing_graph.id_graph',
    id_member INT NOT NULL COMMENT 'FK → bgerp.account.id_member',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY uniq_graph_member (id_graph, id_member),
    INDEX idx_member (id_member),
    INDEX idx_graph (id_graph),
    FOREIGN KEY (id_graph) REFERENCES routing_graph(id_graph) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='User favorites for graphs'
SQL;
    
    migration_create_table_if_missing($db, 'routing_graph_favorite', $sql);
    echo "  ✓ routing_graph_favorite table created\n\n";
    
    echo "✅ Migration complete!\n";
};
```

---

### Phase 2.3: UI/UX Enhancements (1-2 วัน)

#### Task 2.3.1: CSS Styling
**File:** `assets/stylesheets/dag/graph_sidebar.css` (NEW)

```css
/* Graph Sidebar Styles */

#graph-sidebar {
    height: 100%;
    display: flex;
    flex-direction: column;
}

.graph-list-content {
    flex: 1;
    overflow-y: auto;
    overflow-x: hidden;
}

.graph-list-item {
    padding: 0.75rem 1rem;
    border-bottom: 1px solid var(--bs-border-color);
    cursor: pointer;
    transition: background-color 0.2s;
}

.graph-list-item:hover {
    background-color: var(--bs-gray-100);
}

.graph-list-item.active {
    background-color: var(--bs-primary-bg-subtle);
    border-left: 3px solid var(--bs-primary);
}

.graph-item-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 0.25rem;
}

.graph-item-title {
    flex: 1;
    display: flex;
    align-items: center;
    gap: 0.5rem;
}

.graph-icon {
    font-size: 1.25rem;
}

.favorite-star {
    color: var(--bs-warning);
    cursor: pointer;
    font-size: 0.875rem;
}

.graph-item-meta {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 0.25rem;
    font-size: 0.875rem;
}

.graph-code {
    color: var(--bs-secondary);
    font-family: monospace;
}

.graph-badges {
    display: flex;
    gap: 0.25rem;
    flex-wrap: wrap;
}

.graph-item-footer {
    font-size: 0.75rem;
    color: var(--bs-secondary);
}

.graph-group {
    border-bottom: 1px solid var(--bs-border-color);
}

.graph-group-header {
    padding: 0.75rem 1rem;
    background-color: var(--bs-gray-50);
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-weight: 600;
    user-select: none;
}

.graph-group-header:hover {
    background-color: var(--bs-gray-100);
}

.graph-group-content {
    padding: 0;
}

.graph-action-menu {
    position: absolute;
    background: white;
    border: 1px solid var(--bs-border-color);
    border-radius: 0.25rem;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15);
    z-index: 1000;
    min-width: 150px;
    padding: 0.25rem 0;
}

.graph-action-menu .menu-item {
    display: block;
    width: 100%;
    padding: 0.5rem 1rem;
    border: none;
    background: none;
    text-align: left;
    cursor: pointer;
    transition: background-color 0.2s;
}

.graph-action-menu .menu-item:hover {
    background-color: var(--bs-gray-100);
}

.graph-action-menu .menu-item i {
    margin-right: 0.5rem;
}

/* Card View */
.graph-card-view {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
    gap: 1rem;
    padding: 1rem;
}

.graph-card {
    border: 1px solid var(--bs-border-color);
    border-radius: 0.25rem;
    padding: 0.75rem;
    cursor: pointer;
    transition: transform 0.2s, box-shadow 0.2s;
}

.graph-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 8px rgba(0,0,0,0.1);
}

.graph-card-thumbnail {
    width: 100%;
    height: 80px;
    background-color: var(--bs-gray-100);
    border-radius: 0.25rem;
    margin-bottom: 0.5rem;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 2rem;
}

.graph-card-title {
    font-weight: 600;
    font-size: 0.875rem;
    margin-bottom: 0.25rem;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.graph-card-badges {
    display: flex;
    gap: 0.25rem;
    flex-wrap: wrap;
    margin-top: 0.25rem;
}

/* Dark Mode Support */
[data-bs-theme="dark"] .graph-list-item:hover {
    background-color: var(--bs-gray-800);
}

[data-bs-theme="dark"] .graph-list-item.active {
    background-color: var(--bs-primary-bg-subtle);
}

[data-bs-theme="dark"] .graph-group-header {
    background-color: var(--bs-gray-800);
}

[data-bs-theme="dark"] .graph-group-header:hover {
    background-color: var(--bs-gray-700);
}

[data-bs-theme="dark"] .graph-action-menu {
    background: var(--bs-dark);
    border-color: var(--bs-gray-700);
}

[data-bs-theme="dark"] .graph-action-menu .menu-item:hover {
    background-color: var(--bs-gray-700);
}
```

#### Task 2.3.2: Command Palette (Optional)
**File:** `assets/javascripts/dag/graph_command_palette.js` (NEW)

```javascript
/**
 * Command Palette for Graph Designer
 * Ctrl/Cmd+P → Quick search and navigate
 */

(function($) {
    'use strict';
    
    class CommandPalette {
        constructor(options) {
            this.onSelect = options.onSelect || function() {};
            this.init();
        }
        
        init() {
            this.createModal();
            this.bindEvents();
        }
        
        createModal() {
            const modal = $(`
                <div class="modal fade" id="commandPaletteModal" tabindex="-1">
                    <div class="modal-dialog modal-dialog-centered">
                        <div class="modal-content">
                            <div class="modal-body p-0">
                                <div class="input-group">
                                    <span class="input-group-text"><i class="ri-search-line"></i></span>
                                    <input type="text" class="form-control command-palette-input" 
                                           placeholder="Search graphs... (Type to filter)">
                                </div>
                                <div class="command-palette-results" style="max-height: 400px; overflow-y: auto;">
                                    <!-- Results rendered here -->
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            `);
            
            $('body').append(modal);
            this.modal = modal;
        }
        
        async search(query) {
            if (!query || query.length < 2) {
                this.renderResults([]);
                return;
            }
            
            try {
                const response = await $.get('source/dag_routing_api.php', {
                    action: 'graph_quick_search',
                    q: query
                });
                
                if (response.ok && response.results) {
                    this.renderResults(response.results);
                }
            } catch (error) {
                console.error('Search failed:', error);
            }
        }
        
        renderResults(results) {
            const container = this.modal.find('.command-palette-results');
            
            if (results.length === 0) {
                container.html('<div class="p-3 text-center text-muted">No results</div>');
                return;
            }
            
            const html = results.map((graph, index) => `
                <div class="command-palette-item ${index === 0 ? 'active' : ''}" 
                     data-graph-id="${graph.id_graph}">
                    <div class="d-flex align-items-center">
                        <span class="graph-icon me-2">📄</span>
                        <div class="flex-grow-1">
                            <div class="fw-bold">${this.escapeHtml(graph.name)}</div>
                            <div class="text-muted small">${this.escapeHtml(graph.code)}</div>
                        </div>
                        <span class="badge bg-secondary">${graph.match_type}</span>
                    </div>
                </div>
            `).join('');
            
            container.html(html);
            
            // Bind click events
            container.find('.command-palette-item').on('click', (e) => {
                const graphId = $(e.currentTarget).data('graph-id');
                this.selectGraph(graphId);
            });
        }
        
        selectGraph(graphId) {
            this.modal.modal('hide');
            this.onSelect(graphId);
        }
        
        show() {
            this.modal.modal('show');
            const input = this.modal.find('.command-palette-input');
            input.val('');
            input.focus();
            
            // Search on input
            input.on('input', (e) => {
                this.search($(e.target).val());
            });
        }
        
        bindEvents() {
            // Keyboard navigation
            this.modal.on('keydown', '.command-palette-input', (e) => {
                if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
                    e.preventDefault();
                    // Navigate results
                } else if (e.key === 'Enter') {
                    e.preventDefault();
                    const active = this.modal.find('.command-palette-item.active');
                    if (active.length) {
                        active.click();
                    }
                } else if (e.key === 'Escape') {
                    this.modal.modal('hide');
                }
            });
        }
        
        escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }
    }
    
    window.CommandPalette = CommandPalette;
    
})(jQuery);
```

---

### Phase 2.4: Integration & Testing (0.5 วัน)

#### Task 2.4.1: Update graph_designer.js Integration
- Remove DataTable initialization
- Initialize GraphSidebar
- Connect events
- Update refresh calls

#### Task 2.4.2: Update View Template
- Replace table HTML with new sidebar structure
- Add CSS file reference
- Add JavaScript file reference

#### Task 2.4.3: Testing Checklist
- [ ] Graph list loads correctly
- [ ] Search works
- [ ] Filters work
- [ ] Click to select works
- [ ] Double-click to open works
- [ ] Favorite toggle works
- [ ] Action menu works
- [ ] Grouping works
- [ ] View mode switching works
- [ ] Command palette works (Ctrl/Cmd+P)
- [ ] Responsive layout works
- [ ] Dark mode works

---

## 📊 Data Flow Diagram

```
User Action → GraphSidebar → API → Database
     ↓              ↓           ↓        ↓
  Click Row    selectGraph()  GET    routing_graph
  Search       searchGraphs()  GET    + JOINs
  Filter       filterGraphs() GET    + WHERE
  Favorite     toggleFavorite() POST  routing_graph_favorite
  
GraphSidebar Event → graph_designer.js → Cytoscape
     ↓                    ↓                  ↓
'graph:selected'    loadGraph(id)    createCytoscapeInstance()
'graph:action'     handleAction()    updateCanvas()
```

---

## 🎯 Success Criteria

### Phase 2.1 Complete เมื่อ:
- ✅ GraphSidebar component แยกออกจาก graph_designer.js
- ✅ Graph list render ได้ถูกต้อง
- ✅ Click/Double-click ทำงาน
- ✅ Search และ Filter ทำงาน

### Phase 2.2 Complete เมื่อ:
- ✅ API `graph_list` return fields เพิ่มเติม (version, updated_by_name, etc.)
- ✅ API `graph_favorite_toggle` ทำงาน
- ✅ Migration `routing_graph_favorite` table สร้างเสร็จ

### Phase 2.3 Complete เมื่อ:
- ✅ UI สวยงาม responsive
- ✅ List View และ Card View ทำงาน
- ✅ Grouping ทำงาน
- ✅ Action menu ทำงาน
- ✅ Command Palette ทำงาน (Ctrl/Cmd+P)

### Phase 2.4 Complete เมื่อ:
- ✅ Integration กับ graph_designer.js เสร็จ
- ✅ ทุก features ทำงานถูกต้อง
- ✅ Performance ดี (รองรับ 100+ กราฟ)
- ✅ Dark mode รองรับ

---

## 🔄 Migration Path

### Step 1: Create New Files (No Breaking Changes)
1. Create `graph_sidebar.js`
2. Create `graph_sidebar.css`
3. Create migration file
4. Test in isolation

### Step 2: Update API (Backward Compatible)
1. Enhance `graph_list` endpoint (keep old fields)
2. Add new endpoints (`graph_favorite_toggle`)
3. Run migration

### Step 3: Refactor graph_designer.js
1. Remove DataTable code
2. Add GraphSidebar initialization
3. Update event handlers
4. Test thoroughly

### Step 4: Update View Template
1. Replace table HTML
2. Add new CSS/JS references
3. Test UI

### Step 5: Cleanup
1. Remove unused DataTable code
2. Update documentation
3. Final testing

---

## 📚 Code Examples

### Example 1: Basic Usage

```javascript
// Initialize Graph Sidebar
const sidebar = new GraphSidebar({
    container: '#graph-sidebar',
    onGraphSelect: (graphId) => {
        console.log('Graph selected:', graphId);
        loadGraph(graphId);
    },
    onGraphAction: (action, graphId) => {
        console.log('Action:', action, 'Graph:', graphId);
        handleAction(action, graphId);
    }
});

// Refresh list
sidebar.refresh();

// Select graph programmatically
sidebar.selectGraph(5);

// Apply filters
sidebar.filterGraphs({
    status: 'published',
    category: 'hatthasilpa',
    favorite: true
});
```

### Example 2: Event Handling

```javascript
// Listen to sidebar events
$('#graph-sidebar').on('graph:selected', (e, graphId) => {
    console.log('Graph selected via event:', graphId);
});

$('#graph-sidebar').on('graph:action', (e, action, graphId) => {
    if (action === 'duplicate') {
        duplicateGraph(graphId);
    }
});
```

---

## 🚀 Next Steps

1. **Review & Approve Plan** - ทีม review แผน
2. **Create Migration** - สร้าง migration สำหรับ favorite table
3. **Implement GraphSidebar** - เขียน graph_sidebar.js
4. **Enhance API** - เพิ่ม fields และ endpoints
5. **Refactor graph_designer.js** - แยกโค้ดออก
6. **Update View** - อัปเดต template
7. **Testing** - ทดสอบทุก features
8. **Documentation** - อัปเดตเอกสาร

---

## 📝 Notes

- **Backward Compatibility:** API ยังรองรับ old format
- **Performance:** ใช้ pagination ถ้ามีกราฟเยอะ (>50)
- **Accessibility:** รองรับ keyboard navigation
- **Internationalization:** ใช้ translation system ที่มีอยู่
- **Browser Support:** Modern browsers (Chrome, Firefox, Safari, Edge)

---

**Status:** 📋 Ready to Implement  
**Estimated Time:** 2-3 days  
**Priority:** High (Improves UX significantly)

---

## 🚀 Enhancements & Best Practices (Recommended)

**Purpose:** เพิ่มรายละเอียดเสริมเล็กๆ แต่ยกระดับประสิทธิภาพ, ความปลอดภัย, และ UX อย่างมาก

### 1. Performance & UX

#### Virtualized List / Infinite Scroll
- **Problem:** เมื่อมีกราฟ > 200 รายการ การ render ทั้งหมดจะช้า
- **Solution:** 
  - ใช้ IntersectionObserver สำหรับ virtualization
  - หรือ infinite scroll + server-side pagination (limit/offset ที่ API มีแล้ว)
  - Render เฉพาะรายการที่มองเห็น

#### Debounce + Cancel Search
- **Problem:** Search ทุก keystroke → เกิด race condition และ request มากเกินไป
- **Solution:**
```javascript
let searchTimer = null;
let inflight = null;

$('.graph-search-input').on('input', function() {
    const q = $(this).val();
    clearTimeout(searchTimer);
    
    searchTimer = setTimeout(() => {
        // Cancel previous request
        if (inflight) inflight.abort();
        
        inflight = $.ajax({
            url: 'source/dag_routing_api.php',
            data: { 
                action: 'graph_list', 
                search: q, 
                limit: 50, 
                offset: 0 
            },
            success: (res) => {
                if (res.ok) {
                    renderGraphs(res.graphs);
                }
            },
            complete: () => { 
                inflight = null; 
            }
        });
    }, 250); // Debounce 250ms
});
```

#### Lazy Thumbnail Loading
- **Problem:** Thumbnail โหลดพร้อมกันทั้งหมด → layout shift และช้า
- **Solution:**
  - ใช้ `loading="lazy"` attribute
  - ขนาดคงที่ (skeleton placeholder) ป้องกัน layout shift
  - Load เฉพาะเมื่อ scroll เข้า viewport

#### Prefetch on Hover
- **Problem:** เปิดกราฟช้าเพราะต้องโหลดข้อมูล
- **Solution:**
  - Hover บนรายการ → prefetch `GET /graphs/:id?projection=summary`
  - Cache 30s
  - ทำให้เปิดเร็วขึ้นเมื่อ click

### 2. State & Routing

#### Deep-link Support
- **Problem:** Reload แล้วกลับไปหน้าแรก ไม่จำ filter/selection
- **Solution:**
```javascript
// Update URL with current state
function updateUrl(params) {
    const u = new URL(location.href);
    Object.entries(params).forEach(([k, v]) => {
        if (v == null) {
            u.searchParams.delete(k);
        } else {
            u.searchParams.set(k, v);
        }
    });
    history.replaceState(null, '', u.toString());
}

// Load state from URL on init
function loadStateFromUrl() {
    const params = new URLSearchParams(location.search);
    return {
        graphId: params.get('graphId'),
        view: params.get('view') || 'list',
        status: params.get('status'),
        q: params.get('q')
    };
}

// Example: ?graphId=12&view=list&status=published&q=bag
```

#### State Persistence (localStorage)
- **Problem:** ปิด browser แล้วกลับมา → สูญเสีย state
- **Solution:**
```javascript
const KEY = `bgerp.graph_sidebar.state.${tenantId}.${userId}`;

function saveState(state) {
    localStorage.setItem(KEY, JSON.stringify({
        ...state,
        savedAt: Date.now()
    }));
}

function loadState() {
    try {
        const stored = localStorage.getItem(KEY);
        if (!stored) return {};
        
        const state = JSON.parse(stored);
        // Expire after 7 days
        if (Date.now() - state.savedAt > 7 * 24 * 60 * 60 * 1000) {
            localStorage.removeItem(KEY);
            return {};
        }
        return state;
    } catch {
        return {};
    }
}

// Save: last selected graph, filters, view mode
```

### 3. Access Control & Multi-tenant

#### Favorite per User (Current)
- ✅ `routing_graph_favorite` table (id_graph, id_member)
- ✅ User-specific favorites

#### Pinned (Org-wide) - Future Enhancement
- **Future:** `routing_graph_pin` table (admin curated)
- Admin สามารถ pin กราฟที่สำคัญให้ทุกคนเห็น

#### Redaction by Role
- **Problem:** Role ต่ำไม่ควรเห็นข้อมูลบางอย่าง
- **Solution:**
```php
// In graph_list endpoint
if (!hasPermission($member, 'hatthasilpa.routing.runtime.view')) {
    // Remove sensitive fields
    unset($graph['runtime_enabled']);
    unset($graph['last_used_at']);
    unset($graph['node_config']); // May contain sensitive info
}
```

### 4. API & Contract

#### Consistent Sort
- **Problem:** ผลลัพธ์สลับไปมาเมื่อมีค่าเดียวกัน
- **Solution:**
```php
// Always include secondary sort
ORDER BY updated_at DESC, id_graph DESC
// หรือ
ORDER BY name ASC, id_graph ASC
```

#### Deterministic Total
- **Problem:** Total ไม่ตรงกับรายการที่แสดง
- **Solution:**
```php
// Calculate total with same filters as data
$countSql = "SELECT COUNT(*) as total FROM routing_graph rg WHERE 1=1";
// Apply same WHERE conditions as main query
$total = $db->fetchOne($countSql, $params, $types)['total'] ?? 0;
```

#### ETag for graph_list
- **Problem:** ไม่สามารถ cache sidebar ได้
- **Solution:**
```php
// Generate ETag from graph list hash
$etag = md5(json_encode([
    'count' => count($graphs),
    'max_updated_at' => max(array_column($graphs, 'updated_at')),
    'filters' => $filters_applied
]));

header('ETag: W/"' . $etag . '"');
header('Cache-Control: public, max-age=30');

// Check If-None-Match
if (isset($_SERVER['HTTP_IF_NONE_MATCH'])) {
    $clientEtag = trim($_SERVER['HTTP_IF_NONE_MATCH'], '"');
    if ($clientEtag === $etag) {
        http_response_code(304);
        exit;
    }
}
```

### 5. Error / Empty States

#### Empty States (Specific Messages)
- **Problem:** ไม่รู้ว่าไม่มีกราฟเลย หรือ filter ไม่เจอ
- **Solution:**
```javascript
function renderEmptyState(filters) {
    const hasFilters = Object.values(filters).some(v => v);
    
    if (hasFilters) {
        return `
            <div class="empty-state">
                <i class="ri-search-line"></i>
                <h6>No graphs match your filters</h6>
                <p>Try adjusting your search or filters</p>
                <button class="btn btn-sm btn-outline-secondary" onclick="clearFilters()">
                    Clear Filters
                </button>
            </div>
        `;
    } else {
        return `
            <div class="empty-state">
                <i class="ri-file-list-line"></i>
                <h6>No graphs yet</h6>
                <p>Create your first routing graph to get started</p>
                <button class="btn btn-sm btn-primary" onclick="createNewGraph()">
                    Create Graph
                </button>
            </div>
        `;
    }
}
```

#### Retry UI
- **Problem:** โหลดล้มเหลว → ไม่มี feedback
- **Solution:**
```javascript
function loadGraphsWithRetry() {
    $.ajax({
        url: 'source/dag_routing_api.php',
        data: { action: 'graph_list' },
        success: (res) => {
            if (res.ok) {
                renderGraphs(res.graphs);
                hideError();
            }
        },
        error: (xhr) => {
            showError(`
                <div class="alert alert-danger">
                    <i class="ri-error-warning-line"></i>
                    Failed to load graphs
                    <button class="btn btn-sm btn-outline-danger ms-2" onclick="loadGraphsWithRetry()">
                        Retry
                    </button>
                </div>
            `);
        }
    });
}
```

### 6. Actions & Safeguards

#### Optimistic UI (Favorite Toggle)
- **Problem:** Toggle favorite ช้าเพราะรอ API
- **Solution:**
```javascript
async function toggleFavorite(graphId) {
    const $icon = $(`.graph-list-item[data-graph-id="${graphId}"] .favorite-star`);
    const wasFavorite = $icon.hasClass('active');
    
    // Optimistic update
    $icon.toggleClass('active');
    
    try {
        const response = await $.post('source/dag_routing_api.php', {
            action: 'graph_favorite_toggle',
            id_graph: graphId
        });
        
        if (!response.ok) {
            throw new Error('Toggle failed');
        }
        
        // Sync with server response
        if (response.is_favorite !== !wasFavorite) {
            $icon.toggleClass('active');
        }
    } catch (error) {
        // Rollback
        $icon.toggleClass('active');
        notifyError('Failed to update favorite', 'Error');
    }
}
```

#### Confirm Dangerous Actions
- **Problem:** ลบ/archive ผิด → เสียข้อมูล
- **Solution:**
```javascript
function confirmDangerousAction(action, graph) {
    Swal.fire({
        title: `${action === 'delete' ? 'Delete' : 'Archive'} Graph?`,
        html: `
            <div class="alert alert-warning">
                <strong>${graph.name}</strong><br>
                <code>${graph.code}</code>
            </div>
            <p>This action cannot be undone.</p>
            <p>Type the graph code to confirm:</p>
            <input type="text" class="form-control" id="confirm-code" placeholder="${graph.code}">
        `,
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#dc3545',
        confirmButtonText: action === 'delete' ? 'Delete' : 'Archive',
        preConfirm: () => {
            const code = document.getElementById('confirm-code').value;
            if (code !== graph.code) {
                Swal.showValidationMessage('Code does not match');
                return false;
            }
            return code;
        }
    }).then((result) => {
        if (result.isConfirmed) {
            performAction(action, graph.id_graph);
        }
    });
}
```

#### Bulk Actions (Future)
- **Future:** Multi-select → archive/delete หลายรายการ
- รองรับ keyboard Shift/⌘ (Cmd) สำหรับ range selection

### 7. Telemetry (Baseline from Day 1)

#### Metrics to Track
```javascript
// Frontend metrics
Metrics.record('ui.graph_list.load_ms', loadDuration);
Metrics.increment('ui.graph_list.search_count');
Metrics.increment('ui.graph_list.favorite_toggle_total');

// Backend metrics (in API)
Metrics.increment('api.graph_list.total');
Metrics.increment('api.graph_list.cache_hit', ['status:304']); // or ['status:200']
Metrics.record('api.graph_list.duration_ms', $duration);
Metrics.increment('api.graph_list.error_total', ['type:' . $errorType]);
```

#### Cache Hit Ratio
```php
// Track 200 vs 304 responses
if ($statusCode === 304) {
    Metrics::increment('api.graph_list.cache_hit', ['status:304']);
} else {
    Metrics::increment('api.graph_list.cache_hit', ['status:200']);
}
```

### 8. Accessibility & i18n

#### Keyboard Navigation
```javascript
$(document).on('keydown', '#graph-sidebar', function(e) {
    const $items = $('.graph-list-item:visible');
    const $active = $items.filter('.active');
    let index = $items.index($active);
    
    switch(e.key) {
        case 'ArrowDown':
            e.preventDefault();
            index = Math.min(index + 1, $items.length - 1);
            $items.eq(index).click();
            break;
        case 'ArrowUp':
            e.preventDefault();
            index = Math.max(index - 1, 0);
            $items.eq(index).click();
            break;
        case 'Enter':
            e.preventDefault();
            $active.dblclick();
            break;
        case 'f':
        case 'F':
            if (!e.ctrlKey && !e.metaKey) {
                e.preventDefault();
                $active.find('.favorite-star').click();
            }
            break;
    }
});
```

#### ARIA Roles
```html
<div class="graph-list-content" role="list">
    <div class="graph-list-item" role="listitem" tabindex="0" aria-label="Graph: ${name}">
        <!-- content -->
    </div>
</div>

<div class="graph-action-menu" role="menu">
    <button class="menu-item" role="menuitem" aria-label="Duplicate graph">
        <!-- content -->
    </button>
</div>
```

#### i18n Keys
```javascript
// Use existing translation system
const t = (key, fallback) => {
    return (window.APP_I18N && window.APP_I18N[key]) || fallback;
};

// In templates
t('routing.graph_list.search_placeholder', 'Search graphs...')
t('routing.graph_list.empty_no_results', 'No graphs match your filters')
t('routing.graph_list.empty_no_graphs', 'No graphs yet')
t('routing.graph_list.confirm_delete', 'Delete Graph?')
```

### 9. Security & Rate Limit

#### Rate Limiting
```php
// In dag_routing_api.php
use BGERP\Helper\RateLimiter;

case 'graph_list':
    RateLimiter::check($member, 120, 60, 'graph_list'); // 120 req/min
    // ... rest of code
    break;

case 'graph_favorite_toggle':
    RateLimiter::check($member, 60, 60, 'graph_favorite_toggle'); // 60 req/min
    // ... rest of code
    break;
```

#### Audit Log
```php
// Log all state-changing actions
function logGraphAction($action, $graphId, $member, $details = []) {
    $db->execute(
        "INSERT INTO audit_log (
            action_type, 
            entity_type, 
            entity_id, 
            user_id, 
            ip_address, 
            correlation_id, 
            details_json, 
            created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())",
        [
            $action, // 'graph_duplicate', 'graph_rename', 'graph_archive', 'graph_delete'
            'routing_graph',
            $graphId,
            $member['id_member'],
            $_SERVER['REMOTE_ADDR'] ?? null,
            $_SERVER['HTTP_X_CORRELATION_ID'] ?? null,
            json_encode($details)
        ],
        'ssiiisss'
    );
}

// Usage
logGraphAction('graph_delete', $graphId, $member, [
    'graph_name' => $graph['name'],
    'graph_code' => $graph['code']
]);
```

### 10. Testing (Additional Test Cases)

#### Test Cases to Add

1. **Search Debounce & Cancel**
   - Search เดียวกันยิงซ้ำเร็วๆ → ไม่มีผลลัพธ์กระโดด
   - Cancel request เก่าเมื่อมี request ใหม่

2. **Filter Rapid Changes**
   - เปลี่ยน filter ต่อเนื่องเร็วๆ → UI ไม่ค้าง
   - State sync ถูกต้อง

3. **ETag 304 Flow**
   - ส่ง `If-None-Match` แล้วได้ 304 → UI ยังใช้ของเดิม
   - Cache ทำงานถูกต้อง

4. **Optimistic Favorite**
   - Toggle favorite → UI อัปเดตทันที
   - Fail → icon rollback + toast error

5. **Pagination Edge Cases**
   - Last page → delete item → คงอยู่หน้าเดิม ไม่เด้งกลับหน้าแรก
   - Empty page → แสดง empty state

6. **Deep-link**
   - เปิดด้วย `?graphId=12&view=list&status=published&q=bag`
   - Sidebar highlight ตรง
   - Filters apply ถูกต้อง

---

## ✅ Acceptance Checklist

### Performance & UX
- [ ] Virtualized/infinite list หรือ server pagination ใช้งานได้ (100+ กราฟไม่หน่วง)
- [ ] Debounce + cancel สำหรับ search/filter (250ms)
- [ ] Lazy thumbnails + skeleton placeholder (ป้องกัน layout shift)
- [ ] Prefetch on hover (cache 30s)

### State & Routing
- [ ] Deep-link support (`?graphId=12&view=list&status=published&q=bag`)
- [ ] State persist (localStorage per tenant/user)
- [ ] URL sync เมื่อเปลี่ยน state

### Access Control
- [ ] Favorite per-user ทำงาน
- [ ] Redaction by role (ซ่อน sensitive fields สำหรับ role ต่ำ)

### API & Contract
- [ ] Consistent sort (secondary sort: `ORDER BY updated_at DESC, id_graph DESC`)
- [ ] Deterministic total (คำนวณด้วยเงื่อนไขเดียวกับรายการ)
- [ ] ETag สำหรับ `graph_list` + 304 tested

### Error / Empty States
- [ ] Empty states แยกข้อความ (ไม่มีกราฟเลย vs ไม่มีผลจาก filter)
- [ ] Retry UI เมื่อโหลดล้มเหลว

### Actions & Safeguards
- [ ] Optimistic favorite + rollback เมื่อ fail
- [ ] Dangerous actions require confirm-with-code (delete/archive)
- [ ] Bulk actions (future: multi-select)

### Telemetry
- [ ] Telemetry baseline ได้ตัวเลขวันแรก:
  - `ui.graph_list.load_ms`
  - `ui.graph_list.search_count`
  - `ui.graph_list.favorite_toggle_total`
  - `api.graph_list.cache_hit_ratio`
  - `api.graph_list.error_total`

### Accessibility & i18n
- [ ] Keyboard navigation (↑/↓ เลื่อน, Enter เปิด, F ⭐ toggle)
- [ ] ARIA roles (list/listitem, menu/menuitem)
- [ ] i18n keys สำหรับข้อความทั้งหมด

### Security & Rate Limit
- [ ] Rate limit: `graph_list` 120 rpm/user, `favorite_toggle` 60 rpm/user
- [ ] Audit log ครบทุก action (duplicate/rename/archive/delete)

### Testing
- [ ] Search debounce + cancel tested
- [ ] Filter rapid changes tested
- [ ] ETag 304 flow tested
- [ ] Optimistic favorite + rollback tested
- [ ] Pagination edge cases tested
- [ ] Deep-link tested

---

## 📊 Performance Targets

- **Load Time:** < 200ms สำหรับ 50 กราฟ
- **Search Response:** < 100ms (with debounce)
- **Cache Hit Ratio:** > 60% (after warm-up)
- **Error Rate:** < 0.1%
- **Memory Usage:** < 50MB สำหรับ 200 กราฟ (with virtualization)

---

## 🎯 Summary

โครงที่ทำไว้ **"พร้อมใช้งานจริง"** แล้ว ✅

เพิ่มชุด enhancements ข้างบน จะทำให้ panel นี้:
- ⚡ **เร็วขึ้น** (virtualization, debounce, prefetch, cache)
- 🔒 **ปลอดภัยขึ้น** (rate limit, audit log, confirm actions)
- 🎨 **เข้าใจง่ายขึ้น** (empty states, error handling, keyboard nav)
- 📈 **พร้อมรองรับการเติบโต** (100+ กราฟแบบไม่ต้องรื้ออีกยาวๆ)

**Estimated Additional Time:** +0.5-1 วัน (สำหรับ enhancements ทั้งหมด)


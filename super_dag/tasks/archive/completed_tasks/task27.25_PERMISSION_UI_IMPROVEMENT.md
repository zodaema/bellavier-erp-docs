# Task 27.25: Permission UI Improvement

> **Status:** ✅ COMPLETED  
> **Priority:** 🟡 MEDIUM (UX improvement)  
> **Created:** 2025-12-08  
> **Completed:** 2025-12-08  
> **Actual Effort:** 0.5 day (Option A - Phase 1)  
> **Future:** Option B (2-3 days), Option C (Enterprise)

---

## 🎯 Executive Summary

### ปัญหาปัจจุบัน

หน้า `admin_roles.php` มี **131+ permissions** ในรายการเดียว:
- ต้องเลื่อนหานาน
- ไม่มี Search
- ไม่มี Select All per Category
- จัดกลุ่มแค่ตาม prefix แรก (ไม่ละเอียดพอ)

### แนวทางที่เลือก

```
Phase 1 (NOW):  Option A - Accordion + Search + Select All
Phase 2 (LATER): Option B - Quick Presets + Tabs
Phase 3 (FUTURE): Option C - Visual Matrix (Enterprise)
```

---

## 📊 Current State Analysis

### Permission Distribution

| Category | Count | Examples |
|----------|-------|----------|
| `work.*` | 25+ | work.queue.view, work.queue.operate |
| `mo.*` | 26 | mo.view, mo.create, mo.cancel |
| `qc.*` | 21 | qc.fail.view, qc.inspect |
| `hatthasilpa.*` | 19 | hatthasilpa.job.ticket |
| `inventory.*` | 13 | inventory.view, inventory.adjust |
| `dashboard.*` | 13 | dashboard.view |
| Others | 30+ | admin.*, routing.*, products.* |
| **TOTAL** | **131+** | **และจะเพิ่มขึ้นอีก** |

### Current UI Pain Points

```
┌─────────────────────────────────────────────────────────────┐
│ ❌ No search                                                 │
│ ❌ No category collapse/expand                               │
│ ❌ No "Select All" per category                              │
│ ❌ No progress indicator per category                        │
│ ❌ Must scroll through 131+ items                            │
│ ❌ Categories split incorrectly (work.queue vs work.center)  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 Phase 1: Option A - Quick Win (1 day)

### Goal

แก้ไข UX หลักโดยไม่ต้อง restructure permission ทั้งระบบ

### Target UI

```
┌─────────────────────────────────────────────────────────────┐
│ 🔍 [Search permissions...                    ]              │
│                                                             │
│ [Expand All] [Collapse All]                  [15/131] ████░ │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ ▼ Manufacturing Orders (mo.*) ──────── [12/26] [☑ All]     │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ ☑ mo.view           View manufacturing orders           │ │
│ │ ☑ mo.create         Create manufacturing orders         │ │
│ │ ☐ mo.cancel         Cancel orders ⚠️                    │ │
│ │ ☑ mo.complete       Complete manufacturing orders       │ │
│ │ ☑ mo.plan           Plan manufacturing orders           │ │
│ │ ...                                                     │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ▸ Quality Control (qc.*) ──────────────── [5/21]           │
│                                                             │
│ ▸ Work Queue (work.queue.*) ───────────── [8/20]           │
│                                                             │
│ ▸ Hatthasilpa (hatthasilpa.*) ─────────── [6/19]           │
│                                                             │
│ ▸ Inventory (inventory.*) ─────────────── [3/13]           │
│                                                             │
│ ▸ Dashboard (dashboard.*) ─────────────── [2/13]           │
│                                                             │
│ ▸ Administration (admin.*) ────────────── [0/6] ⚠️         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Features to Implement

| Feature | Description | Priority |
|---------|-------------|----------|
| **Search Box** | Filter permissions by code or description | 🔴 P1 |
| **Accordion Categories** | Collapse/expand per category | 🔴 P1 |
| **Select All per Category** | Checkbox at category header | 🔴 P1 |
| **Progress Badge** | Show `x/y` per category | 🔴 P1 |
| **Expand/Collapse All** | Buttons at top | 🟡 P2 |
| **Total Progress Bar** | Visual indicator at top | 🟡 P2 |
| **Sticky Header** | Search stays visible when scrolling | 🟡 P2 |
| **Highlight Search Results** | Show matching permissions | 🟢 P3 |

### Category Mapping (Smart Grouping)

```javascript
const CATEGORY_CONFIG = {
    'mo': {
        label: 'Manufacturing Orders',
        icon: 'ri-hammer-line',
        color: 'primary'
    },
    'qc': {
        label: 'Quality Control',
        icon: 'ri-shield-check-line',
        color: 'success'
    },
    'work.queue': {
        label: 'Work Queue',
        icon: 'ri-list-check-2',
        color: 'info'
    },
    'work.center': {
        label: 'Work Centers',
        icon: 'ri-building-2-line',
        color: 'secondary'
    },
    'hatthasilpa': {
        label: 'Hatthasilpa (Atelier)',
        icon: 'ri-scissors-cut-line',
        color: 'warning'
    },
    'inventory': {
        label: 'Inventory Management',
        icon: 'ri-archive-line',
        color: 'dark'
    },
    'dashboard': {
        label: 'Dashboards',
        icon: 'ri-dashboard-line',
        color: 'info'
    },
    'admin': {
        label: 'Administration',
        icon: 'ri-admin-line',
        color: 'danger',
        warning: true  // Show ⚠️ badge
    },
    'products': {
        label: 'Products',
        icon: 'ri-shopping-bag-line',
        color: 'primary'
    },
    'materials': {
        label: 'Materials',
        icon: 'ri-stack-line',
        color: 'secondary'
    },
    'routing': {
        label: 'Routing',
        icon: 'ri-route-line',
        color: 'info'
    },
    'trace': {
        label: 'Traceability',
        icon: 'ri-fingerprint-line',
        color: 'dark'
    },
    'schedule': {
        label: 'Scheduling',
        icon: 'ri-calendar-line',
        color: 'warning'
    },
    '_other': {
        label: 'Other Permissions',
        icon: 'ri-more-line',
        color: 'secondary'
    }
};
```

---

## 📁 Files to Modify

### Phase 1 (Option A)

| File | Changes |
|------|---------|
| `views/admin_roles.php` | Add search box, accordion structure |
| `assets/javascripts/admin/roles.js` | Smart grouping, search filter, accordion logic |
| `assets/stylesheets/admin_roles.css` | (NEW) Custom styles for accordion |

---

## 🛠️ Implementation Details

### 1. HTML Structure (`views/admin_roles.php`)

```html
<!-- Search & Controls -->
<div class="permission-toolbar sticky-top bg-white py-2 border-bottom">
    <div class="row align-items-center">
        <div class="col-md-6">
            <div class="input-group">
                <span class="input-group-text"><i class="ri-search-line"></i></span>
                <input type="text" class="form-control" id="permission-search" 
                       placeholder="Search permissions...">
                <button class="btn btn-outline-secondary" type="button" id="clear-search">
                    <i class="ri-close-line"></i>
                </button>
            </div>
        </div>
        <div class="col-md-6 text-end">
            <button class="btn btn-sm btn-outline-primary me-2" id="expand-all">
                <i class="ri-arrow-down-s-line"></i> Expand All
            </button>
            <button class="btn btn-sm btn-outline-secondary me-2" id="collapse-all">
                <i class="ri-arrow-up-s-line"></i> Collapse All
            </button>
            <span class="badge bg-primary" id="total-progress">0/0</span>
        </div>
    </div>
</div>

<!-- Permissions Container -->
<div id="permissions-accordion" class="accordion mt-3">
    <!-- Categories loaded via JS -->
</div>
```

### 2. JavaScript Logic (`roles.js`)

```javascript
// Smart category extraction
function getCategoryFromCode(code) {
    // Handle multi-level prefixes
    if (code.startsWith('work.queue')) return 'work.queue';
    if (code.startsWith('work.center')) return 'work.center';
    if (code.startsWith('hatthasilpa.job')) return 'hatthasilpa';
    if (code.startsWith('hatthasilpa.routing')) return 'hatthasilpa.routing';
    
    // Default: first segment
    return code.split('.')[0];
}

// Render accordion
function renderPermissionsAccordion(permissions) {
    const grouped = groupByCategory(permissions);
    let html = '';
    
    Object.keys(grouped).sort().forEach((category, index) => {
        const perms = grouped[category];
        const config = CATEGORY_CONFIG[category] || CATEGORY_CONFIG['_other'];
        const checkedCount = perms.filter(p => p.allow == 1).length;
        const isExpanded = index === 0; // First category expanded by default
        
        html += `
        <div class="accordion-item" data-category="${category}">
            <h2 class="accordion-header">
                <button class="accordion-button ${isExpanded ? '' : 'collapsed'}" type="button" 
                        data-bs-toggle="collapse" data-bs-target="#cat-${category.replace('.', '-')}">
                    <i class="${config.icon} me-2 text-${config.color}"></i>
                    <span class="flex-grow-1">${config.label}</span>
                    <span class="badge bg-${config.color} me-2">${checkedCount}/${perms.length}</span>
                    ${config.warning ? '<i class="ri-alert-line text-warning me-2"></i>' : ''}
                    <div class="form-check form-check-inline ms-2" onclick="event.stopPropagation()">
                        <input class="form-check-input category-select-all" type="checkbox" 
                               data-category="${category}" 
                               ${checkedCount === perms.length ? 'checked' : ''}>
                        <label class="form-check-label small">All</label>
                    </div>
                </button>
            </h2>
            <div id="cat-${category.replace('.', '-')}" 
                 class="accordion-collapse collapse ${isExpanded ? 'show' : ''}">
                <div class="accordion-body">
                    ${renderPermissionCheckboxes(perms)}
                </div>
            </div>
        </div>
        `;
    });
    
    $('#permissions-accordion').html(html);
    updateTotalProgress();
    bindAccordionEvents();
}

// Search functionality
$('#permission-search').on('input', debounce(function() {
    const query = $(this).val().toLowerCase();
    
    if (!query) {
        $('.accordion-item').show();
        $('.perm-item').show();
        return;
    }
    
    $('.perm-item').each(function() {
        const code = $(this).data('code').toLowerCase();
        const desc = $(this).data('desc').toLowerCase();
        const matches = code.includes(query) || desc.includes(query);
        $(this).toggle(matches);
        
        if (matches) {
            $(this).closest('.accordion-collapse').addClass('show');
            $(this).closest('.accordion-button').removeClass('collapsed');
        }
    });
    
    // Hide empty categories
    $('.accordion-item').each(function() {
        const hasVisible = $(this).find('.perm-item:visible').length > 0;
        $(this).toggle(hasVisible);
    });
}, 300));
```

### 3. CSS Styles (`admin_roles.css`)

```css
/* Sticky toolbar */
.permission-toolbar {
    z-index: 100;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

/* Accordion customization */
.accordion-button:not(.collapsed) {
    background-color: var(--bs-light);
}

.accordion-button .badge {
    font-size: 0.75rem;
}

/* Permission item */
.perm-item {
    padding: 0.5rem;
    border-radius: 0.25rem;
    transition: background-color 0.2s;
}

.perm-item:hover {
    background-color: var(--bs-light);
}

.perm-item code {
    font-size: 0.85rem;
}

.perm-item .perm-desc {
    font-size: 0.8rem;
    color: var(--bs-gray-600);
}

/* Warning badge for dangerous permissions */
.perm-item.warning {
    border-left: 3px solid var(--bs-warning);
}

/* Search highlight */
.perm-item.search-match {
    background-color: rgba(var(--bs-warning-rgb), 0.1);
}

/* Category progress */
.category-progress {
    height: 4px;
    background-color: var(--bs-gray-200);
    border-radius: 2px;
    overflow: hidden;
}

.category-progress-bar {
    height: 100%;
    background-color: var(--bs-success);
    transition: width 0.3s;
}
```

---

## ✅ Acceptance Criteria

### Phase 1 (Option A)

- [ ] Search box filters permissions in real-time
- [ ] Categories are collapsible (accordion)
- [ ] First category expanded by default, others collapsed
- [ ] "Select All" checkbox per category works
- [ ] Badge shows `x/y` count per category
- [ ] Total progress shows at top
- [ ] Expand All / Collapse All buttons work
- [ ] Dangerous permissions marked with ⚠️
- [ ] Empty categories hidden when searching
- [ ] Existing save_perms API unchanged

---

## 🚀 Phase 2: Option B (Future)

### Features to Add (After Phase 1 stable)

| Feature | Description |
|---------|-------------|
| **Quick Presets** | [Operator] [QC Lead] [Manager] [Read-Only] buttons |
| **Tab Navigation** | [Core] [Production] [QC] [Inventory] [Admin] tabs |
| **Clone Role** | Copy permissions from existing role |
| **Permission Descriptions** | Full descriptions with examples |
| **Warning Icons** | ⚠️ for dangerous permissions like `*.delete`, `*.override` |

### Preset Templates

```javascript
const ROLE_PRESETS = {
    'operator': {
        label: 'Production Operator',
        permissions: [
            'hatthasilpa.job.ticket',
            'hatthasilpa.job.wip.scan',
            'mo.view',
            'mo.start_stop',
            'dashboard.view',
            'qc.inspect'
        ]
    },
    'qc_lead': {
        label: 'QC Lead',
        permissions: [
            'qc.fail.view',
            'qc.fail.manage',
            'qc.inspect',
            'qc.spec.view',
            'hatthasilpa.qc.checklist',
            'mo.view',
            'products.view',
            'dashboard.view'
        ]
    },
    'manager': {
        label: 'Production Manager',
        permissions: [
            // All production permissions
            'mo.*',
            'qc.*',
            'schedule.*',
            'routing.view',
            'dashboard.*'
        ]
    },
    'readonly': {
        label: 'Read-Only Viewer',
        permissions: [
            '*.view'  // All view permissions
        ]
    }
};
```

---

## 🏢 Phase 3: Option C - Enterprise (Future)

### When to Implement

- [ ] Permission naming standardized
- [ ] PermissionEngine v1.0 stable
- [ ] Multiple tenants/factories
- [ ] Need for complex role management

### Visual Matrix Design

```
┌─────────────────────────────────────────────────────────────┐
│                    VIEW   CREATE   EDIT   DELETE   MANAGE   │
├─────────────────────────────────────────────────────────────┤
│ Manufacturing (MO)  ☑       ☑       ☑       ☐       ☐      │
│ Quality Control     ☑       ☐       ☐       ☐       ☐      │
│ Inventory           ☑       ☐       ☐       ☐       ☐      │
│ Products            ☑       ☑       ☑       ☐       ☐      │
│ Work Queue          ☑       ☑       ☑       ☐       ☐      │
└─────────────────────────────────────────────────────────────┘
```

**Requires:** Permission restructuring to `module.action` format

---

## 🔗 Related Documents

- [RBAC System Architecture Audit](../00-audit/20251208_RBAC_SYSTEM_ARCHITECTURE_AUDIT.md)
- [Permission System Audit](../00-audit/20251208_PERMISSION_SYSTEM_AUDIT.md)
- [Task 27.23: Permission Engine Refactor](./task27.23_PERMISSION_ENGINE_REFACTOR.md)

---

## 📊 Priority Matrix

| Phase | Feature | Impact | Effort | Priority |
|-------|---------|--------|--------|----------|
| **1** | Search box | High | Low | 🔴 P1 |
| **1** | Accordion categories | High | Low | 🔴 P1 |
| **1** | Select All per category | High | Low | 🔴 P1 |
| **1** | Progress badges | Medium | Low | 🟡 P2 |
| **2** | Quick Presets | High | Medium | 🟡 P2 |
| **2** | Tab navigation | Medium | Medium | 🟢 P3 |
| **3** | Visual Matrix | High | High | 🟢 Future |

---

## 🎯 Expected Outcome

**Before:**
- ต้องเลื่อนหา 131 permissions
- ต้องติ๊กทีละอัน 20-30 ครั้ง
- ไม่รู้ว่า role นี้เปิดกี่ %

**After Phase 1:**
- Search หา permission ได้ทันที
- Select All per category ลด click 90%
- เห็น progress x/y ทุก category
- Accordion collapse ทำให้ UI สะอาด


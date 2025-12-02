# Phase 8.3: Version Management & Graph Preview - Integration Notes

**Date:** 2025-11-19  
**Status:** ✅ Complete - Requires View Integration

---

## 🎯 Summary

Phase 8.3 adds complete version management and graph visualization features to product-graph bindings:

1. **Compare Versions** - Side-by-side comparison of graph versions
2. **Graph Preview** - Interactive graph visualization with Cytoscape.js
3. **Pin Version** - Update pinned graph versions
4. **Open in Designer** - Quick access to Graph Designer

---

## ✅ Completed Components

### Backend APIs
- ✅ `dag_routing_api.php` - `compare_versions` endpoint
- ✅ `products.php` - `update_version_pin` endpoint

### Frontend Modules
- ✅ `version_comparison.js` (449 lines) - Version comparison UI
- ✅ `product_graph_binding.js` (enhanced) - Uses **GraphViewer** for preview
- ❌ `graph_preview.js` - **Removed** (replaced with GraphViewer integration)

### Documentation
- ✅ `PHASE8_QUICK_REFERENCE.md` updated
- ✅ `CHANGELOG.md` updated

---

## ⚠️ Required Integration Steps

### 1. JavaScript Modules Already Loaded

**Status:** ✅ **Already configured in `page/products.php`**

```php
$page_detail['jquery'][12] = 'https://unpkg.com/cytoscape@3.28.1/dist/cytoscape.min.js';
$page_detail['jquery'][13] = 'assets/javascripts/dag/graph_viewer.js';  // Existing
$page_detail['jquery'][14] = 'assets/javascripts/products/products.js';
$page_detail['jquery'][15] = 'assets/javascripts/products/version_comparison.js';  // Phase 8.3
$page_detail['jquery'][16] = 'assets/javascripts/products/product_graph_binding.js';
```

**Implementation Decision:**
- ✅ Uses **GraphViewer** (existing, stable component)
- ❌ **Removed** `graph_preview.js` (didn't render correctly)
- ✅ Graph preview now calls `showGraphPreviewWithViewer()` which uses GraphViewer

---

## 🧪 Testing Checklist

Once Cytoscape.js is loaded, test the following:

### Test 1: Compare Versions
1. Open Product management
2. Click "Manage Graph" on a product with active binding
3. If the graph has newer versions, you should see an alert banner
4. Click "Compare Versions" button
5. Modal should show:
   - Summary statistics
   - Node changes (added/removed/modified)
   - Edge changes (added/removed)
   - "Pin to Version" button

### Test 2: Graph Preview
1. In Product Graph Binding modal
2. Click "Preview Graph" button
3. Modal should show:
   - Interactive Cytoscape.js graph
   - Zoom/pan controls
   - Node click details
   - Colored nodes by type (start=green, end=red, operation=blue, decision=orange)

### Test 3: Pin Version
1. In Version Comparison modal
2. Click "Pin to Version {v2}" button
3. Confirm prompt
4. Should see success notification
5. Binding status should update to show pinned version

### Test 4: Open in Designer
1. Click "Open in Designer" button
2. Should open Graph Designer in new tab
3. Graph should load correctly

---

## 🔍 Troubleshooting

### Issue: "Cytoscape is not defined"
**Solution:** Cytoscape.js CDN not loaded. Add the `<script>` tag as shown above.

### Issue: "Version comparison module not loaded"
**Solution:** Ensure `version_comparison.js` is loaded before `product_graph_binding.js`

### Issue: "Graph preview module not loaded"
**Solution:** Ensure `graph_preview.js` is loaded before `product_graph_binding.js`

### Issue: Graph not rendering
**Check:**
1. Browser console for errors
2. Cytoscape.js loaded (check Network tab)
3. API response contains valid node/edge data

---

## 📝 API Endpoints Reference

### Compare Versions
```
GET /source/dag_routing_api.php?action=compare_versions
    &id_graph={graphId}
    &v1={version1}
    &v2={version2}
```

### Update Version Pin
```
POST /source/products.php
    action=update_version_pin
    id_binding={bindingId}
    graph_version_pin={version}
```

**Permission:** `product.graph.pin_version`

---

## 🎨 UI Features

### New Buttons in Binding Status
When a product has an active graph binding, the following buttons appear:

1. **Compare Versions** (conditional - only shows if new version available)
   - Yellow warning badge
   - Shows version comparison modal

2. **Preview Graph**
   - Blue outline button
   - Opens Cytoscape.js visualization modal

3. **Open in Designer**
   - Info button
   - Opens `routing_graph_designer` in new tab

### New Version Alert
When `graph_version_pin` is set and a newer `graph_version_latest` exists:
- Yellow alert banner appears
- Shows current pinned version and latest available version
- "Compare Versions" button to see differences

---

## 🔐 Permissions

### New Permission
- `product.graph.pin_version` - Required to change pinned version

### Existing Permissions (still apply)
- `product.graph.manage` - Manage graph bindings
- `product.graph.view` - View graph bindings

---

## 📦 Dependencies

### Frontend
- **jQuery** - Already included
- **Bootstrap 5** - Already included
- **Cytoscape.js 3.28.1** - ⚠️ **MUST ADD** (via CDN)

### Backend
- PHP 7.4+
- MySQL/MariaDB
- Existing `ProductGraphBindingHelper` class

---

## 🚀 Next Steps (Phase 8.4)

After integration is complete and tested, Phase 8.4 will add:

1. Usage Statistics Dashboard
2. Audit Trail Viewer
3. CSV Export for binding history
4. Metrics tracking

---

## 📞 Support

If you encounter issues:
1. Check browser console for JavaScript errors
2. Verify all files are loaded (Network tab)
3. Confirm API endpoints return valid JSON
4. Check permissions for current user

For detailed API documentation, see:
- `docs/implementation/PHASE8_QUICK_REFERENCE.md`
- `CHANGELOG.md` (Phase 8.3 section)

---

**End of Integration Notes**

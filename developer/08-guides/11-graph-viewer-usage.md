# GraphViewer Usage Guide

## Overview
`GraphViewer` เป็น standalone component สำหรับแสดง routing graphs ที่สามารถใช้ได้ในทุกหน้าโดยไม่ต้องพึ่งพา `product_graph_binding.js`

## การโหลด

### Step 1: โหลด Cytoscape.js
```php
// ใน page/{your_page}.php
$page_detail['jquery'][N] = 'https://unpkg.com/cytoscape@3.28.1/dist/cytoscape.min.js';
```

### Step 2: โหลด GraphViewer
```php
// ใน page/{your_page}.php
$page_detail['jquery'][N+1] = domain::getDomain().'/assets/javascripts/dag/graph_viewer.js';
```

### Step 3: โหลด JavaScript ของคุณเอง (optional)
```php
// ใน page/{your_page}.php
$page_detail['jquery'][N+2] = 'assets/javascripts/{module}/{your_file}.js';
```

## ตัวอย่างการใช้งาน

```javascript
// ในไฟล์ JavaScript ของคุณ
(function($) {
  'use strict';
  
  // ตรวจสอบว่า GraphViewer โหลดแล้วหรือยัง
  if (typeof GraphViewer === 'undefined') {
    console.error('GraphViewer is not loaded. Make sure graph_viewer.js is included.');
    return;
  }
  
  // สร้าง viewer instance
  const viewer = GraphViewer.create({
    container: '#my-graph-canvas', // ID ของ container element
    nodes: [
      {
        id_node: 1,
        node_code: 'START',
        node_name: 'เริ่มงาน',
        node_type: 'start',
        position_x: 100,
        position_y: 100
      },
      // ... nodes อื่นๆ
    ],
    edges: [
      {
        id_edge: 1,
        from_node_code: 'START',
        to_node_code: 'OP1',
        edge_type: 'normal'
      },
      // ... edges อื่นๆ
    ],
    options: {
      minZoom: 0.5,
      maxZoom: 2,
      allowSelection: false,
      useNodeCode: true, // ใช้ node_code สำหรับ edge mapping
      fitPadding: 50
    }
  });
  
  // อัปเดต graph data ทีหลัง
  viewer.update({
    nodes: [...],
    edges: [...]
  });
  
  // Fit graph ให้พอดีกับ viewport
  viewer.fit(50);
  
  // ดึง Cytoscape instance สำหรับใช้งานขั้นสูง
  const cy = viewer.getInstance();
  
  // ทำลาย viewer เมื่อเสร็จสิ้น
  viewer.destroy();
  
})(jQuery);
```

## API Reference

### GraphViewer.create(config)
สร้าง GraphViewer instance ใหม่

**Parameters:**
- `config.container` (string|HTMLElement): ID ของ container element หรือ element โดยตรง
- `config.nodes` (array): Array ของ node objects
- `config.edges` (array): Array ของ edge objects
- `config.options` (object, optional): ตัวเลือกการตั้งค่า

**Options:**
- `minZoom` (number, default: 0.5): ระดับ zoom ต่ำสุด
- `maxZoom` (number, default: 2): ระดับ zoom สูงสุด
- `allowSelection` (boolean, default: false): เปิดใช้งานการเลือก node/edge
- `useNodeCode` (boolean, default: false): ใช้ node_code สำหรับ edge mapping
- `fitPadding` (number, default: 50): padding สำหรับ fit operation

### Methods

#### viewer.update(graphData)
อัปเดต graph data และ render ใหม่

#### viewer.fit(padding)
Fit graph ให้พอดีกับ viewport พร้อม padding (ถ้าระบุ)

#### viewer.getInstance()
ดึง Cytoscape instance สำหรับใช้งานขั้นสูง

#### viewer.destroy()
ทำลาย viewer instance และทำความสะอาด resources

## Node Data Format

```javascript
{
  id_node: 1,
  node_code: 'START',
  node_name: 'เริ่มงาน',
  node_type: 'start', // start|operation|decision|qc|end|...
  position_x: 100,
  position_y: 100,
  estimated_minutes: 30,
  // ... fields อื่นๆ (optional)
}
```

## Edge Data Format

**เมื่อ useNodeCode: true:**
```javascript
{
  id_edge: 1,
  from_node_code: 'START',
  to_node_code: 'OP1',
  edge_type: 'normal' // normal|conditional|rework
}
```

**เมื่อ useNodeCode: false:**
```javascript
{
  id_edge: 1,
  from_node_id: 1,
  to_node_id: 2,
  edge_type: 'normal'
}
```

## ตัวอย่าง: ใช้กับ API

```javascript
// ดึง graph data จาก API
$.getJSON('source/dag_routing_api.php', {
  action: 'graph_viewer',
  id_graph: 7
}, function(resp) {
  if (resp.ok && resp.nodes) {
    const viewer = GraphViewer.create({
      container: '#graph-canvas',
      nodes: resp.nodes,
      edges: resp.edges,
      options: {
        useNodeCode: true,
        fitPadding: 50
      }
    });
  }
});
```

## Dependencies

- **Cytoscape.js 3.28.1+** (ต้องโหลดแยก)
- **ไม่ต้องใช้ jQuery** (แต่สามารถใช้ร่วมกับ jQuery ได้)
- **ไม่มี dependencies อื่นๆ**

## สิ่งสำคัญ

✅ **GraphViewer เป็น component ที่อิสระจาก `product_graph_binding.js`**
✅ **สามารถใช้ในทุกหน้าที่ต้องการแสดง graph visualization**
✅ **ใช้ styling standards เดียวกับ Graph Designer**
✅ **Auto-fit viewport เมื่อแสดงครั้งแรก**

## ตัวอย่างการใช้งานจริง

### ตัวอย่างที่ 1: ใช้ในหน้า Job Ticket
```php
// page/job_ticket.php
$page_detail['jquery'][10] = 'https://unpkg.com/cytoscape@3.28.1/dist/cytoscape.min.js';
$page_detail['jquery'][11] = domain::getDomain().'/assets/javascripts/dag/graph_viewer.js';
$page_detail['jquery'][12] = 'assets/javascripts/job_ticket/graph_preview.js';
```

```javascript
// assets/javascripts/job_ticket/graph_preview.js
(function($) {
  'use strict';
  
  function showGraphPreview(graphId) {
    $.getJSON('source/dag_routing_api.php', {
      action: 'graph_viewer',
      id_graph: graphId
    }, function(resp) {
      if (resp.ok && resp.nodes) {
        const viewer = GraphViewer.create({
          container: '#job-ticket-graph-canvas',
          nodes: resp.nodes,
          edges: resp.edges,
          options: {
            useNodeCode: true,
            fitPadding: 50
          }
        });
      }
    });
  }
  
  // ... rest of your code
})(jQuery);
```

### ตัวอย่างที่ 2: ใช้ในหน้า MO
```php
// page/mo.php
$page_detail['jquery'][8] = 'https://unpkg.com/cytoscape@3.28.1/dist/cytoscape.min.js';
$page_detail['jquery'][9] = domain::getDomain().'/assets/javascripts/dag/graph_viewer.js';
```

```javascript
// assets/javascripts/mo/graph_display.js
(function($) {
  'use strict';
  
  let moGraphViewer = null;
  
  function displayMOGraph(moId) {
    // Fetch graph from MO
    $.getJSON('source/mo.php', {
      action: 'get_graph',
      id_mo: moId
    }, function(resp) {
      if (resp.ok && resp.graph_id) {
        // Fetch graph data
        $.getJSON('source/dag_routing_api.php', {
          action: 'graph_viewer',
          id_graph: resp.graph_id
        }, function(graphResp) {
          if (graphResp.ok && graphResp.nodes) {
            // Destroy existing viewer
            if (moGraphViewer) {
              moGraphViewer.destroy();
            }
            
            // Create new viewer
            moGraphViewer = GraphViewer.create({
              container: '#mo-graph-canvas',
              nodes: graphResp.nodes,
              edges: graphResp.edges,
              options: {
                useNodeCode: true,
                fitPadding: 50
              }
            });
          }
        });
      }
    });
  }
  
  // ... rest of your code
})(jQuery);
```

## สรุป

**ไม่ต้องโหลด `product_graph_binding.js`** หากต้องการใช้ GraphViewer ในหน้าอื่นๆ เพียงแค่:

1. โหลด Cytoscape.js
2. โหลด `graph_viewer.js`
3. เรียกใช้ `GraphViewer.create()` ใน JavaScript ของคุณ

GraphViewer เป็น standalone component ที่ออกแบบมาให้ใช้ซ้ำได้ในทุกหน้าโดยไม่ต้องพึ่งพาไฟล์อื่นๆ


# Chapter 14 — PWA/Frontend Integration

**Last Updated:** November 19, 2025  
**Purpose:** Document how backend links to the PWA and frontend integration patterns  
**Audience:** Frontend developers, PWA developers, full-stack developers

---

## Overview

This chapter explains how the Bellavier Group ERP backend integrates with the Progressive Web App (PWA) and frontend interfaces. It covers API response conventions, QR scanning workflows, mobile UX constraints, and frontend-backend communication patterns.

**Key Topics:**
- How backend links to the PWA
- QR scanning workflows
- Mobile UX constraints
- API → PWA response conventions
- Frontend integration patterns

**Current State:**
- ✅ Work Queue system functional (Hatthasilpa only)
- ✅ PWA QR scanning implemented (Classic only)
- ✅ Mobile-optimized UI
- ⚠️ PWA scan API needs refactor (future task)

**⚠️ Critical Separation:**
- **PWA Scanners = Classic Line only** - Simple scan in/out for job tickets
- **Work Queue = Hatthasilpa Line only** - Full token management interface
- These are **completely separate systems** for different production lines

---

## Key Concepts

### 1. Backend-PWA Communication

**API Endpoints:**
- Backend provides REST APIs
- PWA consumes APIs via AJAX/fetch
- Standardized JSON format (`{ok: true/false}`)

**Response Format:**
```json
{
  "ok": true,
  "data": {...},
  "meta": {
    "ai_trace": "...",
    "correlation_id": "..."
  }
}
```

**Error Format:**
```json
{
  "ok": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Error message"
  }
}
```

### 2. QR Scanning Workflows

**Scan Flow:**
```
Mobile Device
    ↓
Scan QR Code/Barcode
    ↓
Send to API (pwa_scan_api.php or dag_token_api.php)
    ↓
Resolve Code
    ├── Token Code → Token operations
    ├── Job Code → Job operations
    ├── Product Code → Product operations
    └── Material Code → Material operations
    ↓
Execute Action
    ↓
Return Result (JSON)
```

**Supported Codes:**
- Token codes (TOTE-001, TOTE-002, etc.)
- Job ticket codes
- Product codes
- Material codes
- Serial numbers

### 3. Mobile UX Constraints

**Constraints:**
- Small screen size
- Touch interface
- Limited bandwidth
- Offline capability (PWA)
- Battery optimization

**Design Principles:**
- ✅ Large touch targets (≥ 44px)
- ✅ Minimal data transfer
- ✅ Offline-first approach
- ✅ Fast loading
- ✅ Clear feedback

---

## Core Components

### Work Queue System (Hatthasilpa Only)

**⚠️ Important:** Work Queue is **Hatthasilpa Line only**. Classic Line uses PWA scanners, not Work Queue.

**Frontend:** `assets/javascripts/pwa_scan/work_queue.js`  
**Backend:** `source/worker_token_api.php` (work queue endpoints)

**Features:**
- Display tokens grouped by work station
- Real-time timer (updates every second)
- Start/Pause/Resume/Complete workflows
- Help Mode (Assist/Replace)
- Visual indicators

**API Endpoints:**
- `get_work_queue` - Get work queue for operator
- `start_token` - Start work on token
- `pause_token` - Pause work
- `resume_token` - Resume work
- `complete_token` - Complete work

**Example:**
```javascript
// Frontend: Get work queue
$.post('source/dag_token_api.php', {
    action: 'get_work_queue'
}, function(response) {
    if (response.ok) {
        // Display work queue
        displayWorkQueue(response.data);
    } else {
        notifyError(response.error.message);
    }
}, 'json');
```

### QR Scanning Integration (Classic Line Only)

**⚠️ Important:** PWA scanning is **Classic Line only**. Hatthasilpa uses Work Queue, not PWA.

**Frontend:** PWA scan interface  
**Backend:** `source/pwa_scan_api.php` (legacy, Classic only)

**Workflow (Classic Line):**
1. User scans QR code (Classic job ticket)
2. Frontend sends code to `pwa_scan_api.php`
3. API resolves code to Classic job ticket
4. API returns job ticket information
5. Frontend displays job details
6. User performs action (scan in/out)
7. Frontend sends action to `pwa_scan_api.php`
8. API executes action (creates `wip_log` entry)
9. API returns result
10. Frontend updates UI

**Example:**
```javascript
// Scan QR code (Classic Line only)
function scanQRCode() {
    // Use device camera or barcode scanner
    const code = getScannedCode();
    
    // Send to PWA scan API (Classic only)
    $.post('source/pwa_scan_api.php', {
        action: 'lookup',
        code: code
    }, function(response) {
        if (response.ok) {
            // Display Classic job ticket
            displayJobTicket(response.data);
        } else {
            notifyError(response.error.message);
        }
    }, 'json');
}
```

**⚠️ Note:**
- PWA scanning is for **Classic job tickets only**
- Hatthasilpa tokens are managed via **Work Queue** (`worker_token_api.php`), not PWA

### API Response Conventions

#### Success Response

**Format:**
```json
{
  "ok": true,
  "data": {
    "id": 123,
    "name": "Product Name",
    "status": "active"
  },
  "meta": {
    "ai_trace": "abc123",
    "correlation_id": "xyz789"
  }
}
```

**Frontend Handling:**
```javascript
$.post('source/api.php', {action: 'get'}, function(response) {
    if (response.ok) {
        // Success
        const data = response.data;
        // Use data
    } else {
        // Error
        notifyError(response.error.message);
    }
}, 'json');
```

#### Error Response

**Format:**
```json
{
  "ok": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Error message"
  }
}
```

**Frontend Handling:**
```javascript
$.post('source/api.php', {action: 'save'}, function(response) {
    if (response.ok) {
        notifySuccess('Saved successfully');
    } else {
        // Handle error
        const errorCode = response.error.code;
        const errorMessage = response.error.message;
        
        // Show user-friendly message
        notifyError(errorMessage);
        
        // Handle specific error codes
        if (errorCode === 'VALIDATION_ERROR') {
            // Show validation errors
        } else if (errorCode === 'FORBIDDEN') {
            // Show permission error
        }
    }
}, 'json');
```

### Frontend Integration Patterns

#### 1. AJAX Request Pattern

**Standard Pattern:**
```javascript
$.post('source/api.php', {
    action: 'action_name',
    data: requestData
}, function(response) {
    if (response.ok) {
        // Success handling
        handleSuccess(response.data);
    } else {
        // Error handling
        handleError(response.error);
    }
}, 'json').fail(function(jqXHR, textStatus, errorThrown) {
    // Network error
    notifyError('Connection error: ' + textStatus);
});
```

#### 2. DataTable Integration

**Server-Side DataTable:**
```javascript
const table = $('#table-id').DataTable({
    ajax: {
        url: 'source/api.php',
        type: 'POST',
        data: function(d) {
            d.action = 'list';
            d.custom_param = value;
            return d; // MUST return!
        }
    },
    columns: [
        { data: 'id_field' }, // Primary key (REQUIRED)
        { data: 'name' },
        { 
            data: null, 
            render: function(data, type, row) {
                return renderCustomColumn(row);
            }
        }
    ],
    serverSide: true,
    processing: true
});
```

#### 3. Real-Time Updates

**Timer Updates:**
```javascript
// Update timer every second
setInterval(function() {
    $.post('source/dag_token_api.php', {
        action: 'get_token_status',
        token_id: currentTokenId
    }, function(response) {
        if (response.ok) {
            updateTimer(response.data.work_seconds);
        }
    }, 'json');
}, 1000);
```

---

## Developer Responsibilities

### When Working with Frontend

**MUST:**
- ✅ Use standard JSON format (`{ok: true/false}`)
- ✅ Provide clear error messages
- ✅ Handle network errors gracefully
- ✅ Optimize for mobile (minimal data transfer)
- ✅ Test on mobile devices

**DO NOT:**
- ❌ Return non-standard JSON format
- ❌ Expose internal errors to users
- ❌ Send large payloads unnecessarily
- ❌ Ignore mobile UX constraints

### When Working with PWA

**MUST:**
- ✅ Support offline mode (where possible)
- ✅ Use service worker for caching
- ✅ Optimize for mobile performance
- ✅ Provide clear user feedback
- ✅ Handle network errors gracefully

**DO NOT:**
- ❌ Assume always-online
- ❌ Ignore offline scenarios
- ❌ Send sensitive data in requests
- ❌ Ignore battery optimization

---

## Common Pitfalls

### 1. Wrong Response Format Check

**Problem:**
```javascript
// ❌ Wrong: Checking wrong key
if (response.success) { ... }
```

**Solution:**
```javascript
// ✅ Correct: Check 'ok' key
if (response.ok) { ... }
```

### 2. Missing Return in DataTable

**Problem:**
```javascript
// ❌ Wrong: Missing return
data: function(d) {
    d.action = 'list';
    // Missing return!
}
```

**Solution:**
```javascript
// ✅ Correct: Return data object
data: function(d) {
    d.action = 'list';
    return d; // MUST return!
}
```

### 3. Not Handling Network Errors

**Problem:**
```javascript
// ❌ Wrong: No error handling
$.post('source/api.php', data, function(response) {
    // No .fail() handler
});
```

**Solution:**
```javascript
// ✅ Correct: Handle errors
$.post('source/api.php', data, function(response) {
    if (response.ok) { ... }
}, 'json').fail(function(jqXHR, textStatus, errorThrown) {
    notifyError('Connection error: ' + textStatus);
});
```

---

## Examples

### Example 1: Work Queue Integration

```javascript
// Get work queue
function loadWorkQueue() {
    $.post('source/dag_token_api.php', {
        action: 'get_work_queue'
    }, function(response) {
        if (response.ok) {
            const tokens = response.data.tokens;
            displayWorkQueue(tokens);
        } else {
            notifyError(response.error.message);
        }
    }, 'json').fail(function() {
        notifyError('Failed to load work queue');
    });
}

// Start token
function startToken(tokenId) {
    $.post('source/dag_token_api.php', {
        action: 'start_token',
        token_id: tokenId
    }, function(response) {
        if (response.ok) {
            notifySuccess('Work started');
            loadWorkQueue(); // Refresh
        } else {
            notifyError(response.error.message);
        }
    }, 'json');
}
```

### Example 2: QR Code Scanning

```javascript
// Scan and resolve
function scanAndResolve() {
    const code = getScannedCode();
    
    $.post('source/dag_token_api.php', {
        action: 'lookup',
        code: code
    }, function(response) {
        if (response.ok) {
            const entity = response.data;
            if (entity.type === 'token') {
                showTokenDetails(entity.token);
            } else if (entity.type === 'job') {
                showJobDetails(entity.job);
            }
        } else {
            notifyError(response.error.message);
        }
    }, 'json');
}
```

### Example 3: Real-Time Timer

```javascript
// Timer update
let timerInterval;

function startTimer(tokenId) {
    timerInterval = setInterval(function() {
        $.post('source/dag_token_api.php', {
            action: 'get_token_status',
            token_id: tokenId
        }, function(response) {
            if (response.ok) {
                const workSeconds = response.data.work_seconds;
                updateTimerDisplay(workSeconds);
            }
        }, 'json');
    }, 1000);
}

function stopTimer() {
    if (timerInterval) {
        clearInterval(timerInterval);
    }
}
```

---

## Reference Documents

### PWA Documentation

- **Work Queue JS**: `assets/javascripts/pwa_scan/work_queue.js` - Frontend work queue
- **PWA Scan API**: `source/pwa_scan_api.php` - Legacy scanning API
- **DAG Token API**: `source/dag_token_api.php` - Token operations API

### Related Chapters

- **Chapter 6**: API Development Guide
- **Chapter 8**: Traceability / Token System
- **Chapter 9**: PWA Scan System

---

## Future Expansion

### Planned Enhancements

1. **Enhanced PWA Features**
   - Offline-first architecture
   - Background sync
   - Push notifications

2. **Advanced Scanning**
   - Batch scanning
   - Image recognition
   - Voice commands

3. **Real-Time Updates**
   - WebSocket integration
   - Live status updates
   - Real-time notifications

---

**Previous Chapter:** [Chapter 13 — Refactor & Contribution Guide](../chapters/13-refactor-contribution-guide.md)  
**Next Chapter:** [Chapter 15 — AI Developer Guidelines](../chapters/15-ai-developer-guidelines.md)


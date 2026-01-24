# Timer Data Attributes Contract

**Date:** 2025-12-09
**Purpose:** Document the contract between TokenCard renderer and BGTimeEngine
**Status:** ✅ **VERIFIED**

---

## 📋 Overview

This document defines the **required data attributes** that must be present on timer elements for BGTimeEngine to function correctly.

**Single Source of Truth:** `assets/javascripts/pwa_scan/work_queue_timer.js` (BGTimeEngine)

---

## 🔧 BGTimeEngine Requirements

### Required Attributes (MUST HAVE)

| Attribute | Type | Purpose | Example |
|-----------|------|---------|---------|
| `data-token-id` | string/number | Unique identifier for the token/session | `"1234"` |
| `data-status` | string | Timer status | `"active"` \| `"paused"` \| `"completed"` \| `"none"` \| `"unknown"` |
| `data-work-seconds-sync` | number | Work seconds from server at last_server_sync | `1250` |
| `data-last-server-sync` | ISO8601 string | Server time when work_seconds was calculated | `"2025-12-08T10:20:00Z"` |

### Optional Attributes (Nice to Have)

| Attribute | Type | Purpose | Example |
|-----------|------|---------|---------|
| `data-started` | ISO8601 string | Session start time (for display) | `"2025-12-08T10:00:00Z"` |
| `data-pause-min` | number | Total pause minutes (for display) | `5` |
| `data-work-seconds-base` | number | Base work seconds from DB (for display) | `1200` |

---

## ✅ TokenCard Implementation

### Current Implementation (`TokenCardParts.js::renderTimer()`)

```javascript
// Active timer with BGTimeEngine data attributes
html += `
    <span class="work-timer work-timer-active" 
          data-token-id="${state.id}"
          data-started="${session.started_at}"
          data-pause-min="${time.totalPauseMinutes}"
          data-work-seconds-base="${time.baseWorkSeconds}"
          data-work-seconds-sync="${time.workSeconds}"
          data-last-server-sync="${time.lastServerSync || ''}"
          data-status="active">
        <span class="timer-display">${formatWorkSeconds(time.workSeconds)}</span>
    </span>
`;
```

### Verification Status

| BGTimeEngine Requirement | TokenCard Provides | Status |
|-------------------------|-------------------|--------|
| `data-token-id` | ✅ `state.id` | ✅ **VERIFIED** |
| `data-status` | ✅ `"active"` | ✅ **VERIFIED** |
| `data-work-seconds-sync` | ✅ `time.workSeconds` | ✅ **VERIFIED** |
| `data-last-server-sync` | ✅ `time.lastServerSync` | ✅ **VERIFIED** |

**Result:** ✅ **ALL REQUIRED ATTRIBUTES PRESENT**

---

## 📊 Data Flow

### 1. API Response → TokenCardState

```javascript
// TokenCardState.js::computeTokenState()
time: {
    workSeconds: timer?.work_seconds || 0,
    baseWorkSeconds: timer?.base_work_seconds || 0,
    lastServerSync: timer?.last_server_sync || null,
    timerStatus: timer?.status || 'stopped',
    startedAt: session?.started_at || null,
    resumedAt: session?.resumed_at || null,
    pausedAt: session?.paused_at || null,
    totalPauseMinutes: session?.total_pause_minutes || 0
}
```

### 2. TokenCardState → TokenCardParts

```javascript
// TokenCardParts.js::renderTimer(state, options)
const time = state.time;
const session = state.session;

// Extract values:
- state.id → data-token-id
- time.workSeconds → data-work-seconds-sync
- time.lastServerSync → data-last-server-sync
- "active" → data-status (hardcoded for active timers)
```

### 3. TokenCardParts → DOM

```html
<span class="work-timer work-timer-active" 
      data-token-id="1234"
      data-work-seconds-sync="1250"
      data-last-server-sync="2025-12-08T10:20:00Z"
      data-status="active">
    <span class="timer-display">00:20:50</span>
</span>
```

### 4. DOM → BGTimeEngine

```javascript
// BGTimeEngine.registerTimerElement(spanEl)
const tokenId = spanEl.dataset.tokenId; // "1234"
const status = spanEl.dataset.status; // "active"
const syncSeconds = parseInt(spanEl.dataset.workSecondsSync); // 1250
const lastSync = spanEl.dataset.lastServerSync; // "2025-12-08T10:20:00Z"
```

---

## 🔍 Timer Calculation Logic

### BGTimeEngine Calculation (from `work_queue_timer.js`)

```javascript
// For active timers:
displaySeconds = syncSeconds + (now - lastSync) in seconds

// For paused/completed timers:
displaySeconds = syncSeconds (no drift, static value)
```

### Example

```javascript
// Server snapshot (at 10:20:00):
work_seconds = 1250 (20 minutes 50 seconds)
last_server_sync = "2025-12-08T10:20:00Z"

// Client calculation (at 10:20:15):
now = new Date("2025-12-08T10:20:15Z")
elapsed = (now - lastSync) = 15 seconds
displaySeconds = 1250 + 15 = 1265 (20 minutes 65 seconds = 21 minutes 5 seconds)
```

---

## ⚠️ Common Issues & Solutions

### Issue 1: Missing `data-last-server-sync`

**Symptom:** Timer doesn't update, shows static value

**Solution:** Ensure `time.lastServerSync` is set from API response:
```javascript
lastServerSync: timer?.last_server_sync || null
```

### Issue 2: Wrong `data-status` Value

**Symptom:** Timer doesn't register with BGTimeEngine

**Solution:** Use exact values: `"active"`, `"paused"`, `"completed"`, `"none"`, `"unknown"`

### Issue 3: `data-token-id` Mismatch

**Symptom:** Timer registered but doesn't update (duplicate token IDs)

**Solution:** Ensure `state.id` is unique and matches token ID from API

---

## ✅ Verification Checklist

Before deploying changes to timer rendering:

- [ ] `data-token-id` is present and unique
- [ ] `data-status` matches timer state (`"active"` for active, `"paused"` for paused)
- [ ] `data-work-seconds-sync` is a number (not string)
- [ ] `data-last-server-sync` is ISO8601 format string
- [ ] Element has class `work-timer` and `work-timer-active` (for active timers)
- [ ] BGTimeEngine can read all attributes via `dataset` API

---

## 📝 Notes

1. **Optional Attributes:** `data-started`, `data-pause-min`, `data-work-seconds-base` are not required by BGTimeEngine but may be used for display purposes.

2. **Class Requirements:** BGTimeEngine looks for `.work-timer-active` elements. Ensure this class is present for active timers.

3. **Token ID Uniqueness:** Each timer element must have a unique `data-token-id`. Modal timers use `'modal-' + token.id_token` to prevent conflicts.

4. **Status Values:** Only `"active"` timers are registered with BGTimeEngine. Paused/completed timers show static values.

---

## 🔗 Related Files

- **BGTimeEngine:** `assets/javascripts/pwa_scan/work_queue_timer.js`
- **TokenCardParts:** `assets/javascripts/pwa_scan/token_card/TokenCardParts.js`
- **TokenCardState:** `assets/javascripts/pwa_scan/token_card/TokenCardState.js`
- **WorkSessionTimeEngine (Backend):** `source/BGERP/Service/TimeEngine/WorkSessionTimeEngine.php`

---

**Last Updated:** 2025-12-09
**Verified By:** Task 27.22.1 Issue 3


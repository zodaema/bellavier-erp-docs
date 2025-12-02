[BELLAVIER_PROTOCOL:PWA_DESIGN_V1.0 | ORIGIN=GPT-4 | AUTHOR=NATTAPHON_SUPASRI | DATE=2025-10-30]

# 🎨 Bellavier PWA — Design System Specification

**Last Updated:** October 30, 2025  
**Author:** Nattaphon Supasri / Bellavier Group  
**Status:** 📋 **SPECIFICATION** - Ready for Implementation  
**Purpose:** To define a complete design system for the Bellavier PWA (Progressive Web App) that ensures consistency, accessibility, and optimal user experience for factory operators, supervisors, and management.

---

## 🎯 Design Philosophy

> **"Technology that disappears behind craftsmanship."**

The Bellavier PWA must make operators feel like they're using **another tool** in their craft, not a "program."

### **Core Principles:**

| Principle | Meaning | Implementation |
|-----------|---------|----------------|
| **One Tap = One Action** | Every tap is a completed command | Large buttons (80px), no nested menus |
| **Forgiving UX** | No accidental data destruction | Undo available, confirm only for risky actions |
| **Offline First** | Works without internet | IndexedDB + Auto-sync |
| **Cognitive Calmness** | No information overload | Focus mode + Visual feedback |
| **Motivation Loop** | Inspire pride in work | Progress, achievements, streaks |

---

## 🎨 Design Tokens (Global Variables)

### **Color Palette**

```css
:root {
  /* Primary Actions */
  --color-start: #22c55e;       /* Green - Start work */
  --color-pause: #f59e0b;       /* Amber - Pause work */
  --color-resume: #3b82f6;      /* Blue - Resume work */
  --color-complete: #10b981;    /* Emerald - Complete work */
  --color-defect: #ef4444;      /* Red - Report defect */
  
  /* Feedback Colors */
  --color-success: #22c55e;     /* Success state */
  --color-warning: #f59e0b;     /* Warning state */
  --color-error: #ef4444;       /* Error state */
  --color-info: #3b82f6;        /* Info state */
  
  /* Backgrounds */
  --bg-light: #f8fafc;          /* Light background */
  --bg-card: #ffffff;           /* Card background */
  --bg-disabled: #e2e8f0;       /* Disabled state */
  --bg-overlay: rgba(0,0,0,0.5); /* Modal overlay */
  
  /* Text Colors */
  --text-primary: #1e293b;      /* Primary text */
  --text-secondary: #64748b;    /* Secondary text */
  --text-disabled: #cbd5e1;     /* Disabled text */
  --text-inverse: #ffffff;      /* Text on dark bg */
  
  /* Borders */
  --border-light: #e2e8f0;
  --border-medium: #cbd5e1;
  --border-dark: #94a3b8;
  
  /* Shadows */
  --shadow-sm: 0 1px 2px rgba(0,0,0,0.05);
  --shadow-md: 0 4px 6px rgba(0,0,0,0.1);
  --shadow-lg: 0 10px 15px rgba(0,0,0,0.1);
  --shadow-xl: 0 20px 25px rgba(0,0,0,0.15);
}
```

### **Typography**

```css
:root {
  /* Font Families */
  --font-primary: 'Sarabun', 'Prompt', 'Noto Sans Thai', sans-serif;
  --font-mono: 'Courier New', monospace;
  
  /* Font Sizes */
  --text-xs: 12px;    /* Captions, labels */
  --text-sm: 14px;    /* Small text */
  --text-base: 16px;  /* Body text */
  --text-lg: 18px;    /* Large text */
  --text-xl: 20px;    /* Subheadings */
  --text-2xl: 24px;   /* Headings */
  --text-3xl: 30px;   /* Large headings */
  --text-4xl: 36px;   /* Display text */
  --text-5xl: 48px;   /* Hero text */
  
  /* Font Weights */
  --font-normal: 400;
  --font-medium: 500;
  --font-semibold: 600;
  --font-bold: 700;
  
  /* Line Heights */
  --leading-tight: 1.25;
  --leading-normal: 1.5;
  --leading-relaxed: 1.75;
}
```

### **Spacing**

```css
:root {
  /* Spacing Scale (4px base) */
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 12px;
  --space-4: 16px;
  --space-5: 20px;
  --space-6: 24px;
  --space-8: 32px;
  --space-10: 40px;
  --space-12: 48px;
  --space-16: 64px;
  --space-20: 80px;
  --space-24: 96px;
}
```

### **Border Radius**

```css
:root {
  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 12px;
  --radius-xl: 16px;
  --radius-full: 9999px; /* Pills */
}
```

### **Transitions**

```css
:root {
  --transition-fast: 150ms;
  --transition-base: 200ms;
  --transition-slow: 300ms;
  --transition-slower: 500ms;
  
  --ease-in: cubic-bezier(0.4, 0, 1, 1);
  --ease-out: cubic-bezier(0, 0, 0.2, 1);
  --ease-in-out: cubic-bezier(0.4, 0, 0.2, 1);
}
```

---

## 🧩 Component Library

### **1. ActionButton**

**Purpose:** Primary action buttons for operator quick actions

**Variants:**
- `start` - Start work (green)
- `pause` - Pause work (amber)
- `resume` - Resume work (blue)
- `complete` - Complete work (emerald)
- `defect` - Report defect (red)

**Specifications:**
```css
.action-button {
  min-width: 80px;
  min-height: 80px;
  border-radius: var(--radius-lg);
  font-size: var(--text-xl);
  font-weight: var(--font-semibold);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--space-2);
  transition: transform var(--transition-fast) var(--ease-out),
              box-shadow var(--transition-fast) var(--ease-out);
  box-shadow: var(--shadow-md);
}

.action-button:active {
  transform: scale(0.95);
  box-shadow: var(--shadow-sm);
}

.action-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* Icon */
.action-button-icon {
  font-size: 32px;
}

/* Label */
.action-button-label {
  font-size: var(--text-sm);
  font-weight: var(--font-medium);
}
```

**Usage:**
```html
<button class="action-button action-button-start">
  <i class="action-button-icon fas fa-play"></i>
  <span class="action-button-label">เริ่มงาน</span>
</button>
```

---

### **2. ProgressCircle**

**Purpose:** Visual progress indicator with percentage

**Specifications:**
```html
<div class="progress-circle" style="--progress: 45;">
  <svg viewBox="0 0 200 200" class="progress-circle-svg">
    <!-- Background circle -->
    <circle cx="100" cy="100" r="90" 
            fill="none" 
            stroke="var(--bg-disabled)" 
            stroke-width="20"/>
    
    <!-- Progress arc -->
    <circle cx="100" cy="100" r="90" 
            fill="none" 
            stroke="var(--color-success)" 
            stroke-width="20"
            stroke-dasharray="565"
            stroke-dashoffset="calc(565 - (565 * var(--progress) / 100))"
            stroke-linecap="round"
            transform="rotate(-90 100 100)"
            class="progress-circle-arc"/>
  </svg>
  
  <!-- Center content -->
  <div class="progress-circle-content">
    <div class="progress-circle-percent">45%</div>
    <div class="progress-circle-label">เสร็จแล้ว</div>
  </div>
</div>
```

**CSS:**
```css
.progress-circle {
  position: relative;
  width: 200px;
  height: 200px;
  margin: 0 auto;
}

.progress-circle-svg {
  width: 100%;
  height: 100%;
}

.progress-circle-arc {
  transition: stroke-dashoffset var(--transition-slow) var(--ease-out);
}

.progress-circle-content {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  text-align: center;
}

.progress-circle-percent {
  font-size: var(--text-5xl);
  font-weight: var(--font-bold);
  color: var(--color-success);
  line-height: 1;
}

.progress-circle-label {
  font-size: var(--text-sm);
  color: var(--text-secondary);
  margin-top: var(--space-1);
}
```

---

### **3. UndoFloatingButton**

**Purpose:** Persistent undo button for last 3 actions

**Specifications:**
```html
<button id="undo-btn" class="undo-floating-button" disabled>
  <i class="fas fa-undo"></i>
  <span class="undo-badge">0</span>
</button>
```

**CSS:**
```css
.undo-floating-button {
  position: fixed;
  bottom: 80px;
  right: 20px;
  width: 60px;
  height: 60px;
  border-radius: var(--radius-full);
  background: var(--color-warning);
  color: white;
  border: none;
  box-shadow: var(--shadow-lg);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  transition: transform var(--transition-fast) var(--ease-out);
}

.undo-floating-button:active {
  transform: scale(0.9);
}

.undo-floating-button:disabled {
  opacity: 0.3;
  pointer-events: none;
}

.undo-floating-button i {
  font-size: 24px;
}

.undo-badge {
  position: absolute;
  top: -4px;
  right: -4px;
  min-width: 20px;
  height: 20px;
  border-radius: var(--radius-full);
  background: var(--color-error);
  color: white;
  font-size: var(--text-xs);
  font-weight: var(--font-bold);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 var(--space-1);
}
```

---

### **4. SuccessOverlay**

**Purpose:** Full-screen success feedback animation

**Specifications:**
```html
<div class="success-overlay">
  <div class="success-overlay-content">
    <i class="success-overlay-icon fas fa-check-circle"></i>
    <h2 class="success-overlay-title">บันทึกสำเร็จ!</h2>
    <p class="success-overlay-detail">เสร็จสมบูรณ์ 1 ชิ้น</p>
  </div>
</div>
```

**CSS:**
```css
@keyframes fadeInOut {
  0% { opacity: 0; }
  20% { opacity: 1; }
  80% { opacity: 1; }
  100% { opacity: 0; }
}

@keyframes scaleIn {
  0% { transform: scale(0); }
  50% { transform: scale(1.2); }
  100% { transform: scale(1); }
}

.success-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(34, 197, 94, 0.95);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
  animation: fadeInOut 1.5s ease-in-out forwards;
}

.success-overlay-content {
  text-align: center;
  color: white;
}

.success-overlay-icon {
  font-size: 120px;
  margin-bottom: var(--space-4);
  animation: scaleIn 0.5s ease-out;
}

.success-overlay-title {
  font-size: var(--text-4xl);
  font-weight: var(--font-bold);
  margin-bottom: var(--space-2);
}

.success-overlay-detail {
  font-size: var(--text-2xl);
  opacity: 0.9;
}
```

---

### **5. StatusCard**

**Purpose:** Display operator status (for supervisor dashboard)

**Specifications:**
```html
<div class="status-card">
  <div class="status-card-header">
    <div class="status-card-avatar">
      <i class="fas fa-user"></i>
    </div>
    <div class="status-card-info">
      <h4 class="status-card-name">ช่างนำ</h4>
      <span class="status-badge status-badge-active">กำลังทำงาน</span>
    </div>
  </div>
  
  <div class="status-card-body">
    <div class="status-card-task">
      <span class="status-card-label">งาน:</span>
      <span class="status-card-value">เย็บมือ Charlotte Aimée</span>
    </div>
    
    <div class="status-card-progress">
      <div class="progress-bar">
        <div class="progress-bar-fill" style="width: 45%"></div>
      </div>
      <span class="status-card-percent">45% (45/100)</span>
    </div>
  </div>
  
  <div class="status-card-footer">
    <span class="status-card-time">เริ่มเมื่อ: 08:30</span>
    <span class="status-card-duration">2 ชม. 15 นาที</span>
  </div>
</div>
```

**CSS:**
```css
.status-card {
  background: var(--bg-card);
  border-radius: var(--radius-lg);
  padding: var(--space-4);
  box-shadow: var(--shadow-md);
  border-left: 4px solid var(--color-success);
}

.status-card-header {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  margin-bottom: var(--space-4);
}

.status-card-avatar {
  width: 48px;
  height: 48px;
  border-radius: var(--radius-full);
  background: var(--color-success);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 24px;
}

.status-card-name {
  font-size: var(--text-lg);
  font-weight: var(--font-semibold);
  margin: 0;
}

.status-badge {
  display: inline-block;
  padding: var(--space-1) var(--space-2);
  border-radius: var(--radius-sm);
  font-size: var(--text-xs);
  font-weight: var(--font-medium);
}

.status-badge-active {
  background: rgba(34, 197, 94, 0.1);
  color: var(--color-success);
}

.status-badge-paused {
  background: rgba(245, 158, 11, 0.1);
  color: var(--color-warning);
}

.progress-bar {
  height: 8px;
  background: var(--bg-disabled);
  border-radius: var(--radius-full);
  overflow: hidden;
  margin-bottom: var(--space-2);
}

.progress-bar-fill {
  height: 100%;
  background: var(--color-success);
  border-radius: var(--radius-full);
  transition: width var(--transition-slow) var(--ease-out);
}
```

---

### **6. AchievementCard**

**Purpose:** Daily achievement summary (gamification)

**Specifications:**
```html
<div class="achievement-card">
  <div class="achievement-card-header">
    <i class="fas fa-trophy"></i>
    <h3>ผลงานวันนี้</h3>
  </div>
  
  <div class="achievement-card-body">
    <div class="achievement-stat">
      <div class="achievement-icon">🏆</div>
      <div class="achievement-value">25</div>
      <div class="achievement-label">ชิ้น</div>
    </div>
    
    <div class="achievement-stat">
      <div class="achievement-icon">⏱️</div>
      <div class="achievement-value">5.2</div>
      <div class="achievement-label">ชั่วโมง</div>
    </div>
    
    <div class="achievement-stat">
      <div class="achievement-icon">⚡</div>
      <div class="achievement-value">115%</div>
      <div class="achievement-label">ประสิทธิภาพ</div>
    </div>
  </div>
  
  <div class="achievement-card-footer">
    <div class="streak-counter">
      <i class="fas fa-fire text-danger"></i>
      <span>ทำงานติดต่อกัน <strong>7</strong> วัน!</span>
    </div>
  </div>
</div>
```

---

### **7. QRScanFallback**

**Purpose:** Manual input when QR scan fails

**Specifications:**
```html
<div class="qr-fallback-modal">
  <div class="qr-fallback-content">
    <h3>สแกนไม่ติด?</h3>
    <p>กรอกรหัสด้วยตนเอง</p>
    
    <div class="form-group">
      <label>Ticket / MO / Lot Number</label>
      <input type="text" 
             class="form-control-lg" 
             placeholder="เช่น JT251030001"
             autocomplete="off">
    </div>
    
    <div class="qr-fallback-actions">
      <button class="btn btn-secondary">ยกเลิก</button>
      <button class="btn btn-primary">ยืนยัน</button>
    </div>
    
    <div class="qr-fallback-tips">
      <strong>เคล็ดลับ:</strong>
      <ul>
        <li>เปิดไฟแฟลช (ปุ่มมุมขวาบน)</li>
        <li>ถือกล้องห่างจาก QR 15-30 ซม.</li>
        <li>ทำความสะอาด QR ถ้ามีคราบ</li>
      </ul>
    </div>
  </div>
</div>
```

---

## 📐 Layout System

### **Grid System**

```css
/* Mobile-first responsive grid */
.grid {
  display: grid;
  gap: var(--space-4);
}

/* Mobile (default) - 1 column */
.grid-cols-1 {
  grid-template-columns: 1fr;
}

/* Tablet - 2 columns */
@media (min-width: 768px) {
  .grid-cols-2-md {
    grid-template-columns: repeat(2, 1fr);
  }
}

/* Desktop - 3 columns */
@media (min-width: 1024px) {
  .grid-cols-3-lg {
    grid-template-columns: repeat(3, 1fr);
  }
}
```

### **Container**

```css
.container {
  width: 100%;
  max-width: 1280px;
  margin: 0 auto;
  padding: 0 var(--space-4);
}

.container-sm {
  max-width: 640px;
}

.container-md {
  max-width: 768px;
}

.container-lg {
  max-width: 1024px;
}
```

---

## 🎭 Interaction Patterns

### **1. Button States**

```css
/* Default state */
.btn {
  transition: all var(--transition-fast) var(--ease-out);
}

/* Hover (desktop only) */
@media (hover: hover) {
  .btn:hover {
    filter: brightness(1.1);
  }
}

/* Active (pressed) */
.btn:active {
  transform: scale(0.95);
}

/* Focus (keyboard navigation) */
.btn:focus {
  outline: 2px solid var(--color-info);
  outline-offset: 2px;
}

/* Loading state */
.btn.is-loading {
  pointer-events: none;
  opacity: 0.6;
}

.btn.is-loading::after {
  content: '';
  width: 16px;
  height: 16px;
  border: 2px solid currentColor;
  border-right-color: transparent;
  border-radius: 50%;
  display: inline-block;
  animation: spin 0.6s linear infinite;
  margin-left: var(--space-2);
}

@keyframes spin {
  to { transform: rotate(360deg); }
}
```

### **2. Haptic Feedback Patterns**

```javascript
const hapticPatterns = {
  success: [100, 50, 100],              // Double tap
  error: [200, 100, 200, 100, 200],     // Triple long
  warning: [100, 50, 100, 50, 100],     // Rapid
  milestone: [200, 50, 100, 50, 200],   // Celebration
  tap: [50]                              // Single short
};

function hapticFeedback(type) {
  if (navigator.vibrate) {
    navigator.vibrate(hapticPatterns[type] || [50]);
  }
}
```

### **3. Toast Notifications**

```css
.toast {
  position: fixed;
  bottom: 20px;
  left: 50%;
  transform: translateX(-50%);
  background: var(--text-primary);
  color: var(--text-inverse);
  padding: var(--space-3) var(--space-6);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-xl);
  z-index: 1000;
  animation: slideUp 0.3s ease-out;
}

@keyframes slideUp {
  from {
    opacity: 0;
    transform: translateX(-50%) translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateX(-50%) translateY(0);
  }
}

.toast-success {
  background: var(--color-success);
}

.toast-error {
  background: var(--color-error);
}

.toast-warning {
  background: var(--color-warning);
}
```

---

## 📱 Responsive Breakpoints

```css
/* Mobile-first approach */
:root {
  --breakpoint-sm: 640px;   /* Small devices */
  --breakpoint-md: 768px;   /* Medium devices (tablets) */
  --breakpoint-lg: 1024px;  /* Large devices (desktops) */
  --breakpoint-xl: 1280px;  /* Extra large devices */
}

/* Usage */
@media (min-width: 768px) {
  /* Tablet and up */
}

@media (min-width: 1024px) {
  /* Desktop and up */
}
```

---

## ♿ Accessibility Guidelines

### **1. Minimum Touch Target Size**

- **Mobile:** 48x48px (Apple HIG / Material Design)
- **Preferred:** 60x60px (for gloved hands)
- **Critical actions:** 80x80px

### **2. Color Contrast**

- **Normal text:** 4.5:1 minimum (WCAG AA)
- **Large text (18px+):** 3:1 minimum
- **Use tools:** WebAIM Contrast Checker

### **3. Font Sizes**

- **Minimum body text:** 16px
- **Small text (labels):** 14px minimum
- **Critical info:** 20px+

### **4. Focus Indicators**

- **Always visible** on keyboard navigation
- **Outline:** 2px solid, offset 2px
- **Color:** High contrast (blue recommended)

---

## 🎬 Animation Guidelines

### **Principles:**

1. **Purpose:** Every animation has a purpose (feedback, attention, transition)
2. **Speed:** Fast enough to feel responsive, slow enough to perceive (150-300ms)
3. **Easing:** Use ease-out for entrances, ease-in for exits
4. **Performance:** Use transform and opacity (GPU accelerated)
5. **Reduce motion:** Respect `prefers-reduced-motion`

### **Example:**

```css
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

---

## 🧪 Component Testing Checklist

For each component:

- [ ] **Visual:** Renders correctly on all breakpoints
- [ ] **Interaction:** All states work (hover, active, focus, disabled, loading)
- [ ] **Accessibility:** Keyboard navigable, screen reader friendly, WCAG AA compliant
- [ ] **Performance:** No layout shift, smooth animations, < 100ms response time
- [ ] **Responsive:** Scales properly on mobile, tablet, desktop
- [ ] **Dark mode:** (Future consideration)

---

## 📦 Component Status Matrix

| Component | Spec | Implemented | Tested | Documented |
|-----------|------|-------------|--------|------------|
| ActionButton | ✅ | ⏳ | ⏳ | ✅ |
| ProgressCircle | ✅ | ⏳ | ⏳ | ✅ |
| UndoFloatingButton | ✅ | ⏳ | ⏳ | ✅ |
| SuccessOverlay | ✅ | ⏳ | ⏳ | ✅ |
| StatusCard | ✅ | ⏳ | ⏳ | ✅ |
| AchievementCard | ✅ | ⏳ | ⏳ | ✅ |
| QRScanFallback | ✅ | ⏳ | ⏳ | ✅ |

**Legend:**
- ✅ Complete
- ⏳ In Progress
- ❌ Not Started

---

## 🚀 Implementation Priority

### **Phase 1: Core Components (Week 1)**
1. ActionButton
2. SuccessOverlay
3. UndoFloatingButton
4. QRScanFallback

### **Phase 2: Visualization (Week 2)**
5. ProgressCircle
6. StatusCard (for supervisors)

### **Phase 3: Gamification (Week 3)**
7. AchievementCard

---

## 📖 Usage Examples

### **Example 1: Quick Action Panel**

```html
<div class="quick-action-panel">
  <div class="grid grid-cols-2-md gap-4">
    <button class="action-button action-button-start">
      <i class="action-button-icon fas fa-play"></i>
      <span class="action-button-label">เริ่มงาน</span>
    </button>
    
    <button class="action-button action-button-pause">
      <i class="action-button-icon fas fa-pause"></i>
      <span class="action-button-label">พักงาน</span>
    </button>
    
    <button class="action-button action-button-complete">
      <i class="action-button-icon fas fa-check"></i>
      <span class="action-button-label">เสร็จสมบูรณ์</span>
    </button>
    
    <button class="action-button action-button-defect">
      <i class="action-button-icon fas fa-exclamation-triangle"></i>
      <span class="action-button-label">เสีย</span>
    </button>
  </div>
</div>
```

### **Example 2: Progress View**

```html
<div class="progress-view">
  <div class="progress-circle" style="--progress: 45;">
    <!-- SVG markup here -->
  </div>
  
  <div class="progress-stats grid grid-cols-3 gap-4 mt-4">
    <div class="stat-card">
      <div class="stat-value text-success">45</div>
      <div class="stat-label">เสร็จแล้ว</div>
    </div>
    
    <div class="stat-card">
      <div class="stat-value text-primary">55</div>
      <div class="stat-label">เหลือ</div>
    </div>
    
    <div class="stat-card">
      <div class="stat-value text-secondary">100</div>
      <div class="stat-label">เป้าหมาย</div>
    </div>
  </div>
</div>
```

---

## 🎨 Figma Component Kit

**Recommended Structure:**
```
Bellavier PWA Design System
├─ 🎨 Foundations
│  ├─ Colors
│  ├─ Typography
│  ├─ Spacing
│  └─ Icons
├─ 🧩 Components
│  ├─ Buttons
│  ├─ Forms
│  ├─ Cards
│  ├─ Modals
│  └─ Navigation
├─ 📱 Screens
│  ├─ Operator Mode
│  ├─ Supervisor Mode
│  └─ Admin Mode
└─ 🎭 Prototypes
   ├─ Quick Action Flow
   ├─ Undo Interaction
   └─ Success Animation
```

---

**Last Updated:** October 30, 2025  
**Next Review:** After Phase 1 Implementation  
**Maintainer:** Product Team + UX Designer

---

[END OF DOCUMENT]


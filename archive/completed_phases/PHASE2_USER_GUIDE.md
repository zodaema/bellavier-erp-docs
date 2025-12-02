# Phase 2: Team Integration - User Guide

**Version:** 1.0  
**Date:** November 6, 2025  
**For:** Managers & Administrators

---

## 📖 **Overview**

Phase 2 introduces **Team-Based Assignment** with intelligent load balancing, making it easier to distribute work fairly across team members.

**Key Benefits:**
- ⚡ **Faster Assignment** - Assign work to a team, not individuals
- ⚖️ **Automatic Load Balancing** - System selects least-busy member
- 👀 **Full Transparency** - See why each member was chosen
- 📊 **Real-time Workload** - Monitor team capacity live
- 📝 **Complete Audit Trail** - Track all assignment decisions

---

## 🚀 **Quick Start**

### **1. Assigning Work to a Team**

#### **Manager Assignment Page:**

1. Go to **Manager Assignment** page
2. Select tokens you want to assign (checkboxes)
3. Click **"Bulk Assign"**
4. In the dropdown, select a **Team** (marked with team icon)
5. Review the preview:
   - Who will receive the work
   - Current workload
   - Available members
6. Click **"Yes, assign"**

**The system will:**
- ✅ Find the best available member
- ✅ Balance workload across the team
- ✅ Log the decision for transparency
- ✅ Send notification to the selected operator

---

### **2. Understanding Workload Indicators**

Teams show real-time status:
- 🟢 **Green** = Available (low load)
- 🟡 **Yellow** = High load (3+ tokens per member)
- 🔴 **Red** = All busy (no available members)

**Example:**
```
🟢 Sewing Team A (2/5 available, avg load: 1.5)
```
- 2 out of 5 members are available
- Average load is 1.5 tokens per person

---

### **3. Viewing Assignment History**

#### **To see who was assigned and why:**

1. Go to **Team Management** page
2. Click on a team card
3. In the team details drawer, click **"Assignment History"**
4. You'll see:
   - **When** the assignment was made
   - **Who** was selected
   - **Why** they were chosen (decision reason)
   - **Who else** was considered (alternatives)

**Example Decision Reason:**
```
"Lowest load: 2 tokens (mode: least-loaded, 3 available)"
```

---

## 🎯 **How It Works**

### **Load Balancing Modes**

The system uses **3 load balancing strategies** (configured in `assignment_config.php`):

#### **1. Least-Loaded (Default)**
- Selects member with fewest active tokens
- Best for fair distribution
- **Recommended for most teams**

#### **2. Priority-Weighted**
- Combines member load + manual priority setting
- Useful when some members are faster/more experienced
- Set priority in "Edit Member" (0=first, 100=last)

#### **3. Round-Robin**
- Ignores load, just rotates through members
- Rarely used, mostly for testing

---

### **Availability Rules**

A member is considered **unavailable** if:
1. ❌ **On leave** (sick, annual, etc.)
2. ❌ **Manually marked unavailable** (machine broken, training, etc.)
3. ❌ **Unavailable time set** (half-day leave)

Unavailable members are:
- Skipped during assignment
- Shown at the bottom of the list
- Marked with reason (e.g., "Sick leave")

---

## 📊 **Monitoring Teams**

### **Team Management Page**

**Workload Indicators appear on team cards:**

```
Team: Sewing A
🟢 Available (avg load: 1.2)
2/5 available
```

**This updates every 30 seconds automatically.**

---

### **Real-Time Alerts**

**You'll see warnings for:**
- 🔴 **All members busy** - No one available in the team
- 🟡 **High load** - Members have 3+ tokens each
- ⚠️ **Assigning to unavailable member** - If you manually assign to someone on leave

---

## 🛠️ **Managing Member Availability**

### **Setting a Member as Unavailable**

1. Go to **Team Management**
2. Click on a team
3. Find the member in the list
4. Click **"Edit"**
5. Set unavailable time:
   - **From:** Start time (e.g., today 1:00 PM)
   - **Until:** End time (e.g., tomorrow 9:00 AM)
6. **Save**

**The system will:**
- ✅ Not assign work to this member during that time
- ✅ Show them as "unavailable" in the team
- ✅ Automatically make them available again after the time passes

---

### **Recording Leave**

For longer absences (sick leave, vacation):

1. Go to **Team Management**
2. Click on a team
3. Find the member
4. Click **"Record Leave"**
5. Fill in:
   - **Type:** Sick, Annual, Personal, Emergency
   - **Start Date/Time**
   - **End Date/Time**
   - **Reason** (optional, for internal records)
6. **Save**

**The member will:**
- Be marked as "On leave" during that period
- Be automatically skipped for assignments
- Return to "available" after the leave ends

---

## 📋 **Assignment Transparency**

### **Why Was This Person Assigned?**

Every assignment is logged with a **decision reason**.

**View it in Assignment History:**

```
Decision: "Score 0.245 (load: 2 tokens, priority: 10, mode: weighted 30.0%, 3 available)"

Alternatives Considered:
1. ชื่อสมาชิก B - Higher score: 0.312
2. ชื่อสมาชิก C - Higher score: 0.450
```

**This tells you:**
- Why member A was chosen (lowest score)
- What their current load was (2 tokens)
- Who else could have been assigned (B and C had higher scores)

---

## ⚙️ **Configuration**

### **For Administrators**

Edit `source/config/assignment_config.php` to change:

```php
// Load balancing mode
public const LOAD_BALANCING_MODE = 'least_loaded';
// Options: 'round_robin', 'least_loaded', 'priority_weighted'

// Default work capacity (hours per day)
public const DEFAULT_CAPACITY_PER_DAY = 8.00;

// Priority weight (for priority_weighted mode)
public const PRIORITY_WEIGHT = 0.3;  // 30% priority, 70% load

// Overloaded threshold (show warning)
public const OVERLOADED_THRESHOLD_TOKENS = 5;
```

---

## 🔍 **Troubleshooting**

### **Problem: Team dropdown doesn't show any teams**

**Solution:**
1. Go to **Team Management**
2. Create at least one team
3. Add members to the team
4. Refresh Manager Assignment page

---

### **Problem: Workload shows "All busy" but members are idle**

**Solution:**
1. Check if members have old assignments stuck in "started" status
2. Ask operators to complete or pause their work
3. Workload refreshes every 30 seconds

---

### **Problem: Wrong person keeps getting assigned**

**Solution:**
1. Check load balancing mode (in config)
2. Verify member priorities (in Team Management)
3. Check if other members are marked unavailable
4. Review assignment history to see decision reasons

---

### **Problem: Assignment preview doesn't show**

**Solution:**
1. Ensure SweetAlert2 is loaded (check browser console)
2. If browser blocks popups, allow them for this site
3. Fallback: Standard confirmation dialog will appear

---

## 📚 **Additional Resources**

- **API Reference:** `PHASE2_API_REFERENCE.md`
- **Technical Specification:** `PHASE2_TEAM_INTEGRATION_DETAILED_PLAN.md`
- **Deployment Guide:** `PHASE2_DEPLOYMENT_GUIDE.md`

---

## 📞 **Support**

If you encounter issues:
1. Check assignment history logs
2. Review team member availability
3. Verify team production mode matches job type
4. Contact system administrator

---

**End of User Guide**


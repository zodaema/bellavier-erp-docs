# 🤖 Context for Future AI Agents

**Created:** November 2, 2025  
**Purpose:** Critical context for AI agents working on this codebase in the future  
**Read This:** Before making any major architectural decisions

---

## 🎯 **Strategic Direction (READ THIS FIRST!)**

### **⚠️ CRITICAL: Linear System is Temporary**

**Current State (Nov 2, 2025):**
```
✅ Dual-Mode System Active
   ├─ Linear (task-based) = Safety net / Fallback
   └─ DAG (graph-based) = Future production system
```

**Future State (Q3 2026):**
```
✅ Single-Mode System
   └─ DAG Only = Production system
```

### **Why This Matters:**

1. **Don't optimize Linear code** - It will be deleted soon
2. **Don't add Linear features** - Focus on DAG
3. **Don't assume dual-mode is permanent** - It's temporary migration strategy
4. **Always check removal timeline** - See `docs/guide/LINEAR_DEPRECATION_GUIDE.md`

---

## 📊 **System Evolution Timeline**

### **2025 Q3: Pre-DAG Era**
```
Single System: Linear Task-Based
├─ atelier_job_ticket
├─ atelier_job_task (sequential)
└─ atelier_wip_log

Limitations:
❌ No parallel work
❌ No component assembly
❌ No flexible rework
```

### **2025 Q4 - 2026 Q2: Dual-Mode Era (NOW)**
```
Dual System: Linear + DAG Coexist
├─ Linear (legacy)
│   ├─ atelier_job_task
│   └─ atelier_wip_log
└─ DAG (future)
    ├─ routing_graph
    ├─ routing_node
    ├─ flow_token
    └─ token_event

Purpose:
✅ Safe migration path
✅ Rollback capability
✅ User training period
```

### **2026 Q3+: DAG-Only Era (GOAL)**
```
Single System: DAG Graph-Based
├─ routing_graph
├─ routing_node
├─ flow_token
└─ token_event

Benefits:
✅ Parallel execution
✅ Component assembly
✅ Flexible routing
✅ Simpler codebase
```

---

## 🔍 **How to Identify System Version**

### **If You See:**

**⚠️ Deprecated (Task 25.3-25.5):**
```php
// OLD (Deprecated):
if ($ticket['routing_mode'] === 'linear') { /* old system */ }
elseif ($ticket['routing_mode'] === 'dag') { /* new system */ }

// Database
SELECT routing_mode FROM job_ticket; -- Classic DAG was deprecated
```
→ **Classic DAG mode was removed. Classic uses Linear only.**

**Current System (Post Task 25.5):**
```php
// Classic Line
if ($ticket['production_type'] === 'classic') {
    // routing_mode = 'linear' ONLY (DAG deprecated)
    // No graph binding, no DAG tables
}

// Hatthasilpa Line
if ($ticket['production_type'] === 'hatthasilpa') {
    // routing_mode = 'dag' REQUIRED
    // Graph binding required
    // Uses flow_token, token_event, etc.
}
```
→ **System uses production_type to determine routing mode**

---

## 🎓 **Key Architectural Decisions**

### **Decision 1: Why Not "Linear + Parallel Groups"?**

**We considered:**
```sql
ALTER TABLE atelier_job_task 
ADD COLUMN parallel_group INT NULL;

-- Task 1: Group 1 (sequential)
-- Task 2: Group 2 (parallel) \
-- Task 3: Group 2 (parallel)  } These run together
-- Task 4: Group 3 (sequential, waits for Group 2)
```

**Rejected because:**
- ❌ Still can't do component assembly (join nodes)
- ❌ Still can't do conditional routing
- ❌ Still can't track individual pieces (tokens)
- ❌ Complex rework flows not supported

**Chose DAG instead:**
- ✅ Full flexibility
- ✅ Token-based tracking
- ✅ Split/Join nodes
- ✅ Conditional edges
- ✅ Industry standard (Airflow, Temporal use DAGs)

### **Decision 2: Why Keep Dual-Mode Temporarily?**

**Why not switch directly to DAG?**
- ❌ Too risky (production system)
- ❌ Users need training time
- ❌ Need to verify DAG stability
- ❌ Legal requirement (data retention)

**Dual-mode benefits:**
- ✅ Zero downtime migration
- ✅ Can rollback if issues
- ✅ Gradual user adoption
- ✅ Compare performance before/after

### **Decision 3: PWA Design for Operators**

**Why simplified DAG view in PWA?**
```
Operators don't need to see:
❌ Full graph structure
❌ Split/join logic
❌ Conditional routing rules

Operators only need:
✅ "3 tokens at SEW_BODY"
✅ "Next: Will route to ASSEMBLY"
✅ Start/Complete buttons
```

**Reasoning:**
- Shop floor operators aren't graph experts
- They just need to know "what's ready to work on"
- Complex routing handled automatically by system
- Desktop interface for supervisors/planners

---

## 📚 **Essential Reading Order**

### **For Understanding Current System:**
1. `docs/BELLAVIER_DAG_CORE_TODO.md` - Architecture overview
2. `docs/BELLAVIER_DAG_RUNTIME_FLOW.md` - How tokens flow
3. `docs/BELLAVIER_DAG_INTEGRATION_NOTES.md` - UI/API integration
4. `docs/DATABASE_SCHEMA_REFERENCE.md` - Table structures

### **For Understanding Migration:**
1. `docs/BELLAVIER_DAG_MIGRATION_PLAN.md` - Migration strategy
2. `docs/guide/LINEAR_DEPRECATION_GUIDE.md` - Removal plan
3. `DAG_DEVELOPMENT_PLAN.md` - Current development roadmap

### **For Making Changes:**
1. `AI_GUIDE.md` - General AI agent guide
2. `docs/SERVICE_API_REFERENCE.md` - API documentation
3. `.cursorrules` - Coding standards

---

## 🚨 **Common Mistakes to Avoid**

### **Mistake 1: Assuming Dual-Mode is Permanent**
```
❌ "Let's add a config flag for routing_mode preference"
❌ "Let's optimize both Linear and DAG equally"
❌ "Let's create a UI to switch between systems"

✅ "Focus on DAG. Linear is temporary safety net."
```

### **Mistake 2: Breaking Linear During DAG Development**
```
❌ "Let's refactor atelier_wip_log to merge with token_event"
❌ "Let's remove routing_mode column to simplify"
❌ "Let's force all jobs to use DAG"

✅ "Keep Linear working until verified safe to remove"
✅ "DAG tables are separate - no schema conflicts"
✅ "Test Linear jobs after every DAG change"
```

### **Mistake 3: Not Checking Removal Timeline**
```
❌ "Should we add Linear features? I don't see removal date"
❌ "Linear seems stable, why remove it?"
❌ "Users might prefer Linear for simple jobs"

✅ Read: docs/guide/LINEAR_DEPRECATION_GUIDE.md
✅ Check: Target removal date (Q3 2026)
✅ Understand: Dual-mode = technical debt
```

### **Mistake 4: Optimizing the Wrong System**
```
❌ "Let's add indexes to atelier_job_task" (will be deleted)
❌ "Let's rewrite OperatorSessionService for Linear" (legacy)
❌ "Let's create Linear->Parallel migration tool" (unnecessary)

✅ Optimize DAG performance instead
✅ Improve DAG user experience
✅ Write migration tools (Linear→DAG)
```

---

## 🔮 **Future Development Guidelines**

### **When Adding New Features:**

**Ask yourself:**
1. Is this a DAG feature? → ✅ Go ahead
2. Is this a Linear feature? → ❌ Don't add (will be deleted)
3. Does this break dual-mode? → ❌ Don't do it yet
4. Does this help migration? → ✅ Prioritize

### **When Fixing Bugs:**

**Linear bug:**
- Is it critical? → ✅ Fix (users depend on it)
- Is it minor? → ⏸️ Defer (will be deleted anyway)
- Is it cosmetic? → ❌ Skip

**DAG bug:**
- Any severity → ✅ Fix immediately (this is the future)

### **When Refactoring:**

**Allowed:**
- ✅ Refactor DAG code
- ✅ Improve DAG services
- ✅ Optimize DAG queries

**Not Allowed:**
- ❌ Refactor Linear code (temporary)
- ❌ Merge Linear+DAG tables (keep separate)
- ❌ Remove routing_mode checks (needed for dual-mode)

---

## 💡 **Key Insights from Development**

### **What Worked Well:**

1. **Dual-Mode Strategy**
   - Allowed zero-downtime migration
   - Users could test DAG without pressure
   - Could rollback if issues found

2. **Separate Database Tables**
   - No schema conflicts
   - Easy to archive Linear data later
   - Clear separation of concerns

3. **Safety Test Script**
   - `test_dual_mode_safety.php`
   - Automated verification
   - Gave confidence to proceed

### **What We'd Do Differently:**

1. **Earlier User Training**
   - Should have trained users on DAG concepts earlier
   - Graph terminology was confusing at first
   - More visual documentation needed

2. **Clearer Deprecation Timeline**
   - Should have announced removal date from day 1
   - Users thought dual-mode was permanent
   - Created confusion about "which system to use"

3. **Migration Tools**
   - Should have built Linear→DAG converter earlier
   - Manual migration was time-consuming
   - Automated tool would save weeks

---

## 📊 **System Health Metrics**

### **How to Check if DAG is Ready to Replace Linear:**

```sql
-- 1. DAG job success rate (target: >95%)
SELECT 
    COUNT(*) as total,
    SUM(CASE WHEN status='completed' THEN 1 ELSE 0 END) as completed,
    ROUND(SUM(CASE WHEN status='completed' THEN 1 ELSE 0 END)/COUNT(*)*100,1) as success_rate
FROM atelier_job_ticket
WHERE routing_mode='dag' AND created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH);

-- 2. Linear job activity (target: 0 in last 30 days)
SELECT COUNT(*) as active_linear_jobs
FROM atelier_wip_log
WHERE deleted_at IS NULL 
AND event_time >= DATE_SUB(NOW(), INTERVAL 30 DAY);

-- 3. User adoption (target: 100% on DAG)
SELECT 
    routing_mode,
    COUNT(DISTINCT created_by) as unique_users
FROM atelier_job_ticket
WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY routing_mode;
```

**Safe to remove Linear when:**
- ✅ DAG success rate > 95% for 6+ months
- ✅ No Linear job activity in 30+ days
- ✅ All users comfortable with DAG
- ✅ Management approval obtained

---

## 🎯 **Your Mission (Future AI Agent)**

### **If You're Working on This Codebase:**

1. **Check the date** - Has Linear been removed yet?
   - Yes → System is DAG-only (simpler)
   - No → System is dual-mode (be careful)

2. **Read the removal guide** - `docs/guide/LINEAR_DEPRECATION_GUIDE.md`
   - Understand removal timeline
   - Don't break migration path

3. **Focus on DAG** - That's the future
   - Add DAG features
   - Optimize DAG performance
   - Improve DAG UX

4. **Keep Linear working** - Until removal date
   - Don't break it
   - Don't optimize it
   - Just maintain it

5. **Help migration** - Accelerate Linear→DAG transition
   - Build migration tools
   - Write conversion scripts
   - Train users

---

## 📞 **Need Help?**

### **Read These Files:**
1. `AI_GUIDE.md` - General guidance for AI agents
2. `docs/INDEX.md` - Documentation index
3. `ROADMAP_V3.md` - Project roadmap

### **Check These Memories:**
- Memory: "Bellavier ERP - Quick Reference Card"
- Memory: "DAG Implementation Checklist"
- Memory: "Linear System Deprecation Plan"

### **Run These Tests:**
```bash
# Verify system state
php test_dual_mode_safety.php default

# Check DAG health
php test_dag_token_api.php default

# Verify Linear still works
# (manual test via browser)
```

---

**Remember:** 
- 🎯 Goal = DAG replaces Linear completely
- ⏰ Timeline = Q3 2026
- 🛡️ Safety = Keep Linear working until then
- 📚 Context = Read this file before major changes

**Good luck!** 🚀

---

**Last Updated:** November 2, 2025  
**Next Review:** Q2 2026 (before Linear removal)  
**Maintained By:** System Architect


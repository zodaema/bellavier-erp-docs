# 💾 Memory Guide - AI Assistant Knowledge Base

**Purpose:** This document maps all AI memories for Bellavier ERP development

**Last Updated:** October 30, 2025  
**Total Memories:** 11 comprehensive memories

---

## 📚 **Memory Catalog**

### **🎯 Start Here (Must Read)**

#### **1. Master Memory Index**
- **Purpose:** Overview of all memories and reading order
- **When:** At start of EVERY session
- **Content:** Quick start workflow, critical reminders, current system state

#### **2. Quick Reference Card**
- **Purpose:** Emergency cheat sheet for common patterns
- **When:** When you need quick answers
- **Content:** File locations, commands, critical patterns, debugging top 5

---

### **🏗️ Architecture & Structure (Foundation)**

#### **3. Complete Project Structure**
- **Content:** Directory map, existing infrastructure (PHPUnit, Health Check, etc.)
- **Key Points:** Multi-tenant architecture, technology stack, DON'T RECREATE warnings
- **When:** Before creating any new file or feature

#### **4. File Organization & Naming**
- **Content:** Backend/frontend/database file structure, naming conventions
- **Key Points:** page/ vs views/, snake_case vs PascalCase, module prefixes
- **When:** Creating new files or organizing code

---

### **💻 Development (Implementation)**

#### **5. Coding Standards (Comprehensive)**
- **Content:** Database queries, API responses, JavaScript patterns, common mistakes
- **Key Points:** Prepared statements, soft-delete filters, cross-DB query patterns, API response format
- **When:** Writing ANY code (backend or frontend)

#### **6. Complete API Development Checklist**
- **Content:** Step-by-step API endpoint creation (5 steps)
- **Key Points:** Research first, validate input, use transactions, call services in order, write tests
- **When:** Creating or modifying API endpoints

#### **7. Development Workflow & Checklist**
- **Content:** Before/during/after development checklists, quality gates
- **Key Points:** Check existing first, run tests, verify in browser, clean up
- **When:** At each stage of development

---

### **🔧 Technical Systems (Deep Dive)**

#### **8. Job Ticket System Architecture**
- **Content:** 4 core tables, status cascade flow, services, critical rules
- **Key Points:** Auto-calculated progress, soft-delete, session management, event types
- **When:** Working on job tickets, WIP logs, or operator sessions

#### **9. Migration System (Complete Rules)**
- **Content:** PHP-based migrations, helper functions, naming, deployment
- **Key Points:** NEVER .sql files, always use helpers, idempotent patterns
- **When:** Modifying database schema

#### **10. Service Layer Architecture**
- **Content:** All 5 services with methods, dependencies, usage patterns
- **Key Points:** When to call which service, order matters, require_once placement
- **When:** Using or modifying services

#### **11. Database Schema & Query Patterns**
- **Content:** Table structures, FK relationships, query patterns, index usage
- **Key Points:** Soft-delete filters, cross-DB queries, progress calculation
- **When:** Writing database queries

#### **12. Critical Integration Points**
- **Content:** Exact code for WIP log create/update/delete, service call order
- **Key Points:** Sessions FIRST then Status, rebuild after changes, fallback functions
- **When:** Integrating WIP logs with services

---

### **🎨 Frontend (UI/UX)**

#### **13. Frontend Integration Patterns**
- **Content:** Page structure, $page_detail array, JS module pattern, library locations
- **Key Points:** Load order, SweetAlert2 before custom JS, translation system
- **When:** Adding frontend features or fixing UI bugs

#### **14. Page Loading System**
- **Content:** How pages load, css_request(), jquery_request(), SweetAlert2 integration
- **Key Points:** page/ vs views/, load order matters
- **When:** Setting up new pages or adding libraries

---

### **🧪 Quality & Testing (Excellence)**

#### **15. Testing Infrastructure**
- **Content:** PHPUnit setup, 89 existing tests, patterns, commands
- **Key Points:** Use existing patterns, Unit vs Integration, Arrange-Act-Assert
- **When:** Writing tests or debugging test failures

#### **16. Testing Strategy & Patterns**
- **Content:** Test organization, naming, patterns, coverage targets
- **Key Points:** Check existing tests first, follow patterns, clean up in tearDown
- **When:** Planning or writing tests

---

### **⚡ Optimization (Performance)**

#### **17. Performance Optimization Strategies**
- **Content:** Index strategy, query optimization, N+1 prevention, performance targets
- **Key Points:** Use indexes, avoid N+1, LIMIT large datasets, monitor slow queries
- **When:** Optimizing queries or investigating slow performance

---

### **🔐 Security (Protection)**

#### **18. Security Best Practices & Audit**
- **Content:** SQL injection prevention, XSS prevention, input validation, security checklist
- **Key Points:** Always prepared statements, validate all inputs, sanitize outputs
- **When:** Writing new code or security audit

---

### **🚑 Problem Solving (When Things Break)**

#### **19. Common Pitfalls & Solutions**
- **Content:** 8 real historical bugs with symptoms, root causes, solutions
- **Key Points:** Missing soft-delete filter, missing require_once, cross-DB JOINs, etc.
- **When:** Debugging issues or preventing common mistakes

#### **20. Troubleshooting Guide**
- **Content:** Error messages → diagnostic steps → solutions
- **Key Points:** Swal not defined, Class not found, DataTable empty, etc.
- **When:** Something doesn't work and you need quick diagnosis

---

### **🎯 Goals & Vision (Direction)**

#### **21. Production Readiness Goals**
- **Content:** Target score 95%, core principles, quality metrics, non-negotiables
- **Key Points:** Data integrity > speed, no silent failures, test coverage matters
- **When:** Making architectural decisions or prioritizing work

---

## 🔍 **How to Use Memories Effectively**

### **Scenario 1: New Feature Development**
```
Read: 1 (Master Index) → 3 (Project Structure) → 5 (Coding Standards) → 6 (API Development)
Check: Existing infrastructure, similar implementations
Follow: API Development checklist
Test: Write tests following Testing Strategy
```

### **Scenario 2: Bug Fix**
```
Read: 19 (Common Pitfalls) → 20 (Troubleshooting)
Check: Error message against troubleshooting guide
Apply: Solution from historical cases
Verify: Run tests to prevent regression
```

### **Scenario 3: Database Change**
```
Read: 9 (Migration System) → 11 (Database Schema)
Create: PHP migration (NOT SQL)
Test: Run locally first
Deploy: Run for all tenants
Verify: Check tenant_schema_migrations table
```

### **Scenario 4: Performance Issue**
```
Read: 17 (Performance Optimization) → 11 (Database Schema)
Check: EXPLAIN query plan, verify indexes
Optimize: Add indexes via migration, avoid N+1
Measure: Before/after performance
```

### **Scenario 5: Something Doesn't Work**
```
Read: 2 (Quick Reference) → 20 (Troubleshooting)
Debug: F12 Console → Network tab → PHP error log
Check: Common pitfalls list
Review: Relevant memory for rules
```

---

## ⚡ **Critical Success Factors**

**Before ANY Code Change:**
1. ✅ Review relevant memories (5-10 minutes reading saves hours debugging)
2. ✅ Check existing infrastructure (list_dir, glob_file_search)
3. ✅ Read similar code for patterns
4. ✅ Plan the change (which services, which files)
5. ✅ Write tests first (TDD) or immediately after

**During Development:**
1. ✅ Follow checklists from memories
2. ✅ Use prepared statements
3. ✅ Validate all inputs
4. ✅ Log errors properly
5. ✅ Test incrementally

**After Implementation:**
1. ✅ Run all tests: vendor/bin/phpunit
2. ✅ Test manually in browser
3. ✅ Check Console for errors
4. ✅ Verify database changes
5. ✅ Clean up temporary files

---

## 📋 **Memory Quick Index (By Topic)**

**Database:**
- Schema & Queries (#11)
- Migration System (#9)
- Performance (#17)

**Code:**
- Coding Standards (#5)
- API Development (#6)
- Service Layer (#10)

**Testing:**
- Testing Infrastructure (#15)
- Testing Strategy (#16)

**Frontend:**
- Frontend Integration (#13)
- Page Loading (#14)

**Problems:**
- Common Pitfalls (#19)
- Troubleshooting (#20)

**System:**
- Project Structure (#3)
- Job Ticket System (#8)
- Critical Integration (#12)

---

## 🎓 **Learning Path**

**Week 1 (Foundation):**
- Day 1: Read memories 1-4 (structure, standards)
- Day 2: Read memories 5-8 (development, architecture)
- Day 3: Practice with small changes
- Day 4-5: Implement feature following checklists

**Week 2 (Mastery):**
- Day 1: Read memories 9-14 (technical deep dive)
- Day 2: Read memories 15-18 (quality & optimization)
- Day 3: Review memories 19-21 (problems & goals)
- Day 4-5: Implement complex features independently

**Beyond Week 2:**
- Reference memories as needed
- Contribute back: Update memories when finding new patterns
- Build on existing infrastructure
- Maintain 88%+ production readiness score

---

## 📞 **Support**

If memories don't cover your case:
1. Search existing code for similar implementations
2. Check docs/ directory for detailed guides
3. Review tests/ for usage examples
4. Ask specific questions referencing memory numbers

---

**Remember:** These memories are your **permanent knowledge base**. They persist across sessions and grow with the project. **Use them!**

*Generated: October 30, 2025*  
*Total Memories: 11 comprehensive guides*  
*Coverage: 100% of critical development scenarios*


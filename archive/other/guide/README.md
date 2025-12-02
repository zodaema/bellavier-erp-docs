# 📚 Development Guides - Bellavier ERP

**Purpose:** คู่มือการพัฒนาและเอกสารอ้างอิงสำหรับนักพัฒนา  
**Last Updated:** November 8, 2025

---

## 📑 Available Guides

### 🚀 Core Development Guides

| Guide | Purpose | When to Use |
|-------|---------|-------------|
| **[API_DEVELOPMENT_GUIDE.md](./API_DEVELOPMENT_GUIDE.md)** | ⭐ Complete API development guide (Enterprise template, patterns, best practices) | **START HERE** - When creating new API |
| **[SERVICE_AUTO_BINDING.md](./SERVICE_AUTO_BINDING.md)** | 🆕 Service Class Auto-Binding guide (automatic service instantiation) | When implementing service layer |
| **[SERVICE_REUSE_GUIDE.md](./SERVICE_REUSE_GUIDE.md)** | Guidelines for reusing existing services vs creating new ones | When deciding to use DatabaseHelper vs custom Service |
| **[PSR4_API_MIGRATION_AUDIT.md](./PSR4_API_MIGRATION_AUDIT.md)** | PSR-4 migration guide and structure reference | When migrating legacy code to PSR-4 |

### 🔧 Technical Guides

| Guide | Purpose | When to Use |
|-------|---------|-------------|
| **[TROUBLESHOOTING_GUIDE.md](./TROUBLESHOOTING_GUIDE.md)** | Common issues and solutions | When encountering errors or bugs |
| **[MEMORY_GUIDE.md](./MEMORY_GUIDE.md)** | AI assistant memory catalog and reading order | **For AI Agents** - Understanding project context |
| **[MIGRATION_WIZARD_GUIDE.md](./MIGRATION_WIZARD_GUIDE.md)** | Database migration system guide | When creating or running migrations |
| **[PERMISSION_MANAGEMENT_GUIDE.md](./PERMISSION_MANAGEMENT_GUIDE.md)** | Permission system architecture and usage | When working with permissions |
| **[LINEAR_DEPRECATION_GUIDE.md](./LINEAR_DEPRECATION_GUIDE.md)** | Guide for deprecating Linear system (Q3 2026) | When planning DAG migration |

### ✅ Checklists

| Checklist | Purpose | When to Use |
|-----------|---------|-------------|
| **[manual_test_checklist.md](./manual_test_checklist.md)** | Manual testing checklist | Before deploying features |

---

## 🎯 Quick Navigation

### For New Developers

1. **Start Here:** [API_DEVELOPMENT_GUIDE.md](./API_DEVELOPMENT_GUIDE.md)
   - Complete template reference
   - Step-by-step implementation
   - Enterprise features checklist

2. **Understand Architecture:** [MEMORY_GUIDE.md](./MEMORY_GUIDE.md)
   - Project structure
   - Key patterns
   - Critical rules

3. **Service Layer:** [SERVICE_REUSE_GUIDE.md](./SERVICE_REUSE_GUIDE.md)
   - When to use existing services
   - When to create new services

### For AI Agents

1. **Read First:** [MEMORY_GUIDE.md](./MEMORY_GUIDE.md)
2. **API Development:** [API_DEVELOPMENT_GUIDE.md](./API_DEVELOPMENT_GUIDE.md)
3. **Troubleshooting:** [TROUBLESHOOTING_GUIDE.md](./TROUBLESHOOTING_GUIDE.md)

### For Code Reviewers

1. **API Standards:** [API_DEVELOPMENT_GUIDE.md](./API_DEVELOPMENT_GUIDE.md) - Security, Error Policy, Best Practices
2. **PSR-4 Compliance:** [PSR4_API_MIGRATION_AUDIT.md](./PSR4_API_MIGRATION_AUDIT.md)
3. **Testing:** [manual_test_checklist.md](./manual_test_checklist.md)

---

## 📚 Related Documentation

### In `docs/` (Root Level)

- **`API_STRUCTURE_AUDIT.md`** - Complete API standards playbook
- **`API_REFERENCE.md`** - API endpoint documentation
- **`SERVICE_API_REFERENCE.md`** - Service layer documentation
- **`DATABASE_SCHEMA_REFERENCE.md`** - Database schema reference
- **`DEVELOPER_POLICY.md`** - Complete developer policy

### Templates

- **`source/api_template.php`** - Official API template (184 lines)

---

## 🔄 Guide Updates

**Version 1.5** (November 8, 2025)
- ✅ API_DEVELOPMENT_GUIDE.md upgraded to Enterprise+ Edition
- ✅ Added Security Standards section
- ✅ Added PSR-4 Service Layer integration
- ✅ Added Error Code Policy
- ✅ Added Performance & Observability Tips

---

**Last Updated:** November 8, 2025


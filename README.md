# 📚 Documentation - Bellavier Group ERP

**Last Updated:** January 2025  
**Status:** ✅ Lean & Organized

---

## 📖 Quick Navigation

### 🚀 For Developers

**Start Here:**
- **[`developer/README.md`](./developer/README.md)** - ⭐ Developer Documentation Index
- **[`developer/01-policy/DEVELOPER_POLICY.md`](./developer/01-policy/DEVELOPER_POLICY.md)** - Developer guidelines and standards
- **[`developer/02-quick-start/QUICK_START.md`](./developer/02-quick-start/QUICK_START.md)** - Quick start guide

**Core Knowledge:**
- **[`developer/03-superdag/`](./developer/03-superdag/)** - SuperDAG documentation
- **[`developer/04-api/`](./developer/04-api/)** - API documentation
- **[`developer/05-database/`](./developer/05-database/)** - Database documentation
- **[`developer/06-architecture/`](./developer/06-architecture/)** - Architecture documentation
- **[`developer/07-security/`](./developer/07-security/)** - Security documentation
- **[`developer/08-guides/`](./developer/08-guides/)** - Development guides
- **[`developer/09-serial-number/`](./developer/09-serial-number/)** - Serial Number documentation
- **[`developer/10-production/`](./developer/10-production/)** - Production documentation
- **[`developer/11-bootstrap/`](./developer/11-bootstrap/)** - Bootstrap documentation

---

## 📁 Documentation Structure

```
docs/
├── developer/                # Developer Documentation (Core Knowledge)
│   ├── 01-policy/           # Developer policy
│   ├── 02-quick-start/      # Quick start guides
│   ├── 03-superdag/         # SuperDAG documentation
│   ├── 04-api/              # API documentation
│   ├── 05-database/         # Database documentation
│   ├── 06-architecture/     # Architecture documentation
│   ├── 07-security/         # Security documentation
│   ├── 08-guides/           # Development guides
│   ├── 09-serial-number/    # Serial Number documentation
│   ├── 10-production/       # Production documentation
│   └── 11-bootstrap/        # Bootstrap documentation
├── super_dag/                # SuperDAG Task & Test Documentation
│   ├── tasks/               # Task documentation
│   ├── tests/               # Test documentation
│   └── archive/             # SuperDAG archive
├── dag/                      # DAG System Documentation
│   ├── README.md
│   ├── 01-core/            # Core documentation
│   ├── 02-implementation-status/  # Status reports
│   └── 03-comparison/      # Comparison docs
├── api/                      # API Documentation (5 files)
│   ├── README.md
│   ├── 01-reference/       # API reference
│   └── 02-audit/           # API audits
├── database/                 # Database Documentation (3 files)
│   ├── README.md
│   ├── 01-schema/          # Schema reference
│   └── 02-migration/       # Migration docs
├── user-guides/              # User Guides (6 files)
│   ├── README.md
│   ├── 01-manuals/         # Complete manuals
│   └── 02-quick-guides/    # Quick references
├── production/               # Production System (8 files)
│   ├── README.md
│   ├── 01-design/          # Design documentation
│   ├── 02-analysis/        # Analysis docs
│   └── 03-hardening/       # Hardening practices
├── architecture/             # Architecture (4 files)
│   ├── README.md
│   ├── 01-system/          # System architecture
│   └── 02-context/         # Context documentation
├── assignment-team/          # Assignment & Team (5 files)
│   ├── README.md
│   ├── 01-requirements/    # Requirements
│   └── 02-implementation/  # Implementation
├── security-risk/            # Security & Risk (3 files)
│   ├── README.md
│   ├── 01-playbook/        # Risk playbook
│   └── 02-permissions/     # Permissions
├── status-implementation/    # Status & Implementation (5 files)
│   ├── README.md
│   ├── 01-status/          # Status docs
│   └── 02-changelog/       # Changelog
├── developer/                # Developer Documentation (4 files)
│   ├── README.md
│   ├── 01-policy/          # Developer policies
│   └── 02-quick-start/     # Quick start guides
├── other/                    # Other Documentation (4 files)
├── archive/                  # Historical documents
└── README.md                 # This file
```

---

## 📋 Documentation Guidelines

### When Creating New Documentation

1. **Development Guides** → Place in `docs/guide/`
2. **User Guides** → Place in `docs/` root
3. **API Documentation** → Update `API_REFERENCE.md` or create new file in `docs/`
4. **Historical/Completed** → Move to `docs/archive/`

### When Updating Documentation

1. Update version/date in header
2. Update `README.md` if structure changes
3. Update `CHANGELOG_NOV2025.md` for major changes
4. Archive old versions if superseded

---

## 🔗 Related Documentation

- **Root Level:** `README.md`, `STATUS.md`, `CHANGELOG.md` (main changelog)
- **Changelog:** `status-implementation/02-changelog/CHANGELOG_NOV2025.md` (monthly changelog)
- **Templates:** `source/api_template.php` - Official API template
- **Archive:** `docs/archive/` - Historical documents
- **Completed Phases:** `docs/archive/completed_phases/` - Phase completion reports

---

## 📊 Statistics

- **Active Documentation:** 39 files in `docs/`
- **Development Guides:** 11 files in `docs/guide/`
- **Archived Documents:** 16 files (completed phases + obsolete)

---

**Last Updated:** November 8, 2025

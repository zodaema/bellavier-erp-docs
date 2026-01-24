# Windsurf Pack Install

This folder contains a curated `.windsurf` pack (skills + supporting resources) for this repository.

## Install

1. Ensure you already have your existing rules in `.windsurf/rules/` (you do).
2. Copy the pack’s `.windsurf` contents into your repo root `.windsurf/`.

### Option A: Finder

- Copy `docs/windsurf_pack/.windsurf/` into the repository root as `.windsurf/`.
- If you already have `.windsurf/`, merge folders.

### Option B: Terminal (merge)

Run from the repository root:

```bash
mkdir -p .windsurf
cp -R docs/windsurf_pack/.windsurf/* .windsurf/
```

## What this pack gives you

- `skills/bellavier-playbook/`:
  - A project-specific skill that loads a curated set of “canonical” ERP docs and operational doctrines as supporting resources.
  - A lightweight index that distinguishes canonical vs archived/legacy docs.

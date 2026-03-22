---
name: project_api_migration
description: API v1→v2 migration status, decisions, and deadlines
type: project
---

Migrating REST API from v1 to v2. Target completion: 2026-04-15.
**Why:** v1 auth middleware doesn't meet new compliance requirements (legal flagged it 2026-03-01).
**How to apply:** All new endpoints must use v2 patterns. Don't add features to v1 — only bug fixes until deprecation.

---

Database schema changes frozen until 2026-04-01.
**Why:** Data team is running a migration on the analytics tables.
**How to apply:** If a task requires schema changes, defer it or find a workaround with application-level logic.

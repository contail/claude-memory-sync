---
name: feedback_code_style
description: Code style corrections and confirmed patterns to follow
type: feedback
---

Don't add comments to obvious code — only comment on non-obvious logic.
**Why:** User finds over-commented code noisy and harder to read.
**How to apply:** Skip docstrings for simple functions. Only add comments where intent isn't clear from naming.

---

Use table-driven tests in Go, not individual test functions.
**Why:** Team convention, keeps test files consistent.
**How to apply:** When writing Go tests, always use `[]struct{ name, input, want }` pattern.

---

Prefer single bundled PR for related refactors over many small ones.
**Why:** User confirmed this reduces review overhead for their team.
**How to apply:** When refactoring touches multiple files for the same purpose, keep it in one PR.

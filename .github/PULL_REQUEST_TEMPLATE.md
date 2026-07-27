# Pull Request

**What does this change?**
A short summary of the change and why.

**Type**
- [ ] Feature (new query / measure / page / capability)
- [ ] Fix
- [ ] Docs
- [ ] Refactor / performance

**Checklist**
- [ ] New SQL runs against the data and is ANSI-standard (PostgreSQL-compatible)
- [ ] New DAX uses `DIVIDE` for ratios and respects semi-additive patterns
- [ ] The data-quality gate (`python -m src.quality.validate`) passes
- [ ] Docs updated (relevant `docs/*.md`) and, if user-facing, `CHANGELOG.md`
- [ ] Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:` …)

**Related issue**
Closes #

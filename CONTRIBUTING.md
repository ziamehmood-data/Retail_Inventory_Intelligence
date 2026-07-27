# Contributing

Thanks for your interest. This is a portfolio case study, but it's structured
like a real open-source project — contributions and forks are welcome.

## Ground rules

- **Stay in scope.** RIIP is a *decision-support* platform. New work should help
  someone make an inventory decision, not automate replenishment (that's Phase 3).
- **Everything traces to a business question.** New queries, measures, and pages
  should map to a stakeholder need in the BRD.
- **Reproducibility is sacred.** Keep the fixed seed and config-driven parameters;
  don't hard-code values that belong in `config/config.yaml`.

## Workflow

1. Fork and create a branch: `feature/<short-description>` or `fix/<short-description>`.
2. Make the change. Run the pipeline locally:
   ```bash
   python -m src.generator.run
   python -m src.etl.clean
   python -m src.quality.validate      # must pass (exit 0)
   ```
3. Update the relevant `docs/*.md` and `CHANGELOG.md`.
4. Open a PR using the template; ensure CI is green.

## Conventions

- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/) —
  `feat:`, `fix:`, `docs:`, `refactor:`, `perf:`, `chore:`.
- **SQL:** ANSI-standard, PostgreSQL-compatible; every business query gets a header
  comment (question, value, technique).
- **DAX:** `DIVIDE` for ratios; respect semi-additive inventory patterns; add a
  one-line explanation in `powerbi/measures/dax_measures.md`.
- **Python:** keep modules runnable via `python -m src.…`; add docstrings.
- **Naming:** follow the conventions in `docs/02-solution-architecture.md`.

## Reporting issues

Use the bug / feature templates. For anything data-quality related, include the
`active_profile` and `seed` so the result is reproducible.

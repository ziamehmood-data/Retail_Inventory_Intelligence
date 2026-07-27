# Screenshots Guide

Screenshots are what a recruiter sees first. This guide lists the shots that make
the repository land, where they live, and how to capture them consistently.

## Where they live

All images go in `docs/screenshots/`. The README references them by relative path.

## Already included

| File | What it shows |
|---|---|
| `executive_overview.png` | The Executive Overview dashboard (rendered from live figures) |
| `eda_pareto.png` | Pareto revenue curve — the 80/20 that justifies ABC |
| `eda_otif_by_tier.png` | OTIF by supplier tier — the engineered reliability signal |

## Recommended additional captures (from your built `.pbix`)

Capture these once you build the report in Power BI Desktop, for the fullest story:

1. **Executive Overview** — replace the mockup with the real page.
2. **Inventory Health** — turnover/DIO, GMROI scatter, dead-stock table.
3. **Supplier Analytics** — OTIF ranking + lead-time-variability scatter.
4. **Exceptions** — the reorder-now / stock-out worklist (the "action" page).
5. **Mobile layout** — one phone-view shot to prove responsive design.
6. **Drillthrough** — a before/after pair showing right-click → detail page.

## Capture conventions

- Export at a consistent width (1600px works well for GitHub).
- Use the same theme and the same slicer state across shots.
- Prefer PNG; keep each file under ~500 KB (downscale if needed).
- Name files `NN-page-name.png` so they sort in narrative order.

## Tip

A short **GIF** of navigating pages / using a slicer, embedded near the top of the
README, dramatically increases how "real" the project feels. Record with any
screen-capture tool and save as `docs/screenshots/demo.gif`.

# Smaller plots

The user chose smaller plots for a future single-person homestead simulation.
Use 10 × 10 m (100 m²) per plot as the implementation default, retaining the
existing 16 × 16 grid and selection controls. The map represents 2.56 ha.

## Approaches

- Keep 1,000 m² cereal fields and introduce separate small garden beds: adds a
  second plot size and its controls.
- Shrink the existing plots: the user's chosen direction. One area serves all
  crops and the existing rectangular selection still works.

## Rules

- Divide seed costs, full harvests and starting stocks by ten, preserving
  per-hectare rates and the initial five plots per cereal, six for millet.
- Store all mass as integer grams; display kilograms with up to three decimal
  places. Small harvests must not acquire the old one-kilogram minimum.
- Keep physical bag capacities, growth, weather, soil and the rendered grid.
- Update action costs, forecasts, ledger, inventory, debug stock additions,
  wiki and README together. Explain the new plot area in crop facts.
- No saves exist; no migrations. Vegetables, people and time-consuming work
  belong to subsequent changes.

## Validation

Exercise sowing at exact seed boundaries, small harvests, whole and partial
bags, displayed fractional kilograms, the documented crop table and the
existing crop, wheel, menu and audio tests. Inspect a real GPU capture.

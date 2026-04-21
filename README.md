# Howl Microscope

**Howl Microscope** is a text-first terminal test harness that runs comparable VT-core, rendering, input, and performance probes across terminals and platforms, and emits machine-readable reports plus readable markdown summaries.

## Scope

**Phase 1 (current milestone)** builds scaffolding for test definition, execution, capture, and reporting: repo layout, DSL and report contracts, a Zig CLI entrypoint, spec discovery/loading/validation, run/capture/report seams, seed probes, and placeholder artifact emission.

**Phase 1 non-goals** (aligned with `docs/Vision.md`): no rich TUI frontend, no screenshot or OCR-based workflows, and no deep automation against every terminal or platform yet.

See `docs/Vision.md` for product intent and later milestones.

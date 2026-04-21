# Handoff

Session entrypoint only. Keep this file short and current.

## Active Focus

- Product lane: text-first terminal harness
- Last accepted batch: `PH1-M39` (`PH1-M39-S1`) — launch diagnostics canonicalization hardening with corrective recovery (`ANA-3901`..`ANA-3914`); checkpoint `docs/todo/PH1_M39_CHECKPOINT.md`
- Active engineer batch: `PH1-M40` (`PH1-M40-S1`) — launch diagnostics compatibility envelope (`ANA-4001`..`ANA-4010`)
- Super-gate (Architect review): `ANA-GATE-420`
- Active queue authority: `docs/todo/implementation.md`
- Ticket board authority: `docs/todo/JIRA_BOARD.md`
- Engineer entrypoint: `docs/todo/ENGINEER_ENTRYPOINT.md`

## First Read Order

1. `docs/todo/ENGINEER_ENTRYPOINT.md`
2. `docs/todo/implementation.md`
3. `docs/todo/JIRA_BOARD.md`
4. `docs/todo/PH1_M40_TICKETS.md`
5. `docs/Vision.md`
6. `docs/WORKFLOW.md`

## Execution Contract

- Execute only `ANA-4001`..`ANA-4010` in strict order.
- One ticket per commit with `[ANA-###]` prefix.
- Stop at `ANA-GATE-420` or hard blocker.

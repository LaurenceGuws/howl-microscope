# Workflow + Docs Guide

This file defines the operating workflow and doc ownership model for Howl Microscope.

## Audience

- Contributor/operator/agent-facing.
- Not customer-facing product overview.

## Session Modes

Use one mode per session.

### Single Operation Mode (default)

- One agent executes end-to-end with user collaboration.

### Dual Agent Mode (Architect + Engineer)

Use when user explicitly requests split planning/review and execution.

Roles:

- User: product direction and priorities.
- Architect: planning, queue shaping, review gating.
- Engineer: implementation against ticketed plan.

## Jira System (Dual Mode)

- Board authority: `docs/todo/JIRA_BOARD.md`.
- **Ticket authority (dynamic sprint):** the path to the active ticket pack is **not** fixed in this file. Read `docs/todo/implementation.md` (active milestone) and `docs/todo/ENGINEER_ENTRYPOINT.md` for the current filename (for example `docs/todo/PH1_M3_TICKETS.md` during `PH1-M3`). `docs/AGENT_HANDOFF.md` also names the ticket pack in its read order. Do not assume a retired sprint file (such as an older `PH1_M1` pack) unless it is still listed there.
- One ticket should map to one commit.
- Engineer executes in strict ticket order.
- Architect owns transitions to `review_gate` and `done`.

## Reporting Contract (Engineer)

Every engineer report must include:

- `#DONE`
- `#OUTSTANDING`
- `COMMITS`
- `Blocked by Architect review needed: true|false`

Engineer should report only at checkpoint gate or hard blocker.

## Default Operating Model

Treat the repo as one active campaign with ticket-style execution.

If you cannot name the active ticket/batch, do not start coding.

## Single Mode Loop

1. Read `docs/AGENT_HANDOFF.md`.
2. Read `docs/todo/implementation.md`.
3. Confirm acceptance criteria + explicit non-goals.
4. Implement next queue cut.
5. Update queue docs.
6. Validate locally.
7. Commit only after approval unless explicitly instructed.

## Dual Mode Loop

1. Architect defines bounded batch and acceptance/non-goals.
2. Engineer executes tickets sequentially.
3. Engineer updates board + queue checkpoints.
4. Architect reviews at super-gate and accepts/rejects with corrective tickets.

## Ticket Minimum

Every executable ticket must define:

- purpose
- scope
- acceptance criteria
- non-goals
- commit contract

## Doc Placement

- `docs/AGENT_HANDOFF.md`: active focus + startup order + constraints (short).
- `docs/todo/implementation.md`: active milestone queue.
- `docs/todo/JIRA_BOARD.md`: canonical ticket board state.
- `docs/todo/ENGINEER_ENTRYPOINT.md`: engineer execution/reporting contract.
- sprint ticket pack docs: ticket-level acceptance and sequencing.
- `docs/Vision.md` and design docs: durable product/design authority.

# Agent Workflow (Howl Microscope)

## About the Project

Howl Microscope is a text-first terminal test harness intended to run comparable VT-core,
rendering, input, and performance probes across terminals/platforms, then emit
machine-readable reports and readable markdown summaries.

Near-term focus is harness infrastructure, not UI polish.

## Session Mode Orchestrator

This repo supports two explicit session modes.

### Mode A: Single Operation Mode (Default)

- One agent executes end-to-end with direct user collaboration.
- Use this mode unless the user explicitly requests dual-agent operation.

### Mode B: Dual Agent Mode (Architect + Engineer)

Roles:

- User: sets direction and approves milestone boundaries.
- Architect agent: scopes, audits, ticket-plans, and reviews.
- Engineer agent: executes the ticket list quickly and reports status.

Flow:

1. User + Architect define a bounded goal.
2. Architect reads repo docs/code and writes a ticketed plan.
3. User starts Engineer with instruction to execute ticket order.
4. Engineer response contract:
   - `#DONE`
   - `#OUTSTANDING`
   - `COMMITS`
5. Architect reviews at explicit checkpoint gate or hard blocker.
6. After acceptance, Architect must refocus queue + handoff + engineer entrypoint.

Mode discipline:

- Do not mix mode rules implicitly.
- Session must declare mode at start (`single` or `dual`).
- If mode is not explicit, use Single Operation Mode.

## Jira-Style Ticket Governance (Dual Mode)

- Ticket board authority: `docs/todo/JIRA_BOARD.md`.
- Ticket definitions authority: `docs/todo/PH1_M1_TICKETS.md` (or active sprint equivalent).
- One ticket maps to one commit unless Architect labels `atomic-pair`.
- Ticket order is strict unless Architect approves reordering.
- Engineer should continue unattended until sprint super-gate or real blocker.

## Single Operation Mode

Follow this loop:

1. Read `docs/AGENT_HANDOFF.md`.
2. Read `docs/todo/implementation.md`.
3. Read only needed authority docs under `docs/`.
4. Implement the next logical cut from the active queue.
5. Update owning docs with progress.
6. Validate locally.
7. Commit only after approval unless user explicitly asks to commit.

## Architect Gate-Closure Rule (Dual Mode)

After accepting a gate, Architect must:

1. move next batch to `in_progress` in `docs/todo/implementation.md`
2. update `docs/AGENT_HANDOFF.md` to match
3. update `docs/todo/ENGINEER_ENTRYPOINT.md` for the next batch

## Doc Scope Policy

- `docs/AGENT_HANDOFF.md`: short session entrypoint only.
- `docs/todo/`: active queues, ticket board, and execution state.
- `docs/Vision.md` and future design docs: architecture/product authority.

## Validation Policy

- Validate locally via project commands and manual checks relevant to the lane.
- Do not treat external CI as the authority for acceptance.

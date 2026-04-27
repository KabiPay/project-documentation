# Roadmap (post–Phase 1)

Phase 1 target: compile-clean Rust workspace, WunderGraph scaffold, local Postgres via Docker, env template, and UI integration stub — see `STATUS.md` for the live checklist.

## Phase 2 — Core HR (sketch)

1. **Database:** Liquibase domains `0006`–`0009` (org hierarchy → employee core → documents → custom fields), aligned with `hrms_erd_complete.md`.
2. **Services:** Implement `kabipay-employee` first (canonical `EMPLOYEE.id`), then leave and attendance subgraphs per `KABIPAY_AI_PROMPT.md` §11 Phase 2.
3. **Gateway:** Harden federation (auth headers, health), ensure `wunderctl generate` in CI once subgraphs are available offline or via mock.

## Phase 3+ — Finance, talent, platform

Follow the ordered phases in `KABIPAY_AI_PROMPT.md` §11 (sections 12–15): payroll/tax/billing, then recruitment through notification, then full UI integration and operational hardening (workflow, outbox, audit).

Pacing and quality gates are listed in `KABIPAY_AI_PROMPT.md` §11–12.

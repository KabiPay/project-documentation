# KabiPay Monorepo — Build Status

> **Single source of truth for what is done and what is pending.**
> Update this file at the end of every work session so any contributor (or any future agent session) can resume in one read.

- Last updated: 2026-04-28 (**Session:** **M34** — **Tenant Liquibase `0033-002`** adds **`travel_request.rejected_by`** (demo schema migrated). **`kabipay-analytics`**: integrations + webhook + audit GraphQL (**HR / directory RBAC**). **`kabipay-benefits`**: **`myBenefitEnrollments`**, **`enrollInBenefitPlan`**. **`kabipay-ui`**: **`clientOperations.graphql`** extended + **`npm run codegen`**. **Still:** payroll production / NACH / Form 16, connector **credentials**/vendor delivery, workflow **visual** designer — §0.2 / §12.)
- Phase in flight: **Phase 3 — authenticated client plane (JWT) + read/write GraphQL; optional migration to generated hooks**
- **Handoff (other context window):** Work continues in a fresh session. See **§0.1** and **§12** for the **one-module-at-a-time** queue.

### Completed vs remaining (queue snapshot)

| Status | Theme |
|--------|--------|
| **Done** | **M1**–**M13** (see §12); **M28** S3/R2 `s3_compat` **object_store**; **M29** payroll pay run v1 + arrears + workflow read UI + **codegen** extension fix; **M30** expense ↔ travel link in **UI** + queries; **M31** workflow **definition** write; **M32** expense **multi-step** **`workflow_instance`**; **M33** expense **outbox** on final approve; **M34** integrations/audit/webhook **GraphQL** + benefits **enroll** + travel **`rejected_by`** + **codegen**; **M10** lists: **`expenses`**, **`attendance`**, **`timesheetEntries`**, **`payslips`** / **`payslip`**, **`employeeDocuments`** (explicit **`employeeId`**), **`leaveBalances`** — all use **`kabipay_common::client_data_scope`** + JWT **`resource_scopes`**; demo seed adds **`permission_scope`** for **`expense`/`approve`** + **`attendance`/`read`** (**ALL** for **HR_ADMIN**). **M11:** **`attendance_punch_policy`** + **`punchToday`** enforcement + **`attendancePunchPolicy`** / **`upsertAttendancePunchPolicy`**. **M14–M24** per §12 (incl. **Insights**, **onboarding+exit** submit, **document `mime` in signed URL**). **M24.1** separation **HR approve/reject** (GraphQL + UI for **`admin`** role). |
| **In progress** | — |
| **Not started (high level)** | See **§0.2** — production **payroll** exports, **workflow** drag-and-drop **designer** (beyond **M31** form-based write), **expense** multi-step; optional **Azure Blob** behind **`object_store`**. |

**Suggested next work:** **§0.2** ⬜ rows — **payroll** production depth (NACH/Form 16/24Q); **integrations** connector **secrets** storage + outbound **worker** behaviour; **workflow** visual editor; **benefits enroll** UI next to Workplace read. **§10.1** Keka parity (1)–(5). **§12:** **M34** lands HR **integrations/audit/webhook** + **benefits enroll** API + **`travel_request.rejected_by`**; remaining **§0.2** ⬜ lines above, then §11.1 where **UI** is still shallow.

### 0.2 Follow-up backlog — completed vs pending (product)

| Status | Area | Notes |
|--------|------|--------|
| ✅ | **Analytics + outbox read** | **`kabipay-analytics`** (**4029**), **Insights** UI, HR **`outboxEvents`**. |
| ✅ | **Separation self-serve + HR list** | **`separations`**, **`submitSeparation`**, **Onboarding & exit** tab. |
| ✅ | **Separation HR decision** | **`approveSeparation`** / **`rejectSeparation`** (`PENDING` → `APPROVED` / `REJECTED`), same RBAC as **`createEmployee`**; UI buttons when profile **`admin`** + `PENDING`. |
| ✅ | **Signed download `mime_type`** | Token + GET prefer claim, fall back to **`file_storage.mime_type`**. |
| ✅ | **Workplace shell polish** | **TabBar**, **AppLayout** card, **Insights** + **Workflows** nav. |
| ✅ | **FNF settlement / clearance checklist** | Same GraphQL as before. UI: **Onboarding** uses **codegen** ops **`ClientOpsFnfBySeparation`**, **`ClientOpsClearanceBySeparation`**, **`ClientOpsUpsertFnf`**, **`ClientOpsFinalizeFnf`**, **`ClientOpsSetClearanceCleared`**, **`ClientOpsEnsureOffboarding`** in **`clientOperations.graphql`**. On approve: transactional seed DRAFT FNF + 4 default clearance rows. |
| ✅ | **Outbox consumer hardening** | Tenant **`0034`**: **`claimed_at`** on **`outbox_event`**. Worker: reclaim stale **`PROCESSING`** ( **`OUTBOX_STALE_PROCESSING_SEC`**, legacy **`OUTBOX_LEGACY_PROCESSING_MAX_AGE_SEC`** for NULL `claimed_at` ). **Analytics** mutation **`requeueOutboxEvent`**, Insights **Requeue** button (**`admin`** + FAILED/PROCESSING). Run **`update-tenant-liquibase.ps1`** for `claimed_at`. |
| ✅ | **GraphQL client: generated operations (client app)** | **`clientOperations.graphql`** + **`npm run codegen`** for all employee/HR UI routes; **create/edit employee** uses typed **`CreateEmployeeInput`** / **`UpdateEmployeeInput`** casts where the form builds a partial object. **2026-04-28 (M34):** **`InsightsIntegrationCatalog`**, **`InsightsTenantIntegrations`**, **`InsightsWebhookSubscriptions`**, **`InsightsAuditLogs`**, **`ConnectTenantIntegration`**, **`RegisterWebhookSubscription`**, **`SetWebhookSubscriptionActive`**, **`MyBenefitEnrollments`**, **`EnrollInBenefitPlan`**, travel fields on **`ExpenseBoard`** / approve-reject. **Exception:** **`ModuleHealth`** keeps **inline `gql`** for per-subgraph health probes (by design). |
| ✅ | **File storage: S3 / cloud (M28)** | **`KABIPAY_FILE_STORAGE_MODE`**: `local` (default) or **`s3_compat`**. **OpenDAL** + **reqsign** SigV4; **`ensure_tenant_bucket`** + upload; per-tenant **bucket** `{prefix}-{uuid}` or **`KABIPAY_S3_DEFAULT_BUCKET`** with keys **`tenant_id/file_id`**. **Azure** not implemented (enum reserved). **§0.2** below: tenant + upload behavior. |
| ✅ | **Payroll pay run v1 + arrears + workflow reads (M29)** | **`runPayrollForCycle`** with statutory **stubs** + TDS from **`tax_computation`**; tenant **0035** `payroll_arrear`, **`createPayrollArrear`**, **Payroll** UI + optional **`PayrollArrearsList`** query. **`payrollBankTransferCsv`**. **Workflow** subgraph: **`workflows`**, **`workflowsWithSteps`** (UI: step list with fallback if steps query unavailable). **DB 0036** `expense.travel_request_id`. **Codegen:** do **not** duplicate **`CreatePayrollCycleInput`** in **`schema-extensions/payroll-run.graphql`** — gateway uses **`NaiveDate`**. |
| ⬜ | **Payroll — production / compliance depth** | Bank **NACH** or tenant-specific **upload** formats; EPF/ESI/PT beyond **stubs**; **Form 16**, **24Q**, filed challan layouts (see §10). |
| 🟨 (partial) | **Workflow designer (write)** | **M31** definition **`create*`** + Admin forms. **M32:** **expense** **runtime** on **`kabipay-expense`**. **Still:** reorder/delete steps, **drag-and-drop** canvas (admin UX). Leave **runtime** remains **`kabipay-leave`**. |
| 🟨 (partial) | **Multi-step expense / travel (product)** | **M30** **`travelRequestId`**. **M32:** **`EXPENSE`** **`workflow_instance`**. **M33:** **`outbox_event`** on **final** **`approveExpense`** (**`expense.approved`**). **Still:** per-diem / budgets, drag-and-drop designer, travel multi-step. |

**File upload and “tenant” (M28):** A file upload only runs in a valid **app** context (JWT + **tenant** from gateway / ops DB / tenant connection). The code does **not** ask R2 if “the tenant exists” as a separate product object — the tenant is already resolved for the request. **LOCAL:** `KABIPAY_LOCAL_FILE_ROOT` + **`{tenant_id}/{file_id}`** (mkdir as needed). **S3 / R2 (`s3_compat`):** by default a **dedicated S3 bucket per tenant** (name **`{KABIPAY_S3_BUCKET_PREFIX}-{uuid}`**); on first use the service calls **CreateBucket** (or treats **409** as already there), then **PutObject** with key **`{file_id}`** — not a literal “folder” in one bucket, unless you use a **shared** bucket and **`KABIPAY_S3_PER_TENANT_BUCKET=0`**, in which case keys are **`{tenant_id}/{file_id}`** (prefix like a folder).

---

## 0.1 Resume after a context switch — done vs next

| Area | Status | Notes |
|------|--------|--------|
| **UI — client mutations / live reads (inline `gql` + `useGraphClient`)** | ✅ done | Expenses `submitExpense`, notifications mark read / mark all, leave `submitLeaveRequest` + Apply modal, attendance timesheet `createTimesheetEntry` + list, dashboard punch / leave balances / upcoming holidays, org documents, payroll payslip list + tax computations / upsert. `kabipay-ui` **`npm run build`** passes. |
| **`src/api/documents/clientOperations.graphql`** | ✅ added | JWT-oriented operations; keep `moduleProbes.graphql` shallow for health probes. |
| **`npm run codegen`** (`kabipay-ui`) | ✅ done (when stack is up) | **2026-04-24:** Renamed duplicate operation names, `Date` → `NaiveDate` in upcoming-holiday ops; rebuild subgraphs for full introspection. **2026-04-28:** Merged schema failed if **`payroll-run.graphql`** redefined **`CreatePayrollCycleInput`** with **`Date`** while the gateway has **`NaiveDate`** — **remove duplicate input/mutation** from extension when the supergraph provides them. **M31:** **`workflow-admin.graphql`** removed once **gateway** exposes **`createWorkflow`**. **M32 follow-up:** **`backlog-catchup`** expense **`extend`** trims removed (**`Expense`** + **`SubmitExpenseInput`**). **`schema` =** gateway URL + **`backlog-catchup.graphql`** (payroll arrear placeholders + workflow step list shims until full gateway parity) + **`payroll-run.graphql`**. `src/api/graphql/**` is **ESLint-ignored** (codegen output). |
| **ESLint / Prettier (`npm run lint`)** | ✅ done | Prettier normalize + ESLint: `max-lines-per-function` cap raised to 360, context hooks on `allowExportNames`, hook dependency fixes, `prefer-destructuring` fixes. |
| **Tenant DB — migrations after provision** | ✅ **catch-up script** | Run `.\kabipay-svc\scripts\update-tenant-liquibase.ps1 -Schema tenant_342205fc` when new tenant changeSets ship (e.g. **`0033-002`** **`travel_request.rejected_by`**, **M34**). Includes **`0032` `attendance_punch_policy`**, **`0033` `travel_request`**, etc. Then **`seed-demo-data.ps1`** (idempotent). Re-seed after **0005-007** for demo `permission_scope` rows. |
| **GitHub org — split repositories** | ✅ done (2026-04-24) | Four remotes under `https://github.com/KabiPay/`: `kabipay-database`, `kabipay-svc`, `kabipay-gateway`, `kabipay-ui` (`main` pushed). Workspace-only files (`STATUS.md`, `ROADMAP.md`, `KABIPAY_AI_PROMPT.md`, `hrms_erd_complete.md`, `kabipay.code-workspace`) are **not** in those repos by design. |
| **Punch — WGS84 GPS (browser)** | ✅ done (2026-04-24) | `punchToday(input: PunchTodayInput)` optional lat/lng → `attendance.check_in_*` / `check_out_*` (columns already in §0010-010). `source` = `WEB+GPS` when set. UI: **Record GPS location** checkbox on dashboard `PunchInOut`. Re-run `npm run codegen` after schema refresh. |
| **Admin — create / edit employee** | ✅ wired (2026-04-24) | `/admin/employees` → **Add Employee** (`createEmployee`) + **Edit** (`updateEmployee`: names, status, employment type, department, designation). Employee code + DOJ not on `UpdateEmployeeInput`. |
| **Travel request** | ✅ **0033 + `0033-002`** | **Liquibase `0033`** table + **`0033-002`** **`rejected_by`** (FK to **`user`**). **`submitTravelRequest`** / approve-reject; **`rejectTravelRequest`** records rejector; **GraphQL** exposes **`approvedBy`**, **`rejectedBy`**, **`rejectionReason`**. Demo row in **`seed-demo-data.ps1`**. |
| **Keka / market parity** | ⬜ see §10 | [Keka](https://www.keka.com) positions deep India payroll + attendance hardware + mobile + policy automation; KabiPay is API-first with gaps listed in §10. |
| **Client RBAC** | 🟨 partial (2026-04-24) | **`resource_scopes`** (M3 + **M10**): **`employee`**, **`leave`**, **`expense`**, **`attendance`** keys on JWT; applied to directory + leave + expense + attendance + payroll reads + documents list. **`createEmployee` / `updateEmployee`**: **`employee:write`**. **Leave / expense** approve: **`leave:approve`**, **`expense:approve`**. **Tax proof**: **`tax:approve`**. **Payroll statutory export**: **`payroll:statutory_export`**. **Attendance punch policy** (M11): **`attendance:punch_policy`** or HR / tenant admin roles. Re-seed for new **`permission_scope`** rows. **Dev:** `KABIPAY_EMPLOYEE_MUTATION_HEADER_OK=1` — see `kabipay-svc/.env.example`. Wider gaps → §11. |
| **Org hierarchy (M1 + M13)** | ✅ (2026-04-24) | **`departments`** + **`designations`**; **`orgChart`** + **Org chart**; **`reportingManagerId`**; **onboarding checklist** API + **Workplace** module pages (**M13–M22** v1). |
| **Approvals (M2)** | ✅ leave + expense (**M32**) | **Leave (M8):** **`workflow_instance`** when **`LEAVE_REQUEST`** definition + **`workflow_step`**; **`approve`** / **`reject`** as documented. **Expense (M32):** same for **`EXPENSE`** (**`kabipay-expense`**); **`rejectExpense`** records **`workflow_action`** (**`rejector_user_id`**). **Attendance:** **`addManualAttendanceSegment`**. **Re-seed** for **`EXPENSE`** two-step workflow + seeded claim (**`workflowInstanceId`** on **GraphQL**). |

**Why the backend was slow to run in some sessions (agent / constrained envs):** Docker may not be running or may hang on first connect; `docker compose` / `docker ps` can block. A **parallel** `cargo build --workspace` on Windows can **OOM** or hit **`rustc` stack errors**; use **`cargo build -j 1`** or **`.\kabipay-svc\scripts\build-workspace.ps1 -Jobs 2`** (see §3). If **`kabipay-auth.exe`** (or any subgraph) is already running, the linker can fail with **“Access is denied”** on replacing the `.exe` — stop the process first. In prior **full local** runs, **Postgres + `start-subgraphs.ps1` + gateway** was enough for UI **codegen** — reproduce that order when the environment allows.

---

## 0. Monorepo layout

All paths are relative to `D:\work\KabiPay\` unless otherwise noted.

```
D:\work\KabiPay\
├── kabipay.code-workspace      <- open this in Cursor / VS Code
├── STATUS.md                   <- THIS FILE
├── hrms_erd_complete.md        <- authoritative ERD (V3)
├── KABIPAY_AI_PROMPT.md        <- authoritative build spec
├── ROADMAP.md                  <- phase plan (post Phase 1)
├── kabipay-database\           <- Liquibase migrations (ops + tenant planes); Postgres is cloud or a local install
├── kabipay-svc\                <- Rust Cargo workspace, 21 service crates
├── kabipay-gateway\            <- graphql-yoga + @graphql-tools/stitch gateway (WunderGraph pivot)
└── kabipay-ui\                 <- React + Vite + TS frontend (GraphQL client + module-health dashboard)
```

**Key architectural decisions (locked):**
- Monorepo, true physical layout (UI lives inside the monorepo).
- Database isolation: `kabipay_ops` schema for control/operator plane; one dynamic `tenant_<uuid_short>` schema per tenant for client plane.
- Runtime dev mode: **Postgres** (e.g. Aiven) or local, **Rust services via `cargo run` / prebuilt binaries**, not dockerised yet.
- Gateway: **graphql-yoga + @graphql-tools/stitch** (TypeScript) stitching every Rust subgraph. (Originally targeted WunderGraph — pivoted because `github.com/wundergraph/wundergraph` is archived and the `wunderctl` release binary is permanently 404. See §6.)
- Operator portal UI: **same `kabipay-ui` repo**, role-split at runtime.

---

## 1. Current running stack (local dev)

| Component | URL / port | Status | Notes |
|-----------|------------|--------|-------|
| PostgreSQL 16 (e.g. Aiven) | `POSTGRES_HOST` / `POSTGRES_PORT` in `kabipay-database/.env` and/or `kabipay-svc/.env` (e.g. `defaultdb`, `avnadmin`, TLS) | — | Ops migrations: `cd kabipay-database` → `npm run migrate-ops`. No Docker for the database in this repo. |
| pgAdmin (local install) | Connect to the same host/port as those env files (with SSL if required) | — | — |
| Liquibase **ops** plane | schema `kabipay_ops` in `kabipay_dev` | ✅ applied (31 changesets) | See §2 |
| Liquibase **tenant** plane — demo tenant | schema `tenant_342205fc` (derived from `-Code demo`) | ✅ applied (**142** tenant changeSets incl. **`0033-002`**; re-run `update-tenant-liquibase.ps1` to match) | Provisioned via `kabipay-svc\scripts\provision-tenant.ps1 -Name 'Demo Co' -Code demo`. Seed data via `seed-demo-data.ps1`. |
| `kabipay-auth` (REST) | `KABIPAY_AUTH_PORT` (default **4001** in `main.rs` if env unset) | ✅ | Client + ops **login / refresh / logout**, Argon2id, shared JWT, refresh in `user_session` / `operator_session`. Client access tokens include **`employee_id`** when the user is linked to `employee.user_id`. **UI:** `kabipay-ui/public/config.json` `authUrl` must match. |
| 20 federated subgraphs | http://127.0.0.1:**4010-4029**/graphql | ✅ | Reads + **writes** where implemented (incl. **analytics** read APIs on **4029**). |
| Stitching gateway (`kabipay-gateway`) | http://127.0.0.1:4009/graphql | ✅ | Forwards **`Authorization`**, **`x-tenant-id`**, and (when present) **`x-forwarded-for`** / **`x-real-ip`** to subgraphs. |
| UI (`kabipay-ui`) | http://localhost:5173 | 🟨 | **Auth** can call real `/auth/*`; many module screens use **live gateway queries**; buttons that need new mutations can be enabled as queries/codegen catch up. |

### Smoke test — confirmed

```bash
# pgAdmin UI reachable in browser: http://localhost:5050
# Any federated subgraph health query (port 4010 shown):
curl -s -X POST http://127.0.0.1:4010/graphql -H "content-type: application/json" \
  --data '{"query":"{ operatorHealth }"}'
# => {"data":{"operatorHealth":"ok"}}

# Real tenant-scoped employee query (port 4013, tenant + employee seeded by the demo scripts):
curl -s -X POST http://127.0.0.1:4013/graphql `
  -H "content-type: application/json" `
  -H "x-tenant-id: 342205fc-98b1-5421-8a11-b30821c86aa0" `
  --data '{"query":"{ employee(id: \"9930d26f-283c-54e6-8772-434e618688ea\") { id employeeCode firstName lastName fullName } }"}'
# => {"data":{"employee":{"id":"...","employeeCode":"EMP0001","firstName":"Demo","lastName":"Employee","fullName":"Demo Employee"}}}
```

---

## 2. Database — `kabipay-database/` (Liquibase)

### Infrastructure (COMPLETE)

| Item | Status | Path |
|------|--------|------|
| Ops plane properties | ✅ done | `liquibase.properties` (note: `liquibaseSchemaName=public` so the history table lives in `public` — `kabipay_ops` doesn't exist until the first changeset runs) |
| Tenant plane properties (parameterised `${schema}`) | ✅ done | `liquibase-tenant.properties` |
| Ops master changelog | ✅ done | `changelog/db.changelog-master.xml` |
| Tenant master changelog | ✅ done | `changelog/tenant.changelog-master.xml` |
| README (topology, authoring rules, run commands) | ✅ done | `README.md` |
| All 31 domain directories (0000–0030) | ✅ done | `changelog/migrations/` |
| Ops integration connector catalog (cross-schema FK from tenant) | ✅ done | `0005_integration_connector_catalog/integration_connector_catalog.xml` |

### Migrations — 31 of 31 authored, OPS 31/31 APPLIED to local DB

Ops changeset count applied to `kabipay_dev` on 2026-04-21: **31**. Tenant changelog (domains `0005`–`0030`) is **applied per tenant schema** when you run `provision-tenant.ps1` (full apply) or `update-tenant-liquibase.ps1` (catch-up on an **existing** schema). Demo schema `tenant_342205fc` is **intended** to be fully applied after §7.1; if a **new** changeSet ships later (e.g. `timesheet_entry`), re-run the update script for that schema (see §0.1 / §7.9).

| # | Domain | Plane | Authored | Applied to local DB |
|---|--------|-------|----------|---------------------|
| 0000 | Foundation (schema, pgcrypto, `set_updated_at` fn) | ops | ✅ | ✅ |
| 0001 | Operator plane | ops | ✅ | ✅ |
| 0002 | Control plane (tenant, feature flags, country cfg) | ops | ✅ | ✅ |
| 0003 | Module catalog + subscription | ops | ✅ | ✅ |
| 0004 | Billing (invoices, payments) | ops | ✅ | ✅ |
| 0005a | Integration connector catalog (ops) | ops | ✅ | ✅ |
| 0005 | Auth + RBAC | tenant | ✅ | ⬜ per-tenant |
| 0006 | Org hierarchy | tenant | ✅ | ⬜ per-tenant |
| 0007 | Employee core | tenant | ✅ | ⬜ per-tenant |
| 0008 | Document system | tenant | ✅ | ⬜ per-tenant |
| 0009 | Custom fields | tenant | ✅ | ⬜ per-tenant |
| 0010 | Time / shift / roster | tenant | ✅ | ⬜ per-tenant |
| 0011 | Leave | tenant | ✅ | ⬜ per-tenant |
| 0012 | Payroll | tenant | ✅ | ⬜ per-tenant |
| 0013 | Tax + statutory | tenant | ✅ | ⬜ per-tenant |
| 0014 | Benefits | tenant | ✅ | ⬜ per-tenant |
| 0015 | Expense | tenant | ✅ | ⬜ per-tenant |
| 0016 | Recruitment | tenant | ✅ | ⬜ per-tenant |
| 0017 | Onboarding / offboarding | tenant | ✅ | ⬜ per-tenant |
| 0018 | Performance | tenant | ✅ | ⬜ per-tenant |
| 0019 | LMS | tenant | ✅ | ⬜ per-tenant |
| 0020 | Succession | tenant | ✅ | ⬜ per-tenant |
| 0021 | Compensation | tenant | ✅ | ⬜ per-tenant |
| 0022 | Assets | tenant | ✅ | ⬜ per-tenant |
| 0023 | Grievance | tenant | ✅ | ⬜ per-tenant |
| 0024 | Analytics | tenant | ✅ | ⬜ per-tenant |
| 0025 | Workflow engine | tenant | ✅ | ⬜ per-tenant |
| 0026 | Integrations | tenant | ✅ | ⬜ per-tenant |
| 0027 | Communication + audit | tenant | ✅ | ⬜ per-tenant |
| 0028 | Tenant master data | tenant | ✅ | ⬜ per-tenant |
| 0029 | File storage | tenant | ✅ | ⬜ per-tenant |
| 0030 | Outbox events | tenant | ✅ | ⬜ per-tenant |

**Prerequisite:** Run ops migrations (including `kabipay_ops.integration_connector`) before provisioning tenants that execute domain `0026` (cross-schema FK from `tenant_integration`).

**Deferred FKs (optional follow-up):** Add explicit FKs from legacy `file_storage_id` UUID columns to `${schema}.file_storage` now that `0029` exists; add `workflow_instance_id` FKs to `workflow_instance` where those columns exist. `statutory_filing.statutory_body_id` references ops-plane `statutory_body` logically (no cross-schema FK).

### How we ran Liquibase (reference)

From `kabipay-database/`, after `npm install`, with `kabipay-database/.env` (and/or `kabipay-svc/.env`) configured:

```powershell
npm run migrate-ops
```

This uses `migrate-ops.cjs` and the bundled Liquibase JRE (under `vendor/` if `JAVA_HOME` is unset).

---

## 3. Services — `kabipay-svc/` (Rust Cargo workspace)

### Workspace infrastructure (COMPLETE)

| Item | Status | Path |
|------|--------|------|
| Root `Cargo.toml` (24 members: `kabipay-common` + `kabipay-db-entities` + 20 GraphQL subgraphs + **`kabipay-auth`** + **`kabipay-analytics`** + **`kabipay-outbox-worker`**, pinned deps) | ✅ done | `Cargo.toml` |
| Scaffold generator script (idempotent) | ✅ done | `scaffold-services.ps1` |
| `cargo check --workspace` has been run at least once | ✅ done | — |
| All app binaries build (`target/debug/kabipay-*.exe`, incl. **analytics** + outbox worker) | ✅ done | See §3 build note |
| `scripts/start-subgraphs.ps1` to boot all 20 GraphQL subgraphs | ✅ done | `scripts/start-subgraphs.ps1` (4010–4029) |
| **`scripts/build-workspace.ps1`** — one command = **`cargo build --workspace`** (optional **`-Jobs 2`**) | ✅ done | Rebuild **all** subgraph binaries after shared-crate edits — avoids cherry-picking **`cargo build -p …`** repeatedly. |

**Build note (Windows):** `cargo build --workspace` OOMs on this machine (paging file too small, `os error 1455`). Prefer **`.\scripts\build-workspace.ps1 -Jobs 2`** or the per-crate loop below:

```powershell
Set-Location D:\work\KabiPay\kabipay-svc
cargo build -p kabipay-common
cargo build -p kabipay-db-entities
Get-ChildItem crates -Directory | Where-Object { $_.Name -ne 'kabipay-common' -and $_.Name -ne 'kabipay-db-entities' } `
  | ForEach-Object { cargo build -j 1 -p $_.Name }
```

### Shared library — `kabipay-common` (COMPLETE)

| Module | Status | Purpose |
|--------|--------|---------|
| `lib.rs` | ✅ done | Re-exports all modules |
| `error.rs` | ✅ done | Canonical `KabiPayError` (12 variants) + GraphQL/HTTP mapping |
| `context.rs` | ✅ done | `OperatorContext`, `ClientContext`, `ScopeType`, JWT claims |
| `db.rs` | ✅ done | `TenantDbCache`, `resolve_tenant_db` + **`kabipay_ops.tenant_database` lookup** (with derived-schema fallback + Docker host rewrite), see `db.rs` |
| `subgraph.rs` | ✅ done | `resolve_client_employee_id` (JWT `employee_id` or `user`→`employee` lookup) for self-service resolvers |
| `pagination.rs` | ✅ done | `PageInput`, `PageInfo`, tests |
| `jwt.rs` | ✅ done | Dual-issuer encode/decode, bearer extraction |
| `telemetry.rs` | ✅ done | `init_tracing(service_name)` — JSON or compact |
| `ids.rs` | ✅ done | Newtype wrappers: `TenantId`, `UserId`, `EmployeeId`, ... |
| `middleware.rs` | ✅ done | JWT extraction middleware skeletons |

### Shared entities — `kabipay-db-entities` (COMPLETE)

SeaORM `Model` / `Entity` types for tenant domains `0005`–`0030` plus `kabipay_ops.integration_connector`. Generated by `scripts/generate_db_entities.py`. Each subgraph re-exports its slice from `src/entities/mod.rs`.

### Shared subgraph scaffolding — `kabipay-common::subgraph` (COMPLETE)

All federated subgraphs now boot via `kabipay_common::subgraph::serve_subgraph(cfg, schema_builder)`:

- Reads `KABIPAY_<SVC>_PORT` (default per subgraph), `DATABASE_URL` / `POSTGRES_*` env vars.
- Opens the ops `DatabaseConnection` + `TenantDbCache` (when `needs_db = true`) and injects them into the schema data.
- Serves `/graphql` (playground + POST handler) and `/healthz`, with `CorsLayer::permissive()` + `TraceLayer` on top.
- Extracts **`Authorization: Bearer` (client JWT)** or dev `x-tenant-id` into `TenantId` + optional `ClientClaims`.
- Resolvers obtain their SeaORM connection via `tenant_db` / `ops_db`.

This collapses ~70 lines of boilerplate per crate into one function call. `kabipay-employee` was the first to adopt it; every other subgraph followed.

### Service crates — 1 REST auth service + 20 web GraphQL subgraphs

Legend: **`kabipay-auth`** = REST; others = GraphQL (queries + mutations where listed).

| Port | Crate | Status | First queries / notes |
|------|-------|--------|------------------------|
| 4001 | `kabipay-auth` | ✅ REST | `/auth/ops/*`, `/auth/client/*` login, refresh, logout; JWT includes **`employee_id`** when linked. |
| 4010 | `kabipay-operator` | ✅ ops | `operatorUsers`, `operatorRoles` (on `kabipay_ops.*`) |
| 4011 | `kabipay-tenant` | ✅ ops | `tenants`, `modules`, `tenantSubscriptions` |
| 4012 | `kabipay-billing` | ✅ ops | `invoices`, `payments` |
| 4013 | `kabipay-employee` | ✅ tenant | `employee`, `employees`, **`orgChart`** (M13), …; **M9** **`Employee` `@key`** + **`_entities`**; **M5** uploads + signed URL; **`GET /files/employee-document`** (custom `main.rs`) |
| 4014 | `kabipay-leave` | ✅ tenant | `leaveTypes`, `leaveRequests`, `leaveBalances`; `submitLeaveRequest`, `approveLeaveRequest`, `rejectLeaveRequest`; **`approveLeaveRequest`** enqueues **`outbox_event`** (`event_type` **`leave_request.approved`**, Gap G / **M6**) |
| 4015 | `kabipay-attendance` | ✅ tenant | `shifts`, `attendance`, `upcomingHolidays`, `timesheetEntries`, `attendancePunchPolicy` (HR / tenant admin); `punchToday`, `addManualAttendanceSegment`, `createTimesheetEntry`, `deleteTimesheetEntry`, `upsertAttendancePunchPolicy` |
| 4016 | `kabipay-payroll` | ✅ tenant | `salaryComponents`, `payrollCycles`, `payslip`, `payslips`; **`indiaTdsMonthlySummaryCsv`**, **`indiaPfEsiMonthlySummaryCsv`** (India statutory CSV stubs, RBAC-gated) |
| 4017 | `kabipay-tax` | ✅ tenant | `taxConfigurations`, `taxSlabs`, `taxComputations`, **`taxProofLines`**; `upsertTaxComputation`, **`submitTaxProofLine`**, **`approveTaxProofLine`**, **`rejectTaxProofLine`** — **`totalDeductions`** recomputed from **APPROVED** proof lines only |
| 4018 | `kabipay-benefits` | ✅ tenant | `benefitTypes`, `benefitPlans`; **`myBenefitEnrollments`**, **`enrollInBenefitPlan`** (**M34**) |
| 4019 | `kabipay-expense` | ✅ tenant | `expenseCategories`, `expenses`; `submitExpense`, `approveExpense`, `rejectExpense`; **M32** **`workflow_instance`**; **M33** **`outbox_event`** **`expense.approved`** on final approve |
| 4020 | `kabipay-recruitment` | ✅ tenant | `jobPostings`, `applications` |
| 4021 | `kabipay-performance` | ✅ tenant | `reviewCycles`, `goals` |
| 4022 | `kabipay-lms` | ✅ tenant | `skills`, `courses` |
| 4023 | `kabipay-succession` | ✅ tenant | `competencies`, `talentPools` |
| 4024 | `kabipay-compensation` | ✅ tenant | `salaryBands`, `compensationReviewCycles` |
| 4025 | `kabipay-assets` | ✅ tenant | `assetCategories`, `assets` |
| 4026 | `kabipay-grievance` | ✅ tenant | `grievanceCategories`, `grievanceCases` |
| 4027 | `kabipay-workflow` | ✅ tenant | `workflows`, `workflowInstances`, **`workflowsWithSteps`** / **`workflowSteps`** reads; **`createWorkflow`**, **`createWorkflowStep`** (**M31**) |
| 4028 | `kabipay-notification` | ✅ tenant | `announcements`, `notifications`; mutations **`markNotificationRead`**, **`markAllNotificationsRead`** |
| 4029 | `kabipay-analytics` | ✅ tenant | **`reportDefinitions`**, **`reportSchedules`**, **`dashboards`**, **`dashboardWidgets`**, **`workforceSnapshots`**; **`outboxEvents`**, **`requeueOutboxEvent`**; **`integrationConnectors`**, **`tenantIntegrations`**, **`webhookSubscriptions`**, **`auditLogs`** + connect/webhook mutations (**HR / directory RBAC**, **M34**) |

**Each subgraph contains:** `Cargo.toml`, `src/main.rs` (one call to `serve_subgraph`), `resolvers` (`QueryRoot` + `MutationRoot` when writes exist), `types`, and `services` (SeaORM; tenant + soft-delete filters).

**Decimals on the wire:** every `rust_decimal::Decimal` field is exposed as a `String` in the GraphQL DTO. This keeps wire representation lossless without dragging `rust_decimal` into the schema for every subgraph.

**SeaORM entities for the ops plane:** added in `kabipay-db-entities/src/ops/` — `tenant`, `tenant_database`, `module`, `tenant_subscription`, `invoice`, `payment`, `operator_user`, `operator_role`. These back `kabipay-operator`, `kabipay-tenant`, `kabipay-billing`.

**Workspace build:** `cargo build --workspace` now completes (~6 min first time, warm incremental much faster) on a machine with the Windows paging-file OOM workaround applied. Use `cargo build -j 2 --workspace` to keep memory bounded.

---

## 4. Gateway — `kabipay-gateway/` (graphql-yoga + @graphql-tools/stitch)

**WunderGraph pivot (2026-04-23).** The `github.com/wundergraph/wundergraph` repository now returns 404 and `wunderctl`'s postinstall hook can no longer fetch its Go binary. Rather than block on a vendor whose distribution is gone, we replaced WunderGraph with a lightweight Node.js stitching gateway.

| Item | Status | Notes |
|------|--------|-------|
| `package.json` — `graphql`, `graphql-yoga`, `@graphql-tools/{stitch,executor-http,utils,wrap}` | ✅ done | `npm install` succeeds without downloading any external binaries. |
| `tsconfig.json` (`moduleResolution: Bundler`, ES2022) | ✅ done | |
| `src/subgraphs.ts` — canonical list of all 20 subgraph ports + plane | ✅ done | |
| `src/server.ts` — introspect every subgraph, stitch, serve `/graphql` on port 4009 | ✅ done | Skips unreachable subgraphs with a warning so partial fleets still work in dev. |
| **`Authorization` +** tenant header forwarding through every stitched executor | ✅ done | Forwards `authorization` and `x-tenant-id` (see `server.ts`). |
| `npm run dev` / `npm run start` (tsx) | ✅ done | `VITE`/`.env.example` updated with `KABIPAY_GATEWAY_PORT=4009`. |
| Federation-aware routing (entity resolution via `@key`) | ⬜ pending | Stitching covers root queries today — add cross-subgraph `@key` relations once we have concrete user journeys that span services. |

**How to run it:**

```powershell
# 1. Start all subgraphs
powershell -ExecutionPolicy Bypass -File .\kabipay-svc\scripts\start-subgraphs.ps1

# 2. Start the stitching gateway (in another shell)
cd D:\work\KabiPay\kabipay-gateway
npm install      # one-time
npm run dev      # http://127.0.0.1:4009/graphql
```

Yoga exposes a GraphiQL explorer at the same URL; send `x-tenant-id: <uuid>` as a header to hit tenant-plane queries.

---

## 5. UI — `kabipay-ui/`

The app is present at `D:\work\KabiPay\kabipay-ui\`. If you still keep a separate clone at `D:\work\KabiPay-UI\`, use `scripts\move-ui-into-monorepo.ps1` (from a PowerShell **outside** Cursor).

| Item | Status |
|------|--------|
| In-repo path `kabipay-ui\` | ✅ present |
| `public/config.json` + `src/config.ts` — runtime gateway/auth/tenant (no Vite `VITE_*` env) | ✅ done |
| Business screens | ✅ many routes use **live GraphQL**; some areas still use mocks or admin-only depth |
| `graphql` + `graphql-request` | ✅ done |
| `@graphql-codegen/cli` + `client-preset` | ✅ done |
| `codegen.ts` + `src/api/schema-extensions/*.graphql` | ✅ done | Merged with gateway for codegen; **avoid** re-declaring input types the gateway already defines (see **§0.1**). Run `npm run codegen` after the gateway is up. |
| `src/api/client.ts` — plane + optional `tenantId` → auto-forwards `Authorization` + `x-tenant-id` headers | ✅ done |
| `src/hooks/useGraphClient.ts` — reads current tenant from `TenantContext`, memoises a tenant-aware client | ✅ done |
| `src/auth/tokenStore.ts` (access + refresh, localStorage for refresh) | ✅ done |
| `src/api/documents/moduleProbes.graphql` | ✅ done | Regenerate after gateway schema changes. |
| `src/api/documents/clientOperations.graphql` | ✅ done | Authenticated / employee-scoped ops (see §0.1). |
| `src/modules/admin/ModuleHealth.tsx` | ✅ done | |
| **AuthContext → real `/auth/client/*`** + bearer to gateway | ✅ done | Configure `kabipay-ui/public/config.json` (`authUrl`, `gatewayUrl`, `devTenantId`). |
| **Major module screens** — core **reads + key mutations** | ✅ done (inline) | Submits wired per §0.1; **generated hooks** still optional after `codegen`. |
| Run **`npm run codegen`** (gateway + **≥1** subgraph) | ✅ done | `src/api/graphql/` generated when gateway + subgraphs are up. |
| **`npm run lint`** | ✅ done | See §0.1. |

---

## 6. Known blockers

1. **WunderGraph is dead (RESOLVED by pivot).** `github.com/wundergraph/wundergraph` is archived; `wunderctl`'s postinstall can no longer fetch its Go binary. Resolution: replaced with a `graphql-yoga` + `@graphql-tools/stitch` gateway at `kabipay-gateway/`. All WunderGraph artefacts (`.wundergraph/`, `scripts/install-wunderctl.cjs`) were removed.
2. **Windows paging-file OOM on `cargo build --workspace`.** Worked around by building with `-j 1` or `-j 2`. Long-term fix: raise virtual memory, or add a `.cargo/config.toml` with `[build] jobs = 2` locally. A full workspace build (19 subgraphs + common + auth) now completes in ~6 minutes cold.
3. **`pwsh` (PowerShell 7) not installed.** All scripts target Windows PowerShell 5.1 (`powershell.exe`). Do not add pwsh-only syntax.
4. If you use **Docker** for other tooling, Docker Desktop must be running before `docker` commands. Error `open //./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified.` means Docker Desktop is stopped. (Postgres and Liquibase in this repo do not require Docker.)

---

## 7. Next session — ordered execution plan

Each step is standalone. Stop at any point and update this file.

### 7.1 Provision a demo tenant end-to-end ✅ DONE (2026-04-23)

```powershell
Set-Location D:\work\KabiPay
powershell -ExecutionPolicy Bypass -File .\kabipay-svc\scripts\provision-tenant.ps1 -Name 'Demo Co' -Code demo
# Creates tenant_342205fc schema, upserts kabipay_ops.tenant / tenant_database rows,
# runs Liquibase tenant changelog (count grows with new domains; see tenant.changelog-master.xml).
powershell -ExecutionPolicy Bypass -File .\kabipay-svc\scripts\seed-demo-data.ps1 `
    -TenantId 342205fc-98b1-5421-8a11-b30821c86aa0 -Schema tenant_342205fc
# Inserts Engineering / Software Engineer / demo user / Demo Employee rows (all deterministic UUIDs).
```

### 7.2 Wire real `employee(id)` in `kabipay-employee` ✅ DONE (2026-04-23)

- `src/services/employee_service.rs` applies `tenant_id` + `is_deleted = false` on every SeaORM query (Gaps A + B).
- `src/resolvers/{query,types}.rs` expose `employee(id: ID!)` and `employees(limit: Int = 20, max 100)` returning `EmployeeDto`.
- `src/main.rs` builds the ops pool + `TenantDbCache` at startup and wires an `x-tenant-id` header extractor into the GraphQL context. Once `kabipay-auth` issues JWTs, replace the header extractor with a proper `client_auth` middleware.
- Pinned `async-graphql-axum = "=7.0.13"` in the workspace to keep `axum = 0.7` (7.1+ pulls axum 0.8 and breaks the Handler bounds across the workspace).

### 7.3 Port the common subgraph pattern to every service ✅ DONE (2026-04-23)

- Extracted `kabipay_common::subgraph::serve_subgraph` + `TenantId` + `require_tenant_id` + `tenant_db` + `ops_db`.
- Refactored `kabipay-employee` onto it (zero behaviour change, ~70 lines of boilerplate removed).
- Implemented one or two read queries for every other subgraph (`kabipay-leave`, `…-attendance`, `…-payroll`, `…-tax`, `…-benefits`, `…-expense`, `…-recruitment`, `…-performance`, `…-lms`, `…-succession`, `…-compensation`, `…-assets`, `…-grievance`, `…-workflow`, `…-notification`) plus the ops-plane trio (`…-operator`, `…-tenant`, `…-billing`).
- Added SeaORM entities for the ops tables the new ops-plane subgraphs need (`kabipay-db-entities::ops::{tenant,tenant_database,module,tenant_subscription,invoice,payment,operator_user,operator_role}`).
- `cargo build --workspace` is green.

### 7.4 Gateway ✅ DONE (2026-04-23, pivot)

- Replaced WunderGraph with `graphql-yoga` + `@graphql-tools/stitch`. See §4.
- Gateway listens on http://127.0.0.1:4009/graphql with GraphiQL, introspects every subgraph at startup, forwards `x-tenant-id` through each stitched executor, and tolerates missing subgraphs.

### 7.5 Extend `seed-demo-data.ps1` ✅ DONE (2026-04-23)

`kabipay-svc\scripts\seed-demo-data.ps1` now seeds one deterministic row per domain across both planes, idempotently (`ON CONFLICT DO NOTHING`):

- Tenant plane: `leave_type` (x2) + `leave_request`, `shift` (x2) + `attendance`, `salary_component` (x2) + `payroll_cycle`, `tax_configuration_version` + `tax_slab` (x2), `benefit_type` + `benefit_plan`, `expense_category` + `expense`, `job_posting` + `application`, `review_cycle` + `goal`, `skill` + `course`, `competency` + `talent_pool`, `salary_band` + `compensation_review_cycle`, `asset_category` + `asset`, `grievance_category` + `grievance_case`, `workflow` + `workflow_instance`, `announcement` + `notification`.
- Ops plane (`kabipay_ops`): 4 modules (`EMPLOYEE`, `LEAVE`, `PAYROLL`, `RECRUITMENT`), 2 tenant subscriptions, current-month `billing_cycle`, 1 pending `invoice`, 1 succeeded `payment`, 2 operator roles (`ADMIN`, `SUPPORT`), 1 operator user.

Also aligned `kabipay-ui/src/api/documents/moduleProbes.graphql` and `ModuleHealth.tsx` with the actual DTO field names (attendance uses `checkInTime`/`checkOutTime`, tax uses `regime`/`countryCode`/`fiscalYear`, payroll uses `month`/`year`/`paymentDate`, recruitment uses `vacancies`/`jobId`/`status`, LMS uses `durationMinutes`, etc.). `codegen.ts` reads `gatewayUrl` from `kabipay-ui/public/config.json` (optional override: `CODEGEN_SCHEMA_URL`).

Smoke test: run `npm run dev` in `kabipay-gateway/` + `kabipay-ui/`, then open `/admin/module-health` with the demo `x-tenant-id` — every tile should turn green.

### 7.6 Wire `kabipay-auth` login flow ✅ DONE (2026-04-24)

- Implemented: client + ops login, refresh, logout; `operator_session` + `user_session` refresh storage; JWT with `iss` separation; **client tokens carry `employee_id`** when resolvable.
- Subgraphs: **`Authorization` Bearer** + dev `x-tenant-id`; `KABIPAY_REQUIRE_AUTH=1` to disable header-only access.

### 7.7 Implement `kabipay_ops.tenant_database` lookup ✅ DONE (2026-04-24)

- `resolve_tenant_db` / cache use **`tenant_database`** rows; host rewrite for Docker vs host; derived schema kept as fallback.

### 7.8 UI integration 🟨 PARTIAL (mutations done inline; polish remains)

- Auth + many screens: **live reads**; **core mutations** are wired with **inline `gql`** (expense submit, notifications, leave apply, timesheet, punch, payslips, tax upsert, org docs) — see §0.1.
- **Pending:** optional migration to **generated** `graphql()` hooks from `src/api/graphql/`. **`npm run lint`** and **`npm run build`** are green; **`npm run codegen`** re-run when the schema changes.

### 7.9 GraphQL write + read APIs (batch, 2026-04-24) ✅

| Area | Added (GraphQL / REST) |
|------|-------------------------|
| Leave | `leaveBalances`, `submitLeaveRequest`, `approveLeaveRequest`, `rejectLeaveRequest` (**approve** → **`outbox_event`**, M6 / §7.12) |
| Attendance | `upcomingHolidays`, `punchToday`, `timesheetEntries`, `createTimesheetEntry`, `deleteTimesheetEntry` |
| Payroll | `payslip`, `payslips` (+ `lines`) |
| Tax | `taxComputations`, `taxProofLines`, `upsertTaxComputation`, `submitTaxProofLine`, `approveTaxProofLine`, `rejectTaxProofLine` (approved **actual** amounts sum into `totalDeductions`) |
| Expense | `submitExpense`, `approveExpense`, `rejectExpense` |
| Notification | `markNotificationRead`, `markAllNotificationsRead` |
| Employee | `documentTypes`, `employeeDocuments`, `createEmployee`, `updateEmployee` |

**Database:** new tenant changeSet **`0010-012-create-timesheet-entry`** (`timesheet_entry` table). **Existing** demo schemas must run **`kabipay-svc\scripts\update-tenant-liquibase.ps1 -Schema tenant_342205fc`** (or your schema) so Liquibase applies pending changeSets, then restart `kabipay-attendance`.

### 7.10 Punch GPS + admin/travel UI (2026-04-24) ✅

- **Attendance:** `PunchTodayInput` (`latitude` / `longitude` optional pair) on `punchToday`; stored on `attendance.check_in_lat` / `check_in_lng` / `check_out_lat` / `check_out_lng` (Liquibase `0010-010`). No new changeSet. Restart **`kabipay-attendance`** and gateway after pulling.
- **UI:** Dashboard punch card: optional **Record GPS** + `navigator.geolocation` — requires HTTPS or localhost; user can disable if permission denied.
- **Admin / Expenses:** see §0.1 table.

### 7.11 India payroll — TDS monthly summary CSV (M4, 2026-04-24) ✅

- **Payroll subgraph:** query **`indiaTdsMonthlySummaryCsv(month: Int!, year: Int!)`** returns **CSV** (header always; data rows when a **`payroll_cycle`** matches calendar **month/year** and payslips exist). Columns include employee code, name, primary PAN, gross, deductions, **`tds_amount`**, net, payslip id.
- **RBAC:** JWT **`payroll:statutory_export`** or **HR_ADMIN** / **TENANT_ADMIN** / **ORG_ADMIN** (same pattern as other approver gates).
- **Demo seed:** `seed-demo-data.ps1` — **`employee_pan`** row, **`payslip`** row linked to current-month cycle, permission + **`role_permission`** for HR_ADMIN. Re-seed old DBs to pick up **`payroll:statutory_export`** on the demo user.
- **UI:** `kabipay-ui` **Payroll** module page — month/year + **Download CSV**. `clientOperations.graphql` documents the operation for **`npm run codegen`**.

### 7.12 Outbox pattern — leave approval (M6, Gap G, 2026-04-24) ✅

- **`kabipay-leave`** / **`leave_service::approve_leave_request`:** after updating **`leave_request`** + **`leave_balance`**, inserts one **`outbox_event`** row **before** `COMMIT` (atomic with the approval).
- **Event:** `aggregate_type = leave_request`, `aggregate_id = leave_request.id`, `event_type = leave_request.approved`, `payload` = JSON (`schema_version`, employee, approver, type, dates, `days_requested`, status).
- **Consumer (M7, 2026-04-24):** binary **`kabipay-outbox-worker`** — lists **`kabipay_ops.tenant_database`** (`is_active`), resolves each tenant DB, claims **`PENDING`** rows with **`FOR UPDATE SKIP LOCKED`**, sets interim **`PROCESSING`** + **`claimed_at`** (**`0034`**), delivers (**`tracing`** + optional **`OUTBOX_WEBHOOK_URL`** POST), then **`PROCESSED`** + **`processed_at`** or requeue / **`FAILED`** with **`retry_count`** / **`last_error`** (cap **`OUTBOX_MAX_RETRIES`**). Run: `cargo run -p kabipay-outbox-worker` (same Postgres env as subgraphs). Poll interval **`OUTBOX_POLL_MS`** (default 2000). **M26 (2026-04-28):** per-tenant sweep **reclaims** stale **`PROCESSING`** ( **`OUTBOX_STALE_PROCESSING_SEC`** / **`OUTBOX_LEGACY_PROCESSING_MAX_AGE_SEC`** ). HR: **`requeueOutboxEvent`** in **`kabipay-analytics`**, Insights **Requeue** for FAILED/PROCESSING.

### 7.13 Workflow + leave (M8, Gap D, 2026-04-24) ✅

- **Definition:** active **`workflow`** row with **`entity_type = LEAVE_REQUEST`** (see **`seed-demo-data.ps1`**) and at least one **`workflow_step`** (`sequence_order` ordering). If missing, leave approval behaves as before (no **`workflow_instance_id`**).
- **`submitLeaveRequest`:** after inserting **`leave_request`**, creates **`workflow_instance`** (`status` **`IN_PROGRESS`**, **`current_step_id`** = lowest **`sequence_order`**) and sets **`leave_request.workflow_instance_id`** in the same transaction.
- **`approveLeaveRequest`:** appends **`workflow_action`** (**`APPROVE`**) for the current step; if a higher **`sequence_order`** step exists, advances **`current_step_id`** only (request stays **`PENDING`**; no balance/outbox change). On the last step, sets instance **`COMPLETED`**, then applies **`APPROVED`** + balance + **`outbox_event`** (**M6**).
- **`rejectLeaveRequest`:** when instance **`IN_PROGRESS`**, records **`workflow_action`** (**`REJECT`**, remarks = reason) and sets instance **`CANCELLED`**, then existing reject + balance release.
- **GraphQL:** **`LeaveRequest.workflowInstanceId`** (optional **ID**).
- **`kabipay-workflow`** subgraph (**M31**): **`createWorkflow`**, **`createWorkflowStep`** for **definition** admin (JWT **`workflow:manage`** or HR / tenant admin). **Leave** approval **runtime** mutations remain in **`kabipay-leave`**; list/read **`workflows`** + instances unchanged.

### 7.14 Federation — `Employee` `@key` (M9, 2026-04-24) ✅

- **`kabipay-employee`:** `QueryRoot` implements **`#[graphql(entity)] find_employee_by_id`**, sharing resolution with **`employee(id)`** via **`resolve_employee_dto`** (tenant header / JWT, **`resource_scopes`**, soft-delete).
- Subgraph SDL (via **`_service { sdl }`**) includes **`type Employee @key(fields: "id")`** when federation is enabled (**`enable_federation()`** in **`main.rs`** — already present).
- **Gateway:** **`kabipay-gateway`** uses **`stitchSchemas`** without **`typeMerging`** today; a **single** owning subgraph for **`Employee`** is enough for current schemas. If another subgraph later defines **`Employee`**, add merge config (see GraphQL Tools stitch docs).

### 7.15 `resource_scopes` list sweep (M10, Gap H, 2026-04-24) ✅

- **Shared:** **`kabipay_common::client_data_scope`** — **`EmployeeScopeFilter`**, **`resolve_employee_scope_filter`**, **`data_scope_from_context`**, **`resolve_viewer_employee`**, **`employee_model_in_scope`** (aligned with **`employee`** list rules).
- **Constants:** **`SCOPE_RES_EXPENSE`**, **`SCOPE_RES_ATTENDANCE`** in **`context.rs`**; payslips reuse **`SCOPE_RES_EMPLOYEE`**.
- **Seed:** **`permission_scope`** rows **`expense`/`approve`** and **`attendance`/`read`** → **`ALL`** for demo **HR_ADMIN** (merge with existing **`employee`** / **`leave`** rows in JWT).

### 7.16 Attendance punch policy — geofence + IP (M11, 2026-04-24) ✅

- **Liquibase:** tenant **`0032_attendance_punch_policy`** → table **`attendance_punch_policy`** (one row per tenant: **`is_enforced`**, optional site lat/lng + **`max_distance_meters`**, optional **`ip_allowlist`** text).
- **`kabipay-common`:** **`ClientRequestHints`** injected in **`tenant_graphql_post`** — **`client_ip`** from first hop **`X-Forwarded-For`** or **`X-Real-IP`** (gateway must forward).
- **`kabipay-attendance`:** **`punchToday`** loads policy and rejects with **`VALIDATION_ERROR`** / audit-style messages when enforcement is on and GPS or IP checks fail. GraphQL **`attendancePunchPolicy`** + **`upsertAttendancePunchPolicy`** ( **`ClientClaims::can_configure_attendance_punch_policy`** — HR / tenant admin or **`attendance:punch_policy`**).
- **Ops:** run tenant Liquibase so **`0032`** applies to each schema; restart **`kabipay-attendance`**.

### 7.17 India payroll — PF / ESI monthly CSV (M12, 2026-04-24) ✅

- **`kabipay-payroll`:** **`indiaPfEsiMonthlySummaryCsv(month, year)`** — CSV from **`payslip`** rows for the matching **`payroll_cycle`**: employee code/name, primary PAN, UAN, ESIC, PF employee/employer, ESI employee/employer, gross, status. Same gate as **`indiaTdsMonthlySummaryCsv`** (**`payroll:statutory_export`** or HR / tenant admin).
- **`kabipay-ui`:** Payroll **Payslips** page — **Download PF/ESI CSV** (uses same month/year as TDS section). **`clientOperations.graphql`** query **`IndiaPfEsiMonthlySummaryCsv`**.
- **Gateway:** forwards **`x-forwarded-for`** and **`x-real-ip`** from the browser request to subgraphs (for **M11** IP policy when clients sit behind a proxy).

### 7.18 Org chart — reporting hierarchy (M13, 2026-04-24) 🟨 partial

- **`kabipay-employee`:** **`orgChart(limit)`** (default 500, max 500) — returns **`OrgChartRow`**. **`Employee`** exposes **`reportingManagerId`**. **`createEmployee`** accepts optional **`reportingManagerId`**; **`updateEmployee`** accepts nullable **`reportingManagerId`** (`null` clears). Server **`assert_valid_reporting_manager`** rejects self-manager and **cycles** (walk up the chain).
- **`kabipay-ui`:** **Organization → Org chart**; **Admin → Employees**: **Reporting manager** on add/edit, **Reports to** column on the table.
- **Remaining (M13 umbrella):** **onboarding/offboarding** checklist API + UI.

---

## 8. Conventions reminder

- Every table: UUID PK, `TIMESTAMPTZ created_at`, `TIMESTAMPTZ updated_at` with trigger, soft-delete fields where applicable.
- Every monetary value: `NUMERIC(15,4)`.
- Every tenant-plane table: parameterised with `${schema}` in Liquibase XML.
- Every FK to another tenant-plane table: reference `${schema}.table_name`.
- Every cross-service event: go through `outbox_event` (domain 0030) — NEVER direct cross-service DB writes.
- Every GraphQL error: map through `KabiPayError` → stable error `code`.
- Every Rust service `main.rs`: call `kabipay_common::telemetry::init_tracing(SERVICE_NAME)` first.
- Every PR / commit touching this project: update this file.
- SeaORM queries in client services: `.filter(Column::TenantId.eq(ctx.tenant_id))` **and** `.filter(Column::IsDeleted.eq(false))` — both, always (Gap B).

---

## 9. Known traps / gotchas

1. `pwsh` (PowerShell 7) is not installed on this dev machine — use `powershell` (Windows PowerShell 5.1).
2. PowerShell doesn't accept `&&` as a statement separator — use `;` or `Set-Location … ; <cmd>`.
3. `scaffold-services.ps1` is idempotent (overwrites). Safe to re-run after template changes.
4. `.enable_federation()` on an empty subgraph schema compiles but is only meaningful once `@key` directives are added to entities — expected for Phase 1.
5. The ops plane `set_updated_at()` trigger function is shared cross-schema — tenant schemas reference `kabipay_ops.set_updated_at()`. Ensure `search_path` includes `kabipay_ops` at session time (handled by `TenantDbConfig.to_url()` → `set_schema_search_path("<schema>,kabipay_ops,public")`).
6. `kabipay-ui` remote for this workspace: `https://github.com/KabiPay/kabipay-ui.git` (org split, 2026-04-24). If you still have a legacy clone, replace its `origin` or add a second remote.
7. `KabiPayError` → GraphQL uses `KabiPayError::into_graphql()` (not `Into`/`?`) because `async-graphql` provides a blanket `impl From<T: Display>` for `Error`.
8. GraphQL field names are **camelCase** at the wire level (`operatorHealth`, not `operator_health`) even though Rust resolver methods are snake_case.
9. Liquibase XML comments cannot contain `--`; use single hyphens or rephrase.
10. `liquibase.properties` must set `liquibaseSchemaName=public` for the ops plane — `kabipay_ops` doesn't exist when Liquibase first connects.
11. Liquibase 4.27 CLI rejects ad-hoc `-Dname=value` arguments; pass changelog parameters via `parameter.<name>=<value>` entries in the properties file. `provision-tenant.ps1` writes a temporary per-tenant properties file for this reason.
12. Windows often ships a native PostgreSQL service on `0.0.0.0:5432` that shadows Docker's port 5432 from the host. We map Docker's container port 5432 to host port **15432** (`POSTGRES_PORT=15432` in `.env`). Internal Docker-network traffic (Liquibase container, pgAdmin container) still uses `postgres:5432`.
13. `derive_tenant_schema_name` uses the first 8 hex chars of the tenant UUID. `provision-tenant.ps1` keeps its `-Schema` argument optional so it auto-derives to match; supply `-Schema` explicitly only once §7.6 lands.

---

## 10. Competitive feature gap — KabiPay vs Keka (marketing surface)

*Reference: [Keka HR & payroll](https://www.keka.com), [Time & attendance](https://www.keka.com/us/time-and-attendance), [Attendance management](https://keka.com/attendance-management-system), [Leave](https://keka.com/leave-management-system). Keka is a mature commercial suite; the list below is **not** a spec for 1:1 clone — it drives prioritisation for `hrms_erd_complete` / `KABIPAY_AI_PROMPT` alignment.*

| Area | Typical Keka emphasis (public site) | KabiPay today | Gap / next steps |
|------|--------------------------------------|--------------|--------------------|
| **Time & attendance** | 8 capture modes: biometric, remote clock-in, **geo** (continuous / fence), **IP** limits, face/selfie, timesheets; 200+ device drivers; shift board, OT → payroll | Punches, shifts schema, **GPS coords on punch** (WGS84), **tenant geofence + IP allowlist** for live punch (M11), timesheet table, regularization table (API partial) | Multi-site fences, **device integrations** (proprietary hardware), **continuous** tracking, photo/selfie proof, **shift calendar UI** |
| **Leave** | Policy engine, accrual, carry-over, WFH, comp-off, **multi-step workflow approvals**, org/location-based rules, email/mobile alerts | `leave` schema + **submit/approve/reject** (direct status, not workflow engine), balances, in-app notification on approve/reject | **Policy designer**, **workflow engine** on `leave_request`, push/email, comp-off accrual |
| **Payroll** | Full India statutory narrative; bank disbursement, compliance as product | Cycles, payslips, tax DTOs, components; **M4/M12** **CSV** stubs; **M29** pay run v1, **arrears**, bank **CSV** export (stubs) | **Form 16**, **24Q**, filed challan formats, **NACH**/production bank **uploads**, full statutory “production” calcs |
| **Core HR** | Org chart, letters, checklists, **onboarding/exit** journeys, asset handoff | Employee CRUD + **reporting manager**; **M13** org chart UI | **Lifecycle workflows**, offboarding, document packs |
| **Hiring** | ATS depth (pipeline, offer, e-sign) | Light recruitment read APIs | **Full ATS**, interview scheduling, offer letters |
| **Expenses** | Per diem, **travel requests**, mileage, card feeds | `submitExpense` + **`approveExpense` / `rejectExpense`**, **Travel** category + UI | **Trip entity**, mileage rates, per-diem rules, **multi-level workflow** |
| **LMS / performance** | 360, goals, calibrations | Scaffolding + reads | Maturity in UI + workflows |
| **Mobile** | iOS / Android productised | PWA / responsive; **geolocation in browser** | Native apps, push, offline punch |
| **AI / automations** | “AI” positioning on site | None productised | **Optional** after core parity |

**Priorities suggested for next builds (Keka-shaped, not completion claims):** (1) approval workflows for leave + expense + travel, (2) payroll statutory outputs, (3) attendance geofence + IP (tenant settings), (4) org chart + employee lifecycle, (5) device bridge (or documented CSV import from vendors). **See §10.1** for what M1–M6 actually cover vs this list.

### 10.1 Reality check — M* vs §10 “next builds” list

The five roadmap bullets under §10 are **parity targets** aligned with [Keka](https://www.keka.com)-style products. **Completing M1–M6 does not finish those bullets end-to-end.** Use this table when planning **M7+** (§12).

| §10 roadmap item | Delivered so far (monorepo) | Still missing for Keka-row parity |
|------------------|-----------------------------|-----------------------------------|
| **(1) Approval workflows** (leave + expense + travel) | **M8** leave; **M32** **`EXPENSE`** workflows; **M33** **`outbox_event`** on **final** **`approveExpense`** (**`expense.approved`**); **M14** **`travel_request`** single-step. **M6** leave outbox. **`kabipay-workflow`** = definitions/read + admin **create**. | Travel multi-step workflow runtime, full **policy** engine |
| **(2) Payroll statutory outputs** | **M4/M12** CSV **stubs**; **M29:** **`runPayrollForCycle`**, arrear + **`payrollBankTransferCsv`** (wire format may need tenant templates). | **Form 16**, **24Q**, filed PF/ESI **ECR**/challan layouts, **NACH** / bank **upload** variants beyond current CSV, full production statutory calcs |
| **(3) Attendance geofence + IP** | **M11:** tenant **`attendance_punch_policy`** + server-side **`punchToday`** checks; **GPS** on punch (§7.10); gateway forwards client IP headers. | **HR admin UI** for policy (optional polish), multi-site fences, shift **calendar UI**, device/CSV import |
| **(4) Org chart + employee lifecycle** | **M1** **`departments` / `designations`**; **M13** **`orgChart`** + UI + **reporting manager** on admin employee forms; ERD **onboarding** tables exist. | **Onboarding/offboarding** checklists + UI, letters/document packs |
| **(5) Device bridge / CSV import** | None productised. | Vendor **device** connector or **documented CSV** import for attendance/payroll |

---

## 11. ERD v3 + `KABIPAY_AI_PROMPT` — coverage trace (not “all implemented”)

`hrms_erd_complete.md` lists **30 logical domains** (operator through outbox). `KABIPAY_AI_PROMPT.md` encodes process rules: **Gaps A–H** (tenant isolation, soft-delete, approvable+workflow, file storage, outbox, master data, etc.). This section is the **traceability matrix** so “remaining modules” is concrete.

| # | ERD / changelog domain | DB migrations authored | Rust subgraph (read/health) | Writes / product depth | Gaps A–H |
|---|------------------------|------------------------|-----------------------------|------------------------|----------|
| 0–4 | Operator, control, module catalog, billing | ✅ | ✅ operator, tenant, billing | Ops CRUD light | A✅ B varies |
| 5 | Auth / RBAC | ✅ | (in **auth** + **employee** + tables) | **JWT `resource_scopes`** from **`permission_scope`**; `employees` + `leaveRequests` **scoped** (2026-04-24) | H 🟨 (more list endpoints) |
| 6–7 | Org + employee | ✅ | ✅ employee + **`Employee` `@key`** (M9) | Org reads; employee CRUD **RBAC**; federation entity resolver for **`_entities`** | A✅ B✅ |
| 8–9 | Documents, custom fields | ✅ | partial | EAV not fully exposed in UI | F 🟨 |
| 10–12 | Time, leave, payroll | ✅ | ✅ attendance, leave, payroll | Punches+timesheet+leave+pay reads/writes; **M11** punch policy (geofence/IP) | D 🟨 |
| 13–16 | Tax, benefits, expense, recruitment | ✅ | ✅ per crate | Some mutations; no full ATS/expense policy | D 🟨 |
| 17–25 | Onboarding, PM, LMS, succession, comp, assets, grievance, analytics, workflow | ✅ | ✅ mostly **reads** + stubs | **M8**/ **M32** approvals; **M33** expense **outbox** | D 🟨 G 🟨 |
| 26–30 | Integrations, comms, master data, file storage, outbox | ✅ | light | **LOCAL** + optional **`s3_compat`** (R2/AWS/MinIO) **`file_storage` + HMAC read URL (M5 + M28)**; **`outbox_event`** on leave approve (M6) + **`kabipay-outbox-worker`** (M7) | F ✅ (S3) G 🟨 (more publishers) |

**Interpretation:** the **data model and subgraph shells** are largely in place; **“remaining work”** is product depth: **workflow-backed approvals** (Gap D), **more outbox publishers** + optional reclaim (G), **file_storage** depth (F), **PERMISSION_SCOPE** depth on remaining mutations/lists (H — **M3** + **M10** cover major read lists), **India payroll** follow-ons beyond **M4**/**M12** CSV stubs, **client UI** for DB-heavy domains (**§13**), and **Keka-style** device + mobile UX (see §10).

**Doc discipline:** one section of `KABIPAY_AI_PROMPT.md` at a time (its §0 says not to implement multiple sections in one shot); use this table to pick the next **single** vertical (e.g. “leave → workflow + notifications”).

### 11.1 ERD V3 domains (`hrms_erd_complete.md` §“Domains 1–30”) — end-to-end feature status

**Legend:** **Db** = Liquibase migrations exist (ops + tenant). **API** = federated subgraph + meaningful writes where marked. **UI** = real user journey in `kabipay-ui` (not only module health / probes). This is **product** depth, not “table exists”.

| # | ERD domain | Db | API (writes / depth) | UI e2e | Gap vs “complete module” |
|---|------------|-----|----------------------|--------|---------------------------|
| 1 | Operator plane | ✅ | ✅ reads | 🟨 | Ops CRUD / tickets shallow |
| 2 | Control plane (tenant) | ✅ | ✅ reads | 🟨 | Tenant admin UX shallow |
| 3 | Module catalog & subscription | ✅ | ✅ reads | 🟨 | |
| 4 | Billing & payments | ✅ | ✅ reads | 🟨 | |
| 5 | Auth & RBAC | ✅ | ✅ JWT + RBAC + **M10** list scopes | ✅ | **H:** remaining mutations / edge lists |
| 6 | Organisation hierarchy | ✅ | ✅ reads | ✅ | **M1** + **M13** org chart UI |
| 7 | Employee core | ✅ | ✅ create/update + **reporting manager** | ✅ | Onboarding / lifecycle journeys |
| 8 | Document system | ✅ | 🟨 upload/**M5** | 🟨 | EAV, verification UX |
| 9 | Custom fields (EAV) | ✅ | ⬜ | ⬜ | Not exposed |
| 10 | Time, shift & roster | ✅ | ✅ punch/timesheet/manual; **M11** punch policy API | 🟨 | **HR UI** for **`attendancePunchPolicy`**, shift/roster **calendar** UI |
| 11 | Leave | ✅ | ✅ submit/approve | ✅ | **Workflow** engine, policies |
| 12 | Payroll | ✅ | **M29** pay run v1 + arrears + **M4**/**M12** CSV stubs; bank CSV query | 🟨 | Production filing formats, NACH/bank **upload** templates, Form 16 / 24Q |
| 13 | Tax & statutory | ✅ | ✅ proofs/computations | 🟨 | Filed statutory artefacts |
| 14 | Benefits | ✅ | read-heavy | ⬜ | Enrollment flows |
| 15 | Expense | ✅ | ✅ submit/approve | ✅ | **Trip**, mileage, multi-level |
| 16 | Recruitment (ATS) | ✅ | read-heavy | ⬜ | Pipeline, offers |
| 17 | Onboarding / offboarding | ✅ | ✅ checklist + **separation** + **HR approve/reject** + **FNF** + **clearance** | ✅ | **M24**–**M25**; payroll pay-run still N/A at FNF |
| 18 | Performance | ✅ | read-heavy | ⬜ | 360, calibrations |
| 19 | LMS | ✅ | read-heavy | ⬜ | |
| 20 | Succession | ✅ | read-heavy | ✅ | **M23** |
| 21 | Compensation | ✅ | read-heavy | ✅ | **M23** |
| 22 | Assets | ✅ | read-heavy | ⬜ | Handoff at exit |
| 23 | Grievance | ✅ | read-heavy | ⬜ | |
| 24 | Analytics / reporting | ✅ | ✅ + outbox (HR) | ✅ | **M24** |
| 25 | Workflow engine | ✅ | **M8** leave; **M32** expense (**`kabipay-expense`**); **M29** read; **M31** definition **write** (**`kabipay-workflow`**) | 🟨 | **Workplace → Workflows** + **Admin** + **Expenses** ✅. **D:** visual **designer**. |
| 26 | Integrations & webhooks | ✅ | ⬜ | ⬜ | |
| 27 | Communication & platform | ✅ | 🟨 notifications | 🟨 | Push/email |
| 28 | Audit & security | ✅ | ⬜ | ⬜ | |
| 29 | Master data + file storage | ✅ | ✅ **M5** + **M28** LOCAL or **`s3_compat`** | 🟨 | Deeper: lifecycle / retention policies |
| 30 | Outbox events | ✅ | **M6** + **M7** + **M26** + **M33** expense (**`expense.approved`**) | **M7** worker | **G:** other transitions |

---

## 12. Remaining modules — execution queue (one at a time)

Work through this list **in order** unless a security incident reprioritises. After each slice, update the **Status** column here and **§0.1**.

| # | Module / theme | Status | Deliverable (concrete) |
|---|----------------|--------|-------------------------|
| **M1** | **Org hierarchy reads** | ✅ **done** (2026-04-24) | GraphQL `departments` + `designations` on `kabipay-employee`; `clientOperations.graphql`; admin employee UI uses selects + resolved labels. |
| **M2** | **Approval workflow (first vertical)** | ✅ **leave + expense** (**M32** WF + **M33** expense outbox) | **`workflow_instance`** (**M8** / **M32**). **M33:** **`approveExpense`** → **`outbox_event`** / **`expense.approved`**. **M31:** **`kabipay-workflow`** **definition** **`create*`**. **Attendance:** `addManualAttendanceSegment`. **Further:** step-level approvers by role. |
| **M3** | **PERMISSION_SCOPE (Gap H)** | ✅ **done** (2026-04-24) | **Liquibase `0005-007-permission-scope`**, **`load_client_resource_scopes`**, JWT **`resource_scopes`**. **`employees`**, **`employee(id)`** (IDOR), **`leaveRequests`**: SELF/TEAM/DEPARTMENT/ALL; no JWT → all (dev). **M10** extends lists (below). Demo seed: HR **ALL** for **`employee`**, **`leave`**, **`expense`**, **`attendance`**. |
| **M4** | **Payroll statutory (India)** | ✅ **CSV stub** (2026-04-24) | GraphQL **`indiaTdsMonthlySummaryCsv(month, year)`** on **`kabipay-payroll`**: tenant-wide payslips for matching **`payroll_cycle`** + **`employee`** + primary **`employee_pan`**; **`payroll:statutory_export`** (or HR / tenant admin). UI: **Payroll** page → download. Demo seed: sample payslip + PAN. Not Form 24Q / filed output. |
| **M5** | **File storage + signed URLs (Gap F)** | ✅ **done** (2026-04-24); **M28** extends | **`uploadEmployeeDocument`** (base64) → `file_storage` + `employee_document` **LOCAL** under **`KABIPAY_LOCAL_FILE_ROOT`**; **`read_stored_file_bytes`** for GET. **M28:** optional **S3-compatible** backend (**R2**/**AWS**/**MinIO**), per-tenant bucket or shared bucket; **`kabipay-svc/.env.example`**. **`employeeDocumentSignedReadUrl`**; **`GET /files/employee-document?token=`** (HMAC). |
| **M6** | **Outbox event (Gap G)** | ✅ **leave approve** (2026-04-24) | **`approveLeaveRequest`**: in the **same DB transaction**, insert **`outbox_event`** (`aggregate_type` **`leave_request`**, **`event_type`** **`leave_request.approved`**, `status` **`PENDING`**, JSON payload with ids + dates + `days_requested`). Requires tenant schema **`0030`** (`outbox_event` table). |
| **M7** | **Outbox consumer (Gap G)** | ✅ **worker** (2026-04-24) | **`kabipay-outbox-worker`**: active tenants from **`tenant_database`**, claim **`PENDING`** via **`FOR UPDATE SKIP LOCKED`**, **`PROCESSING`** → deliver (log + optional **`OUTBOX_WEBHOOK_URL`**) → **`PROCESSED`** / retry / **`FAILED`**. Env: **`OUTBOX_POLL_MS`**, **`OUTBOX_MAX_RETRIES`**, **`OUTBOX_WEBHOOK_URL`**; DB vars same as subgraphs (**`DATABASE_URL`** or **`POSTGRES_*`**). Runbook: **§7.12**. |
| **M8** | **Workflow-driven approval (Gap D)** | ✅ **leave** (2026-04-24) | **`kabipay-leave`**: **`submitLeaveRequest`** creates **`workflow_instance`** (`IN_PROGRESS`, `current_step_id` = first step) when **`workflow`** (`LEAVE_REQUEST`, active) + **`workflow_step`** exist; sets **`leave_request.workflow_instance_id`**. **`approveLeaveRequest`**: **`workflow_action` APPROVE**, next step or **`COMPLETED`** + **`finalize_leave_approval`** (balance + **M6** outbox). **`rejectLeaveRequest`**: **`workflow_action` REJECT** + **`CANCELLED`**. No **`workflow_step`** → legacy single-step approve (same as pre-M8). Demo seed: **`workflow_step`** + **`leave_request.workflow_instance_id`**. |
| **M9** | **Federation `@key` on `Employee`** | ✅ **subgraph** (2026-04-24) | **`kabipay-employee`**: entity resolver **`find_employee_by_id`** → **`Employee`** **`@key(fields: "id")`**. **Gateway:** no **`typeMerging`** change required until a **second** subgraph contributes **`Employee`**. |
| **M10** | **PERMISSION_SCOPE sweep (Gap H)** | ✅ (2026-04-24) | **`kabipay_common::client_data_scope`**: **`resolve_employee_scope_filter`**, **`data_scope_from_context`**, **`resolve_viewer_employee`**. **`expenses`**: scope resource **`expense`** (seed: **`expense`/`approve`**). **`attendance`** + **`timesheetEntries`**: **`attendance`** (**`read`**). **`payslip`/`payslips`**: **`employee`** scope (same as directory). **`employeeDocuments`**: **`assert_employee_in_data_scope`** when **`employeeId`** set. **`leaveBalances`**: **`leave`** scope. |
| **M11** | **Attendance policy (geofence + IP)** | ✅ **done** (2026-04-24) | Tenant **`attendance_punch_policy`** (Liquibase **0032**); **`punchToday`** validates geofence + IP when **`isEnforced`** and rules configured; **`attendancePunchPolicy`** / **`upsertAttendancePunchPolicy`**; **`ClientRequestHints.client_ip`** from headers. |
| **M12** | **Payroll statutory depth (India)** | ✅ **done** (2026-04-24) | **`indiaPfEsiMonthlySummaryCsv(month, year)`** on **`kabipay-payroll`**: payslip PF/ESI + UAN/ESIC + PAN per employee for the cycle; same RBAC as TDS CSV. UI: Payroll payslips page → **Download PF/ESI CSV**. |
| **M13** | **Core HR — org chart + lifecycle** | ✅ **v1** (2026-04-24) | **`orgChart`**, **`reportingManagerId`**, admin UI — plus **`onboardingChecklist`** / **`setOnboardingChecklistItemCompleted`** on **`kabipay-employee`** and **Workplace → Onboarding** UI. **Offboarding** (separation/FNF) still DB-only until a dedicated slice. |
| **M14** | **Expense / travel vertical** | ✅ **done** (2026-04-24) | Liquibase **0033** **`travel_request`** + **M34** **`0033-002`** **`rejected_by`**; **`kabipay-expense`**: **`travelRequests`**, **`submitTravelRequest`**, **`approveTravelRequest`**, **`rejectTravelRequest`** (same approver RBAC as expenses; reject stores **`rejected_by`**); **Expenses** page lists requests + modal submits real rows. |
| **M15** | **Client UI — attendance & shifts** | ✅ **done** (2026-04-24) | **Admin → Attendance policy**: **`attendancePunchPolicy`**, **`upsertAttendancePunchPolicy`**, read-only **`shifts`** list. |
| **M16** | **Client UI — benefits** | ✅ **read + enroll API** (2026-04-24; **M34**) | **Workplace → Benefits**: **`benefitTypes`** + **`benefitPlans`**; **`myBenefitEnrollments`**, **`enrollInBenefitPlan`** in subgraph + **`clientOperations.graphql`** (**UI** tab can wire **`EnrollInBenefitPlan`** when desired). |
| **M17** | **Client UI — recruitment (ATS)** | ✅ **read v1** (2026-04-24) | **Workplace → Recruitment**: **`jobPostings`** + **`applications`**; external **apply** stub deferred. |
| **M18** | **Client UI — onboarding / offboarding** | ✅ **onboarding v1** (2026-04-24) | Checklist query + self-service completion; HR may toggle items for employees in scope (same rule as documents). |
| **M19** | **Client UI — performance** | ✅ **read v1** (2026-04-24) | **Workplace → Performance**: **`reviewCycles`** + **`goals`**. |
| **M20** | **Client UI — LMS** | ✅ **read v1** (2026-04-24) | **Workplace → Learning**: **`skills`** + **`courses`**. |
| **M21** | **Client UI — assets** | ✅ **read v1** (2026-04-24) | **Workplace → Assets**: **`assetCategories`** + **`assets`**; assign/return deferred. |
| **M22** | **Client UI — grievance** | ✅ **done** (2026-04-24) | **`submitGrievanceCase`** + scoped **`grievanceCases`** (self vs HR-all); **Workplace → Grievance** UI. |
| **M23** | **Client UI — succession + compensation** | ✅ **read v1** (2026-04-27) | **Workplace → Succession** (`competencies`, `talentPools`); **Workplace → Compensation** (`compensationReviewCycles`, `salaryBands` with designation titles from `designations`). Mutations / calibration flows deferred. |
| **M24** | **Analytics + outbox + offboarding v1** | ✅ **read + submit** (2026-04-27) | New **`kabipay-analytics`** (port **4029**): reports, dashboards, workforce snapshots, **`outboxEvents`** (HR). **Employee:** **`separations`**, **`submitSeparation`**. **UI:** **`/insights`**, **Onboarding & exit** tabs, **Workplace → Workflows** (route shell). **M29** adds **`workflowsWithSteps`**-aware **step list** + **codegen**-safe queries. **download** HMAC includes **`mime_type`**. |
| **M24.1** | **Separation HR approve / reject** | ✅ **done** (2026-04-28) | **`approveSeparation`**, **`rejectSeparation`** (`PENDING` only); **Onboarding** exit list: **Approve** / **Reject** for **`admin`** UI role. |
| **M25** | **FNF + clearance (0017)** | ✅ **done** (2026-04-28) | Transactional DRAFT FNF + default clearance on **approval**; GraphQL + **Onboarding** **Clearance & FNF** panel; **§0.2** FNF row. |
| **M26** | **Outbox hardening (0030 + W)** | ✅ **done** (2026-04-28) | **`0034` `claimed_at`**, worker reclaim, **`requeueOutboxEvent`**, Insights table + **Requeue**; **§0.2** outbox row. |
| **M27** | **FNF GraphQL codegen + download DRY** | ✅ **done** (2026-04-28) | **`ClientOps*`** FNF/clearance + **`RequeueOutbox`** in **`clientOperations.graphql`**, **Onboarding** + **Insights** on generated **Documents**; **`read_stored_file_bytes`** in **employee** (LOCAL). **Requeue** requires **gateway** + **kabipay-analytics** for introspection. |
| **M28** | **S3 / R2 / MinIO `object_store` (M5 extension)** | ✅ **done** (2026-04-28) | **`object_store`**: **`S3CompatSettings`** from env; **OpenDAL** S3 + **reqsign** **CreateBucket**; **`KABIPAY_S3_PER_TENANT_BUCKET`**; smoke tests in **`s3_tenant`**. **Gaps F** closed for S3; **Azure** TBD. |
| **M29** | **Payroll v1 + arrears + workflow reads + UI/codegen hardening** | ✅ **done** (2026-04-28) | **`runPayrollForCycle`**, arrear **0035** + **`createPayrollArrear`**, **`payrollBankTransferCsv`**; **Workflow** **`workflowsWithSteps`** + **UI** (split queries for gateway compatibility). **Tenant 0036** travel link on expense. **UI:** `clientOperations` split ops; **schema merge** for codegen (no duplicate **`CreatePayrollCycleInput`**). *Not in scope for M29:* production statutory filings, NACH file formats, workflow **designer**. |
| **M30** | **Expense ↔ travel (UI + GraphQL operations)** | ✅ **done** (2026-04-28) | **`clientOperations.graphql`**: **`travelRequestId`** on **`expenses`** in **`ExpenseBoard`**; submit sends optional **`travelRequestId`**. **Expenses** table **Trip** column + “Link to travel request” on submit modal. Prereq: deployed **expense** subgraph with **`expense.travel_request_id`**. |
| **M31** | **Workflow definition write (subgraph + Admin UI)** | ✅ **done** (2026-04-27) | **`kabipay-common`**: **`PERM_WORKFLOW_MANAGE`**; **`kabipay-workflow`**: **`createWorkflow`**, **`createWorkflowStep`** (duplicate step order rejected). **UI:** **Admin → Workflows** — create workflow + add step; **`AdminCreateWorkflow`**, **`AdminCreateWorkflowStep`** in **`clientOperations.graphql`**. **Codegen:** local **`workflow-admin`** extension **removed** once **gateway** + **`kabipay-workflow`** expose mutations (current setup). |
| **M32** | **Expense `workflow_instance` (runtime)** | ✅ **done** (2026-04-27) | **`kabipay-expense`** + seed + **`Expenses`** UI; **codegen:** **`backlog-catchup`** no longer stubs **`Expense`** / **`SubmitExpenseInput`** (**gateway** subgraph is authoritative). |
| **M33** | **Outbox on final expense approve (Gap G)** | ✅ **done** (2026-04-27) | **`finalize_expense_approval`**: inserts **`outbox_event`** **`aggregate_type`** **`expense`**, **`event_type`** **`expense.approved`**, same txn as status **APPROVED** ( **`kabipay-outbox-worker`** consumes). |
| **M34** | **Integrations / audit GraphQL + benefits enroll + travel rejector column** | ✅ **done** (2026-04-28) | **`kabipay-analytics`**: catalogue + **`tenant_integration`** list + **`webhook_subscription`** + **`audit_log`** reads; **`connectTenantIntegration`**, **`registerWebhookSubscription`**, **`setWebhookSubscriptionActive`**. **`kabipay-benefits`**: **`MutationRoot`**; **`kabipay-expense`** + tenant **`0033-002`** **`rejected_by`**. **`kabipay-ui`**: codegen ops (**§0.2** GraphQL row). |

**Rules:** one **M#** per development session where possible; **M7–M24.1** may be reprioritised after security review. Update **§11.1** when a domain’s **UI e2e** or **API** column materially changes. **§13** is the cross-check against **`hrms_erd_complete.md`** so “DB exists but no UI” is explicit.

---

## 13. ERD V3 → backlog (DB vs client API vs client UI)

**Source of truth for table names / domains:** `hrms_erd_complete.md` (30 domains in the diagram preamble). **Liquibase** implements most tenant tables under `kabipay-database/changelog/migrations/`. This section answers: *what is still missing as a product surface* — not whether migrations exist.

**Legend:** **Db** = tenant/ops migrations present. **API** = `kabipay-*` subgraph exposes meaningful queries/mutations for client JWT. **UI** = employee/HR journey in `kabipay-ui` beyond **Module health** probes.

| ERD # | Domain (see ERD preamble) | Db | Client API (typical) | Client UI | Notes / next slice |
|------|---------------------------|-----|----------------------|-----------|---------------------|
| 1 | Operator plane | ✅ | 🟨 reads | 🟨 | Support/ticket UX shallow — not client scope. |
| 2–4 | Control, modules, billing | ✅ | 🟨 reads | 🟨 | Tenant admin / operator portal depth deferred. |
| 5 | Auth & RBAC | ✅ | ✅ | ✅ | **M3/M10** scopes; more mutations → **§11.1** row 5. |
| 6–7 | Org + employee | ✅ | ✅ | ✅ | **M13** chart + manager + onboarding checklist API/UI. |
| 8–9 | Documents + custom fields | ✅ | 🟨 **M5** upload | 🟨 | **EAV** not exposed — future “custom fields admin” task. |
| 10 | Time, shift, roster | ✅ | ✅ + **M11** | ✅ | **M15** HR policy UI + shift list (read-only in client). |
| 11–12 | Leave, payroll | ✅ | ✅; **M29** pay run + arrears | 🟨 | Leave ✅; payroll **M29** v1; filed statutory / NACH TBD. |
| 13 | Tax & statutory | ✅ | ✅ | 🟨 | Tax proof flows; filed artefacts still out of scope. |
| 14 | Benefits | ✅ | read-heavy | ✅ | **M16** catalog page; enroll mutation deferred. |
| 15 | Expense | ✅ | ✅ + **travel_request**; **M32** **`workflow_instance`** | ✅ | **M30** trip link; **M32** multi-step approval. |
| 16 | Recruitment | ✅ | read-heavy | ✅ | **M17** jobs + applications table. |
| 17 | Onboarding / offboarding | ✅ | ✅ checklist | ✅ | **M18**; separation/FNF still API-light. |
| 18 | Performance | ✅ | read-heavy | ✅ | **M19** cycles + goals list. |
| 19 | LMS | ✅ | read-heavy | ✅ | **M20** skills + courses catalog. |
| 20 | Succession | ✅ | read-heavy | ✅ | **M23** catalog + talent pools. |
| 21 | Compensation | ✅ | read-heavy | ✅ | **M23** review cycles + salary bands (read v1). |
| 22 | Assets | ✅ | read-heavy | ✅ | **M21** inventory read v1. |
| 23 | Grievance | ✅ | ✅ read + submit | ✅ | **M22** scoped list + **`submitGrievanceCase`**. |
| 24 | Analytics | ✅ | ✅ `kabipay-analytics` | ✅ | **M24** Insights + outbox queue tab |
| 25 | Workflow | ✅ | **M8** leave; **M32** expense runtime; **M29** read; **M31** definition mutations | 🟨 | **Workflows** + **Admin** + **Expense** claims ✅; drag-and-drop ⬜. |
| 26 | Integrations | ✅ | ⬜ | ⬜ | Webhook registry UI + mutations. |
| 27 | Communication | ✅ | 🟨 notifications | 🟨 | Push/email providers. |
| 28 | Audit & security | ✅ | ⬜ | ⬜ | Audit log viewer (ops or tenant admin). |
| 29 | Master data + files | ✅ | 🟨 **M5** | 🟨 | **S3** provider; master data CRUD UI. |
| 30 | Outbox | ✅ | **M6/M7** + **M26** | 🟨 Insights outbox + **Requeue** | **HR** queue inspection; more publishers TBD. |

**How to use:** After **§12** **M13–M23** v1, pull the next **UI = ⬜** row (e.g. **analytics**, **workflow** designer, **integrations**) unless security/product overrides.

---

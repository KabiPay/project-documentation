# KabiPay HRMS Feature Completion Status

Last reviewed: **2026-05-03** (HRMS expense policy round + notification email roadmap doc + **`limitPerDay`** hints — session sync with **`status.md`**)

This document is the working reference for the next AI agent. It focuses only on the HRMS features requested for Admin, HR, and Employee users:

- Punch in / punch out and attendance
- Leave management
- Timesheet management
- Expense approval flow, because it is part of the requested Admin/HR approval surface
- Notifications
- Role-based configuration and access control
- Session, password, and known UI issues

Source documents reviewed:

- `project-documentation/hrms_erd_complete.md`
- `project-documentation/KABIPAY_AI_PROMPT.md`
- `kabipay-ui`
- `kabipay-auth` (REST — login, refresh, logout, change-password)
- `kabipay-svc/scripts/seed-demo-data.ps1` (tenant RBAC demo seed)

## Progress tracker (implementation snapshot)

Last updated: **2026-05-03** (includes demo DB migration/seed log in **Roll-up**)

### Completed (recent passes)

| Area | Notes |
|------|--------|
| **Client JWT / auth context** | JWT decoded for `roles`, `permissions`, `resource_scopes`. `AuthContext`: `persona` (`ADMIN` \| `HR` \| `EMPLOYEE`), `showTenantAdminNav`, `showHrNav`, `clientSession`, `can` / `canAny`, `hasJwtRole` / `hasAnyJwtRole`, `isElevated`. Legacy UI: `UserRole` = `employee` \| `admin` (HR maps to `admin` for compatibility). |
| **HR persona / `/hr/*` shell** | **`/hr`** overview (`HrHomePage`), **`/hr/people`** (reuses `AdminEmployeesPage`), **`/hr/access`** RBAC matrix (`HrAccessManagementPage` — user↔roles, role permissions, permission scopes). Sidebar **HR** block when `showHrNav` or `showTenantAdminNav`; gates in `navAccess.ts`. **`TENANT_ADMIN`** sees **Admin** + HR; HR-only sees HR + permitted workplace paths, not tenant **Admin** routes unless also tenant admin. |
| **Manual “switch role”** | Removed from normal UI; **dev-only** when `import.meta.env.DEV` **and** `VITE_ENABLE_DEV_ROLE_SWITCH=true`. |
| **Nav / routes** | **`/admin/*`** registered only when `showTenantAdminNav`. **`/hr/*`** when HR or tenant admin passes path gates. **`TenantPermissionRoute`** passes full `NavAccessOptions` (incl. `showHrNav`). Payroll tax/compensation admin routes use `showTenantAdminNav`. Command palette: `adminOnly` catalog entries require `showTenantAdminNav`; people quick-search when `showHrNav` or `showTenantAdminNav`. JWT permission checks per path in `src/auth/navAccess.ts`. |
| **Attendance / punch time display** | `formatBackendTime` — times shown without millisecond noise on dashboard punch card and attendance tables. |
| **Day / night shift in UI** | No Day/Night badges on shift cards; “night” suffix removed from admin attendance policy shift list. (Backend `isNightShift` may remain.) |
| **Leave apply form** | Reason required; half-day disallowed for multi-day range; `halfDayAllowed` from API; session `FIRST_HALF` / `SECOND_HALF`. `LeaveBoard` GraphQL includes `halfDayAllowed`. |
| **Idle session** | **15-minute** idle logout on tenant `AppLayout` → `logout` and redirect to `/login`. |
| **Change password** | **Backend:** `POST /auth/client/change-password` with `Authorization: Bearer <access>`, body `{ currentPassword, newPassword }` — updates hash, revokes **all** refresh sessions for that user. **UI:** Profile → **Security** tab. |
| **Demo RBAC seed** | Permissions `attendance:punch_policy`, `workflow:manage`, **`role:manage`** (module employee); `kabipay_ops.module` rows **ATTENDANCE**, **WORKFLOW**; tenant subscriptions; **HR_ADMIN** linked including **`role:manage`**, **`notification:manage`**, and `permission_scope` rows where applicable. Re-run `seed-demo-data.ps1` to apply on existing DBs. |
| **Leave approve / reject** | On **Leave** page: Approve / Reject when JWT allows (see **hierarchical** row) or **TEAM**/**ALL** `resource_scopes.leave`. |
| **Leave (employee self-service)** | **Balances** + **year selector**; **cancel own pending**; apply modal validates **`minNoticeDays`** / **`maxConsecutiveDays`** when policies exist; sandwich-rule **warning** on applicable types; **`/hr/leaves`** HR queue; request table **Applied** time + org-chart names (employee column hidden for pure self-view); **Refresh**. Backend unchanged for sandwich arithmetic (calendar inclusive days). |
| **Timesheet (employee)** | Create form: work date constrained to **current week Mon–Sun** (local calendar). **Delete** via API for statuses **`DRAFT`** / **`REJECTED`**. |
| **Expense & travel approval (tenant)** | In-app **`RejectReasonModal`**. Buttons when `expense:approve` / admin JWT, **TEAM** scope on `expense`, or legacy elevated empty perms. |
| **Expense policy admin + org pickers** | **`/admin/expense-categories`** (`expense:manage`): second card **Expense policies by category** — list / add / edit / delete scoped policies (**ALL** / **DEPARTMENT** / **DESIGNATION** / **ROLE**), limits (day / month / per claim), receipt + approval flags. GraphQL: `expensePoliciesForAdmin`, `upsertExpensePolicyAdmin`, `deleteExpensePolicyAdmin`. Employee subgraph query **`expenseAssignableRoles`** (requires expense configuration permission, not **`role:manage`**) powers **role** pickers. UI: **`UuidEntitySearchSelect`**, org directory loaded with categories; policy grid shows **resolved** department / designation / role names (falls back to short UUID if missing from directory). |
| **Hierarchical approvals (backend)** | `kabipay-common` **`workflow_approval`**: steps **`REPORTING_MANAGER`** / **`MANAGER`** vs **`ROLE`** (+ `approver_role_id`). Enforced on **leave**, **expense**, and **travel** (when a **`TRAVEL_REQUEST`** workflow exists; else travel falls back to legacy manager / `expense:approve` rule). Demo seeds: **reporting manager → `ACCOUNTING_APPROVER`** on expense & travel (not only HR_ADMIN). |
| **Notifications (tenant)** | Announcements with audience (dept, location, `ROLE:*`), publish/expiry, attachments; private notification rows; **`unreadNotificationCount`**; header dropdown + **`/notifications`** + **`/admin/notifications`**; JWT **`notification:manage`** (+ HR-like roles); demo seed grants permission to **HR_ADMIN**. **Per-user prefs** (0046): in-app off, bulletin off, topic mutes; Profile → Notifications. **Outbound email** not implemented yet — roadmap in `kabipay-notification/README.md`. |
| **Demo DB (local catch-up)** | **2026-05-03:** Ops migrations current; demo tenant **`tenant_342205fc`** updated through Liquibase **0046**; **`seed-demo-data.ps1`** re-run. |

### Partially complete

| Area | Done | Still to do |
|------|------|-------------|
| **Permission-based product** | `can()` / JWT permissions; `canAccessTenantPath` for **Admin**, **`/hr/*`** (`employee:write` on people admin, **`role:manage`** on access page), **Workflows** (`workflow:manage`); legacy: empty JWT permission set + elevated → matching paths. Sidebar, `AppRoutes`, command palette aligned. | Richer per-feature matrix (feature flags, audit trail on RBAC edits). |
| **GraphQL codegen** | Gateway introspection + schema-extensions merge; **`hrms-leave-fields`** retired (leave types live in federated schema). | Prefer `npm run codegen` with gateway running after document changes. |

## Roll-up: completed vs remaining vs enhancements

**Demo DB (this workspace, 2026-05-03):** `npm run migrate-ops` — ops plane **up to date** (32 changeSets, none pending). Tenant schema **`tenant_342205fc`** — `update-tenant-liquibase.ps1` applied **0044** (announcement media), **0045** (expense policy scope + payment columns), **0046** (`user_notification_preference`); **154** tenant changeSets total. **`seed-demo-data.ps1`** re-run (idempotent) for tenant `342205fc-98b1-5421-8a11-b30821c86aa0`. *Other tenants:* run the same Liquibase update per schema, then seed if needed.

### Completed (product areas — reference the tables above for detail)

- **Identity & session:** Client JWT with roles/permissions/scopes; **`can()`** + route gates; change password; **15-minute** idle logout on tenant shell.
- **HR shell & RBAC:** **`/hr`**, **`/hr/people`**, **`/hr/access`** (roles, permissions, scopes); **`/admin/*`** for tenant configuration when permitted.
- **Leave:** Self-service + policies + holidays + balances; **`/hr/leaves`** queue; workflow trail; hierarchical approvals.
- **Attendance & timesheet (employee):** Punch, policy, **weekly-window** timesheet entry; draft/rejected delete — **not** full PM approval/productization.
- **Expense & travel:** Categories; **scoped `expense_policy`**; multi-step workflows; **submit-time server enforcement** + employee **hints** (**per claim**, **per day**, **per month**, receipt); travel requests; hierarchical approvals; **`approveExpense`** may use **`approved_amount` &lt; claim** — **no** finance-grade partial module / rich payment UX / receipt line-items yet.
- **Notifications:** Announcements + inbox + bell + admin console; **`notification:manage`** in seed; **per-user preferences** (0046, Profile → Notifications). **Outbound email/SMS** roadmap: `kabipay-svc/crates/kabipay-notification/README.md`.
- **Payroll / tax / benefits / etc.:** Demo-seeded surfaces as before; not the focus of this doc.

### Remaining (blocking or near-term product gaps)

For the **full** checklist (governance, §1–§8, routes, DX), see **All remaining tasks (master inventory)** below.

| Theme | Items |
|--------|--------|
| **Timesheet** | Project catalog linkage; weekly submit; **approval** flows (full/partial/reject + comments); broader edit rules. |
| **Expense / travel** | Partial approval; **payment / reimbursement** lifecycle in UI + ops; **receipts** / `FILE_STORAGE` + **`expense_item`** (full attach flow); optional **`/hr/expenses`** queue. |
| **Employee management** | Documents, user provisioning, deactivate, richer fields/filters (see §1). |
| **Quality** | Stale modals, `DataStore`, raw UUID labels, shared formatters (see **Code Quality**). |
| **Governance** | Richer permission matrix, RBAC audit trail, feature flags (see **Partially complete**). |

### Enhancements (nice-to-have / backlog)

- **Notifications:** Implement **email** outbound (SES/Sendgrid/etc.) via **outbox + worker**, tenant relay config, and preference keys for **email_opt_in** / digest — see **`kabipay-notification/README.md`**. SMS/push stays backlog unless product prioritizes.

- **Expense UX:** Org-directory refresh without full reload; demo seed variants for **ROLE**/dept policies; Playwright smoke for policy CRUD (see checklist).
- **Timesheet:** Manager bulk actions; calendar integrations — *not specified in detail here*.
- **Analytics / insights:** Deeper workforce dashboards beyond seeded snapshots.

## Pending work checklist (tracked)

Use this list between releases; fold completed items back into the **Progress tracker** tables above.

### Leave

- [x] Admin/HR screens: CRUD **leave types**, **policies**, **balances** (and adjustments), **holiday calendars** — **`/admin/leave-settings`** (`leave:manage` or legacy elevated JWT with no permission strings).
- [x] Optional **dedicated approval inbox** route — **`/hr/leaves`** (`HrLeavesPage`: pending / status tabs, org-chart employee labels, larger request limit).
- [x] **Workflow trail** per request (`leaveRequestWorkflowTrail`) — **History** on Leave board when `workflowInstanceId` is set.
- [x] Remove **`hrms-leave-fields.graphql`** from codegen — federated gateway schema includes leave admin fields; extension file removed.

### Expense & travel

- [x] **Category master data (HR/admin):** `/admin/expense-categories` (`expense:manage`) — create / edit / soft-delete; `max_amount_per_claim` on category.
- [x] **Expense policy (HR/admin):** same page — CRUD **`expense_policy`** per category with **`applicable_to`** (ALL / department / designation / role), optional scope UUIDs, day/month/per-claim limits, receipt + approval flags. Backend resolves best-matching tier for submit + hints.
- [x] **Multi-step workflows:** `EXPENSE` and **`TRAVEL_REQUEST`** (`workflow_instance_id` on both); demo **manager → accounting** role on step 2.
- [x] **Submit-time enforcement (server):** `kabipay-expense` resolves effective caps / receipt rule from category + policies and rejects over-cap / missing receipt on submit (see `resolve_expense_submit_constraints` / submit path).
- [x] **Submit hints (employee UI):** `expenseSubmissionHints` + `ExpensesPage` shows effective **per-claim** cap, **daily policy limit** (when set), **monthly** limit, and **receipt required** (`limitPerDay` is also folded into per-claim max when tighter).
- [x] **Approve with adjusted amount:** `approveExpense` + **`ExpensesPage`** modal allow **`approved_amount` &lt; claimed** (financial + workflow path); not a full reconciliation / accruals module.
- [ ] **Partial approval (formal):** dedicated audit trail, payroll handoff, reporting — if product requires beyond current approve mutation.
- [ ] **Payment / reimbursement lifecycle** beyond **Mark paid** on **`/expenses`** (batch, hold/failed, **`expense:pay`** ops); align all surfaces with **`payment_status`**, paid date, reference.
- [ ] **Receipts** / **`FILE_STORAGE`** + `expense_item` line items in API + UI (attach proof to claim flow beyond current receipt storage id).
- [ ] **Enhancement ideas (non-blocking):** optional “paste UUID” expander when org directory load partially fails; refresh org directory after external master-data changes without full page reload; demo seed rows for **department/designation/role** policies tied to seeded org + roles; Playwright smoke for policy CRUD.

### Timesheet

- [ ] Projects catalog linkage; weekly submit; approval flows (full / partial / reject + comments); broader edit rules.

### Core HR / RBAC

- [x] Dedicated **`/hr/*`** routes and HR sidebar (vs **`/admin/*`** tenant configuration).
- [x] **Role / permission management** UI — **`/hr/access`**: assign user↔roles, role↔permissions, `permission_scope` rows (GraphQL: `tenantDirectory*`, `setUserRoles`, `setRolePermissions`, `setRolePermissionScopes`; backend requires `role:manage` or privileged roles).
- [x] Optional **approval inbox** routes under `/hr` — **`/hr/leaves`**.

### Employee management

- [ ] Documents, user provisioning, deactivate, rich fields, filters (see §1).

### Notifications

- [x] **Announcements + inbox:** `/notifications` loads announcements and private rows; mark one / mark all read; **`CreateAnnouncementModal`** with full HR targeting (dept, location UUID, role code, schedule) when JWT has **`notification:manage`** or HR-like roles; employees keep simple audience text.
- [x] **Header bell:** `NotificationDropdown` uses GraphQL (recent rows + **`unreadNotificationCount`**); mark read; clears unread on logout.
- [x] **Admin console:** `/admin/notifications` — CRUD announcements (incl. media), direct multi-user notifications, admin notification edit/delete — see `AdminNotificationsPage.tsx`.
- [x] **Seed:** **`notification:manage`** granted to **HR_ADMIN** (and **TENANT_ADMIN** via role copy) in `seed-demo-data.ps1`.
- [x] **Notification preferences:** `user_notification_preference` (tenant Liquibase **0046**); Profile → **Notifications** — master toggles (in-app, bulletin), per-topic mutes (`leave`, `expense`, `travel`, `tax`, `hr_direct`, `other`); list, unread count, announcements visibility, and mark-all-read respect prefs. GraphQL: `myNotificationPreferences`, `updateNotificationPreferences`.
- [ ] **Outbound email / SMS:** not implemented; in-app + bulletin only. Roadmap: outbox + worker + tenant/provider config + optional prefs columns — see `kabipay-svc/crates/kabipay-notification/README.md`.

### Quality / cleanup

- [ ] Items under **Code Quality And Cleanup Notes** (stale modals, `DataStore`, UUID labels, etc.).

### Logged complete (2026-05 — do not re-open)

These are **done**; they stay out of the **master inventory** below. Details sit in the **Progress tracker** and module **§** sections.

- [x] **Scoped `expense_policy` admin** on **`/admin/expense-categories`** (GraphQL CRUD, org pickers, resolved labels in grid, **`expenseAssignableRoles`** on employee subgraph).
- [x] **`limitPerDay` on `expenseSubmissionHints`** + submit modal copy on **`ExpensesPage`** (backend `ExpenseSubmitConstraints.limit_per_day`; still folded into per-claim max when tighter).
- [x] **`kabipay-notification/README.md`** — documents **shipped** in-app announcement/notification flows and **planned** outbound **email** (outbox/worker/providers); SMS/push remain backlog.

---

## All remaining tasks (master inventory)

Single list of **not done** work drawn from checklists, roll-up, module sections (**§1–§8**), routes, code quality, and governance. *Enhancement-only* bullets are marked **(enh)**.

### Governance, auth model, and permissions

- [ ] Richer **permission / feature matrix** (per-module flags, stricter URL gates) — see **Partially complete**.
- [ ] **Audit trail** on RBAC edits (who changed role/permission/scope, when).
- [ ] **§ Required End State:** evolve beyond `UserRole = 'employee' | 'admin'` where still relied upon; **`hasRole` / `hasAnyRole` / `can` / `canAny`** coverage; remove or keep **dev-only** profile dropdown role switch only.
- [ ] Resolve **open product questions** (**Open Backend Questions** § below): project entity plan, timesheet partial approve backend, **expense payment** batching/reporting parity ( **`markExpensePaymentStatus`** exists), HR as role vs permission bundle, idle logout vs server TTL.

### Employee management (§1)

- [ ] List **filters**: status, department, designation, manager, role.
- [ ] **Create/edit:** full HR fields (contact, DOB, gender, nationality, employment type, emergency contact, statutory IDs masked, bank if supported).
- [ ] **Documents:** type, upload via `FILE_STORAGE`, expiry, verify/reject.
- [ ] **Deactivate / soft-delete** (confirm UX; no hard delete of business facts).
- [ ] **User provisioning:** link `USER`, assign roles, invite / initial password / reset flow.
- [ ] Fix **directory UX** (e.g. email vs `userId` label); backend mutations as needed (`deactivateEmployee`, document upload, user-invite, etc.).

### Project management (§2)

- [ ] **Admin/HR project catalog** screen (and route, e.g. `/admin/projects`).
- [ ] **Data model:** dedicated `PROJECT` (or agreed `MASTER_DATA` MVP) + fields per §2; optional **`PROJECT_TASK`** if tasks are reusable.
- [ ] Wire **timesheet** to project **ID** / validated code (remove free-text-only / hardcoded modal projects).

### Timesheet (§3 + checklist)

- [ ] **Employee:** week selector/summary; **submit week** for approval; status badges (entry + week); edit/delete rules aligned with backend; **project + task** from catalog; policy-driven window (already partial: current-week local window exists).
- [ ] **Admin/HR:** queue **`/hr/timesheets`** (or `/admin/timesheets`) — list by employee/team/dept/week/project/status; **full / partial / reject** with reasons visible to employee; optional override rules.
- [ ] **Backend (confirm/extend):** week entity, `workflow_instance_id`, mutations: `updateTimesheetEntry`, `submitTimesheetWeek`, `approveTimesheetWeek`, `partiallyApproveTimesheetWeek`, `rejectTimesheetWeek`; tenant **timesheet config** (window, max hours/day, mandatory project/task).
- [ ] Replace or remove **`TimesheetEntryEditModal`** hardcoded projects ( **Code Quality** ).

### Leave (§4 — optional / parity)

- [ ] **Partial approval** for leave (only if product requires).
- [ ] **Sandwich rule** server-side recompute on submit (today: UI warning; balances use inclusive calendar days).
- [ ] **Strict server-side** parity for `min_notice_days` / `max_consecutive_days` if required beyond client validation.

### Attendance & punch (§5)

- [ ] **HR /admin:** attendance **by employee/date/status**; manual segment add/edit/delete where permitted; **regularization** approve/reject if backend supports.
- [ ] **Remove** remaining **day/night shift** emphasis on **`AttendancePage`** / shift list (align with “no day/night product feature”); ensure **shared `formatBackendTime`** on all punch/attendance surfaces.
- [ ] **Location required** policy: clear browser permission errors for employees.

### Expense & travel (checklist + §6)

- [ ] **Partial approval depth:** **`approveExpense`** accepts optional **`approvedAmount`** and the **Expenses** modal can pay less than claimed — **full** audit/history/payroll reconciliation UX still TBD if product needs a formal partial-approval module.
- [ ] **Payment / reimbursement** beyond **Mark paid** on **`ExpensesPage`**: batch pay, failure/hold states, **`expense:pay`** runbooks — surface **`payment_status`**, **`paid_at`**, **`payment_reference`** consistently for finance/HR workflows.
- [ ] **Receipts:** guided **upload → `FILE_STORAGE` → attach** (today: optional **`receipt_file_storage_id`** on submit); **`expense_item`** line items in API + UI.
- [ ] **Optional route:** dedicated **`/hr/expenses`** (or `/admin/expenses`) approval/payment queue vs single **`/expenses`**.
- [ ] Remove or refactor stale **`SubmitExpenseModal.tsx`**.
- [ ] **(enh)** Org-directory refresh without full page reload; paste-UUID expander when directory partial fail remains optional; demo **policy** rows for dept/designation/role in seed; Playwright smoke for policy CRUD.
- [ ] **Deploy / ops:** restart **`kabipay-employee`** after shipping **`expenseAssignableRoles`**; **`npm run codegen`** with gateway **up** after SDL changes.

### Notifications (§7 roadmap)

- [ ] **Outbound email** (SES/Sendgrid/etc.): outbox/worker, tenant/provider config, preference keys for email/digest — **`kabipay-notification` README**.
- [ ] **SMS / push** — backlog unless prioritized.

### Session & security (§8 — optional)

- [ ] Idle **warning** dialog before logout.
- [ ] **Align** idle duration with **backend access TTL** if product requires.

### Developer experience & quality

- [ ] **`npm run codegen`** with **gateway running** after schema/doc changes — if the gateway is down (**`ECONNREFUSED`** on `public/config.json` **`gatewayUrl`**), codegen cannot introspect; merge **schema-extensions** locally or bring **4009** up first (**Partially complete** table).
- [ ] **Code Quality And Cleanup Notes:** `DataStore` / demo store; raw **UUID** labels → human labels; shared **date/time/currency** formatters; migrate hardcoded **role** checks to **`can()`**.
- [ ] **Other tenants:** run **`update-tenant-liquibase.ps1`** per schema when changeSets ship; re-seed as needed (ops + tenant not auto-synced across environments).

### Routes / surfaces not fully productized (see § Route Plan)

- [ ] **`/admin/projects`**, **`/hr/expenses`** (if adopted), **`/admin/roles`** vs **`/hr/access`** split as product defines.
- [ ] HR **timesheet** and **expense payment** queues at depth matching **Testing Checklist** expectations.

### Testing & CI expectations (before release)

- [ ] Extend **persona tests** for: timesheet submit/approve/partial/reject; expense partial approve + payment status; employee documents/provisioning when built.
- [ ] **`npm run lint`** + **`npm run build`** on handoff (already standard; automate in CI if not).

### Payroll / tax / benefits (not HRMS-doc depth)

- [ ] **Product expansion** beyond demo-seeded **payroll / tax / benefits** surfaces — track in **`project-documentation/STATUS.md`** and payroll/compensation subgraphs when prioritized; this file focuses on punch, leave, timesheet, expense, notifications, RBAC.

---

Narrative breakdowns by module (acceptance criteria, file pointers) follow in the sections below.

## Current Status Summary

Use the **Progress tracker**, **Roll-up**, **Pending work checklist**, and **All remaining tasks (master inventory)** for done vs not done. The **master inventory** is the exhaustive “what’s left” list; module **§** sections keep acceptance criteria and file pointers.

The UI still has **partial** GraphQL integration in places and is **not** feature-complete for the full Admin / HR / Employee story. **Notification preferences** and **expense policy + submit enforcement** are in place; **timesheet PM flows**, **expense finance-grade payments/receipts/line items**, and **employee hardening** remain the largest gaps (**basic** approve-less-than-claim exists).

**Still accurate baseline (unchanged unless noted above):**

- Employee login/logout via `kabipay-auth`; refresh; **change password**; **idle logout** on client.
- JWT carries roles and permissions; UI exposes helpers; **`/hr/access`** edits RBAC in-app (gateway must federate employee subgraph RBAC fields).
- Punch in/out, attendance board, basic timesheet entry, **leave** apply/balances/approve/reject/cancel/workflow-aware approvals (with stricter apply rules), expenses, notifications page, admin employees, attendance policy, workflow designer — as before.
- **Not done:** projects, full timesheet approval flows, expense **payments / receipts & line items / partial approval UI depth**, employee hardening beyond current admin screens. **Notification outbound email/SMS** is not built (announcements & inbox are **in-app** — see **`kabipay-notification` README** for email roadmap).

## Important Product Decisions

Follow these decisions unless the user changes them:

- **Personas:** Three client-plane personas (`ADMIN`, `HR`, `EMPLOYEE`). **`/admin/*`** is **`showTenantAdminNav`** (tenant configuration). **`/hr/*`** is **`showHrNav`** (and tenant admins also see HR). **`HR_ADMIN`** gets HR shell + legacy **`admin`** `UserRole` for components that still key off that field.
- Do not continue day/night shift work. Shift templates may still exist in backend, but the UI should not emphasize day/night shift.
- Everything configurable means Admin/HR screens must read policy/master data from backend and save configuration, not hardcode local arrays.
- Use ERD entities as the source of truth:
  - `ROLE`, `PERMISSION`, `ROLE_PERMISSION`, `PERMISSION_SCOPE`, `USER_ROLE`
  - `EMPLOYEE`, `EMPLOYEE_DOCUMENT`, `DOCUMENT_TYPE`, `FILE_STORAGE`
  - `ATTENDANCE`, `ATTENDANCE_REGULARIZATION`, `SHIFT`
  - `LEAVE_TYPE`, `LEAVE_POLICY`, `LEAVE_BALANCE`, `LEAVE_REQUEST`
  - `EXPENSE`, `EXPENSE_ITEM`, `EXPENSE_CATEGORY`, `EXPENSE_POLICY`
  - `WORKFLOW`, `WORKFLOW_STEP`, `WORKFLOW_INSTANCE`, `WORKFLOW_ACTION`
  - `ANNOUNCEMENT`, `NOTIFICATION`
  - `MASTER_DATA` for simple configurable statuses/types
- Respect the AI prompt architecture:
  - Client-plane tenant data must be tenant-scoped.
  - Employee identity should use canonical `EMPLOYEE.id`.
  - Approvable entities should flow through workflow where configured.
  - File references should use `FILE_STORAGE`, not raw file paths.
  - Backend writes that trigger side effects should use outbox events.

## Role And Configuration Layer

### Current UI State

Relevant files:

- `kabipay-ui/src/auth/navAccess.ts`
- `kabipay-ui/src/contexts/AuthContext.tsx`
- `kabipay-ui/src/components/layout/Sidebar.tsx`
- `kabipay-ui/src/components/layout/ProfileDropdown.tsx`
- `kabipay-ui/src/routes/AppRoutes.tsx`
- `kabipay-ui/src/navigation/navCatalog.ts`

Current behavior (post–2026-05-03 pass):

- `UserRole` is `'employee' | 'admin'` (HR persona still maps to **`admin`** for legacy hooks); JWT drives `persona` `ADMIN` \| `HR` \| `EMPLOYEE`, `showTenantAdminNav`, `showHrNav`, `permissions`, and `can()` helpers.
- **`/admin/*`** routes render only when `showTenantAdminNav`. **`/hr/*`** (overview, people admin, roles & access) when `showHrNav` or tenant admin, with per-path permission gates (`navAccess.ts`).
- Manual role switch in `ProfileDropdown` is **dev-gated** only (see `VITE_ENABLE_DEV_ROLE_SWITCH`).
- **`/hr/access`** implements tenant RBAC editing (users↔roles, role↔permissions, `permission_scope` rows) via federated employee GraphQL when deployed.

### Required End State

Implement a proper role/permission layer for the client UI:

- `ADMIN`: full tenant-level configuration and CRUD.
- `HR`: HR operations and approvals, but not necessarily tenant billing/platform configuration.
- `EMPLOYEE`: self-service only.

The UI should use JWT roles/permissions/scopes, not manual role switching.

Minimum UI permissions:

- `employee:read`, `employee:create`, `employee:update`, `employee:delete`
- `employee_document:read`, `employee_document:create`, `employee_document:update`, `employee_document:delete`
- `project:read`, `project:create`, `project:update`, `project:delete`
- `timesheet:read`, `timesheet:create`, `timesheet:update`, `timesheet:delete`, `timesheet:approve`
- `attendance:read`, `attendance:punch`, `attendance:regularize`, `attendance:punch_policy`
- `leave:read`, `leave:create`, `leave:update`, `leave:delete`, `leave:approve`, `leave:manage`
- `expense:read`, `expense:create`, `expense:update`, `expense:delete`, `expense:approve`, `expense:pay`
- `notification:read`, `notification:create`, `notification:update`, `notification:delete`
- `workflow:manage`
- `role:manage`
- `master_data:manage`

Implementation guidance:

1. Replace `UserRole = 'employee' | 'admin'` with a richer client auth model:
   - Keep normalized roles from JWT: `ADMIN`, `HR`, `EMPLOYEE`, or backend role codes.
   - Keep permissions from JWT as a `Set<string>`.
   - Keep scopes from JWT if backend exposes them.
2. Add helpers:
   - `hasRole(roleCode)`
   - `hasAnyRole(roleCodes)`
   - `can(permission)`
   - `canAny(permissions)`
3. Remove or hide the manual "Switch to Admin/Employee" action from `ProfileDropdown`.
4. Update `Sidebar`, `AppRoutes`, and `navCatalog` to gate by permissions, not only `adminOnly`.
5. Add an Admin/HR "Role Management" screen:
   - List roles.
   - List permissions by module/resource.
   - Assign permissions to roles.
   - Assign roles to users.
   - Configure data scope: `SELF`, `TEAM`, `DEPARTMENT`, `ALL`.

Acceptance criteria:

- Employee cannot access Admin/HR screens by URL.
- HR can access HR operational screens and approval queues.
- Admin can access all configuration screens.
- Manual role switching is gone or dev-only behind an explicit local development flag.

## Admin And HR Feature Plan

### 1. Employee Management

Current files:

- `kabipay-ui/src/modules/admin/AdminEmployeesPage.tsx`
- `kabipay-ui/src/modules/admin/components/CreateEmployeeModal.tsx`
- `kabipay-ui/src/modules/admin/components/EditEmployeeModal.tsx`
- `kabipay-ui/src/modules/organization/OrganizationEmployeesPage.tsx`

Current behavior:

- Admin can create basic employee fields: code, first name, last name, date of joining, status, department, designation, reporting manager.
- Admin can update limited fields.
- No delete/deactivate button on the Admin employee page.
- No document upload/verification flow in employee create/edit.
- No user provisioning flow: cannot create linked user, assign role, set initial password, or send invite.
- Employee directory displays `userId` as "Email", which is incorrect.

Required:

- Add employee list filters by status, department, designation, manager, and role.
- Add create/edit sections:
  - Basic details: name, code, email/user link, phone, date of birth, gender, nationality, joining date, employment type, status.
  - Org details: department, designation, cost center, location, reporting manager.
  - Emergency contact.
  - Statutory identifiers: PAN, Aadhaar last 4, UAN, ESIC, with sensitive values masked.
  - Bank details if backend supports it.
  - Documents: document type, upload, expiry date, status, verify/reject.
- Add delete as soft delete/deactivate:
  - Prefer "Deactivate employee" in UI unless backend mutation is named delete.
  - Confirm before action.
  - Do not hard-delete business data.
- Add user provisioning:
  - Create/link `USER`.
  - Assign client roles.
  - Trigger invite/reset password flow.

Backend/API likely needed:

- `deleteEmployee` or `deactivateEmployee`
- employee document upload flow using `FILE_STORAGE`
- role/user management mutations
- maybe `createUserForEmployee` or tenant user invite mutation

Acceptance criteria:

- Admin/HR can add, edit, deactivate, and view employee documents.
- Employee can view own profile/documents but cannot edit restricted HR fields.
- "How to add new Employee" is discoverable through Admin > Employees with required field guidance.

### 2. Project Management

Current state:

- No project management screen found in `kabipay-ui`.
- Timesheet entry only captures a free text `projectCode`.
- `TimesheetEntryEditModal` still has hardcoded local projects and is not wired into current GraphQL flow.
- ERD does not define a dedicated `PROJECT` table in `hrms_erd_complete.md`, but the requested product scope requires projects.

Required:

- Add an Admin/HR Project Management screen.
- Admin/HR can add/edit/delete projects.
- Employee timesheet form should select a project from backend, then add task and effort.

Data model decision needed before coding:

- Preferred: add a dedicated `PROJECT` entity/table in database and backend service.
- Minimum viable: expose a tenant-scoped project catalog from `MASTER_DATA` category `PROJECT` only if project needs are simple.
- Because the requirement includes Add/Edit/Delete Project and task/effort tracking, a real project entity is better.

Suggested project fields:

- `id`, `tenant_id`, `code`, `name`, `description`, `status`
- `start_date`, `end_date`
- `manager_employee_id`
- `is_billable`
- `is_deleted`, `deleted_at`, `deleted_by`

Suggested task fields:

- Either `TIMESHEET_ENTRY.description` can remain the task text for v1, or add `PROJECT_TASK`.
- If task reuse is required, add `PROJECT_TASK(id, tenant_id, project_id, code, title, status)`.

Acceptance criteria:

- Admin/HR can maintain project catalog.
- Employee cannot type arbitrary project codes unless configuration allows it.
- Timesheet stores project ID or validated project code consistently.

### 3. Timesheet Management

Current files:

- `kabipay-ui/src/modules/attendance/AttendancePage.tsx`
- `kabipay-ui/src/modules/attendance/components/TimesheetEntryForm.tsx`
- `kabipay-ui/src/modules/attendance/components/TimesheetEntryEditModal.tsx`
- `kabipay-ui/src/api/documents/clientOperations.graphql`

Current behavior:

- Employee can create a basic timesheet entry using `createTimesheetEntry`.
- Form fields: work date, hours, project code, description.
- No edit/delete actions shown in current `AttendancePage`, although `DeleteTimesheetEntry` exists in GraphQL document.
- No admin/HR timesheet management page.
- No approval flow UI.
- No weekly entry limit.
- Future dates appear allowed in the current GraphQL form because there is no `max` attribute, but backend validation must be checked.

Required Employee behavior:

- Employee can add timesheet only for one configured week window.
- Future date should be allowed inside that one-week window.
- Employee can select project, enter task, and enter effort/hours.
- Employee can edit/delete only draft or rejected entries, if backend rules allow.
- Employee can submit a weekly timesheet for approval.
- Employee can see approval status and approver comments.

Required Admin/HR behavior:

- View timesheets by employee, team, department, week, project, and status.
- Add/edit/delete timesheet entries if role permits.
- Approve weekly timesheets:
  - Fully approved
  - Partial approval
  - Rejected
- Partial approval must record which entries/days/hours were approved/rejected and why.

Suggested backend changes:

- Add or confirm `TIMESHEET_ENTRY` backend entity fields:
  - `employee_id`, `work_date`, `project_id` or `project_code`, `task_description`, `hours_worked`
  - `status`: `DRAFT`, `SUBMITTED`, `PARTIALLY_APPROVED`, `APPROVED`, `REJECTED`
  - `submitted_at`, `approved_by`, `approved_at`, `rejection_reason`
  - `workflow_instance_id`
- Add a weekly parent entity if needed:
  - `TIMESHEET_WEEK(id, employee_id, week_start, week_end, status, submitted_at, workflow_instance_id)`
- Add mutations:
  - `updateTimesheetEntry`
  - `deleteTimesheetEntry`
  - `submitTimesheetWeek`
  - `approveTimesheetWeek`
  - `partiallyApproveTimesheetWeek`
  - `rejectTimesheetWeek`
- Add tenant config:
  - timesheet entry window length, default 7 days
  - whether future dates are allowed, default true within active week
  - max hours per day
  - whether project is mandatory
  - whether task description is mandatory

UI guidance:

- Replace `projectCode` input in `TimesheetEntryForm` with project select plus optional task select/text.
- Add week selector and week summary.
- Add weekly submit button.
- Add status badges per entry and per week.
- Add Admin/HR approval queue under a new route such as `/hr/timesheets` or `/admin/timesheets`.
- Keep `AttendancePage` as the employee self-service page; do not overload it with all Admin controls.

Acceptance criteria:

- Employee can enter a full week timesheet with future dates inside configured week.
- Employee cannot enter outside the configured week unless Admin/HR override permission exists.
- Admin/HR can fully approve, partially approve, or reject.
- Rejection and partial approval reasons are visible to employee.

### 4. Leave Management

Current files:

- `kabipay-ui/src/modules/leave/LeavePage.tsx`
- `kabipay-ui/src/modules/leave/components/LeaveRequestsTableSection.tsx`
- `kabipay-ui/src/modules/hr/HrLeavesPage.tsx`
- `kabipay-ui/src/modules/admin/AdminLeaveSettingsPage.tsx`
- `kabipay-ui/src/modules/leave/components/ApplyLeaveModal.tsx`
- `kabipay-ui/src/modules/leave/components/LeaveRejectModal.tsx`
- `kabipay-ui/src/api/documents/clientOperations.graphql`
- `kabipay-svc/crates/kabipay-leave` — queries, mutations, `leave_service` (submit / approve / reject / **cancel**)

Current behavior (employee):

- **Apply:** `ApplyLeaveModal` — reason required; half-day blocked on multi-day ranges; half-day session select `FIRST_HALF` / `SECOND_HALF`; respects `halfDayAllowed`; **client validation** for **`minNoticeDays`** / **`maxConsecutiveDays`** when policy rows exist; sandwich-rule **warning** when `sandwichRule` on type; shows policy hints, upcoming holidays strip, **supporting document reference** when `requiresDocument`; submits `supportingDocumentReference`.
- **Balances:** Leave page shows **`leaveBalances`** on `LeaveBoard` with a **year selector** (default current year); columns available / pending / used / entitled; type names from `leaveTypes`.
- **Context:** `LeaveBoard` includes **`leavePolicies`**, **`upcomingHolidays`**, **`sandwichRule`** on types; table shows doc ref and **History** (workflow trail) when applicable.
- **Withdraw:** **Cancel** on own **PENDING** rows (`cancelLeaveRequest`) — releases balance reservation and cancels an in-progress workflow instance when present.
- **Requests table:** Shared **`LeaveRequestsTableSection`** — statuses, half-day vs full day, workflow hint, **`rejectionReason`**, doc ref, **History**; **Applied** timestamp; **Employee** via org chart on **`/leave`** / **`/hr/leaves`** (column hidden when the viewer only sees own rows); **Refresh** on both pages.

Current behavior (approver):

- **Approve / Reject** inline when JWT permits (`leave:approve`, elevated fallback per legacy rules, **TEAM**/**ALL** `resource_scopes.leave`, or hierarchical workflow step actor — enforced in **`kabipay-common` `workflow_approval`**).

Backend/API:

- Implemented: `submitLeaveRequest`, `approveLeaveRequest`, `rejectLeaveRequest`, **`cancelLeaveRequest`**, `leave_requests`, `leave_balances`, **`viewerEmployeeId`**, **`leave_policies`**, **`leaveRequestWorkflowTrail`**, admin mutations under **`leave:manage`** (types, policies, balances, entitlement adjustment), supporting document on submit; **`kabipay-attendance`** holiday calendar CRUD consumed by admin UI and **`upcomingHolidays`** on `LeaveBoard`.

Current behavior (HR / tenant admin):

- **`/hr/leaves`** — approval-focused queue: status tabs (pending default), up to 120 visible requests, **org-chart** employee names on rows, compact balance strip for the signed-in HR user, link to **`/leave`** and shortcut to **Leave settings** (tenant admins).

Still optional / product gaps:

- **Partial approval** for leave only if product mandates it (not standard on current model).
- **Sandwich rule arithmetic** (weekends/holidays between leave days) is **not** recomputed server-side on submit yet — UI warns when the leave type has **`sandwichRule`**; balances still use inclusive calendar days like the API today.
- **`min_notice_days` / `max_consecutive_days`** are **validated in `ApplyLeaveModal`** before submit; align backend rules when product requires strict server-side parity.

Acceptance criteria (current sprint):

- Employee cannot submit without reason or misuse half-day rules — satisfied in `ApplyLeaveModal`.
- Approvers acting at the correct workflow step (when configured) can approve/reject; employees can cancel own pending requests — satisfied server-side + Leave page.
- Balances update correctly on submit (reserve), approve (finalize), reject/cancel (release) — implemented in `leave_service`.

### 5. Punch In / Punch Out And Attendance

Current files:

- `kabipay-ui/src/modules/dashboard/components/PunchInOut.tsx`
- `kabipay-ui/src/modules/attendance/AttendancePage.tsx`
- `kabipay-ui/src/modules/admin/AdminAttendancePolicyPage.tsx`

Current behavior:

- Dashboard card calls `punchToday(input)` with optional GPS coordinates.
- It displays today's segments and completed minutes.
- Location can be captured.
- Admin can configure punch policy with geofence/IP fields.
- Time values are rendered raw from backend. This is why values like `In 10:34:56.289912 · Out 11:06:04.614686` are visible.
- Attendance page lists shifts and attendance rows.
- Shift UI still displays day/night badges.

Required Employee behavior:

- Punch in and punch out with location.
- If location is required by policy, explain browser permission failure clearly.
- Show last punch action with clean time format: `HH:mm:ss`, no milliseconds.
- Show coordinates only where useful; do not overwhelm employee with raw precision unless needed.
- Show today's worked duration and open segment.

Required Admin/HR behavior:

- View attendance by employee/date/status.
- Add/edit/delete manual attendance segments if permission allows.
- Approve/reject regularization requests if backend supports it.
- Configure punch policy:
  - geofence on/off
  - site lat/lng
  - max distance
  - IP allowlist
  - location required on/off
  - multiple punches per day allowed on/off
- Do not build day/night shift functionality.

Required bug fix:

- Add a shared time formatter:
  - Input may be `10:34:56.289912`, `10:34:56`, ISO timestamp, or null.
  - Output should be `10:34:56` for time-only values.
  - Use it in `PunchInOut` and `AttendancePage`.

Suggested implementation:

- Add `kabipay-ui/src/utils/timeFormat.ts`.
- Use `formatBackendTime(value)` for check-in/check-out display.
- Remove/hide `isNightShift` display in attendance screens for this scope.

Acceptance criteria:

- Punch in/out works with browser location.
- UI never shows milliseconds for attendance times.
- Admin/HR can configure punch policy.
- Day/night shift is not presented as a product feature.

### 6. Expense Management And Approval

Current files:

- `kabipay-ui/src/modules/expenses/ExpensesPage.tsx`
- `kabipay-ui/src/modules/expenses/components/SubmitTravelModal.tsx`
- `kabipay-ui/src/modules/expenses/components/SubmitExpenseModal.tsx`
- `kabipay-ui/src/modules/admin/AdminExpenseCategoriesPage.tsx` — categories + **expense policies** (scoped caps / flags, org pickers, grid labels).
- `kabipay-ui/src/components/common/UuidEntitySearchSelect.tsx` — reusable searchable UUID entity picker.
- `kabipay-svc` — `kabipay-expense` (policy admin + submit resolution); `kabipay-employee` — **`expenseAssignableRoles`** for policy pickers.

Current behavior:

- `ExpensesPage` is the real GraphQL-backed page.
- It lists categories, expense claims, and travel requests (including **`workflowInstanceId`** when a workflow is attached).
- Employee can submit expense and travel request inline; approver can approve/reject with workflow-aware actors.
- **`/admin/expense-categories`:** HR/admin CRUD for **`expense_category`** and **`expense_policy`** (`expense:manage`); org directory (departments, designations, assignable roles) supports policy scope pickers; policy list shows human-readable scope labels when directory data is loaded.
- `SubmitExpenseModal.tsx` remains stale / unused — prefer removing or refactoring.
- **Gaps vs full spec:** no partial approval, no end-to-end payment UX, no receipt **upload** / `expense_item` lines; submission hints now include **`limitPerDay`** when a policy sets it (also merged into effective per-claim max server-side).

Required Employee behavior:

- Apply expenses.
- Upload receipts where required.
- Link expense to travel request when needed.
- See approval status and payment/reimbursement status.

Required Admin/HR behavior:

- Add/edit/delete expense categories and policies.
- Approve expense:
  - Fully approved
  - Partially approved
  - Rejected
- Manage payment status:
  - pending payment
  - paid/reimbursed
  - failed/on hold
- Record approved amount separately from claimed amount.
- Record approver comments/rejection reason.

Suggested backend changes:

- Add or confirm fields:
  - `claimed_amount`
  - `approved_amount`
  - `payment_status`
  - `paid_at`
  - `payment_reference`
  - `workflow_instance_id`
- Add mutations (**partial inventory — some exist today**):
  - `partiallyApproveExpense(expenseId, approvedAmount, remarks)`
  - `markExpensePaymentStatus(expenseId, paymentStatus, reference)`
  - Category admin: **`upsertExpenseCategoryAdmin`**, **`deleteExpenseCategoryAdmin`**
  - Policy admin: **`upsertExpensePolicyAdmin`**, **`deleteExpensePolicyAdmin`** (+ queries **`expensePoliciesForAdmin`**, **`expenseSubmissionHints`**)
- Add file upload through `FILE_STORAGE` for receipts.

UI guidance:

- Keep employee submission under `/expenses`.
- Add Admin/HR approval queue under `/hr/expenses` or `/admin/expenses`.
- Show approval status and payment status as separate columns.
- Remove or refactor stale `SubmitExpenseModal.tsx` to avoid accidental reuse.

Acceptance criteria:

- Employee can submit expense with required fields.
- Admin/HR can full approve, partial approve, reject, and update payment status.
- Employee sees both approval status and payment status.

### 7. Notifications

**Status (2026-05-03): implemented** — see **Progress tracker** and checklist above; **per-user preferences** (in-app / bulletin / topic mutes) are shipped (Liquibase **0046** + Profile → Notifications).

Relevant files:

- `kabipay-ui/src/modules/notifications/NotificationsPage.tsx` — employee board + announcement cards (dept name, location short id, role badge, publish/expiry); link to admin console when permitted.
- `kabipay-ui/src/modules/notifications/CreateAnnouncementModal.tsx` — compose with attachments; **HR** fields when `canManageNotifications`.
- `kabipay-ui/src/modules/admin/AdminNotificationsPage.tsx` — full admin: edit/delete announcements, direct notifications, lists.
- `kabipay-ui/src/components/layout/NotificationDropdown.tsx` — bell + unread count + mark read.
- `kabipay-ui/src/auth/navAccess.ts` — **`canManageNotifications`** (`notification:manage` or `HR_ADMIN` / `TENANT_ADMIN` / `ORG_ADMIN`).
- `kabipay-notification` subgraph — `createAnnouncement`, `updateAnnouncement`, `deleteAnnouncement`, `createDirectNotifications`, `updateNotificationAdmin`, `deleteNotificationAdmin`, `unreadNotificationCount`, audience filters (dept, location, `ROLE:*`), publish / expiry window.
- `kabipay-svc/crates/kabipay-notification/README.md` — roadmap for adding **email** delivery on top of the current in-app + bulletin stack.

Implemented behavior:

- Employees see visible announcements and private notifications; mark read / mark all read; optional **New announcement** (team/company post); HR users get scheduling and targeting in the same modal.
- Header bell shows unread count and recent items; clears count when logged out.
- Admin route for deep management and direct user notifications.

**Roadmap — email (and SMS, optional)**

- **Current:** persistence + GraphQL + UI only deliver **inside the app** (and preferences gate bulletin vs in-app feeds).
- **Next:** enqueue outbound messages on announcement publish / high-value transactional events; worker sends via SES/Sendgrid/similar using tenant or platform relay; extend preferences with **`email_enabled`** / digest / per-topic email opt-ins. Full outline: **`kabipay-svc/crates/kabipay-notification/README.md`**.

Acceptance criteria (met for in-app):

- Header bell displays unread count and loads real data.
- Admin/HR can create, schedule, target, and manage announcements; send direct notifications; maintain notification rows.
- Employees receive content and can mark notifications read.

### 8. Change Password, Session Timeout, Auto Logout

**Status (2026-05-03): implemented** — see **Progress tracker** at top for details.

Relevant files:

- `kabipay-ui/src/auth/authClient.ts` — `changeClientPassword` (Bearer access)
- `kabipay-ui/src/hooks/useIdleLogout.ts` — activity events + timer
- `kabipay-ui/src/components/layout/AppLayout.tsx` — idle logout wired
- `kabipay-ui/src/modules/profile/components/SecurityTab.tsx` — change-password form
- `kabipay-ui/src/modules/profile/ProfileSettingsPage.tsx` — Security tab
- `kabipay-auth` — `POST /auth/client/change-password` (revokes all refresh sessions for user)

Implemented behavior:

- Profile **Security** tab: change password; on success, client calls `logout` and redirects to login (server has already invalidated refresh tokens).
- **15-minute** idle logout on tenant shell via `useIdleLogout` in `AppLayout`.
- Bearer token required for change-password; validation for min length (8) on client and server.

Optional / not done:

- Idle **warning** dialog before logout (spec was optional).
- Align idle timer with backend access TTL (if product requires).

Acceptance criteria:

- User can change password with validation.
- Idle client user is logged out after 15 minutes.
- Refresh tokens/access tokens are cleared locally after logout.

## Route Plan

Keep employee self-service pages simple and add HR/Admin work queues/configuration pages.

Suggested routes:

- `/dashboard`: employee overview, punch card, balances, notification preview
- `/attendance`: employee attendance and own timesheet
- `/leave`: employee leave
- `/expenses`: employee expenses and travel
- `/notifications`: employee inbox
- `/profile/settings`: profile, documents, security/change password
- `/hr/attendance`: HR attendance review and regularization
- `/hr/timesheets`: HR timesheet approval queue
- `/hr/leaves`: HR leave approval queue
- `/hr/expenses`: HR expense approval/payment queue
- `/admin/employees`: employee CRUD and documents
- `/admin/projects`: project CRUD
- `/admin/roles`: user role and permission management
- `/admin/leave-settings`: leave types, policies, balances, holiday calendars
- `/admin/timesheet-config`: timesheet policy config
- `/admin/attendance-policy`: punch policy config
- `/admin/expense-categories`: expense category + scoped **expense_policy** config
- `/admin/notifications`: notification/announcement management
- `/admin/workflows`: workflow designer

## Code Quality And Cleanup Notes

Address these while implementing:

- `SubmitExpenseModal.tsx` appears stale and mock-only. Refactor or remove once the live expense form is settled.
- `TimesheetEntryEditModal.tsx` has hardcoded local projects and does not match the current GraphQL timesheet model. Replace with backend project data or remove if unused.
- `localStorageStore.ts` and `DataStoreContext.tsx` are demo-era state. Do not add new features to this store unless the app explicitly keeps demo mode. Prefer GraphQL-backed flows.
- `ProfileDropdown` manual role switch: **dev-gated**; remove entirely once real RBAC UX is enough.
- Replace remaining hardcoded role checks with **permission** helpers (`can` / route metadata).
- Add shared formatters for date/time/currency to avoid inconsistent rendering.
- Avoid showing raw UUIDs when a human label is available. Employee directory currently shows department/designation IDs in places.

## Implementation Order For Next Agent

Work in this order to reduce rework:

1. Auth/role foundation — **partially done:** expanded JWT model + `can()`; dev-gated role switch; **`isElevated` gates**; **still need** full permission-based nav/routes + role management UI.
2. Fix known small bugs — **done:** time formatting, leave rules, hide day/night shift emphasis in UI.
3. Session/security — **done:** 15-minute idle logout; change password **REST** + Profile **Security** tab.
4. Timesheet v1 completion:
   - Employee weekly timesheet window.
   - Project/task selection.
   - Edit/delete draft entries.
   - Submit weekly timesheet.
5. Admin/HR approval queues:
   - Leave approval.
   - Timesheet full/partial/reject.
   - Expense full/partial/reject/payment status.
6. Admin configuration:
   - Project CRUD.
   - Leave config.
   - Timesheet config.
   - Expense config.
   - Notification config.
   - Role management.
7. Employee management completion:
   - Documents.
   - User provisioning.
   - Deactivate/delete.
8. Notification roadmap:
   - **Done (in-app):** header dropdown; admin/HR console; compose HR fields; seed `notification:manage`; **per-user prefs (0046)**.
   - **Remaining:** outbound **email** (and optional SMS) — see **`kabipay-notification` README**.

## Testing Checklist

For each completed feature, test all three personas:

- Employee:
  - Can punch in/out with location.
  - Can add current/future dates inside one-week timesheet window.
  - Cannot add outside allowed window.
  - Can apply leave only with reason.
  - Cannot choose half-day for multi-day leave.
  - Can apply expense.
  - Can view/read notifications.
  - Is auto-logged out after 15 minutes idle.
- HR:
  - Can view employee/team/department data according to scope.
  - Can approve/reject leave.
  - Can full/partial/reject timesheet.
  - Can full/partial/reject expense and update payment status if permitted.
  - Cannot access tenant-admin-only configuration if not granted.
- Admin:
  - Can manage users/roles/permissions/scopes.
  - Can add/edit/deactivate employees.
  - Can manage projects, leave config, timesheet config, expense config, notifications.
  - Can configure punch policy.

Run before handoff:

- `npm run codegen` if GraphQL documents changed.
- `npm run lint`
- `npm run build`

## Open Backend Questions

Answer these before implementing large UI flows:

- Does backend expose client-plane role/user management mutations? (**Yes:** `/hr/access` tenant RBAC.)
- Is there a project entity/service already planned outside the reviewed ERD? (**See master inventory § projects.**)
- Does backend support timesheet weekly submission and partial approval, or only entry creation/deletion? (**Submit week exists; partial approval depth TBD.**)
- Does backend support expense **partial** approve and **payment** status? (**Yes at API level:** `approveExpense(expenseId, approvedAmount)`, `markExpensePaymentStatus`; **finance-grade** workflows still TBD — see **`Status_HRMS` expense checklist.**)
- **Change-password:** `POST /auth/client/change-password` — ✅ **kabipay-auth**.
- Idle logout UI vs backend TTL? **UI 15m on tenant shell;** alignment TBD.
- HR role vs permission bundle? **Both in use** (JWT roles + **`can()`**); formalize per product.

## Definition Of Done

This feature set is complete when:

- Admin, HR, and Employee roles are real and permission-gated **(HR split and fine-grained gates still outstanding; see Progress tracker).**
- Employee self-service works for punch, weekly timesheet, leave, expenses, notifications, password change, and auto logout **(password change + idle logout + notification inbox/admin done; weekly timesheet depth partially complete).**
- Admin/HR can configure and approve the requested workflows **(many approval/config UIs still pending).**
- All configurable values come from backend or tenant config, not hardcoded local arrays.
- Attendance time display never shows milliseconds **(done for punch/attendance surfaces using `formatBackendTime`).**
- The app builds and lints successfully.
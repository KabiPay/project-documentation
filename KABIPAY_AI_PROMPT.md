# KabiPay HRMS — AI Implementation Prompt
> **Target model:** Claude Opus 4 in Cursor IDE  
> **Purpose:** Step-by-step guided implementation of the KabiPay HRMS backend, database project, and UI integration.  
> **Instruction to AI:** Read this entire document before writing a single line of code. If anything is ambiguous, **ask a clarifying question before proceeding**. Do not assume. Do not hallucinate package versions — use `cargo search` or ask the developer to confirm. Never skip a section.

---

## 0. HOW TO USE THIS PROMPT

Paste this document into Cursor as your project context. Work through it **one section at a time**. At the end of each section, the AI must:
1. Show a summary of what was created.
2. Ask: *"Shall I proceed to the next section?"*
3. Wait for confirmation before continuing.

**Never implement more than one section in a single response.**

---

## 1. BUSINESS CONTEXT — Read this before anything else

### What is KabiPay?
KabiPay is a **multi-tenant, microservice-based SaaS HRMS** (Human Resource Management System). It is sold to companies (called **tenants**) who use it to manage their employees. KabiPay is the product company — tenants are KabiPay's customers.

### Why this matters for technical decisions
- Every table in the client database is scoped to a `tenant_id`. A tenant's data must never be visible to another tenant.
- KabiPay has **two separate user planes**:
  - **Operator plane** — KabiPay's own internal staff (account managers, billing ops, support). They log in to an internal portal to manage tenants, pricing, invoices.
  - **Client plane** — The tenant's own HR admins and employees. They log in to the tenant-facing app.
- These two planes use **separate authentication, separate user tables, and separate JWT issuers**. They must never share auth tokens.
- Tenants subscribe to **modules** (Leave, Payroll, Recruitment, etc.). RBAC permissions are seeded only for modules a tenant has an active subscription for.
- Billing is **automated** — a monthly cron generates invoices per tenant based on their active subscriptions, contracted seat counts, and applicable pricing overrides (best-deal-wins discount logic).
- Tenants exceeding contracted seats are **hard-blocked** — the seat-add API must reject with a clear error.

### Cross-service identifier contract [Gap A]
`EMPLOYEE.id` (UUID v4) is the **single canonical identifier** for an employee across all microservices. When the payroll service, leave service, or tax service references an employee, they store only this UUID. They **never** duplicate employee core data (name, email, department name). Those fields are fetched on demand via GraphQL federation from `kabipay-employee`. The same contract applies to `TENANT.id`, `USER.id`, and `DEPARTMENT.id`. If the AI generates code that copies employee name/email into another service's table, flag it and refuse.

### Soft delete policy [Gap B]
Every major entity table (EMPLOYEE, LEAVE_REQUEST, EXPENSE, APPLICATION, etc.) has three soft-delete fields: `is_deleted BOOLEAN DEFAULT false`, `deleted_at TIMESTAMPTZ`, `deleted_by UUID`. Hard deletes are **never** performed on business data. Every SeaORM query on these tables **must** include `.filter(Column::IsDeleted.eq(false))` unless explicitly fetching deleted records for audit purposes. The `is_deleted` filter must be applied **in addition to** the `tenant_id` filter.

### Approvable entity pattern [Gap D]
Entities that flow through an approval process (LEAVE_REQUEST, EXPENSE, APPLICATION, EMPLOYEE_DOCUMENT, SEPARATION, BENEFIT_CLAIM, COMPENSATION_REVIEW_ITEM) carry a `workflow_instance_id FK` (nullable). When a workflow is configured for that entity type, this FK is populated at creation time. The workflow engine drives status transitions — the entity's `status` field should only be updated by the workflow action handler, never directly by other mutations.

### Data-level access control [Gap H]
The RBAC model has two layers:
1. **Permission layer** — `ROLE_PERMISSION` determines *what operations* a role can perform (create leave, view payslip, etc.)
2. **Scope layer** — `PERMISSION_SCOPE` determines *whose data* they can operate on:
   - `SELF` — only their own records (default for employees)
   - `TEAM` — their direct reports (for managers, resolved via `EMPLOYEE_HIERARCHY`)
   - `DEPARTMENT` — all employees in their department
   - `ALL` — unrestricted within tenant (for HR admins)

The auth middleware must inject the effective scope into `ClientContext` and resolvers must apply the scope filter before returning data.

### File storage policy [Gap F]
No service stores raw file paths as plain strings. All file references go through `FILE_STORAGE` table. The file service handles upload → storage → signed URL generation. Other services store only the `file_storage_id UUID FK`. Signed URLs are generated at read time with a short TTL (15 minutes) and never persisted back to the database.

### Transactional outbox policy [Gap G]
Every business operation that must trigger a cross-service side effect uses the transactional outbox pattern. The business write and the outbox event row are written in the **same database transaction**. A separate background task (one per service) polls `OUTBOX_EVENT WHERE status = 'pending'` and publishes to the message bus. Consumers must be idempotent — they check the `event_id` before processing. This is the **only** mechanism for cross-service communication. Direct HTTP calls between services at write time are forbidden (they break transactional guarantees).

### Enum/config policy [Gap E]
Simple status/type dropdowns that have no business-logic columns are backed by `MASTER_DATA`. Examples: expense status values, application status labels, grievance priority labels. `MASTER_DATA` rows with `is_system = true` are seeded during tenant provisioning and cannot be deleted. Tenants may add custom values and deactivate system values they don't use. Type tables with business columns (LEAVE_TYPE with carry_forward, BENEFIT_TYPE, etc.) remain as dedicated tables — do not move them to MASTER_DATA.

### Modularity model
The system is **plug-and-play**. A tenant can subscribe to any combination of modules. The backend must check `TENANT_SUBSCRIPTION` before processing any module-specific request. Permissions are module-gated at the RBAC level.

### Target market
India-first (PF, ESI, TDS, Form 16, PAN, Aadhaar compliance) but architected for multi-country expansion via `COUNTRY_CONFIG` and `LOCALIZATION_SETTING`.

---

## 2. PROJECT NAMING & REPOSITORY STRUCTURE

### Repository layout
```
kabipay/                          ← monorepo root
├── kabipay-database/             ← Liquibase migration project (this session)
│   ├── changelog/
│   │   ├── db.changelog-master.xml
│   │   └── migrations/
│   │       ├── 0001_operator_plane/
│   │       ├── 0002_control_plane/
│   │       ├── 0003_module_catalog/
│   │       ├── 0004_billing/
│   │       ├── 0005_auth_rbac/
│   │       ├── 0006_org_hierarchy/
│   │       ├── 0007_employee_core/
│   │       ├── 0008_document_system/
│   │       ├── 0009_custom_fields/
│   │       ├── 0010_time_shift_roster/
│   │       ├── 0011_leave/
│   │       ├── 0012_payroll/
│   │       ├── 0013_tax_statutory/
│   │       ├── 0014_benefits/
│   │       ├── 0015_expense/
│   │       ├── 0016_recruitment/
│   │       ├── 0017_onboarding_offboarding/
│   │       ├── 0018_performance/
│   │       ├── 0019_lms/
│   │       ├── 0020_succession/
│   │       ├── 0021_compensation/
│   │       ├── 0022_assets/
│   │       ├── 0023_grievance/
│   │       ├── 0024_analytics/
│   │       ├── 0025_workflow/
│   │       ├── 0026_integrations/
│   │       ├── 0027_communication_audit/
│   │       ├── 0028_master_data/
│   │       ├── 0029_file_storage/
│   │       └── 0030_outbox_events/
│   ├── liquibase.properties
│   ├── (no Docker Compose)       ← use cloud or local PostgreSQL; Liquibase 4.27+ on PATH
│   └── README.md
│
├── kabipay-svc/                  ← Rust workspace (this session)
│   ├── Cargo.toml                ← workspace root
│   ├── crates/
│   │   ├── kabipay-gateway/      ← API gateway + auth middleware + GraphQL federation
│   │   ├── kabipay-common/       ← shared types, errors, middleware, tenant resolver
│   │   ├── kabipay-auth/         ← JWT issuance, MFA, session management
│   │   ├── kabipay-operator/     ← operator plane service
│   │   ├── kabipay-tenant/       ← tenant & subscription management
│   │   ├── kabipay-billing/      ← billing cycle, invoice, payment
│   │   ├── kabipay-employee/     ← employee core, org hierarchy, documents
│   │   ├── kabipay-leave/        ← leave types, policies, balances, requests
│   │   ├── kabipay-attendance/   ← shifts, roster, attendance, regularisation
│   │   ├── kabipay-payroll/      ← salary structures, payroll cycle, payslips
│   │   ├── kabipay-tax/          ← tax config, slabs, computation, statutory
│   │   ├── kabipay-benefits/     ← benefit plans, enrollment, claims
│   │   ├── kabipay-expense/      ← expense categories, policies, claims
│   │   ├── kabipay-recruitment/  ← ATS, job postings, interviews, offers
│   │   ├── kabipay-performance/  ← goals, KPIs, reviews, ratings
│   │   ├── kabipay-lms/          ← courses, enrollments, certifications, skills
│   │   ├── kabipay-succession/   ← competencies, talent pools, succession plans
│   │   ├── kabipay-compensation/ ← salary bands, increment cycles, bonuses, equity
│   │   ├── kabipay-assets/       ← asset catalog, allocation, returns
│   │   ├── kabipay-grievance/    ← cases, participants, actions, disciplinary
│   │   ├── kabipay-workflow/     ← workflow engine, approval matrix
│   │   └── kabipay-notification/ ← notifications, announcements, webhooks
│
└── kabipay-ui/                   ← Already exists — integrate services here
```

> **AI instruction:** Before creating any file, print the intended directory tree for that crate/module and ask for confirmation.

---

## 3. TECHNOLOGY STACK — Exact versions matter

### Database
- **PostgreSQL 16** — primary database
- **Liquibase 4.27+** — migration tool
- **Migration format:** XML changesets (not YAML, not SQL raw — always XML for Liquibase)
- **Schema strategy:** Each tenant gets its own PostgreSQL schema (e.g. `tenant_abc123`). The operator/control plane lives in a `public` (or `kabipay_ops`) schema.

### Backend
- **Rust** (stable, latest at time of implementation — ask AI to confirm current stable version before writing `Cargo.toml`)
- **SeaORM** — ORM for database models. One SeaORM entity per table. Use the `sea-orm-cli` codegen as a reference but hand-craft entities for full control.
- **async-graphql** — GraphQL server library. Use `async-graphql = "7"` (confirm latest 7.x before using)
- **Apollo Federation subgraph** protocol via `async-graphql`'s federation support — each service exposes a federated subgraph
- **axum** — HTTP server framework
- **tokio** — async runtime
- **jsonwebtoken** — JWT encoding/decoding
- **argon2** — password hashing
- **serde / serde_json** — serialisation
- **uuid** — UUID v4 generation
- **chrono** — date/time handling
- **tracing + tracing-subscriber** — structured logging
- **thiserror** — typed error handling
- **anyhow** — error propagation in application code (not library code)
- **sqlx** (optional, for raw queries where SeaORM falls short) — confirm with developer before adding

> **AI instruction:** Before writing any `Cargo.toml`, list all crates with the versions you intend to use and ask the developer to confirm. Never invent version numbers.

### API Gateway
- **Apollo Router** or **async-graphql` gateway mode** — ask developer which to use before implementing
- GraphQL Federation v2

### Authentication
- **Operator JWT:** signed with a separate secret (`KABIPAY_OPERATOR_JWT_SECRET`), `iss` = `kabipay-ops`
- **Client JWT:** signed with `KABIPAY_CLIENT_JWT_SECRET`, `iss` = `kabipay-client`, includes `tenant_id` and `user_id` claims
- Tokens are **never interchangeable** between planes. Middleware must validate `iss` claim.

### Infrastructure (local dev)
- Docker Compose for PostgreSQL + services
- `.env` files per service — never hardcode secrets

---

## 4. CODING STANDARDS — Follow these exactly

### 4.1 Rust standards

```rust
// ✅ CORRECT: Typed errors using thiserror in library crates
#[derive(Debug, thiserror::Error)]
pub enum KabiPayError {
    #[error("tenant not found: {0}")]
    TenantNotFound(String),
    #[error("seat limit reached for subscription {0}")]
    SeatLimitReached(uuid::Uuid),
    #[error("database error: {0}")]
    Database(#[from] sea_orm::DbErr),
    #[error("unauthorised")]
    Unauthorised,
    #[error("forbidden: {0}")]
    Forbidden(String),
}

// ✅ CORRECT: Every public function must have a doc comment
/// Resolves the tenant database connection from the request context.
/// Returns an error if the tenant is not found or the schema is unavailable.
pub async fn resolve_tenant_db(tenant_id: &Uuid) -> Result<DatabaseConnection, KabiPayError> {
    // ...
}

// ❌ WRONG: unwrap() in production code
let result = some_operation().unwrap(); // NEVER do this

// ✅ CORRECT: Always propagate with ?
let result = some_operation().await?;

// ✅ CORRECT: Use tracing macros, never println!
tracing::info!(tenant_id = %tenant_id, "resolved tenant database connection");
tracing::error!(error = %e, "failed to process payroll cycle");

// ✅ CORRECT: Newtype wrappers for domain IDs
pub struct TenantId(pub Uuid);
pub struct EmployeeId(pub Uuid);
// Never use raw Uuid where a domain ID is expected

// ✅ CORRECT: Builder pattern for complex structs
// ✅ CORRECT: snake_case for variables/functions, PascalCase for types/traits
// ✅ CORRECT: Group imports: std, external crates, internal crates
```

### 4.2 GraphQL standards

```graphql
# ✅ CORRECT: Every type must have a description
"""
Represents an employee within a tenant organisation.
All fields are tenant-scoped — queries automatically filter by the authenticated tenant.
"""
type Employee {
  """Unique identifier for the employee"""
  id: ID!
  """Employee display code (e.g. EMP-0042)"""
  employeeCode: String!
  # ...
}

# ✅ CORRECT: Mutations always return a result type, never raw scalars
type CreateEmployeePayload {
  employee: Employee
  errors: [UserError!]!
}

type UserError {
  field: String
  message: String!
  code: String!
}

# ✅ CORRECT: Use pagination on all list queries
type EmployeeConnection {
  nodes: [Employee!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

# ❌ WRONG: Never return a raw list
employees: [Employee!]!  # missing pagination

# ✅ CORRECT: Use input types for all mutation arguments
input CreateEmployeeInput {
  firstName: String!
  lastName: String!
  departmentId: ID!
  # ...
}

# ✅ CORRECT: Subscription events follow noun_verb pattern
type Subscription {
  employeeStatusChanged(employeeId: ID!): EmployeeStatusChangedEvent!
}
```

### 4.3 SQL / Liquibase standards

```xml
<!-- ✅ CORRECT: Every changeset has a unique, descriptive id -->
<changeSet id="0007-001-create-employee-table" author="kabipay-dev">
    <!-- ✅ CORRECT: Every table has a comment -->
    <comment>Core employee record. tenant_id scopes all queries. Never query without tenant_id filter.</comment>
    
    <createTable tableName="employee" schemaName="${schema}">
        <!-- ✅ CORRECT: id is always UUID, generated at application layer, not DB -->
        <column name="id" type="UUID">
            <constraints primaryKey="true" nullable="false"/>
        </column>
        <!-- ✅ CORRECT: tenant_id on every client-plane table -->
        <column name="tenant_id" type="UUID">
            <constraints nullable="false"/>
        </column>
        <!-- ✅ CORRECT: All timestamps are timestamptz (timezone-aware) -->
        <column name="created_at" type="TIMESTAMPTZ" defaultValueComputed="NOW()">
            <constraints nullable="false"/>
        </column>
        <column name="updated_at" type="TIMESTAMPTZ" defaultValueComputed="NOW()">
            <constraints nullable="false"/>
        </column>
    </createTable>
    
    <!-- ✅ CORRECT: Always add indexes for FK columns and common query patterns -->
    <createIndex tableName="employee" indexName="idx_employee_tenant_id">
        <column name="tenant_id"/>
    </createIndex>

    <!-- ✅ CORRECT: Always add rollback -->
    <rollback>
        <dropTable tableName="employee" schemaName="${schema}"/>
    </rollback>
</changeSet>

<!-- ❌ WRONG: Missing rollback, missing comment, missing index, using SERIAL instead of UUID -->
```

### 4.4 SeaORM entity standards

```rust
// ✅ CORRECT: One file per entity, named after the table in snake_case
// File: src/entities/employee.rs

use sea_orm::entity::prelude::*;
use uuid::Uuid;
use chrono::{DateTime, Utc};

/// SeaORM entity for the `employee` table.
/// Always filter by `tenant_id` before any query — never expose cross-tenant data.
#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]
#[sea_orm(table_name = "employee")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub id: Uuid,
    pub tenant_id: Uuid,
    pub user_id: Option<Uuid>,
    pub department_id: Option<Uuid>,
    pub employee_code: String,
    pub first_name: String,
    pub last_name: String,
    // ... all columns from ERD
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::department::Entity",
        from = "Column::DepartmentId",
        to = "super::department::Column::Id"
    )]
    Department,
    // ... other relations
}

impl ActiveModelBehavior for ActiveModel {}
```

---

## 5. DATABASE SCHEMA — kabipay-database

### 5.1 Setup instructions

> **AI: Before creating any file, ask:**
> 1. What is the PostgreSQL version running locally?
> 2. What is the Liquibase version installed?
> 3. Is there an existing `kabipay-database` directory, or should this be created fresh?
> 4. What is the database name for local dev? (default assumption: `kabipay_dev`)
> 5. Is the operator schema called `kabipay_ops` or `public`? (default assumption: `kabipay_ops`)

### 5.2 Liquibase project structure

Create `kabipay-database/liquibase.properties`:
```properties
changeLogFile=changelog/db.changelog-master.xml
url=jdbc:postgresql://localhost:5432/kabipay_dev
username=${KABIPAY_DB_USER}
password=${KABIPAY_DB_PASSWORD}
defaultSchemaName=kabipay_ops
driver=org.postgresql.Driver
logLevel=INFO
```

Create `kabipay-database/changelog/db.changelog-master.xml`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog
    xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
        http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-4.27.xsd">

    <!-- Include each domain migration file in order -->
    <include file="migrations/0001_operator_plane/operator_plane.xml"
             relativeToChangelogFile="true"/>
    <include file="migrations/0002_control_plane/control_plane.xml"
             relativeToChangelogFile="true"/>
    <!-- ... continue for all 27 domains -->
</databaseChangeLog>
```

### 5.3 Migration rules (follow exactly)

1. **One XML file per domain folder.** The file is named after the domain (e.g. `operator_plane.xml`).
2. **Changeset ID format:** `{domain_number}-{sequence}-{description}` e.g. `0001-001-create-operator-user`.
3. **Never modify an existing changeset.** Always add a new one if a change is needed.
4. **Every table must have** `id UUID`, `created_at TIMESTAMPTZ`, `updated_at TIMESTAMPTZ`.
5. **Soft delete fields on every major entity table:** `is_deleted BOOLEAN NOT NULL DEFAULT false`, `deleted_at TIMESTAMPTZ`, `deleted_by UUID`. Junction/log tables (e.g. USER_ROLE, SEAT_USAGE_LOG, AUDIT_LOG) do not need soft delete — they are append-only.
6. **Every client-plane table must have** `tenant_id UUID NOT NULL` with a corresponding index.
7. **JSONB columns** (for `before_state`, `after_state`, `config_json`, `payload`, etc.) use type `JSONB`.
8. **All monetary values** use `NUMERIC(15,4)` — never FLOAT or DECIMAL without precision.
9. **Enum-like string fields** (status, type, etc.) use `VARCHAR(50)` with a `CHECK` constraint listing valid values, OR reference `MASTER_DATA.key` for tenant-configurable values.
10. **Foreign keys:** Always explicit, with `ON DELETE` behaviour specified (`RESTRICT` by default, `CASCADE` only where stated).
11. **`updated_at` trigger:** Create a reusable function `set_updated_at()` in changeset `0000-001-create-updated-at-trigger` and apply it to every table.
12. **`workflow_instance_id` column:** Add as `UUID NULLABLE` to: `leave_request`, `expense`, `application`, `employee_document`, `separation`, `benefit_claim`, `compensation_review_item`. Add FK to `workflow_instance.id` with `ON DELETE SET NULL`.
13. **File references:** Use `file_storage_id UUID FK` referencing `file_storage.id`. Never use plain `VARCHAR file_url` for user-uploaded files.
14. **`OUTBOX_EVENT` table:** Every service database must include this table (domain `0030`). It is not shared — each service writes its own events.

### 5.4 Domain migration order and tables

Implement in this exact order (dependencies flow downward):

| # | Domain | Key tables |
|---|--------|------------|
| 0001 | Operator Plane | `operator_user`, `operator_role`, `operator_user_role`, `operator_permission`, `operator_role_permission`, `operator_tenant_access`, `operator_audit_log`, `operator_support_ticket` |
| 0002 | Control Plane | `tenant`, `tenant_database`, `feature_flag`, `country_config`, `localization_setting`, `statutory_body` |
| 0003 | Module Catalog | `module`, `module_dependency`, `module_pricing`, `pricing_tier`, `client_pricing_override`, `tenant_subscription`, `seat_usage_log` |
| 0004 | Billing | `billing_cycle`, `invoice`, `invoice_line_item`, `payment`, `credit_note` |
| 0005 | Auth & RBAC | `user`, `role`, `permission`, `role_permission`, `user_role`, `user_session` |
| 0006 | Org Hierarchy | `department`, `designation`, `cost_center`, `location` |
| 0007 | Employee Core | `employee`, `employment_history`, `employee_pan`, `employee_aadhaar`, `employee_bank`, `dependent` |
| 0008 | Document System | `document_type`, `employee_document`, `document_field_definition`, `employee_document_field` |
| 0009 | Custom Fields | `custom_field_definition`, `custom_field_value` |
| 0010 | Time & Roster | `holiday_calendar`, `holiday`, `overtime_rule`, `shift`, `employee_shift`, `roster`, `roster_slot`, `shift_swap_request`, `comp_off_balance`, `attendance`, `attendance_regularization` |
| 0011 | Leave | `leave_type`, `leave_policy`, `leave_balance`, `leave_accrual_log`, `leave_request` |
| 0012 | Payroll | `salary_component`, `salary_structure`, `salary_structure_component`, `employee_salary_structure`, `payroll_cycle`, `payslip`, `payslip_component` |
| 0013 | Tax & Statutory | `tax_configuration_version`, `tax_slab`, `tax_computation`, `statutory_filing`, `form_16`, `labour_law_register` |
| 0014 | Benefits | `benefit_type`, `benefit_plan`, `employee_benefit_enrollment`, `benefit_claim` |
| 0015 | Expense | `expense_category`, `expense_policy`, `expense`, `expense_item` |
| 0016 | Recruitment | `job_posting`, `hiring_stage`, `application`, `application_stage_log`, `interview`, `interview_scorecard`, `referral`, `offer_letter`, `job_board_sync` |
| 0017 | Onboarding/Offboarding | `onboarding_checklist`, `separation`, `exit_interview`, `fnf_settlement`, `clearance_checklist` |
| 0018 | Performance | `review_cycle`, `goal`, `kpi`, `feedback_response`, `performance_rating` |
| 0019 | LMS | `skill`, `employee_skill`, `course`, `course_module`, `learning_path`, `learning_path_course`, `enrollment`, `course_progress`, `certification` |
| 0020 | Succession | `competency`, `competency_level`, `designation_competency`, `employee_competency`, `talent_pool`, `talent_pool_member`, `succession_plan`, `succession_candidate`, `career_path` |
| 0021 | Compensation | `salary_band`, `compensation_review_cycle`, `compensation_review_item`, `bonus_plan`, `bonus_payout`, `equity_grant` |
| 0022 | Assets | `asset_category`, `asset`, `asset_allocation`, `asset_return_log` |
| 0023 | Grievance | `grievance_category`, `grievance_case`, `case_participant`, `case_action`, `disciplinary_action` |
| 0024 | Analytics | `report_definition`, `report_schedule`, `dashboard`, `dashboard_widget`, `workforce_snapshot` |
| 0025 | Workflow | `workflow`, `workflow_step`, `workflow_instance`, `workflow_action`, `approval_matrix`, `approval_rule`, `approval_condition` |
| 0026 | Integrations | `integration_connector`, `tenant_integration`, `webhook_subscription`, `webhook_delivery_log` |
| 0027 | Communication & Audit | `announcement`, `notification`, `audit_log` |

> **AI instruction:** Implement one domain at a time. After generating a domain's XML, ask: *"Domain N complete. Shall I proceed to domain N+1?"*

---

## 6. BACKEND — kabipay-svc

### 6.1 Rust workspace setup

> **AI: Before creating any file, ask:**
> 1. Which Rust edition to use? (default: 2021)
> 2. Should all crates compile to binaries (each service runs independently) or shared library crates with one binary entry point per service?
> 3. Is there a preferred port range for services? (suggestion: gateway=4000, auth=4001, employee=4002, leave=4003, payroll=4004, billing=4005, etc.)
> 4. Are we using Docker networking or direct localhost for inter-service communication in local dev?
> 5. Should the GraphQL playground be enabled in production? (default: disabled)

`kabipay-svc/Cargo.toml` (workspace root):
```toml
[workspace]
resolver = "2"
members = [
    "crates/kabipay-gateway",
    "crates/kabipay-common",
    "crates/kabipay-auth",
    "crates/kabipay-operator",
    "crates/kabipay-tenant",
    "crates/kabipay-billing",
    "crates/kabipay-employee",
    "crates/kabipay-leave",
    "crates/kabipay-attendance",
    "crates/kabipay-payroll",
    "crates/kabipay-tax",
    "crates/kabipay-benefits",
    "crates/kabipay-expense",
    "crates/kabipay-recruitment",
    "crates/kabipay-performance",
    "crates/kabipay-lms",
    "crates/kabipay-succession",
    "crates/kabipay-compensation",
    "crates/kabipay-assets",
    "crates/kabipay-grievance",
    "crates/kabipay-workflow",
    "crates/kabipay-notification",
]

# Shared dependency versions — all crates inherit from here
[workspace.dependencies]
# Confirm exact versions before finalising
async-graphql = { version = "7", features = ["federation", "uuid", "chrono"] }
axum = { version = "0.7", features = ["macros"] }
tokio = { version = "1", features = ["full"] }
sea-orm = { version = "1", features = ["sqlx-postgres", "runtime-tokio-rustls", "macros", "with-uuid", "with-chrono"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
uuid = { version = "1", features = ["v4", "serde"] }
chrono = { version = "0.4", features = ["serde"] }
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }
thiserror = "1"
anyhow = "1"
jsonwebtoken = "9"
argon2 = "0.5"
tower = "0.4"
tower-http = { version = "0.5", features = ["cors", "trace"] }
dotenvy = "0.15"
```

### 6.2 kabipay-common — shared types

This crate is imported by every other crate. It must contain:

**`src/error.rs`** — The canonical `KabiPayError` enum (all services use this):
```rust
#[derive(Debug, thiserror::Error)]
pub enum KabiPayError {
    #[error("not found: {entity} with id {id}")]
    NotFound { entity: &'static str, id: String },
    #[error("tenant not found: {0}")]
    TenantNotFound(String),
    #[error("seat limit reached for module {module_code} — contracted: {contracted}, current: {current}")]
    SeatLimitReached { module_code: String, contracted: i32, current: i32 },
    #[error("module {0} is not subscribed for this tenant")]
    ModuleNotSubscribed(String),
    #[error("unauthorised — invalid or missing token")]
    Unauthorised,
    #[error("forbidden — insufficient permissions: {0}")]
    Forbidden(String),
    #[error("validation error: {0}")]
    Validation(String),
    #[error("database error: {0}")]
    Database(#[from] sea_orm::DbErr),
    #[error("internal error: {0}")]
    Internal(String),
}

// Must implement Into<async_graphql::Error> for GraphQL error responses
impl From<KabiPayError> for async_graphql::Error {
    fn from(e: KabiPayError) -> Self {
        // Map error variants to GraphQL error codes
        // e.g. Unauthorised → code: "UNAUTHENTICATED"
        // e.g. Forbidden → code: "FORBIDDEN"
        // e.g. SeatLimitReached → code: "SEAT_LIMIT_REACHED"
        // Include the error message as the GraphQL error message
        todo!()
    }
}
```

**`src/context.rs`** — Request context injected by middleware:
```rust
/// Authenticated operator context — injected by operator auth middleware.
pub struct OperatorContext {
    pub operator_user_id: Uuid,
    pub roles: Vec<String>,
    pub tenant_access: Vec<Uuid>, // empty = all tenants (super admin)
}

/// Authenticated client context — injected by client auth middleware.
/// Always includes tenant_id — every downstream query is scoped to this.
pub struct ClientContext {
    pub user_id: Uuid,
    pub tenant_id: Uuid,
    pub employee_id: Option<Uuid>,
    pub roles: Vec<String>,
    pub permissions: Vec<String>,
}
```

**`src/db.rs`** — Tenant database resolver:
```rust
/// Resolves the SeaORM DatabaseConnection for a given tenant.
/// Looks up TENANT_DATABASE record, constructs schema-scoped connection.
/// Connections should be pooled — use a DashMap<TenantId, DatabaseConnection> cache.
/// 
/// Business rule: Each tenant has an isolated PostgreSQL schema.
/// The schema name is stored in tenant_database.schema_name.
/// Set search_path to the tenant schema before any query.
pub async fn resolve_tenant_db(
    tenant_id: Uuid,
    pool_cache: &TenantDbCache,
) -> Result<DatabaseConnection, KabiPayError> {
    todo!("implement: look up tenant_database row, build connection string, set search_path")
}
```

**`src/pagination.rs`** — Reusable pagination types for GraphQL:
```rust
pub struct PageInput {
    pub page: u64,
    pub per_page: u64, // max 100
}

pub struct PageInfo {
    pub total_count: u64,
    pub total_pages: u64,
    pub current_page: u64,
    pub has_next_page: bool,
    pub has_prev_page: bool,
}
```

**`src/middleware/`** — Axum middleware:
- `src/middleware/client_auth.rs` — validates client JWT, extracts `ClientContext`, rejects if `iss != "kabipay-client"`, rejects if tenant is suspended
- `src/middleware/operator_auth.rs` — validates operator JWT, extracts `OperatorContext`, rejects if `iss != "kabipay-ops"`
- `src/middleware/module_guard.rs` — checks `TENANT_SUBSCRIPTION` for the required module code, returns `ModuleNotSubscribed` error if not active

### 6.3 kabipay-gateway — API gateway

> **AI: Ask before implementing:**
> 1. Are we using Apollo Router as a separate process, or implementing federation gateway logic in Rust inside kabipay-gateway?
> 2. Should the gateway handle rate limiting? If yes, what library?
> 3. Should the gateway expose a REST endpoint for health checks?

The gateway must:
- Accept all incoming HTTP requests on port 4000
- Route `/graphql/ops` to the operator plane subgraphs (require operator JWT)
- Route `/graphql/client` to client plane subgraphs (require client JWT)
- Route `/auth/*` to kabipay-auth for login, refresh, logout (no auth required)
- Apply CORS, request ID injection, and structured request logging middleware
- Federate subgraph schemas using GraphQL Federation v2

### 6.4 kabipay-auth — Authentication service

Business rules for auth:
- **Operator login:** email + password → validate against `operator_user` table → issue operator JWT (`iss = "kabipay-ops"`, exp = 8h) + refresh token
- **Client login:** email + password + `tenant_id` (from subdomain or explicit) → validate against `user` table in tenant schema → check `is_active` → issue client JWT (`iss = "kabipay-client"`, exp = 1h) + refresh token
- **MFA:** if `mfa_enabled = true` on the user, issue a short-lived `mfa_pending` token after password check, require TOTP code, then issue full JWT
- **Refresh:** rotate refresh token on every use (sliding expiry). Store refresh token hash in `user_session`
- **Logout:** delete `user_session` row
- **Password hash:** argon2id, never store plaintext
- **Seat check on login:** when a client user logs in, if this would be a new active session and `current_seat_usage >= contracted_seats`, reject with `SeatLimitReached`

### 6.5 Service implementation pattern

Every service (e.g. `kabipay-employee`) must follow this structure:

```
crates/kabipay-employee/
├── Cargo.toml
├── src/
│   ├── main.rs              ← axum server setup, routes, GraphQL schema build
│   ├── schema.rs            ← GraphQL schema assembly (Query + Mutation + Subscription)
│   ├── entities/            ← SeaORM entities (one file per table)
│   │   ├── mod.rs
│   │   ├── employee.rs
│   │   ├── department.rs
│   │   └── ...
│   ├── resolvers/           ← GraphQL resolvers
│   │   ├── mod.rs
│   │   ├── query.rs         ← #[Object] impl for queries
│   │   ├── mutation.rs      ← #[Object] impl for mutations
│   │   └── types.rs         ← GraphQL output types (#[SimpleObject], #[ComplexObject])
│   ├── services/            ← Business logic (no GraphQL imports here)
│   │   ├── mod.rs
│   │   ├── employee_service.rs
│   │   └── ...
│   └── errors.rs            ← service-specific errors (extending KabiPayError)
```

**Key architectural rule:** Business logic lives in `services/`. Resolvers call services. Services use entities. This separation allows testing services without a GraphQL context.

### 6.6 Tenant isolation rule (critical)

Every SeaORM query in a client service **must** include `.filter(entity::Column::TenantId.eq(ctx.tenant_id))`. 

Create a macro or helper to enforce this:
```rust
/// Enforce tenant isolation on every query.
/// Use this instead of Entity::find() directly.
macro_rules! tenant_query {
    ($entity:ty, $ctx:expr) => {
        <$entity>::find().filter(
            <$entity as EntityTrait>::Column::tenant_id().eq($ctx.tenant_id)
        )
    };
}
```

> **AI instruction:** If you see a query without a tenant_id filter in a client service, flag it as a security issue in a code comment.

### 6.7 Seat usage enforcement

Implement in `kabipay-tenant` service as a shared function called by every service that provisions a new user:

```rust
/// Before adding a new licensed user (calling USER create mutation),
/// this function MUST be called.
/// 
/// Business rule: Hard block if current_seat_usage >= contracted_seats.
/// On success, increment current_seat_usage and write a SEAT_USAGE_LOG row.
/// This must be atomic — use a database transaction.
pub async fn check_and_increment_seat(
    tenant_id: Uuid,
    module_code: &str,
    user_id: Uuid,
    db: &DatabaseConnection,
) -> Result<(), KabiPayError> {
    todo!()
}
```

### 6.8 Billing cron job

Implement in `kabipay-billing` as a Tokio background task spawned on startup:

**Business logic:**
1. Every day at midnight UTC, check for tenants whose `billing_cycle.period_end` is today and `status = 'pending'`
2. For each such tenant, fetch all `tenant_subscription` rows with `status = 'active'`
3. For each subscription:
   a. Fetch `module_pricing` (current = true) for the module
   b. Fetch all active `client_pricing_override` rows for this tenant+module
   c. Apply pricing: if `pricing_model = 'per_seat'`, use `contracted_seats` × best tier price. Apply best-deal-wins discount (highest `override_value` among all active overrides)
   d. Write one `invoice_line_item` per subscription, recording `discount_applied` and `discount_source`
4. Sum line items → create `invoice` with `status = 'pending'`
5. Update `billing_cycle.status = 'invoiced'`
6. Create next month's `billing_cycle` with `status = 'pending'`
7. Write `audit_log` entries for all created records

```rust
/// Billing cycle processor — runs as a background task.
/// Must be idempotent: if an invoice already exists for a cycle, skip it.
pub async fn process_billing_cycles(db: DatabaseConnection) {
    let mut interval = tokio::time::interval(tokio::time::Duration::from_secs(3600)); // hourly check
    loop {
        interval.tick().await;
        if let Err(e) = run_billing_cycle_job(&db).await {
            tracing::error!(error = %e, "billing cycle job failed");
        }
    }
}
```

---

## 7. GRAPHQL SCHEMA — Key types per service

> **AI instruction:** Do not generate GraphQL schemas for all services at once. Generate one service schema at a time, show it, and wait for confirmation.

### Global conventions
- All IDs are `ID!` (maps to UUID string)
- All timestamps are `DateTime` (ISO 8601 string)
- All money amounts are `Float` with a note that they represent `NUMERIC(15,4)`
- All list queries are paginated using `Connection` pattern
- Mutations return payload types with `errors: [UserError!]!`
- `@key` directive on every federated type using `id: ID!`

### Employee service example schema structure
```graphql
type Employee @key(fields: "id") {
  id: ID!
  employeeCode: String!
  firstName: String!
  lastName: String!
  fullName: String!  # computed: firstName + " " + lastName
  department: Department
  designation: Designation
  status: EmployeeStatus!
  dateOfJoining: DateTime!
  # ... other fields from ERD
}

enum EmployeeStatus {
  ACTIVE
  INACTIVE
  ON_LEAVE
  TERMINATED
}

type Query {
  employee(id: ID!): Employee
  employees(filter: EmployeeFilterInput, page: PageInput): EmployeeConnection!
  myProfile: Employee  # returns the authenticated user's employee record
}

type Mutation {
  createEmployee(input: CreateEmployeeInput!): CreateEmployeePayload!
  updateEmployee(id: ID!, input: UpdateEmployeeInput!): UpdateEmployeePayload!
  terminateEmployee(id: ID!, input: TerminateEmployeeInput!): TerminateEmployeePayload!
}
```

---

## 8. UI INTEGRATION

> **AI: Before touching the UI project, ask:**
> 1. What is the UI framework? (React, Next.js, Remix, Vue, SvelteKit?)
> 2. What GraphQL client is being used? (Apollo Client, urql, TanStack Query + graphql-request?)
> 3. Where is the UI project located relative to the monorepo root?
> 4. Is there an existing codegen setup (graphql-codegen)?
> 5. Are there existing authentication flows in the UI, or is this being built fresh?

### Integration requirements
Once answers are received, integrate as follows:

1. **GraphQL endpoint configuration** — point the GraphQL client at `http://localhost:4000/graphql/client` for client plane requests and `http://localhost:4000/graphql/ops` for operator plane requests
2. **Authentication flow:**
   - Login page calls `POST /auth/client/login` → stores access token in memory (never localStorage), stores refresh token in httpOnly cookie
   - Axios/fetch interceptor calls `POST /auth/client/refresh` automatically when 401 received
3. **Type generation** — set up `graphql-codegen` to generate TypeScript types from the federated schema
4. **Module gating in UI** — check user's subscribed modules (from JWT or a `/me` query) and conditionally render nav items and routes
5. **Error handling** — map GraphQL `UserError` codes to toast notifications. Map `UNAUTHENTICATED` to redirect to login.

---

## 9. DOCKER COMPOSE — Local development

Create `kabipay-svc/docker-compose.yml`:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: kabipay_dev
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "5432:5432"
    volumes:
      - kabipay_pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 5s
      timeout: 5s
      retries: 5

  # Add one service block per kabipay-svc crate
  # Each service should have:
  #   - build context pointing to its crate directory
  #   - env_file: .env
  #   - depends_on: [postgres]
  #   - ports: unique port per service

volumes:
  kabipay_pgdata:
```

---

## 10. ENVIRONMENT VARIABLES

Create `.env.example` at workspace root. Every variable listed here must be present in `.env` (not checked into git).

```env
# Database
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=kabipay_dev
POSTGRES_USER=kabipay
POSTGRES_PASSWORD=changeme

# JWT — operator plane
KABIPAY_OPERATOR_JWT_SECRET=change-me-operator-secret-min-32-chars
KABIPAY_OPERATOR_JWT_EXPIRY_HOURS=8

# JWT — client plane
KABIPAY_CLIENT_JWT_SECRET=change-me-client-secret-min-32-chars
KABIPAY_CLIENT_JWT_EXPIRY_HOURS=1
KABIPAY_CLIENT_REFRESH_EXPIRY_DAYS=30

# Service ports
KABIPAY_GATEWAY_PORT=4000
KABIPAY_AUTH_PORT=4001
KABIPAY_EMPLOYEE_PORT=4002
KABIPAY_LEAVE_PORT=4003
KABIPAY_PAYROLL_PORT=4004
KABIPAY_BILLING_PORT=4005
# ... add remaining services

# Logging
RUST_LOG=info,kabipay=debug
```

---

## 11. IMPLEMENTATION ORDER

Follow this order strictly. Do not jump ahead.

### Phase 1 — Foundation (do this first)
1. `kabipay-database`: setup project scaffold + changeset `0000` (updated_at trigger)
2. `kabipay-database`: domain `0001` (operator plane tables)
3. `kabipay-database`: domain `0002` (control plane tables)
4. `kabipay-database`: domain `0003` (module catalog + subscription)
5. `kabipay-database`: domain `0004` (billing)
6. `kabipay-database`: domain `0005` (auth + RBAC)
7. `kabipay-svc`: workspace `Cargo.toml` scaffold
8. `kabipay-common`: full implementation
9. `kabipay-auth`: full implementation (login, refresh, logout for both planes)
10. `kabipay-gateway`: setup + routing

### Phase 2 — Core HR
11. `kabipay-database`: domains `0006` through `0009`
12. `kabipay-employee`: full service (entities + schema + resolvers + business logic)
13. `kabipay-leave`: full service
14. `kabipay-attendance`: full service

### Phase 3 — Finance
15. `kabipay-database`: domains `0010` through `0014`
16. `kabipay-payroll`: full service
17. `kabipay-tax`: full service
18. `kabipay-billing`: full service including billing cron

### Phase 4 — Talent & Engagement
19. `kabipay-database`: domains `0015` through `0021`
20. `kabipay-recruitment`: full service
21. `kabipay-performance`: full service
22. `kabipay-lms`: full service
23. `kabipay-succession`: full service
24. `kabipay-compensation`: full service

### Phase 5 — Operations & Platform
25. `kabipay-database`: domains `0022` through `0027`
26. `kabipay-assets`: full service
27. `kabipay-grievance`: full service
28. `kabipay-workflow`: full service
29. `kabipay-notification`: full service
30. UI integration

---

## 12. QUALITY GATES — AI must verify before marking any phase done

Before declaring a phase complete, verify:

- [ ] All Liquibase changesets have `<rollback>` blocks
- [ ] All monetary columns are `NUMERIC(15,4)`
- [ ] All timestamp columns are `TIMESTAMPTZ`
- [ ] All client-plane tables have `tenant_id` column and index
- [ ] No `unwrap()` or `expect()` calls in production code paths
- [ ] All SeaORM queries in client services filter by `tenant_id`
- [ ] All GraphQL mutations return payload types with `errors: [UserError!]!`
- [ ] All public Rust functions have doc comments
- [ ] `tracing::info!` / `tracing::error!` used — no `println!`
- [ ] `.env.example` is updated if new variables are added
- [ ] Seat limit is checked before any user provisioning

---

## 13. QUESTIONS THE AI MUST ASK BEFORE STARTING

> **AI: Do not write a single line of code until you have answers to these questions:**

1. What is the current stable Rust version in this environment?
2. What version of `async-graphql` is to be used? (AI should not assume — check crates.io or ask)
3. What version of `sea-orm` is to be used?
4. Is the `kabipay-database` directory going to live inside the monorepo alongside `kabipay-svc` and `kabipay-ui`, or as a completely separate repository?
5. Does the existing `kabipay-ui` use Apollo Client or another GraphQL client?
6. What framework is `kabipay-ui` built on?
7. Is Apollo Router being used as the federation gateway, or should the gateway be implemented in Rust with `async-graphql`?
8. For local development, should services be run via `cargo run` directly or via Docker containers?
9. Is there an existing CI/CD pipeline that I need to consider for the Liquibase migration step?
10. For the operator portal (internal HRMS company portal), does a UI already exist or is it part of `kabipay-ui` with a role-based split?

**After receiving answers, summarise your understanding of the full project in 10 bullet points, then ask: "Is this understanding correct? Shall I begin Phase 1?"**

---

*End of prompt. Do not begin implementation until all Section 13 questions are answered and the developer confirms the understanding summary.*

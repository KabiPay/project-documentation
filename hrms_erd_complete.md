```mermaid
erDiagram

%% ============================================================
%% HRMS SAAS — COMPLETE ENTITY RELATIONSHIP DIAGRAM
%% Version: 3.0
%% Changelog v3.0:
%%   [A] Documented global cross-service identifier contract (EMPLOYEE.id = canonical UUID)
%%   [B] Added is_deleted / deleted_at / deleted_by soft-delete fields to all major entity tables
%%   [C] Added is_primary to EMPLOYEE_PAN and EMPLOYEE_AADHAAR
%%   [D] Added workflow_instance_id FK to all approvable entities
%%   [E] Added MASTER_DATA table for tenant-configurable enums
%%   [F] Added FILE_STORAGE table — replaces raw file_url strings across 11 tables
%%   [G] Added OUTBOX_EVENT table — transactional outbox for microservice reliability
%%   [H] Added EMPLOYEE_HIERARCHY (matrix reporting) + PERMISSION_SCOPE (data-level RBAC)
%%
%% Domains:
%%   1.  Operator Plane (HRMS company internal staff)
%%   2.  Control Plane (tenant management)
%%   3.  Module Catalog & Subscription
%%   4.  Billing & Payments
%%   5.  Auth & RBAC (client plane)
%%   6.  Organisation Hierarchy
%%   7.  Employee Core
%%   8.  Document System (dynamic EAV)
%%   9.  Custom Fields Engine (global EAV)
%%   10. Time, Shift & Roster
%%   11. Leave Management
%%   12. Payroll & Salary Components
%%   13. Tax & Statutory Compliance
%%   14. Benefits Administration
%%   15. Expense Management
%%   16. Recruitment & ATS
%%   17. Onboarding & Offboarding
%%   18. Performance & Goals
%%   19. Learning Management (LMS)
%%   20. Succession & Competency
%%   21. Compensation Management
%%   22. Asset Management
%%   23. Grievance & Case Management
%%   24. Workforce Analytics & Reporting
%%   25. Workflow & Approval Engine
%%   26. Integration & Webhook Registry
%%   27. Communication & Platform
%%   28. Audit & Security
%%   29. Foundation: Master Data + File Storage  [NEW v3.0]
%%   30. Platform Reliability: Outbox Events     [NEW v3.0]
%%
%% CROSS-SERVICE IDENTIFIER CONTRACT [Gap A]:
%%   EMPLOYEE.id (UUID v4) is the single canonical employee identifier
%%   used across ALL microservices. Services store only this UUID as a FK.
%%   Services must NEVER duplicate employee core data (name, email, etc.)
%%   — they fetch it from kabipay-employee service via GraphQL federation.
%%   The same contract applies to: TENANT.id, USER.id, DEPARTMENT.id.
%% ============================================================


%% ============================================================
%% 1. OPERATOR PLANE — HRMS company internal portal
%%    Completely isolated from client USER/ROLE tables.
%%    Account Managers get scoped access via OPERATOR_TENANT_ACCESS.
%% ============================================================

OPERATOR_USER {
  uuid id PK
  string email
  string password_hash
  string full_name
  string phone
  boolean is_active
  timestamp last_login_at
  timestamp created_at
}

OPERATOR_ROLE {
  uuid id PK
  string code
  string name
  string description
}

OPERATOR_USER_ROLE {
  uuid operator_user_id FK
  uuid operator_role_id FK
  timestamp assigned_at
}

OPERATOR_PERMISSION {
  uuid id PK
  string resource
  string action
  string description
}

OPERATOR_ROLE_PERMISSION {
  uuid operator_role_id FK
  uuid operator_permission_id FK
}

OPERATOR_TENANT_ACCESS {
  uuid id PK
  uuid operator_user_id FK
  uuid tenant_id FK
  string access_level
  timestamp granted_at
  timestamp expires_at
}

OPERATOR_AUDIT_LOG {
  uuid id PK
  uuid operator_user_id FK
  uuid tenant_id FK
  string entity_type
  uuid entity_id
  string action
  jsonb before_state
  jsonb after_state
  string ip_address
  timestamp created_at
}

OPERATOR_SUPPORT_TICKET {
  uuid id PK
  uuid tenant_id FK
  uuid assigned_to FK
  string subject
  string status
  string priority
  timestamp opened_at
  timestamp resolved_at
}


%% ============================================================
%% 2. CONTROL PLANE — Tenant management
%%    Each tenant maps to an isolated DB schema.
%%    White-label via subdomain + branding fields.
%% ============================================================

TENANT {
  uuid id PK
  string name
  string status
  string plan
  string country
  string timezone
  string currency
  string gstin
  string pan
  string registered_address
  string logo_url
  string primary_color
  string subdomain
  uuid account_manager_id FK
  timestamp created_at
}

TENANT_DATABASE {
  uuid id PK
  uuid tenant_id FK
  string db_type
  string db_host
  string db_name
  string schema_name
  boolean is_active
}

FEATURE_FLAG {
  uuid id PK
  uuid tenant_id FK
  string feature_name
  boolean is_enabled
  timestamp updated_at
}

COUNTRY_CONFIG {
  uuid id PK
  string country_code
  string country_name
  string default_currency
  string date_format
  string fiscal_year_start
  string tax_regime_type
}

LOCALIZATION_SETTING {
  uuid id PK
  uuid tenant_id FK
  string country_code
  string language
  string date_format
  string number_format
  string currency_symbol
}

STATUTORY_BODY {
  uuid id PK
  uuid country_config_id FK
  string name
  string code
  string filing_type
  string frequency
}


%% ============================================================
%% 3. MODULE CATALOG & SUBSCRIPTION
%%    MODULE is the product catalog.
%%    Pricing supports flat / per_seat / tiered models.
%%    CLIENT_PRICING_OVERRIDE: best-deal-wins at invoice time.
%%    TENANT_SUBSCRIPTION: hard-block on contracted_seats breach.
%% ============================================================

MODULE {
  uuid id PK
  string code
  string name
  string category
  string description
  boolean is_active
  int display_order
  boolean is_core
}

MODULE_DEPENDENCY {
  uuid id PK
  uuid module_id FK
  uuid depends_on_module_id FK
}

MODULE_PRICING {
  uuid id PK
  uuid module_id FK
  string pricing_model
  decimal base_price
  string billing_unit
  int min_units
  string currency
  date effective_from
  date effective_to
  boolean is_current
}

PRICING_TIER {
  uuid id PK
  uuid module_pricing_id FK
  int units_from
  int units_to
  decimal price_per_unit
}

CLIENT_PRICING_OVERRIDE {
  uuid id PK
  uuid tenant_id FK
  uuid module_id FK
  string override_type
  decimal override_value
  date valid_from
  date valid_to
  string reason
  uuid approved_by FK
  boolean is_active
}

TENANT_SUBSCRIPTION {
  uuid id PK
  uuid tenant_id FK
  uuid module_id FK
  string status
  date activated_at
  date expires_at
  int contracted_seats
  int current_seat_usage
  string overage_policy
  uuid approved_by FK
  timestamp created_at
}

SEAT_USAGE_LOG {
  uuid id PK
  uuid subscription_id FK
  uuid user_id FK
  string action
  int seat_count_after
  string triggered_by
  timestamp changed_at
}


%% ============================================================
%% 4. BILLING & PAYMENTS
%%    Auto-generated monthly BILLING_CYCLE per tenant.
%%    INVOICE_LINE_ITEM records which override was applied (audit).
%%    PAYMENT closes the invoice via gateway.
%% ============================================================

BILLING_CYCLE {
  uuid id PK
  uuid tenant_id FK
  date period_start
  date period_end
  string frequency
  string status
  timestamp auto_generated_at
}

INVOICE {
  uuid id PK
  uuid tenant_id FK
  uuid billing_cycle_id FK
  string invoice_number
  decimal subtotal
  decimal discount_total
  decimal tax_amount
  decimal total_amount
  string currency
  string status
  date due_date
  timestamp sent_at
  timestamp paid_at
}

INVOICE_LINE_ITEM {
  uuid id PK
  uuid invoice_id FK
  uuid subscription_id FK
  uuid module_id FK
  string description
  int units_consumed
  decimal unit_price
  decimal gross_amount
  decimal discount_applied
  string discount_source
  decimal line_total
}

PAYMENT {
  uuid id PK
  uuid invoice_id FK
  decimal amount
  string payment_method
  string status
  timestamp paid_at
  string gateway_ref
  string failure_reason
}

CREDIT_NOTE {
  uuid id PK
  uuid invoice_id FK
  uuid tenant_id FK
  decimal amount
  string reason
  string status
  timestamp issued_at
}


%% ============================================================
%% 5. AUTH & RBAC — Client plane
%%    PERMISSION is gated by module_id.
%%    Permissions are only seeded for subscribed modules.
%% ============================================================

USER {
  uuid id PK
  uuid tenant_id FK
  string email
  string password_hash
  boolean is_active
  boolean mfa_enabled
  string mfa_secret
  timestamp last_login_at
  timestamp created_at
}

ROLE {
  uuid id PK
  uuid tenant_id FK
  string name
  string description
  boolean is_system_role
}

PERMISSION {
  uuid id PK
  string resource
  string action
  uuid module_id FK
  string description
}

ROLE_PERMISSION {
  uuid role_id FK
  uuid permission_id FK
}

USER_ROLE {
  uuid user_id FK
  uuid role_id FK
  timestamp assigned_at
}

USER_SESSION {
  uuid id PK
  uuid user_id FK
  string token_hash
  string ip_address
  string user_agent
  timestamp created_at
  timestamp expires_at
}


%% ============================================================
%% 6. ORGANISATION HIERARCHY
%%    DEPARTMENT is self-referencing for tree structure.
%%    COST_CENTER links to payroll cost allocation.
%% ============================================================

DEPARTMENT {
  uuid id PK
  uuid tenant_id FK
  uuid parent_department_id FK
  string name
  string code
  uuid head_employee_id FK
}

DESIGNATION {
  uuid id PK
  uuid tenant_id FK
  uuid department_id FK
  string title
  string level
  int grade
}

COST_CENTER {
  uuid id PK
  uuid tenant_id FK
  string code
  string name
  string type
}

LOCATION {
  uuid id PK
  uuid tenant_id FK
  string name
  string address
  string city
  string state
  string country
  decimal geo_lat
  decimal geo_lng
  decimal geo_fence_radius_meters
}


%% ============================================================
%% 7. EMPLOYEE CORE
%%    Linked to org hierarchy, identification, and all modules.
%%    Probation, notice period, emergency contact added.
%% ============================================================

EMPLOYEE {
  uuid id PK
  uuid tenant_id FK
  uuid user_id FK
  uuid department_id FK
  uuid designation_id FK
  uuid cost_center_id FK
  uuid location_id FK
  uuid reporting_manager_id FK
  string employee_code
  string first_name
  string last_name
  date date_of_birth
  string gender
  string blood_group
  string nationality
  string employment_type
  string status
  date date_of_joining
  date probation_end_date
  int notice_period_days
  string emergency_contact_name
  string emergency_contact_phone
  string emergency_contact_relation
  string uan_number
  string esic_number
  boolean is_deleted
  timestamp deleted_at
  uuid deleted_by FK
  timestamp created_at
  timestamp updated_at
}

EMPLOYMENT_HISTORY {
  uuid id PK
  uuid employee_id FK
  uuid department_id FK
  uuid designation_id FK
  uuid cost_center_id FK
  decimal salary
  date effective_from
  date effective_to
  string change_reason
  uuid changed_by FK
  boolean is_deleted
  timestamp created_at
  timestamp updated_at
}

EMPLOYEE_PAN {
  uuid id PK
  uuid employee_id FK
  string pan_number
  boolean is_primary
  boolean is_verified
  timestamp verified_at
  timestamp created_at
  timestamp updated_at
}

EMPLOYEE_AADHAAR {
  uuid id PK
  uuid employee_id FK
  string aadhaar_last4
  boolean is_primary
  boolean is_verified
  timestamp verified_at
  timestamp created_at
  timestamp updated_at
}

EMPLOYEE_BANK {
  uuid id PK
  uuid employee_id FK
  string account_number
  string ifsc_code
  string bank_name
  string account_type
  boolean is_primary
  boolean is_verified
}

DEPENDENT {
  uuid id PK
  uuid employee_id FK
  string name
  string relationship
  date date_of_birth
  string gender
}


%% ============================================================
%% 8. DOCUMENT SYSTEM — Dynamic EAV per document type
%%    DOCUMENT_FIELD_DEFINITION defines schema per doc type.
%%    EMPLOYEE_DOCUMENT_FIELD stores values.
%% ============================================================

DOCUMENT_TYPE {
  uuid id PK
  uuid tenant_id FK
  string name
  string category
  boolean is_required
  int expiry_alert_days
}

EMPLOYEE_DOCUMENT {
  uuid id PK
  uuid employee_id FK
  uuid document_type_id FK
  uuid file_storage_id FK
  string status
  date expiry_date
  uuid workflow_instance_id FK
  timestamp uploaded_at
  uuid verified_by FK
  timestamp verified_at
  boolean is_deleted
  timestamp deleted_at
  timestamp created_at
  timestamp updated_at
}

DOCUMENT_FIELD_DEFINITION {
  uuid id PK
  uuid document_type_id FK
  string field_name
  string field_type
  boolean is_required
  int display_order
}

EMPLOYEE_DOCUMENT_FIELD {
  uuid id PK
  uuid document_id FK
  uuid field_definition_id FK
  string field_value
}


%% ============================================================
%% 9. CUSTOM FIELDS ENGINE — Global EAV
%%    Applies to any entity (Employee, Leave, Expense, etc.)
%%    Tenants add custom fields without schema migration.
%% ============================================================

CUSTOM_FIELD_DEFINITION {
  uuid id PK
  uuid tenant_id FK
  string entity_type
  string field_name
  string field_label
  string field_type
  string options_json
  boolean is_required
  int display_order
  boolean is_active
}

CUSTOM_FIELD_VALUE {
  uuid id PK
  uuid field_definition_id FK
  uuid entity_id
  string entity_type
  string field_value
}


%% ============================================================
%% 10. TIME, SHIFT & ROSTER
%%     ROSTER + ROSTER_SLOT for advance scheduling.
%%     SHIFT_SWAP_REQUEST for employee-initiated swaps.
%%     COMP_OFF_BALANCE for compensatory leave.
%%     GEO_FENCE on ATTENDANCE via LOCATION.
%% ============================================================

HOLIDAY_CALENDAR {
  uuid id PK
  uuid tenant_id FK
  uuid location_id FK
  string name
  int year
}

HOLIDAY {
  uuid id PK
  uuid calendar_id FK
  date holiday_date
  string name
  string type
}

OVERTIME_RULE {
  uuid id PK
  uuid tenant_id FK
  string name
  decimal threshold_hours_per_day
  decimal threshold_hours_per_week
  decimal multiplier
}

SHIFT {
  uuid id PK
  uuid tenant_id FK
  string name
  time start_time
  time end_time
  int work_hours
  int grace_minutes_in
  int grace_minutes_out
  boolean is_night_shift
}

EMPLOYEE_SHIFT {
  uuid id PK
  uuid employee_id FK
  uuid shift_id FK
  date effective_from
  date effective_to
}

ROSTER {
  uuid id PK
  uuid tenant_id FK
  uuid department_id FK
  date week_start
  string status
}

ROSTER_SLOT {
  uuid id PK
  uuid roster_id FK
  uuid employee_id FK
  uuid shift_id FK
  date slot_date
}

SHIFT_SWAP_REQUEST {
  uuid id PK
  uuid requester_id FK
  uuid target_employee_id FK
  uuid roster_slot_id FK
  string status
  string reason
  timestamp requested_at
}

COMP_OFF_BALANCE {
  uuid id PK
  uuid employee_id FK
  decimal earned_days
  decimal used_days
  decimal balance_days
  int year
}

ATTENDANCE {
  uuid id PK
  uuid employee_id FK
  uuid shift_id FK
  date work_date
  time check_in_time
  time check_out_time
  decimal check_in_lat
  decimal check_in_lng
  decimal check_out_lat
  decimal check_out_lng
  string source
  string status
  string regularization_status
  string biometric_ref
  decimal overtime_hours
  int late_minutes
  int early_exit_minutes
}

ATTENDANCE_REGULARIZATION {
  uuid id PK
  uuid attendance_id FK
  uuid employee_id FK
  string reason
  string status
  uuid approved_by FK
  timestamp requested_at
}


%% ============================================================
%% 11. LEAVE MANAGEMENT
%%     LEAVE_TYPE → LEAVE_POLICY → LEAVE_BALANCE per employee.
%%     LEAVE_ACCRUAL_LOG tracks monthly credit events.
%%     Leave calendar integration via HOLIDAY_CALENDAR.
%% ============================================================

LEAVE_TYPE {
  uuid id PK
  uuid tenant_id FK
  string name
  string code
  boolean is_paid
  boolean carry_forward
  int max_carry_forward_days
  boolean sandwich_rule
  boolean half_day_allowed
  boolean requires_document
}

LEAVE_POLICY {
  uuid id PK
  uuid tenant_id FK
  uuid leave_type_id FK
  string applicable_to
  int annual_entitlement
  string accrual_frequency
  decimal accrual_days
  int max_consecutive_days
  int min_notice_days
}

LEAVE_BALANCE {
  uuid id PK
  uuid employee_id FK
  uuid leave_type_id FK
  int year
  decimal entitled_days
  decimal used_days
  decimal pending_days
  decimal carried_forward_days
  decimal balance_days
}

LEAVE_ACCRUAL_LOG {
  uuid id PK
  uuid employee_id FK
  uuid leave_type_id FK
  decimal days_credited
  string reason
  timestamp credited_at
}

LEAVE_REQUEST {
  uuid id PK
  uuid employee_id FK
  uuid leave_type_id FK
  date from_date
  date to_date
  decimal days_requested
  boolean is_half_day
  string half_day_session
  string status
  string reason
  string rejection_reason
  uuid approved_by FK
  uuid workflow_instance_id FK
  timestamp applied_at
  boolean is_deleted
  timestamp deleted_at
  timestamp created_at
  timestamp updated_at
}


%% ============================================================
%% 12. PAYROLL & SALARY COMPONENTS
%%     SALARY_COMPONENT defines earnings/deductions.
%%     EMPLOYEE_SALARY_STRUCTURE maps components to employee.
%%     PAYSLIP_COMPONENT stores computed amounts per payslip.
%%     Indian statutory fields on PAYSLIP (PF, ESI, TDS).
%% ============================================================

SALARY_COMPONENT {
  uuid id PK
  uuid tenant_id FK
  string name
  string code
  string type
  boolean is_taxable
  boolean is_fixed
  boolean is_active
  string formula_expression
}

SALARY_STRUCTURE {
  uuid id PK
  uuid tenant_id FK
  string name
  string description
}

SALARY_STRUCTURE_COMPONENT {
  uuid id PK
  uuid salary_structure_id FK
  uuid salary_component_id FK
  decimal amount
  decimal percentage_of_basic
  int display_order
}

EMPLOYEE_SALARY_STRUCTURE {
  uuid id PK
  uuid employee_id FK
  uuid salary_structure_id FK
  decimal ctc
  date effective_from
  date effective_to
}

PAYROLL_CYCLE {
  uuid id PK
  uuid tenant_id FK
  string name
  int month
  int year
  string status
  date payment_date
  uuid processed_by FK
  timestamp processed_at
}

PAYSLIP {
  uuid id PK
  uuid employee_id FK
  uuid payroll_cycle_id FK
  decimal gross_salary
  decimal total_deductions
  decimal net_salary
  decimal pf_employee
  decimal pf_employer
  decimal esi_employee
  decimal esi_employer
  decimal tds_amount
  decimal professional_tax
  string uan_number
  string esic_number
  string status
  timestamp generated_at
}

PAYSLIP_COMPONENT {
  uuid id PK
  uuid payslip_id FK
  uuid salary_component_id FK
  decimal amount
  string component_type
}


%% ============================================================
%% 13. TAX & STATUTORY COMPLIANCE
%%     TAX_SLAB supports slab-based computation.
%%     STATUTORY_FILING tracks PF challan, ESI return, TDS, etc.
%%     FORM_16 stores annual tax certificates.
%% ============================================================

TAX_CONFIGURATION_VERSION {
  uuid id PK
  uuid tenant_id FK
  int fiscal_year
  string regime
  string country_code
  boolean is_active
}

TAX_SLAB {
  uuid id PK
  uuid tax_config_version_id FK
  decimal income_from
  decimal income_to
  decimal tax_rate
  decimal surcharge_rate
  decimal cess_rate
}

TAX_COMPUTATION {
  uuid id PK
  uuid employee_id FK
  uuid tax_config_version_id FK
  int fiscal_year
  string tax_regime_chosen
  decimal gross_income
  decimal total_deductions
  decimal taxable_income
  decimal final_tax
  decimal tds_per_month
  timestamp computed_at
}

STATUTORY_FILING {
  uuid id PK
  uuid tenant_id FK
  uuid statutory_body_id FK
  string filing_type
  int month
  int year
  decimal amount
  string status
  string reference_number
  date filed_on
  string file_url
}

FORM_16 {
  uuid id PK
  uuid employee_id FK
  uuid payroll_cycle_id FK
  int fiscal_year
  uuid file_storage_id FK
  timestamp generated_at
  boolean is_sent_to_employee
}

LABOUR_LAW_REGISTER {
  uuid id PK
  uuid tenant_id FK
  string register_name
  string register_type
  int year
  string file_url
  timestamp generated_at
}


%% ============================================================
%% 14. BENEFITS ADMINISTRATION
%%     BENEFIT_PLAN defines what a tenant offers.
%%     EMPLOYEE_BENEFIT_ENROLLMENT is the active election.
%%     BENEFIT_CLAIM for reimbursable benefits.
%% ============================================================

BENEFIT_TYPE {
  uuid id PK
  string name
  string code
  string category
}

BENEFIT_PLAN {
  uuid id PK
  uuid tenant_id FK
  uuid benefit_type_id FK
  string name
  decimal employer_contribution
  decimal employee_contribution
  string contribution_type
  boolean is_mandatory
  boolean is_active
}

EMPLOYEE_BENEFIT_ENROLLMENT {
  uuid id PK
  uuid employee_id FK
  uuid benefit_plan_id FK
  string status
  date enrolled_on
  date effective_from
  date effective_to
  decimal employee_contribution_amount
  decimal employer_contribution_amount
}

BENEFIT_CLAIM {
  uuid id PK
  uuid employee_id FK
  uuid benefit_plan_id FK
  decimal amount
  string status
  date claim_date
  string receipt_url
  string rejection_reason
}


%% ============================================================
%% 15. EXPENSE MANAGEMENT
%%     EXPENSE_POLICY defines per-category limits.
%%     EXPENSE_ITEM is line items within a claim.
%%     Workflow engine handles multi-level approval.
%% ============================================================

EXPENSE_CATEGORY {
  uuid id PK
  uuid tenant_id FK
  string name
  string code
  decimal max_amount_per_claim
}

EXPENSE_POLICY {
  uuid id PK
  uuid tenant_id FK
  uuid expense_category_id FK
  decimal limit_per_day
  decimal limit_per_month
  boolean receipt_required
  boolean approval_required
}

EXPENSE {
  uuid id PK
  uuid employee_id FK
  uuid expense_category_id FK
  decimal amount
  string currency
  date expense_date
  string title
  string status
  string rejection_reason
  uuid approved_by FK
  uuid workflow_instance_id FK
  timestamp submitted_at
  boolean is_deleted
  timestamp deleted_at
  timestamp created_at
  timestamp updated_at
}

EXPENSE_ITEM {
  uuid id PK
  uuid expense_id FK
  string description
  decimal amount
  string receipt_url
  string vendor_name
}


%% ============================================================
%% 16. RECRUITMENT & ATS
%%     Full pipeline: JOB_POSTING → HIRING_STAGE → APPLICATION
%%     → APPLICATION_STAGE_LOG → INTERVIEW → INTERVIEW_SCORECARD
%%     → OFFER_LETTER.
%%     JOB_BOARD_SYNC for external job board publishing.
%%     REFERRAL for employee referral tracking.
%% ============================================================

JOB_POSTING {
  uuid id PK
  uuid tenant_id FK
  uuid department_id FK
  uuid designation_id FK
  uuid location_id FK
  string title
  string description
  string employment_type
  int vacancies
  string status
  date open_date
  date close_date
  uuid created_by FK
}

HIRING_STAGE {
  uuid id PK
  uuid tenant_id FK
  string name
  int sequence_order
  string stage_type
  boolean is_system_stage
}

APPLICATION {
  uuid id PK
  uuid job_id FK
  string candidate_name
  string candidate_email
  string candidate_phone
  string resume_url
  string source
  uuid current_stage_id FK
  string status
  uuid workflow_instance_id FK
  timestamp applied_at
  boolean is_deleted
  timestamp deleted_at
  timestamp created_at
  timestamp updated_at
}

APPLICATION_STAGE_LOG {
  uuid id PK
  uuid application_id FK
  uuid hiring_stage_id FK
  uuid moved_by FK
  string notes
  timestamp moved_at
}

INTERVIEW {
  uuid id PK
  uuid application_id FK
  uuid interviewer_id FK
  uuid hiring_stage_id FK
  timestamp scheduled_at
  int duration_minutes
  string mode
  string meeting_link
  string outcome
  string feedback
}

INTERVIEW_SCORECARD {
  uuid id PK
  uuid interview_id FK
  uuid evaluator_id FK
  string criterion
  int score
  string comments
}

REFERRAL {
  uuid id PK
  uuid application_id FK
  uuid referred_by FK
  string status
  decimal bonus_amount
  string bonus_status
}

OFFER_LETTER {
  uuid id PK
  uuid application_id FK
  uuid employee_id FK
  decimal offered_ctc
  date joining_date
  string status
  uuid file_storage_id FK
  timestamp sent_at
  timestamp accepted_at
}

JOB_BOARD_SYNC {
  uuid id PK
  uuid job_posting_id FK
  string board_name
  string external_job_id
  string status
  timestamp synced_at
}


%% ============================================================
%% 17. ONBOARDING & OFFBOARDING
%%     ONBOARDING_CHECKLIST: task list per new hire.
%%     SEPARATION: resignation/termination record.
%%     EXIT_INTERVIEW: structured exit feedback.
%%     FNF_SETTLEMENT: full & final computation.
%%     CLEARANCE_CHECKLIST: asset return, IT access revocation.
%% ============================================================

ONBOARDING_CHECKLIST {
  uuid id PK
  uuid employee_id FK
  string task_name
  string task_category
  uuid assigned_to FK
  boolean is_completed
  date due_date
  timestamp completed_at
}

SEPARATION {
  uuid id PK
  uuid employee_id FK
  string separation_type
  date resignation_date
  date last_working_date
  string reason
  string status
  uuid approved_by FK
}

EXIT_INTERVIEW {
  uuid id PK
  uuid separation_id FK
  uuid conducted_by FK
  string reason_for_leaving
  string feedback
  int satisfaction_score
  timestamp conducted_at
}

FNF_SETTLEMENT {
  uuid id PK
  uuid separation_id FK
  decimal leave_encashment
  decimal gratuity_amount
  decimal bonus_payable
  decimal recovery_amount
  decimal net_payable
  string status
  timestamp processed_at
  uuid processed_by FK
}

CLEARANCE_CHECKLIST {
  uuid id PK
  uuid separation_id FK
  string department
  string task_name
  boolean is_cleared
  uuid cleared_by FK
  timestamp cleared_at
}


%% ============================================================
%% 18. PERFORMANCE & GOALS
%%     REVIEW_CYCLE frames the appraisal period.
%%     GOAL → KPI for measurable targets.
%%     FEEDBACK_RESPONSE for 360-degree reviews.
%%     PERFORMANCE_RATING for final cycle rating.
%% ============================================================

REVIEW_CYCLE {
  uuid id PK
  uuid tenant_id FK
  string name
  date start_date
  date end_date
  string status
  string review_type
}

GOAL {
  uuid id PK
  uuid employee_id FK
  uuid review_cycle_id FK
  uuid parent_goal_id FK
  string title
  string description
  decimal weightage
  string status
  string visibility
}

KPI {
  uuid id PK
  uuid goal_id FK
  string metric_name
  decimal target_value
  decimal actual_value
  string unit
  date measurement_date
}

FEEDBACK_RESPONSE {
  uuid id PK
  uuid review_cycle_id FK
  uuid reviewer_id FK
  uuid reviewee_id FK
  string relationship
  decimal rating
  string comments
  boolean is_anonymous
  timestamp submitted_at
}

PERFORMANCE_RATING {
  uuid id PK
  uuid employee_id FK
  uuid review_cycle_id FK
  decimal self_rating
  decimal manager_rating
  decimal final_rating
  string performance_band
  string comments
  uuid rated_by FK
  timestamp rated_at
}


%% ============================================================
%% 19. LEARNING MANAGEMENT SYSTEM (LMS)
%%     COURSE → COURSE_MODULE → ENROLLMENT → PROGRESS.
%%     LEARNING_PATH bundles multiple courses.
%%     CERTIFICATION tracks completion certificates.
%%     SKILL and EMPLOYEE_SKILL for skills inventory.
%% ============================================================

SKILL {
  uuid id PK
  uuid tenant_id FK
  string name
  string category
  string level
}

EMPLOYEE_SKILL {
  uuid id PK
  uuid employee_id FK
  uuid skill_id FK
  string proficiency_level
  date acquired_on
  boolean is_verified
}

COURSE {
  uuid id PK
  uuid tenant_id FK
  string title
  string description
  string category
  string delivery_mode
  int duration_minutes
  boolean is_mandatory
  boolean is_active
  uuid created_by FK
}

COURSE_MODULE {
  uuid id PK
  uuid course_id FK
  string title
  string content_type
  string content_url
  int duration_minutes
  int sequence_order
}

LEARNING_PATH {
  uuid id PK
  uuid tenant_id FK
  string name
  string description
  uuid target_designation_id FK
}

LEARNING_PATH_COURSE {
  uuid id PK
  uuid learning_path_id FK
  uuid course_id FK
  int sequence_order
  boolean is_mandatory
}

ENROLLMENT {
  uuid id PK
  uuid employee_id FK
  uuid course_id FK
  string status
  decimal completion_percentage
  timestamp enrolled_at
  timestamp completed_at
  timestamp due_date
}

COURSE_PROGRESS {
  uuid id PK
  uuid enrollment_id FK
  uuid course_module_id FK
  boolean is_completed
  decimal progress_percentage
  timestamp last_accessed_at
}

CERTIFICATION {
  uuid id PK
  uuid employee_id FK
  uuid course_id FK
  string certificate_number
  uuid file_storage_id FK
  date issued_on
  date expires_on
}


%% ============================================================
%% 20. SUCCESSION PLANNING & COMPETENCY
%%     COMPETENCY framework for role requirements.
%%     SUCCESSION_PLAN maps critical roles to successors.
%%     TALENT_POOL groups high-potential employees.
%%     CAREER_PATH defines progression routes.
%% ============================================================

COMPETENCY {
  uuid id PK
  uuid tenant_id FK
  string name
  string category
  string description
}

COMPETENCY_LEVEL {
  uuid id PK
  uuid competency_id FK
  int level
  string descriptor
}

DESIGNATION_COMPETENCY {
  uuid id PK
  uuid designation_id FK
  uuid competency_id FK
  int required_level
}

EMPLOYEE_COMPETENCY {
  uuid id PK
  uuid employee_id FK
  uuid competency_id FK
  int current_level
  timestamp assessed_at
  uuid assessed_by FK
}

TALENT_POOL {
  uuid id PK
  uuid tenant_id FK
  string name
  string description
}

TALENT_POOL_MEMBER {
  uuid id PK
  uuid talent_pool_id FK
  uuid employee_id FK
  string readiness_level
  timestamp added_at
  uuid added_by FK
}

SUCCESSION_PLAN {
  uuid id PK
  uuid tenant_id FK
  uuid critical_designation_id FK
  uuid review_cycle_id FK
  string status
}

SUCCESSION_CANDIDATE {
  uuid id PK
  uuid succession_plan_id FK
  uuid employee_id FK
  int rank
  string readiness_level
  string gap_summary
}

CAREER_PATH {
  uuid id PK
  uuid tenant_id FK
  uuid from_designation_id FK
  uuid to_designation_id FK
  int typical_months
}


%% ============================================================
%% 21. COMPENSATION MANAGEMENT
%%     SALARY_BAND defines market ranges per grade.
%%     COMPENSATION_REVIEW_CYCLE drives annual increment.
%%     BONUS_PLAN for performance-linked payouts.
%%     EQUITY_GRANT for ESOP/stock-based comp.
%% ============================================================

SALARY_BAND {
  uuid id PK
  uuid tenant_id FK
  uuid designation_id FK
  int grade
  decimal min_salary
  decimal mid_salary
  decimal max_salary
  string currency
  int effective_year
}

COMPENSATION_REVIEW_CYCLE {
  uuid id PK
  uuid tenant_id FK
  string name
  int year
  date start_date
  date end_date
  string status
  decimal budget_percentage
}

COMPENSATION_REVIEW_ITEM {
  uuid id PK
  uuid review_cycle_id FK
  uuid employee_id FK
  decimal current_ctc
  decimal recommended_ctc
  decimal increment_percentage
  string increment_type
  string status
  uuid approved_by FK
}

BONUS_PLAN {
  uuid id PK
  uuid tenant_id FK
  string name
  string calculation_basis
  decimal target_percentage
  uuid review_cycle_id FK
}

BONUS_PAYOUT {
  uuid id PK
  uuid bonus_plan_id FK
  uuid employee_id FK
  decimal target_amount
  decimal actual_amount
  decimal performance_multiplier
  string status
  uuid approved_by FK
}

EQUITY_GRANT {
  uuid id PK
  uuid employee_id FK
  string grant_type
  int units_granted
  decimal strike_price
  date grant_date
  date vesting_start_date
  string vesting_schedule
  string status
}


%% ============================================================
%% 22. ASSET MANAGEMENT
%%     ASSET tracks physical/digital assets.
%%     ASSET_ALLOCATION links to employee (onboarding/offboarding).
%%     ASSET_RETURN_LOG records returns with condition.
%% ============================================================

ASSET_CATEGORY {
  uuid id PK
  uuid tenant_id FK
  string name
  string code
}

ASSET {
  uuid id PK
  uuid tenant_id FK
  uuid asset_category_id FK
  string name
  string serial_number
  string asset_tag
  decimal purchase_value
  date purchase_date
  string status
  uuid location_id FK
}

ASSET_ALLOCATION {
  uuid id PK
  uuid asset_id FK
  uuid employee_id FK
  date allocated_on
  date expected_return_on
  string condition_at_allocation
  string status
}

ASSET_RETURN_LOG {
  uuid id PK
  uuid asset_allocation_id FK
  date returned_on
  string condition_at_return
  string remarks
  uuid received_by FK
}


%% ============================================================
%% 23. GRIEVANCE & CASE MANAGEMENT
%%     GRIEVANCE_CASE for formal complaints (inc. POSH).
%%     CASE_PARTICIPANT tracks involved parties.
%%     CASE_ACTION for timeline of investigation actions.
%%     DISCIPLINARY_ACTION for formal outcomes.
%% ============================================================

GRIEVANCE_CATEGORY {
  uuid id PK
  uuid tenant_id FK
  string name
  string code
  boolean is_posh
  int resolution_sla_days
}

GRIEVANCE_CASE {
  uuid id PK
  uuid tenant_id FK
  uuid employee_id FK
  uuid grievance_category_id FK
  string subject
  string description
  string status
  string priority
  string confidentiality_level
  uuid assigned_to FK
  timestamp filed_at
  timestamp resolved_at
}

CASE_PARTICIPANT {
  uuid id PK
  uuid grievance_case_id FK
  uuid employee_id FK
  string role
}

CASE_ACTION {
  uuid id PK
  uuid grievance_case_id FK
  uuid performed_by FK
  string action_type
  string description
  string file_url
  timestamp performed_at
}

DISCIPLINARY_ACTION {
  uuid id PK
  uuid grievance_case_id FK
  uuid employee_id FK
  string action_type
  string description
  date effective_date
  date expiry_date
  uuid issued_by FK
}


%% ============================================================
%% 24. WORKFORCE ANALYTICS & REPORTING
%%     REPORT_DEFINITION: saved report configs per tenant.
%%     DASHBOARD + DASHBOARD_WIDGET: KPI dashboards.
%%     WORKFORCE_SNAPSHOT: periodic headcount snapshots.
%%     REPORT_SCHEDULE: automated report delivery.
%% ============================================================

REPORT_DEFINITION {
  uuid id PK
  uuid tenant_id FK
  string name
  string entity_type
  string filters_json
  string columns_json
  string groupby_json
  string chart_type
  boolean is_public
  uuid created_by FK
}

REPORT_SCHEDULE {
  uuid id PK
  uuid report_definition_id FK
  string frequency
  string recipients_json
  string delivery_format
  timestamp last_sent_at
  timestamp next_run_at
  boolean is_active
}

DASHBOARD {
  uuid id PK
  uuid tenant_id FK
  string name
  string description
  boolean is_default
  uuid created_by FK
}

DASHBOARD_WIDGET {
  uuid id PK
  uuid dashboard_id FK
  uuid report_definition_id FK
  string widget_type
  string title
  int grid_col
  int grid_row
  int col_span
  int row_span
}

WORKFORCE_SNAPSHOT {
  uuid id PK
  uuid tenant_id FK
  date snapshot_date
  int total_headcount
  int active_employees
  int new_joiners
  int separations
  int open_positions
  decimal average_tenure_months
  decimal attrition_rate
}


%% ============================================================
%% 25. WORKFLOW & APPROVAL ENGINE
%%     WORKFLOW is reusable per entity_type.
%%     APPROVAL_MATRIX defines who approves what by rule.
%%     APPROVAL_RULE with conditions (amount, grade, dept).
%% ============================================================

WORKFLOW {
  uuid id PK
  uuid tenant_id FK
  string name
  string entity_type
  boolean is_active
}

WORKFLOW_STEP {
  uuid id PK
  uuid workflow_id FK
  int sequence_order
  string step_name
  string approver_type
  uuid approver_role_id FK
  boolean can_skip
  int sla_hours
}

WORKFLOW_INSTANCE {
  uuid id PK
  uuid workflow_id FK
  string entity_type
  uuid entity_id
  string status
  uuid current_step_id FK
  timestamp created_at
  timestamp completed_at
}

WORKFLOW_ACTION {
  uuid id PK
  uuid instance_id FK
  uuid workflow_step_id FK
  uuid performed_by FK
  string action
  string remarks
  timestamp acted_at
}

APPROVAL_MATRIX {
  uuid id PK
  uuid tenant_id FK
  string entity_type
  string name
  boolean is_active
}

APPROVAL_RULE {
  uuid id PK
  uuid approval_matrix_id FK
  int sequence_order
  string approver_type
  uuid approver_role_id FK
  uuid approver_employee_id FK
}

APPROVAL_CONDITION {
  uuid id PK
  uuid approval_rule_id FK
  string field_name
  string operator
  string value
}


%% ============================================================
%% 26. INTEGRATION & WEBHOOK REGISTRY
%%     INTEGRATION_CONNECTOR: catalog of available connectors.
%%     TENANT_INTEGRATION: per-tenant activation with credentials.
%%     WEBHOOK_SUBSCRIPTION: event-based outbound hooks.
%%     WEBHOOK_DELIVERY_LOG: delivery audit trail.
%% ============================================================

INTEGRATION_CONNECTOR {
  uuid id PK
  string name
  string code
  string category
  string auth_type
  string config_schema_json
  boolean is_active
}

TENANT_INTEGRATION {
  uuid id PK
  uuid tenant_id FK
  uuid integration_connector_id FK
  string credentials_encrypted
  string config_json
  boolean is_active
  timestamp connected_at
}

WEBHOOK_SUBSCRIPTION {
  uuid id PK
  uuid tenant_id FK
  string event_name
  string endpoint_url
  string secret_hash
  boolean is_active
  timestamp created_at
}

WEBHOOK_DELIVERY_LOG {
  uuid id PK
  uuid webhook_subscription_id FK
  string event_name
  string payload_json
  int http_status
  string response_body
  boolean is_success
  int attempt_number
  timestamp delivered_at
}


%% ============================================================
%% 27. COMMUNICATION & PLATFORM
%%     ANNOUNCEMENT with target audience scoping.
%%     NOTIFICATION per user with action URL.
%% ============================================================

ANNOUNCEMENT {
  uuid id PK
  uuid tenant_id FK
  uuid created_by FK
  string title
  string body
  string target_audience
  uuid target_department_id FK
  uuid target_location_id FK
  timestamp publish_at
  timestamp expires_at
}

NOTIFICATION {
  uuid id PK
  uuid user_id FK
  string type
  string title
  string message
  string action_url
  boolean is_read
  timestamp read_at
  timestamp created_at
}


%% ============================================================
%% 28. AUDIT & SECURITY
%%     CLIENT AUDIT_LOG: full before/after jsonb per entity.
%%     USER_SESSION: token management per device.
%% ============================================================

AUDIT_LOG {
  uuid id PK
  uuid tenant_id FK
  uuid user_id FK
  string entity_type
  uuid entity_id
  string action
  jsonb before_state
  jsonb after_state
  string ip_address
  string user_agent
  timestamp created_at
}


%% ============================================================
%% 29. FOUNDATION: MASTER DATA + FILE STORAGE          [NEW v3.0]
%%
%%     MASTER_DATA [Gap E]: Tenant-configurable enum values.
%%       category = 'LEAVE_STATUS' | 'EXPENSE_STATUS' | 'APPLICATION_STATUS'
%%                | 'GRIEVANCE_PRIORITY' | 'DOC_CATEGORY' | ...
%%       System values (is_system=true) seeded at tenant creation,
%%       cannot be deleted but can be hidden. Tenant can add custom values.
%%       Use this for any status/type field that is a simple dropdown.
%%       Do NOT use for types with business-logic columns (LEAVE_TYPE etc.).
%%
%%     FILE_STORAGE [Gap F]: Provider-agnostic file abstraction.
%%       All file_url string columns across the ERD have been replaced
%%       with file_storage_id FK pointing here. Enables switching
%%       S3 → GCP → Azure → local without any data migration.
%%       signed_url and signed_url_expires_at are populated at read time
%%       by the file service, never stored permanently.
%% ============================================================

MASTER_DATA {
  uuid id PK
  uuid tenant_id FK
  string category
  string key
  string value
  string description
  int display_order
  boolean is_system
  boolean is_active
  timestamp created_at
  timestamp updated_at
}

FILE_STORAGE {
  uuid id PK
  uuid tenant_id FK
  string provider
  string bucket
  string storage_path
  string original_filename
  string mime_type
  int file_size_bytes
  boolean is_public
  uuid uploaded_by FK
  timestamp created_at
}


%% ============================================================
%% 30. PLATFORM RELIABILITY: OUTBOX EVENTS              [NEW v3.0]
%%
%%     OUTBOX_EVENT [Gap G]: Transactional outbox pattern.
%%       Each microservice has this table in its own database.
%%       Events are written atomically in the same DB transaction
%%       as the business operation (e.g. payslip generated → event row).
%%       A background poller publishes pending events to the message bus
%%       and marks them processed. Guarantees at-least-once delivery.
%%
%%       Critical event flows:
%%         employee.created       → provision user in all subscribed modules
%%         leave.approved         → update leave_balance, notify employee
%%         payroll.processed      → trigger tax computation, notify employees
%%         subscription.activated → seed permissions, notify tenant admin
%%         seat.limit_reached     → notify account manager + tenant admin
%%
%%       Consumers must be idempotent — check event_id before processing.
%% ============================================================

OUTBOX_EVENT {
  uuid id PK
  uuid tenant_id FK
  string aggregate_type
  uuid aggregate_id
  string event_type
  jsonb payload
  string status
  int retry_count
  string last_error
  timestamp created_at
  timestamp processed_at
}


%% ============================================================
%% ADDITIONS TO DOMAIN 5 & 6: PERMISSION SCOPE + HIERARCHY [NEW v3.0]
%%
%%     PERMISSION_SCOPE [Gap H]: Data-level access control.
%%       Extends the role-permission model with scope_type:
%%         SELF      — user can only see/edit their own records
%%         TEAM      — manager sees their direct reports
%%         DEPARTMENT — HR sees their department
%%         ALL       — full access (HR admin, payroll admin)
%%       Applied per resource per role. The middleware checks scope
%%       before executing any query and injects the appropriate
%%       WHERE clause filter.
%%
%%     EMPLOYEE_HIERARCHY [Gap H]: Supports matrix / dotted-line reporting.
%%       hierarchy_type = DIRECT (primary manager) | DOTTED_LINE (secondary)
%%       A single employee can have one DIRECT manager and N DOTTED_LINE managers.
%%       This table is the source of truth for approval routing in WORKFLOW_STEP
%%       when approver_type = 'REPORTING_MANAGER'.
%% ============================================================

PERMISSION_SCOPE {
  uuid id PK
  uuid tenant_id FK
  uuid role_id FK
  string resource
  string action
  string scope_type
  timestamp created_at
}

EMPLOYEE_HIERARCHY {
  uuid id PK
  uuid tenant_id FK
  uuid employee_id FK
  uuid manager_id FK
  string hierarchy_type
  date effective_from
  date effective_to
  boolean is_active
  timestamp created_at
  timestamp updated_at
}


%% ============================================================

%% --- Operator Plane ---
OPERATOR_USER ||--o{ OPERATOR_USER_ROLE : "has"
OPERATOR_ROLE ||--o{ OPERATOR_USER_ROLE : "assigned via"
OPERATOR_ROLE ||--o{ OPERATOR_ROLE_PERMISSION : "has"
OPERATOR_PERMISSION ||--o{ OPERATOR_ROLE_PERMISSION : "granted via"
OPERATOR_USER ||--o{ OPERATOR_TENANT_ACCESS : "scoped to"
TENANT ||--o{ OPERATOR_TENANT_ACCESS : "managed by"
OPERATOR_USER ||--o{ OPERATOR_AUDIT_LOG : "tracked in"
OPERATOR_USER ||--o{ TENANT : "account manages"
OPERATOR_USER ||--o{ OPERATOR_SUPPORT_TICKET : "handles"
TENANT ||--o{ OPERATOR_SUPPORT_TICKET : "raises"

%% --- Control Plane ---
TENANT ||--o{ TENANT_DATABASE : "has"
TENANT ||--o{ FEATURE_FLAG : "has"
TENANT ||--o{ LOCALIZATION_SETTING : "configured in"
COUNTRY_CONFIG ||--o{ STATUTORY_BODY : "defines"
COUNTRY_CONFIG ||--o{ LOCALIZATION_SETTING : "referenced by"

%% --- Module Catalog ---
MODULE ||--o{ MODULE_PRICING : "priced via"
MODULE ||--o{ MODULE_DEPENDENCY : "depends on"
MODULE_PRICING ||--o{ PRICING_TIER : "has tiers"
MODULE ||--o{ CLIENT_PRICING_OVERRIDE : "overridden for"
MODULE ||--o{ TENANT_SUBSCRIPTION : "subscribed as"
MODULE ||--o{ PERMISSION : "gates"
TENANT ||--o{ CLIENT_PRICING_OVERRIDE : "has"
TENANT ||--o{ TENANT_SUBSCRIPTION : "subscribes to"
TENANT_SUBSCRIPTION ||--o{ SEAT_USAGE_LOG : "tracked via"
TENANT_SUBSCRIPTION ||--o{ INVOICE_LINE_ITEM : "billed as"

%% --- Billing ---
TENANT ||--o{ BILLING_CYCLE : "billed via"
BILLING_CYCLE ||--o{ INVOICE : "generates"
INVOICE ||--o{ INVOICE_LINE_ITEM : "contains"
INVOICE ||--o{ PAYMENT : "settled by"
INVOICE ||--o{ CREDIT_NOTE : "credited via"
MODULE ||--o{ INVOICE_LINE_ITEM : "itemised as"

%% --- Auth & RBAC ---
USER ||--o{ USER_ROLE : "has"
ROLE ||--o{ USER_ROLE : "assigned via"
ROLE ||--o{ ROLE_PERMISSION : "has"
PERMISSION ||--o{ ROLE_PERMISSION : "granted via"
USER ||--o{ USER_SESSION : "authenticated via"

%% --- Org Hierarchy ---
TENANT ||--o{ DEPARTMENT : "has"
TENANT ||--o{ LOCATION : "has"
DEPARTMENT ||--o{ DEPARTMENT : "parent of"
DEPARTMENT ||--o{ DESIGNATION : "has"
TENANT ||--o{ COST_CENTER : "has"

%% --- Employee ---
EMPLOYEE ||--o{ EMPLOYMENT_HISTORY : "has"
EMPLOYEE ||--|| EMPLOYEE_PAN : "has"
EMPLOYEE ||--|| EMPLOYEE_AADHAAR : "has"
EMPLOYEE ||--o{ EMPLOYEE_BANK : "has"
EMPLOYEE ||--o{ DEPENDENT : "has"
DEPARTMENT ||--o{ EMPLOYEE : "contains"
DESIGNATION ||--o{ EMPLOYEE : "holds"
COST_CENTER ||--o{ EMPLOYEE : "allocated to"
LOCATION ||--o{ EMPLOYEE : "based at"

%% --- Documents ---
DOCUMENT_TYPE ||--o{ EMPLOYEE_DOCUMENT : "typed as"
DOCUMENT_TYPE ||--o{ DOCUMENT_FIELD_DEFINITION : "defines"
EMPLOYEE ||--o{ EMPLOYEE_DOCUMENT : "has"
EMPLOYEE_DOCUMENT ||--o{ EMPLOYEE_DOCUMENT_FIELD : "has values"
DOCUMENT_FIELD_DEFINITION ||--o{ EMPLOYEE_DOCUMENT_FIELD : "defined by"

%% --- Custom Fields ---
TENANT ||--o{ CUSTOM_FIELD_DEFINITION : "defines"
CUSTOM_FIELD_DEFINITION ||--o{ CUSTOM_FIELD_VALUE : "stores"

%% --- Time & Roster ---
TENANT ||--o{ HOLIDAY_CALENDAR : "has"
LOCATION ||--o{ HOLIDAY_CALENDAR : "scoped to"
HOLIDAY_CALENDAR ||--o{ HOLIDAY : "contains"
TENANT ||--o{ OVERTIME_RULE : "has"
TENANT ||--o{ SHIFT : "defines"
SHIFT ||--o{ EMPLOYEE_SHIFT : "assigned via"
EMPLOYEE ||--o{ EMPLOYEE_SHIFT : "has"
DEPARTMENT ||--o{ ROSTER : "scheduled in"
ROSTER ||--o{ ROSTER_SLOT : "contains"
SHIFT ||--o{ ROSTER_SLOT : "used in"
EMPLOYEE ||--o{ ROSTER_SLOT : "assigned in"
EMPLOYEE ||--o{ SHIFT_SWAP_REQUEST : "requests"
EMPLOYEE ||--o{ COMP_OFF_BALANCE : "has"
EMPLOYEE ||--o{ ATTENDANCE : "logs"
ATTENDANCE ||--o{ ATTENDANCE_REGULARIZATION : "regularised via"

%% --- Leave ---
LEAVE_TYPE ||--o{ LEAVE_POLICY : "governed by"
LEAVE_TYPE ||--o{ LEAVE_BALANCE : "tracked in"
LEAVE_TYPE ||--o{ LEAVE_REQUEST : "requested as"
EMPLOYEE ||--o{ LEAVE_BALANCE : "has"
EMPLOYEE ||--o{ LEAVE_REQUEST : "submits"
EMPLOYEE ||--o{ LEAVE_ACCRUAL_LOG : "credited in"

%% --- Payroll ---
SALARY_STRUCTURE ||--o{ SALARY_STRUCTURE_COMPONENT : "has"
SALARY_COMPONENT ||--o{ SALARY_STRUCTURE_COMPONENT : "used in"
EMPLOYEE ||--o{ EMPLOYEE_SALARY_STRUCTURE : "has"
SALARY_STRUCTURE ||--o{ EMPLOYEE_SALARY_STRUCTURE : "applied to"
PAYROLL_CYCLE ||--o{ PAYSLIP : "generates"
EMPLOYEE ||--o{ PAYSLIP : "receives"
PAYSLIP ||--o{ PAYSLIP_COMPONENT : "contains"
SALARY_COMPONENT ||--o{ PAYSLIP_COMPONENT : "used in"

%% --- Tax & Compliance ---
TAX_CONFIGURATION_VERSION ||--o{ TAX_SLAB : "has"
TAX_CONFIGURATION_VERSION ||--o{ TAX_COMPUTATION : "used in"
EMPLOYEE ||--o{ TAX_COMPUTATION : "computed for"
PAYROLL_CYCLE ||--o{ FORM_16 : "generates"
EMPLOYEE ||--o{ FORM_16 : "issued to"
TENANT ||--o{ STATUTORY_FILING : "files"
STATUTORY_BODY ||--o{ STATUTORY_FILING : "filed with"
TENANT ||--o{ LABOUR_LAW_REGISTER : "maintains"

%% --- Benefits ---
BENEFIT_TYPE ||--o{ BENEFIT_PLAN : "typed as"
TENANT ||--o{ BENEFIT_PLAN : "offers"
EMPLOYEE ||--o{ EMPLOYEE_BENEFIT_ENROLLMENT : "enrolled in"
BENEFIT_PLAN ||--o{ EMPLOYEE_BENEFIT_ENROLLMENT : "enrolled via"
EMPLOYEE ||--o{ BENEFIT_CLAIM : "claims"
BENEFIT_PLAN ||--o{ BENEFIT_CLAIM : "claimed under"
EMPLOYEE ||--o{ DEPENDENT : "has"

%% --- Expense ---
TENANT ||--o{ EXPENSE_CATEGORY : "defines"
EXPENSE_CATEGORY ||--o{ EXPENSE_POLICY : "governed by"
EXPENSE_CATEGORY ||--o{ EXPENSE : "categorised as"
EMPLOYEE ||--o{ EXPENSE : "claims"
EXPENSE ||--o{ EXPENSE_ITEM : "contains"

%% --- Recruitment ---
DEPARTMENT ||--o{ JOB_POSTING : "opens"
DESIGNATION ||--o{ JOB_POSTING : "for"
LOCATION ||--o{ JOB_POSTING : "at"
JOB_POSTING ||--o{ APPLICATION : "receives"
HIRING_STAGE ||--o{ APPLICATION : "current stage"
APPLICATION ||--o{ APPLICATION_STAGE_LOG : "tracked via"
HIRING_STAGE ||--o{ APPLICATION_STAGE_LOG : "logged at"
APPLICATION ||--o{ INTERVIEW : "has"
INTERVIEW ||--o{ INTERVIEW_SCORECARD : "scored via"
APPLICATION ||--o{ REFERRAL : "referred via"
APPLICATION ||--|| OFFER_LETTER : "results in"
JOB_POSTING ||--o{ JOB_BOARD_SYNC : "published via"

%% --- Onboarding & Offboarding ---
EMPLOYEE ||--o{ ONBOARDING_CHECKLIST : "completes"
EMPLOYEE ||--o{ SEPARATION : "has"
SEPARATION ||--|| EXIT_INTERVIEW : "has"
SEPARATION ||--|| FNF_SETTLEMENT : "settled via"
SEPARATION ||--o{ CLEARANCE_CHECKLIST : "cleared via"

%% --- Performance ---
REVIEW_CYCLE ||--o{ GOAL : "frames"
REVIEW_CYCLE ||--o{ FEEDBACK_RESPONSE : "collects"
REVIEW_CYCLE ||--o{ PERFORMANCE_RATING : "produces"
GOAL ||--o{ KPI : "measured by"
GOAL ||--o{ GOAL : "parent of"
EMPLOYEE ||--o{ GOAL : "sets"
EMPLOYEE ||--o{ FEEDBACK_RESPONSE : "reviewed in"
EMPLOYEE ||--o{ PERFORMANCE_RATING : "rated in"

%% --- LMS ---
TENANT ||--o{ COURSE : "owns"
COURSE ||--o{ COURSE_MODULE : "has"
LEARNING_PATH ||--o{ LEARNING_PATH_COURSE : "includes"
COURSE ||--o{ LEARNING_PATH_COURSE : "used in"
EMPLOYEE ||--o{ ENROLLMENT : "enrolled in"
COURSE ||--o{ ENROLLMENT : "enrolled via"
ENROLLMENT ||--o{ COURSE_PROGRESS : "tracked via"
COURSE_MODULE ||--o{ COURSE_PROGRESS : "tracked in"
EMPLOYEE ||--o{ CERTIFICATION : "holds"
COURSE ||--o{ CERTIFICATION : "grants"
TENANT ||--o{ SKILL : "defines"
EMPLOYEE ||--o{ EMPLOYEE_SKILL : "has"
SKILL ||--o{ EMPLOYEE_SKILL : "tagged in"

%% --- Succession & Competency ---
TENANT ||--o{ COMPETENCY : "defines"
COMPETENCY ||--o{ COMPETENCY_LEVEL : "has"
DESIGNATION ||--o{ DESIGNATION_COMPETENCY : "requires"
COMPETENCY ||--o{ DESIGNATION_COMPETENCY : "required via"
EMPLOYEE ||--o{ EMPLOYEE_COMPETENCY : "assessed in"
COMPETENCY ||--o{ EMPLOYEE_COMPETENCY : "assessed as"
TENANT ||--o{ TALENT_POOL : "has"
TALENT_POOL ||--o{ TALENT_POOL_MEMBER : "contains"
EMPLOYEE ||--o{ TALENT_POOL_MEMBER : "member of"
SUCCESSION_PLAN ||--o{ SUCCESSION_CANDIDATE : "has"
EMPLOYEE ||--o{ SUCCESSION_CANDIDATE : "nominated as"
DESIGNATION ||--o{ CAREER_PATH : "from"
DESIGNATION ||--o{ CAREER_PATH : "to"

%% --- Compensation ---
DESIGNATION ||--o{ SALARY_BAND : "banded by"
TENANT ||--o{ COMPENSATION_REVIEW_CYCLE : "runs"
COMPENSATION_REVIEW_CYCLE ||--o{ COMPENSATION_REVIEW_ITEM : "contains"
EMPLOYEE ||--o{ COMPENSATION_REVIEW_ITEM : "reviewed in"
TENANT ||--o{ BONUS_PLAN : "defines"
BONUS_PLAN ||--o{ BONUS_PAYOUT : "pays out"
EMPLOYEE ||--o{ BONUS_PAYOUT : "receives"
EMPLOYEE ||--o{ EQUITY_GRANT : "granted"

%% --- Assets ---
TENANT ||--o{ ASSET_CATEGORY : "defines"
ASSET_CATEGORY ||--o{ ASSET : "categorised as"
ASSET ||--o{ ASSET_ALLOCATION : "allocated via"
EMPLOYEE ||--o{ ASSET_ALLOCATION : "allocated to"
ASSET_ALLOCATION ||--o{ ASSET_RETURN_LOG : "returned via"

%% --- Grievance ---
TENANT ||--o{ GRIEVANCE_CATEGORY : "defines"
GRIEVANCE_CATEGORY ||--o{ GRIEVANCE_CASE : "categorised as"
EMPLOYEE ||--o{ GRIEVANCE_CASE : "files"
GRIEVANCE_CASE ||--o{ CASE_PARTICIPANT : "involves"
GRIEVANCE_CASE ||--o{ CASE_ACTION : "actioned via"
GRIEVANCE_CASE ||--o{ DISCIPLINARY_ACTION : "results in"

%% --- Analytics ---
TENANT ||--o{ REPORT_DEFINITION : "defines"
REPORT_DEFINITION ||--o{ REPORT_SCHEDULE : "scheduled via"
TENANT ||--o{ DASHBOARD : "has"
DASHBOARD ||--o{ DASHBOARD_WIDGET : "contains"
REPORT_DEFINITION ||--o{ DASHBOARD_WIDGET : "feeds"
TENANT ||--o{ WORKFORCE_SNAPSHOT : "snapshotted in"

%% --- Workflow & Approvals ---
TENANT ||--o{ WORKFLOW : "defines"
WORKFLOW ||--o{ WORKFLOW_STEP : "has"
WORKFLOW ||--o{ WORKFLOW_INSTANCE : "instantiated as"
WORKFLOW_INSTANCE ||--o{ WORKFLOW_ACTION : "progresses via"
WORKFLOW_STEP ||--o{ WORKFLOW_ACTION : "actioned at"
TENANT ||--o{ APPROVAL_MATRIX : "defines"
APPROVAL_MATRIX ||--o{ APPROVAL_RULE : "has"
APPROVAL_RULE ||--o{ APPROVAL_CONDITION : "conditioned by"

%% --- Integrations ---
TENANT ||--o{ TENANT_INTEGRATION : "connected via"
INTEGRATION_CONNECTOR ||--o{ TENANT_INTEGRATION : "activated as"
TENANT ||--o{ WEBHOOK_SUBSCRIPTION : "subscribes to"
WEBHOOK_SUBSCRIPTION ||--o{ WEBHOOK_DELIVERY_LOG : "logged in"

%% --- Communication ---
TENANT ||--o{ ANNOUNCEMENT : "publishes"
DEPARTMENT ||--o{ ANNOUNCEMENT : "targeted to"
USER ||--o{ NOTIFICATION : "receives"

%% --- Audit ---
TENANT ||--o{ AUDIT_LOG : "tracked in"
USER ||--o{ AUDIT_LOG : "performed by"

%% --- Master Data [Gap E] ---
TENANT ||--o{ MASTER_DATA : "configures"

%% --- File Storage [Gap F] ---
TENANT ||--o{ FILE_STORAGE : "stores files in"
FILE_STORAGE ||--o{ EMPLOYEE_DOCUMENT : "referenced by"
FILE_STORAGE ||--o{ OFFER_LETTER : "referenced by"
FILE_STORAGE ||--o{ CERTIFICATION : "referenced by"
FILE_STORAGE ||--o{ FORM_16 : "referenced by"

%% --- Outbox Events [Gap G] ---
TENANT ||--o{ OUTBOX_EVENT : "emits events in"

%% --- Permission Scope [Gap H] ---
TENANT ||--o{ PERMISSION_SCOPE : "defines"
ROLE ||--o{ PERMISSION_SCOPE : "scoped by"

%% --- Employee Hierarchy [Gap H] ---
TENANT ||--o{ EMPLOYEE_HIERARCHY : "defines"
EMPLOYEE ||--o{ EMPLOYEE_HIERARCHY : "managed in"

%% --- Workflow instance linkage [Gap D] ---
WORKFLOW_INSTANCE ||--o{ LEAVE_REQUEST : "governs"
WORKFLOW_INSTANCE ||--o{ EXPENSE : "governs"
WORKFLOW_INSTANCE ||--o{ APPLICATION : "governs"
WORKFLOW_INSTANCE ||--o{ EMPLOYEE_DOCUMENT : "governs"
```

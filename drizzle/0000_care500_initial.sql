CREATE TYPE "contribution_type" AS ENUM ('one_off', 'recurring');
CREATE TYPE "contribution_status" AS ENUM ('pending', 'success', 'failed');
CREATE TYPE "provider_type" AS ENUM ('hospital', 'pharmacy', 'lab', 'other');
CREATE TYPE "case_status" AS ENUM ('submitted', 'in_review', 'approved', 'rejected', 'paid', 'closed');
CREATE TYPE "case_category" AS ENUM ('surgery', 'medication', 'diagnostics', 'maternal', 'paediatric', 'other');
CREATE TYPE "subscription_status" AS ENUM ('active', 'non_renewing', 'cancelled', 'attention');
CREATE TYPE "billing_interval" AS ENUM ('monthly');
CREATE TYPE "disbursement_status" AS ENUM ('pending', 'paid', 'failed');
CREATE TYPE "ledger_type" AS ENUM ('contribution', 'disbursement', 'fee', 'reversal');
CREATE TYPE "admin_role" AS ENUM ('admin', 'reviewer');

CREATE TABLE "donors" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "name" text, "email" text, "phone" text,
  "created_at" timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE "contributions" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  "donor_id" uuid REFERENCES "donors"("id") ON DELETE SET NULL,
  "amount_kobo" bigint NOT NULL CHECK ("amount_kobo" >= 50000),
  "currency" varchar(3) NOT NULL DEFAULT 'NGN',
  "type" "contribution_type" NOT NULL DEFAULT 'one_off',
  "paystack_reference" text NOT NULL,
  "status" "contribution_status" NOT NULL DEFAULT 'pending',
  "paid_at" timestamptz, "created_at" timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX "contributions_paystack_reference_uq" ON "contributions" ("paystack_reference");
CREATE INDEX "contributions_status_created_idx" ON "contributions" ("status", "created_at");
CREATE INDEX "contributions_donor_idx" ON "contributions" ("donor_id");
CREATE INDEX "donors_email_idx" ON "donors" ("email");
CREATE INDEX "donors_phone_idx" ON "donors" ("phone");

CREATE TABLE "subscriptions" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "donor_id" uuid REFERENCES "donors"("id") ON DELETE SET NULL,
  "paystack_plan_code" text NOT NULL, "paystack_subscription_code" text NOT NULL,
  "amount_kobo" bigint NOT NULL, "interval" "billing_interval" NOT NULL DEFAULT 'monthly',
  "status" "subscription_status" NOT NULL DEFAULT 'active', "created_at" timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX "subscriptions_paystack_code_uq" ON "subscriptions" ("paystack_subscription_code");
CREATE INDEX "subscriptions_donor_idx" ON "subscriptions" ("donor_id");

CREATE TABLE "providers" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "name" text NOT NULL, "type" "provider_type" NOT NULL,
  "state" text NOT NULL, "account_name" text NOT NULL, "account_number" text NOT NULL, "bank_code" text NOT NULL,
  "verified_at" timestamptz, "active" boolean NOT NULL DEFAULT true, "created_at" timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX "providers_active_verified_idx" ON "providers" ("active", "verified_at");
CREATE INDEX "providers_state_idx" ON "providers" ("state");

CREATE TABLE "cases" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "public_ref" text NOT NULL,
  "status" "case_status" NOT NULL DEFAULT 'submitted', "category" "case_category" NOT NULL, "urgency" text NOT NULL,
  "provider_id" uuid REFERENCES "providers"("id") ON DELETE RESTRICT,
  "requested_kobo" bigint NOT NULL CHECK ("requested_kobo" > 0),
  "approved_kobo" bigint CHECK ("approved_kobo" IS NULL OR "approved_kobo" >= 0),
  "decision_note" text, "public_summary" text, "created_at" timestamptz NOT NULL DEFAULT now(),
  "decided_at" timestamptz, "decided_by" uuid
);
CREATE UNIQUE INDEX "cases_public_ref_uq" ON "cases" ("public_ref");
CREATE INDEX "cases_status_created_idx" ON "cases" ("status", "created_at");
CREATE INDEX "cases_provider_idx" ON "cases" ("provider_id");

-- Patient-identifying information is isolated in this table and must never be selected by public queries.
CREATE TABLE "case_private" (
  "case_id" uuid PRIMARY KEY REFERENCES "cases"("id") ON DELETE CASCADE,
  "patient_name" text NOT NULL, "patient_phone" text NOT NULL, "next_of_kin" text,
  "id_document_ref" text, "medical_doc_refs" jsonb NOT NULL DEFAULT '[]'::jsonb,
  "provider_estimate_ref" text
);

CREATE TABLE "disbursements" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  "case_id" uuid NOT NULL REFERENCES "cases"("id") ON DELETE RESTRICT,
  "provider_id" uuid NOT NULL REFERENCES "providers"("id") ON DELETE RESTRICT,
  "amount_kobo" bigint NOT NULL CHECK ("amount_kobo" > 0),
  "transfer_reference" text, "invoice_ref" text,
  "status" "disbursement_status" NOT NULL DEFAULT 'pending',
  "paid_at" timestamptz, "created_at" timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX "disbursements_transfer_reference_uq" ON "disbursements" ("transfer_reference");
CREATE INDEX "disbursements_case_idx" ON "disbursements" ("case_id");
CREATE INDEX "disbursements_status_idx" ON "disbursements" ("status");

CREATE TABLE "ledger_entries" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "entry_ref" text NOT NULL,
  "type" "ledger_type" NOT NULL, "amount_kobo" bigint NOT NULL CHECK ("amount_kobo" <> 0),
  "contribution_id" uuid REFERENCES "contributions"("id") ON DELETE RESTRICT,
  "disbursement_id" uuid REFERENCES "disbursements"("id") ON DELETE RESTRICT,
  "case_public_ref" text, "description" text NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX "ledger_entries_entry_ref_uq" ON "ledger_entries" ("entry_ref");
CREATE UNIQUE INDEX "ledger_entries_contribution_uq" ON "ledger_entries" ("contribution_id");
CREATE UNIQUE INDEX "ledger_entries_disbursement_type_uq" ON "ledger_entries" ("disbursement_id", "type");
CREATE INDEX "ledger_entries_created_idx" ON "ledger_entries" ("created_at", "id");
CREATE INDEX "ledger_entries_type_created_idx" ON "ledger_entries" ("type", "created_at");

-- Append-only enforcement applies even to application code using the table owner role.
CREATE OR REPLACE FUNCTION prevent_ledger_mutation() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'ledger_entries is append-only; add a reversal entry instead';
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER ledger_entries_no_update_delete
BEFORE UPDATE OR DELETE ON "ledger_entries"
FOR EACH ROW EXECUTE FUNCTION prevent_ledger_mutation();

CREATE TABLE "allocation_rules" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "key" text NOT NULL,
  "value" jsonb NOT NULL, "updated_at" timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX "allocation_rules_key_uq" ON "allocation_rules" ("key");

CREATE TABLE "admin_users" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "email" text NOT NULL,
  "password_hash" text NOT NULL, "role" "admin_role" NOT NULL DEFAULT 'reviewer',
  "created_at" timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX "admin_users_email_uq" ON "admin_users" ("email");

CREATE TABLE "audit_log" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  "actor_admin_id" uuid REFERENCES "admin_users"("id") ON DELETE RESTRICT,
  "action" text NOT NULL, "entity" text NOT NULL, "entity_id" text NOT NULL,
  "meta" jsonb NOT NULL DEFAULT '{}'::jsonb, "created_at" timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX "audit_log_entity_idx" ON "audit_log" ("entity", "entity_id");
CREATE INDEX "audit_log_created_idx" ON "audit_log" ("created_at");

CREATE TABLE "webhook_events" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "provider" varchar(32) NOT NULL DEFAULT 'paystack',
  "event_id" text NOT NULL, "reference" text, "payload" jsonb NOT NULL,
  "processed_at" timestamptz, "created_at" timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX "webhook_events_provider_event_uq" ON "webhook_events" ("provider", "event_id");
CREATE INDEX "webhook_events_reference_idx" ON "webhook_events" ("reference");
CREATE INDEX "webhook_events_processed_idx" ON "webhook_events" ("processed_at");

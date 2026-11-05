CREATE TYPE "contribution_type" AS ENUM ('one_off', 'recurring');
--> statement-breakpoint
CREATE TYPE "contribution_status" AS ENUM ('pending', 'success', 'failed');
--> statement-breakpoint
CREATE TYPE "provider_type" AS ENUM ('hospital', 'pharmacy', 'lab', 'other');
--> statement-breakpoint
CREATE TYPE "case_status" AS ENUM ('submitted', 'in_review', 'approved', 'rejected', 'paid', 'closed');
--> statement-breakpoint
CREATE TYPE "case_category" AS ENUM ('surgery', 'medication', 'diagnostics', 'maternal', 'paediatric', 'other');
--> statement-breakpoint
CREATE TYPE "subscription_status" AS ENUM ('active', 'non_renewing', 'cancelled', 'attention');
--> statement-breakpoint
CREATE TYPE "billing_interval" AS ENUM ('monthly');
--> statement-breakpoint
CREATE TYPE "disbursement_status" AS ENUM ('pending', 'paid', 'failed');
--> statement-breakpoint
CREATE TYPE "ledger_type" AS ENUM ('contribution', 'disbursement', 'fee', 'reversal');
--> statement-breakpoint
CREATE TYPE "admin_role" AS ENUM ('admin', 'reviewer');
--> statement-breakpoint
CREATE TABLE "donors" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "name" text, "email" text, "phone" text,
  "created_at" timestamptz NOT NULL DEFAULT now()
);
--> statement-breakpoint
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
--> statement-breakpoint
CREATE UNIQUE INDEX "contributions_paystack_reference_uq" ON "contributions" ("paystack_reference");
--> statement-breakpoint
CREATE INDEX "contributions_status_created_idx" ON "contributions" ("status", "created_at");
--> statement-breakpoint
CREATE INDEX "contributions_donor_idx" ON "contributions" ("donor_id");
--> statement-breakpoint
CREATE INDEX "donors_email_idx" ON "donors" ("email");
--> statement-breakpoint
CREATE INDEX "donors_phone_idx" ON "donors" ("phone");
--> statement-breakpoint
CREATE TABLE "subscriptions" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "donor_id" uuid REFERENCES "donors"("id") ON DELETE SET NULL,
  "paystack_plan_code" text NOT NULL, "paystack_subscription_code" text NOT NULL,
  "amount_kobo" bigint NOT NULL, "interval" "billing_interval" NOT NULL DEFAULT 'monthly',
  "status" "subscription_status" NOT NULL DEFAULT 'active', "created_at" timestamptz NOT NULL DEFAULT now()
);
--> statement-breakpoint
CREATE UNIQUE INDEX "subscriptions_paystack_code_uq" ON "subscriptions" ("paystack_subscription_code");
--> statement-breakpoint
CREATE INDEX "subscriptions_donor_idx" ON "subscriptions" ("donor_id");
--> statement-breakpoint
CREATE TABLE "providers" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "name" text NOT NULL, "type" "provider_type" NOT NULL,
  "state" text NOT NULL, "account_name" text NOT NULL, "account_number" text NOT NULL, "bank_code" text NOT NULL,
  "verified_at" timestamptz, "active" boolean NOT NULL DEFAULT true, "created_at" timestamptz NOT NULL DEFAULT now()
);
--> statement-breakpoint
CREATE INDEX "providers_active_verified_idx" ON "providers" ("active", "verified_at");
--> statement-breakpoint
CREATE INDEX "providers_state_idx" ON "providers" ("state");
--> statement-breakpoint
CREATE TABLE "cases" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "public_ref" text NOT NULL,
  "status" "case_status" NOT NULL DEFAULT 'submitted', "category" "case_category" NOT NULL, "urgency" text NOT NULL,
  "provider_id" uuid REFERENCES "providers"("id") ON DELETE RESTRICT,
  "requested_kobo" bigint NOT NULL CHECK ("requested_kobo" > 0),
  "approved_kobo" bigint CHECK ("approved_kobo" IS NULL OR "approved_kobo" >= 0),
  "decision_note" text, "public_summary" text, "created_at" timestamptz NOT NULL DEFAULT now(),
  "decided_at" timestamptz, "decided_by" uuid
);
--> statement-breakpoint
CREATE UNIQUE INDEX "cases_public_ref_uq" ON "cases" ("public_ref");
--> statement-breakpoint
CREATE INDEX "cases_status_created_idx" ON "cases" ("status", "created_at");
--> statement-breakpoint
CREATE INDEX "cases_provider_idx" ON "cases" ("provider_id");
--> statement-breakpoint
-- Patient-identifying information is isolated in this table and must never be selected by public queries.
CREATE TABLE "case_private" (
  "case_id" uuid PRIMARY KEY REFERENCES "cases"("id") ON DELETE CASCADE,
  "patient_name" text NOT NULL, "patient_phone" text NOT NULL, "next_of_kin" text,
  "id_document_ref" text, "medical_doc_refs" jsonb NOT NULL DEFAULT '[]'::jsonb,
  "provider_estimate_ref" text
);
--> statement-breakpoint
CREATE TABLE "disbursements" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  "case_id" uuid NOT NULL REFERENCES "cases"("id") ON DELETE RESTRICT,
  "provider_id" uuid NOT NULL REFERENCES "providers"("id") ON DELETE RESTRICT,
  "amount_kobo" bigint NOT NULL CHECK ("amount_kobo" > 0),
  "transfer_reference" text, "invoice_ref" text,
  "status" "disbursement_status" NOT NULL DEFAULT 'pending',
  "paid_at" timestamptz, "created_at" timestamptz NOT NULL DEFAULT now()
);
--> statement-breakpoint
CREATE UNIQUE INDEX "disbursements_transfer_reference_uq" ON "disbursements" ("transfer_reference");
--> statement-breakpoint
CREATE INDEX "disbursements_case_idx" ON "disbursements" ("case_id");
--> statement-breakpoint
CREATE INDEX "disbursements_status_idx" ON "disbursements" ("status");
--> statement-breakpoint
CREATE TABLE "ledger_entries" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "entry_ref" text NOT NULL,
  "type" "ledger_type" NOT NULL, "amount_kobo" bigint NOT NULL CHECK ("amount_kobo" <> 0),
  "contribution_id" uuid REFERENCES "contributions"("id") ON DELETE RESTRICT,
  "disbursement_id" uuid REFERENCES "disbursements"("id") ON DELETE RESTRICT,
  "case_public_ref" text, "description" text NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now()
);
--> statement-breakpoint
CREATE UNIQUE INDEX "ledger_entries_entry_ref_uq" ON "ledger_entries" ("entry_ref");
--> statement-breakpoint
CREATE UNIQUE INDEX "ledger_entries_contribution_uq" ON "ledger_entries" ("contribution_id");
--> statement-breakpoint
CREATE UNIQUE INDEX "ledger_entries_disbursement_type_uq" ON "ledger_entries" ("disbursement_id", "type");
--> statement-breakpoint
CREATE INDEX "ledger_entries_created_idx" ON "ledger_entries" ("created_at", "id");
--> statement-breakpoint
CREATE INDEX "ledger_entries_type_created_idx" ON "ledger_entries" ("type", "created_at");
--> statement-breakpoint
-- Append-only enforcement applies even to application code using the table owner role.
CREATE OR REPLACE FUNCTION prevent_ledger_mutation() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'ledger_entries is append-only; add a reversal entry instead';
END;
$$ LANGUAGE plpgsql;
--> statement-breakpoint
CREATE TRIGGER ledger_entries_no_update_delete
BEFORE UPDATE OR DELETE ON "ledger_entries"
FOR EACH ROW EXECUTE FUNCTION prevent_ledger_mutation();
--> statement-breakpoint
CREATE TABLE "allocation_rules" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "key" text NOT NULL,
  "value" jsonb NOT NULL, "updated_at" timestamptz NOT NULL DEFAULT now()
);
--> statement-breakpoint
CREATE UNIQUE INDEX "allocation_rules_key_uq" ON "allocation_rules" ("key");
--> statement-breakpoint
CREATE TABLE "admin_users" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "email" text NOT NULL,
  "password_hash" text NOT NULL, "role" "admin_role" NOT NULL DEFAULT 'reviewer',
  "created_at" timestamptz NOT NULL DEFAULT now()
);
--> statement-breakpoint
CREATE UNIQUE INDEX "admin_users_email_uq" ON "admin_users" ("email");
--> statement-breakpoint
ALTER TABLE "cases" ADD CONSTRAINT "cases_decided_by_admin_users_id_fk" FOREIGN KEY ("decided_by") REFERENCES "admin_users"("id") ON DELETE SET NULL;
--> statement-breakpoint
CREATE TABLE "audit_log" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  "actor_admin_id" uuid REFERENCES "admin_users"("id") ON DELETE RESTRICT,
  "action" text NOT NULL, "entity" text NOT NULL, "entity_id" text NOT NULL,
  "meta" jsonb NOT NULL DEFAULT '{}'::jsonb, "created_at" timestamptz NOT NULL DEFAULT now()
);
--> statement-breakpoint
CREATE INDEX "audit_log_entity_idx" ON "audit_log" ("entity", "entity_id");
--> statement-breakpoint
CREATE INDEX "audit_log_created_idx" ON "audit_log" ("created_at");
--> statement-breakpoint
CREATE TABLE "webhook_events" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(), "provider" varchar(32) NOT NULL DEFAULT 'paystack',
  "event_id" text NOT NULL, "reference" text, "payload" jsonb NOT NULL,
  "processed_at" timestamptz, "created_at" timestamptz NOT NULL DEFAULT now()
);
--> statement-breakpoint
CREATE UNIQUE INDEX "webhook_events_provider_event_uq" ON "webhook_events" ("provider", "event_id");
--> statement-breakpoint
CREATE INDEX "webhook_events_reference_idx" ON "webhook_events" ("reference");
--> statement-breakpoint
CREATE INDEX "webhook_events_processed_idx" ON "webhook_events" ("processed_at");

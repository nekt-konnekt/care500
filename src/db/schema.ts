import {
  pgTable, pgEnum, uuid, text, varchar, bigint, boolean, timestamp, jsonb,
  integer, index, uniqueIndex, check
} from "drizzle-orm/pg-core";
import { sql } from "drizzle-orm";

export const contributionTypeEnum = pgEnum("contribution_type", ["one_off", "recurring"]);
export const contributionStatusEnum = pgEnum("contribution_status", ["pending", "success", "failed"]);
export const providerTypeEnum = pgEnum("provider_type", ["hospital", "pharmacy", "lab", "other"]);
export const caseStatusEnum = pgEnum("case_status", ["submitted", "in_review", "approved", "rejected", "paid", "closed"]);
export const caseCategoryEnum = pgEnum("case_category", ["surgery", "medication", "diagnostics", "maternal", "paediatric", "other"]);
export const subscriptionStatusEnum = pgEnum("subscription_status", ["active", "non_renewing", "cancelled", "attention"]);
export const billingIntervalEnum = pgEnum("billing_interval", ["monthly"]);
export const disbursementStatusEnum = pgEnum("disbursement_status", ["pending", "paid", "failed"]);
export const ledgerTypeEnum = pgEnum("ledger_type", ["contribution", "disbursement", "fee", "reversal"]);
export const adminRoleEnum = pgEnum("admin_role", ["admin", "reviewer"]);

const createdAt = () => timestamp("created_at", { withTimezone: true }).notNull().defaultNow();

export const donors = pgTable("donors", {
  id: uuid("id").defaultRandom().primaryKey(),
  name: text("name"),
  email: text("email"),
  phone: text("phone"),
  createdAt: createdAt()
}, t => [index("donors_email_idx").on(t.email), index("donors_phone_idx").on(t.phone)]);

export const contributions = pgTable("contributions", {
  id: uuid("id").defaultRandom().primaryKey(),
  donorId: uuid("donor_id").references(() => donors.id, { onDelete: "set null" }),
  amountKobo: bigint("amount_kobo", { mode: "bigint" }).notNull(),
  currency: varchar("currency", { length: 3 }).notNull().default("NGN"),
  type: contributionTypeEnum("type").notNull().default("one_off"),
  paystackReference: text("paystack_reference").notNull(),
  status: contributionStatusEnum("status").notNull().default("pending"),
  paidAt: timestamp("paid_at", { withTimezone: true }),
  createdAt: createdAt()
}, t => [
  uniqueIndex("contributions_paystack_reference_uq").on(t.paystackReference),
  index("contributions_status_created_idx").on(t.status, t.createdAt),
  index("contributions_donor_idx").on(t.donorId),
  check("contributions_amount_positive", sql`${t.amountKobo} >= 50000`)
]);

export const subscriptions = pgTable("subscriptions", {
  id: uuid("id").defaultRandom().primaryKey(),
  donorId: uuid("donor_id").references(() => donors.id, { onDelete: "set null" }),
  paystackPlanCode: text("paystack_plan_code").notNull(),
  paystackSubscriptionCode: text("paystack_subscription_code").notNull(),
  amountKobo: bigint("amount_kobo", { mode: "bigint" }).notNull(),
  interval: billingIntervalEnum("interval").notNull().default("monthly"),
  status: subscriptionStatusEnum("status").notNull().default("active"),
  createdAt: createdAt()
}, t => [
  uniqueIndex("subscriptions_paystack_code_uq").on(t.paystackSubscriptionCode),
  index("subscriptions_donor_idx").on(t.donorId)
]);

export const providers = pgTable("providers", {
  id: uuid("id").defaultRandom().primaryKey(),
  name: text("name").notNull(),
  type: providerTypeEnum("type").notNull(),
  state: text("state").notNull(),
  accountName: text("account_name").notNull(),
  accountNumber: text("account_number").notNull(),
  bankCode: text("bank_code").notNull(),
  verifiedAt: timestamp("verified_at", { withTimezone: true }),
  active: boolean("active").notNull().default(true),
  createdAt: createdAt()
}, t => [index("providers_active_verified_idx").on(t.active, t.verifiedAt), index("providers_state_idx").on(t.state)]);

export const cases = pgTable("cases", {
  id: uuid("id").defaultRandom().primaryKey(),
  publicRef: text("public_ref").notNull(),
  status: caseStatusEnum("status").notNull().default("submitted"),
  category: caseCategoryEnum("category").notNull(),
  urgency: text("urgency").notNull(),
  providerId: uuid("provider_id").references(() => providers.id, { onDelete: "restrict" }),
  requestedKobo: bigint("requested_kobo", { mode: "bigint" }).notNull(),
  approvedKobo: bigint("approved_kobo", { mode: "bigint" }),
  decisionNote: text("decision_note"),
  publicSummary: text("public_summary"),
  createdAt: createdAt(),
  decidedAt: timestamp("decided_at", { withTimezone: true }),
  decidedBy: uuid("decided_by"),
}, t => [
  uniqueIndex("cases_public_ref_uq").on(t.publicRef),
  index("cases_status_created_idx").on(t.status, t.createdAt),
  index("cases_provider_idx").on(t.providerId),
  check("cases_requested_positive", sql`${t.requestedKobo} > 0`),
  check("cases_approved_nonnegative", sql`${t.approvedKobo} IS NULL OR ${t.approvedKobo} >= 0`)
]);

export const casePrivate = pgTable("case_private", {
  caseId: uuid("case_id").primaryKey().references(() => cases.id, { onDelete: "cascade" }),
  patientName: text("patient_name").notNull(),
  patientPhone: text("patient_phone").notNull(),
  nextOfKin: text("next_of_kin"),
  idDocumentRef: text("id_document_ref"),
  medicalDocRefs: jsonb("medical_doc_refs").$type<string[]>().notNull().default(sql`'[]'::jsonb`),
  providerEstimateRef: text("provider_estimate_ref")
});

export const disbursements = pgTable("disbursements", {
  id: uuid("id").defaultRandom().primaryKey(),
  caseId: uuid("case_id").notNull().references(() => cases.id, { onDelete: "restrict" }),
  providerId: uuid("provider_id").notNull().references(() => providers.id, { onDelete: "restrict" }),
  amountKobo: bigint("amount_kobo", { mode: "bigint" }).notNull(),
  transferReference: text("transfer_reference"),
  invoiceRef: text("invoice_ref"),
  status: disbursementStatusEnum("status").notNull().default("pending"),
  paidAt: timestamp("paid_at", { withTimezone: true }),
  createdAt: createdAt()
}, t => [
  uniqueIndex("disbursements_transfer_reference_uq").on(t.transferReference),
  index("disbursements_case_idx").on(t.caseId),
  index("disbursements_status_idx").on(t.status),
  check("disbursements_amount_positive", sql`${t.amountKobo} > 0`)
]);

export const ledgerEntries = pgTable("ledger_entries", {
  id: uuid("id").defaultRandom().primaryKey(),
  entryRef: text("entry_ref").notNull(),
  type: ledgerTypeEnum("type").notNull(),
  amountKobo: bigint("amount_kobo", { mode: "bigint" }).notNull(),
  contributionId: uuid("contribution_id").references(() => contributions.id, { onDelete: "restrict" }),
  disbursementId: uuid("disbursement_id").references(() => disbursements.id, { onDelete: "restrict" }),
  casePublicRef: text("case_public_ref"),
  description: text("description").notNull(),
  createdAt: createdAt()
}, t => [
  uniqueIndex("ledger_entries_entry_ref_uq").on(t.entryRef),
  uniqueIndex("ledger_entries_contribution_uq").on(t.contributionId),
  uniqueIndex("ledger_entries_disbursement_type_uq").on(t.disbursementId, t.type),
  index("ledger_entries_created_idx").on(t.createdAt, t.id),
  index("ledger_entries_type_created_idx").on(t.type, t.createdAt),
  check("ledger_entries_nonzero_amount", sql`${t.amountKobo} <> 0`)
]);

export const allocationRules = pgTable("allocation_rules", {
  id: uuid("id").defaultRandom().primaryKey(),
  key: text("key").notNull(),
  value: jsonb("value").notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow()
}, t => [uniqueIndex("allocation_rules_key_uq").on(t.key)]);

export const adminUsers = pgTable("admin_users", {
  id: uuid("id").defaultRandom().primaryKey(),
  email: text("email").notNull(),
  passwordHash: text("password_hash").notNull(),
  role: adminRoleEnum("role").notNull().default("reviewer"),
  createdAt: createdAt()
}, t => [uniqueIndex("admin_users_email_uq").on(t.email)]);

export const auditLog = pgTable("audit_log", {
  id: uuid("id").defaultRandom().primaryKey(),
  actorAdminId: uuid("actor_admin_id").references(() => adminUsers.id, { onDelete: "restrict" }),
  action: text("action").notNull(),
  entity: text("entity").notNull(),
  entityId: text("entity_id").notNull(),
  meta: jsonb("meta").notNull().default(sql`'{}'::jsonb`),
  createdAt: createdAt()
}, t => [index("audit_log_entity_idx").on(t.entity, t.entityId), index("audit_log_created_idx").on(t.createdAt)]);

export const webhookEvents = pgTable("webhook_events", {
  id: uuid("id").defaultRandom().primaryKey(),
  provider: varchar("provider", { length: 32 }).notNull().default("paystack"),
  eventId: text("event_id").notNull(),
  reference: text("reference"),
  payload: jsonb("payload").notNull(),
  processedAt: timestamp("processed_at", { withTimezone: true }),
  createdAt: createdAt()
}, t => [
  uniqueIndex("webhook_events_provider_event_uq").on(t.provider, t.eventId),
  index("webhook_events_reference_idx").on(t.reference),
  index("webhook_events_processed_idx").on(t.processedAt)
]);

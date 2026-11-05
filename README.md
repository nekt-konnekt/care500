# Care500

Care500 is a Nigeria-focused pooled medical emergency fund. The frontend remains a static HTML/CSS/vanilla-JavaScript page served by Vercel; backend endpoints are implemented as Vercel TypeScript functions under `api/`.

## Stack
- Static frontend: HTML, CSS, vanilla JavaScript
- Backend: Vercel serverless TypeScript functions
- Database: Neon Postgres via `@neondatabase/serverless` HTTP driver and Drizzle ORM
- Validation: Zod
- Payments: Paystack (server-side initialization and signed webhooks)

## Local setup
1. Install Node.js 20+ and npm.
2. Copy `.env.example` to `.env` and fill the required values.
3. Run `npm install`.
4. Run `npm run db:migrate` to apply committed Drizzle migrations.
5. Set `ADMIN_EMAIL` and a strong `ADMIN_PASSWORD`, then run `npm run db:seed` to create the first admin and ensure default allocation rules.
6. Run `npm run dev` to start Vercel's local development server.

## Environment variables
See `.env.example`. Never commit `.env`, database credentials, Paystack keys, or admin secrets. All amounts are represented as integer kobo in storage and business logic.

## Database
- Drizzle schema: `src/db/schema.ts`
- Drizzle migrations: `drizzle/`
- Drizzle config: `drizzle.config.ts`
- Seed script: `scripts/seed.ts`

The ledger is append-only at the database level. Corrections must be represented by reversal entries. Patient-identifying fields are isolated in `case_private`; public handlers must never select or serialize that table.

## Payments and webhook testing
Use Paystack test keys first. Configure the Paystack webhook URL as `https://YOUR_APP/api/webhooks/paystack`. For local testing, run `npm run dev`, expose the local Vercel server with a secure tunnel (for example, Cloudflare Tunnel or ngrok), and configure the resulting HTTPS URL in the Paystack test dashboard. Verify a successful test charge through its webhook and replay the same event to confirm idempotency.

## Go-live checklist
- Complete test-mode payment, webhook replay, ledger and stats verification.
- Configure production-only environment variables in Vercel; never expose secret keys to browser code.
- Verify Paystack webhook signature handling against raw request bytes.
- Configure private document storage, access controls, retention and backups before accepting case documents.
- Create and test admin credentials securely; do not use seed credentials in production.
- Verify providers and payout bank details before approving cases.
- Reconcile ledger balances and provider transfers.
- Complete legal, financial, privacy and regulatory review for operating a pooled medical fund in Nigeria.

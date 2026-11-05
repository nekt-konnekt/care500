import "dotenv/config";
import { neon } from "@neondatabase/serverless";
import { hash } from "argon2";
import { z } from "zod";

const envSchema = z.object({
  DATABASE_URL: z.string().url(),
  ADMIN_EMAIL: z.string().email(),
  ADMIN_PASSWORD: z.string().min(14)
});
const env = envSchema.parse(process.env);
const sql = neon(env.DATABASE_URL);

const existing = await sql`SELECT id FROM admin_users WHERE lower(email) = lower(${env.ADMIN_EMAIL}) LIMIT 1`;
if (existing.length === 0) {
  const passwordHash = await hash(env.ADMIN_PASSWORD);
  await sql`INSERT INTO admin_users (email, password_hash, role) VALUES (${env.ADMIN_EMAIL.toLowerCase()}, ${passwordHash}, 'admin')`;
}

const defaults: ReadonlyArray<readonly [string, unknown]> = [
  ["max_per_case_kobo", 50000000],
  ["ops_fee_bps", 0],
  ["min_reserve_kobo", 0]
];
for (const [key, value] of defaults) {
  await sql`INSERT INTO allocation_rules (key, value) VALUES (${key}, ${JSON.stringify(value)}::jsonb) ON CONFLICT (key) DO NOTHING`;
}
console.info("Care500 seed complete: default allocation rules ensured; admin account created if absent.");

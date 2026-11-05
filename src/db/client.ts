import { neon } from "@neondatabase/serverless";
import { drizzle } from "drizzle-orm/neon-http";
import * as schema from "./schema.js";

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) {
  throw new Error("DATABASE_URL is required by the Care500 API.");
}

const client = neon(databaseUrl);
export const db = drizzle({ client, schema });
export type Database = typeof db;

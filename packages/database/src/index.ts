import pg from "pg";
export type { PoolClient } from "pg";
/** PostgreSQL int8 remains a decimal string; callers use BigInt for arithmetic. */
export const pool = new pg.Pool({
  connectionString:
    process.env.DATABASE_URL ??
    "postgres://unconfigured:unconfigured@127.0.0.1:1/unconfigured",
  max: 10,
  connectionTimeoutMillis: 3000,
  idleTimeoutMillis: 30000,
  options: "-c timezone=UTC -c statement_timeout=10000",
});
pool.on("error", () => {
  console.error("Database pool connection error");
});
export async function transaction<T>(
  work: (client: pg.PoolClient) => Promise<T>,
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const value = await work(client);
    await client.query("COMMIT");
    return value;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}
export async function ready() {
  await pool.query("SELECT 1");
}

export { migrations } from "./migrations.js";

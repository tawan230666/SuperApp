import bcrypt from "bcryptjs";
import { randomUUID } from "node:crypto";
import { authCredentialsSchema } from "@tipkhun/contracts";
import { pool, ready, transaction } from "./index.js";
import { migrations } from "./migrations.js";
try {
  if (!process.env.DATABASE_URL) throw new Error("DATABASE_URL required");
  await ready();
  const command = process.argv[2];
  if (command === "seed") {
    if (!["development", "test"].includes(process.env.NODE_ENV ?? ""))
      throw new Error("Seed requires NODE_ENV=development or test");
    const parsed = authCredentialsSchema.safeParse({
      email: process.env.SEED_EMAIL,
      password: process.env.SEED_PASSWORD,
    });
    if (!parsed.success)
      throw new Error(
        "Seed requires valid SEED_EMAIL and SEED_PASSWORD (12-72 UTF-8 bytes)",
      );
    const passwordHash = await bcrypt.hash(parsed.data.password, 12);
    await transaction(async (c) => {
      await c.query("SELECT pg_advisory_xact_lock(74219302)");
      const existing = await c.query("SELECT id FROM users WHERE email=$1", [
        parsed.data.email,
      ]);
      if (existing.rowCount) return;
      const user = await c.query(
        "INSERT INTO users(email,password_hash) VALUES($1,$2) RETURNING id",
        [parsed.data.email, passwordHash],
      );
      const id = user.rows[0].id;
      await c.query(
        "INSERT INTO accounts(user_id,environment) VALUES($1,'simulation')",
        [id],
      );
      await c.query(
        "INSERT INTO audit_logs(user_id,action,entity,entity_id,request_id,source) VALUES($1,'USER_REGISTERED','User',$1,$2,'development-seed')",
        [id, randomUUID()],
      );
    });
    console.log(
      "Development/test user seed completed; existing credentials and balances preserved.",
    );
  } else if (command === "migrate" || command === "status")
    console.table(await migrations(command === "migrate"));
  else throw new Error("Expected migrate, status or seed");
} catch (error) {
  console.error(
    error instanceof Error &&
      /^(DATABASE_URL|Seed requires|Expected|Migration checksum)/.test(
        error.message,
      )
      ? error.message
      : "Database command failed; check database availability and configuration",
  );
  process.exitCode = 1;
} finally {
  await pool.end();
}

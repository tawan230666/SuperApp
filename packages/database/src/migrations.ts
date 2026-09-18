import { readFile, readdir } from "node:fs/promises";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";
import { transaction } from "./index.js";
const directory = fileURLToPath(
  new URL("../../../database/migrations/", import.meta.url),
);
export async function migrations(apply: boolean) {
  return transaction(async (client) => {
    await client.query("SELECT pg_advisory_xact_lock(74219301)");
    await client.query(
      "CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, checksum text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now())",
    );
    const result: { name: string; status: string }[] = [];
    for (const name of (await readdir(directory))
      .filter((n) => n.endsWith(".sql"))
      .sort()) {
      const sql = await readFile(`${directory}/${name}`, "utf8");
      const checksum = createHash("sha256").update(sql).digest("hex");
      const existing = await client.query(
        "SELECT checksum FROM schema_migrations WHERE name=$1",
        [name],
      );
      if (existing.rowCount && existing.rows[0].checksum !== checksum)
        throw new Error(`Migration checksum mismatch: ${name}`);
      if (!existing.rowCount && apply) {
        await client.query(sql);
        await client.query(
          "INSERT INTO schema_migrations(name,checksum) VALUES($1,$2)",
          [name, checksum],
        );
      }
      result.push({
        name,
        status: existing.rowCount ? "applied" : apply ? "applied" : "pending",
      });
    }
    return result;
  });
}

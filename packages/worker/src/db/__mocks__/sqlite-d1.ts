import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

// Loaded through require: Vite does not know the node:sqlite builtin and fails to resolve an import.
const { DatabaseSync } = createRequire(import.meta.url)("node:sqlite") as typeof import("node:sqlite");

/**
 * Enough of D1's API over Node's built-in SQLite to run the real SQL and migrations in tests.
 * Migrations are applied from /migrations, the same files `wrangler d1 migrations apply` uses.
 */
export function createSqliteD1(): D1Database {
  const db = new DatabaseSync(":memory:");
  db.exec("PRAGMA foreign_keys = ON");
  const migration = readFileSync(fileURLToPath(new URL("../../../migrations/0001_accounts.sql", import.meta.url)), "utf8");
  db.exec(migration);

  class Stmt {
    constructor(readonly sql: string, readonly args: unknown[] = []) {}
    bind(...args: unknown[]) { return new Stmt(this.sql, args); }
    private params() {
      // D1 uses ?1, ?2…; node:sqlite binds those positionally by number.
      const named: Record<string, string | number | null> = {};
      this.args.forEach((v, i) => { named[`${i + 1}`] = v === undefined ? null : (v as string | number | null); });
      return named;
    }
    async first<T>() { return (this.prepared().get(this.params()) as T) ?? null; }
    async all<T>() { return { results: this.prepared().all(this.params()) as T[], success: true, meta: {} }; }
    async run() {
      const r = this.prepared().run(this.params());
      return { success: true, results: [], meta: { changes: Number(r.changes) } };
    }
    private prepared() {
      // node:sqlite names numbered parameters "?1" as "1"; rewrite to a named form it accepts.
      return db.prepare(this.sql.replace(/\?(\d+)/g, ":$1"));
    }
  }

  return {
    prepare: (sql: string) => new Stmt(sql),
    batch: async (stmts: Stmt[]) => {
      db.exec("BEGIN");
      try {
        const out = [];
        for (const s of stmts) out.push(/^\s*select/i.test(s.sql) ? await s.all() : await s.run());
        db.exec("COMMIT");
        return out;
      } catch (e) {
        db.exec("ROLLBACK");
        throw e;
      }
    },
    exec: async (sql: string) => { db.exec(sql); return { count: 1, duration: 0 }; },
  } as unknown as D1Database;
}

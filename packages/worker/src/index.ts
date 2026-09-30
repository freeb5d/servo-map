import { Hono } from "hono";
import { cors } from "hono/cors";
import { stationsRoute } from "./routes/stations";
import { metadataRoute } from "./routes/metadata";
import { brandsRoute } from "./routes/brands";
import { trendsRoute } from "./routes/trends";
import { vehiclesRoute } from "./routes/vehicles";
import { dispatchIngest } from "./cron/dispatch";
import type { Env } from "./env";

const app = new Hono<{ Bindings: Env }>();

app.use("*", cors());

// Health check
app.get("/", (c) => c.json({ name: "servo-map-api", version: "1.0.0" }));

// API routes
const api = app.basePath("/api/v1");
api.route("/stations", stationsRoute);
api.route("/metadata", metadataRoute);
api.route("/brands", brandsRoute);
api.route("/trends", trendsRoute);
api.route("/vehicles", vehiclesRoute);

export default {
  fetch: app.fetch,
  // Cloudflare Cron Trigger（可靠调度）→ 触发 GitHub Actions ingest（在 GH runner 上执行）。
  // GH 自己的 schedule 仍保留作 fallback；concurrency 护栏防止重复运行。
  async scheduled(
    _controller: ScheduledController,
    env: Env,
    ctx: ExecutionContext,
  ): Promise<void> {
    ctx.waitUntil(dispatchIngest(env));
  },
};

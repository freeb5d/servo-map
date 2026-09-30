import { Hono } from "hono";
import { cors } from "hono/cors";
import { stationsRoute } from "./routes/stations";
import { metadataRoute } from "./routes/metadata";
import { brandsRoute } from "./routes/brands";
import { trendsRoute } from "./routes/trends";
import { vehiclesRoute } from "./routes/vehicles";
import { authRoute } from "./routes/auth";
import { meRoute } from "./routes/me";
import { dispatchIngest } from "./cron/dispatch";
import type { Env } from "./env";

const app = new Hono<{ Bindings: Env }>();

// Public read routes are open to any origin. Account routes carry a bearer token and answer only
// the ServoMap sites (the iOS app sends no Origin, so CORS does not apply to it).
const ACCOUNT_ORIGINS = ["https://www.servo-map.com", "https://servo-map.com", "http://localhost:3000"];
app.use("/api/v1/auth/*", cors({ origin: ACCOUNT_ORIGINS, allowMethods: ["POST"] }));
app.use("/api/v1/me/*", cors({ origin: ACCOUNT_ORIGINS, allowMethods: ["GET", "PUT", "DELETE"], allowHeaders: ["Authorization", "Content-Type"] }));
app.use("/api/v1/me", cors({ origin: ACCOUNT_ORIGINS, allowMethods: ["GET", "DELETE"], allowHeaders: ["Authorization", "Content-Type"] }));
app.use("*", async (c, next) => {
  if (c.req.path.startsWith("/api/v1/auth") || c.req.path.startsWith("/api/v1/me")) return next();
  return cors()(c, next);
});

// Health check
app.get("/", (c) => c.json({ name: "servo-map-api", version: "1.0.0" }));

// API routes
const api = app.basePath("/api/v1");
api.route("/stations", stationsRoute);
api.route("/metadata", metadataRoute);
api.route("/brands", brandsRoute);
api.route("/trends", trendsRoute);
api.route("/vehicles", vehiclesRoute);
api.route("/auth", authRoute);
api.route("/me", meRoute);

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

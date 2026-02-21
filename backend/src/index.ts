import { Hono } from "hono";
import { cors } from "hono/cors";
import type { Bindings } from "./types";
import { plaidRoutes } from "./routes/plaid";
import { openaiRoutes } from "./routes/openai";

const app = new Hono<{ Bindings: Bindings }>();

// CORS for iOS app
app.use("/*", cors({ origin: "*" }));

// Auth middleware: validate device token on all /api routes
app.use("/api/*", async (c, next) => {
  const authHeader = c.req.header("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return c.json({ error: "Unauthorized" }, 401);
  }

  const token = authHeader.replace("Bearer ", "");
  if (!token || token.length < 10) {
    return c.json({ error: "Invalid token" }, 401);
  }

  // Store device token in context for route handlers
  c.set("deviceToken" as never, token as never);
  await next();
});

// Health check
app.get("/", (c) => c.json({ status: "ok", service: "spender-api" }));

// Mount routes
app.route("/api/plaid", plaidRoutes);
app.route("/api/openai", openaiRoutes);

export default app;

import type { Context, Next } from "hono";
import type { Bindings } from "../types";

/**
 * Validates the device token from the Authorization header.
 * In production, this could verify an HMAC signature or
 * check against a token registry.
 */
export async function authMiddleware(
  c: Context<{ Bindings: Bindings }>,
  next: Next
) {
  const authHeader = c.req.header("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return c.json({ error: "Unauthorized" }, 401);
  }

  const token = authHeader.replace("Bearer ", "");
  if (!token || token.length < 10) {
    return c.json({ error: "Invalid token" }, 401);
  }

  await next();
}

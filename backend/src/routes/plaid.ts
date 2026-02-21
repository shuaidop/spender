import { Hono } from "hono";
import {
  Configuration,
  PlaidApi,
  PlaidEnvironments,
  Products,
  CountryCode,
} from "plaid";
import type { Bindings } from "../types";

export const plaidRoutes = new Hono<{ Bindings: Bindings }>();

function createPlaidClient(env: Bindings): PlaidApi {
  const config = new Configuration({
    basePath:
      PlaidEnvironments[env.PLAID_ENV as keyof typeof PlaidEnvironments],
    baseOptions: {
      headers: {
        "PLAID-CLIENT-ID": env.PLAID_CLIENT_ID,
        "PLAID-SECRET": env.PLAID_SECRET,
      },
    },
  });
  return new PlaidApi(config);
}

// Create a Link token for the iOS SDK
plaidRoutes.post("/create-link-token", async (c) => {
  const { deviceToken } = await c.req.json<{ deviceToken: string }>();
  const client = createPlaidClient(c.env);

  const response = await client.linkTokenCreate({
    user: { client_user_id: deviceToken },
    client_name: "Spender",
    products: [Products.Transactions],
    country_codes: [CountryCode.Us],
    language: "en",
  });

  return c.json({ link_token: response.data.link_token });
});

// Exchange public token for access token
plaidRoutes.post("/exchange-token", async (c) => {
  const { publicToken, deviceToken } = await c.req.json<{
    publicToken: string;
    deviceToken: string;
  }>();
  const client = createPlaidClient(c.env);

  const exchangeResponse = await client.itemPublicTokenExchange({
    public_token: publicToken,
  });

  const accessToken = exchangeResponse.data.access_token;
  const itemId = exchangeResponse.data.item_id;

  // Store access token in Workers KV
  await c.env.ACCESS_TOKENS.put(`${deviceToken}:${itemId}`, accessToken, {
    expirationTtl: 365 * 24 * 60 * 60,
  });

  // Fetch account details
  const accountsResponse = await client.accountsGet({
    access_token: accessToken,
  });

  return c.json({
    item_id: itemId,
    accounts: accountsResponse.data.accounts.map((a) => ({
      account_id: a.account_id,
      name: a.name,
      official_name: a.official_name,
      type: a.type,
      subtype: a.subtype,
      mask: a.mask,
      balances: {
        available: a.balances.available,
        current: a.balances.current,
        iso_currency_code: a.balances.iso_currency_code,
      },
    })),
  });
});

// Sync transactions using cursor-based pagination
plaidRoutes.post("/sync-transactions", async (c) => {
  const { deviceToken, itemId, cursor } = await c.req.json<{
    deviceToken: string;
    itemId: string;
    cursor?: string;
  }>();
  const client = createPlaidClient(c.env);

  const accessToken = await c.env.ACCESS_TOKENS.get(
    `${deviceToken}:${itemId}`
  );
  if (!accessToken) {
    return c.json({ error: "Item not found" }, 404);
  }

  const allAdded: any[] = [];
  const allModified: any[] = [];
  const allRemoved: any[] = [];
  let hasMore = true;
  let nextCursor = cursor || undefined;

  while (hasMore) {
    const response = await client.transactionsSync({
      access_token: accessToken,
      cursor: nextCursor,
      count: 500,
    });

    allAdded.push(...response.data.added);
    allModified.push(...response.data.modified);
    allRemoved.push(...response.data.removed);
    hasMore = response.data.has_more;
    nextCursor = response.data.next_cursor;
  }

  return c.json({
    added: allAdded.map((t) => ({
      transaction_id: t.transaction_id,
      account_id: t.account_id,
      amount: t.amount,
      name: t.name,
      merchant_name: t.merchant_name,
      date: t.date,
      authorized_date: t.authorized_date,
      pending: t.pending,
      iso_currency_code: t.iso_currency_code,
      personal_finance_category: t.personal_finance_category
        ? {
            primary: t.personal_finance_category.primary,
            detailed: t.personal_finance_category.detailed,
          }
        : null,
    })),
    modified: allModified.map((t) => ({
      transaction_id: t.transaction_id,
      account_id: t.account_id,
      amount: t.amount,
      name: t.name,
      merchant_name: t.merchant_name,
      date: t.date,
      pending: t.pending,
    })),
    removed: allRemoved.map((t) => ({
      transaction_id: t.transaction_id,
    })),
    next_cursor: nextCursor,
  });
});

// Disconnect an item
plaidRoutes.delete("/disconnect", async (c) => {
  const itemId = c.req.query("itemId");
  const deviceToken = c.get("deviceToken" as never) as string;

  if (!itemId) {
    return c.json({ error: "itemId required" }, 400);
  }

  const client = createPlaidClient(c.env);
  const accessToken = await c.env.ACCESS_TOKENS.get(
    `${deviceToken}:${itemId}`
  );

  if (accessToken) {
    try {
      await client.itemRemove({ access_token: accessToken });
    } catch {
      // Item may already be removed on Plaid's side
    }
    await c.env.ACCESS_TOKENS.delete(`${deviceToken}:${itemId}`);
  }

  return c.json({ success: true });
});

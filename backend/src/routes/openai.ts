import { Hono } from "hono";
import type { Bindings } from "../types";

export const openaiRoutes = new Hono<{ Bindings: Bindings }>();

// Batch categorize transactions
openaiRoutes.post("/categorize", async (c) => {
  const { transactions } = await c.req.json<{
    transactions: Array<{
      id: string;
      merchantName: string;
      description: string;
      amount: number;
      date: string;
    }>;
  }>();

  const prompt = `You are a financial transaction categorizer. Categorize each transaction into exactly one of these categories: Groceries, Dining, Transportation, Subscriptions, Shopping, Entertainment, Health, Travel, Bills & Utilities, Gas, Personal Care, Education, Gifts & Donations, Other.

Return a JSON object with a "results" array containing objects: { "id": "<transaction_id>", "category": "<category>", "confidence": <0.0-1.0> }

Transactions:
${JSON.stringify(transactions, null, 2)}`;

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${c.env.OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      messages: [{ role: "user", content: prompt }],
      response_format: { type: "json_object" },
      temperature: 0.1,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    return c.json({ error: "OpenAI API error", details: error }, 502);
  }

  const data = (await response.json()) as any;
  const content = JSON.parse(data.choices[0].message.content);
  return c.json(content);
});

// Generate spending insights
openaiRoutes.post("/insights", async (c) => {
  const { spendingData, periodType } = await c.req.json<{
    spendingData: {
      current: Record<string, any>;
      previous: Record<string, any>;
    };
    periodType: string;
  }>();

  const prompt = `You are a personal finance advisor. Analyze this ${periodType} spending data and provide:
1. A brief 2-3 sentence summary of spending patterns
2. Up to 3 specific, actionable optimization suggestions
3. Any notable changes compared to the previous period

Current period: ${JSON.stringify(spendingData.current)}
Previous period: ${JSON.stringify(spendingData.previous)}

Return JSON: { "summary": "...", "suggestions": ["...", "..."], "highlights": ["..."] }`;

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${c.env.OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      messages: [{ role: "user", content: prompt }],
      response_format: { type: "json_object" },
      temperature: 0.7,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    return c.json({ error: "OpenAI API error", details: error }, 502);
  }

  const data = (await response.json()) as any;
  const content = JSON.parse(data.choices[0].message.content);
  return c.json(content);
});

// Conversational chat about spending
openaiRoutes.post("/chat", async (c) => {
  const { message, context, history } = await c.req.json<{
    message: string;
    context: Record<string, any>;
    history: Array<{ role: string; content: string }>;
  }>();

  const systemPrompt = `You are a helpful personal finance assistant embedded in a spending tracker app called Spender. You have access to the user's spending data.

Current spending context:
- Total spend this month: $${context.totalSpendThisMonth?.toFixed(2) || "0.00"}
- Total spend last month: $${context.totalSpendLastMonth?.toFixed(2) || "0.00"}
- Top categories: ${JSON.stringify(context.topCategories || {})}
- Recent transactions: ${JSON.stringify(context.recentTransactions || [])}

Be concise, specific, and actionable. Reference actual numbers from the data. If asked about something not in the data, say so honestly.`;

  const messages = [
    { role: "system" as const, content: systemPrompt },
    ...history.map((h) => ({
      role: h.role as "user" | "assistant",
      content: h.content,
    })),
    { role: "user" as const, content: message },
  ];

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${c.env.OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      messages,
      temperature: 0.7,
      max_tokens: 500,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    return c.json({ error: "OpenAI API error", details: error }, 502);
  }

  const data = (await response.json()) as any;
  return c.json({ reply: data.choices[0].message.content });
});

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  corsHeaders,
  jsonResponse,
  STARTER_GRANT,
} from "../_shared/credits.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Missing Authorization" }, 401);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();
    if (userError || !user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const { data: existing } = await admin
      .from("credit_balances")
      .select("balance, starter_granted")
      .eq("user_id", user.id)
      .maybeSingle();

    let balance = existing?.balance ?? 0;
    let starterGranted = existing?.starter_granted ?? false;

    if (!existing) {
      const { error: insertError } = await admin.from("credit_balances").insert({
        user_id: user.id,
        balance: STARTER_GRANT,
        starter_granted: true,
      });
      if (insertError) {
        return jsonResponse({ error: insertError.message }, 500);
      }
      const { error: ledgerError } = await admin.from("credit_ledger").insert({
        user_id: user.id,
        kind: "starter_grant",
        amount: STARTER_GRANT,
        idempotency_key: `starter_grant:${user.id}`,
        metadata: { source: "credits-wallet" },
      });
      if (ledgerError && !ledgerError.message.includes("duplicate")) {
        return jsonResponse({ error: ledgerError.message }, 500);
      }
      balance = STARTER_GRANT;
      starterGranted = true;
    } else if (!starterGranted) {
      const { error: updateError } = await admin
        .from("credit_balances")
        .update({
          balance: balance + STARTER_GRANT,
          starter_granted: true,
          updated_at: new Date().toISOString(),
        })
        .eq("user_id", user.id);
      if (updateError) {
        return jsonResponse({ error: updateError.message }, 500);
      }
      await admin.from("credit_ledger").upsert({
        user_id: user.id,
        kind: "starter_grant",
        amount: STARTER_GRANT,
        idempotency_key: `starter_grant:${user.id}`,
        metadata: { source: "credits-wallet-backfill" },
      }, { onConflict: "idempotency_key", ignoreDuplicates: true });
      balance = balance + STARTER_GRANT;
      starterGranted = true;
    }

    // Stipend flag is informational; grants arrive via revenuecat-webhook.
    const { data: stipendRow } = await admin
      .from("credit_ledger")
      .select("id")
      .eq("user_id", user.id)
      .eq("kind", "stipend")
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    return jsonResponse({
      balance,
      starterGranted,
      hasActiveStipend: Boolean(stipendRow),
      ledgerAvailable: true,
    });
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unknown error" },
      500,
    );
  }
});

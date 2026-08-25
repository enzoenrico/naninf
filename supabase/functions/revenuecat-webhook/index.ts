import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  corsHeaders,
  jsonResponse,
  PRODUCT_CREDITS,
} from "../_shared/credits.ts";

/**
 * RevenueCat Server Notification webhook.
 * Configure Authorization header in RC dashboard to match REVENUECAT_WEBHOOK_AUTH.
 *
 * App User ID must be the Supabase user UUID (Purchases.shared.logIn(supabaseUserId)).
 */
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const expected = Deno.env.get("REVENUECAT_WEBHOOK_AUTH") ?? "";
    const auth = req.headers.get("Authorization") ?? "";
    if (!expected || auth !== `Bearer ${expected}`) {
      return jsonResponse({ error: "Unauthorized webhook" }, 401);
    }

    const payload = await req.json();
    const event = payload?.event ?? payload;
    const eventID: string | undefined = event?.id;
    const appUserID: string | undefined = event?.app_user_id;
    const productID: string | undefined = event?.product_id;
    const type: string = event?.type ?? "";

    if (!eventID || !appUserID || !productID) {
      return jsonResponse({ error: "Malformed RevenueCat event" }, 400);
    }

    const grantTypes = new Set([
      "INITIAL_PURCHASE",
      "RENEWAL",
      "NON_RENEWING_PURCHASE",
      "PRODUCT_CHANGE",
      "UNCANCELLATION",
    ]);

    if (!grantTypes.has(type)) {
      return jsonResponse({ ok: true, ignored: type });
    }

    const credits = PRODUCT_CREDITS[productID];
    if (!credits) {
      return jsonResponse({ ok: true, ignored_product: productID });
    }

    // Only grant monthly CREDITS on INITIAL_PURCHASE + RENEWAL for the Scribe sub.
    const isScribe = productID === "com.kyou.naninf.sub.scribe_monthly";
    if (isScribe && type !== "INITIAL_PURCHASE" && type !== "RENEWAL") {
      return jsonResponse({ ok: true, ignored_scribe_type: type });
    }

    const kind = isScribe ? "stipend" : "purchase";
    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const { data: existingEvent } = await admin
      .from("credit_ledger")
      .select("id")
      .eq("revenuecat_event_id", eventID)
      .maybeSingle();
    if (existingEvent) {
      return jsonResponse({ ok: true, duplicate: true });
    }

    const { data: balanceRow } = await admin
      .from("credit_balances")
      .select("balance, starter_granted")
      .eq("user_id", appUserID)
      .maybeSingle();

    const current = balanceRow?.balance ?? 0;
    if (!balanceRow) {
      await admin.from("credit_balances").insert({
        user_id: appUserID,
        balance: credits,
        starter_granted: false,
      });
    } else {
      await admin
        .from("credit_balances")
        .update({
          balance: current + credits,
          updated_at: new Date().toISOString(),
        })
        .eq("user_id", appUserID);
    }

    const { error: ledgerError } = await admin.from("credit_ledger").insert({
      user_id: appUserID,
      kind,
      amount: credits,
      idempotency_key: `rc:${eventID}`,
      revenuecat_event_id: eventID,
      product_id: productID,
      metadata: { type, store: event?.store ?? null },
    });
    if (ledgerError) {
      return jsonResponse({ error: ledgerError.message }, 500);
    }

    return jsonResponse({
      ok: true,
      credited: credits,
      balance: current + credits,
    });
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unknown error" },
      500,
    );
  }
});

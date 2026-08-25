import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  corsHeaders,
  CREDIT_COSTS,
  jsonResponse,
} from "../_shared/credits.ts";

type MeterBody = {
  action?: string;
  spend?: string;
  generation_id?: string;
  idempotency_key?: string;
  hold_id?: string;
};

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

    const body = (await req.json()) as MeterBody;
    const action = body.action ?? "";
    const generationID = body.generation_id ?? "";
    const idempotencyKey = body.idempotency_key ?? "";

    if (!generationID || !idempotencyKey) {
      return jsonResponse({ error: "generation_id and idempotency_key required" }, 400);
    }

    async function readBalance(): Promise<number> {
      const { data } = await admin
        .from("credit_balances")
        .select("balance")
        .eq("user_id", user.id)
        .maybeSingle();
      return data?.balance ?? 0;
    }

    if (action === "hold") {
      const spend = body.spend ?? "";
      const cost = CREDIT_COSTS[spend];
      if (!cost) {
        return jsonResponse({ error: `Unknown spend: ${spend}` }, 400);
      }

      const { data: existingHold } = await admin
        .from("credit_ledger")
        .select("hold_id, metadata")
        .eq("idempotency_key", idempotencyKey)
        .maybeSingle();
      if (existingHold?.hold_id) {
        return jsonResponse({
          holdID: existingHold.hold_id,
          balance: await readBalance(),
          cost,
        });
      }

      const balance = await readBalance();
      if (balance < cost) {
        return jsonResponse({ error: "insufficient", balance, required: cost }, 402);
      }

      const { data: hold, error: holdError } = await admin
        .from("credit_holds")
        .insert({
          user_id: user.id,
          generation_id: generationID,
          spend,
          cost,
          status: "held",
        })
        .select("id")
        .single();
      if (holdError || !hold) {
        return jsonResponse({ error: holdError?.message ?? "hold failed" }, 500);
      }

      const { error: balError } = await admin
        .from("credit_balances")
        .update({
          balance: balance - cost,
          updated_at: new Date().toISOString(),
        })
        .eq("user_id", user.id);
      if (balError) {
        return jsonResponse({ error: balError.message }, 500);
      }

      await admin.from("credit_ledger").insert({
        user_id: user.id,
        kind: "hold",
        amount: -cost,
        idempotency_key: idempotencyKey,
        generation_id: generationID,
        hold_id: hold.id,
        metadata: { spend },
      });

      return jsonResponse({
        holdID: hold.id,
        balance: balance - cost,
        cost,
      });
    }

    if (action === "capture" || action === "release") {
      const holdID = body.hold_id;
      if (!holdID) {
        return jsonResponse({ error: "hold_id required" }, 400);
      }

      const { data: hold } = await admin
        .from("credit_holds")
        .select("*")
        .eq("id", holdID)
        .eq("user_id", user.id)
        .maybeSingle();
      if (!hold) {
        return jsonResponse({ error: "hold not found" }, 404);
      }

      if (hold.status !== "held") {
        return jsonResponse({
          balance: await readBalance(),
          starterGranted: true,
          hasActiveStipend: false,
          ledgerAvailable: true,
        });
      }

      if (action === "capture") {
        await admin
          .from("credit_holds")
          .update({ status: "captured", finished_at: new Date().toISOString() })
          .eq("id", holdID);
        await admin.from("credit_ledger").upsert({
          user_id: user.id,
          kind: "capture",
          amount: 0,
          idempotency_key: idempotencyKey,
          generation_id: generationID,
          hold_id: holdID,
          metadata: { spend: hold.spend },
        }, { onConflict: "idempotency_key", ignoreDuplicates: true });
      } else {
        const balance = await readBalance();
        await admin
          .from("credit_balances")
          .update({
            balance: balance + hold.cost,
            updated_at: new Date().toISOString(),
          })
          .eq("user_id", user.id);
        await admin
          .from("credit_holds")
          .update({ status: "released", finished_at: new Date().toISOString() })
          .eq("id", holdID);
        await admin.from("credit_ledger").upsert({
          user_id: user.id,
          kind: "release",
          amount: hold.cost,
          idempotency_key: idempotencyKey,
          generation_id: generationID,
          hold_id: holdID,
          metadata: { spend: hold.spend },
        }, { onConflict: "idempotency_key", ignoreDuplicates: true });
      }

      return jsonResponse({
        balance: await readBalance(),
        starterGranted: true,
        hasActiveStipend: false,
        ledgerAvailable: true,
      });
    }

    if (action === "charge") {
      const spend = body.spend ?? "";
      const cost = CREDIT_COSTS[spend];
      if (!cost) {
        return jsonResponse({ error: `Unknown spend: ${spend}` }, 400);
      }

      const { data: existing } = await admin
        .from("credit_ledger")
        .select("id")
        .eq("idempotency_key", idempotencyKey)
        .maybeSingle();
      if (existing) {
        return jsonResponse({
          balance: await readBalance(),
          starterGranted: true,
          hasActiveStipend: false,
          ledgerAvailable: true,
        });
      }

      const balance = await readBalance();
      if (balance < cost) {
        return jsonResponse({ error: "insufficient", balance, required: cost }, 402);
      }

      await admin
        .from("credit_balances")
        .update({
          balance: balance - cost,
          updated_at: new Date().toISOString(),
        })
        .eq("user_id", user.id);

      await admin.from("credit_ledger").insert({
        user_id: user.id,
        kind: "charge",
        amount: -cost,
        idempotency_key: idempotencyKey,
        generation_id: generationID,
        metadata: { spend },
      });

      return jsonResponse({
        balance: balance - cost,
        starterGranted: true,
        hasActiveStipend: false,
        ledgerAvailable: true,
      });
    }

    return jsonResponse({ error: `Unknown action: ${action}` }, 400);
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : "Unknown error" },
      500,
    );
  }
});

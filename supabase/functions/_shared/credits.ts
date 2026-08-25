export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export const CREDIT_COSTS: Record<string, number> = {
  dm_turn: 1,
  scene_image: 3,
};

export const PRODUCT_CREDITS: Record<string, number> = {
  "com.kyou.naninf.credits.starter_40": 40,
  "com.kyou.naninf.credits.plus_100": 100,
  "com.kyou.naninf.credits.vault_250": 250,
  "com.kyou.naninf.sub.stipend_monthly": 120,
};

export const STARTER_GRANT = 20;

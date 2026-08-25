# RevenueCat + credits setup (NanInf)

This app meters AI spend with **Credits** (1 / DM turn, 3 / successful DALL·E scene) and sells them through **RevenueCat** (not raw StoreKit / Stripe). The balance ledger lives in **Supabase** (`supabase/` in this repo).

## Xcode key to paste

| Build setting / Info.plist key | Value |
| --- | --- |
| `REVENUECAT_API_KEY` | RevenueCat **public** Apple SDK key (`appl_…`) |

Wire it like `SUPABASE_*`:

1. Copy `magoSanduiche/Config/Secrets.xcconfig.example` → `magoSanduiche/Config/Secrets.xcconfig` (gitignored pattern: `Secrets.xcconfig`).
2. Set `REVENUECAT_API_KEY = appl_your_key`.
3. Or set **Build Settings → REVENUECAT_API_KEY** on the `magoSanduiche` target (Debug + Release).

`Info.plist` already maps `REVENUECAT_API_KEY` → `$(REVENUECAT_API_KEY)`.

Without this key, Profile shows a hint and purchases stay disabled; generation still works until the ledger is deployed (fail-open).

## RevenueCat dashboard steps (Enzo)

1. Open the existing RevenueCat project → **Apps** → ensure iOS app **bundle id** `com.kyou.naninf` / App Store ID **6749869965** is linked.
2. **Project settings → API keys** → copy the **Apple** public SDK key into `REVENUECAT_API_KEY`.
3. **Product catalog → Entitlements**
   - Create `credits` (optional grouping for packs).
   - Create `stipend` (attach the monthly subscription).
4. **Products** (IDs must match App Store Connect + `CreditCatalog`):
   - `com.kyou.naninf.credits.starter_40` — Consumable → entitlement `credits` (metadata / dashboard only).
   - `com.kyou.naninf.credits.plus_100` — Consumable.
   - `com.kyou.naninf.credits.vault_250` — Consumable.
   - `com.kyou.naninf.sub.stipend_monthly` — Auto-renewable → entitlement `stipend`.
5. **Offerings** → create/current offering id `default` containing those packages.
6. **App Store Connect**: create the same product IDs, Paid Apps agreement active, then **Products → Import from App Store Connect** (or link manually) in RevenueCat.
7. **Integrations → Webhooks** → URL  
   `https://hqbfifbyxrtegcpndjsg.supabase.co/functions/v1/revenuecat-webhook`  
   Authorization: `Bearer <REVENUECAT_WEBHOOK_AUTH>` (same secret set as a Supabase function secret).
8. App identifies users with `Purchases.shared.logIn(supabaseUserId)` — **App User ID = Supabase `auth.users.id`**.

Suggested credit grants (server webhook map): starter_40→40, plus_100→100, vault_250→250, stipend_monthly→**120 per INITIAL_PURCHASE/RENEWAL**.

## Supabase ledger deploy

```bash
supabase link --project-ref hqbfifbyxrtegcpndjsg
supabase db push
supabase secrets set REVENUECAT_WEBHOOK_AUTH=your_webhook_secret
# SUPABASE_SERVICE_ROLE_KEY is provided to functions automatically when deployed via CLI
supabase functions deploy credits-wallet
supabase functions deploy credits-meter
supabase functions deploy revenuecat-webhook
```

Tables: `credit_balances`, `credit_ledger`, `credit_holds` (see `supabase/migrations/`).

## Enforcement status

| Layer | Status in this PR |
| --- | --- |
| RevenueCat purchase / restore / identify | Implemented in app |
| Profile balance + packages | Implemented |
| Game preflight + hold/capture + image charge-on-success | Implemented against Edge Functions |
| Server ledger | Source in `supabase/` — **must be deployed** |
| OpenAI proxy (remove client `OPENAI_API_KEY`) | **Not shipped** — key remains; jailbreaks can still hit OpenAI until a generation proxy lands. Metering is **not** hard enforcement until `credits-wallet` / `credits-meter` are live; client fail-opens if functions 404. |

## App surfaces

- **Profile** → credits balance, packs, monthly stipend, Restore.
- **Game** → insufficient-credits system `TerminalEntry` when ledger reports 402; images skipped (no charge) when underfunded or soft-fail.

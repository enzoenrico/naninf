# RevenueCat + credits setup (NanInf)

This app meters AI spend with **Credits** (1 / DM turn, 3 / successful DALL·E scene) and sells them through **RevenueCat** (not raw StoreKit / Stripe). The balance ledger lives in **Supabase** (`supabase/` in this repo). Virtual currency **CREDITS** in RevenueCat grants pack/monthly amounts; **Supabase remains spend authority**.

## Live project (do not recreate / do not use binis)

| Field | Value |
| --- | --- |
| Project | `projcb74c4bd` (**NanInf**) — never `projf867d61b` (binis) |
| App Store app | `app255cd2ec86` · bundle `com.kyou.naninf` · ASC **6749869965** |
| Offering | `default` (current) |
| Entitlement | `scribe` only (monthly). There is **no** `credits` or `stipend` entitlement. |
| Virtual currency | `CREDITS` (40 / 100 / 250 / 120 monthly with `expire_at_cycle_end`) |

### Product IDs (already in dashboard)

| Store product ID | Type | CREDITS grant |
| --- | --- | --- |
| `com.kyou.naninf.credits.starter_40` | Consumable | 40 |
| `com.kyou.naninf.credits.plus_100` | Consumable | 100 |
| `com.kyou.naninf.credits.vault_250` | Consumable | 250 |
| `com.kyou.naninf.sub.scribe_monthly` | Auto-renewable → entitlement `scribe` | 120 / period |

## Xcode keys

| Build setting / Info.plist | Value |
| --- | --- |
| `REVENUECAT_API_KEY` (Release / device) | `appl_vGMVhMXUbYDDBVfDylqKIvuFybX` |
| `REVENUECAT_API_KEY` (DEBUG / Test Store only) | `test_jCXzzWuNNSIPdTPDzgwBzefqtoa` |

1. Copy `magoSanduiche/Config/Secrets.xcconfig.example` → `magoSanduiche/Config/Secrets.xcconfig` (gitignored), **or** set **Build Settings → REVENUECAT_API_KEY** on the `magoSanduiche` target.
2. `Info.plist` maps `REVENUECAT_API_KEY` → `$(REVENUECAT_API_KEY)`.

Without a real key, Profile shows a hint and purchases stay disabled; generation still works until the ledger is deployed (fail-open).

## Dashboard checklist (align only — catalog already exists)

1. Confirm project **NanInf** `projcb74c4bd` and app `app255cd2ec86`.
2. Confirm offering **`default`** is current and contains the four products above.
3. Confirm entitlement **`scribe`** is attached only to `com.kyou.naninf.sub.scribe_monthly`.
4. **Integrations → Webhooks** →  
   `https://hqbfifbyxrtegcpndjsg.supabase.co/functions/v1/revenuecat-webhook`  
   Authorization: `Bearer <REVENUECAT_WEBHOOK_AUTH>` (Supabase function secret).
5. App identifies users with `Purchases.shared.logIn(supabaseUserId)` — **App User ID = Supabase `auth.users.id`**.

Webhook / ledger credit map matches RC virtual currency: starter_40→40, plus_100→100, vault_250→250, scribe_monthly→**120** on `INITIAL_PURCHASE` / `RENEWAL`.

## Supabase ledger deploy

```bash
supabase link --project-ref hqbfifbyxrtegcpndjsg
supabase db push
supabase secrets set REVENUECAT_WEBHOOK_AUTH=your_webhook_secret
supabase functions deploy credits-wallet
supabase functions deploy credits-meter
supabase functions deploy revenuecat-webhook
```

Tables: `credit_balances`, `credit_ledger`, `credit_holds` (see `supabase/migrations/`).

## Enforcement status

| Layer | Status |
| --- | --- |
| RevenueCat purchase / restore / identify | Implemented (`purchases-ios-spm` **5.86.0**) |
| Profile balance + packages | Implemented |
| Game preflight + hold/capture + image charge-on-success | Implemented against Edge Functions |
| Server ledger | Source in `supabase/` — **must be deployed** |
| OpenAI proxy (remove client `OPENAI_API_KEY`) | **Not shipped** — key remains; fail-open until `credits-*` functions are live |

## App surfaces

- **Profile** → credits balance, packs, monthly Scribe, Restore.
- **Game** → insufficient-credits system `TerminalEntry` when ledger reports 402; images skipped (no charge) when underfunded or soft-fail.

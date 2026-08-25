# NanInf (`magoSanduiche`)

iOS SwiftUI infinite text RPG — Xcode target `magoSanduiche`, bundle `com.kyou.naninf`.

## Payments & credits

AI turns and scene images are metered in **Credits** via **RevenueCat** + a **Supabase** ledger.

- Operator setup (dashboard clicks, `REVENUECAT_API_KEY`, webhook, `supabase` deploy): **[`docs/revenuecat-setup.md`](docs/revenuecat-setup.md)**
- Architecture ADR: **[`docs/adr/0003-payments-and-token-spend.md`](docs/adr/0003-payments-and-token-spend.md)**

Copy `magoSanduiche/Config/Secrets.xcconfig.example` to a local `Secrets.xcconfig` (gitignored) and paste your RevenueCat public Apple SDK key.

## Docs index

See [`CONTEXT.md`](CONTEXT.md) and [`DESIGN.md`](DESIGN.md).

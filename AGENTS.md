# AGENTS.md

## Cursor Cloud specific instructions

### What this project is

`magoSanduiche` (display name **NanInf**, bundle id `com.kyou.naninf`) is a native
**iOS / iPadOS SwiftUI application** — a CRT/terminal-styled, AI dungeon-master RPG.
It is built and run exclusively through **Xcode** (project created with Xcode 26,
`SDKROOT = iphoneos`, app deployment target `IPHONEOS_DEPLOYMENT_TARGET = 27.0`,
shared scheme `magoSanduiche`). There is **no `Package.swift`** and no SwiftPM target.

### Critical: this app cannot be built/run/tested on the Linux Cloud Agent VM

The Cursor Cloud Agent runs on **Linux (Ubuntu)**. This app depends on Apple-only
frameworks that **do not exist on Linux**, and on `xcodebuild`/the iOS Simulator,
which are **macOS-only**. This is a hard platform limitation, not a missing
dependency. Concretely verified on this VM:

- `xcodebuild` / `xcrun` are not present (macOS only).
- The open-source Swift toolchain installs and runs on Linux (`swift --version`
  works), but `import SwiftUI` fails with `no such module 'SwiftUI'`. The same
  applies to `UIKit`, `SwiftData`, `TipKit`, `ImagePlayground`, and
  `AuthenticationServices`, which the app and its sources use pervasively.
- Test targets (`magoSanduicheTests`, `magoSanduicheUITests`) use
  `@testable import magoSanduiche` and run as host-based `.xctest` bundles, so even
  individual logic tests require building the full iOS app module + Simulator.

Do **not** spend time trying to `swift build`/`swiftc` the app on Linux — it will not
work. A future agent that needs to build, run, lint, or test this app must do so on
**macOS with Xcode 27 + an iOS 27 Simulator**.

### Commands to use on macOS (for reference, not runnable on the Linux VM)

- Build: `xcodebuild -project magoSanduiche.xcodeproj -scheme magoSanduiche -destination 'platform=iOS Simulator,name=iPhone 16' build`
- Test:  `xcodebuild -project magoSanduiche.xcodeproj -scheme magoSanduiche -destination 'platform=iOS Simulator,name=iPhone 16' test`
- Lint:  `swiftlint` (config in `.swiftlint.yml`; only `inclusive_language` is disabled). SwiftLint is not installed by default.
- Run:   open `magoSanduiche.xcodeproj` in Xcode and Run the `magoSanduiche` scheme on a Simulator/device.

### External services & credentials (needed for end-to-end gameplay on macOS)

| Service | Required | Purpose | Where configured |
| --- | --- | --- | --- |
| Private Cloud Compute | Yes (core) | Dungeon-master turns via `PrivateCloudComputeLanguageModel` | Apple-managed entitlement. The key is not in this repo. No app credential. |
| Supabase | Yes (auth gating) | Apple/Google sign-in sessions | `SUPABASE_URL` / `SUPABASE_PUBLISHABLE_KEY` build settings in `project.pbxproj`, surfaced into `Info.plist` |
| Google Sign-In | Yes (one sign-in path) | OAuth → Supabase | `GIDClientID` + URL types in `Info.plist`; `magoSanduiche/GoogleOAuthClient.plist` |
| Apple Sign-In | Yes (other sign-in path) | OAuth → Supabase | `magoSanduiche.entitlements`; needs Apple Developer team `DEVELOPMENT_TEAM` |
| PostHog | Optional | Analytics (non-blocking) | `POSTHOG_*` in `Info.plist` / scheme env vars |
| Image Playground | Optional | On-device scene art through `ImageCreator`. The iOS 27 sheet is interactive, so the vision panel keeps the programmatic API. | Apple framework. No app credential. |

Note: the intended secret-injection pattern is an untracked `Secrets.xcconfig`
(see `.gitignore`), though some keys are currently committed in `Info.plist` /
`project.pbxproj`. SPM dependencies are resolved by Xcode (`Package.resolved`), not by
any Linux package manager.

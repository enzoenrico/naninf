# Context

## Glossary

### Onboarding Completion

The point where a player has answered the onboarding questions, finished the demo/paywall sequence, and the app has persisted their onboarding responses locally. Onboarding completion does not grant player home access by itself.

### Authenticated Session

A Supabase Auth session created through Apple or Google social sign-in. The Supabase access and refresh tokens are session secrets and live in secure system storage managed by the auth SDK, not in UserDefaults.

### Login Snapshot

The non-sensitive local record of the authenticated player, including user id, email, display name, provider, and sign-in timestamp. The app stores this in UserDefaults for UI display and launch gating hints, but it is not treated as proof of authentication.

### Player Home Access

The state where the player can reach `PlayerHomeView`. It requires both Onboarding Completion and a current Authenticated Session.

### Model Provider

The runtime that generates dungeon-master responses. OpenAI is the current production Model Provider; Apple Foundation Models is a future local-provider target.

### Model Tool

A typed capability the dungeon master can call while generating a turn, such as rolling dice, requesting the next player action, or changing player health. Model Tools are defined in app-owned terms and adapted to each Model Provider.

### Tool Arguments

The typed input data a Model Tool accepts. Tool Arguments are the source of truth for provider schemas and debug controls.

### Tool Result

The typed output of a Model Tool. A Tool Result includes a model-facing message and zero or more game effects for the app to apply after tool execution.

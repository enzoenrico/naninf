# Context

## Glossary

### Onboarding Completion

The point where a player has answered the onboarding questions, finished the demo and sign-in sequence, and the app has persisted their onboarding responses locally. Onboarding completion does not grant player home access by itself.

### Authenticated Session

A Supabase Auth session created through Apple or Google social sign-in. The Supabase access and refresh tokens are session secrets and live in secure system storage managed by the auth SDK, not in UserDefaults.

### Login Snapshot

The non-sensitive local record of the authenticated player, including user id, email, display name, provider, and sign-in timestamp. The app stores this in UserDefaults for UI display and launch gating hints, but it is not treated as proof of authentication.

### Player Home Access

The state where the player can reach `PlayerHomeView`. It requires both Onboarding Completion and a current Authenticated Session.

### Model Provider

The runtime that generates dungeon-master responses. Private Cloud Compute is the production Model Provider. Each turn is one guided response on a fresh session. The app does not keep a second provider.

### Model Tool

Retired. Health, mana, and the next input mode are guided fields on `DungeonTurnDraft` (`healthChange`, `manaChange`, `nextInput`). `resolved()` turns those fields into `GameToolEffect` values. Numeric dice outcomes come from the **Player-facing roll**, not from the narrator.

### Tool Arguments

The typed input data a Model Tool accepts. Tool Arguments are the source of truth for provider schemas and debug controls.

### Tool Result

The typed output of a Model Tool. A Tool Result includes a model-facing message and zero or more game effects for the app to apply after tool execution.

### Player-facing roll

A die roll performed through the game’s dice UI. The numeric outcome is authoritative for anything framed as the player’s skill check or uncertain player action. The app holds that result locally until the player **explicitly confirms** sending it; confirmation triggers a structured message to the Model Provider on the next DM turn. **Dice animation alone does not change health or mana**; resource updates follow the turn’s `healthChange` and `manaChange` fields.

### Dice result confirmation

The deliberate player action that submits a completed **Player-facing roll** to the Model Provider. **UX:** reuse the primary **ContextualButton** after the reveal: its label switches to a confirm/send-roll action (no separate floating button unless later usability testing says otherwise).

### DM-internal random roll (removed)

The product direction is to **not** expose a Model Tool that rolls dice on behalf of the world without the player’s dice UI. Ambiguous or environmental outcomes are resolved by narration or by requesting a **player-facing roll**, not by a hidden numeric tool roll.

### Ambient uncertainty (hybrid)

How the dungeon master resolves outcomes when there is no DM-side random tool. **Pure environment** beats that do not involve player agency may be resolved in narration alone. When player attention, luck, or skill could matter, the dungeon master requests a **Player-facing roll** and adjudicates only after **Dice result confirmation**.

### Canonical prompt

The dungeon master system instructions loaded from a **single bundled Markdown** resource in the app target (not duplicated ad hoc in Swift source). Editors treat that file as the source of truth for tone, mechanics language, and tool names.

### Game state snapshot

A compact payload appended to each dungeon master request: current resources and caps, pending player interaction (if any), the **last player message**, a **short excerpt** of the latest dungeon master narrative, and **`turnKind`** indicating whether this request is normal player text or a **Dice result confirmation**. Full transcripts remain client-side in v1.

### Request player input (`RequestPlayerInput`)

A single Model Tool the dungeon master uses to choose the **next** player interaction mode: **`text`** (typing / suggested actions) or **`dice`** (player-facing roll flow). Tool Arguments carry shared context (for example what to roll or why). Replaces older integer-coded `decideAction` tools. If a turn completes without this tool, the app **falls back to text mode** and records an analytics signal rather than failing the turn.

### Mana adjustment (`changeMana`)

A Model Tool that applies a signed mana delta (with clamping in app code). Spell costs and magical resource changes should use this tool rather than obsolete prompt names such as `playerMana`.

### Suggested action

A structured choice offered after a dungeon master turn: **`id`** (stable analytics key), **`submitText`** (verbatim player message sent on tap), optional **`shortTitle`** for compact chip UI. Not parsed from narrative prefixes such as `A.`/`B.`.

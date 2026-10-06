# 0003. Narrate With Private Cloud Compute Guided Turns

## Status

Accepted. Supersedes [0002](0002-use-typed-model-tools-with-provider-adapters.md).

## Context

The dungeon master used to run on OpenAI. `OpenAIService` owned a tool loop (`decideAction`, `changeHealth`, `changeMana`) and then a second JSON phase for `PromptOutput`. That path is removed. ADR 0002 kept `ModelTool` provider-neutral so a later adapter could retarget the same tools. Guided generation makes that adapter unnecessary.

`nextInput` has to be present on every turn. A Foundation Models tool call cannot express that. `ToolCallingMode.required` only forces some tool, not `decideAction` specifically. A shared effect ledger would also be mutable state the turn does not need, because effects are known only after `respond` returns.

Private Cloud Compute is iOS 27 only. Apple requires a managed entitlement for it. This repo does not know the entitlement key, so none is declared.

## Decision

One turn is one `LanguageModelSession` on `PrivateCloudComputeLanguageModel`, with no tools. The session is not stored. Memory is the persisted terminal transcript (`storySoFar`), formatted under a character budget.

The model returns `DungeonTurnDraft`. `resolved()` is the only function that turns that draft into `DungeonMasterTurn`: nonzero `healthChange`, nonzero `manaChange`, then exactly one `.requestAction`. `GameViewModel.applyToolEffects` remains the only writer of HP, mana, and input mode.

`DungeonNarrator` and, for scene art, `SceneIllustrator` are test seams. They are not a provider registry. Tests inject `ScriptedNarrator` and do not construct `PrivateCloudComputeLanguageModel`.

Analytics records provider `apple_private_cloud_compute`, model `private-cloud-compute`, latency, and token counts. It does not send the prompt, narrative, options, or arguments.

## Consequences

- A turn cannot omit the next input mode.
- Health and mana are one net delta per turn. Two tool calls that used to clamp step by step now net first.
- Restore keeps story memory, because the story is the terminal log rather than an in-memory transcript.
- Ineligible devices, an unready system, quota, offline, and refusal each have a terminal line. There is no silent-narrator branch.
- Shipping on a device still needs Apple's Private Cloud Compute entitlement. The key is not invented here.

# 0002. Use Typed Model Tools With Provider Adapters

## Status

Superseded by [0003. Narrate With Private Cloud Compute Guided Turns](0003-narrate-with-private-cloud-compute-guided-turns.md).

## Context

The dungeon master needs tools for game actions such as dice rolls, action selection, and health changes. The first implementation defined these tools in OpenAI-specific terms: each tool exposed an OpenAI function definition and decoded raw JSON strings inside its execution method.

Apple Foundation Models uses a typed tool model: tools define typed arguments, execute through a typed async call, and return values the model can consume. The app also needs to preserve game effects without parsing prose, and OpenAI still remains the current production provider.

## Decision

Model Tools are defined as typed app-owned contracts. Each tool owns its typed arguments, provider-neutral parameter metadata, and typed result. Provider adapters convert those contracts into provider-specific formats, such as OpenAI function definitions and JSON Schema parameters.

OpenAI remains the active provider for now. Apple Foundation Models can be added later as an adapter over the same Model Tool contracts.

## Consequences

- Domain tools no longer import OpenAI or decode provider JSON directly.
- OpenAI tool definitions are generated from provider-neutral tool metadata, so function parameters stay aligned with Swift argument types.
- Tool results can carry typed game effects for `GameViewModel` to apply after the model turn.
- Future Apple Foundation Models support should not require redefining the dungeon-master tools, only adding a provider adapter.

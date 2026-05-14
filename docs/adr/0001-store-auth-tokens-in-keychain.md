# 0001. Store Auth Tokens In Keychain

## Status

Accepted

## Context

The app now requires a Supabase Auth session after onboarding and before player home access. Social sign-in through Apple and Google returns a Supabase access token and refresh token. These tokens can grant account access and should be treated as session secrets.

The product also needs lightweight local state for UI and flow decisions, such as the signed-in user id, email, provider, display name, and sign-in timestamp.

## Decision

Supabase access and refresh tokens are stored only through Supabase Swift's secure auth storage on Apple platforms, which is Keychain-backed. UserDefaults stores only a non-sensitive login snapshot and onboarding/auth flow flags.

## Consequences

- Refresh tokens are not exposed through UserDefaults or device backup paths intended for preferences.
- The login snapshot can help render profile UI, but it is not proof of authentication.
- Home access must be based on the current Supabase session, not only the UserDefaults snapshot.
- Sign-out must clear both the Supabase session and the local login snapshot while preserving onboarding responses.

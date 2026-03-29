# Sparkle release checklist

## Preflight

- If this repo expects CI-driven macOS releases, confirm the actual workflow file path in `.github/workflows/`. Do not assume `macos-release.yml`.
- Confirm Sparkle feed/public key configuration exists in macOS app Info settings.
- Confirm `SUPublicEDKey` matches the public key derived from the local Sparkle private key.
- Confirm release artifact naming convention and appcast destination.
- Capture any `LSApplicationCategory` warning from the Release build as a P3 hardening finding.

## Signing + notarization + distribution gates

1. Build signed Release app.
2. Zip app for notarization submission.
3. Submit for notarization and wait for terminal status.
4. Staple notarization ticket to `.app`.
5. Re-zip distributable artifact from stapled `.app`.
6. Run Gatekeeper assessment on final `.app`.
7. Publish only artifacts from the stapled build.
8. Publish `appcast.xml` alongside the release zip.

Fail the release when any gate above fails.

## Appcast generation safety

- Resolve `generate_appcast` from explicit local `-derivedDataPath` for the current job.
- Reject broad global scans across all DerivedData roots.
- Fail when tool candidate count is not exactly one.
- Convert the resolved tool path to an absolute path before invoking it from another working directory.
- Emit resolved tool path in logs for traceability.
- Generate appcast from inside the target archives directory so output location is deterministic.
- Fail if generated appcast does not contain `sparkle:edSignature`.

## Sparkle signing integrity checks

- Inspect Sparkle helper binaries in `Sparkle.framework` and fail on `Signature=adhoc`.
- If ad-hoc helpers are detected, re-sign `Sparkle.framework` with Developer ID and timestamp, then re-sign the outer app.
- Re-run deep `codesign --verify --strict` after re-signing.
- After any manual re-sign, confirm the app still carries iCloud entitlements (`codesign -d --entitlements -` includes `icloud-container-identifiers`).

## CI hardening checks

- Use restrictive file mode for temporary Sparkle private key material.
- Ensure cleanup trap removes key files on success and failure.
- Prefer commit SHA pinning for third-party GitHub Actions.

## Channel policy checks

- Verify whether Debug/Beta/Release share or split feeds.
- If shared feed is intentional, verify explicit safeguards preventing cross-channel mistakes.
- If split feeds are required, verify each channel maps to intended appcast and artifacts.

## Finding severity rubric

- **P1**: Trust-chain breakages (missing notarization/stapling, unsigned publish path).
- **P2**: Determinism and architecture risks (nondeterministic tooling, channel drift).
- **P3**: Hardening and simplification opportunities.

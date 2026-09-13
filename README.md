# Rescue Triage

An iPhone demo of the intake scan behind [Rescue](https://rescue-riga.vercel.app),
Rīga's anti-waste supermarket. Start from a supplier's rejected-goods declaration,
photograph the product, and get a reasoned verdict: **accepted**, **held for a
human**, or **rejected**.

## How it decides

Gemini looks at the photograph and describes it. It never issues the verdict.

Dates, cold-chain gaps and storage temperatures are arithmetic, so they are
handled by pure local rules that hold veto power — a language model should not
be the thing standing between a broken cold chain and a shelf. The rules can
only ever make a verdict worse, never better.

The business logic is inverted from a normal grocer's, which is the whole point:

| Supplier's reason | Verdict |
|---|---|
| Odd calibre, hail marks, spotty skin, old packaging, overstock | **Accepted** — it is what we sell |
| Use-by is today | **Accepted**, flagged sell-today |
| Photo contradicts the declaration | **Held** — always |
| Use-by passed, cold chain broken, spoilage visible | **Rejected** |

## Running it

```bash
open RescueTriage.xcodeproj
```

Build to a simulator or a connected iPhone. No packages to resolve — the app
uses only Apple frameworks.

Tests:

```bash
xcodebuild test -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17'
```

78 tests, all green: safety rules (expiry, cold chain, temperature), scoring,
the verdict engine's priority order, all twelve demo batches, Keychain
round-tripping, Gemini response decoding, and the session tally.

## The Gemini key

There is no key in this repository and there never will be one — it is public.

Get a key from [aistudio.google.com](https://aistudio.google.com), then enter it
in the app under **Settings → Gemini**. It is stored in the device Keychain.

Without a key the app still works: it applies the expiry, cold-chain and
temperature rules and labels each verdict *partial*.

## Installing on your own iPhone

With a free Apple ID, Xcode will sign and install the app, but it stops working
after seven days and has to be reinstalled. A paid Apple Developer account
(€99/year) lifts that and opens TestFlight.

1. Plug the iPhone in and trust the Mac.
2. In Xcode: **Signing & Capabilities** → pick your Apple ID team.
3. Change the bundle identifier if `lv.rescue.triage` is taken.
4. Select the device and run.
5. On the phone: **Settings → General → VPN & Device Management** → trust the
   developer certificate.

## Known gap

The twelve `samplePhotoName` assets referenced by the demo batches (e.g.
`demo-yoghurt`) are not bundled — no image files were generated for them. The
"Use the sample photo" button on the scan screen simply doesn't appear when the
asset is missing, so the app is correct either way; camera and photo-library
capture both work regardless. Add JPEGs under those names to
`RescueTriage/Assets.xcassets` to light the button up.

## Documents

- Design: `docs/superpowers/specs/2026-09-13-rescue-triage-ios-design.md`
- Plan: `docs/superpowers/plans/2026-09-13-rescue-triage-ios.md`

## Built by

Two Claude Code sessions working the same repo in parallel: `nono86` did the
project skeleton, domain models, safety rules, verdict engine, demo batches,
Keychain storage, Gemini client, session store, and the final scan/settings/
wiring (Tasks 1–10, 13). `nono60` did the brand theme, verdict card, and the
queue/declaration screens (Tasks 11–12), coordinating over this file and
direct messages while working from a machine without Xcode installed.

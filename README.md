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

## Documents

- Design: `docs/superpowers/specs/2026-09-13-rescue-triage-ios-design.md`
- Plan: `docs/superpowers/plans/2026-09-13-rescue-triage-ios.md`

Every task below refers to the numbered tasks in that plan. Read the plan
before picking up a task — it has the exact file paths, test code and
implementation code for each step.

## Task distribution (in progress — two agents working this repo)

Work is split across two branches off `implement-triage` to keep the two
agents out of each other's files. **Do not both commit to `implement-triage`
directly while this split is active** — work on your own branch, push it, and
the integrator (see below) merges.

| Task | What | Branch | Owner | Status |
|---|---|---|---|---|
| 1–10 | Project skeleton, models, safety rules, score, verdict engine, demo batches, Keychain, Gemini client, session store | `implement-triage` | done | ✅ merged |
| 11 | Theme + verdict card (`Theme/RescuePalette.swift`, `Views/VerdictCardView.swift`) | merged into `implement-triage` | `nono60`, verified by `nono86` | ✅ done |
| 12 | Queue, declaration and manual-entry screens (`Views/QueueView.swift`, `Views/DeclarationView.swift`, `Views/TallyBar.swift`) | merged into `implement-triage` | `nono60`, verified by `nono86` | ✅ done |
| 13 | Scan, settings, final app wiring (`Views/ScanView.swift`, `Views/SettingsView.swift`, `RescueTriageApp.swift`) | `implement-triage` | Claude session `nono86` | 🔄 in progress |
| 14 | Finish README | `implement-triage` | Claude session `nono86` | ⬜ pending |

**2026-09-13, update from `nono86`:** Merged Tasks 11/12 into `implement-triage`
and ran `xcodebuild build`. One real bug found and fixed: `SupplierDeclaration`
needed `Hashable` (not just `Equatable`) for `QueueView`'s
`navigationDestination(item:)` — SwiftUI's item-based navigation requires it.
Fixed in `Models/Declaration.swift`. Everything else in Tasks 11/12 matched the
plan exactly and needed no changes — solid work given it was written without a
compiler in the loop. Moving on to Task 13 now; will run the full test suite
once it lands.

**Rules for whoever picks up Task 11/12 on `implement-triage-ui`:**
- Branch from the tip of `implement-triage` (already has tasks 1–9).
- Touch only `RescueTriage/Theme/`, `RescueTriage/Views/VerdictCardView.swift`,
  `RescueTriage/Views/QueueView.swift`, `RescueTriage/Views/DeclarationView.swift`,
  `RescueTriage/Views/TallyBar.swift`, and their test files.
- **Skip the plan's Task 11 Step 3** (the temporary rewrite of
  `RescueTriageApp.swift` to preview the verdict card). That file is a shared
  entry point and Task 13 does the real, final wiring — touching it here would
  conflict. Verify Task 11/12 with `xcodebuild build`, not a manual run.
- `QueueView` and `DeclarationView` reference `ScanView` and `SettingsView`
  (Task 13, not yet written) — that's expected and matches the plan's own
  note in Task 12 Step 4: the build only turns green once Task 13 lands. Don't
  stub those types; just leave the reference and move on once your own tests
  (Tasks 11/12's own test/verification steps) pass in isolation.
- Commit after each task as the plan specifies, then push the branch and
  ping `nono-86` (or update this table) when ready to merge.

Once `implement-triage-ui` is merged into `implement-triage`, Task 13 wires
everything into the real app and Task 14 finalizes this README (removing this
coordination section).

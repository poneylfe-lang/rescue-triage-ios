# Rescue Triage — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an iPhone demo app that turns a supplier surplus declaration plus a product photo into a reasoned verdict — accepted, held for human judgement, or rejected.

**Architecture:** A pure, side-effect-free rule core (`Rules/`) owns every date, temperature and cold-chain decision and holds veto power. Gemini is called only to describe what the photo shows and to flag contradictions with the declaration; it never issues the verdict. `VerdictEngine` fuses the two under a strict precedence where a rule can only ever downgrade a score-derived outcome. SwiftUI drives a five-screen flow over an observable `SessionStore`.

**Tech Stack:** Swift 6.3, SwiftUI, iOS 17+, XCTest, URLSession, Security.framework (Keychain). No external packages.

**Spec:** `docs/superpowers/specs/2026-09-13-rescue-triage-ios-design.md`

## Global Constraints

- iOS deployment target **17.0**. Swift language mode **5** (Swift 6 strict concurrency is off — it would force actor annotations across every view for no demo benefit).
- **Zero external dependencies.** No Swift Package Manager remote packages, no CocoaPods, no Carthage. Only Apple frameworks.
- The Gemini API key lives **only** in the iOS Keychain. It must never appear in source, in `Info.plist`, in a commit, or in a log line. This repo is public.
- `Rules/` and `Models/` must not import `UIKit`, `SwiftUI`, or `Foundation.URLSession`, and must never read `Date()` directly — the current date is always injected. This is what makes them exhaustively testable.
- Verdict bands, thresholds and penalties are **copied verbatim from the spec**. Do not round, reinterpret, or "improve" them.
- UI copy in English. Brand palette: orange `#e8562f`, navy `#171c3a`, lime `#d8fb45`, cream `#faf3df`, ink `#17130e`, amber `#e0a32e`.
- Commit after every task.

---

## File Structure

| File | Responsibility |
|---|---|
| `RescueTriage.xcodeproj/project.pbxproj` | App + test target, synchronized file groups |
| `RescueTriage/RescueTriageApp.swift` | Entry point |
| `RescueTriage/Models/ProductCategory.swift` | Category enum + per-category thresholds |
| `RescueTriage/Models/Declaration.swift` | `ExpiryKind`, `RejectReason`, `SupplierDeclaration` |
| `RescueTriage/Models/Observation.swift` | `PackagingIntegrity`, `Discrepancy`, `ScanObservation` |
| `RescueTriage/Models/Verdict.swift` | `Outcome`, `VerdictReason`, `Verdict` |
| `RescueTriage/Rules/SafetyRules.swift` | Expiry, cold chain, temperature — pure |
| `RescueTriage/Rules/ScoreCalculator.swift` | Score from observation + rule penalties — pure |
| `RescueTriage/Rules/VerdictEngine.swift` | Precedence fusion — pure |
| `RescueTriage/Vision/GeminiClient.swift` | HTTP call, response schema, decoding |
| `RescueTriage/Store/KeychainStore.swift` | API key read/write/delete |
| `RescueTriage/Store/SessionStore.swift` | Queue, tally, observable state |
| `RescueTriage/Theme/RescuePalette.swift` | Brand colours |
| `RescueTriage/Views/*.swift` | One file per screen |
| `RescueTriage/Resources/DemoBatches.json` | The twelve demo batches |
| `RescueTriageTests/*.swift` | One test file per rule component |

---

### Task 1: Xcode project that builds and runs a test

The riskiest step in the whole plan: a hand-written `project.pbxproj`. Everything else depends on it, so it is verified by an actual build and an actual test run before anything else is written.

**Files:**
- Create: `RescueTriage.xcodeproj/project.pbxproj`
- Create: `RescueTriage.xcodeproj/xcshareddata/xcschemes/RescueTriage.xcscheme`
- Create: `RescueTriage/RescueTriageApp.swift`
- Create: `RescueTriage/Assets.xcassets/Contents.json`, `.../AppIcon.appiconset/Contents.json`, `.../AccentColor.colorset/Contents.json`
- Test: `RescueTriageTests/SmokeTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: a scheme named `RescueTriage` buildable with
  `xcodebuild -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17'`, and a test target `RescueTriageTests` that runs under `xcodebuild test`.

`objectVersion = 77` with `PBXFileSystemSynchronizedRootGroup` (Xcode 16+) means files added to `RescueTriage/` on disk are compiled automatically — no pbxproj edit per file. Every later task therefore only writes Swift files.

- [ ] **Step 1: Confirm a simulator runtime exists**

Run: `xcrun simctl list runtimes | grep iOS`
Expected: at least one `iOS 26.x` line. If empty, the runtime download is unfinished — run `xcodebuild -downloadPlatform iOS` and wait. Do not start this task without a runtime; every verification step below needs one.

- [ ] **Step 2: Write the app entry point**

```swift
// RescueTriage/RescueTriageApp.swift
import SwiftUI

@main
struct RescueTriageApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Rescue Triage")
        }
    }
}
```

- [ ] **Step 3: Write the asset catalogue stubs**

`RescueTriage/Assets.xcassets/Contents.json`:

```json
{ "info" : { "author" : "xcode", "version" : 1 } }
```

`RescueTriage/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images" : [ { "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" } ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`RescueTriage/Assets.xcassets/AccentColor.colorset/Contents.json`:

```json
{
  "colors" : [ {
    "color" : { "color-space" : "srgb", "components" : { "alpha" : "1.000", "blue" : "0x2F", "green" : "0x56", "red" : "0xE8" } },
    "idiom" : "universal"
  } ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 4: Write the failing smoke test**

```swift
// RescueTriageTests/SmokeTests.swift
import XCTest
@testable import RescueTriage

final class SmokeTests: XCTestCase {
    func test_targetLinksAndRuns() {
        XCTAssertEqual(2 + 2, 4)
    }
}
```

- [ ] **Step 5: Write `project.pbxproj`**

Write the file below verbatim. The UUIDs are fixed 24-character hex strings; they only need to be internally consistent.

```
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {};
	objectVersion = 77;
	objects = {

/* Begin PBXFileSystemSynchronizedRootGroup section */
		A0000000000000000000001A /* RescueTriage */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = RescueTriage;
			sourceTree = "<group>";
		};
		A0000000000000000000001B /* RescueTriageTests */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = RescueTriageTests;
			sourceTree = "<group>";
		};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXBuildFile section */
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		A00000000000000000000010 /* RescueTriage.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = RescueTriage.app; sourceTree = BUILT_PRODUCTS_DIR; };
		A00000000000000000000011 /* RescueTriageTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = RescueTriageTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		A00000000000000000000020 = { isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
		A00000000000000000000021 = { isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		A00000000000000000000030 = {
			isa = PBXGroup;
			children = (
				A0000000000000000000001A /* RescueTriage */,
				A0000000000000000000001B /* RescueTriageTests */,
				A00000000000000000000031 /* Products */,
			);
			sourceTree = "<group>";
		};
		A00000000000000000000031 /* Products */ = {
			isa = PBXGroup;
			children = (
				A00000000000000000000010 /* RescueTriage.app */,
				A00000000000000000000011 /* RescueTriageTests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		A00000000000000000000040 /* RescueTriage */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = A00000000000000000000050;
			buildPhases = (
				A00000000000000000000060,
				A00000000000000000000020,
				A00000000000000000000061,
			);
			buildRules = ();
			dependencies = ();
			fileSystemSynchronizedGroups = ( A0000000000000000000001A );
			name = RescueTriage;
			productName = RescueTriage;
			productReference = A00000000000000000000010;
			productType = "com.apple.product-type.application";
		};
		A00000000000000000000041 /* RescueTriageTests */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = A00000000000000000000051;
			buildPhases = (
				A00000000000000000000062,
				A00000000000000000000021,
			);
			buildRules = ();
			dependencies = ( A00000000000000000000070 );
			fileSystemSynchronizedGroups = ( A0000000000000000000001B );
			name = RescueTriageTests;
			productName = RescueTriageTests;
			productReference = A00000000000000000000011;
			productType = "com.apple.product-type.bundle.unit-test";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		A00000000000000000000001 = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 2660;
				LastUpgradeCheck = 2660;
				TargetAttributes = {
					A00000000000000000000040 = { CreatedOnToolsVersion = 26.6; };
					A00000000000000000000041 = { CreatedOnToolsVersion = 26.6; TestTargetID = A00000000000000000000040; };
				};
			};
			buildConfigurationList = A00000000000000000000052;
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = ( en, Base );
			mainGroup = A00000000000000000000030;
			minimizedProjectReferenceProxies = 1;
			preferredProjectObjectVersion = 77;
			productRefGroup = A00000000000000000000031;
			projectDirPath = "";
			projectRoot = "";
			targets = ( A00000000000000000000040, A00000000000000000000041 );
		};
/* End PBXProject section */

/* Begin PBXSourcesBuildPhase section */
		A00000000000000000000060 = { isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
		A00000000000000000000062 = { isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
/* End PBXSourcesBuildPhase section */

/* Begin PBXResourcesBuildPhase section */
		A00000000000000000000061 = { isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
/* End PBXResourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		A00000000000000000000070 = {
			isa = PBXTargetDependency;
			target = A00000000000000000000040;
			targetProxy = A00000000000000000000071;
		};
/* End PBXTargetDependency section */

/* Begin PBXContainerItemProxy section */
		A00000000000000000000071 = {
			isa = PBXContainerItemProxy;
			containerPortal = A00000000000000000000001;
			proxyType = 1;
			remoteGlobalIDString = A00000000000000000000040;
			remoteInfo = RescueTriage;
		};
/* End PBXContainerItemProxy section */

/* Begin XCBuildConfiguration section */
		A00000000000000000000080 /* Debug project */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = ( "DEBUG=1", "$(inherited)" );
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.0;
			};
			name = Debug;
		};
		A00000000000000000000081 /* Release project */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_VERSION = 5.0;
				VALIDATE_PRODUCT = YES;
			};
			name = Release;
		};
		A00000000000000000000082 /* Debug app */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_NSCameraUsageDescription = "Rescue Triage photographs the product to check it against the supplier's declaration.";
				INFOPLIST_KEY_NSPhotoLibraryUsageDescription = "Pick an existing product photo to run through triage.";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait";
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = lv.rescue.triage;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				TARGETED_DEVICE_FAMILY = 1;
			};
			name = Debug;
		};
		A00000000000000000000083 /* Release app */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_NSCameraUsageDescription = "Rescue Triage photographs the product to check it against the supplier's declaration.";
				INFOPLIST_KEY_NSPhotoLibraryUsageDescription = "Pick an existing product photo to run through triage.";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait";
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = lv.rescue.triage;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				TARGETED_DEVICE_FAMILY = 1;
			};
			name = Release;
		};
		A00000000000000000000084 /* Debug tests */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = lv.rescue.triage.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				TARGETED_DEVICE_FAMILY = 1;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/RescueTriage.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/RescueTriage";
			};
			name = Debug;
		};
		A00000000000000000000085 /* Release tests */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = lv.rescue.triage.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				TARGETED_DEVICE_FAMILY = 1;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/RescueTriage.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/RescueTriage";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		A00000000000000000000052 = {
			isa = XCConfigurationList;
			buildConfigurations = ( A00000000000000000000080, A00000000000000000000081 );
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		A00000000000000000000050 = {
			isa = XCConfigurationList;
			buildConfigurations = ( A00000000000000000000082, A00000000000000000000083 );
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		A00000000000000000000051 = {
			isa = XCConfigurationList;
			buildConfigurations = ( A00000000000000000000084, A00000000000000000000085 );
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = A00000000000000000000001;
}
```

- [ ] **Step 6: Write the shared scheme**

`RescueTriage.xcodeproj/xcshareddata/xcschemes/RescueTriage.xcscheme`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "2660" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "A00000000000000000000040" BuildableName = "RescueTriage.app" BlueprintName = "RescueTriage" ReferencedContainer = "container:RescueTriage.xcodeproj"/>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference skipped = "NO">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "A00000000000000000000041" BuildableName = "RescueTriageTests.xctest" BlueprintName = "RescueTriageTests" ReferencedContainer = "container:RescueTriage.xcodeproj"/>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "A00000000000000000000040" BuildableName = "RescueTriage.app" BlueprintName = "RescueTriage" ReferencedContainer = "container:RescueTriage.xcodeproj"/>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "A00000000000000000000040" BuildableName = "RescueTriage.app" BlueprintName = "RescueTriage" ReferencedContainer = "container:RescueTriage.xcodeproj"/>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug"/>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"/>
</Scheme>
```

- [ ] **Step 7: Verify the project parses**

Run: `xcodebuild -list -project RescueTriage.xcodeproj`
Expected: targets `RescueTriage` and `RescueTriageTests`, scheme `RescueTriage`.
If it reports a parse error, the pbxproj is malformed — fix it before going further; nothing downstream can work.

- [ ] **Step 8: Run the test to verify the whole toolchain works**

Run:
```bash
xcodebuild test -scheme RescueTriage \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`. If the named simulator does not exist, list them with `xcrun simctl list devices available` and substitute a real name.

- [ ] **Step 9: Commit**

```bash
git add RescueTriage.xcodeproj RescueTriage RescueTriageTests
git commit -m "Xcode project skeleton that builds and tests"
```

---

### Task 2: Domain models

**Files:**
- Create: `RescueTriage/Models/ProductCategory.swift`
- Create: `RescueTriage/Models/Declaration.swift`
- Create: `RescueTriage/Models/Observation.swift`
- Create: `RescueTriage/Models/Verdict.swift`
- Test: `RescueTriageTests/ModelTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `ProductCategory`, `ExpiryKind`, `RejectReason` (with `.isCosmetic` and `.label`), `SupplierDeclaration`, `PackagingIntegrity`, `Discrepancy`, `ScanObservation`, `Outcome` (with `.isWorse(than:)`), `VerdictReason`, `Verdict`.

Note on `Codable`: `Discrepancy`, `VerdictReason` and `SupplierDeclaration` carry a generated `UUID` for `Identifiable`, excluded from `CodingKeys` so that Gemini's JSON and `DemoBatches.json` — neither of which supplies an `id` — still decode.

- [ ] **Step 1: Write the failing tests**

```swift
// RescueTriageTests/ModelTests.swift
import XCTest
@testable import RescueTriage

final class ModelTests: XCTestCase {

    func test_coldChainGapIsTheOnlyNonCosmeticReason() {
        let nonCosmetic = RejectReason.allCases.filter { !$0.isCosmetic }
        XCTAssertEqual(nonCosmetic, [.coldChainGap])
    }

    func test_everyReasonHasANonEmptyLabel() {
        for reason in RejectReason.allCases {
            XCTAssertFalse(reason.label.isEmpty, "\(reason) has no label")
        }
    }

    func test_outcomeOrdering() {
        XCTAssertTrue(Outcome.rejected.isWorse(than: .heldForHuman))
        XCTAssertTrue(Outcome.heldForHuman.isWorse(than: .accepted))
        XCTAssertFalse(Outcome.accepted.isWorse(than: .rejected))
        XCTAssertFalse(Outcome.accepted.isWorse(than: .accepted))
    }

    func test_observationDecodesGeminiShapedJSONWithoutIDs() throws {
        let json = """
        {
          "damageSeverity": 2,
          "packagingIntegrity": "dented",
          "spoilageSigns": [],
          "labelLegible": true,
          "observedProduct": "yoghurt case",
          "observedQuantityPlausible": true,
          "discrepancies": [
            { "field": "packaging", "declared": "slight dent", "observed": "corner torn", "severity": "major" }
          ],
          "visualNotes": "Outer carton scuffed."
        }
        """.data(using: .utf8)!

        let observation = try JSONDecoder().decode(ScanObservation.self, from: json)
        XCTAssertEqual(observation.damageSeverity, 2)
        XCTAssertEqual(observation.packagingIntegrity, .dented)
        XCTAssertEqual(observation.discrepancies.count, 1)
        XCTAssertEqual(observation.discrepancies[0].severity, .major)
    }

    func test_coldSensitiveCategories() {
        XCTAssertTrue(ProductCategory.dairy.isColdSensitive)
        XCTAssertTrue(ProductCategory.meatFish.isColdSensitive)
        XCTAssertTrue(ProductCategory.chilledPrepared.isColdSensitive)
        XCTAssertTrue(ProductCategory.frozen.isColdSensitive)
        XCTAssertFalse(ProductCategory.bakery.isColdSensitive)
        XCTAssertFalse(ProductCategory.produce.isColdSensitive)
        XCTAssertFalse(ProductCategory.ambient.isColdSensitive)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20`
Expected: compile failure — `cannot find 'RejectReason' in scope`.

- [ ] **Step 3: Write `ProductCategory.swift`**

```swift
// RescueTriage/Models/ProductCategory.swift
import Foundation

/// What kind of food this is. Drives every cold-chain and temperature threshold,
/// so the cases are deliberately coarse — they match how a supplier's reject list
/// is actually written, not a nutritionist's taxonomy.
enum ProductCategory: String, Codable, CaseIterable, Identifiable {
    case dairy
    case bakery
    case produce
    case meatFish
    case chilledPrepared
    case frozen
    case ambient

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dairy: "Dairy"
        case .bakery: "Bakery"
        case .produce: "Fruit & veg"
        case .meatFish: "Meat & fish"
        case .chilledPrepared: "Chilled prepared"
        case .frozen: "Frozen"
        case .ambient: "Ambient"
        }
    }

    /// Bakery, produce and ambient goods have no cold chain to break.
    var isColdSensitive: Bool {
        switch self {
        case .dairy, .meatFish, .chilledPrepared, .frozen: true
        case .bakery, .produce, .ambient: false
        }
    }
}
```

- [ ] **Step 4: Write `Declaration.swift`**

```swift
// RescueTriage/Models/Declaration.swift
import Foundation

/// Use-by (DLC) versus best-before (DDM). This is the sharpest line in the
/// domain: a passed use-by date is a food-safety rejection with no appeal, while
/// a passed best-before date is Rescue's entire business model. There is
/// deliberately no default value — every declaration must state which it is.
enum ExpiryKind: String, Codable, CaseIterable, Identifiable {
    case useBy
    case bestBefore

    var id: String { rawValue }

    var label: String {
        switch self {
        case .useBy: "Use by (DLC)"
        case .bestBefore: "Best before (DDM)"
        }
    }
}

/// Why the supermarket refused the goods. Vocabulary lifted from the concept
/// site's triage log so the app and the website tell the same story.
enum RejectReason: String, Codable, CaseIterable, Identifiable {
    case endOfDayBake
    case hailMarks
    case calibreOut
    case oldPackaging
    case sellByTomorrow
    case shortShelfLife
    case discontinued
    case postPromoOverstock
    case spottySkin
    case overproduction
    case dentedOuterBox
    case holidaySurplus
    case packagingRedesign
    case shortDatedBatch
    case gradedOutForShape
    case coldChainGap

    var id: String { rawValue }

    /// Cosmetic and commercial reasons cost nothing at all in the score. What a
    /// supermarket throws away for looking wrong is exactly what Rescue sells.
    /// A broken cold chain is the one reason that is about safety, not appearance.
    var isCosmetic: Bool { self != .coldChainGap }

    var label: String {
        switch self {
        case .endOfDayBake: "End-of-day bake"
        case .hailMarks: "Hail marks"
        case .calibreOut: "Out of calibre"
        case .oldPackaging: "Old packaging design"
        case .sellByTomorrow: "Sell-by tomorrow"
        case .shortShelfLife: "Short shelf life left"
        case .discontinued: "Discontinued line"
        case .postPromoOverstock: "Post-promo overstock"
        case .spottySkin: "Spotty skin"
        case .overproduction: "Kitchen overproduction"
        case .dentedOuterBox: "Dented outer box"
        case .holidaySurplus: "Holiday surplus"
        case .packagingRedesign: "Packaging redesign"
        case .shortDatedBatch: "Short-dated batch"
        case .gradedOutForShape: "Graded out for shape"
        case .coldChainGap: "Cold-chain gap"
        }
    }
}

/// What the supplier claims about the goods. Everything here is assertion, not
/// fact — checking it against the photo is the whole point of the app.
struct SupplierDeclaration: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var supplier: String
    var productName: String
    var category: ProductCategory
    var quantity: Double
    var unit: String
    var arrivalDate: Date
    var expiryDate: Date
    var expiryKind: ExpiryKind
    var declaredReason: RejectReason
    var coldChainGapMinutes: Int?
    var storageTempC: Double?
    var retailUnitPrice: Decimal
    var estimatedWeightKg: Double

    private enum CodingKeys: String, CodingKey {
        case supplier, productName, category, quantity, unit
        case arrivalDate, expiryDate, expiryKind, declaredReason
        case coldChainGapMinutes, storageTempC, retailUnitPrice, estimatedWeightKg
    }

    var summaryLine: String {
        "\(formattedQuantity) \(unit) · \(declaredReason.label)"
    }

    var formattedQuantity: String {
        quantity == quantity.rounded()
            ? String(Int(quantity))
            : String(format: "%.1f", quantity)
    }
}
```

- [ ] **Step 5: Write `Observation.swift`**

```swift
// RescueTriage/Models/Observation.swift
import Foundation

enum PackagingIntegrity: String, Codable, CaseIterable {
    case intact
    case dented
    case compromised
    case breached

    var label: String {
        switch self {
        case .intact: "Intact"
        case .dented: "Dented"
        case .compromised: "Compromised"
        case .breached: "Breached"
        }
    }
}

/// A contradiction between what the supplier declared and what the photo shows.
/// A supplier who is wrong — or lying — earns a human look, never a rubber stamp.
struct Discrepancy: Codable, Equatable, Identifiable {
    enum Severity: String, Codable {
        case minor
        case major
    }

    var id: UUID = UUID()
    var field: String
    var declared: String
    var observed: String
    var severity: Severity

    private enum CodingKeys: String, CodingKey {
        case field, declared, observed, severity
    }
}

/// What the model saw in the photograph. Description only — no judgement.
/// The verdict is never Gemini's to make.
struct ScanObservation: Codable, Equatable {
    var damageSeverity: Int
    var packagingIntegrity: PackagingIntegrity
    var spoilageSigns: [String]
    var labelLegible: Bool
    var observedProduct: String
    var observedQuantityPlausible: Bool
    var discrepancies: [Discrepancy]
    var visualNotes: String

    /// Used when Gemini could not be reached: describes nothing, penalises
    /// nothing, and lets the safety rules stand on their own.
    static let unavailable = ScanObservation(
        damageSeverity: 0,
        packagingIntegrity: .intact,
        spoilageSigns: [],
        labelLegible: true,
        observedProduct: "",
        observedQuantityPlausible: true,
        discrepancies: [],
        visualNotes: ""
    )
}
```

- [ ] **Step 6: Write `Verdict.swift`**

```swift
// RescueTriage/Models/Verdict.swift
import Foundation

enum Outcome: String, Codable, CaseIterable {
    case accepted
    case heldForHuman
    case rejected

    var label: String {
        switch self {
        case .accepted: "ACCEPTED"
        case .heldForHuman: "HELD"
        case .rejected: "REJECTED"
        }
    }

    /// Severity ranking. Rules may only ever push a verdict further down this
    /// order, never back up it.
    var severity: Int {
        switch self {
        case .accepted: 0
        case .heldForHuman: 1
        case .rejected: 2
        }
    }

    func isWorse(than other: Outcome) -> Bool { severity > other.severity }
}

struct VerdictReason: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var code: String
    var label: String

    private enum CodingKeys: String, CodingKey { case code, label }

    init(_ code: String, _ label: String) {
        self.code = code
        self.label = label
    }
}

struct Verdict: Codable, Equatable {
    var outcome: Outcome
    var score: Double
    var reasons: [VerdictReason]
    var discrepancies: [Discrepancy]
    /// True when a food-safety rule forced the rejection. Nothing overrides it.
    var vetoed: Bool
    /// Set when an operator overruled a held verdict.
    var humanOverride: Outcome?
    var sellToday: Bool
    /// True when Gemini was unreachable and only the regulatory rules ran.
    var partial: Bool

    /// What the session tally counts: the human's call when there was one.
    var effectiveOutcome: Outcome { humanOverride ?? outcome }
}
```

- [ ] **Step 7: Run the tests**

Run: `xcodebuild test -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add RescueTriage/Models RescueTriageTests/ModelTests.swift
git commit -m "Domain models for declaration, observation and verdict"
```

---

### Task 3: Expiry rules

**Files:**
- Create: `RescueTriage/Rules/SafetyRules.swift`
- Test: `RescueTriageTests/ExpiryRuleTests.swift`

**Interfaces:**
- Consumes: `SupplierDeclaration`, `ExpiryKind`, `VerdictReason` from Task 2.
- Produces: `RuleFloor` (`.none`/`.hold`/`.reject`), `RuleAssessment` (`floor`, `vetoed`, `penalty`, `sellToday`, `reasons`) and `SafetyRules.expiry(declaration:now:calendar:) -> RuleAssessment`.

The current date is a parameter, never `Date()`. Without that, every boundary test would be unwritable.

- [ ] **Step 1: Write the failing tests**

```swift
// RescueTriageTests/ExpiryRuleTests.swift
import XCTest
@testable import RescueTriage

final class ExpiryRuleTests: XCTestCase {

    private let now = ISO8601DateFormatter().date(from: "2026-09-13T09:00:00Z")!
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func declaration(_ kind: ExpiryKind, daysFromNow: Int) -> SupplierDeclaration {
        SupplierDeclaration(
            supplier: "Rimi", productName: "Test", category: .ambient,
            quantity: 1, unit: "case",
            arrivalDate: now, expiryDate: calendar.date(byAdding: .day, value: daysFromNow, to: now)!,
            expiryKind: kind, declaredReason: .discontinued,
            coldChainGapMinutes: nil, storageTempC: nil,
            retailUnitPrice: 1, estimatedWeightKg: 1
        )
    }

    private func assess(_ kind: ExpiryKind, _ days: Int) -> RuleAssessment {
        SafetyRules.expiry(declaration: declaration(kind, daysFromNow: days), now: now, calendar: calendar)
    }

    // --- Use-by (DLC) ---

    func test_useByPassedYesterday_isVetoedRejection() {
        let a = assess(.useBy, -1)
        XCTAssertEqual(a.floor, .reject)
        XCTAssertTrue(a.vetoed)
    }

    func test_useByToday_isAcceptedAndFlaggedSellToday() {
        let a = assess(.useBy, 0)
        XCTAssertEqual(a.floor, .none)
        XCTAssertFalse(a.vetoed)
        XCTAssertTrue(a.sellToday)
        XCTAssertEqual(a.penalty, 1.0, accuracy: 0.001)
    }

    func test_useByTomorrow_isClean() {
        let a = assess(.useBy, 1)
        XCTAssertEqual(a.floor, .none)
        XCTAssertEqual(a.penalty, 0.0, accuracy: 0.001)
        XCTAssertFalse(a.sellToday)
    }

    // --- Best-before (DDM) ---

    func test_bestBeforeNotYetPassed_isClean() {
        let a = assess(.bestBefore, 5)
        XCTAssertEqual(a.floor, .none)
        XCTAssertEqual(a.penalty, 0.0, accuracy: 0.001)
    }

    func test_bestBeforeOneDayOver_isAcceptedWithSmallPenalty() {
        let a = assess(.bestBefore, -1)
        XCTAssertEqual(a.floor, .none)
        XCTAssertEqual(a.penalty, 0.5, accuracy: 0.001)
    }

    func test_bestBefore30DaysOver_isStillAccepted() {
        let a = assess(.bestBefore, -30)
        XCTAssertEqual(a.floor, .none)
        XCTAssertEqual(a.penalty, 0.5, accuracy: 0.001)
    }

    func test_bestBefore31DaysOver_isHeld() {
        let a = assess(.bestBefore, -31)
        XCTAssertEqual(a.floor, .hold)
        XCTAssertEqual(a.penalty, 1.0, accuracy: 0.001)
    }

    func test_bestBefore90DaysOver_isHeld() {
        XCTAssertEqual(assess(.bestBefore, -90).floor, .hold)
    }

    func test_bestBefore91DaysOver_isRejectedButNotVetoed() {
        let a = assess(.bestBefore, -91)
        XCTAssertEqual(a.floor, .reject)
        XCTAssertFalse(a.vetoed, "unsellable quality is not a food-safety veto")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RescueTriageTests/ExpiryRuleTests 2>&1 | tail -20`
Expected: compile failure — `cannot find 'SafetyRules' in scope`.

- [ ] **Step 3: Write `SafetyRules.swift` with the expiry rule**

```swift
// RescueTriage/Rules/SafetyRules.swift
import Foundation

/// The worst outcome a rule insists on. Rules set floors; they never set
/// ceilings. A floor of `.hold` means "no better than held".
enum RuleFloor: Int, Equatable {
    case none = 0
    case hold = 1
    case reject = 2

    var asOutcome: Outcome? {
        switch self {
        case .none: nil
        case .hold: .heldForHuman
        case .reject: .rejected
        }
    }
}

/// One rule's finding: how far it forces the verdict down, whether that force is
/// a food-safety veto, what it costs in score, and why.
struct RuleAssessment: Equatable {
    var floor: RuleFloor = .none
    var vetoed: Bool = false
    var penalty: Double = 0
    var sellToday: Bool = false
    var reasons: [VerdictReason] = []

    static let clean = RuleAssessment()

    /// Combine findings: worst floor wins, any veto sticks, penalties add up.
    static func merge(_ assessments: [RuleAssessment]) -> RuleAssessment {
        RuleAssessment(
            floor: assessments.map(\.floor).max(by: { $0.rawValue < $1.rawValue }) ?? .none,
            vetoed: assessments.contains(where: \.vetoed),
            penalty: assessments.reduce(0) { $0 + $1.penalty },
            sellToday: assessments.contains(where: \.sellToday),
            reasons: assessments.flatMap(\.reasons)
        )
    }
}

/// Every date, temperature and cold-chain decision. Pure functions: no network,
/// no disk, no ambient clock. That is what makes the boundaries testable, and
/// it is why these rules — not the language model — hold the veto.
enum SafetyRules {

    // MARK: Expiry

    static func expiry(
        declaration: SupplierDeclaration,
        now: Date,
        calendar: Calendar = .current
    ) -> RuleAssessment {
        let today = calendar.startOfDay(for: now)
        let expiry = calendar.startOfDay(for: declaration.expiryDate)
        let daysLeft = calendar.dateComponents([.day], from: today, to: expiry).day ?? 0

        switch declaration.expiryKind {
        case .useBy:
            if daysLeft < 0 {
                return RuleAssessment(
                    floor: .reject,
                    vetoed: true,
                    reasons: [VerdictReason("expiry.useBy.passed",
                                            "Use-by date passed \(-daysLeft) day(s) ago — food safety, no appeal")]
                )
            }
            if daysLeft == 0 {
                return RuleAssessment(
                    penalty: 1.0,
                    sellToday: true,
                    reasons: [VerdictReason("expiry.useBy.today", "Use-by is today — sell today")]
                )
            }
            return .clean

        case .bestBefore:
            guard daysLeft < 0 else { return .clean }
            let daysOver = -daysLeft
            let blocks = Int(ceil(Double(daysOver) / 30.0))
            let penalty = Double(blocks) * 0.5

            if daysOver > 90 {
                return RuleAssessment(
                    floor: .reject,
                    vetoed: false,
                    penalty: penalty,
                    reasons: [VerdictReason("expiry.bestBefore.unsellable",
                                            "Best-before passed \(daysOver) days ago — past sellable quality")]
                )
            }
            if daysOver > 30 {
                return RuleAssessment(
                    floor: .hold,
                    penalty: penalty,
                    reasons: [VerdictReason("expiry.bestBefore.long",
                                            "Best-before passed \(daysOver) days ago — needs a taste call")]
                )
            }
            return RuleAssessment(
                penalty: penalty,
                reasons: [VerdictReason("expiry.bestBefore.short",
                                        "Best-before passed \(daysOver) day(s) ago — legal to sell, and our business")]
            )
        }
    }
}
```

- [ ] **Step 4: Run the tests**

Run: `xcodebuild test -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RescueTriageTests/ExpiryRuleTests 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **`, 9 tests.

- [ ] **Step 5: Commit**

```bash
git add RescueTriage/Rules/SafetyRules.swift RescueTriageTests/ExpiryRuleTests.swift
git commit -m "Expiry rules: use-by veto, best-before tiers"
```

---

### Task 4: Cold-chain and temperature rules

**Files:**
- Modify: `RescueTriage/Rules/SafetyRules.swift` (append two functions to the `SafetyRules` enum)
- Test: `RescueTriageTests/ColdChainRuleTests.swift`

**Interfaces:**
- Consumes: `RuleAssessment`, `ProductCategory` from Tasks 2–3.
- Produces: `SafetyRules.coldChain(category:gapMinutes:)` and `SafetyRules.temperature(category:tempC:)`, both returning `RuleAssessment`.

- [ ] **Step 1: Write the failing tests**

```swift
// RescueTriageTests/ColdChainRuleTests.swift
import XCTest
@testable import RescueTriage

final class ColdChainRuleTests: XCTestCase {

    private func gap(_ category: ProductCategory, _ minutes: Int?) -> RuleAssessment {
        SafetyRules.coldChain(category: category, gapMinutes: minutes)
    }

    private func temp(_ category: ProductCategory, _ celsius: Double?) -> RuleAssessment {
        SafetyRules.temperature(category: category, tempC: celsius)
    }

    // --- Cold chain, meat & fish: zero tolerance, hold to 15, reject past it ---

    func test_meat_noGapDeclared_isClean() {
        XCTAssertEqual(gap(.meatFish, nil), .clean)
        XCTAssertEqual(gap(.meatFish, 0).floor, .none)
    }

    func test_meat_oneMinute_isHeld() {
        XCTAssertEqual(gap(.meatFish, 1).floor, .hold)
    }

    func test_meat_fifteenMinutes_isHeld() {
        XCTAssertEqual(gap(.meatFish, 15).floor, .hold)
    }

    func test_meat_sixteenMinutes_isVetoedRejection() {
        let a = gap(.meatFish, 16)
        XCTAssertEqual(a.floor, .reject)
        XCTAssertTrue(a.vetoed)
    }

    // --- Cold chain, dairy and chilled prepared: 15 clean, 30 held, past that rejected ---

    func test_dairy_fifteenMinutes_isClean() {
        XCTAssertEqual(gap(.dairy, 15).floor, .none)
    }

    func test_dairy_sixteenMinutes_isHeld() {
        XCTAssertEqual(gap(.dairy, 16).floor, .hold)
    }

    func test_dairy_thirtyMinutes_isHeld() {
        XCTAssertEqual(gap(.dairy, 30).floor, .hold)
    }

    func test_dairy_fortyMinutes_isVetoedRejection() {
        let a = gap(.dairy, 40)
        XCTAssertEqual(a.floor, .reject)
        XCTAssertTrue(a.vetoed, "the Sky&More yoghurt case")
    }

    func test_chilledPrepared_followsTheDairyThresholds() {
        XCTAssertEqual(gap(.chilledPrepared, 30).floor, .hold)
        XCTAssertEqual(gap(.chilledPrepared, 31).floor, .reject)
    }

    // --- Cold chain, frozen: zero tolerance, hold to 20 ---

    func test_frozen_twentyMinutes_isHeld() {
        XCTAssertEqual(gap(.frozen, 20).floor, .hold)
    }

    func test_frozen_twentyOneMinutes_isVetoedRejection() {
        XCTAssertTrue(gap(.frozen, 21).vetoed)
    }

    // --- Cold chain does not apply to ambient goods ---

    func test_ambientAndProduceAndBakery_ignoreColdChainEntirely() {
        XCTAssertEqual(gap(.ambient, 500), .clean)
        XCTAssertEqual(gap(.produce, 500), .clean)
        XCTAssertEqual(gap(.bakery, 500), .clean)
    }

    // --- Penalty: one point per started 10 minutes, while not vetoed ---

    func test_toleratedGapCostsOnePointPerStartedTenMinutes() {
        XCTAssertEqual(gap(.dairy, 5).penalty, 1.0, accuracy: 0.001)
        XCTAssertEqual(gap(.dairy, 10).penalty, 1.0, accuracy: 0.001)
        XCTAssertEqual(gap(.dairy, 11).penalty, 2.0, accuracy: 0.001)
    }

    // --- Temperature ---

    func test_chilledAtFourDegrees_isClean() {
        XCTAssertEqual(temp(.dairy, 4.0).floor, .none)
    }

    func test_chilledAtSixDegrees_isHeld() {
        XCTAssertEqual(temp(.dairy, 6.0).floor, .hold)
    }

    func test_chilledAtNineDegrees_isVetoedRejection() {
        let a = temp(.dairy, 9.0)
        XCTAssertEqual(a.floor, .reject)
        XCTAssertTrue(a.vetoed)
    }

    func test_frozenAtMinusEighteen_isClean() {
        XCTAssertEqual(temp(.frozen, -18.0).floor, .none)
    }

    func test_frozenAtMinusFifteen_isHeld() {
        XCTAssertEqual(temp(.frozen, -15.0).floor, .hold)
    }

    func test_frozenAtMinusTen_isVetoedRejection() {
        XCTAssertTrue(temp(.frozen, -10.0).vetoed)
    }

    func test_ambientTemperatureIsIgnored() {
        XCTAssertEqual(temp(.ambient, 25.0), .clean)
        XCTAssertEqual(temp(.bakery, 25.0), .clean)
    }

    func test_noTemperatureDeclared_isClean() {
        XCTAssertEqual(temp(.dairy, nil), .clean)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RescueTriageTests/ColdChainRuleTests 2>&1 | tail -20`
Expected: compile failure — no `coldChain` member.

- [ ] **Step 3: Append the two rules to `SafetyRules.swift`**

Insert inside `enum SafetyRules`, after `expiry`:

```swift
    // MARK: Cold chain

    /// Minutes of declared cold-chain break the category tolerates before the
    /// verdict is held, and before it is refused outright.
    private static func coldChainLimits(for category: ProductCategory) -> (tolerated: Int, held: Int)? {
        switch category {
        case .meatFish: (tolerated: 0, held: 15)
        case .dairy, .chilledPrepared: (tolerated: 15, held: 30)
        case .frozen: (tolerated: 0, held: 20)
        case .bakery, .produce, .ambient: nil
        }
    }

    static func coldChain(category: ProductCategory, gapMinutes: Int?) -> RuleAssessment {
        guard let limits = coldChainLimits(for: category),
              let gap = gapMinutes, gap > 0 else { return .clean }

        let penalty = Double(Int(ceil(Double(gap) / 10.0)))

        if gap > limits.held {
            return RuleAssessment(
                floor: .reject,
                vetoed: true,
                reasons: [VerdictReason("coldChain.broken",
                                        "\(gap) min cold-chain gap on \(category.label.lowercased()) — over the \(limits.held) min limit")]
            )
        }
        if gap > limits.tolerated {
            return RuleAssessment(
                floor: .hold,
                penalty: penalty,
                reasons: [VerdictReason("coldChain.marginal",
                                        "\(gap) min cold-chain gap — inside the limit but needs a human look")]
            )
        }
        return RuleAssessment(
            penalty: penalty,
            reasons: [VerdictReason("coldChain.tolerated", "\(gap) min cold-chain gap — within tolerance")]
        )
    }

    // MARK: Storage temperature

    /// Upper bound for compliant storage, and the bound past which it is refused.
    private static func temperatureLimits(for category: ProductCategory) -> (compliant: Double, held: Double)? {
        switch category {
        case .dairy, .chilledPrepared, .meatFish: (compliant: 4.0, held: 8.0)
        case .frozen: (compliant: -18.0, held: -12.0)
        case .bakery, .produce, .ambient: nil
        }
    }

    static func temperature(category: ProductCategory, tempC: Double?) -> RuleAssessment {
        guard let limits = temperatureLimits(for: category),
              let temp = tempC else { return .clean }

        let formatted = String(format: "%.1f", temp)

        if temp > limits.held {
            return RuleAssessment(
                floor: .reject,
                vetoed: true,
                reasons: [VerdictReason("temperature.breach",
                                        "Stored at \(formatted) °C — past the \(String(format: "%.0f", limits.held)) °C limit")]
            )
        }
        if temp > limits.compliant {
            return RuleAssessment(
                floor: .hold,
                penalty: 1.0,
                reasons: [VerdictReason("temperature.marginal",
                                        "Stored at \(formatted) °C — above \(String(format: "%.0f", limits.compliant)) °C")]
            )
        }
        return .clean
    }
```

- [ ] **Step 4: Run the tests**

Run: `xcodebuild test -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RescueTriageTests/ColdChainRuleTests 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **`, 21 tests.

- [ ] **Step 5: Commit**

```bash
git add RescueTriage/Rules/SafetyRules.swift RescueTriageTests/ColdChainRuleTests.swift
git commit -m "Cold-chain and storage-temperature rules with per-category thresholds"
```

---

### Task 5: Score calculation

**Files:**
- Create: `RescueTriage/Rules/ScoreCalculator.swift`
- Test: `RescueTriageTests/ScoreCalculatorTests.swift`

**Interfaces:**
- Consumes: `ScanObservation`, `SupplierDeclaration`, `RuleAssessment`.
- Produces: `ScoreCalculator.score(declaration:observation:ruleAssessment:) -> Double`, clamped to `0...10`.

- [ ] **Step 1: Write the failing tests**

```swift
// RescueTriageTests/ScoreCalculatorTests.swift
import XCTest
@testable import RescueTriage

final class ScoreCalculatorTests: XCTestCase {

    private func declaration(reason: RejectReason = .calibreOut) -> SupplierDeclaration {
        SupplierDeclaration(
            supplier: "Elvi", productName: "Apples", category: .produce,
            quantity: 6, unit: "crates",
            arrivalDate: Date(), expiryDate: Date(),
            expiryKind: .bestBefore, declaredReason: reason,
            coldChainGapMinutes: nil, storageTempC: nil,
            retailUnitPrice: 12, estimatedWeightKg: 60
        )
    }

    private func observation(
        damage: Int = 0,
        packaging: PackagingIntegrity = .intact,
        legible: Bool = true,
        discrepancies: [Discrepancy] = []
    ) -> ScanObservation {
        ScanObservation(
            damageSeverity: damage, packagingIntegrity: packaging,
            spoilageSigns: [], labelLegible: legible,
            observedProduct: "apples", observedQuantityPlausible: true,
            discrepancies: discrepancies, visualNotes: ""
        )
    }

    private func score(_ o: ScanObservation, _ rules: RuleAssessment = .clean,
                       _ d: SupplierDeclaration? = nil) -> Double {
        ScoreCalculator.score(declaration: d ?? declaration(), observation: o, ruleAssessment: rules)
    }

    func test_perfectProduct_scoresTen() {
        XCTAssertEqual(score(observation()), 10.0, accuracy: 0.001)
    }

    func test_cosmeticRejectReasonCostsNothing() {
        for reason in RejectReason.allCases where reason.isCosmetic {
            XCTAssertEqual(score(observation(), .clean, declaration(reason: reason)), 10.0,
                           accuracy: 0.001, "\(reason) should be free")
        }
    }

    func test_damageSeverityCostsOnePointFiveEach() {
        XCTAssertEqual(score(observation(damage: 1)), 8.5, accuracy: 0.001)
        XCTAssertEqual(score(observation(damage: 2)), 7.0, accuracy: 0.001)
        XCTAssertEqual(score(observation(damage: 4)), 4.0, accuracy: 0.001)
    }

    func test_packagingPenalties() {
        XCTAssertEqual(score(observation(packaging: .dented)), 9.5, accuracy: 0.001)
        XCTAssertEqual(score(observation(packaging: .compromised)), 8.0, accuracy: 0.001)
    }

    func test_illegibleLabelCostsHalfAPoint() {
        XCTAssertEqual(score(observation(legible: false)), 9.5, accuracy: 0.001)
    }

    func test_discrepancyPenalties() {
        let minor = Discrepancy(field: "quantity", declared: "6", observed: "5", severity: .minor)
        let major = Discrepancy(field: "packaging", declared: "dent", observed: "torn open", severity: .major)
        XCTAssertEqual(score(observation(discrepancies: [minor])), 9.0, accuracy: 0.001)
        XCTAssertEqual(score(observation(discrepancies: [major])), 8.0, accuracy: 0.001)
        XCTAssertEqual(score(observation(discrepancies: [minor, major])), 7.0, accuracy: 0.001)
    }

    func test_rulePenaltiesAreSubtracted() {
        XCTAssertEqual(score(observation(), RuleAssessment(penalty: 2.5)), 7.5, accuracy: 0.001)
    }

    func test_scoreNeverGoesBelowZero() {
        let worst = observation(damage: 4, packaging: .compromised, legible: false)
        XCTAssertEqual(score(worst, RuleAssessment(penalty: 9.0)), 0.0, accuracy: 0.001)
    }

    func test_scoreNeverGoesAboveTen() {
        XCTAssertEqual(score(observation(), RuleAssessment(penalty: -5)), 10.0, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RescueTriageTests/ScoreCalculatorTests 2>&1 | tail -20`
Expected: compile failure — `cannot find 'ScoreCalculator' in scope`.

- [ ] **Step 3: Write `ScoreCalculator.swift`**

```swift
// RescueTriage/Rules/ScoreCalculator.swift
import Foundation

/// Sellability out of 10, on the same scale the concept site's triage log uses.
///
/// The declared reject reason contributes nothing when it is cosmetic, which is
/// the whole inversion Rescue runs on: a supermarket refuses goods for looking
/// wrong, and that costs us zero points because looking wrong is what we sell.
enum ScoreCalculator {

    static func score(
        declaration: SupplierDeclaration,
        observation: ScanObservation,
        ruleAssessment: RuleAssessment
    ) -> Double {
        var score = 10.0

        score -= Double(observation.damageSeverity) * 1.5

        switch observation.packagingIntegrity {
        case .intact: break
        case .dented: score -= 0.5
        case .compromised: score -= 2.0
        case .breached: score -= 10.0  // vetoed anyway; floor it so the number matches the verdict
        }

        if !observation.labelLegible { score -= 0.5 }

        for discrepancy in observation.discrepancies {
            score -= discrepancy.severity == .major ? 2.0 : 1.0
        }

        // Expiry pressure and tolerated cold-chain gaps, already quantified by the rules.
        score -= ruleAssessment.penalty

        // Cosmetic reasons are deliberately free. No branch needed — this line
        // documents the absence.
        _ = declaration.declaredReason.isCosmetic

        return min(10.0, max(0.0, score))
    }
}
```

- [ ] **Step 4: Run the tests**

Run: `xcodebuild test -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RescueTriageTests/ScoreCalculatorTests 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **`, 9 tests.

- [ ] **Step 5: Commit**

```bash
git add RescueTriage/Rules/ScoreCalculator.swift RescueTriageTests/ScoreCalculatorTests.swift
git commit -m "Score calculation with cosmetic reasons costing nothing"
```

---

### Task 6: Verdict engine

The precedence rule from spec §6: veto, then quality rejection, then rule floor, then score bands. A rule may only ever downgrade.

**Files:**
- Create: `RescueTriage/Rules/VerdictEngine.swift`
- Test: `RescueTriageTests/VerdictEngineTests.swift`

**Interfaces:**
- Consumes: `SafetyRules`, `ScoreCalculator`, all models.
- Produces: `VerdictEngine.evaluate(declaration:observation:now:calendar:geminiAvailable:) -> Verdict`.

- [ ] **Step 1: Write the failing tests**

```swift
// RescueTriageTests/VerdictEngineTests.swift
import XCTest
@testable import RescueTriage

final class VerdictEngineTests: XCTestCase {

    private let now = ISO8601DateFormatter().date(from: "2026-09-13T09:00:00Z")!
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func declaration(
        category: ProductCategory = .produce,
        expiryKind: ExpiryKind = .bestBefore,
        expiryOffsetDays: Int = 5,
        reason: RejectReason = .calibreOut,
        gap: Int? = nil,
        temp: Double? = nil
    ) -> SupplierDeclaration {
        SupplierDeclaration(
            supplier: "Elvi", productName: "Apples", category: category,
            quantity: 6, unit: "crates", arrivalDate: now,
            expiryDate: calendar.date(byAdding: .day, value: expiryOffsetDays, to: now)!,
            expiryKind: expiryKind, declaredReason: reason,
            coldChainGapMinutes: gap, storageTempC: temp,
            retailUnitPrice: 12, estimatedWeightKg: 60
        )
    }

    private func observation(
        damage: Int = 0,
        packaging: PackagingIntegrity = .intact,
        spoilage: [String] = [],
        discrepancies: [Discrepancy] = []
    ) -> ScanObservation {
        ScanObservation(
            damageSeverity: damage, packagingIntegrity: packaging,
            spoilageSigns: spoilage, labelLegible: true,
            observedProduct: "apples", observedQuantityPlausible: true,
            discrepancies: discrepancies, visualNotes: ""
        )
    }

    private func evaluate(
        _ d: SupplierDeclaration, _ o: ScanObservation, geminiAvailable: Bool = true
    ) -> Verdict {
        VerdictEngine.evaluate(declaration: d, observation: o, now: now,
                               calendar: calendar, geminiAvailable: geminiAvailable)
    }

    // --- Priority 1: the safety veto beats everything ---

    func test_pristineProductWithPassedUseBy_isRejected() {
        let v = evaluate(declaration(category: .dairy, expiryKind: .useBy, expiryOffsetDays: -1),
                         observation())
        XCTAssertEqual(v.outcome, .rejected)
        XCTAssertTrue(v.vetoed)
        XCTAssertGreaterThanOrEqual(v.score, 7.0, "the photo looked fine — the veto is why it failed")
    }

    func test_spoilageSignsVeto() {
        let v = evaluate(declaration(), observation(spoilage: ["mould on the rind"]))
        XCTAssertEqual(v.outcome, .rejected)
        XCTAssertTrue(v.vetoed)
    }

    func test_breachedPackagingVetoes() {
        let v = evaluate(declaration(), observation(packaging: .breached))
        XCTAssertEqual(v.outcome, .rejected)
        XCTAssertTrue(v.vetoed)
    }

    func test_theSkyAndMoreYoghurtCase() {
        let v = evaluate(
            declaration(category: .dairy, expiryKind: .useBy, expiryOffsetDays: 2,
                        reason: .coldChainGap, gap: 40),
            observation()
        )
        XCTAssertEqual(v.outcome, .rejected)
        XCTAssertTrue(v.vetoed)
    }

    // --- Priority 3: a rule floor holds a high score down ---

    func test_majorDiscrepancyForcesHoldDespiteHighScore() {
        let major = Discrepancy(field: "packaging", declared: "small dent",
                                observed: "corner torn open", severity: .major)
        let v = evaluate(declaration(), observation(discrepancies: [major]))
        XCTAssertEqual(v.score, 8.0, accuracy: 0.001)
        XCTAssertEqual(v.outcome, .heldForHuman, "score says accept; the contradiction says look at it")
        XCTAssertFalse(v.vetoed)
    }

    func test_minorDiscrepancyDoesNotForceHold() {
        let minor = Discrepancy(field: "quantity", declared: "6", observed: "5", severity: .minor)
        XCTAssertEqual(evaluate(declaration(), observation(discrepancies: [minor])).outcome, .accepted)
    }

    // --- Priority 4: score bands ---

    func test_scoreBandBoundaries() {
        // 10 - 1.5*2 = 7.0 → accepted
        XCTAssertEqual(evaluate(declaration(), observation(damage: 2)).outcome, .accepted)
        // 10 - 1.5*2 - 0.5 = 6.5 → held
        XCTAssertEqual(evaluate(declaration(), observation(damage: 2, packaging: .dented)).outcome,
                       .heldForHuman)
        // 10 - 1.5*4 = 4.0 → held
        XCTAssertEqual(evaluate(declaration(), observation(damage: 4)).outcome, .heldForHuman)
        // 10 - 1.5*4 - 2.0 = 2.0 → rejected
        XCTAssertEqual(evaluate(declaration(), observation(damage: 4, packaging: .compromised)).outcome,
                       .rejected)
    }

    // --- Cosmetic reasons ---

    func test_everyCosmeticReasonOnACleanPhotoIsAccepted() {
        for reason in RejectReason.allCases where reason.isCosmetic {
            let v = evaluate(declaration(reason: reason), observation())
            XCTAssertEqual(v.outcome, .accepted, "\(reason) should sail through")
            XCTAssertEqual(v.score, 10.0, accuracy: 0.001)
        }
    }

    // --- Sell-today flag ---

    func test_useByTodayIsAcceptedAndFlagged() {
        let v = evaluate(declaration(category: .bakery, expiryKind: .useBy, expiryOffsetDays: 0),
                         observation())
        XCTAssertEqual(v.outcome, .accepted)
        XCTAssertTrue(v.sellToday)
        XCTAssertEqual(v.score, 9.0, accuracy: 0.001)
    }

    // --- Degraded mode ---

    func test_withoutGeminiTheVerdictIsMarkedPartialButStillRuns() {
        let v = evaluate(declaration(category: .dairy, expiryKind: .useBy, expiryOffsetDays: -1),
                         .unavailable, geminiAvailable: false)
        XCTAssertTrue(v.partial)
        XCTAssertEqual(v.outcome, .rejected, "the regulatory half still stands on its own")
    }

    func test_reasonsAreNeverEmpty() {
        XCTAssertFalse(evaluate(declaration(), observation()).reasons.isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RescueTriageTests/VerdictEngineTests 2>&1 | tail -20`
Expected: compile failure — `cannot find 'VerdictEngine' in scope`.

- [ ] **Step 3: Write `VerdictEngine.swift`**

```swift
// RescueTriage/Rules/VerdictEngine.swift
import Foundation

/// Fuses the deterministic rules with the model's visual reading.
///
/// The order below is the whole safety argument of this app. Gemini describes
/// the photograph; it never decides. A rule can push a verdict down the
/// severity ladder, never back up it.
enum VerdictEngine {

    static func evaluate(
        declaration: SupplierDeclaration,
        observation: ScanObservation,
        now: Date,
        calendar: Calendar = .current,
        geminiAvailable: Bool = true
    ) -> Verdict {

        let rules = RuleAssessment.merge([
            SafetyRules.expiry(declaration: declaration, now: now, calendar: calendar),
            SafetyRules.coldChain(category: declaration.category,
                                  gapMinutes: declaration.coldChainGapMinutes),
            SafetyRules.temperature(category: declaration.category,
                                    tempC: declaration.storageTempC),
            visualVeto(observation)
        ])

        let score = ScoreCalculator.score(
            declaration: declaration, observation: observation, ruleAssessment: rules
        )

        var reasons = rules.reasons
        reasons.append(contentsOf: observationReasons(observation))
        if declaration.declaredReason.isCosmetic {
            reasons.append(VerdictReason(
                "reason.cosmetic",
                "Supplier's reason — \(declaration.declaredReason.label.lowercased()) — is exactly what we sell"
            ))
        }
        if !geminiAvailable {
            reasons.append(VerdictReason(
                "gemini.unavailable",
                "Photo analysis unavailable — regulatory checks only"
            ))
        }

        let hasMajorDiscrepancy = observation.discrepancies.contains { $0.severity == .major }
        if hasMajorDiscrepancy {
            reasons.append(VerdictReason(
                "discrepancy.major",
                "Photo contradicts the declaration — a human decides this one"
            ))
        }

        return Verdict(
            outcome: resolve(score: score, rules: rules, hasMajorDiscrepancy: hasMajorDiscrepancy),
            score: score,
            reasons: reasons,
            discrepancies: observation.discrepancies,
            vetoed: rules.vetoed,
            humanOverride: nil,
            sellToday: rules.sellToday,
            partial: !geminiAvailable
        )
    }

    /// Priority order, first match wins. See spec §6.
    private static func resolve(
        score: Double, rules: RuleAssessment, hasMajorDiscrepancy: Bool
    ) -> Outcome {
        // 1. Food-safety veto. Nothing annuls it.
        if rules.vetoed { return .rejected }

        // 2–3. A rule floor. It may only make the verdict worse.
        let band = band(for: score)
        var outcome = band
        if let floor = rules.floor.asOutcome, floor.isWorse(than: outcome) {
            outcome = floor
        }
        // A contradiction between declaration and photo is never auto-stamped.
        if hasMajorDiscrepancy, Outcome.heldForHuman.isWorse(than: outcome) {
            outcome = .heldForHuman
        }
        return outcome
    }

    /// Spec §6 bands, chosen to reproduce the concept site's own log:
    /// 8.6 / 9.0 / 8.1 / 7.1 pass, 6.2 hold, 3.4 reject.
    private static func band(for score: Double) -> Outcome {
        switch score {
        case 7.0...: .accepted
        case 4.0..<7.0: .heldForHuman
        default: .rejected
        }
    }

    /// The two things in a photograph that are food-safety facts, not opinions.
    private static func visualVeto(_ observation: ScanObservation) -> RuleAssessment {
        var assessments: [RuleAssessment] = []

        if !observation.spoilageSigns.isEmpty {
            assessments.append(RuleAssessment(
                floor: .reject, vetoed: true,
                reasons: [VerdictReason("visual.spoilage",
                                        "Spoilage visible: \(observation.spoilageSigns.joined(separator: ", "))")]
            ))
        }
        if observation.packagingIntegrity == .breached {
            assessments.append(RuleAssessment(
                floor: .reject, vetoed: true,
                reasons: [VerdictReason("visual.breached", "Sealed packaging is breached")]
            ))
        }
        return RuleAssessment.merge(assessments)
    }

    private static func observationReasons(_ observation: ScanObservation) -> [VerdictReason] {
        var reasons: [VerdictReason] = []
        if observation.damageSeverity > 0 {
            reasons.append(VerdictReason("visual.damage",
                                         "Visible damage, severity \(observation.damageSeverity)/4"))
        }
        if observation.packagingIntegrity == .dented || observation.packagingIntegrity == .compromised {
            reasons.append(VerdictReason("visual.packaging",
                                         "Packaging \(observation.packagingIntegrity.label.lowercased()) — contents look unaffected"))
        }
        if !observation.labelLegible {
            reasons.append(VerdictReason("visual.label", "Label not fully legible"))
        }
        return reasons
    }
}
```

- [ ] **Step 4: Run the tests**

Run: `xcodebuild test -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RescueTriageTests/VerdictEngineTests 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **`, 12 tests.

- [ ] **Step 5: Commit**

```bash
git add RescueTriage/Rules/VerdictEngine.swift RescueTriageTests/VerdictEngineTests.swift
git commit -m "Verdict engine: safety veto beats score, rules only ever downgrade"
```

---

### Task 7: Demo batches

**Files:**
- Create: `RescueTriage/Resources/DemoBatches.json`
- Create: `RescueTriage/Models/DemoBatch.swift`
- Test: `RescueTriageTests/DemoBatchTests.swift`

**Interfaces:**
- Consumes: `SupplierDeclaration`.
- Produces: `DemoBatch` (`declaration`, `samplePhotoName`, `expectedOutcome`) and `DemoBatch.all` loaded from the bundle.

Dates in the JSON are offsets in days from "today", not absolute dates — a demo dated 2026-09-13 would rot within a week.

- [ ] **Step 1: Write the failing tests**

```swift
// RescueTriageTests/DemoBatchTests.swift
import XCTest
@testable import RescueTriage

final class DemoBatchTests: XCTestCase {

    func test_twelveBatchesLoadFromTheBundle() {
        XCTAssertEqual(DemoBatch.all.count, 12)
    }

    func test_everyBatchHasASupplierFromTheConceptSite() {
        let known: Set<String> = [
            "Rimi", "Maxima", "Lidl", "Sky&More", "Barbora", "Elvi",
            "top!", "Mego", "Aibe", "LaTS", "Your Neighbour Grocery", "Baltic Fresh"
        ]
        for batch in DemoBatch.all {
            XCTAssertTrue(known.contains(batch.declaration.supplier),
                          "\(batch.declaration.supplier) is not one of the site's feeders")
        }
    }

    func test_eachBatchProducesItsExpectedVerdict() {
        let now = Date()
        for batch in DemoBatch.all {
            guard let expected = batch.expectedOutcome else { continue }
            let verdict = VerdictEngine.evaluate(
                declaration: batch.declaration,
                observation: batch.syntheticObservation,
                now: now
            )
            XCTAssertEqual(verdict.outcome, expected,
                           "\(batch.declaration.supplier) · \(batch.declaration.productName)")
        }
    }

    func test_theSkyAndMoreYoghurtIsRejectedByVetoDespiteACleanPhoto() {
        let batch = try! XCTUnwrap(DemoBatch.all.first { $0.declaration.supplier == "Sky&More" })
        let verdict = VerdictEngine.evaluate(
            declaration: batch.declaration, observation: .unavailable, now: Date()
        )
        XCTAssertEqual(verdict.outcome, .rejected)
        XCTAssertTrue(verdict.vetoed)
    }

    func test_batchesCoverAllThreeOutcomes() {
        let outcomes = Set(DemoBatch.all.compactMap(\.expectedOutcome))
        XCTAssertTrue(outcomes.contains(.accepted))
        XCTAssertTrue(outcomes.contains(.heldForHuman))
        XCTAssertTrue(outcomes.contains(.rejected))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RescueTriageTests/DemoBatchTests 2>&1 | tail -20`
Expected: compile failure — `cannot find 'DemoBatch' in scope`.

- [ ] **Step 3: Write `DemoBatches.json`**

```json
[
  { "supplier": "Rimi", "productName": "42 rye loaves", "category": "bakery",
    "quantity": 42, "unit": "loaves", "arrivalOffsetDays": 0, "expiryOffsetDays": 0,
    "expiryKind": "useBy", "declaredReason": "endOfDayBake",
    "coldChainGapMinutes": null, "storageTempC": null,
    "retailUnitPrice": 1.9, "estimatedWeightKg": 21,
    "samplePhotoName": "demo-bread", "expectedOutcome": "accepted",
    "synthetic": { "damageSeverity": 0, "packagingIntegrity": "intact", "spoilageSigns": [], "labelLegible": true, "observedProduct": "rye loaves", "observedQuantityPlausible": true, "discrepancies": [], "visualNotes": "Crust intact, no mould." } },

  { "supplier": "Elvi", "productName": "6 crates apples", "category": "produce",
    "quantity": 6, "unit": "crates", "arrivalOffsetDays": -1, "expiryOffsetDays": 12,
    "expiryKind": "bestBefore", "declaredReason": "calibreOut",
    "coldChainGapMinutes": null, "storageTempC": null,
    "retailUnitPrice": 11.5, "estimatedWeightKg": 60,
    "samplePhotoName": "demo-apples", "expectedOutcome": "accepted",
    "synthetic": { "damageSeverity": 0, "packagingIntegrity": "intact", "spoilageSigns": [], "labelLegible": true, "observedProduct": "apples, hail-marked", "observedQuantityPlausible": true, "discrepancies": [], "visualNotes": "Surface marks only, firm fruit." } },

  { "supplier": "Barbora", "productName": "18 L milk", "category": "dairy",
    "quantity": 18, "unit": "L", "arrivalOffsetDays": 0, "expiryOffsetDays": 6,
    "expiryKind": "useBy", "declaredReason": "oldPackaging",
    "coldChainGapMinutes": null, "storageTempC": 3.5,
    "retailUnitPrice": 1.15, "estimatedWeightKg": 18,
    "samplePhotoName": "demo-milk", "expectedOutcome": "accepted",
    "synthetic": { "damageSeverity": 0, "packagingIntegrity": "intact", "spoilageSigns": [], "labelLegible": true, "observedProduct": "milk cartons, previous design", "observedQuantityPlausible": true, "discrepancies": [], "visualNotes": "Cartons sealed and cold." } },

  { "supplier": "Baltic Fresh", "productName": "30 banana bunches", "category": "produce",
    "quantity": 30, "unit": "bunches", "arrivalOffsetDays": -2, "expiryOffsetDays": 3,
    "expiryKind": "bestBefore", "declaredReason": "spottySkin",
    "coldChainGapMinutes": null, "storageTempC": null,
    "retailUnitPrice": 1.4, "estimatedWeightKg": 45,
    "samplePhotoName": "demo-bananas", "expectedOutcome": "accepted",
    "synthetic": { "damageSeverity": 0, "packagingIntegrity": "intact", "spoilageSigns": [], "labelLegible": true, "observedProduct": "bananas, speckled", "observedQuantityPlausible": true, "discrepancies": [], "visualNotes": "Sugar spots, no split skins." } },

  { "supplier": "top!", "productName": "1 case passata", "category": "ambient",
    "quantity": 1, "unit": "case", "arrivalOffsetDays": -3, "expiryOffsetDays": 240,
    "expiryKind": "bestBefore", "declaredReason": "dentedOuterBox",
    "coldChainGapMinutes": null, "storageTempC": null,
    "retailUnitPrice": 18.0, "estimatedWeightKg": 12,
    "samplePhotoName": "demo-passata", "expectedOutcome": "accepted",
    "synthetic": { "damageSeverity": 0, "packagingIntegrity": "dented", "spoilageSigns": [], "labelLegible": true, "observedProduct": "passata bottles in outer case", "observedQuantityPlausible": true, "discrepancies": [], "visualNotes": "Outer box crushed at one corner; bottles unharmed." } },

  { "supplier": "Aibe", "productName": "5 kg coffee", "category": "ambient",
    "quantity": 5, "unit": "kg", "arrivalOffsetDays": -5, "expiryOffsetDays": 180,
    "expiryKind": "bestBefore", "declaredReason": "packagingRedesign",
    "coldChainGapMinutes": null, "storageTempC": null,
    "retailUnitPrice": 42.0, "estimatedWeightKg": 5,
    "samplePhotoName": "demo-coffee", "expectedOutcome": "accepted",
    "synthetic": { "damageSeverity": 0, "packagingIntegrity": "intact", "spoilageSigns": [], "labelLegible": true, "observedProduct": "coffee bags, old livery", "observedQuantityPlausible": true, "discrepancies": [], "visualNotes": "Valves intact, bags sealed." } },

  { "supplier": "Your Neighbour Grocery", "productName": "12 curd packs", "category": "dairy",
    "quantity": 12, "unit": "packs", "arrivalOffsetDays": 0, "expiryOffsetDays": 4,
    "expiryKind": "useBy", "declaredReason": "postPromoOverstock",
    "coldChainGapMinutes": null, "storageTempC": 2.8,
    "retailUnitPrice": 0.95, "estimatedWeightKg": 4,
    "samplePhotoName": "demo-curd", "expectedOutcome": "accepted",
    "synthetic": { "damageSeverity": 0, "packagingIntegrity": "intact", "spoilageSigns": [], "labelLegible": true, "observedProduct": "curd snack packs", "observedQuantityPlausible": true, "discrepancies": [], "visualNotes": "Foil lids unbroken." } },

  { "supplier": "Lidl", "productName": "9 chicken trays", "category": "meatFish",
    "quantity": 9, "unit": "trays", "arrivalOffsetDays": 0, "expiryOffsetDays": 1,
    "expiryKind": "useBy", "declaredReason": "sellByTomorrow",
    "coldChainGapMinutes": null, "storageTempC": 2.0,
    "retailUnitPrice": 4.6, "estimatedWeightKg": 9,
    "samplePhotoName": "demo-chicken", "expectedOutcome": "accepted",
    "synthetic": { "damageSeverity": 0, "packagingIntegrity": "intact", "spoilageSigns": [], "labelLegible": true, "observedProduct": "chicken trays, vacuum sealed", "observedQuantityPlausible": true, "discrepancies": [], "visualNotes": "Seals tight, no purge in tray." } },

  { "supplier": "Mego", "productName": "8 ready meals", "category": "chilledPrepared",
    "quantity": 8, "unit": "meals", "arrivalOffsetDays": 0, "expiryOffsetDays": 0,
    "expiryKind": "useBy", "declaredReason": "overproduction",
    "coldChainGapMinutes": null, "storageTempC": 3.0,
    "retailUnitPrice": 5.2, "estimatedWeightKg": 3.2,
    "samplePhotoName": "demo-readymeals", "expectedOutcome": "accepted",
    "synthetic": { "damageSeverity": 0, "packagingIntegrity": "intact", "spoilageSigns": [], "labelLegible": true, "observedProduct": "chilled ready meals", "observedQuantityPlausible": true, "discrepancies": [], "visualNotes": "Film lids intact." } },

  { "supplier": "Maxima", "productName": "24 salad bags", "category": "produce",
    "quantity": 24, "unit": "bags", "arrivalOffsetDays": -1, "expiryOffsetDays": 2,
    "expiryKind": "useBy", "declaredReason": "shortShelfLife",
    "coldChainGapMinutes": null, "storageTempC": null,
    "retailUnitPrice": 1.8, "estimatedWeightKg": 4.8,
    "samplePhotoName": "demo-salad", "expectedOutcome": "heldForHuman",
    "synthetic": { "damageSeverity": 2, "packagingIntegrity": "dented", "spoilageSigns": [], "labelLegible": true, "observedProduct": "bagged salad", "observedQuantityPlausible": true, "discrepancies": [], "visualNotes": "Some leaf wilt and condensation inside the bags." } },

  { "supplier": "LaTS", "productName": "1 pallet pasta", "category": "ambient",
    "quantity": 1, "unit": "pallet", "arrivalOffsetDays": -10, "expiryOffsetDays": -45,
    "expiryKind": "bestBefore", "declaredReason": "discontinued",
    "coldChainGapMinutes": null, "storageTempC": null,
    "retailUnitPrice": 320.0, "estimatedWeightKg": 480,
    "samplePhotoName": "demo-pasta", "expectedOutcome": "heldForHuman",
    "synthetic": { "damageSeverity": 0, "packagingIntegrity": "intact", "spoilageSigns": [], "labelLegible": true, "observedProduct": "dried pasta, discontinued shape", "observedQuantityPlausible": true, "discrepancies": [], "visualNotes": "Shrink wrap intact, boxes dry." } },

  { "supplier": "Sky&More", "productName": "1 case yoghurt", "category": "dairy",
    "quantity": 1, "unit": "case", "arrivalOffsetDays": 0, "expiryOffsetDays": 5,
    "expiryKind": "useBy", "declaredReason": "coldChainGap",
    "coldChainGapMinutes": 40, "storageTempC": 9.5,
    "retailUnitPrice": 22.0, "estimatedWeightKg": 8,
    "samplePhotoName": "demo-yoghurt", "expectedOutcome": "rejected",
    "synthetic": { "damageSeverity": 0, "packagingIntegrity": "intact", "spoilageSigns": [], "labelLegible": true, "observedProduct": "yoghurt pots in a case", "observedQuantityPlausible": true, "discrepancies": [], "visualNotes": "Looks perfect. The problem is not visible." } }
]
```

- [ ] **Step 4: Write `DemoBatch.swift`**

```swift
// RescueTriage/Models/DemoBatch.swift
import Foundation

/// A pre-loaded case from the concept site's triage log, ready to demo in one tap.
///
/// Dates are stored as day offsets from "now" rather than absolute dates: a demo
/// with a hard-coded 2026 date stops making sense within a week of shipping.
struct DemoBatch: Identifiable, Equatable {
    var id: UUID { declaration.id }
    var declaration: SupplierDeclaration
    var samplePhotoName: String
    var expectedOutcome: Outcome?
    /// Stand-in for Gemini, so the demo set can be verdict-tested without a network call.
    var syntheticObservation: ScanObservation

    private struct Raw: Decodable {
        let supplier: String
        let productName: String
        let category: ProductCategory
        let quantity: Double
        let unit: String
        let arrivalOffsetDays: Int
        let expiryOffsetDays: Int
        let expiryKind: ExpiryKind
        let declaredReason: RejectReason
        let coldChainGapMinutes: Int?
        let storageTempC: Double?
        let retailUnitPrice: Double
        let estimatedWeightKg: Double
        let samplePhotoName: String
        let expectedOutcome: Outcome?
        let synthetic: ScanObservation
    }

    static let all: [DemoBatch] = load()

    private static func load(now: Date = Date(), calendar: Calendar = .current) -> [DemoBatch] {
        guard let url = Bundle.main.url(forResource: "DemoBatches", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raws = try? JSONDecoder().decode([Raw].self, from: data)
        else {
            assertionFailure("DemoBatches.json missing or malformed — it is bundled, so this is a build problem")
            return []
        }

        return raws.map { raw in
            DemoBatch(
                declaration: SupplierDeclaration(
                    supplier: raw.supplier,
                    productName: raw.productName,
                    category: raw.category,
                    quantity: raw.quantity,
                    unit: raw.unit,
                    arrivalDate: calendar.date(byAdding: .day, value: raw.arrivalOffsetDays, to: now) ?? now,
                    expiryDate: calendar.date(byAdding: .day, value: raw.expiryOffsetDays, to: now) ?? now,
                    expiryKind: raw.expiryKind,
                    declaredReason: raw.declaredReason,
                    coldChainGapMinutes: raw.coldChainGapMinutes,
                    storageTempC: raw.storageTempC,
                    retailUnitPrice: Decimal(raw.retailUnitPrice),
                    estimatedWeightKg: raw.estimatedWeightKg
                ),
                samplePhotoName: raw.samplePhotoName,
                expectedOutcome: raw.expectedOutcome,
                syntheticObservation: raw.synthetic
            )
        }
    }
}
```

- [ ] **Step 5: Run the tests**

Run: `xcodebuild test -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RescueTriageTests/DemoBatchTests 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **`, 5 tests.

If `test_eachBatchProducesItsExpectedVerdict` fails, the fix is in the JSON, never in the thresholds — the thresholds are the spec.

- [ ] **Step 6: Commit**

```bash
git add RescueTriage/Resources/DemoBatches.json RescueTriage/Models/DemoBatch.swift RescueTriageTests/DemoBatchTests.swift
git commit -m "Twelve demo batches drawn from the concept site's triage log"
```

---

### Task 8: Keychain storage for the API key

**Files:**
- Create: `RescueTriage/Store/KeychainStore.swift`
- Test: `RescueTriageTests/KeychainStoreTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `KeychainStore.save(_:) throws`, `KeychainStore.read() -> String?`, `KeychainStore.delete() throws`.

- [ ] **Step 1: Write the failing tests**

```swift
// RescueTriageTests/KeychainStoreTests.swift
import XCTest
@testable import RescueTriage

final class KeychainStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        try? KeychainStore.delete()
    }

    override func tearDown() {
        try? KeychainStore.delete()
        super.tearDown()
    }

    func test_readingWhenNothingIsStoredReturnsNil() {
        XCTAssertNil(KeychainStore.read())
    }

    func test_savedKeyComesBack() throws {
        try KeychainStore.save("AIzaTESTKEY123")
        XCTAssertEqual(KeychainStore.read(), "AIzaTESTKEY123")
    }

    func test_savingTwiceOverwrites() throws {
        try KeychainStore.save("first")
        try KeychainStore.save("second")
        XCTAssertEqual(KeychainStore.read(), "second")
    }

    func test_deleteRemovesTheKey() throws {
        try KeychainStore.save("AIzaTESTKEY123")
        try KeychainStore.delete()
        XCTAssertNil(KeychainStore.read())
    }

    func test_savingAnEmptyStringDeletesInstead() throws {
        try KeychainStore.save("AIzaTESTKEY123")
        try KeychainStore.save("   ")
        XCTAssertNil(KeychainStore.read(), "whitespace is not a key")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RescueTriageTests/KeychainStoreTests 2>&1 | tail -20`
Expected: compile failure — `cannot find 'KeychainStore' in scope`.

- [ ] **Step 3: Write `KeychainStore.swift`**

```swift
// RescueTriage/Store/KeychainStore.swift
import Foundation
import Security

/// The Gemini API key's only home on the device.
///
/// It is never written to UserDefaults, never printed, never committed. The
/// accessibility class keeps it on this device only and unreadable while the
/// phone is locked — a demo key is still a live credential.
enum KeychainStore {

    enum KeychainError: Error, LocalizedError {
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let status):
                "Keychain error \(status)"
            }
        }
    }

    private static let service = "lv.rescue.triage"
    private static let account = "gemini.api.key"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    static func save(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try delete()
            return
        }

        try delete()

        var query = baseQuery
        query[kSecValueData as String] = Data(trimmed.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    static func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
```

- [ ] **Step 4: Run the tests**

Run: `xcodebuild test -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RescueTriageTests/KeychainStoreTests 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **`, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add RescueTriage/Store/KeychainStore.swift RescueTriageTests/KeychainStoreTests.swift
git commit -m "Keychain storage for the Gemini API key"
```

---

### Task 9: Gemini client

**Files:**
- Create: `RescueTriage/Vision/GeminiClient.swift`
- Test: `RescueTriageTests/GeminiClientTests.swift`

**Interfaces:**
- Consumes: `ScanObservation`, `SupplierDeclaration`, `KeychainStore`.
- Produces: `GeminiClient(apiKey:model:session:)`, `analyse(imageData:declaration:) async throws -> ScanObservation`, `GeminiClient.decodeObservation(from:) throws -> ScanObservation` (exposed for testing), `GeminiError`.

The response schema forces structured JSON out of the model, so the demo cannot fail because it answered in prose. Decoding is tested against a recorded payload — no network in the test suite.

- [ ] **Step 1: Write the failing tests**

```swift
// RescueTriageTests/GeminiClientTests.swift
import XCTest
@testable import RescueTriage

final class GeminiClientTests: XCTestCase {

    /// A real-shaped Gemini response: the observation JSON arrives as a string
    /// inside candidates[0].content.parts[0].text.
    private let recordedResponse = """
    {
      "candidates": [
        { "content": { "parts": [ { "text": "{\\"damageSeverity\\":1,\\"packagingIntegrity\\":\\"dented\\",\\"spoilageSigns\\":[],\\"labelLegible\\":true,\\"observedProduct\\":\\"passata bottles\\",\\"observedQuantityPlausible\\":true,\\"discrepancies\\":[{\\"field\\":\\"packaging\\",\\"declared\\":\\"dented outer box\\",\\"observed\\":\\"one bottle cracked\\",\\"severity\\":\\"major\\"}],\\"visualNotes\\":\\"Corner crushed.\\"}" } ], "role": "model" },
          "finishReason": "STOP" }
      ]
    }
    """.data(using: .utf8)!

    func test_decodesTheObservationOutOfAGeminiEnvelope() throws {
        let observation = try GeminiClient.decodeObservation(from: recordedResponse)
        XCTAssertEqual(observation.damageSeverity, 1)
        XCTAssertEqual(observation.packagingIntegrity, .dented)
        XCTAssertEqual(observation.observedProduct, "passata bottles")
        XCTAssertEqual(observation.discrepancies.count, 1)
        XCTAssertEqual(observation.discrepancies[0].severity, .major)
    }

    func test_emptyCandidatesThrows() {
        let empty = #"{"candidates":[]}"#.data(using: .utf8)!
        XCTAssertThrowsError(try GeminiClient.decodeObservation(from: empty))
    }

    func test_nonJSONTextPartThrows() {
        let prose = """
        { "candidates": [ { "content": { "parts": [ { "text": "The yoghurt looks fine to me." } ] } } ] }
        """.data(using: .utf8)!
        XCTAssertThrowsError(try GeminiClient.decodeObservation(from: prose))
    }

    func test_damageSeverityIsClampedToTheZeroToFourRange() throws {
        let outOfRange = """
        { "candidates": [ { "content": { "parts": [ { "text": "{\\"damageSeverity\\":9,\\"packagingIntegrity\\":\\"intact\\",\\"spoilageSigns\\":[],\\"labelLegible\\":true,\\"observedProduct\\":\\"x\\",\\"observedQuantityPlausible\\":true,\\"discrepancies\\":[],\\"visualNotes\\":\\"\\"}" } ] } } ] }
        """.data(using: .utf8)!
        XCTAssertEqual(try GeminiClient.decodeObservation(from: outOfRange).damageSeverity, 4)
    }

    func test_missingAPIKeyIsReportedBeforeAnyNetworkCall() async {
        let client = GeminiClient(apiKey: "", model: "gemini-2.5-flash")
        do {
            _ = try await client.analyse(imageData: Data(), declaration: Self.sampleDeclaration)
            XCTFail("should have thrown")
        } catch let error as GeminiError {
            XCTAssertEqual(error, .missingAPIKey)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    private static let sampleDeclaration = SupplierDeclaration(
        supplier: "top!", productName: "1 case passata", category: .ambient,
        quantity: 1, unit: "case", arrivalDate: Date(), expiryDate: Date(),
        expiryKind: .bestBefore, declaredReason: .dentedOuterBox,
        coldChainGapMinutes: nil, storageTempC: nil,
        retailUnitPrice: 18, estimatedWeightKg: 12
    )
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RescueTriageTests/GeminiClientTests 2>&1 | tail -20`
Expected: compile failure — `cannot find 'GeminiClient' in scope`.

- [ ] **Step 3: Write `GeminiClient.swift`**

```swift
// RescueTriage/Vision/GeminiClient.swift
import Foundation

enum GeminiError: Error, Equatable, LocalizedError {
    case missingAPIKey
    case http(Int, String)
    case emptyResponse
    case malformedObservation
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "No Gemini API key. Add one in Settings."
        case .http(let code, let message): "Gemini returned \(code): \(message)"
        case .emptyResponse: "Gemini returned no candidates."
        case .malformedObservation: "Gemini's answer did not match the expected shape."
        case .transport(let message): "Network error: \(message)"
        }
    }
}

/// Calls Gemini to describe a product photograph.
///
/// It is asked to *describe*, never to decide. The verdict belongs to
/// `VerdictEngine`, whose rules can overrule anything said here. `responseSchema`
/// forces structured JSON back, so a demo cannot collapse because the model felt
/// chatty that afternoon.
struct GeminiClient {

    let apiKey: String
    let model: String
    private let session: URLSession

    static let defaultModel = "gemini-2.5-flash"

    init(apiKey: String, model: String = GeminiClient.defaultModel, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    /// Built from the Keychain plus the model chosen in Settings.
    static func fromStoredSettings() -> GeminiClient {
        let model = UserDefaults.standard.string(forKey: "gemini.model") ?? defaultModel
        return GeminiClient(apiKey: KeychainStore.read() ?? "", model: model)
    }

    var isConfigured: Bool { !apiKey.isEmpty }

    func analyse(imageData: Data, declaration: SupplierDeclaration) async throws -> ScanObservation {
        guard isConfigured else { throw GeminiError.missingAPIKey }

        var request = URLRequest(
            url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        )
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: requestBody(imageData: imageData, declaration: declaration)
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GeminiError.transport(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
            throw GeminiError.http(http.statusCode, String(message))
        }

        return try Self.decodeObservation(from: data)
    }

    // MARK: Request

    private func requestBody(imageData: Data, declaration: SupplierDeclaration) -> [String: Any] {
        [
            "contents": [[
                "role": "user",
                "parts": [
                    ["text": prompt(for: declaration)],
                    ["inline_data": ["mime_type": "image/jpeg",
                                     "data": imageData.base64EncodedString()]]
                ]
            ]],
            "generationConfig": [
                "temperature": 0.1,
                "responseMimeType": "application/json",
                "responseSchema": Self.responseSchema
            ]
        ]
    }

    private func prompt(for declaration: SupplierDeclaration) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return """
        You are inspecting surplus food goods arriving at Rescue, an anti-waste \
        supermarket that deliberately sells produce other shops refuse for looking wrong.

        Describe ONLY what the photograph shows. Do not decide whether to accept \
        the goods — that decision is made elsewhere by food-safety rules.

        The supplier declared:
        - Product: \(declaration.productName) (\(declaration.category.label))
        - Quantity: \(declaration.formattedQuantity) \(declaration.unit)
        - Arrived at supplier: \(formatter.string(from: declaration.arrivalDate))
        - \(declaration.expiryKind.label): \(formatter.string(from: declaration.expiryDate))
        - Their stated reason for rejecting it: \(declaration.declaredReason.label)
        \(declaration.coldChainGapMinutes.map { "- Declared cold-chain gap: \($0) min" } ?? "")
        \(declaration.storageTempC.map { "- Declared storage temperature: \($0) °C" } ?? "")

        Report any contradiction between that declaration and the photograph as a \
        discrepancy. Use severity "major" when the truth is materially worse than \
        declared — for example a declared small dent that is actually a torn or \
        punctured pack. Use "minor" for differences that do not change how sellable \
        the goods are.

        damageSeverity: 0 none, 1 trivial, 2 noticeable, 3 serious, 4 severe.
        Cosmetic imperfection — odd shape, blemished skin, old packaging — is NOT \
        damage here. Report it as 0 and mention it in visualNotes.
        List spoilageSigns only for actual signs of spoiled food: mould, slime, \
        discolouration, leaking fluid. An empty list when there are none.
        """
    }

    private static let responseSchema: [String: Any] = [
        "type": "OBJECT",
        "properties": [
            "damageSeverity": ["type": "INTEGER"],
            "packagingIntegrity": ["type": "STRING",
                                   "enum": ["intact", "dented", "compromised", "breached"]],
            "spoilageSigns": ["type": "ARRAY", "items": ["type": "STRING"]],
            "labelLegible": ["type": "BOOLEAN"],
            "observedProduct": ["type": "STRING"],
            "observedQuantityPlausible": ["type": "BOOLEAN"],
            "discrepancies": [
                "type": "ARRAY",
                "items": [
                    "type": "OBJECT",
                    "properties": [
                        "field": ["type": "STRING"],
                        "declared": ["type": "STRING"],
                        "observed": ["type": "STRING"],
                        "severity": ["type": "STRING", "enum": ["minor", "major"]]
                    ],
                    "required": ["field", "declared", "observed", "severity"]
                ]
            ],
            "visualNotes": ["type": "STRING"]
        ],
        "required": [
            "damageSeverity", "packagingIntegrity", "spoilageSigns", "labelLegible",
            "observedProduct", "observedQuantityPlausible", "discrepancies", "visualNotes"
        ]
    ]

    // MARK: Response

    private struct Envelope: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable { let text: String? }
                let parts: [Part]?
            }
            let content: Content?
        }
        let candidates: [Candidate]?
    }

    static func decodeObservation(from data: Data) throws -> ScanObservation {
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        guard let text = envelope.candidates?.first?.content?.parts?
            .compactMap(\.text).first, !text.isEmpty
        else { throw GeminiError.emptyResponse }

        guard let inner = text.data(using: .utf8),
              var observation = try? JSONDecoder().decode(ScanObservation.self, from: inner)
        else { throw GeminiError.malformedObservation }

        observation.damageSeverity = min(4, max(0, observation.damageSeverity))
        return observation
    }
}
```

- [ ] **Step 4: Run the tests**

Run: `xcodebuild test -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RescueTriageTests/GeminiClientTests 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **`, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add RescueTriage/Vision/GeminiClient.swift RescueTriageTests/GeminiClientTests.swift
git commit -m "Gemini client with a forced response schema and no verdict authority"
```

---

### Task 10: Session store

**Files:**
- Create: `RescueTriage/Store/SessionStore.swift`
- Test: `RescueTriageTests/SessionStoreTests.swift`

**Interfaces:**
- Consumes: `DemoBatch`, `Verdict`, `VerdictEngine`, `GeminiClient`.
- Produces: `@MainActor final class SessionStore: ObservableObject` with `queue`, `processed`, `tally`, `add(_:)`, `record(declaration:verdict:)`, `applyOverride(_:to:)`, `reset()`; and `SessionTally` (`count`, `accepted`, `held`, `rejected`, `kgDiverted`, `valueRecovered`).

The tally counts the human's call when there was one — that is what `Verdict.effectiveOutcome` is for.

- [ ] **Step 1: Write the failing tests**

```swift
// RescueTriageTests/SessionStoreTests.swift
import XCTest
@testable import RescueTriage

@MainActor
final class SessionStoreTests: XCTestCase {

    private func declaration(weight: Double, price: Decimal, quantity: Double = 1) -> SupplierDeclaration {
        SupplierDeclaration(
            supplier: "Rimi", productName: "Test", category: .ambient,
            quantity: quantity, unit: "case", arrivalDate: Date(), expiryDate: Date(),
            expiryKind: .bestBefore, declaredReason: .discontinued,
            coldChainGapMinutes: nil, storageTempC: nil,
            retailUnitPrice: price, estimatedWeightKg: weight
        )
    }

    private func verdict(_ outcome: Outcome) -> Verdict {
        Verdict(outcome: outcome, score: 8, reasons: [], discrepancies: [],
                vetoed: false, humanOverride: nil, sellToday: false, partial: false)
    }

    func test_freshSessionIsEmpty() {
        let store = SessionStore(queue: [])
        XCTAssertEqual(store.tally.count, 0)
        XCTAssertEqual(store.tally.kgDiverted, 0, accuracy: 0.001)
    }

    func test_acceptedItemAddsWeightAndValue() {
        let store = SessionStore(queue: [])
        store.record(declaration: declaration(weight: 21, price: 1.9, quantity: 42),
                     verdict: verdict(.accepted))
        XCTAssertEqual(store.tally.accepted, 1)
        XCTAssertEqual(store.tally.kgDiverted, 21, accuracy: 0.001)
        XCTAssertEqual(store.tally.valueRecovered, Decimal(1.9) * 42)
    }

    func test_rejectedItemCountsButDivertsNothing() {
        let store = SessionStore(queue: [])
        store.record(declaration: declaration(weight: 8, price: 22), verdict: verdict(.rejected))
        XCTAssertEqual(store.tally.rejected, 1)
        XCTAssertEqual(store.tally.kgDiverted, 0, accuracy: 0.001)
        XCTAssertEqual(store.tally.valueRecovered, 0)
    }

    func test_heldItemCountsButDivertsNothingUntilDecided() {
        let store = SessionStore(queue: [])
        store.record(declaration: declaration(weight: 5, price: 3), verdict: verdict(.heldForHuman))
        XCTAssertEqual(store.tally.held, 1)
        XCTAssertEqual(store.tally.kgDiverted, 0, accuracy: 0.001)
    }

    func test_humanOverrideMovesTheItemInTheTally() {
        let store = SessionStore(queue: [])
        store.record(declaration: declaration(weight: 5, price: 3), verdict: verdict(.heldForHuman))
        let id = try! XCTUnwrap(store.processed.first?.id)

        store.applyOverride(.accepted, to: id)

        XCTAssertEqual(store.tally.held, 0)
        XCTAssertEqual(store.tally.accepted, 1)
        XCTAssertEqual(store.tally.kgDiverted, 5, accuracy: 0.001)
    }

    func test_recordingRemovesTheItemFromTheQueue() {
        let batch = DemoBatch.all[0]
        let store = SessionStore(queue: [batch.declaration])
        XCTAssertEqual(store.queue.count, 1)
        store.record(declaration: batch.declaration, verdict: verdict(.accepted))
        XCTAssertTrue(store.queue.isEmpty)
    }

    func test_resetClearsEverything() {
        let store = SessionStore(queue: [])
        store.record(declaration: declaration(weight: 5, price: 3), verdict: verdict(.accepted))
        store.reset()
        XCTAssertEqual(store.tally.count, 0)
        XCTAssertTrue(store.processed.isEmpty)
        XCTAssertEqual(store.queue.count, DemoBatch.all.count)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RescueTriageTests/SessionStoreTests 2>&1 | tail -20`
Expected: compile failure — `cannot find 'SessionStore' in scope`.

- [ ] **Step 3: Write `SessionStore.swift`**

```swift
// RescueTriage/Store/SessionStore.swift
import Foundation
import SwiftUI

/// What the operator has got through so far. This is the number that turns a
/// technical demo into a business case, so it counts the human's decision when
/// one was made, not the machine's first guess.
struct SessionTally: Equatable {
    var count: Int = 0
    var accepted: Int = 0
    var held: Int = 0
    var rejected: Int = 0
    var kgDiverted: Double = 0
    var valueRecovered: Decimal = 0
}

struct ProcessedItem: Identifiable, Equatable {
    let id: UUID
    var declaration: SupplierDeclaration
    var verdict: Verdict
    var processedAt: Date
}

@MainActor
final class SessionStore: ObservableObject {

    @Published private(set) var queue: [SupplierDeclaration]
    @Published private(set) var processed: [ProcessedItem] = []

    init(queue: [SupplierDeclaration]? = nil) {
        self.queue = queue ?? DemoBatch.all.map(\.declaration)
    }

    /// Recomputed rather than accumulated, so an override can never leave the
    /// running totals out of step with the list they summarise.
    var tally: SessionTally {
        processed.reduce(into: SessionTally()) { tally, item in
            tally.count += 1
            switch item.verdict.effectiveOutcome {
            case .accepted:
                tally.accepted += 1
                tally.kgDiverted += item.declaration.estimatedWeightKg
                tally.valueRecovered += item.declaration.retailUnitPrice
                    * Decimal(item.declaration.quantity)
            case .heldForHuman:
                tally.held += 1
            case .rejected:
                tally.rejected += 1
            }
        }
    }

    func add(_ declaration: SupplierDeclaration) {
        queue.append(declaration)
    }

    func record(declaration: SupplierDeclaration, verdict: Verdict) {
        queue.removeAll { $0.id == declaration.id }
        processed.insert(
            ProcessedItem(id: declaration.id, declaration: declaration,
                          verdict: verdict, processedAt: Date()),
            at: 0
        )
    }

    func applyOverride(_ outcome: Outcome, to id: UUID) {
        guard let index = processed.firstIndex(where: { $0.id == id }) else { return }
        processed[index].verdict.humanOverride = outcome
    }

    func reset() {
        processed.removeAll()
        queue = DemoBatch.all.map(\.declaration)
    }
}
```

- [ ] **Step 4: Run the tests**

Run: `xcodebuild test -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:RescueTriageTests/SessionStoreTests 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **`, 7 tests.

- [ ] **Step 5: Commit**

```bash
git add RescueTriage/Store/SessionStore.swift RescueTriageTests/SessionStoreTests.swift
git commit -m "Session store with a tally that follows human overrides"
```

---

### Task 11: Theme and the verdict card

The first visible screen. Built before the navigation so the look can be judged early, when changing it is still cheap.

**Files:**
- Create: `RescueTriage/Theme/RescuePalette.swift`
- Create: `RescueTriage/Views/VerdictCardView.swift`
- Modify: `RescueTriage/RescueTriageApp.swift`

**Interfaces:**
- Consumes: `Verdict`, `SupplierDeclaration`.
- Produces: `RescuePalette` colour constants; `VerdictCardView(declaration:verdict:onOverride:onDone:)`.

- [ ] **Step 1: Write `RescuePalette.swift`**

```swift
// RescueTriage/Theme/RescuePalette.swift
import SwiftUI

/// Lifted from the concept site so the app and the website read as one product.
enum RescuePalette {
    static let orange = Color(hex: 0xE8562F)
    static let navy   = Color(hex: 0x171C3A)
    static let lime   = Color(hex: 0xD8FB45)
    static let cream  = Color(hex: 0xFAF3DF)
    static let paper  = Color(hex: 0xECE7DA)
    static let ink    = Color(hex: 0x17130E)
    static let amber  = Color(hex: 0xE0A32E)
    static let muted  = Color(hex: 0x5C5648)

    static func background(for outcome: Outcome) -> Color {
        switch outcome {
        case .accepted: lime
        case .heldForHuman: amber
        case .rejected: orange
        }
    }

    static func foreground(for outcome: Outcome) -> Color {
        switch outcome {
        case .accepted: ink
        case .heldForHuman, .rejected: .white
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
```

- [ ] **Step 2: Write `VerdictCardView.swift`**

```swift
// RescueTriage/Views/VerdictCardView.swift
import SwiftUI

struct VerdictCardView: View {
    let declaration: SupplierDeclaration
    let verdict: Verdict
    var onOverride: ((Outcome) -> Void)?
    var onDone: (() -> Void)?

    private var outcome: Outcome { verdict.effectiveOutcome }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                body(for: verdict)
            }
        }
        .background(RescuePalette.cream)
        .safeAreaInset(edge: .bottom) { doneBar }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(declaration.supplier.uppercased())
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.6)
                .opacity(0.75)

            Text(outcome.label)
                .font(.system(size: 46, weight: .black))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            HStack(spacing: 10) {
                Text(String(format: "%.1f", verdict.score))
                    .font(.system(size: 19, weight: .heavy, design: .monospaced))
                Text("/ 10 sellability")
                    .font(.system(size: 13, weight: .semibold))
                    .opacity(0.8)

                if verdict.vetoed {
                    Spacer()
                    Label("SAFETY VETO", systemImage: "exclamationmark.octagon.fill")
                        .font(.system(size: 11, weight: .heavy))
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(.black.opacity(0.22), in: Capsule())
                }
            }

            if verdict.sellToday {
                Label("Sell today", systemImage: "clock.fill")
                    .font(.system(size: 12, weight: .bold))
            }
            if verdict.humanOverride != nil {
                Label("Operator decision", systemImage: "person.fill.checkmark")
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RescuePalette.background(for: outcome))
        .foregroundStyle(RescuePalette.foreground(for: outcome))
    }

    @ViewBuilder
    private func body(for verdict: Verdict) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("\(declaration.productName) · \(declaration.category.label)")
                .font(.system(size: 17, weight: .bold))
                .padding(.top, 20)

            if verdict.partial {
                noticeRow(
                    "Photo analysis unavailable — this verdict rests on the regulatory checks alone.",
                    icon: "wifi.slash"
                )
            }

            if !verdict.discrepancies.isEmpty {
                section("Contradicts the declaration") {
                    ForEach(verdict.discrepancies) { discrepancy in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(discrepancy.field.capitalized)
                                .font(.system(size: 13, weight: .heavy))
                            Text("Declared: \(discrepancy.declared)")
                                .font(.system(size: 13))
                            Text("Photo shows: \(discrepancy.observed)")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            (discrepancy.severity == .major ? RescuePalette.orange : RescuePalette.amber)
                                .opacity(0.16),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                }
            }

            section("Why") {
                ForEach(verdict.reasons) { reason in
                    HStack(alignment: .top, spacing: 9) {
                        Text("·").font(.system(size: 15, weight: .black))
                        Text(reason.label).font(.system(size: 14))
                    }
                }
            }

            if outcome == .heldForHuman, let onOverride {
                section("Your call") {
                    HStack(spacing: 10) {
                        overrideButton("Accept", .accepted, RescuePalette.lime, RescuePalette.ink, onOverride)
                        overrideButton("Reject", .rejected, RescuePalette.orange, .white, onOverride)
                    }
                }
            }
        }
        .foregroundStyle(RescuePalette.ink)
        .padding(.horizontal, 22)
        .padding(.bottom, 28)
    }

    private func overrideButton(
        _ title: String, _ outcome: Outcome, _ background: Color,
        _ foreground: Color, _ action: @escaping (Outcome) -> Void
    ) -> some View {
        Button { action(outcome) } label: {
            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(background, in: Capsule())
                .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
    }

    private func noticeRow(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 13, weight: .semibold))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RescuePalette.navy.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.3)
                .foregroundStyle(RescuePalette.muted)
            content()
        }
    }

    private var doneBar: some View {
        Button { onDone?() } label: {
            Text("Next item")
                .font(.system(size: 16, weight: .heavy))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RescuePalette.navy, in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 22)
        .padding(.bottom, 10)
        .background(RescuePalette.cream)
    }
}

#Preview("Accepted") {
    VerdictCardView(
        declaration: DemoBatch.all[1].declaration,
        verdict: Verdict(outcome: .accepted, score: 9.0,
                         reasons: [VerdictReason("reason.cosmetic",
                                                 "Supplier's reason — out of calibre — is exactly what we sell")],
                         discrepancies: [], vetoed: false, humanOverride: nil,
                         sellToday: false, partial: false)
    )
}

#Preview("Vetoed") {
    VerdictCardView(
        declaration: DemoBatch.all[11].declaration,
        verdict: Verdict(outcome: .rejected, score: 8.0,
                         reasons: [VerdictReason("coldChain.broken",
                                                 "40 min cold-chain gap on dairy — over the 30 min limit")],
                         discrepancies: [], vetoed: true, humanOverride: nil,
                         sellToday: false, partial: false)
    )
}
```

- [ ] **Step 3: Point the app at the card so it can be seen**

```swift
// RescueTriage/RescueTriageApp.swift
import SwiftUI

@main
struct RescueTriageApp: App {
    var body: some Scene {
        WindowGroup {
            VerdictCardView(
                declaration: DemoBatch.all[1].declaration,
                verdict: VerdictEngine.evaluate(
                    declaration: DemoBatch.all[1].declaration,
                    observation: DemoBatch.all[1].syntheticObservation,
                    now: Date()
                )
            )
        }
    }
}
```

- [ ] **Step 4: Build and look at it**

```bash
xcodebuild build -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcrun simctl install booted "$(xcodebuild -showBuildSettings -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{print $2; exit}')/RescueTriage.app"
xcrun simctl launch booted lv.rescue.triage
xcrun simctl io booted screenshot /tmp/rescue-verdict.png
```
Expected: a lime card reading ACCEPTED, 10.0 / 10, with the cosmetic-reason line. Open the screenshot and check it before moving on.

- [ ] **Step 5: Commit**

```bash
git add RescueTriage/Theme RescueTriage/Views/VerdictCardView.swift RescueTriage/RescueTriageApp.swift
git commit -m "Brand palette and the verdict card"
```

---

### Task 12: Queue, declaration and manual entry screens

**Files:**
- Create: `RescueTriage/Views/QueueView.swift`
- Create: `RescueTriage/Views/DeclarationView.swift`
- Create: `RescueTriage/Views/TallyBar.swift`

**Interfaces:**
- Consumes: `SessionStore`, `SupplierDeclaration`, `RescuePalette`.
- Produces: `QueueView()`, `DeclarationView(declaration:onScan:)`, `DeclarationEditor(declaration:onSave:)`, `TallyBar(tally:)`.

- [ ] **Step 1: Write `TallyBar.swift`**

```swift
// RescueTriage/Views/TallyBar.swift
import SwiftUI

/// The running session total. This is the line that makes the demo a business
/// case rather than a gadget.
struct TallyBar: View {
    let tally: SessionTally

    private var euros: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: tally.valueRecovered as NSDecimalNumber) ?? "—"
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                cell("\(tally.count)", "triaged")
                cell("\(tally.accepted)", "accepted", tint: RescuePalette.lime)
                cell("\(tally.held)", "held", tint: RescuePalette.amber)
                cell("\(tally.rejected)", "rejected", tint: RescuePalette.orange)
            }
            if tally.count > 0 {
                HStack(spacing: 18) {
                    Text("\(String(format: "%.0f", tally.kgDiverted)) kg out of the bin")
                    Text("·")
                    Text("\(euros) recovered")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(RescuePalette.navy)
    }

    private func cell(_ value: String, _ label: String, tint: Color = .white) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}
```

- [ ] **Step 2: Write `QueueView.swift`**

```swift
// RescueTriage/Views/QueueView.swift
import SwiftUI

struct QueueView: View {
    @EnvironmentObject private var store: SessionStore
    @State private var selected: SupplierDeclaration?
    @State private var showingEditor = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TallyBar(tally: store.tally)
                list
            }
            .background(RescuePalette.cream)
            .navigationTitle("Intake")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingEditor = true } label: { Image(systemName: "plus") }
                }
            }
            .navigationDestination(item: $selected) { declaration in
                DeclarationView(declaration: declaration)
            }
            .sheet(isPresented: $showingEditor) {
                NavigationStack {
                    DeclarationEditor { store.add($0) }
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack { SettingsView() }
            }
        }
    }

    private var list: some View {
        List {
            if !store.queue.isEmpty {
                Section("Waiting") {
                    ForEach(store.queue) { declaration in
                        Button { selected = declaration } label: { row(declaration) }
                            .buttonStyle(.plain)
                    }
                }
            }
            if !store.processed.isEmpty {
                Section("Done") {
                    ForEach(store.processed) { item in
                        processedRow(item)
                    }
                }
            }
            if store.queue.isEmpty && store.processed.isEmpty {
                Text("Nothing in the queue.")
                    .foregroundStyle(RescuePalette.muted)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func row(_ declaration: SupplierDeclaration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(declaration.supplier.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(RescuePalette.orange)
            Text(declaration.productName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(RescuePalette.ink)
            Text(declaration.summaryLine)
                .font(.system(size: 13))
                .foregroundStyle(RescuePalette.muted)
        }
        .padding(.vertical, 4)
    }

    private func processedRow(_ item: ProcessedItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.declaration.productName)
                    .font(.system(size: 15, weight: .semibold))
                Text(item.declaration.supplier)
                    .font(.system(size: 12))
                    .foregroundStyle(RescuePalette.muted)
            }
            Spacer()
            Text(item.verdict.effectiveOutcome.label)
                .font(.system(size: 10, weight: .heavy))
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(
                    RescuePalette.background(for: item.verdict.effectiveOutcome),
                    in: Capsule()
                )
                .foregroundStyle(RescuePalette.foreground(for: item.verdict.effectiveOutcome))
        }
    }
}
```

- [ ] **Step 3: Write `DeclarationView.swift`**

```swift
// RescueTriage/Views/DeclarationView.swift
import SwiftUI

/// Read the supplier's claims, correct anything wrong, then go and photograph it.
struct DeclarationView: View {
    let declaration: SupplierDeclaration
    @State private var editable: SupplierDeclaration
    @State private var scanning = false

    init(declaration: SupplierDeclaration) {
        self.declaration = declaration
        _editable = State(initialValue: declaration)
    }

    var body: some View {
        Form {
            Section("Supplier") {
                LabeledContent("Store", value: editable.supplier)
                LabeledContent("Product", value: editable.productName)
                LabeledContent("Category", value: editable.category.label)
                LabeledContent("Quantity",
                               value: "\(editable.formattedQuantity) \(editable.unit)")
            }

            Section("Dates") {
                DatePicker("Arrived at supplier", selection: $editable.arrivalDate,
                           displayedComponents: .date)
                Picker("Date type", selection: $editable.expiryKind) {
                    ForEach(ExpiryKind.allCases) { Text($0.label).tag($0) }
                }
                DatePicker(editable.expiryKind.label, selection: $editable.expiryDate,
                           displayedComponents: .date)
            }

            Section("Their stated problem") {
                Picker("Reason", selection: $editable.declaredReason) {
                    ForEach(RejectReason.allCases) { Text($0.label).tag($0) }
                }
                if editable.declaredReason.isCosmetic {
                    Label("Cosmetic — costs nothing in our scoring",
                          systemImage: "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RescuePalette.muted)
                }
            }

            if editable.category.isColdSensitive {
                Section("Cold chain") {
                    Stepper(
                        editable.coldChainGapMinutes.map { "Gap: \($0) min" } ?? "No gap declared",
                        value: Binding(
                            get: { editable.coldChainGapMinutes ?? 0 },
                            set: { editable.coldChainGapMinutes = $0 == 0 ? nil : $0 }
                        ),
                        in: 0...180, step: 5
                    )
                    if let temp = editable.storageTempC {
                        LabeledContent("Storage temperature",
                                       value: String(format: "%.1f °C", temp))
                    }
                }
            }
        }
        .navigationTitle("Declaration")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button { scanning = true } label: {
                Label("Scan the product", systemImage: "camera.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RescuePalette.orange, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .navigationDestination(isPresented: $scanning) {
            ScanView(declaration: editable)
        }
    }
}

/// Manual entry, for the cases the pre-loaded batches do not cover.
struct DeclarationEditor: View {
    var onSave: (SupplierDeclaration) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var supplier = "Rimi"
    @State private var productName = ""
    @State private var category: ProductCategory = .produce
    @State private var quantity = 1.0
    @State private var unit = "crates"
    @State private var arrivalDate = Date()
    @State private var expiryDate = Date()
    @State private var expiryKind: ExpiryKind = .bestBefore
    @State private var reason: RejectReason = .calibreOut
    @State private var coldChainGap = 0
    @State private var storageTemp = ""
    @State private var price = "1.00"
    @State private var weight = "10"

    private static let suppliers = [
        "Rimi", "Maxima", "Lidl", "Sky&More", "Barbora", "Elvi",
        "top!", "Mego", "Aibe", "LaTS", "Your Neighbour Grocery", "Baltic Fresh"
    ]

    var body: some View {
        Form {
            Section("Supplier") {
                Picker("Store", selection: $supplier) {
                    ForEach(Self.suppliers, id: \.self) { Text($0).tag($0) }
                }
                TextField("Product", text: $productName)
                Picker("Category", selection: $category) {
                    ForEach(ProductCategory.allCases) { Text($0.label).tag($0) }
                }
                HStack {
                    TextField("Quantity", value: $quantity, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Unit", text: $unit)
                }
            }
            Section("Dates") {
                DatePicker("Arrived at supplier", selection: $arrivalDate, displayedComponents: .date)
                Picker("Date type", selection: $expiryKind) {
                    ForEach(ExpiryKind.allCases) { Text($0.label).tag($0) }
                }
                DatePicker(expiryKind.label, selection: $expiryDate, displayedComponents: .date)
            }
            Section("Their stated problem") {
                Picker("Reason", selection: $reason) {
                    ForEach(RejectReason.allCases) { Text($0.label).tag($0) }
                }
            }
            if category.isColdSensitive {
                Section("Cold chain") {
                    Stepper("Gap: \(coldChainGap) min", value: $coldChainGap, in: 0...180, step: 5)
                    TextField("Storage temperature °C", text: $storageTemp)
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            Section("Economics") {
                TextField("Unit price €", text: $price).keyboardType(.decimalPad)
                TextField("Total weight kg", text: $weight).keyboardType(.decimalPad)
            }
        }
        .navigationTitle("New item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { save() }
                    .disabled(productName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func save() {
        onSave(SupplierDeclaration(
            supplier: supplier,
            productName: productName,
            category: category,
            quantity: quantity,
            unit: unit,
            arrivalDate: arrivalDate,
            expiryDate: expiryDate,
            expiryKind: expiryKind,
            declaredReason: reason,
            coldChainGapMinutes: coldChainGap == 0 ? nil : coldChainGap,
            storageTempC: Double(storageTemp.replacingOccurrences(of: ",", with: ".")),
            retailUnitPrice: Decimal(Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0),
            estimatedWeightKg: Double(weight.replacingOccurrences(of: ",", with: ".")) ?? 0
        ))
        dismiss()
    }
}
```

- [ ] **Step 4: Build**

Run: `xcodebuild build -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`. `ScanView` and `SettingsView` do not exist yet, so this will fail to compile — that is expected; it is fixed in Task 13. Skip to Task 13 and build there.

- [ ] **Step 5: Commit**

```bash
git add RescueTriage/Views/QueueView.swift RescueTriage/Views/DeclarationView.swift RescueTriage/Views/TallyBar.swift
git commit -m "Queue, declaration and manual-entry screens"
```

---

### Task 13: Scan, analysis and settings — the app wired together

**Files:**
- Create: `RescueTriage/Views/ScanView.swift`
- Create: `RescueTriage/Views/SettingsView.swift`
- Modify: `RescueTriage/RescueTriageApp.swift`

**Interfaces:**
- Consumes: everything above.
- Produces: `ScanView(declaration:)`, `SettingsView()`; the app's real entry point.

The simulator has no camera, so the photo picker is a first-class path, not a fallback. Sample photos ship in the asset catalogue under the `samplePhotoName` each demo batch declares.

- [ ] **Step 1: Write `ScanView.swift`**

```swift
// RescueTriage/Views/ScanView.swift
import SwiftUI
import PhotosUI
import UIKit

struct ScanView: View {
    let declaration: SupplierDeclaration

    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var image: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var state: ScanState = .idle
    @State private var verdict: Verdict?

    private enum ScanState: Equatable {
        case idle, analysing, done
    }

    var body: some View {
        Group {
            if let verdict {
                VerdictCardView(
                    declaration: declaration,
                    verdict: verdict,
                    onOverride: { outcome in
                        store.applyOverride(outcome, to: declaration.id)
                        self.verdict?.humanOverride = outcome
                    },
                    onDone: { dismiss() }
                )
            } else {
                capture
            }
        }
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { captured in
                image = captured
                Task { await analyse(captured) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let picked = UIImage(data: data) {
                    image = picked
                    await analyse(picked)
                }
            }
        }
    }

    private var capture: some View {
        VStack(spacing: 20) {
            preview

            if state == .analysing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Checking the photo against the declaration…")
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.top, 6)
            } else {
                VStack(spacing: 12) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { showingCamera = true } label: {
                            Label("Take a photo", systemImage: "camera.fill")
                                .font(.system(size: 16, weight: .heavy))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(RescuePalette.orange, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Choose from library", systemImage: "photo.on.rectangle")
                            .font(.system(size: 16, weight: .heavy))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RescuePalette.navy, in: Capsule())
                            .foregroundStyle(.white)
                    }

                    if let sample = UIImage(named: sampleName) {
                        Button {
                            image = sample
                            Task { await analyse(sample) }
                        } label: {
                            Text("Use the sample photo")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(RescuePalette.muted)
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            Spacer()
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity)
        .background(RescuePalette.cream)
    }

    private var sampleName: String {
        DemoBatch.all.first { $0.declaration.productName == declaration.productName }?
            .samplePhotoName ?? ""
    }

    @ViewBuilder
    private var preview: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)
        } else {
            RoundedRectangle(cornerRadius: 14)
                .fill(RescuePalette.paper)
                .frame(height: 240)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.viewfinder").font(.system(size: 40))
                        Text(declaration.productName).font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(RescuePalette.muted)
                }
                .padding(.horizontal, 24)
        }
    }

    /// Gemini describes; the engine decides. If the call fails for any reason,
    /// the regulatory verdict still stands and is labelled partial.
    private func analyse(_ image: UIImage) async {
        state = .analysing

        let client = GeminiClient.fromStoredSettings()
        var observation = ScanObservation.unavailable
        var available = false

        if client.isConfigured, let jpeg = image.jpegForUpload() {
            do {
                observation = try await client.analyse(imageData: jpeg, declaration: declaration)
                available = true
            } catch {
                observation = .unavailable
                available = false
            }
        }

        let result = VerdictEngine.evaluate(
            declaration: declaration,
            observation: observation,
            now: Date(),
            geminiAvailable: available
        )

        store.record(declaration: declaration, verdict: result)
        verdict = result
        state = .done
    }
}

extension UIImage {
    /// Gemini does not need a 12-megapixel photo, and a smaller upload is a
    /// faster demo. Long edge 1568 px, JPEG quality 0.8.
    func jpegForUpload(maxEdge: CGFloat = 1568, quality: CGFloat = 0.8) -> Data? {
        let longest = max(size.width, size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxEdge / longest)
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: quality)
    }
}

/// UIKit camera, wrapped. SwiftUI has no native camera capture on iOS 17.
struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage { parent.onCapture(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
```

- [ ] **Step 2: Write `SettingsView.swift`**

```swift
// RescueTriage/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey = ""
    @State private var model = UserDefaults.standard.string(forKey: "gemini.model")
        ?? GeminiClient.defaultModel
    @State private var saved = false

    var body: some View {
        Form {
            Section {
                SecureField("AIza…", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Model", text: $model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Save") { save() }
                if saved {
                    Label("Saved to the Keychain", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(RescuePalette.muted)
                        .font(.system(size: 13, weight: .semibold))
                }
            } header: {
                Text("Gemini")
            } footer: {
                Text("""
                The key is stored in this device's Keychain and never leaves it except \
                in calls to Google. Without a key the app still runs: it applies the \
                expiry, cold-chain and temperature rules and marks each verdict as partial.

                Model identifiers change faster than app releases, which is why this \
                field is editable.
                """)
            }

            Section("Session") {
                LabeledContent("Triaged", value: "\(store.tally.count)")
                Button("Reset the session", role: .destructive) {
                    store.reset()
                    dismiss()
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
        .onAppear { apiKey = KeychainStore.read() ?? "" }
    }

    private func save() {
        try? KeychainStore.save(apiKey)
        UserDefaults.standard.set(model.trimmingCharacters(in: .whitespaces), forKey: "gemini.model")
        saved = true
    }
}
```

- [ ] **Step 3: Wire the real entry point**

```swift
// RescueTriage/RescueTriageApp.swift
import SwiftUI

@main
struct RescueTriageApp: App {
    @StateObject private var store = SessionStore()

    var body: some Scene {
        WindowGroup {
            QueueView().environmentObject(store)
        }
    }
}
```

- [ ] **Step 4: Build and run the whole suite**

```bash
xcodebuild test -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -25
```
Expected: `** TEST SUCCEEDED **` with every test from Tasks 1–10 passing.

- [ ] **Step 5: Walk the flow in the simulator**

```bash
xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcodebuild build -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -3
xcrun simctl install booted "$(xcodebuild -showBuildSettings -scheme RescueTriage -destination 'platform=iOS Simulator,name=iPhone 17' 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{print $2; exit}')/RescueTriage.app"
xcrun simctl launch booted lv.rescue.triage
xcrun simctl io booted screenshot /tmp/rescue-queue.png
```

Check by hand, without a key configured: tap **Sky&More · 1 case yoghurt**, scan with any library photo, and confirm the verdict is a vetoed REJECTED citing the 40-minute cold-chain gap. Then tap **Elvi · 6 crates apples** and confirm ACCEPTED at 10.0 with the cosmetic-reason line. The tally bar must move both times.

- [ ] **Step 6: Commit**

```bash
git add RescueTriage/Views/ScanView.swift RescueTriage/Views/SettingsView.swift RescueTriage/RescueTriageApp.swift
git commit -m "Scan flow, settings, and the wired-up app"
```

---

### Task 14: README and install instructions

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

- [ ] **Step 1: Write `README.md`**

````markdown
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

## Documents

- Design: `docs/superpowers/specs/2026-09-13-rescue-triage-ios-design.md`
- Plan: `docs/superpowers/plans/2026-09-13-rescue-triage-ios.md`
````

- [ ] **Step 2: Commit and push**

```bash
git add README.md
git commit -m "README: how the decision works, and how to install"
git push
```

---

## Self-Review

**Spec coverage.** §3 models → Task 2. §3.4 reasons → Task 2. §4 split → Tasks 3–6, 9. §5.1 vetoes → Tasks 3, 4, 6. §5.2 cold chain → Task 4. §5.3 temperature → Task 4. §5.4 expiry → Task 3. §6 score and precedence → Tasks 5, 6. §7 Gemini → Task 9; key security → Task 8, Task 13 settings. §8 architecture → Tasks 1–13. §9 flow → Tasks 11–13. §10 demo batches → Task 7. §11 tests → every task. §12 risks → degraded mode in Tasks 6, 13; editable model in Task 13. §13 delivery → Task 14.

**Gap found and closed.** Spec §9 promises bundled sample photographs. No task can create photographs — that needs real image files. Task 13 reads them by name and degrades silently when absent (`if let sample = UIImage(named:)`), so the app is correct without them and better with them. This is called out below rather than papered over.

**Type consistency.** `RuleAssessment` is produced by every `SafetyRules` function and consumed by `ScoreCalculator.score` and `VerdictEngine.evaluate`. `Outcome.isWorse(than:)` defined in Task 2, used in Task 6. `ScanObservation.unavailable` defined in Task 2, used in Tasks 6, 7, 13. `Verdict.effectiveOutcome` defined in Task 2, used in Tasks 10, 12. `GeminiClient.defaultModel` defined in Task 9, used in Task 13. `DemoBatch.all` defined in Task 7, used in Tasks 10, 11, 13.

**Known non-blocking gap.** The twelve `samplePhotoName` values have no image assets. The "Use the sample photo" button hides itself when the asset is missing; camera and library both work regardless.

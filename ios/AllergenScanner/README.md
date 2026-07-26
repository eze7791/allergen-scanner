# Allergen Scanner (iOS/iPadOS)

Native SwiftUI app for the Allergen Scanner backend. Admins create and manage
the restaurant's food items, recipes, and allergens; staff join with a
restaurant code and get read-only access. Ingredient labels are scanned
on-device with Apple's Vision framework -- photos never leave the phone, only
the recognized text is sent to the API for allergen matching.

Talks to the API hosted at `https://allergen-scanner-api.onrender.com`
(see `Networking/APIClient.swift` to change it).

## Prerequisites

1. **Xcode** (full app, not just Command Line Tools) -- install from the Mac
   App Store. Free.
2. **XcodeGen** -- generates the `.xcodeproj` from `project.yml` so the
   project file itself doesn't need to be committed to git (avoids merge
   conflicts in Xcode's project XML). Install with Homebrew:

   ```
   brew install xcodegen
   ```

## Generate and open the project

From this directory (`ios/AllergenScanner`):

```
xcodegen generate
open AllergenScanner.xcodeproj
```

Re-run `xcodegen generate` any time `project.yml` changes (e.g. after
pulling changes that add new source files or settings).

## Running on your own iPhone (free, no paid Apple Developer account)

1. In Xcode, select your Apple ID under **Xcode > Settings > Accounts** (add
   it if it's not there -- any free Apple ID works).
2. Select the `AllergenScanner` project in the navigator, then the
   `AllergenScanner` target > **Signing & Capabilities**.
3. Under **Team**, pick your personal team (created automatically from your
   Apple ID).
4. Plug in your iPhone via cable, select it as the run destination (top bar,
   next to the Run/Stop buttons), and press **Run**.
5. First run only: on the iPhone, go to **Settings > General > VPN & Device
   Management** and trust your developer certificate.

Notes on the free-provisioning path:
- The app only installs on devices physically connected to your Mac at least
  once -- no TestFlight, no App Store, no sending a link to someone else.
- The build **expires after 7 days** and needs to be reinstalled by
  re-running from Xcode.
- Camera scanning only works on a real device -- the Simulator has no
  camera, use the Photo Library picker there instead.

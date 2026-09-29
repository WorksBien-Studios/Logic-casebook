# TestFlight issue ledger

No TestFlight session has run for this app yet.

## Provisioning pending

- Status: `open`
- Stage: `preflight`
- Signature: `ios-source-and-credential-route-missing`
- Resolved: Explicit bundle ID `com.worksbienstudios.logiccasebook`, App Store Connect app record `6817388232`, internal beta group `Internal QA` (`ef8f600d-1b25-4354-9e3a-7f8e8c556218`), and one internal tester are created and mapped.
- Symptom: The default branch does not yet contain a distributable app Xcode project/workspace with a shared scheme, and the App Store Connect API credential route is not configured.
- Prevention: The workflow is fail-closed and performs these checks on Linux before allocating macOS.
- Next action: Add the real iOS app project, fill the Xcode fields in the non-secret app map, configure the App Store Connect credential route, then switch the map state to `ready`.

## Tester target

- Status: `resolved`
- `Internal QA` contains both designated internal tester accounts.
- The delivery helper assigns the exact processed build to that group and attaches the same build to the editable App Store version for later review without re-signing.

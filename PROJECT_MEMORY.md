# Project Memory — FINAL.zip

**Reviewed:** 2026-09-18 15:22–15:23 (+06:00)
**Source archive:** `/home/ubuntu/upload/FINAL.zip`
**Extracted review copy:** `/home/ubuntu/project_review`

## Identity and build

- This is a complete iOS/Xcode project named **ThreeOneOSFive**, branded in the UI as **ATH EXTERNAL / ATH REGEDIT** and described in the repository README as **HYperRegedit / 3105**.
- Xcode project: `ThreeOneOSFive.xcodeproj`; scheme: `JVZTXNX`.
- Bundle ID: `com.apple.mobile.MobileHouseArrest`; product name: `ATHEXTERNAL`; deployment target: iOS 16.0; Swift 5.0; iPhone and iPad targeted.
- App version in `Info.plist`: `1.1.1` / build `7`.
- Build scripts: `build_unsigned.sh` creates an unsigned iOS archive/IPA on macOS with Xcode; `build_esign_ready_ipa.sh` verifies that the IPA is unsigned and suitable for eSign. The current Linux sandbox cannot run `xcodebuild`.

## Main architecture

- Entry point: `ThreeOneOSFive/App.swift` (`@main` `ThreeOneOSFiveApp`). It creates shared `AppState`, `LicenseManager`, `PatchDraftCoordinator`, and `FileOperationCoordinator`; captures stdout/stderr into the in-app log; applies dark mode and language environment; checks GitHub releases for updates.
- Root UI: `ThreeOneOSFive/ContentView.swift`. Tabs are `FF Normal`, `FF Max`, and `Developer`. The main controls toggle bundled `.3105` patch packages. The Developer tab exposes app/device/license information and Telegram links.
- UI is primarily SwiftUI under `views/`; notable screens include file browser, app-data browser, cleaner, patch projects/editor, wallpaper lab, settings, onboarding, and logs.
- Shared services/models are under `helpers/`; low-level Objective-C implementation is under `exploit/` and `kexploit/`.

## Patch/file workflow

- Bundled `.3105` packages are installed into Application Support under `PatchProjects`; imported packages can be password protected.
- Current button mapping in `ContentView.swift`: **FF NORMAL** → `ATH BODY.3105`, `ATH DRAG.3105`, `ATH MAGIC.3105`; **FF MAX** → `ATH BODY M.3105`, `ATH DRAG M.3105`, `ATH MAGIC M.3105`.
- The six ATH packages were added to `ThreeOneOSFive/Patches` and to the Xcode Resources build phase from `FFNORMAL.zip` and `FFMMAX.zip`. Bundled ATH packages are silently decoded with the internal bundled-password list (including the supplied `XRE` password); the user-facing button flow does not display or request that password.
- Runtime fix: `PatchProjectLibrary.load()` now deduplicates by standardized package URL instead of package UUID. The supplied NORMAL/MAX variants share package IDs/content, so UUID-based deduplication previously hid five filenames and caused `PACKAGE NOT FOUND` on buttons.
- Resource-path fix: all `.3105` PBX file references now use `SOURCE_ROOT` because their paths already include `ThreeOneOSFive/Patches/...`; runtime discovery also recursively scans the complete app bundle so nested or flattened Xcode resource layouts are both supported.
- `PatchProjectModels.swift` defines `PatchProject`, `PatchRule`, and `PatchDirectory`; patch rules map bundle IDs and relative target paths to replacement payload data.
- `PatchPackageCodec.swift`, `PatchKeyStore.swift`, `SecureZIPArchive.swift`, `PatchProjectLibrary.swift`, and `PatchWorkspaceService.swift` handle package inspection, encryption/key storage, safe archive handling, persistence, and editable workspaces.
- `PatchTransaction.swift` applies changes atomically, records a journal/backups, verifies replacement digests, and supports rollback/restore.
- `FileManagerService.swift` implements validated file/folder creation, rename/delete, copy/move, import, archive/extract, conflict policies, symbolic-link rejection, recursive-destination checks, and size/path safety checks.

## License/activation source of truth

- **Actual implementation is server-side verification**, not local-only activation: `LicenseManager.swift` calls `APONLicenseSDK.verify(...)` during initialization/launch and stores key/status/expiry/last verification in Keychain.
- `APONLicenseSDK.swift` posts to `APONServerURL + /api/sdk/verify` (currently configured as `https://api.m3sbapi.shop`), sends device information, and signs requests with M3SB Signature v3. Valid responses require signature verification before being trusted.
- `Info.plist` contains package metadata and embedded APON credentials. Treat those credentials as sensitive; do not publish or commit them to a public repository. Do not reproduce their values in future notes.
- `README.md` is stale/inconsistent: it claims a local key and no API server, while `API_INTEGRATION.md`, `Info.plist`, `LicenseManager.swift`, and `APONLicenseSDK.swift` describe the current server-backed flow. Prefer the latter files when changing activation behavior.

## Device access / low-level behavior

- `AppState.detectSupport()` checks supported iOS/build combinations and may automatically run the kernel exploit when applicable.
- `KernelExploit.swift` wraps the native chain `kexploit_opa334` followed by `sandbox_escape`; iOS 26+ requires verified sandbox access, while older supported versions can use kernel R/W fallback.
- `exploit/` and `kexploit/` contain low-level private/unsupported iOS functionality. Changes require physical-device testing and careful compatibility review; simulator support is only a preview path (`--simulate-access`).

## Important operational notes

- Before modifying activation, first reconcile the stale README against the current APON SDK implementation and protect embedded credentials.
- Before modifying patch application, preserve path validation, symlink rejection, transaction journaling, digest verification, rollback, and restore behavior.
- Before building, use macOS/Xcode and inspect signing/provisioning requirements; the supplied build output is intentionally unsigned for eSign.
- The archive contains 130 files (~8.6 MB uncompressed). The extracted review copy and this memory note are available at `/home/ubuntu/project_review`.

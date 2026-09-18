# API integration

The app now uses the M3SB APON SDK and server-side Signature v3 license verification. The base URL is `https://api.m3sbapi.shop`, and verification uses `/api/sdk/verify`; saved keys are rechecked on launch. Package credentials are stored in the app Info.plist for this private build and must not be committed to a public repository.

Build on macOS with Xcode, then test with a valid license key issued for package `ATH IPA` (package ID 106) and bundle ID `com.apple.mobile.MobileHouseArrest`.

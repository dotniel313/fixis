# FIXIS PRO v1.5.0 — Wallet v2 + Settlements

This package is based on the validated v1.4.2 client.

## Install
1. Back up current `lib/`.
2. Apply Migration 011 after the already-applied Migration 010.
3. Replace the project's `lib/` with this package's `lib/`.
4. Run:
   - `flutter clean`
   - `flutter pub get`
   - `flutter analyze`
   - `flutter run`

## First functional test
Do not pay a withdrawal immediately. First request USD 20 from the app and verify:
- available = 25.50
- reserved = 20.00
- earned = 45.50
- withdrawn = 0.00

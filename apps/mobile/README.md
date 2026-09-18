# Mobile migration boundary

The existing Flutter app intentionally remains at the repository root during the first monorepo phase. This avoids breaking Android/iOS package paths, launcher assets, test fixtures, and the `tipkhun.plan.v1` local storage key.

When the remote API migration is proven, move the Flutter project here in one reviewed change and verify `flutter analyze`, `flutter test`, Android build, iOS build, Web build, and legacy-data reload before removing the root location. Do not copy or maintain a second mobile implementation.

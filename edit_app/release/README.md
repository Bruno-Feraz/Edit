# Note firma e build release — Edit

## macOS (Developer ID + notarizzazione)

1. `flutter build macos --release`
2. Firmare `build/macos/Build/Products/Release/Edit.app` con Developer ID Application
3. Creare DMG o zip, notarizzare con `notarytool`, staple
4. Calcolare SHA-256 e salvarlo in `release/`

Esempio (sostituire identità):

```bash
codesign --deep --force --options runtime \
  --sign "Developer ID Application: …" \
  build/macos/Build/Products/Release/Edit.app

ditto -c -k --keepParent \
  build/macos/Build/Products/Release/Edit.app \
  release/Edit-macos.zip

xcrun notarytool submit release/Edit-macos.zip \
  --apple-id … --team-id … --password … --wait
xcrun stapler staple build/macos/Build/Products/Release/Edit.app
shasum -a 256 release/Edit-macos.zip > release/Edit-macos.sha256
```

## Android (Play AAB)

1. Configurare keystore di produzione (fuori dal repo)
2. `flutter build appbundle --release`
3. Caricare AAB su Play Console (internal → production)
4. Archiviare AAB + SHA-256 in `release/`

```bash
flutter build appbundle --release
shasum -a 256 build/app/outputs/bundle/release/app-release.aab \
  > release/Edit-android.sha256
```

## SBOM

```bash
cd edit_app
dart run scripts/generate_sbom.dart
```

## Checklist

Seguire `../RELEASE-CHECKLIST.md` e allegare copia spuntata alla cartella `release/`.

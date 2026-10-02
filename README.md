# Edit

Editor video minimale nativo per **macOS** e **Android**: taglia, voice-over, testo, pulizia audio/immagine, rimozione sfondo, movimento fluido su immagini, export per TikTok e YouTube.

Offline-first: progetti e media restano sul dispositivo.

## Certificazione d'uso

**Uso privato / personale soltanto. Uso commerciale vietato.**  
Vedi [`LICENSE`](LICENSE).

## Stack

- Flutter (macOS + Android)
- FFmpeg (export) — richiesto nel PATH: `brew install ffmpeg`

## Funzionalità (v1)

- Home progetti e persistenza locale
- Import video, preview, timeline (spezza / trim / elimina)
- Undo / redo
- Export MP4 con preset social (9:16, 16:9, 1:1)

## Avvio

```bash
cd edit_app
flutter pub get
flutter run -d macos
# oppure
flutter run -d <android-device-id>
```

## Struttura

```text
Edit/
├── PRD.md
├── RELEASE-CHECKLIST.md
├── STORE-LISTING.md
└── edit_app/
    ├── lib/          # models, services, editor, preview, timeline, tools
    ├── macos/
    ├── android/
    └── scripts/
```

## Documentazione

- [`PRD.md`](PRD.md)
- [`RELEASE-CHECKLIST.md`](RELEASE-CHECKLIST.md)
- [`STORE-LISTING.md`](STORE-LISTING.md)
- [`edit_app/README.md`](edit_app/README.md)
- [`edit_app/SECURITY.md`](edit_app/SECURITY.md)

## Autore

Bruno Feraz

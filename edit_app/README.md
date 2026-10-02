# Edit

Editor video minimale per **macOS** e **Android** (Flutter).  
PRD: `../PRD.md`

## Avvio

```bash
cd edit_app
flutter run -d macos
# oppure
flutter run -d <android-device-id>
```

## Stato

- Fase 0: home progetti, tema dark, persistenza locale
- Fase 1: import video, preview, timeline (spezza/trim/elimina), undo/redo, export FFmpeg

Export richiede `ffmpeg` nel PATH (`brew install ffmpeg`). Output in `…/Edit/projects/<id>/exports/`.

## Struttura (modulare)

```
lib/
  models/          # project, timeline_clip
  services/        # store, import, export, undo
  editor/          # EditorController
  preview/         # VideoPreviewPane
  timeline/        # TimelinePanel
  tools/           # EditorToolbar
  screens/         # Home, Editor
  theme/
```

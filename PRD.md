# PRD — Edit

App nativa per montare clip corti su **Mac** e **Android**: tagliare, voice-over, testo, pulizia audio/immagine, rimozione sfondo, movimento fluido su immagini, export pronto per TikTok e YouTube.

**Stato:** bozza v0.3 — Flutter confermato; UI dark minimale  
**Nome lavoro:** Edit  
**Piattaforme:** macOS (app firmata) + Android (APK/AAB)  
**Stack:** Flutter (confermato)  
**Utente:** creator che vuole clip pubblicabili senza CapCut/Premiere  
**UI:** minimale, clean, tema scuro, intuitiva, responsive (Mac ↔ telefono)

Fonte idea: `edit.md`. Vincoli di rilascio, sicurezza e conformità: `REGOLE-PRODUZIONE-SVILUPPO.md` (in particolare §4 software, §5 legale applicabile, CRA).

---

## 1. Perché esiste

Montare un video per social richiede tool pesanti o app chiuse. Edit fa solo il ciclo utile, offline-first sul dispositivo:

- tagliare e riordinare clip
- voce (import o registrazione) e testo parlato / sottotitoli
- migliorare immagine e audio in-app
- togliere lo sfondo
- muovere immagini in modo fluido (niente keyframe frame-per-frame)
- esportare già nel formato giusto (9:16, 16:9, 1:1) per TikTok e YouTube

Se una funzione non serve a chiudere e salvare una clip sul device, **non entra** in v1.

---

## 2. Principi

1. **Nativo Mac + Android, non sito.** Nessuna dipendenza obbligatoria da browser o hosting web per editare.
2. **Timeline prima di tutto.** Preview + timeline + playhead. Tutto passa da lì.
3. **Poche azioni, prevedibili.** Taglia, spezza, sposta, elimina, mute, volume, testo, audio, effetto.
4. **Media sul device.** Progetti e file restano locali (sandbox app). Cloud sync = fuori v1.
5. **Export = prodotto finito.** File MP4 salvato in Archivio/Galleria/condivisione di sistema.
6. **Formati social nativi.** Preset canvas e export senza ricette manuali.
7. **Stesso prodotto, UI adattata.** Mac = mouse/trackpad + scorciatoie; Android = touch e sheet. Stesso modello progetto.
8. **UI minimale e scura.** Pochi controlli, gerarchia chiara, zero clutter. Tema scuro di default (editor video). Responsive: layout che scala da telefono a finestra Mac larga.
9. **Intuitivo al primo uso.** Azioni primarie evidenti (Nuovo, Importa, Taglia, Esporta); niente jargon da NLE.
10. **Rilascio sicuro.** Build firmata, niente segreti nel binario, SBOM, contatto vulnerabilità, update verificato (regole §4).

---

## 2.1 Design UI / UX

| Regola | Dettaglio |
| --- | --- |
| **Minimal** | Una barra tool essenziale; niente pannelli secondari aperti di default |
| **Clean** | Superfici piatte, pochi bordi, tipografia leggibile, spacing coerente |
| **Dark** | Sfondo quasi nero, superfici elevate leggermente più chiare, accento unico (non viola generico) |
| **Intuitivo** | Icone + label corte; conferma solo su azioni distruttive |
| **Responsive** | Breakpoint: stretto (<600) = colonna (preview → tool → timeline); largo = preview + sidebar tool, timeline full-width sotto |
| **Motion** | Micro-transizioni misurate; rispetta `prefers-reduced-motion` / disable animazioni OS |

Token (da fissare in codice):

- `bg` / `surface` / `surfaceHigh`
- `text` / `textMuted`
- `accent` (un solo colore brand)
- `danger` per elimina
- raggio piccolo (4–8), niente pill decorative

---

## 3. Cosa non è (fuori scope v1)

- Versione web / PWA / Electron-solo-browser
- iOS (possibile dopo; non bloccante v1)
- Premiere / DaVinci (multicam, grading pro, nesting)
- After Effects (motion pro, expression)
- Collaborazione real-time / team cloud
- Pubblicazione OAuth diretta su TikTok/YouTube (v1 = file locale + share sheet; API = v1.x)
- AI generazione video da prompt, lip-sync avatar, stock library

---

## 4. Piattaforme e stack (proposta)

| Target | Forma | Note |
| --- | --- | --- |
| **macOS** | App `.app` / DMG, firmata | Windowed, menu bar, drag&drop file |
| **Android** | AAB Play Store (+ APK sideload dev) | Touch-first, permessi mic/storage |

**Stack (confermato):** **Flutter** + FFmpeg (plugin / binary bundlato) + ML on-device per rembg dove possibile. Un repo, target macOS + Android.

Cartella app: `edit_app/`.

### 4.1 Dove gira il lavoro pesante

| Job | Dove |
| --- | --- |
| Preview / scrub | On-device (decoder nativo / texture) |
| Export MP4 | FFmpeg locale (coda in-process) |
| Denoise audio | Libreria locale (es. RNNoise) o filtro FFmpeg |
| Rimozione sfondo | Modello on-device (MediaPipe / ONNX) se fattibile; altrimenti job opzionale remoto **esplicito** |
| STT / TTS | Post-MVP; se terzi → policy IA + consenso |

Niente chiave API compilata nel client. Se un giorno c’è un backend opzionale, le chiamate passano da lì con scope stretto.

---

## 5. Visione prodotto (flusso)

```text
Import video/immagini/audio (file picker / share intent)
    → Timeline (tagli, ordine, durata)
    → Voce (import o registra) + testo
    → Effetti (sfondo, pulizia, motion immagini)
    → Preset social + export
    → Salva / Condividi (Files, Foto, Intent Android)
```

Un **progetto** = cartella/documento locale: media copiati o referenziati in sandbox, `project.json` (timeline, canvas, effetti), autosave.

---

## 6. Funzionalità

### 6.1 Progetto e media

| Funzione | Dettaglio v1 |
| --- | --- |
| Nuovo progetto | Nome, aspect ratio (9:16 default) |
| Import video | MP4/MOV (Mac); MP4/3GP comuni Android |
| Import immagini | PNG/JPEG/WebP |
| Import audio | MP3/WAV/M4A/AAC |
| Libreria progetto | Lista media; elimina con conferma |
| Persistenza | Solo locale; path interni non esposti all’utente |

### 6.2 Timeline e tagli

- Tracce base: **2 video** (V1, V2) + **2 audio** (A1, A2). Si possono aggiungere tracce audio extra.
- Clip e immagini sulle tracce video; audio/VO sulle tracce audio.
- Spezza al playhead, trim, sposta, riordina, elimina, snap
- Undo/redo
- Zoom timeline, scrub, preview sync
- Transizione: cut hard in MVP; dissolve in v1.1

### 6.2.1 Layout editor (shell)

```text
┌────────────────────────────────┬─────────────────────────┐
│         Preview canvas         │  Pannello destro        │
│                                │  DINAMICO (inspector)   │
├────────────────────────────────┤  — Media (clip/img)     │
│  Toolbar piccola (sopra TL)    │  — Audio / VO           │
│  [Import][Spezza][Trim]…       │  — Rimuovi sfondo       │
├────────────────────────────────┤  — Pulisci audio        │
│  V1  ████  ██                  │  Sezioni/menu/finestre  │
│  V2     ████                   │  (non barra fissa tool) │
│  A1  ▭▭▭                     │                         │
│  A2                            │                         │
└────────────────────────────────┴─────────────────────────┘
```

Regole UI:

1. **Azioni di montaggio** (import, spezza, trim, elimina, undo/redo, play) = **bottoni piccoli sopra la timeline**, non colonna destra fissa.
2. **Destra** = spazio **dinamico**: cambia contenuto in base al tab/bottone scelto (media library, crea traccia audio, rimozione sfondo, pulizia audio, dettagli clip…). Menu e finestre/dialog dove serve; niente toolbar monolitica sempre uguale.
3. Responsive stretto: preview sopra; sotto toolbar+timeline; inspector in bottom sheet o tab.

### 6.3 Testo parlato / caption

MVP: caption/overlay manuali (posizione, durata, stile preset social).  
v1.1: trascrizione automatica (STT) editabile; TTS opzionale con policy IA.

### 6.4 Voice-over

Schermata **Registra voce**:

- permesso microfono, waveform, countdown
- start / pausa / stop / riascolta
- salva come clip audio nel progetto → timeline
- import file audio come alternativa

### 6.5 Effetti

| Effetto | MVP | Note |
| --- | --- | --- |
| Rimozione sfondo | Sì | On-device se stabile |
| Enhance immagine | Base | Esposizione, contrasto, saturazione, sharpness |
| Denoise audio | Sì | Locale |
| Normalize loudness | Base | In export |

Job lunghi: UI con progresso / annulla; device non deve sembrare bloccato.

### 6.6 Movimento fluido immagini

Ken Burns / motion path: start → end (scale/position), easing, durata = clip. Niente keyframe per frame.

### 6.7 Clipping social

- Preset canvas: **9:16**, **16:9**, **1:1**
- Safe area overlay in preview (non nel render)
- Export: risoluzione, 30 fps default, AAC
- Condivisione via share sheet / Esporta in…

### 6.8 Mac vs Android (UX)

| | Mac | Android |
| --- | --- | --- |
| Input | Mouse, trackpad, scorciatoie | Touch, gesture |
| Import | Drag&drop + Open | Picker / share into app |
| Export | Save dialog + Reveal in Finder | MediaStore / share |
| Layout | Preview + inspector dinamico a destra; tool piccoli sopra TL multi-traccia | Preview full-width; tool sopra TL; inspector in sheet |

---

## 7. Account e dati

v1 **senza account obbligatorio**: progetti solo sul device.

Opzionale post-MVP: account per sync/licenza Pro — allora sessione sicura, age gate, marketing opt-in, isolamento UUID (regole §3/§5).

Classificazione: video/audio utente = **sensibili**; restano sul device; niente upload silenzioso; crash report senza contenuti media.

---

## 8. Architettura app

```text
UI Flutter (macOS + Android)
    → Domain: Project / Timeline / Effects
    → Media engine: decode, preview, FFmpeg export
    → ML locale: rembg / denoise (plugin)
    → OS: file picker, mic, share, notifications job
```

Documento progetto (es.):

```text
ProgettoEdit/
  project.json
  media/<uuid>.<ext>
  cache/proxies/...
  exports/   (opzionale, o solo ultimo path scelto)
```

Identificativi media = UUID. Nessun path storage interno mostrato come “nome” all’utente.

---

## 9. Rilascio e conformità (software)

Checklist essenziale da regole §4 / §5 / CRA:

- Nessun segreto nell’artefatto; credenziali diverse se un giorno c’è backend
- Build Mac firmata; Android firmata (keystore); update solo da canale ufficiale con verifica
- SBOM della release; versione + commit tracciabili
- Contatto pubblico vulnerabilità (`security@` o pagina)
- Errori utente generici; stack solo in log locali di debug
- Se c’è IA remota: pagina/in-app **uso dell’IA**, no training su contenuti senza consenso
- Age gate solo se/quando c’è signup
- Periodo di supporto dichiarato quando si distribuisce come prodotto sul mercato UE

Landing/marketing del prodotto possono essere un sito separato; **l’editor no**.

---

## 10. Monetizzazione (bozza)

- Free: export limitati / risoluzione cap
- Pro: IAP (Android Play Billing) + Mac (Store o licenza) — da decidere canale

Termini di rinnovo chiari prima del pagamento se abbonamento (regole §5).

---

## 11. Roadmap build

### Fase 0 — Fondamenta ✅

- [x] Repo Flutter (macOS + Android) in `edit_app/`
- [x] Shell UI: home progetti, nuovo, apri, elimina
- [x] Modello `project.json` + sandbox locale
- [x] Token UI dark minimale + layout responsive

### Fase 1 — Editor core ✅

- [x] Import video, preview, spezza/trim/undo, export FFmpeg
- [ ] Layout: tool piccoli sopra timeline; 2V+2A; inspector destro dinamico ← **in corso**

### Fase 1.1 — Shell UI (layout) ✅

- [x] Toolbar montaggio sopra la timeline (bottoni piccoli)
- [x] Timeline multi-traccia: V1, V2, A1, A2 (+ aggiungi audio)
- [x] Inspector destro dinamico: Media, Audio/VO, Rimuovi sfondo, Pulisci audio
- [x] Menu/dialog per import e aspect (non colonna tool fissa)
- Effetti rembg/denoise: UI placeholder → logica in Fase 4

### Fase 2 — Audio e testo ✅

- [x] Import audio + schermata **Registra voice-over**
- [x] Caption manuali (traccia T1) + tab Testo
- [x] Volume clip audio + mix VO/caption in export FFmpeg

### Fase 2.1 / 4 — Intelligenza e motion ✅

- [x] **Sottotitoli automatici** dall’audio (Whisper CLI se presente, altrimenti chunk editabili)
- [x] **Rimuovi sfondo** immagini/video via rembg/backgroundremover CLI
- [x] **Animazioni** immagini (Ken Burns/pan) e testo (fade/slide) in preview
- [x] Help in-app dalla toolbar / app bar

### Fase 3 — Social + polish ✅

- [x] Logo brand: E nera in cerchio verde (asset + icone Mac/Android)
- [x] Preset canvas 9:16 / 16:9 / 1:1
- [x] Export preset social (TikTok/Shorts, YouTube, 1:1) + scale FFmpeg
- [x] Share file dopo export (`share_plus`) + bottone share in toolbar
- [x] Scorciatoie Mac

### Fase 4 — Effetti ✅

- [x] Enhance (luminosità / contrasto / saturazione) preview + export
- [x] Denoise audio (FFmpeg afftdn / filtri) su clip selezionato
- [x] Rembg + motion già in 2.1

### Fase 5 — Release ✅ (preparazione)

- [x] Checklist binario (`RELEASE-CHECKLIST.md`, da §9 REGOLE adattata)
- [x] SBOM CycloneDX da `pubspec.lock` (`scripts/generate_sbom.dart` → `release/`)
- [x] `SECURITY.md` (contatto vulnerabilità + nota CRA art. 14)
- [x] Bozza store listing (`STORE-LISTING.md`)
- [x] Note firma macOS/Android (`edit_app/release/README.md`)
- [ ] Firma Developer ID + notarizzazione (richiede certificato Apple dell’autore)
- [ ] Keystore produzione Android + upload Play (richiede account store)
- [ ] Casella `security@` / `support@` reali al go-live

---

## 12. Criteri successo MVP

Su **Mac e Android**, in una sessione:

1. crea progetto 9:16
2. importa un video, lo taglia
3. registra ~10s di voice-over in timeline
4. aggiunge una riga di testo
5. esporta MP4 e lo apre/condivide dal sistema

---

## 13. Decisioni

| Decisione | Scelta |
| --- | --- |
| Stack | **Flutter** |
| UI | Dark, minimale, clean, responsive |
| iOS v1 | No |
| Account v1 | No (solo locale) |
| Rembg | On-device (fallback cloud solo se necessario e esplicito) |

Aperti: brand definitivo / bundle id store, watermark free, canale IAP.

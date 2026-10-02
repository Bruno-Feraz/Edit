import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Guida in-app: come funzionano le feature di Edit.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _sections = <_HelpSection>[
    _HelpSection(
      title: 'Progetti',
      body:
          'Dalla home crea un progetto (default 9:16). I file restano sul dispositivo, nella sandbox dell’app. Tocca il nome in editor per rinominare.',
    ),
    _HelpSection(
      title: 'Import e libreria',
      body:
          'Toolbar → Importa (video/immagine o audio), oppure tab Media a destra → Aggiungi. I file compaiono in libreria: “+” li mette sulla timeline (traccia V o A scelta dal menu).',
    ),
    _HelpSection(
      title: 'Timeline',
      body:
          'V1/V2 = video e immagini · A1/A2… = audio/VO · T1 = testo/caption. Ruler in alto con tacche per taglio e trasporto. Trascina i clip: si agganciano (snap) se start/end sono vicini, anche tra tracce diverse. Playhead (cerchio cyan) o tap sulla riga. Play con Space. Spezza con B o col forbici. Trim ±0.5s e Elimina nella toolbar sopra la timeline.',
    ),
    _HelpSection(
      title: 'Voice-over',
      body:
          'Toolbar mic oppure tab Audio → Registra voice-over. Schermata dedicata: Registra → Stop → Usa sulla timeline. Il take va sulla traccia audio selezionata, allineato al playhead. Volume dal tab Audio se il clip è selezionato.',
    ),
    _HelpSection(
      title: 'Testo e sottotitoli',
      body:
          'Caption manuali: toolbar “Aa” o tab Testo → Aggiungi caption, poi modifica il testo. '
          'Sottotitoli automatici: tab Testo → Genera dall’audio: Edit estrae l’audio e prova a trascrivere (Whisper CLI se installato). I risultati finiscono su T1 ed sono editabili.',
    ),
    _HelpSection(
      title: 'Animazioni',
      body:
          'Seleziona un’immagine sulla timeline: nel pannello destro (Media / Animazione) scegli Ken Burns o pan. '
          'Per il testo: fade o slide. L’anteprima segue il playhead; in export le motion vengono applicate dove supportato.',
    ),
    _HelpSection(
      title: 'Rimuovi sfondo',
      body:
          'Tab “Rimuovi sfondo”: seleziona clip immagine o video e avvia. Preferisce tool locali (rembg / backgroundremover) se presenti nel PATH; altrimenti indica come installarli. Il risultato sostituisce il media del clip (flag “sfondo rimosso”).',
    ),
    _HelpSection(
      title: 'Pulisci audio',
      body:
          'Tab “Pulisci audio”: seleziona un clip audio/video e avvia. Usa FFmpeg (afftdn) e scrive un nuovo file in sandbox.',
    ),
    _HelpSection(
      title: 'Enhance',
      body:
          'Tab Enhance: luminosità, contrasto, saturazione sul clip video/immagine. Anteprima live; export con filtro eq.',
    ),
    _HelpSection(
      title: 'Formato ed export',
      body:
          'In alto: 9:16 / 16:9 / 1:1. Esporta apre i preset social (TikTok 1080×1920, YouTube 1920×1080, quadrato) oppure il formato progetto. Poi puoi Condividi il MP4. Su Mac serve ffmpeg.',
    ),
    _HelpSection(
      title: 'Scorciatoie Mac',
      body: 'Space = play/pausa · B = spezza · ⌘Z = annulla · ⇧⌘Z = ripeti.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guida Edit')),
      body: ListView.separated(
        padding: const EdgeInsets.all(EditTokens.spaceLg),
        itemCount: _sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: EditTokens.spaceMd),
        itemBuilder: (context, i) {
          final s = _sections[i];
          return Container(
            padding: const EdgeInsets.all(EditTokens.spaceMd),
            decoration: BoxDecoration(
              color: EditTokens.surface,
              borderRadius: BorderRadius.circular(EditTokens.radiusMd),
              border: Border.all(color: EditTokens.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(s.body, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HelpSection {
  const _HelpSection({required this.title, required this.body});
  final String title;
  final String body;
}

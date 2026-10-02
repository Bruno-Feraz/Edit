# Security — Edit

## Segnalare una vulnerabilità

Se trovi un problema di sicurezza in Edit (app macOS o Android), **non** aprire una issue pubblica con dettagli sfruttabili.

Scrivi a: **security@edit.app**  
(sostituire con casella reale prima del go-live; deve essere letta entro 2 giorni lavorativi.)

Includi:

- versione app (`Impostazioni` / `pubspec` version)
- piattaforma (macOS / Android) e OS
- passi per riprodurre
- impatto stimato

## Risposta attesa

1. Conferma di ricezione entro 2 giorni lavorativi
2. Valutazione e, se confermato, fix nella prossima release firmata
3. Credit opzionale se richiesto

## Notifiche autorità (CRA art. 14)

In caso di vulnerabilità sfruttata attivamente o incidente grave sulla sicurezza del prodotto:

- avviso al CSIRT coordinatore / ENISA entro **24 ore**
- notifica entro **72 ore**
- rapporto finale secondo i tempi di regolamento

Responsabile operativo: da nominare prima dell’immissione sul mercato UE.

## Ambito v1

Edit è offline-first: progetti e media restano sul device. Non ci sono account cloud né backend obbligatorio in v1. I rischi tipici riguardano lettura file locali, permessi mic/storage e integrità del binario firmato.

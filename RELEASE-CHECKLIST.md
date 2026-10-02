# Checklist release — Edit (binario Mac + Android)

Adattata da `REGOLE-PRODUZIONE-SVILUPPO.md` §4 / §9 per un’app nativa (niente SEO web).  
Spuntare a ogni build destinata a utenti.

## Identità release

- [ ] Versione in `pubspec.yaml` (`version: x.y.z+build`) allineata a macOS/Android
- [ ] Data release e canale (DMG / TestFlight-no / Play internal / APK sideload)
- [ ] Commit git della build annotato
- [ ] Hash SHA-256 del binario (`.app` zip / DMG / AAB / APK) archiviato in `release/`
- [ ] SBOM generato con `dart run scripts/generate_sbom.dart` e archiviato in `release/`

## Build e codice

- [ ] `flutter analyze` senza issue
- [ ] `flutter test` ok
- [ ] Nessun segreto / API key nel repo o nel binario
- [ ] Nessun placeholder / TODO / lorem visibile in UI
- [ ] Media: stream/path su disco, un solo `VideoPlayerController` attivo
- [ ] Dipendenze da `pubspec.lock`; `flutter pub outdated` rivisto

## Firma e distribuzione

- [ ] macOS: build firmata (Developer ID) + notarizzazione Apple
- [ ] Android: AAB firmato con keystore di produzione (non debug)
- [ ] Canale update (se presente) HTTPS + verifica firma/hash
- [ ] Bundle id: macOS `it.edit.editApp` · Android `it.edit.edit_app`

## Sicurezza prodotto

- [ ] Contatto vulnerabilità pubblico in `SECURITY.md` (casella monitorata)
- [ ] Crash/log senza path interni, token o PII
- [ ] Permessi Android/macOS minimi (mic, file, share)
- [ ] Periodo di supporto dichiarato (vedi sotto)

## Conformità (locale, no account cloud)

- [ ] Nessun analytics/marketing di terzi prima di consenso (v1: nessuno)
- [ ] Informativa privacy: progetti e media restano sul device
- [ ] Se in futuro STT/rembg cloud: policy IA + consenso esplicito
- [ ] CRA / art. 14: procedura notifica CSIRT/ENISA documentata (contatto in SECURITY.md)

## Store listing

- [ ] Testi e screenshot in `STORE-LISTING.md` aggiornati
- [ ] Icona / feature graphic coerenti col logo (cerchio verde + E)
- [ ] Classificazione età e dichiarazioni permessi

## Periodo di supporto (dichiarazione prodotto)

| Voce | Valore |
| --- | --- |
| Prodotto | Edit |
| Supporto sicurezza fino a | **dicembre 2031** (5 anni da prima immissione prevista 2026) |
| Aggiornamenti | Build firmate via canale ufficiale |

---

Dopo la spunta: archiviare questa checklist firmata (data + versione) insieme a SBOM e hash in `edit_app/release/`.

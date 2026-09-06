# Check before pushing

Questa checklist è il gate minimo prima di push, merge o release di DadaFinanza. Non considerare una modifica conclusa finché i controlli applicabili non sono verdi.

## 1. Base Git e scope

- [ ] Partire dall'ultimo `main` e verificare che non ci siano modifiche concorrenti non considerate.
- [ ] Controllare il diff completo: niente file temporanei, dump, APK, database locali, credenziali, token o dati personali.
- [ ] Ogni modifica UI deve rispettare `docs/LINEE_GUIDA_STYLE.md` e riusare i componenti esistenti quando possibile.
- [ ] Nessuna feature visibile deve essere un placeholder, una CTA senza azione o una schermata raggiungibile ma non implementata.

## 2. Versioning

- [ ] Verificare `version:` in `pubspec.yaml`.
- [ ] Incrementare sempre il build number `+N` quando il commit deve produrre un APK distribuibile.
- [ ] Usare una patch (`x.y.Z`) per bugfix compatibili, una minor (`x.Y.0`) per nuove funzioni compatibili e una major solo per cambi incompatibili.
- [ ] Verificare che il versioning Android derivi dalla stessa versione e che non ci siano numeri di build duplicati rispetto all'ultima release distribuita.

## 3. Qualità codice obbligatoria

Eseguire nell'ordine:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug
```

Per una release candidata eseguire anche:

```bash
flutter build apk --release
```

- [ ] Nessun errore di format.
- [ ] Nessun errore di analyze.
- [ ] Tutti i test verdi.
- [ ] APK generato realmente e presente nel path atteso.

## 4. Smoke test UI / UX

Testare almeno 320, 360, 390 e 430 dp e testo ingrandito quando la schermata è stata modificata.

- [ ] Nessun overflow, rettangolo di `ErrorWidget`, schermata trasparente/nera non voluta o contenuto tagliato.
- [ ] Empty state centrati quando occupano l'intera pagina; empty state inline restano compatti.
- [ ] Light e dark theme leggibili.
- [ ] Touch target, tooltip/semantics e contrasto restano accessibili.
- [ ] Back navigation e bottom sheet/dialog non lasciano stato incoerente.

## 5. Home e dashboard

- [ ] `Personalizza Home` modifica davvero la Home: visibilità, ordine e dimensione devono avere effetto dopo il salvataggio.
- [ ] Disabilitare un widget lo rimuove dalla Home senza lasciare doppioni hard-coded.
- [ ] Riordinare verso l'alto e verso il basso mantiene l'ordine scelto.
- [ ] `Ripristina` ricrea il layout di default.
- [ ] La dashboard avanzata apre dentro un `Scaffold`/Material corretto in light e dark mode.
- [ ] Provare tutti i tipi di `DashboardWidgetType`, inclusi stato vuoto e stato con dati.
- [ ] Nessun grafico o widget deve produrre `ErrorWidget`, area grigia anomala, `NaN` o eccezioni di layout.

## 6. Impostazioni e feature raggiungibili

- [ ] Aprire ogni voce della schermata Impostazioni e verificare che la destinazione esista.
- [ ] Ogni switch salva il valore, aggiorna subito la UI e mantiene il valore dopo reload/riavvio.
- [ ] Tema, privacy locale, notifiche, voce, suggerimenti Smart, preset, anticipi, categorie, regole, Home, widget Android e dati/backup devono essere raggiungibili.
- [ ] Le feature dipendenti dalla piattaforma devono gestire permesso negato/non disponibile senza crash.
- [ ] Evitare due schermate impostazioni divergenti con feature diverse; la superficie principale deve restare quella canonica.

## 7. Categorie, regole e preset

- [ ] Una categoria può essere creata, rinominata e modificata successivamente almeno per icona e colore.
- [ ] L'icona modificata si aggiorna nelle liste, nei movimenti, nelle analisi, nei widget e nei picker che leggono la categoria.
- [ ] Merge/eliminazione categoria mantengono l'integrità dei riferimenti.
- [ ] Regole: crea, modifica, attiva/disattiva, duplica, prova, applica allo storico, riordina ed elimina.
- [ ] Preset: crea, modifica, riordina ed elimina con conferma.
- [ ] Regole e preset vuoti devono essere centrati e responsive.

## 8. Dati, CSV e backup

- [ ] Esportare un CSV con spese, entrate e trasferimenti.
- [ ] Verificare nomi conto/categoria, date, importi a due decimali, tag e `include_in_analytics`.
- [ ] Verificare escaping CSV con virgole, virgolette, caratteri Unicode e newline nelle descrizioni.
- [ ] Reimportare il CSV: anteprima valida, mapping dei conti/categorie mancanti e rilevamento duplicati corretti.
- [ ] Verificare che l'import non alteri i saldi in modo errato e che i trasferimenti aggiornino origine/destinazione una sola volta.
- [ ] Creare un backup completo, ispezionarlo e fare almeno un restore di prova su dati non importanti.
- [ ] Verificare il safety backup/rollback se il restore fallisce.
- [ ] Nessun dato finanziario o pattern deve uscire dal dispositivo per funzioni dichiarate local-first.

## 9. Database e integrità

- [ ] Se cambia lo schema, testare migrazione da una versione precedente e database appena creato.
- [ ] Controllare foreign/reference integrity per conti, categorie, split, ricorrenti, budget, obiettivi, regole e anticipi.
- [ ] Eliminazioni distruttive richiedono conferma e non lasciano riferimenti orfani.
- [ ] I valori monetari restano coerenti con il percorso in centesimi previsto dall'architettura.

## 10. Prima del merge su main

- [ ] Pushare prima su un branch `build/**` così parte la CI completa.
- [ ] Verificare sullo stesso HEAD: Format, Analyze, Tests, debug APK e artifact.
- [ ] Se la CI fallisce, correggere e rieseguire; non mergiare un HEAD diverso da quello verificato.
- [ ] Ricontrollare il diff finale e il versioning.
- [ ] Mergiare su `main` solo quando il branch è verde.
- [ ] Verificare anche la CI generata dal push/merge su `main`.
- [ ] Per una release, verificare infine il workflow release e l'artifact APK prodotto.

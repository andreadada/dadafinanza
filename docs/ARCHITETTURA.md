# DadaFinanza — Architettura

DadaFinanza è un'app di finanza personale Android-first, local-first e private-first. Non richiede account, backend o cloud per funzionare. I dati finanziari restano nel database SQLite locale e gli allegati vengono gestiti nella directory privata dell'app.

## 1. Principi

- una sola navigazione canonica: **Home / Movimenti / Analisi / Pianifica**;
- nessuna operazione finanziaria viene eseguita in background da un deep link o da un widget;
- gli importi monetari vengono normalizzati in minor units nei servizi critici;
- Smart Finance e matching Anticipi sono deterministici, spiegabili e locali;
- voce, widget e preset sono modalità di acquisizione, non ledger separati;
- **liquidità e analytics personali sono concetti distinti**: un movimento può cambiare il saldo di un conto senza essere reddito/spesa;
- ogni modifica UI segue `docs/LINEE_GUIDA_STYLE.md`.

## 2. Livelli principali

### UI

- `DadaAppShell`: unico root di navigazione esposto all'utente;
- `DadaHomeScreen`: Home canonica informativa e flat;
- `CanonicalAnalyticsScreen`: analisi canonica;
- `TransactionsScreen`: movimenti e filtri;
- `QuickAddPage`: unica superficie di conferma e modifica del nuovo movimento;
- `AdvancesScreen`: vista di crediti/debiti informali e relativo storico;
- schermate account, pianificazione e impostazioni.

Le vecchie classi di shell restano temporaneamente nel sorgente solo finché contengono componenti condivisi ancora riutilizzati, ma non costituiscono entry point raggiungibili dall'app.

### Stato e dominio

`AppState` espone lo stato reattivo dell'app e coordina database e servizi. La business logic con invarianti forti resta nei servizi dedicati (`AdvanceService`, `GoalLedgerService`, Smart Finance) invece che nei widget.

### Persistenza

`AppDatabase` gestisce SQLite e le migrazioni. `FinanceSchemaService` consolida lo schema e mantiene compatibilità con installazioni precedenti. Allegati e backup hanno servizi dedicati.

Gli importi nuovi persistenti che richiedono integrità contabile usano centesimi interi; le API UI legacy possono continuare a esporre `double`, normalizzato tramite `Money` al confine di persistenza.

### Smart Finance

Il motore usa regole manuali, pattern appresi localmente, confidence, ricorrenze rilevate e goal planning. Non usa LLM o classificatori cloud.

## 3. Quick Capture Engine

Tutti i modi di inserire un movimento convergono nello stesso modello `TransactionDraft`.

```text
Manuale ───────┐
Preset ────────┤
Widget ────────┤
Deep link ─────┼──> TransactionDraft ──> QuickAddPage ──> conferma utente ──> Save
Voce ──────────┤             ▲
Smart Finance ─┘             │
                    completa solo campi mancanti
```

`TransactionDraft` può contenere tipo, importo in centesimi, conti, categoria, data, nota, tag, sorgente e indicazione di avvio vocale.

### Precedenza dei dati

Per l'inserimento vocale:

1. valore pronunciato esplicitamente;
2. entità locali riconosciute con confidence sufficiente;
3. Smart Finance per i soli campi ancora mancanti;
4. preferenze/recenti del Quick Add.

Un valore esplicito pronunciato dall'utente non viene sostituito da Smart Finance.

## 4. Anticipi ledger

Anticipi è un dominio separato che mantiene allineati cash movement e significato economico personale.

```text
Cash movement reale ──> saldo conto
          │
          ├─ normale ───────────────> analytics Entrate/Spese
          │
          └─ Anticipo/settlement ───> Advance ledger
                                      (analytics escluse)
```

Una spesa mista usa un solo cash movement e una proiezione analitica della sola quota personale. Un rimborso/restituzione può avvenire su un conto diverso dall'origine. Il residuo è ricostruibile dall'importo originale meno i settlement.

Componenti principali:

- `FinancePerson`;
- `Advance` (`receivable` / `payable`);
- `AdvanceSettlement`;
- `AdvanceService` per creazione, settlement, chiusura e matching;
- `AppState` per proiezione analytics e stato reattivo.

La specifica completa e le invarianti sono in `docs/ANTICIPI.md`.

## 5. Voice Capture

`VoiceInputService` gestisce esclusivamente il riconoscimento speech-to-text. `VoiceTransactionParser` interpreta poi la stringa localmente e in modo deterministico.

Default:

- riconoscimento **on-device** quando Android lo rende disponibile;
- fallback al recognizer di sistema disabilitato;
- l'utente può abilitarlo esplicitamente;
- nessun audio o testo viene inviato a server DadaFinanza.

Il risultato vocale produce soltanto un `TransactionDraft`: non salva mai da solo.

## 6. Deep link

Schema canonico: `dadafinanza://quick-add`.

Parametri validati: `type`, `amount`, `category`, `account`, `toAccount`, `date`, `note`, `voice`, `presetId`.

Un deep link può solo precompilare un draft. Non può cancellare, modificare o salvare movimenti.

## 7. Widget Android

La famiglia widget resta basata su `HomeWidget` + `RemoteViews`:

1. **Saldo**;
2. **Quick Capture**;
3. **Importi rapidi**;
4. **Riepilogo**.

`DadaWidgetConfigActivity` salva preferenze keyed per `appWidgetId`. `hideBalance` globale prevale sui singoli widget.

## 8. Allegati e backup

`AttachmentService` copia le ricevute in storage privato persistente. Il backup contiene database SQLite, allegati e manifest. Poiché Anticipi vive nello stesso database, persone, posizioni, settlement e riferimenti transazionali vengono ripristinati nello stesso snapshot.

## 9. Conferma come invariant

Sono sempre richiesti UI e conferma dell'utente per nuovo movimento da widget/preset/voce/deep link, Smart Suggestion e matching Anticipi.

> **Capture suggests/prefills; Quick Add confirms; the ledger saves.**

## 10. Testing e CI

I contratti critici devono essere coperti da:

- parser vocale e deep-link resolver;
- Home zero-data su più viewport;
- widget/deep-link contract;
- Smart Finance precedence;
- Anticipi: saldo vs analytics, settlement parziali, mixed expense, matching e chiusure;
- Quick Add UI/accessibilità;
- backup/restore;
- CI con format, analyzer, test e APK debug artifact.

## 11. Fuori scope

Non fanno parte di questa architettura:

- assistente conversazionale generale;
- sincronizzazione cloud;
- login/backend;
- esecuzione di transazioni reali bancarie;
- salvataggio automatico da voce/widget/deep link;
- prestiti finanziari con interessi/piani di ammortamento: `Anticipi` rappresenta solo crediti/debiti informali.

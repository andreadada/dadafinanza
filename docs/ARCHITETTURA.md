# DadaFinanza — Architettura

DadaFinanza è un'app di finanza personale Android-first, local-first e private-first. Non richiede account, backend o cloud per funzionare. I dati finanziari restano nel database SQLite locale e gli allegati vengono gestiti nella directory privata dell'app.

## 1. Principi

- una sola navigazione canonica: **Home / Movimenti / Analisi / Pianifica**;
- nessuna operazione finanziaria viene eseguita in background da un deep link o da un widget;
- gli importi monetari vengono normalizzati in minor units quando entrano nei nuovi servizi critici;
- Smart Finance è deterministico, spiegabile e locale;
- voce, widget e preset sono modalità di acquisizione, non ledger separati;
- ogni modifica UI segue `docs/LINEE_GUIDA_STYLE.md`.

## 2. Livelli principali

### UI

- `DadaAppShell`: unico root di navigazione esposto all'utente;
- `CanonicalHomeScreen`: Home canonica;
- `QuickAddPage`: unica superficie di conferma e modifica del nuovo movimento;
- schermate account, pianificazione, analytics e impostazioni.

Le vecchie classi di shell restano temporaneamente nel sorgente solo finché contengono componenti condivisi ancora riutilizzati, ma non costituiscono entry point raggiungibili dall'app.

### Stato e dominio

`AppState` espone lo stato reattivo dell'app e coordina repository/servizi esistenti. Il refactor evita di aggiungere nuova logica di acquisizione direttamente nel widget Android o nel parser vocale.

### Persistenza

`AppDatabase` gestisce SQLite e le migrazioni. `FinanceSchemaService` mantiene compatibilità con installazioni precedenti durante il consolidamento dello schema. Allegati e backup hanno servizi dedicati.

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

`TransactionDraft` può contenere:

- tipo;
- importo in centesimi;
- conto origine;
- conto destinazione;
- categoria;
- data;
- nota;
- tag;
- sorgente del draft;
- indicazione di avvio vocale;
- origine dei singoli campi quando rilevante.

### Precedenza dei dati

Per l'inserimento vocale:

1. valore pronunciato esplicitamente;
2. entità locali riconosciute con confidence sufficiente;
3. Smart Finance per i soli campi ancora mancanti;
4. preferenze/recenti del Quick Add.

Un valore esplicito pronunciato dall'utente non viene sostituito da Smart Finance.

## 4. Voice Capture

`VoiceInputService` gestisce esclusivamente il riconoscimento speech-to-text. `VoiceTransactionParser` interpreta poi la stringa localmente e in modo deterministico.

### Privacy

Default:

- riconoscimento **on-device** quando Android lo rende disponibile;
- fallback al recognizer di sistema disabilitato;
- l'utente può abilitarlo esplicitamente nelle Impostazioni;
- nessun audio o testo viene inviato a server DadaFinanza;
- nessun OpenAI/Gemini/Whisper cloud viene usato.

Il recognizer di sistema, se abilitato, è un servizio del dispositivo: la sua privacy dipende dal provider configurato dall'utente.

### Sicurezza

Il risultato vocale produce soltanto un `TransactionDraft`. Anche una frase completamente riconosciuta apre/compila `QuickAddPage`: **non salva mai da sola**.

## 5. Deep link

Schema canonico:

`dadafinanza://quick-add`

Parametri supportati e validati:

- `type`;
- `amount`;
- `category`;
- `account`;
- `toAccount`;
- `date`;
- `note`;
- `voice`;
- `presetId`.

I nomi di conti e categorie vengono risolti solo se esiste una corrispondenza locale valida. ID/nomi inesistenti non vengono rimpiazzati arbitrariamente.

Un deep link può **solo precompilare** un draft. Non può cancellare, modificare o salvare movimenti.

## 6. Widget Android

La famiglia widget resta basata su `HomeWidget` + `RemoteViews` perché copre i casi d'uso richiesti senza introdurre Glance come secondo framework UI nativo.

Widget canonici:

1. **Saldo** — compatto;
2. **Quick Capture** — Spesa / Entrata / Trasferisci / Voce;
3. **Importi rapidi** — quattro importi configurabili + tipo/conto/categoria + voce;
4. **Riepilogo** — saldo e categorie rapide.

### Configurazione per istanza

`DadaWidgetConfigActivity` salva preferenze keyed per `appWidgetId`. In questo modo due widget possono usare conti, categorie e importi diversi.

La configurazione nativa non accede direttamente al database Flutter: memorizza i nomi scelti e il resolver Flutter li valida quando il Quick Add viene aperto. Un valore non valido resta non assegnato invece di essere sostituito con un'entità casuale.

### Privacy widget

- la visualizzazione del saldo è opt-in per istanza;
- gli importi rapidi possono essere oscurati;
- `hideBalance` globale prevale e forza `••••` sui dati sensibili;
- reboot/update non devono rendere visibili valori precedentemente nascosti.

## 7. Allegati

`AttachmentService` copia le ricevute in storage privato persistente. Quick Add consente fotocamera, galleria, sostituzione/rimozione e cleanup dei file non più referenziati.

## 8. Conferma come invariant

Sono sempre richiesti UI e conferma dell'utente per:

- nuovo movimento da widget;
- movimento generato da preset;
- movimento compilato dalla voce;
- deep link;
- Smart Suggestion.

La regola architetturale è:

> **Capture suggests/prefills; Quick Add confirms; the ledger saves.**

## 9. Testing

I contratti critici devono essere coperti da:

- parser vocale;
- deep-link resolver;
- Home zero-data su più viewport;
- widget/deep-link contract;
- Smart Finance precedence;
- Quick Add UI/accessibilità;
- CI con format, analyzer, test e APK debug.

## 10. Fuori scope

Non fanno parte di questa architettura:

- assistente conversazionale generale;
- sincronizzazione cloud;
- login/backend;
- esecuzione di transazioni reali bancarie;
- salvataggio automatico da voce/widget/deep link.

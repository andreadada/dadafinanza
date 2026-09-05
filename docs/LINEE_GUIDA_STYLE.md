# DadaFinanza — Linee guida UI/UX

Questo documento è il riferimento ufficiale per ogni modifica visiva di DadaFinanza. La UI deve sembrare progettata come un unico sistema, non come una somma di feature aggiunte nel tempo.

## 1. Filosofia visiva

DadaFinanza è clean, piatta, leggibile, professionale, moderna e accessibile. La gerarchia nasce prima da tipografia, spacing e allineamento; superfici, bordi ed elevation si usano solo quando aggiungono significato.

Default: **nessun container**. Non usare card per separare elementi che possono essere distinti da spazio, titoli o divider. Evitare card dentro card, rettangoli bordati decorativi e profondità artificiale.

## 2. Regola di riuso obbligatoria

Prima di creare UI nuova:

1. cercare un componente esistente;
2. riutilizzarlo;
3. estenderlo se manca solo una variante;
4. creare un nuovo componente solo se è semanticamente diverso.

Non duplicare styling nei singoli screen. Token ripetuti vanno centralizzati nel theme o in componenti condivisi.

## 3. Spacing ufficiale

Scala: `4, 8, 12, 16, 20, 24, 32, 40, 48`.

- padding pagina standard: 20dp orizzontali;
- app bar / contenuto iniziale: 8dp verticale;
- icona ↔ testo: 8–12dp;
- righe correlate: 8–16dp;
- sezioni: 24–32dp;
- touch target: minimo 48dp;
- contenuto scrollabile: deve considerare SafeArea, FAB e bottom navigation.

Valori diversi sono ammessi solo se motivati da vincoli di layout.

## 4. Tipografia

Usare `Theme.of(context).textTheme` e non creare stili one-off se esiste un equivalente.

- patrimonio / importo hero: `displaySmall`;
- titolo pagina: AppBar + `headlineSmall` quando serve nel contenuto;
- titolo sezione: `SectionTitle`;
- titolo riga: `titleMedium` o ListTile title;
- body: `bodyMedium` / `bodyLarge`;
- secondario e spiegazioni: `bodySmall`;
- label tecniche: `labelMedium` con letter spacing leggero;
- importi nelle liste: `titleMedium` o testo bold, senza font decorativi.

## 5. Importi finanziari

Mostrare sempre contesto testuale oltre al colore.

- patrimonio: neutro;
- entrata: colore semantico `positive` + label Entrata;
- spesa: colore semantico `negative` + label Spesa;
- warning budget: `warning`;
- forecast: neutro/informational salvo stato negativo esplicito.

`hideBalance` deve essere rispettato in tutte le superfici, inclusi widget Android.

## 6. Colori

Base: bianco/quasi bianco in light, nero/quasi nero in dark, grigi neutrali. Nessun verde dominante. I colori semantici servono per significato, non per riempire grandi superfici.

Usare `FinanceColors` / `context.financeColors` per positive, negative, warning e neutral quando disponibile.

## 7. Container, card e superfici

Usare Card/Container solo per:

- widget dashboard autonomi;
- entità realmente raggruppate;
- selezioni complesse;
- contenuti che necessitano una superficie distinta per comprensione.

Non usare `Container > Container > TextField`, né card per ogni ListTile.

## 8. Bordi

Default: nessun bordo. Per input preferire lo stile underline già definito dal theme. Per separare sezioni usare spacing o `Divider`.

## 9. Pulsanti e azioni

- **Primary CTA**: `FilledButton`, solo azione dominante e rara.
- **Secondary**: `TextButton` o tonal leggero quando serve davvero.
- **Destructive**: colore `error`, sempre con conferma se irreversibile.
- **Inline action**: icona + testo, senza grande background.
- **Quick action**: `FinanceQuickAction`, icona + label, area touch invisibile >=48dp, nessun bordo/elevation/superficie grande.

Non ogni azione deve sembrare un bottone.

## 10. Icone

Preferire Material rounded/outlines coerenti col contesto. Dimensioni standard 20–24dp; 16–18dp per indicatori secondari. CircleAvatar solo quando rappresenta un'entità con identità visuale (conto/categoria), non come decorazione generica. Sempre tooltip/semantics dove il significato non è già scritto.

Usare la libreria icone categorizzata esistente per conti/categorie.

## 11. List item

Pattern: leading opzionale, title, subtitle opzionale, trailing, touch target >=48dp. Usare `ListTile` senza card per default. Separare con Divider quando necessario.

## 12. Form

Mostrare prima i campi frequenti. Campi avanzati sotto progressive disclosure (`Altre opzioni`, `Aggiungi dettagli`). Nota e tag usano input semplici, senza box decorativi pesanti.

## 13. Empty state

Usare `EmptyState`: icona, titolo, descrizione breve, CTA solo se non esiste già un'azione primaria evidente nella schermata. Evitare CTA gigantesche duplicate col FAB.

Uno stato vuoto non deve mai riservare altezze artificiali o mostrare skeleton permanenti. In Home, `Conti` senza dati resta una riga/sezione compatta con testo `Nessun conto` o un `EmptyState` breve.

## 14. Navigazione

Bottom navigation ufficiale: Home, Movimenti, Analisi, Pianifica. Il FAB centrale/prominente crea un movimento. Conti resta destinazione secondaria, non quinta tab.

Esiste una sola shell canonica. La **Home canonica** deve essere la superficie quotidiana: informativa ma pulita, con patrimonio, metriche, azioni rapide e sezioni operative. La **Dashboard avanzata** può essere raggiunta dalla Home come vista secondaria personalizzabile tramite l'azione dedicata in AppBar, ma non deve introdurre una seconda bottom navigation, sostituire la Home o diventare un secondo entry point dell'app. Vecchie shell complete restano non raggiungibili.

## 15. Accessibilità

- touch target >=48dp;
- Dynamic Type senza overflow;
- Semantics e tooltip;
- contrasto Material 3;
- nessuna informazione solo tramite colore;
- SafeArea;
- testi lunghi e localizzazione futura;
- layout verificato su telefoni piccoli e font scaling elevato.

## 16. Light e Dark mode

Mai hardcodare bianco/nero per superfici Flutter di sistema. Derivare da Theme/ColorScheme. Verificare ogni nuovo componente in entrambe le modalità.

I widget Android nativi possono usare una superficie propria coerente e ad alto contrasto, ma devono privilegiare leggibilità e privacy rispetto alla decorazione.

## 17. Responsive

Verificare almeno larghezze 320, 360, 390, 430dp e text scale elevato. Le quick action devono mantenere label leggibili; preferire icona sopra testo su spazi stretti anziché mandare parole a capo in modo casuale.

## 18. DO / DON'T

**DO**: `↑ Spesa`, `↓ Entrata`, `↔ Trasferisci` come azioni piatte con area touch ampia.

**DON'T**: tre grandi rettangoli tonali se non sono il CTA principale.

**DO**: `SectionTitle` + lista + divider.

**DON'T**: `Card > Container > ListTile`.

**DO**: mostrare solo opzioni frequenti e aprire dettagli su richiesta.

**DON'T**: form lunghi con tutti gli switch visibili subito.

**DO**: una piccola icona microfono in AppBar con tooltip `Compila con la voce`.

**DON'T**: un enorme pulsante vocale permanente dentro il form.

## 19. Inventario componenti condivisi

- `SectionTitle` — `lib/widgets/ui_helpers.dart`: titoli sezione; non usare per titoli pagina.
- `EmptyState` — `lib/widgets/ui_helpers.dart`: stati vuoti; non duplicare icona/titolo/CTA manualmente.
- `FlatMetric` — `lib/widgets/ui_helpers.dart`: metriche piatte; non usare per card decorative.
- `TransactionListTile` — `lib/screens/transaction_screens.dart`: riga movimento con navigazione al dettaglio.
- `FinanceQuickAction` — `lib/widgets/finance_quick_action.dart`: azioni rapide senza superficie visiva, ad esempio Spesa/Entrata/Trasferisci/Voce.
- `showIconPicker` — `lib/widgets/ui_helpers.dart`: selezione icone categorizzata.
- `confirmDestructiveAction` — `lib/widgets/ui_helpers.dart`: conferme distruttive.
- `TransactionDraft` — modello di acquisizione condiviso da Quick Add, voce, widget, preset e deep link; non è un secondo modello di transazione persistita.

Ogni nuovo componente shared deve essere aggiunto qui.

## 20. Quick Capture pattern

Quick Add è l'unica superficie di conferma del movimento. Widget, voce, preset, deep link e Smart Finance devono produrre/precompilare lo stesso `TransactionDraft` e convergere nella stessa pagina.

Principio:

`Capture → Draft → Quick Add → conferma utente → Save`.

Mai creare una seconda UI di inserimento che possieda regole di validazione o salvataggio proprie.

Quando Quick Add arriva da widget:

- importo mancante → focus numerico immediato;
- importo già presente → non aprire inutilmente la tastiera;
- mostrare subito tipo, categoria, conto e data;
- niente animazioni lente o schermate intermedie.

## 21. Voice action e stato di ascolto

L'azione vocale primaria è un'icona `mic` discreta nella AppBar di `Nuovo movimento` e può essere richiamata anche da long press del FAB e widget Android.

Durante l'ascolto usare un bottom sheet piccolo e chiaro:

- titolo `Ti ascolto`;
- trascrizione parziale;
- waveform semplice derivata dal livello microfono quando disponibile;
- niente badge tecnico ridondante nel modal: la privacy/on-device resta esplicitata nelle Impostazioni;
- `X` in alto a destra per chiudere, icona restart per ripartire da zero e conferma separata `Usa questo`;
- dopo circa 1 secondo senza nuovi risultati la trascrizione resta visibile nel modal senza resettarsi; se il recognizer è ancora attivo, nuovo parlato aggiorna la stessa frase;
- niente waveform decorative complesse;
- stato annunciabile a TalkBack tramite live region/Semantics.

Dopo il riconoscimento il form mostra un helper discreto: `Compilato dalla voce · controlla e salva`. Il salvataggio resta sempre una CTA separata e volontaria.

Errori (`permesso negato`, `nessun audio`, `offline non disponibile`, ambiguità) vanno espressi con testo semplice e una via d'uscita manuale, mai con crash o auto-correzioni arbitrarie.

## 22. Widget Android

I widget sono estensioni di Quick Capture, non mini-app indipendenti.

Famiglia canonica massima:

1. **Saldo** — 2×1 circa;
2. **Quick Capture** — 2×2 circa, Spesa/Entrata/Trasferisci/Voce;
3. **Importi rapidi** — 4×2 circa, quattro importi configurabili + voce;
4. **Riepilogo** — 4×2 circa.

Per azioni arbitrarie un widget apre Quick Add. Non simulare un `TextField` dentro `RemoteViews`.

Con poco spazio si eliminano dettagli secondari; non si comprimono testo e touch target fino a renderli illeggibili.

## 23. Privacy widget

La privacy widget è distinta dalla privacy in-app:

- saldo visibile solo se configurato per l'istanza;
- importi rapidi oscurabili;
- `hideBalance` globale prevale sempre;
- dati nascosti = `••••`/`••` e non solo colore attenuato;
- aggiornamento settings, reboot o update non deve far ricomparire dati sensibili.

Ogni istanza può avere conto/categoria/importi propri. La configurazione non deve mai bypassare la validazione Flutter prima di aprire Quick Add.

## 24. Checklist prima di fare merge

- sto riusando un componente esistente?
- il nuovo elemento ha davvero bisogno di una superficie?
- spacing usa la scala ufficiale?
- touch target >=48dp?
- dark/light funzionano?
- font scaling non rompe il layout?
- l'informazione resta chiara senza colore?
- la schermata ha lo stesso ritmo delle altre sezioni DadaFinanza?
- widget/voce/preset passano tutti da `TransactionDraft` e Quick Add?
- nessun input esterno salva un movimento senza conferma?
- privacy widget e voice fallback sono conservativi di default?

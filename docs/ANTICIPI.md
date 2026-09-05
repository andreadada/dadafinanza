# DadaFinanza — Anticipi

`Anticipi` gestisce crediti e debiti informali tra persone senza confonderli con reddito e spesa personale.

## Modello mentale

DadaFinanza separa tre concetti:

1. **liquidità**: quanto denaro è realmente entrato o uscito dai conti;
2. **analytics personali**: quanto ho realmente guadagnato o speso;
3. **posizioni Anticipi**: quanto devo ricevere o restituire.

Esempio: anticipo 30 € a Marco da Revolut. Revolut diminuisce di 30 €, ma le spese personali non aumentano: nasce invece una posizione `Da ricevere` di 30 €. Se Marco restituisce 10 € su Contanti, Contanti aumenta di 10 €, le entrate personali restano invariate e il residuo diventa 20 €.

Il caso inverso usa `Da restituire`: una somma anticipata da un'altra persona può aumentare la liquidità, ma non è reddito; la successiva restituzione riduce la liquidità, ma non è spesa.

## Dominio

- `FinancePerson`: controparte locale, archiviabile e preservata quando possiede storico.
- `AdvanceDirection.receivable`: **Ho anticipato** — devo ricevere dei soldi.
- `AdvanceDirection.payable`: **Mi hanno anticipato** — devo restituire dei soldi.
- `Advance`: posizione originale con persona, importo in centesimi, eventuale conto/movimento sorgente, scadenza, promemoria e chiusura.
- `AdvanceSettlement`: rimborso/restituzione parziale o totale, collegato a un movimento di cassa e al conto effettivamente usato.

Gli stati esposti sono `open`, `partial`, `overdue`, `settled`, `cancelled`, `writtenOff` e `forgiven`.

## Persistenza e invarianti

Le tabelle principali sono:

- `finance_people`;
- `advances`;
- `advance_settlements`.

Gli importi persistenti sono minor units (`INTEGER`, centesimi). Il residuo è ricostruibile come:

`original_amount_cents - SUM(advance_settlements.amount_cents)`

Invarianti:

- importi originali e settlement devono essere > 0;
- un settlement non può superare il residuo;
- il residuo non può diventare negativo;
- il movimento sorgente e i settlement usano `include_in_analytics = 0` quando rappresentano puro anticipo/rimborso;
- FK e servizi impediscono record orfani;
- movimenti protetti (`advance_origin`, `mixed_advance`, `advance_settlement`, `advance_writeoff`, `advance_forgiven_income`) si gestiscono dal dominio Anticipi e non dalle azioni generiche che romperebbero il ledger.

## Anticipo puro

`Ho anticipato 30 € a Marco da Revolut` crea:

- movimento di cassa `expense`, 30 €, escluso dalle analytics, `kind=advance_origin`;
- `Advance.receivable` da 30 € collegato al movimento.

`Mi hanno anticipato 50 € da Luca su Intesa` crea in modo simmetrico:

- movimento di cassa `income`, 50 €, escluso dalle analytics;
- `Advance.payable` da 50 €.

## Rimborso e restituzione parziale

Ogni settlement:

- può usare un conto diverso da quello iniziale;
- crea il cash movement nella direzione corretta;
- resta escluso da Entrate/Spese personali;
- aggiorna il residuo;
- porta lo stato a `partial` o `settled`.

Un settlement collegato a una transazione già inserita viene applicato solo dopo conferma dell'utente.

## Spesa mista

Una spesa può avere una quota personale e una quota anticipata.

Esempio: ristorante 40 €, di cui 10 € miei e 30 € anticipati a Marco.

Il sistema conserva **un solo movimento di cassa da -40 €**. Il movimento è marcato `mixed_advance` e l'Advance collegato rappresenta 30 €. La proiezione analytics restituisce 10 € come spesa personale.

Categorie, budget, top categorie, medie e giorni senza spesa usano la quota personale. In presenza di `transaction_splits`, le quote analitiche vengono scalate in proporzione per non reintrodurre la parte anticipata.

## Matching deterministico

Per una normale entrata/spesa DadaFinanza può suggerire un anticipo aperto compatibile usando solo dati locali:

- direzione compatibile;
- importo <= residuo;
- bonus per importo esatto;
- nome persona nella descrizione;
- recenza/compatibilità della posizione.

Il matching **non viene mai applicato automaticamente**. Quick Add mostra `Collega` / `Non è questo`; la conferma converte il movimento in settlement e lo esclude dalle analytics personali.

## Movimenti e dettaglio

I cash movement rimangono visibili perché hanno modificato realmente un conto, ma vengono etichettati semanticamente come:

- `Anticipo a Marco`;
- `Anticipo da Luca`;
- `Rimborso da Marco`;
- `Restituzione a Luca`.

Il filtro `Anticipi` include origini, quote miste, settlement e chiusure economiche. Il dettaglio collega sempre alla posizione Anticipi quando esiste.

## Write-off e condono

Una posizione aperta non diventa automaticamente spesa o reddito.

Per un receivable l'azione `Non verrà restituito` richiede conferma esplicita. Solo se l'utente sceglie di riconoscere il residuo nelle analytics viene registrata la perdita personale nella categoria scelta.

Per un payable condonato vale il principio simmetrico: nessun reddito automatico senza conferma.

## Home e Analisi

La Home mostra Anticipi solo quando utili, dentro `Per te`, privilegiando scaduti/scadenze e poi il riepilogo aperto. `hideBalance` oscura gli importi.

Analisi mantiene Entrate/Spese separate e aggiunge una sezione Anticipi con:

- da ricevere;
- da restituire;
- importi regolati nel periodo;
- accesso alla schermata completa.

Il saldo dei conti non cambia significato: Anticipi non viene sommato silenziosamente al saldo totale.

## Notifiche

I reminder Anticipi riusano `NotificationService` e `flutter_local_notifications`:

- scheduling esclusivamente locale;
- opt-in insieme alle notifiche dell'app;
- niente cloud;
- ID deterministici per evitare duplicati;
- reminder annullato o aggiornato quando la posizione viene modificata/saldata.

## Backup e ripristino

Il backup DadaFinanza copia l'intero SQLite: persone, Advances, settlement e collegamenti alle transazioni sono quindi parte dello stesso snapshot atomico. Il manifest espone inoltre conteggi diagnostici di persone/anticipi/settlement. Dopo il restore `FinanceSchemaService` riallinea lo schema senza creare un secondo formato dati.

## Privacy

Nomi delle persone, note, posizioni, matching e reminder restano locali. Anticipi non introduce account, backend, sincronizzazione o IA/cloud.

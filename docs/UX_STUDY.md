# DadaFinanza — studio UX/UI e roadmap

## Cosa mostrano gli screenshot di riferimento

L'app di partenza ha già una buona base funzionale: inserimento separato di spese ed entrate, più conti, giroconti, categorie personalizzate, tag, data, commento, foto/ricevute, pagamenti regolari, promemoria, grafici, possibilità di nascondere i saldi e di escludere alcuni conti dal totale.

## Problemi UX individuati

### Navigazione troppo orientata alle sezioni
Il drawer contiene molte destinazioni ma le azioni più frequenti — vedere la situazione e registrare un movimento — richiedono più attenzione del necessario.

**DadaFinanza:** bottom navigation persistente con Home, Movimenti, Analisi, Conti e Altro, più un pulsante Aggiungi sempre raggiungibile.

### Inserimento movimento troppo lungo
Il riferimento mostra subito una grande griglia di categorie e poi conto, data, tag, commento e foto. È completo ma una spesa da cinque secondi sembra un form.

**DadaFinanza:** importo per primo; conto e categoria subito dopo; oggi come data predefinita; nota, tag e ricevuta secondari. Il widget può preselezionare direttamente la categoria.

### Ambiguità tra 246,12 € e 296,12 €
Negli screenshot un conto da 50 € è escluso dal totale principale, quindi compaiono due valori senza una distinzione sufficientemente esplicita.

**DadaFinanza:** `Saldo incluso nel totale` e `Patrimonio su tutti i conti` sono due metriche esplicitamente nominate. Nascondere un saldo e includere/escludere un conto sono due azioni diverse.

### Categorie e tag diventano densi
Una griglia grande funziona con poche categorie ma rallenta quando crescono. I tag globali diventano presto rumorosi.

**DadaFinanza:** card categoria più compatte; in seguito preferiti, recenti, ricerca e suggerimenti contestuali per conto/merchant.

### I grafici descrivono ma non aiutano a decidere
Il riferimento mostra bene i dati ma lascia quasi tutta l'interpretazione all'utente.

**DadaFinanza:** confronto entrate/spese, consumo budget, top categorie e insight brevi direttamente nella dashboard.

## Architettura informativa

### Home
Risponde immediatamente a quattro domande: quanto ho, come sta andando il mese, quanto budget resta e quali sono gli ultimi movimenti. Include azioni rapide Spesa, Entrata e Giroconto.

### Movimenti
Timeline ricercabile per categoria, conto, tag e nota; filtro per tipo; eliminazione con correzione automatica del saldo.

### Analisi
Confronto mensile entrate/spese e ranking delle categorie. In futuro drill-down per periodo, conto e categoria.

### Conti
Mostra saldo incluso e patrimonio totale, lista conti, inclusione/esclusione dal totale e accesso immediato al giroconto.

### Altro
Pagamenti regolari, categorie, promemoria e impostazioni: funzioni importanti ma meno frequenti, quindi fuori dalla navigazione primaria.

## Feature implementate nella fondazione Flutter

- database SQLite locale;
- conti multipli;
- saldo incluso e patrimonio totale;
- mostra/nascondi saldi;
- spese, entrate e giroconti;
- categorie spese/entrate separate;
- categorie personalizzate;
- tag e note;
- data movimento;
- foto/ricevuta da fotocamera o galleria;
- cronologia e ricerca;
- eliminazione con rollback del saldo;
- riepilogo mensile entrate/spese;
- budget mensile modificabile;
- grafico ultimi 6 mesi;
- top categorie del mese;
- pagamenti ricorrenti e attivazione/disattivazione;
- schermata promemoria/scadenze;
- widget Android saldo + 4 categorie rapide;
- deep link dal widget al Quick Add già preselezionato;
- dati local-first e backup Android disabilitato di default.

## Feature ad alto valore da aggiungere

1. **Preset rapidi** — pressione lunga su Aggiungi o scorciatoie widget tipo Caffè, Benzina, Spesa con conto/categoria predefiniti.
2. **Budget per categoria** — oltre al budget mensile globale.
3. **Ricorrenti automatici** — creazione automatica del movimento alla scadenza, con modalità conferma per importi variabili.
4. **Notifiche locali vere** — scadenze e soglie budget, tutte opt-in.
5. **Backup/export/import** — backup cifrato locale e CSV; fondamentale per un'app privata.
6. **Blocco biometrico/PIN** — protezione saldi e cronologia.
7. **OCR ricevute** — suggerisce importo, esercente e data, sempre con conferma prima del salvataggio.
8. **Memoria esercente** — dopo più acquisti da uno stesso merchant propone automaticamente categoria e conto.
9. **Split transaction** — dividere un pagamento tra più categorie.
10. **Spese da rimborsare/condivise** — tenere crediti/debiti personali separati dalle vere entrate.
11. **Obiettivi di risparmio** — emergenze, viaggio, hardware; collegabili a un conto come Salvadanaio.
12. **Rilevatore abbonamenti** — trova movimenti ripetuti e propone di trasformarli in ricorrenti.
13. **Previsione cash-flow 30 giorni** — saldo attuale + entrate e spese ricorrenti previste.
14. **Regole automatiche** — categorizza per esercente, conto o intervallo importo.
15. **Undo dopo eliminazione** — più veloce e sicuro di molte modali di conferma.
16. **Widget multipli** — piccolo `+ Spesa`, medio saldo + categorie, grande riepilogo mensile.
17. **Categorie widget configurabili** — scelta delle 4 scorciatoie e conto predefinito per ciascuna.
18. **Preferiti/recenti categorie** — il Quick Add impara quali usi davvero.
19. **Filtri avanzati** — periodo, conto, categoria, tag, importo.
20. **Dettaglio movimento** — modifica completa, ricevuta, storico e duplicazione.

## Direzione visuale

Material 3 scuro, un verde principale per azioni/positivo, rosso riservato a spese e azioni distruttive, superfici con contrasto leggero invece di molti colori concorrenti. Importi grandi ma sempre accompagnati da una label che spiega cosa rappresentano. Touch target almeno 48dp e navigazione raggiungibile con una mano.

## Privacy e framework

DadaFinanza non importa `playpartygamesframework`: quel framework è correttamente dedicato alla piattaforma giochi e contiene dipendenze da ads, login e acquisti che non devono entrare nel perimetro dei dati finanziari privati. DadaFinanza usa lo stesso baseline Flutter moderno ma possiede un layer finance dedicato e locale.

Un eventuale cloud sync futuro dovrà essere facoltativo, cifrato e separato da analytics/pubblicità.

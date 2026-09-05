# DadaFinanza — Smart Finance Engine

## Obiettivo

Il motore Smart Finance rende DadaFinanza adattiva senza IA, cloud o classificatori remoti. Tutto resta locale e spiegabile.

## Architettura

`AutomationRule -> LearnedPattern -> ConfidenceEngine -> SmartSuggestion -> AdaptiveGoalPlanner`

Le regole manuali hanno precedenza assoluta. I pattern appresi non modificano da soli un movimento: producono suggerimenti. I suggerimenti richiedono conferma.

## Segnali

Ordine di importanza: descrizione normalizzata, storico dominante, conto, fascia importo, periodicità, giorno, ora. Giorno e ora non sono sufficienti da soli per una classificazione ad alta confidenza.

## Normalizzazione

La descrizione viene lowercased, privata di punteggiatura, numeri transazionali isolati e spazi multipli. I token troppo generici vengono ignorati nel confronto. Exact/prefix/contains e Jaccard sui token alimentano la similarità.

## Soglie

- conservative: minimo 4 campioni, high >= 0.82;
- balanced: minimo 3 campioni, high >= 0.74;
- proactive: minimo 2 campioni, high >= 0.66.

Una descrizione assente limita la confidence: i segnali temporali possono rafforzare, non creare da soli un suggerimento forte.

## Feedback

Accetta aumenta `accepted_count`; rifiuta aumenta `rejected_count`; modifica penalizza il candidato originale e il movimento salvato alimenta il pattern corretto; soppressione impedisce nuove proposte per la firma scelta.

## Ricorrenze

Un pattern richiede almeno tre eventi coerenti. La mediana degli intervalli viene confrontata con finestre settimanale, quindicinale, mensile e annuale. Viene verificata anche la stabilità dell'importo. Le ricorrenze apprese sono sempre `previste`, mai create automaticamente come ricorrenze esplicite.

## Forecast

Il forecast separa:

- **Confermato**: recurring espliciti;
- **Previsto**: ricorrenze apprese ad alta confidence;
- **Stimato**: spesa comportamentale aggregata, calcolata con mediane settimanali robuste.

Orizzonti: 7, 30 e 90 giorni; fine mese deriva dallo stesso modello.

## Goal Planner

Il contributo matematico è `remaining / weeksLeft`. Il contributo realistico usa il surplus storico robusto, spese/entrate ricorrenti, saldo liquido e safety buffer. Una singola grande entrata non fa aumentare aggressivamente il consiglio perché il modello usa mediane di più settimane e un buffer minimo.

Stati: `ahead`, `onTrack`, `slightlyBehind`, `unrealistic`, `insufficientData`.

## Privacy

Nessuna descrizione, cifra, categoria, pattern o obiettivo viene inviato fuori dal dispositivo. Learned patterns e feedback fanno parte del database e quindi del backup completo. Il CSV resta interoperabile e non esporta il modello di apprendimento.

## Performance

Il Quick Add interroga pattern già aggregati e in memoria con debounce. Il rebuild avviene solo dopo mutazioni dei movimenti/import, non ad ogni battuta. Il database indicizza chiavi e firme di apprendimento.

## Limiti intenzionali

Il sistema è prudente: ambiguità tra categorie riduce la confidence; dati insufficienti non producono consigli. Non sposta mai denaro automaticamente e non trasforma pattern in regole manuali senza consenso.

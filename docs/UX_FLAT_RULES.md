# DadaFinanza — regole UI/UX

- Gerarchia tramite tipografia, spaziatura e allineamento; non tramite card annidate.
- Niente bordi decorativi su card, pulsanti, chip o selettori.
- Campi di testo semplici con linea inferiore; placeholder e label devono spiegare cosa inserire.
- Azioni necessarie disponibili nel contesto: da una nuova spesa/entrata si possono creare conto e categoria senza uscire dal flusso.
- Ogni azione distruttiva deve avere una conferma che spiega cosa verrà eliminato e cosa resterà.
- Eliminare una categoria mantiene i movimenti storici e rimuove solo il collegamento alla categoria.
- Eliminare un conto elimina i movimenti e i pagamenti ricorrenti collegati; eventuali saldi degli altri conti coinvolti in giroconti vengono corretti.
- Target touch minimo circa 48x48 dp per icone e azioni.
- Non affidarsi solo al colore: stato selezionato, tipo movimento e azioni devono avere anche testo o icone riconoscibili.
- Icon button con tooltip/semantics quando il significato non è immediato.
- Stati vuoti devono spiegare il passo successivo e offrire l’azione direttamente.

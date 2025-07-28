# Architettura Progetto Trading App

## 📋 Indice
1. [Overview Architettura](#overview-architettura)
2. [Flusso Dati](#flusso-dati)
3. [Componenti Principali](#componenti-principali)
4. [Struttura Directory](#struttura-directory)
5. [Responsabilità dei Componenti](#responsabilità-dei-componenti)
6. [Modelli Dati](#modelli-dati)
7. [Sistema di Widget](#sistema-di-widget)
8. [Gestione API Esterne](#gestione-api-esterne)

---

## 🏗️ Overview Architettura

L'applicazione segue un'architettura a layer con separazione delle responsabilità:

```
┌─────────────────────────────────────────────────────────┐
│                      UI Layer                            │
│                 (Widgets & Views)                        │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│                    DataHub                               │
│         (Facade + Business Logic + Cache)                │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│                  DataManager                             │
│        (API Coordination + Standardization)              │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│                DownloadManager                           │
│              (Network Requests)                          │
└────────────────────────┬────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────┐
│              External APIs                               │
│        (Schwab, Webull, Yahoo, etc.)                    │
└─────────────────────────────────────────────────────────┘
```

---

## 🔄 Flusso Dati

### Richiesta Dati (Top-Down)
1. **Widget** richiede dati a DataHub
2. **DataHub** verifica cache e TTL
3. Se necessario, **DataHub** chiede a DataManager
4. **DataManager** coordina con DownloadManager
5. **DownloadManager** chiama API esterna appropriata

### Risposta Dati (Bottom-Up)
1. **API Esterna** ritorna dati grezzi
2. **DownloadManager** passa a DataManager
3. **DataManager** standardizza tramite Adapter specifico
4. **DataHub** enrichisce con dati locali e cache
5. **Widget** riceve dati pronti all'uso

---

## 📁 Struttura Directory

```
mafia_AI/
├── UI/
│   ├── Widgets/
│   │   ├── BaseWidget/          # Classe base per tutti i widget
│   │   ├── Watchlist/           # Widget watchlist con view-based table
│   │   ├── Alert/               # Widget gestione alert
│   │   ├── Chart/               # Widget grafici
│   │   └── GeneralMarket/       # Widget market overview
│   └── MainWindow/              # Finestra principale e container
│
├── DataLayer/
│   ├── DataHub/
│   │   ├── DataHub.h/m          # Facade principale
│   │   └── Categories/          # Estensioni per quote, alerts, etc.
│   │
│   ├── DataManager/
│   │   ├── DataManager.h/m      # Coordinatore API
│   │   ├── Adapters/            # Converter per ogni API
│   │   │   ├── SchwabAdapter.m
│   │   │   ├── WebullAdapter.m
│   │   │   └── YahooAdapter.m
│   │   └── StandardModels/      # Modelli unificati
│   │
│   └── DownloadManager/
│       ├── DownloadManager.h/m  # Gestione richieste HTTP
│       └── DataSources/         # Implementazioni specifiche API
│
├── Models/
│   ├── CoreData/                # Modelli Core Data
│   │   ├── Watchlist+CoreDataClass
│   │   ├── Alert+CoreDataClass
│   │   └── TradingModel+CoreDataClass
│   └── Runtime/                 # Modelli runtime
│       ├── MarketData.h
│       └── PriceHistory.h
│
└── Utils/
    ├── Network/                 # Utility di rete
    └── UI/                      # Utility UI
```

---

## 🎯 Responsabilità dei Componenti

### DataHub
- ✅ Punto di accesso UNICO per tutti i widget
- ✅ Gestione cache con TTL intelligente
- ✅ Persistenza locale (Core Data)
- ✅ Business logic (alerts, watchlist, favorites)
- ✅ Enrichment dati (aggiunge info locali a dati remoti)
- ✅ Emissione notifiche unificate
- ❌ NON sa nulla di API esterne o formati

### DataManager
- ✅ Coordinamento richieste verso API multiple
- ✅ Standardizzazione dati tramite Adapter
- ✅ Gestione priorità data source
- ✅ Subscription management per pseudo real-time
- ❌ NON gestisce persistenza o cache
- ❌ NON conosce business logic

### DownloadManager
- ✅ Esecuzione richieste HTTP
- ✅ Gestione autenticazione per API
- ✅ Retry logic e error handling
- ❌ NON interpreta o modifica i dati
- ❌ NON decide quale API usare

### Adapters
- ✅ Conversione formato API → formato standard
- ✅ Validazione dati ricevuti
- ✅ Gestione campi mancanti/null
- ✅ Un adapter per ogni API esterna

---

## 📊 Modelli Dati

### Formato Standard App

```objc
// MarketData (Quote )
@interface MarketData : NSObject
@property NSString *symbol;
@property double lastPrice;
@property double change;
@property double changePercent;
@property NSInteger volume;
@property double bid;
@property double ask;
@property NSDate *timestamp;
@end

// PriceHistory
@interface PriceBar : NSObject
@property NSDate *date;
@property double open;
@property double high;
@property double low;
@property double close;
@property NSInteger volume;
@end
```

### Cache TTL Policy

| Tipo Dato | TTL | Motivazione |
|-----------|-----|-------------|
| Quote  | 5-10 sec | Dati cambiano rapidamente |
| Market Overview | 1 min | Aggiornamenti meno critici |
| Price History | 5 min | Dati storici stabili |
| Company Info | 24 ore | Raramente cambia |
| Watchlist | ∞ | Solo modifiche utente |

---

## 🧩 Sistema di Widget

### Gerarchia Widget
```
BaseWidget (abstract)
├── WatchlistWidget      # Table-based, view-based cells
├── AlertWidget          # Gestione alert prezzi
├── ChartWidget          # Grafici con CHChart
├── QuoteWidget          # Quote singola 
├── GeneralMarketWidget  # Overview mercato
└── PortfolioWidget      # Posizioni e P&L
```

### Comunicazione Widget
- Widget comunicano SOLO attraverso DataHub
- Nessun widget chiama direttamente DataManager
- Updates via NSNotification da DataHub

---

## 🔌 Gestione API Esterne

### Priorità Data Source
1. **Schwab** - Dati se autenticato
2. **Webull** - Fallback per quote gratuite
3. **Yahoo Finance** - Ultimo fallback

### Flusso Autenticazione
```
1. Widget richiede dati premium
2. DataHub verifica auth status
3. Se non autenticato, notifica UI
4. UI mostra dialog login
5. DownloadManager gestisce OAuth
6. Success → retry richiesta originale
```

---

## 🚀 Best Practices

### Per Nuovi Widget
1. Estendi sempre `BaseWidget`
2. Usa SOLO DataHub per dati
3. Implementa `viewForTableColumn:` per table view
4. Gestisci stato in `serializeState/restoreState`

### Per Nuove API
1. Crea nuovo DataSource in DownloadManager
2. Implementa Adapter in DataManager
3. Aggiungi a priority list
4. Testa conversione formato

### Per Modifiche Cache
1. Modifica TTL in DataHub
2. Considera impatto performance
3. Testa con/senza connessione

---

## 📝 Note Importanti

- **Thread Safety**: DataHub usa @synchronized per cache access
- **Memory**: Widget rilasciano observer in dealloc
- **Error Handling**: Sempre fallback graceful se API fail
- **Testing**: Mock DataHub per unit test widget

---

## 🔧 Prossimi Miglioramenti

- [ ] Implementare cache persistente su disco
- [ ] Aggiungere request coalescing in DataManager
- [ ] Migliorare error reporting agli utenti
- [ ] Aggiungere metriche performance API
- [ ] Implementare offline mode completo




##### struttura UI

L'app è strutturata con i seguenti componenti principali:

### 1. **MainWindowController**
- Gestisce la finestra principale con 3 pannelli (sinistra, centro, destra)
- I pannelli laterali sono collassabili tramite pulsanti nella toolbar
- Gestisce il salvataggio/caricamento dei layout

### 2. **PanelController**
- Ogni pannello ha il proprio controller
- Gestisce i widget al suo interno
- Ha una barra superiore per salvare/caricare layout specifici del pannello
- Garantisce che ci sia sempre almeno un widget nel pannello

### 3. **BaseWidget**
- Classe base per tutti i widget
- Barra del titolo con:
  - [X] Chiudi (disabilitato se è l'ultimo widget)
  - [-] Collassa (solo pannelli laterali)
  - Titolo editabile con autocompletamento
  - [🔗] Chain per connessioni
  - [+] Aggiungi nuovo widget

### 4. **WidgetContainerView**
- Gestisce la disposizione dei widget usando NSSplitView annidate
- Nessuno spazio vuoto - i widget riempiono sempre tutto lo spazio
- Struttura ad albero per facile serializzazione

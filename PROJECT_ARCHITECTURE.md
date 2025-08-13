# PROJECT ARCHITECTURE - Versione Corretta

## 🏗️ Architettura Generale

L'app è strutturata in 4 layer principali con responsabilità ben definite:

```
┌─────────────────────────────────────────────────────────┐
│                    UI LAYER                             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐      │
│  │   Widget    │ │   Widget    │ │   Widget    │      │
│  │    #1       │ │    #2       │ │    #3       │      │
│  └─────────────┘ └─────────────┘ └─────────────┘      │
└─────────────────────┬───────────────────────────────────┘
                      │ DataHub API calls only
┌─────────────────────▼───────────────────────────────────┐
│                 DATA HUB LAYER                          │
│ ┌─────────────────────────────────────────────────────┐ │
│ │              DataHub (Facade)                       │ │
│ │  • Cache Management (Memory + Core Data)            │ │
│ │  • TTL Policy & Freshness Logic                     │ │
│ │  • Notification Broadcasting                        │ │
│ │  • Subscription Management (Pseudo Real-Time)       │ │
│ │  • Business Logic (Alerts, Watchlists, Favorites)   │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────┬───────────────────────────────────┘
                      │ Standardized requests
┌─────────────────────▼───────────────────────────────────┐
│                DATA MANAGER LAYER                       │
│ ┌─────────────────────────────────────────────────────┐ │
│ │              DataManager                            │ │
│ │  • Data Standardization via Adapters               │ │
│ │  • Runtime Model Creation                           │ │
│ │  • Request Coordination                             │ │
│ │  • Response Validation                              │ │
│ └─────────────────────────────────────────────────────┘ │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
│ │   Schwab    │ │   Webull    │ │    Other    │       │
│ │   Adapter   │ │   Adapter   │ │   Adapter   │       │
│ └─────────────┘ └─────────────┘ └─────────────┘       │
└─────────────────────┬───────────────────────────────────┘
                      │ Raw API calls
┌─────────────────────▼───────────────────────────────────┐
│              DOWNLOAD MANAGER LAYER                     │
│ ┌─────────────────────────────────────────────────────┐ │
│ │              DownloadManager                        │ │
│ │  • API Selection & Priority Management             │ │
│ │  • Automatic Failover Logic                        │ │
│ │  • HTTP Request Execution                           │ │
│ │  • Connection Status Monitoring                     │ │
│ │  • Rate Limiting & Error Handling                   │ │
│ │  • Authentication Management                        │ │
│ └─────────────────────────────────────────────────────┘ │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │
│ │   Schwab    │ │   Webull    │ │    Other    │       │
│ │ DataSource  │ │ DataSource  │ │ DataSource  │       │
│ └─────────────┘ └─────────────┘ └─────────────┘       │
└─────────────────────┬───────────────────────────────────┘
                      │ HTTP/REST calls
┌─────────────────────▼───────────────────────────────────┐
│                 EXTERNAL APIs                           │
│     Schwab API  ┃  Webull API  ┃  Yahoo Finance API     │
│                 ┃              ┃                        │
└─────────────────────────────────────────────────────────┘
```

---

## 🎯 Responsabilità dei Componenti

### DataHub (Business Logic Layer)
- ✅ **Punto di accesso UNICO** per tutti i widget
- ✅ **Cache Management** intelligente (Memory + Core Data)
- ✅ **TTL Policy** e gestione freshness dei dati
- ✅ **Subscription Management** per aggiornamenti pseudo real-time
- ✅ **Notification Broadcasting** via NSNotificationCenter
- ✅ **Business Logic** (alerts, watchlist, favorites, portfolio)
- ✅ **Data Enrichment** (unione info locali a dati remoti)
- ❌ **NON sa nulla di API esterne o formati specifici**
- ❌ **NON decide quale API usare**

### DataManager (Standardization Layer)
- ✅ **Standardizzazione dati** tramite Adapter pattern
- ✅ **Creazione Runtime Models** thread-safe per UI
- ✅ **Coordinamento richieste** verso DownloadManager
- ✅ **Validazione response** e gestione errori
- ✅ **Request delegation** al DownloadManager
- ❌ **NON gestisce persistenza o cache**
- ❌ **NON decide quale API chiamare**
- ❌ **NON esegue chiamate HTTP dirette**

### DownloadManager (Network & Selection Layer)
- ✅ **API Selection** basata su priorità e capabilities
- ✅ **Automatic Failover** tra data sources
- ✅ **HTTP Request Execution** effettiva
- ✅ **Connection Status Monitoring** per ogni API
- ✅ **Rate Limiting** e retry logic
- ✅ **Authentication Management** (OAuth, tokens)
- ✅ **Data Source Registration** con priorità
- ✅ **Failure Tracking** per smart fallback
- ❌ **NON interpreta o modifica i dati**
- ❌ **NON conosce business logic**

### Adapters (Format Conversion)
- ✅ **Conversione formato** API → formato standard app
- ✅ **Validazione dati** ricevuti da API
- ✅ **Gestione campi mancanti/null** con valori default
- ✅ **Un adapter specifico** per ogni API esterna
- ✅ **Creazione diretta** di Runtime Models

---

## 🔄 Flusso Dati Dettagliato

### 📤 Richiesta Dati (Widget → API)

1. **Widget** chiama DataHub con richiesta specifica
2. **DataHub** verifica cache in memoria e TTL
3. Se cache stale/missing, **DataHub** chiama DataManager
4. **DataManager** delega richiesta a DownloadManager
5. **DownloadManager** seleziona API ottimale basandosi su:
   - Priorità registrate (Schwab=1, Webull=50, Other=100)
   - Capabilities per il tipo di richiesta
   - Stato connessione
   - History di failures
6. **DownloadManager** esegue chiamata HTTP via DataSource
7. **DataSource** specifico gestisce protocollo API

### 📥 Risposta Dati (API → Widget)

1. **DataSource** ritorna dati grezzi JSON/XML
2. **DownloadManager** passa dati a DataManager
3. **DataManager** usa Adapter appropriato per standardizzazione
4. **Adapter** converte in Runtime Models thread-safe
5. **DataHub** riceve Runtime Models e li cacheizza
6. **DataHub** arricchisce con dati locali se necessario
7. **DataHub** broadcast notifica di aggiornamento
8. **Widget** riceve Runtime Models pronti per display

### 🔄 Gestione Errori e Fallback

1. Se API primaria fallisce, **DownloadManager** incrementa failure counter
2. **DownloadManager** prova automaticamente API successiva per priorità
3. Se tutte le API falliscono, **DataHub** ritorna dati cached (se disponibili)
4. **DataHub** notifica errore ai widget per gestione UI appropriata

---

## 📊 Modelli Dati

### Runtime Models (Thread-Safe, UI-Ready)

```objc
// MarketQuoteModel - Per quote real-time
@interface MarketQuoteModel : NSObject
@property NSString *symbol;
@property double lastPrice;
@property double change;
@property double changePercent;
@property NSInteger volume;
@property double bid;
@property double ask;
@property NSDate *timestamp;
@property BOOL isAfterHours;
@end

// HistoricalBarModel - Per dati storici
@interface HistoricalBarModel : NSObject
@property NSDate *date;
@property double open;
@property double high;
@property double low;
@property double close;
@property NSInteger volume;
@property BarTimeframe timeframe;
@end

// CompanyInfoModel - Per informazioni aziendali
@interface CompanyInfoModel : NSObject
@property NSString *symbol;
@property NSString *companyName;
@property NSString *sector;
@property NSString *industry;
@property double marketCap;
@property double peRatio;
@end
```

### Cache TTL Policy

| Tipo Dato | TTL | Motivazione |
|-----------|-----|-------------|
| **Quote** | 10 sec | Dati cambiano rapidamente durante trading |
| **Historical Data** | 5 min | Dati storici relativamente stabili |
| **Market Overview** | 1 min | Aggiornamenti meno critici |
| **Company Info** | 24 ore | Informazioni aziendali cambiano raramente |
| **Watchlist** | ∞ | Solo modifiche manuali utente |

---

## 🔌 Gestione Data Sources

### Registrazione e Priorità (AppDelegate)

```objc
// Priorità crescente = Qualità decrescente
[downloadManager registerDataSource:schwabSource withType:DataSourceTypeSchwab priority:1];      // Premium
[downloadManager registerDataSource:webullSource withType:DataSourceTypeWebull priority:50];    // Free
[downloadManager registerDataSource:otherSource withType:DataSourceTypeOther priority:100];     // Fallback
[downloadManager registerDataSource:claudeSource withType:DataSourceTypeClaude priority:200];   // AI only
```

### Selezione Automatica

Il **DownloadManager** sceglie automaticamente l'API migliore considerando:

1. **Priorità** (numero più basso = priorità più alta)
2. **Capabilities** (l'API supporta il tipo di richiesta?)
3. **Connection Status** (l'API è attualmente connessa?)
4. **Failure Count** (quanti errori recenti?)
5. **Request Type** (alcune richieste sono specifiche per certe API)

### Fallback Logic

```objc
Schwab Fallisce → Prova Webull → Prova Other → Ritorna Cache (se disponibile) → Errore
```

---

## 🧩 Sistema Widget

### Gerarchia Widget

```
BaseWidget (abstract)
├── WatchlistWidget      # Watchlist con table view-based
├── AlertWidget          # Gestione alert prezzi
├── ChartWidget          # Grafici avanzati con CHChart
├── QuoteWidget          # Quote singola dettagliata
├── PortfolioWidget      # Posizioni e P&L
├── TickChartWidget      # Tick-by-tick data e volume analysis
└── NewsWidget           # News e sentiment analysis
```

### Comunicazione Widget

- **Widget comunicano SOLO attraverso DataHub** - mai chiamate dirette
- **Updates via NSNotification** broadcasting da DataHub
- **Subscription automatica** per aggiornamenti real-time
- **Thread-safe** grazie ai Runtime Models

---

## 🚀 Sistema Subscription (Pseudo Real-Time)

### Timer-Based Updates

```objc
// DataHub gestisce subscription con timer da 5 secondi
- (void)subscribeToQuoteUpdatesForSymbol:(NSString *)symbol;
- (void)startRefreshTimer; // Timer ogni 5 secondi
- (void)refreshSubscribedQuotes; // Aggiorna tutti i simboli sottoscritti
```

### Workflow Subscription

1. **Widget** si subscribe a simboli specifici
2. **DataHub** mantiene set di simboli attivi
3. **Timer** aggiorna periodicamente tutti i simboli
4. **Notification broadcast** notifica tutti i widget interessati
5. **Auto-unsubscribe** quando widget viene deallocato

---

## 📁 Struttura Directory

```
mafia_AI/
├── UI/
│   ├── Widgets/
│   │   ├── BaseWidget/          # Classe base astratta
│   │   ├── Watchlist/           # WatchlistWidget + Provider system
│   │   ├── Alert/               # AlertWidget + gestione notifiche
│   │   ├── Chart/               # ChartWidget + CHChart integration
│   │   ├── Quote/               # QuoteWidget dettagliato
│   │   ├── GeneralMarket/       # Market overview widget
│   │   ├── Portfolio/           # Portfolio tracking
│   │   ├── TickData/            # Tick chart e volume analysis
│   │   └── News/                # News e sentiment widget
│   │
│   └── MainWindow/
│       ├── MainWindowController # Finestra principale 3-panel
│       ├── PanelController      # Gestione widget per pannello
│       └── WidgetContainerView  # Layout management con NSSplitView
│
├── Gestione Dati/
│   ├── DataHub/
│   │   ├── DataHub.h/m          # Facade principale
│   │   ├── DataHub+MarketData   # Quote e dati storici
│   │   ├── DataHub+TickData     # Tick-by-tick data
│   │   ├── DataHub+SeasonalData # Dati stagionali/quarterly
│   │   └── DataHub+Private.h    # Metodi interni
│   │
│   ├── DataManager/
│   │   ├── DataManager.h/m      # Coordinatore standardizzazione
│   │   └── ADAPTERS/            # Converter per ogni API
│   │       ├── SchwabAdapter.m  # Schwab API → Runtime Models
│   │       ├── WebullAdapter.m  # Webull API → Runtime Models
│   │       ├── OtherAdapter.m   # Other APIs → Runtime Models
│   │       └── DataSourceAdapter.h # Protocol base
│   │
│   └── DownloadManager/
│       ├── DownloadManager.h/m  # Network layer + API selection
│       └── DATA SOURCES/        # Implementazioni specifiche API
│           ├── SchwabDataSource.m
│           ├── WebullDataSource.m
│           ├── OtherDataSource.m
│           └── ClaudeDataSource.m
│
├── Models/
│   ├── CoreData/                # Persistenza locale
│   │   ├── Symbol+CoreDataClass
│   │   ├── MarketQuote+CoreDataClass
│   │   ├── HistoricalBar+CoreDataClass
│   │   ├── Watchlist+CoreDataClass
│   │   └── Alert+CoreDataClass
│   │
│   ├── Runtime/                 # Runtime Models thread-safe
│   │   ├── RuntimeModels.h      # Tutti i runtime models
│   │   ├── MarketQuoteModel.m
│   │   ├── HistoricalBarModel.m
│   │   ├── CompanyInfoModel.m
│   │   ├── TickDataModel.m
│   │   └── SeasonalDataModel.m
│   │
│   └── Standard/                # Legacy models
│       ├── MarketData.h         # Standard quote format
│       └── PriceHistory.h       # Standard historical format
│
└── Utils/
    ├── Network/                 # HTTP utilities
    ├── UI/                      # UI utilities e extensions
    └── Core/                    # Core utilities e constants
```

---

## 🔧 Best Practices

### Per Nuovi Widget
1. **Estendi sempre BaseWidget** per funzionalità comuni
2. **Usa SOLO DataHub** per dati - mai chiamate dirette a DataManager
3. **Implementa subscription management** in viewDidLoad/dealloc
4. **Gestisci stato** in serializeState/restoreState
5. **Thread-safe UI updates** via dispatch_async main queue

### Per Nuove API
1. **Crea DataSource** in DownloadManager per gestione HTTP
2. **Implementa Adapter** in DataManager per standardizzazione
3. **Registra in AppDelegate** con priorità appropriata
4. **Testa capabilities** per ogni tipo di richiesta
5. **Gestisci error cases** e fallback gracefully

### Per Modifiche Cache
1. **Modifica TTL** in DataHub+Private.h
2. **Considera impatto performance** su widget multipli
3. **Testa con/senza connessione** per offline behavior
4. **Monitora memory usage** per cache grandi

### Per Thread Safety
1. **Usa Runtime Models** sempre - mai Core Data objects su main thread
2. **@synchronized blocks** per cache access in DataHub
3. **Background queues** per Core Data operations
4. **Main queue dispatch** per UI updates

---

## 📝 Note Architetturali

### Design Patterns Utilizzati
- **Facade Pattern**: DataHub come interfaccia unificata
- **Adapter Pattern**: Conversione formati API diversi
- **Observer Pattern**: NSNotification per updates
- **Strategy Pattern**: Selezione automatica API
- **Singleton Pattern**: DataHub, DataManager, DownloadManager

### Thread Safety Considerations
- **DataHub**: @synchronized per cache operations
- **Runtime Models**: Immutable objects, thread-safe
- **Core Data**: Background context per save operations
- **UI Updates**: Sempre su main queue via dispatch_async

### Memory Management
- **Widget observers**: Removals in dealloc per evitare leaks
- **Cache TTL**: Automatic cleanup di dati stale
- **Runtime Models**: ARC automatic memory management
- **Request coalescing**: Evita richieste duplicate

### Error Handling Strategy
- **Automatic Fallback**: DownloadManager prova API alternative
- **Graceful Degradation**: DataHub ritorna cache se API fail
- **User Notification**: Widget gestiscono display errori appropriati
- **Retry Logic**: Automatic retry con exponential backoff

---

## 🚀 Roadmap Future

### Planned Improvements
- [ ] **WebSocket Support** per true real-time data
- [ ] **Request Coalescing** in DataManager per performance
- [ ] **Disk Cache** persistente per offline mode
- [ ] **Performance Metrics** per monitoring API
- [ ] **Smart Prefetching** basato su usage patterns
- [ ] **Advanced Error Analytics** per debugging
- [ ] **API Usage Statistics** per optimization

### Scalability Considerations
- Architettura progettata per **multiple concurrent widgets**
- **Cache layer** riduce load su API esterne
- **Subscription system** ottimizza refresh patterns
- **Modular design** facilita aggiunta nuove API
- **Thread-safe operations** supportano UI responsive

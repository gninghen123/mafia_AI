/ GeneralMarketWidget.m - Versione che usa SOLO DataHub

#import "GeneralMarketWidget.h"
#import "DataHub.h"
#import "DataHub+MarketData.h"
#import "Watchlist+CoreDataClass.h"
#import "MarketPerformer+CoreDataClass.h"

@interface GeneralMarketWidget ()
@property (nonatomic, strong) NSMenuItem *contextMenuCreateWatchlist;
@property (nonatomic, strong) NSMenuItem *contextMenuSendToChain;
@property (nonatomic, strong) NSMenu *contextMenu;
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *marketLists;
@end

@implementation GeneralMarketWidget

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        _marketLists = [NSMutableArray array];
        _pageSize = 50;
    }
    return self;
}

#pragma mark - Setup

- (void)setupContentView {
    [super setupContentView];
    // Main container
    NSView *containerView = [[NSView alloc] init];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:containerView];
    
    // Toolbar with refresh button
    NSView *toolbar = [self createToolbar];
    toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:toolbar];
    
    // Scroll view for outline
    self.scrollView = [[NSScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.autohidesScrollers = YES;
    [containerView addSubview:self.scrollView];
    
    // Outline view
    self.outlineView = [[NSOutlineView alloc] init];
    self.outlineView.delegate = self;
    self.outlineView.dataSource = self;
    self.outlineView.headerView = nil;
    self.outlineView.allowsMultipleSelection = YES;
    self.outlineView.doubleAction = @selector(doubleClickAction:);
    self.outlineView.target = self;
    
    // Columns
    NSTableColumn *symbolColumn = [[NSTableColumn alloc] initWithIdentifier:@"symbol"];
    symbolColumn.title = @"Symbol";
    symbolColumn.width = 80;
    [self.outlineView addTableColumn:symbolColumn];
    
    NSTableColumn *nameColumn = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    nameColumn.title = @"Name";
    nameColumn.width = 200;
    [self.outlineView addTableColumn:nameColumn];
    
    NSTableColumn *priceColumn = [[NSTableColumn alloc] initWithIdentifier:@"price"];
    priceColumn.title = @"Price";
    priceColumn.width = 80;
    [self.outlineView addTableColumn:priceColumn];
    
    NSTableColumn *changeColumn = [[NSTableColumn alloc] initWithIdentifier:@"change"];
    changeColumn.title = @"Change %";
    changeColumn.width = 80;
    [self.outlineView addTableColumn:changeColumn];
    
    self.scrollView.documentView = self.outlineView;
    
    // Context menu
    self.outlineView.menu = [self createContextMenu];
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [containerView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [containerView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [containerView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [containerView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        
        [toolbar.topAnchor constraintEqualToAnchor:containerView.topAnchor],
        [toolbar.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [toolbar.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
        [toolbar.heightAnchor constraintEqualToConstant:30],
        
        [self.scrollView.topAnchor constraintEqualToAnchor:toolbar.bottomAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor]
    ]];
    
    [self setupInitialDataStructure];
      [self registerForNotifications];
      [self loadDataFromDataHub];
  }

  - (void)setupInitialDataStructure {
      self.marketLists = [NSMutableArray array];
      
      NSArray *listTypes = @[@"ETF", @"Day Gainers", @"Day Losers", @"Week Gainers", @"Week Losers"];
      for (NSString *type in listTypes) {
          [self.marketLists addObject:@{
              @"type": type,
              @"items": [NSMutableArray array],
              @"expanded": @NO,
              @"lastUpdate": [NSDate date]
          }.mutableCopy];
      }
  }

  - (void)registerForNotifications {
      NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
      
      [nc addObserver:self
             selector:@selector(marketDataUpdated:)
                 name:@"DataHubMarketListUpdated"
               object:nil];
      
      [nc addObserver:self
             selector:@selector(marketQuoteUpdated:)
                 name:@"DataHubMarketQuoteUpdated"
               object:nil];
  }

  #pragma mark - Data Loading from DataHub ONLY

  - (void)refreshData {
      if (self.isLoading) return;
      
      self.isLoading = YES;
      self.progressIndicator.hidden = NO;
      [self.progressIndicator startAnimation:nil];
      self.refreshButton.enabled = NO;
      
      // NON chiamiamo DataManager!
      // Invece, chiediamo a DataHub di aggiornare i dati
      DataHub *hub = [DataHub shared];
      
      // DataHub dovrebbe avere un metodo per richiedere aggiornamenti
      // Per ora, carichiamo solo quello che c'è
      [self loadDataFromDataHub];
      
      // Se vogliamo dati freschi, DataHub dovrebbe gestirlo internamente
      // Potremmo aggiungere un metodo come:
      // [hub requestMarketDataUpdate];
      
      self.isLoading = NO;
      self.progressIndicator.hidden = YES;
      [self.progressIndicator stopAnimation:nil];
      self.refreshButton.enabled = YES;
      
      [self showTemporaryMessage:@"Data loaded from cache"];
  }

  - (void)loadDataFromDataHub {
      DataHub *hub = [DataHub shared];
      
      // Mapping tra tipo lista e timeframe
      NSDictionary *listMappings = @{
          @"Day Gainers": @{@"type": @"gainers", @"timeframe": @"1d"},
          @"Day Losers": @{@"type": @"losers", @"timeframe": @"1d"},
          @"Week Gainers": @{@"type": @"gainers", @"timeframe": @"52w"},
          @"Week Losers": @{@"type": @"losers", @"timeframe": @"52w"},
          @"ETF": @{@"type": @"etf", @"timeframe": @"1d"}
      };
      
      for (NSMutableDictionary *marketList in self.marketLists) {
          NSString *listName = marketList[@"type"];
          NSDictionary *mapping = listMappings[listName];
          
          if (mapping) {
              NSArray<MarketPerformer *> *performers = [hub getMarketPerformersForList:mapping[@"type"]
                                                                            timeframe:mapping[@"timeframe"]];
              
              NSMutableArray *items = [NSMutableArray array];
              for (MarketPerformer *performer in performers) {
                  [items addObject:@{
                      @"symbol": performer.symbol ?: @"",
                      @"name": performer.name ?: performer.symbol ?: @"",
                      @"price": @(performer.price),
                      @"changePercent": @(performer.changePercent),
                      @"volume": @(performer.volume)
                  }];
              }
              
              marketList[@"items"] = items;
              marketList[@"lastUpdate"] = [NSDate date];
          }
      }
      
      [self.outlineView reloadData];
  }

  #pragma mark - Notifications

  - (void)marketDataUpdated:(NSNotification *)notification {
      // DataHub ci notifica che ci sono nuovi dati
      dispatch_async(dispatch_get_main_queue(), ^{
          [self loadDataFromDataHub];
      });
  }

  - (void)marketQuoteUpdated:(NSNotification *)notification {
      NSDictionary *userInfo = notification.userInfo;
      NSString *symbol = userInfo[@"symbol"];
      MarketQuote *quote = userInfo[@"quote"];
      
      // Aggiorna solo il simbolo specifico
      for (NSMutableDictionary *list in self.marketLists) {
          NSMutableArray *items = list[@"items"];
          for (NSMutableDictionary *item in items) {
              if ([item[@"symbol"] isEqualToString:symbol]) {
                  item[@"price"] = @(quote.currentPrice);
                  item[@"changePercent"] = @(quote.changePercent);
                  
                  // Aggiorna solo questa riga
                  NSInteger row = [self rowForItem:item];
                  if (row >= 0) {
                      [self.outlineView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
                                                  columnIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, self.outlineView.numberOfColumns)]];
                  }
              }
          }
      }
  }

  #pragma mark - Actions

  - (void)createWatchlistFromSelection {
      NSArray *symbols = [self selectedSymbols];
      if (symbols.count > 0) {
          [self createWatchlistFromList:symbols];
      }
  }

  - (void)createWatchlistFromList:(NSArray *)symbols {
      // Usa DataHub per creare la watchlist
      DataHub *hub = [DataHub shared];
      
      NSAlert *alert = [[NSAlert alloc] init];
      alert.messageText = @"Create New Watchlist";
      alert.informativeText = [NSString stringWithFormat:@"Enter a name for the watchlist with %lu symbols",
                             (unsigned long)symbols.count];
      [alert addButtonWithTitle:@"Create"];
      [alert addButtonWithTitle:@"Cancel"];
      
      NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
      input.stringValue = @"New Watchlist";
      alert.accessoryView = input;
      
      NSModalResponse response = [alert runModal];
      if (response == NSAlertFirstButtonReturn) {
          NSString *name = input.stringValue;
          if (name.length > 0) {
              Watchlist *watchlist = [hub createWatchlistWithName:name];
              watchlist.symbols = symbols;
              [hub updateWatchlist:watchlist];
              [self showTemporaryMessage:[NSString stringWithFormat:@"Created watchlist: %@", name]];
          }
      }
  }

  - (void)dealloc {
      [[NSNotificationCenter defaultCenter] removeObserver:self];
      [self.refreshTimer invalidate];
  }

  @end

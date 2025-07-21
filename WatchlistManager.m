// WatchlistManager.m - VERSIONE COMPLETA DATAHUB

#import "WatchlistManager.h"
#import "SymbolDataHub.h"
#import "SymbolDataModels.h"

@interface WatchlistManager ()
// Non serve più dizionario locale!
@end

@implementation WatchlistManager

+ (instancetype)sharedManager {
    static WatchlistManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Crea watchlist di default se non esistono
        [self createDefaultWatchlistsIfNeeded];
        
        // Osserva notifiche dal DataHub
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(watchlistsUpdated:)
                                                     name:@"WatchlistsUpdatedNotification"
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Watchlist Management

- (void)createDefaultWatchlistsIfNeeded {
    NSArray<WatchlistDataModel *> *existing = [[SymbolDataHub sharedHub] allWatchlists];
    
    if (existing.count == 0) {
        // Crea watchlist di default
        [[SymbolDataHub sharedHub] createWatchlistWithName:@"Favorites"];
        [[SymbolDataHub sharedHub] createWatchlistWithName:@"Tech Stocks"];
        [[SymbolDataHub sharedHub] createWatchlistWithName:@"Crypto"];
        
        NSLog(@"Created default watchlists");
    }
}

- (NSArray<NSString *> *)allWatchlistNames {
    NSArray<WatchlistDataModel *> *watchlists = [[SymbolDataHub sharedHub] allWatchlists];
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    
    for (WatchlistDataModel *watchlist in watchlists) {
        [names addObject:watchlist.name];
    }
    
    return names;
}

- (WatchlistData *)watchlistWithName:(NSString *)name {
    WatchlistDataModel *model = [[SymbolDataHub sharedHub] watchlistWithName:name];
    if (!model) return nil;
    
    // Converti da Core Data model a WatchlistData per compatibilità
    WatchlistData *data = [[WatchlistData alloc] initWithName:model.name];
    data.isDynamic = model.isDynamic;
    data.dynamicTag = model.dynamicTag;
    
    // Copia simboli
    [data.symbols removeAllObjects];
    [data.symbols addObjectsFromArray:[model symbolNames]];
    
    return data;
}

- (void)saveWatchlist:(WatchlistData *)watchlist {
    if (!watchlist) return;
    
    WatchlistDataModel *model = [[SymbolDataHub sharedHub] watchlistWithName:watchlist.name];
    
    if (!model) {
        // Crea nuova
        model = [[SymbolDataHub sharedHub] createWatchlistWithName:watchlist.name];
    }
    
    // Aggiorna simboli (solo per watchlist non dinamiche)
    if (!model.isDynamic) {
        // Rimuovi tutti i simboli esistenti
        for (NSString *symbol in [model symbolNames]) {
            [[SymbolDataHub sharedHub] removeSymbol:symbol fromWatchlist:model];
        }
        
        // Aggiungi i nuovi
        for (NSString *symbol in watchlist.symbols) {
            [[SymbolDataHub sharedHub] addSymbol:symbol toWatchlist:model];
        }
    }
}

- (void)deleteWatchlistWithName:(NSString *)name {
    WatchlistDataModel *model = [[SymbolDataHub sharedHub] watchlistWithName:name];
    if (model) {
        [[SymbolDataHub sharedHub] deleteWatchlist:model];
    }
}

- (WatchlistData *)createWatchlistWithName:(NSString *)name {
    WatchlistDataModel *model = [[SymbolDataHub sharedHub] createWatchlistWithName:name];
    return [self watchlistWithName:model.name];
}

- (WatchlistData *)createDynamicWatchlistWithName:(NSString *)name forTag:(NSString *)tag {
    WatchlistDataModel *model = [[SymbolDataHub sharedHub] createDynamicWatchlistWithName:name forTag:tag];
    return [self watchlistWithName:model.name];
}

#pragma mark - Symbol Management

- (void)addSymbol:(NSString *)symbol toWatchlist:(NSString *)watchlistName {
    WatchlistDataModel *model = [[SymbolDataHub sharedHub] watchlistWithName:watchlistName];
    if (model) {
        [[SymbolDataHub sharedHub] addSymbol:symbol toWatchlist:model];
    }
}

- (void)removeSymbol:(NSString *)symbol fromWatchlist:(NSString *)watchlistName {
    WatchlistDataModel *model = [[SymbolDataHub sharedHub] watchlistWithName:watchlistName];
    if (model) {
        [[SymbolDataHub sharedHub] removeSymbol:symbol fromWatchlist:model];
    }
}

#pragma mark - Tags

- (NSArray<NSString *> *)availableTags {
    return [[SymbolDataHub sharedHub] allAvailableTags];
}

- (void)addTag:(NSString *)tag toSymbol:(NSString *)symbol {
    [[SymbolDataHub sharedHub] addTag:tag toSymbol:symbol];
}

- (void)removeTag:(NSString *)tag fromSymbol:(NSString *)symbol {
    [[SymbolDataHub sharedHub] removeTag:tag fromSymbol:symbol];
}

- (NSArray<NSString *> *)tagsForSymbol:(NSString *)symbol {
    return [[SymbolDataHub sharedHub] tagsForSymbol:symbol];
}

#pragma mark - Notifications

- (void)watchlistsUpdated:(NSNotification *)notification {
    // Propaga la notifica ai widget
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WatchlistManagerUpdatedNotification"
                                                        object:self
                                                      userInfo:notification.userInfo];
}

@end

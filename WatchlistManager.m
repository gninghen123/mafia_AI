//
//  WatchlistManager.m
//  TradingApp
//

#import "WatchlistManager.h"

#pragma mark - WatchlistData Implementation

@implementation WatchlistData

- (instancetype)initWithName:(NSString *)name {
    self = [super init];
    if (self) {
        _name = name;
        _symbols = [NSMutableArray array];
        _createdDate = [NSDate date];
        _lastModified = [NSDate date];
        _isDynamic = NO;
        _dynamicTag = nil;
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name dynamicTag:(NSString *)tag {
    self = [super init];
    if (self) {
        _name = name;
        _symbols = [NSMutableArray array];
        _createdDate = [NSDate date];
        _lastModified = [NSDate date];
        _isDynamic = YES;
        _dynamicTag = tag;
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"name": self.name,
        @"symbols": [self.symbols copy],
        @"createdDate": @([self.createdDate timeIntervalSince1970]),
        @"lastModified": @([self.lastModified timeIntervalSince1970]),
        @"isDynamic": @(self.isDynamic),
        @"dynamicTag": self.dynamicTag ?: [NSNull null]
    };
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        _name = dict[@"name"];
        _symbols = [dict[@"symbols"] mutableCopy] ?: [NSMutableArray array];
        _createdDate = dict[@"createdDate"] ? [NSDate dateWithTimeIntervalSince1970:[dict[@"createdDate"] doubleValue]] : [NSDate date];
        _lastModified = dict[@"lastModified"] ? [NSDate dateWithTimeIntervalSince1970:[dict[@"lastModified"] doubleValue]] : [NSDate date];
        _isDynamic = [dict[@"isDynamic"] boolValue];
        _dynamicTag = dict[@"dynamicTag"] != [NSNull null] ? dict[@"dynamicTag"] : nil;
    }
    return self;
}

@end

#pragma mark - SymbolProperties Implementation

@implementation SymbolProperties

- (instancetype)initWithSymbol:(NSString *)symbol {
    self = [super init];
    if (self) {
        _symbol = symbol;
        _color = nil;
        _tags = [NSMutableSet set];
        _note = @"";
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"symbol"] = self.symbol;
    
    if (self.color) {
        // Convert NSColor to RGB values
        NSColor *rgbColor = [self.color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
        dict[@"color"] = @{
            @"red": @([rgbColor redComponent]),
            @"green": @([rgbColor greenComponent]),
            @"blue": @([rgbColor blueComponent]),
            @"alpha": @([rgbColor alphaComponent])
        };
    }
    
    dict[@"tags"] = [self.tags allObjects];
    dict[@"note"] = self.note ?: @"";
    
    return dict;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        _symbol = dict[@"symbol"];
        _tags = [NSMutableSet setWithArray:dict[@"tags"] ?: @[]];
        _note = dict[@"note"] ?: @"";
        
        // Restore color from RGB values
        if (dict[@"color"]) {
            NSDictionary *colorDict = dict[@"color"];
            CGFloat red = [colorDict[@"red"] doubleValue];
            CGFloat green = [colorDict[@"green"] doubleValue];
            CGFloat blue = [colorDict[@"blue"] doubleValue];
            CGFloat alpha = [colorDict[@"alpha"] doubleValue];
            _color = [NSColor colorWithRed:red green:green blue:blue alpha:alpha];
        }
    }
    return self;
}

@end

#pragma mark - WatchlistManager Implementation

@interface WatchlistManager ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, WatchlistData *> *watchlists;
@property (nonatomic, strong) NSMutableDictionary<NSString *, SymbolProperties *> *symbolProperties;
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
        _watchlists = [NSMutableDictionary dictionary];
        _symbolProperties = [NSMutableDictionary dictionary];
        [self loadAllData];
        
        // Create default watchlist if none exist
        if (self.watchlists.count == 0) {
            WatchlistData *defaultWL = [self createWatchlistWithName:@"Default"];
            [defaultWL.symbols addObjectsFromArray:@[@"AAPL", @"MSFT", @"GOOGL"]];
            [self saveWatchlist:defaultWL];
        }
    }
    return self;
}

#pragma mark - Watchlist Management

- (NSArray<NSString *> *)availableWatchlistNames {
    NSArray *names = [self.watchlists.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    return names;
}

- (WatchlistData *)watchlistWithName:(NSString *)name {
    return self.watchlists[name];
}

- (void)saveWatchlist:(WatchlistData *)watchlist {
    if (!watchlist || !watchlist.name) return;
    
    watchlist.lastModified = [NSDate date];
    self.watchlists[watchlist.name] = watchlist;
    [self saveAllData];
    
    NSLog(@"WatchlistManager: Saved watchlist '%@' with %lu symbols", watchlist.name, (unsigned long)watchlist.symbols.count);
}

- (void)deleteWatchlistWithName:(NSString *)name {
    if (!name) return;
    
    [self.watchlists removeObjectForKey:name];
    [self saveAllData];
    
    NSLog(@"WatchlistManager: Deleted watchlist '%@'", name);
}

- (WatchlistData *)createWatchlistWithName:(NSString *)name {
    if (!name || name.length == 0) {
        name = [NSString stringWithFormat:@"Watchlist %lu", (unsigned long)(self.watchlists.count + 1)];
    }
    
    // Ensure unique name
    NSString *uniqueName = name;
    NSInteger counter = 1;
    while (self.watchlists[uniqueName]) {
        uniqueName = [NSString stringWithFormat:@"%@ (%ld)", name, (long)counter];
        counter++;
    }
    
    WatchlistData *newWatchlist = [[WatchlistData alloc] initWithName:uniqueName];
    self.watchlists[uniqueName] = newWatchlist;
    [self saveAllData];
    
    NSLog(@"WatchlistManager: Created watchlist '%@'", uniqueName);
    return newWatchlist;
}

- (WatchlistData *)createDynamicWatchlistWithName:(NSString *)name forTag:(NSString *)tag {
    if (!name || name.length == 0) {
        name = [NSString stringWithFormat:@"#%@", tag];
    }
    
    // Ensure unique name
    NSString *uniqueName = name;
    NSInteger counter = 1;
    while (self.watchlists[uniqueName]) {
        uniqueName = [NSString stringWithFormat:@"%@ (%ld)", name, (long)counter];
        counter++;
    }
    
    WatchlistData *newWatchlist = [[WatchlistData alloc] initWithName:uniqueName dynamicTag:tag];
    [self updateDynamicWatchlistContent:newWatchlist];
    self.watchlists[uniqueName] = newWatchlist;
    [self saveAllData];
    
    NSLog(@"WatchlistManager: Created dynamic watchlist '%@' for tag '%@'", uniqueName, tag);
    return newWatchlist;
}

- (void)updateDynamicWatchlistContent:(WatchlistData *)watchlist {
    if (!watchlist.isDynamic || !watchlist.dynamicTag) return;
    
    NSArray<NSString *> *symbolsWithTag = [self symbolsWithTag:watchlist.dynamicTag];
    
    [watchlist.symbols removeAllObjects];
    [watchlist.symbols addObjectsFromArray:symbolsWithTag];
    watchlist.lastModified = [NSDate date];
}

#pragma mark - Dynamic Watchlist Management

- (void)updateDynamicWatchlists {
    for (WatchlistData *watchlist in self.watchlists.allValues) {
        if (watchlist.isDynamic) {
            [self updateDynamicWatchlistContent:watchlist];
        }
    }
    [self saveAllData];
}

- (NSArray<NSString *> *)symbolsWithTag:(NSString *)tag {
    NSMutableArray *symbolsWithTag = [NSMutableArray array];
    
    for (NSString *symbol in self.symbolProperties.allKeys) {
        SymbolProperties *properties = self.symbolProperties[symbol];
        if ([properties.tags containsObject:tag]) {
            [symbolsWithTag addObject:symbol];
        }
    }
    
    return [symbolsWithTag sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (NSArray<NSString *> *)availableTags {
    NSMutableSet *allTags = [NSMutableSet set];
    
    for (SymbolProperties *properties in self.symbolProperties.allValues) {
        [allTags unionSet:properties.tags];
    }
    
    return [[allTags allObjects] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

#pragma mark - Symbol Operations



- (void)addSymbol:(NSString *)symbol toWatchlist:(NSString *)watchlistName {
    WatchlistData *watchlist = self.watchlists[watchlistName];
    if (!watchlist) return;
    
    NSString *upperSymbol = symbol.uppercaseString;
    if (![watchlist.symbols containsObject:upperSymbol]) {
        [watchlist.symbols addObject:upperSymbol];
        [self saveWatchlist:watchlist];
        
        NSLog(@"WatchlistManager: Added %@ to watchlist '%@'", upperSymbol, watchlistName);
    }
}

- (void)removeSymbol:(NSString *)symbol fromWatchlist:(NSString *)watchlistName {
    WatchlistData *watchlist = self.watchlists[watchlistName];
    if (!watchlist) return;
    
    [watchlist.symbols removeObject:symbol.uppercaseString];
    [self saveWatchlist:watchlist];
    
    NSLog(@"WatchlistManager: Removed %@ from watchlist '%@'", symbol, watchlistName);
}

- (void)addSymbols:(NSArray<NSString *> *)symbols toWatchlist:(NSString *)watchlistName {
    WatchlistData *watchlist = self.watchlists[watchlistName];
    if (!watchlist) return;
    
    for (NSString *symbol in symbols) {
        NSString *upperSymbol = symbol.uppercaseString;
        if (![watchlist.symbols containsObject:upperSymbol]) {
            [watchlist.symbols addObject:upperSymbol];
        }
    }
    
    [self saveWatchlist:watchlist];
    NSLog(@"WatchlistManager: Added %lu symbols to watchlist '%@'", (unsigned long)symbols.count, watchlistName);
}

#pragma mark - Symbol Properties

- (SymbolProperties *)propertiesForSymbol:(NSString *)symbol {
    NSString *upperSymbol = symbol.uppercaseString;
    SymbolProperties *properties = self.symbolProperties[upperSymbol];
    
    if (!properties) {
        properties = [[SymbolProperties alloc] initWithSymbol:upperSymbol];
        self.symbolProperties[upperSymbol] = properties;
    }
    
    return properties;
}

- (void)setColor:(NSColor *)color forSymbol:(NSString *)symbol {
    SymbolProperties *properties = [self propertiesForSymbol:symbol];
    properties.color = color;
    [self saveAllData];
    
    NSLog(@"WatchlistManager: Set color for %@", symbol);
}

- (void)addTag:(NSString *)tag toSymbol:(NSString *)symbol {
    SymbolProperties *properties = [self propertiesForSymbol:symbol];
    [properties.tags addObject:tag];
    [self saveAllData];
    
    // Update dynamic watchlists that might be affected
    [self updateDynamicWatchlists];
    
    NSLog(@"WatchlistManager: Added tag '%@' to %@", tag, symbol);
}

- (void)removeTag:(NSString *)tag fromSymbol:(NSString *)symbol {
    SymbolProperties *properties = [self propertiesForSymbol:symbol];
    [properties.tags removeObject:tag];
    [self saveAllData];
    
    // Update dynamic watchlists that might be affected
    [self updateDynamicWatchlists];
    
    NSLog(@"WatchlistManager: Removed tag '%@' from %@", tag, symbol);
}

- (void)setNote:(NSString *)note forSymbol:(NSString *)symbol {
    SymbolProperties *properties = [self propertiesForSymbol:symbol];
    properties.note = note ?: @"";
    [self saveAllData];
    
    NSLog(@"WatchlistManager: Set note for %@", symbol);
}

#pragma mark - Persistence

- (NSString *)dataFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *applicationSupport = paths.firstObject;
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSString *appDirectory = [applicationSupport stringByAppendingPathComponent:bundleID];
    
    // Create directory if it doesn't exist
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:appDirectory]) {
        NSError *error;
        BOOL created = [fileManager createDirectoryAtPath:appDirectory
                                withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
        if (!created) {
            NSLog(@"Failed to create directory: %@", error.localizedDescription);
        }
    }
    
    // Usa .json invece di .plist
    return [appDirectory stringByAppendingPathComponent:@"watchlists.json"];
}

- (void)saveAllData {
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    
    // Save watchlists
    NSMutableDictionary *watchlistsDict = [NSMutableDictionary dictionary];
    for (NSString *name in self.watchlists) {
        watchlistsDict[name] = [self.watchlists[name] toDictionary];
    }
    data[@"watchlists"] = watchlistsDict;
    
    // Save symbol properties
    NSMutableDictionary *symbolPropsDict = [NSMutableDictionary dictionary];
    for (NSString *symbol in self.symbolProperties) {
        symbolPropsDict[symbol] = [self.symbolProperties[symbol] toDictionary];
    }
    data[@"symbolProperties"] = symbolPropsDict;
    
    // Write to file
    NSString *filePath = [self dataFilePath];
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingPrettyPrinted error:&error];

    if (jsonData) {
        [jsonData writeToFile:filePath atomically:YES];
        NSLog(@"Salvato su disco in: %@", filePath);
    } else {
        NSLog(@"Errore nella serializzazione JSON: %@", error.localizedDescription);
    }
  /*  BOOL success = [data writeToFile:filePath atomically:YES];
    
    if (success) {
        NSLog(@"WatchlistManager: Saved data to %@", filePath);
    } else {
        NSLog(@"WatchlistManager: Failed to save data to %@", filePath);
    }
   */
}

- (void)loadAllData {
    NSString *filePath = [self dataFilePath];
    NSLog(@"Tentativo di caricare da: %@", filePath);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:filePath]) {
        NSLog(@"WatchlistManager: No existing data file found, starting fresh");
        return;
    }
    
    // Leggi il file JSON
    NSData *jsonData = [NSData dataWithContentsOfFile:filePath];
    if (!jsonData) {
        NSLog(@"WatchlistManager: Could not read data file");
        return;
    }
    
    // Deserializza JSON
    NSError *error;
    NSDictionary *data = [NSJSONSerialization JSONObjectWithData:jsonData
                                                         options:NSJSONReadingMutableContainers
                                                           error:&error];
    
    if (!data) {
        NSLog(@"WatchlistManager: Failed to parse JSON: %@", error.localizedDescription);
        return;
    }
    
    // Load watchlists
    NSDictionary *watchlistsDict = data[@"watchlists"];
    if (watchlistsDict) {
        for (NSString *name in watchlistsDict) {
            WatchlistData *watchlist = [[WatchlistData alloc] initWithDictionary:watchlistsDict[name]];
            self.watchlists[name] = watchlist;
        }
    }
    
    // Load symbol properties
    NSDictionary *symbolPropsDict = data[@"symbolProperties"];
    if (symbolPropsDict) {
        for (NSString *symbol in symbolPropsDict) {
            SymbolProperties *properties = [[SymbolProperties alloc] initWithDictionary:symbolPropsDict[symbol]];
            self.symbolProperties[symbol] = properties;
        }
    }
    
    NSLog(@"WatchlistManager: Loaded %lu watchlists and %lu symbol properties from JSON",
          (unsigned long)self.watchlists.count, (unsigned long)self.symbolProperties.count);
    
    // Debug: stampa nomi watchlist caricate
}

@end

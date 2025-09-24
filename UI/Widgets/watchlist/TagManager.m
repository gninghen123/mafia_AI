//
//  TagManager.m
//  TradingApp
//

#import "TagManager.h"
#import "DataHub.h"
#import "Symbol+CoreDataClass.h"

// Notifications
NSString * const TagManagerDidStartBuildingNotification = @"TagManagerDidStartBuilding";
NSString * const TagManagerDidFinishBuildingNotification = @"TagManagerDidFinishBuilding";
NSString * const TagManagerDidUpdateNotification = @"TagManagerDidUpdate";

@interface TagManager ()

// In-memory cache indexes for O(1) access
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *tagToSymbols;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *symbolToTags;

// Ordered arrays for fast enumeration
@property (nonatomic, strong) NSMutableArray<NSString *> *sortedTags;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *sortedSymbolsForTag;

// State management
@property (nonatomic, assign) TagManagerState state;
@property (nonatomic, assign) NSTimeInterval lastBuildTime;
@property (nonatomic, assign) NSUInteger totalSymbolsWithTags;
@property (nonatomic, assign) NSUInteger totalUniqueTags;

// Thread safety
@property (nonatomic, strong) dispatch_queue_t cacheQueue;
@property (nonatomic, assign) BOOL isBuildingInProgress;

@end

@implementation TagManager

#pragma mark - Singleton

+ (instancetype)sharedManager {
    static TagManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[TagManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    // Initialize collections
    self.tagToSymbols = [NSMutableDictionary dictionary];
    self.symbolToTags = [NSMutableDictionary dictionary];
    self.sortedTags = [NSMutableArray array];
    self.sortedSymbolsForTag = [NSMutableDictionary dictionary];
    
    // State
    self.state = TagManagerStateEmpty;
    self.lastBuildTime = 0;
    self.totalSymbolsWithTags = 0;
    self.totalUniqueTags = 0;
    self.isBuildingInProgress = NO;
    
    // Thread safety
    self.cacheQueue = dispatch_queue_create("com.tradingapp.tagmanager", DISPATCH_QUEUE_SERIAL);
    
    // Listen to DataHub notifications for real-time updates
    [self setupNotificationListeners];
    
    NSLog(@"✅ TagManager: Initialized and ready for background building");
}

#pragma mark - Notification Setup

- (void)setupNotificationListeners {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    // Listen to tag add/remove from DataHub
    [center addObserver:self
               selector:@selector(handleTagAddedNotification:)
                   name:@"DataHubSymbolTagAdded"
                 object:nil];
    
    [center addObserver:self
               selector:@selector(handleTagRemovedNotification:)
                   name:@"DataHubSymbolTagRemoved"
                 object:nil];
    
    NSLog(@"✅ TagManager: Notification listeners setup complete");
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Cache Building

- (void)buildCacheInBackground {
    dispatch_async(self.cacheQueue, ^{
        // Prevent multiple simultaneous builds
        if (self.isBuildingInProgress) {
            NSLog(@"⚠️ TagManager: Build already in progress, skipping");
            return;
        }
        
        self.isBuildingInProgress = YES;
        
        // Notify start
        dispatch_async(dispatch_get_main_queue(), ^{
            self.state = TagManagerStateBuilding;
            [[NSNotificationCenter defaultCenter] postNotificationName:TagManagerDidStartBuildingNotification object:self];
        });
        
        NSLog(@"🏗️ TagManager: Starting background cache build...");
        NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
        
        // Build the cache
        BOOL success = [self performCacheBuild];
        
        NSTimeInterval buildDuration = [NSDate timeIntervalSinceReferenceDate] - startTime;
        self.lastBuildTime = buildDuration;
        self.isBuildingInProgress = NO;
        
        // Update state and notify completion
        dispatch_async(dispatch_get_main_queue(), ^{
            self.state = success ? TagManagerStateReady : TagManagerStateError;
            
            if (success) {
                NSLog(@"✅ TagManager: Cache build completed in %.3f seconds", buildDuration);
                NSLog(@"   📊 Statistics: %lu tags, %lu symbols with tags",
                      (unsigned long)self.totalUniqueTags,
                      (unsigned long)self.totalSymbolsWithTags);
            } else {
                NSLog(@"❌ TagManager: Cache build FAILED after %.3f seconds", buildDuration);
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:TagManagerDidFinishBuildingNotification
                                                                object:self
                                                              userInfo:@{@"success": @(success)}];
        });
    });
}

//
//  TagManager.m - VERSIONE OTTIMIZZATA
//  TradingApp
//
//  SOSTITUIRE IL METODO performCacheBuild CON QUESTA VERSIONE


- (BOOL)performCacheBuild {
    @try {
        // Clear existing cache
        [self.tagToSymbols removeAllObjects];
        [self.symbolToTags removeAllObjects];
        [self.sortedTags removeAllObjects];
        [self.sortedSymbolsForTag removeAllObjects];
        
        // ✅ RUNTIME APPROACH: Usa i metodi runtime-friendly di DataHub
        // Niente Core Data objects, solo stringhe e dizionari
        DataHub *dataHub = [DataHub shared];
        
        NSLog(@"🚀 TagManager: Using DataHub runtime methods (no Core Data objects)");
        
        // ✅ GET SYMBOLS WITH TAGS: Usa metodo runtime-friendly
        NSArray<NSDictionary *> *symbolsWithTagsInfo = [dataHub getAllSymbolsWithTagsInfo];
        
        if (!symbolsWithTagsInfo || symbolsWithTagsInfo.count == 0) {
            NSLog(@"⚠️ TagManager: No symbols with tags found");
            self.totalUniqueTags = 0;
            self.totalSymbolsWithTags = 0;
            return YES; // Success but empty
        }
        
        NSLog(@"📊 TagManager: Found %lu symbols with tags (runtime method)",
              (unsigned long)symbolsWithTagsInfo.count);
        
        NSMutableSet<NSString *> *allTagsSet = [NSMutableSet set];
        NSUInteger processedSymbols = 0;
        
        // ✅ PROCESS SYMBOLS: Solo stringhe, niente Core Data objects
        for (NSDictionary *symbolInfo in symbolsWithTagsInfo) {
            NSString *symbolName = symbolInfo[@"symbol"];
            NSArray<NSString *> *symbolTags = symbolInfo[@"tags"];
            
            if (!symbolName || !symbolTags || symbolTags.count == 0) continue;
            
            // Initialize symbol entry
            if (!self.symbolToTags[symbolName]) {
                self.symbolToTags[symbolName] = [NSMutableSet set];
            }
            
            // Process each tag
            for (NSString *tag in symbolTags) {
                if (!tag || ![tag isKindOfClass:[NSString class]] || tag.length == 0) continue;
                
                // Add to all tags set
                [allTagsSet addObject:tag];
                
                // Initialize tag entry if needed
                if (!self.tagToSymbols[tag]) {
                    self.tagToSymbols[tag] = [NSMutableSet set];
                }
                
                // Add bidirectional mapping
                [self.tagToSymbols[tag] addObject:symbolName];
                [self.symbolToTags[symbolName] addObject:tag];
            }
            
            processedSymbols++;
        }
        
        // ✅ CREATE SORTED ARRAYS: Per fast enumeration
        [self.sortedTags addObjectsFromArray:[[allTagsSet allObjects] sortedArrayUsingSelector:@selector(compare:)]];
        
        // ✅ CREATE SORTED SYMBOL ARRAYS: Per ogni tag (già ordinati per lastInteraction)
        for (NSString *tag in self.sortedTags) {
            NSSet<NSString *> *symbolsForTag = self.tagToSymbols[tag];
            
            // Crea array ordinato mantenendo l'ordine di lastInteraction da symbolsWithTagsInfo
            NSMutableArray<NSString *> *sortedSymbolsForTag = [NSMutableArray array];
            for (NSDictionary *symbolInfo in symbolsWithTagsInfo) {
                NSString *symbolName = symbolInfo[@"symbol"];
                if ([symbolsForTag containsObject:symbolName]) {
                    [sortedSymbolsForTag addObject:symbolName];
                }
            }
            
            self.sortedSymbolsForTag[tag] = sortedSymbolsForTag;
        }
        
        // ✅ UPDATE STATISTICS
        self.totalUniqueTags = self.sortedTags.count;
        self.totalSymbolsWithTags = processedSymbols;
        
        NSLog(@"✅ TagManager: RUNTIME-OPTIMIZED cache build successful!");
        NSLog(@"   📊 Processed %lu symbols with tags, found %lu unique tags",
              (unsigned long)processedSymbols, (unsigned long)self.totalUniqueTags);
        NSLog(@"   🚀 Used DataHub runtime methods (no Core Data object exposure)");
        
        return YES;
        
    } @catch (NSException *exception) {
        NSLog(@"❌ TagManager: Cache build exception: %@", exception);
        return NO;
    }
}



- (void)rebuildCacheSync {
    dispatch_sync(self.cacheQueue, ^{
        if (self.isBuildingInProgress) {
            NSLog(@"⚠️ TagManager: Sync rebuild blocked - async build in progress");
            return;
        }
        
        self.isBuildingInProgress = YES;
        NSLog(@"🔄 TagManager: Performing synchronous cache rebuild");
        
        BOOL success = [self performCacheBuild];
        self.state = success ? TagManagerStateReady : TagManagerStateError;
        self.isBuildingInProgress = NO;
        
        NSLog(@"%@ TagManager: Sync rebuild %@", success ? @"✅" : @"❌", success ? @"completed" : @"failed");
    });
}

- (void)invalidateAndRebuild {
    NSLog(@"🔄 TagManager: Cache invalidated - triggering rebuild");
    dispatch_async(self.cacheQueue, ^{
        self.state = TagManagerStateEmpty;
    });
    [self buildCacheInBackground];
}

#pragma mark - Immediate Access (O(1) Performance)

- (NSArray<NSString *> *)allActiveTags {
    if (self.state != TagManagerStateReady) {
        return @[];
    }
    return [self.sortedTags copy];
}

- (NSArray<NSString *> *)symbolsWithTag:(NSString *)tag {
    if (self.state != TagManagerStateReady || !tag) {
        return @[];
    }
    
    NSMutableArray<NSString *> *symbols = self.sortedSymbolsForTag[tag];
    return symbols ? [symbols copy] : @[];
}

- (NSArray<NSString *> *)tagsForSymbol:(NSString *)symbol {
    if (self.state != TagManagerStateReady || !symbol) {
        return @[];
    }
    
    NSSet<NSString *> *tags = self.symbolToTags[symbol];
    if (!tags) return @[];
    
    // Return sorted tags
    return [[tags allObjects] sortedArrayUsingSelector:@selector(compare:)];
}

- (NSUInteger)symbolCountForTag:(NSString *)tag {
    if (self.state != TagManagerStateReady || !tag) {
        return 0;
    }
    
    NSSet<NSString *> *symbols = self.tagToSymbols[tag];
    return symbols ? symbols.count : 0;
}

- (BOOL)tagExists:(NSString *)tag {
    if (self.state != TagManagerStateReady || !tag) {
        return NO;
    }
    return self.tagToSymbols[tag] != nil;
}

- (BOOL)symbol:(NSString *)symbol hasTag:(NSString *)tag {
    if (self.state != TagManagerStateReady || !symbol || !tag) {
        return NO;
    }
    
    NSSet<NSString *> *tags = self.symbolToTags[symbol];
    return [tags containsObject:tag];
}

#pragma mark - Real-time Updates

- (void)handleTagAddedNotification:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    Symbol *symbol = userInfo[@"symbol"];
    NSString *tag = userInfo[@"tag"];
    
    if (symbol.symbol && tag) {
        [self tagAdded:tag toSymbol:symbol.symbol];
    }
}

- (void)handleTagRemovedNotification:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    Symbol *symbol = userInfo[@"symbol"];
    NSString *tag = userInfo[@"tag"];
    
    if (symbol.symbol && tag) {
        [self tagRemoved:tag fromSymbol:symbol.symbol];
    }
}

- (void)tagAdded:(NSString *)tag toSymbol:(NSString *)symbol {
    if (self.state != TagManagerStateReady) return;
    
    dispatch_async(self.cacheQueue, ^{
        NSLog(@"⚡ TagManager: Real-time update - tag '%@' added to '%@'", tag, symbol);
        
        // Initialize collections if needed
        if (!self.tagToSymbols[tag]) {
            self.tagToSymbols[tag] = [NSMutableSet set];
            
            // Add to sorted tags
            NSUInteger insertIndex = [self.sortedTags indexOfObject:tag inSortedRange:NSMakeRange(0, self.sortedTags.count)
                                                             options:NSBinarySearchingInsertionIndex
                                                     usingComparator:^(NSString *tag1, NSString *tag2) {
                return [tag1 compare:tag2];
            }];
            [self.sortedTags insertObject:tag atIndex:insertIndex];
            
            self.sortedSymbolsForTag[tag] = [NSMutableArray array];
            self.totalUniqueTags++;
        }
        
        if (!self.symbolToTags[symbol]) {
            self.symbolToTags[symbol] = [NSMutableSet set];
        }
        
        // Add bidirectional mapping
        [self.tagToSymbols[tag] addObject:symbol];
        [self.symbolToTags[symbol] addObject:tag];
        
        // Add to sorted symbols for tag (insert at beginning for most recent)
        NSMutableArray<NSString *> *sortedSymbols = self.sortedSymbolsForTag[tag];
        if (![sortedSymbols containsObject:symbol]) {
            [sortedSymbols insertObject:symbol atIndex:0];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:TagManagerDidUpdateNotification
                                                                object:self
                                                              userInfo:@{@"action": @"added", @"tag": tag, @"symbol": symbol}];
        });
    });
}

- (void)tagRemoved:(NSString *)tag fromSymbol:(NSString *)symbol {
    if (self.state != TagManagerStateReady) return;
    
    dispatch_async(self.cacheQueue, ^{
        NSLog(@"⚡ TagManager: Real-time update - tag '%@' removed from '%@'", tag, symbol);
        
        // Remove bidirectional mapping
        [self.tagToSymbols[tag] removeObject:symbol];
        [self.symbolToTags[symbol] removeObject:tag];
        
        // Remove from sorted symbols
        [self.sortedSymbolsForTag[tag] removeObject:symbol];
        
        // Clean up empty tag
        if (self.tagToSymbols[tag].count == 0) {
            [self.tagToSymbols removeObjectForKey:tag];
            [self.sortedTags removeObject:tag];
            [self.sortedSymbolsForTag removeObjectForKey:tag];
            self.totalUniqueTags--;
        }
        
        // Clean up empty symbol
        if (self.symbolToTags[symbol].count == 0) {
            [self.symbolToTags removeObjectForKey:symbol];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:TagManagerDidUpdateNotification
                                                                object:self
                                                              userInfo:@{@"action": @"removed", @"tag": tag, @"symbol": symbol}];
        });
    });
}

- (void)symbolDeleted:(NSString *)symbol {
    if (self.state != TagManagerStateReady) return;
    
    dispatch_async(self.cacheQueue, ^{
        NSLog(@"⚡ TagManager: Real-time update - symbol '%@' deleted", symbol);
        
        NSSet<NSString *> *tagsForSymbol = [self.symbolToTags[symbol] copy];
        
        for (NSString *tag in tagsForSymbol) {
            [self tagRemoved:tag fromSymbol:symbol];
        }
    });
}

#pragma mark - Debugging & Statistics

- (NSString *)cacheStatistics {
    return [NSString stringWithFormat:@"TagManager Statistics:\n"
            @"  State: %@\n"
            @"  Unique Tags: %lu\n"
            @"  Symbols with Tags: %lu\n"
            @"  Build Time: %.3f seconds\n"
            @"  Memory Usage: ~%.1f KB",
            [self stateDescription],
            (unsigned long)self.totalUniqueTags,
            (unsigned long)self.totalSymbolsWithTags,
            self.lastBuildTime,
            (self.tagToSymbols.count * 64 + self.symbolToTags.count * 64) / 1024.0];
}

- (NSString *)stateDescription {
    switch (self.state) {
        case TagManagerStateEmpty: return @"Empty";
        case TagManagerStateBuilding: return @"Building";
        case TagManagerStateReady: return @"Ready";
        case TagManagerStateError: return @"Error";
        default: return @"Unknown";
    }
}

- (void)logCurrentState {
    NSLog(@"\n🏷️ TagManager Current State:");
    NSLog(@"   %@", [self cacheStatistics]);
    NSLog(@"   Sample Tags: %@", [[self.sortedTags subarrayWithRange:NSMakeRange(0, MIN(5, self.sortedTags.count))] componentsJoinedByString:@", "]);
}

@end

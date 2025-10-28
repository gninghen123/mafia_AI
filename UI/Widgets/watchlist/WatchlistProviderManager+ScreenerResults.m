//
//  WatchlistProviderManager+ScreenerResults.m
//  TradingApp
//
//  Extension to load Stooq Screener archived results
//

#import "WatchlistProviderManager+ScreenerResults.h"
#import "StooqScreenerArchiveProvider.h"
#import "ExecutionSession.h"
#import "ScreenerModel.h"

// ✅ Private flag per tracking dello stato di caricamento
static BOOL _screenerProvidersLoaded = NO;

@implementation WatchlistProviderManager (ScreenerResults)

#pragma mark - Public Methods

- (void)loadScreenerResultProviders {
    
    // ✅ FIX: Evita caricamenti duplicati
    if (_screenerProvidersLoaded) {
        NSLog(@"⚠️ Screener providers already loaded, skipping");
        return;
    }
    
    // ✅ SETTA IL FLAG SUBITO
    _screenerProvidersLoaded = YES;
    
    // Get most recent session file
    NSString *sessionFile = [self findMostRecentSessionFile];
    
    if (!sessionFile) {
        NSLog(@"⚠️ No recent screener sessions found (last 7 days)");
        [self clearScreenerProviders];
        return;
    }
    
    // Load session from file
    NSError *error;
    ExecutionSession *session = [ExecutionSession loadFromFile:sessionFile error:&error];
    
    if (!session) {
        NSLog(@"❌ Failed to load session from %@: %@", sessionFile, error);
        [self clearScreenerProviders];
        return;
    }
    
    
    // Clear existing screener providers
    [self clearScreenerProviders];
    // ✅ RESETTA IL FLAG DOPO LA CLEAR (clearScreenerProviders lo resetta)
    _screenerProvidersLoaded = YES;
    
    
    // Create provider for each ModelResult
    for (ModelResult *modelResult in session.modelResults) {
        
        StooqScreenerArchiveProvider *provider =
            [[StooqScreenerArchiveProvider alloc] initWithModelResult:modelResult
                                                        executionDate:session.executionDate];
        
        
        [self addScreenerProvider:provider];
        
        NSLog(@"   📈 Added provider: %@ (%lu symbols)",
              provider.displayName,
              (unsigned long)provider.symbols.count);
    }
    
}

- (void)loadScreenerResultProvidersAsync {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self loadScreenerResultProviders];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"✅ Async screener provider loading complete");
            
            // ✅ FIX: Posta notifica per aggiornare la UI
            [[NSNotificationCenter defaultCenter] postNotificationName:@"ScreenerProvidersDidLoad"
                                                                object:self
                                                              userInfo:@{@"count": @([self screenerProviderCount])}];
        });
    });
}

#pragma mark - Reset (chiamare da refreshAllProviders)

+ (void)resetScreenerProvidersState {
    _screenerProvidersLoaded = NO;
}

#pragma mark - File System

- (NSString *)screenerArchiveDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                         NSUserDomainMask, YES);
    NSString *appSupportDir = paths[0];
    NSString *appDir = [appSupportDir stringByAppendingPathComponent:@"TradingApp"];
    return [appDir stringByAppendingPathComponent:@"ScreenerArchive"];
}

- (nullable NSString *)findMostRecentSessionFile {
    NSString *archiveDir = [self screenerArchiveDirectory];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:archiveDir]) {
        NSLog(@"📦 Screener archive directory doesn't exist: %@", archiveDir);
        return nil;
    }
    
    NSError *error;
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:archiveDir error:&error];
    
    if (error) {
        NSLog(@"❌ Error reading archive directory: %@", error);
        return nil;
    }
    
    // Filter to session JSON files
    NSMutableArray<NSString *> *sessionFiles = [NSMutableArray array];
    for (NSString *filename in files) {
        if ([filename hasPrefix:@"session_"] && [filename hasSuffix:@".json"]) {
            [sessionFiles addObject:filename];
        }
    }
    
    if (sessionFiles.count == 0) {
        NSLog(@"📦 No session files found in archive");
        return nil;
    }
    
    // Sort by filename (which contains date) - most recent first
    [sessionFiles sortUsingComparator:^NSComparisonResult(NSString *file1, NSString *file2) {
        return [file2 compare:file1]; // Descending order
    }];
    
    // Check if most recent is within last 7 days
    NSString *mostRecentFile = sessionFiles.firstObject;
    NSString *fullPath = [archiveDir stringByAppendingPathComponent:mostRecentFile];
    
    // Get file modification date
    NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
    NSDate *modDate = attrs[NSFileModificationDate];
    
    if (modDate) {
        NSTimeInterval age = [[NSDate date] timeIntervalSinceDate:modDate];
        NSTimeInterval sevenDays = 7 * 24 * 60 * 60;
        
        if (age > sevenDays) {
            NSLog(@"📦 Most recent session is older than 7 days: %@", mostRecentFile);
            return nil;
        }
    }
    
    NSLog(@"📦 Found most recent session: %@", mostRecentFile);
    return fullPath;
}

#pragma mark - Private Helper Methods

// These methods assume that the base WatchlistProviderManager has been extended
// with a mutableScreenerProviders array (similar to other provider arrays)

- (void)clearScreenerProviders {
    // Access the mutable array via KVC if not directly accessible
    NSMutableArray *providers = [self valueForKey:@"mutableScreenerProviders"];
    if (providers) {
        // ✅ FIX: Crea copia per evitare mutazione durante enumerazione
        NSArray *providersCopy = [providers copy];
        
        // Remove from cache
        NSMutableDictionary *cache = [self valueForKey:@"providerCache"];
        for (id<WatchlistProvider> provider in providersCopy) {
            [cache removeObjectForKey:provider.providerId];
        }
        
        // Clear array
        [providers removeAllObjects];
    }
    
    // ✅ Reset flag
    _screenerProvidersLoaded = NO;
}

- (void)addScreenerProvider:(StooqScreenerArchiveProvider *)provider {
    NSMutableArray *providers = [self valueForKey:@"mutableScreenerProviders"];
    if (providers) {
        [providers addObject:provider];
        
        // Add to cache
        NSMutableDictionary *cache = [self valueForKey:@"providerCache"];
        cache[provider.providerId] = provider;
    }
}

- (NSUInteger)screenerProviderCount {
    NSMutableArray *providers = [self valueForKey:@"mutableScreenerProviders"];
    return providers ? providers.count : 0;
}

@end

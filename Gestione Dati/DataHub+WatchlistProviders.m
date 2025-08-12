//
//  DataHub+WatchlistProviders.m
//  TradingApp
//
//  Extensions to DataHub to support the new unified WatchlistWidget provider system
//

#import "DataHub+WatchlistProviders.h"
#import "Symbol+CoreDataClass.h"
#import "Symbol+CoreDataProperties.h"
#import "Watchlist+CoreDataClass.h"
#import "Watchlist+CoreDataProperties.h"

@interface DataHub (PrivateArchiveMethods)
- (Watchlist *)findWatchlistByName:(NSString *)name;
- (Symbol *)createSymbolWithName:(NSString *)symbolName;
- (Symbol *)getSymbolWithName:(NSString *)symbolName;
- (void)saveContext;
- (NSMutableArray *)watchlists;
- (NSManagedObjectContext *)mainContext;
@end

@implementation DataHub (WatchlistProviders)

#pragma mark - Tag-Based Symbol Discovery

- (void)getSymbolsWithTag:(NSString *)tag
               completion:(void(^)(NSArray<NSString *> *symbols))completion {
    
    if (!tag || tag.length == 0) {
        if (completion) completion(@[]);
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray<NSString *> *matchingSymbols = [NSMutableArray array];
        
        NSFetchRequest *request = [Symbol fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"tags CONTAINS %@", tag];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"lastInteraction" ascending:NO]];
        
        NSError *error = nil;
        NSArray<Symbol *> *symbols = [self.mainContext executeFetchRequest:request error:&error];
        
        if (error) {
            NSLog(@"❌ Error fetching symbols with tag '%@': %@", tag, error);
        } else {
            for (Symbol *symbol in symbols) {
                if (symbol.symbol && symbol.symbol.length > 0) {
                    [matchingSymbols addObject:symbol.symbol];
                }
            }
            NSLog(@"✅ Found %lu symbols with tag '%@'", (unsigned long)matchingSymbols.count, tag);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion([matchingSymbols copy]);
        });
    });
}

- (void)discoverAllActiveTagsWithCompletion:(void(^)(NSArray<NSString *> *tags))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableSet<NSString *> *allTags = [NSMutableSet set];
        
        // ✅ FIX: Fetch tutti i Symbol con tags != NULL (senza @count)
        NSFetchRequest *request = [Symbol fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"tags != NULL"];
        
        NSError *error = nil;
        NSArray<Symbol *> *symbols = [self.mainContext executeFetchRequest:request error:&error];
        
        if (error) {
            NSLog(@"❌ Error discovering tags: %@", error);
        } else {
            for (Symbol *symbol in symbols) {
                if (symbol.tags && [symbol.tags isKindOfClass:[NSArray class]] && symbol.tags.count > 0) {
                    for (NSString *tag in symbol.tags) {
                        if ([tag isKindOfClass:[NSString class]] && tag.length > 0) {
                            [allTags addObject:tag];
                        }
                    }
                }
            }
            NSLog(@"✅ Discovered %lu unique tags from %lu symbols", (unsigned long)allTags.count, (unsigned long)symbols.count);
        }
        
        // Sort tags alphabetically
        NSArray<NSString *> *sortedTags = [[allTags allObjects] sortedArrayUsingSelector:@selector(compare:)];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(sortedTags);
        });
    });
}

- (void)getSymbolsWithAnyOfTags:(NSArray<NSString *> *)tags
                     completion:(void(^)(NSArray<NSString *> *symbols))completion {
    
    if (!tags || tags.count == 0) {
        if (completion) completion(@[]);
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableSet<NSString *> *matchingSymbols = [NSMutableSet set];
        
        for (NSString *tag in tags) {
            NSFetchRequest *request = [Symbol fetchRequest];
            request.predicate = [NSPredicate predicateWithFormat:@"tags CONTAINS %@", tag];
            
            NSError *error = nil;
            NSArray<Symbol *> *symbols = [self.mainContext executeFetchRequest:request error:&error];
            
            if (!error) {
                for (Symbol *symbol in symbols) {
                    if (symbol.symbol && symbol.symbol.length > 0) {
                        [matchingSymbols addObject:symbol.symbol];
                    }
                }
            }
        }
        
        // Sort by symbol name
        NSArray<NSString *> *sortedSymbols = [[matchingSymbols allObjects] sortedArrayUsingSelector:@selector(compare:)];
        
        NSLog(@"✅ Found %lu symbols with any of tags: %@", (unsigned long)sortedSymbols.count, tags);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(sortedSymbols);
        });
    });
}

#pragma mark - Interaction-Based Baskets

- (void)getSymbolsWithInteractionInLastDays:(NSInteger)days
                                 completion:(void(^)(NSArray<NSString *> *symbols))completion {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray<NSString *> *interactionSymbols = [NSMutableArray array];
        
        // Calculate cutoff date
        NSDate *cutoffDate = [[NSDate date] dateByAddingTimeInterval:-(days * 24 * 60 * 60)];
        
        NSFetchRequest *request = [Symbol fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"lastInteraction >= %@", cutoffDate];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"lastInteraction" ascending:NO]];
        
        NSError *error = nil;
        NSArray<Symbol *> *symbols = [self.mainContext executeFetchRequest:request error:&error];
        
        if (error) {
            NSLog(@"❌ Error fetching symbols with interactions in last %ld days: %@", (long)days, error);
        } else {
            for (Symbol *symbol in symbols) {
                if (symbol.symbol && symbol.symbol.length > 0) {
                    [interactionSymbols addObject:symbol.symbol];
                }
            }
            NSLog(@"✅ Found %lu symbols with interactions in last %ld days",
                  (unsigned long)interactionSymbols.count, (long)days);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion([interactionSymbols copy]);
        });
    });
}

- (void)getTodayInteractionSymbolsWithCompletion:(void(^)(NSArray<NSString *> *symbols))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray<NSString *> *todaySymbols = [NSMutableArray array];
        
        // Get start of today
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDate *startOfToday = [calendar startOfDayForDate:[NSDate date]];
        
        NSFetchRequest *request = [Symbol fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"lastInteraction >= %@", startOfToday];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"lastInteraction" ascending:NO]];
        
        NSError *error = nil;
        NSArray<Symbol *> *symbols = [self.mainContext executeFetchRequest:request error:&error];
        
        if (error) {
            NSLog(@"❌ Error fetching today's interaction symbols: %@", error);
        } else {
            for (Symbol *symbol in symbols) {
                if (symbol.symbol && symbol.symbol.length > 0) {
                    [todaySymbols addObject:symbol.symbol];
                }
            }
            NSLog(@"✅ Found %lu symbols with interactions today", (unsigned long)todaySymbols.count);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion([todaySymbols copy]);
        });
    });
}

- (void)updateLastInteractionForSymbol:(NSString *)symbol {
    if (!symbol || symbol.length == 0) return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Create context for background work
        NSManagedObjectContext *backgroundContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        backgroundContext.parentContext = self.mainContext;
        
        [backgroundContext performBlock:^{
            // Find or create symbol
            NSFetchRequest *request = [Symbol fetchRequest];
            request.predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
            
            NSError *error = nil;
            NSArray<Symbol *> *symbols = [backgroundContext executeFetchRequest:request error:&error];
            
            Symbol *symbolEntity = symbols.firstObject;
            if (!symbolEntity) {
                // Create new symbol if it doesn't exist
                symbolEntity = [NSEntityDescription insertNewObjectForEntityForName:@"Symbol"
                                                             inManagedObjectContext:backgroundContext];
                symbolEntity.symbol = symbol;
                symbolEntity.creationDate = [NSDate date];
            }
            
            // Update interaction timestamp
            symbolEntity.lastInteraction = [NSDate date];
            
            // Save background context
            NSError *saveError = nil;
            if ([backgroundContext save:&saveError]) {
                // Save parent context on main thread
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self saveContext];
                });
            } else {
                NSLog(@"❌ Error updating last interaction for %@: %@", symbol, saveError);
            }
        }];
    });
}

#pragma mark - Archive Management

- (void)archiveBasketSymbols:(NSArray<NSString *> *)symbols
                     forDate:(NSString *)date
                  completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    
    if (!symbols || symbols.count == 0) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"DataHubArchive"
                                                 code:1001
                                             userInfo:@{NSLocalizedDescriptionKey: @"No symbols to archive"}];
            completion(NO, error);
        }
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        BOOL success = NO;
        
        // Crea la struttura delle directory
        NSString *archivePath = [self createArchiveDirectoryForDate:date error:&error];
        if (!archivePath) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, error);
            });
            return;
        }
        
        // Crea il file di archivio
        NSString *fileName = [NSString stringWithFormat:@"%@.plist", date];
        NSString *filePath = [archivePath stringByAppendingPathComponent:fileName];
        
        // Prepara i dati da archiviare
        NSDictionary *archiveData = @{
            @"date": date,
            @"symbols": symbols,
            @"symbolCount": @(symbols.count),
            @"createdAt": [NSDate date],
            @"version": @"1.0"
        };
        
        // Salva come binary plist
        NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:archiveData
                                                                        format:NSPropertyListBinaryFormat_v1_0
                                                                       options:0
                                                                         error:&error];
        
        if (plistData) {
            success = [plistData writeToFile:filePath atomically:YES];
            if (!success) {
                error = [NSError errorWithDomain:@"DataHubArchive"
                                            code:1002
                                        userInfo:@{NSLocalizedDescriptionKey: @"Failed to write archive file"}];
            } else {
                NSLog(@"✅ Archived %lu symbols to: %@", (unsigned long)symbols.count, filePath);
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(success, error);
        });
    });
}


- (void)loadArchivedBasketWithKey:(NSString *)archiveKey
                       completion:(void(^)(NSArray<NSString *> * _Nullable symbols, NSError * _Nullable error))completion {
    
    if (!archiveKey || archiveKey.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataHub" code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid archive key"}];
        if (completion) completion(nil, error);
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Parse archive key (format: "YYYY-QX/YYYY-MM-DD")
        NSArray<NSString *> *components = [archiveKey componentsSeparatedByString:@"/"];
        if (components.count != 2) {
            NSError *error = [NSError errorWithDomain:@"DataHub" code:400
                                             userInfo:@{NSLocalizedDescriptionKey: @"Invalid archive key format"}];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error);
            });
            return;
        }
        
        NSString *quarter = components[0];
        NSString *date = components[1];
        
        // Build file path
        NSArray<NSString *> *libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *libraryPath = libraryPaths.firstObject;
        NSString *archiveBasePath = [libraryPath stringByAppendingPathComponent:@"Application Support/TradingApp/Archives"];
        NSString *quarterPath = [archiveBasePath stringByAppendingPathComponent:quarter];
        NSString *archiveFileName = [NSString stringWithFormat:@"%@.plist", date];
        NSString *archiveFilePath = [quarterPath stringByAppendingPathComponent:archiveFileName];
        
        // Check if file exists
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:archiveFilePath]) {
            NSError *error = [NSError errorWithDomain:@"DataHub" code:404
                                             userInfo:@{NSLocalizedDescriptionKey: @"Archive file not found"}];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error);
            });
            return;
        }
        
        // Load plist data
        NSDictionary *archiveData = [NSDictionary dictionaryWithContentsOfFile:archiveFilePath];
        if (!archiveData) {
            NSError *error = [NSError errorWithDomain:@"DataHub" code:500
                                             userInfo:@{NSLocalizedDescriptionKey: @"Failed to read archive file"}];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error);
            });
            return;
        }
        
        // Extract symbols array
        NSArray<NSString *> *symbols = archiveData[@"symbols"];
        if (![symbols isKindOfClass:[NSArray class]]) {
            NSError *error = [NSError errorWithDomain:@"DataHub" code:500
                                             userInfo:@{NSLocalizedDescriptionKey: @"Invalid archive data format"}];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error);
            });
            return;
        }
        
        NSLog(@"✅ DataHub: Loaded archived basket for %@ with %lu symbols",
              archiveKey, (unsigned long)symbols.count);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(symbols, nil);
        });
    });
}

- (void)discoverAvailableArchivesWithCompletion:(void(^)(NSArray<NSString *> *archiveKeys))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray<NSString *> *archiveKeys = [NSMutableArray array];
        
        // Get archive base directory
        NSArray<NSString *> *libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *libraryPath = libraryPaths.firstObject;
        NSString *archiveBasePath = [libraryPath stringByAppendingPathComponent:@"Application Support/TradingApp/Archives"];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        
        // Get quarter directories
        NSArray<NSString *> *quarterDirs = [fileManager contentsOfDirectoryAtPath:archiveBasePath error:&error];
        if (error) {
            NSLog(@"⚠️ No archive directory found or error reading: %@", error);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(@[]);
            });
            return;
        }
        
        for (NSString *quarterDir in quarterDirs) {
            // Skip hidden files and non-quarter directories
            if ([quarterDir hasPrefix:@"."] || ![quarterDir containsString:@"-Q"]) continue;
            
            NSString *quarterPath = [archiveBasePath stringByAppendingPathComponent:quarterDir];
            
            // Get plist files in quarter directory
            NSArray<NSString *> *files = [fileManager contentsOfDirectoryAtPath:quarterPath error:nil];
            for (NSString *file in files) {
                if ([file hasSuffix:@".plist"]) {
                    // Remove .plist extension to get date
                    NSString *date = [file stringByDeletingPathExtension];
                    NSString *archiveKey = [NSString stringWithFormat:@"%@/%@", quarterDir, date];
                    [archiveKeys addObject:archiveKey];
                }
            }
        }
        
        // Sort archive keys in descending order (newest first)
        NSArray<NSString *> *sortedKeys = [archiveKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *key1, NSString *key2) {
            return [key2 compare:key1]; // Reverse order for newest first
        }];
        
        NSLog(@"✅ DataHub: Discovered %lu archives", (unsigned long)sortedKeys.count);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(sortedKeys);
        });
    });
}

- (void)performAutomaticBasketArchiving {
    NSLog(@"🔄 DataHub: Starting automatic basket archiving");
    
    // Get symbols that were interacted with more than 30 days ago but haven't been archived
    NSDate *cutoffDate = [[NSDate date] dateByAddingTimeInterval:-(30 * 24 * 60 * 60)];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFetchRequest *request = [Symbol fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"lastInteraction < %@ AND lastInteraction != NULL", cutoffDate];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"lastInteraction" ascending:NO]];
        
        NSError *error = nil;
        NSArray<Symbol *> *oldSymbols = [self.mainContext executeFetchRequest:request error:&error];
        
        if (error) {
            NSLog(@"❌ Error fetching old symbols for archiving: %@", error);
            return;
        }
        
        // Group symbols by date
        NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *symbolsByDate = [NSMutableDictionary dictionary];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = @"yyyy-MM-dd";
        
        for (Symbol *symbol in oldSymbols) {
            if (symbol.lastInteraction && symbol.symbol) {
                NSString *dateKey = [dateFormatter stringFromDate:symbol.lastInteraction];
                
                if (!symbolsByDate[dateKey]) {
                    symbolsByDate[dateKey] = [NSMutableArray array];
                }
                [symbolsByDate[dateKey] addObject:symbol.symbol];
            }
        }
        
        // Archive each date group
        dispatch_group_t archiveGroup = dispatch_group_create();
        
        for (NSString *dateKey in symbolsByDate.allKeys) {
            NSArray<NSString *> *dateSymbols = symbolsByDate[dateKey];
            
            dispatch_group_enter(archiveGroup);
            [self archiveBasketSymbols:dateSymbols
                               forDate:dateKey
                            completion:^(BOOL success, NSError *error) {
                if (success) {
                    NSLog(@"✅ Archived %lu symbols for %@", (unsigned long)dateSymbols.count, dateKey);
                } else {
                    NSLog(@"❌ Failed to archive symbols for %@: %@", dateKey, error);
                }
                dispatch_group_leave(archiveGroup);
            }];
        }
        
        // Wait for all archives to complete
        dispatch_group_notify(archiveGroup, dispatch_get_main_queue(), ^{
            NSLog(@"✅ Automatic basket archiving completed for %lu dates", (unsigned long)symbolsByDate.count);
        });
    });
}

#pragma mark - Smart Symbol Discovery

- (void)getRecentlyAddedSymbolsInLastDays:(NSInteger)days
                               completion:(void(^)(NSArray<NSString *> *symbols))completion {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray<NSString *> *recentSymbols = [NSMutableArray array];
        
        // Calculate cutoff date
        NSDate *cutoffDate = [[NSDate date] dateByAddingTimeInterval:-(days * 24 * 60 * 60)];
        
        NSFetchRequest *request = [Symbol fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"creationDate >= %@", cutoffDate];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
        
        NSError *error = nil;
        NSArray<Symbol *> *symbols = [self.mainContext executeFetchRequest:request error:&error];
        
        if (error) {
            NSLog(@"❌ Error fetching recently added symbols: %@", error);
        } else {
            for (Symbol *symbol in symbols) {
                if (symbol.symbol && symbol.symbol.length > 0) {
                    [recentSymbols addObject:symbol.symbol];
                }
            }
            NSLog(@"✅ Found %lu recently added symbols in last %ld days",
                  (unsigned long)recentSymbols.count, (long)days);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion([recentSymbols copy]);
        });
    });
}

- (void)getMostFrequentlyUsedSymbols:(NSInteger)limit
                          completion:(void(^)(NSArray<NSString *> *symbols))completion {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray<NSString *> *frequentSymbols = [NSMutableArray array];
        
        NSFetchRequest *request = [Symbol fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"interactionCount > 0"];
        request.sortDescriptors = @[
            [NSSortDescriptor sortDescriptorWithKey:@"interactionCount" ascending:NO],
            [NSSortDescriptor sortDescriptorWithKey:@"lastInteraction" ascending:NO]
        ];
        request.fetchLimit = limit;
        
        NSError *error = nil;
        NSArray<Symbol *> *symbols = [self.mainContext executeFetchRequest:request error:&error];
        
        if (error) {
            NSLog(@"❌ Error fetching frequently used symbols: %@", error);
        } else {
            for (Symbol *symbol in symbols) {
                if (symbol.symbol && symbol.symbol.length > 0) {
                    [frequentSymbols addObject:symbol.symbol];
                }
            }
            NSLog(@"✅ Found %lu most frequently used symbols", (unsigned long)frequentSymbols.count);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion([frequentSymbols copy]);
        });
    });
}

#pragma mark - Daily Archive Management

- (void)ensureTodayArchiveExists {
    NSString *today = [self todayDateString];
    NSString *archiveName = [NSString stringWithFormat:@"Archive-%@", today];
    
    // Controlla se esiste già
    Watchlist *existingArchive = [self findWatchlistByName:archiveName];
    if (existingArchive) {
        return; // Già esiste
    }
    
    // Crea nuovo archivio giornaliero
    Watchlist *todayArchive = [NSEntityDescription insertNewObjectForEntityForName:@"Watchlist"
                                                            inManagedObjectContext:self.mainContext];
    todayArchive.name = archiveName;
    todayArchive.creationDate = [NSDate date];
    todayArchive.lastModified = [NSDate date];
    todayArchive.colorHex = @"#007AFF"; // Blu per archivi
    todayArchive.sortOrder = 9999; // In fondo alla lista
    
    [self saveContext];
    
    // Aggiungi alla cache interna
    if (![self.watchlists containsObject:todayArchive]) {
        [self.watchlists addObject:todayArchive];
    }
    
    NSLog(@"✅ Created today's archive: %@", archiveName);
}

- (void)addSymbolToTodayArchive:(NSString *)symbolName {
    if (!symbolName || symbolName.length == 0) return;
    
    [self ensureTodayArchiveExists];
    
    NSString *today = [self todayDateString];
    NSString *archiveName = [NSString stringWithFormat:@"Archive-%@", today];
    
    Watchlist *todayArchive = [self findWatchlistByName:archiveName];
    if (!todayArchive) {
        NSLog(@"❌ Today's archive not found: %@", archiveName);
        return;
    }
    
    // Controlla se il simbolo è già nell'archivio
    if ([todayArchive containsSymbolWithName:symbolName]) {
        return; // Già presente
    }
    
    // Aggiungi simbolo all'archivio
    [todayArchive addSymbolWithName:symbolName context:self.mainContext];
    [self saveContext];
    
    NSLog(@"📅 Added %@ to today's archive", symbolName.uppercaseString);
}

#pragma mark - Archive Discovery and Cleanup

- (void)performCatchUpArchiving {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *lastArchiveCheck = [defaults stringForKey:@"LastArchiveCheck"];
    NSString *today = [self todayDateString];
    
    NSLog(@"🔄 Starting catch-up archiving...");
    NSLog(@"   Last check: %@", lastArchiveCheck ?: @"Never");
    NSLog(@"   Today: %@", today);
    
    if (!lastArchiveCheck) {
        // Prima volta - archivia solo oggi se ha attività
        [self archiveDayIfHasActivity:today];
        [defaults setObject:today forKey:@"LastArchiveCheck"];        return;
    }
    
    if ([lastArchiveCheck isEqualToString:today]) {
        NSLog(@"✅ Archive check already done today");
        return;
    }
    
    // Trova giorni da archiviare
    NSArray<NSString *> *missingDays = [self daysBetween:lastArchiveCheck and:today];
    
    NSLog(@"📅 Found %lu missing days to archive", (unsigned long)missingDays.count);
    
    for (NSString *dayString in missingDays) {
        [self archiveDayIfHasActivity:dayString];
    }
    
    // Esegui cleanup degli archivi vecchi
    [self performArchiveCleanupIfNeeded];
    
    // Aggiorna timestamp
    [defaults setObject:today forKey:@"LastArchiveCheck"];
    NSLog(@"✅ Catch-up archiving completed");
}

- (void)archiveDayIfHasActivity:(NSString *)dateString {
    NSDate *date = [self dateFromString:dateString];
    if (!date) return;
    
    // Ottieni simboli attivi per quella data
    NSArray<NSString *> *activeSymbols = [self getSymbolsForSpecificDate:date];
    
    if (activeSymbols.count == 0) {
        NSLog(@"📅 No activity on %@ - skipping archive", dateString);
        return;
    }
    
    // Crea/aggiorna archivio Core Data per quella data
    NSString *archiveName = [NSString stringWithFormat:@"Archive-%@", dateString];
    Watchlist *dayArchive = [self findWatchlistByName:archiveName];
    
    if (!dayArchive) {
        // Crea nuovo archivio
        dayArchive = [NSEntityDescription insertNewObjectForEntityForName:@"Watchlist"
                                                   inManagedObjectContext:self.mainContext];
        dayArchive.name = archiveName;
        dayArchive.creationDate = date;
        dayArchive.lastModified = [NSDate date];
        dayArchive.colorHex = @"#007AFF";
        dayArchive.sortOrder = 9999;
        
        [self.watchlists addObject:dayArchive];
    }
    
    // Aggiungi simboli all'archivio
    for (NSString *symbolName in activeSymbols) {
        if (![dayArchive containsSymbolWithName:symbolName]) {
            [dayArchive addSymbolWithName:symbolName context:self.mainContext];
        }
    }
    
    [self saveContext];
    
    NSLog(@"📅 Archived %lu symbols for %@", (unsigned long)activeSymbols.count, dateString);
}

- (void)performArchiveCleanupIfNeeded {
    NSLog(@"🧹 Starting archive cleanup...");
    
    // Trova archivi più vecchi di 30 giorni
    NSDate *cutoffDate = [[NSDate date] dateByAddingTimeInterval:-(30 * 24 * 60 * 60)];
    NSMutableArray<Watchlist *> *archivesToMigrate = [NSMutableArray array];
    
    for (Watchlist *watchlist in self.watchlists) {
        if ([watchlist.name hasPrefix:@"Archive-"] && watchlist.creationDate) {
            if ([watchlist.creationDate compare:cutoffDate] == NSOrderedAscending) {
                [archivesToMigrate addObject:watchlist];
            }
        }
    }
    
    NSLog(@"🗄️ Found %lu archives to migrate to disk", (unsigned long)archivesToMigrate.count);
    
    for (Watchlist *archive in archivesToMigrate) {
        [self migrateArchiveToDisk:archive];
    }
    
    NSLog(@"✅ Archive cleanup completed");
}

- (void)migrateArchiveToDisk:(Watchlist *)archive {
    if (!archive || ![archive.name hasPrefix:@"Archive-"]) return;
    
    // Estrai la data dal nome (Archive-2024-01-15)
    NSString *dateString = [archive.name substringFromIndex:8]; // Rimuovi "Archive-"
    
    // Ottieni simboli dall'archivio
    NSArray<NSString *> *symbols = [archive sortedSymbolNames];
    
    if (symbols.count == 0) {
        NSLog(@"📦 Archive %@ is empty - removing from Core Data", archive.name);
        [self.watchlists removeObject:archive];
        [self.mainContext deleteObject:archive];
        [self saveContext];
        return;
    }
    
    // Archivia su disco
    [self archiveBasketSymbols:symbols
                       forDate:dateString
                    completion:^(BOOL success, NSError *error) {
        if (success) {
            NSLog(@"📦 Successfully migrated %@ to disk with %lu symbols", archive.name, (unsigned long)symbols.count);
            
            // Rimuovi da Core Data
            [self.watchlists removeObject:archive];
            [self.mainContext deleteObject:archive];
            [self saveContext];
        } else {
            NSLog(@"❌ Failed to migrate %@ to disk: %@", archive.name, error.localizedDescription);
        }
    }];
}


- (NSString *)todayDateString {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd";
    return [formatter stringFromDate:[NSDate date]];
}

- (NSDate *)dateFromString:(NSString *)dateString {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd";
    return [formatter dateFromString:dateString];
}

- (NSArray<NSString *> *)daysBetween:(NSString *)startDateString and:(NSString *)endDateString {
    NSDate *startDate = [self dateFromString:startDateString];
    NSDate *endDate = [self dateFromString:endDateString];
    
    if (!startDate || !endDate) return @[];
    
    NSMutableArray<NSString *> *days = [NSMutableArray array];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd";
    
    NSDate *currentDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:startDate options:0];
    
    while ([currentDate compare:endDate] != NSOrderedDescending) {
        // Includi solo giorni lavorativi (lunedì-venerdì)
        NSInteger weekday = [calendar component:NSCalendarUnitWeekday fromDate:currentDate];
        if (weekday >= 2 && weekday <= 6) { // 2=lunedì, 6=venerdì
            [days addObject:[formatter stringFromDate:currentDate]];
        }
        
        currentDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:currentDate options:0];
    }
    
    return [days copy];
}

- (NSArray<NSString *> *)getSymbolsForSpecificDate:(NSDate *)date {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *startOfDay = [calendar startOfDayForDate:date];
    NSDate *endOfDay = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:startOfDay options:0];
    
    NSFetchRequest *request = [Symbol fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"lastInteraction >= %@ AND lastInteraction < %@",
                        startOfDay, endOfDay];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"lastInteraction" ascending:NO]];
    
    NSError *error = nil;
    NSArray<Symbol *> *symbolEntities = [self.mainContext executeFetchRequest:request error:&error];
    
    NSMutableArray<NSString *> *symbols = [NSMutableArray array];
    if (!error) {
        for (Symbol *symbol in symbolEntities) {
            if (symbol.symbol && symbol.symbol.length > 0) {
                [symbols addObject:symbol.symbol];
            }
        }
    }
    
    return [symbols copy];
}

- (NSString *)getArchiveDirectoryPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *appSupportPath = [paths firstObject];
    NSString *appPath = [appSupportPath stringByAppendingPathComponent:@"TradingApp"];
    return [appPath stringByAppendingPathComponent:@"Archives"];
}

- (NSString *)createArchiveDirectoryForDate:(NSString *)date error:(NSError **)error {
    // Parse date per determinare il quarter
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd";
    NSDate *dateObj = [formatter dateFromString:date];
    
    if (!dateObj) {
        if (error) {
            *error = [NSError errorWithDomain:@"DataHubArchive"
                                         code:1006
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid date format"}];
        }
        return nil;
    }
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSInteger year = [calendar component:NSCalendarUnitYear fromDate:dateObj];
    NSInteger month = [calendar component:NSCalendarUnitMonth fromDate:dateObj];
    
    // Determina il quarter
    NSInteger quarter = ((month - 1) / 3) + 1;
    NSString *quarterString = [NSString stringWithFormat:@"%ld-Q%ld", (long)year, (long)quarter];
    
    // Crea la directory path
    NSString *archivePath = [self getArchiveDirectoryPath];
    NSString *quarterPath = [archivePath stringByAppendingPathComponent:quarterString];
    
    // Crea le directory se non esistono
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL success = [fileManager createDirectoryAtPath:quarterPath
                          withIntermediateDirectories:YES
                                           attributes:nil
                                                error:error];
    
    if (success) {
        return quarterPath;
    } else {
        return nil;
    }
}


@end

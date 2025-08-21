//
//  DataHub+ChartPatterns.m
//  TradingApp
//
//  DataHub extension for Chart Patterns persistence
//

#import "DataHub+ChartPatterns.h"
#import "DataHub+Private.h"
#import "ChartPattern+CoreDataClass.h"
#import "ChartWidget+SaveData.h"

// UserDefaults key for storing user-added pattern types
static NSString * const kUserPatternTypesKey = @"UserAddedPatternTypes";

@implementation DataHub (ChartPatterns)

#pragma mark - CRUD Operations

- (nullable ChartPatternModel *)createPatternWithType:(NSString *)patternType
                                   savedDataReference:(NSString *)savedDataRef
                                                notes:(nullable NSString *)notes {
    
    // Validation
    if (![self isValidPatternType:patternType]) {
        NSLog(@"❌ DataHub: Invalid pattern type: %@", patternType);
        return nil;
    }
    
    if (![self savedDataExistsForReference:savedDataRef]) {
        NSLog(@"❌ DataHub: SavedChartData not found for reference: %@", savedDataRef);
        return nil;
    }
    
    // Create Core Data entity
    ChartPattern *coreDataPattern = [NSEntityDescription insertNewObjectForEntityForName:@"ChartPattern"
                                                                  inManagedObjectContext:self.mainContext];
    coreDataPattern.patternID = [[NSUUID UUID] UUIDString];
    coreDataPattern.patternType = patternType;
    coreDataPattern.savedDataReference = savedDataRef;
    coreDataPattern.creationDate = [NSDate date];
    coreDataPattern.additionalNotes = notes;
    
    // Save to Core Data
    [self saveContext];
    
    // Convert to Runtime Model
    ChartPatternModel *patternModel = [self patternModelFromCoreData:coreDataPattern];
    
    // Add pattern type to known types if new
    [self addPatternType:patternType];
    
    NSLog(@"✅ DataHub: Created pattern %@ [%@] with savedDataRef %@",
          patternType, patternModel.patternID, savedDataRef);
    
    // Post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubChartPatternCreated"
                                                        object:self
                                                      userInfo:@{@"pattern": patternModel}];
    
    return patternModel;
}

- (NSArray<ChartPatternModel *> *)getAllPatterns {
    NSFetchRequest *request = [ChartPattern fetchRequest];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    
    NSError *error = nil;
    NSArray<ChartPattern *> *coreDataPatterns = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"❌ DataHub: Error fetching patterns: %@", error);
        return @[];
    }
    
    NSMutableArray<ChartPatternModel *> *patterns = [NSMutableArray array];
    for (ChartPattern *coreDataPattern in coreDataPatterns) {
        ChartPatternModel *patternModel = [self patternModelFromCoreData:coreDataPattern];
        [patterns addObject:patternModel];
    }
    
    NSLog(@"📊 DataHub: Loaded %lu chart patterns", (unsigned long)patterns.count);
    return [patterns copy];
}

- (NSArray<ChartPatternModel *> *)getPatternsOfType:(NSString *)patternType {
    NSFetchRequest *request = [ChartPattern fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"patternType == %@", patternType];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
    
    NSError *error = nil;
    NSArray<ChartPattern *> *coreDataPatterns = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"❌ DataHub: Error fetching patterns of type %@: %@", patternType, error);
        return @[];
    }
    
    NSMutableArray<ChartPatternModel *> *patterns = [NSMutableArray array];
    for (ChartPattern *coreDataPattern in coreDataPatterns) {
        ChartPatternModel *patternModel = [self patternModelFromCoreData:coreDataPattern];
        [patterns addObject:patternModel];
    }
    
    return [patterns copy];
}

- (NSArray<ChartPatternModel *> *)getPatternsForSymbol:(NSString *)symbol {
    // Get all patterns and filter by symbol from SavedChartData
    NSArray<ChartPatternModel *> *allPatterns = [self getAllPatterns];
    NSMutableArray<ChartPatternModel *> *symbolPatterns = [NSMutableArray array];
    
    for (ChartPatternModel *pattern in allPatterns) {
        if ([pattern.symbol isEqualToString:symbol]) {
            [symbolPatterns addObject:pattern];
        }
    }
    
    return [symbolPatterns copy];
}

- (nullable ChartPatternModel *)getPatternWithID:(NSString *)patternID {
    NSFetchRequest *request = [ChartPattern fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"patternID == %@", patternID];
    request.fetchLimit = 1;
    
    NSError *error = nil;
    NSArray<ChartPattern *> *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"❌ DataHub: Error fetching pattern %@: %@", patternID, error);
        return nil;
    }
    
    if (results.count == 0) {
        return nil;
    }
    
    return [self patternModelFromCoreData:results.firstObject];
}

- (BOOL)updatePattern:(ChartPatternModel *)pattern {
    NSFetchRequest *request = [ChartPattern fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"patternID == %@", pattern.patternID];
    request.fetchLimit = 1;
    
    NSError *error = nil;
    NSArray<ChartPattern *> *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error || results.count == 0) {
        NSLog(@"❌ DataHub: Pattern not found for update: %@", pattern.patternID);
        return NO;
    }
    
    ChartPattern *coreDataPattern = results.firstObject;
    coreDataPattern.patternType = pattern.patternType;
    coreDataPattern.additionalNotes = pattern.additionalNotes;
    
    [self saveContext];
    
    NSLog(@"✅ DataHub: Updated pattern %@", pattern.patternID);
    
    // Post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubChartPatternUpdated"
                                                        object:self
                                                      userInfo:@{@"pattern": pattern}];
    
    return YES;
}

- (BOOL)deletePatternWithID:(NSString *)patternID {
    NSFetchRequest *request = [ChartPattern fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"patternID == %@", patternID];
    request.fetchLimit = 1;
    
    NSError *error = nil;
    NSArray<ChartPattern *> *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error || results.count == 0) {
        NSLog(@"❌ DataHub: Pattern not found for deletion: %@", patternID);
        return NO;
    }
    
    ChartPattern *coreDataPattern = results.firstObject;
    [self.mainContext deleteObject:coreDataPattern];
    
    [self saveContext];
    
    NSLog(@"🗑️ DataHub: Deleted pattern %@", patternID);
    
    // Post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubChartPatternDeleted"
                                                        object:self
                                                      userInfo:@{@"patternID": patternID}];
    
    return YES;
}

#pragma mark - Pattern Types Management

- (NSArray<NSString *> *)getAllPatternTypes {
    NSFetchRequest *request = [ChartPattern fetchRequest];
    request.resultType = NSDictionaryResultType;
    request.propertiesToFetch = @[@"patternType"];
    request.returnsDistinctResults = YES;
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"❌ DataHub: Error fetching pattern types: %@", error);
        return @[];
    }
    
    NSMutableArray<NSString *> *patternTypes = [NSMutableArray array];
    for (NSDictionary *result in results) {
        NSString *patternType = result[@"patternType"];
        if (patternType) {
            [patternTypes addObject:patternType];
        }
    }
    
    return [patternTypes copy];
}

- (void)addPatternType:(NSString *)newType {
    if (![self isValidPatternType:newType]) {
        return;
    }
    
    NSArray<NSString *> *knownTypes = [self getAllKnownPatternTypes];
    if ([knownTypes containsObject:newType]) {
        return; // Already exists
    }
    
    // Add to user defaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *userTypes = [[defaults arrayForKey:kUserPatternTypesKey] mutableCopy] ?: [NSMutableArray array];
    [userTypes addObject:newType];
    [defaults setObject:userTypes forKey:kUserPatternTypesKey];
    [defaults synchronize];
    
    NSLog(@"📝 DataHub: Added new pattern type: %@", newType);
}

- (NSArray<NSString *> *)getDefaultPatternTypes {
    return @[
        @"IUESEI",
        @"PD model",
        @"Catapulta"
    ];
}

- (NSArray<NSString *> *)getAllKnownPatternTypes {
    NSMutableSet<NSString *> *allTypes = [NSMutableSet set];
    
    // Add default types
    [allTypes addObjectsFromArray:[self getDefaultPatternTypes]];
    
    // Add user-added types
    NSArray *userTypes = [[NSUserDefaults standardUserDefaults] arrayForKey:kUserPatternTypesKey];
    if (userTypes) {
        [allTypes addObjectsFromArray:userTypes];
    }
    
    // Add types from database
    [allTypes addObjectsFromArray:[self getAllPatternTypes]];
    
    return [[allTypes allObjects] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

#pragma mark - Validation

- (BOOL)isValidPatternType:(NSString *)patternType {
    if (!patternType || patternType.length == 0) {
        return NO;
    }
    
    if (patternType.length > 100) { // Reasonable length limit
        return NO;
    }
    
    return YES;
}

- (BOOL)savedDataExistsForReference:(NSString *)savedDataRef {
    if (!savedDataRef) {
        return NO;
    }
    
    // Build file path and check if file exists
    NSString *directory = [ChartWidget savedChartDataDirectory];
    NSString *filename = [NSString stringWithFormat:@"%@.plist", savedDataRef];
    NSString *filePath = [directory stringByAppendingPathComponent:filename];
    
    return [[NSFileManager defaultManager] fileExistsAtPath:filePath];
}

#pragma mark - Cleanup Operations

- (NSArray<ChartPatternModel *> *)findOrphanedPatterns {
    NSArray<ChartPatternModel *> *allPatterns = [self getAllPatterns];
    NSMutableArray<ChartPatternModel *> *orphanedPatterns = [NSMutableArray array];
    
    for (ChartPatternModel *pattern in allPatterns) {
        if (!pattern.hasValidSavedData) {
            [orphanedPatterns addObject:pattern];
        }
    }
    
    NSLog(@"🔍 DataHub: Found %lu orphaned patterns", (unsigned long)orphanedPatterns.count);
    return [orphanedPatterns copy];
}

- (NSArray<NSString *> *)findOrphanedSavedData {
    // Get all SavedChartData files
    NSArray<NSString *> *allFiles = [ChartWidget availableSavedChartDataFiles];
    NSMutableArray<NSString *> *allSavedDataIDs = [NSMutableArray array];
    
    // Extract UUIDs from filenames (assuming format: UUID.plist)
    for (NSString *filePath in allFiles) {
        NSString *filename = filePath.lastPathComponent;
        NSString *uuid = [filename stringByDeletingPathExtension];
        [allSavedDataIDs addObject:uuid];
    }
    
    // Get all referenced SavedChartData IDs from patterns
    NSFetchRequest *request = [ChartPattern fetchRequest];
    request.resultType = NSDictionaryResultType;
    request.propertiesToFetch = @[@"savedDataReference"];
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"❌ DataHub: Error fetching pattern references: %@", error);
        return @[];
    }
    
    NSMutableSet<NSString *> *referencedIDs = [NSMutableSet set];
    for (NSDictionary *result in results) {
        NSString *reference = result[@"savedDataReference"];
        if (reference) {
            [referencedIDs addObject:reference];
        }
    }
    
    // Find orphaned IDs
    NSMutableArray<NSString *> *orphanedIDs = [NSMutableArray array];
    for (NSString *savedDataID in allSavedDataIDs) {
        if (![referencedIDs containsObject:savedDataID]) {
            [orphanedIDs addObject:savedDataID];
        }
    }
    
    NSLog(@"🔍 DataHub: Found %lu orphaned SavedChartData files", (unsigned long)orphanedIDs.count);
    return [orphanedIDs copy];
}

- (void)cleanupOrphanedPatterns:(NSArray<ChartPatternModel *> *)orphanedPatterns
                     completion:(void(^)(NSInteger deletedCount, NSError * _Nullable error))completion {
    
    if (orphanedPatterns.count == 0) {
        completion(0, nil);
        return;
    }
    
    // Show alert for user confirmation
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Cleanup Orphaned Patterns";
        alert.informativeText = [NSString stringWithFormat:@"Found %lu patterns with missing SavedChartData files. Do you want to delete these patterns?", (unsigned long)orphanedPatterns.count];
        [alert addButtonWithTitle:@"Delete"];
        [alert addButtonWithTitle:@"Cancel"];
        alert.alertStyle = NSAlertStyleWarning;
        
        NSModalResponse response = [alert runModal];
        
        if (response == NSAlertFirstButtonReturn) {
            // User confirmed deletion
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSInteger deletedCount = 0;
                NSError *deleteError = nil;
                
                for (ChartPatternModel *pattern in orphanedPatterns) {
                    if ([self deletePatternWithID:pattern.patternID]) {
                        deletedCount++;
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(deletedCount, deleteError);
                });
            });
        } else {
            // User cancelled
            completion(0, nil);
        }
    });
}

#pragma mark - Statistics

- (NSDictionary<NSString *, NSNumber *> *)getPatternStatistics {
    NSArray<ChartPatternModel *> *allPatterns = [self getAllPatterns];
    NSMutableDictionary<NSString *, NSNumber *> *stats = [NSMutableDictionary dictionary];
    
    for (ChartPatternModel *pattern in allPatterns) {
        NSString *type = pattern.patternType;
        NSNumber *currentCount = stats[type] ?: @(0);
        stats[type] = @(currentCount.integerValue + 1);
    }
    
    return [stats copy];
}

- (NSInteger)getTotalPatternCount {
    NSFetchRequest *request = [ChartPattern fetchRequest];
    request.resultType = NSCountResultType;
    
    NSError *error = nil;
    NSArray *results = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"❌ DataHub: Error counting patterns: %@", error);
        return 0;
    }
    
    return [results.firstObject integerValue];
}

#pragma mark - Private Helpers

- (ChartPatternModel *)patternModelFromCoreData:(ChartPattern *)coreDataPattern {
    NSDictionary *dict = @{
        @"patternID": coreDataPattern.patternID ?: @"",
        @"patternType": coreDataPattern.patternType ?: @"",
        @"savedDataReference": coreDataPattern.savedDataReference ?: @"",
        @"creationDate": coreDataPattern.creationDate ?: [NSDate date],
        @"additionalNotes": coreDataPattern.additionalNotes ?: @""
    };
    
    return [[ChartPatternModel alloc] initWithDictionary:dict];
}

@end

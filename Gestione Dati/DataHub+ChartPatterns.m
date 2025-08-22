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
#import "SavedChartData.h"

// UserDefaults key for storing user-added pattern types
static NSString * const kUserPatternTypesKey = @"UserAddedPatternTypes";

@interface DataHub (ChartPatternsPrivate)
- (BOOL)isStringLikelyUUID:(NSString *)string;
- (ChartPatternModel *)patternModelFromCoreData:(ChartPattern *)coreDataPattern;
- (void)updateCoreDataPattern:(ChartPattern *)coreDataPattern fromModel:(ChartPatternModel *)model;
@end

@implementation DataHub (ChartPatterns)

#pragma mark - CRUD Operations

- (nullable ChartPatternModel *)createPatternWithType:(NSString *)patternType
                                   savedDataReference:(NSString *)savedDataRef
                                       patternStartDate:(NSDate *)startDate
                                         patternEndDate:(NSDate *)endDate
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
    
    if (![self validatePatternDateRange:startDate endDate:endDate forSavedDataReference:savedDataRef]) {
        NSLog(@"❌ DataHub: Invalid pattern date range for savedDataRef: %@", savedDataRef);
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
    
    // Set pattern date range
    coreDataPattern.patternStartDate = startDate;
    coreDataPattern.patternEndDate = endDate;
    
    // Save to Core Data
    [self saveContext];
    
    // Convert to Runtime Model
    ChartPatternModel *patternModel = [self patternModelFromCoreData:coreDataPattern];
    
    // Add pattern type to known types if new
    [self addPatternType:patternType];
    
    NSLog(@"✅ DataHub: Created pattern %@ [%@] with savedDataRef %@ and date range %@ to %@",
          patternType, patternModel.patternID, savedDataRef, startDate, endDate);
    
    // Post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubChartPatternCreated"
                                                        object:self
                                                      userInfo:@{@"pattern": patternModel}];
    
    return patternModel;
}

- (nullable ChartPatternModel *)createPatternWithType:(NSString *)patternType
                                   savedDataReference:(NSString *)savedDataRef
                                                notes:(nullable NSString *)notes {
    
    // Load SavedChartData to get full date range
    NSString *directory = [ChartWidget savedChartDataDirectory];
    NSString *filename = [NSString stringWithFormat:@"%@.chartdata", savedDataRef];
    NSString *filePath = [directory stringByAppendingPathComponent:filename];
    SavedChartData *savedData = [SavedChartData loadFromFile:filePath];
    
    if (!savedData) {
        NSLog(@"❌ DataHub: Cannot load SavedChartData for reference: %@", savedDataRef);
        return nil;
    }
    
    NSDate *startDate = savedData.startDate ?: [NSDate date];
    NSDate *endDate = savedData.endDate ?: [NSDate date];
    
    return [self createPatternWithType:patternType
                    savedDataReference:savedDataRef
                        patternStartDate:startDate
                          patternEndDate:endDate
                               notes:notes];
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

- (NSArray<ChartPatternModel *> *)getPatternsForSymbol:(NSString *)symbol
                                             startDate:(NSDate *)startDate
                                               endDate:(NSDate *)endDate {
    
    NSArray<ChartPatternModel *> *symbolPatterns = [self getPatternsForSymbol:symbol];
    NSMutableArray<ChartPatternModel *> *filteredPatterns = [NSMutableArray array];
    
    for (ChartPatternModel *pattern in symbolPatterns) {
        // Check if pattern overlaps with requested date range
        BOOL overlaps = NO;
        
        if (pattern.patternStartDate && pattern.patternEndDate) {
            // Pattern has specific date range - check for overlap
            BOOL startsBeforeEnd = [pattern.patternStartDate compare:endDate] != NSOrderedDescending;
            BOOL endsAfterStart = [pattern.patternEndDate compare:startDate] != NSOrderedAscending;
            overlaps = startsBeforeEnd && endsAfterStart;
        }
        
        if (overlaps) {
            [filteredPatterns addObject:pattern];
        }
    }
    
    return [filteredPatterns copy];
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
    [self updateCoreDataPattern:coreDataPattern fromModel:pattern];
    
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
        @"Catapulta",
        @"Head & Shoulders",
        @"Cup & Handle",
        @"Breakout",
        @"Flag",
        @"Pennant",
        @"Triangle",
        @"Double Top",
        @"Double Bottom",
        @"Support/Resistance"
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
    NSString *filename = [NSString stringWithFormat:@"%@.chartdata", savedDataRef];
    NSString *filePath = [directory stringByAppendingPathComponent:filename];
    
    return [[NSFileManager defaultManager] fileExistsAtPath:filePath];
}

- (BOOL)validatePatternDateRange:(NSDate *)startDate
                         endDate:(NSDate *)endDate
              forSavedDataReference:(NSString *)savedDataRef {
    
    if (!startDate || !endDate) {
        NSLog(@"❌ DataHub: Missing pattern dates");
        return NO;
    }
    
    // Check that start < end
    if ([startDate compare:endDate] != NSOrderedAscending) {
        NSLog(@"❌ DataHub: Pattern start date must be before end date");
        return NO;
    }
    
    // Load SavedChartData to check bounds
    NSString *directory = [ChartWidget savedChartDataDirectory];
    NSString *filename = [NSString stringWithFormat:@"%@.chartdata", savedDataRef];
    NSString *filePath = [directory stringByAppendingPathComponent:filename];
    SavedChartData *savedData = [SavedChartData loadFromFile:filePath];
    
    if (!savedData) {
        NSLog(@"❌ DataHub: Cannot load SavedChartData for validation");
        return NO;
    }
    
    // Check that pattern dates are within SavedChartData range
    BOOL startInRange = [startDate compare:savedData.startDate] != NSOrderedAscending &&
                       [startDate compare:savedData.endDate] != NSOrderedDescending;
    
    BOOL endInRange = [endDate compare:savedData.startDate] != NSOrderedAscending &&
                     [endDate compare:savedData.endDate] != NSOrderedDescending;
    
    if (!startInRange || !endInRange) {
        NSLog(@"❌ DataHub: Pattern dates outside SavedChartData range");
        NSLog(@"   Pattern range: %@ to %@", startDate, endDate);
        NSLog(@"   Data range: %@ to %@", savedData.startDate, savedData.endDate);
        return NO;
    }
    
    return YES;
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

- (NSArray<ChartPatternModel *> *)findPatternsWithInvalidDateRanges {
    NSArray<ChartPatternModel *> *allPatterns = [self getAllPatterns];
    NSMutableArray<ChartPatternModel *> *invalidPatterns = [NSMutableArray array];
    
    for (ChartPatternModel *pattern in allPatterns) {
        if (!pattern.hasValidDateRange) {
            [invalidPatterns addObject:pattern];
        }
    }
    
    NSLog(@"🔍 DataHub: Found %lu patterns with invalid date ranges", (unsigned long)invalidPatterns.count);
    return [invalidPatterns copy];
}

- (NSArray<NSString *> *)findOrphanedSavedData {
    // Get all SavedChartData files
    NSArray<NSString *> *allFiles = [ChartWidget availableSavedChartDataFiles];
    NSMutableArray<NSString *> *allSavedDataIDs = [NSMutableArray array];
    
    // Extract UUIDs from filenames
    for (NSString *filePath in allFiles) {
        NSString *filename = filePath.lastPathComponent;
        NSString *uuid = [filename stringByDeletingPathExtension];
        if ([self isStringLikelyUUID:uuid]) {
            [allSavedDataIDs addObject:uuid];
        }
    }
    
    // Get all referenced SavedChartData IDs from patterns
    NSArray<ChartPatternModel *> *allPatterns = [self getAllPatterns];
    NSMutableSet<NSString *> *referencedIDs = [NSMutableSet set];
    
    for (ChartPatternModel *pattern in allPatterns) {
        [referencedIDs addObject:pattern.savedDataReference];
    }
    
    // Find orphaned (unreferenced) IDs
    NSMutableArray<NSString *> *orphanedIDs = [NSMutableArray array];
    for (NSString *uuid in allSavedDataIDs) {
        if (![referencedIDs containsObject:uuid]) {
            [orphanedIDs addObject:uuid];
        }
    }
    
    NSLog(@"🔍 DataHub: Found %lu orphaned SavedChartData files", (unsigned long)orphanedIDs.count);
    return [orphanedIDs copy];
}

- (void)cleanupOrphanedPatternsWithCompletion:(void(^)(NSInteger deletedCount, NSError * _Nullable error))completion {
    NSArray<ChartPatternModel *> *orphanedPatterns = [self findOrphanedPatterns];
    
    NSInteger deletedCount = 0;
    NSError *error = nil;
    
    for (ChartPatternModel *pattern in orphanedPatterns) {
        if ([self deletePatternWithID:pattern.patternID]) {
            deletedCount++;
        }
    }
    
    NSLog(@"🧹 DataHub: Cleaned up %ld orphaned patterns", (long)deletedCount);
    
    if (completion) {
        completion(deletedCount, error);
    }
}

// ✅ AGGIUNTO: Metodo con signature richiesta dal ChartPatternManager
- (void)cleanupOrphanedPatterns:(NSArray<ChartPatternModel *> *)orphanedPatterns
                     completion:(void(^)(NSInteger deletedCount, NSError * _Nullable error))completion {
    
    NSInteger deletedCount = 0;
    NSError *error = nil;
    
    for (ChartPatternModel *pattern in orphanedPatterns) {
        if ([self deletePatternWithID:pattern.patternID]) {
            deletedCount++;
        }
    }
    
    NSLog(@"🧹 DataHub: Cleaned up %ld specified orphaned patterns", (long)deletedCount);
    
    if (completion) {
        completion(deletedCount, error);
    }
}

// ✅ AGGIUNTO: Metodo getPatternStatistics richiesto dal ChartPatternManager
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

// ✅ AGGIUNTO: Metodo getTotalPatternCount richiesto dal ChartPatternManager
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

- (void)fixInvalidPatternDateRangesWithCompletion:(void(^)(NSInteger fixedCount, NSError * _Nullable error))completion {
    NSArray<ChartPatternModel *> *invalidPatterns = [self findPatternsWithInvalidDateRanges];
    
    NSInteger fixedCount = 0;
    NSError *error = nil;
    
    for (ChartPatternModel *pattern in invalidPatterns) {
        // Load SavedChartData to get valid date range
        SavedChartData *savedData = [pattern loadConnectedSavedData];
        if (savedData && savedData.startDate && savedData.endDate) {
            // Update pattern with full SavedChartData range
            [pattern updatePatternType:pattern.patternType
                        patternStartDate:savedData.startDate
                          patternEndDate:savedData.endDate
                               notes:pattern.additionalNotes];
            
            if ([self updatePattern:pattern]) {
                fixedCount++;
            }
        }
    }
    
    NSLog(@"🔧 DataHub: Fixed %ld patterns with invalid date ranges", (long)fixedCount);
    
    if (completion) {
        completion(fixedCount, error);
    }
}

#pragma mark - Migration Support

- (void)migratePatternDateRangesWithCompletion:(void(^)(NSInteger migratedCount, NSError * _Nullable error))completion {
    // Get all patterns from Core Data directly to check for missing date ranges
    NSFetchRequest *request = [ChartPattern fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"patternStartDate == nil OR patternEndDate == nil"];
    
    NSError *error = nil;
    NSArray<ChartPattern *> *patternsToMigrate = [self.mainContext executeFetchRequest:request error:&error];
    
    if (error) {
        NSLog(@"❌ DataHub: Error fetching patterns for migration: %@", error);
        if (completion) {
            completion(0, error);
        }
        return;
    }
    
    NSInteger migratedCount = 0;
    
    for (ChartPattern *pattern in patternsToMigrate) {
        // Load SavedChartData to get date range
        NSString *directory = [ChartWidget savedChartDataDirectory];
        NSString *filename = [NSString stringWithFormat:@"%@.chartdata", pattern.savedDataReference];
        NSString *filePath = [directory stringByAppendingPathComponent:filename];
        SavedChartData *savedData = [SavedChartData loadFromFile:filePath];
        
        if (savedData && savedData.startDate && savedData.endDate) {
            // Set pattern dates to full SavedChartData range
            pattern.patternStartDate = savedData.startDate;
            pattern.patternEndDate = savedData.endDate;
            migratedCount++;
            
            NSLog(@"📈 DataHub: Migrated pattern %@ with date range %@ to %@",
                  pattern.patternID, savedData.startDate, savedData.endDate);
        }
    }
    
    if (migratedCount > 0) {
        [self saveContext];
    }
    
    NSLog(@"🔄 DataHub: Migrated %ld patterns to new date range format", (long)migratedCount);
    
    if (completion) {
        completion(migratedCount, nil);
    }
}

#pragma mark - Private Helper Methods

- (ChartPatternModel *)patternModelFromCoreData:(ChartPattern *)coreDataPattern {
    if (!coreDataPattern) return nil;
    
    ChartPatternModel *model;
    
    // Check if pattern has date range (new format)
    if (coreDataPattern.patternStartDate && coreDataPattern.patternEndDate) {
        model = [[ChartPatternModel alloc] initWithPatternType:coreDataPattern.patternType
                                           savedDataReference:coreDataPattern.savedDataReference
                                               patternStartDate:coreDataPattern.patternStartDate
                                                 patternEndDate:coreDataPattern.patternEndDate
                                                       notes:coreDataPattern.additionalNotes];
    } else {
        // Legacy format - use old initializer (will auto-fill dates from SavedChartData)
        model = [[ChartPatternModel alloc] initWithPatternType:coreDataPattern.patternType
                                          savedDataReference:coreDataPattern.savedDataReference
                                                       notes:coreDataPattern.additionalNotes];
    }
    
    // Set the immutable properties from Core Data
    if (model) {
        // Use setValue:forKey: to set readonly properties
        [model setValue:coreDataPattern.patternID forKey:@"patternID"];
        [model setValue:coreDataPattern.creationDate forKey:@"creationDate"];
    }
    
    return model;
}

- (void)updateCoreDataPattern:(ChartPattern *)coreDataPattern fromModel:(ChartPatternModel *)model {
    coreDataPattern.patternType = model.patternType;
    coreDataPattern.additionalNotes = model.additionalNotes;
    
    // Update pattern date range
    coreDataPattern.patternStartDate = model.patternStartDate;
    coreDataPattern.patternEndDate = model.patternEndDate;
    
    // Note: We don't update patternID, savedDataReference, or creationDate as these are immutable
}

- (BOOL)isStringLikelyUUID:(NSString *)string {
    if (!string || string.length != 36) {
        return NO;
    }
    
    // Basic UUID format check: 8-4-4-4-12
    NSRange range1 = NSMakeRange(8, 1);
    NSRange range2 = NSMakeRange(13, 1);
    NSRange range3 = NSMakeRange(18, 1);
    NSRange range4 = NSMakeRange(23, 1);
    
    return ([[string substringWithRange:range1] isEqualToString:@"-"]) &&
           ([[string substringWithRange:range2] isEqualToString:@"-"]) &&
           ([[string substringWithRange:range3] isEqualToString:@"-"]) &&
           ([[string substringWithRange:range4] isEqualToString:@"-"]);
}

@end

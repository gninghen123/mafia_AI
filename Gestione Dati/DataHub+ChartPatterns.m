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

/// Create pattern with specific date range
/// @param patternType The pattern type string
/// @param savedDataReference UUID reference to SavedChartData file
/// @param patternStartDate Start date of the pattern within the SavedChartData
/// @param patternEndDate End date of the pattern within the SavedChartData
/// @param notes Optional user notes
/// @return Created ChartPatternModel or nil if failed
- (nullable ChartPatternModel *)createPatternWithType:(NSString *)patternType
                                   savedDataReference:(NSString *)savedDataReference
                                       patternStartDate:(NSDate *)patternStartDate
                                         patternEndDate:(NSDate *)patternEndDate
                                                notes:(nullable NSString *)notes {
    
    if (!patternType || !savedDataReference || !patternStartDate || !patternEndDate) {
        NSLog(@"❌ DataHub: Invalid parameters for pattern creation with date range");
        return nil;
    }
    
    // Validate date range
    if ([patternStartDate compare:patternEndDate] != NSOrderedAscending) {
        NSLog(@"❌ DataHub: Invalid date range - start date must be before end date");
        return nil;
    }
    
    // Create runtime model with date range
    ChartPatternModel *runtimeModel = [[ChartPatternModel alloc] initWithPatternType:patternType
                                                                  savedDataReference:savedDataReference
                                                                      patternStartDate:patternStartDate
                                                                        patternEndDate:patternEndDate
                                                                                notes:notes];
    
    if (!runtimeModel) {
        NSLog(@"❌ DataHub: Failed to create runtime ChartPatternModel");
        return nil;
    }
    
    // Validate SavedChartData reference exists
    if (![runtimeModel validateSavedDataReference]) {
        NSLog(@"❌ DataHub: SavedChartData reference %@ does not exist", savedDataReference);
        return nil;
    }
    
    // Validate pattern date range is within SavedChartData bounds
    if (![runtimeModel validatePatternDateRange]) {
        NSLog(@"❌ DataHub: Pattern date range is outside SavedChartData bounds");
        return nil;
    }
    
    // Create Core Data entity
    ChartPattern *coreDataEntity = [NSEntityDescription insertNewObjectForEntityForName:@"ChartPattern"
                                                                 inManagedObjectContext:self.mainContext];
    
    if (!coreDataEntity) {
        NSLog(@"❌ DataHub: Failed to create ChartPattern Core Data entity");
        return nil;
    }
    
    // Set Core Data properties from runtime model
    coreDataEntity.patternID = runtimeModel.patternID;
    coreDataEntity.patternType = runtimeModel.patternType;
    coreDataEntity.savedDataReference = runtimeModel.savedDataReference;
    coreDataEntity.creationDate = runtimeModel.creationDate;
    coreDataEntity.additionalNotes = runtimeModel.additionalNotes;
    
    // ✅ NUOVO: Set pattern date range in Core Data
    coreDataEntity.patternStartDate = runtimeModel.patternStartDate;
    coreDataEntity.patternEndDate = runtimeModel.patternEndDate;
    
    // Save to persistent store
    NSError *error;
    if (![self.mainContext save:&error]) {
        NSLog(@"❌ DataHub: Failed to save ChartPattern to Core Data: %@", error.localizedDescription);
        [self.mainContext deleteObject:coreDataEntity];
        return nil;
    }
    
    NSLog(@"✅ DataHub: Created pattern '%@' [%@] with date range %@ to %@",
          patternType, runtimeModel.patternID, patternStartDate, patternEndDate);
    
    return runtimeModel;
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

#pragma mark - SavedChartData Usage Analytics

/// Get detailed analytics about SavedChartData sharing efficiency
- (NSDictionary<NSString *, id> *)getSavedChartDataSharingAnalytics {
    NSMutableDictionary *analytics = [NSMutableDictionary dictionary];
    
    // Get all patterns
    NSArray<ChartPatternModel *> *allPatterns = [self getAllPatterns];
    analytics[@"totalPatterns"] = @(allPatterns.count);
    
    if (allPatterns.count == 0) {
        analytics[@"efficiency"] = @"No patterns created yet";
        return [analytics copy];
    }
    
    // Group patterns by SavedChartData reference
    NSMutableDictionary<NSString *, NSMutableArray<ChartPatternModel *> *> *patternsByReference =
        [NSMutableDictionary dictionary];
    
    for (ChartPatternModel *pattern in allPatterns) {
        NSString *ref = pattern.savedDataReference;
        if (!patternsByReference[ref]) {
            patternsByReference[ref] = [NSMutableArray array];
        }
        [patternsByReference[ref] addObject:pattern];
    }
    
    analytics[@"uniqueSavedChartDataReferences"] = @(patternsByReference.count);
    
    // Calculate sharing statistics
    NSInteger sharedReferences = 0;
    NSInteger totalSharedPatterns = 0;
    NSInteger maxPatternsPerReference = 0;
    
    for (NSString *ref in patternsByReference) {
        NSInteger patternCount = patternsByReference[ref].count;
        maxPatternsPerReference = MAX(maxPatternsPerReference, patternCount);
        
        if (patternCount > 1) {
            sharedReferences++;
            totalSharedPatterns += patternCount;
        }
    }
    
    analytics[@"sharedSavedChartDataReferences"] = @(sharedReferences);
    analytics[@"totalPatternsUsingSharedData"] = @(totalSharedPatterns);
    analytics[@"maxPatternsPerSavedChartData"] = @(maxPatternsPerReference);
    
    // Calculate efficiency metrics
    double sharingEfficiency = (double)allPatterns.count / (double)patternsByReference.count;
    analytics[@"averagePatternsPerSavedChartData"] = @(sharingEfficiency);
    
    double storageEfficiency = 1.0 - ((double)patternsByReference.count / (double)allPatterns.count);
    analytics[@"storageEfficiencyPercent"] = @(storageEfficiency * 100.0);
    
    // Top shared SavedChartData
    NSArray<NSString *> *sortedRefs = [patternsByReference.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *ref1, NSString *ref2) {
        NSInteger count1 = patternsByReference[ref1].count;
        NSInteger count2 = patternsByReference[ref2].count;
        return [@(count2) compare:@(count1)]; // Descending order
    }];
    
    NSMutableArray *topShared = [NSMutableArray array];
    for (NSInteger i = 0; i < MIN(5, sortedRefs.count); i++) {
        NSString *ref = sortedRefs[i];
        NSArray<ChartPatternModel *> *patterns = patternsByReference[ref];
        if (patterns.count > 1) {
            ChartPatternModel *firstPattern = patterns.firstObject;
            [topShared addObject:@{
                @"savedChartDataReference": ref,
                @"patternCount": @(patterns.count),
                @"symbol": firstPattern.symbol ?: @"Unknown",
                @"timeframe": @(firstPattern.timeframe)
            }];
        }
    }
    analytics[@"topSharedSavedChartData"] = topShared;
    
    return [analytics copy];
}

/// Log SavedChartData sharing statistics to console
- (void)logSavedChartDataSharingStatistics {
    NSDictionary *analytics = [self getSavedChartDataSharingAnalytics];
    
    NSLog(@"\n📊 SAVEDCHARTDATA SHARING ANALYTICS");
    NSLog(@"=====================================");
    NSLog(@"Total Patterns: %@", analytics[@"totalPatterns"]);
    NSLog(@"Unique SavedChartData Files: %@", analytics[@"uniqueSavedChartDataReferences"]);
    NSLog(@"Average Patterns per File: %.2f", [analytics[@"averagePatternsPerSavedChartData"] doubleValue]);
    NSLog(@"Storage Efficiency: %.1f%%", [analytics[@"storageEfficiencyPercent"] doubleValue]);
    NSLog(@"Shared Files: %@", analytics[@"sharedSavedChartDataReferences"]);
    NSLog(@"Patterns Using Shared Data: %@", analytics[@"totalPatternsUsingSharedData"]);
    NSLog(@"Max Patterns per File: %@", analytics[@"maxPatternsPerSavedChartData"]);
    
    NSArray *topShared = analytics[@"topSharedSavedChartData"];
    if (topShared.count > 0) {
        NSLog(@"\n🏆 TOP SHARED SAVEDCHARTDATA:");
        for (NSDictionary *shared in topShared) {
            NSLog(@"  • %@ patterns for %@ [timeframe:%@] (ref: %@)",
                  shared[@"patternCount"], shared[@"symbol"], shared[@"timeframe"],
                  [shared[@"savedChartDataReference"] substringToIndex:8]);
        }
    }
    NSLog(@"=====================================\n");
}

/// Analyze storage optimization potential
- (NSDictionary<NSString *, NSNumber *> *)analyzeSavedChartDataStorageOptimization {
    NSMutableDictionary *analysis = [NSMutableDictionary dictionary];
    
    // Current state
    NSDictionary *sharingAnalytics = [self getSavedChartDataSharingAnalytics];
    NSInteger currentFiles = [sharingAnalytics[@"uniqueSavedChartDataReferences"] integerValue];
    NSInteger totalPatterns = [sharingAnalytics[@"totalPatterns"] integerValue];
    
    analysis[@"currentSavedChartDataFiles"] = @(currentFiles);
    analysis[@"totalPatterns"] = @(totalPatterns);
    analysis[@"currentStorageEfficiency"] = sharingAnalytics[@"storageEfficiencyPercent"];
    
    // Theoretical optimal (1 file per symbol+timeframe+hours combination)
    NSMutableSet<NSString *> *uniqueCombinations = [NSMutableSet set];
    NSArray<ChartPatternModel *> *allPatterns = [self getAllPatterns];
    
    for (ChartPatternModel *pattern in allPatterns) {
        SavedChartData *savedData = [pattern loadConnectedSavedData];
        if (savedData) {
            NSString *combination = [NSString stringWithFormat:@"%@_%ld_%@",
                                   savedData.symbol.uppercaseString,
                                   (long)savedData.timeframe,
                                   savedData.includesExtendedHours ? @"EXT" : @"REG"];
            [uniqueCombinations addObject:combination];
        }
    }
    
    NSInteger optimalFiles = uniqueCombinations.count;
    analysis[@"theoreticalOptimalFiles"] = @(optimalFiles);
    
    if (currentFiles > 0) {
        double potentialReduction = ((double)(currentFiles - optimalFiles) / (double)currentFiles) * 100.0;
        analysis[@"potentialStorageReductionPercent"] = @(potentialReduction);
        
        double optimalEfficiency = totalPatterns > 0 ? ((double)totalPatterns / (double)optimalFiles) : 0;
        analysis[@"theoreticalOptimalEfficiency"] = @(optimalEfficiency);
    }
    
    // Find mergeable files
    NSArray *mergeableGroups = [self findMergeableSavedChartDataFiles];
    analysis[@"mergeableGroups"] = @(mergeableGroups.count);
    
    NSInteger filesToMerge = 0;
    for (NSDictionary *group in mergeableGroups) {
        NSArray *files = group[@"files"];
        filesToMerge += files.count;
    }
    analysis[@"filesToMerge"] = @(filesToMerge);
    
    return [analysis copy];
}

/// Log storage optimization analysis
- (void)logSavedChartDataStorageOptimizationAnalysis {
    NSDictionary *analysis = [self analyzeSavedChartDataStorageOptimization];
    
    NSLog(@"\n💾 SAVEDCHARTDATA STORAGE OPTIMIZATION ANALYSIS");
    NSLog(@"================================================");
    NSLog(@"Current Files: %@", analysis[@"currentSavedChartDataFiles"]);
    NSLog(@"Theoretical Optimal: %@", analysis[@"theoreticalOptimalFiles"]);
    NSLog(@"Current Efficiency: %.1f%%", [analysis[@"currentStorageEfficiency"] doubleValue]);
    NSLog(@"Theoretical Max Efficiency: %.1f patterns per file", [analysis[@"theoreticalOptimalEfficiency"] doubleValue]);
    NSLog(@"Potential Storage Reduction: %.1f%%", [analysis[@"potentialStorageReductionPercent"] doubleValue]);
    NSLog(@"Mergeable Groups: %@", analysis[@"mergeableGroups"]);
    NSLog(@"Files That Could Be Merged: %@", analysis[@"filesToMerge"]);
    NSLog(@"================================================\n");
}

/// Find SavedChartData files that could be merged (same symbol, timeframe, extended hours, overlapping dates)
- (NSArray<NSDictionary *> *)findMergeableSavedChartDataFiles {
    NSMutableArray *mergeableGroups = [NSMutableArray array];
    
    // Get all SavedChartData files
    NSString *directory = [ChartWidget savedChartDataDirectory];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSArray<NSString *> *files = [fileManager contentsOfDirectoryAtPath:directory error:&error];
    
    if (!files) {
        NSLog(@"⚠️ Cannot read SavedChartData directory: %@", error.localizedDescription);
        return @[];
    }
    
    NSArray<NSString *> *chartDataFiles = [files filteredArrayUsingPredicate:
        [NSPredicate predicateWithFormat:@"self ENDSWITH '.chartdata'"]];
    
    NSMutableArray<SavedChartData *> *allSavedData = [NSMutableArray array];
    
    // Load all SavedChartData
    for (NSString *filename in chartDataFiles) {
        NSString *filePath = [directory stringByAppendingPathComponent:filename];
        SavedChartData *savedData = [SavedChartData loadFromFile:filePath];
        if (savedData && savedData.isDataValid) {
            [allSavedData addObject:savedData];
        }
    }
    
    // Group by symbol + timeframe + extended hours
    NSMutableDictionary<NSString *, NSMutableArray<SavedChartData *> *> *groups = [NSMutableDictionary dictionary];
    
    for (SavedChartData *savedData in allSavedData) {
        NSString *groupKey = [NSString stringWithFormat:@"%@_%ld_%@",
                             savedData.symbol.uppercaseString,
                             (long)savedData.timeframe,
                             savedData.includesExtendedHours ? @"EXT" : @"REG"];
        
        if (!groups[groupKey]) {
            groups[groupKey] = [NSMutableArray array];
        }
        [groups[groupKey] addObject:savedData];
    }
    
    // Find groups with multiple files that could be merged
    for (NSString *groupKey in groups) {
        NSArray<SavedChartData *> *groupFiles = groups[groupKey];
        if (groupFiles.count > 1) {
            // Check for overlapping or adjacent date ranges
            NSMutableArray *mergeable = [NSMutableArray array];
            for (SavedChartData *savedData in groupFiles) {
                [mergeable addObject:@{
                    @"chartID": savedData.chartID,
                    @"symbol": savedData.symbol,
                    @"timeframe": @(savedData.timeframe),
                    @"includesExtendedHours": @(savedData.includesExtendedHours),
                    @"startDate": savedData.startDate,
                    @"endDate": savedData.endDate,
                    @"barCount": @(savedData.barCount)
                }];
            }
            
            if (mergeable.count > 1) {
                [mergeableGroups addObject:@{
                    @"groupKey": groupKey,
                    @"files": mergeable
                }];
            }
        }
    }
    
    NSLog(@"🔍 Found %ld groups of mergeable SavedChartData files", (long)mergeableGroups.count);
    return [mergeableGroups copy];
}

@end

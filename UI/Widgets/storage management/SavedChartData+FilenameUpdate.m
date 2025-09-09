#import "SavedChartData+FilenameUpdate.h"
#import "SavedChartData+FilenameParsing.h"

@implementation SavedChartData (FilenameUpdate)

- (NSString *)generateCurrentFilename {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyyMMdd"];
    
    NSDateFormatter *dateTimeFormatter = [[NSDateFormatter alloc] init];
    [dateTimeFormatter setDateFormat:@"yyyyMMdd_HHmm"];
    
    NSMutableArray *components = [NSMutableArray array];
    
    [components addObject:self.symbol ?: @"UNKNOWN"];
    [components addObject:[self timeframeToString:self.timeframe]];
    [components addObject:(self.dataType == SavedChartDataTypeContinuous) ? @"continuous" : @"snapshot"];
    
    NSString *startDate = self.startDate ? [dateFormatter stringFromDate:self.startDate] : @"00000000";
    [components addObject:[NSString stringWithFormat:@"s%@", startDate]];
    
    NSString *endDate = self.endDate ? [dateFormatter stringFromDate:self.endDate] : @"00000000";
    [components addObject:[NSString stringWithFormat:@"e%@", endDate]];
    
    [components addObject:[NSString stringWithFormat:@"%ldbars", (long)self.barCount]];
    [components addObject:[NSString stringWithFormat:@"eh%d", self.includesExtendedHours ? 1 : 0]];
    [components addObject:[NSString stringWithFormat:@"g%d", self.hasGaps ? 1 : 0]];
    
    if (self.lastSuccessfulUpdate) {
        NSString *lastUpdate = [dateTimeFormatter stringFromDate:self.lastSuccessfulUpdate];
        [components addObject:[NSString stringWithFormat:@"u%@", lastUpdate]];
    } else {
        [components addObject:@"u00000000_0000"];
    }
    
    NSString *creationDate = self.creationDate ? [dateTimeFormatter stringFromDate:self.creationDate] : [dateTimeFormatter stringFromDate:[NSDate date]];
    [components addObject:[NSString stringWithFormat:@"c%@", creationDate]];
    
    return [[components componentsJoinedByString:@"_"] stringByAppendingString:@".chartdata"];
}

- (NSString *)generateUpdatedFilePath:(NSString *)currentFilePath {
    NSString *directory = [currentFilePath stringByDeletingLastPathComponent];
    NSString *newFilename = [self generateCurrentFilename];
    return [directory stringByAppendingPathComponent:newFilename];
}

- (BOOL)filenameNeedsUpdate:(NSString *)filePath {
    NSString *currentFilename = [filePath lastPathComponent];
    
    if (![SavedChartData isNewFormatFilename:currentFilename]) return YES;
    
    NSString *fileSymbol = [SavedChartData symbolFromFilename:currentFilename];
    NSInteger fileBarCount = [SavedChartData barCountFromFilename:currentFilename];
    NSDate *fileEndDate = [SavedChartData endDateFromFilename:currentFilename];
    NSDate *fileLastUpdate = [SavedChartData lastUpdateFromFilename:currentFilename];
    BOOL fileHasGaps = [SavedChartData hasGapsFromFilename:currentFilename];
    
    if (![fileSymbol isEqualToString:self.symbol]) return YES;
    if (fileBarCount != self.barCount) return YES;
    if (fileEndDate && self.endDate && ![self datesAreEqual:fileEndDate other:self.endDate]) return YES;
    if (fileLastUpdate && self.lastSuccessfulUpdate && ![self datesAreEqual:fileLastUpdate other:self.lastSuccessfulUpdate]) return YES;
    if (fileHasGaps != self.hasGaps) return YES;
    
    return NO;
}

- (nullable NSString *)updateFilenameMetadata:(NSString *)currentFilePath error:(NSError **)error {
    if (![self filenameNeedsUpdate:currentFilePath]) return currentFilePath;
    
    NSString *newFilePath = [self generateUpdatedFilePath:currentFilePath];
    if ([currentFilePath isEqualToString:newFilePath]) return currentFilePath;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:newFilePath]) {
        if (error) {
            *error = [NSError errorWithDomain:@"FilenameUpdate" code:1001
                                     userInfo:@{NSLocalizedDescriptionKey:
                                               [NSString stringWithFormat:@"Target file already exists: %@", [newFilePath lastPathComponent]]}];
        }
        return nil;
    }
    
    NSError *renameError;
    BOOL renameSuccess = [[NSFileManager defaultManager] moveItemAtPath:currentFilePath toPath:newFilePath error:&renameError];
    
    if (renameSuccess) {
        NSLog(@"✅ Updated filename: %@ → %@", [currentFilePath lastPathComponent], [newFilePath lastPathComponent]);
        return newFilePath;
    } else {
        if (error) *error = renameError;
        return nil;
    }
}

- (nullable NSString *)saveToFileWithFilenameUpdate:(NSString *)filePath error:(NSError **)error {
    BOOL saveSuccess = [self saveToFile:filePath error:error];
    if (!saveSuccess) return nil;
    
    NSString *updatedFilePath = [self updateFilenameMetadata:filePath error:error];
    if (!updatedFilePath) {
        NSLog(@"⚠️ Save succeeded but filename update failed for: %@", [filePath lastPathComponent]);
        return filePath;
    }
    
    return updatedFilePath;
}

#pragma mark - Helper Methods

- (NSString *)timeframeToString:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Min: return @"1min";
        case BarTimeframe5Min: return @"5min";
        case BarTimeframe15Min: return @"15min";
        case BarTimeframe30Min: return @"30min";
        case BarTimeframe1Hour: return @"1h";
        case BarTimeframe4Hour: return @"4h";
        case BarTimeframeDaily: return @"1d";
        case BarTimeframeWeekly: return @"1w";
        case BarTimeframeMonthly: return @"1M";
        default: return @"unknown";
    }
}

- (BOOL)datesAreEqual:(NSDate *)date1 other:(NSDate *)date2 {
    if (!date1 && !date2) return YES;
    if (!date1 || !date2) return NO;
    return fabs([date1 timeIntervalSinceDate:date2]) < 60.0;
}

@end

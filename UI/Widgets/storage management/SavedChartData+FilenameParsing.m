#import "SavedChartData+FilenameParsing.h"

@implementation SavedChartData (FilenameParsing)

+ (nullable NSString *)symbolFromFilename:(NSString *)filename {
    if (![self isNewFormatFilename:filename]) return nil;
    NSArray *components = [[filename stringByDeletingPathExtension] componentsSeparatedByString:@"_"];
    return components.count > 0 ? components[0] : nil;
}

+ (nullable NSString *)timeframeFromFilename:(NSString *)filename {
    if (![self isNewFormatFilename:filename]) return nil;
    NSArray *components = [[filename stringByDeletingPathExtension] componentsSeparatedByString:@"_"];
    return components.count > 1 ? components[1] : nil;
}

+ (BarTimeframe)timeframeEnumFromFilename:(NSString *)filename {
    NSString *timeframeStr = [self timeframeFromFilename:filename];
    if (!timeframeStr) return BarTimeframeDaily;
    
    // ✅ USA IL METODO CANONICO INVERSO
    return [SavedChartData timeframeFromCanonicalString:timeframeStr];
}

+ (nullable NSString *)typeFromFilename:(NSString *)filename {
    if (![self isNewFormatFilename:filename]) return nil;
    NSArray *components = [[filename stringByDeletingPathExtension] componentsSeparatedByString:@"_"];
    if (components.count <= 2) return nil;
    
    NSString *typeStr = components[2];
    if ([typeStr isEqualToString:@"continuous"]) return @"Continuous";
    if ([typeStr isEqualToString:@"snapshot"]) return @"Snapshot";
    return typeStr;
}

+ (NSInteger)barCountFromFilename:(NSString *)filename {
    if (![self isNewFormatFilename:filename]) return 0;
    NSArray *components = [[filename stringByDeletingPathExtension] componentsSeparatedByString:@"_"];
    
    for (NSString *component in components) {
        if ([component hasSuffix:@"bars"]) {
            NSString *numberStr = [component stringByReplacingOccurrencesOfString:@"bars" withString:@""];
            return [numberStr integerValue];
        }
    }
    return 0;
}

+ (nullable NSDate *)startDateFromFilename:(NSString *)filename {
    if (![self isNewFormatFilename:filename]) return nil;
    NSArray *components = [[filename stringByDeletingPathExtension] componentsSeparatedByString:@"_"];
    
    for (NSString *component in components) {
        if ([component hasPrefix:@"s"] && component.length == 9) {
            NSString *dateStr = [component substringFromIndex:1];
            return [self parseDateFromString:dateStr];
        }
    }
    return nil;
}

+ (nullable NSDate *)endDateFromFilename:(NSString *)filename {
    if (![self isNewFormatFilename:filename]) return nil;
    NSArray *components = [[filename stringByDeletingPathExtension] componentsSeparatedByString:@"_"];
    
    for (NSString *component in components) {
        if ([component hasPrefix:@"e"] && component.length == 9) {
            NSString *dateStr = [component substringFromIndex:1];
            return [self parseDateFromString:dateStr];
        }
    }
    return nil;
}

+ (nullable NSString *)dateRangeStringFromFilename:(NSString *)filename {
    NSDate *startDate = [self startDateFromFilename:filename];
    NSDate *endDate = [self endDateFromFilename:filename];
    
    if (!startDate || !endDate) return nil;
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterShortStyle;
    formatter.timeStyle = NSDateFormatterNoStyle;
    
    return [NSString stringWithFormat:@"%@ - %@",
            [formatter stringFromDate:startDate],
            [formatter stringFromDate:endDate]];
}

+ (BOOL)extendedHoursFromFilename:(NSString *)filename {
    if (![self isNewFormatFilename:filename]) return NO;
    NSArray *components = [[filename stringByDeletingPathExtension] componentsSeparatedByString:@"_"];
    
    for (NSString *component in components) {
        if ([component hasPrefix:@"eh"] && component.length >= 3) {
            NSString *flagStr = [component substringFromIndex:2];
            return [flagStr boolValue];
        }
    }
    return NO;
}

+ (BOOL)hasGapsFromFilename:(NSString *)filename {
    if (![self isNewFormatFilename:filename]) return NO;
    NSArray *components = [[filename stringByDeletingPathExtension] componentsSeparatedByString:@"_"];
    
    for (NSString *component in components) {
        if ([component hasPrefix:@"g"] && component.length >= 2) {
            NSString *flagStr = [component substringFromIndex:1];
            return [flagStr boolValue];
        }
    }
    return NO;
}

+ (nullable NSDate *)creationDateFromFilename:(NSString *)filename {
    if (![self isNewFormatFilename:filename]) return nil;
    NSArray *components = [[filename stringByDeletingPathExtension] componentsSeparatedByString:@"_"];
    
    for (NSString *component in components) {
        if ([component hasPrefix:@"c"] && component.length == 14) {
            NSString *dateTimeStr = [component substringFromIndex:1];
            return [self parseDateTimeFromString:dateTimeStr];
        }
    }
    return nil;
}

+ (nullable NSDate *)lastUpdateFromFilename:(NSString *)filename {
    if (![self isNewFormatFilename:filename]) return nil;
    NSArray *components = [[filename stringByDeletingPathExtension] componentsSeparatedByString:@"_"];
    
    for (NSString *component in components) {
        if ([component hasPrefix:@"u"] && component.length == 14) {
            NSString *dateTimeStr = [component substringFromIndex:1];
            return [self parseDateTimeFromString:dateTimeStr];
        }
    }
    return nil;
}

+ (NSInteger)fileSizeFromPath:(NSString *)filePath {
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
    return attributes ? [attributes[NSFileSize] integerValue] : 0;
}

+ (BOOL)isNewFormatFilename:(NSString *)filename {
    return [filename containsString:@"_s"] &&
           [filename containsString:@"_e"] &&
           [filename containsString:@"bars"];
}

#pragma mark - Helper Methods

+ (nullable NSDate *)parseDateFromString:(NSString *)dateString {
    if (dateString.length != 8) return nil;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMdd"];
    return [formatter dateFromString:dateString];
}

+ (nullable NSDate *)parseDateTimeFromString:(NSString *)dateTimeString {
    if (dateTimeString.length != 13) return nil;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMdd_HHmm"];
    return [formatter dateFromString:dateTimeString];
}

@end

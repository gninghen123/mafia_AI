//
//  OtherDataAdapter.m
//  TradingApp
//

#import "OtherDataAdapter.h"
#import "MarketData.h"
#import "RuntimeModels.h"

@implementation OtherDataAdapter

#pragma mark - DataSourceAdapter Protocol (Required - Minimal Implementation)

- (MarketData *)standardizeQuoteData:(NSDictionary *)rawData forSymbol:(NSString *)symbol {
    // OtherDataSource doesn't provide real-time quotes
    // This is just protocol compliance - return nil
    return nil;
}

- (NSArray<HistoricalBarModel *> *)standardizeHistoricalData:(id)rawData forSymbol:(NSString *)symbol {
    // OtherDataSource doesn't provide historical bars
    // This is just protocol compliance - return empty array
    return @[];
}

- (NSDictionary *)standardizeOrderBookData:(id)rawData forSymbol:(NSString *)symbol {
    // OtherDataSource doesn't provide order book data
    // This is just protocol compliance - return empty
    return @{@"bids": @[], @"asks": @[]};
}

- (id)standardizePositionData:(NSDictionary *)rawData {
    // Not implemented
    return nil;
}

- (id)standardizeOrderData:(NSDictionary *)rawData {
    // Not implemented
    return nil;
}

- (NSString *)sourceName {
    return @"OtherDataSource";
}

#pragma mark - Zacks Data Conversion (MAIN FUNCTIONALITY)

- (SeasonalDataModel *)convertZacksChartToSeasonalModel:(NSDictionary *)rawData
                                                 symbol:(NSString *)symbol
                                               dataType:(NSString *)dataType {
    
    if (!rawData || ![rawData isKindOfClass:[NSDictionary class]]) {
        NSLog(@"❌ OtherDataAdapter: Invalid raw data format from Zacks");
        return nil;
    }
    
    if (!symbol || !dataType) {
        NSLog(@"❌ OtherDataAdapter: Missing symbol or dataType");
        return nil;
    }
    
    // Zacks format: {"revenue": {"06/30/25": "95359.0", "03/31/25": "124300", ...}}
    NSDictionary *dataTypeDict = rawData[dataType];
    if (!dataTypeDict || ![dataTypeDict isKindOfClass:[NSDictionary class]]) {
        NSLog(@"❌ OtherDataAdapter: No data found for dataType '%@' in Zacks response", dataType);
        NSLog(@"Available keys: %@", rawData.allKeys);
        return nil;
    }
    
    NSMutableArray<QuarterlyDataPoint *> *quarters = [NSMutableArray array];
    
    // Itera attraverso il dizionario {date: value}
    for (NSString *dateString in dataTypeDict.allKeys) {
        NSString *valueString = dataTypeDict[dateString];
        
        // Salta valori "N/A"
        if (!valueString || [valueString isEqualToString:@"N/A"]) {
            continue;
        }
        
        // Parse del valore
        NSNumber *valueNum = [self safeNumber:valueString];
        if (!valueNum) {
            NSLog(@"⚠️ OtherDataAdapter: Invalid value '%@' for date '%@'", valueString, dateString);
            continue;
        }
        
        // Parse della data da MM/dd/yy a quarter/year
        NSInteger quarter, year;
        if (![self parseZacksDate:dateString toQuarter:&quarter year:&year]) {
            NSLog(@"⚠️ OtherDataAdapter: Failed to parse date '%@'", dateString);
            continue;
        }
        
        // Crea QuarterlyDataPoint
        QuarterlyDataPoint *quarterlyPoint = [QuarterlyDataPoint dataPointWithQuarter:quarter
                                                                                 year:year
                                                                                value:valueNum.doubleValue];
        [quarters addObject:quarterlyPoint];
        
        NSLog(@"✅ Parsed %@ -> Q%ld'%ld: %.2f", dateString, (long)quarter, (long)year, valueNum.doubleValue);
    }
    
    if (quarters.count == 0) {
        NSLog(@"❌ OtherDataAdapter: No valid quarterly data points found");
        return nil;
    }
    
    // Crea SeasonalDataModel
    SeasonalDataModel *seasonalModel = [SeasonalDataModel modelWithSymbol:symbol
                                                                 dataType:dataType
                                                                 quarters:quarters];
    
    // Set metadata
    seasonalModel.currency = @"USD";
    seasonalModel.units = @"millions"; // Zacks typically uses millions
    
    NSLog(@"✅ OtherDataAdapter: Created SeasonalDataModel for %@ %@ with %lu quarters",
          symbol, dataType, (unsigned long)quarters.count);
    
    return seasonalModel;
}

- (BOOL)parseZacksDate:(NSString *)dateString toQuarter:(NSInteger *)outQuarter year:(NSInteger *)outYear {
    if (!dateString || dateString.length == 0) return NO;
    
    // Formato Zacks: "MM/dd/yy" o "MM/dd/yyyy"
    // Esempi: "06/30/25", "03/31/25", "12/31/24"
    
    NSArray *components = [dateString componentsSeparatedByString:@"/"];
    if (components.count != 3) return NO;
    
    NSInteger month = [components[0] integerValue];
    NSInteger day = [components[1] integerValue];
    NSInteger year = [components[2] integerValue];
    
    // Convert 2-digit year to 4-digit
    if (year < 100) {
        year += (year < 50) ? 2000 : 1900;
    }
    
    // Map month to quarter based on typical fiscal quarter end dates
    NSInteger quarter;
    
    // Apple's fiscal year ends in September, but most companies use calendar quarters
    // Q1: Jan-Mar (ends 03/31)
    // Q2: Apr-Jun (ends 06/30)
    // Q3: Jul-Sep (ends 09/30)
    // Q4: Oct-Dec (ends 12/31)
    
    if (month <= 3) {
        quarter = 1;
    } else if (month <= 6) {
        quarter = 2;
    } else if (month <= 9) {
        quarter = 3;
    } else {
        quarter = 4;
    }
    
    *outQuarter = quarter;
    *outYear = year;
    
    return YES;
}
#pragma mark - Helper Methods

- (NSString *)extractPeriodString:(NSDictionary *)dataPoint {
    // Try various keys for period information
    NSArray *periodKeys = @[@"period", @"date", @"quarter", @"fiscalPeriod", @"time"];
    
    for (NSString *key in periodKeys) {
        NSString *value = [self safeString:dataPoint[key]];
        if (value.length > 0) {
            return value;
        }
    }
    
    return nil;
}

- (NSNumber *)extractValue:(NSDictionary *)dataPoint forDataType:(NSString *)dataType {
    // Try the specific dataType key first
    NSNumber *value = [self safeNumber:dataPoint[dataType]];
    if (value) return value;
    
    // Try common value keys
    NSArray *valueKeys = @[@"value", @"amount", @"total", @"revenue", @"eps", @"earnings"];
    
    for (NSString *key in valueKeys) {
        value = [self safeNumber:dataPoint[key]];
        if (value) return value;
    }
    
    return nil;
}

- (BOOL)parseQuarterAndYear:(NSInteger *)outQuarter year:(NSInteger *)outYear fromPeriod:(NSString *)period {
    if (!period || period.length == 0) return NO;
    
    // Handle formats like "Q1 2024", "Q1'24", "2024-Q1", "1Q24", etc.
    NSString *upperPeriod = [period uppercaseString];
    
    // Try regex patterns
    NSArray *patterns = @[
        @"Q(\\d)\\s*'?(\\d{2,4})",           // Q1'24, Q1 2024
        @"(\\d{4})\\s*-?\\s*Q(\\d)",         // 2024-Q1, 2024Q1
        @"(\\d)Q(\\d{2,4})",                 // 1Q24
        @"FY(\\d{4})\\s*Q(\\d)"              // FY2024 Q1
    ];
    
    for (NSString *pattern in patterns) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                               options:0
                                                                                 error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:upperPeriod
                                                        options:0
                                                          range:NSMakeRange(0, upperPeriod.length)];
        
        if (match) {
            if (match.numberOfRanges >= 3) {
                NSString *quarterStr, *yearStr;
                
                // Determine which capture group is quarter vs year based on pattern
                NSString *firstCapture = [upperPeriod substringWithRange:[match rangeAtIndex:1]];
                NSString *secondCapture = [upperPeriod substringWithRange:[match rangeAtIndex:2]];
                
                if (firstCapture.integerValue >= 1 && firstCapture.integerValue <= 4) {
                    quarterStr = firstCapture;
                    yearStr = secondCapture;
                } else {
                    quarterStr = secondCapture;
                    yearStr = firstCapture;
                }
                
                *outQuarter = quarterStr.integerValue;
                NSInteger year = yearStr.integerValue;
                
                // Convert 2-digit year to 4-digit
                if (year < 100) {
                    year += (year < 50) ? 2000 : 1900;
                }
                *outYear = year;
                
                return (*outQuarter >= 1 && *outQuarter <= 4 && *outYear > 1900);
            }
        }
    }
    
    return NO;
}

- (NSString *)safeString:(id)value {
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value stringValue];
    }
    return nil;
}

- (NSNumber *)safeNumber:(id)value {
    if ([value isKindOfClass:[NSNumber class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString *str = [(NSString *)value stringByReplacingOccurrencesOfString:@"," withString:@""];
        str = [str stringByReplacingOccurrencesOfString:@"$" withString:@""];
        str = [str stringByReplacingOccurrencesOfString:@"%" withString:@""];
        str = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (str.length == 0 || [str isEqualToString:@"N/A"]) {
            return nil;
        }
        
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        return [formatter numberFromString:str];
    }
    return nil;
}
@end

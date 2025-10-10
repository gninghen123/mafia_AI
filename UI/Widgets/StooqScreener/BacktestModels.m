//
//  BacktestModels.m
//  TradingApp
//

#import "BacktestModels.h"

#pragma mark - DailyBacktestResult Implementation

@implementation DailyBacktestResult

+ (instancetype)resultWithDate:(NSDate *)date
                     modelName:(NSString *)modelName
                       modelID:(NSString *)modelID
               screenedSymbols:(NSArray<ScreenedSymbol *> *)symbols {
    
    DailyBacktestResult *result = [[DailyBacktestResult alloc] init];
    result.date = date;
    result.modelName = modelName;
    result.modelID = modelID;
    result.screenedSymbols = symbols;
    result.symbolCount = symbols.count;
    
    // Initialize other stats to 0
    result.winRate = 0.0;
    result.avgGain = 0.0;
    result.avgLoss = 0.0;
    result.tradeCount = 0;
    result.winLossRatio = 0.0;
    result.executionTime = 0.0;
    
    return result;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<DailyBacktestResult: %@ | %@ | %ld symbols>",
            self.date, self.modelName, (long)self.symbolCount];
}

@end

#pragma mark - BacktestSession Implementation

@implementation BacktestSession

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _sessionID = [[NSUUID UUID] UUIDString];
        _createdAt = [NSDate date];
        _models = @[];
        _dailyResults = @[];
        _benchmarkBars = @[];
    }
    return self;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.sessionID forKey:@"sessionID"];
    [coder encodeObject:self.createdAt forKey:@"createdAt"];
    [coder encodeObject:self.startDate forKey:@"startDate"];
    [coder encodeObject:self.endDate forKey:@"endDate"];
    [coder encodeObject:self.benchmarkSymbol forKey:@"benchmarkSymbol"];
    [coder encodeObject:self.benchmarkBars forKey:@"benchmarkBars"];
    [coder encodeObject:self.models forKey:@"models"];
    [coder encodeObject:self.dailyResults forKey:@"dailyResults"];
    [coder encodeDouble:self.totalExecutionTime forKey:@"totalExecutionTime"];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _sessionID = [coder decodeObjectOfClass:[NSString class] forKey:@"sessionID"];
        _createdAt = [coder decodeObjectOfClass:[NSDate class] forKey:@"createdAt"];
        _startDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"startDate"];
        _endDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"endDate"];
        _benchmarkSymbol = [coder decodeObjectOfClass:[NSString class] forKey:@"benchmarkSymbol"];
        _benchmarkBars = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [HistoricalBarModel class], nil]
                                               forKey:@"benchmarkBars"];
        _models = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [ScreenerModel class], nil]
                                        forKey:@"models"];
        _dailyResults = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [DailyBacktestResult class], nil]
                                              forKey:@"dailyResults"];
        _totalExecutionTime = [coder decodeDoubleForKey:@"totalExecutionTime"];
    }
    return self;
}

#pragma mark - Computed Properties

- (NSInteger)tradingDaysCount {
    NSSet *uniqueDates = [NSSet setWithArray:[self.dailyResults valueForKey:@"date"]];
    return uniqueDates.count;
}

#pragma mark - Convenience Methods

- (NSArray<DailyBacktestResult *> *)resultsForModelID:(NSString *)modelID {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"modelID == %@", modelID];
    return [self.dailyResults filteredArrayUsingPredicate:predicate];
}

- (NSArray<DailyBacktestResult *> *)resultsForDate:(NSDate *)date {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(DailyBacktestResult *result, NSDictionary *bindings) {
        return [result.date compare:date] == NSOrderedSame;
    }];
    return [self.dailyResults filteredArrayUsingPredicate:predicate];
}

- (NSArray<NSDate *> *)allDates {
    // Extract unique dates and sort
    NSMutableSet *dateSet = [NSMutableSet set];
    for (DailyBacktestResult *result in self.dailyResults) {
        [dateSet addObject:result.date];
    }
    
    NSArray *dates = [dateSet allObjects];
    return [dates sortedArrayUsingComparator:^NSComparisonResult(NSDate *date1, NSDate *date2) {
        return [date1 compare:date2];
    }];
}

- (nullable HistoricalBarModel *)benchmarkBarForDate:(NSDate *)date {
    for (HistoricalBarModel *bar in self.benchmarkBars) {
        if ([bar.date compare:date] == NSOrderedSame) {
            return bar;
        }
    }
    return nil;
}

#pragma mark - Persistence

- (BOOL)saveToPath:(NSString *)path error:(NSError **)error {
    @try {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self
                                             requiringSecureCoding:YES
                                                             error:error];
        if (!data) {
            return NO;
        }
        
        return [data writeToFile:path options:NSDataWritingAtomic error:error];
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:@"BacktestSession"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Save failed"}];
        }
        return NO;
    }
}

+ (nullable instancetype)loadFromPath:(NSString *)path error:(NSError **)error {
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:error];
    if (!data) {
        return nil;
    }
    
    @try {
        NSSet *classes = [NSSet setWithObjects:
                         [BacktestSession class],
                         [DailyBacktestResult class],
                         [ScreenerModel class],
                         [ScreenerStep class],
                         [ScreenedSymbol class],
                         [HistoricalBarModel class],
                         [NSArray class],
                         [NSDictionary class],
                         [NSString class],
                         [NSDate class],
                         [NSNumber class],
                         nil];
        
        return [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                   fromData:data
                                                      error:error];
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:@"BacktestSession"
                                         code:-2
                                     userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Load failed"}];
        }
        return nil;
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<BacktestSession: %@ | %@ to %@ | %ld models | %ld results>",
            self.sessionID, self.startDate, self.endDate,
            (long)self.models.count, (long)self.dailyResults.count];
}

@end

#pragma mark - BacktestStatisticsCalculator Implementation

@implementation BacktestStatisticsCalculator

+ (CGFloat)calculateWinRateForSymbols:(NSArray<NSString *> *)symbols
                            startDate:(NSDate *)startDate
                        holdingPeriod:(NSInteger)holdingPeriod
                            priceData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)priceData {
    
    if (symbols.count == 0) {
        return 0.0;
    }
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *exitDate = [calendar dateByAddingUnit:NSCalendarUnitDay
                                             value:holdingPeriod
                                            toDate:startDate
                                           options:0];
    
    NSInteger winners = 0;
    NSInteger totalTrades = 0;
    
    for (NSString *symbol in symbols) {
        NSArray<HistoricalBarModel *> *bars = priceData[symbol];
        if (!bars || bars.count < 2) continue;
        
        // Find entry bar (at or after startDate)
        HistoricalBarModel *entryBar = [self findBarOnOrAfter:startDate inBars:bars];
        if (!entryBar) continue;
        
        // Find exit bar (at or after exitDate)
        HistoricalBarModel *exitBar = [self findBarOnOrAfter:exitDate inBars:bars];
        if (!exitBar) continue;
        
        // Calculate return
        double entryPrice = entryBar.close;
        double exitPrice = exitBar.close;
        double returnPercent = ((exitPrice - entryPrice) / entryPrice) * 100.0;
        
        if (returnPercent > 0) {
            winners++;
        }
        totalTrades++;
    }
    
    if (totalTrades == 0) {
        return 0.0;
    }
    
    return (CGFloat)(winners * 100.0 / totalTrades);
}

+ (NSDictionary<NSString *, NSNumber *> *)calculateReturnsForSymbols:(NSArray<NSString *> *)symbols
                                                           startDate:(NSDate *)startDate
                                                       holdingPeriod:(NSInteger)holdingPeriod
                                                           priceData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)priceData {
    
    if (symbols.count == 0) {
        return @{@"avgGain": @0.0, @"avgLoss": @0.0};
    }
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *exitDate = [calendar dateByAddingUnit:NSCalendarUnitDay
                                             value:holdingPeriod
                                            toDate:startDate
                                           options:0];
    
    NSMutableArray *gains = [NSMutableArray array];
    NSMutableArray *losses = [NSMutableArray array];
    
    for (NSString *symbol in symbols) {
        NSArray<HistoricalBarModel *> *bars = priceData[symbol];
        if (!bars || bars.count < 2) continue;
        
        HistoricalBarModel *entryBar = [self findBarOnOrAfter:startDate inBars:bars];
        if (!entryBar) continue;
        
        HistoricalBarModel *exitBar = [self findBarOnOrAfter:exitDate inBars:bars];
        if (!exitBar) continue;
        
        double returnPercent = ((exitBar.close - entryBar.close) / entryBar.close) * 100.0;
        
        if (returnPercent > 0) {
            [gains addObject:@(returnPercent)];
        } else {
            [losses addObject:@(returnPercent)];
        }
    }
    
    // Calculate averages
    double avgGain = 0.0;
    if (gains.count > 0) {
        double sum = 0.0;
        for (NSNumber *num in gains) {
            sum += num.doubleValue;
        }
        avgGain = sum / gains.count;
    }
    
    double avgLoss = 0.0;
    if (losses.count > 0) {
        double sum = 0.0;
        for (NSNumber *num in losses) {
            sum += num.doubleValue;
        }
        avgLoss = sum / losses.count;
    }
    
    return @{
        @"avgGain": @(avgGain),
        @"avgLoss": @(avgLoss)
    };
}

#pragma mark - Helper Methods

+ (nullable HistoricalBarModel *)findBarOnOrAfter:(NSDate *)date
                                           inBars:(NSArray<HistoricalBarModel *> *)bars {
    
    for (HistoricalBarModel *bar in bars) {
        if ([bar.date compare:date] != NSOrderedAscending) {
            return bar;
        }
    }
    return nil;
}

@end

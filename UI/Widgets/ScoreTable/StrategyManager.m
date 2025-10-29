//
//  StrategyManager.m
//  TradingApp
//

#import "StrategyManager.h"

@interface StrategyManager ()
@property (nonatomic, strong) NSMutableArray<ScoringStrategy *> *strategies;
@property (nonatomic, strong) NSString *strategiesPath;
@end

@implementation StrategyManager

+ (instancetype)sharedManager {
    static StrategyManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[StrategyManager alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _strategies = [NSMutableArray array];
        
        // Setup strategies directory
        NSString *appSupport = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
        NSString *appDir = [appSupport stringByAppendingPathComponent:@"TradingApp"];
        _strategiesPath = [appDir stringByAppendingPathComponent:@"ScoringStrategies"];
        
        // Create directory if needed
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:_strategiesPath]) {
            NSError *error;
            [fm createDirectoryAtPath:_strategiesPath
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&error];
            if (error) {
                NSLog(@"❌ Failed to create strategies directory: %@", error);
            } else {
                NSLog(@"✅ Created strategies directory: %@", _strategiesPath);
            }
        }
        
        // Load existing strategies
        [self reloadStrategies];
        
        // Ensure at least default strategy exists
        [self ensureDefaultStrategy];
    }
    return self;
}

#pragma mark - Strategy CRUD

- (NSArray<ScoringStrategy *> *)allStrategies {
    return [self.strategies copy];
}

- (ScoringStrategy *)strategyWithId:(NSString *)strategyId {
    for (ScoringStrategy *strategy in self.strategies) {
        if ([strategy.strategyId isEqualToString:strategyId]) {
            return strategy;
        }
    }
    return nil;
}

- (ScoringStrategy *)strategyWithName:(NSString *)name {
    for (ScoringStrategy *strategy in self.strategies) {
        if ([strategy.strategyName isEqualToString:name]) {
            return strategy;
        }
    }
    return nil;
}

- (BOOL)saveStrategy:(ScoringStrategy *)strategy error:(NSError **)error {
    if (!strategy.isValid) {
        if (error) {
            *error = [NSError errorWithDomain:@"StrategyManager"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Strategy is not valid"}];
        }
        return NO;
    }
    
    // Update modification date
    strategy.dateModified = [NSDate date];
    
    // Add or update in memory
    NSInteger existingIndex = -1;
    for (NSInteger i = 0; i < self.strategies.count; i++) {
        if ([self.strategies[i].strategyId isEqualToString:strategy.strategyId]) {
            existingIndex = i;
            break;
        }
    }
    
    if (existingIndex >= 0) {
        self.strategies[existingIndex] = strategy;
        NSLog(@"📝 Updated strategy: %@", strategy.strategyName);
    } else {
        [self.strategies addObject:strategy];
        NSLog(@"➕ Added new strategy: %@", strategy.strategyName);
    }
    
    // Save to disk
    return [self saveStrategyToDisk:strategy error:error];
}

- (BOOL)deleteStrategy:(NSString *)strategyId error:(NSError **)error {
    // Remove from memory
    NSInteger indexToRemove = -1;
    for (NSInteger i = 0; i < self.strategies.count; i++) {
        if ([self.strategies[i].strategyId isEqualToString:strategyId]) {
            indexToRemove = i;
            break;
        }
    }
    
    if (indexToRemove < 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"StrategyManager"
                                         code:1002
                                     userInfo:@{NSLocalizedDescriptionKey: @"Strategy not found"}];
        }
        return NO;
    }
    
    ScoringStrategy *strategy = self.strategies[indexToRemove];
    [self.strategies removeObjectAtIndex:indexToRemove];
    
    // Delete from disk
    NSString *filename = [NSString stringWithFormat:@"%@.json", strategyId];
    NSString *filePath = [self.strategiesPath stringByAppendingPathComponent:filename];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:filePath]) {
        return [fm removeItemAtPath:filePath error:error];
    }
    
    NSLog(@"🗑️ Deleted strategy: %@", strategy.strategyName);
    return YES;
}

#pragma mark - Built-in Strategies

- (ScoringStrategy *)defaultStrategy {
    // Check if default already exists
    ScoringStrategy *existing = [self strategyWithName:@"Default Strategy"];
    if (existing) return existing;
    
    // Create default strategy with all 6 indicators
    ScoringStrategy *strategy = [ScoringStrategy strategyWithName:@"Default Strategy"];
    
    // Equal weight for all indicators (16.67% each ≈ 100/6)
    CGFloat equalWeight = 100.0 / 6.0;
    
    IndicatorConfig *dollarVolume = [[IndicatorConfig alloc] initWithType:@"DollarVolume"
                                                               displayName:@"Dollar Volume"
                                                                    weight:equalWeight
                                                                parameters:@{@"threshold": @(10000000)}];
    
    IndicatorConfig *ascendingLows = [[IndicatorConfig alloc] initWithType:@"AscendingLows"
                                                                displayName:@"Ascending Lows"
                                                                     weight:equalWeight
                                                                 parameters:@{@"lookbackDays": @(5)}];
    
    IndicatorConfig *bearTrap = [[IndicatorConfig alloc] initWithType:@"BearTrap"
                                                           displayName:@"Bear Trap"
                                                                weight:equalWeight
                                                            parameters:@{}];
    
    IndicatorConfig *unr = [[IndicatorConfig alloc] initWithType:@"UNR"
                                                      displayName:@"UNR (EMA 10)"
                                                           weight:equalWeight
                                                       parameters:@{@"maType": @"EMA",
                                                                   @"maPeriod": @(10),
                                                                   @"lookbackDays": @(5),
                                                                   @"sameBarWeight": @(1.0),
                                                                   @"nextBarWeight": @(0.7)}];
    
    IndicatorConfig *priceVsMA = [[IndicatorConfig alloc] initWithType:@"PriceVsMA"
                                                            displayName:@"Close > EMA(10)"
                                                                 weight:equalWeight
                                                             parameters:@{@"maType": @"EMA",
                                                                         @"maPeriod": @(10),
                                                                         @"pricePoints": @[@"close"],
                                                                         @"condition": @"above"}];
    
    IndicatorConfig *volumeSpike = [[IndicatorConfig alloc] initWithType:@"VolumeSpike"
                                                              displayName:@"Volume Spike"
                                                                   weight:equalWeight
                                                               parameters:@{@"volumeMAPeriod": @(20)}];
    
    [strategy addIndicator:dollarVolume];
    [strategy addIndicator:ascendingLows];
    [strategy addIndicator:bearTrap];
    [strategy addIndicator:unr];
    [strategy addIndicator:priceVsMA];
    [strategy addIndicator:volumeSpike];
    
    // Save it
    [self saveStrategy:strategy error:nil];
    
    NSLog(@"✅ Created default strategy with %lu indicators", (unsigned long)strategy.indicators.count);
    
    return strategy;
}

- (NSArray<ScoringStrategy *> *)builtInStrategies {
    // For now, only default strategy is built-in
    // In future, can add more presets here
    return @[[self defaultStrategy]];
}

- (void)ensureDefaultStrategy {
    if (self.strategies.count == 0) {
        [self defaultStrategy]; // Will create and save it
    }
}

#pragma mark - Persistence

- (void)reloadStrategies {
    [self.strategies removeAllObjects];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:self.strategiesPath error:&error];
    
    if (error) {
        NSLog(@"⚠️ Error reading strategies directory: %@", error);
        return;
    }
    
    NSInteger loadedCount = 0;
    for (NSString *filename in files) {
        if (![filename hasSuffix:@".json"]) continue;
        
        NSString *filePath = [self.strategiesPath stringByAppendingPathComponent:filename];
        ScoringStrategy *strategy = [self loadStrategyFromFile:filePath];
        
        if (strategy) {
            [self.strategies addObject:strategy];
            loadedCount++;
        }
    }
    
    NSLog(@"📂 Loaded %ld strategies from disk", (long)loadedCount);
}

- (NSString *)strategiesDirectory {
    return self.strategiesPath;
}

#pragma mark - File I/O

- (BOOL)saveStrategyToDisk:(ScoringStrategy *)strategy error:(NSError **)error {
    NSString *filename = [NSString stringWithFormat:@"%@.json", strategy.strategyId];
    NSString *filePath = [self.strategiesPath stringByAppendingPathComponent:filename];
    
    // Convert to JSON
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"strategyId"] = strategy.strategyId;
    dict[@"strategyName"] = strategy.strategyName;
    dict[@"dateCreated"] = @([strategy.dateCreated timeIntervalSince1970]);
    dict[@"dateModified"] = @([strategy.dateModified timeIntervalSince1970]);
    
    NSMutableArray *indicatorsArray = [NSMutableArray array];
    for (IndicatorConfig *indicator in strategy.indicators) {
        NSDictionary *indicatorDict = @{
            @"indicatorType": indicator.indicatorType,
            @"displayName": indicator.displayName,
            @"weight": @(indicator.weight),
            @"parameters": indicator.parameters ?: @{},
            @"isEnabled": @(indicator.isEnabled)
        };
        [indicatorsArray addObject:indicatorDict];
    }
    dict[@"indicators"] = indicatorsArray;
    
    // Write to file
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:error];
    if (!jsonData) {
        NSLog(@"❌ Failed to serialize strategy: %@", *error);
        return NO;
    }
    
    BOOL success = [jsonData writeToFile:filePath options:NSDataWritingAtomic error:error];
    if (success) {
        NSLog(@"💾 Saved strategy to: %@", filePath);
    } else {
        NSLog(@"❌ Failed to save strategy: %@", *error);
    }
    
    return success;
}

- (nullable ScoringStrategy *)loadStrategyFromFile:(NSString *)filePath {
    NSError *error;
    NSData *jsonData = [NSData dataWithContentsOfFile:filePath options:0 error:&error];
    
    if (!jsonData) {
        NSLog(@"⚠️ Failed to read strategy file: %@", error);
        return nil;
    }
    
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (!dict) {
        NSLog(@"⚠️ Failed to parse strategy JSON: %@", error);
        return nil;
    }
    
    // Reconstruct strategy
    ScoringStrategy *strategy = [[ScoringStrategy alloc] init];
    strategy.strategyId = dict[@"strategyId"];
    strategy.strategyName = dict[@"strategyName"];
    strategy.dateCreated = [NSDate dateWithTimeIntervalSince1970:[dict[@"dateCreated"] doubleValue]];
    strategy.dateModified = [NSDate dateWithTimeIntervalSince1970:[dict[@"dateModified"] doubleValue]];
    
    NSArray *indicatorsArray = dict[@"indicators"];
    for (NSDictionary *indicatorDict in indicatorsArray) {
        IndicatorConfig *indicator = [[IndicatorConfig alloc] initWithType:indicatorDict[@"indicatorType"]
                                                                displayName:indicatorDict[@"displayName"]
                                                                     weight:[indicatorDict[@"weight"] doubleValue]
                                                                 parameters:indicatorDict[@"parameters"]];
        indicator.isEnabled = [indicatorDict[@"isEnabled"] boolValue];
        [strategy addIndicator:indicator];
    }
    
    NSLog(@"📥 Loaded strategy: %@ (%lu indicators)", strategy.strategyName, (unsigned long)strategy.indicators.count);
    
    return strategy;
}

@end

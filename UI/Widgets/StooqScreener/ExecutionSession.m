//
//  ExecutionSession.m
//  TradingApp
//

#import "ExecutionSession.h"
#import "ScreenedSymbol.h"

@implementation ExecutionSession

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _sessionID = [[NSUUID UUID] UUIDString];
        _executionDate = [NSDate date];
        _modelResults = @[];
        _universe = @[];
    }
    return self;
}

#pragma mark - Factory Methods

+ (instancetype)sessionWithModelResults:(NSArray<ModelResult *> *)modelResults
                               universe:(NSArray<NSString *> *)universe {
    return [self sessionWithModelResults:modelResults universe:universe date:[NSDate date]];
}

+ (instancetype)sessionWithModelResults:(NSArray<ModelResult *> *)modelResults
                               universe:(NSArray<NSString *> *)universe
                                   date:(NSDate *)date {
    ExecutionSession *session = [[ExecutionSession alloc] init];
    session.modelResults = modelResults;
    session.universe = universe;
    session.executionDate = date;
    
    // Calculate totals
    session.totalModels = modelResults.count;
    
    NSMutableSet *uniqueSymbols = [NSMutableSet set];
    NSTimeInterval totalTime = 0.0;
    
    for (ModelResult *result in modelResults) {
        totalTime += result.totalExecutionTime;
        
        // Add symbols from this model
        for (ScreenedSymbol *screenedSymbol in result.screenedSymbols) {
            [uniqueSymbols addObject:screenedSymbol.symbol];
        }
    }
    
    session.totalSymbols = uniqueSymbols.count;
    session.totalExecutionTime = totalTime;
    
    return session;
}

#pragma mark - Analysis

- (NSSet<NSString *> *)allUniqueSymbols {
    NSMutableSet *symbols = [NSMutableSet set];
    
    for (ModelResult *result in self.modelResults) {
        for (ScreenedSymbol *screenedSymbol in result.screenedSymbols) {
            [symbols addObject:screenedSymbol.symbol];
        }
    }
    
    return [symbols copy];
}

- (NSArray<ScreenedSymbol *> *)allSelectedSymbols {
    NSMutableArray *selected = [NSMutableArray array];
    
    for (ModelResult *result in self.modelResults) {
        for (ScreenedSymbol *screenedSymbol in result.screenedSymbols) {
            if (screenedSymbol.isSelected) {
                [selected addObject:screenedSymbol];
            }
        }
    }
    
    return [selected copy];
}

- (NSDictionary<NSString *, NSArray<NSString *> *> *)symbolsInMultipleModels {
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *symbolToModels = [NSMutableDictionary dictionary];
    
    for (ModelResult *result in self.modelResults) {
        // Extract symbol strings from ScreenedSymbol objects
        NSMutableArray *symbols = [NSMutableArray array];
        for (ScreenedSymbol *screenedSymbol in result.screenedSymbols) {
            [symbols addObject:screenedSymbol.symbol];
        }
        
        for (NSString *symbol in symbols) {
            if (!symbolToModels[symbol]) {
                symbolToModels[symbol] = [NSMutableArray array];
            }
            [symbolToModels[symbol] addObject:result.modelName];
        }
    }
    
    // Filter to only symbols in multiple models
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSString *symbol in symbolToModels) {
        if (symbolToModels[symbol].count > 1) {
            result[symbol] = [symbolToModels[symbol] copy];
        }
    }
    
    return [result copy];
}

- (NSDictionary *)statistics {
    NSInteger totalSymbolsAcrossModels = 0;
    NSInteger minSymbols = NSIntegerMax;
    NSInteger maxSymbols = 0;
    
    for (ModelResult *result in self.modelResults) {
        NSInteger count = result.screenedSymbols.count;
        totalSymbolsAcrossModels += count;
        minSymbols = MIN(minSymbols, count);
        maxSymbols = MAX(maxSymbols, count);
    }
    
    double avgSymbolsPerModel = self.totalModels > 0 ? (double)totalSymbolsAcrossModels / self.totalModels : 0.0;
    
    return @{
        @"total_models": @(self.totalModels),
        @"total_unique_symbols": @(self.totalSymbols),
        @"total_symbols_across_models": @(totalSymbolsAcrossModels),
        @"avg_symbols_per_model": @(avgSymbolsPerModel),
        @"min_symbols": @(minSymbols),
        @"max_symbols": @(maxSymbols),
        @"total_execution_time": @(self.totalExecutionTime),
        @"avg_time_per_model": @(self.totalModels > 0 ? self.totalExecutionTime / self.totalModels : 0.0)
    };
}

#pragma mark - Persistence

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    // Date formatter per convertire NSDate in stringa ISO8601
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    dateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    
    // Converti execution_date
    if (self.executionDate) {
        dict[@"execution_date"] = [dateFormatter stringFromDate:self.executionDate];
    }
    
    // Converti model_results
    NSMutableArray *modelResults = [NSMutableArray array];
    for (ModelResult *result in self.modelResults) {
        // Crea manualmente il dizionario invece di chiamare toDictionary
        NSMutableDictionary *resultDict = [NSMutableDictionary dictionary];
        
        resultDict[@"model_id"] = result.modelID ?: @"";
        resultDict[@"model_name"] = result.modelName ?: @"";
        resultDict[@"model_description"] = result.modelDescription ?: @"";
        resultDict[@"initial_universe_size"] = @(result.initialUniverseSize);
        resultDict[@"total_execution_time"] = @(result.totalExecutionTime);
        
        // Converti execution_time
        if (result.executionTime) {
            resultDict[@"execution_time"] = [dateFormatter stringFromDate:result.executionTime];
        }
        
        // Aggiungi steps se esistono
        if (result.steps) {
            NSMutableArray *stepsArray = [NSMutableArray array];
            for (ScreenerStep *step in result.steps) {
                [stepsArray addObject:[step toDictionary]];
            }
            resultDict[@"steps"] = stepsArray;
        }
        
        // Converti screened_symbols con le date nei metadata
        if (result.screenedSymbols) {
            NSMutableArray *symbols = [NSMutableArray array];
            for (ScreenedSymbol *symbol in result.screenedSymbols) {
                NSMutableDictionary *symbolDict = [NSMutableDictionary dictionary];
                
                symbolDict[@"symbol"] = symbol.symbol ?: @"";
                symbolDict[@"added_at_step"] = @(symbol.addedAtStep);
                symbolDict[@"is_selected"] = @(symbol.isSelected);
                
                // Converti metadata con signalDate
                if (symbol.metadata) {
                    NSMutableDictionary *metadata = [symbol.metadata mutableCopy];
                    if ([metadata[@"signalDate"] isKindOfClass:[NSDate class]]) {
                        metadata[@"signalDate"] = [dateFormatter stringFromDate:metadata[@"signalDate"]];
                    }
                    symbolDict[@"metadata"] = metadata;
                }
                
                [symbols addObject:symbolDict];
            }
            resultDict[@"screened_symbols"] = symbols;
        }
        
        // Converti step_results
        if (result.stepResults) {
            NSMutableArray *stepResults = [NSMutableArray array];
            for (StepResult *stepResult in result.stepResults) {
                NSMutableDictionary *stepDict = [NSMutableDictionary dictionary];
                
                stepDict[@"screener_id"] = stepResult.screenerID ?: @"";
                stepDict[@"screener_name"] = stepResult.screenerName ?: @"";
                stepDict[@"input_count"] = @(stepResult.inputCount);
                stepDict[@"execution_time"] = @(stepResult.executionTime);
                
                // Aggiungi symbols se esistono
                if (stepResult.symbols) {
                    stepDict[@"symbols"] = stepResult.symbols;
                }
                
                [stepResults addObject:stepDict];
            }
            resultDict[@"step_results"] = stepResults;
        }
        
        // ✅ FIX CRITICO: Aggiungi resultDict all'array modelResults!
        [modelResults addObject:resultDict];
    }
    
    dict[@"model_results"] = modelResults;
    
    // Altri campi (nota: sessionID non sessionId, e rimuovo version)
    dict[@"session_id"] = self.sessionID ?: @"";
    dict[@"notes"] = self.notes ?: @"";
    dict[@"total_execution_time"] = @(self.totalExecutionTime);
    dict[@"total_models"] = @(self.totalModels);
    dict[@"total_symbols"] = @(self.totalSymbols);
    
    if (self.universe) {
        dict[@"universe"] = self.universe;
    }
    
    return dict;
}

+ (nullable instancetype)fromDictionary:(NSDictionary *)dict {
    if (!dict) return nil;
    
    // ✅ FIX: Gestisci sia formato ISO8601 (stringa) che timestamp (numero)
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    dateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    
    ExecutionSession *session = [[ExecutionSession alloc] init];
    session.sessionID = dict[@"session_id"] ?: [[NSUUID UUID] UUIDString];
    
    // Parse execution_date (supporta sia stringa ISO che numero timestamp)
    id executionDateValue = dict[@"execution_date"];
    if ([executionDateValue isKindOfClass:[NSString class]]) {
        session.executionDate = [dateFormatter dateFromString:executionDateValue];
    } else if ([executionDateValue isKindOfClass:[NSNumber class]]) {
        session.executionDate = [NSDate dateWithTimeIntervalSince1970:[executionDateValue doubleValue]];
    }
    
    if (!session.executionDate) {
        session.executionDate = [NSDate date]; // Fallback
    }
    
    session.totalModels = [dict[@"total_models"] integerValue];
    session.totalSymbols = [dict[@"total_symbols"] integerValue];
    session.totalExecutionTime = [dict[@"total_execution_time"] doubleValue];
    session.universe = dict[@"universe"] ?: @[];
    session.notes = dict[@"notes"];
    
    // Deserialize model results
    NSArray *modelResultsArray = dict[@"model_results"];
    if (modelResultsArray) {
        NSMutableArray *results = [NSMutableArray array];
        for (NSDictionary *resultDict in modelResultsArray) {
            ModelResult *result = [self modelResultFromDictionary:resultDict];
            if (result) {
                [results addObject:result];
            }
        }
        session.modelResults = [results copy];
    }
    
    return session;
}

+ (nullable ModelResult *)modelResultFromDictionary:(NSDictionary *)dict {
    if (!dict) return nil;
    
    // ✅ FIX: Date parser per supportare formato ISO8601
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    dateFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    
    ModelResult *result = [[ModelResult alloc] init];
    result.modelID = dict[@"model_id"];
    result.modelName = dict[@"model_name"];
    result.modelDescription = dict[@"model_description"];
    
    // Parse execution_time (supporta sia stringa ISO che numero timestamp)
    id executionTimeValue = dict[@"execution_time"];
    if ([executionTimeValue isKindOfClass:[NSString class]]) {
        result.executionTime = [dateFormatter dateFromString:executionTimeValue];
    } else if ([executionTimeValue isKindOfClass:[NSNumber class]]) {
        result.executionTime = [NSDate dateWithTimeIntervalSince1970:[executionTimeValue doubleValue]];
    }
    
    if (!result.executionTime) {
        result.executionTime = [NSDate date]; // Fallback
    }
    
    result.totalExecutionTime = [dict[@"total_execution_time"] doubleValue];
    result.initialUniverseSize = [dict[@"initial_universe_size"] integerValue];
    
    // Deserialize steps
    NSArray *stepsArray = dict[@"steps"];
    if (stepsArray) {
        NSMutableArray *steps = [NSMutableArray array];
        for (NSDictionary *stepDict in stepsArray) {
            ScreenerStep *step = [ScreenerStep fromDictionary:stepDict];
            if (step) {
                [steps addObject:step];
            }
        }
        result.steps = [steps copy];
    }
    
    // Deserialize step results
    NSArray *stepResultsArray = dict[@"step_results"];
    if (stepResultsArray) {
        NSMutableArray *stepResults = [NSMutableArray array];
        for (NSDictionary *srDict in stepResultsArray) {
            StepResult *sr = [[StepResult alloc] init];
            sr.screenerID = srDict[@"screener_id"];
            sr.screenerName = srDict[@"screener_name"];
            sr.symbols = srDict[@"symbols"];
            sr.inputCount = [srDict[@"input_count"] integerValue];
            sr.executionTime = [srDict[@"execution_time"] doubleValue];
            [stepResults addObject:sr];
        }
        result.stepResults = [stepResults copy];
    }
    
    // Deserialize screened symbols
    NSArray *screenedSymbolsArray = dict[@"screened_symbols"];
    if (screenedSymbolsArray) {
        NSMutableArray *symbols = [NSMutableArray array];
        for (NSDictionary *symbolDict in screenedSymbolsArray) {
            ScreenedSymbol *symbol = [ScreenedSymbol fromDictionary:symbolDict];
            if (symbol) {
                [symbols addObject:symbol];
            }
        }
        result.screenedSymbols = [symbols copy];
    }
    
    return result;
}

- (BOOL)saveToFile:(NSString *)filePath error:(NSError **)error {
    NSDictionary *dict = [self toDictionary];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:error];
    if (!jsonData) {
        return NO;
    }
    
    return [jsonData writeToFile:filePath options:NSDataWritingAtomic error:error];
}

+ (nullable instancetype)loadFromFile:(NSString *)filePath error:(NSError **)error {
    NSData *jsonData = [NSData dataWithContentsOfFile:filePath options:0 error:error];
    if (!jsonData) {
        return nil;
    }
    
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                         options:0
                                                           error:error];
    if (!dict) {
        return nil;
    }
    
    return [self fromDictionary:dict];
}

#pragma mark - Display

- (NSString *)formattedExecutionDate {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm";
    return [formatter stringFromDate:self.executionDate];
}

- (NSString *)summaryString {
    return [NSString stringWithFormat:@"%ld models, %ld symbols, %.1fs",
            (long)self.totalModels,
            (long)self.totalSymbols,
            self.totalExecutionTime];
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<ExecutionSession: %@ - %@>",
            [self formattedExecutionDate],
            [self summaryString]];
}

@end

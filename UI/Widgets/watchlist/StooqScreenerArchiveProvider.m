//
//  StooqScreenerArchiveProvider.m
//  TradingApp
//
//  Provider for Stooq Screener archived results
//

#import "StooqScreenerArchiveProvider.h"
#import "ScreenerModel.h"  // Per ModelResult, ScreenedSymbol
#import "screenedsymbol.h"


@implementation StooqScreenerArchiveProvider

#pragma mark - Initialization

- (instancetype)initWithModelResult:(ModelResult *)modelResult
                     executionDate:(NSDate *)executionDate {
    if (self = [super init]) {
        _modelResult = modelResult;
        _executionDate = executionDate;
    }
    return self;
}

#pragma mark - WatchlistProvider Protocol

- (NSString *)providerId {
    return [NSString stringWithFormat:@"screener:%@", self.modelResult.modelID];
}

- (NSString *)displayName {
    // Format: "Model Name (Jan 15)"
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"MMM dd";
    NSString *dateStr = [formatter stringFromDate:self.executionDate];
    
    return [NSString stringWithFormat:@"%@ (%@)",
            self.modelResult.modelName,
            dateStr];
}

- (NSString *)categoryName {
    return @"Screener Results";
}

- (BOOL)canAddSymbols {
    return NO;
}

- (BOOL)canRemoveSymbols {
    return NO;
}

- (BOOL)isAutoUpdating {
    return NO;
}

- (BOOL)showCount {
    return YES;
}

- (NSArray<NSString *> *)symbols {
    // Extract symbol strings from ScreenedSymbol objects
    NSMutableArray<NSString *> *symbolStrings = [NSMutableArray array];
    
    for (ScreenedSymbol *screenedSymbol in self.modelResult.screenedSymbols) {
        if (screenedSymbol.symbol) {
            [symbolStrings addObject:screenedSymbol.symbol];
        }
    }
    
    return [symbolStrings copy];
}

- (BOOL)isLoaded {
    return self.modelResult.screenedSymbols != nil;
}

- (void)loadSymbolsWithCompletion:(void(^)(NSArray<NSString *> * _Nullable symbols, NSError * _Nullable error))completion {
    // Data is already loaded in ModelResult, return immediately
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray<NSString *> *symbols = [self symbols];
        
        NSLog(@"✅ StooqScreenerArchiveProvider (%@): %lu symbols ready",
              self.displayName, (unsigned long)symbols.count);
        
        if (completion) {
            completion(symbols, nil);
        }
    });
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<StooqScreenerArchiveProvider: %@ - %lu symbols>",
            self.displayName, (unsigned long)self.symbols.count];
}

@end

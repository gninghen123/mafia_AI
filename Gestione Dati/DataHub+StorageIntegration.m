//
//  DataHub+StorageIntegration.m
//  TradingApp
//
//  Implementation of DataHub + StorageManager integration
//

#import "DataHub+StorageIntegration.h"
#import "StorageManager.h"
#import "SavedChartData.h"
#import "ChartWidget+SaveData.h"
#import <objc/runtime.h>

// Associated object keys
static const void *kStorageIntegrationEnabledKey = &kStorageIntegrationEnabledKey;
static const void *kOpportunisticUpdatesEnabledKey = &kOpportunisticUpdatesEnabledKey;
static const void *kOpportunisticUpdateThresholdKey = &kOpportunisticUpdateThresholdKey;
static const void *kStorageIntegrationInitializedKey = &kStorageIntegrationInitializedKey;

@implementation DataHub (StorageIntegration)

#pragma mark - Properties via Associated Objects

- (BOOL)storageIntegrationEnabled {
    NSNumber *value = objc_getAssociatedObject(self, kStorageIntegrationEnabledKey);
    return value ? [value boolValue] : YES; // Default: YES
}

- (void)setStorageIntegrationEnabled:(BOOL)storageIntegrationEnabled {
    objc_setAssociatedObject(self, kStorageIntegrationEnabledKey, @(storageIntegrationEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    if (storageIntegrationEnabled && ![self isStorageIntegrationInitialized]) {
        [self initializeStorageManagerIntegration];
    }
}

- (BOOL)opportunisticUpdatesEnabled {
    NSNumber *value = objc_getAssociatedObject(self, kOpportunisticUpdatesEnabledKey);
    return value ? [value boolValue] : YES; // Default: YES
}

- (void)setOpportunisticUpdatesEnabled:(BOOL)opportunisticUpdatesEnabled {
    objc_setAssociatedObject(self, kOpportunisticUpdatesEnabledKey, @(opportunisticUpdatesEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSInteger)opportunisticUpdateThreshold {
    NSNumber *value = objc_getAssociatedObject(self, kOpportunisticUpdateThresholdKey);
    return value ? [value integerValue] : 10; // Default: 10
}

- (void)setOpportunisticUpdateThreshold:(NSInteger)opportunisticUpdateThreshold {
    objc_setAssociatedObject(self, kOpportunisticUpdateThresholdKey, @(opportunisticUpdateThreshold), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isStorageIntegrationInitialized {
    NSNumber *value = objc_getAssociatedObject(self, kStorageIntegrationInitializedKey);
    return value ? [value boolValue] : NO;
}

- (void)setStorageIntegrationInitialized:(BOOL)initialized {
    objc_setAssociatedObject(self, kStorageIntegrationInitializedKey, @(initialized), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Initialization

- (void)initializeStorageManagerIntegration {
    if ([self isStorageIntegrationInitialized]) {
        NSLog(@"ℹ️ StorageManager integration already initialized");
        return;
    }
    
    if (!self.storageIntegrationEnabled) {
        NSLog(@"⚠️ StorageManager integration disabled");
        return;
    }
    
    NSLog(@"🔗 Initializing DataHub + StorageManager integration...");
    
    // Initialize StorageManager (this will auto-discover existing storages)
    [[StorageManager sharedManager] class];
    
    // Setup method swizzling to hook into historical data requests
    [self swizzleHistoricalDataMethods];
    
    // Mark as initialized
    [self setStorageIntegrationInitialized:YES];
    
    NSLog(@"✅ DataHub + StorageManager integration initialized");
    NSLog(@"   Opportunistic updates: %@", self.opportunisticUpdatesEnabled ? @"enabled" : @"disabled");
    NSLog(@"   Update threshold: %ld bars", (long)self.opportunisticUpdateThreshold);
}

- (void)swizzleHistoricalDataMethods {
    // Swizzle the main historical data request method to add storage awareness
    Class class = [self class];
    
    SEL originalSelector = @selector(requestHistoricalData:timeframe:fromDate:toDate:completionHandler:);
    SEL swizzledSelector = @selector(swizzled_requestHistoricalData:timeframe:fromDate:toDate:completionHandler:);
    
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    
    if (originalMethod && swizzledMethod) {
        BOOL didAddMethod = class_addMethod(class, originalSelector,
                                           method_getImplementation(swizzledMethod),
                                           method_getTypeEncoding(swizzledMethod));
        
        if (didAddMethod) {
            class_replaceMethod(class, swizzledSelector,
                               method_getImplementation(originalMethod),
                               method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
        
        NSLog(@"🔄 Successfully swizzled requestHistoricalData method for storage integration");
    } else {
        NSLog(@"❌ Failed to swizzle requestHistoricalData method - methods not found");
    }
}

#pragma mark - Enhanced Historical Data Methods

- (void)requestHistoricalDataWithStorageAwareness:(NSString *)symbol
                                        timeframe:(BarTimeframe)timeframe
                                         fromDate:(NSDate *)fromDate
                                           toDate:(NSDate *)toDate
                                completionHandler:(void(^)(NSArray<HistoricalBarModel *> * _Nullable bars, NSError * _Nullable error))completionHandler {
    
    NSLog(@"📊 Storage-aware historical data request: %@ [%@] from %@ to %@",
          symbol, [self timeframeToString:timeframe], fromDate, toDate);
    
    // Check if we have continuous storage that could benefit from this data
    BOOL hasContinuousStorage = [self hasContinuousStorageForSymbol:symbol timeframe:timeframe];
    
    if (hasContinuousStorage) {
        NSLog(@"🎯 Found continuous storage for %@ [%@] - will check for opportunistic update",
              symbol, [self timeframeToString:timeframe]);
    }
    
    // Call original method
    [self swizzled_requestHistoricalData:symbol
                               timeframe:timeframe
                                fromDate:fromDate
                                  toDate:toDate
                       completionHandler:^(NSArray<HistoricalBarModel *> *bars, NSError *error) {
        
        // If successful and we have enough data, notify StorageManager
        if (!error && bars && bars.count >= self.opportunisticUpdateThreshold &&
            self.opportunisticUpdatesEnabled && hasContinuousStorage) {
            
            NSLog(@"🚀 Triggering opportunistic update for %@ [%@] with %ld bars",
                  symbol, [self timeframeToString:timeframe], (long)bars.count);
            
            [self notifyStorageManagerOfDownload:symbol
                                       timeframe:timeframe
                                            bars:bars
                                        fromDate:fromDate
                                          toDate:toDate];
        }
        
        // Always call original completion handler
        if (completionHandler) {
            completionHandler(bars, error);
        }
    }];
}

// This is the swizzled method that replaces the original
- (void)swizzled_requestHistoricalData:(NSString *)symbol
                             timeframe:(BarTimeframe)timeframe
                              fromDate:(NSDate *)fromDate
                                toDate:(NSDate *)toDate
                     completionHandler:(void(^)(NSArray<HistoricalBarModel *> * _Nullable bars, NSError * _Nullable error))completionHandler {
    
    if (self.storageIntegrationEnabled) {
        // Use storage-aware version
        [self requestHistoricalDataWithStorageAwareness:symbol
                                              timeframe:timeframe
                                               fromDate:fromDate
                                                 toDate:toDate
                                      completionHandler:completionHandler];
    } else {
        // Call original implementation (this calls the original method due to swizzling)
        [self swizzled_requestHistoricalData:symbol
                                   timeframe:timeframe
                                    fromDate:fromDate
                                      toDate:toDate
                           completionHandler:completionHandler];
    }
}

#pragma mark - Storage Manager Communication

- (void)notifyStorageManagerOfDownload:(NSString *)symbol
                             timeframe:(BarTimeframe)timeframe
                                  bars:(NSArray<HistoricalBarModel *> *)bars
                              fromDate:(NSDate *)fromDate
                                toDate:(NSDate *)toDate {
    
    if (!self.storageIntegrationEnabled || !self.opportunisticUpdatesEnabled) {
        return;
    }
    
    NSLog(@"📡 Notifying StorageManager of download: %@ [%@] - %ld bars",
          symbol, [self timeframeToString:timeframe], (long)bars.count);
    
    // Notify via direct method call
    [[StorageManager sharedManager] handleOpportunisticUpdate:symbol timeframe:timeframe bars:bars];
    
    // Also send notification for other observers
    NSDictionary *userInfo = @{
        @"symbol": symbol,
        @"timeframe": @(timeframe),
        @"bars": bars,
        @"fromDate": fromDate,
        @"toDate": toDate
    };
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"DataHubHistoricalDataDownloaded"
                                                        object:self
                                                      userInfo:userInfo];
}

#pragma mark - Storage-Aware Methods

- (BOOL)hasContinuousStorageForSymbol:(NSString *)symbol timeframe:(BarTimeframe)timeframe {
    if (!self.storageIntegrationEnabled) return NO;
    
    StorageManager *manager = [StorageManager sharedManager];
    
    for (ActiveStorageItem *item in manager.activeStorages) {
        SavedChartData *storage = item.savedData;
        if ([storage.symbol isEqualToString:symbol] &&
            storage.timeframe == timeframe &&
            storage.dataType == SavedChartDataTypeContinuous &&
            !item.isPaused) {
            return YES;
        }
    }
    
    return NO;
}

- (NSArray<HistoricalBarModel *> *)getStorageDataForSymbol:(NSString *)symbol
                                                 timeframe:(BarTimeframe)timeframe
                                                  fromDate:(NSDate *)fromDate
                                                    toDate:(NSDate *)toDate {
    
    if (!self.storageIntegrationEnabled) return nil;
    
    StorageManager *manager = [StorageManager sharedManager];
    
    for (ActiveStorageItem *item in manager.activeStorages) {
        SavedChartData *storage = item.savedData;
        
        if ([storage.symbol isEqualToString:symbol] &&
            storage.timeframe == timeframe &&
            storage.dataType == SavedChartDataTypeContinuous) {
            
            // Check if storage covers the requested range
            if ([storage.startDate compare:fromDate] != NSOrderedDescending &&
                [storage.endDate compare:toDate] != NSOrderedAscending) {
                
                NSLog(@"📦 Found storage data for %@ [%@] covering requested range",
                      symbol, [self timeframeToString:timeframe]);
                
                // Filter bars to requested date range
                NSPredicate *dateRangePredicate = [NSPredicate predicateWithFormat:@"date >= %@ AND date <= %@", fromDate, toDate];
                NSArray *filteredBars = [storage.historicalBars filteredArrayUsingPredicate:dateRangePredicate];
                
                return filteredBars;
            }
        }
    }
    
    return nil;
}

#pragma mark - Utility Methods

- (NSString *)timeframeToString:(BarTimeframe)timeframe {
    switch (timeframe) {
        case BarTimeframe1Min: return @"1min";
        case BarTimeframe5Min: return @"5min";
        case BarTimeframe15Min: return @"15min";
        case BarTimeframe30Min: return @"30min";
        case BarTimeframe1Hour: return @"1hour";
        case BarTimeframe4Hour: return @"4hour";
        case BarTimeframeDaily: return @"daily";
        case BarTimeframeWeekly: return @"weekly";
        case BarTimeframeMonthly: return @"monthly";
        default: return @"unknown";
    }
}

@end

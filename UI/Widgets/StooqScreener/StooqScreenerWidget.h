//
//  StooqScreenerWidget.h
//  TradingApp
//
//  Widget for running screener models on Stooq database
//

#import "BaseWidget.h"

NS_ASSUME_NONNULL_BEGIN

@interface StooqScreenerWidget : BaseWidget

#pragma mark - Configuration

/// Path to Stooq data directory
@property (nonatomic, strong) NSString *dataDirectory;

/// Selected exchanges to screen (e.g., @[@"nasdaq", @"nyse"])
@property (nonatomic, strong) NSArray<NSString *> *selectedExchanges;

#pragma mark - Public Methods

/// Set data directory and refresh
- (void)setDataDirectory:(NSString *)path;

/// Refresh available models
- (void)refreshModels;

/// Run selected models
- (void)runSelectedModels;

/// Cancel current execution
- (void)cancelExecution;

@end

NS_ASSUME_NONNULL_END

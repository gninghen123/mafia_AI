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
// StooqScreenerWidget.h - @interface
@property (nonatomic, strong) NSDatePicker *targetDatePicker;
/// Path to Stooq data directory
@property (nonatomic, strong, nullable) NSString *dataDirectory;

/// Selected exchanges to screen (e.g., @[@"nasdaq", @"nyse"])
@property (nonatomic, strong) NSArray<NSString *> *selectedExchanges;
@property (nonatomic, strong) NSView *archiveStatsPanel;
@property (nonatomic, strong) NSTextField *statsAllLabel;
@property (nonatomic, strong) NSTextField *statsSelectedLabel;


#pragma mark - Public Methods

/// Set data directory and initialize data manager
/// @param path Path to Stooq data directory
- (void)setDataDirectory:(NSString *)path;

/// Refresh models list from disk
- (void)refreshModels;

/// Run selected models on universe
- (void)runSelectedModels;

/// Cancel current batch execution
- (void)cancelExecution;

@end

NS_ASSUME_NONNULL_END

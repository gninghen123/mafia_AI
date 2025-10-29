//
//  ScoreTableWidget.h
//  TradingApp
//
//  Score Table Widget - Ranks symbols based on custom indicators
//

#import "BaseWidget.h"
#import "ScoreTableWidget_Models.h"
#import "StooqDataManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface ScoreTableWidget : BaseWidget <NSTableViewDataSource, NSTableViewDelegate, NSTextViewDelegate>

#pragma mark - UI Components

@property (nonatomic, strong) NSScrollView *symbolInputScrollView;
@property (nonatomic, strong) NSTextView *symbolInputTextView;
@property (nonatomic, strong) NSPopUpButton *strategySelector;
@property (nonatomic, strong) NSButton *configureButton;
@property (nonatomic, strong) NSButton *refreshButton;
@property (nonatomic, strong) NSButton *exportButton;

@property (nonatomic, strong) NSScrollView *tableScrollView;
@property (nonatomic, strong) NSTableView *scoreTableView;

@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSProgressIndicator *loadingIndicator;

#pragma mark - Data

@property (nonatomic, strong) NSMutableArray<ScoreResult *> *scoreResults;
@property (nonatomic, strong) ScoringStrategy *currentStrategy;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<HistoricalBarModel *> *> *symbolDataCache;

#pragma mark - External Managers

@property (nonatomic, strong) StooqDataManager *stooqManager;

#pragma mark - Public Methods

/**
 * Load symbols and calculate scores
 */
- (void)loadSymbolsAndCalculateScores:(NSArray<NSString *> *)symbols;

/**
 * Refresh scores for current symbols
 */
- (void)refreshScores;

/**
 * Export results to CSV
 */
- (void)exportToCSV;

#pragma mark - Internal Methods (for Categories)

/**
 * Fetch data with priority cascade
 */
- (void)fetchDataForSymbols:(NSArray<NSString *> *)symbols
               requirements:(DataRequirements *)requirements
                 completion:(void (^)(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *symbolData, NSError *error))completion;

/**
 * Calculate scores from data
 */
- (void)calculateScoresWithData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)symbolData;

/**
 * Validate data against requirements
 */
- (BOOL)isDataValid:(NSArray<HistoricalBarModel *> *)data forRequirements:(DataRequirements *)requirements;

/**
 * Fetch from DataHub
 */
- (void)fetchFromDataHub:(NSArray<NSString *> *)symbols
            requirements:(DataRequirements *)requirements
              completion:(void (^)(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *data, NSError *error))completion;

/**
 * Show loading for symbols
 */
- (void)showLoadingForSymbols:(NSArray<NSString *> *)symbols;

/**
 * Hide loading for symbols
 */
- (void)hideLoadingForSymbols:(NSArray<NSString *> *)symbols;

/**
 * Color for score value
 */
- (NSColor *)colorForScore:(CGFloat)score;

@end

NS_ASSUME_NONNULL_END

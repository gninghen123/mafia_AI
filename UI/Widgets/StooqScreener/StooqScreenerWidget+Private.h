//
//  StooqScreenerWidget+Private.h
//  TradingApp
//
//  Private interface exposing properties needed by categories
//  Import this in category implementations to access main widget properties
//

#import "StooqScreenerWidget.h"

NS_ASSUME_NONNULL_BEGIN

@class StooqDataManager;
@class ModelManager;
@class ScreenerModel;
@class ExecutionSession;
@class ModelResult;

/**
 * Private interface for StooqScreenerWidget
 * Exposes internal properties for category access
 */
@interface StooqScreenerWidget ()

#pragma mark - UI Components (from main implementation)

@property (nonatomic, strong) NSTabView *tabView;
@property (nonatomic, strong) NSView *contentView;

#pragma mark - Data Managers

@property (nonatomic, strong) ModelManager *modelManager;
@property (nonatomic, strong) StooqDataManager *dataManager;

#pragma mark - Data

@property (nonatomic, strong) NSMutableArray<ScreenerModel *> *models;
@property (nonatomic, strong) NSArray<NSString *> *availableSymbols;
@property (nonatomic, strong) NSMutableArray<ExecutionSession *> *archivedSessions;

#pragma mark - Currently Selected Items

@property (nonatomic, strong, nullable) ScreenerModel *selectedModel;
@property (nonatomic, strong, nullable) ExecutionSession *selectedSession;
@property (nonatomic, strong, nullable) ModelResult *selectedModelResult;

#pragma mark - Cache (for Results tab integration)

@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *lastScreeningCache;
@property (nonatomic, strong, nullable) NSDate *lastScreeningDate;
@property (nonatomic, strong, nullable) NSString *cachedSessionID;

@end

NS_ASSUME_NONNULL_END

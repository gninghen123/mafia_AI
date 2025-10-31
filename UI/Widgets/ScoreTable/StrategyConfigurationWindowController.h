//
//  StrategyConfigurationWindowController.h
//  TradingApp
//
//  Strategy Configuration Window - Manage scoring strategies
//

#import <Cocoa/Cocoa.h>
#import "ScoreTableWidget_Models.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate protocol for strategy configuration changes
 */
@protocol StrategyConfigurationDelegate <NSObject>
@optional
- (void)strategyConfigurationDidSaveStrategy:(ScoringStrategy *)strategy;
- (void)strategyConfigurationDidDeleteStrategy:(NSString *)strategyId;
- (void)strategyConfigurationDidCancel;
@end

/**
 * Window controller for creating, editing, and managing scoring strategies
 */
@interface StrategyConfigurationWindowController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate>

#pragma mark - Initialization

/**
 * Show configuration window with optional initial strategy selection
 * @param strategy Strategy to edit (nil for creating new)
 * @param delegate Delegate to notify of changes
 */
+ (instancetype)showConfigurationWithStrategy:(nullable ScoringStrategy *)strategy
                                      delegate:(nullable id<StrategyConfigurationDelegate>)delegate;

@property (nonatomic, weak) id<StrategyConfigurationDelegate> delegate;

#pragma mark - UI Components - Left Panel (Strategy List)

@property (nonatomic, strong) NSScrollView *strategyListScrollView;
@property (nonatomic, strong) NSTableView *strategyListTable;
@property (nonatomic, strong) NSButton *addStrategyButton;
@property (nonatomic, strong) NSButton *deleteStrategyButton;
@property (nonatomic, strong) NSButton *duplicateStrategyButton;

#pragma mark - UI Components - Right Panel (Strategy Details)

@property (nonatomic, strong) NSTextField *strategyNameField;
@property (nonatomic, strong) NSTextField *createdLabel;
@property (nonatomic, strong) NSTextField *modifiedLabel;
@property (nonatomic, strong) NSTextField *totalWeightLabel;

// Indicator table
@property (nonatomic, strong) NSScrollView *indicatorScrollView;
@property (nonatomic, strong) NSTableView *indicatorTable;

@property (nonatomic, strong) NSButton *normalizeWeightsButton;
@property (nonatomic, strong) NSButton *addIndicatorButton;

// Bottom buttons
@property (nonatomic, strong) NSButton *saveButton;
@property (nonatomic, strong) NSButton *cancelButton;

#pragma mark - Data

@property (nonatomic, strong) NSMutableArray<ScoringStrategy *> *allStrategies;
@property (nonatomic, strong, nullable) ScoringStrategy *selectedStrategy;
@property (nonatomic, assign) BOOL isEditingExisting; // YES if editing, NO if creating new

#pragma mark - Available Indicators

/**
 * Returns all available indicator types with default configurations
 */
+ (NSArray<IndicatorConfig *> *)availableIndicatorTypes;

@end

NS_ASSUME_NONNULL_END

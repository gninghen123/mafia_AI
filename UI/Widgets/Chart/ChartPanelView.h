//
//  ChartPanelView.h
//  TradingApp
//
//  Individual chart panel view for rendering indicators
//

#import <Cocoa/Cocoa.h>
#import "ChartPanelModel.h"
#import "ChartCoordinator.h"
#import "RuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

@class ChartWidget;

@interface ChartPanelView : NSView

#pragma mark - Core Properties
@property (nonatomic, strong) ChartPanelModel *panelModel;
@property (nonatomic, weak) ChartWidget *chartWidget;
@property (nonatomic, weak) ChartCoordinator *coordinator;
@property (nonatomic, strong, nullable) NSArray<HistoricalBarModel *> *historicalData;

#pragma mark - UI Components
@property (nonatomic, strong) NSButton *deleteButton;      // ❌ button (if deletable)
@property (nonatomic, strong) NSTextField *titleLabel;     // Panel title
@property (nonatomic, strong) NSTextField *yAxisLabel;     // Y-axis values

#pragma mark - State
@property (nonatomic, assign) BOOL showYAxis;
@property (nonatomic, assign) BOOL showTitle;

#pragma mark - Initialization
- (instancetype)initWithPanelModel:(ChartPanelModel *)panelModel
                        coordinator:(ChartCoordinator *)coordinator
                        chartWidget:(ChartWidget *)chartWidget;

#pragma mark - Data Updates
- (void)updateWithHistoricalData:(NSArray<HistoricalBarModel *> *)data;
- (void)refreshDisplay;

#pragma mark - UI Updates
- (void)updateUI;
- (void)setupDeleteButton;
- (void)setupYAxis;

@end

NS_ASSUME_NONNULL_END

//
//  IndicatorsPanelController.h
//  TradingApp
//
//  Interactive indicators panel with split view and table views for each panel
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class ChartWidget;
@class ChartPanelModel;

@interface IndicatorsPanelController : NSViewController <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate, NSSplitViewDelegate>

// Properties
@property (nonatomic, weak) ChartWidget *chartWidget;
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, strong, readonly) NSWindow *popupWindow; // AGGIUNTO per controllare lo stato

// Available indicators
@property (nonatomic, strong) NSArray<NSString *> *availableIndicatorTypes;
@property (nonatomic, strong) NSMutableArray<NSString *> *savedTemplates;

// UI Components - Main Structure
@property (nonatomic, strong) NSView *panelView;

// Header
@property (nonatomic, strong) NSTextField *headerLabel;
@property (nonatomic, strong) NSButton *closeButton;

// Template Section
@property (nonatomic, strong) NSTextField *templateLabel;
@property (nonatomic, strong) NSComboBox *templateComboBox;
@property (nonatomic, strong) NSButton *saveTemplateButton;
@property (nonatomic, strong) NSButton *loadTemplateButton;

// Split View Structure
@property (nonatomic, strong) NSScrollView *panelsScrollView;
@property (nonatomic, strong) NSStackView *panelsStackView;

// Available Indicators Section
@property (nonatomic, strong) NSTextField *availableLabel;

// Initialization
- (instancetype)initWithChartWidget:(ChartWidget *)chartWidget;

// Panel management
- (void)showPanel;
- (void)hidePanel;
- (void)togglePanel;

// Content updates
- (void)refreshPanelsList;

// Panel operations
- (void)deletePanelModel:(ChartPanelModel *)panelModel;
- (void)showAddIndicatorPopupForPanel:(ChartPanelModel *)panel sourceButton:(NSButton *)button;
- (void)addIndicatorType:(NSString *)indicatorType toPanel:(ChartPanelModel *)panel;

// Utility methods
- (NSString *)displayNameForIndicatorType:(NSString *)indicatorType;
- (NSString *)iconForIndicatorType:(NSString *)indicatorType;

@end

NS_ASSUME_NONNULL_END

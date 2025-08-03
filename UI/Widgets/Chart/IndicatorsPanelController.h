//
//  IndicatorsPanelController.h
//  TradingApp
//
//  Floating popup panel for managing chart indicators and templates
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class ChartWidget;
@class TemplateManager;

@interface IndicatorsPanelController : NSViewController <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate>

// Properties
@property (nonatomic, weak) ChartWidget *chartWidget;
@property (nonatomic, assign) BOOL isVisible;

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

// Panels Section
@property (nonatomic, strong) NSScrollView *panelsScrollView;
@property (nonatomic, strong) NSStackView *panelsStackView;
@property (nonatomic, strong) NSButton *addPanelButton;

// Indicators Section
@property (nonatomic, strong) NSTextField *availableLabel;
@property (nonatomic, strong) NSScrollView *availableScrollView;

// Initialization
- (instancetype)initWithChartWidget:(ChartWidget *)chartWidget;

// Panel management
- (void)showPanel;
- (void)hidePanel;
- (void)togglePanel;

// Content updates
- (void)refreshPanelsList;

@end

NS_ASSUME_NONNULL_END

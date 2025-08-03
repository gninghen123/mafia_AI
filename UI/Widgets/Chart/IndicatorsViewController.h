//
//  IndicatorsPanelController.h
//  TradingApp
//
//  Slide-out panel for managing chart indicators and templates
//

#import <Cocoa/Cocoa.h>
#import "ChartTypes.h"
#import "ChartPanelModel.h"
#import "IndicatorRenderer.h"

NS_ASSUME_NONNULL_BEGIN

@class ChartWidget;
@class TemplateManager;

@interface IndicatorsPanelController : NSViewController <NSTableViewDataSource, NSTableViewDelegate>

#pragma mark - Core Properties
@property (nonatomic, weak) ChartWidget *chartWidget;
@property (nonatomic, assign) BOOL isVisible;

#pragma mark - UI Components
// Panel container
@property (nonatomic, strong) NSView *panelView;
@property (nonatomic, strong) NSVisualEffectView *backdropView;

// Header
@property (nonatomic, strong) NSTextField *headerLabel;
@property (nonatomic, strong) NSButton *closeButton;

// Template section
@property (nonatomic, strong) NSTextField *templateLabel;
@property (nonatomic, strong) NSComboBox *templateComboBox;
@property (nonatomic, strong) NSButton *saveTemplateButton;
@property (nonatomic, strong) NSButton *loadTemplateButton;

// Panels management
@property (nonatomic, strong) NSScrollView *panelsScrollView;
@property (nonatomic, strong) NSStackView *panelsStackView;
@property (nonatomic, strong) NSButton *addPanelButton;

// Available indicators
@property (nonatomic, strong) NSTextField *availableLabel;
@property (nonatomic, strong) NSTableView *availableIndicatorsTable;
@property (nonatomic, strong) NSScrollView *availableScrollView;

#pragma mark - Data
@property (nonatomic, strong) NSArray<NSString *> *availableIndicatorTypes;
@property (nonatomic, strong) NSMutableArray<NSString *> *savedTemplates;

#pragma mark - Initialization
- (instancetype)initWithChartWidget:(ChartWidget *)chartWidget;

#pragma mark - Panel Management
- (void)showPanel;
- (void)hidePanel;
- (void)togglePanel;

#pragma mark - Data Updates
- (void)refreshPanelsList;
- (void)refreshTemplatesList;

#pragma mark - Actions
- (IBAction)addPanelButtonClicked:(id)sender;
- (IBAction)saveTemplateButtonClicked:(id)sender;
- (IBAction)loadTemplateButtonClicked:(id)sender;
- (IBAction)closeButtonClicked:(id)sender;

@end

NS_ASSUME_NONNULL_END

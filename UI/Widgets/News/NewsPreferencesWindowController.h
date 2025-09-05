//
//  NewsPreferencesWindowController.h
//  TradingApp
//
//  Preferences window controller for NewsWidget V2
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class NewsWidget;

@interface NewsPreferencesWindowController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource, NSTextViewDelegate>

#pragma mark - Properties

@property (nonatomic, weak) NewsWidget *newsWidget;

// UI Components
@property (nonatomic, strong) NSTabView *tabView;

// Tab 1: Sources
@property (nonatomic, strong) NSTableView *sourcesTableView;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *sourcesList;

// Tab 2: Colors & Keywords
@property (nonatomic, strong) NSTableView *colorsTableView;
@property (nonatomic, strong) NSButton *addColorButton;
@property (nonatomic, strong) NSButton *removeColorButton;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *colorMappings;

// Tab 3: Filters
@property (nonatomic, strong) NSTextView *excludeKeywordsTextView;
@property (nonatomic, strong) NSTextField *newsLimitField;

#pragma mark - Lifecycle

- (instancetype)initWithNewsWidget:(NewsWidget *)newsWidget;
- (void)refreshUI;

#pragma mark - UI Creation

- (void)createWindow;
- (void)createTabView;
- (void)createSourcesTab;
- (void)createColorsTab;
- (void)createFiltersTab;
- (void)createButtonsPanel;
- (void)setupConstraints;

#pragma mark - Data Management

- (void)loadDataFromWidget;
- (void)saveDataToWidget;
- (void)loadSourcesData;
- (void)loadColorMappingsData;
- (void)loadOtherSettings;

#pragma mark - Action Methods

- (IBAction)addColorMapping:(id)sender;
- (IBAction)removeColorMapping:(id)sender;
- (IBAction)sourceEnabledChanged:(NSButton *)sender;
- (IBAction)colorChanged:(NSColorWell *)sender;
- (IBAction)keywordsChanged:(NSTextField *)sender;
- (IBAction)autoRefreshChanged:(NSButton *)sender;
- (IBAction)savePreferences:(id)sender;
- (IBAction)cancelPreferences:(id)sender;
- (IBAction)resetToDefaults:(id)sender;

#pragma mark - Utility Methods

- (NSColor *)colorFromHexString:(NSString *)hexString;
- (NSString *)hexStringFromColor:(NSColor *)color;

@end

NS_ASSUME_NONNULL_END

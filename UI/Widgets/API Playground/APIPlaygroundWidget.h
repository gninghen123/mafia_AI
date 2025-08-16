//
//  APIPlaygroundWidget.h
//  TradingApp
//
//  API Playground widget per testing chiamate dirette alle API
//  Bypassa DataHub/DataManager per testing raw delle API
//

#import "BaseWidget.h"
#import "CommonTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface APIPlaygroundWidget : BaseWidget

#pragma mark - UI Components
@property (nonatomic, strong) NSTabView *tabView;

// Tab "Historical Data"
@property (nonatomic, strong) NSView *historicalTabView;

// Controls Section
@property (nonatomic, strong) NSTextField *symbolField;
@property (nonatomic, strong) NSDatePicker *startDatePicker;
@property (nonatomic, strong) NSDatePicker *endDatePicker;
@property (nonatomic, strong) NSPopUpButton *timeframePopup;
@property (nonatomic, strong) NSButton *extendedHoursCheckbox;
@property (nonatomic, strong) NSTextField *periodField;
@property (nonatomic, strong) NSPopUpButton *periodTypePopup;
@property (nonatomic, strong) NSTextField *frequencyField;
@property (nonatomic, strong) NSPopUpButton *frequencyTypePopup;
@property (nonatomic, strong) NSTextField *barCountField; // NUOVO: Controllo numero barre

// Data Source Selection
@property (nonatomic, strong) NSSegmentedControl *dataSourceSegmented;
@property (nonatomic, strong) NSTextField *parametersLabel;

// Action buttons
@property (nonatomic, strong) NSButton *executeButton;
@property (nonatomic, strong) NSButton *clearButton;

// Results Section
@property (nonatomic, strong) NSTableView *resultsTableView;
@property (nonatomic, strong) NSScrollView *tableScrollView;
@property (nonatomic, strong) NSTextView *rawResponseTextView;
@property (nonatomic, strong) NSScrollView *textScrollView;

#pragma mark - Data Properties
@property (nonatomic, strong) NSMutableArray *historicalData;
@property (nonatomic, strong) NSString *lastRawResponse;

#pragma mark - Methods
- (void)setupHistoricalTab;
- (void)executeHistoricalCall;
- (void)clearResults;
- (void)updateParametersLabel;

@end

NS_ASSUME_NONNULL_END

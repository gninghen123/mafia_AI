//
//  APIPlaygroundWidget.h (UPDATED - UNIFIED EXTENSION)
//  TradingApp
//
//  ESTENSIONE: API Playground con supporto completo per tutte le chiamate
//  unificate del DownloadManager (quotes, historical, market lists, account, etc.)
//

#import "BaseWidget.h"
#import "CommonTypes.h"
#import "DownloadManager.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, APIPlaygroundRequestType) {
    // Market Data
    APIPlaygroundRequestTypeQuote = 0,
    APIPlaygroundRequestTypeBatchQuotes,
    APIPlaygroundRequestTypeHistoricalBars,
    
    // Market Lists
    APIPlaygroundRequestTypeTopGainers,
    APIPlaygroundRequestTypeTopLosers,
    APIPlaygroundRequestTypeETFList,
    APIPlaygroundRequestType52WeekHigh,
    APIPlaygroundRequestTypeMarketList,
    
    // Account Data (only for trading APIs)
    APIPlaygroundRequestTypeAccounts,
    APIPlaygroundRequestTypeAccountDetails,
    APIPlaygroundRequestTypePositions,
    APIPlaygroundRequestTypeOrders,
    
    // Advanced
    APIPlaygroundRequestTypeOrderBook,
    APIPlaygroundRequestTypeFundamentals
};

@interface APIPlaygroundWidget : BaseWidget

#pragma mark - UI Components
@property (nonatomic, strong) NSTabView *tabView;

// UNIFIED CONTROLS TAB
@property (nonatomic, strong) NSView *unifiedTabView;

// Request Type Selection
@property (nonatomic, strong) NSPopUpButton *requestTypePopup;
@property (nonatomic, strong) NSPopUpButton *dataSourcePopup; // NEW: Choose specific DataSource
@property (nonatomic, strong) NSTextField *parametersLabel;

// Symbol Input (for market data requests)
@property (nonatomic, strong) NSTextField *symbolField;
@property (nonatomic, strong) NSTextField *symbolsField; // For batch quotes

// Historical Data Controls
@property (nonatomic, strong) NSPopUpButton *timeframePopup;
@property (nonatomic, strong) NSDatePicker *startDatePicker;
@property (nonatomic, strong) NSDatePicker *endDatePicker;
@property (nonatomic, strong) NSTextField *barCountField;
@property (nonatomic, strong) NSButton *extendedHoursCheckbox;

// Market List Controls
@property (nonatomic, strong) NSTextField *limitField; // Max results
@property (nonatomic, strong) NSPopUpButton *marketTimeframePopup;

// Account Controls (for trading APIs)
@property (nonatomic, strong) NSTextField *accountIdField;

// Action Buttons
@property (nonatomic, strong) NSButton *executeButton;
@property (nonatomic, strong) NSButton *clearButton;
@property (nonatomic, strong) NSButton *ccopyRawButton; // NEW: Copy raw response

// RESULTS SECTION
@property (nonatomic, strong) NSTableView *resultsTableView;
@property (nonatomic, strong) NSScrollView *tableScrollView;
@property (nonatomic, strong) NSTextView *rawResponseTextView;
@property (nonatomic, strong) NSScrollView *textScrollView;

// Status
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSProgressIndicator *loadingIndicator;

#pragma mark - LEGACY TAB (keep existing)
@property (nonatomic, strong) NSView *historicalTabView;
// ... keep all existing historical tab properties ...

#pragma mark - Data Properties
@property (nonatomic, strong) NSMutableArray *resultData;
@property (nonatomic, strong) NSString *lastRawResponse;
@property (nonatomic, assign) APIPlaygroundRequestType currentRequestType;
@property (nonatomic, assign) DataSourceType preferredDataSource;
@property (nonatomic, strong) NSString *activeRequestID;

#pragma mark - NEW UNIFIED METHODS

// Setup
- (void)setupUnifiedTab;
- (void)setupResultsViews;

// Request Type Management
- (void)requestTypeChanged:(NSPopUpButton *)sender;
- (void)dataSourceChanged:(NSPopUpButton *)sender;
- (void)updateControlsVisibilityForRequestType:(APIPlaygroundRequestType)requestType;

// Execution
- (void)executeUnifiedRequest;
- (void)handleUnifiedResponse:(id)result
                   usedSource:(DataSourceType)usedSource
                        error:(NSError *)error;

// Results Display
- (void)populateTableWithData:(NSArray *)data;
- (void)displayRawResponse:(NSString *)response withSummary:(NSString *)summary;
- (NSString *)generateRequestSummary;

// Utility
- (void)copyRawResponseToClipboard;
- (void)clearAllResults;
// Account request helpers
- (void)executeAccountsRequestForAllBrokers;
- (void)executeAccountDataRequest:(APIPlaygroundRequestType)requestType parameters:(NSDictionary *)parameters;
@end

NS_ASSUME_NONNULL_END

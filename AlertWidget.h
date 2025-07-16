//
//  AlertWidget.h
//  TradingApp
//

#import <Cocoa/Cocoa.h>
#import "BaseWidget.h"
#import "AlertManager.h"

@interface AlertWidget : BaseWidget <NSTableViewDelegate, NSTableViewDataSource, NSSearchFieldDelegate, AlertManagerDelegate>

// UI Elements
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSSearchField *searchField;
@property (nonatomic, strong) NSButton *addButton;
@property (nonatomic, strong) NSButton *deleteButton;
@property (nonatomic, strong) NSButton *editButton;
@property (nonatomic, strong) NSButton *clearTriggeredButton;

// Toolbar
@property (nonatomic, strong) NSView *toolbarView;

// Data
@property (nonatomic, strong) NSMutableArray<AlertEntry *> *displayedAlerts;
@property (nonatomic, strong) NSString *searchFilter;

// Methods
- (void)refreshData;
- (void)addNewAlert;
- (void)editSelectedAlert;
- (void)deleteSelectedAlert;
- (void)clearTriggeredAlerts;
- (void)showAlertEditSheet:(AlertEntry *)alert;

@end

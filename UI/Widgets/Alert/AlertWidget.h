//
//  AlertWidget.h
//  mafia_AI
//
//  Widget per la gestione degli alert di prezzo
//

#import "BaseWidget.h"

@class Alert;

@interface AlertWidget : BaseWidget <NSTableViewDelegate, NSTableViewDataSource>

// UI Components
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSButton *addButton;
@property (nonatomic, strong) NSButton *deleteButton;
@property (nonatomic, strong) NSSegmentedControl *filterControl;
@property (nonatomic, strong) NSTextField *statusLabel;

// Data
@property (nonatomic, strong) NSArray<Alert *> *alerts;
@property (nonatomic, strong) NSArray<Alert *> *filteredAlerts;
@property (nonatomic, assign) NSInteger currentFilter; // 0=All, 1=Active, 2=Triggered

@end

// Alert creation/edit window controller
@interface AlertEditController : NSWindowController

@property (nonatomic, strong) Alert *alert; // nil for new alert
@property (nonatomic, copy) void (^completionHandler)(Alert *alert, BOOL saved);

- (instancetype)initWithAlert:(Alert *)alert;

@end

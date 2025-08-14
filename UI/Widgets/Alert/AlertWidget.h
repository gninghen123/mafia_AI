//
//  AlertWidget.h
//  mafia_AI
//
//  Widget per la gestione degli alert di prezzo
//  UPDATED: Usa solo RuntimeModels, no CoreData
//

#import "BaseWidget.h"
#import "RuntimeModels.h"
#import "AlertEditController.h"


@interface AlertWidget : BaseWidget <NSTableViewDelegate, NSTableViewDataSource>

// UI Components
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSTableView *tableView;
@property (nonatomic, strong) NSButton *addButton;
@property (nonatomic, strong) NSButton *deleteButton;
@property (nonatomic, strong) NSSegmentedControl *filterControl;
@property (nonatomic, strong) NSTextField *statusLabel;

// Data - ONLY RuntimeModels
@property (nonatomic, strong) NSArray<AlertModel *> *alerts;
@property (nonatomic, strong) NSArray<AlertModel *> *filteredAlerts;
@property (nonatomic, assign) NSInteger currentFilter; // 0=All, 1=Active, 2=Triggered
@property (nonatomic, strong) AlertEditController *alertEditController;

@end

//
//  ConnectionsWidget.h
//  mafia_AI
//
//  Widget per gestire le connections tra simboli
//

#import "BaseWidget.h"
#import "ConnectionModel.h"
#import "ConnectionTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface ConnectionsWidget : BaseWidget <NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate>

#pragma mark - UI Components

// Main views
@property (nonatomic, strong, readonly) NSScrollView *scrollView;
@property (nonatomic, strong, readonly) NSTableView *connectionsTableView;
@property (nonatomic, strong, readonly) NSSearchField *searchField;
@property (nonatomic, strong, readonly) NSPopUpButton *filterButton;
@property (nonatomic, strong, readonly) NSButton *addConnectionButton;
@property (nonatomic, strong, readonly) NSButton *settingsButton;

// Status views
@property (nonatomic, strong, readonly) NSTextField *statusLabel;
@property (nonatomic, strong, readonly) NSProgressIndicator *loadingIndicator;

#pragma mark - Data Management

// Data arrays
@property (nonatomic, strong) NSArray<ConnectionModel *> *allConnections;
@property (nonatomic, strong) NSArray<ConnectionModel *> *filteredConnections;

// State
@property (nonatomic, strong) NSString *searchText;
@property (nonatomic, assign) StockConnectionType selectedFilter;
@property (nonatomic, assign) BOOL showOnlyActive;
@property (nonatomic, assign) BOOL isLoading;

#pragma mark - Public Methods

// Data operations
- (void)refreshConnections;
- (void)searchConnections:(NSString *)query;
- (void)filterByType:(StockConnectionType)type;

// Connection management
- (void)createNewConnection;
- (void)createConnectionFromSymbols:(NSArray<NSString *> *)symbols;
- (void)editConnection:(ConnectionModel *)connection;
- (void)deleteConnection:(ConnectionModel *)connection;

// Selection and interaction
- (ConnectionModel * _Nullable)selectedConnection;
- (NSArray<ConnectionModel *> *)selectedConnections;
- (void)selectConnection:(ConnectionModel *)connection;

@end

NS_ASSUME_NONNULL_END

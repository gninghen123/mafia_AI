//
//  ChartObjectManagerWindow.h
//  TradingApp
//
//  Floating window per gestione avanzata degli oggetti chart
//

#import <Cocoa/Cocoa.h>
#import "ChartObjectsManager.h"

@class DataHub;

NS_ASSUME_NONNULL_BEGIN

@interface ChartObjectManagerWindow : NSPanel <NSOutlineViewDataSource, NSOutlineViewDelegate, NSTableViewDataSource, NSTableViewDelegate>

// Dependencies
@property (nonatomic, weak) ChartObjectsManager *objectsManager;
@property (nonatomic, weak) DataHub *dataHub;
@property (nonatomic, strong) NSString *currentSymbol;

// UI Components
@property (nonatomic, strong) NSOutlineView *layersOutlineView;
@property (nonatomic, strong) NSTableView *objectsTableView;
@property (nonatomic, strong) NSTextField *symbolLabel;

// Selected state
@property (nonatomic, strong, nullable) ChartLayerModel *selectedLayer;
@property (nonatomic, strong, nullable) ChartObjectModel *selectedObject;

// Initialization
- (instancetype)initWithObjectsManager:(ChartObjectsManager *)objectsManager
                               dataHub:(DataHub *)dataHub
                                symbol:(NSString *)symbol;

// Public actions
- (void)refreshContent;
- (void)updateForSymbol:(NSString *)symbol;

@end

NS_ASSUME_NONNULL_END

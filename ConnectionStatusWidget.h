//
//  ConnectionStatusWidget.h
//  TradingApp
//
//  Widget for displaying data source connection status
//

#import "BaseWidget.h"
#import "DataManager.h"

@interface ConnectionStatusWidget : BaseWidget <DataManagerDelegate>

// UI Elements
@property (nonatomic, strong, readonly) NSTextField *statusLabel;
@property (nonatomic, strong, readonly) NSTextField *sourceLabel;
@property (nonatomic, strong, readonly) NSButton *connectButton;
@property (nonatomic, strong, readonly) NSProgressIndicator *activityIndicator;

@end

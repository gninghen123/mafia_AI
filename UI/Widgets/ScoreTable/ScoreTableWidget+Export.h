//
//  ScoreTableWidget+Export.h
//  TradingApp
//
//  CSV Export to Clipboard
//

#import "ScoreTableWidget.h"

NS_ASSUME_NONNULL_BEGIN

@interface ScoreTableWidget (Export)

/// Export selected rows to clipboard as CSV
- (void)exportSelectionToClipboard:(id)sender;

/// Export all rows to clipboard as CSV
- (void)exportAllToClipboard:(id)sender;

@end

NS_ASSUME_NONNULL_END

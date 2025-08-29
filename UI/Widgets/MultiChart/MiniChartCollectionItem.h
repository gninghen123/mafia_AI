// ==========================================
// MiniChartCollectionItem.h - NUOVA CLASSE
// ==========================================
#import <Cocoa/Cocoa.h>
#import "MiniChart.h"

@interface MiniChartCollectionItem : NSCollectionViewItem

@property (nonatomic, strong) MiniChart *miniChart;

// Chain callback
@property (nonatomic, copy) void(^onChartClicked)(MiniChart *chart);
@property (nonatomic, copy) void(^onSetupContextMenu)(MiniChart *chart);

- (void)configureMiniChart:(MiniChart *)miniChart;

@end

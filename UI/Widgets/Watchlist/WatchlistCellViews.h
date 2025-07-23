//
//  WatchlistCellViews.h
//  mafia_AI
//

#import <Cocoa/Cocoa.h>

// Forward declaration
@interface WatchlistSymbolCellView : NSTableCellView
@property (nonatomic, strong) NSTextField *symbolField;
@property (nonatomic, assign) BOOL isEditable;
@end

@interface WatchlistPriceCellView : NSTableCellView
@property (nonatomic, strong) NSTextField *priceField;
@end

@interface WatchlistChangeCellView : NSTableCellView
@property (nonatomic, strong) NSTextField *changeField;
@property (nonatomic, strong) NSTextField *percentField;
@property (nonatomic, strong) NSImageView *trendIcon;
- (void)setChangeValue:(double)change percentChange:(double)percent;
@end

@interface WatchlistVolumeCellView : NSTableCellView
@property (nonatomic, strong) NSTextField *volumeField;
@property (nonatomic, strong) NSProgressIndicator *volumeBar;
- (void)setVolume:(NSNumber *)volume avgVolume:(NSNumber *)avgVolume;
@end

@interface WatchlistMarketCapCellView : NSTableCellView
@property (nonatomic, strong) NSTextField *marketCapField;
- (void)setMarketCap:(NSNumber *)marketCap;
@end

@interface WatchlistSidebarCellView : NSTableCellView
@property (nonatomic, strong) NSTextField *nameField;
@property (nonatomic, strong) NSTextField *countField;
@property (nonatomic, strong) NSImageView *iconView;
@end

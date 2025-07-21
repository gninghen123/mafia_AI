//
//  WatchlistManagerController.h
//  mafia_AI
//

#import <Cocoa/Cocoa.h>

@interface WatchlistManagerController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource>

@property (nonatomic, copy) void (^completionHandler)(BOOL changed);

@end

//
//  AddSymbolController.h
//  mafia_AI
//

#import <Cocoa/Cocoa.h>

@class Watchlist;

@interface AddSymbolController : NSWindowController <NSTextViewDelegate>

@property (nonatomic, strong) Watchlist *watchlist;
@property (nonatomic, copy) void (^completionHandler)(NSArray<NSString *> *symbols);

- (instancetype)initWithWatchlist:(Watchlist *)watchlist;

@end

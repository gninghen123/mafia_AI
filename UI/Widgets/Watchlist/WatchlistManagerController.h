//
//  WatchlistManagerController.h
//  mafia_AI
//

#import <Cocoa/Cocoa.h>

@interface WatchlistManagerController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, copy) void (^completionHandler)(BOOL changed);

@end

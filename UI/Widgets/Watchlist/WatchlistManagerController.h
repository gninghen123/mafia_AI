//
//  WatchlistManagerController.h
//  mafia_AI
//

#import <Cocoa/Cocoa.h>

@interface WatchlistManagerController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource>

@property (nonatomic, copy) void (^completionHandler)(BOOL changed);

@end

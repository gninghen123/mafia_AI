//
//  MarketQuote+CoreDataClass.m
//  mafia_AI
//

#import "MarketQuote+CoreDataClass.h"
#import <AppKit/AppKit.h>  // Aggiungi questo per NSColor

@implementation MarketQuote

- (BOOL)isGainer {
    return self.changePercent > 0;
}

- (BOOL)isLoser {
    return self.changePercent < 0;
}

- (NSColor *)changeColor {
    if (self.changePercent > 0) {
        return [NSColor systemGreenColor];
    } else if (self.changePercent < 0) {
        return [NSColor systemRedColor];
    }
    return [NSColor labelColor];
}

@end

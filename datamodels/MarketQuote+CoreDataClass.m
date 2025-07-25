//
//  MarketQuote+CoreDataClass.m
//  mafia_AI
//
//  Created by fabio gattone on 25/07/25.
//
//

#import "MarketQuote+CoreDataClass.h"

@implementation MarketQuote

@end
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

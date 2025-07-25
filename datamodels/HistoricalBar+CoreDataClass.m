//
//  HistoricalBar+CoreDataClass.m
//  mafia_AI
//
//  Created by fabio gattone on 25/07/25.
//
//

#import "HistoricalBar+CoreDataClass.h"

@implementation HistoricalBar

@end
- (double)typicalPrice {
    return (self.high + self.low + self.close) / 3.0;
}

- (double)range {
    return self.high - self.low;
}

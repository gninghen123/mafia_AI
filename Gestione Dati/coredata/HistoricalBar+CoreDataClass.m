//
//  HistoricalBar+CoreDataClass.m
//  mafia_AI
//

#import "HistoricalBar+CoreDataClass.h"

@implementation HistoricalBar

- (double)typicalPrice {
    return (self.high + self.low + self.close) / 3.0;
}

- (double)range {
    return self.high - self.low;
}

@end

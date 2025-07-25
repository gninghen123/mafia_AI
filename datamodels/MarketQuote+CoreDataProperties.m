//
//  MarketQuote+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 25/07/25.
//
//

#import "MarketQuote+CoreDataProperties.h"

@implementation MarketQuote (CoreDataProperties)

+ (NSFetchRequest<MarketQuote *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"MarketQuote"];
}

@dynamic symbol;
@dynamic name;
@dynamic exchange;
@dynamic currentPrice;
@dynamic previousClose;
@dynamic open;
@dynamic high;
@dynamic low;
@dynamic change;
@dynamic changePercent;
@dynamic volume;
@dynamic avgVolume;
@dynamic marketCap;
@dynamic pe;
@dynamic eps;
@dynamic beta;
@dynamic lastUpdate;
@dynamic marketTime;

@end

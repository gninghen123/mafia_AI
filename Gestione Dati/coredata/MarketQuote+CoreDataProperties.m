//
//  MarketQuote+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import "MarketQuote+CoreDataProperties.h"

@implementation MarketQuote (CoreDataProperties)

+ (NSFetchRequest<MarketQuote *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"MarketQuote"];
}

@dynamic avgVolume;
@dynamic beta;
@dynamic change;
@dynamic changePercent;
@dynamic currentPrice;
@dynamic eps;
@dynamic exchange;
@dynamic high;
@dynamic lastUpdate;
@dynamic low;
@dynamic marketCap;
@dynamic marketTime;
@dynamic name;
@dynamic open;
@dynamic pe;
@dynamic previousClose;
@dynamic volume;
@dynamic symbol;

@end

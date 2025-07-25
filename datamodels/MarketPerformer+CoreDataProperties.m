//
//  MarketPerformer+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 25/07/25.
//
//

#import "MarketPerformer+CoreDataProperties.h"

@implementation MarketPerformer (CoreDataProperties)

+ (NSFetchRequest<MarketPerformer *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"MarketPerformer"];
}

@dynamic symbol;
@dynamic name;
@dynamic price;
@dynamic changePercent;
@dynamic volume;
@dynamic listType;
@dynamic timeframe;
@dynamic timestamp;

@end

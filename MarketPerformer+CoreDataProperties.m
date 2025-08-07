//
//  MarketPerformer+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import "MarketPerformer+CoreDataProperties.h"

@implementation MarketPerformer (CoreDataProperties)

+ (NSFetchRequest<MarketPerformer *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"MarketPerformer"];
}

@dynamic changePercent;
@dynamic listType;
@dynamic name;
@dynamic price;
@dynamic timeframe;
@dynamic timestamp;
@dynamic volume;
@dynamic symbol;

@end

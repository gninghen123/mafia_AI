//
//  Symbol+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import "Symbol+CoreDataProperties.h"

@implementation Symbol (CoreDataProperties)

+ (NSFetchRequest<Symbol *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"Symbol"];
}

@dynamic creationDate;
@dynamic firstInteraction;
@dynamic interactionCount;
@dynamic isFavorite;
@dynamic lastInteraction;
@dynamic notes;
@dynamic symbol;
@dynamic tags;
@dynamic alerts;
@dynamic chartLayers;
@dynamic companyInfo;
@dynamic historicalBars;
@dynamic marketPerformers;
@dynamic marketQuotes;
@dynamic sourceConnections;
@dynamic targetConnections;
@dynamic tradingModels;
@dynamic watchlists;

@end

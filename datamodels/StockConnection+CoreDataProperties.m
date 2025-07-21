//
//  StockConnection+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 21/07/25.
//
//

#import "StockConnection+CoreDataProperties.h"

@implementation StockConnection (CoreDataProperties)

+ (NSFetchRequest<StockConnection *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"StockConnection"];
}

@dynamic connectionDescription;
@dynamic connectionType;
@dynamic creationDate;
@dynamic source;
@dynamic symbols;
@dynamic url;

@end

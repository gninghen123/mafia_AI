//
//  StockConnection+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import "StockConnection+CoreDataProperties.h"

@implementation StockConnection (CoreDataProperties)

+ (NSFetchRequest<StockConnection *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"StockConnection"];
}

@dynamic autoDelete;
@dynamic bidirectional;
@dynamic connectionDescription;
@dynamic connectionID;
@dynamic connectionType;
@dynamic creationDate;
@dynamic currentStrength;
@dynamic decayRate;
@dynamic initialStrength;
@dynamic isActive;
@dynamic lastModified;
@dynamic lastStrengthUpdate;
@dynamic manualSummary;
@dynamic minimumStrength;
@dynamic notes;
@dynamic originalSummary;
@dynamic source;
@dynamic strengthHorizon;
@dynamic summarySource;
@dynamic tags;
@dynamic title;
@dynamic url;
@dynamic sourceSymbol;
@dynamic targetSymbols;

@end

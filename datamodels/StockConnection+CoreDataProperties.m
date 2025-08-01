//
//  StockConnection+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 31/07/25.
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
@dynamic connectionID;
@dynamic title;
@dynamic lastModified;
@dynamic isActive;
@dynamic sourceSymbol;
@dynamic targetSymbols;
@dynamic bidirectional;
@dynamic originalSummary;
@dynamic manualSummary;
@dynamic summarySource;
@dynamic initialStrength;
@dynamic currentStrength;
@dynamic decayRate;
@dynamic minimumStrength;
@dynamic strengthHorizon;
@dynamic autoDelete;
@dynamic lastStrengthUpdate;
@dynamic notes;
@dynamic tags;

@end

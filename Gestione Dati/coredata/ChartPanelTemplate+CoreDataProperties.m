//
//  ChartPanelTemplate+CoreDataProperties.m
//  mafia_AI
//
//  Created by fabio gattone on 02/09/25.
//
//

#import "ChartPanelTemplate+CoreDataProperties.h"

@implementation ChartPanelTemplate (CoreDataProperties)

+ (NSFetchRequest<ChartPanelTemplate *> *)fetchRequest {
	return [NSFetchRequest fetchRequestWithEntityName:@"ChartPanelTemplate"];
}

@dynamic childIndicatorsData;
@dynamic displayOrder;
@dynamic panelID;
@dynamic panelName;
@dynamic relativeHeight;
@dynamic rootIndicatorParams;
@dynamic rootIndicatorType;
@dynamic template;

@end

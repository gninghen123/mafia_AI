//
//  ChartPanelTemplate+CoreDataProperties.h
//  mafia_AI
//
//  Created by fabio gattone on 02/09/25.
//
//

#import "ChartPanelTemplate+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface ChartPanelTemplate (CoreDataProperties)

+ (NSFetchRequest<ChartPanelTemplate *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nullable, nonatomic, copy) NSString *panelID;
@property (nonatomic) double relativeHeight;
@property (nonatomic) int16_t displayOrder;
@property (nullable, nonatomic, copy) NSString *panelName;
@property (nullable, nonatomic, copy) NSString *rootIndicatorType;
@property (nullable, nonatomic, retain) NSData *rootIndicatorParams;
@property (nullable, nonatomic, retain) NSData *childIndicatorsData;
@property (nullable, nonatomic, retain) ChartTemplate *template;

@end

NS_ASSUME_NONNULL_END

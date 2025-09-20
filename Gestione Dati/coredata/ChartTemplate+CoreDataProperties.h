//
//  ChartTemplate+CoreDataProperties.h
//  mafia_AI
//
//  Created by fabio gattone on 02/09/25.
//
//

#import "ChartTemplate+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface ChartTemplate (CoreDataProperties)

+ (NSFetchRequest<ChartTemplate *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nullable, nonatomic, copy) NSDate *createdDate;
@property (nonatomic) BOOL isDefault;
@property (nullable, nonatomic, copy) NSDate *modifiedDate;
@property (nullable, nonatomic, copy) NSString *templateID;
@property (nullable, nonatomic, copy) NSString *templateName;
@property (nullable, nonatomic, retain) NSSet<ChartPanelTemplate *> *panels;

@end

@interface ChartTemplate (CoreDataGeneratedAccessors)

- (void)addPanelsObject:(ChartPanelTemplate *)value;
- (void)removePanelsObject:(ChartPanelTemplate *)value;
- (void)addPanels:(NSSet<ChartPanelTemplate *> *)values;
- (void)removePanels:(NSSet<ChartPanelTemplate *> *)values;

@end

NS_ASSUME_NONNULL_END

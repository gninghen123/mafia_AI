//
//  Alert+CoreDataProperties.h
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import "Alert+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface Alert (CoreDataProperties)

+ (NSFetchRequest<Alert *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nullable, nonatomic, copy) NSString *conditionString;
@property (nullable, nonatomic, copy) NSDate *creationDate;
@property (nonatomic) BOOL isActive;
@property (nonatomic) BOOL isTriggered;
@property (nullable, nonatomic, copy) NSString *notes;
@property (nonatomic) BOOL notificationEnabled;
@property (nullable, nonatomic, copy) NSDate *triggerDate;
@property (nonatomic) double triggerValue;
@property (nullable, nonatomic, retain) Symbol *symbol;

@end

NS_ASSUME_NONNULL_END

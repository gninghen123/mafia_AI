//
//  MarketPerformer+CoreDataProperties.h
//  mafia_AI
//
//  Created by fabio gattone on 25/07/25.
//
//

#import "MarketPerformer+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface MarketPerformer (CoreDataProperties)

+ (NSFetchRequest<MarketPerformer *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nullable, nonatomic, copy) NSString *symbol;
@property (nullable, nonatomic, copy) NSString *name;
@property (nonatomic) double price;
@property (nonatomic) double changePercent;
@property (nonatomic) int64_t volume;
@property (nullable, nonatomic, copy) NSString *listType;
@property (nullable, nonatomic, copy) NSString *timeframe;
@property (nullable, nonatomic, copy) NSDate *timestamp;

@end

NS_ASSUME_NONNULL_END

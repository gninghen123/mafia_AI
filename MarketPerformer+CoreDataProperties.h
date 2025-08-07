//
//  MarketPerformer+CoreDataProperties.h
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import "MarketPerformer+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface MarketPerformer (CoreDataProperties)

+ (NSFetchRequest<MarketPerformer *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nonatomic) double changePercent;
@property (nullable, nonatomic, copy) NSString *listType;
@property (nullable, nonatomic, copy) NSString *name;
@property (nonatomic) double price;
@property (nullable, nonatomic, copy) NSString *timeframe;
@property (nullable, nonatomic, copy) NSDate *timestamp;
@property (nonatomic) int64_t volume;
@property (nullable, nonatomic, retain) Symbol *symbol;

@end

NS_ASSUME_NONNULL_END

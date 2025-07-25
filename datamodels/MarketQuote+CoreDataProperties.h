//
//  MarketQuote+CoreDataProperties.h
//  mafia_AI
//
//  Created by fabio gattone on 25/07/25.
//
//

#import "MarketQuote+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface MarketQuote (CoreDataProperties)

+ (NSFetchRequest<MarketQuote *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nullable, nonatomic, copy) NSString *symbol;
@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, copy) NSString *exchange;
@property (nonatomic) double currentPrice;
@property (nonatomic) double previousClose;
@property (nonatomic) double open;
@property (nonatomic) double high;
@property (nonatomic) double low;
@property (nonatomic) double change;
@property (nonatomic) double changePercent;
@property (nonatomic) int64_t volume;
@property (nonatomic) int64_t avgVolume;
@property (nonatomic) double marketCap;
@property (nonatomic) double pe;
@property (nonatomic) double eps;
@property (nonatomic) double beta;
@property (nullable, nonatomic, copy) NSDate *lastUpdate;
@property (nullable, nonatomic, copy) NSDate *marketTime;

@end

NS_ASSUME_NONNULL_END

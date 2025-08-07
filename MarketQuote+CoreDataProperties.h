//
//  MarketQuote+CoreDataProperties.h
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import "MarketQuote+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface MarketQuote (CoreDataProperties)

+ (NSFetchRequest<MarketQuote *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nonatomic) int64_t avgVolume;
@property (nonatomic) double beta;
@property (nonatomic) double change;
@property (nonatomic) double changePercent;
@property (nonatomic) double currentPrice;
@property (nonatomic) double eps;
@property (nullable, nonatomic, copy) NSString *exchange;
@property (nonatomic) double high;
@property (nullable, nonatomic, copy) NSDate *lastUpdate;
@property (nonatomic) double low;
@property (nonatomic) double marketCap;
@property (nullable, nonatomic, copy) NSDate *marketTime;
@property (nullable, nonatomic, copy) NSString *name;
@property (nonatomic) double open;
@property (nonatomic) double pe;
@property (nonatomic) double previousClose;
@property (nonatomic) int64_t volume;
@property (nullable, nonatomic, retain) Symbol *symbol;

@end

NS_ASSUME_NONNULL_END

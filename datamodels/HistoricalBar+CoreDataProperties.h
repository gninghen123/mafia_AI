//
//  HistoricalBar+CoreDataProperties.h
//  mafia_AI
//
//  Created by fabio gattone on 25/07/25.
//
//

#import "HistoricalBar+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface HistoricalBar (CoreDataProperties)

+ (NSFetchRequest<HistoricalBar *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nullable, nonatomic, copy) NSString *symbol;
@property (nullable, nonatomic, copy) NSDate *date;
@property (nonatomic) double open;
@property (nonatomic) double high;
@property (nonatomic) double low;
@property (nonatomic) double close;
@property (nonatomic) double adjustedClose;
@property (nonatomic) int64_t volume;
@property (nonatomic) int16_t timeframe;

@end

NS_ASSUME_NONNULL_END

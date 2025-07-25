#import <Cocoa/Cocoa.h>


#pragma mark - HistoricalBar Entity
// Memorizza dati OHLCV storici
@interface HistoricalBar : NSManagedObject

@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic) double open;
@property (nonatomic) double high;
@property (nonatomic) double low;
@property (nonatomic) double close;
@property (nonatomic) double adjustedClose;
@property (nonatomic) int64_t volume;
@property (nonatomic) int16_t timeframe; // enum BarTimeframe

// Calcolati
@property (nonatomic, readonly) double typicalPrice;
@property (nonatomic, readonly) double range;

@end

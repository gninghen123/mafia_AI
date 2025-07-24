// DataStandardization.h
// Define standard models and adapter protocol

#import <Foundation/Foundation.h>
#import "MarketDataModels.h"

// Protocol that all adapters must implement
@protocol DataSourceAdapter <NSObject>

@required
// Convert quote data from API format to standard MarketData
- (MarketData *)standardizeQuoteData:(NSDictionary *)rawData forSymbol:(NSString *)symbol;

// Convert historical data from API format to standard HistoricalBar array
- (NSArray<HistoricalBar *> *)standardizeHistoricalData:(id)rawData forSymbol:(NSString *)symbol;

// Convert position data from API format to standard Position
- (Position *)standardizePositionData:(NSDictionary *)rawData;

// Convert order data from API format to standard Order
- (Order *)standardizeOrderData:(NSDictionary *)rawData;

@optional
// Source name for logging/debugging
- (NSString *)sourceName;

@end

//
//  TickDataModel.h
//  mafia_AI
//
//  Runtime model for tick-by-tick trade data
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, TickDirection) {
    TickDirectionDown = -1,     // Selling pressure (price < previous)
    TickDirectionNeutral = 0,   // No pressure (price = previous)
    TickDirectionUp = 1         // Buying pressure (price > previous)
};

typedef NS_ENUM(NSInteger, MarketSession) {
    MarketSessionPreMarket,     // 4:00-9:30 ET
    MarketSessionRegular,       // 9:30-16:00 ET
    MarketSessionAfterHours     // 16:00-20:00 ET
};

@interface TickDataModel : NSObject

#pragma mark - Core Trade Data

@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic) double price;
@property (nonatomic) NSInteger volume;
@property (nonatomic, strong) NSString *exchange;
@property (nonatomic, strong) NSString *conditions;
@property (nonatomic) double dollarVolume;

#pragma mark - Analysis Properties

@property (nonatomic) TickDirection direction;      // Calculated: up/down/neutral tick
@property (nonatomic) MarketSession session;        // Pre/Regular/After hours
@property (nonatomic) double priceChange;           // Change from previous tick
@property (nonatomic) BOOL isSignificantTrade;      // Large block trade (volume > threshold)

#pragma mark - Factory Methods

// Create from Nasdaq API response
+ (instancetype)tickFromNasdaqData:(NSDictionary *)data;

// Create array from API response array
+ (NSArray<TickDataModel *> *)ticksFromNasdaqDataArray:(NSArray *)dataArray;

#pragma mark - Analysis Methods

// Calculate tick direction compared to previous tick
- (void)calculateDirectionFromPreviousTick:(TickDataModel *)previousTick;

// Determine market session from timestamp
- (void)calculateMarketSession;

// Check if this is a significant trade (large volume)
- (void)calculateSignificanceWithVolumeThreshold:(NSInteger)threshold;

#pragma mark - Utility Methods

// Format timestamp for display
- (NSString *)formattedTime;
- (NSString *)formattedTimeWithSeconds;

// Get tick direction as string
- (NSString *)directionString;

// Get session as string
- (NSString *)sessionString;

@end

#pragma mark - MarketPerformer Entity
// Per liste di gainers/losers
@interface MarketPerformer : NSManagedObject

@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong) NSString *name;
@property (nonatomic) double price;
@property (nonatomic) double changePercent;
@property (nonatomic) int64_t volume;
@property (nonatomic, strong) NSString *listType; // "gainers", "losers", "active"
@property (nonatomic, strong) NSString *timeframe; // "1d", "52w", etc.
@property (nonatomic, strong) NSDate *timestamp;

@end

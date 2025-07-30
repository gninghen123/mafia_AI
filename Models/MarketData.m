//
//  MarketData.m
//  mafia_AI
//

#import "MarketData.h"

@implementation MarketData

- (instancetype)init {
    self = [super init];
    if (self) {
        _timestamp = [NSDate date];
        _isMarketOpen = YES;
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [self init];
    if (self) {
        // Identificazione
        _symbol = dictionary[@"symbol"];
        _name = dictionary[@"name"];
        _exchange = dictionary[@"exchange"];
        
        // Prezzi
        _last = dictionary[@"last"];
        _bid = dictionary[@"bid"];
        _ask = dictionary[@"ask"];
        _open = dictionary[@"open"];
        _high = dictionary[@"high"];
        _low = dictionary[@"low"];
        _previousClose = dictionary[@"previousClose"];
        _close = dictionary[@"close"];
        
        // Variazioni
        _change = dictionary[@"change"];
        _changePercent = dictionary[@"changePercent"];
        
        // Volume
        _volume = dictionary[@"volume"];
        _avgVolume = dictionary[@"avgVolume"];
        
        // Altri dati
        _marketCap = dictionary[@"marketCap"];
        _pe = dictionary[@"pe"];
        _eps = dictionary[@"eps"];
        _beta = dictionary[@"beta"];
        
        // Timestamp
        if (dictionary[@"timestamp"]) {
            _timestamp = dictionary[@"timestamp"];
        }
        
        if (dictionary[@"isMarketOpen"]) {
            _isMarketOpen = [dictionary[@"isMarketOpen"] boolValue];
        }
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    // Identificazione
    if (_symbol) dict[@"symbol"] = _symbol;
    if (_name) dict[@"name"] = _name;
    if (_exchange) dict[@"exchange"] = _exchange;
    
    // Prezzi
    if (_last) dict[@"last"] = _last;
    if (_bid) dict[@"bid"] = _bid;
    if (_ask) dict[@"ask"] = _ask;
    if (_open) dict[@"open"] = _open;
    if (_high) dict[@"high"] = _high;
    if (_low) dict[@"low"] = _low;
    if (_previousClose) dict[@"previousClose"] = _previousClose;
    if (_close) dict[@"close"] = _close;
    
    // Variazioni
    if (_change) dict[@"change"] = _change;
    if (_changePercent) dict[@"changePercent"] = _changePercent;
    
    // Volume
    if (_volume) dict[@"volume"] = _volume;
    if (_avgVolume) dict[@"avgVolume"] = _avgVolume;
    
    // Altri dati
    if (_marketCap) dict[@"marketCap"] = _marketCap;
    if (_pe) dict[@"pe"] = _pe;
    if (_eps) dict[@"eps"] = _eps;
    if (_beta) dict[@"beta"] = _beta;
    
    // Timestamp
    dict[@"timestamp"] = _timestamp;
    dict[@"isMarketOpen"] = @(_isMarketOpen);
    
    return [dict copy];
}

#pragma mark - Helper Methods

- (BOOL)isGainer {
    return [self.changePercent doubleValue] > 0;
}

- (BOOL)isLoser {
    return [self.changePercent doubleValue] < 0;
}

- (NSString *)formattedPrice {
    if (!self.last) return @"--";
    return [NSString stringWithFormat:@"$%.2f", [self.last doubleValue]];
}

- (NSString *)formattedChange {
    if (!self.change) return @"--";
    double changeValue = [self.change doubleValue];
    NSString *sign = changeValue >= 0 ? @"+" : @"";
    return [NSString stringWithFormat:@"%@%.2f", sign, changeValue];
}

- (NSString *)formattedChangePercent {
    if (!self.changePercent) return @"--";
    double changeValue = [self.changePercent doubleValue];
    NSString *sign = changeValue >= 0 ? @"+" : @"";
    return [NSString stringWithFormat:@"%@%.2f%%", sign, changeValue];
}

@end

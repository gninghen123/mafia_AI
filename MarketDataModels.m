//
//  MarketDataModels.m
//  TradingApp
//

#import "MarketDataModels.h"

#pragma mark - MarketData

@implementation MarketData

- (instancetype)init {
    self = [super init];
    if (self) {
        _timestamp = [NSDate date];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [self init];
    if (self) {
        NSLog(@"MarketData: Initializing with dictionary: %@", dictionary);
        
        _symbol = dictionary[@"symbol"];
        NSLog(@"MarketData: Symbol: %@", _symbol);
        
        _bid = [self decimalNumberFromValue:dictionary[@"bid"]];
        NSLog(@"MarketData: Bid: %@ (from: %@)", _bid, dictionary[@"bid"]);
        
        _ask = [self decimalNumberFromValue:dictionary[@"ask"]];
        NSLog(@"MarketData: Ask: %@ (from: %@)", _ask, dictionary[@"ask"]);
        
        _last = [self decimalNumberFromValue:dictionary[@"last"]];
        NSLog(@"MarketData: Last: %@ (from: %@)", _last, dictionary[@"last"]);
        
        _open = [self decimalNumberFromValue:dictionary[@"open"]];
        _high = [self decimalNumberFromValue:dictionary[@"high"]];
        _low = [self decimalNumberFromValue:dictionary[@"low"]];
        _close = [self decimalNumberFromValue:dictionary[@"close"]];
        _previousClose = [self decimalNumberFromValue:dictionary[@"previousClose"]];
        
        _volume = [dictionary[@"volume"] integerValue];
        _bidSize = [dictionary[@"bidSize"] integerValue];
        _askSize = [dictionary[@"askSize"] integerValue];
        _exchange = dictionary[@"exchange"];
        _isMarketOpen = [dictionary[@"isMarketOpen"] boolValue];
        
        if (dictionary[@"timestamp"]) {
            _timestamp = [NSDate dateWithTimeIntervalSince1970:[dictionary[@"timestamp"] doubleValue]];
        }
        
        // Calculate change and change percent if not provided
        if (!dictionary[@"change"] && _last && _previousClose) {
            _change = [_last decimalNumberBySubtracting:_previousClose];
            NSLog(@"MarketData: Calculated change: %@", _change);
        } else {
            _change = [self decimalNumberFromValue:dictionary[@"change"]];
            NSLog(@"MarketData: Change from data: %@", _change);
        }
        
        if (!dictionary[@"changePercent"] && _change && _previousClose && ![_previousClose isEqualToNumber:[NSDecimalNumber zero]]) {
            NSDecimalNumber *hundred = [NSDecimalNumber decimalNumberWithString:@"100"];
            _changePercent = [[_change decimalNumberByDividingBy:_previousClose] decimalNumberByMultiplyingBy:hundred];
            NSLog(@"MarketData: Calculated changePercent: %@", _changePercent);
        } else {
            _changePercent = [self decimalNumberFromValue:dictionary[@"changePercent"]];
            NSLog(@"MarketData: ChangePercent from data: %@", _changePercent);
        }
        
        NSLog(@"MarketData: Final quote - Symbol: %@, Last: %@, Change: %@", _symbol, _last, _change);
    }
    return self;
}
- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    if (_symbol) dict[@"symbol"] = _symbol;
    if (_bid) dict[@"bid"] = _bid;
    if (_ask) dict[@"ask"] = _ask;
    if (_last) dict[@"last"] = _last;
    if (_open) dict[@"open"] = _open;
    if (_high) dict[@"high"] = _high;
    if (_low) dict[@"low"] = _low;
    if (_close) dict[@"close"] = _close;
    if (_previousClose) dict[@"previousClose"] = _previousClose;
    dict[@"volume"] = @(_volume);
    dict[@"bidSize"] = @(_bidSize);
    dict[@"askSize"] = @(_askSize);
    if (_exchange) dict[@"exchange"] = _exchange;
    dict[@"isMarketOpen"] = @(_isMarketOpen);
    if (_timestamp) dict[@"timestamp"] = @([_timestamp timeIntervalSince1970]);
    if (_change) dict[@"change"] = _change;
    if (_changePercent) dict[@"changePercent"] = _changePercent;
    
    return dict;
}

- (NSDecimalNumber *)decimalNumberFromValue:(id)value {
    if (!value || value == [NSNull null]) {
        NSLog(@"MarketData: Value is nil or NSNull");
        return nil;
    }
    
    NSLog(@"MarketData: Converting value: %@ (class: %@)", value, [value class]);
    
    if ([value isKindOfClass:[NSDecimalNumber class]]) {
        NSLog(@"MarketData: Value is already NSDecimalNumber: %@", value);
        return value;
    } else if ([value isKindOfClass:[NSNumber class]]) {
        NSLog(@"MarketData: Converting NSNumber to NSDecimalNumber: %@", value);
        
        // Verifica se il NSNumber è valido
        double doubleValue = [value doubleValue];
        if (isnan(doubleValue) || isinf(doubleValue)) {
            NSLog(@"MarketData: NSNumber contains invalid value (NaN or Inf): %f", doubleValue);
            return nil;
        }
        
        return [NSDecimalNumber decimalNumberWithDecimal:[value decimalValue]];
    } else if ([value isKindOfClass:[NSString class]]) {
        NSLog(@"MarketData: Converting NSString to NSDecimalNumber: %@", value);
        
        NSString *stringValue = (NSString *)value;
        
        // Rimuovi spazi e caratteri non numerici
        stringValue = [stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (stringValue.length == 0 || [stringValue isEqualToString:@"null"] || [stringValue isEqualToString:@"N/A"]) {
            NSLog(@"MarketData: String is empty or contains null value");
            return nil;
        }
        
        NSDecimalNumber *result = [NSDecimalNumber decimalNumberWithString:stringValue];
        
        // Verifica se la conversione è riuscita
        if ([result isEqual:[NSDecimalNumber notANumber]]) {
            NSLog(@"MarketData: String conversion failed, result is NaN: %@", stringValue);
            return nil;
        }
        
        NSLog(@"MarketData: Successfully converted string to NSDecimalNumber: %@", result);
        return result;
    }
    
    NSLog(@"MarketData: Unknown value type: %@", [value class]);
    return nil;
}
@end
#pragma mark - HistoricalBar

@implementation HistoricalBar

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    self = [super init];
    if (self) {
        if (dictionary[@"timestamp"]) {
            _timestamp = [NSDate dateWithTimeIntervalSince1970:[dictionary[@"timestamp"] doubleValue]];
        }
        
        _open = [self decimalNumberFromValue:dictionary[@"open"]];
        _high = [self decimalNumberFromValue:dictionary[@"high"]];
        _low = [self decimalNumberFromValue:dictionary[@"low"]];
        _close = [self decimalNumberFromValue:dictionary[@"close"]];
        _volume = [dictionary[@"volume"] integerValue];
        _vwap = [self decimalNumberFromValue:dictionary[@"vwap"]];
        _trades = [dictionary[@"trades"] integerValue];
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    if (_timestamp) dict[@"timestamp"] = @([_timestamp timeIntervalSince1970]);
    if (_open) dict[@"open"] = _open;
    if (_high) dict[@"high"] = _high;
    if (_low) dict[@"low"] = _low;
    if (_close) dict[@"close"] = _close;
    dict[@"volume"] = @(_volume);
    if (_vwap) dict[@"vwap"] = _vwap;
    dict[@"trades"] = @(_trades);
    
    return dict;
}

- (NSDecimalNumber *)decimalNumberFromValue:(id)value {
    if (!value || value == [NSNull null]) {
        return nil;
    }
    
    if ([value isKindOfClass:[NSDecimalNumber class]]) {
        return value;
    } else if ([value isKindOfClass:[NSNumber class]]) {
        return [NSDecimalNumber decimalNumberWithDecimal:[value decimalValue]];
    } else if ([value isKindOfClass:[NSString class]]) {
        return [NSDecimalNumber decimalNumberWithString:value];
    }
    
    return nil;
}

@end

#pragma mark - OrderBookEntry

@implementation OrderBookEntry

- (instancetype)initWithPrice:(NSDecimalNumber *)price size:(NSInteger)size {
    self = [super init];
    if (self) {
        _price = price;
        _size = size;
        _timestamp = [NSDate date];
    }
    return self;
}

@end

#pragma mark - TimeSalesEntry

@implementation TimeSalesEntry
@end

#pragma mark - Position

@implementation Position

- (NSDecimalNumber *)totalPnL {
    if (!_unrealizedPnL || !_realizedPnL) {
        return [NSDecimalNumber zero];
    }
    return [_unrealizedPnL decimalNumberByAdding:_realizedPnL];
}

- (NSDecimalNumber *)totalPnLPercent {
    NSDecimalNumber *totalPnL = [self totalPnL];
    if (!totalPnL || !_averageCost || [_averageCost isEqualToNumber:[NSDecimalNumber zero]]) {
        return [NSDecimalNumber zero];
    }
    
    NSDecimalNumber *totalCost = [_averageCost decimalNumberByMultiplyingBy:
                                  [NSDecimalNumber decimalNumberWithDecimal:[@(_quantity) decimalValue]]];
    
    if ([totalCost isEqualToNumber:[NSDecimalNumber zero]]) {
        return [NSDecimalNumber zero];
    }
    
    NSDecimalNumber *hundred = [NSDecimalNumber decimalNumberWithString:@"100"];
    return [[totalPnL decimalNumberByDividingBy:totalCost] decimalNumberByMultiplyingBy:hundred];
}

@end

#pragma mark - Order

@implementation Order

- (BOOL)isActive {
    return [_status isEqualToString:@"pending"] ||
           [_status isEqualToString:@"open"] ||
           [_status isEqualToString:@"partially_filled"] ||
           [_status isEqualToString:@"accepted"] ||
           [_status isEqualToString:@"new"];
}

- (BOOL)isFilled {
    return [_status isEqualToString:@"filled"] ||
           [_status isEqualToString:@"executed"];
}

- (BOOL)isCancelled {
    return [_status isEqualToString:@"cancelled"] ||
           [_status isEqualToString:@"rejected"] ||
           [_status isEqualToString:@"expired"];
}

@end

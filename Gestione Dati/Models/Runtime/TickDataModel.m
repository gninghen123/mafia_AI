
//
//  TickDataModel.m
//  mafia_AI
//

#import "TickDataModel.h"

@implementation TickDataModel

#pragma mark - Factory Methods

+ (instancetype)tickFromNasdaqData:(NSDictionary *)data {
    TickDataModel *tick = [[TickDataModel alloc] init];
    
    // Extract basic data
    tick.symbol = data[@"symbol"] ?: @"";
    tick.price = [data[@"price"] doubleValue];
    tick.volume = [data[@"size"] integerValue];
    tick.exchange = data[@"exchange"] ?: @"";
    tick.conditions = data[@"conditions"] ?: @"";
    tick.dollarVolume = [data[@"dollarVolume"] doubleValue];
    
    // Parse timestamp
    NSString *timeString = data[@"timestamp"] ?: data[@"nlsTime"] ?: data[@"time"];
    tick.timestamp = [self parseNasdaqTimestamp:timeString];
    
    // Calculate derived properties
    [tick calculateMarketSession];
    [tick calculateSignificanceWithVolumeThreshold:10000]; // Default 10K+ shares
    
    return tick;
}

+ (NSArray<TickDataModel *> *)ticksFromNasdaqDataArray:(NSArray *)dataArray {
    NSMutableArray *ticks = [NSMutableArray array];
    TickDataModel *previousTick = nil;
    
    for (NSDictionary *data in dataArray) {
        TickDataModel *tick = [self tickFromNasdaqData:data];
        
        // Calculate direction from previous tick
        if (previousTick) {
            [tick calculateDirectionFromPreviousTick:previousTick];
        }
        
        [ticks addObject:tick];
        previousTick = tick;
    }
    
    return [ticks copy];
}

#pragma mark - Analysis Methods

- (void)calculateDirectionFromPreviousTick:(TickDataModel *)previousTick {
    if (!previousTick) {
        self.direction = TickDirectionNeutral;
        self.priceChange = 0.0;
        return;
    }
    
    self.priceChange = self.price - previousTick.price;
    
    if (self.priceChange > 0.001) {
        self.direction = TickDirectionUp;
    } else if (self.priceChange < -0.001) {
        self.direction = TickDirectionDown;
    } else {
        self.direction = TickDirectionNeutral;
    }
}

- (void)calculateMarketSession {
    if (!self.timestamp) {
        self.session = MarketSessionRegular;
        return;
    }
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute
                                               fromDate:self.timestamp];
    
    NSInteger hour = components.hour;
    NSInteger minute = components.minute;
    NSInteger totalMinutes = hour * 60 + minute;
    
    // Convert to ET (assuming data is already in ET)
    if (totalMinutes >= 4 * 60 && totalMinutes < 9 * 60 + 30) {
        self.session = MarketSessionPreMarket;
    } else if (totalMinutes >= 9 * 60 + 30 && totalMinutes < 16 * 60) {
        self.session = MarketSessionRegular;
    } else {
        self.session = MarketSessionAfterHours;
    }
}

- (void)calculateSignificanceWithVolumeThreshold:(NSInteger)threshold {
    self.isSignificantTrade = (self.volume >= threshold);
}

#pragma mark - Utility Methods

- (NSString *)formattedTime {
    if (!self.timestamp) return @"--:--";
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm";
    return [formatter stringFromDate:self.timestamp];
}

- (NSString *)formattedTimeWithSeconds {
    if (!self.timestamp) return @"--:--:--";
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss";
    return [formatter stringFromDate:self.timestamp];
}

- (NSString *)directionString {
    switch (self.direction) {
        case TickDirectionUp:
            return @"↑";
        case TickDirectionDown:
            return @"↓";
        case TickDirectionNeutral:
            return @"→";
        default:
            return @"?";
    }
}

- (NSString *)sessionString {
    switch (self.session) {
        case MarketSessionPreMarket:
            return @"Pre";
        case MarketSessionRegular:
            return @"Regular";
        case MarketSessionAfterHours:
            return @"After";
        default:
            return @"Unknown";
    }
}

#pragma mark - Private Methods

+ (NSDate *)parseNasdaqTimestamp:(NSString *)timeString {
    if (!timeString || timeString.length == 0) {
        return [NSDate date];
    }
    
    // Handle various Nasdaq timestamp formats
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    
    // Try different formats
    NSArray *formats = @[
        @"HH:mm:ss",
        @"HH:mm",
        @"yyyy-MM-dd HH:mm:ss",
        @"MM/dd/yyyy HH:mm:ss"
    ];
    
    for (NSString *format in formats) {
        formatter.dateFormat = format;
        NSDate *date = [formatter dateFromString:timeString];
        if (date) {
            // If only time is provided, use today's date
            if (format.length <= 8) {
                NSCalendar *calendar = [NSCalendar currentCalendar];
                NSDateComponents *todayComponents = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay
                                                             fromDate:[NSDate date]];
                NSDateComponents *timeComponents = [calendar components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond
                                                              fromDate:date];
                
                todayComponents.hour = timeComponents.hour;
                todayComponents.minute = timeComponents.minute;
                todayComponents.second = timeComponents.second;
                
                return [calendar dateFromComponents:todayComponents];
            }
            return date;
        }
    }
    
    // Fallback to current time
    return [NSDate date];
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"TickData[%@ %@ %.2f x%ld %@ %@]",
            self.symbol,
            [self formattedTimeWithSeconds],
            self.price,
            (long)self.volume,
            [self directionString],
            self.exchange];
}

@end

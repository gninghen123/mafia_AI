#import "RuntimeModels.h"


// =======================================
// IMPLEMENTATION
// =======================================

@implementation HistoricalBarModel

#pragma mark - Convenience Methods

- (double)typicalPrice {
    return (self.high + self.low + self.close) / 3.0;
}

- (double)range {
    return self.high - self.low;
}

- (double)midPoint {
    return (self.high + self.low) / 2.0;
}

- (BOOL)isGreen {
    return self.close > self.open;
}

- (BOOL)isRed {
    return self.close < self.open;
}

- (double)bodySize {
    return fabs(self.close - self.open);
}

- (double)upperShadow {
    return self.high - fmax(self.open, self.close);
}

- (double)lowerShadow {
    return fmin(self.open, self.close) - self.low;
}

#pragma mark - Factory Methods

+ (instancetype)barFromDictionary:(NSDictionary *)dict {
    if (!dict) return nil;
    
    HistoricalBarModel *bar = [[HistoricalBarModel alloc] init];
    bar.symbol = dict[@"symbol"];
    bar.date = dict[@"date"];
    bar.open = [dict[@"open"] doubleValue];
    bar.high = [dict[@"high"] doubleValue];
    bar.low = [dict[@"low"] doubleValue];
    bar.close = [dict[@"close"] doubleValue];
    bar.adjustedClose = dict[@"adjustedClose"] ? [dict[@"adjustedClose"] doubleValue] : bar.close;
    bar.volume = [dict[@"volume"] longLongValue];
    bar.timeframe = dict[@"timeframe"] ? (BarTimeframe)[dict[@"timeframe"] integerValue] : BarTimeframeDaily;
    
    return bar;
}

+ (NSArray<HistoricalBarModel *> *)barsFromDictionaries:(NSArray<NSDictionary *> *)dictionaries {
    NSMutableArray<HistoricalBarModel *> *bars = [NSMutableArray array];
    
    for (NSDictionary *dict in dictionaries) {
        HistoricalBarModel *bar = [self barFromDictionary:dict];
        if (bar) {
            [bars addObject:bar];
        }
    }
    
    return [bars copy];
}

#pragma mark - Conversion

- (NSDictionary *)toDictionary {
    return @{
        @"symbol": self.symbol ?: @"",
        @"date": self.date ?: [NSDate date],
        @"open": @(self.open),
        @"high": @(self.high),
        @"low": @(self.low),
        @"close": @(self.close),
        @"adjustedClose": @(self.adjustedClose),
        @"volume": @(self.volume),
        @"timeframe": @(self.timeframe)
    };
}

@end

// =======================================

@implementation MarketQuoteModel

#pragma mark - Convenience Methods

- (BOOL)isGainer {
    return self.change && [self.change doubleValue] > 0;
}

- (BOOL)isLoser {
    return self.change && [self.change doubleValue] < 0;
}

- (double)spread {
    if (self.bid && self.ask) {
        return [self.ask doubleValue] - [self.bid doubleValue];
    }
    return 0.0;
}

- (double)midPrice {
    if (self.bid && self.ask) {
        return ([self.bid doubleValue] + [self.ask doubleValue]) / 2.0;
    }
    return self.last ? [self.last doubleValue] : 0.0;
}

#pragma mark - Factory Methods

+ (instancetype)quoteFromDictionary:(NSDictionary *)dict {
    if (!dict) return nil;
    
    MarketQuoteModel *quote = [[MarketQuoteModel alloc] init];
    quote.symbol = dict[@"symbol"];
    quote.name = dict[@"name"];
    quote.exchange = dict[@"exchange"];
    
    // Prices
    quote.last = dict[@"last"] ?: dict[@"lastPrice"];
    quote.bid = dict[@"bid"];
    quote.ask = dict[@"ask"];
    quote.open = dict[@"open"];
    quote.high = dict[@"high"];
    quote.low = dict[@"low"];
    quote.close = dict[@"close"];
    quote.previousClose = dict[@"previousClose"];
    
    // Changes
    quote.change = dict[@"change"];
    quote.changePercent = dict[@"changePercent"];
    
    // Volume
    quote.volume = dict[@"volume"];
    quote.avgVolume = dict[@"avgVolume"];
    
    // Market data
    quote.marketCap = dict[@"marketCap"];
    quote.pe = dict[@"pe"];
    quote.eps = dict[@"eps"];
    quote.beta = dict[@"beta"];
    
    // Status
    quote.timestamp = dict[@"timestamp"] ?: [NSDate date];
    quote.isMarketOpen = dict[@"isMarketOpen"] ? [dict[@"isMarketOpen"] boolValue] : YES;
    
    return quote;
}

+ (instancetype)quoteFromMarketData:(MarketData *)marketData {
    if (!marketData) return nil;
    
    MarketQuoteModel *quote = [[MarketQuoteModel alloc] init];
    quote.symbol = marketData.symbol;
    quote.name = marketData.name;
    quote.exchange = marketData.exchange;
    quote.last = marketData.last;
    quote.bid = marketData.bid;
    quote.ask = marketData.ask;
    quote.open = marketData.open;
    quote.high = marketData.high;
    quote.low = marketData.low;
    quote.close = marketData.close;
    quote.previousClose = marketData.previousClose;
    quote.change = marketData.change;
    quote.changePercent = marketData.changePercent;
    quote.volume = marketData.volume;
    quote.avgVolume = marketData.avgVolume;
    quote.marketCap = marketData.marketCap;
    quote.pe = marketData.pe;
    quote.eps = marketData.eps;
    quote.beta = marketData.beta;
    quote.timestamp = marketData.timestamp;
    quote.isMarketOpen = marketData.isMarketOpen;
    
    return quote;
}

#pragma mark - Conversion

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"symbol"] = self.symbol ?: @"";
    if (self.name) dict[@"name"] = self.name;
    if (self.exchange) dict[@"exchange"] = self.exchange;
    
    if (self.last) dict[@"last"] = self.last;
    if (self.bid) dict[@"bid"] = self.bid;
    if (self.ask) dict[@"ask"] = self.ask;
    if (self.open) dict[@"open"] = self.open;
    if (self.high) dict[@"high"] = self.high;
    if (self.low) dict[@"low"] = self.low;
    if (self.close) dict[@"close"] = self.close;
    if (self.previousClose) dict[@"previousClose"] = self.previousClose;
    
    if (self.change) dict[@"change"] = self.change;
    if (self.changePercent) dict[@"changePercent"] = self.changePercent;
    
    if (self.volume) dict[@"volume"] = self.volume;
    if (self.avgVolume) dict[@"avgVolume"] = self.avgVolume;
    
    if (self.marketCap) dict[@"marketCap"] = self.marketCap;
    if (self.pe) dict[@"pe"] = self.pe;
    if (self.eps) dict[@"eps"] = self.eps;
    if (self.beta) dict[@"beta"] = self.beta;
    
    dict[@"timestamp"] = self.timestamp;
    dict[@"isMarketOpen"] = @(self.isMarketOpen);
    
    return [dict copy];
}

@end

// =======================================

@implementation CompanyInfoModel

+ (instancetype)infoFromDictionary:(NSDictionary *)dict {
    if (!dict) return nil;
    
    CompanyInfoModel *info = [[CompanyInfoModel alloc] init];
    info.symbol = dict[@"symbol"];
    info.name = dict[@"name"];
    info.sector = dict[@"sector"];
    info.industry = dict[@"industry"];
    info.companyDescription = dict[@"description"] ?: dict[@"companyDescription"];
    info.website = dict[@"website"];
    info.ceo = dict[@"ceo"];
    info.employees = dict[@"employees"] ? [dict[@"employees"] integerValue] : 0;
    info.headquarters = dict[@"headquarters"];
    info.lastUpdate = dict[@"lastUpdate"] ?: [NSDate date];
    
    return info;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"symbol"] = self.symbol ?: @"";
    if (self.name) dict[@"name"] = self.name;
    if (self.sector) dict[@"sector"] = self.sector;
    if (self.industry) dict[@"industry"] = self.industry;
    if (self.companyDescription) dict[@"companyDescription"] = self.companyDescription;
    if (self.website) dict[@"website"] = self.website;
    if (self.ceo) dict[@"ceo"] = self.ceo;
    if (self.employees > 0) dict[@"employees"] = @(self.employees);
    if (self.headquarters) dict[@"headquarters"] = self.headquarters;
    dict[@"lastUpdate"] = self.lastUpdate;
    
    return [dict copy];
}

@end


// =======================================
// WATCHLIST MODEL IMPLEMENTATION
// =======================================

@implementation WatchlistModel

+ (instancetype)watchlistFromDictionary:(NSDictionary *)dict {
    WatchlistModel *model = [[WatchlistModel alloc] init];
    model.name = dict[@"name"];
    model.colorHex = dict[@"colorHex"];
    model.creationDate = dict[@"creationDate"];
    model.lastModified = dict[@"lastModified"];
    model.sortOrder = [dict[@"sortOrder"] integerValue];
    model.symbols = dict[@"symbols"] ?: @[];
    return model;
}

- (NSDictionary *)toDictionary {
    return @{
        @"name": self.name ?: @"",
        @"colorHex": self.colorHex ?: [NSNull null],
        @"creationDate": self.creationDate ?: [NSNull null],
        @"lastModified": self.lastModified ?: [NSNull null],
        @"sortOrder": @(self.sortOrder),
        @"symbols": self.symbols ?: @[]
    };
}

@end

// =======================================
// MARKET PERFORMER MODEL IMPLEMENTATION
// =======================================

@implementation MarketPerformerModel

#pragma mark - Factory Methods

+ (instancetype)performerFromDictionary:(NSDictionary *)dict {
    if (!dict) return nil;
    
    MarketPerformerModel *performer = [[MarketPerformerModel alloc] init];
    performer.symbol = dict[@"symbol"];
    performer.name = dict[@"name"];
    performer.exchange = dict[@"exchange"];
    performer.sector = dict[@"sector"];
    
    // Price data
    performer.price = dict[@"price"] ?: dict[@"close"];
    performer.change = dict[@"change"];
    performer.changePercent = dict[@"changePercent"];
    performer.volume = dict[@"volume"];
    
    // Market data
    performer.marketCap = dict[@"marketCap"];
    performer.avgVolume = dict[@"avgVolume"];
    
    // List metadata
    performer.listType = dict[@"listType"] ?: @"unknown";
    performer.timeframe = dict[@"timeframe"] ?: @"1d";
    performer.rank = dict[@"rank"] ? [dict[@"rank"] integerValue] : 0;
    
    // Timestamp
    performer.timestamp = dict[@"timestamp"] ?: [NSDate date];
    
    return performer;
}

+ (NSArray<MarketPerformerModel *> *)performersFromDictionaries:(NSArray<NSDictionary *> *)dictionaries {
    if (!dictionaries) return @[];
    
    NSMutableArray *performers = [NSMutableArray arrayWithCapacity:dictionaries.count];
    
    for (NSDictionary *dict in dictionaries) {
        MarketPerformerModel *performer = [self performerFromDictionary:dict];
        if (performer) {
            [performers addObject:performer];
        }
    }
    
    return [performers copy];
}

#pragma mark - Conversion

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    // Basic info
    if (self.symbol) dict[@"symbol"] = self.symbol;
    if (self.name) dict[@"name"] = self.name;
    if (self.exchange) dict[@"exchange"] = self.exchange;
    if (self.sector) dict[@"sector"] = self.sector;
    
    // Price data
    if (self.price) dict[@"price"] = self.price;
    if (self.change) dict[@"change"] = self.change;
    if (self.changePercent) dict[@"changePercent"] = self.changePercent;
    if (self.volume) dict[@"volume"] = self.volume;
    
    // Market data
    if (self.marketCap) dict[@"marketCap"] = self.marketCap;
    if (self.avgVolume) dict[@"avgVolume"] = self.avgVolume;
    
    // List metadata
    if (self.listType) dict[@"listType"] = self.listType;
    if (self.timeframe) dict[@"timeframe"] = self.timeframe;
    dict[@"rank"] = @(self.rank);
    
    // Timestamp
    if (self.timestamp) dict[@"timestamp"] = self.timestamp;
    
    return [dict copy];
}

#pragma mark - Convenience Methods

- (BOOL)isGainer {
    return self.changePercent && [self.changePercent doubleValue] > 0;
}

- (BOOL)isLoser {
    return self.changePercent && [self.changePercent doubleValue] < 0;
}

- (NSString *)formattedPrice {
    if (!self.price) return @"--";
    return [NSString stringWithFormat:@"$%.2f", [self.price doubleValue]];
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

- (NSString *)formattedVolume {
    if (!self.volume) return @"--";
    
    long long vol = [self.volume longLongValue];
    
    if (vol >= 1000000000) {
        return [NSString stringWithFormat:@"%.1fB", vol / 1000000000.0];
    } else if (vol >= 1000000) {
        return [NSString stringWithFormat:@"%.1fM", vol / 1000000.0];
    } else if (vol >= 1000) {
        return [NSString stringWithFormat:@"%.1fK", vol / 1000.0];
    } else {
        return [NSString stringWithFormat:@"%lld", vol];
    }
}

- (NSString *)formattedMarketCap {
    if (!self.marketCap) return @"--";
    
    double cap = [self.marketCap doubleValue];
    
    if (cap >= 1000000000000) {
        return [NSString stringWithFormat:@"$%.1fT", cap / 1000000000000.0];
    } else if (cap >= 1000000000) {
        return [NSString stringWithFormat:@"$%.1fB", cap / 1000000000.0];
    } else if (cap >= 1000000) {
        return [NSString stringWithFormat:@"$%.1fM", cap / 1000000.0];
    } else {
        return [NSString stringWithFormat:@"$%.0f", cap];
    }
}

#pragma mark - NSObject

- (NSString *)description {
    return [NSString stringWithFormat:@"<MarketPerformerModel: %@ (%@) %@ %@>",
            self.symbol, self.name, [self formattedPrice], [self formattedChangePercent]];
}

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[MarketPerformerModel class]]) return NO;
    
    MarketPerformerModel *other = (MarketPerformerModel *)object;
    return [self.symbol isEqualToString:other.symbol] &&
           [self.listType isEqualToString:other.listType] &&
           [self.timeframe isEqualToString:other.timeframe];
}

- (NSUInteger)hash {
    return [self.symbol hash] ^ [self.listType hash] ^ [self.timeframe hash];
}

@end
@implementation AlertModel

#pragma mark - Factory Methods

+ (instancetype)alertFromDictionary:(NSDictionary *)dict {
    if (!dict) return nil;
    
    AlertModel *alert = [[AlertModel alloc] init];
    alert.symbol = dict[@"symbol"];
    alert.triggerValue = [dict[@"triggerValue"] doubleValue];
    alert.conditionString = dict[@"conditionString"];
    alert.isActive = [dict[@"isActive"] boolValue];
    alert.isTriggered = [dict[@"isTriggered"] boolValue];
    alert.notificationEnabled = [dict[@"notificationEnabled"] boolValue];
    alert.notes = dict[@"notes"];
    alert.creationDate = dict[@"creationDate"];
    alert.triggerDate = dict[@"triggerDate"];
    
    return alert;
}

#pragma mark - Conversion

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    if (self.symbol) dict[@"symbol"] = self.symbol;
    dict[@"triggerValue"] = @(self.triggerValue);
    if (self.conditionString) dict[@"conditionString"] = self.conditionString;
    dict[@"isActive"] = @(self.isActive);
    dict[@"isTriggered"] = @(self.isTriggered);
    dict[@"notificationEnabled"] = @(self.notificationEnabled);
    if (self.notes) dict[@"notes"] = self.notes;
    if (self.creationDate) dict[@"creationDate"] = self.creationDate;
    if (self.triggerDate) dict[@"triggerDate"] = self.triggerDate;
    
    return [dict copy];
}

#pragma mark - Convenience Methods

- (NSString *)formattedTriggerValue {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.minimumFractionDigits = 2;
    formatter.maximumFractionDigits = 2;
    
    return [formatter stringFromNumber:@(self.triggerValue)];
}

- (NSString *)statusString {
    if (self.isTriggered) {
        return @"Triggered";
    } else if (self.isActive) {
        return @"Active";
    } else {
        return @"Inactive";
    }
}

- (BOOL)shouldTriggerWithCurrentPrice:(double)currentPrice previousPrice:(double)previousPrice {
    if (!self.isActive || self.isTriggered) {
        return NO;
    }
    
    if ([self.conditionString isEqualToString:@"above"]) {
        return currentPrice > self.triggerValue;
    } else if ([self.conditionString isEqualToString:@"below"]) {
        return currentPrice < self.triggerValue;
    } else if ([self.conditionString isEqualToString:@"crosses_above"]) {
        return (previousPrice <= self.triggerValue) && (currentPrice > self.triggerValue);
    } else if ([self.conditionString isEqualToString:@"crosses_below"]) {
        return (previousPrice >= self.triggerValue) && (currentPrice < self.triggerValue);
    }
    
    return NO;
}

@end

// =======================================
// NEWS MODEL IMPLEMENTATION
// =======================================

@implementation NewsModel

#pragma mark - Factory Methods

+ (instancetype)newsFromDictionary:(NSDictionary *)dict {
    if (!dict) return nil;
    
    NewsModel *news = [[NewsModel alloc] init];
    
    // Basic info
    news.symbol = dict[@"symbol"] ?: @"";
    news.headline = dict[@"headline"] ?: dict[@"title"] ?: @"";
    news.summary = dict[@"summary"] ?: dict[@"description"];
    news.url = dict[@"url"] ?: dict[@"link"];
    news.source = dict[@"source"] ?: @"";
    
    // Parse published date
    if (dict[@"publishedDate"]) {
        if ([dict[@"publishedDate"] isKindOfClass:[NSDate class]]) {
            news.publishedDate = dict[@"publishedDate"];
        } else if ([dict[@"publishedDate"] isKindOfClass:[NSString class]]) {
            // Parse date string - try multiple formats
            news.publishedDate = [self parseDate:dict[@"publishedDate"]];
        }
    }
    
    if (!news.publishedDate) {
        news.publishedDate = [NSDate date]; // Default to now
    }
    
    // Additional metadata
    news.type = dict[@"type"] ?: @"news";
    news.category = dict[@"category"];
    news.author = dict[@"author"];
    news.sentiment = dict[@"sentiment"] ? [dict[@"sentiment"] integerValue] : 0;
    news.isBreaking = dict[@"isBreaking"] ? [dict[@"isBreaking"] boolValue] : NO;
    news.priority = dict[@"priority"] ? [dict[@"priority"] integerValue] : 3; // Default medium priority
    
    return news;
}

+ (NSArray<NewsModel *> *)newsArrayFromDictionaries:(NSArray<NSDictionary *> *)dictionaries {
    if (!dictionaries) return @[];
    
    NSMutableArray<NewsModel *> *newsArray = [NSMutableArray array];
    
    for (NSDictionary *dict in dictionaries) {
        if ([dict isKindOfClass:[NSDictionary class]]) {
            NewsModel *news = [self newsFromDictionary:dict];
            if (news) {
                [newsArray addObject:news];
            }
        }
    }
    
    // Sort by date (newest first)
    [newsArray sortUsingComparator:^NSComparisonResult(NewsModel *obj1, NewsModel *obj2) {
        return [obj2.publishedDate compare:obj1.publishedDate];
    }];
    
    return [newsArray copy];
}

#pragma mark - Date Parsing Helper

+ (NSDate *)parseDate:(NSString *)dateString {
    if (!dateString || dateString.length == 0) {
        return nil;
    }
    
    // Common date formats for news feeds
    NSArray *dateFormats = @[
        @"yyyy-MM-dd'T'HH:mm:ssZ",      // ISO 8601
        @"yyyy-MM-dd'T'HH:mm:ss.SSSZ",  // ISO 8601 with milliseconds
        @"EEE, dd MMM yyyy HH:mm:ss Z", // RSS format
        @"yyyy-MM-dd HH:mm:ss",         // Simple format
        @"yyyy-MM-dd",                  // Date only
        @"MMM dd, yyyy",                // Mar 15, 2024
        @"MM/dd/yyyy"                   // US format
    ];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    
    for (NSString *format in dateFormats) {
        formatter.dateFormat = format;
        NSDate *date = [formatter dateFromString:dateString];
        if (date) {
            return date;
        }
    }
    
    NSLog(@"⚠️ NewsModel: Could not parse date string: %@", dateString);
    return nil;
}

#pragma mark - Conversion

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"symbol"] = self.symbol ?: @"";
    dict[@"headline"] = self.headline ?: @"";
    if (self.summary) dict[@"summary"] = self.summary;
    if (self.url) dict[@"url"] = self.url;
    dict[@"source"] = self.source ?: @"";
    dict[@"publishedDate"] = self.publishedDate ?: [NSDate date];
    
    if (self.type) dict[@"type"] = self.type;
    if (self.category) dict[@"category"] = self.category;
    if (self.author) dict[@"author"] = self.author;
    dict[@"sentiment"] = @(self.sentiment);
    dict[@"isBreaking"] = @(self.isBreaking);
    dict[@"priority"] = @(self.priority);
    
    return [dict copy];
}

#pragma mark - Comparison

- (NSComparisonResult)compareByDate:(NewsModel *)otherNews {
    if (!otherNews) return NSOrderedAscending;
    
    // Compare dates (newer first)
    return [otherNews.publishedDate compare:self.publishedDate];
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"NewsModel{symbol=%@, headline=%@, source=%@, date=%@}",
            self.symbol, self.headline, self.source, self.publishedDate];
}

@end

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
    bar.timeframe = dict[@"timeframe"] ? (BarTimeframe)[dict[@"timeframe"] integerValue] : BarTimeframe1Day;
    
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

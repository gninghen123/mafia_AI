//
//  OtherDataAdapter.m
//  TradingApp
//

#import "OtherDataAdapter.h"
#import "MarketData.h"
#import "RuntimeModels.h"
#import "SeasonalDataModel.h"
#import "QuarterlyDataPoint.h"

@implementation OtherDataAdapter

#pragma mark - DataSourceAdapter Protocol

- (MarketData *)standardizeQuoteData:(NSDictionary *)rawData forSymbol:(NSString *)symbol {
    // OtherDataSource doesn't provide real-time quotes typically
    // This method exists for protocol compliance
    if (!rawData || !symbol) return nil;
    
    MarketData *marketData = [[MarketData alloc] init];
    marketData.symbol = symbol;
    marketData.lastPrice = [self safeDouble:rawData[@"lastPrice"] ?: rawData[@"price"]];
    marketData.change = [self safeDouble:rawData[@"change"]];
    marketData.changePercent = [self safeDouble:rawData[@"changePercent"]];
    marketData.volume = [self safeInteger:rawData[@"volume"]];
    marketData.bid = [self safeDouble:rawData[@"bid"]];
    marketData.ask = [self safeDouble:rawData[@"ask"]];
    marketData.timestamp = [NSDate date];
    
    return marketData;
}

- (NSArray<HistoricalBarModel *> *)standardizeHistoricalData:(id)rawData forSymbol:(NSString *)symbol {
    // OtherDataSource doesn't provide historical bars typically
    // This method exists for protocol compliance
    return @[];
}

#pragma mark - Zacks Data Conversion

- (SeasonalDataModel *)convertZacksChartToSeasonalModel:(NSDictionary *)rawData
                                                 symbol:(NSString *)symbol
                                               dataType:(NSString *)dataType {
    
    if (!rawData || ![rawData isKindOfClass:[NSDictionary class]]) {
        NSLog(@"❌ OtherDataAdapter: Invalid raw data format from Zacks");
        return nil;
    }
    
    // Parse Zacks response format
    NSArray *chartData = rawData[@"data"] ?: rawData[@"chartData"] ?: rawData[@"series"];
    if (!chartData || ![chartData isKindOfClass:[NSArray class]]) {
        NSLog(@"❌ OtherDataAdapter: No chart data array found in Zacks response");
        return nil;
    }
    
    NSMutableArray<QuarterlyDataPoint *> *quarters = [NSMutableArray array];
    
    for (NSDictionary *dataPoint in chartData) {
        if (![dataPoint isKindOfClass:[NSDictionary class]]) continue;
        
        // Extract quarter information from Zacks data
        // Format may vary - adapt based on actual Zacks API response
        NSString *periodStr = dataPoint[@"period"] ?: dataPoint[@"date"] ?: dataPoint[@"quarter"];
        NSNumber *valueNum = dataPoint[@"value"] ?: dataPoint[dataType] ?: dataPoint[@"y"];
        
        if (!periodStr || !valueNum) {
            // Try alternative formats
            periodStr = dataPoint[@"x"];
            valueNum = dataPoint[@"y"];
        }
        
        if (!periodStr || !valueNum) continue;
        
        // Parse quarter and year from period string
        NSInteger quarter = 0;
        NSInteger year = 0;
        NSDate *quarterEndDate = nil;
        
        if ([self parseQuarterFromPeriodString:periodStr quarter:&quarter year:&year date:&quarterEndDate]) {
            QuarterlyDataPoint *quarterPoint = [QuarterlyDataPoint dataPointWithQuarter:quarter
                                                                                    year:year
                                                                                   value:valueNum.doubleValue
                                                                          quarterEndDate:quarterEndDate];
            [quarters addObject:quarterPoint];
        }
    }
    
    if (quarters.count == 0) {
        NSLog(@"❌ OtherDataAdapter: No valid quarterly data points parsed from Zacks response");
        return nil;
    }
    
    // Create SeasonalDataModel
    SeasonalDataModel *seasonalModel = [SeasonalDataModel modelWithSymbol:symbol
                                                                 dataType:dataType
                                                                 quarters:quarters];
    
    // Set metadata if available
    seasonalModel.currency = [self safeString:rawData[@"currency"]] ?: @"USD";
    seasonalModel.units = [self safeString:rawData[@"units"]] ?: @"";
    
    NSLog(@"✅ OtherDataAdapter: Converted %lu quarters to SeasonalDataModel for %@ (%@)",
          (unsigned long)quarters.count, symbol, dataType);
    
    return seasonalModel;
}

- (BOOL)parseQuarterFromPeriodString:(NSString *)periodStr
                             quarter:(NSInteger *)quarter
                                year:(NSInteger *)year
                                date:(NSDate **)date {
    
    if (!periodStr || periodStr.length == 0) return NO;
    
    // Try various formats that Zacks might use
    NSString *normalizedPeriod = [periodStr uppercaseString];
    
    // Format: "Q1 2024", "Q2 2023", etc.
    NSRegularExpression *qYearRegex = [NSRegularExpression regularExpressionWithPattern:@"Q([1-4])\\s+(\\d{4})"
                                                                                options:0
                                                                                  error:nil];
    NSTextCheckingResult *qYearMatch = [qYearRegex firstMatchInString:normalizedPeriod
                                                              options:0
                                                                range:NSMakeRange(0, normalizedPeriod.length)];
    
    if (qYearMatch && qYearMatch.numberOfRanges >= 3) {
        NSString *quarterStr = [normalizedPeriod substringWithRange:[qYearMatch rangeAtIndex:1]];
        NSString *yearStr = [normalizedPeriod substringWithRange:[qYearMatch rangeAtIndex:2]];
        
        *quarter = quarterStr.integerValue;
        *year = yearStr.integerValue;
        
        if (date) {
            *date = [self approximateQuarterEndDateForQuarter:*quarter year:*year];
        }
        
        return YES;
    }
    
    // Format: "2024-Q1", "2023-Q4", etc.
    NSRegularExpression *yearQRegex = [NSRegularExpression regularExpressionWithPattern:@"(\\d{4})-Q([1-4])"
                                                                                options:0
                                                                                  error:nil];
    NSTextCheckingResult *yearQMatch = [yearQRegex firstMatchInString:normalizedPeriod
                                                              options:0
                                                                range:NSMakeRange(0, normalizedPeriod.length)];
    
    if (yearQMatch && yearQMatch.numberOfRanges >= 3) {
        NSString *yearStr = [normalizedPeriod substringWithRange:[yearQMatch rangeAtIndex:1]];
        NSString *quarterStr = [normalizedPeriod substringWithRange:[yearQMatch rangeAtIndex:2]];
        
        *quarter = quarterStr.integerValue;
        *year = yearStr.integerValue;
        
        if (date) {
            *date = [self approximateQuarterEndDateForQuarter:*quarter year:*year];
        }
        
        return YES;
    }
    
    // Format: "2024Q1", "2023Q4", etc. (no separator)
    NSRegularExpression *yearQNoSepRegex = [NSRegularExpression regularExpressionWithPattern:@"(\\d{4})Q([1-4])"
                                                                                     options:0
                                                                                       error:nil];
    NSTextCheckingResult *yearQNoSepMatch = [yearQNoSepRegex firstMatchInString:normalizedPeriod
                                                                        options:0
                                                                          range:NSMakeRange(0, normalizedPeriod.length)];
    
    if (yearQNoSepMatch && yearQNoSepMatch.numberOfRanges >= 3) {
        NSString *yearStr = [normalizedPeriod substringWithRange:[yearQNoSepMatch rangeAtIndex:1]];
        NSString *quarterStr = [normalizedPeriod substringWithRange:[yearQNoSepMatch rangeAtIndex:2]];
        
        *quarter = quarterStr.integerValue;
        *year = yearStr.integerValue;
        
        if (date) {
            *date = [self approximateQuarterEndDateForQuarter:*quarter year:*year];
        }
        
        return YES;
    }
    
    NSLog(@"⚠️ OtherDataAdapter: Could not parse quarter from period string: %@", periodStr);
    return NO;
}

- (NSDate *)approximateQuarterEndDateForQuarter:(NSInteger)quarter year:(NSInteger)year {
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.year = year;
    
    switch (quarter) {
        case 1:
            components.month = 3;
            components.day = 31;
            break;
        case 2:
            components.month = 6;
            components.day = 30;
            break;
        case 3:
            components.month = 9;
            components.day = 30;
            break;
        case 4:
            components.month = 12;
            components.day = 31;
            break;
        default:
            return nil;
    }
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    return [calendar dateFromComponents:components];
}

#pragma mark - Market Data Conversion

- (NSArray *)convertFrom52WeekHighs:(NSArray *)rawData {
    NSMutableArray *results = [NSMutableArray array];
    
    for (NSDictionary *item in rawData) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        
        NSDictionary *result = @{
            @"symbol": [self safeString:item[@"symbol"]],
            @"lastSale": @([self safeDouble:item[@"lastSale"]]),
            @"netChange": @([self safeDouble:item[@"netchange"]]),
            @"pctChange": @([self safeDouble:item[@"pctchange"]]),
            @"volume": @([self safeInteger:item[@"volume"]]),
            @"marketCap": @([self parseMarketCapString:[self safeString:item[@"marketCap"]]])
        };
        [results addObject:result];
    }
    
    return results;
}

- (NSArray *)convertFromStocksList:(NSArray *)rawData {
    NSMutableArray *stocks = [NSMutableArray array];
    
    for (NSDictionary *item in rawData) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        
        NSDictionary *stock = @{
            @"symbol": [self safeString:item[@"symbol"]],
            @"name": [self safeString:item[@"name"]],
            @"lastsale": @([self safeDouble:item[@"lastsale"]]),
            @"netchange": @([self safeDouble:item[@"netchange"]]),
            @"pctchange": @([self safeDouble:item[@"pctchange"]]),
            @"volume": @([self safeInteger:item[@"volume"]]),
            @"marketCap": @([self parseMarketCapString:[self safeString:item[@"marketCap"]]]),
            @"country": [self safeString:item[@"country"]],
            @"ipoyear": [self safeString:item[@"ipoyear"]],
            @"industry": [self safeString:item[@"industry"]],
            @"sector": [self safeString:item[@"sector"]]
        };
        [stocks addObject:stock];
    }
    
    return stocks;
}

- (NSArray *)convertFromETFList:(NSArray *)rawData {
    NSMutableArray *etfs = [NSMutableArray array];
    
    for (NSDictionary *item in rawData) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        
        NSDictionary *etf = @{
            @"symbol": [self safeString:item[@"symbol"]],
            @"companyName": [self safeString:item[@"companyName"]],
            @"lastSale": @([self safeDouble:item[@"lastSale"]]),
            @"netChange": @([self safeDouble:item[@"netChange"]]),
            @"pctChange": @([self safeDouble:item[@"pctChange"]]),
            @"volume": @([self safeInteger:item[@"volume"]])
        };
        [etfs addObject:etf];
    }
    
    return etfs;
}

- (NSArray *)convertFromEarningsCalendar:(NSArray *)rawData {
    NSMutableArray *earnings = [NSMutableArray array];
    
    for (NSDictionary *item in rawData) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        
        NSDictionary *earning = @{
            @"symbol": [self safeString:item[@"symbol"]],
            @"companyName": [self safeString:item[@"companyName"]],
            @"epsForecast": @([self safeDouble:item[@"epsForecast"]]),
            @"numberOfEstimates": @([self safeInteger:item[@"noOfEsts"]]),
            @"reportTime": [self safeString:item[@"time"]],
            @"lastYearEPS": @([self safeDouble:item[@"lastYearEPS"]]),
            @"lastYearDate": [self safeString:item[@"lastYearDate"]],
            @"marketCap": @([self parseMarketCapString:[self safeString:item[@"marketCap"]]])
        };
        [earnings addObject:earning];
    }
    
    return earnings;
}

- (NSArray *)convertFromEarningsSurprise:(NSArray *)rawData {
    NSMutableArray *surprises = [NSMutableArray array];
    
    for (NSDictionary *item in rawData) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        
        NSDictionary *surprise = @{
            @"symbol": [self safeString:item[@"symbol"]],
            @"companyName": [self safeString:item[@"companyName"]],
            @"eps": @([self safeDouble:item[@"eps"]]),
            @"epsEstimate": @([self safeDouble:item[@"epsEstimate"]]),
            @"epsSurprise": @([self safeDouble:item[@"epsSurprise"]]),
            @"epsSurprisePercent": @([self safeDouble:item[@"epsSurprisePct"]]),
            @"reportTime": [self safeString:item[@"time"]]
        };
        [surprises addObject:surprise];
    }
    
    return surprises;
}

- (NSArray *)convertFromInstitutionalTransactions:(NSArray *)rawData {
    NSMutableArray *transactions = [NSMutableArray array];
    
    for (NSDictionary *item in rawData) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        
        NSDictionary *transaction = @{
            @"symbol": [self safeString:item[@"symbol"]],
            @"companyName": [self safeString:item[@"companyName"]],
            @"ownerName": [self safeString:item[@"ownerName"]],
            @"sharesTraded": @([self safeInteger:item[@"sharesTraded"]]),
            @"lastPrice": @([self safeDouble:item[@"lastPrice"]]),
            @"transactionValue": @([self safeDouble:item[@"transactionValue"]]),
            @"transactionType": [self safeString:item[@"transactionType"]],
            @"filingDate": [self safeString:item[@"filingDate"]]
        };
        [transactions addObject:transaction];
    }
    
    return transactions;
}

#pragma mark - Company Data Conversion

- (NSArray *)convertFromNews:(NSArray *)rawData {
    NSMutableArray *news = [NSMutableArray array];
    
    for (NSDictionary *item in rawData) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        
        NSDictionary *newsItem = @{
            @"headline": [self safeString:item[@"headline"]],
            @"summary": [self safeString:item[@"summary"]],
            @"publishedDate": [self safeString:item[@"publishedDate"]],
            @"url": [self safeString:item[@"url"]],
            @"source": [self safeString:item[@"source"]],
            @"timestamp": [self convertDateString:[self safeString:item[@"publishedDate"]]] ?: [NSDate date]
        };
        [news addObject:newsItem];
    }
    
    return news;
}

- (NSArray *)convertFromPressReleases:(NSArray *)rawData {
    // Same structure as news
    return [self convertFromNews:rawData];
}

- (NSDictionary *)convertFromFinancials:(NSDictionary *)rawData {
    NSMutableDictionary *financials = [NSMutableDictionary dictionary];
    
    // Extract key financial metrics
    financials[@"revenue"] = [self extractFinancialMetric:rawData key:@"revenue"];
    financials[@"netIncome"] = [self extractFinancialMetric:rawData key:@"netIncome"];
    financials[@"eps"] = [self extractFinancialMetric:rawData key:@"eps"];
    financials[@"operatingIncome"] = [self extractFinancialMetric:rawData key:@"operatingIncome"];
    financials[@"totalAssets"] = [self extractFinancialMetric:rawData key:@"totalAssets"];
    financials[@"totalLiabilities"] = [self extractFinancialMetric:rawData key:@"totalLiabilities"];
    financials[@"shareholderEquity"] = [self extractFinancialMetric:rawData key:@"shareholderEquity"];
    financials[@"cashFlow"] = [self extractFinancialMetric:rawData key:@"cashFlow"];
    
    // Metadata
    financials[@"currency"] = [self safeString:rawData[@"currency"]] ?: @"USD";
    financials[@"period"] = [self safeString:rawData[@"period"]];
    financials[@"fiscalYear"] = [self safeString:rawData[@"fiscalYear"]];
    
    return financials;
}

- (NSDictionary *)convertFromPEGRatio:(NSDictionary *)rawData {
    NSMutableDictionary *pegData = [NSMutableDictionary dictionary];
    
    pegData[@"pegRatio"] = @([self safeDouble:rawData[@"pegRatio"]]);
    pegData[@"peRatio"] = @([self safeDouble:rawData[@"peRatio"]]);
    pegData[@"growthRate"] = @([self safeDouble:rawData[@"growthRate"]]);
    pegData[@"lastUpdated"] = [self safeString:rawData[@"lastUpdated"]];
    
    return pegData;
}

- (NSDictionary *)convertFromPriceTarget:(NSDictionary *)rawData {
    NSMutableDictionary *target = [NSMutableDictionary dictionary];
    
    target[@"meanTarget"] = @([self safeDouble:rawData[@"meanTarget"]]);
    target[@"highTarget"] = @([self safeDouble:rawData[@"highTarget"]]);
    target[@"lowTarget"] = @([self safeDouble:rawData[@"lowTarget"]]);
    target[@"numberOfAnalysts"] = @([self safeInteger:rawData[@"numberOfAnalysts"]]);
    target[@"lastUpdated"] = [self safeString:rawData[@"lastUpdated"]];
    
    return target;
}

- (NSArray *)convertFromRatings:(NSArray *)rawData {
    NSMutableArray *ratings = [NSMutableArray array];
    
    for (NSDictionary *item in rawData) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        
        NSDictionary *rating = @{
            @"firm": [self safeString:item[@"firm"]],
            @"rating": [self safeString:item[@"rating"]],
            @"priceTarget": @([self safeDouble:item[@"priceTarget"]]),
            @"date": [self safeString:item[@"date"]],
            @"action": [self safeString:item[@"action"]],
            @"ratingScore": @([self normalizeRating:[self safeString:item[@"rating"]]])
        };
        [ratings addObject:rating];
    }
    
    return ratings;
}

- (NSDictionary *)convertFromShortInterest:(NSDictionary *)rawData {
    NSMutableDictionary *shortData = [NSMutableDictionary dictionary];
    
    shortData[@"shortInterest"] = @([self safeInteger:rawData[@"shortInterest"]]);
    shortData[@"shortRatio"] = @([self safeDouble:rawData[@"shortRatio"]]);
    shortData[@"percentOfFloat"] = @([self safeDouble:rawData[@"percentOfFloat"]]);
    shortData[@"previousShortInterest"] = @([self safeInteger:rawData[@"previousShortInterest"]]);
    shortData[@"changeFromPrevious"] = @([self safeInteger:rawData[@"changeFromPrevious"]]);
    shortData[@"reportDate"] = [self safeString:rawData[@"reportDate"]];
    
    return shortData;
}

- (NSArray *)convertFromInsiderTrades:(NSArray *)rawData {
    NSMutableArray *trades = [NSMutableArray array];
    
    for (NSDictionary *item in rawData) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        
        NSDictionary *trade = @{
            @"insiderName": [self safeString:item[@"insider"]],
            @"relation": [self safeString:item[@"relation"]],
            @"lastDate": [self safeString:item[@"lastDate"]],
            @"transactionType": [self safeString:item[@"transactionType"]],
            @"ownershipType": [self safeString:item[@"ownershipType"]],
            @"sharesTraded": @([self safeInteger:item[@"sharesTraded"]]),
            @"lastPrice": @([self safeDouble:item[@"lastPrice"]]),
            @"sharesHeld": @([self safeInteger:item[@"sharesHeld"]]),
            @"transactionValue": @([self safeInteger:item[@"sharesTraded"]] * [self safeDouble:item[@"lastPrice"]])
        };
        [trades addObject:trade];
    }
    
    return trades;
}

- (NSArray *)convertFromInstitutionalHoldings:(NSArray *)rawData {
    NSMutableArray *holdings = [NSMutableArray array];
    
    for (NSDictionary *item in rawData) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        
        NSDictionary *holding = @{
            @"institutionName": [self safeString:item[@"institutionName"]],
            @"sharesHeld": @([self safeInteger:item[@"sharesHeld"]]),
            @"marketValue": @([self safeDouble:item[@"marketValue"]]),
            @"percentHeld": @([self safeDouble:item[@"percentHeld"]]),
            @"reportDate": [self safeString:item[@"reportDate"]],
            @"change": @([self safeInteger:item[@"change"]]),
            @"changePercent": @([self safeDouble:item[@"changePercent"]])
        };
        [holdings addObject:holding];
    }
    
    return holdings;
}

- (NSArray *)convertFromSECFilings:(NSArray *)rawData {
    NSMutableArray *filings = [NSMutableArray array];
    
    for (NSDictionary *item in rawData) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        
        NSDictionary *filing = @{
            @"form": [self safeString:item[@"form"]],
            @"description": [self safeString:item[@"description"]],
            @"filedDate": [self safeString:item[@"filed"]],
            @"period": [self safeString:item[@"period"]],
            @"url": [self safeString:item[@"url"]]
        };
        [filings addObject:filing];
    }
    
    return filings;
}

- (NSDictionary *)convertFromRevenue:(NSDictionary *)rawData {
    NSMutableDictionary *revenue = [NSMutableDictionary dictionary];
    
    revenue[@"revenueHistory"] = [self extractFinancialMetric:rawData key:@"revenue"];
    revenue[@"epsHistory"] = [self extractFinancialMetric:rawData key:@"eps"];
    revenue[@"period"] = [self safeString:rawData[@"period"]];
    revenue[@"currency"] = [self safeString:rawData[@"currency"]] ?: @"USD";
    
    return revenue;
}

- (NSDictionary *)convertFromEPS:(NSDictionary *)rawData {
    NSMutableDictionary *eps = [NSMutableDictionary dictionary];
    
    eps[@"currentEPS"] = @([self safeDouble:rawData[@"eps"]]);
    eps[@"previousEPS"] = @([self safeDouble:rawData[@"previousEps"]]);
    eps[@"epsChange"] = @([self safeDouble:rawData[@"epsChange"]]);
    eps[@"epsChangePercent"] = @([self safeDouble:rawData[@"epsChangePercent"]]);
    eps[@"reportDate"] = [self safeString:rawData[@"reportDate"]];
    
    return eps;
}

- (NSDictionary *)convertFromEarningsDate:(NSDictionary *)rawData {
    NSMutableDictionary *earningsDate = [NSMutableDictionary dictionary];
    
    earningsDate[@"nextEarningsDate"] = [self safeString:rawData[@"nextEarningsDate"]];
    earningsDate[@"estimatedEPS"] = @([self safeDouble:rawData[@"estimatedEps"]]);
    earningsDate[@"previousEarningsDate"] = [self safeString:rawData[@"previousEarningsDate"]];
    earningsDate[@"previousEPS"] = @([self safeDouble:rawData[@"previousEps"]]);
    
    return earningsDate;
}

- (NSArray *)convertFromEarningsSurpriseSymbol:(NSArray *)rawData {
    NSMutableArray *surprises = [NSMutableArray array];
    
    for (NSDictionary *item in rawData) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        
        NSDictionary *surprise = @{
            @"reportDate": [self safeString:item[@"reportDate"]],
            @"fiscalQuarterEnding": [self safeString:item[@"fiscalQuarterEnding"]],
            @"eps": @([self safeDouble:item[@"eps"]]),
            @"epsEstimate": @([self safeDouble:item[@"epsEstimate"]]),
            @"epsSurprise": @([self safeDouble:item[@"epsSurprise"]]),
            @"epsSurprisePercent": @([self safeDouble:item[@"epsSurprisePct"]])
        };
        [surprises addObject:surprise];
    }
    
    return surprises;
}

- (NSDictionary *)convertFromEarningsForecast:(NSDictionary *)rawData {
    NSMutableDictionary *forecast = [NSMutableDictionary dictionary];
    
    forecast[@"currentQuarterEstimate"] = @([self safeDouble:rawData[@"currentQuarterEstimate"]]);
    forecast[@"nextQuarterEstimate"] = @([self safeDouble:rawData[@"nextQuarterEstimate"]]);
    forecast[@"currentYearEstimate"] = @([self safeDouble:rawData[@"currentYearEstimate"]]);
    forecast[@"nextYearEstimate"] = @([self safeDouble:rawData[@"nextYearEstimate"]]);
    forecast[@"numberOfAnalysts"] = @([self safeInteger:rawData[@"numberOfAnalysts"]]);
    
    return forecast;
}

- (NSDictionary *)convertFromAnalystMomentum:(NSDictionary *)rawData {
    NSMutableDictionary *momentum = [NSMutableDictionary dictionary];
    
    momentum[@"upRevisions"] = @([self safeInteger:rawData[@"upRevisions"]]);
    momentum[@"downRevisions"] = @([self safeInteger:rawData[@"downRevisions"]]);
    momentum[@"momentum"] = [self safeString:rawData[@"momentum"]];
    momentum[@"momentumScore"] = @([self safeDouble:rawData[@"momentumScore"]]);
    momentum[@"lastUpdated"] = [self safeString:rawData[@"lastUpdated"]];
    
    return momentum;
}

#pragma mark - External Data Conversion

- (NSDictionary *)convertFromFinvizStatement:(NSDictionary *)rawData {
    NSMutableDictionary *statement = [NSMutableDictionary dictionary];
    
    statement[@"rawData"] = rawData[@"raw_data"];
    statement[@"source"] = @"Finviz";
    statement[@"timestamp"] = [NSDate date];
    
    // Additional parsing would be implemented here based on Finviz response format
    
    return statement;
}

- (NSArray *)convertFromOpenInsider:(NSArray *)rawData {
    NSMutableArray *insiderData = [NSMutableArray array];
    
    for (NSDictionary *item in rawData) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        
        NSDictionary *insider = @{
            @"filingDate": [self safeString:item[@"filing_date"]],
            @"tradeDate": [self safeString:item[@"trade_date"]],
            @"ticker": [self safeString:item[@"ticker"]],
            @"companyName": [self safeString:item[@"company_name"]],
            @"insiderName": [self safeString:item[@"insider_name"]],
            @"title": [self safeString:item[@"title"]],
            @"tradeType": [self safeString:item[@"trade_type"]],
            @"price": @([self safeDouble:item[@"price"]]),
            @"quantity": @([self safeInteger:item[@"qty"]]),
            @"owned": @([self safeInteger:item[@"owned"]]),
            @"deltaOwn": @([self safeDouble:item[@"delta_own"]]),
            @"value": @([self safeDouble:item[@"value"]])
        };
        [insiderData addObject:insider];
    }
    
    return insiderData;
}

- (NSArray *)convertFromPrePostMarketMovers:(NSArray *)rawData {
    NSMutableArray *movers = [NSMutableArray array];
    
    for (NSDictionary *item in rawData) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        
        NSDictionary *mover = @{
            @"symbol": [self safeString:item[@"symbol"]],
            @"companyName": [self safeString:item[@"name"] ?: item[@"companyName"]],
            @"lastPrice": @([self safeDouble:item[@"price"] ?: item[@"lastPrice"]]),
            @"change": @([self safeDouble:item[@"change"]]),
            @"changePercent": @([self safeDouble:item[@"changePercent"] ?: item[@"pctChange"]]),
            @"volume": @([self safeInteger:item[@"volume"]]),
            @"marketSession": [self safeString:item[@"session"]] ?: @"premarket"
        };
        [movers addObject:mover];
    }
    
    return movers;
}

#pragma mark - Additional Helper Methods

- (NSInteger)normalizeRating:(NSString *)rating {
    // Normalize analyst ratings to a 1-5 scale
    // 5 = Strong Buy, 4 = Buy, 3 = Hold, 2 = Sell, 1 = Strong Sell
    
    NSString *lowerRating = [rating lowercaseString];
    
    if ([lowerRating containsString:@"strong buy"] || [lowerRating containsString:@"outperform"]) {
        return 5;
    } else if ([lowerRating containsString:@"buy"] || [lowerRating containsString:@"positive"]) {
        return 4;
    } else if ([lowerRating containsString:@"hold"] || [lowerRating containsString:@"neutral"]) {
        return 3;
    } else if ([lowerRating containsString:@"sell"] || [lowerRating containsString:@"negative"]) {
        return 2;
    } else if ([lowerRating containsString:@"strong sell"] || [lowerRating containsString:@"underperform"]) {
        return 1;
    }
    
    return 3; // Default to hold/neutral
}

@end

- (NSString *)safeString:(id)value {
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value stringValue];
    }
    return @"";
}

- (double)safeDouble:(id)value {
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value doubleValue];
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString *str = [(NSString *)value stringByReplacingOccurrencesOfString:@"," withString:@""];
        str = [str stringByReplacingOccurrencesOfString:@"$" withString:@""];
        str = [str stringByReplacingOccurrencesOfString:@"%" withString:@""];
        return [str doubleValue];
    }
    return 0.0;
}

- (NSInteger)safeInteger:(id)value {
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value integerValue];
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString *str = [(NSString *)value stringByReplacingOccurrencesOfString:@"," withString:@""];
        return [str integerValue];
    }
    return 0;
}

- (double)parseMarketCapString:(NSString *)marketCapStr {
    if (!marketCapStr || marketCapStr.length == 0) return 0.0;
    
    NSString *cleanStr = [marketCapStr stringByReplacingOccurrencesOfString:@"$" withString:@""];
    cleanStr = [cleanStr stringByReplacingOccurrencesOfString:@"," withString:@""];
    cleanStr = [cleanStr uppercaseString];
    
    double multiplier = 1.0;
    if ([cleanStr hasSuffix:@"B"]) {
        multiplier = 1000000000.0;
        cleanStr = [cleanStr substringToIndex:cleanStr.length - 1];
    } else if ([cleanStr hasSuffix:@"M"]) {
        multiplier = 1000000.0;
        cleanStr = [cleanStr substringToIndex:cleanStr.length - 1];
    } else if ([cleanStr hasSuffix:@"K"]) {
        multiplier = 1000.0;
        cleanStr = [cleanStr substringToIndex:cleanStr.length - 1];
    } else if ([cleanStr hasSuffix:@"T"]) {
        multiplier = 1000000000000.0;
        cleanStr = [cleanStr substringToIndex:cleanStr.length - 1];
    }
    
    return [cleanStr doubleValue] * multiplier;
}

- (NSDate *)convertDateString:(NSString *)dateString {
    if (!dateString || dateString.length == 0) return nil;
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    
    // Try common date formats
    NSArray *formats = @[
        @"yyyy-MM-dd'T'HH:mm:ss.SSSZ",
        @"yyyy-MM-dd'T'HH:mm:ssZ",
        @"yyyy-MM-dd HH:mm:ss",
        @"yyyy-MM-dd",
        @"MM/dd/yyyy",
        @"dd/MM/yyyy"
    ];
    
    for (NSString *format in formats) {
        formatter.dateFormat = format;
        NSDate *date = [formatter dateFromString:dateString];
        if (date) return date;
    }
    
    return nil;
}

- (NSArray *)extractFinancialMetric:(NSDictionary *)rawData key:(NSString *)key {
    // Extract time series data for financial metrics
    NSMutableArray *timeSeries = [NSMutableArray array];
    
    id dataValue = rawData[key];
    if ([dataValue isKindOfClass:[NSArray class]]) {
        for (NSDictionary *item in dataValue) {
            NSMutableDictionary *dataPoint = [NSMutableDictionary dictionary];
            dataPoint[@"date"] = [self safeString:item[@"date"] ?: item[@"period"]];
            dataPoint[@"value"] = @([self safeDouble:item[@"value"] ?: item[key]]);
            [timeSeries addObject:dataPoint];
        }
    } else if ([dataValue isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dataDict = dataValue;
        for (NSString *period in dataDict.allKeys) {
            NSMutableDictionary *dataPoint = [NSMutableDictionary dictionary];
            dataPoint[@"date"] = period;
            dataPoint[@"value"] = @([self safeDouble:dataDict[period]]);
            [timeSeries addObject:dataPoint];
        }
    }
    
    return timeSeries;
}

// Add the remaining conversion methods for analyst data, SEC filings, etc.
// (Keeping the implementation concise - include all other methods from the previous version)

@end;
}

- (NSArray<HistoricalBarModel *> *)convertHistoricalBars:(NSArray *)rawBars {
    // OtherDataSource doesn't provide historical bars
    // This method exists for protocol compliance
    return @[];
}

- (CompanyInfoModel *)convertCompanyInfo:(NSDictionary *)rawInfo {
    // Convert company info from various sources
    CompanyInfoModel *companyInfo = [[CompanyInfoModel alloc] init];
    
    companyInfo.symbol = [self safeString:rawInfo[@"symbol"]];
    companyInfo.companyName = [self safeString:rawInfo[@"companyName"] ?: rawInfo[@"name"]];
    companyInfo.exchange = [self safeString:rawInfo[@"exchange"]];
    companyInfo.sector = [self safeString:rawInfo[@"sector"]];
    companyInfo.industry = [self safeString:rawInfo[@"industry"]];
    companyInfo.country = [self safeString:rawInfo[@"country"]];
    companyInfo.website = [self safeString:rawInfo[@"website"]];
    companyInfo.description_ = [self safeString:rawInfo[@"description"]];
    
    // Market cap from string format (e.g., "1.5B", "500M")
    NSString *marketCapStr = [self safeString:rawInfo[@"marketCap"]];
    companyInfo.marketCap = [self parseMarketCapString:marketCapStr];
    
    return companyInfo;
}

- (NSArray<MarketPerformerModel *> *)convertMarketPerformers:(NSArray *)rawPerformers {
    NSMutableArray *performers = [NSMutableArray array];
    
    for (NSDictionary *rawPerformer in rawPerformers) {
        MarketPerformerModel *performer = [[MarketPerformerModel alloc] init];
        
        performer.symbol = [self safeString:rawPerformer[@"symbol"]];
        performer.companyName = [self safeString:rawPerformer[@"companyName"] ?: rawPerformer[@"name"]];
        performer.lastPrice = [self safeDouble:rawPerformer[@"lastSale"] ?: rawPerformer[@"lastPrice"] ?: rawPerformer[@"price"]];
        performer.change = [self safeDouble:rawPerformer[@"netChange"] ?: rawPerformer[@"change"]];
        performer.changePercent = [self safeDouble:rawPerformer[@"pctChange"] ?: rawPerformer[@"changePercent"]];
        performer.volume = [self safeInteger:rawPerformer[@"volume"]];
        
        // Market cap handling
        NSString *marketCapStr = [self safeString:rawPerformer[@"marketCap"]];
        performer.marketCap = [self parseMarketCapString:marketCapStr];
        
        [performers addObject:performer];
    }
    
    return performers;
}

#pragma mark - Market Data Conversion

- (NSArray *)convertFrom52WeekHighs:(NSArray *)rawData {
    return [self convertMarketPerformers:rawData];
}

- (NSArray *)convertFromStocksList:(NSArray *)rawData {
    NSMutableArray *stocks = [NSMutableArray array];
    
    for (NSDictionary *rawStock in rawData) {
        NSMutableDictionary *stock = [NSMutableDictionary dictionary];
        
        stock[@"symbol"] = [self safeString:rawStock[@"symbol"]];
        stock[@"name"] = [self safeString:rawStock[@"name"]];
        stock[@"lastSale"] = @([self safeDouble:rawStock[@"lastsale"]]);
        stock[@"netChange"] = @([self safeDouble:rawStock[@"netchange"]]);
        stock[@"pctChange"] = @([self safeDouble:rawStock[@"pctchange"]]);
        stock[@"volume"] = @([self safeInteger:rawStock[@"volume"]]);
        stock[@"marketCap"] = @([self parseMarketCapString:[self safeString:rawStock[@"marketCap"]]]);
        stock[@"country"] = [self safeString:rawStock[@"country"]];
        stock[@"ipoYear"] = [self safeString:rawStock[@"ipoyear"]];
        stock[@"industry"] = [self safeString:rawStock[@"industry"]];
        stock[@"sector"] = [self safeString:rawStock[@"sector"]];
        
        [stocks addObject:stock];
    }
    
    return stocks;
}

- (NSArray *)convertFromETFList:(NSArray *)rawData {
    NSMutableArray *etfs = [NSMutableArray array];
    
    for (NSDictionary *rawETF in rawData) {
        NSMutableDictionary *etf = [NSMutableDictionary dictionary];
        
        etf[@"symbol"] = [self safeString:rawETF[@"symbol"]];
        etf[@"companyName"] = [self safeString:rawETF[@"companyName"]];
        etf[@"lastSale"] = @([self safeDouble:rawETF[@"lastSale"]]);
        etf[@"netChange"] = @([self safeDouble:rawETF[@"netChange"]]);
        etf[@"pctChange"] = @([self safeDouble:rawETF[@"pctChange"]]);
        etf[@"volume"] = @([self safeInteger:rawETF[@"volume"]]);
        
        [etfs addObject:etf];
    }
    
    return etfs;
}

- (NSArray *)convertFromEarningsCalendar:(NSArray *)rawData {
    NSMutableArray *earnings = [NSMutableArray array];
    
    for (NSDictionary *rawEarning in rawData) {
        NSMutableDictionary *earning = [NSMutableDictionary dictionary];
        
        earning[@"symbol"] = [self safeString:rawEarning[@"symbol"]];
        earning[@"companyName"] = [self safeString:rawEarning[@"companyName"]];
        earning[@"epsForecast"] = @([self safeDouble:rawEarning[@"epsForecast"]]);
        earning[@"numberOfEstimates"] = @([self safeInteger:rawEarning[@"noOfEsts"]]);
        earning[@"reportTime"] = [self safeString:rawEarning[@"time"]];
        earning[@"lastYearEPS"] = @([self safeDouble:rawEarning[@"lastYearEPS"]]);
        earning[@"lastYearDate"] = [self safeString:rawEarning[@"lastYearDate"]];
        earning[@"marketCap"] = @([self parseMarketCapString:[self safeString:rawEarning[@"marketCap"]]]);
        
        [earnings addObject:earning];
    }
    
    return earnings;
}

- (NSArray *)convertFromEarningsSurprise:(NSArray *)rawData {
    NSMutableArray *surprises = [NSMutableArray array];
    
    for (NSDictionary *rawSurprise in rawData) {
        NSMutableDictionary *surprise = [NSMutableDictionary dictionary];
        
        surprise[@"symbol"] = [self safeString:rawSurprise[@"symbol"]];
        surprise[@"companyName"] = [self safeString:rawSurprise[@"companyName"]];
        surprise[@"eps"] = @([self safeDouble:rawSurprise[@"eps"]]);
        surprise[@"epsEstimate"] = @([self safeDouble:rawSurprise[@"epsEstimate"]]);
        surprise[@"epsSurprise"] = @([self safeDouble:rawSurprise[@"epsSurprise"]]);
        surprise[@"epsSurprisePercent"] = @([self safeDouble:rawSurprise[@"epsSurprisePct"]]);
        surprise[@"reportTime"] = [self safeString:rawSurprise[@"time"]];
        
        [surprises addObject:surprise];
    }
    
    return surprises;
}

- (NSArray *)convertFromInstitutionalTransactions:(NSArray *)rawData {
    NSMutableArray *transactions = [NSMutableArray array];
    
    for (NSDictionary *rawTx in rawData) {
        NSMutableDictionary *transaction = [NSMutableDictionary dictionary];
        
        transaction[@"symbol"] = [self safeString:rawTx[@"symbol"]];
        transaction[@"companyName"] = [self safeString:rawTx[@"companyName"]];
        transaction[@"ownerName"] = [self safeString:rawTx[@"ownerName"]];
        transaction[@"sharesTraded"] = @([self safeInteger:rawTx[@"sharesTraded"]]);
        transaction[@"lastPrice"] = @([self safeDouble:rawTx[@"lastPrice"]]);
        transaction[@"transactionValue"] = @([self safeDouble:rawTx[@"transactionValue"]]);
        transaction[@"transactionType"] = [self safeString:rawTx[@"transactionType"]];
        transaction[@"filingDate"] = [self safeString:rawTx[@"filingDate"]];
        
        [transactions addObject:transaction];
    }
    
    return transactions;
}

#pragma mark - Company Data Conversion

- (NSArray *)convertFromNews:(NSArray *)rawData {
    NSMutableArray *news = [NSMutableArray array];
    
    for (NSDictionary *rawNews in rawData) {
        NSMutableDictionary *newsItem = [NSMutableDictionary dictionary];
        
        newsItem[@"headline"] = [self safeString:rawNews[@"headline"]];
        newsItem[@"summary"] = [self safeString:rawNews[@"summary"]];
        newsItem[@"publishedDate"] = [self safeString:rawNews[@"publishedDate"]];
        newsItem[@"url"] = [self safeString:rawNews[@"url"]];
        newsItem[@"source"] = [self safeString:rawNews[@"source"]];
        
        // Standardize date format
        newsItem[@"timestamp"] = [self convertDateString:newsItem[@"publishedDate"]];
        
        [news addObject:newsItem];
    }
    
    return news;
}

- (NSArray *)convertFromPressReleases:(NSArray *)rawData {
    // Same structure as news
    return [self convertFromNews:rawData];
}

- (NSDictionary *)convertFromFinancials:(NSDictionary *)rawData {
    NSMutableDictionary *financials = [NSMutableDictionary dictionary];
    
    // Extract key financial metrics
    financials[@"revenue"] = [self extractFinancialMetric:rawData key:@"revenue"];
    financials[@"netIncome"] = [self extractFinancialMetric:rawData key:@"netIncome"];
    financials[@"eps"] = [self extractFinancialMetric:rawData key:@"eps"];
    financials[@"operatingIncome"] = [self extractFinancialMetric:rawData key:@"operatingIncome"];
    financials[@"totalAssets"] = [self extractFinancialMetric:rawData key:@"totalAssets"];
    financials[@"totalLiabilities"] = [self extractFinancialMetric:rawData key:@"totalLiabilities"];
    financials[@"shareholderEquity"] = [self extractFinancialMetric:rawData key:@"shareholderEquity"];
    financials[@"cashFlow"] = [self extractFinancialMetric:rawData key:@"cashFlow"];
    
    // Metadata
    financials[@"currency"] = [self safeString:rawData[@"currency"]];
    financials[@"period"] = [self safeString:rawData[@"period"]];
    financials[@"fiscalYear"] = [self safeString:rawData[@"fiscalYear"]];
    
    return financials;
}

- (NSDictionary *)convertFromPEGRatio:(NSDictionary *)rawData {
    NSMutableDictionary *pegData = [NSMutableDictionary dictionary];
    
    pegData[@"pegRatio"] = @([self safeDouble:rawData[@"pegRatio"]]);
    pegData[@"peRatio"] = @([self safeDouble:rawData[@"peRatio"]]);
    pegData[@"growthRate"] = @([self safeDouble:rawData[@"growthRate"]]);
    pegData[@"lastUpdated"] = [self safeString:rawData[@"lastUpdated"]];
    
    return pegData;
}

- (NSDictionary *)convertFromPriceTarget:(NSDictionary *)rawData {
    NSMutableDictionary *target = [NSMutableDictionary dictionary];
    
    target[@"meanTarget"] = @([self safeDouble:rawData[@"meanTarget"]]);
    target[@"highTarget"] = @([self safeDouble:rawData[@"highTarget"]]);
    target[@"lowTarget"] = @([self safeDouble:rawData[@"lowTarget"]]);
    target[@"numberOfAnalysts"] = @([self safeInteger:rawData[@"numberOfAnalysts"]]);
    target[@"lastUpdated"] = [self safeString:rawData[@"lastUpdated"]];
    
    return target;
}

- (NSArray *)convertFromRatings:(NSArray *)rawData {
    NSMutableArray *ratings = [NSMutableArray array];
    
    for (NSDictionary *rawRating in rawData) {
        NSMutableDictionary *rating = [NSMutableDictionary dictionary];
        
        rating[@"firm"] = [self safeString:rawRating[@"firm"]];
        rating[@"rating"] = [self safeString:rawRating[@"rating"]];
        rating[@"priceTarget"] = @([self safeDouble:rawRating[@"priceTarget"]]);
        rating[@"date"] = [self safeString:rawRating[@"date"]];
        rating[@"action"] = [self safeString:rawRating[@"action"]];
        
        // Normalize rating to standard scale
        rating[@"ratingScore"] = @([self normalizeRating:rating[@"rating"]]);
        
        [ratings addObject:rating];
    }
    
    return ratings;
}

- (NSDictionary *)convertFromShortInterest:(NSDictionary *)rawData {
    NSMutableDictionary *shortData = [NSMutableDictionary dictionary];
    
    shortData[@"shortInterest"] = @([self safeInteger:rawData[@"shortInterest"]]);
    shortData[@"shortRatio"] = @([self safeDouble:rawData[@"shortRatio"]]);
    shortData[@"percentOfFloat"] = @([self safeDouble:rawData[@"percentOfFloat"]]);
    shortData[@"previousShortInterest"] = @([self safeInteger:rawData[@"previousShortInterest"]]);
    shortData[@"changeFromPrevious"] = @([self safeInteger:rawData[@"changeFromPrevious"]]);
    shortData[@"reportDate"] = [self safeString:rawData[@"reportDate"]];
    
    return shortData;
}

- (NSArray *)convertFromInsiderTrades:(NSArray *)rawData {
    NSMutableArray *trades = [NSMutableArray array];
    
    for (NSDictionary *rawTrade in rawData) {
        NSMutableDictionary *trade = [NSMutableDictionary dictionary];
        
        trade[@"insiderName"] = [self safeString:rawTrade[@"insider"]];
        trade[@"relation"] = [self safeString:rawTrade[@"relation"]];
        trade[@"lastDate"] = [self safeString:rawTrade[@"lastDate"]];
        trade[@"transactionType"] = [self safeString:rawTrade[@"transactionType"]];
        trade[@"ownershipType"] = [self safeString:rawTrade[@"ownershipType"]];
        trade[@"sharesTraded"] = @([self safeInteger:rawTrade[@"sharesTraded"]]);
        trade[@"lastPrice"] = @([self safeDouble:rawTrade[@"lastPrice"]]);
        trade[@"sharesHeld"] = @([self safeInteger:rawTrade[@"sharesHeld"]]);
        trade[@"transactionValue"] = @([trade[@"sharesTraded"] doubleValue] * [trade[@"lastPrice"] doubleValue]);
        
        [trades addObject:trade];
    }
    
    return trades;
}

- (NSArray *)convertFromInstitutionalHoldings:(NSArray *)rawData {
    NSMutableArray *holdings = [NSMutableArray array];
    
    for (NSDictionary *rawHolding in rawData) {
        NSMutableDictionary *holding = [NSMutableDictionary dictionary];
        
        holding[@"institutionName"] = [self safeString:rawHolding[@"institutionName"]];
        holding[@"sharesHeld"] = @([self safeInteger:rawHolding[@"sharesHeld"]]);
        holding[@"marketValue"] = @([self safeDouble:rawHolding[@"marketValue"]]);
        holding[@"percentHeld"] = @([self safeDouble:rawHolding[@"percentHeld"]]);
        holding[@"reportDate"] = [self safeString:rawHolding[@"reportDate"]];
        holding[@"change"] = @([self safeInteger:rawHolding[@"change"]]);
        holding[@"changePercent"] = @([self safeDouble:rawHolding[@"changePercent"]]);
        
        [holdings addObject:holding];
    }
    
    return holdings;
}

- (NSArray *)convertFromSECFilings:(NSArray *)rawData {
    NSMutableArray *filings = [NSMutableArray array];
    
    for (NSDictionary *rawFiling in rawData) {
        NSMutableDictionary *filing = [NSMutableDictionary dictionary];
        
        filing[@"form"] = [self safeString:rawFiling[@"form"]];
        filing[@"description"] = [self safeString:rawFiling[@"description"]];
        filing[@"filedDate"] = [self safeString:rawFiling[@"filed"]];
        filing[@"period"] = [self safeString:rawFiling[@"period"]];
        filing[@"url"] = [self safeString:rawFiling[@"url"]];
        
        [filings addObject:filing];
    }
    
    return filings;
}

- (NSDictionary *)convertFromRevenue:(NSDictionary *)rawData {
    NSMutableDictionary *revenue = [NSMutableDictionary dictionary];
    
    // Extract revenue history and EPS data
    revenue[@"revenueHistory"] = [self extractTimeSeries:rawData key:@"revenue"];
    revenue[@"epsHistory"] = [self extractTimeSeries:rawData key:@"eps"];
    revenue[@"period"] = [self safeString:rawData[@"period"]];
    revenue[@"currency"] = [self safeString:rawData[@"currency"]];
    
    return revenue;
}

- (NSDictionary *)convertFromEPS:(NSDictionary *)rawData {
    NSMutableDictionary *eps = [NSMutableDictionary dictionary];
    
    eps[@"currentEPS"] = @([self safeDouble:rawData[@"eps"]]);
    eps[@"previousEPS"] = @([self safeDouble:rawData[@"previousEps"]]);
    eps[@"epsChange"] = @([self safeDouble:rawData[@"epsChange"]]);
    eps[@"epsChangePercent"] = @([self safeDouble:rawData[@"epsChangePercent"]]);
    eps[@"reportDate"] = [self safeString:rawData[@"reportDate"]];
    
    return eps;
}

- (NSDictionary *)convertFromEarningsDate:(NSDictionary *)rawData {
    NSMutableDictionary *earningsDate = [NSMutableDictionary dictionary];
    
    earningsDate[@"nextEarningsDate"] = [self safeString:rawData[@"nextEarningsDate"]];
    earningsDate[@"estimatedEPS"] = @([self safeDouble:rawData[@"estimatedEps"]]);
    earningsDate[@"previousEarningsDate"] = [self safeString:rawData[@"previousEarningsDate"]];
    earningsDate[@"previousEPS"] = @([self safeDouble:rawData[@"previousEps"]]);
    
    return earningsDate;
}

- (NSArray *)convertFromEarningsSurpriseSymbol:(NSArray *)rawData {
    NSMutableArray *surprises = [NSMutableArray array];
    
    for (NSDictionary *rawSurprise in rawData) {
        NSMutableDictionary *surprise = [NSMutableDictionary dictionary];
        
        surprise[@"reportDate"] = [self safeString:rawSurprise[@"reportDate"]];
        surprise[@"fiscalQuarterEnding"] = [self safeString:rawSurprise[@"fiscalQuarterEnding"]];
        surprise[@"eps"] = @([self safeDouble:rawSurprise[@"eps"]]);
        surprise[@"epsEstimate"] = @([self safeDouble:rawSurprise[@"epsEstimate"]]);
        surprise[@"epsSurprise"] = @([self safeDouble:rawSurprise[@"epsSurprise"]]);
        surprise[@"epsSurprisePercent"] = @([self safeDouble:rawSurprise[@"epsSurprisePct"]]);
        
        [surprises addObject:surprise];
    }
    
    return surprises;
}

- (NSDictionary *)convertFromEarningsForecast:(NSDictionary *)rawData {
    NSMutableDictionary *forecast = [NSMutableDictionary dictionary];
    
    forecast[@"currentQuarterEstimate"] = @([self safeDouble:rawData[@"currentQuarterEstimate"]]);
    forecast[@"nextQuarterEstimate"] = @([self safeDouble:rawData[@"nextQuarterEstimate"]]);
    forecast[@"currentYearEstimate"] = @([self safeDouble:rawData[@"currentYearEstimate"]]);
    forecast[@"nextYearEstimate"] = @([self safeDouble:rawData[@"nextYearEstimate"]]);
    forecast[@"numberOfAnalysts"] = @([self safeInteger:rawData[@"numberOfAnalysts"]]);
    
    return forecast;
}

- (NSDictionary *)convertFromAnalystMomentum:(NSDictionary *)rawData {
    NSMutableDictionary *momentum = [NSMutableDictionary dictionary];
    
    momentum[@"upRevisions"] = @([self safeInteger:rawData[@"upRevisions"]]);
    momentum[@"downRevisions"] = @([self safeInteger:rawData[@"downRevisions"]]);
    momentum[@"momentum"] = [self safeString:rawData[@"momentum"]];
    momentum[@"momentumScore"] = @([self safeDouble:rawData[@"momentumScore"]]);
    momentum[@"lastUpdated"] = [self safeString:rawData[@"lastUpdated"]];
    
    return momentum;
}

#pragma mark - External Data Conversion

- (NSDictionary *)convertFromFinvizStatement:(NSDictionary *)rawData {
    // Finviz data needs custom parsing
    NSMutableDictionary *statement = [NSMutableDictionary dictionary];
    
    statement[@"rawData"] = rawData[@"raw_data"];
    statement[@"source"] = @"Finviz";
    statement[@"timestamp"] = [NSDate date];
    
    // Additional parsing would be implemented here based on Finviz response format
    
    return statement;
}

- (NSDictionary *)convertFromZacksChart:(NSDictionary *)rawData {
    NSMutableDictionary *chartData = [NSMutableDictionary dictionary];
    
    chartData[@"data"] = rawData[@"data"] ?: rawData[@"raw_data"];
    chartData[@"source"] = @"Zacks";
    chartData[@"timestamp"] = [NSDate date];
    
    return chartData;
}

- (NSArray *)convertFromOpenInsider:(NSArray *)rawData {
    NSMutableArray *insiderData = [NSMutableArray array];
    
    for (NSDictionary *rawInsider in rawData) {
        NSMutableDictionary *insider = [NSMutableDictionary dictionary];
        
        insider[@"filingDate"] = [self safeString:rawInsider[@"filing_date"]];
        insider[@"tradeDate"] = [self safeString:rawInsider[@"trade_date"]];
        insider[@"ticker"] = [self safeString:rawInsider[@"ticker"]];
        insider[@"companyName"] = [self safeString:rawInsider[@"company_name"]];
        insider[@"insiderName"] = [self safeString:rawInsider[@"insider_name"]];
        insider[@"title"] = [self safeString:rawInsider[@"title"]];
        insider[@"tradeType"] = [self safeString:rawInsider[@"trade_type"]];
        insider[@"price"] = @([self safeDouble:rawInsider[@"price"]]);
        insider[@"quantity"] = @([self safeInteger:rawInsider[@"qty"]]);
        insider[@"owned"] = @([self safeInteger:rawInsider[@"owned"]]);
        insider[@"deltaOwn"] = @([self safeDouble:rawInsider[@"delta_own"]]);
        insider[@"value"] = @([self safeDouble:rawInsider[@"value"]]);
        
        [insiderData addObject:insider];
    }
    
    return insiderData;
}

- (NSArray *)convertFromPrePostMarketMovers:(NSArray *)rawData {
    // Convert StockCatalyst movers to standard format
    return [self convertMarketPerformers:rawData];
}

#pragma mark - Helper Methods

- (NSString *)safeString:(id)value {
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value stringValue];
    }
    return @"";
}

- (double)safeDouble:(id)value {
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value doubleValue];
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString *str = [(NSString *)value stringByReplacingOccurrencesOfString:@"," withString:@""];
        str = [str stringByReplacingOccurrencesOfString:@"$" withString:@""];
        str = [str stringByReplacingOccurrencesOfString:@"%" withString:@""];
        return [str doubleValue];
    }
    return 0.0;
}

- (NSInteger)safeInteger:(id)value {
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value integerValue];
    }
    if ([value isKindOfClass:[NSString class]]) {
        NSString *str = [(NSString *)value stringByReplacingOccurrencesOfString:@"," withString:@""];
        return [str integerValue];
    }
    return 0;
}

- (double)parseMarketCapString:(NSString *)marketCapStr {
    if (!marketCapStr || marketCapStr.length == 0) return 0.0;
    
    NSString *cleanStr = [marketCapStr stringByReplacingOccurrencesOfString:@"$" withString:@""];
    cleanStr = [cleanStr stringByReplacingOccurrencesOfString:@"," withString:@""];
    cleanStr = [cleanStr uppercaseString];
    
    double multiplier = 1.0;
    if ([cleanStr hasSuffix:@"B"]) {
        multiplier = 1000000000.0;
        cleanStr = [cleanStr substringToIndex:cleanStr.length - 1];
    } else if ([cleanStr hasSuffix:@"M"]) {
        multiplier = 1000000.0;
        cleanStr = [cleanStr substringToIndex:cleanStr.length - 1];
    } else if ([cleanStr hasSuffix:@"K"]) {
        multiplier = 1000.0;
        cleanStr = [cleanStr substringToIndex:cleanStr.length - 1];
    } else if ([cleanStr hasSuffix:@"T"]) {
        multiplier = 1000000000000.0;
        cleanStr = [cleanStr substringToIndex:cleanStr.length - 1];
    }
    
    return [cleanStr doubleValue] * multiplier;
}

- (NSDate *)convertDateString:(NSString *)dateString {
    if (!dateString || dateString.length == 0) return nil;
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    
    // Try common date formats
    NSArray *formats = @[
        @"yyyy-MM-dd'T'HH:mm:ss.SSSZ",
        @"yyyy-MM-dd'T'HH:mm:ssZ",
        @"yyyy-MM-dd HH:mm:ss",
        @"yyyy-MM-dd",
        @"MM/dd/yyyy",
        @"dd/MM/yyyy"
    ];
    
    for (NSString *format in formats) {
        formatter.dateFormat = format;
        NSDate *date = [formatter dateFromString:dateString];
        if (date) return date;
    }
    
    return nil;
}

- (NSArray *)extractFinancialMetric:(NSDictionary *)rawData key:(NSString *)key {
    // Extract time series data for financial metrics
    NSMutableArray *timeSeries = [NSMutableArray array];
    
    id dataValue = rawData[key];
    if ([dataValue isKindOfClass:[NSArray class]]) {
        for (NSDictionary *item in dataValue) {
            NSMutableDictionary *dataPoint = [NSMutableDictionary dictionary];
            dataPoint[@"date"] = [self safeString:item[@"date"] ?: item[@"period"]];
            dataPoint[@"value"] = @([self safeDouble:item[@"value"] ?: item[key]]);
            [timeSeries addObject:dataPoint];
        }
    } else if ([dataValue isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dataDict = dataValue;
        for (NSString *period in dataDict.allKeys) {
            NSMutableDictionary *dataPoint = [NSMutableDictionary dictionary];
            dataPoint[@"date"] = period;
            dataPoint[@"value"] = @([self safeDouble:dataDict[period]]);
            [timeSeries addObject:dataPoint];
        }
    }
    
    return timeSeries;
}

- (NSArray *)extractTimeSeries:(NSDictionary *)rawData key:(NSString *)key {
    return [self extractFinancialMetric:rawData key:key];
}

- (NSInteger)normalizeRating:(NSString *)rating {
    // Normalize analyst ratings to a 1-5 scale
    // 5 = Strong Buy, 4 = Buy, 3 = Hold, 2 = Sell, 1 = Strong Sell
    
    NSString *lowerRating = [rating lowercaseString];
    
    if ([lowerRating containsString:@"strong buy"] || [lowerRating containsString:@"outperform"]) {
        return 5;
    } else if ([lowerRating containsString:@"buy"] || [lowerRating containsString:@"positive"]) {
        return 4;
    } else if ([lowerRating containsString:@"hold"] || [lowerRating containsString:@"neutral"]) {
        return 3;
    } else if ([lowerRating containsString:@"sell"] || [lowerRating containsString:@"negative"]) {
        return 2;
    } else if ([lowerRating containsString:@"strong sell"] || [lowerRating containsString:@"underperform"]) {
        return 1;
    }
    
    return 3; // Default to hold/neutral
}

@end

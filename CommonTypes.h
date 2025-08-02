//
//  CommonTypes.h
//  TradingApp
//
//  Common type definitions shared between DataManager and DownloadManager
//

#ifndef CommonTypes_h
#define CommonTypes_h

#import <Foundation/Foundation.h>

// Data source types
typedef NS_ENUM(NSInteger, DataSourceType) {
    DataSourceTypeSchwab,
    DataSourceTypeIBKR,
    DataSourceTypeYahoo,
    DataSourceTypeWebull,
    DataSourceTypeCustom,
    DataSourceTypeClaude,
    DataSourceTypeOther
};

typedef NS_ENUM(NSInteger, DataRequestType) {
    DataRequestTypeQuote,           // Current price quote
    DataRequestTypeBatchQuotes,     // Multiple quotes in single request
    DataRequestTypeHistoricalBars,  // Historical OHLCV data
    DataRequestTypeOrderBook,       // Level 2 data
    DataRequestTypeTimeSales,       // Time and sales
    DataRequestTypeOptionChain,     // Options data
    DataRequestTypeNews,            // News feed
    DataRequestTypeFundamentals,    // Company fundamentals
    DataRequestTypePositions,       // Account positions
    DataRequestTypeOrders,          // Account orders
    DataRequestTypeAccountInfo,     // Account details
    
    // Market lists
    DataRequestTypeMarketList = 100,
    DataRequestTypeTopGainers = 101,
    DataRequestTypeTopLosers = 102,
    DataRequestTypeETFList = 103,
    DataRequestType52WeekHigh = 104,        // NUOVO: 52-week highs/lows
        DataRequestTypeStocksList = 105,        // NUOVO: Lista completa stocks
        DataRequestTypeEarningsCalendar = 106,  // NUOVO: Calendario earnings
        DataRequestTypeEarningsSurprise = 107,  // NUOVO: Earnings surprise
        DataRequestTypeInstitutionalTx = 108,   // NUOVO: Transazioni istituzionali >1M
        DataRequestTypePMMovers = 109,          // NUOVO: Pre/post market movers
        
        // Company specific data
        DataRequestTypeCompanyNews = 200,       // NUOVO: News per simbolo
        DataRequestTypePressReleases = 201,     // NUOVO: Press releases
        DataRequestTypeFinancials = 202,        // NUOVO: Statements finanziari
        DataRequestTypePEGRatio = 203,          // NUOVO: PEG ratio
        DataRequestTypeShortInterest = 204,     // NUOVO: Short interest
        DataRequestTypeInsiderTrades = 205,     // NUOVO: Insider trades
        DataRequestTypeInstitutional = 206,     // NUOVO: Institutional holdings
        DataRequestTypeSECFilings = 207,        // NUOVO: SEC filings
        DataRequestTypeRevenue = 208,           // NUOVO: Revenue & EPS history
        DataRequestTypePriceTarget = 209,       // NUOVO: Analyst price targets
        DataRequestTypeRatings = 210,           // NUOVO: Analyst ratings
        DataRequestTypeEarningsDate = 211,      // NUOVO: Earnings report dates
        DataRequestTypeEPS = 212,               // NUOVO: EPS data
        DataRequestTypeEarningsForecast = 213,  // NUOVO: Earnings forecast
        DataRequestTypeAnalystMomentum = 214,   // NUOVO: Analyst estimate momentum
        
        // Finviz data
        DataRequestTypeFinvizStatements = 300,  // NUOVO: Finviz financial statements
        
        // Zacks data
        DataRequestTypeZacksCharts = 400,       // NUOVO: Zacks chart data (revenue, eps, etc.)
        
        // Web scraping data
        DataRequestTypeOpenInsider = 500,       // NUOVO: OpenInsider buy/sell data
    // AI Services - NUOVO
    DataRequestTypeNewsSummary = 200,      // Claude AI news summary
    DataRequestTypeTextSummary = 201,      // Claude AI text summary
    DataRequestTypeAIAnalysis = 202        // Future: AI analysis requests
};

// Bar timeframes
typedef NS_ENUM(NSInteger, BarTimeframe) {
    BarTimeframe1Min,
    BarTimeframe5Min,
    BarTimeframe15Min,
    BarTimeframe30Min,
    BarTimeframe1Hour,
    BarTimeframe4Hour,
    BarTimeframe1Day,
    BarTimeframe1Week,
    BarTimeframe1Month
};

// Data freshness types for caching
typedef NS_ENUM(NSInteger, DataFreshnessType) {
    DataFreshnessTypeQuote,           // TTL: 5-10 seconds
    DataFreshnessTypeMarketOverview,  // TTL: 1 minute
    DataFreshnessTypeHistorical,      // TTL: 5 minutes
    DataFreshnessTypeCompanyInfo,     // TTL: 24 hours
    DataFreshnessTypeWatchlist,       // TTL: Infinite (user managed)
    DataFreshnessTypeAISummary        // TTL: 24 hours (AI summaries are stable)
};

// Data source capabilities
typedef NS_OPTIONS(NSUInteger, DataSourceCapabilities) {
    DataSourceCapabilityQuotes          = 1 << 0,
    DataSourceCapabilityHistorical      = 1 << 1,
    DataSourceCapabilityOrderBook       = 1 << 2,
    DataSourceCapabilityTimeSales       = 1 << 3,
    DataSourceCapabilityOptions         = 1 << 4,
    DataSourceCapabilityNews            = 1 << 5,
    DataSourceCapabilityFundamentals    = 1 << 6,
    DataSourceCapabilityAccounts        = 1 << 7,
    DataSourceCapabilityTrading         = 1 << 8,
    DataSourceCapabilityRealtime        = 1 << 9,
    DataSourceCapabilityAI              = 1 << 10,  // AI capabilities
       DataSourceCapabilityAnalyst         = 1 << 11,  // NUOVO: Analyst data
       DataSourceCapabilityInsider         = 1 << 12,  // NUOVO: Insider data
       DataSourceCapabilityInstitutional   = 1 << 13   // NUOVO: Institutional data
};

#endif /* CommonTypes_h */

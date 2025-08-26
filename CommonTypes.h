//
//  CommonTypes.h (UPDATED - UNIFIED TIMEFRAMES)
//  TradingApp
//
//  UNIFICAZIONE: Enum BarTimeframe standardizzato per supportare
//  tutti i timeframe delle API (Yahoo, Schwab, Webull, IBKR)
//

#ifndef CommonTypes_h
#define CommonTypes_h

#import <Foundation/Foundation.h>

#pragma mark - Data Source Types

typedef NS_ENUM(NSInteger, DataSourceType) {
    DataSourceTypeSchwab,
    DataSourceTypeIBKR,
    DataSourceTypeYahoo,
    DataSourceTypeWebull,
    DataSourceTypeCustom,
    DataSourceTypeClaude,
    DataSourceTypeOther  // For Yahoo Finance and other fallback APIs
};

#pragma mark - Data Source Capabilities

typedef NS_OPTIONS(NSInteger, DataSourceCapabilities) {
    DataSourceCapabilityNone = 0,
    DataSourceCapabilityQuotes = 1 << 0,              // Real-time/delayed quotes
    DataSourceCapabilityHistoricalData = 1 << 1,      // Historical OHLCV bars
    DataSourceCapabilityLevel2Data = 1 << 2,          // Order book/market depth
    DataSourceCapabilityPortfolioData = 1 << 3,       // Account positions/orders
    DataSourceCapabilityTrading = 1 << 4,             // Order placement/management
    DataSourceCapabilityMarketLists = 1 << 5,         // Top gainers/losers/etc
    DataSourceCapabilityFundamentals = 1 << 6,        // Company fundamental data
    DataSourceCapabilityOptions = 1 << 7,             // Options chains
    DataSourceCapabilityNews = 1 << 8,                // News feeds
    DataSourceCapabilityAnalytics = 1 << 9            // Technical indicators/analytics
};

#pragma mark - UNIFIED BAR TIMEFRAMES

/**
 * UNIFIED: Standardized bar timeframes supported across all data sources
 * Maps to specific intervals for each API:
 * - Yahoo Finance: 1m, 2m, 5m, 15m, 30m, 60m, 90m, 1d, 5d, 1wk, 1mo, 3mo
 * - Schwab: 1, 5, 10, 15, 30, 60 (minutes), Daily, Weekly, Monthly
 * - Webull: m1, m5, m15, m30, h1, h4, d1, w1, M1
 * - IBKR: 1 secs, 5 secs, 10 secs, 15 secs, 30 secs, 1 min, 2 mins, 3 mins, 5 mins, 10 mins, 15 mins, 20 mins, 30 mins, 1 hour, 2 hours, 3 hours, 4 hours, 8 hours, 1 day, 1W, 1M
 */
typedef NS_ENUM(NSInteger, BarTimeframe) {
    // Intraday timeframes
    BarTimeframe1Min = 1,        // 1 minute bars
    BarTimeframe2Min = 2,        // 2 minute bars
    BarTimeframe5Min = 5,        // 5 minute bars
    BarTimeframe10Min = 10,      // 10 minute bars (Schwab, IBKR)
    BarTimeframe15Min = 15,      // 15 minute bars
    BarTimeframe20Min = 20,      // 20 minute bars (IBKR)
    BarTimeframe30Min = 30,      // 30 minute bars
    BarTimeframe1Hour = 60,      // 1 hour bars
    BarTimeframe90Min = 90,      // 90 minute bars (Yahoo)
    BarTimeframe2Hour = 120,     // 2 hour bars (IBKR)
    BarTimeframe4Hour = 240,     // 4 hour bars (Webull, IBKR)
    
    // Daily and higher timeframes
    BarTimeframeDaily = 1000,    // Daily bars
    BarTimeframeWeekly = 1001,   // Weekly bars
    BarTimeframeMonthly = 1002,  // Monthly bars
    BarTimeframeQuarterly = 1003 // Quarterly bars (Yahoo 3mo)
};

#pragma mark - Request Types

typedef NS_ENUM(NSInteger, DataRequestType) {
    // Core market data
    DataRequestTypeQuote,           // Single symbol quote
    DataRequestTypeBatchQuotes,     // Multiple symbols quotes
    DataRequestTypeHistoricalBars,  // Historical OHLCV data
    DataRequestTypeOrderBook,       // Level 2 market depth
    DataRequestTypeTimeSales,       // Time and sales data
    DataRequestTypeOptionChain,     // Options data
    DataRequestTypeNews,            // News feed
    DataRequestTypeFundamentals,    // Company fundamentals
    
    // Account/portfolio data
    DataRequestTypePositions,       // Account positions
    DataRequestTypeOrders,          // Account orders
    DataRequestTypeAccountInfo,     // Account details
    
    // Market lists and screeners
    DataRequestTypeMarketList = 100,
    DataRequestTypeTopGainers = 101,
    DataRequestTypeTopLosers = 102,
    DataRequestTypeETFList = 103,
    DataRequestType52WeekHigh = 104,
    DataRequestType52WeekLow = 105,
    DataRequestTypeStocksList = 106,
    DataRequestTypeEarningsCalendar = 107,
    DataRequestTypeEarningsSurprise = 108,
    DataRequestTypeInstitutionalTx = 109,
    DataRequestTypePMMovers = 110,
    
    // Company specific data
    DataRequestTypeCompanyNews = 200,
    DataRequestTypePressReleases = 201,
    DataRequestTypeFinancials = 202,
    DataRequestTypePEGRatio = 203,
    DataRequestTypeShortInterest = 204,
    DataRequestTypeInsiderTrades = 205,
    DataRequestTypeInstitutional = 206,
    DataRequestTypeSECFilings = 207,
    DataRequestTypeRevenue = 208,
    DataRequestTypePriceTarget = 209,
    DataRequestTypeRatings = 210,
    DataRequestTypeEarningsDate = 211,
    DataRequestTypeEPS = 212,
    DataRequestTypeEarningsForecast = 213,
    DataRequestTypeAnalystMomentum = 214,
    
    // External data sources
    DataRequestTypeFinvizStatements = 300,
    DataRequestTypeZacksCharts = 400,
    DataRequestTypeOpenInsider = 500
};

#pragma mark - Market Timeframes for Lists

typedef NS_ENUM(NSInteger, MarketTimeframe) {
    MarketTimeframePreMarket,     // Pre-market hours
    MarketTimeframeAfterHours,    // After-hours
    MarketTimeframeFiveMinutes,   // Last 5 minutes
    MarketTimeframeOneDay,        // Current trading day
    MarketTimeframeFiveDays,      // Last 5 trading days
    MarketTimeframeOneWeek,       // Last week
    MarketTimeframeOneMonth,      // Last month
    MarketTimeframeThreeMonths,   // Last 3 months
    MarketTimeframeFiftyTwoWeeks  // Last 52 weeks
};

#pragma mark - Data Freshness

typedef NS_ENUM(NSInteger, DataFreshnessType) {
    DataFreshnessLive,      // Real-time data (< 1 second old)
    DataFreshnessDelayed,   // Delayed data (15-20 minutes)
    DataFreshnessCached,    // Cached data (fresh within TTL)
    DataFreshnessStale      // Stale data (beyond TTL)
};

#pragma mark - Helper Functions

/**
 * Convert BarTimeframe to human-readable string
 */
static inline NSString* BarTimeframeToString(BarTimeframe timeframe) {
    switch (timeframe) {
        case BarTimeframe1Min: return @"1min";
        case BarTimeframe2Min: return @"2min";
        case BarTimeframe5Min: return @"5min";
        case BarTimeframe10Min: return @"10min";
        case BarTimeframe15Min: return @"15min";
        case BarTimeframe20Min: return @"20min";
        case BarTimeframe30Min: return @"30min";
        case BarTimeframe1Hour: return @"1hour";
        case BarTimeframe90Min: return @"90min";
        case BarTimeframe2Hour: return @"2hour";
        case BarTimeframe4Hour: return @"4hour";
        case BarTimeframeDaily: return @"daily";
        case BarTimeframeWeekly: return @"weekly";
        case BarTimeframeMonthly: return @"monthly";
        case BarTimeframeQuarterly: return @"quarterly";
        default: return @"unknown";
    }
}

/**
 * Convert BarTimeframe to minutes (for intraday timeframes)
 * Returns 0 for daily and higher timeframes
 */
static inline NSInteger BarTimeframeToMinutes(BarTimeframe timeframe) {
    if (timeframe < 1000) {
        return timeframe; // Intraday timeframes are stored as minutes
    }
    return 0; // Daily and higher timeframes
}

/**
 * Check if timeframe is intraday
 */
static inline BOOL BarTimeframeIsIntraday(BarTimeframe timeframe) {
    return timeframe < 1000;
}

/**
 * Get appropriate bar count for timeframe to cover a specific time period
 */
static inline NSInteger BarTimeframeGetBarsForPeriod(BarTimeframe timeframe, NSTimeInterval period) {
    NSTimeInterval barInterval;
    
    switch (timeframe) {
        case BarTimeframe1Min: barInterval = 60; break;
        case BarTimeframe2Min: barInterval = 120; break;
        case BarTimeframe5Min: barInterval = 300; break;
        case BarTimeframe10Min: barInterval = 600; break;
        case BarTimeframe15Min: barInterval = 900; break;
        case BarTimeframe20Min: barInterval = 1200; break;
        case BarTimeframe30Min: barInterval = 1800; break;
        case BarTimeframe1Hour: barInterval = 3600; break;
        case BarTimeframe90Min: barInterval = 5400; break;
        case BarTimeframe2Hour: barInterval = 7200; break;
        case BarTimeframe4Hour: barInterval = 14400; break;
        case BarTimeframeDaily: barInterval = 86400; break;
        case BarTimeframeWeekly: barInterval = 604800; break;
        case BarTimeframeMonthly: barInterval = 2592000; break; // Approx 30 days
        case BarTimeframeQuarterly: barInterval = 7776000; break; // Approx 90 days
        default: barInterval = 86400; break; // Default to daily
    }
    
    return (NSInteger)(period / barInterval);
}

#endif /* CommonTypes_h */

//
//  CommonTypes.h (UPDATED - SECURITY ENHANCED)
//  TradingApp
//
//  🛡️ SECURITY UPDATE: Added missing DataRequestType for Account & Trading operations
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
    DataSourceTypeOther,
    DataSourceTypeLocal = 999  // ADD THIS LINE
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
    DataSourceCapabilityAnalytics = 1 << 9,
    DataSourceCapabilityAI = 1 << 10
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
    // 📈 MARKET DATA (Automatic routing with fallback OK)
    DataRequestTypeQuote,           // Single symbol quote
    DataRequestTypeBatchQuotes,     // Multiple symbols quotes
    DataRequestTypeHistoricalBars,  // Historical OHLCV data
    DataRequestTypeOrderBook,       // Level 2 market depth
    DataRequestTypeTimeSales,       // Time and sales data
    DataRequestTypeOptionChain,     // Options data
    DataRequestTypeNews,            // News feed
    DataRequestTypeFundamentals,    // Company fundamentals
    
    // 🛡️ ACCOUNT DATA (Specific DataSource REQUIRED, NO fallback)
    DataRequestTypePositions,       // Account positions
    DataRequestTypeOrders,          // Account orders
    DataRequestTypeAccountInfo,     // Account details
    DataRequestTypeAccounts,        // List of accounts for specific broker
    
    // Market lists and screeners (routing OK)
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
    
    // Company specific data (routing OK)
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
    DataRequestTypeGoogleFinanceNews = 215,
     DataRequestTypeYahooFinanceNews = 217,
     DataRequestTypeSeekingAlphaNews = 218,
    
    // External data sources (routing OK)
    DataRequestTypeFinvizStatements = 300,
    DataRequestTypeZacksCharts = 400,
    DataRequestTypeOpenInsider = 500,
    
    // 🚨 TRADING OPERATIONS (Specific DataSource REQUIRED, NEVER fallback)
    DataRequestTypePlaceOrder = 600,      // Place new order
    DataRequestTypeCancelOrder = 601,     // Cancel existing order
    DataRequestTypeModifyOrder = 602,     // Modify existing order
    DataRequestTypePreviewOrder = 603,    // Preview order before placing
    DataRequestTypeOrderStatus = 604      // Get order status
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

#pragma mark - 🛡️ Security Classification Helper Functions

/**
 * 📈 Check if request type allows automatic routing (Market Data)
 * These request types can use fallback between different data sources
 */
static inline BOOL IsMarketDataRequestType(DataRequestType requestType) {
    switch (requestType) {
        // Core market data (routing OK)
        case DataRequestTypeQuote:
        case DataRequestTypeBatchQuotes:
        case DataRequestTypeHistoricalBars:
        case DataRequestTypeOrderBook:
        case DataRequestTypeTimeSales:
        case DataRequestTypeOptionChain:
        case DataRequestTypeNews:
        case DataRequestTypeFundamentals:
            
        // Market lists and screeners (routing OK)
        case DataRequestTypeMarketList:
        case DataRequestTypeTopGainers:
        case DataRequestTypeTopLosers:
        case DataRequestTypeETFList:
        case DataRequestType52WeekHigh:
        case DataRequestType52WeekLow:
        case DataRequestTypeStocksList:
        case DataRequestTypeEarningsCalendar:
        case DataRequestTypeEarningsSurprise:
        case DataRequestTypeInstitutionalTx:
        case DataRequestTypePMMovers:
            
        // Company specific data (routing OK)
        case DataRequestTypeCompanyNews:
        case DataRequestTypePressReleases:
        case DataRequestTypeFinancials:
        case DataRequestTypePEGRatio:
        case DataRequestTypeShortInterest:
        case DataRequestTypeInsiderTrades:
        case DataRequestTypeInstitutional:
        case DataRequestTypeSECFilings:
        case DataRequestTypeRevenue:
        case DataRequestTypePriceTarget:
        case DataRequestTypeRatings:
        case DataRequestTypeEarningsDate:
        case DataRequestTypeEPS:
        case DataRequestTypeEarningsForecast:
        case DataRequestTypeAnalystMomentum:
            
        // 📰 NEWS DATA SOURCES (AGGIUNTI) ✅
        case DataRequestTypeGoogleFinanceNews:
        case DataRequestTypeYahooFinanceNews:
        case DataRequestTypeSeekingAlphaNews:
            
        // External data sources (routing OK)
        case DataRequestTypeFinvizStatements:
        case DataRequestTypeZacksCharts:
        case DataRequestTypeOpenInsider:
            return YES;
            
        default:
            return NO; // Account data and trading operations not allowed
    }
}

/**
 * 🛡️ Check if request type is Account Data (requires specific DataSource)
 * These request types MUST specify exact broker, NO automatic routing
 */
static inline BOOL IsAccountDataRequestType(DataRequestType requestType) {
    switch (requestType) {
        case DataRequestTypePositions:
        case DataRequestTypeOrders:
        case DataRequestTypeAccountInfo:
        case DataRequestTypeAccounts:
        case DataRequestTypeOrderStatus:  // Order status is account-specific
            return YES;
            
        default:
            return NO;
    }
}

/**
 * 🚨 Check if request type is Trading Operation (most critical security)
 * These request types are NEVER allowed automatic routing - exact broker required
 */
static inline BOOL IsTradingRequestType(DataRequestType requestType) {
    switch (requestType) {
        case DataRequestTypePlaceOrder:
        case DataRequestTypeCancelOrder:
        case DataRequestTypeModifyOrder:
        case DataRequestTypePreviewOrder:
            return YES;
            
        default:
            return NO;
    }
}

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
        case BarTimeframeDaily: return @"1day";
        case BarTimeframeWeekly: return @"1week";
        case BarTimeframeMonthly: return @"1month";
        case BarTimeframeQuarterly: return @"3month";
        default: return @"unknown";
    }
}

/**
 * Convert DataRequestType to human-readable string for logging
 */
static inline NSString* DataRequestTypeToString(DataRequestType requestType) {
    switch (requestType) {
        // Market Data
        case DataRequestTypeQuote: return @"Quote";
        case DataRequestTypeBatchQuotes: return @"BatchQuotes";
        case DataRequestTypeHistoricalBars: return @"HistoricalBars";
        case DataRequestTypeOrderBook: return @"OrderBook";
        case DataRequestTypeFundamentals: return @"Fundamentals";
        case DataRequestTypeNews: return @"News";
        case DataRequestTypeGoogleFinanceNews: return @"GoogleFinanceNews";
               case DataRequestTypeSECFilings: return @"SECFilings";
               case DataRequestTypeYahooFinanceNews: return @"YahooFinanceNews";
               case DataRequestTypeSeekingAlphaNews: return @"SeekingAlphaNews";
        // Account Data
        case DataRequestTypePositions: return @"🛡️ Positions";
        case DataRequestTypeOrders: return @"🛡️ Orders";
        case DataRequestTypeAccountInfo: return @"🛡️ AccountInfo";
        case DataRequestTypeAccounts: return @"🛡️ Accounts";
        
        // Trading Operations
        case DataRequestTypePlaceOrder: return @"🚨 PlaceOrder";
        case DataRequestTypeCancelOrder: return @"🚨 CancelOrder";
        case DataRequestTypeModifyOrder: return @"🚨 ModifyOrder";
        
        // Market Lists
        case DataRequestTypeTopGainers: return @"TopGainers";
        case DataRequestTypeTopLosers: return @"TopLosers";
        case DataRequestTypeETFList: return @"ETFList";
        
        default: return [NSString stringWithFormat:@"Unknown(%ld)", (long)requestType];
    }
}

/**
 * Convert DataSourceType to human-readable string
 */
static inline NSString* DataSourceTypeToString(DataSourceType sourceType) {
    switch (sourceType) {
        case DataSourceTypeSchwab: return @"SCHWAB";
        case DataSourceTypeIBKR: return @"IBKR";
        case DataSourceTypeYahoo: return @"Yahoo";
        case DataSourceTypeWebull: return @"Webull";
        case DataSourceTypeCustom: return @"Custom";
        case DataSourceTypeClaude: return @"Claude";
        case DataSourceTypeOther: return @"Other";
        default: return [NSString stringWithFormat:@"Unknown(%ld)", (long)sourceType];
    }
}

#endif /* CommonTypes_h */

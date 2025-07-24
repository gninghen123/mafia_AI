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
    DataSourceTypeTDAmeritrade,
    DataSourceTypeInteractiveBrokers,
    DataSourceTypeAlpaca,
    DataSourceTypeYahoo,
    DataSourceTypePolygon,
    DataSourceTypeIEX,
    DataSourceTypeCustom
};

// Data request types
typedef NS_ENUM(NSInteger, DataRequestType) {
    DataRequestTypeQuote,           // Current price quote
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
    DataSourceCapabilityRealtime        = 1 << 9
};

#endif /* CommonTypes_h */

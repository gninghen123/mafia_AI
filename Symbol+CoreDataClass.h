//
//  Symbol+CoreDataClass.h
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Alert, ChartLayer, CompanyInfo, HistoricalBar, MarketPerformer, MarketQuote, NSArray, StockConnection, TradingModel, Watchlist;

NS_ASSUME_NONNULL_BEGIN

@interface Symbol : NSManagedObject

@end

NS_ASSUME_NONNULL_END

#import "Symbol+CoreDataProperties.h"

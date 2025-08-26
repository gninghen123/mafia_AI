//
//  Symbol+CoreDataProperties.h
//  mafia_AI
//
//  Created by fabio gattone on 07/08/25.
//
//

#import "Symbol+CoreDataClass.h"


NS_ASSUME_NONNULL_BEGIN

@interface Symbol (CoreDataProperties)

+ (NSFetchRequest<Symbol *> *)fetchRequest NS_SWIFT_NAME(fetchRequest());

@property (nullable, nonatomic, copy) NSDate *creationDate;
@property (nullable, nonatomic, copy) NSDate *firstInteraction;
@property (nonatomic) int32_t interactionCount;
@property (nonatomic) BOOL isFavorite;
@property (nullable, nonatomic, copy) NSDate *lastInteraction;
@property (nullable, nonatomic, copy) NSString *notes;
@property (nullable, nonatomic, copy) NSString *symbol;
@property (nullable, nonatomic, retain) NSArray *tags;
@property (nullable, nonatomic, retain) NSSet<Alert *> *alerts;
@property (nullable, nonatomic, retain) NSSet<ChartLayer *> *chartLayers;
@property (nullable, nonatomic, retain) CompanyInfo *companyInfo;
@property (nullable, nonatomic, retain) NSSet<HistoricalBar *> *historicalBars;
@property (nullable, nonatomic, retain) NSSet<MarketPerformer *> *marketPerformers;
@property (nullable, nonatomic, retain) NSSet<MarketQuote *> *marketQuotes;
@property (nullable, nonatomic, retain) NSSet<StockConnection *> *sourceConnections;
@property (nullable, nonatomic, retain) NSSet<StockConnection *> *targetConnections;
@property (nullable, nonatomic, retain) NSSet<TradingModel *> *tradingModels;
@property (nullable, nonatomic, retain) NSSet<Watchlist *> *watchlists;

@end

@interface Symbol (CoreDataGeneratedAccessors)

- (void)addAlertsObject:(Alert *)value;
- (void)removeAlertsObject:(Alert *)value;
- (void)addAlerts:(NSSet<Alert *> *)values;
- (void)removeAlerts:(NSSet<Alert *> *)values;

- (void)addChartLayersObject:(ChartLayer *)value;
- (void)removeChartLayersObject:(ChartLayer *)value;
- (void)addChartLayers:(NSSet<ChartLayer *> *)values;
- (void)removeChartLayers:(NSSet<ChartLayer *> *)values;

- (void)addHistoricalBarsObject:(HistoricalBar *)value;
- (void)removeHistoricalBarsObject:(HistoricalBar *)value;
- (void)addHistoricalBars:(NSSet<HistoricalBar *> *)values;
- (void)removeHistoricalBars:(NSSet<HistoricalBar *> *)values;

- (void)addMarketPerformersObject:(MarketPerformer *)value;
- (void)removeMarketPerformersObject:(MarketPerformer *)value;
- (void)addMarketPerformers:(NSSet<MarketPerformer *> *)values;
- (void)removeMarketPerformers:(NSSet<MarketPerformer *> *)values;

- (void)addMarketQuotesObject:(MarketQuote *)value;
- (void)removeMarketQuotesObject:(MarketQuote *)value;
- (void)addMarketQuotes:(NSSet<MarketQuote *> *)values;
- (void)removeMarketQuotes:(NSSet<MarketQuote *> *)values;

- (void)addSourceConnectionsObject:(StockConnection *)value;
- (void)removeSourceConnectionsObject:(StockConnection *)value;
- (void)addSourceConnections:(NSSet<StockConnection *> *)values;
- (void)removeSourceConnections:(NSSet<StockConnection *> *)values;

- (void)addTargetConnectionsObject:(StockConnection *)value;
- (void)removeTargetConnectionsObject:(StockConnection *)value;
- (void)addTargetConnections:(NSSet<StockConnection *> *)values;
- (void)removeTargetConnections:(NSSet<StockConnection *> *)values;

- (void)addTradingModelsObject:(TradingModel *)value;
- (void)removeTradingModelsObject:(TradingModel *)value;
- (void)addTradingModels:(NSSet<TradingModel *> *)values;
- (void)removeTradingModels:(NSSet<TradingModel *> *)values;

- (void)addWatchlistsObject:(Watchlist *)value;
- (void)removeWatchlistsObject:(Watchlist *)value;
- (void)addWatchlists:(NSSet<Watchlist *> *)values;
- (void)removeWatchlists:(NSSet<Watchlist *> *)values;

@end

NS_ASSUME_NONNULL_END

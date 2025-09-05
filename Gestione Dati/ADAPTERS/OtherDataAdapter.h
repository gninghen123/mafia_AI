//
//  OtherDataAdapter.h
//  TradingApp
//
//  Adapter for OtherDataSource - converts Zacks API responses to standard formats
//  FOCUS: Only Zacks seasonal data for SeasonalChartWidget
//

#import <Foundation/Foundation.h>
#import "DataSourceAdapter.h"
#import "SeasonalDataModel.h"
#import "QuarterlyDataPoint.h"

NS_ASSUME_NONNULL_BEGIN

@interface OtherDataAdapter : NSObject <DataSourceAdapter>

#pragma mark - Zacks Data Conversion (PRIMARY FOCUS)

/**
 * Convert Zacks chart data to SeasonalDataModel for SeasonalChartWidget
 * This is the main method for this adapter
 */
- (nullable SeasonalDataModel *)convertZacksChartToSeasonalModel:(NSDictionary *)rawData
                                                          symbol:(NSString *)symbol
                                                        dataType:(NSString *)dataType;
#pragma mark - News Data Standardization (Runtime Models) - NEW

/**
 * Convert raw news array to NewsModel runtime models
 * @param rawData Raw news array from API response
 * @param symbol Symbol identifier
 * @param newsType Type of news ("news", "press_release", "filing", etc.)
 * @return Array of NewsModel runtime models
 */
- (NSArray<NewsModel *> *)standardizeNewsData:(NSArray *)rawData
                                    forSymbol:(NSString *)symbol
                                     newsType:(NSString *)newsType;

@end

NS_ASSUME_NONNULL_END

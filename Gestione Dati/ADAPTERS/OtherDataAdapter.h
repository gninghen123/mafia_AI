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

@end

NS_ASSUME_NONNULL_END

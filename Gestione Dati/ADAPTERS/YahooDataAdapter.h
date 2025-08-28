//
//  YahooDataAdapter.h
//  TradingApp
//
//  Dedicated adapter for Yahoo Finance API JSON format
//  Converts Yahoo's modern JSON API responses to standardized app format
//

#import <Foundation/Foundation.h>
#import "DataSourceAdapter.h"


@interface YahooDataAdapter : NSObject <DataSourceAdapter>

@end

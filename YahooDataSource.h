//
//  YahooDataSource.h
//  TradingApp
//
//  Yahoo Finance data source implementation
//

#import <Foundation/Foundation.h>
#import "DownloadManager.h"

@interface YahooDataSource : NSObject 

// Yahoo-specific configuration
@property (nonatomic, assign) BOOL useCrumbAuthentication;
@property (nonatomic, assign) NSTimeInterval cacheTimeout;

@end

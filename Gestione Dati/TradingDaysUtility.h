// TradingDaysUtility.h
#import <Foundation/Foundation.h>

@interface TradingDaysUtility : NSObject

// Check if a date is a trading day (excludes weekends and US holidays)
+ (BOOL)isTradingDay:(NSDate *)date;

// Check if a date is a US market holiday
+ (BOOL)isUSMarketHoliday:(NSDate *)date;

// Get next N trading days from a given date
+ (NSArray<NSDate *> *)getNextTradingDays:(NSInteger)count fromDate:(NSDate *)startDate;

// Get previous N trading days from a given date
+ (NSArray<NSDate *> *)getPreviousTradingDays:(NSInteger)count fromDate:(NSDate *)startDate;

// Get US market holidays for a given year
+ (NSArray<NSDate *> *)getUSMarketHolidaysForYear:(NSInteger)year;

@end

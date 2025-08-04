// TradingDaysUtility.m
#import "TradingDaysUtility.h"

@implementation TradingDaysUtility

+ (BOOL)isTradingDay:(NSDate *)date {
    if (!date) return NO;
    
    // Check if it's weekend
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSInteger weekday = [calendar component:NSCalendarUnitWeekday fromDate:date];
    
    // Sunday = 1, Saturday = 7
    if (weekday == 1 || weekday == 7) {
        return NO;
    }
    
    // Check if it's a US market holiday
    if ([self isUSMarketHoliday:date]) {
        return NO;
    }
    
    return YES;
}

+ (BOOL)isUSMarketHoliday:(NSDate *)date {
    if (!date) return NO;
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitWeekday) fromDate:date];
    
    NSInteger year = components.year;
    NSInteger month = components.month;
    NSInteger day = components.day;
    NSInteger weekday = components.weekday;
    
    // New Year's Day (January 1st, or next Monday if weekend)
    if (month == 1) {
        if (day == 1 && weekday >= 2 && weekday <= 6) return YES; // Jan 1 on weekday
        if (day == 2 && weekday == 2) return YES; // Jan 2 Monday if Jan 1 was Sunday
        if (day == 3 && weekday == 2) return YES; // Jan 3 Monday if Jan 1 was Saturday
    }
    
    // Martin Luther King Jr. Day (3rd Monday in January)
    if (month == 1 && weekday == 2) {
        NSInteger mondayCount = (day - 1) / 7 + 1;
        if (mondayCount == 3) return YES;
    }
    
    // Presidents' Day (3rd Monday in February)
    if (month == 2 && weekday == 2) {
        NSInteger mondayCount = (day - 1) / 7 + 1;
        if (mondayCount == 3) return YES;
    }
    
    // Good Friday (Friday before Easter) - Complex calculation
    NSDate *easter = [self getEasterDateForYear:year];
    if (easter) {
        NSDate *goodFriday = [calendar dateByAddingUnit:NSCalendarUnitDay value:-2 toDate:easter options:0];
        NSDateComponents *goodFridayComponents = [calendar components:(NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:goodFriday];
        if (month == goodFridayComponents.month && day == goodFridayComponents.day) {
            return YES;
        }
    }
    
    // Memorial Day (last Monday in May)
    if (month == 5 && weekday == 2) {
        // Check if this is the last Monday in May
        NSDate *nextWeek = [calendar dateByAddingUnit:NSCalendarUnitWeekOfYear value:1 toDate:date options:0];
        NSDateComponents *nextWeekComponents = [calendar components:NSCalendarUnitMonth fromDate:nextWeek];
        if (nextWeekComponents.month == 6) return YES; // Next week is June, so this is last Monday of May
    }
    
    // Juneteenth (June 19th, or next Monday if weekend)
    if (month == 6) {
        if (day == 19 && weekday >= 2 && weekday <= 6) return YES; // Jun 19 on weekday
        if (day == 20 && weekday == 2) return YES; // Jun 20 Monday if Jun 19 was Sunday
        if (day == 21 && weekday == 2) return YES; // Jun 21 Monday if Jun 19 was Saturday
    }
    
    // Independence Day (July 4th, or next Monday if weekend)
    if (month == 7) {
        if (day == 4 && weekday >= 2 && weekday <= 6) return YES; // Jul 4 on weekday
        if (day == 5 && weekday == 2) return YES; // Jul 5 Monday if Jul 4 was Sunday
        if (day == 6 && weekday == 2) return YES; // Jul 6 Monday if Jul 4 was Saturday
    }
    
    // Labor Day (1st Monday in September)
    if (month == 9 && weekday == 2) {
        NSInteger mondayCount = (day - 1) / 7 + 1;
        if (mondayCount == 1) return YES;
    }
    
    // Thanksgiving Day (4th Thursday in November)
    if (month == 11 && weekday == 5) {
        NSInteger thursdayCount = (day - 1) / 7 + 1;
        if (thursdayCount == 4) return YES;
    }
    
    // Christmas Day (December 25th, or next Monday if weekend)
    if (month == 12) {
        if (day == 25 && weekday >= 2 && weekday <= 6) return YES; // Dec 25 on weekday
        if (day == 26 && weekday == 2) return YES; // Dec 26 Monday if Dec 25 was Sunday
        if (day == 27 && weekday == 2) return YES; // Dec 27 Monday if Dec 25 was Saturday
    }
    
    return NO;
}

+ (NSArray<NSDate *> *)getNextTradingDays:(NSInteger)count fromDate:(NSDate *)startDate {
    if (count <= 0 || !startDate) return @[];
    
    NSMutableArray<NSDate *> *tradingDays = [NSMutableArray array];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *currentDate = startDate;
    
    while (tradingDays.count < count) {
        // Move to next day
        currentDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:currentDate options:0];
        
        if ([self isTradingDay:currentDate]) {
            [tradingDays addObject:currentDate];
        }
    }
    
    return [tradingDays copy];
}

+ (NSArray<NSDate *> *)getPreviousTradingDays:(NSInteger)count fromDate:(NSDate *)startDate {
    if (count <= 0 || !startDate) return @[];
    
    NSMutableArray<NSDate *> *tradingDays = [NSMutableArray array];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *currentDate = startDate;
    
    while (tradingDays.count < count) {
        // Move to previous day
        currentDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:-1 toDate:currentDate options:0];
        
        if ([self isTradingDay:currentDate]) {
            [tradingDays insertObject:currentDate atIndex:0]; // Insert at beginning to maintain chronological order
        }
    }
    
    return [tradingDays copy];
}

+ (NSArray<NSDate *> *)getUSMarketHolidaysForYear:(NSInteger)year {
    NSMutableArray<NSDate *> *holidays = [NSMutableArray array];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    // Helper function to create date
    NSDate* (^createDate)(NSInteger, NSInteger, NSInteger) = ^NSDate*(NSInteger year, NSInteger month, NSInteger day) {
        NSDateComponents *components = [[NSDateComponents alloc] init];
        components.year = year;
        components.month = month;
        components.day = day;
        return [calendar dateFromComponents:components];
    };
    
    // New Year's Day (with Monday substitution)
    NSDate *newYear = createDate(year, 1, 1);
    [holidays addObject:[self getObservedHoliday:newYear]];
    
    // Martin Luther King Jr. Day (3rd Monday in January)
    [holidays addObject:[self getNthWeekdayOfMonth:3 weekday:2 month:1 year:year]];
    
    // Presidents' Day (3rd Monday in February)
    [holidays addObject:[self getNthWeekdayOfMonth:3 weekday:2 month:2 year:year]];
    
    // Good Friday
    NSDate *easter = [self getEasterDateForYear:year];
    if (easter) {
        NSDate *goodFriday = [calendar dateByAddingUnit:NSCalendarUnitDay value:-2 toDate:easter options:0];
        [holidays addObject:goodFriday];
    }
    
    // Memorial Day (last Monday in May)
    [holidays addObject:[self getLastWeekdayOfMonth:2 month:5 year:year]];
    
    // Juneteenth (with Monday substitution)
    NSDate *juneteenth = createDate(year, 6, 19);
    [holidays addObject:[self getObservedHoliday:juneteenth]];
    
    // Independence Day (with Monday substitution)
    NSDate *july4th = createDate(year, 7, 4);
    [holidays addObject:[self getObservedHoliday:july4th]];
    
    // Labor Day (1st Monday in September)
    [holidays addObject:[self getNthWeekdayOfMonth:1 weekday:2 month:9 year:year]];
    
    // Thanksgiving (4th Thursday in November)
    [holidays addObject:[self getNthWeekdayOfMonth:4 weekday:5 month:11 year:year]];
    
    // Christmas (with Monday substitution)
    NSDate *christmas = createDate(year, 12, 25);
    [holidays addObject:[self getObservedHoliday:christmas]];
    
    return [holidays copy];
}

#pragma mark - Helper Methods

+ (NSDate *)getObservedHoliday:(NSDate *)holiday {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSInteger weekday = [calendar component:NSCalendarUnitWeekday fromDate:holiday];
    
    if (weekday == 1) { // Sunday -> Monday
        return [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:holiday options:0];
    } else if (weekday == 7) { // Saturday -> Monday
        return [calendar dateByAddingUnit:NSCalendarUnitDay value:2 toDate:holiday options:0];
    }
    
    return holiday; // Weekday, no change
}

+ (NSDate *)getNthWeekdayOfMonth:(NSInteger)n weekday:(NSInteger)weekday month:(NSInteger)month year:(NSInteger)year {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.year = year;
    components.month = month;
    components.day = 1;
    components.weekday = weekday;
    components.weekdayOrdinal = n;
    
    return [calendar dateFromComponents:components];
}

+ (NSDate *)getLastWeekdayOfMonth:(NSInteger)weekday month:(NSInteger)month year:(NSInteger)year {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    // Start with last day of month
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.year = year;
    components.month = month + 1;
    components.day = 0; // This gives us the last day of the previous month
    
    NSDate *lastDayOfMonth = [calendar dateFromComponents:components];
    
    // Find the last occurrence of the desired weekday
    for (NSInteger i = 0; i < 7; i++) {
        NSDate *testDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:-i toDate:lastDayOfMonth options:0];
        NSInteger testWeekday = [calendar component:NSCalendarUnitWeekday fromDate:testDate];
        
        if (testWeekday == weekday) {
            return testDate;
        }
    }
    
    return nil; // Should never happen
}

+ (NSDate *)getEasterDateForYear:(NSInteger)year {
    // Easter calculation using the algorithm for Western Christianity
    NSInteger a = year % 19;
    NSInteger b = year / 100;
    NSInteger c = year % 100;
    NSInteger d = b / 4;
    NSInteger e = b % 4;
    NSInteger f = (b + 8) / 25;
    NSInteger g = (b - f + 1) / 3;
    NSInteger h = (19 * a + b - d - g + 15) % 30;
    NSInteger i = c / 4;
    NSInteger k = c % 4;
    NSInteger l = (32 + 2 * e + 2 * i - h - k) % 7;
    NSInteger m = (a + 11 * h + 22 * l) / 451;
    NSInteger month = (h + l - 7 * m + 114) / 31;
    NSInteger day = ((h + l - 7 * m + 114) % 31) + 1;
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.year = year;
    components.month = month;
    components.day = day;
    
    return [calendar dateFromComponents:components];
}

@end

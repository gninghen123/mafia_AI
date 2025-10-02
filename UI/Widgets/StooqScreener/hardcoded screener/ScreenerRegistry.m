//
//  ScreenerRegistry.m
//  TradingApp
//

#import "ScreenerRegistry.h"
#import "ShakeScreener.h"
#import "WIRScreener.h"
#import "FlyingBabyScreener.h"
#import "PDScreener.h"
#import "SMCScreener.h"
#import "InsideBoxScreener.h"
#import "PullbackToSMAScreener.h"


@interface ScreenerRegistry ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, BaseScreener *> *screeners;

@end

@implementation ScreenerRegistry

#pragma mark - Singleton

+ (instancetype)sharedRegistry {
    static ScreenerRegistry *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ScreenerRegistry alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _screeners = [NSMutableDictionary dictionary];
        [self registerDefaultScreeners];
    }
    return self;
}

- (void)registerDefaultScreeners {
    // Existing screeners
    [self registerScreenerClass:[ShakeScreener class]];
    [self registerScreenerClass:[WIRScreener class]];
    [self registerScreenerClass:[FlyingBabyScreener class]];
    [self registerScreenerClass:[PDScreener class]];
    [self registerScreenerClass:[SMCScreener class]];
    [self registerScreenerClass:[InsideBoxScreener class]];
    [self registerScreenerClass:[PullbackToSMAScreener class]];
    NSLog(@"✅ Registered %lu default screeners", (unsigned long)self.screeners.count);
}

#pragma mark - Registration

- (void)registerScreener:(BaseScreener *)screener {
    if (!screener || !screener.screenerID) {
        NSLog(@"⚠️ Cannot register screener: invalid screener or missing ID");
        return;
    }
    
    self.screeners[screener.screenerID] = screener;
    NSLog(@"✅ Registered screener: %@ (%@)", screener.displayName, screener.screenerID);
}

- (void)registerScreenerClass:(Class)screenerClass {
    if (![screenerClass isSubclassOfClass:[BaseScreener class]]) {
        NSLog(@"⚠️ Cannot register screener class: not a subclass of BaseScreener");
        return;
    }
    
    BaseScreener *instance = [[screenerClass alloc] init];
    [self registerScreener:instance];
}

#pragma mark - Access

- (nullable BaseScreener *)screenerWithID:(NSString *)screenerID {
    return self.screeners[screenerID];
}

- (NSArray<NSString *> *)allScreenerIDs {
    return [self.screeners allKeys];
}

- (NSArray<BaseScreener *> *)allScreeners {
    return [self.screeners allValues];
}

- (BOOL)isScreenerRegistered:(NSString *)screenerID {
    return self.screeners[screenerID] != nil;
}

#pragma mark - Information

- (nullable NSDictionary *)infoForScreener:(NSString *)screenerID {
    BaseScreener *screener = [self screenerWithID:screenerID];
    if (!screener) return nil;
    
    return @{
        @"screenerID": screener.screenerID,
        @"displayName": screener.displayName,
        @"description": screener.descriptionText,
        @"minBarsRequired": @(screener.minBarsRequired)
    };
}

@end

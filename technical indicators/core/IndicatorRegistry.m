//
// IndicatorRegistry.m
//

#import "IndicatorRegistry.h"
#import "emaindicator.h"
#import "atrindicator.h"
#import "bollingerbandsindicator.h"
#import "smaindicator.h"
#import "rsiindicator.h"
#import "securityIndicator.h"
#import "volumeindicator.h"
#import "RawDataSeriesIndicator.h"



@interface IndicatorRegistry ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, Class> *hardcodedIndicators;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *pineScriptIndicators;
@property (nonatomic, strong) dispatch_queue_t registryQueue;
@end

@implementation IndicatorRegistry

#pragma mark - Singleton

+ (instancetype)sharedRegistry {
    static IndicatorRegistry *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _hardcodedIndicators = [[NSMutableDictionary alloc] init];
        _pineScriptIndicators = [[NSMutableDictionary alloc] init];
        _registryQueue = dispatch_queue_create("com.tradingapp.indicator.registry", DISPATCH_QUEUE_CONCURRENT);
        
        [self registerBuiltInIndicators];
    }
    return self;
}

#pragma mark - Registration

- (void)registerIndicatorClass:(Class)indicatorClass withIdentifier:(NSString *)identifier {
    if (!indicatorClass || !identifier) {
        NSLog(@"❌ IndicatorRegistry: Invalid parameters for registration");
        return;
    }
    
    // Verify class implements TechnicalIndicatorBase
    if (![indicatorClass isSubclassOfClass:[TechnicalIndicatorBase class]]) {
        NSLog(@"❌ IndicatorRegistry: Class %@ must inherit from TechnicalIndicatorBase", NSStringFromClass(indicatorClass));
        return;
    }
    
    dispatch_barrier_async(self.registryQueue, ^{
        self.hardcodedIndicators[identifier] = indicatorClass;
        NSLog(@"✅ IndicatorRegistry: Registered hardcoded indicator '%@' -> %@", identifier, NSStringFromClass(indicatorClass));
    });
}

- (BOOL)registerPineScriptIndicator:(NSString *)script
                     withIdentifier:(NSString *)identifier
                              error:(NSError **)error {
    if (!script || !identifier) {
        if (error) {
            *error = [NSError errorWithDomain:@"IndicatorRegistry"
                                         code:2001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Script and identifier are required"}];
        }
        return NO;
    }
    
    // TODO: Add PineScript validation here in Phase 3
    // For now, just store the script
    
    __block BOOL success = YES;
    dispatch_barrier_sync(self.registryQueue, ^{
        self.pineScriptIndicators[identifier] = script;
        NSLog(@"✅ IndicatorRegistry: Registered PineScript indicator '%@'", identifier);
    });
    
    return success;
}

#pragma mark - Factory Methods

- (nullable TechnicalIndicatorBase *)createIndicatorWithIdentifier:(NSString *)identifier
                                                        parameters:(nullable NSDictionary<NSString *, id> *)parameters {
    if (!identifier) {
        return nil;
    }
    
    __block Class indicatorClass = nil;
    dispatch_sync(self.registryQueue, ^{
        indicatorClass = self.hardcodedIndicators[identifier];
    });
    
    if (indicatorClass) {
        return [self createIndicatorWithClass:indicatorClass parameters:parameters];
    }
    
    // TODO: Handle PineScript indicators in Phase 3
    __block NSString *pineScript = nil;
    dispatch_sync(self.registryQueue, ^{
        pineScript = self.pineScriptIndicators[identifier];
    });
    
    if (pineScript) {
        NSLog(@"⚠️ IndicatorRegistry: PineScript indicators not yet implemented for '%@'", identifier);
        return nil;
    }
    
    NSLog(@"❌ IndicatorRegistry: Unknown indicator identifier '%@'", identifier);
    return nil;
}

- (nullable TechnicalIndicatorBase *)createIndicatorWithClass:(Class)indicatorClass
                                                   parameters:(nullable NSDictionary<NSString *, id> *)parameters {
    if (!indicatorClass) {
        return nil;
    }
    
    NSDictionary *effectiveParams = parameters ?: [indicatorClass defaultParameters];
    
    TechnicalIndicatorBase *indicator = [[indicatorClass alloc] initWithParameters:effectiveParams];
    if (!indicator) {
        NSLog(@"❌ IndicatorRegistry: Failed to create indicator of class %@", NSStringFromClass(indicatorClass));
        return nil;
    }
    
    return indicator;
}

#pragma mark - Discovery

- (NSArray<NSString *> *)allIndicatorIdentifiers {
    __block NSArray *hardcoded, *pineScript;
    dispatch_sync(self.registryQueue, ^{
        hardcoded = [self.hardcodedIndicators allKeys];
        pineScript = [self.pineScriptIndicators allKeys];
    });
    
    NSMutableArray *all = [NSMutableArray arrayWithArray:hardcoded];
    [all addObjectsFromArray:pineScript];
    
    return [all sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray<NSString *> *)hardcodedIndicatorIdentifiers {
    __block NSArray<NSString *> *identifiers;
    dispatch_sync(self.registryQueue, ^{
        identifiers = [[self.hardcodedIndicators allKeys] sortedArrayUsingSelector:@selector(compare:)];
    });
    return identifiers;
}

- (NSArray<NSString *> *)pineScriptIndicatorIdentifiers {
    __block NSArray<NSString *> *identifiers;
    dispatch_sync(self.registryQueue, ^{
        identifiers = [[self.pineScriptIndicators allKeys] sortedArrayUsingSelector:@selector(compare:)];
    });
    return identifiers;
}

- (nullable NSDictionary<NSString *, id> *)indicatorInfoForIdentifier:(NSString *)identifier {
    if (!identifier) {
        return nil;
    }
    
    __block Class indicatorClass = nil;
    dispatch_sync(self.registryQueue, ^{
        indicatorClass = self.hardcodedIndicators[identifier];
    });
    
    if (indicatorClass) {
        return @{
            @"identifier": identifier,
            @"name": NSStringFromClass(indicatorClass),
            @"type": @"hardcoded",
            @"defaultParameters": [indicatorClass defaultParameters],
            @"parameterRules": [indicatorClass parameterValidationRules],
            @"minimumBars": @([indicatorClass instanceMethodForSelector:@selector(minimumBarsRequired)] ? 1 : 0) // Simplified
        };
    }
    
    __block NSString *pineScript = nil;
    dispatch_sync(self.registryQueue, ^{
        pineScript = self.pineScriptIndicators[identifier];
    });
    
    if (pineScript) {
        return @{
            @"identifier": identifier,
            @"name": identifier,
            @"type": @"pinescript",
            @"script": pineScript
        };
    }
    
    return nil;
}

#pragma mark - Validation

- (BOOL)isIndicatorRegistered:(NSString *)identifier {
    if (!identifier) {
        return NO;
    }
    
    __block BOOL isRegistered = NO;
    dispatch_sync(self.registryQueue, ^{
        isRegistered = (self.hardcodedIndicators[identifier] != nil) || (self.pineScriptIndicators[identifier] != nil);
    });
    
    return isRegistered;
}

- (nullable Class)indicatorClassForIdentifier:(NSString *)identifier {
    if (!identifier) {
        return nil;
    }
    
    __block Class indicatorClass = nil;
    dispatch_sync(self.registryQueue, ^{
        indicatorClass = self.hardcodedIndicators[identifier];
    });
    
    return indicatorClass;
}

#pragma mark - Built-in Registration

- (void)registerBuiltInIndicators {
    // This will be called when hardcoded indicators are implemented in Phase 2
    // For now, just log that registry is ready
    NSLog(@"🔧 IndicatorRegistry: Ready for indicator registration");
    
    [self registerIndicatorClass:[SecurityIndicator class] withIdentifier:@"SecurityIndicator"];
       [self registerIndicatorClass:[VolumeIndicator class] withIdentifier:@"VolumeIndicator"];
            [self registerIndicatorClass:[EMAIndicator class] withIdentifier:@"EMA"];
     [self registerIndicatorClass:[SMAIndicator class] withIdentifier:@"SMA"];
     [self registerIndicatorClass:[RSIIndicator class] withIdentifier:@"RSI"];
     [self registerIndicatorClass:[ATRIndicator class] withIdentifier:@"ATR"];
     [self registerIndicatorClass:[BollingerBandsIndicator class] withIdentifier:@"BB"];
    // [self registerIndicatorClass:[APTRIndicator class] withIdentifier:@"APTR"];
}

@end

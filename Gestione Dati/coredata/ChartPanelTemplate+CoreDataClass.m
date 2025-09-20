//
// ChartPanelTemplate+CoreDataClass.m
// TradingApp
//
// CoreData model implementation for chart panel templates
//

#import "ChartPanelTemplate+CoreDataClass.h"
#import "ChartTemplate+CoreDataClass.h"
#import "TechnicalIndicatorBase+Hierarchy.h"

@implementation ChartPanelTemplate

// ❌ RIMUOVO TUTTI I @dynamic - Xcode li genererà automaticamente nei +CoreDataProperties files

// Runtime property (not persisted)
@synthesize rootIndicator = _rootIndicator;

#pragma mark - Convenience Methods

+ (instancetype)createWithRootIndicatorType:(NSString *)rootType
                                 parameters:(NSDictionary *)params
                                    context:(NSManagedObjectContext *)context {
    
    ChartPanelTemplate *panel = [NSEntityDescription insertNewObjectForEntityForName:@"ChartPanelTemplate"
                                                              inManagedObjectContext:context];
    
    panel.panelID = [[NSUUID UUID] UUIDString];
    panel.rootIndicatorType = rootType;
    panel.relativeHeight = 0.33; // Default height
    panel.displayOrder = 0;
    
    // Serialize parameters to JSON
    if (params) {
        NSError *error;
        NSData *paramsData = [NSJSONSerialization dataWithJSONObject:params
                                                             options:0
                                                               error:&error];
        if (paramsData) {
            panel.rootIndicatorParams = paramsData;
        } else {
            NSLog(@"⚠️ Failed to serialize root indicator params: %@", error);
        }
    }
    
    return panel;
}

- (ChartPanelTemplate *)createWorkingCopy {
    ChartPanelTemplate *workingCopy = [[ChartPanelTemplate alloc] init];
    
    workingCopy.panelID = self.panelID;
    workingCopy.relativeHeight = self.relativeHeight;
    workingCopy.displayOrder = self.displayOrder;
    workingCopy.panelName = [self.panelName copy];
    workingCopy.rootIndicatorType = [self.rootIndicatorType copy];
    workingCopy.rootIndicatorParams = [self.rootIndicatorParams copy];
    workingCopy.childIndicatorsData = [self.childIndicatorsData copy];
    
    // Deserialize the runtime indicator
    workingCopy.rootIndicator = [self deserializeRootIndicator];
    
    return workingCopy;
}

- (void)updateFromWorkingCopy:(ChartPanelTemplate *)workingCopy {
    self.panelID = workingCopy.panelID;
    self.relativeHeight = workingCopy.relativeHeight;
    self.displayOrder = workingCopy.displayOrder;
    self.panelName = workingCopy.panelName;
    self.rootIndicatorType = workingCopy.rootIndicatorType;
    self.rootIndicatorParams = workingCopy.rootIndicatorParams;
    self.childIndicatorsData = workingCopy.childIndicatorsData;
    
    // Update serialized data from runtime indicator
    if (workingCopy.rootIndicator) {
        [self serializeRootIndicator:workingCopy.rootIndicator];
    }
}

#pragma mark - Serialization Methods

- (void)serializeRootIndicator:(TechnicalIndicatorBase *)rootIndicator {
    if (!rootIndicator) return;
    
    // Store the class name
    self.rootIndicatorType = NSStringFromClass([rootIndicator class]);
    
    // Serialize parameters
    NSDictionary *indicatorDict = [rootIndicator serializeToDictionary];
    NSError *error;
    NSData *paramsData = [NSJSONSerialization dataWithJSONObject:indicatorDict
                                                         options:NSJSONWritingPrettyPrinted
                                                           error:&error];
    if (paramsData) {
        self.rootIndicatorParams = paramsData;
    } else {
        NSLog(@"⚠️ Failed to serialize root indicator: %@", error);
    }
    
    // Serialize child indicators
    if (rootIndicator.childIndicators.count > 0) {
        [self serializeChildIndicators:rootIndicator.childIndicators];
    }
}

- (TechnicalIndicatorBase *)deserializeRootIndicator {
    if (!self.rootIndicatorType || !self.rootIndicatorParams) return nil;
    
    NSError *error;
    NSDictionary *indicatorDict = [NSJSONSerialization JSONObjectWithData:self.rootIndicatorParams
                                                                  options:0
                                                                    error:&error];
    if (!indicatorDict) {
        NSLog(@"⚠️ Failed to deserialize root indicator params: %@", error);
        return nil;
    }
    
    // Create the indicator instance
    TechnicalIndicatorBase *rootIndicator = [TechnicalIndicatorBase deserializeFromDictionary:indicatorDict];
    
    if (rootIndicator) {
        // Deserialize and add child indicators
        NSArray<TechnicalIndicatorBase *> *children = [self deserializeChildIndicators];
        for (TechnicalIndicatorBase *child in children) {
            [rootIndicator addChildIndicator:child];
        }
        
        // Cache the runtime instance
        _rootIndicator = rootIndicator;
    }
    
    return rootIndicator;
}

- (void)serializeChildIndicators:(NSArray<TechnicalIndicatorBase *> *)childIndicators {
    if (!childIndicators || childIndicators.count == 0) {
        self.childIndicatorsData = nil;
        return;
    }
    
    NSMutableArray *serializedChildren = [[NSMutableArray alloc] init];
    
    for (TechnicalIndicatorBase *child in childIndicators) {
        NSDictionary *childDict = [child serializeSubtreeToDictionary]; // Include grandchildren
        [serializedChildren addObject:childDict];
    }
    
    NSError *error;
    NSData *childrenData = [NSJSONSerialization dataWithJSONObject:serializedChildren
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:&error];
    if (childrenData) {
        self.childIndicatorsData = childrenData;
    } else {
        NSLog(@"⚠️ Failed to serialize child indicators: %@", error);
    }
}

- (NSArray<TechnicalIndicatorBase *> *)deserializeChildIndicators {
    if (!self.childIndicatorsData) return @[];
    
    NSError *error;
    NSArray *childrenArray = [NSJSONSerialization JSONObjectWithData:self.childIndicatorsData
                                                             options:0
                                                               error:&error];
    if (!childrenArray) {
        NSLog(@"⚠️ Failed to deserialize child indicators: %@", error);
        return @[];
    }
    
    NSMutableArray<TechnicalIndicatorBase *> *children = [[NSMutableArray alloc] init];
    
    for (NSDictionary *childDict in childrenArray) {
        TechnicalIndicatorBase *child = [TechnicalIndicatorBase deserializeSubtreeFromDictionary:childDict];
        if (child) {
            [children addObject:child];
        }
    }
    
    return [children copy];
}

#pragma mark - Display Helpers

- (NSString *)displayName {
    if (self.panelName && self.panelName.length > 0) {
        return self.panelName;
    }
    
    // Generate from root indicator type
    return [NSString stringWithFormat:@"%@ Panel", [self rootIndicatorDisplayName]];
}

- (NSString *)rootIndicatorDisplayName {
    if (!self.rootIndicatorType) return @"Unknown";
    
    // Convert class name to display name
    NSString *displayName = self.rootIndicatorType;
    displayName = [displayName stringByReplacingOccurrencesOfString:@"Indicator" withString:@""];
    
    // Handle common cases
    if ([displayName isEqualToString:@"Security"]) return @"Security";
    if ([displayName isEqualToString:@"Volume"]) return @"Volume";
    if ([displayName isEqualToString:@"RSI"]) return @"RSI";
    if ([displayName isEqualToString:@"MACD"]) return @"MACD";
    
    return displayName;
}

#pragma mark - Runtime Indicator Access

- (TechnicalIndicatorBase *)rootIndicator {
    if (!_rootIndicator) {
        _rootIndicator = [self deserializeRootIndicator];
    }
    return _rootIndicator;
}

- (void)setRootIndicator:(TechnicalIndicatorBase *)rootIndicator {
    _rootIndicator = rootIndicator;
    
    // Update serialized data
    if (rootIndicator) {
        [self serializeRootIndicator:rootIndicator];
    }
}

#pragma mark - Validation

- (BOOL)validatePanelID:(id *)valueRef error:(NSError **)outError {
    NSString *panelID = *valueRef;
    
    if (!panelID || panelID.length == 0) {
        if (outError) {
            *outError = [NSError errorWithDomain:@"ChartPanelTemplateValidation"
                                            code:2001
                                        userInfo:@{NSLocalizedDescriptionKey: @"Panel ID cannot be empty"}];
        }
        return NO;
    }
    
    return YES;
}

- (BOOL)validateRelativeHeight:(id *)valueRef error:(NSError **)outError {
    NSNumber *height = *valueRef;
    double heightValue = [height doubleValue];
    
    if (heightValue <= 0.0 || heightValue > 1.0) {
        if (outError) {
            *outError = [NSError errorWithDomain:@"ChartPanelTemplateValidation"
                                            code:2002
                                        userInfo:@{NSLocalizedDescriptionKey: @"Relative height must be between 0.0 and 1.0"}];
        }
        return NO;
    }
    
    return YES;
}

- (BOOL)validateRootIndicatorType:(id *)valueRef error:(NSError **)outError {
    NSString *indicatorType = *valueRef;
    
    if (!indicatorType || indicatorType.length == 0) {
        if (outError) {
            *outError = [NSError errorWithDomain:@"ChartPanelTemplateValidation"
                                            code:2003
                                        userInfo:@{NSLocalizedDescriptionKey: @"Root indicator type cannot be empty"}];
        }
        return NO;
    }
    
    // Verify class exists
    Class indicatorClass = NSClassFromString(indicatorType);
    if (!indicatorClass) {
        if (outError) {
            *outError = [NSError errorWithDomain:@"ChartPanelTemplateValidation"
                                            code:2004
                                        userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unknown indicator class: %@", indicatorType]}];
        }
        return NO;
    }
    
    return YES;
}

#pragma mark - Core Data Lifecycle

- (void)awakeFromInsert {
    [super awakeFromInsert];
    
    if (!self.panelID) {
        self.panelID = [[NSUUID UUID] UUIDString];
    }
    
    if (self.relativeHeight == 0.0) {
        self.relativeHeight = 0.33; // Default height
    }
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p> ID:%@ Type:%@ Height:%.2f Order:%d",
            NSStringFromClass(self.class), self,
            self.panelID, self.rootIndicatorType,
            self.relativeHeight, self.displayOrder];
}

@end

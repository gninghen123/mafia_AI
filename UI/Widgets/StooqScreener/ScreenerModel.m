//
//  ScreenerModel.m
//  TradingApp
//

#import "ScreenerModel.h"

// ============================================================================
// SCREENER STEP IMPLEMENTATION
// ============================================================================

@implementation ScreenerStep

+ (instancetype)stepWithScreenerID:(NSString *)screenerID
                       inputSource:(NSString *)inputSource
                        parameters:(NSDictionary *)parameters {
    ScreenerStep *step = [[ScreenerStep alloc] init];
    step.screenerID = screenerID;
    step.inputSource = inputSource;
    step.parameters = parameters ?: @{};
    return step;
}

- (NSDictionary *)toDictionary {
    return @{
        @"screener_id": self.screenerID ?: @"",
        @"input_source": self.inputSource ?: @"universe",
        @"parameters": self.parameters ?: @{}
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (!dict) return nil;
    
    ScreenerStep *step = [[ScreenerStep alloc] init];
    step.screenerID = dict[@"screener_id"];
    step.inputSource = dict[@"input_source"] ?: @"universe";
    step.parameters = dict[@"parameters"] ?: @{};
    
    return step;
}

@end

// ============================================================================
// STEP RESULT IMPLEMENTATION
// ============================================================================

@implementation StepResult
@end

// ============================================================================
// MODEL RESULT IMPLEMENTATION
// ============================================================================

@implementation ModelResult
@end

// ============================================================================
// SCREENER MODEL IMPLEMENTATION
// ============================================================================

@implementation ScreenerModel

#pragma mark - Factory Methods

+ (instancetype)modelWithID:(NSString *)modelID
                displayName:(NSString *)displayName
                      steps:(NSArray<ScreenerStep *> *)steps {
    ScreenerModel *model = [[ScreenerModel alloc] init];
    model.modelID = modelID;
    model.displayName = displayName;
    model.steps = steps;
    model.schedule = @"manual";
    model.isEnabled = YES;
    model.createdAt = [NSDate date];
    model.modifiedAt = [NSDate date];
    return model;
}

#pragma mark - Validation

- (BOOL)isValid {
    if (!self.modelID || self.modelID.length == 0) return NO;
    if (!self.displayName || self.displayName.length == 0) return NO;
    if (!self.steps || self.steps.count == 0) return NO;
    
    // Check that all steps have valid screener IDs
    for (ScreenerStep *step in self.steps) {
        if (!step.screenerID || step.screenerID.length == 0) return NO;
    }
    
    return YES;
}

- (NSInteger)totalMinBarsRequired {
    // This will be calculated by the batch runner based on actual screener instances
    // For now, return a safe default
    return 100;
}

#pragma mark - Serialization

- (NSDictionary *)toDictionary {
    NSMutableArray *stepsArray = [NSMutableArray array];
    for (ScreenerStep *step in self.steps) {
        [stepsArray addObject:[step toDictionary]];
    }
    
    return @{
        @"model_id": self.modelID ?: @"",
        @"display_name": self.displayName ?: @"",
        @"description": self.modelDescription ?: @"",
        @"steps": stepsArray,
        @"schedule": self.schedule ?: @"manual",
        @"is_enabled": @(self.isEnabled),
        @"created_at": @([self.createdAt timeIntervalSince1970]),
        @"modified_at": @([self.modifiedAt timeIntervalSince1970])
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (!dict) return nil;
    
    ScreenerModel *model = [[ScreenerModel alloc] init];
    model.modelID = dict[@"model_id"];
    model.displayName = dict[@"display_name"];
    model.modelDescription = dict[@"description"];
    model.schedule = dict[@"schedule"] ?: @"manual";
    model.isEnabled = [dict[@"is_enabled"] boolValue];
    
    // Parse steps
    NSArray *stepsData = dict[@"steps"];
    if (stepsData && [stepsData isKindOfClass:[NSArray class]]) {
        NSMutableArray *steps = [NSMutableArray array];
        for (NSDictionary *stepDict in stepsData) {
            ScreenerStep *step = [ScreenerStep fromDictionary:stepDict];
            if (step) {
                [steps addObject:step];
            }
        }
        model.steps = [steps copy];
    }
    
    // Parse dates
    if (dict[@"created_at"]) {
        model.createdAt = [NSDate dateWithTimeIntervalSince1970:[dict[@"created_at"] doubleValue]];
    } else {
        model.createdAt = [NSDate date];
    }
    
    if (dict[@"modified_at"]) {
        model.modifiedAt = [NSDate dateWithTimeIntervalSince1970:[dict[@"modified_at"] doubleValue]];
    } else {
        model.modifiedAt = [NSDate date];
    }
    
    return model;
}

- (BOOL)saveToFile:(NSString *)filePath error:(NSError **)error {
    NSDictionary *dict = [self toDictionary];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:error];
    if (!jsonData) {
        return NO;
    }
    
    return [jsonData writeToFile:filePath options:NSDataWritingAtomic error:error];
}

+ (instancetype)loadFromFile:(NSString *)filePath error:(NSError **)error {
    NSData *jsonData = [NSData dataWithContentsOfFile:filePath options:0 error:error];
    if (!jsonData) {
        return nil;
    }
    
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                         options:0
                                                           error:error];
    if (!dict) {
        return nil;
    }
    
    return [ScreenerModel fromDictionary:dict];
}

@end
